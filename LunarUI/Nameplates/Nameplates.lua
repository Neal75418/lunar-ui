---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field
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

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- Wait for oUF
-- oUF is exposed as LunarUF via X-oUF TOC header
local oUF = Engine.oUF or _G.LunarUF or _G.oUF
if not oUF then
    return
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local statusBarTexture = "Interface\\Buttons\\WHITE8x8"
local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Classification colors
local CLASSIFICATION_COLORS = {
    worldboss = { r = 1.0, g = 0.2, b = 0.2 },
    rareelite = { r = 1.0, g = 0.5, b = 0.0 },
    elite = { r = 1.0, g = 0.8, b = 0.0 },
    rare = { r = 0.7, g = 0.7, b = 1.0 },
    normal = { r = 0.5, g = 0.5, b = 0.5 },
    trivial = { r = 0.3, g = 0.3, b = 0.3 },
}

-- Threat colors
local THREAT_COLORS = {
    [0] = { r = 0.5, g = 0.5, b = 0.5 },  -- Not tanking
    [1] = { r = 1.0, g = 1.0, b = 0.0 },  -- Threat warning
    [2] = { r = 1.0, g = 0.6, b = 0.0 },  -- High threat
    [3] = { r = 1.0, g = 0.0, b = 0.0 },  -- Tanking
}

-- Fix #50: Fallback debuff type colors (DebuffTypeColor may not exist in WoW 12.0)
local DEBUFF_TYPE_COLORS = _G.DebuffTypeColor or {
    none = { r = 0.8, g = 0.0, b = 0.0 },
    Magic = { r = 0.2, g = 0.6, b = 1.0 },
    Curse = { r = 0.6, g = 0.0, b = 1.0 },
    Disease = { r = 0.6, g = 0.4, b = 0.0 },
    Poison = { r = 0.0, g = 0.6, b = 0.0 },
    [""] = { r = 0.8, g = 0.0, b = 0.0 },
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function CreateBackdrop(frame)
    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetPoint("TOPLEFT", -1, 1)
    backdrop:SetPoint("BOTTOMRIGHT", 1, -1)
    backdrop:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    backdrop:SetBackdrop(backdropTemplate)
    backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    backdrop:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)
    frame.Backdrop = backdrop
    return backdrop
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
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(statusBarTexture)
    health:SetAllPoints()

    -- Reaction colors (hostile/friendly)
    health.colorReaction = true
    health.colorTapping = true
    health.colorDisconnected = true

    -- Background
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    health.bg:SetTexture(statusBarTexture)
    health.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    health.bg.multiplier = 0.3

    -- Frequent updates
    health.frequentUpdates = true

    frame.Health = health
    return health
end

--[[ Name Text ]]
local function CreateNameText(frame)
    local name = frame:CreateFontString(nil, "OVERLAY")
    name:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
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
    level:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
    level:SetPoint("LEFT", frame, "LEFT", 2, 0)
    level:SetJustifyH("LEFT")

    frame:Tag(level, "[difficulty][level]")
    frame.LevelText = level
    return level
end

--[[ Castbar ]]
local function CreateCastbar(frame)
    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(statusBarTexture)
    castbar:SetStatusBarColor(0.4, 0.6, 0.8, 1)
    castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -3)
    castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -3)
    castbar:SetHeight(6)

    -- Background
    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(statusBarTexture)
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.9)
    castbar.bg = bg

    -- Border
    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop(backdropTemplate)
    border:SetBackdropColor(0, 0, 0, 0)
    border:SetBackdropBorderColor(0.1, 0.1, 0.1, 1)

    -- Icon
    local icon = castbar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(6, 6)
    icon:SetPoint("RIGHT", castbar, "LEFT", -2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = icon

    -- Text
    local text = castbar:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 7, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    castbar.Text = text

    -- Interruptible color change
    -- Fix #69: WoW 12.0 makes notInterruptible a secret value
    castbar.PostCastStart = function(self, unit)
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
    debuffs.FilterAura = function(element, unit, data)
        -- Just check if it's the player's aura - Debuffs element handles harmful filtering
        return data.isPlayerAura == true
    end

    -- Post-create styling
    debuffs.PostCreateButton = function(self, button)
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Count:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
        button.Count:SetPoint("BOTTOMRIGHT", 2, -2)

        -- Fix #49: Apply BackdropTemplateMixin before calling SetBackdrop
        -- oUF aura buttons don't inherit from BackdropTemplate
        Mixin(button, BackdropTemplateMixin)
        button:OnBackdropLoaded()

        -- Border based on debuff type
        button:SetBackdrop(backdropTemplate)
        button:SetBackdropColor(0, 0, 0, 0.5)
    end

    -- Post-update for debuff type colors
    -- Fix #50 + Fix #57: WoW 12.0 makes dispelName a secret value
    -- Use generic debuff color since we can't access dispel type
    debuffs.PostUpdateButton = function(self, button, unit, data, position)
        local color = DEBUFF_TYPE_COLORS["none"]
        button:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    end

    frame.Debuffs = debuffs
    return debuffs
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

    threat.PostUpdate = function(self, unit, status, r, g, b)
        if status and status > 0 then
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

--[[ Raid Target Icon ]]
local function CreateRaidTargetIndicator(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    frame.RaidTargetIndicator = icon
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

--------------------------------------------------------------------------------
-- Phase Awareness for Nameplates
--------------------------------------------------------------------------------

-- Fix #4: Use weak table to prevent memory leaks from frame references
local nameplateFrames = setmetatable({}, { __mode = "v" })

local function UpdateNameplatePhase(frame)
    if not frame then return end

    local tokens = LunarUI:GetTokens()
    local db = LunarUI.db and LunarUI.db.profile.nameplates

    -- Nameplates should be more visible even in NEW phase
    -- Use a minimum alpha to keep them usable
    local minAlpha = 0.5
    local alpha = math.max(tokens.alpha, minAlpha)

    frame:SetAlpha(alpha)
end

local function RegisterNameplateForPhase(frame)
    nameplateFrames[frame] = true

    -- Register global callback if not done
    if not LunarUI._nameplatePhaseRegistered then
        LunarUI._nameplatePhaseRegistered = true

        LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
            for np in pairs(nameplateFrames) do
                if np and np:IsShown() then
                    UpdateNameplatePhase(np)
                end
            end
        end)
    end

    -- Apply initial phase
    UpdateNameplatePhase(frame)
end

--------------------------------------------------------------------------------
-- Layout Functions
--------------------------------------------------------------------------------

--[[ Enemy Nameplate Layout ]]
local function EnemyNameplateLayout(frame, unit)
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
    else
        CreateCastbar(frame)
        CreateDebuffs(frame)
    end

    CreateThreatIndicator(frame)
    CreateClassificationIndicator(frame)
    CreateRaidTargetIndicator(frame)
    CreateTargetIndicator(frame)

    -- Register for phase updates
    RegisterNameplateForPhase(frame)

    return frame
end

--[[ Friendly Nameplate Layout ]]
local function FriendlyNameplateLayout(frame, unit)
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

    CreateRaidTargetIndicator(frame)
    CreateTargetIndicator(frame)

    -- Register for phase updates
    RegisterNameplateForPhase(frame)

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

    -- Update phase alpha
    UpdateNameplatePhase(frame)

    -- Update target indicator
    UpdateTargetIndicator(frame)

    -- Update classification highlight
    if frame.unit then
        local classification = GetUnitClassification(frame.unit)
        local db = LunarUI.db and LunarUI.db.profile.nameplates

        if db and db.highlight then
            local color = CLASSIFICATION_COLORS[classification]
            if color and IsImportantTarget(frame.unit) then
                if frame.Backdrop then
                    frame.Backdrop:SetBackdropBorderColor(color.r, color.g, color.b, 1)
                end
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
    -- Fix #4: Remove frame reference when hidden
    nameplateFrames[frame] = nil
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
    oUF:SpawnNamePlates("LunarUI_Nameplate", function(frame, event, unit)
        -- Callback for nameplate events
        if event == "NAME_PLATE_UNIT_ADDED" then
            Nameplate_OnShow(frame)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            Nameplate_OnHide(frame)
        end
    end)

    -- Fix #5: Use singleton pattern to prevent duplicate event handlers
    if not LunarUI._nameplateTargetFrame then
        LunarUI._nameplateTargetFrame = CreateFrame("Frame")
        LunarUI._nameplateTargetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        LunarUI._nameplateTargetFrame:SetScript("OnEvent", function()
            for np in pairs(nameplateFrames) do
                if np and np:IsShown() then
                    UpdateTargetIndicator(np)
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
    if self._nameplateTargetFrame then
        self._nameplateTargetFrame:UnregisterAllEvents()
        self._nameplateTargetFrame:SetScript("OnEvent", nil)
    end
    -- Clear weak table references
    wipe(nameplateFrames)
    -- Reset registration flag
    self._nameplatePhaseRegistered = nil
end

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.2, SpawnNameplates)
end)
