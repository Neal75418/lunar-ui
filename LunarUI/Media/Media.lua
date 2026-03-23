---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
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
if not LSM then
    return
end

--------------------------------------------------------------------------------
-- Media Paths
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Texture Definitions
--------------------------------------------------------------------------------

-- Effective textures: built-in paths used at runtime
local TEXTURES = {
    -- Status bars
    flat = "Interface\\Buttons\\WHITE8x8",
    gradient = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    smooth = "Interface\\TARGETINGFRAME\\UI-StatusBar",

    -- Borders
    borderThin = "Interface\\Buttons\\WHITE8x8",
    borderInk = "Interface\\Buttons\\WHITE8x8",
    borderGlow = "Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64",

    -- Backgrounds
    parchment = "Interface\\ACHIEVEMENTFRAME\\UI-Achievement-Parchment-Horizontal",
    dark = "Interface\\Buttons\\WHITE8x8",

    -- Effects
    glow = "Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64",
    spark = "Interface\\Cooldown\\star4",
}

--------------------------------------------------------------------------------
-- Color Palettes
--------------------------------------------------------------------------------

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

    -- Custom fonts: placeholder for future custom font
    -- lunar = "Interface\\AddOns\\LunarUI\\Media\\Fonts\\LunarFont.ttf",
}

--------------------------------------------------------------------------------
-- Media Registration
--------------------------------------------------------------------------------

local function RegisterMedia()
    -- Register status bar textures
    LSM:Register("statusbar", "Lunar Flat", TEXTURES.flat)
    LSM:Register("statusbar", "Lunar Gradient", TEXTURES.gradient)
    LSM:Register("statusbar", "Lunar Smooth", TEXTURES.smooth)

    -- Register border textures
    LSM:Register("border", "Lunar Thin", TEXTURES.borderThin)
    LSM:Register("border", "Lunar Ink", TEXTURES.borderInk)
    LSM:Register("border", "Lunar Glow", TEXTURES.borderGlow)

    -- Register background textures
    LSM:Register("background", "Lunar Dark", TEXTURES.dark)
    LSM:Register("background", "Lunar Parchment", TEXTURES.parchment)

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

-- Get user-selected font from LSM (reads db.profile.style.font)
function LunarUI.GetSelectedFont()
    local db = LunarUI.GetModuleDB("style")
    local fontName = db and db.font
    if fontName and LSM then
        local ok, path = pcall(LSM.Fetch, LSM, "font", fontName)
        if ok and path then
            return path
        end
    end
    return FONTS.normal
end

--------------------------------------------------------------------------------
-- Font Registry — 統一字體管理
--------------------------------------------------------------------------------

local fontRegistry = setmetatable({}, { __mode = "k" }) -- weak keys：框架銷毀時自動回收

--- 設定 FontString 字體並自動註冊到 registry（供 ApplyFontSettings 批次更新）
---@param fs FontString|table
---@param size number
---@param flags string|nil
function LunarUI.SetFont(fs, size, flags)
    if not fs or not fs.SetFont then
        return
    end
    fs:SetFont(LunarUI.GetSelectedFont(), size, flags or "")
    fontRegistry[fs] = true
end

--- 手動註冊已存在的 FontString（不重新設定字體）
function LunarUI.RegisterFontString(fs)
    if fs and fs.SetFont then
        fontRegistry[fs] = true
    end
end

--- 批次更新所有已註冊 FontString 的字體路徑（保留各自的 size 和 flags）
function LunarUI:ApplyFontSettings()
    local font = LunarUI.GetSelectedFont()
    for fs in pairs(fontRegistry) do
        if fs and fs.GetFont and fs.SetFont then
            local _, size, flags = fs:GetFont()
            if size then
                fs:SetFont(font, size, flags)
            end
        end
    end
end

-- Get user-selected statusbar texture from LSM (reads db.profile.style.statusBarTexture)
function LunarUI.GetSelectedStatusBarTexture()
    local db = LunarUI.GetModuleDB("style")
    local texName = db and db.statusBarTexture
    if texName and LSM then
        local ok, path = pcall(LSM.Fetch, LSM, "statusbar", texName)
        if ok and path then
            return path
        end
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

-- Register media on load
hooksecurefunc(LunarUI, "OnInitialize", function()
    RegisterMedia()
end)
