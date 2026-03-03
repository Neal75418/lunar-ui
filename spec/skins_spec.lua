--[[
    Unit tests for LunarUI/Modules/Skins.lua
    Tests: CreateIconBorder, StripTextures, SetFont*, MarkSkinned, RegisterSkin,
           SkinScrollBar, SkinEditBox
]]

require("spec.wow_mock")
local loader = require("spec.loader")

local unpack = table.unpack or unpack -- luacheck: ignore 143

--------------------------------------------------------------------------------
-- Mock WoW frame API
--------------------------------------------------------------------------------

-- 模擬 FontString 物件
local function MockFontString()
    local fs = {
        _textColor = { 0, 0, 0, 1 },
        _text = "",
        _point = {},
    }
    function fs:SetTextColor(r, g, b, a)
        self._textColor = { r, g, b, a }
    end
    function fs:GetTextColor()
        return self._textColor[1], self._textColor[2], self._textColor[3], self._textColor[4]
    end
    function fs:SetText(t)
        self._text = t
    end
    function fs:SetPoint(...)
        self._point = { ... }
    end
    function fs:IsObjectType(t)
        return t == "FontString"
    end
    return fs
end

-- 模擬 Texture 物件
local function MockTexture(drawLayer)
    local tex = {
        _alpha = 1,
        _drawLayer = drawLayer or "BACKGROUND",
        _color = {},
    }
    function tex:SetAlpha(a)
        self._alpha = a
    end
    function tex:GetDrawLayer()
        return self._drawLayer
    end
    function tex:IsObjectType(t)
        return t == "Texture"
    end
    function tex:SetAllPoints() end
    function tex:SetColorTexture(r, g, b, a)
        self._color = { r, g, b, a }
    end
    function tex:SetHeight() end
    function tex:SetPoint() end
    return tex
end

-- 模擬框架物件
local function MockFrame(opts)
    opts = opts or {}
    local frame = {
        _points = {},
        _backdrop = nil,
        _backdropColor = {},
        _backdropBorderColor = {},
        _frameLevel = opts.frameLevel or 1,
        _scripts = {},
        _regions = opts.regions or {},
        _children = opts.children or {},
        _textures = {},
        _fontStrings = {},
        _size = { 0, 0 },
    }
    function frame:SetPoint(...)
        table.insert(self._points, { ... })
    end
    function frame:SetBackdrop(bd)
        self._backdrop = bd
    end
    function frame:SetBackdropColor(r, g, b, a)
        self._backdropColor = { r, g, b, a }
    end
    function frame:SetBackdropBorderColor(r, g, b, a)
        self._backdropBorderColor = { r, g, b, a }
    end
    function frame:GetFrameLevel()
        return self._frameLevel
    end
    function frame:SetFrameLevel(level)
        self._frameLevel = level
    end
    function frame:GetRegions()
        if #self._regions == 0 then
            return nil
        end
        return unpack(self._regions) -- luacheck: ignore 143
    end
    function frame:GetChildren()
        if #self._children == 0 then
            return nil
        end
        return unpack(self._children)
    end
    function frame:SetScript(name, fn)
        self._scripts[name] = fn
    end
    function frame:SetAllPoints() end
    function frame:GetObjectType()
        return "Frame"
    end
    function frame:RegisterEvent() end
    function frame:UnregisterAllEvents() end
    function frame:SetSize(w, h)
        self._size = { w, h }
    end
    function frame:CreateTexture(_name, layer)
        local tex = MockTexture(layer)
        table.insert(self._textures, tex)
        return tex
    end
    function frame:CreateFontString(_name, _layer)
        local fs = MockFontString()
        table.insert(self._fontStrings, fs)
        return fs
    end
    function frame:SetNormalTexture() end
    function frame:SetHighlightTexture() end
    function frame:SetPushedTexture() end
    function frame:SetDisabledTexture() end
    function frame:SetTextColor(r, g, b, a)
        self._textColor = { r, g, b, a }
    end
    return frame
end

_G.CreateFrame = function(_type, _name, _parent, _template)
    return MockFrame()
end

_G.BackdropTemplateMixin = {}

-- Skins.lua 需要的全域 API
_G.hooksecurefunc = function() end
_G.C_AddOns = {
    IsAddOnLoaded = function()
        return false
    end,
}
_G.C_Timer = {
    After = function(_delay, _fn) end,
}

--------------------------------------------------------------------------------
-- Load Skins.lua
--------------------------------------------------------------------------------

local LunarUI = {
    Colors = {
        border = { 0.3, 0.3, 0.3, 1 },
        background = { 0.1, 0.1, 0.1, 0.9 },
        bg = { 0.1, 0.1, 0.1 },
        bgButton = { 0.2, 0.2, 0.2, 0.8 },
        bgIcon = { 0.15, 0.15, 0.15, 0.9 },
        borderGold = { 0.8, 0.6, 0.2, 1 },
    },
    iconBackdropTemplate = {
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
    },
    backdropTemplate = {
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
    },
    db = nil,
}

function LunarUI:RegisterModule(_name, _callbacks) end
function LunarUI.SetFont(_fontString, _size, _flags) end
function LunarUI.ApplyBackdrop(_frame) end

local extraEngine = { L = {} }
loader.loadAddonFile("LunarUI/Modules/Skins.lua", LunarUI, extraEngine)

--------------------------------------------------------------------------------
-- CreateIconBorder
--------------------------------------------------------------------------------

describe("CreateIconBorder", function()
    it("creates border frame with default options", function()
        local parent = MockFrame()
        local border = LunarUI.CreateIconBorder(parent)
        assert.is_not_nil(border)
        assert.is_not_nil(parent._lunarBorder)
        assert.equals(border, parent._lunarBorder)
    end)

    it("returns nil for nil parent", function()
        assert.is_nil(LunarUI.CreateIconBorder(nil))
    end)

    it("returns nil when BackdropTemplateMixin is nil", function()
        local saved = _G.BackdropTemplateMixin
        _G.BackdropTemplateMixin = nil
        local parent = MockFrame()
        assert.is_nil(LunarUI.CreateIconBorder(parent))
        _G.BackdropTemplateMixin = saved
    end)

    it("prevents duplicate border creation", function()
        local parent = MockFrame()
        local first = LunarUI.CreateIconBorder(parent)
        assert.is_not_nil(first)
        local second = LunarUI.CreateIconBorder(parent)
        assert.is_nil(second)
    end)

    it("sets correct frame level (parent + 1)", function()
        local parent = MockFrame({ frameLevel = 5 })
        local border = LunarUI.CreateIconBorder(parent)
        assert.is_not_nil(border)
        assert.equals(6, border._frameLevel)
    end)

    it("applies custom color from options", function()
        local parent = MockFrame()
        local border = LunarUI.CreateIconBorder(parent, { color = { 1, 0, 0, 1 } })
        assert.is_not_nil(border)
        assert.same({ 1, 0, 0, 1 }, border._backdropBorderColor)
    end)

    it("uses default border color when no color option", function()
        local parent = MockFrame()
        local border = LunarUI.CreateIconBorder(parent)
        assert.is_not_nil(border)
        assert.same({ 0.3, 0.3, 0.3, 1 }, border._backdropBorderColor)
    end)

    it("sets backdrop to transparent background", function()
        local parent = MockFrame()
        local border = LunarUI.CreateIconBorder(parent)
        assert.is_not_nil(border)
        assert.same({ 0, 0, 0, 0 }, border._backdropColor)
    end)
end)

--------------------------------------------------------------------------------
-- StripTextures
--------------------------------------------------------------------------------

describe("StripTextures", function()
    it("hides BACKGROUND textures", function()
        local tex = MockTexture("BACKGROUND")
        local frame = MockFrame({ regions = { tex } })
        LunarUI.StripTextures(frame)
        assert.equals(0, tex._alpha)
    end)

    it("hides BORDER textures", function()
        local tex = MockTexture("BORDER")
        local frame = MockFrame({ regions = { tex } })
        LunarUI.StripTextures(frame)
        assert.equals(0, tex._alpha)
    end)

    it("hides ARTWORK textures", function()
        local tex = MockTexture("ARTWORK")
        local frame = MockFrame({ regions = { tex } })
        LunarUI.StripTextures(frame)
        assert.equals(0, tex._alpha)
    end)

    it("does not hide OVERLAY textures", function()
        local tex = MockTexture("OVERLAY")
        local frame = MockFrame({ regions = { tex } })
        LunarUI.StripTextures(frame)
        assert.equals(1, tex._alpha)
    end)

    it("handles nil frame safely", function()
        assert.has_no_errors(function()
            LunarUI.StripTextures(nil)
        end)
    end)

    it("handles frame with no regions", function()
        local frame = MockFrame()
        assert.has_no_errors(function()
            LunarUI.StripTextures(frame)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- SetFont helpers
--------------------------------------------------------------------------------

describe("SetFontLight", function()
    it("sets text color to white", function()
        local fs = MockFontString()
        LunarUI.SetFontLight(fs)
        assert.same({ 1, 1, 1, 1 }, fs._textColor)
    end)

    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI.SetFontLight(nil)
        end)
    end)
end)

describe("SetFontSecondary", function()
    it("sets text color to light gray", function()
        local fs = MockFontString()
        LunarUI.SetFontSecondary(fs)
        assert.same({ 0.9, 0.9, 0.9, 1 }, fs._textColor)
    end)

    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI.SetFontSecondary(nil)
        end)
    end)
end)

describe("SetFontMuted", function()
    it("sets text color to muted gray", function()
        local fs = MockFontString()
        LunarUI.SetFontMuted(fs)
        assert.same({ 0.7, 0.7, 0.7, 1 }, fs._textColor)
    end)

    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI.SetFontMuted(nil)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- MarkSkinned
--------------------------------------------------------------------------------

describe("MarkSkinned", function()
    it("returns true on first call", function()
        local frame = MockFrame()
        assert.is_true(LunarUI.MarkSkinned(frame))
    end)

    it("returns false on second call (already skinned)", function()
        local frame = MockFrame()
        LunarUI.MarkSkinned(frame)
        assert.is_false(LunarUI.MarkSkinned(frame))
    end)

    it("returns false for nil frame", function()
        assert.is_false(LunarUI.MarkSkinned(nil))
    end)
end)

--------------------------------------------------------------------------------
-- SkinScrollBar
--------------------------------------------------------------------------------

describe("SkinScrollBar", function()
    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI.SkinScrollBar(nil)
        end)
    end)

    it("strips textures from scrollbar", function()
        local tex = MockTexture("BACKGROUND")
        local frame = MockFrame({ regions = { tex } })
        LunarUI.SkinScrollBar(frame)
        assert.equals(0, tex._alpha)
    end)
end)

--------------------------------------------------------------------------------
-- SkinEditBox
--------------------------------------------------------------------------------

describe("SkinEditBox", function()
    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI.SkinEditBox(nil)
        end)
    end)

    it("creates background texture", function()
        local frame = MockFrame()
        LunarUI.SkinEditBox(frame)
        assert.is_not_nil(frame._lunarSkinBG)
    end)

    it("sets text color to white", function()
        local frame = MockFrame()
        LunarUI.SkinEditBox(frame)
        assert.same({ 1, 1, 1, 1 }, frame._textColor)
    end)
end)

--------------------------------------------------------------------------------
-- RegisterSkin
--------------------------------------------------------------------------------

describe("RegisterSkin", function()
    it("registers a skin function", function()
        assert.has_no_errors(function()
            LunarUI.RegisterSkin("TestSkin", "PLAYER_ENTERING_WORLD", function()
                return true
            end)
        end)
    end)
end)
