--[[
    LunarUI - oUF Layout
    Defines the visual style for all unit frames

    Phase-aware UnitFrames that respond to Lunar Phase changes
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- Wait for oUF to be available
local oUF = Engine.oUF or _G.oUF
if not oUF then
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

    -- Interruptible indicator
    castbar.PostCastStart = function(self, unit)
        if self.notInterruptible then
            self:SetStatusBarColor(0.7, 0.3, 0.3, 1)
        else
            self:SetStatusBarColor(0.4, 0.6, 0.8, 1)
        end
    end
    castbar.PostChannelStart = castbar.PostCastStart

    -- Spark
    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(20, 20)
    spark:SetBlendMode("ADD")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    castbar.Spark = spark

    frame.Castbar = castbar
    return castbar
end

--[[ Auras (Buffs/Debuffs) ]]
local function CreateAuras(frame, unit)
    local auras = CreateFrame("Frame", nil, frame)

    -- Position based on unit type
    if unit == "target" then
        auras:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
        auras:SetSize(180, 50)
        auras.initialAnchor = "TOPLEFT"
        auras["growth-x"] = "RIGHT"
        auras["growth-y"] = "DOWN"
    elseif unit == "player" then
        auras:SetPoint("TOPRIGHT", frame, "TOPLEFT", -4, 0)
        auras:SetSize(180, 50)
        auras.initialAnchor = "TOPRIGHT"
        auras["growth-x"] = "LEFT"
        auras["growth-y"] = "DOWN"
    else
        auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
        auras:SetSize(frame:GetWidth(), 20)
        auras.initialAnchor = "BOTTOMLEFT"
        auras["growth-x"] = "RIGHT"
        auras["growth-y"] = "UP"
    end

    auras.size = 22
    auras.spacing = 2
    auras.num = 16
    auras.numBuffs = 8
    auras.numDebuffs = 8

    -- Show only debuffs from player on target
    if unit == "target" then
        auras.onlyShowPlayer = true
    end

    -- Post-create hook for styling
    auras.PostCreateButton = function(self, button)
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
    auras.PostUpdateButton = function(self, button, unit, data, position)
        if data.isHarmful then
            local color = DebuffTypeColor[data.dispelName] or DebuffTypeColor["none"]
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

    -- Filter to important debuffs
    debuffs.FilterAura = function(element, unit, data)
        return data.isHarmful and (data.isPlayerAura or data.isBossAura)
    end

    debuffs.PostCreateButton = function(self, button)
        button:SetBackdrop(backdropTemplate)
        button:SetBackdropColor(0, 0, 0, 0.5)
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Count:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    end

    debuffs.PostUpdateButton = function(self, button, unit, data, position)
        local color = DebuffTypeColor[data.dispelName] or DebuffTypeColor["none"]
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

--------------------------------------------------------------------------------
-- Phase Awareness
--------------------------------------------------------------------------------

-- Global phase callback registration (only once)
local phaseCallbackRegistered = false

local function UpdateAllFramesForPhase()
    local tokens = LunarUI:GetTokens()
    for name, frame in pairs(spawnedFrames) do
        if frame and frame.IsShown and frame:IsShown() then
            frame:SetAlpha(tokens.alpha)
            frame:SetScale(tokens.scale)
        end
    end

    -- Also update header child frames (party/raid)
    for _, headerName in ipairs({"party", "raid"}) do
        local header = spawnedFrames[headerName]
        if header then
            for i = 1, 40 do
                local child = header:GetAttribute("child" .. i)
                if child and child.IsShown and child:IsShown() then
                    child:SetAlpha(tokens.alpha)
                    child:SetScale(tokens.scale)
                end
            end
        end
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
    CreateAuras(frame, unit)
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
    CreateAuras(frame, unit)
    CreateClassification(frame)
    CreateLevelText(frame, unit)
    CreateThreatIndicator(frame)

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
    debuffs.FilterAura = function(element, unit, data)
        return data.isHarmful and data.isBossAura
    end
    debuffs.PostCreateButton = function(self, button)
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.Count:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
    end
    frame.Debuffs = debuffs

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
    if not LunarUI.db then return end
    local uf = LunarUI.db.profile.unitframes

    -- Player
    if uf.player.enabled then
        oUF:SetActiveStyle("LunarUI_Player")
        spawnedFrames.player = oUF:Spawn("player", "LunarUI_Player")
        spawnedFrames.player:SetPoint(uf.player.point, UIParent, "CENTER", uf.player.x, uf.player.y)
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
    if uf.targettarget and uf.targettarget.enabled then
        oUF:SetActiveStyle("LunarUI_TargetTarget")
        spawnedFrames.targettarget = oUF:Spawn("targettarget", "LunarUI_TargetTarget")
        if spawnedFrames.target then
            spawnedFrames.targettarget:SetPoint("TOPRIGHT", spawnedFrames.target, "BOTTOMRIGHT", 0, -8)
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

    -- Party Header
    if uf.party and uf.party.enabled then
        oUF:SetActiveStyle("LunarUI_Party")
        spawnedFrames.party = oUF:SpawnHeader(
            "LunarUI_Party",
            nil,
            "party",
            "showParty", true,
            "showPlayer", false,
            "showSolo", false,
            "yOffset", -8,
            "groupBy", "ASSIGNEDROLE",
            "groupingOrder", "TANK,HEALER,DAMAGER",
            "oUF-initialConfigFunction", [[
                self:SetHeight(35)
                self:SetWidth(160)
            ]]
        )
        spawnedFrames.party:SetPoint("TOPLEFT", UIParent, "TOPLEFT", uf.party.x or 20, uf.party.y or -200)
    end

    -- Raid Header
    if uf.raid and uf.raid.enabled then
        oUF:SetActiveStyle("LunarUI_Raid")
        spawnedFrames.raid = oUF:SpawnHeader(
            "LunarUI_Raid",
            nil,
            "raid",
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
            "oUF-initialConfigFunction", [[
                self:SetHeight(30)
                self:SetWidth(80)
            ]]
        )
        spawnedFrames.raid:SetPoint("TOPLEFT", UIParent, "TOPLEFT", uf.raid.x or 20, uf.raid.y or -200)
    end
end

-- Export
LunarUI.SpawnUnitFrames = SpawnUnitFrames
LunarUI.spawnedFrames = spawnedFrames

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.1, SpawnUnitFrames)
end)
