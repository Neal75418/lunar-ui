--[[
    LunarUI - oUF Layout
    Defines the visual style for all unit frames
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- Wait for oUF to be available
local oUF = Engine.oUF or _G.oUF
if not oUF then
    -- oUF not loaded yet, will be initialized later
    return
end

-- Shared media
local statusBarTexture = "Interface\\Buttons\\WHITE8x8"  -- Will be replaced with custom texture
local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

--[[
    Create backdrop for frames
]]
local function CreateBackdrop(frame)
    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetAllPoints()
    backdrop:SetFrameLevel(frame:GetFrameLevel() - 1)
    backdrop:SetBackdrop(backdropTemplate)

    -- Lunar theme colors
    backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    backdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)  -- Ink dark

    frame.Backdrop = backdrop
    return backdrop
end

--[[
    Create health bar element
]]
local function CreateHealthBar(frame)
    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(statusBarTexture)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    health:SetHeight(frame:GetHeight() * 0.65)

    -- Health colors (will use class colors)
    health.colorClass = true
    health.colorReaction = true
    health.colorHealth = true

    -- Background
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    health.bg:SetTexture(statusBarTexture)
    health.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    health.bg.multiplier = 0.3

    frame.Health = health
    return health
end

--[[
    Create power bar element
]]
local function CreatePowerBar(frame)
    local power = CreateFrame("StatusBar", nil, frame)
    power:SetStatusBarTexture(statusBarTexture)
    power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, -1)
    power:SetPoint("TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, -1)
    power:SetPoint("BOTTOM", frame, "BOTTOM", 0, 1)

    -- Power colors
    power.colorPower = true

    -- Background
    power.bg = power:CreateTexture(nil, "BACKGROUND")
    power.bg:SetAllPoints()
    power.bg:SetTexture(statusBarTexture)
    power.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    power.bg.multiplier = 0.3

    frame.Power = power
    return power
end

--[[
    Create name text
]]
local function CreateNameText(frame)
    local name = frame.Health:CreateFontString(nil, "OVERLAY")
    name:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    name:SetPoint("LEFT", frame.Health, "LEFT", 5, 0)
    name:SetJustifyH("LEFT")

    frame:Tag(name, "[name]")
    frame.Name = name
    return name
end

--[[
    Create health text
]]
local function CreateHealthText(frame)
    local healthText = frame.Health:CreateFontString(nil, "OVERLAY")
    healthText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    healthText:SetPoint("RIGHT", frame.Health, "RIGHT", -5, 0)
    healthText:SetJustifyH("RIGHT")

    frame:Tag(healthText, "[curhp] / [maxhp]")
    frame.HealthText = healthText
    return healthText
end

--[[
    Apply Phase-aware behavior to frame
]]
local function ApplyPhaseAwareness(frame)
    -- Register for phase changes
    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        local tokens = LunarUI:GetTokens()
        if frame and frame:IsShown() then
            frame:SetAlpha(tokens.alpha)
            frame:SetScale(tokens.scale)
        end
    end)

    -- Apply initial tokens
    local tokens = LunarUI:GetTokens()
    frame:SetAlpha(tokens.alpha)
    frame:SetScale(tokens.scale)
end

--[[
    Shared layout function for all units
]]
local function Shared(frame, unit)
    -- Basic setup
    frame:SetSize(220, 45)
    frame:RegisterForClicks("AnyUp")
    frame:SetScript("OnEnter", UnitFrame_OnEnter)
    frame:SetScript("OnLeave", UnitFrame_OnLeave)

    -- Create elements
    CreateBackdrop(frame)
    CreateHealthBar(frame)
    CreatePowerBar(frame)
    CreateNameText(frame)
    CreateHealthText(frame)

    -- Apply phase awareness
    ApplyPhaseAwareness(frame)

    return frame
end

--[[
    Player-specific layout
]]
local function PlayerLayout(frame, unit)
    Shared(frame, unit)

    local db = LunarUI.db and LunarUI.db.profile.unitframes.player
    if db then
        frame:SetSize(db.width, db.height)
    end

    return frame
end

--[[
    Target-specific layout
]]
local function TargetLayout(frame, unit)
    Shared(frame, unit)

    local db = LunarUI.db and LunarUI.db.profile.unitframes.target
    if db then
        frame:SetSize(db.width, db.height)
    end

    return frame
end

-- Register oUF styles
oUF:RegisterStyle("LunarUI", Shared)
oUF:RegisterStyle("LunarUI_Player", PlayerLayout)
oUF:RegisterStyle("LunarUI_Target", TargetLayout)

-- Set active style
oUF:SetActiveStyle("LunarUI")

-- Spawn unit frames
local function SpawnUnitFrames()
    if not LunarUI.db then return end
    local uf = LunarUI.db.profile.unitframes

    -- Player
    if uf.player.enabled then
        oUF:SetActiveStyle("LunarUI_Player")
        local player = oUF:Spawn("player", "LunarUI_Player")
        player:SetPoint(uf.player.point, UIParent, "CENTER", uf.player.x, uf.player.y)
    end

    -- Target
    if uf.target.enabled then
        oUF:SetActiveStyle("LunarUI_Target")
        local target = oUF:Spawn("target", "LunarUI_Target")
        target:SetPoint(uf.target.point, UIParent, "CENTER", uf.target.x, uf.target.y)
    end
end

-- Export spawn function
LunarUI.SpawnUnitFrames = SpawnUnitFrames

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.1, SpawnUnitFrames)
end)
