--[[
    LunarUI - oUF Layout
    Defines the visual style for all unit frames

    Phase-aware UnitFrames that respond to Lunar Phase changes
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- Wait for oUF to be available (X-oUF: LunarUF in TOC)
local oUF = Engine.oUF or _G.LunarUF or _G.oUF
if not oUF then
    print("|cffff0000LunarUI:|r oUF not found!")
    return
end

--------------------------------------------------------------------------------
-- Constants & Shared Resources
--------------------------------------------------------------------------------

local statusBarTexture = "Interface\\Buttons\\WHITE8x8"
local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Frame sizes
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
-- Helper Functions
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
-- Core Elements
--------------------------------------------------------------------------------

--[[ Health Bar ]]
local function CreateHealthBar(frame, unit)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(statusBarTexture)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    -- Height varies by unit type
    local heightPercent = (unit == "raid") and 0.85 or 0.65
    health:SetHeight(frame:GetHeight() * heightPercent)

    -- Colors
    health.colorClass = true
    health.colorReaction = true
    health.colorHealth = true
    health.colorSmooth = false

    -- Background
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    health.bg:SetTexture(statusBarTexture)
    health.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    health.bg.multiplier = 0.3

    -- Frequent updates for smooth animation
    health.frequentUpdates = true

    -- Fix #71: PostUpdate hook to ensure class colors are applied correctly
    health.PostUpdate = function(self, unit, cur, max)
        if not unit then return end

        -- For players, use class color
        if UnitIsPlayer(unit) then
            local _, class = UnitClass(unit)
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

        -- For NPCs, use reaction color
        local reaction = UnitReaction(unit, "player")
        if reaction then
            local color
            if reaction >= 5 then
                -- Friendly (green)
                color = { r = 0.2, g = 0.9, b = 0.3 }
            elseif reaction == 4 then
                -- Neutral (yellow)
                color = { r = 0.9, g = 0.9, b = 0.2 }
            else
                -- Hostile (red)
                color = { r = 0.9, g = 0.2, b = 0.2 }
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

--[[ Power Bar ]]
local function CreatePowerBar(frame, unit)
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

--[[ Name Text ]]
local function CreateNameText(frame, unit)
    local name = frame.Health:CreateFontString(nil, "OVERLAY")
    name:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    name:SetPoint("LEFT", frame.Health, "LEFT", 5, 0)
    name:SetJustifyH("LEFT")

    -- Truncate long names for smaller frames
    if unit == "raid" or unit == "party" then
        name:SetWidth(frame:GetWidth() - 10)
        frame:Tag(name, "[name:short]")
    else
        frame:Tag(name, "[name]")
    end

    frame.Name = name
    return name
end

--[[ Health Text ]]
local function CreateHealthText(frame, unit)
    -- Skip for raid frames (too small)
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

--[[ Castbar ]]
local function CreateCastbar(frame, unit)
    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(statusBarTexture)
    castbar:SetStatusBarColor(0.4, 0.6, 0.8, 1)

    -- Position below main frame
    castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
    castbar:SetHeight(16)

    -- Background
    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(statusBarTexture)
    bg:SetVertexColor(0.05, 0.05, 0.05, 0.9)
    castbar.bg = bg

    -- Border
    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop(backdropTemplate)
    border:SetBackdropColor(0, 0, 0, 0)
    border:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)

    -- Spell icon
    local icon = castbar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", castbar, "LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = icon

    -- Spell name
    local text = castbar:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetJustifyH("LEFT")
    castbar.Text = text

    -- Cast time
    local time = castbar:CreateFontString(nil, "OVERLAY")
    time:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    time:SetPoint("RIGHT", castbar, "RIGHT", -4, 0)
    time:SetJustifyH("RIGHT")
    castbar.Time = time

    -- Fix #48: WoW 12.0 makes notInterruptible a completely inaccessible secret value
    -- Blizzard intentionally restricts this information from addons
    -- Use a consistent cast bar color since we cannot determine interruptibility
    castbar.PostCastStart = function(self, unit)
        self:SetStatusBarColor(0.4, 0.6, 0.8, 1)
    end

    castbar.PostChannelStart = function(self, unit)
        self:SetStatusBarColor(0.4, 0.6, 0.8, 1)
    end

    -- Spark
    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(20, 20)
    spark:SetBlendMode("ADD")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    castbar.Spark = spark

    frame.Castbar = castbar
    return castbar
end

-- Fix #51: Fallback debuff type colors for UnitFrames (DebuffTypeColor may not exist in WoW 12.0)
local UNITFRAME_DEBUFF_COLORS = _G.DebuffTypeColor or {
    none = { r = 0.8, g = 0.0, b = 0.0 },
    Magic = { r = 0.2, g = 0.6, b = 1.0 },
    Curse = { r = 0.6, g = 0.0, b = 1.0 },
    Disease = { r = 0.6, g = 0.4, b = 0.0 },
    Poison = { r = 0.0, g = 0.6, b = 0.0 },
    [""] = { r = 0.8, g = 0.0, b = 0.0 },
}

--[[ Auras (Buffs/Debuffs) ]]
local function CreateAuras(frame, unit)
    local auras = CreateFrame("Frame", nil, frame)

    -- Fix #64: Determine unit type from multiple sources
    local unitType = unit or frame.unit
    -- Also check frame name as fallback
    local frameName = frame:GetName() or ""
    if not unitType or unitType == "" then
        if frameName:find("Player") then
            unitType = "player"
        elseif frameName:find("Target") then
            unitType = "target"
        else
            unitType = "unknown"
        end
    end

    -- Position based on unit type - auras should NOT overlap with the frame
    if unitType == "target" then
        -- Target: auras appear to the RIGHT
        auras:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
        auras:SetSize(180, 50)
        auras.initialAnchor = "TOPLEFT"
        auras["growth-x"] = "RIGHT"
        auras["growth-y"] = "DOWN"
    elseif unitType == "player" then
        -- Player: auras appear to the LEFT
        auras:SetPoint("TOPRIGHT", frame, "TOPLEFT", -4, 0)
        auras:SetSize(180, 50)
        auras.initialAnchor = "TOPRIGHT"
        auras["growth-x"] = "LEFT"
        auras["growth-y"] = "DOWN"
    else
        -- Other units: auras appear ABOVE the frame
        auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
        auras:SetSize(frame:GetWidth() > 0 and frame:GetWidth() or 180, 20)
        auras.initialAnchor = "BOTTOMLEFT"
        auras["growth-x"] = "RIGHT"
        auras["growth-y"] = "UP"
    end

    auras.size = 22
    auras.spacing = 2
    auras.num = 16
    auras.numBuffs = 8
    auras.numDebuffs = 8

    -- Fix #51 + Fix #55 + Fix #56: Initialize all tables required by oUF Auras element
    auras.allBuffs = {}
    auras.allDebuffs = {}
    auras.activeBuffs = {}
    auras.activeDebuffs = {}
    auras.sortedBuffs = {}
    auras.sortedDebuffs = {}

    -- Filter auras for specific units
    if unitType == "target" then
        auras.onlyShowPlayer = true
        auras.FilterAura = function(element, unit, data)
            return data.isPlayerAura == true
        end
    end

    -- Post-create hook for styling
    auras.PostCreateButton = function(self, button)
        -- Fix #51: Apply BackdropTemplateMixin before calling SetBackdrop
        Mixin(button, BackdropTemplateMixin)
        button:OnBackdropLoaded()
        button:SetBackdrop(backdropTemplate)
        button:SetBackdropColor(0, 0, 0, 0.5)
        button:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)

        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Icon:SetDrawLayer("ARTWORK")

        button.Count:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        button.Count:SetPoint("BOTTOMRIGHT", 2, -2)

        if button.Cooldown then
            button.Cooldown:SetDrawEdge(false)
            button.Cooldown:SetHideCountdownNumbers(true)
        end
    end

    -- Post-update hook for debuff colors
    -- Fix #53 + Fix #57: WoW 12.0 makes isHarmful and dispelName secret values
    -- Use isHarmfulAura (added by oUF) which is safe to access
    auras.PostUpdateButton = function(self, button, unit, data, position)
        if data.isHarmfulAura then
            -- Debuff - use generic debuff color since dispelName is inaccessible
            local color = UNITFRAME_DEBUFF_COLORS["none"]
            button:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        else
            button:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        end
    end

    frame.Auras = auras
    return auras
end

--[[ Debuffs only (for party/raid) ]]
local function CreateDebuffs(frame, unit)
    local debuffs = CreateFrame("Frame", nil, frame)
    debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    debuffs:SetSize(frame:GetWidth(), 18)

    debuffs.size = 18
    debuffs.spacing = 2
    debuffs.num = 4
    debuffs.initialAnchor = "BOTTOMLEFT"
    debuffs["growth-x"] = "RIGHT"
    debuffs["growth-y"] = "UP"

    -- Fix #53: WoW 12.0 makes isHarmful/isBossAura secret values
    -- Debuffs element already filters to harmful, just check source
    debuffs.FilterAura = function(element, unit, data)
        return data.isPlayerAura == true
    end

    debuffs.PostCreateButton = function(self, button)
        -- Fix #51: Apply BackdropTemplateMixin before calling SetBackdrop
        Mixin(button, BackdropTemplateMixin)
        button:OnBackdropLoaded()
        button:SetBackdrop(backdropTemplate)
        button:SetBackdropColor(0, 0, 0, 0.5)
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Count:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    end

    debuffs.PostUpdateButton = function(self, button, unit, data, position)
        -- Fix #51 + Fix #57: WoW 12.0 makes dispelName a secret value
        -- Use generic debuff color since we can't access dispel type
        local color = UNITFRAME_DEBUFF_COLORS["none"]
        button:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    end

    frame.Debuffs = debuffs
    return debuffs
end

--------------------------------------------------------------------------------
-- Unit-Specific Elements
--------------------------------------------------------------------------------

--[[ Player: Resting Indicator ]]
local function CreateRestingIndicator(frame)
    local resting = frame.Health:CreateTexture(nil, "OVERLAY")
    resting:SetSize(16, 16)
    resting:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
    resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    resting:SetTexCoord(0.09, 0.43, 0.08, 0.42)
    frame.RestingIndicator = resting
    return resting
end

--[[ Player: Combat Indicator ]]
local function CreateCombatIndicator(frame)
    local combat = frame.Health:CreateTexture(nil, "OVERLAY")
    combat:SetSize(16, 16)
    combat:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 8, 8)
    combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    combat:SetTexCoord(0.58, 0.90, 0.08, 0.41)
    frame.CombatIndicator = combat
    return combat
end

--[[ Player: Experience Bar ]]
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

    -- Rested XP overlay
    exp.Rested = CreateFrame("StatusBar", nil, exp)
    exp.Rested:SetStatusBarTexture(statusBarTexture)
    exp.Rested:SetStatusBarColor(0.0, 0.39, 0.88, 0.5)
    exp.Rested:SetAllPoints()

    frame.ExperienceBar = exp
    return exp
end

--[[ Target: Classification (Elite/Rare) ]]
local function CreateClassification(frame)
    local class = frame.Health:CreateFontString(nil, "OVERLAY")
    class:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    class:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, 10)
    class:SetTextColor(1, 0.82, 0)

    frame:Tag(class, "[classification]")
    frame.Classification = class
    return class
end

--[[ Target: Level Text ]]
local function CreateLevelText(frame, unit)
    local level = frame.Health:CreateFontString(nil, "OVERLAY")
    level:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    level:SetPoint("RIGHT", frame.Name, "LEFT", -4, 0)

    frame:Tag(level, "[difficulty][level]")
    frame.LevelText = level
    return level
end

--[[ Threat Indicator ]]
local function CreateThreatIndicator(frame)
    local threat = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    threat:SetAllPoints()
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

--[[ Range Indicator (for party/raid) ]]
local function CreateRangeIndicator(frame)
    frame.Range = {
        insideAlpha = 1,
        outsideAlpha = 0.4,
    }
    return frame.Range
end

--[[ Leader/Assistant Indicators ]]
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

--[[ Raid Role Indicator ]]
local function CreateRaidRoleIndicator(frame)
    local role = frame.Health:CreateTexture(nil, "OVERLAY")
    role:SetSize(12, 12)
    role:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
    frame.RaidRoleIndicator = role
    return role
end

--[[ Group Role Indicator (Tank/Healer/DPS) ]]
local function CreateGroupRoleIndicator(frame)
    local role = frame.Health:CreateTexture(nil, "OVERLAY")
    role:SetSize(14, 14)
    role:SetPoint("LEFT", frame.Health, "LEFT", 2, 0)
    frame.GroupRoleIndicator = role
    return role
end

--[[ Ready Check Indicator ]]
local function CreateReadyCheckIndicator(frame)
    local ready = frame:CreateTexture(nil, "OVERLAY")
    ready:SetSize(20, 20)
    ready:SetPoint("CENTER")
    frame.ReadyCheckIndicator = ready
    return ready
end

--[[ Summon Indicator ]]
local function CreateSummonIndicator(frame)
    local summon = frame:CreateTexture(nil, "OVERLAY")
    summon:SetSize(24, 24)
    summon:SetPoint("CENTER")
    frame.SummonIndicator = summon
    return summon
end

--[[ Resurrection Indicator ]]
local function CreateResurrectIndicator(frame)
    local res = frame:CreateTexture(nil, "OVERLAY")
    res:SetSize(20, 20)
    res:SetPoint("CENTER")
    frame.ResurrectIndicator = res
    return res
end

-- Fix #74 + Fix #100: Death Indicator with single global event frame to prevent memory leaks
-- Use weak table to track frames needing death state updates
local deathIndicatorFrames = setmetatable({}, { __mode = "k" })
local deathIndicatorEventFrame

local function UpdateDeathStateForFrame(frame)
    -- Fix #107: Wrap in pcall with debug logging to prevent silent failures
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

    if not success and LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.debug then
        LunarUI:Print("UpdateDeathStateForFrame error: " .. tostring(err))
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

-- Create single global event frame (lazy initialization)
local function EnsureDeathIndicatorEventFrame()
    if deathIndicatorEventFrame then return end

    deathIndicatorEventFrame = CreateFrame("Frame")
    deathIndicatorEventFrame:RegisterEvent("UNIT_HEALTH")
    deathIndicatorEventFrame:RegisterEvent("UNIT_CONNECTION")
    deathIndicatorEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    deathIndicatorEventFrame:RegisterEvent("UNIT_FLAGS")
    deathIndicatorEventFrame:SetScript("OnEvent", function(self, event, eventUnit, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            UpdateAllDeathStates()
        elseif eventUnit then
            UpdateAllDeathStates(eventUnit)
        end
    end)
end

local function CreateDeathIndicator(frame, unit)
    -- Create skull icon for dead units
    local dead = frame:CreateTexture(nil, "OVERLAY")
    dead:SetSize(20, 20)
    dead:SetPoint("CENTER", frame.Health, "CENTER")
    dead:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    dead:Hide()
    frame.DeadIndicator = dead

    -- Create gray overlay for dead units
    local deadOverlay = frame.Health:CreateTexture(nil, "OVERLAY")
    deadOverlay:SetAllPoints(frame.Health)
    deadOverlay:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    deadOverlay:Hide()
    frame.DeadOverlay = deadOverlay

    -- Register frame with global death indicator system (weak reference)
    EnsureDeathIndicatorEventFrame()
    deathIndicatorFrames[frame] = true

    -- Initial update
    C_Timer.After(0.2, function()
        UpdateDeathStateForFrame(frame)
    end)

    return dead
end

--------------------------------------------------------------------------------
-- Phase Awareness
--------------------------------------------------------------------------------

-- Global phase callback registration (only once)
local phaseCallbackRegistered = false

-- Fix #21: Optimized phase callback for large raids using batched updates
-- Fix #101: Use stored timer for proper cancellation to prevent timer accumulation
local updateQueue = {}
local isUpdating = false
local updateBatchTimer = nil

local function ProcessUpdateBatch()
    updateBatchTimer = nil  -- Clear timer reference

    -- Fix #105: Wrap entire batch processing in pcall to ensure isUpdating is reset on error
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

        -- Process up to 10 frames per batch
        local batchSize = 10
        for i = 1, batchSize do
            local frame = table.remove(updateQueue, 1)
            if frame and frame.IsShown and frame:IsShown() then
                -- Wrap individual frame updates in pcall to prevent one bad frame from stopping all updates
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

        -- Continue processing next frame with cancellable timer
        updateBatchTimer = C_Timer.NewTimer(0, ProcessUpdateBatch)
    end)

    -- Fix #105: Ensure isUpdating is reset even if an error occurred
    if not success then
        isUpdating = false
        wipe(updateQueue)
        if LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.debug then
            LunarUI:Print("ProcessUpdateBatch error: " .. tostring(err))
        end
    end
end

local function UpdateAllFramesForPhase()
    -- Fix #101: Cancel any existing batch timer before starting new updates
    if updateBatchTimer then
        updateBatchTimer:Cancel()
        updateBatchTimer = nil
    end

    -- Collect all frames to update
    wipe(updateQueue)

    for name, frame in pairs(spawnedFrames) do
        if frame and frame.IsShown and frame:IsShown() then
            table.insert(updateQueue, frame)
        end
    end

    -- Also collect header child frames (party/raid)
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

    -- Start batched processing if not already running
    if not isUpdating and #updateQueue > 0 then
        isUpdating = true
        ProcessUpdateBatch()
    end
end

local function RegisterGlobalPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        UpdateAllFramesForPhase()
    end)
end

local function ApplyPhaseAwareness(frame)
    -- Register global callback if not done
    RegisterGlobalPhaseCallback()

    -- Apply initial tokens
    local tokens = LunarUI:GetTokens()
    frame:SetAlpha(tokens.alpha)
    frame:SetScale(tokens.scale)
end

--------------------------------------------------------------------------------
-- Layout Functions
--------------------------------------------------------------------------------

--[[ Shared layout for all units ]]
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

--[[ Player Layout ]]
local function PlayerLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.player
    local size = db and { width = db.width, height = db.height } or SIZES.player
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateHealthText(frame, unit)
    CreateCastbar(frame, unit)
    -- Fix #66: Remove player auras (already shown in top-right corner)
    CreateLevelText(frame, unit)  -- Fix #66: Add level display
    CreateRestingIndicator(frame)
    CreateCombatIndicator(frame)
    CreateThreatIndicator(frame)

    -- Experience bar (only if not max level)
    if UnitLevel("player") < GetMaxPlayerLevel() then
        CreateExperienceBar(frame)
    end

    return frame
end

--[[ Target Layout ]]
local function TargetLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.target
    local size = db and { width = db.width, height = db.height } or SIZES.target
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateHealthText(frame, unit)
    CreateCastbar(frame, unit)

    -- Fix #67: Use Debuffs instead of Auras - only show player's debuffs
    CreateDebuffs(frame, unit)

    -- Position debuffs to the RIGHT of frame
    if frame.Debuffs then
        frame.Debuffs:ClearAllPoints()
        frame.Debuffs:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
        frame.Debuffs:SetSize(180, 50)
        frame.Debuffs.size = 22
        frame.Debuffs.num = 8
        frame.Debuffs.initialAnchor = "TOPLEFT"
        frame.Debuffs["growth-x"] = "RIGHT"
        frame.Debuffs["growth-y"] = "DOWN"
    end

    CreateClassification(frame)
    CreateLevelText(frame, unit)
    CreateThreatIndicator(frame)
    CreateDeathIndicator(frame, unit)  -- Fix #74: Death indicator

    return frame
end

--[[ Focus Layout ]]
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

--[[ Pet Layout ]]
local function PetLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.pet
    local size = db and { width = db.width, height = db.height } or SIZES.pet
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreatePowerBar(frame, unit)
    CreateThreatIndicator(frame)

    return frame
end

--[[ TargetTarget Layout ]]
local function TargetTargetLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.targettarget
    local size = db and { width = db.width, height = db.height } or SIZES.targettarget
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)

    return frame
end

--[[ Boss Layout ]]
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

--[[ Party Layout ]]
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
    CreateLeaderIndicator(frame)
    CreateGroupRoleIndicator(frame)
    CreateReadyCheckIndicator(frame)
    CreateSummonIndicator(frame)
    CreateResurrectIndicator(frame)
    CreateDeathIndicator(frame, unit)  -- Fix #74: Death indicator

    return frame
end

--[[ Raid Layout ]]
local function RaidLayout(frame, unit)
    local db = LunarUI.db and LunarUI.db.profile.unitframes.raid
    local size = db and { width = db.width, height = db.height } or SIZES.raid
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    CreateThreatIndicator(frame)
    CreateRangeIndicator(frame)
    CreateLeaderIndicator(frame)
    CreateAssistantIndicator(frame)
    CreateRaidRoleIndicator(frame)
    CreateGroupRoleIndicator(frame)
    CreateReadyCheckIndicator(frame)
    CreateSummonIndicator(frame)
    CreateResurrectIndicator(frame)

    -- Debuffs for raid (smaller)
    local debuffs = CreateFrame("Frame", nil, frame)
    debuffs:SetPoint("CENTER", frame, "CENTER", 0, 0)
    debuffs:SetSize(40, 20)
    debuffs.size = 16
    debuffs.spacing = 2
    debuffs.num = 2
    debuffs.initialAnchor = "CENTER"
    -- Fix #54: WoW 12.0 makes isHarmful and isBossAura secret values
    debuffs.FilterAura = function(element, unit, data)
        return data.isPlayerAura == true
    end
    debuffs.PostCreateButton = function(self, button)
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Count:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
    end
    frame.Debuffs = debuffs

    CreateDeathIndicator(frame, unit)  -- Fix #74: Death indicator

    return frame
end

--------------------------------------------------------------------------------
-- Register Styles
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
-- Spawn Functions
--------------------------------------------------------------------------------

local spawnedFrames = {}

local function SpawnUnitFrames()
    -- Fix #37: Use event-driven retry instead of fixed timer for combat lockdown
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

    -- Player
    if uf.player.enabled then
        oUF:SetActiveStyle("LunarUI_Player")
        spawnedFrames.player = oUF:Spawn("player", "LunarUI_Player")
        spawnedFrames.player:SetPoint(uf.player.point, UIParent, "CENTER", uf.player.x, uf.player.y)

        -- Fix #63: Force update player frame after spawn to ensure elements are visible
        -- Player unit exists immediately but elements may not update until PLAYER_ENTERING_WORLD
        C_Timer.After(0.2, function()
            if spawnedFrames.player then
                spawnedFrames.player:Show()
                if spawnedFrames.player.UpdateAllElements then
                    spawnedFrames.player:UpdateAllElements("ForceUpdate")
                end
            end
        end)
    end

    -- Target
    if uf.target.enabled then
        oUF:SetActiveStyle("LunarUI_Target")
        spawnedFrames.target = oUF:Spawn("target", "LunarUI_Target")
        spawnedFrames.target:SetPoint(uf.target.point, UIParent, "CENTER", uf.target.x, uf.target.y)
    end

    -- Focus
    if uf.focus and uf.focus.enabled then
        oUF:SetActiveStyle("LunarUI_Focus")
        spawnedFrames.focus = oUF:Spawn("focus", "LunarUI_Focus")
        spawnedFrames.focus:SetPoint(uf.focus.point or "CENTER", UIParent, "CENTER", uf.focus.x or -350, uf.focus.y or 200)
    end

    -- Pet
    if uf.pet and uf.pet.enabled then
        oUF:SetActiveStyle("LunarUI_Pet")
        spawnedFrames.pet = oUF:Spawn("pet", "LunarUI_Pet")
        if spawnedFrames.player then
            spawnedFrames.pet:SetPoint("TOPLEFT", spawnedFrames.player, "BOTTOMLEFT", 0, -8)
        else
            spawnedFrames.pet:SetPoint("CENTER", UIParent, "CENTER", uf.pet.x or -200, uf.pet.y or -180)
        end
    end

    -- TargetTarget
    -- Fix #68: Position below castbar to avoid overlap (castbar is 16px high at -4 offset)
    if uf.targettarget and uf.targettarget.enabled then
        oUF:SetActiveStyle("LunarUI_TargetTarget")
        spawnedFrames.targettarget = oUF:Spawn("targettarget", "LunarUI_TargetTarget")
        if spawnedFrames.target then
            spawnedFrames.targettarget:SetPoint("TOPRIGHT", spawnedFrames.target, "BOTTOMRIGHT", 0, -28)
        else
            spawnedFrames.targettarget:SetPoint("CENTER", UIParent, "CENTER", uf.targettarget.x or 280, uf.targettarget.y or -180)
        end
    end

    -- Boss Frames
    if uf.boss and uf.boss.enabled then
        oUF:SetActiveStyle("LunarUI_Boss")
        for i = 1, 8 do
            local boss = oUF:Spawn("boss" .. i, "LunarUI_Boss" .. i)
            boss:SetPoint("RIGHT", UIParent, "RIGHT", uf.boss.x or -50, uf.boss.y or (200 - (i - 1) * 55))
            spawnedFrames["boss" .. i] = boss
        end
    end

    -- Party Header (Fix #20: Added visibility driver)
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
            -- Fix #20: Visibility driver - hide in raid, show in party
            RegisterStateDriver(partyHeader, "visibility", "[@raid6,exists] hide; [group:party,nogroup:raid] show; hide")
            spawnedFrames.party = partyHeader
        end
    end

    -- Raid Header (Fix #20: Added visibility driver)
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
            -- Fix #20: Visibility driver - show raid frames when in raid
            RegisterStateDriver(raidHeader, "visibility", "[group:raid] show; hide")
            spawnedFrames.raid = raidHeader
        end
    end
end

-- Fix #85 & #87 & #100 & #101: Cleanup function for updateQueue and timers
-- Death indicator frames are now tracked via weak table and auto-cleaned by GC
local function CleanupUnitFrames()
    -- Cancel pending batch update timer
    if updateBatchTimer then
        updateBatchTimer:Cancel()
        updateBatchTimer = nil
    end

    -- Clear update queue
    wipe(updateQueue)
    isUpdating = false

    -- Clear death indicator weak table entries
    wipe(deathIndicatorFrames)
end

-- Export
LunarUI.SpawnUnitFrames = SpawnUnitFrames
LunarUI.spawnedFrames = spawnedFrames
LunarUI.CleanupUnitFrames = CleanupUnitFrames

-- Fix #63: Force update player frame on PLAYER_ENTERING_WORLD
-- This ensures player data is available before updating elements
local playerUpdateFrame = CreateFrame("Frame")
playerUpdateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
playerUpdateFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(0.3, function()
        if spawnedFrames.player then
            spawnedFrames.player:Show()
            if spawnedFrames.player.UpdateAllElements then
                spawnedFrames.player:UpdateAllElements("ForceUpdate")
            end
        end
    end)
end)

-- Fix #91 + #92 + #93: Ensure Skyriding Vigor bar remains visible
-- The vigor bar is a UI widget that can be hidden when using custom unit frames
-- Fix #93: Don't force Show() on PlayerPowerBarAlt - let Blizzard handle it
--          Only ensure proper parenting and visibility settings
local function EnsureVigorBarVisible()
    -- PlayerPowerBarAlt is the standalone alternate power bar (Skyriding Vigor)
    -- Fix #93: Only adjust parent/strata, don't call Show() as that causes errors
    -- when barInfo is nil (player not on mount with vigor bar)
    if PlayerPowerBarAlt then
        -- Only reparent if it was moved to a hidden parent
        local parent = PlayerPowerBarAlt:GetParent()
        if parent and parent ~= UIParent and not parent:IsShown() then
            PlayerPowerBarAlt:SetParent(UIParent)
        end
        -- Ensure alpha is visible
        if PlayerPowerBarAlt:GetAlpha() < 1 then
            PlayerPowerBarAlt:SetAlpha(1)
        end
        -- Set proper frame strata so it appears above custom frames
        PlayerPowerBarAlt:SetFrameStrata("HIGH")
    end

    -- UIWidgetPowerBarContainerFrame is the Skyriding vigor bar container (WoW 12.0)
    if UIWidgetPowerBarContainerFrame then
        local parent = UIWidgetPowerBarContainerFrame:GetParent()
        if parent and parent ~= UIParent and not parent:IsShown() then
            UIWidgetPowerBarContainerFrame:SetParent(UIParent)
        end
        UIWidgetPowerBarContainerFrame:SetFrameStrata("HIGH")
        UIWidgetPowerBarContainerFrame:SetAlpha(1)
    end

    -- UIWidgetBelowMinimapContainerFrame may also contain vigor bar
    if UIWidgetBelowMinimapContainerFrame then
        UIWidgetBelowMinimapContainerFrame:SetAlpha(1)
    end

    -- UIWidgetTopCenterContainerFrame may contain the vigor bar
    if UIWidgetTopCenterContainerFrame then
        UIWidgetTopCenterContainerFrame:SetAlpha(1)
    end

    -- UIWidgetCenterScreenContainerFrame - center screen widgets
    if UIWidgetCenterScreenContainerFrame then
        local parent = UIWidgetCenterScreenContainerFrame:GetParent()
        if parent and parent ~= UIParent and not parent:IsShown() then
            UIWidgetCenterScreenContainerFrame:SetParent(UIParent)
        end
        UIWidgetCenterScreenContainerFrame:SetFrameStrata("HIGH")
        UIWidgetCenterScreenContainerFrame:SetAlpha(1)
    end
end

-- Register for events that might trigger vigor bar changes
local vigorFrame = CreateFrame("Frame")
vigorFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
vigorFrame:RegisterEvent("UPDATE_UI_WIDGET")
vigorFrame:RegisterEvent("UNIT_POWER_BAR_SHOW")
vigorFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
vigorFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(0.5, EnsureVigorBarVisible)
end)

-- Also run on initial load
C_Timer.After(1, EnsureVigorBarVisible)

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.1, SpawnUnitFrames)
end)
