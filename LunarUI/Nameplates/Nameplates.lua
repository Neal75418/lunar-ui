---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Nameplates
    oUF-based nameplate system with Phase awareness

    Features:
    - Enemy nameplates with health, castbar, debuffs
    - Friendly nameplates (simplified)
    - Phase-aware alpha (faded in NEW phase)
    - Important target highlighting (rare, elite, boss)
    - Performance optimized for large pulls
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors

-- Wait for oUF
-- oUF is exposed as LunarUF via X-oUF TOC header
local oUF = Engine.oUF or _G.LunarUF or _G.oUF
if not oUF then
    return
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local statusBarTexture  -- lazy: resolved after DB is ready
local function GetStatusBarTexture()
    if not statusBarTexture then
        statusBarTexture = LunarUI.GetSelectedStatusBarTexture()
    end
    return statusBarTexture
end
local backdropTemplate = LunarUI.backdropTemplate

-- Classification colors
local CLASSIFICATION_COLORS = {
    worldboss = { r = 1.0, g = 0.2, b = 0.2 },
    rareelite = { r = 1.0, g = 0.5, b = 0.0 },
    elite = { r = 1.0, g = 0.8, b = 0.0 },
    rare = { r = 0.7, g = 0.7, b = 1.0 },
    normal = { r = 0.5, g = 0.5, b = 0.5 },
    trivial = { r = 0.3, g = 0.3, b = 0.3 },
}

local DEBUFF_TYPE_COLORS = LunarUI.DEBUFF_TYPE_COLORS

-- 私有事件框架（不暴露到 LunarUI 物件）
local nameplateTargetFrame
local nameplateQuestFrame

-- 前向宣告：堆疊偵測髒旗標函數
local MarkStackingDirty

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function CreateBackdrop(frame)
    return LunarUI.CreateBackdrop(frame, { inset = 1, borderColor = C.borderSubtle })
end

local function GetUnitClassification(unit)
    local classification = UnitClassification(unit)
    return classification or "normal"
end

local function IsImportantTarget(unit)
    local classification = GetUnitClassification(unit)
    return classification == "worldboss" or
           classification == "rareelite" or
           classification == "elite" or
           classification == "rare"
end

--------------------------------------------------------------------------------
-- Nameplate Elements
--------------------------------------------------------------------------------

--[[ Health Bar ]]
local function CreateHealthBar(frame)
    local db = LunarUI.db and LunarUI.db.profile.nameplates

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(GetStatusBarTexture())
    health:SetAllPoints()

    -- Reaction colors (hostile/friendly)
    health.colorReaction = true
    health.colorTapping = true
    health.colorDisconnected = true

    -- Background
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    health.bg:SetTexture(GetStatusBarTexture())
    health.bg:SetVertexColor(unpack(C.bgIcon))
    health.bg.multiplier = 0.3

    -- Frequent updates
    health.frequentUpdates = true

    -- Health text overlay
    if db and db.showHealthText then
        local healthText = health:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(healthText, 8, "OUTLINE")
        healthText:SetPoint("CENTER", health, "CENTER", 0, 0)
        frame.HealthText = healthText

        local fmt = db.healthTextFormat or "percent"
        health.PostUpdate = function(_bar, _unit, cur, max)
            if not healthText then return end
            -- WoW secret value: type()=="number", tonumber() 原樣回傳, 但算術會報錯
            -- 唯一可靠的偵測方式是嘗試算術並 pcall
            -- 額外檢查類型以提早過濾非數字值
            if type(cur) ~= "number" or type(max) ~= "number" then
                healthText:SetText("")
                return
            end
            local ok, pct = pcall(function()
                if not cur or not max or max == 0 then return nil end
                return math.floor(cur / max * 100)
            end)
            if not ok or not pct then
                healthText:SetText("")
                return
            end
            if fmt == "percent" then
                healthText:SetText(pct .. "%")
            elseif fmt == "current" then
                -- cur 已通過 pcall 驗證，可安全使用
                if cur >= 1e6 then
                    healthText:SetText(string.format("%.1fM", cur / 1e6))
                elseif cur >= 1e3 then
                    healthText:SetText(string.format("%.1fK", cur / 1e3))
                else
                    healthText:SetText(tostring(cur))
                end
            elseif fmt == "both" then
                if cur >= 1e6 then
                    healthText:SetText(string.format("%.1fM - %d%%", cur / 1e6, pct))
                elseif cur >= 1e3 then
                    healthText:SetText(string.format("%.1fK - %d%%", cur / 1e3, pct))
                else
                    healthText:SetText(string.format("%d - %d%%", cur, pct))
                end
            end
        end
    end

    frame.Health = health
    return health
end

--[[ Name Text ]]
local function CreateNameText(frame)
    local name = frame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(name, 9, "OUTLINE")
    name:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    name:SetJustifyH("CENTER")
    name:SetWidth(frame:GetWidth() * 1.5)

    -- Fix #47: Use standard oUF tag instead of undefined [name:abbrev]
    frame:Tag(name, "[name]")
    frame.Name = name
    return name
end

--[[ Level Text ]]
local function CreateLevelText(frame)
    local level = frame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(level, 8, "OUTLINE")
    level:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", -2, 2)
    level:SetJustifyH("RIGHT")

    frame:Tag(level, "[difficulty][level]")
    frame.LevelText = level
    return level
end

--[[ Castbar ]]
local function CreateCastbar(frame)
    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(GetStatusBarTexture())
    castbar:SetStatusBarColor(0.4, 0.6, 0.8, 1)
    castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -3)
    castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -3)
    castbar:SetHeight(6)

    -- Background
    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(GetStatusBarTexture())
    bg:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    castbar.bg = bg

    -- Border
    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop(backdropTemplate)
    border:SetBackdropColor(0, 0, 0, 0)
    border:SetBackdropBorderColor(C.borderSubtle[1], C.borderSubtle[2], C.borderSubtle[3], C.borderSubtle[4])

    -- Icon
    local icon = castbar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(6, 6)
    icon:SetPoint("RIGHT", castbar, "LEFT", -2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = icon

    -- Text
    local text = castbar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(text, 7, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    castbar.Text = text

    -- Interruptible color change
    -- Fix #69: WoW 12.0 makes notInterruptible a secret value
    castbar.PostCastStart = function(self, _unit)
        -- Use pcall to safely check notInterruptible
        local success, isNotInterruptible = pcall(function() return self.notInterruptible == true end)
        if success and isNotInterruptible then
            self:SetStatusBarColor(0.7, 0.3, 0.3, 1)  -- Red for uninterruptible
        else
            self:SetStatusBarColor(0.4, 0.6, 0.8, 1)  -- Blue for interruptible
        end
    end
    castbar.PostChannelStart = castbar.PostCastStart

    -- Spark
    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(10, 10)
    spark:SetBlendMode("ADD")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    castbar.Spark = spark

    frame.Castbar = castbar
    return castbar
end

--[[ Debuffs ]]
local function CreateDebuffs(frame)
    local debuffs = CreateFrame("Frame", nil, frame)
    debuffs:SetPoint("BOTTOM", frame, "TOP", 0, 14)
    debuffs:SetSize(frame:GetWidth(), 18)

    debuffs.size = 16
    debuffs.spacing = 2
    debuffs.num = 5
    debuffs.initialAnchor = "CENTER"
    debuffs["growth-x"] = "RIGHT"
    debuffs["growth-y"] = "UP"

    -- Only show player's debuffs
    debuffs.onlyShowPlayer = true

    -- Fix #53: WoW 12.0 makes isHarmful a secret value that cannot be tested
    -- The Debuffs element already filters to harmful auras, so just check isPlayerAura
    -- Use isHarmfulAura as fallback if available (non-secret in some cases)
    debuffs.FilterAura = function(_element, _unit, data)
        -- Just check if it's the player's aura - Debuffs element handles harmful filtering
        return data.isPlayerAura == true
    end

    -- Post-create styling
    debuffs.PostCreateButton = function(_self, button)
        LunarUI.StyleAuraButton(button)
        LunarUI.SetFont(button.Count, 8, "OUTLINE")
        button.Count:SetPoint("BOTTOMRIGHT", 2, -2)
        if button.SetBackdropColor then
            button:SetBackdropColor(unpack(C.bgOverlay))
        end
    end

    -- Post-update for debuff type colors
    -- Fix #50 + Fix #57: WoW 12.0 makes dispelName a secret value
    -- Use generic debuff color since we can't access dispel type
    debuffs.PostUpdateButton = function(_self, button, _unit, _data, _position)
        if button.SetBackdropBorderColor then
            local color = DEBUFF_TYPE_COLORS["none"]
            button:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        end
    end

    frame.Debuffs = debuffs
    return debuffs
end

--[[ Buffs (enemy nameplates — stealable/important buffs) ]]
local function CreateNameplateBuffs(frame)
    local db = LunarUI.db and LunarUI.db.profile.nameplates
    local enemyDb = db and db.enemy
    local buffSize = enemyDb and enemyDb.buffSize or 14
    local maxBuffs = enemyDb and enemyDb.maxBuffs or 4

    local buffs = CreateFrame("Frame", nil, frame)
    -- Position above debuffs if they exist, otherwise above health
    if frame.Debuffs then
        buffs:SetPoint("BOTTOM", frame.Debuffs, "TOP", 0, 2)
    else
        buffs:SetPoint("BOTTOM", frame, "TOP", 0, 14)
    end
    buffs:SetSize(frame:GetWidth(), buffSize + 2)

    buffs.size = buffSize
    buffs.spacing = 2
    buffs.num = maxBuffs
    buffs.initialAnchor = "CENTER"
    buffs["growth-x"] = "RIGHT"
    buffs["growth-y"] = "UP"

    -- Filter: only show stealable/purgeable buffs on enemies
    buffs.FilterAura = function(_element, _unit, data)
        return data.isStealable == true
    end

    -- Post-create styling (shared with debuffs)
    buffs.PostCreateButton = function(_self, button)
        LunarUI.StyleAuraButton(button)
        LunarUI.SetFont(button.Count, 8, "OUTLINE")
        button.Count:SetPoint("BOTTOMRIGHT", 2, -2)
        if button.SetBackdropColor then
            button:SetBackdropColor(unpack(C.bgOverlay))
        end
    end

    -- Stealable buffs get a bright border
    buffs.PostUpdateButton = function(_self, button, _unit, _data, _position)
        if button.SetBackdropBorderColor then
            button:SetBackdropBorderColor(unpack(C.stealableBorder))
        end
    end

    frame.Buffs = buffs
    return buffs
end

--[[ Threat Indicator ]]
local function CreateThreatIndicator(frame)
    local threat = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    threat:SetPoint("TOPLEFT", -2, 2)
    threat:SetPoint("BOTTOMRIGHT", 2, -2)
    threat:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    threat:SetBackdropBorderColor(0, 0, 0, 0)
    threat:SetFrameLevel(frame:GetFrameLevel() + 5)

    threat.PostUpdate = function(self, _unit, status, r, g, b)
        if not self then return end
        if status and status > 0 and r and g and b then
            self:SetBackdropBorderColor(r, g, b, 0.8)
        else
            self:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end

    frame.ThreatIndicator = threat
    return threat
end

--[[ Classification Icon ]]
local function CreateClassificationIndicator(frame)
    local class = frame:CreateTexture(nil, "OVERLAY")
    class:SetSize(14, 14)
    class:SetPoint("LEFT", frame, "RIGHT", 2, 0)
    frame.ClassificationIndicator = class
    return class
end

--[[ Classification Glow (elite/rare/boss subtle outer glow) ]]
local function CreateClassificationGlow(frame)
    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    glow:SetTexture(LunarUI.textures.glow)
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", -8, 8)
    glow:SetPoint("BOTTOMRIGHT", 8, -8)
    glow:SetAlpha(0)
    glow:Hide()
    frame.ClassificationGlow = glow
    return glow
end

--[[ Raid Target Icon ]]
local function CreateRaidTargetIndicator(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    frame.RaidTargetIndicator = icon
    return icon
end

--[[ Quest Icon Indicator ]]
local function CreateQuestIndicator(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", frame, "RIGHT", 18, 0)
    icon:SetTexture("Interface\\TARGETINGFRAME\\PortraitQuestBadge")
    icon:Hide()
    frame.QuestIndicator = icon
    return icon
end

--[[ Target Highlight ]]
local function CreateTargetIndicator(frame)
    local highlight = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    highlight:SetPoint("TOPLEFT", -3, 3)
    highlight:SetPoint("BOTTOMRIGHT", 3, -3)
    highlight:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    highlight:SetBackdropBorderColor(1, 1, 1, 0)
    highlight:SetFrameLevel(frame:GetFrameLevel() + 6)
    highlight:Hide()

    frame.TargetIndicator = highlight
    return highlight
end

-- Weak table for nameplate frame tracking (stacking detection, etc.)
local nameplateFrames = setmetatable({}, { __mode = "v" })

--------------------------------------------------------------------------------
-- Layout Functions
--------------------------------------------------------------------------------

--[[ Enemy Nameplate Layout ]]
local function EnemyNameplateLayout(frame, _unit)
    local db = LunarUI.db and LunarUI.db.profile.nameplates
    local width = db and db.width or 120
    local height = db and db.height or 12

    frame:SetSize(width, height)

    CreateBackdrop(frame)
    CreateHealthBar(frame)
    CreateNameText(frame)

    if db and db.enemy then
        if db.enemy.showCastbar then
            CreateCastbar(frame)
        end
        if db.enemy.showAuras then
            CreateDebuffs(frame)
        end
        if db.enemy.showBuffs then
            CreateNameplateBuffs(frame)
        end
        if db.enemy.showLevel then
            CreateLevelText(frame)
        end
    else
        CreateCastbar(frame)
        CreateDebuffs(frame)
        CreateLevelText(frame)
    end

    CreateThreatIndicator(frame)
    CreateClassificationIndicator(frame)
    CreateClassificationGlow(frame)
    CreateRaidTargetIndicator(frame)
    CreateTargetIndicator(frame)

    -- 任務目標高亮
    if db and db.enemy and db.enemy.showQuestIcon then
        CreateQuestIndicator(frame)
    end

    return frame
end

--[[ Friendly Nameplate Layout ]]
local function FriendlyNameplateLayout(frame, _unit)
    local db = LunarUI.db and LunarUI.db.profile.nameplates
    local width = db and db.width or 120
    local height = (db and db.height or 12) * 0.8  -- Slightly smaller

    frame:SetSize(width, height)

    CreateBackdrop(frame)
    CreateHealthBar(frame)
    CreateNameText(frame)

    if db and db.friendly and db.friendly.showCastbar then
        CreateCastbar(frame)
    end
    if db and db.friendly and db.friendly.showLevel then
        CreateLevelText(frame)
    end

    CreateRaidTargetIndicator(frame)
    CreateTargetIndicator(frame)

    return frame
end

--[[ Shared Nameplate Layout (for callback) ]]
local function NameplateLayout(frame, unit)
    -- Determine if enemy or friendly
    local reaction = UnitReaction(unit, "player")

    -- Fix #22: nil or hostile (1-4) uses enemy layout
    -- Reaction: 1-3 = hostile, 4 = neutral, 5-8 = friendly
    -- Default to enemy if reaction is nil (safer assumption)
    if not reaction or reaction <= 4 then
        return EnemyNameplateLayout(frame, unit)
    else
        return FriendlyNameplateLayout(frame, unit)
    end
end

--------------------------------------------------------------------------------
-- Nameplate Callbacks
--------------------------------------------------------------------------------

--[[ Update quest indicator ]]
local function UpdateQuestIndicator(frame)
    if not frame or not frame.QuestIndicator or not frame.unit then return end
    local isQuest = C_QuestLog.UnitIsRelatedToActiveQuest(frame.unit)
    if isQuest then
        frame.QuestIndicator:Show()
    else
        frame.QuestIndicator:Hide()
    end
end

--[[ Update target indicator ]]
local function UpdateTargetIndicator(frame)
    if not frame or not frame.TargetIndicator then return end

    if UnitIsUnit(frame.unit, "target") then
        frame.TargetIndicator:SetBackdropBorderColor(1, 1, 1, 1)
        frame.TargetIndicator:Show()
    else
        frame.TargetIndicator:Hide()
    end
end

--[[ Nameplate callback: OnShow ]]
local function Nameplate_OnShow(frame)
    if not frame then return end

    -- Re-register frame for tracking (removed on hide)
    nameplateFrames[frame] = true

    -- Performance: 標記堆疊偵測需要重新計算
    MarkStackingDirty()

    -- Update target indicator
    UpdateTargetIndicator(frame)

    -- Update quest indicator
    UpdateQuestIndicator(frame)

    -- Update classification highlight + glow
    if frame.unit then
        local classification = GetUnitClassification(frame.unit)
        local db = LunarUI.db and LunarUI.db.profile.nameplates
        local isImportant = IsImportantTarget(frame.unit)

        if db and db.highlight then
            local color = CLASSIFICATION_COLORS[classification]
            if color and isImportant then
                if frame.Backdrop then
                    frame.Backdrop:SetBackdropBorderColor(color.r, color.g, color.b, 1)
                end
            end
        end

        -- Show classification glow for important targets
        if frame.ClassificationGlow then
            if isImportant then
                local color = CLASSIFICATION_COLORS[classification]
                if color then
                    frame.ClassificationGlow:SetVertexColor(color.r, color.g, color.b, 0.4)
                    frame.ClassificationGlow:Show()
                end
            else
                frame.ClassificationGlow:Hide()
            end
        end
    end
end

--[[ Nameplate callback: OnHide ]]
local function Nameplate_OnHide(frame)
    -- Clean up
    if frame.TargetIndicator then
        frame.TargetIndicator:Hide()
    end
    if frame.ClassificationGlow then
        frame.ClassificationGlow:Hide()
    end
    if frame.QuestIndicator then
        frame.QuestIndicator:Hide()
    end
    -- Fix #4: Remove frame reference when hidden
    nameplateFrames[frame] = nil

    -- Performance: 標記堆疊偵測需要重新計算
    MarkStackingDirty()
end

--------------------------------------------------------------------------------
-- Stacking Detection (offset overlapping nameplates)
--------------------------------------------------------------------------------

local stackingFrame = nil
local STACKING_INTERVAL = 0.1  -- 更新間隔（秒）
local STACKING_OFFSET = 10     -- 每層偏移量（像素）

-- Fix 7: 重用平行陣列，避免每 0.1s 為每個名牌建新 table
local stackFrames = {}
local stackYs = {}
local stackOffsets = {}

-- Performance: 髒旗標驅動 - 只有名牌數量變化時才重新計算
local stackingDirty = false
MarkStackingDirty = function()
    stackingDirty = true
end

-- Fix 8: 記錄上一個目標名牌，切換時只更新前/後兩個
local lastTargetNameplate = nil

local function UpdateNameplateStacking()
    if InCombatLockdown() then return end  -- 12.0: 戰鬥中避免操作名牌子框架
    local db = LunarUI.db and LunarUI.db.profile.nameplates
    if not db or not db.stackingDetection then return end

    -- 名牌高度作為重疊閾值
    local npHeight = (db.height or 8) + 4  -- 名牌高度 + 小間距

    -- Fix 7: 收集可見名牌到重用的平行陣列，避免每次建新 table
    local count = 0
    for k = 1, #stackFrames do stackFrames[k] = nil; stackYs[k] = nil; stackOffsets[k] = nil end
    for np in pairs(nameplateFrames) do
        if np and np:IsShown() and np:GetParent() then
            local _, screenY = np:GetCenter()
            if screenY then
                local appliedOffset = np._lunarStackOffset or 0
                local baseY = screenY - appliedOffset
                count = count + 1
                stackFrames[count] = np
                stackYs[count] = baseY
                stackOffsets[count] = 0
            end
        end
    end

    -- 按 Y 座標排序（由下到上）— 簡單插入排序，名牌數量通常 < 30
    for i = 2, count do
        local keyFrame = stackFrames[i]
        local keyY = stackYs[i]
        local j = i - 1
        while j >= 1 and stackYs[j] > keyY do
            stackFrames[j + 1] = stackFrames[j]
            stackYs[j + 1] = stackYs[j]
            stackOffsets[j + 1] = stackOffsets[j]
            j = j - 1
        end
        stackFrames[j + 1] = keyFrame
        stackYs[j + 1] = keyY
        stackOffsets[j + 1] = 0
    end

    -- 偵測重疊並計算偏移（使用固定閾值）
    for i = 2, count do
        local effectivePrevY = stackYs[i - 1] + stackOffsets[i - 1]
        local dy = stackYs[i] - effectivePrevY
        if dy < npHeight then
            stackOffsets[i] = stackOffsets[i - 1] + STACKING_OFFSET
        end
    end

    -- 套用偏移
    for i = 1, count do
        local np = stackFrames[i]
        local offset = stackOffsets[i]
        if np._lunarStackOffset ~= offset then
            np._lunarStackOffset = offset
            -- 偏移整個名牌的子元素（名稱/光環等在上方，不受影響）
            -- 直接調整名牌的 Y 偏移
            local parent = np:GetParent()
            if parent and np.SetPoint then
                -- oUF 名牌由暴雪 NamePlate 框架管理位置
                -- 我們透過調整子內容的相對位置來模擬偏移
                if offset > 0 then
                    if not np._lunarStackShift then
                        np._lunarStackShift = true
                    end
                    -- 使用 Health bar 的位移來表現偏移
                    if np.Health then
                        np.Health:ClearAllPoints()
                        np.Health:SetPoint("TOPLEFT", np, "TOPLEFT", 0, offset)
                        np.Health:SetPoint("BOTTOMRIGHT", np, "BOTTOMRIGHT", 0, offset)
                    end
                    if np.Backdrop then
                        np.Backdrop:ClearAllPoints()
                        np.Backdrop:SetPoint("TOPLEFT", np.Health or np, "TOPLEFT", -1, 1)
                        np.Backdrop:SetPoint("BOTTOMRIGHT", np.Health or np, "BOTTOMRIGHT", 1, -1)
                    end
                else
                    if np._lunarStackShift then
                        np._lunarStackShift = nil
                        if np.Health then
                            np.Health:ClearAllPoints()
                            np.Health:SetAllPoints(np)
                        end
                        if np.Backdrop then
                            np.Backdrop:ClearAllPoints()
                            np.Backdrop:SetPoint("TOPLEFT", np, "TOPLEFT", -1, 1)
                            np.Backdrop:SetPoint("BOTTOMRIGHT", np, "BOTTOMRIGHT", 1, -1)
                        end
                    end
                end
            end
        end
    end
end

local function StartStackingDetection()
    local db = LunarUI.db and LunarUI.db.profile.nameplates
    if not db or not db.stackingDetection then return end

    if stackingFrame then return end
    stackingFrame = CreateFrame("Frame")
    local elapsed = 0
    stackingFrame:SetScript("OnUpdate", function(_self, dt)
        elapsed = elapsed + dt
        if elapsed >= STACKING_INTERVAL then
            elapsed = 0
            -- Performance: 只在髒旗標為 true 時才重新計算
            if stackingDirty then
                stackingDirty = false
                UpdateNameplateStacking()
            end
        end
    end)
    -- 初次標記為髒，確保立即執行第一次計算
    stackingDirty = true
end

local function StopStackingDetection()
    if stackingFrame then
        stackingFrame:SetScript("OnUpdate", nil)
        stackingFrame:Hide()
        stackingFrame = nil
    end
    -- 重設所有名牌偏移
    for np in pairs(nameplateFrames) do
        if np and np._lunarStackShift then
            np._lunarStackShift = nil
            np._lunarStackOffset = nil
            if np.Health then
                np.Health:ClearAllPoints()
                np.Health:SetAllPoints(np)
            end
            if np.Backdrop then
                np.Backdrop:ClearAllPoints()
                np.Backdrop:SetPoint("TOPLEFT", np, "TOPLEFT", -1, 1)
                np.Backdrop:SetPoint("BOTTOMRIGHT", np, "BOTTOMRIGHT", 1, -1)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Register Style & Spawn
--------------------------------------------------------------------------------

oUF:RegisterStyle("LunarUI_Nameplate", NameplateLayout)

local function SpawnNameplates()
    local db = LunarUI.db and LunarUI.db.profile.nameplates
    if not db or not db.enabled then return end

    -- Fix #39: Use event-driven retry for combat lockdown
    if InCombatLockdown() then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            SpawnNameplates()
        end)
        return
    end

    oUF:SetActiveStyle("LunarUI_Nameplate")

    -- Spawn nameplates with callbacks
    oUF:SpawnNamePlates("LunarUI_Nameplate", function(frame, event, _unit)
        -- Callback for nameplate events
        if event == "NAME_PLATE_UNIT_ADDED" then
            Nameplate_OnShow(frame)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            Nameplate_OnHide(frame)
        end
    end)

    -- 堆疊偵測
    StartStackingDetection()

    -- Fix #5: Use singleton pattern to prevent duplicate event handlers
    if not nameplateTargetFrame then
        nameplateTargetFrame = CreateFrame("Frame")
        nameplateTargetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        nameplateTargetFrame:SetScript("OnEvent", function()
            -- Fix 8: 只更新前一個和當前目標名牌，而非遍歷全部
            -- 清除舊目標
            if lastTargetNameplate and lastTargetNameplate:IsShown() then
                UpdateTargetIndicator(lastTargetNameplate)
            end
            -- 設定新目標
            local targetPlate = C_NamePlate.GetNamePlateForUnit("target")
            if targetPlate then
                -- oUF 名牌掛在 unitFrame 子框架上
                local np = targetPlate.unitFrame or targetPlate
                -- 驗證框架有效性：存在於追蹤表中且仍顯示
                if np and nameplateFrames[np] and np:IsShown() then
                    UpdateTargetIndicator(np)
                    lastTargetNameplate = np
                else
                    lastTargetNameplate = nil
                end
            else
                lastTargetNameplate = nil
            end
        end)
    end

    -- 任務狀態變更時更新任務圖示
    if not nameplateQuestFrame then
        nameplateQuestFrame = CreateFrame("Frame")
        nameplateQuestFrame:RegisterEvent("QUEST_LOG_UPDATE")
        nameplateQuestFrame:SetScript("OnEvent", function()
            for np in pairs(nameplateFrames) do
                if np and np:IsShown() then
                    UpdateQuestIndicator(np)
                end
            end
        end)
    end
end

-- Export
LunarUI.SpawnNameplates = SpawnNameplates

-- Fix #35: Cleanup function to prevent memory leaks on disable/reload
function LunarUI:CleanupNameplates()
    -- Unregister target change event handler
    if nameplateTargetFrame then
        nameplateTargetFrame:UnregisterAllEvents()
        nameplateTargetFrame:SetScript("OnEvent", nil)
        nameplateTargetFrame = nil
    end
    -- Unregister quest update event handler
    if nameplateQuestFrame then
        nameplateQuestFrame:UnregisterAllEvents()
        nameplateQuestFrame:SetScript("OnEvent", nil)
        nameplateQuestFrame = nil
    end
    -- 停止堆疊偵測
    StopStackingDetection()
    -- Clear weak table references
    wipe(nameplateFrames)
end

LunarUI:RegisterModule("Nameplates", {
    onEnable = SpawnNameplates,
    onDisable = function() LunarUI:CleanupNameplates() end,
    delay = 0.2,
})
