---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field
--[[
    LunarUI - Phase Glow Effects
    Moonlight glow effects that respond to Phase changes

    Features:
    - Soft glow during FULL phase
    - Subtle pulse animation
    - Border glow for important elements
    - Configurable intensity
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local GLOW_COLOR = { 0.70, 0.80, 0.95, 0.6 }  -- Soft moonlight blue
local GLOW_FULL_ALPHA = 0.5
local GLOW_PULSE_SPEED = 2  -- seconds per cycle
local GLOW_MIN_ALPHA = 0.2
local GLOW_MAX_ALPHA = 0.6

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

-- Fix #23: Use weak-valued table to prevent memory leaks
local glowFrames = setmetatable({}, { __mode = "v" })
local animationFrame
local pulseTime = 0
local isAnimating = false

--------------------------------------------------------------------------------
-- Glow Creation
--------------------------------------------------------------------------------

local function CreateGlowTexture(parent, size)
    local glow = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture("Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)

    local glowSize = size or 8
    glow:SetPoint("TOPLEFT", parent, "TOPLEFT", -glowSize, glowSize)
    glow:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", glowSize, -glowSize)

    return glow
end

-- Create corner glows for a frame
local function CreateCornerGlows(parent)
    local corners = {}
    local size = 16

    -- Top-left
    corners.topLeft = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    corners.topLeft:SetTexture("Interface\\Cooldown\\star4")
    corners.topLeft:SetSize(size, size)
    corners.topLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", -size/2, size/2)
    corners.topLeft:SetBlendMode("ADD")
    corners.topLeft:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)

    -- Top-right
    corners.topRight = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    corners.topRight:SetTexture("Interface\\Cooldown\\star4")
    corners.topRight:SetSize(size, size)
    corners.topRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", size/2, size/2)
    corners.topRight:SetBlendMode("ADD")
    corners.topRight:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)

    -- Bottom-left
    corners.bottomLeft = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    corners.bottomLeft:SetTexture("Interface\\Cooldown\\star4")
    corners.bottomLeft:SetSize(size, size)
    corners.bottomLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -size/2, -size/2)
    corners.bottomLeft:SetBlendMode("ADD")
    corners.bottomLeft:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)

    -- Bottom-right
    corners.bottomRight = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    corners.bottomRight:SetTexture("Interface\\Cooldown\\star4")
    corners.bottomRight:SetSize(size, size)
    corners.bottomRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size/2, -size/2)
    corners.bottomRight:SetBlendMode("ADD")
    corners.bottomRight:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)

    return corners
end

-- Create edge glows for a frame
local function CreateEdgeGlows(parent)
    local edges = {}
    local thickness = 2

    -- Top edge
    edges.top = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
    edges.top:SetTexture("Interface\\Buttons\\WHITE8x8")
    edges.top:SetHeight(thickness)
    edges.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, thickness)
    edges.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, thickness)
    edges.top:SetBlendMode("ADD")
    edges.top:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)
    -- Fix #24: Check SetGradient compatibility
    if edges.top.SetGradient then
        edges.top:SetGradient("VERTICAL",
            CreateColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0),
            CreateColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 1))
    end

    -- Bottom edge
    edges.bottom = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
    edges.bottom:SetTexture("Interface\\Buttons\\WHITE8x8")
    edges.bottom:SetHeight(thickness)
    edges.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, -thickness)
    edges.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, -thickness)
    edges.bottom:SetBlendMode("ADD")
    edges.bottom:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)

    -- Left edge
    edges.left = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
    edges.left:SetTexture("Interface\\Buttons\\WHITE8x8")
    edges.left:SetWidth(thickness)
    edges.left:SetPoint("TOPLEFT", parent, "TOPLEFT", -thickness, 0)
    edges.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -thickness, 0)
    edges.left:SetBlendMode("ADD")
    edges.left:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)

    -- Right edge
    edges.right = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
    edges.right:SetTexture("Interface\\Buttons\\WHITE8x8")
    edges.right:SetWidth(thickness)
    edges.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", thickness, 0)
    edges.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", thickness, 0)
    edges.right:SetBlendMode("ADD")
    edges.right:SetVertexColor(GLOW_COLOR[1], GLOW_COLOR[2], GLOW_COLOR[3], 0)

    return edges
end

--------------------------------------------------------------------------------
-- Glow Management
--------------------------------------------------------------------------------

-- Add glow to a frame
function LunarUI:AddPhaseGlow(frame, glowType)
    if not frame then return end

    local glowData = {
        frame = frame,
        type = glowType or "simple",
        alpha = 0,
    }

    if glowType == "corner" then
        glowData.corners = CreateCornerGlows(frame)
    elseif glowType == "edge" then
        glowData.edges = CreateEdgeGlows(frame)
    else
        glowData.glow = CreateGlowTexture(frame)
    end

    table.insert(glowFrames, glowData)

    -- Update immediately
    self:UpdatePhaseGlow(glowData)

    return glowData
end

-- Remove glow from a frame
function LunarUI:RemovePhaseGlow(frame)
    for i = #glowFrames, 1, -1 do
        if glowFrames[i].frame == frame then
            local glowData = glowFrames[i]

            -- Hide all glow elements
            if glowData.glow then glowData.glow:Hide() end
            if glowData.corners then
                for _, corner in pairs(glowData.corners) do corner:Hide() end
            end
            if glowData.edges then
                for _, edge in pairs(glowData.edges) do edge:Hide() end
            end

            table.remove(glowFrames, i)
            break
        end
    end
end

-- Update glow for a specific frame
function LunarUI:UpdatePhaseGlow(glowData)
    if not glowData then return end

    local phase = self:GetPhase()
    local targetAlpha = 0

    if phase == "FULL" then
        targetAlpha = GLOW_FULL_ALPHA
    elseif phase == "WAXING" then
        targetAlpha = GLOW_FULL_ALPHA * 0.3
    elseif phase == "WANING" then
        targetAlpha = GLOW_FULL_ALPHA * 0.5
    end

    glowData.targetAlpha = targetAlpha
    glowData.alpha = targetAlpha
end

-- Set alpha on glow elements
local function SetGlowAlpha(glowData, alpha)
    if glowData.glow then
        glowData.glow:SetAlpha(alpha)
    end

    if glowData.corners then
        for _, corner in pairs(glowData.corners) do
            corner:SetAlpha(alpha)
        end
    end

    if glowData.edges then
        for _, edge in pairs(glowData.edges) do
            edge:SetAlpha(alpha)
        end
    end
end

--------------------------------------------------------------------------------
-- Animation
--------------------------------------------------------------------------------

local function UpdateGlowAnimation(elapsed)
    pulseTime = pulseTime + elapsed

    -- Calculate pulse alpha
    local pulsePhase = (math.sin(pulseTime * math.pi * 2 / GLOW_PULSE_SPEED) + 1) / 2
    local pulseAlpha = GLOW_MIN_ALPHA + (GLOW_MAX_ALPHA - GLOW_MIN_ALPHA) * pulsePhase

    local phase = LunarUI:GetPhase()

    for _, glowData in ipairs(glowFrames) do
        if glowData.frame and glowData.frame:IsShown() then
            local alpha = 0

            if phase == "FULL" then
                alpha = pulseAlpha
            elseif phase == "WAXING" then
                alpha = GLOW_MIN_ALPHA * 0.5
            elseif phase == "WANING" then
                alpha = GLOW_MIN_ALPHA
            end

            SetGlowAlpha(glowData, alpha)
        end
    end
end

local function StartAnimation()
    if isAnimating then return end
    isAnimating = true

    if not animationFrame then
        animationFrame = CreateFrame("Frame")
    end

    animationFrame:SetScript("OnUpdate", function(self, elapsed)
        UpdateGlowAnimation(elapsed)
    end)
end

local function StopAnimation()
    if not isAnimating then return end
    isAnimating = false

    if animationFrame then
        animationFrame:SetScript("OnUpdate", nil)
    end

    -- Reset all glows
    for _, glowData in ipairs(glowFrames) do
        SetGlowAlpha(glowData, 0)
    end
end

--------------------------------------------------------------------------------
-- Phase Integration
--------------------------------------------------------------------------------

local function OnPhaseChanged(oldPhase, newPhase)
    if newPhase == "FULL" or newPhase == "WAXING" or newPhase == "WANING" then
        StartAnimation()
    else
        StopAnimation()
    end

    -- Update all glows
    for _, glowData in ipairs(glowFrames) do
        LunarUI:UpdatePhaseGlow(glowData)
    end
end

--------------------------------------------------------------------------------
-- Moonlight Effect (for screen overlay)
--------------------------------------------------------------------------------

local moonlightOverlay

local function CreateMoonlightOverlay()
    if moonlightOverlay then return moonlightOverlay end

    moonlightOverlay = CreateFrame("Frame", "LunarUI_MoonlightOverlay", UIParent)
    moonlightOverlay:SetAllPoints()
    moonlightOverlay:SetFrameStrata("BACKGROUND")
    moonlightOverlay:SetFrameLevel(0)

    -- Create subtle vignette effect
    local vignette = moonlightOverlay:CreateTexture(nil, "BACKGROUND")
    vignette:SetAllPoints()
    vignette:SetTexture("Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64")
    vignette:SetBlendMode("ADD")
    vignette:SetVertexColor(0.15, 0.18, 0.25, 0)
    vignette:SetAlpha(0)
    moonlightOverlay.vignette = vignette

    -- Top-center moonlight source
    local moonlight = moonlightOverlay:CreateTexture(nil, "BACKGROUND")
    moonlight:SetSize(600, 300)
    moonlight:SetPoint("TOP", UIParent, "TOP", 0, 100)
    moonlight:SetTexture("Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64")
    moonlight:SetBlendMode("ADD")
    moonlight:SetVertexColor(0.70, 0.80, 0.95, 0)
    moonlight:SetAlpha(0)
    moonlightOverlay.moonlight = moonlight

    moonlightOverlay:Hide()

    return moonlightOverlay
end

local function UpdateMoonlightOverlay()
    local db = LunarUI.db and LunarUI.db.profile.style
    if not db or not db.moonlightOverlay then
        if moonlightOverlay then moonlightOverlay:Hide() end
        return
    end

    local overlay = CreateMoonlightOverlay()
    local phase = LunarUI:GetPhase()

    if phase == "FULL" then
        overlay:Show()
        overlay.vignette:SetAlpha(0.05)
        overlay.moonlight:SetAlpha(0.03)
    elseif phase == "WAXING" or phase == "WANING" then
        overlay:Show()
        overlay.vignette:SetAlpha(0.02)
        overlay.moonlight:SetAlpha(0.01)
    else
        overlay:Hide()
    end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function Initialize()
    -- Register for phase changes
    LunarUI:RegisterPhaseCallback(OnPhaseChanged)

    -- Initial state check
    local phase = LunarUI:GetPhase()
    if phase == "FULL" or phase == "WAXING" or phase == "WANING" then
        StartAnimation()
    end

    -- Setup moonlight overlay
    UpdateMoonlightOverlay()
end

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.5, Initialize)
end)

-- Export
LunarUI.StartGlowAnimation = StartAnimation
LunarUI.StopGlowAnimation = StopAnimation
