---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, redundant-value
--[[
    LunarUI - oUF 佈局
    定義所有單位框架的視覺風格

    月相感知單位框架：根據月相變化調整外觀
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- 等待 oUF 可用（TOC 中設定 X-oUF: LunarUF）
local oUF = Engine.oUF or _G.LunarUF or _G.oUF
if not oUF then
    local L = Engine.L or {}
    print("|cffff0000LunarUI:|r " .. (L["ErrorOUFNotFound"] or "找不到 oUF 框架"))
    return
end

--------------------------------------------------------------------------------
-- 常數與共用資源
--------------------------------------------------------------------------------

-- 前向宣告（供後續函數使用）
local spawnedFrames = {}

local statusBarTexture  -- lazy: resolved after DB is ready
local function GetStatusBarTexture()
    if not statusBarTexture then
        statusBarTexture = LunarUI.GetSelectedStatusBarTexture()
    end
    return statusBarTexture
end
local C = LunarUI.Colors

-- 框架尺寸
local SIZES = {
    player = { width = 220, height = 50 },
    target = { width = 220, height = 50 },
    focus = { width = 180, height = 40 },
    pet = { width = 120, height = 30 },
    targettarget = { width = 120, height = 30 },
    boss = { width = 180, height = 40 },
    party = { width = 160, height = 35 },
    raid = { width = 80, height = 30 },
}

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local CreateBackdrop = LunarUI.CreateBackdrop

--------------------------------------------------------------------------------
-- 核心元素
--------------------------------------------------------------------------------

--[[ 生命條 ]]
local function CreateHealthBar(frame, unit)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(GetStatusBarTexture())
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    -- 高度依單位類型而異
    local heightPercent = (unit == "raid") and 0.85 or 0.65
    health:SetHeight(frame:GetHeight() * heightPercent)

    -- 顏色設定
    health.colorClass = true
    health.colorReaction = true
    health.colorHealth = true
    health.colorSmooth = false

    -- 背景
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    health.bg:SetTexture(GetStatusBarTexture())
    health.bg:SetVertexColor(unpack(C.bgIcon))
    health.bg.multiplier = 0.3

    -- 頻繁更新以確保動畫流暢
    health.frequentUpdates = true

    -- 更新後鉤子：確保職業顏色正確套用（含 color cache 避免每幀重設）
    health.PostUpdate = function(self, _unit, _cur, _max)
        local ownerUnit = self.__owner and self.__owner.unit
        if not ownerUnit then return end

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
                if reaction >= 5 then
                    r, g, b = 0.2, 0.9, 0.3  -- 友善
                elseif reaction == 4 then
                    r, g, b = 0.9, 0.9, 0.2  -- 中立
                else
                    r, g, b = 0.9, 0.2, 0.2  -- 敵對
                end
            end
        end

        if not r then return end

        -- 僅在顏色變更時呼叫 SetStatusBarColor
        if self._lastR ~= r or self._lastG ~= g or self._lastB ~= b then
            self._lastR, self._lastG, self._lastB = r, g, b
            self:SetStatusBarColor(r, g, b)
            self.bg:SetVertexColor(r * 0.3, g * 0.3, b * 0.3, 0.8)
        end
    end

    frame.Health = health
    return health
end

--[[ 能量條 ]]
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
    power.bg:SetVertexColor(unpack(C.bgIcon))
    power.bg.multiplier = 0.3

    frame.Power = power
    return power
end

--[[ 名稱文字 ]]
local function CreateNameText(frame, unit)
    local name = frame.Health:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(name, 12, "OUTLINE")
    name:SetPoint("LEFT", frame.Health, "LEFT", 5, 0)
    name:SetJustifyH("LEFT")

    -- 較小框架截斷長名稱
    if unit == "raid" or unit == "party" then
        name:SetWidth(frame:GetWidth() - 10)
        frame:Tag(name, "[name:short]")
    else
        frame:Tag(name, "[name]")
    end

    frame.Name = name
    return name
end

--[[ 生命值文字 ]]
local function CreateHealthText(frame, unit)
    -- 團隊框架太小，跳過
    if unit == "raid" then return end

    local healthText = frame.Health:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(healthText, 10, "OUTLINE")
    healthText:SetPoint("RIGHT", frame.Health, "RIGHT", -5, 0)
    healthText:SetJustifyH("RIGHT")

    if unit == "player" or unit == "target" then
        frame:Tag(healthText, "[curhp] / [maxhp]")
    else
        frame:Tag(healthText, "[perhp]%")
    end

    frame.HealthText = healthText
    return healthText
end

--[[ 施法條 ]]
local function CreateCastbar(frame)
    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(GetStatusBarTexture())
    castbar:SetStatusBarColor(0.4, 0.6, 0.8, 1)

    -- 位於主框架下方
    castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
    castbar:SetHeight(16)

    -- 背景
    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(GetStatusBarTexture())
    bg:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    castbar.bg = bg

    -- 邊框
    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetAllPoints()
    LunarUI.ApplyBackdrop(border, nil, C.transparent)

    -- 法術圖示
    local icon = castbar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", castbar, "LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = icon

    -- 法術名稱
    local text = castbar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(text, 10, "OUTLINE")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetJustifyH("LEFT")
    castbar.Text = text

    -- 施法時間
    local time = castbar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(time, 10, "OUTLINE")
    time:SetPoint("RIGHT", castbar, "RIGHT", -4, 0)
    time:SetJustifyH("RIGHT")
    castbar.Time = time

    -- WoW 12.0 將 notInterruptible 設為隱藏值
    -- 暴雪故意限制插件存取此資訊
    -- 使用統一的施法條顏色（無法判斷是否可打斷）
    castbar.PostCastStart = function(self, _unit)
        self:SetStatusBarColor(0.4, 0.6, 0.8, 1)
    end

    castbar.PostChannelStart = function(self, _unit)
        self:SetStatusBarColor(0.4, 0.6, 0.8, 1)
    end

    -- 火花
    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(20, 20)
    spark:SetBlendMode("ADD")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    castbar.Spark = spark

    frame.Castbar = castbar
    return castbar
end

local UNITFRAME_DEBUFF_COLORS = LunarUI.DEBUFF_TYPE_COLORS

--[[ 光環白名單/黑名單快取 ]]
local auraWhitelistCache = {}
local auraBlacklistCache = {}

local function RebuildAuraFilterCache()
    wipe(auraWhitelistCache)
    wipe(auraBlacklistCache)
    local db = LunarUI.db.profile
    if not db then return end

    -- 將逗號分隔的 spell ID 字串轉為查找表
    if db.auraWhitelist and db.auraWhitelist ~= "" then
        for id in db.auraWhitelist:gmatch("(%d+)") do
            auraWhitelistCache[tonumber(id)] = true
        end
    end
    if db.auraBlacklist and db.auraBlacklist ~= "" then
        for id in db.auraBlacklist:gmatch("(%d+)") do
            auraBlacklistCache[tonumber(id)] = true
        end
    end
end

-- 公開方法供 Options 呼叫
LunarUI.RebuildAuraFilterCache = RebuildAuraFilterCache

--[[ 光環過濾器：根據 DB 設定過濾 ]]
local function AuraFilter(_element, unit, data)
    -- 標準化單位 key（boss1 → boss, party1 → party）
    local unitKey = unit:gsub("%d+$", "")
    local ufDB = LunarUI.db.profile.unitframes[unitKey]
    if not ufDB then return true end

    -- Fix 9: 合併多次 pcall 為一次，減少每個 aura 的開銷
    -- data 的欄位可能是 WoW secret value，用單一 pcall 保護所有存取
    local ok, shouldFilter = pcall(function()
        local spellId = data.spellId

        -- 黑名單：永遠不顯示
        if spellId and auraBlacklistCache[spellId] then
            return true
        end

        -- 白名單：永遠顯示（跳過其他過濾規則）
        if spellId and auraWhitelistCache[spellId] then
            return false
        end

        -- 僅顯示玩家施放的 debuff
        if ufDB.onlyPlayerDebuffs and data.isHarmfulAura and not data.isPlayerAura then
            return true
        end
        -- 隱藏持續超過 5 分鐘的 buff（減少雜訊），0 表示永久
        if not data.isHarmfulAura and data.duration and data.duration > 300 then
            return true
        end
        return false
    end)

    -- pcall 失敗（secret value 異常）則預設顯示
    if ok and shouldFilter then
        return false
    end

    return true
end

--[[ 光環圖示樣式化鉤子 ]]
local function PostCreateAuraIcon(_self, button)
    LunarUI.StyleAuraButton(button)

    if button.SetBackdropColor then
        button:SetBackdropColor(unpack(C.bgOverlay))
        button:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end

    button.Icon:SetDrawLayer("ARTWORK")
    button.Count:SetPoint("BOTTOMRIGHT", 2, -2)

    if button.Cooldown then
        button.Cooldown:SetDrawEdge(false)
        button.Cooldown:SetHideCountdownNumbers(true)
    end
end

--[[ 減益更新鉤子：根據類型著色邊框 ]]
local function PostUpdateDebuffIcon(_self, button, _unit, data, _position)
    if data.isHarmfulAura then
        -- WoW 12.0 中 dispelName 為隱藏值，使用通用減益顏色
        local color = UNITFRAME_DEBUFF_COLORS["none"]
        button:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    else
        button:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end
end

--[[ 光環框架共用建構 ]]
local function CreateAuraFrame(frame, unit, isDebuff)
    local unitKey = unit and unit:gsub("%d+$", "") or (isDebuff and "unknown" or "player")
    local ufDB = LunarUI.db.profile.unitframes[unitKey]

    -- 檢查是否啟用
    if isDebuff then
        if ufDB and not ufDB.showDebuffs then return end
    else
        if ufDB and not ufDB.showBuffs then return end
    end

    local sizeKey = isDebuff and "debuffSize" or "buffSize"
    local numKey = isDebuff and "maxDebuffs" or "maxBuffs"
    local defaultSize = isDebuff and 18 or 22
    local defaultNum = isDebuff and 4 or 16

    local auraSize = ufDB and ufDB[sizeKey] or defaultSize
    local auraNum = ufDB and ufDB[numKey] or defaultNum

    local auras = CreateFrame("Frame", nil, frame)
    auras.size = auraSize
    auras.spacing = isDebuff and 2 or 3
    auras.num = auraNum
    auras.FilterAura = AuraFilter
    auras.PostCreateButton = PostCreateAuraIcon

    if isDebuff then
        auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
        auras:SetSize(frame:GetWidth(), auraSize)
        auras.initialAnchor = "BOTTOMLEFT"
        auras["growth-x"] = "RIGHT"
        auras["growth-y"] = "UP"
        auras.PostUpdateButton = PostUpdateDebuffIcon
    else
        -- 增益使用預設邊框色
        auras.PostUpdateButton = function(_self, button, _unit, _data, _position)
            button:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
        end

        -- 定位依單位類型
        if unitKey == "player" then
            auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
            auras:SetSize(frame:GetWidth() > 0 and frame:GetWidth() or 220, auraSize * 2 + 3)
            auras.initialAnchor = "BOTTOMLEFT"
            auras["growth-x"] = "RIGHT"
            auras["growth-y"] = "UP"
        elseif unitKey == "target" or unitKey == "focus" then
            auras:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
            auras:SetSize(180, auraSize * 2 + 3)
            auras.initialAnchor = "TOPLEFT"
            auras["growth-x"] = "RIGHT"
            auras["growth-y"] = "DOWN"
        else
            auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
            auras:SetSize(frame:GetWidth() > 0 and frame:GetWidth() or 160, auraSize)
            auras.initialAnchor = "BOTTOMLEFT"
            auras["growth-x"] = "RIGHT"
            auras["growth-y"] = "UP"
        end
    end

    return auras
end

--[[ 增益框架 ]]
local function CreateBuffs(frame, unit)
    local buffs = CreateAuraFrame(frame, unit, false)
    if not buffs then return end
    frame.Buffs = buffs
    return buffs
end

--[[ 僅減益（用於隊伍/團隊/目標/焦點/首領） ]]
local function CreateDebuffs(frame, unit)
    local debuffs = CreateAuraFrame(frame, unit, true)
    if not debuffs then return end
    frame.Debuffs = debuffs
    return debuffs
end

--------------------------------------------------------------------------------
-- 單位專屬元素
--------------------------------------------------------------------------------

--[[ 職業資源（連擊點/聖能/符文等） ]]
local function CreateClassPower(frame)
    local db = LunarUI.db.profile.unitframes.player
    if db and db.showClassPower == false then return end

    local MAX_POINTS = 10  -- 最多 10（盜賊可到 7+，術士 5 靈魂碎片等）
    local barWidth = frame:GetWidth()
    local barHeight = 6
    local spacing = 2

    local classPower = {}
    for i = 1, MAX_POINTS do
        local bar = CreateFrame("StatusBar", nil, frame)
        bar:SetStatusBarTexture(GetStatusBarTexture())
        bar:SetHeight(barHeight)

        -- 背景
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetTexture(GetStatusBarTexture())
        bar.bg:SetVertexColor(unpack(C.bgIcon))

        classPower[i] = bar
    end

    -- 佈局更新：根據實際點數重排寬度和位置
    classPower.PostUpdate = function(element, _cur, _max, _hasMaxChanged, powerType)
        local maxVisible = 0
        for idx = 1, MAX_POINTS do
            if element[idx]:IsShown() then
                maxVisible = idx
            end
        end
        if maxVisible == 0 then return end

        local singleWidth = (barWidth - (maxVisible - 1) * spacing) / maxVisible
        for idx = 1, maxVisible do
            element[idx]:ClearAllPoints()
            element[idx]:SetSize(singleWidth, barHeight)
            if idx == 1 then
                element[idx]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
            else
                element[idx]:SetPoint("LEFT", element[idx - 1], "RIGHT", spacing, 0)
            end
        end

        -- 根據職業著色
        local colors = oUF and oUF.colors and oUF.colors.power
        if colors and powerType and colors[powerType] then
            local c = colors[powerType]
            for idx = 1, maxVisible do
                element[idx]:SetStatusBarColor(c[1] or c.r, c[2] or c.g, c[3] or c.b)
            end
        end
    end

    frame.ClassPower = classPower
    return classPower
end

--[[ 替代能量條（BOSS 戰特殊資源） ]]
local function CreateAlternativePower(frame)
    local altPower = CreateFrame("StatusBar", nil, frame)
    altPower:SetStatusBarTexture(GetStatusBarTexture())
    altPower:SetSize(frame:GetWidth(), 6)
    altPower:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    altPower:SetStatusBarColor(0.20, 0.60, 1.0)

    altPower.bg = altPower:CreateTexture(nil, "BACKGROUND")
    altPower.bg:SetAllPoints()
    altPower.bg:SetTexture(GetStatusBarTexture())
    altPower.bg:SetVertexColor(0.05, 0.05, 0.10, 0.8)

    -- 數值文字
    altPower.text = altPower:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(altPower.text, 9, "OUTLINE")
    altPower.text:SetPoint("CENTER")

    altPower.PostUpdate = function(element, _unit, cur, _min, max)
        if element.text then
            if max and max > 0 then
                element.text:SetText(math.floor(cur / max * 100 + 0.5) .. "%")
            else
                element.text:SetText("")
            end
        end
    end

    frame.AlternativePower = altPower
    return altPower
end

--[[ 治療預測條 ]]
local function CreateHealPrediction(frame, unit)
    local unitKey = unit or "player"
    unitKey = unitKey:gsub("%d+$", "")
    local ufDB = LunarUI.db.profile.unitframes[unitKey]
    if ufDB and ufDB.showHealPrediction == false then return end

    local hp = frame.Health
    if not hp then return end

    -- 自身治療預測（使用 TOPLEFT+BOTTOMRIGHT 確保正確的錨點參考）
    local healingPlayer = CreateFrame("StatusBar", nil, hp)
    healingPlayer:SetStatusBarTexture(GetStatusBarTexture())
    healingPlayer:SetStatusBarColor(0.0, 0.8, 0.0, 0.4)
    healingPlayer:SetPoint("TOPLEFT", hp, "TOPLEFT", 0, 0)
    healingPlayer:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 0, 0)
    healingPlayer:SetWidth(frame:GetWidth())

    -- 他人治療預測
    local healingOther = CreateFrame("StatusBar", nil, hp)
    healingOther:SetStatusBarTexture(GetStatusBarTexture())
    healingOther:SetStatusBarColor(0.0, 0.6, 0.0, 0.3)
    healingOther:SetPoint("TOPLEFT", hp, "TOPLEFT", 0, 0)
    healingOther:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 0, 0)
    healingOther:SetWidth(frame:GetWidth())

    -- 吸收盾
    local damageAbsorb = CreateFrame("StatusBar", nil, hp)
    damageAbsorb:SetStatusBarTexture(GetStatusBarTexture())
    damageAbsorb:SetStatusBarColor(1.0, 1.0, 1.0, 0.3)
    damageAbsorb:SetPoint("TOPLEFT", hp, "TOPLEFT", 0, 0)
    damageAbsorb:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 0, 0)
    damageAbsorb:SetWidth(frame:GetWidth())

    frame.HealthPrediction = {
        healingPlayer = healingPlayer,
        healingOther = healingOther,
        damageAbsorb = damageAbsorb,
        incomingHealOverflow = 1.05,
    }

    return frame.HealthPrediction
end

--[[ 玩家：休息指示器 ]]
local function CreateRestingIndicator(frame)
    local resting = frame.Health:CreateTexture(nil, "OVERLAY")
    resting:SetSize(16, 16)
    resting:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
    resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    resting:SetTexCoord(0.09, 0.43, 0.08, 0.42)
    frame.RestingIndicator = resting
    return resting
end

--[[ 玩家：戰鬥指示器 ]]
local function CreateCombatIndicator(frame)
    local combat = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    combat:SetSize(24, 24)
    combat:SetPoint("CENTER", frame, "TOPRIGHT", 0, 0)
    combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    combat:SetTexCoord(0.58, 0.90, 0.08, 0.41)
    frame.CombatIndicator = combat
    return combat
end

--[[ 玩家：經驗條 ]]
local function CreateExperienceBar(frame)
    local exp = CreateFrame("StatusBar", nil, frame)
    exp:SetStatusBarTexture(GetStatusBarTexture())
    exp:SetStatusBarColor(0.58, 0.0, 0.55, 1)
    exp:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    exp:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
    exp:SetHeight(4)

    exp.bg = exp:CreateTexture(nil, "BACKGROUND")
    exp.bg:SetAllPoints()
    exp.bg:SetTexture(GetStatusBarTexture())
    exp.bg:SetVertexColor(unpack(C.bgIcon))

    -- 精力條覆蓋
    exp.Rested = CreateFrame("StatusBar", nil, exp)
    exp.Rested:SetStatusBarTexture(GetStatusBarTexture())
    exp.Rested:SetStatusBarColor(0.0, 0.39, 0.88, 0.5)
    exp.Rested:SetAllPoints()

    frame.ExperienceBar = exp
    return exp
end

--[[ 目標：分類（菁英/稀有） ]]
local function CreateClassification(frame)
    local class = frame.Health:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(class, 10, "OUTLINE")
    class:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, 10)
    class:SetTextColor(1, 0.82, 0)

    frame:Tag(class, "[classification]")
    frame.Classification = class
    return class
end

--[[ 目標：等級文字 ]]
local function CreateLevelText(frame, _unit)
    local level = frame.Health:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(level, 11, "OUTLINE")
    level:SetPoint("RIGHT", frame.Name, "LEFT", -4, 0)

    frame:Tag(level, "[difficulty][level]")
    frame.LevelText = level
    return level
end

--[[ 仇恨指示器 ]]
local function CreateThreatIndicator(frame)
    local threat = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    threat:SetAllPoints()
    threat:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    threat:SetBackdropBorderColor(0, 0, 0, 0)
    threat:SetFrameLevel(frame:GetFrameLevel() + 5)

    threat.PostUpdate = function(self, _unit, status, r, g, b)
        if status and status > 0 then
            self:SetBackdropBorderColor(r, g, b, 0.8)
        else
            self:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end

    frame.ThreatIndicator = threat
    return threat
end

--[[ 距離指示器（用於隊伍/團隊） ]]
local function CreateRangeIndicator(frame)
    frame.Range = {
        insideAlpha = 1,
        outsideAlpha = 0.4,
    }
    return frame.Range
end

--[[ 隊長/助理指示器 ]]
local function CreateLeaderIndicator(frame)
    local leader = frame.Health:CreateTexture(nil, "OVERLAY")
    leader:SetSize(12, 12)
    leader:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    frame.LeaderIndicator = leader
    return leader
end

local function CreateAssistantIndicator(frame)
    local assist = frame.Health:CreateTexture(nil, "OVERLAY")
    assist:SetSize(12, 12)
    assist:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    frame.AssistantIndicator = assist
    return assist
end

--[[ 團隊角色指示器 ]]
local function CreateRaidRoleIndicator(frame)
    local role = frame.Health:CreateTexture(nil, "OVERLAY")
    role:SetSize(12, 12)
    role:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
    frame.RaidRoleIndicator = role
    return role
end

--[[ 職責指示器（坦克/治療/輸出） ]]
local function CreateGroupRoleIndicator(frame)
    local role = frame.Health:CreateTexture(nil, "OVERLAY")
    role:SetSize(14, 14)
    role:SetPoint("LEFT", frame.Health, "LEFT", 2, 0)
    frame.GroupRoleIndicator = role
    return role
end

--[[ 準備確認指示器 ]]
local function CreateReadyCheckIndicator(frame)
    local ready = frame:CreateTexture(nil, "OVERLAY")
    ready:SetSize(20, 20)
    ready:SetPoint("CENTER")
    frame.ReadyCheckIndicator = ready
    return ready
end

--[[ 召喚指示器 ]]
local function CreateSummonIndicator(frame)
    local summon = frame:CreateTexture(nil, "OVERLAY")
    summon:SetSize(24, 24)
    summon:SetPoint("CENTER")
    frame.SummonIndicator = summon
    return summon
end

--[[ 復活指示器 ]]
local function CreateResurrectIndicator(frame)
    local res = frame:CreateTexture(nil, "OVERLAY")
    res:SetSize(20, 20)
    res:SetPoint("CENTER")
    frame.ResurrectIndicator = res
    return res
end

-- 死亡指示器：使用單一全域事件框架防止記憶體洩漏
-- 使用弱引用表追蹤需要死亡狀態更新的框架
local deathIndicatorFrames = setmetatable({}, { __mode = "k" })
local deathUnitMap = {}  -- unit → frame 反向映射（O(1) 事件查詢）
local deathIndicatorEventFrame

local function UpdateDeathStateForFrame(frame)
    -- 使用 pcall 包裹並記錄除錯資訊，防止靜默失敗
    local success, err = pcall(function()
        local unit = frame.unit
        if not unit or not UnitExists(unit) then
            if frame.DeadIndicator then frame.DeadIndicator:Hide() end
            if frame.DeadOverlay then frame.DeadOverlay:Hide() end
            return
        end

        if UnitIsDead(unit) or UnitIsGhost(unit) then
            if frame.DeadIndicator then frame.DeadIndicator:Show() end
            if frame.DeadOverlay then frame.DeadOverlay:Show() end
        else
            if frame.DeadIndicator then frame.DeadIndicator:Hide() end
            if frame.DeadOverlay then frame.DeadOverlay:Hide() end
        end
    end)

    if not success and LunarUI:IsDebugMode() then
        LunarUI:Debug("UpdateDeathStateForFrame 錯誤：" .. tostring(err))
    end
end

local function RebuildDeathUnitMap()
    wipe(deathUnitMap)
    for frame in pairs(deathIndicatorFrames) do
        if frame and frame.unit then
            deathUnitMap[frame.unit] = frame
        end
    end
end

local function UpdateAllDeathStates(eventUnit)
    if not eventUnit then
        -- 全量刷新（PLAYER_ENTERING_WORLD / GROUP_ROSTER_UPDATE）
        RebuildDeathUnitMap()
        for frame in pairs(deathIndicatorFrames) do
            if frame and frame.unit then
                UpdateDeathStateForFrame(frame)
            end
        end
    else
        -- O(1) 查詢取代 O(n) 迭代
        local frame = deathUnitMap[eventUnit]
        if not frame or frame.unit ~= eventUnit then
            -- 映射表過時（新框架或單位變更），惰性重建
            RebuildDeathUnitMap()
            frame = deathUnitMap[eventUnit]
        end
        if frame then
            UpdateDeathStateForFrame(frame)
        end
    end
end

-- 建立單一全域事件框架（延遲初始化）
local function EnsureDeathIndicatorEventFrame()
    if deathIndicatorEventFrame then return end

    deathIndicatorEventFrame = CreateFrame("Frame")
    deathIndicatorEventFrame:RegisterEvent("UNIT_HEALTH")
    deathIndicatorEventFrame:RegisterEvent("UNIT_CONNECTION")
    deathIndicatorEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    deathIndicatorEventFrame:RegisterEvent("UNIT_FLAGS")
    deathIndicatorEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    deathIndicatorEventFrame:SetScript("OnEvent", function(_self, event, eventUnit)
        if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
            UpdateAllDeathStates()
        elseif eventUnit then
            UpdateAllDeathStates(eventUnit)
        end
    end)
end

local function CreateDeathIndicator(frame, _unit)
    -- 建立死亡單位的骷髏圖示
    local dead = frame:CreateTexture(nil, "OVERLAY")
    dead:SetSize(20, 20)
    dead:SetPoint("CENTER", frame.Health, "CENTER")
    dead:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    dead:Hide()
    frame.DeadIndicator = dead

    -- 建立死亡單位的灰色覆蓋
    local deadOverlay = frame.Health:CreateTexture(nil, "OVERLAY")
    deadOverlay:SetAllPoints(frame.Health)
    deadOverlay:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    deadOverlay:Hide()
    frame.DeadOverlay = deadOverlay

    -- 向全域死亡指示器系統註冊框架（弱引用）
    EnsureDeathIndicatorEventFrame()
    deathIndicatorFrames[frame] = true

    -- 初始更新
    C_Timer.After(0.2, function()
        UpdateDeathStateForFrame(frame)
    end)

    return dead
end


--------------------------------------------------------------------------------
-- 佈局函數
--------------------------------------------------------------------------------

--[[ 所有單位的共用佈局 ]]
local function Shared(frame, unit)
    frame:RegisterForClicks("AnyUp")
    frame:SetScript("OnEnter", UnitFrame_OnEnter)
    frame:SetScript("OnLeave", UnitFrame_OnLeave)

    CreateBackdrop(frame)
    CreateHealthBar(frame, unit)
    CreateNameText(frame, unit)

    return frame
end

--[[ 玩家佈局 ]]
local function PlayerLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.player
    local size = db and { width = db.width, height = db.height } or SIZES.player
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateHealthText(frame, unit)
    CreateCastbar(frame, unit)
    CreateBuffs(frame, unit)
    CreateLevelText(frame, unit)
    CreateRestingIndicator(frame)
    CreateCombatIndicator(frame)
    CreateThreatIndicator(frame)
    CreateClassPower(frame)
    CreateAlternativePower(frame)
    CreateHealPrediction(frame, unit)

    -- 經驗條（僅未滿級時）
    if _G.UnitLevel("player") < _G.GetMaxPlayerLevel() then
        CreateExperienceBar(frame)
    end

    return frame
end

--[[ 目標佈局 ]]
local function TargetLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.target
    local size = db and { width = db.width, height = db.height } or SIZES.target
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateHealthText(frame, unit)
    CreateCastbar(frame, unit)

    -- 減益：定位在框架上方（顯示所有人的 debuff）
    CreateDebuffs(frame, unit)
    if frame.Debuffs then
        frame.Debuffs:ClearAllPoints()
        frame.Debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
        local debuffSize = db and db.debuffSize or 22
        frame.Debuffs:SetSize(frame:GetWidth(), debuffSize * 2 + 3)
        frame.Debuffs.initialAnchor = "BOTTOMLEFT"  -- 與 SetPoint 一致
        frame.Debuffs["growth-x"] = "RIGHT"
        frame.Debuffs["growth-y"] = "UP"
    end

    CreateClassification(frame)
    CreateLevelText(frame, unit)
    CreateThreatIndicator(frame)
    CreateDeathIndicator(frame, unit)

    return frame
end

--[[ 焦點佈局 ]]
local function FocusLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.focus
    local size = db and { width = db.width, height = db.height } or SIZES.focus
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateHealthText(frame, unit)
    CreateCastbar(frame, unit)
    CreateDebuffs(frame, unit)

    return frame
end

--[[ 寵物佈局 ]]
local function PetLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.pet
    local size = db and { width = db.width, height = db.height } or SIZES.pet
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateThreatIndicator(frame)

    return frame
end

--[[ 目標的目標佈局 ]]
local function TargetTargetLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.targettarget
    local size = db and { width = db.width, height = db.height } or SIZES.targettarget
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)

    return frame
end

--[[ 首領佈局 ]]
local function BossLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.boss
    local size = db and { width = db.width, height = db.height } or SIZES.boss
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateHealthText(frame, unit)
    CreateCastbar(frame, unit)
    CreateDebuffs(frame, unit)

    return frame
end

--[[ 隊伍佈局 ]]
local function PartyLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.party
    local size = db and { width = db.width, height = db.height } or SIZES.party
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateHealthText(frame, unit)
    CreateDebuffs(frame, unit)
    CreateThreatIndicator(frame)
    CreateRangeIndicator(frame)
    CreateHealPrediction(frame, unit)
    CreateLeaderIndicator(frame)
    CreateGroupRoleIndicator(frame)
    CreateReadyCheckIndicator(frame)
    CreateSummonIndicator(frame)
    CreateResurrectIndicator(frame)
    CreateDeathIndicator(frame, unit)

    return frame
end

--[[ 團隊佈局 ]]
local function RaidLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.raid
    local size = db and { width = db.width, height = db.height } or SIZES.raid
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreateThreatIndicator(frame)
    CreateRangeIndicator(frame)
    CreateHealPrediction(frame, unit)
    CreateLeaderIndicator(frame)
    CreateAssistantIndicator(frame)
    CreateRaidRoleIndicator(frame)
    CreateGroupRoleIndicator(frame)
    CreateReadyCheckIndicator(frame)
    CreateSummonIndicator(frame)
    CreateResurrectIndicator(frame)

    -- 團隊減益（較小，居中顯示）
    local raidDB = LunarUI.db.profile.unitframes.raid
    if not raidDB or raidDB.showDebuffs ~= false then
        local debuffSize = raidDB and raidDB.debuffSize or 16
        local maxDebuffs = raidDB and raidDB.maxDebuffs or 2

        local debuffs = CreateFrame("Frame", nil, frame)
        debuffs:SetPoint("CENTER", frame, "CENTER", 0, 0)
        debuffs:SetSize(debuffSize * maxDebuffs + 2, debuffSize)
        debuffs.size = debuffSize
        debuffs.spacing = 2
        debuffs.num = maxDebuffs
        debuffs.initialAnchor = "CENTER"
        debuffs["growth-x"] = "RIGHT"  -- 添加水平成長方向
        debuffs.FilterAura = AuraFilter
        debuffs.PostCreateButton = PostCreateAuraIcon
        debuffs.PostUpdateButton = PostUpdateDebuffIcon
        frame.Debuffs = debuffs
    end

    CreateDeathIndicator(frame, unit)

    return frame
end

--------------------------------------------------------------------------------
-- 註冊風格
--------------------------------------------------------------------------------

oUF:RegisterStyle("LunarUI", Shared)
oUF:RegisterStyle("LunarUI_Player", PlayerLayout)
oUF:RegisterStyle("LunarUI_Target", TargetLayout)
oUF:RegisterStyle("LunarUI_Focus", FocusLayout)
oUF:RegisterStyle("LunarUI_Pet", PetLayout)
oUF:RegisterStyle("LunarUI_TargetTarget", TargetTargetLayout)
oUF:RegisterStyle("LunarUI_Boss", BossLayout)
oUF:RegisterStyle("LunarUI_Party", PartyLayout)
oUF:RegisterStyle("LunarUI_Raid", RaidLayout)

oUF:SetActiveStyle("LunarUI")

--------------------------------------------------------------------------------
-- 生成函數
--------------------------------------------------------------------------------

local spawnRetries = 0
local MAX_SPAWN_RETRIES = 15  -- 最多重試 15 次（3 秒）

-- 生成個人單位框架：player, target, focus, pet, targettarget
local function SpawnPlayerFrames(uf)
    if uf.player.enabled then
        oUF:SetActiveStyle("LunarUI_Player")
        spawnedFrames.player = oUF:Spawn("player", "LunarUI_Player")
        spawnedFrames.player:SetPoint(uf.player.point, UIParent, "CENTER", uf.player.x, uf.player.y)

        C_Timer.After(0.2, function()
            if spawnedFrames.player then
                spawnedFrames.player:Show()
                if spawnedFrames.player.UpdateAllElements then
                    spawnedFrames.player:UpdateAllElements("ForceUpdate")
                end
            end
        end)
    end

    if uf.target.enabled then
        oUF:SetActiveStyle("LunarUI_Target")
        spawnedFrames.target = oUF:Spawn("target", "LunarUI_Target")
        spawnedFrames.target:SetPoint(uf.target.point, UIParent, "CENTER", uf.target.x, uf.target.y)
    end

    if uf.focus and uf.focus.enabled then
        oUF:SetActiveStyle("LunarUI_Focus")
        spawnedFrames.focus = oUF:Spawn("focus", "LunarUI_Focus")
        spawnedFrames.focus:SetPoint(uf.focus.point or "CENTER", UIParent, "CENTER", uf.focus.x or -350, uf.focus.y or 200)
    end

    if uf.pet and uf.pet.enabled then
        oUF:SetActiveStyle("LunarUI_Pet")
        spawnedFrames.pet = oUF:Spawn("pet", "LunarUI_Pet")
        if spawnedFrames.player then
            spawnedFrames.pet:SetPoint("TOPLEFT", spawnedFrames.player, "BOTTOMLEFT", 0, -8)
        else
            spawnedFrames.pet:SetPoint("CENTER", UIParent, "CENTER", uf.pet.x or -200, uf.pet.y or -180)
        end
    end

    if uf.targettarget and uf.targettarget.enabled then
        oUF:SetActiveStyle("LunarUI_TargetTarget")
        spawnedFrames.targettarget = oUF:Spawn("targettarget", "LunarUI_TargetTarget")
        if spawnedFrames.target then
            spawnedFrames.targettarget:SetPoint("TOPRIGHT", spawnedFrames.target, "BOTTOMRIGHT", 0, -28)
        else
            spawnedFrames.targettarget:SetPoint("CENTER", UIParent, "CENTER", uf.targettarget.x or 280, uf.targettarget.y or -180)
        end
    end
end

-- 生成首領框架
local function SpawnBossFrames(uf)
    if not (uf.boss and uf.boss.enabled) then return end

    oUF:SetActiveStyle("LunarUI_Boss")
    for i = 1, 8 do
        local boss = oUF:Spawn("boss" .. i, "LunarUI_Boss" .. i)
        boss:SetPoint("RIGHT", UIParent, "RIGHT", uf.boss.x or -50, uf.boss.y or (200 - (i - 1) * 55))
        spawnedFrames["boss" .. i] = boss
    end
end

-- 生成隊伍/團隊標頭框架
local function SpawnGroupFrames(uf)
    if uf.party and uf.party.enabled then
        oUF:SetActiveStyle("LunarUI_Party")
        local partyHeader = oUF:SpawnHeader(
            "LunarUI_Party",
            nil,
            "showParty", true,
            "showPlayer", false,
            "showSolo", false,
            "yOffset", -8,
            "oUF-initialConfigFunction", ([[
                self:SetHeight(%d)
                self:SetWidth(%d)
            ]]):format(uf.party.height or 35, uf.party.width or 160)
        )
        partyHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", uf.party.x or 20, uf.party.y or -200)
        _G.RegisterStateDriver(partyHeader, "visibility", "[@raid6,exists] hide; [group:party,nogroup:raid] show; hide")
        spawnedFrames.party = partyHeader
    end

    if uf.raid and uf.raid.enabled then
        oUF:SetActiveStyle("LunarUI_Raid")
        local raidHeader = oUF:SpawnHeader(
            "LunarUI_Raid",
            nil,
            "showRaid", true,
            "showParty", false,
            "showPlayer", true,
            "showSolo", false,
            "xOffset", 4,
            "yOffset", -4,
            "groupFilter", "1,2,3,4,5,6,7,8",
            "groupBy", "GROUP",
            "groupingOrder", "1,2,3,4,5,6,7,8",
            "maxColumns", 8,
            "unitsPerColumn", 5,
            "columnSpacing", 4,
            "columnAnchorPoint", "TOP",
            "oUF-initialConfigFunction", ([[
                self:SetHeight(%d)
                self:SetWidth(%d)
            ]]):format(uf.raid.height or 30, uf.raid.width or 80)
        )
        raidHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", uf.raid.x or 20, uf.raid.y or -200)
        _G.RegisterStateDriver(raidHeader, "visibility", "[group:raid] show; hide")
        spawnedFrames.raid = raidHeader
    end
end

local function SpawnUnitFrames()
    if _G.InCombatLockdown() then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            SpawnUnitFrames()
        end)
        return
    end

    if not LunarUI.db or not LunarUI.db.profile then
        spawnRetries = spawnRetries + 1
        if spawnRetries < MAX_SPAWN_RETRIES then
            C_Timer.After(0.2, SpawnUnitFrames)
        end
        return
    end
    local uf = LunarUI.db.profile.unitframes

    RebuildAuraFilterCache()
    SpawnPlayerFrames(uf)
    SpawnBossFrames(uf)
    SpawnGroupFrames(uf)
end

-- 編輯模式退出時清除 focus（暴雪編輯模式會將玩家設為 focus 用於預覽，退出時不清除）
if _G.EditModeManagerFrame and _G.EditModeManagerFrame.ExitEditMode then
    hooksecurefunc(_G.EditModeManagerFrame, "ExitEditMode", function()
        if _G.UnitIsUnit("focus", "player") then
            _G.ClearFocus()
        end
    end)
end

-- 清理函數
local function CleanupUnitFrames()
    -- 清除死亡指示器弱引用表項目
    wipe(deathIndicatorFrames)
    wipe(deathUnitMap)
end

-- 匯出
LunarUI.SpawnUnitFrames = SpawnUnitFrames
LunarUI.spawnedFrames = spawnedFrames
LunarUI.CleanupUnitFrames = CleanupUnitFrames

-- 在 PLAYER_ENTERING_WORLD 時強制更新玩家框架
-- 確保玩家資料在更新元素前可用
LunarUI.CreateEventHandler({"PLAYER_ENTERING_WORLD"}, function(_self, _event)
    C_Timer.After(0.3, function()
        if spawnedFrames.player then
            spawnedFrames.player:Show()
            if spawnedFrames.player.UpdateAllElements then
                spawnedFrames.player:UpdateAllElements("ForceUpdate")
            end
        end
    end)
end)

LunarUI:RegisterModule("UnitFrames", {
    onEnable = SpawnUnitFrames,
    onDisable = LunarUI.CleanupUnitFrames,
    delay = 0.1,
})
