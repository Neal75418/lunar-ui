--[[
    LunarUI - Media
    Shared visual resources and helper functions
    Fix #102: Consolidate duplicated backdrop creation code
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- Shared Backdrop Template
--------------------------------------------------------------------------------

-- Standard backdrop template used throughout LunarUI
LunarUI.backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Default backdrop colors
LunarUI.backdropColors = {
    background = { 0.05, 0.05, 0.05, 0.9 },
    border = { 0.15, 0.12, 0.08, 1 },
    borderGold = { 0.4, 0.35, 0.2, 1 },
}

--------------------------------------------------------------------------------
-- Shared Textures
--------------------------------------------------------------------------------

LunarUI.textures = {
    statusBar = "Interface\\Buttons\\WHITE8x8",
    blank = "Interface\\Buttons\\WHITE8x8",
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

--[[
    Create a styled backdrop frame
    @param parent Frame - Parent frame
    @param options table (optional) - Override default options
        - bgColor table - {r, g, b, a} background color
        - borderColor table - {r, g, b, a} border color
        - frameLevel number - Frame level offset (default: parent - 1)
    @return Frame - The backdrop frame
]]
function LunarUI:CreateStyledBackdrop(parent, options)
    options = options or {}

    local backdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    backdrop:SetAllPoints()

    -- Set frame level
    local level = options.frameLevel or math.max(parent:GetFrameLevel() - 1, 0)
    backdrop:SetFrameLevel(level)

    -- Apply backdrop template
    backdrop:SetBackdrop(self.backdropTemplate)

    -- Apply colors
    local bgColor = options.bgColor or self.backdropColors.background
    local borderColor = options.borderColor or self.backdropColors.border

    backdrop:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    backdrop:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

    return backdrop
end

--[[
    Create a styled border for a button/item slot
    @param parent Frame - Parent frame (usually a button)
    @param options table (optional) - Override default options
    @return Frame - The border frame
]]
function LunarUI:CreateStyledBorder(parent, options)
    options = options or {}

    local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop(self.backdropTemplate)
    border:SetBackdropColor(0, 0, 0, 0)

    local borderColor = options.borderColor or self.backdropColors.border
    border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)

    -- Set frame level above parent
    local levelOffset = options.levelOffset or 1
    border:SetFrameLevel(parent:GetFrameLevel() + levelOffset)

    return border
end

--[[
    Style an icon (crop edges, set proper draw layer)
    @param icon Texture - The icon texture
    @param inset number (optional) - Inset from edges (default: 1)
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
    Get a quality color for an item
    @param quality number - Item quality (0-8)
    @return table - {r, g, b} color values
]]
function LunarUI:GetQualityColor(quality)
    local colors = {
        [0] = { 0.62, 0.62, 0.62 }, -- Poor (gray)
        [1] = { 1.00, 1.00, 1.00 }, -- Common (white)
        [2] = { 0.12, 1.00, 0.00 }, -- Uncommon (green)
        [3] = { 0.00, 0.44, 0.87 }, -- Rare (blue)
        [4] = { 0.64, 0.21, 0.93 }, -- Epic (purple)
        [5] = { 1.00, 0.50, 0.00 }, -- Legendary (orange)
        [6] = { 0.90, 0.80, 0.50 }, -- Artifact (gold)
        [7] = { 0.00, 0.80, 0.98 }, -- Heirloom (light blue)
        [8] = { 0.00, 0.80, 1.00 }, -- WoW Token
    }

    return colors[quality] or colors[1]
end
