---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 單位框架基本元素
    生命條、能量條、名稱文字、生命值文字、等級文字、治療預測、角色肖像
    StatusBar 材質快取與失效
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- 效能：快取 PostUpdate hot path 使用的全域變數
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local C = LunarUI.Colors
local BG_DARKEN = LunarUI.BG_DARKEN

--------------------------------------------------------------------------------
-- StatusBar 材質快取
--------------------------------------------------------------------------------

local statusBarTexture -- 延遲載入：等 DB 就緒後再解析
local function GetStatusBarTexture()
    if not statusBarTexture then
        statusBarTexture = LunarUI.GetSelectedStatusBarTexture()
    end
    return statusBarTexture
end

-- 提供快取失效函數供 Options 模組在材質變更時呼叫
local function InvalidateStatusBarTexture()
    statusBarTexture = nil
end

LunarUI.UFGetStatusBarTexture = GetStatusBarTexture
LunarUI.InvalidateStatusBarTextureCache = InvalidateStatusBarTexture

--------------------------------------------------------------------------------
-- 共用顏色常數
--------------------------------------------------------------------------------

local REACTION_COLORS = {
    [1] = { 0.9, 0.2, 0.2 }, -- 仇恨
    [2] = { 0.9, 0.2, 0.2 }, -- 敵對
    [3] = { 0.9, 0.2, 0.2 }, -- 不友好
    [4] = { 0.9, 0.9, 0.2 }, -- 中立
    [5] = { 0.2, 0.9, 0.3 }, -- 友善
    [6] = { 0.2, 0.9, 0.3 }, -- 尊敬
    [7] = { 0.2, 0.9, 0.3 }, -- 崇敬
    [8] = { 0.2, 0.9, 0.3 }, -- 崇拜
}

--------------------------------------------------------------------------------
-- 生命條
--------------------------------------------------------------------------------

local function CreateHealthBar(frame, unit)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(GetStatusBarTexture())
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    -- 高度：框架總高度減去能量條高度（嵌入式佈局）
    -- pet/targettarget 無能量條，血條填滿整個框架（減去邊框）
    local powerHeight = (unit == "pet" or unit == "targettarget") and 0 or (unit == "raid") and 4 or 6
    health:SetHeight(frame:GetHeight() - powerHeight - 2) -- -2 for top+bottom border

    -- 顏色設定：職業顏色優先，NPC 用反應顏色
    health.colorClass = true
    health.colorReaction = true
    health.colorTapping = true
    health.colorDisconnected = true
    health.colorSmooth = false

    -- 背景
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    health.bg:SetTexture(GetStatusBarTexture())
    health.bg:SetVertexColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    health.bg.multiplier = BG_DARKEN

    -- 頻繁更新以確保動畫流暢
    health.frequentUpdates = true

    -- 更新後鉤子：確保職業顏色正確套用（含 color cache 避免每幀重設）
    health.PostUpdate = function(self, _unit, _cur, _max)
        -- M11：快取 __owner 避免後段二次存取時 owner 已失效
        local ownerFrame = self.__owner
        local ownerUnit = ownerFrame and ownerFrame.unit
        if not ownerUnit then
            return
        end
        -- H2：frequentUpdates=true 下 unit 可能暫時無效，提早退出避免 API 傳入 nil
        if not UnitExists(ownerUnit) then
            return
        end

        local r, g, b

        -- 玩家使用職業顏色
        if UnitIsPlayer(ownerUnit) then
            local _, class = UnitClass(ownerUnit)
            if class then
                local color = RAID_CLASS_COLORS[class]
                if color then
                    r, g, b = color.r, color.g, color.b
                end
            end
        end

        -- NPC 使用聲望顏色
        if not r then
            local reaction = UnitReaction(ownerUnit, "player")
            if reaction then
                local rc = REACTION_COLORS[reaction]
                if rc then
                    r, g, b = rc[1], rc[2], rc[3]
                else
                    r, g, b = REACTION_COLORS[3][1], REACTION_COLORS[3][2], REACTION_COLORS[3][3]
                end
            end
        end

        if not r then
            return
        end

        -- 僅在顏色變更時呼叫 SetStatusBarColor
        if self._lastR ~= r or self._lastG ~= g or self._lastB ~= b then
            self._lastR, self._lastG, self._lastB = r, g, b
            self:SetStatusBarColor(r, g, b)
            self.bg:SetVertexColor(r * BG_DARKEN, g * BG_DARKEN, b * BG_DARKEN, 0.8)
        end

        -- 死亡狀態指示器（oUF 無內建 DeadIndicator element，需手動驅動）
        -- B3 效能修復：快取 isDead 狀態，只在狀態改變時才呼叫 SetShown（frequentUpdates=true 下每幀執行）
        if ownerFrame and ownerFrame.DeadIndicator then
            local isDead = UnitIsDeadOrGhost(ownerUnit)
            if isDead ~= self._lastIsDead then
                self._lastIsDead = isDead
                ownerFrame.DeadIndicator:SetShown(isDead)
                if ownerFrame.DeadOverlay then
                    ownerFrame.DeadOverlay:SetShown(isDead)
                end
            end
        end
    end

    frame.Health = health
    return health
end

--------------------------------------------------------------------------------
-- 能量條
--------------------------------------------------------------------------------

local function CreatePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetStatusBarTexture(GetStatusBarTexture())
    power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -1)
    power:SetPoint("TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -1)
    power:SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)

    power.colorPower = true
    power.frequentUpdates = true

    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
    power.bg:SetTexture(GetStatusBarTexture())
    power.bg:SetVertexColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    power.bg.multiplier = BG_DARKEN

    frame.Power = power
    return power
end

--------------------------------------------------------------------------------
-- 名稱文字
--------------------------------------------------------------------------------

local function CreateNameText(frame, unit)
    local name = frame.Health:CreateFontString(nil, "OVERLAY")
    -- 字型大小依框架類型
    local fontSize = (unit == "player" or unit == "target") and 11
        or (unit == "raid" or unit == "pet" or unit == "targettarget") and 9
        or 10
    LunarUI.SetFont(name, fontSize, "OUTLINE")
    name:SetPoint("LEFT", frame.Health, "LEFT", 5, 0)
    name:SetJustifyH("LEFT")

    -- 截斷長名稱（防止與血量文字重疊）
    -- raid/pet/targettarget 不顯示血量文字，名字可以更寬
    local nameWidthPct = (unit == "raid" or unit == "pet" or unit == "targettarget") and 0.9 or 0.6
    name:SetWidth(frame:GetWidth() * nameWidthPct)
    -- 使用 lunar:* 自訂 tag（SafeTag pcall 保護 + locale 支援 + UTF-8 安全）
    if unit == "raid" or unit == "party" then
        frame:Tag(name, "[lunar:name:abbrev]")
    else
        frame:Tag(name, "[lunar:name:medium]")
    end

    frame.Name = name
    return name
end

--------------------------------------------------------------------------------
-- 生命值文字
--------------------------------------------------------------------------------

local function CreateHealthText(frame, unit)
    -- raid/pet/targettarget 太小，不顯示血量百分比
    if unit == "raid" or unit == "pet" or unit == "targettarget" then
        return
    end

    local healthText = frame.Health:CreateFontString(nil, "OVERLAY")
    local fontSize = (unit == "player" or unit == "target") and 11 or 10
    LunarUI.SetFont(healthText, fontSize, "OUTLINE")
    healthText:SetPoint("RIGHT", frame.Health, "RIGHT", -5, 0)
    healthText:SetJustifyH("RIGHT")

    -- 使用 lunar:health:percent（四捨五入 + SafeTag pcall 保護）
    frame:Tag(healthText, "[lunar:health:percent]")

    frame.HealthText = healthText
    return healthText
end

--------------------------------------------------------------------------------
-- 等級文字
--------------------------------------------------------------------------------

local function CreateLevelText(frame, _unit)
    local level = frame.Health:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(level, 11, "OUTLINE")
    level:SetPoint("RIGHT", frame.Name, "LEFT", -4, 0)

    frame:Tag(level, "[lunar:level:smart]")
    frame.LevelText = level
    return level
end

--------------------------------------------------------------------------------
-- 治療預測條
--------------------------------------------------------------------------------

local function CreateHealPrediction(frame, unit)
    local unitKey = unit or "player"
    unitKey = unitKey:gsub("%d+$", "")
    local ufAll = LunarUI.GetModuleDB("unitframes")
    local ufDB = ufAll and ufAll[unitKey]
    if ufDB and ufDB.showHealPrediction == false then
        return
    end

    local hp = frame.Health
    if not hp then
        return
    end

    -- 自身治療預測（從 health fill 右端延伸，符合 oUF healthprediction 錨點慣例）
    local healingPlayer = CreateFrame("StatusBar", nil, hp)
    healingPlayer:SetStatusBarTexture(GetStatusBarTexture())
    healingPlayer:SetStatusBarColor(0.0, 0.8, 0.0, 0.4)
    healingPlayer:SetPoint("TOP")
    healingPlayer:SetPoint("BOTTOM")
    healingPlayer:SetPoint("LEFT", hp:GetStatusBarTexture(), "RIGHT")
    healingPlayer:SetWidth(hp:GetWidth())

    -- 他人治療預測
    local healingOther = CreateFrame("StatusBar", nil, hp)
    healingOther:SetStatusBarTexture(GetStatusBarTexture())
    healingOther:SetStatusBarColor(0.0, 0.6, 0.0, 0.3)
    healingOther:SetPoint("TOP")
    healingOther:SetPoint("BOTTOM")
    healingOther:SetPoint("LEFT", healingPlayer:GetStatusBarTexture(), "RIGHT")
    healingOther:SetWidth(hp:GetWidth())

    -- 吸收盾
    local damageAbsorb = CreateFrame("StatusBar", nil, hp)
    damageAbsorb:SetStatusBarTexture(GetStatusBarTexture())
    damageAbsorb:SetStatusBarColor(1.0, 1.0, 1.0, 0.3)
    damageAbsorb:SetPoint("TOP")
    damageAbsorb:SetPoint("BOTTOM")
    damageAbsorb:SetPoint("LEFT", healingOther:GetStatusBarTexture(), "RIGHT")
    damageAbsorb:SetWidth(hp:GetWidth())

    frame.HealthPrediction = {
        healingPlayer = healingPlayer,
        healingOther = healingOther,
        damageAbsorb = damageAbsorb,
        incomingHealOverflow = 1.05,
    }

    return frame.HealthPrediction
end

--------------------------------------------------------------------------------
-- 角色肖像
--------------------------------------------------------------------------------

local function CreatePortrait(frame, unit)
    local unitKey = unit and unit:gsub("%d+$", "") or "player"
    local ufAll = LunarUI.GetModuleDB("unitframes")
    local ufDB = ufAll and ufAll[unitKey]
    if not ufDB or not ufDB.showPortrait then
        return
    end

    local style = ufDB.portraitStyle or "class"
    local size = frame:GetHeight() - 2 -- 與框架高度對齊（扣除邊框）

    if style == "3d" then
        -- 3D 角色模型：oUF 會自動設定 SetUnit / SetCamera
        local portrait = CreateFrame("PlayerModel", nil, frame)
        portrait:SetSize(size, size)
        portrait:SetPoint("LEFT", frame, "LEFT", 1, 0)
        portrait:SetFrameLevel(frame.Health:GetFrameLevel() + 1)

        -- 背景（掛在 portrait 框架上確保正確層級）
        local bg = portrait:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetAllPoints(portrait)
        bg:SetColorTexture(0, 0, 0, 0.6)
        portrait._bg = bg

        frame.Portrait = portrait
    else
        -- 2D 職業圖示：設定 showClass 讓 oUF 使用 classicon atlas
        local portrait = frame.Health:CreateTexture(nil, "OVERLAY")
        portrait:SetSize(size, size)
        portrait:SetPoint("LEFT", frame, "LEFT", 1, 0)
        portrait.showClass = true

        frame.Portrait = portrait
    end

    -- 有 Portrait 時將血條右移，避免重疊
    -- 需先清除錨點再重新設定，避免重複 TOPLEFT 造成不確定行為
    if frame.Health and frame.Portrait then
        frame.Health:ClearAllPoints()
        frame.Health:SetPoint("TOPLEFT", frame, "TOPLEFT", size + 2, -1)
        frame.Health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        -- 與 CreateHealthBar 相同的固定像素計算（不用舊的百分比）
        local powerHeight = (unitKey == "pet" or unitKey == "targettarget") and 0 or (unitKey == "raid") and 4 or 6
        frame.Health:SetHeight(frame:GetHeight() - powerHeight - 2)
    end

    return frame.Portrait
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.UFCreateHealthBar = CreateHealthBar
LunarUI.UFCreatePowerBar = CreatePowerBar
LunarUI.UFCreateNameText = CreateNameText
LunarUI.UFCreateHealthText = CreateHealthText
LunarUI.UFCreateLevelText = CreateLevelText
LunarUI.UFCreateHealPrediction = CreateHealPrediction
LunarUI.UFCreatePortrait = CreatePortrait
