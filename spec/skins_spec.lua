---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Modules/Skins.lua
    Tests: CreateIconBorder, StripTextures, SetFontLight, MarkSkinned, RegisterSkin,
           SkinEditBox
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

local originalCreateFrame = _G.CreateFrame
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
LunarUI.GetModuleDB = function(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

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
    -- NOTE: The `skins` table is module-local in Skins.lua and not exported.
    -- We can only verify that registration does not raise an error.
    -- Deeper verification would require exposing the skins table or a lookup API.
    it("registers a skin function without error", function()
        assert.has_no_errors(function()
            LunarUI.RegisterSkin("TestSkin", "PLAYER_ENTERING_WORLD", function()
                return true
            end)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- SkinButton
--------------------------------------------------------------------------------

describe("SkinButton", function()
    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI.SkinButton(nil)
        end)
    end)

    it("creates background texture", function()
        local btn = MockFrame()
        LunarUI.SkinButton(btn)
        assert.is_not_nil(btn._lunarSkinBG)
    end)

    it("creates highlight texture", function()
        local btn = MockFrame()
        LunarUI.SkinButton(btn)
        assert.is_not_nil(btn._lunarHighlight)
    end)

    it("strips existing textures", function()
        local tex = MockTexture("BACKGROUND")
        local btn = MockFrame({ regions = { tex } })
        LunarUI.SkinButton(btn)
        assert.equals(0, tex._alpha)
    end)

    it("does not create duplicate background", function()
        local btn = MockFrame()
        LunarUI.SkinButton(btn)
        local firstBG = btn._lunarSkinBG
        LunarUI.SkinButton(btn)
        assert.equals(firstBG, btn._lunarSkinBG)
    end)
end)

--------------------------------------------------------------------------------
-- SkinCloseButton
--------------------------------------------------------------------------------

describe("SkinCloseButton", function()
    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI.SkinCloseButton(nil)
        end)
    end)

    it("creates close background", function()
        local btn = MockFrame()
        LunarUI.SkinCloseButton(btn)
        assert.is_not_nil(btn._lunarCloseBG)
    end)

    it("creates close text with X", function()
        local btn = MockFrame()
        LunarUI.SkinCloseButton(btn)
        assert.is_not_nil(btn._lunarCloseText)
    end)

    it("creates highlight texture", function()
        local btn = MockFrame()
        LunarUI.SkinCloseButton(btn)
        assert.is_not_nil(btn._lunarHighlight)
    end)

    it("sets button size to 18x18", function()
        local btn = MockFrame()
        LunarUI.SkinCloseButton(btn)
        assert.same({ 18, 18 }, btn._size)
    end)

    it("does not create duplicate elements", function()
        local btn = MockFrame()
        LunarUI.SkinCloseButton(btn)
        local firstBG = btn._lunarCloseBG
        local firstText = btn._lunarCloseText
        LunarUI.SkinCloseButton(btn)
        assert.equals(firstBG, btn._lunarCloseBG)
        assert.equals(firstText, btn._lunarCloseText)
    end)
end)

--------------------------------------------------------------------------------
-- SkinTab
--------------------------------------------------------------------------------

describe("SkinTab", function()
    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI.SkinTab(nil)
        end)
    end)

    it("creates tab background", function()
        local tab = MockFrame()
        LunarUI.SkinTab(tab)
        assert.is_not_nil(tab._lunarTabBG)
    end)

    it("creates indicator line", function()
        local tab = MockFrame()
        LunarUI.SkinTab(tab)
        assert.is_not_nil(tab._lunarIndicator)
    end)

    it("strips existing textures", function()
        local tex = MockTexture("BACKGROUND")
        local tab = MockFrame({ regions = { tex } })
        LunarUI.SkinTab(tab)
        assert.equals(0, tex._alpha)
    end)

    it("does not create duplicate elements", function()
        local tab = MockFrame()
        LunarUI.SkinTab(tab)
        local firstBG = tab._lunarTabBG
        local firstInd = tab._lunarIndicator
        LunarUI.SkinTab(tab)
        assert.equals(firstBG, tab._lunarTabBG)
        assert.equals(firstInd, tab._lunarIndicator)
    end)
end)

--------------------------------------------------------------------------------
-- SkinFrame
--------------------------------------------------------------------------------

describe("SkinFrame", function()
    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI:SkinFrame(nil)
        end)
    end)

    it("creates skin background", function()
        local frame = MockFrame()
        LunarUI:SkinFrame(frame)
        assert.is_not_nil(frame._lunarSkinBG)
    end)

    it("strips textures by default", function()
        local tex = MockTexture("BACKGROUND")
        local frame = MockFrame({ regions = { tex } })
        LunarUI:SkinFrame(frame)
        assert.equals(0, tex._alpha)
    end)

    it("respects noStrip option", function()
        local tex = MockTexture("BACKGROUND")
        local frame = MockFrame({ regions = { tex } })
        LunarUI:SkinFrame(frame, { noStrip = true })
        assert.equals(1, tex._alpha)
    end)

    it("hides NineSlice if present", function()
        local nineSlice = { _alpha = 1 }
        function nineSlice:SetAlpha(a)
            self._alpha = a
        end
        local frame = MockFrame()
        frame.NineSlice = nineSlice
        LunarUI:SkinFrame(frame)
        assert.equals(0, nineSlice._alpha)
    end)

    it("does not create duplicate background", function()
        local frame = MockFrame()
        LunarUI:SkinFrame(frame)
        local firstBG = frame._lunarSkinBG
        LunarUI:SkinFrame(frame)
        assert.equals(firstBG, frame._lunarSkinBG)
    end)
end)

--------------------------------------------------------------------------------
-- SkinFrameText
--------------------------------------------------------------------------------

describe("SkinFrameText", function()
    it("handles nil safely", function()
        assert.has_no_errors(function()
            LunarUI:SkinFrameText(nil)
        end)
    end)

    it("changes dark text to white", function()
        local fs = MockFontString()
        fs._textColor = { 0.1, 0.1, 0.1, 1 }
        local frame = MockFrame({ regions = { fs } })
        LunarUI:SkinFrameText(frame)
        assert.same({ 1, 1, 1, 1 }, fs._textColor)
    end)

    it("does not change light-colored text", function()
        local fs = MockFontString()
        fs._textColor = { 0.8, 0.8, 0.8, 1 }
        local frame = MockFrame({ regions = { fs } })
        LunarUI:SkinFrameText(frame)
        assert.same({ 0.8, 0.8, 0.8, 1 }, fs._textColor)
    end)

    it("recurses into children", function()
        local childFS = MockFontString()
        childFS._textColor = { 0.1, 0.1, 0.1, 1 }
        local child = MockFrame({ regions = { childFS } })
        local parent = MockFrame({ children = { child } })
        LunarUI:SkinFrameText(parent, 2)
        assert.same({ 1, 1, 1, 1 }, childFS._textColor)
    end)

    it("respects depth limit", function()
        local deepFS = MockFontString()
        deepFS._textColor = { 0.1, 0.1, 0.1, 1 }
        local deepChild = MockFrame({ regions = { deepFS } })
        local child = MockFrame({ children = { deepChild } })
        local parent = MockFrame({ children = { child } })
        LunarUI:SkinFrameText(parent, 1) -- depth 1 = only direct children
        -- deepChild is at depth 2, should not be touched
        assert.same({ 0.1, 0.1, 0.1, 1 }, deepFS._textColor)
    end)

    it("skips children with _lunarSkinBG", function()
        local childFS = MockFontString()
        childFS._textColor = { 0.1, 0.1, 0.1, 1 }
        local child = MockFrame({ regions = { childFS } })
        child._lunarSkinBG = true -- already skinned
        local parent = MockFrame({ children = { child } })
        LunarUI:SkinFrameText(parent, 2)
        assert.same({ 0.1, 0.1, 0.1, 1 }, childFS._textColor)
    end)
end)

--------------------------------------------------------------------------------
-- SkinStandardFrame
--------------------------------------------------------------------------------

describe("SkinStandardFrame", function()
    it("returns nil for nil frame", function()
        assert.is_nil(LunarUI:SkinStandardFrame(nil))
    end)

    it("skins a frame object", function()
        local frame = MockFrame()
        local result = LunarUI:SkinStandardFrame(frame)
        assert.equals(frame, result)
        assert.is_not_nil(frame._lunarSkinBG)
        assert.is_true(frame._lunarSkinned)
    end)

    it("returns frame without re-skinning if already skinned", function()
        local frame = MockFrame()
        LunarUI:SkinStandardFrame(frame)
        -- Mark a second time - should return frame but not re-process
        local result = LunarUI:SkinStandardFrame(frame)
        assert.equals(frame, result)
    end)

    it("skins CloseButton if present", function()
        local closeBtn = MockFrame()
        local frame = MockFrame()
        frame.CloseButton = closeBtn
        LunarUI:SkinStandardFrame(frame)
        assert.is_not_nil(closeBtn._lunarCloseBG)
    end)

    it("skins TitleText if present", function()
        local titleText = MockFontString()
        titleText._textColor = { 0.1, 0.1, 0.1, 1 }
        local frame = MockFrame()
        frame.TitleText = titleText
        LunarUI:SkinStandardFrame(frame)
        assert.same({ 1, 1, 1, 1 }, titleText._textColor)
    end)

    it("skins tabs via tabPrefix", function()
        local tab1 = MockFrame()
        local tab2 = MockFrame()
        _G["TestTab1"] = tab1
        _G["TestTab2"] = tab2
        local frame = MockFrame()
        LunarUI:SkinStandardFrame(frame, { tabPrefix = "TestTab", tabCount = 2 })
        assert.is_not_nil(tab1._lunarTabBG)
        assert.is_not_nil(tab2._lunarTabBG)
        _G["TestTab1"] = nil
        _G["TestTab2"] = nil
    end)

    it("skins tabs via tabProperty", function()
        local tab1 = MockFrame()
        local tab2 = MockFrame()
        local frame = MockFrame()
        frame.Tabs = { tab1, tab2 }
        LunarUI:SkinStandardFrame(frame, { tabProperty = "Tabs" })
        assert.is_not_nil(tab1._lunarTabBG)
        assert.is_not_nil(tab2._lunarTabBG)
    end)

    it("skins tabs via useTabSystem", function()
        local tab1 = MockFrame()
        local frame = MockFrame()
        frame.TabSystem = { tabs = { tab1 } }
        LunarUI:SkinStandardFrame(frame, { useTabSystem = true })
        assert.is_not_nil(tab1._lunarTabBG)
    end)

    it("resolves frame from global name string", function()
        local frame = MockFrame()
        _G["TestGlobalFrame"] = frame
        local result = LunarUI:SkinStandardFrame("TestGlobalFrame")
        assert.equals(frame, result)
        assert.is_true(frame._lunarSkinned)
        _G["TestGlobalFrame"] = nil
    end)
end)

--------------------------------------------------------------------------------
-- CleanupSkins
--------------------------------------------------------------------------------

describe("CleanupSkins", function()
    it("does not error when no event frame exists", function()
        assert.has_no_errors(function()
            LunarUI.CleanupSkins()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- InitializeSkins
--------------------------------------------------------------------------------

describe("InitializeSkins", function()
    it("does nothing when db is nil", function()
        local savedDB = LunarUI.db
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI.InitializeSkins()
        end)
        LunarUI.db = savedDB
    end)

    it("does nothing when skins not enabled", function()
        local savedDB = LunarUI.db
        LunarUI.db = { profile = { skins = { enabled = false } } }
        assert.has_no_errors(function()
            LunarUI.InitializeSkins()
        end)
        LunarUI.db = savedDB
    end)

    it("runs when skins enabled", function()
        local savedDB = LunarUI.db
        LunarUI.db = { profile = { skins = { enabled = true, blizzard = {} } } }
        assert.has_no_errors(function()
            LunarUI.InitializeSkins()
        end)
        LunarUI.db = savedDB
    end)
end)

-- Restore the original CreateFrame after all tests in this file complete
teardown(function()
    _G.CreateFrame = originalCreateFrame
end)
