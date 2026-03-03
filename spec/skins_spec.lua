--[[
    Unit tests for LunarUI/Modules/Skins.lua
    Tests: CreateIconBorder
]]

require("spec.wow_mock")
local loader = require("spec.loader")

--------------------------------------------------------------------------------
-- Mock WoW frame API
--------------------------------------------------------------------------------

-- 模擬框架物件
local function MockFrame()
    local frame = {
        _points = {},
        _backdrop = nil,
        _backdropColor = {},
        _backdropBorderColor = {},
        _frameLevel = 1,
        _scripts = {},
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
        return nil
    end
    function frame:SetScript(name, fn)
        self._scripts[name] = fn
    end
    return frame
end

_G.CreateFrame = function(_type, _name, _parent, _template)
    return MockFrame()
end

_G.BackdropTemplateMixin = {}

-- Skins.lua 需要的框架與方法
_G.hooksecurefunc = function() end
_G.C_AddOns = {
    IsAddOnLoaded = function()
        return false
    end,
}

--------------------------------------------------------------------------------
-- Load Skins.lua
--------------------------------------------------------------------------------

local LunarUI = {
    Colors = {
        border = { 0.3, 0.3, 0.3, 1 },
        background = { 0.1, 0.1, 0.1, 0.9 },
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

-- Skins.lua 中 RegisterModule 會被呼叫，需要 stub
function LunarUI:RegisterModule(_name, _callbacks)
    -- stub
end

-- SkinStandardFrame stub（被其他模組用，但 CreateIconBorder 不依賴）
function LunarUI:SkinStandardFrame(_name, _opts)
    return nil
end

-- MarkSkinned stub
function LunarUI.MarkSkinned(_frame)
    return true
end

-- RegisterSkin stub
function LunarUI.RegisterSkin(_name, _event, _func)
    -- stub
end

local extraEngine = {
    L = {},
}

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
        local parent = MockFrame()
        parent._frameLevel = 5
        local border = LunarUI.CreateIconBorder(parent)
        assert.is_not_nil(border)
        assert.equals(6, border._frameLevel)
    end)

    it("applies custom inset from options", function()
        local parent = MockFrame()
        local border = LunarUI.CreateIconBorder(parent, { inset = 2 })
        assert.is_not_nil(border)
        -- 驗證 SetPoint 被呼叫了 2 次（TOPLEFT + BOTTOMRIGHT）
        assert.equals(2, #border._points)
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
        -- 預設色來自 LunarUI.Colors.border = { 0.3, 0.3, 0.3, 1 }
        assert.same({ 0.3, 0.3, 0.3, 1 }, border._backdropBorderColor)
    end)

    it("sets backdrop to transparent background", function()
        local parent = MockFrame()
        local border = LunarUI.CreateIconBorder(parent)
        assert.is_not_nil(border)
        assert.same({ 0, 0, 0, 0 }, border._backdropColor)
    end)
end)
