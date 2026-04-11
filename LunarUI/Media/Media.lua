---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch
--[[
    LunarUI - 媒體註冊
    將自訂材質、字體與音效註冊到 LibSharedMedia

    設計理念：
    - 月相意象：柔和光暈、弧線、不完整的形狀
    - 克制內斂：低飽和度、細微的細節
    - 功能優先：清晰勝過裝飾
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local LSM = LibStub("LibSharedMedia-3.0", true)
if not LSM then
    return
end

--------------------------------------------------------------------------------
-- 媒體路徑
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 材質定義
--------------------------------------------------------------------------------

-- 運行時使用的內建材質路徑
local TEXTURES = {
    -- StatusBar 材質
    flat = "Interface\\Buttons\\WHITE8x8",
    gradient = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    smooth = "Interface\\TARGETINGFRAME\\UI-StatusBar",

    -- 邊框材質
    borderThin = "Interface\\Buttons\\WHITE8x8",
    borderInk = "Interface\\Buttons\\WHITE8x8",
    borderGlow = "Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64",

    -- 背景材質
    parchment = "Interface\\ACHIEVEMENTFRAME\\UI-Achievement-Parchment-Horizontal",
    dark = "Interface\\Buttons\\WHITE8x8",
}

--------------------------------------------------------------------------------
-- 色彩調色盤
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 字體定義
--------------------------------------------------------------------------------

-- 偏好字體（自訂或系統內建）
local FONTS = {
    -- 主要 UI 字體
    normal = "Fonts\\FRIZQT__.TTF",

    -- 數字字體（血量、傷害等）
    number = "Fonts\\FRIZQT__.TTF",

    -- 標題字體
    header = "Fonts\\MORPHEUS.TTF",

    -- 自訂字體：未來自訂字體預留位置
    -- lunar = "Interface\\AddOns\\LunarUI\\Media\\Fonts\\LunarFont.ttf",
}

--------------------------------------------------------------------------------
-- 媒體註冊
--------------------------------------------------------------------------------

local function RegisterMedia()
    -- 註冊 StatusBar 材質
    LSM:Register("statusbar", "Lunar Flat", TEXTURES.flat)
    LSM:Register("statusbar", "Lunar Gradient", TEXTURES.gradient)
    LSM:Register("statusbar", "Lunar Smooth", TEXTURES.smooth)

    -- 註冊邊框材質
    LSM:Register("border", "Lunar Thin", TEXTURES.borderThin)
    LSM:Register("border", "Lunar Ink", TEXTURES.borderInk)
    LSM:Register("border", "Lunar Glow", TEXTURES.borderGlow)

    -- 註冊背景材質
    LSM:Register("background", "Lunar Dark", TEXTURES.dark)
    LSM:Register("background", "Lunar Parchment", TEXTURES.parchment)

    -- 註冊字體
    LSM:Register("font", "Lunar Normal", FONTS.normal)
    LSM:Register("font", "Lunar Number", FONTS.number)
    LSM:Register("font", "Lunar Header", FONTS.header)

    -- 設定預設值
    LSM:SetDefault("statusbar", "Lunar Flat")
    LSM:SetDefault("border", "Lunar Thin")
    LSM:SetDefault("background", "Lunar Dark")
    LSM:SetDefault("font", "Lunar Normal")
end

--------------------------------------------------------------------------------
-- 材質取得
--------------------------------------------------------------------------------

-- 從 LSM 取得使用者選取的字體（讀取 db.profile.style.font）
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

-- 從 LSM 取得使用者選取的 StatusBar 材質（讀取 db.profile.style.statusBarTexture）
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
-- 初始化
--------------------------------------------------------------------------------

-- 載入時註冊媒體資源
hooksecurefunc(LunarUI, "OnInitialize", function()
    RegisterMedia()
end)
