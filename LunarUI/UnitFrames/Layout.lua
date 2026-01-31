---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, redundant-value, unnecessary-if
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

local statusBarTexture = "Interface\\TargetingFrame\\UI-StatusBar"
local backdropTemplate = LunarUI.backdropTemplate

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

local function CreateBackdrop(frame)
    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetAllPoints()
    backdrop:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    backdrop:SetBackdrop(backdropTemplate)
    backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    backdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    frame.Backdrop = backdrop
    return backdrop
end

--------------------------------------------------------------------------------
-- 核心元素
--------------------------------------------------------------------------------

--[[ 生命條 ]]
local function CreateHealthBar(frame, unit)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(statusBarTexture)
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
    health.bg:SetTexture(statusBarTexture)
    health.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    health.bg.multiplier = 0.3

    -- 頻繁更新以確保動畫流暢
    health.frequentUpdates = true

    -- 更新後鉤子：確保職業顏色正確套用
    health.PostUpdate = function(self, _unit, _cur, _max)
        local ownerUnit = self.__owner and self.__owner.unit
        if not ownerUnit then return end

        -- 玩家使用職業顏色
        if UnitIsPlayer(ownerUnit) then
            local _, class = UnitClass(ownerUnit)
            if class then
                local color = RAID_CLASS_COLORS[class]
                if color then
                    self:SetStatusBarColor(color.r, color.g, color.b)
                    if self.bg then
                        self.bg:SetVertexColor(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
                    end
                    return
                end
            end
        end

        -- NPC 使用聲望顏色
        local reaction = UnitReaction(ownerUnit, "player")
        if reaction then
            local color
            if reaction >= 5 then
                color = { r = 0.2, g = 0.9, b = 0.3 }  -- 友善
            elseif reaction == 4 then
                color = { r = 0.9, g = 0.9, b = 0.2 }  -- 中立
            else
                color = { r = 0.9, g = 0.2, b = 0.2 }  -- 敵對
            end
            self:SetStatusBarColor(color.r, color.g, color.b)
            if self.bg then
                self.bg:SetVertexColor(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
            end
        end
    end

    frame.Health = health
    return health
end

--[[ 能量條 ]]
local function CreatePowerBar(frame, _unit)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetStatusBarTexture(statusBarTexture)
    power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -1)
    power:SetPoint("TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -1)
    power:SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)

    power.colorPower = true
    power.frequentUpdates = true

    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
    power.bg:SetTexture(statusBarTexture)
    power.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    power.bg.multiplier = 0.3

    frame.Power = power
    return power
end

--[[ 名稱文字 ]]
local function CreateNameText(frame, unit)
    local name = frame.Health:CreateFontString(nil, "OVERLAY")
    name:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
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
    healthText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
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
local function CreateCastbar(frame, _unit)
    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(statusBarTexture)
    castbar:SetStatusBarColor(0.4, 0.6, 0.8, 1)

    -- 位於主框架下方
    castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
    castbar:SetHeight(16)

    -- 背景
    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(statusBarTexture)
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.9)
    castbar.bg = bg

    -- 邊框
    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop(backdropTemplate)
    border:SetBackdropColor(0, 0, 0, 0)
    border:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)

    -- 法術圖示
    local icon = castbar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", castbar, "LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = icon

    -- 法術名稱
    local text = castbar:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetJustifyH("LEFT")
    castbar.Text = text

    -- 施法時間
    local time = castbar:CreateFontString(nil, "OVERLAY")
    time:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
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

--[[ 光環過濾器：根據 DB 設定過濾 ]]
local function AuraFilter(_element, unit, data)
    local unitKey = unit
    -- 標準化單位 key（boss1 → boss, party1 → party）
    if unitKey then
        unitKey = unitKey:gsub("%d+$", "")
    end
    local ufDB = LunarUI.db and LunarUI.db.profile.unitframes[unitKey]
    if not ufDB then return true end

    -- Fix 9: 合併多次 pcall 為一次，減少每個 aura 的開銷
    -- data 的欄位可能是 WoW secret value，用單一 pcall 保護所有存取
    local ok, shouldFilter = pcall(function()
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
    if BackdropTemplateMixin then
        Mixin(button, BackdropTemplateMixin)
        button:OnBackdropLoaded()
        button:SetBackdrop(backdropTemplate)
        button:SetBackdropColor(0, 0, 0, 0.5)
        button:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    end

    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Icon:SetDrawLayer("ARTWORK")

    -- 層數文字（右下角）
    button.Count:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    button.Count:SetPoint("BOTTOMRIGHT", 2, -2)

    -- 冷卻
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
        button:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    end
end

--[[ 增益框架 ]]
local function CreateBuffs(frame, unit)
    local unitKey = unit and unit:gsub("%d+$", "") or "player"
    local ufDB = LunarUI.db and LunarUI.db.profile.unitframes[unitKey]
    if ufDB and not ufDB.showBuffs then return end

    local buffSize = ufDB and ufDB.buffSize or 22
    local maxBuffs = ufDB and ufDB.maxBuffs or 16

    local buffs = CreateFrame("Frame", nil, frame)
    buffs.size = buffSize
    buffs.spacing = 3
    buffs.num = maxBuffs
    buffs.FilterAura = AuraFilter
    buffs.PostCreateButton = PostCreateAuraIcon

    -- 增益使用預設邊框色
    buffs.PostUpdateButton = function(_self, button, _unit, _data, _position)
        button:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    end

    -- 定位依單位類型
    if unitKey == "player" then
        buffs:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 4, 0)
        buffs:SetSize(180, buffSize * 2 + 3)
        buffs.initialAnchor = "BOTTOMLEFT"
        buffs["growth-x"] = "RIGHT"
        buffs["growth-y"] = "UP"
    elseif unitKey == "target" or unitKey == "focus" then
        buffs:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
        buffs:SetSize(180, buffSize * 2 + 3)
        buffs.initialAnchor = "TOPLEFT"
        buffs["growth-x"] = "RIGHT"
        buffs["growth-y"] = "DOWN"
    else
        buffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
        buffs:SetSize(frame:GetWidth() > 0 and frame:GetWidth() or 160, buffSize)
        buffs.initialAnchor = "BOTTOMLEFT"
        buffs["growth-x"] = "RIGHT"
        buffs["growth-y"] = "UP"
    end

    frame.Buffs = buffs
    return buffs
end


--[[ 僅減益（用於隊伍/團隊/目標/焦點/首領） ]]
local function CreateDebuffs(frame, unit)
    local unitKey = unit and unit:gsub("%d+$", "") or "unknown"
    local ufDB = LunarUI.db and LunarUI.db.profile.unitframes[unitKey]
    if ufDB and not ufDB.showDebuffs then return end

    local debuffSize = ufDB and ufDB.debuffSize or 18
    local maxDebuffs = ufDB and ufDB.maxDebuffs or 4

    local debuffs = CreateFrame("Frame", nil, frame)
    debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    debuffs:SetSize(frame:GetWidth(), debuffSize)

    debuffs.size = debuffSize
    debuffs.spacing = 2
    debuffs.num = maxDebuffs
    debuffs.initialAnchor = "BOTTOMLEFT"
    debuffs["growth-x"] = "RIGHT"
    debuffs["growth-y"] = "UP"

    debuffs.FilterAura = AuraFilter
    debuffs.PostCreateButton = PostCreateAuraIcon
    debuffs.PostUpdateButton = PostUpdateDebuffIcon

    frame.Debuffs = debuffs
    return debuffs
end

--------------------------------------------------------------------------------
-- 單位專屬元素
--------------------------------------------------------------------------------

--[[ 職業資源（連擊點/聖能/符文等） ]]
local function CreateClassPower(frame)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.player
    if db and db.showClassPower == false then return end

    local MAX_POINTS = 10  -- 最多 10（盜賊可到 7+，術士 5 靈魂碎片等）
    local barWidth = frame:GetWidth()
    local barHeight = 6
    local spacing = 2

    local classPower = {}
    for i = 1, MAX_POINTS do
        local bar = CreateFrame("StatusBar", nil, frame)
        bar:SetStatusBarTexture(statusBarTexture)
        bar:SetHeight(barHeight)

        -- 背景
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetTexture(statusBarTexture)
        bar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

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
        local colors = oUF.colors.power
        if powerType and colors[powerType] then
            local c = colors[powerType]
            for idx = 1, maxVisible do
                element[idx]:SetStatusBarColor(c[1] or c.r, c[2] or c.g, c[3] or c.b)
            end
        end
    end

    frame.ClassPower = classPower
    return classPower
end

--[[ 治療預測條 ]]
local function CreateHealPrediction(frame, unit)
    local unitKey = unit or "player"
    unitKey = unitKey:gsub("%d+$", "")
    local ufDB = LunarUI.db and LunarUI.db.profile.unitframes[unitKey]
    if ufDB and ufDB.showHealPrediction == false then return end

    local hp = frame.Health
    if not hp then return end

    -- 自身治療預測
    local healingPlayer = CreateFrame("StatusBar", nil, hp)
    healingPlayer:SetStatusBarTexture(statusBarTexture)
    healingPlayer:SetStatusBarColor(0.0, 0.8, 0.0, 0.4)
    healingPlayer:SetPoint("TOP")
    healingPlayer:SetPoint("BOTTOM")
    healingPlayer:SetWidth(frame:GetWidth())

    -- 他人治療預測
    local healingOther = CreateFrame("StatusBar", nil, hp)
    healingOther:SetStatusBarTexture(statusBarTexture)
    healingOther:SetStatusBarColor(0.0, 0.6, 0.0, 0.3)
    healingOther:SetPoint("TOP")
    healingOther:SetPoint("BOTTOM")
    healingOther:SetWidth(frame:GetWidth())

    -- 吸收盾
    local damageAbsorb = CreateFrame("StatusBar", nil, hp)
    damageAbsorb:SetStatusBarTexture(statusBarTexture)
    damageAbsorb:SetStatusBarColor(1.0, 1.0, 1.0, 0.3)
    damageAbsorb:SetPoint("TOP")
    damageAbsorb:SetPoint("BOTTOM")
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
    local combat = frame.Health:CreateTexture(nil, "OVERLAY")
    combat:SetSize(16, 16)
    combat:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 8, 8)
    combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    combat:SetTexCoord(0.58, 0.90, 0.08, 0.41)
    frame.CombatIndicator = combat
    return combat
end

--[[ 玩家：經驗條 ]]
local function CreateExperienceBar(frame)
    local exp = CreateFrame("StatusBar", nil, frame)
    exp:SetStatusBarTexture(statusBarTexture)
    exp:SetStatusBarColor(0.58, 0.0, 0.55, 1)
    exp:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    exp:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
    exp:SetHeight(4)

    exp.bg = exp:CreateTexture(nil, "BACKGROUND")
    exp.bg:SetAllPoints()
    exp.bg:SetTexture(statusBarTexture)
    exp.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- 精力條覆蓋
    exp.Rested = CreateFrame("StatusBar", nil, exp)
    exp.Rested:SetStatusBarTexture(statusBarTexture)
    exp.Rested:SetStatusBarColor(0.0, 0.39, 0.88, 0.5)
    exp.Rested:SetAllPoints()

    frame.ExperienceBar = exp
    return exp
end

--[[ 目標：分類（菁英/稀有） ]]
local function CreateClassification(frame)
    local class = frame.Health:CreateFontString(nil, "OVERLAY")
    class:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    class:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, 10)
    class:SetTextColor(1, 0.82, 0)

    frame:Tag(class, "[classification]")
    frame.Classification = class
    return class
end

--[[ 目標：等級文字 ]]
local function CreateLevelText(frame, _unit)
    local level = frame.Health:CreateFontString(nil, "OVERLAY")
    level:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
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

local function UpdateAllDeathStates(eventUnit)
    for frame in pairs(deathIndicatorFrames) do
        if frame and frame.unit then
            if not eventUnit or eventUnit == frame.unit then
                UpdateDeathStateForFrame(frame)
            end
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
    deathIndicatorEventFrame:SetScript("OnEvent", function(_self, event, eventUnit, ...)
        if event == "PLAYER_ENTERING_WORLD" then
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
-- 月相感知
--------------------------------------------------------------------------------

-- 全域月相回呼註冊（僅一次）
local phaseCallbackRegistered = false

-- 針對大型團隊優化的月相回呼：使用批次更新
-- 使用儲存的計時器以正確取消，防止計時器累積
local updateQueue = {}
local isUpdating = false
local updateBatchTimer = nil
local batchFramePool = nil  -- 重用單一框架，避免每批次創建新框架

-- 取消批次更新計時器（支援 C_Timer 和 OnUpdate 兩種機制）
local function CancelBatchTimer()
    if not updateBatchTimer then return end
    if updateBatchTimer.Cancel then
        updateBatchTimer:Cancel()
    elseif updateBatchTimer.SetScript then
        updateBatchTimer:SetScript("OnUpdate", nil)
    end
    updateBatchTimer = nil
end

local function ProcessUpdateBatch()
    updateBatchTimer = nil  -- 清除計時器引用

    -- 使用 pcall 包裹整個批次處理，確保錯誤時重設 isUpdating
    local success, err = pcall(function()
        if #updateQueue == 0 then
            isUpdating = false
            return
        end

        local tokens = LunarUI:GetTokens()
        if not tokens then
            isUpdating = false
            wipe(updateQueue)
            return
        end

        -- 每批次處理最多 10 個框架
        local batchSize = 10
        for _i = 1, batchSize do
            local frame = table.remove(updateQueue, 1)
            if frame and frame.IsShown and frame:IsShown() then
                -- 使用 pcall 包裹個別框架更新，防止單一壞框架阻止所有更新
                pcall(function()
                    if tokens.alpha and type(tokens.alpha) == "number" then
                        frame:SetAlpha(tokens.alpha)
                    end
                    if tokens.scale and type(tokens.scale) == "number" then
                        frame:SetScale(tokens.scale)
                    end
                end)
            end
            if #updateQueue == 0 then
                isUpdating = false
                return
            end
        end

        -- 使用 OnUpdate 延遲到下一幀繼續處理（重用同一框架避免洩漏）
        if not updateBatchTimer then
            if not batchFramePool then
                batchFramePool = CreateFrame("Frame")
            end
            batchFramePool:SetScript("OnUpdate", function(self)
                self:SetScript("OnUpdate", nil)
                updateBatchTimer = nil
                ProcessUpdateBatch()
            end)
            updateBatchTimer = batchFramePool
        end
    end)

    -- 確保即使發生錯誤也重設 isUpdating
    if not success then
        isUpdating = false
        wipe(updateQueue)
        if LunarUI:IsDebugMode() then
            LunarUI:Debug("ProcessUpdateBatch 錯誤：" .. tostring(err))
        end
    end
end

local function UpdateAllFramesForPhase()
    -- 開始新更新前取消任何現有的批次框架
    CancelBatchTimer()

    -- 收集所有需要更新的框架
    wipe(updateQueue)

    for _name, frame in pairs(spawnedFrames) do
        if frame and frame.IsShown and frame:IsShown() then
            table.insert(updateQueue, frame)
        end
    end

    -- 同時收集標頭子框架（隊伍/團隊）
    for _, headerName in ipairs({"party", "raid"}) do
        local header = spawnedFrames[headerName]
        if header then
            for i = 1, 40 do
                local child = header:GetAttribute("child" .. i)
                if child and child.IsShown and child:IsShown() then
                    table.insert(updateQueue, child)
                end
            end
        end
    end

    -- 若未在執行中則開始批次處理
    if not isUpdating and #updateQueue > 0 then
        isUpdating = true
        ProcessUpdateBatch()
    end
end

local function RegisterGlobalPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(_oldPhase, _newPhase)
        UpdateAllFramesForPhase()
    end)
end

local function ApplyPhaseAwareness(frame)
    -- 若尚未完成則註冊全域回呼
    RegisterGlobalPhaseCallback()

    -- 套用初始標記
    local tokens = LunarUI:GetTokens()
    frame:SetAlpha(tokens.alpha)
    frame:SetScale(tokens.scale)
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

    ApplyPhaseAwareness(frame)

    return frame
end

--[[ 玩家佈局 ]]
local function PlayerLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.player
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
    CreateHealPrediction(frame, unit)

    -- 經驗條（僅未滿級時）
    if UnitLevel("player") < GetMaxPlayerLevel() then
        CreateExperienceBar(frame)
    end

    return frame
end

--[[ 目標佈局 ]]
local function TargetLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.target
    local size = db and { width = db.width, height = db.height } or SIZES.target
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateHealthText(frame, unit)
    CreateCastbar(frame, unit)

    -- 減益：定位在框架上方
    CreateDebuffs(frame, unit)
    if frame.Debuffs then
        frame.Debuffs:ClearAllPoints()
        frame.Debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
        local debuffSize = db and db.debuffSize or 22
        frame.Debuffs:SetSize(frame:GetWidth(), debuffSize * 2 + 3)
        frame.Debuffs["growth-y"] = "UP"
    end

    -- 增益：定位在框架右側
    CreateBuffs(frame, unit)

    CreateClassification(frame)
    CreateLevelText(frame, unit)
    CreateThreatIndicator(frame)
    CreateDeathIndicator(frame, unit)

    return frame
end

--[[ 焦點佈局 ]]
local function FocusLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.focus
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
    local db = LunarUI.db and LunarUI.db.profile.unitframes.pet
    local size = db and { width = db.width, height = db.height } or SIZES.pet
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateThreatIndicator(frame)

    return frame
end

--[[ 目標的目標佈局 ]]
local function TargetTargetLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.targettarget
    local size = db and { width = db.width, height = db.height } or SIZES.targettarget
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)

    return frame
end

--[[ 首領佈局 ]]
local function BossLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.boss
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
    local db = LunarUI.db and LunarUI.db.profile.unitframes.party
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
    local db = LunarUI.db and LunarUI.db.profile.unitframes.raid
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
    local raidDB = LunarUI.db and LunarUI.db.profile.unitframes.raid
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

local function SpawnUnitFrames()
    -- 使用事件驅動重試取代固定計時器（處理戰鬥鎖定）
    if InCombatLockdown() then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            SpawnUnitFrames()
        end)
        return
    end

    if not LunarUI.db then return end
    local uf = LunarUI.db.profile.unitframes

    -- 玩家
    if uf.player.enabled then
        oUF:SetActiveStyle("LunarUI_Player")
        spawnedFrames.player = oUF:Spawn("player", "LunarUI_Player")
        spawnedFrames.player:SetPoint(uf.player.point, UIParent, "CENTER", uf.player.x, uf.player.y)

        -- 生成後強制更新玩家框架以確保元素可見
        -- 玩家單位立即存在，但元素可能在 PLAYER_ENTERING_WORLD 前不會更新
        C_Timer.After(0.2, function()
            if spawnedFrames.player then
                spawnedFrames.player:Show()
                if spawnedFrames.player.UpdateAllElements then
                    spawnedFrames.player:UpdateAllElements("ForceUpdate")
                end
            end
        end)
    end

    -- 目標
    if uf.target.enabled then
        oUF:SetActiveStyle("LunarUI_Target")
        spawnedFrames.target = oUF:Spawn("target", "LunarUI_Target")
        spawnedFrames.target:SetPoint(uf.target.point, UIParent, "CENTER", uf.target.x, uf.target.y)
    end

    -- 焦點
    if uf.focus and uf.focus.enabled then
        oUF:SetActiveStyle("LunarUI_Focus")
        spawnedFrames.focus = oUF:Spawn("focus", "LunarUI_Focus")
        spawnedFrames.focus:SetPoint(uf.focus.point or "CENTER", UIParent, "CENTER", uf.focus.x or -350, uf.focus.y or 200)
    end

    -- 寵物
    if uf.pet and uf.pet.enabled then
        oUF:SetActiveStyle("LunarUI_Pet")
        spawnedFrames.pet = oUF:Spawn("pet", "LunarUI_Pet")
        if spawnedFrames.player then
            spawnedFrames.pet:SetPoint("TOPLEFT", spawnedFrames.player, "BOTTOMLEFT", 0, -8)
        else
            spawnedFrames.pet:SetPoint("CENTER", UIParent, "CENTER", uf.pet.x or -200, uf.pet.y or -180)
        end
    end

    -- 目標的目標
    -- 定位在施法條下方避免重疊（施法條高 16px，偏移 -4）
    if uf.targettarget and uf.targettarget.enabled then
        oUF:SetActiveStyle("LunarUI_TargetTarget")
        spawnedFrames.targettarget = oUF:Spawn("targettarget", "LunarUI_TargetTarget")
        if spawnedFrames.target then
            spawnedFrames.targettarget:SetPoint("TOPRIGHT", spawnedFrames.target, "BOTTOMRIGHT", 0, -28)
        else
            spawnedFrames.targettarget:SetPoint("CENTER", UIParent, "CENTER", uf.targettarget.x or 280, uf.targettarget.y or -180)
        end
    end

    -- 首領框架
    if uf.boss and uf.boss.enabled then
        oUF:SetActiveStyle("LunarUI_Boss")
        for i = 1, 8 do
            local boss = oUF:Spawn("boss" .. i, "LunarUI_Boss" .. i)
            boss:SetPoint("RIGHT", UIParent, "RIGHT", uf.boss.x or -50, uf.boss.y or (200 - (i - 1) * 55))
            spawnedFrames["boss" .. i] = boss
        end
    end

    -- 隊伍標頭（含可見性驅動器）
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
        if partyHeader then
            partyHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", uf.party.x or 20, uf.party.y or -200)
            -- 可見性驅動器：團隊中隱藏，隊伍中顯示
            RegisterStateDriver(partyHeader, "visibility", "[@raid6,exists] hide; [group:party,nogroup:raid] show; hide")
            spawnedFrames.party = partyHeader
        end
    end

    -- 團隊標頭（含可見性驅動器）
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
        if raidHeader then
            raidHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", uf.raid.x or 20, uf.raid.y or -200)
            -- 可見性驅動器：團隊中顯示團隊框架
            RegisterStateDriver(raidHeader, "visibility", "[group:raid] show; hide")
            spawnedFrames.raid = raidHeader
        end
    end
end

-- 清理函數：處理 updateQueue 和計時器
-- 死亡指示器框架現在透過弱引用表追蹤，由 GC 自動清理
local function CleanupUnitFrames()
    -- 取消待處理的批次更新框架
    CancelBatchTimer()

    -- 清除更新佇列
    wipe(updateQueue)
    isUpdating = false

    -- 清除死亡指示器弱引用表項目
    wipe(deathIndicatorFrames)
end

-- 匯出
LunarUI.SpawnUnitFrames = SpawnUnitFrames
LunarUI.spawnedFrames = spawnedFrames
LunarUI.CleanupUnitFrames = CleanupUnitFrames

-- 在 PLAYER_ENTERING_WORLD 時強制更新玩家框架
-- 確保玩家資料在更新元素前可用
local playerUpdateFrame = CreateFrame("Frame")
playerUpdateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
playerUpdateFrame:SetScript("OnEvent", function(_self, _event)
    C_Timer.After(0.3, function()
        if spawnedFrames.player then
            spawnedFrames.player:Show()
            if spawnedFrames.player.UpdateAllElements then
                spawnedFrames.player:UpdateAllElements("ForceUpdate")
            end
        end
    end)
end)

-- 確保飛行活力條保持可見
-- 活力條是 UI 元件，使用自訂單位框架時可能被隱藏
-- 僅調整 parent/strata，不呼叫 Show()（當 barInfo 為 nil 時會導致錯誤）
local function EnsureVigorBarVisible()
    -- 戰鬥中不修改框架以避免 taint
    if InCombatLockdown() then return end

    -- PlayerPowerBarAlt 是獨立的替代能量條（飛行活力）
    -- 僅在被移至隱藏父框架時重新設定父框架
    if PlayerPowerBarAlt then
        pcall(function()
            local parent = PlayerPowerBarAlt:GetParent()
            if parent and parent ~= UIParent and not parent:IsShown() then
                PlayerPowerBarAlt:SetParent(UIParent)
            end
            if PlayerPowerBarAlt:GetAlpha() < 1 then
                PlayerPowerBarAlt:SetAlpha(1)
            end
            PlayerPowerBarAlt:SetFrameStrata("HIGH")
        end)
    end

    -- UIWidgetPowerBarContainerFrame 是飛行活力條容器（WoW 12.0）
    if UIWidgetPowerBarContainerFrame then
        pcall(function()
            local parent = UIWidgetPowerBarContainerFrame:GetParent()
            if parent and parent ~= UIParent and not parent:IsShown() then
                UIWidgetPowerBarContainerFrame:SetParent(UIParent)
            end
            UIWidgetPowerBarContainerFrame:SetFrameStrata("HIGH")
            UIWidgetPowerBarContainerFrame:SetAlpha(1)
        end)
    end

    -- UIWidgetBelowMinimapContainerFrame 也可能包含活力條
    if UIWidgetBelowMinimapContainerFrame then
        pcall(function() UIWidgetBelowMinimapContainerFrame:SetAlpha(1) end)
    end

    -- UIWidgetTopCenterContainerFrame 可能包含活力條
    if UIWidgetTopCenterContainerFrame then
        pcall(function() UIWidgetTopCenterContainerFrame:SetAlpha(1) end)
    end

    -- UIWidgetCenterScreenContainerFrame - 中央螢幕元件
    if UIWidgetCenterScreenContainerFrame then
        pcall(function()
            local parent = UIWidgetCenterScreenContainerFrame:GetParent()
            if parent and parent ~= UIParent and not parent:IsShown() then
                UIWidgetCenterScreenContainerFrame:SetParent(UIParent)
            end
            UIWidgetCenterScreenContainerFrame:SetFrameStrata("HIGH")
            UIWidgetCenterScreenContainerFrame:SetAlpha(1)
        end)
    end
end

-- 註冊可能觸發活力條變更的事件
local vigorFrame = CreateFrame("Frame")
vigorFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
vigorFrame:RegisterEvent("UPDATE_UI_WIDGET")
vigorFrame:RegisterEvent("UNIT_POWER_BAR_SHOW")
vigorFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
vigorFrame:SetScript("OnEvent", function(_self, _event)
    C_Timer.After(0.5, EnsureVigorBarVisible)
end)

-- 初始載入時也執行
C_Timer.After(1, EnsureVigorBarVisible)

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.1, SpawnUnitFrames)
end)
