---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Media Registration
    Register custom textures, fonts, and sounds with LibSharedMedia

    Design Philosophy:
    - Moon-inspired: soft glows, arcs, incomplete shapes
    - Restrained: low saturation, subtle details
    - Functional: clarity over decoration
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local LSM = LibStub("LibSharedMedia-3.0", true)
if not LSM then return end

--------------------------------------------------------------------------------
-- Media Paths
--------------------------------------------------------------------------------

local MEDIA_PATH = "Interface\\AddOns\\LunarUI\\Media\\"
local TEXTURE_PATH = MEDIA_PATH .. "Textures\\"
local FONT_PATH = MEDIA_PATH .. "Fonts\\"
local _SOUND_PATH = MEDIA_PATH .. "Sounds\\"  -- Reserved for future use

--------------------------------------------------------------------------------
-- Texture Definitions
--------------------------------------------------------------------------------

-- Core textures (using built-in WoW textures as fallbacks until custom ones are made)
local TEXTURES = {
    -- Status bars
    flat = "Interface\\Buttons\\WHITE8x8",
    gradient = "Interface\\AddOns\\LunarUI\\Media\\Textures\\LunarGradient",
    smooth = "Interface\\AddOns\\LunarUI\\Media\\Textures\\LunarSmooth",

    -- Borders
    borderThin = "Interface\\Buttons\\WHITE8x8",
    borderInk = "Interface\\AddOns\\LunarUI\\Media\\Textures\\InkBorder",
    borderGlow = "Interface\\AddOns\\LunarUI\\Media\\Textures\\GlowBorder",

    -- Backgrounds
    parchment = "Interface\\AddOns\\LunarUI\\Media\\Textures\\Parchment",
    dark = "Interface\\Buttons\\WHITE8x8",

    -- Effects
    glow = "Interface\\AddOns\\LunarUI\\Media\\Textures\\Glow",
    spark = "Interface\\AddOns\\LunarUI\\Media\\Textures\\Spark",
}

-- Fallback textures (use WoW built-in until custom assets are ready)
local TEXTURE_FALLBACKS = {
    gradient = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    smooth = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    borderInk = "Interface\\Buttons\\WHITE8x8",
    borderGlow = "Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64",
    parchment = "Interface\\ACHIEVEMENTFRAME\\UI-Achievement-Parchment-Horizontal",
    glow = "Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64",
    spark = "Interface\\Cooldown\\star4",
}

--------------------------------------------------------------------------------
-- Color Palettes
--------------------------------------------------------------------------------

-- Lunar color palette (擴充 Tokens.lua 定義的 LunarUI.Colors)
-- 基礎 design tokens（bg, border, text 等）已在 Core/Tokens.lua 定義
-- 此處僅新增 Media 專用的延伸色彩
local Colors = LunarUI.Colors
Colors.moonlight       = { 0.85, 0.90, 1.00, 1.0 }      -- Soft blue-white
Colors.moonGlow        = { 0.70, 0.80, 0.95, 0.8 }      -- Subtle glow
Colors.nightSky        = { 0.08, 0.08, 0.12, 0.95 }     -- Dark background
Colors.borderHighlight = { 0.40, 0.45, 0.55, 1.0 }      -- Highlighted border
Colors.text            = { 0.90, 0.90, 0.88, 1.0 }      -- Off-white text
Colors.healthLow       = { 0.75, 0.25, 0.20, 1.0 }      -- Muted red

-- Class colors (slightly desaturated for Lunar theme)
Colors.classColors = {
    WARRIOR = { 0.78, 0.61, 0.43 },
    PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1.00, 0.96, 0.41 },
    PRIEST = { 1.00, 1.00, 1.00 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    MAGE = { 0.41, 0.80, 0.94 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    MONK = { 0.00, 0.78, 0.59 },
    DRUID = { 1.00, 0.49, 0.04 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
    EVOKER = { 0.20, 0.58, 0.50 },
}

--------------------------------------------------------------------------------
-- Font Definitions
--------------------------------------------------------------------------------

-- Preferred fonts (custom or system)
local FONTS = {
    -- Main UI font
    normal = "Fonts\\FRIZQT__.TTF",

    -- Number font (for health, damage, etc.)
    number = "Fonts\\FRIZQT__.TTF",

    -- Header font
    header = "Fonts\\MORPHEUS.TTF",

    -- Custom fonts (if installed)
    lunar = FONT_PATH .. "LunarFont.ttf",
}

-- Font sizes based on context
LunarUI.FontSizes = {
    tiny = 9,
    small = 10,
    normal = 12,
    medium = 14,
    large = 16,
    huge = 20,
    header = 24,
}

--------------------------------------------------------------------------------
-- Media Registration
--------------------------------------------------------------------------------

local function RegisterMedia()
    -- Register status bar textures
    LSM:Register("statusbar", "Lunar Flat", TEXTURES.flat)
    LSM:Register("statusbar", "Lunar Gradient", TEXTURE_FALLBACKS.gradient)
    LSM:Register("statusbar", "Lunar Smooth", TEXTURE_FALLBACKS.smooth)

    -- Register border textures
    LSM:Register("border", "Lunar Thin", TEXTURES.borderThin)
    LSM:Register("border", "Lunar Ink", TEXTURE_FALLBACKS.borderInk)
    LSM:Register("border", "Lunar Glow", TEXTURE_FALLBACKS.borderGlow)

    -- Register background textures
    LSM:Register("background", "Lunar Dark", TEXTURES.dark)
    LSM:Register("background", "Lunar Parchment", TEXTURE_FALLBACKS.parchment)

    -- Register fonts
    LSM:Register("font", "Lunar Normal", FONTS.normal)
    LSM:Register("font", "Lunar Number", FONTS.number)
    LSM:Register("font", "Lunar Header", FONTS.header)

    -- Set defaults
    LSM:SetDefault("statusbar", "Lunar Flat")
    LSM:SetDefault("border", "Lunar Thin")
    LSM:SetDefault("background", "Lunar Dark")
    LSM:SetDefault("font", "Lunar Normal")
end

--------------------------------------------------------------------------------
-- Texture Getter
--------------------------------------------------------------------------------

-- Fix #7: Improved GetTexture logic with clear fallback behavior
-- Get texture path with fallback support
function LunarUI.GetTexture(name)
    local path = TEXTURES[name]
    if not path then
        return TEXTURES.flat
    end

    -- Check if this is a custom LunarUI texture path (contains "LunarUI")
    -- Custom textures are not yet created, so use fallbacks
    if path:find("LunarUI") then
        -- Use fallback for custom textures until assets are made
        if TEXTURE_FALLBACKS[name] then
            return TEXTURE_FALLBACKS[name]
        end
    end

    -- Return the texture path (built-in textures like WHITE8x8)
    return path
end

-- Get font path
function LunarUI.GetFont(name)
    return FONTS[name] or FONTS.normal
end

-- Get user-selected font from LSM (reads db.profile.style.font)
function LunarUI.GetSelectedFont()
    local db = LunarUI.db and LunarUI.db.profile
    local fontName = db and db.style and db.style.font
    if fontName and LSM then
        local ok, path = pcall(LSM.Fetch, LSM, "font", fontName)
        if ok and path then return path end
    end
    return FONTS.normal
end

-- Get user-selected font size from db
function LunarUI.GetSelectedFontSize()
    local db = LunarUI.db and LunarUI.db.profile
    return db and db.style and db.style.fontSize or 12
end

-- Get user-selected statusbar texture from LSM (reads db.profile.style.statusBarTexture)
function LunarUI.GetSelectedStatusBarTexture()
    local db = LunarUI.db and LunarUI.db.profile
    local texName = db and db.style and db.style.statusBarTexture
    if texName and LSM then
        local ok, path = pcall(LSM.Fetch, LSM, "statusbar", texName)
        if ok and path then return path end
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

-- Get color by name
function LunarUI:GetColor(name)
    return self.Colors[name]
end

--------------------------------------------------------------------------------
-- Backdrop Templates
--------------------------------------------------------------------------------

-- Standard Lunar backdrop
LunarUI.Backdrops = {
    default = {
        bgFile = TEXTURES.flat,
        edgeFile = TEXTURES.borderThin,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    },

    thin = {
        bgFile = TEXTURES.flat,
        edgeFile = TEXTURES.borderThin,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    },

    panel = {
        bgFile = TEXTURES.flat,
        edgeFile = TEXTURES.borderThin,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    },

    tooltip = {
        bgFile = TEXTURES.flat,
        edgeFile = TEXTURES.borderThin,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    },

    glow = {
        bgFile = nil,
        edgeFile = TEXTURE_FALLBACKS.glow,
        edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    },
}

-- Get backdrop colors
function LunarUI:GetBackdropColors()
    return self.Colors.nightSky, self.Colors.border
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

-- Register media on load
hooksecurefunc(LunarUI, "OnInitialize", function()
    RegisterMedia()
end)

-- Export paths for direct access
LunarUI.MediaPath = MEDIA_PATH
LunarUI.TexturePath = TEXTURE_PATH
LunarUI.FontPath = FONT_PATH
