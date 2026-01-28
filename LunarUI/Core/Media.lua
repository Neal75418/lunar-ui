---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field
--[[
    LunarUI - 媒體資源
    共用視覺資源與輔助函數
]]

local ADDON_NAME, Engine = ...
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

-- 預設背景顏色
LunarUI.backdropColors = {
    background = { 0.05, 0.05, 0.05, 0.9 },
    border = { 0.15, 0.12, 0.08, 1 },
    borderGold = { 0.4, 0.35, 0.2, 1 },
}

--------------------------------------------------------------------------------
-- 共用材質
--------------------------------------------------------------------------------

LunarUI.textures = {
    statusBar = "Interface\\Buttons\\WHITE8x8",
    blank = "Interface\\Buttons\\WHITE8x8",
}

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

--[[
    建立風格化背景框架
    @param parent 父框架
    @param options 覆蓋預設選項（可選）
        - bgColor 背景顏色 {r, g, b, a}
        - borderColor 邊框顏色 {r, g, b, a}
        - frameLevel 框架層級偏移（預設：父框架 - 1）
    @return Frame 背景框架
]]
function LunarUI:CreateStyledBackdrop(parent, options)
    options = options or {}

    local backdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    backdrop:SetAllPoints()

    -- 設定框架層級
    local level = options.frameLevel or math.max(parent:GetFrameLevel() - 1, 0)
    backdrop:SetFrameLevel(level)

    -- 套用背景模板
    backdrop:SetBackdrop(self.backdropTemplate)

    -- 套用顏色
    local bgColor = options.bgColor or self.backdropColors.background
    local borderColor = options.borderColor or self.backdropColors.border

    backdrop:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    backdrop:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

    return backdrop
end

--[[
    為按鈕或物品格建立風格化邊框
    @param parent 父框架（通常是按鈕）
    @param options 覆蓋預設選項（可選）
    @return Frame 邊框框架
]]
function LunarUI:CreateStyledBorder(parent, options)
    options = options or {}

    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop(self.backdropTemplate)
    border:SetBackdropColor(0, 0, 0, 0)

    local borderColor = options.borderColor or self.backdropColors.border
    border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

    -- 設定框架層級在父框架之上
    local levelOffset = options.levelOffset or 1
    border:SetFrameLevel(parent:GetFrameLevel() + levelOffset)

    return border
end

--[[
    風格化圖示（裁切邊緣、設定繪製層）
    @param icon 圖示材質
    @param inset 邊緣內縮（預設：1）
]]
function LunarUI:StyleIcon(icon, inset)
    if not icon then return end

    inset = inset or 1

    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetDrawLayer("ARTWORK")
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", -inset, inset)
end

--[[
    取得物品品質顏色
    @param quality 物品品質（0-8）
    @return table 顏色值 {r, g, b}
]]
function LunarUI:GetQualityColor(quality)
    local colors = {
        [0] = { 0.62, 0.62, 0.62 },  -- 粗糙
        [1] = { 1.00, 1.00, 1.00 },  -- 普通
        [2] = { 0.12, 1.00, 0.00 },  -- 優秀
        [3] = { 0.00, 0.44, 0.87 },  -- 精良
        [4] = { 0.64, 0.21, 0.93 },  -- 史詩
        [5] = { 1.00, 0.50, 0.00 },  -- 傳說
        [6] = { 0.90, 0.80, 0.50 },  -- 神器
        [7] = { 0.00, 0.80, 0.98 },  -- 傳家寶
        [8] = { 0.00, 0.80, 1.00 },  -- WoW 代幣
    }

    return colors[quality] or colors[1]
end
