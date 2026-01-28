--[[
    LunarUI - Phase Indicator
    Visual moon icon showing current Lunar Phase

    Features:
    - Moon icon changes with phase
    - Animated glow during FULL phase
    - Smooth transitions between phases
    - Click interactions (toggle WAXING, debug)
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local phaseIndicator = nil
local animationFrame = nil
local pulseTime = 0

--------------------------------------------------------------------------------
-- Phase Visual Constants
--------------------------------------------------------------------------------

-- Moon phase colors (used to tint the moon icon)
local PHASE_COLORS = {
    NEW = { r = 0.25, g = 0.28, b = 0.35, a = 0.5 },      -- Dark, mysterious
    WAXING = { r = 0.55, g = 0.60, b = 0.75, a = 0.75 },  -- Building
    FULL = { r = 1.00, g = 1.00, b = 1.00, a = 1.0 },     -- Bright white
    WANING = { r = 0.65, g = 0.70, b = 0.85, a = 0.85 },  -- Fading
}

-- Glow intensity per phase
local PHASE_GLOW = {
    NEW = 0,
    WAXING = 0.25,
    FULL = 0.8,
    WANING = 0.4,
}

-- Moon icons per phase (using game icons as fallback)
local MOON_ICONS = {
    NEW = "Interface\\Icons\\Spell_Shadow_Twilight",
    WAXING = "Interface\\Icons\\Spell_Nature_MoonKey",
    FULL = "Interface\\Icons\\Spell_Nature_StarFall",
    WANING = "Interface\\Icons\\Spell_Arcane_Starfire",
}

--------------------------------------------------------------------------------
-- Animation
--------------------------------------------------------------------------------

local function StartPulseAnimation()
    if not animationFrame then
        animationFrame = CreateFrame("Frame")
    end

    animationFrame:SetScript("OnUpdate", function(self, elapsed)
        if not phaseIndicator or not phaseIndicator:IsShown() then return end

        pulseTime = pulseTime + elapsed
        local phase = LunarUI:GetPhase()

        if phase == "FULL" then
            -- Gentle pulse animation
            local pulse = (math.sin(pulseTime * 2) + 1) / 2
            local baseGlow = PHASE_GLOW.FULL
            local glowAlpha = baseGlow * 0.6 + baseGlow * 0.4 * pulse

            if phaseIndicator.glow then
                phaseIndicator.glow:SetAlpha(glowAlpha)
            end

            -- Subtle scale pulse
            local scale = 1 + 0.03 * pulse
            phaseIndicator:SetScale(scale)

            -- Rotate glow slightly
            if phaseIndicator.glowOuter then
                local rotation = pulseTime * 0.2  -- Slow rotation
                -- SetRotation would be applied if we used a rotation-capable texture
            end
        elseif phase == "WAXING" then
            -- Subtle breathing
            local breath = (math.sin(pulseTime * 1.5) + 1) / 2
            local glowAlpha = PHASE_GLOW.WAXING * (0.7 + 0.3 * breath)

            if phaseIndicator.glow then
                phaseIndicator.glow:SetAlpha(glowAlpha)
            end
            phaseIndicator:SetScale(1)
        elseif phase == "WANING" then
            -- Slow fade feeling
            local fade = (math.sin(pulseTime * 0.8) + 1) / 2
            local glowAlpha = PHASE_GLOW.WANING * (0.5 + 0.5 * fade)

            if phaseIndicator.glow then
                phaseIndicator.glow:SetAlpha(glowAlpha)
            end
            phaseIndicator:SetScale(1)
        else
            -- NEW phase - no animation
            if phaseIndicator.glow then
                phaseIndicator.glow:SetAlpha(0)
            end
            phaseIndicator:SetScale(1)
        end
    end)
end

local function StopPulseAnimation()
    if animationFrame then
        animationFrame:SetScript("OnUpdate", nil)
    end
    pulseTime = 0
end

--------------------------------------------------------------------------------
-- Create Phase Indicator
--------------------------------------------------------------------------------

local function CreatePhaseIndicator()
    if phaseIndicator then return phaseIndicator end

    -- Main container
    phaseIndicator = CreateFrame("Frame", "LunarUIPhaseIndicator", UIParent)
    phaseIndicator:SetSize(36, 36)
    phaseIndicator:SetPoint("TOP", UIParent, "TOP", 0, -50)
    phaseIndicator:SetFrameStrata("HIGH")

    -- Background ring (subtle dark border)
    local ring = phaseIndicator:CreateTexture(nil, "BACKGROUND")
    ring:SetSize(42, 42)
    ring:SetPoint("CENTER")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetVertexColor(0.1, 0.1, 0.15, 0.8)
    phaseIndicator.ring = ring

    -- Outer glow (behind moon)
    local glowOuter = phaseIndicator:CreateTexture(nil, "BACKGROUND", nil, -1)
    glowOuter:SetSize(80, 80)
    glowOuter:SetPoint("CENTER")
    glowOuter:SetTexture("Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64")
    glowOuter:SetBlendMode("ADD")
    glowOuter:SetVertexColor(0.6, 0.7, 0.9, 0)
    phaseIndicator.glowOuter = glowOuter

    -- Main glow (close to moon)
    local glow = phaseIndicator:CreateTexture(nil, "ARTWORK", nil, -1)
    glow:SetSize(56, 56)
    glow:SetPoint("CENTER")
    glow:SetTexture("Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.7, 0.8, 1.0, 0)
    phaseIndicator.glow = glow

    -- Moon icon
    local moon = phaseIndicator:CreateTexture(nil, "ARTWORK")
    moon:SetSize(32, 32)
    moon:SetPoint("CENTER")
    moon:SetTexture(MOON_ICONS.NEW)
    moon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Trim icon edges
    phaseIndicator.moon = moon

    -- Mask to make circular (if supported)
    -- moon:SetMask("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")

    -- Inner highlight (top-left light source)
    local highlight = phaseIndicator:CreateTexture(nil, "OVERLAY")
    highlight:SetSize(16, 16)
    highlight:SetPoint("TOPLEFT", moon, "TOPLEFT", 2, -2)
    highlight:SetTexture("Interface\\Cooldown\\star4")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 1, 1, 0)
    phaseIndicator.highlight = highlight

    -- Phase text (shows in debug mode)
    local text = phaseIndicator:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    text:SetPoint("TOP", phaseIndicator, "BOTTOM", 0, -4)
    text:SetTextColor(0.7, 0.75, 0.85)
    text:Hide()
    phaseIndicator.text = text

    -- Combat timer text (shows during WANING)
    local timer = phaseIndicator:CreateFontString(nil, "OVERLAY")
    timer:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    timer:SetPoint("BOTTOM", phaseIndicator, "TOP", 0, 2)
    timer:SetTextColor(0.6, 0.65, 0.75)
    timer:Hide()
    phaseIndicator.timer = timer

    -- Tooltip
    phaseIndicator:EnableMouse(true)
    phaseIndicator:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("|cff8882ffLunar|r |cffffffffPhase|r")

        local phase = LunarUI:GetPhase()
        local L = Engine.L or {}
        local phaseName = L[phase] or phase

        -- Phase color
        local colors = PHASE_COLORS[phase] or PHASE_COLORS.NEW
        GameTooltip:AddLine(phaseName, colors.r, colors.g, colors.b)

        -- Phase description
        local descriptions = {
            NEW = "Resting - UI fades to background",
            WAXING = "Preparing - Attention focusing",
            FULL = "Combat - Maximum clarity",
            WANING = "Post-combat - Gradually relaxing",
        }
        GameTooltip:AddLine(descriptions[phase] or "", 0.7, 0.7, 0.7)

        -- Timer for WANING
        if phase == "WANING" then
            local remaining = LunarUI:GetWaningTimeRemaining()
            if remaining and remaining > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format("Returning to rest in %.0fs", remaining), 0.5, 0.55, 0.65)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Left-click", "Toggle WAXING mode", 0.5, 0.5, 0.5, 0.8, 0.8, 0.8)
        GameTooltip:AddDoubleLine("Right-click", "Toggle debug overlay", 0.5, 0.5, 0.5, 0.8, 0.8, 0.8)

        GameTooltip:Show()
    end)

    phaseIndicator:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click interactions
    phaseIndicator:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            LunarUI:ToggleWaxing()
        elseif button == "RightButton" then
            LunarUI:ToggleDebug()
        end
    end)

    -- Drag support
    phaseIndicator:SetMovable(true)
    phaseIndicator:RegisterForDrag("LeftButton")
    phaseIndicator:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    phaseIndicator:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    return phaseIndicator
end

--------------------------------------------------------------------------------
-- Update Phase Indicator
--------------------------------------------------------------------------------

local function UpdatePhaseIndicator(oldPhase, newPhase)
    if not phaseIndicator then return end

    local colors = PHASE_COLORS[newPhase] or PHASE_COLORS.NEW
    local glowIntensity = PHASE_GLOW[newPhase] or 0
    local moonIcon = MOON_ICONS[newPhase] or MOON_ICONS.NEW

    -- Update moon icon and color
    phaseIndicator.moon:SetTexture(moonIcon)
    phaseIndicator.moon:SetVertexColor(colors.r, colors.g, colors.b, colors.a)

    -- Update glow
    phaseIndicator.glow:SetAlpha(glowIntensity * 0.6)
    phaseIndicator.glowOuter:SetAlpha(glowIntensity * 0.3)

    -- Update highlight (visible only during FULL)
    if newPhase == "FULL" then
        phaseIndicator.highlight:SetAlpha(0.6)
    elseif newPhase == "WAXING" then
        phaseIndicator.highlight:SetAlpha(0.2)
    else
        phaseIndicator.highlight:SetAlpha(0)
    end

    -- Update ring color
    if newPhase == "FULL" then
        phaseIndicator.ring:SetVertexColor(0.4, 0.45, 0.55, 0.9)
    else
        phaseIndicator.ring:SetVertexColor(0.1, 0.1, 0.15, 0.8)
    end

    -- Update text (if debug mode)
    if LunarUI.db and LunarUI.db.profile.debug then
        local L = Engine.L or {}
        phaseIndicator.text:SetText(L[newPhase] or newPhase)
        phaseIndicator.text:Show()
    else
        phaseIndicator.text:Hide()
    end

    -- Show/hide timer during WANING
    if newPhase == "WANING" then
        phaseIndicator.timer:Show()
        -- Update timer text periodically
        if not phaseIndicator.timerUpdate then
            phaseIndicator.timerUpdate = C_Timer.NewTicker(0.5, function()
                if LunarUI:GetPhase() == "WANING" then
                    local remaining = LunarUI:GetWaningTimeRemaining()
                    if remaining and remaining > 0 then
                        phaseIndicator.timer:SetText(string.format("%.0f", remaining))
                    else
                        phaseIndicator.timer:SetText("")
                    end
                else
                    phaseIndicator.timer:Hide()
                    if phaseIndicator.timerUpdate then
                        phaseIndicator.timerUpdate:Cancel()
                        phaseIndicator.timerUpdate = nil
                    end
                end
            end)
        end
    else
        phaseIndicator.timer:Hide()
        if phaseIndicator.timerUpdate then
            phaseIndicator.timerUpdate:Cancel()
            phaseIndicator.timerUpdate = nil
        end
    end

    -- Start/stop animation based on phase
    if newPhase == "FULL" or newPhase == "WAXING" or newPhase == "WANING" then
        StartPulseAnimation()
    else
        StopPulseAnimation()
    end
end

--------------------------------------------------------------------------------
-- Initialize Phase Indicator
--------------------------------------------------------------------------------

function LunarUI:InitPhaseIndicator()
    CreatePhaseIndicator()

    -- Register for phase changes
    self:RegisterPhaseCallback(UpdatePhaseIndicator)

    -- Initial update
    UpdatePhaseIndicator(nil, self:GetPhase())

    -- Start animation if needed
    local phase = self:GetPhase()
    if phase == "FULL" or phase == "WAXING" or phase == "WANING" then
        StartPulseAnimation()
    end
end

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

-- Fix #8: Cleanup function to cancel all timers
function LunarUI:CleanupPhaseIndicator()
    if phaseIndicator then
        -- Cancel timer
        if phaseIndicator.timerUpdate then
            phaseIndicator.timerUpdate:Cancel()
            phaseIndicator.timerUpdate = nil
        end
        phaseIndicator.timer:Hide()
    end

    -- Stop animation
    if animationFrame then
        animationFrame:SetScript("OnUpdate", nil)
    end
    pulseTime = 0
end

-- Initialize on addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    LunarUI:InitPhaseIndicator()
end)
