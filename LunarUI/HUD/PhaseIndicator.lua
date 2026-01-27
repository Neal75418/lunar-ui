--[[
    LunarUI - Phase Indicator
    Visual moon icon showing current Lunar Phase
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local phaseIndicator = nil

-- Moon phase visual representations
-- In the final version, these will be custom textures
local PHASE_COLORS = {
    NEW = { r = 0.2, g = 0.2, b = 0.25, a = 0.6 },      -- Dark, barely visible
    WAXING = { r = 0.5, g = 0.5, b = 0.6, a = 0.8 },    -- Half lit
    FULL = { r = 0.95, g = 0.95, b = 1.0, a = 1.0 },    -- Bright white
    WANING = { r = 0.6, g = 0.6, b = 0.7, a = 0.85 },   -- Dimming
}

local PHASE_GLOW = {
    NEW = 0,
    WAXING = 0.3,
    FULL = 1.0,
    WANING = 0.5,
}

--[[
    Create the phase indicator frame
]]
local function CreatePhaseIndicator()
    if phaseIndicator then return phaseIndicator end

    -- Main container
    phaseIndicator = CreateFrame("Frame", "LunarUIPhaseIndicator", UIParent)
    phaseIndicator:SetSize(40, 40)
    phaseIndicator:SetPoint("TOP", UIParent, "TOP", 0, -50)
    phaseIndicator:SetFrameStrata("HIGH")

    -- Moon circle (base)
    local moon = phaseIndicator:CreateTexture(nil, "ARTWORK")
    moon:SetAllPoints()
    moon:SetTexture("Interface\\COMMON\\Indicator-Gray")  -- Placeholder, will use custom
    phaseIndicator.moon = moon

    -- Glow effect
    local glow = phaseIndicator:CreateTexture(nil, "BACKGROUND")
    glow:SetSize(60, 60)
    glow:SetPoint("CENTER")
    glow:SetTexture("Interface\\COMMON\\ShadowOverlay-Corner")  -- Placeholder
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    phaseIndicator.glow = glow

    -- Phase text (optional, for debug)
    local text = phaseIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOP", phaseIndicator, "BOTTOM", 0, -5)
    text:SetTextColor(0.7, 0.7, 0.8)
    phaseIndicator.text = text

    -- Tooltip
    phaseIndicator:EnableMouse(true)
    phaseIndicator:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("|cff8882ffLunar Phase|r")
        local phase = LunarUI:GetPhase()
        local L = Engine.L or {}
        GameTooltip:AddLine(L[phase] or phase, 1, 1, 1)

        if phase == LunarUI.PHASES.WANING then
            local remaining = LunarUI:GetWaningTimeRemaining()
            GameTooltip:AddLine(string.format("Returning to rest in %.1fs", remaining), 0.7, 0.7, 0.7)
        end

        GameTooltip:Show()
    end)
    phaseIndicator:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click to toggle WAXING
    phaseIndicator:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            LunarUI:ToggleWaxing()
        elseif button == "RightButton" then
            LunarUI:ToggleDebug()
        end
    end)

    return phaseIndicator
end

--[[
    Update the phase indicator visual
]]
local function UpdatePhaseIndicator(oldPhase, newPhase)
    if not phaseIndicator then return end

    local colors = PHASE_COLORS[newPhase] or PHASE_COLORS.NEW
    local glowAlpha = PHASE_GLOW[newPhase] or 0

    -- Update moon color
    phaseIndicator.moon:SetVertexColor(colors.r, colors.g, colors.b, colors.a)

    -- Update glow
    phaseIndicator.glow:SetAlpha(glowAlpha * 0.5)
    phaseIndicator.glow:SetVertexColor(
        LunarUI.Colors.lunarGlow[1],
        LunarUI.Colors.lunarGlow[2],
        LunarUI.Colors.lunarGlow[3]
    )

    -- Update text (if debug mode)
    if LunarUI.db and LunarUI.db.profile.debug then
        local L = Engine.L or {}
        phaseIndicator.text:SetText(L[newPhase] or newPhase)
        phaseIndicator.text:Show()
    else
        phaseIndicator.text:Hide()
    end
end

--[[
    Initialize phase indicator
]]
function LunarUI:InitPhaseIndicator()
    CreatePhaseIndicator()

    -- Register for phase changes
    self:RegisterPhaseCallback(UpdatePhaseIndicator)

    -- Initial update
    UpdatePhaseIndicator(nil, self:GetPhase())
end

--[[
    Show/hide phase indicator
]]
function LunarUI:ShowPhaseIndicator()
    if not phaseIndicator then
        CreatePhaseIndicator()
    end
    phaseIndicator:Show()
end

function LunarUI:HidePhaseIndicator()
    if phaseIndicator then
        phaseIndicator:Hide()
    end
end

-- Initialize on addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    LunarUI:InitPhaseIndicator()
end)
