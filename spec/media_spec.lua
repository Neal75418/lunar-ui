--[[
    Unit tests for LunarUI/Core/Media.lua
    Tests backdrop creation, application, aura button styling, and constant tables
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
local MockFrame = {}
MockFrame.__index = MockFrame

local lastBackdrop, lastBGColor, lastBorderColor
function MockFrame:SetBackdrop(bd)
    lastBackdrop = bd
end
function MockFrame:SetBackdropColor(r, g, b, a)
    lastBGColor = { r, g, b, a }
end
function MockFrame:SetBackdropBorderColor(r, g, b, a)
    lastBorderColor = { r, g, b, a }
end
function MockFrame:SetAllPoints() end
function MockFrame:SetPoint() end
function MockFrame:GetFrameLevel()
    return 2
end
function MockFrame:SetFrameLevel() end
function MockFrame:SetTexCoord() end
function MockFrame:OnBackdropLoaded() end

_G.BackdropTemplateMixin = { OnBackdropLoaded = function() end }
_G.Mixin = function(frame, mixin)
    for k, v in pairs(mixin) do
        frame[k] = v
    end
end

_G.CreateFrame = function()
    return setmetatable({}, { __index = MockFrame })
end

local LunarUI = {
    Colors = {
        bg = { 0.05, 0.05, 0.05, 0.8 },
        border = { 0.3, 0.3, 0.4, 1 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    SetFont = function() end,
    RegisterModule = function() end,
}

loader.loadAddonFile("LunarUI/Core/Media.lua", LunarUI)

--------------------------------------------------------------------------------
-- Constants / Tables
--------------------------------------------------------------------------------

describe("Media constants", function()
    it("defines backdropTemplate with required fields", function()
        assert.truthy(LunarUI.backdropTemplate)
        assert.truthy(LunarUI.backdropTemplate.bgFile)
        assert.truthy(LunarUI.backdropTemplate.edgeFile)
        assert.is_number(LunarUI.backdropTemplate.edgeSize)
    end)

    it("defines iconBackdropTemplate without insets", function()
        assert.truthy(LunarUI.iconBackdropTemplate)
        assert.truthy(LunarUI.iconBackdropTemplate.bgFile)
        assert.is_nil(LunarUI.iconBackdropTemplate.insets)
    end)

    it("defines textures table", function()
        assert.truthy(LunarUI.textures)
        assert.truthy(LunarUI.textures.statusBar)
        assert.truthy(LunarUI.textures.blank)
        assert.truthy(LunarUI.textures.glow)
    end)
end)

describe("QUALITY_COLORS", function()
    it("has entries for quality indices 0-8", function()
        for i = 0, 8 do
            assert.truthy(LunarUI.QUALITY_COLORS[i], "Missing quality " .. i)
            assert.equals(3, #LunarUI.QUALITY_COLORS[i])
        end
    end)

    it("has Poor quality as grey", function()
        local c = LunarUI.QUALITY_COLORS[0]
        assert.is_true(c[1] < 0.7 and c[2] < 0.7 and c[3] < 0.7)
    end)

    it("has Legendary quality as orange", function()
        local c = LunarUI.QUALITY_COLORS[5]
        assert.is_true(c[1] > 0.9 and c[2] > 0.3 and c[3] < 0.2)
    end)
end)

describe("DEBUFF_TYPE_COLORS", function()
    it("has standard debuff types", function()
        local dtc = LunarUI.DEBUFF_TYPE_COLORS
        assert.truthy(dtc)
        assert.truthy(dtc.Magic)
        assert.truthy(dtc.Curse)
        assert.truthy(dtc.Disease)
        assert.truthy(dtc.Poison)
    end)

    it("each color has r, g, b fields", function()
        for _, color in pairs(LunarUI.DEBUFF_TYPE_COLORS) do
            assert.is_number(color.r)
            assert.is_number(color.g)
            assert.is_number(color.b)
        end
    end)
end)

--------------------------------------------------------------------------------
-- CreateBackdrop
--------------------------------------------------------------------------------

describe("CreateBackdrop", function()
    before_each(function()
        lastBackdrop = nil
        lastBGColor = nil
        lastBorderColor = nil
    end)

    it("returns a frame", function()
        local parent = setmetatable({}, { __index = MockFrame })
        local backdrop = LunarUI.CreateBackdrop(parent)
        assert.truthy(backdrop)
    end)

    it("sets parent.Backdrop reference", function()
        local parent = setmetatable({}, { __index = MockFrame })
        local backdrop = LunarUI.CreateBackdrop(parent)
        assert.equals(backdrop, parent.Backdrop)
    end)

    it("applies bg and border colors from Colors", function()
        local parent = setmetatable({}, { __index = MockFrame })
        LunarUI.CreateBackdrop(parent)
        assert.truthy(lastBGColor)
        assert.near(0.05, lastBGColor[1], 0.01)
        assert.truthy(lastBorderColor)
        assert.near(0.3, lastBorderColor[1], 0.01)
    end)

    it("uses custom borderColor when provided", function()
        local parent = setmetatable({}, { __index = MockFrame })
        LunarUI.CreateBackdrop(parent, { borderColor = { 1, 0, 0, 1 } })
        assert.near(1, lastBorderColor[1], 0.01)
        assert.near(0, lastBorderColor[2], 0.01)
    end)
end)

--------------------------------------------------------------------------------
-- ApplyBackdrop
--------------------------------------------------------------------------------

describe("ApplyBackdrop", function()
    before_each(function()
        lastBackdrop = nil
        lastBGColor = nil
        lastBorderColor = nil
    end)

    it("applies backdrop template to frame", function()
        local frame = setmetatable({}, { __index = MockFrame })
        LunarUI.ApplyBackdrop(frame)
        assert.equals(LunarUI.backdropTemplate, lastBackdrop)
    end)

    it("uses custom colors when provided", function()
        local frame = setmetatable({}, { __index = MockFrame })
        LunarUI.ApplyBackdrop(frame, nil, { 1, 0, 0, 1 }, { 0, 1, 0, 1 })
        assert.near(1, lastBGColor[1], 0.01)
        assert.near(0, lastBorderColor[1], 0.01)
        assert.near(1, lastBorderColor[2], 0.01)
    end)

    it("defaults alpha to 1 when not specified", function()
        local frame = setmetatable({}, { __index = MockFrame })
        LunarUI.ApplyBackdrop(frame, nil, { 0.5, 0.5, 0.5 })
        assert.near(1, lastBGColor[4], 0.01)
    end)
end)

--------------------------------------------------------------------------------
-- StyleAuraButton
--------------------------------------------------------------------------------

describe("StyleAuraButton", function()
    it("applies backdrop to button with BackdropTemplateMixin", function()
        local button = setmetatable({}, { __index = MockFrame })
        LunarUI.StyleAuraButton(button)
        assert.truthy(lastBackdrop)
    end)

    it("sets icon TexCoord if Icon exists", function()
        local texCoordCalled = false
        local button = setmetatable({
            Icon = setmetatable({
                SetTexCoord = function()
                    texCoordCalled = true
                end,
            }, { __index = MockFrame }),
        }, { __index = MockFrame })
        LunarUI.StyleAuraButton(button)
        assert.is_true(texCoordCalled)
    end)

    it("sets Count font if Count exists", function()
        local fontCalled = false
        local origSetFont = LunarUI.SetFont
        LunarUI.SetFont = function()
            fontCalled = true
        end
        local button = setmetatable({
            Count = setmetatable({}, { __index = MockFrame }),
        }, { __index = MockFrame })
        LunarUI.StyleAuraButton(button)
        assert.is_true(fontCalled)
        LunarUI.SetFont = origSetFont
    end)
end)
