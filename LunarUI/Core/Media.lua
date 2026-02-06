---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 媒體資源
    共用視覺資源與輔助函數
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 共用背景模板
--------------------------------------------------------------------------------

-- LunarUI 通用背景模板
LunarUI.backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- 圖示用背景模板（無內縮，適合小圖示/按鈕）
LunarUI.iconBackdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 共用減益類型顏色（WoW 12.0 中 DebuffTypeColor 可能不存在）
--------------------------------------------------------------------------------

LunarUI.DEBUFF_TYPE_COLORS = _G.DebuffTypeColor or {
    none    = { r = 0.8, g = 0.0, b = 0.0 },
    Magic   = { r = 0.2, g = 0.6, b = 1.0 },
    Curse   = { r = 0.6, g = 0.0, b = 1.0 },
    Disease = { r = 0.6, g = 0.4, b = 0.0 },
    Poison  = { r = 0.0, g = 0.6, b = 0.0 },
    [""]    = { r = 0.8, g = 0.0, b = 0.0 },
}

--------------------------------------------------------------------------------
-- 共用材質
--------------------------------------------------------------------------------

LunarUI.textures = {
    statusBar = "Interface\\TargetingFrame\\UI-StatusBar",
    blank = "Interface\\Buttons\\WHITE8x8",
    glow = "Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64",
}

--- 取得使用者選定的狀態條材質（若未配置則回傳預設值）
function LunarUI.GetSelectedStatusBarTexture()
    local db = LunarUI.db and LunarUI.db.profile
    if db and db.statusBarTexture then
        return db.statusBarTexture
    end
    return LunarUI.textures.statusBar
end

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

--[[
    風格化圖示（裁切邊緣、設定繪製層）
    @param icon 圖示材質
    @param inset 邊緣內縮（預設：1）
]]
function LunarUI.StyleIcon(icon, inset)
    if not icon then return end

    inset = inset or 1

    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetDrawLayer("ARTWORK")
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", -inset, inset)
end

--[[
    物品品質顏色（集中定義，避免重複）
    Usage: local color = LunarUI.QUALITY_COLORS[quality]
           local color = LunarUI.GetQualityColor(quality)
]]
LunarUI.QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },  -- 粗糙（Poor）
    [1] = { 1.00, 1.00, 1.00 },  -- 普通（Common）
    [2] = { 0.12, 1.00, 0.00 },  -- 優秀（Uncommon）
    [3] = { 0.00, 0.44, 0.87 },  -- 精良（Rare）
    [4] = { 0.64, 0.21, 0.93 },  -- 史詩（Epic）
    [5] = { 1.00, 0.50, 0.00 },  -- 傳說（Legendary）
    [6] = { 0.90, 0.80, 0.50 },  -- 神器（Artifact）
    [7] = { 0.00, 0.80, 0.98 },  -- 傳家寶（Heirloom）
    [8] = { 0.00, 0.80, 1.00 },  -- WoW 代幣（Token）
}

--[[
    取得物品品質顏色
    @param quality 物品品質（0-8）
    @return table 顏色值 {r, g, b}
]]
function LunarUI.GetQualityColor(quality)
    return LunarUI.QUALITY_COLORS[quality] or LunarUI.QUALITY_COLORS[1]
end

--------------------------------------------------------------------------------
-- 光環按鈕風格化
--------------------------------------------------------------------------------

--[[
    統一風格化光環按鈕（背景、圖示裁切、計數字型）
    @param button Frame - 光環按鈕框架

    Usage:
        LunarUI.StyleAuraButton(auraButton)
]]
--[[
    建立共用背景框架（backdrop）
    @param frame Frame - 父框架
    @param options table|nil - 可選設定
        - inset number: 邊框外擴像素（預設 0，使用 SetAllPoints）
        - borderColor table: {r, g, b, a} 邊框顏色（預設 Colors.border）
    @return Frame - 背景框架

    Usage:
        LunarUI.CreateBackdrop(healthBar)
        LunarUI.CreateBackdrop(nameplate, { inset = 1, borderColor = C.borderSubtle })
]]
function LunarUI.CreateBackdrop(frame, options)
    options = options or {}
    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    if options.inset then
        backdrop:SetPoint("TOPLEFT", -options.inset, options.inset)
        backdrop:SetPoint("BOTTOMRIGHT", options.inset, -options.inset)
    else
        backdrop:SetAllPoints()
    end
    backdrop:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    backdrop:SetBackdrop(LunarUI.backdropTemplate)
    backdrop:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    local border = options.borderColor or C.border
    backdrop:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    frame.Backdrop = backdrop
    return backdrop
end

function LunarUI.StyleAuraButton(button)
    if BackdropTemplateMixin then
        Mixin(button, BackdropTemplateMixin)
        button:OnBackdropLoaded()
        button:SetBackdrop(LunarUI.backdropTemplate)
    end
    if button.Icon then
        button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if button.Count then
        button.Count:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    end
end
