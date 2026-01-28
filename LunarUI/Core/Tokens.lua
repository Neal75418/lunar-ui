--[[
    LunarUI - Design Tokens
    Visual parameters for each Lunar Phase
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- Default token values for each phase
local DEFAULT_TOKENS = {
    NEW = {
        alpha = 0.40,       -- Low presence
        scale = 0.95,       -- Slightly smaller
        contrast = 0.6,     -- Lower contrast
        glowIntensity = 0,  -- No glow
    },
    WAXING = {
        alpha = 0.65,       -- Building up
        scale = 0.98,       -- Almost full size
        contrast = 0.8,     -- Medium contrast
        glowIntensity = 0.3, -- Subtle glow
    },
    FULL = {
        alpha = 1.00,       -- Full visibility
        scale = 1.00,       -- Full size
        contrast = 1.0,     -- Maximum contrast
        glowIntensity = 0.8, -- Strong glow
    },
    WANING = {
        alpha = 0.75,       -- Fading
        scale = 0.98,       -- Slightly smaller
        contrast = 0.85,    -- Good contrast still
        glowIntensity = 0.4, -- Dimming glow
    },
}

-- Color palette (Lunar theme)
LunarUI.Colors = {
    -- Parchment tones (hand-drawn style)
    parchment = { 0.85, 0.78, 0.65, 0.95 },
    inkDark = { 0.15, 0.12, 0.08, 1 },
    inkFaded = { 0.4, 0.35, 0.25, 1 },

    -- Health/Power
    health = { 0.6, 0.1, 0.1, 1 },      -- Blood red
    mana = { 0.2, 0.3, 0.5, 1 },        -- Ink blue
    energy = { 0.9, 0.8, 0.3, 1 },      -- Gold
    rage = { 0.8, 0.2, 0.2, 1 },        -- Deep red
    focus = { 0.7, 0.5, 0.3, 1 },       -- Brown

    -- Lunar theme
    moonSilver = { 0.75, 0.78, 0.85, 1 },   -- Moonlight
    nightPurple = { 0.25, 0.2, 0.4, 1 },    -- Night sky
    starGold = { 0.9, 0.8, 0.5, 1 },        -- Starlight
    lunarGlow = { 0.6, 0.7, 0.9, 0.5 },     -- Moon glow

    -- UI elements
    border = { 0.1, 0.1, 0.1, 1 },
    backdrop = { 0.05, 0.05, 0.05, 0.9 },
}

-- Current tokens (will be updated based on phase)
LunarUI.tokens = {}

--[[
    Get tokens for a specific phase
    @param phase string - Phase name (NEW, WAXING, FULL, WANING)
    @return table - Token values
]]
function LunarUI:GetTokensForPhase(phase)
    local db = self.db and self.db.profile and self.db.profile.tokens
    if db and db[phase] then
        return db[phase]
    end
    return DEFAULT_TOKENS[phase] or DEFAULT_TOKENS.NEW
end

--[[
    Get current tokens based on current phase
    @return table - Current token values
]]
function LunarUI:GetTokens()
    local phase = self:GetPhase()
    return self:GetTokensForPhase(phase)
end

--[[
    Update current tokens when phase changes
    Called by PhaseManager
]]
function LunarUI:UpdateTokens()
    self.tokens = self:GetTokens()
end

--[[
    Apply tokens to a frame
    @param frame Frame - The frame to apply tokens to
    @param tokens table (optional) - Specific tokens to use
]]
function LunarUI:ApplyTokensToFrame(frame, tokens)
    tokens = tokens or self:GetTokens()

    if not frame then return end
    if not tokens then return end

    -- Apply alpha (Fix #11: type check)
    if tokens.alpha and type(tokens.alpha) == "number" then
        frame:SetAlpha(tokens.alpha)
    end

    -- Apply scale (Fix #11: type check)
    if tokens.scale and type(tokens.scale) == "number" then
        frame:SetScale(tokens.scale)
    end
end

--[[
    Interpolate between two token sets (for smooth transitions)
    @param from table - Starting tokens
    @param to table - Target tokens
    @param progress number - 0 to 1
    @return table - Interpolated tokens
]]
function LunarUI:InterpolateTokens(from, to, progress)
    local result = {}
    -- Fix #32: Handle edge cases when from is nil or empty
    from = from or {}
    to = to or {}

    for key, toValue in pairs(to) do
        -- Fix #32: Safely get from value, default to toValue if nil
        local fromValue = from[key]
        if fromValue == nil then
            fromValue = toValue
        end

        if type(toValue) == "number" and type(fromValue) == "number" then
            result[key] = fromValue + (toValue - fromValue) * progress
        else
            result[key] = toValue
        end
    end
    return result
end

-- Export defaults for database
LunarUI.DEFAULT_TOKENS = DEFAULT_TOKENS
