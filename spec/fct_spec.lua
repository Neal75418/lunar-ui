--[[
    Unit tests for LunarUI/HUD/FloatingCombatText.lua
    Tests Sanitize function, GetSettings, and lifecycle
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.GetTime = function()
    return 1000
end
_G.UnitGUID = function()
    return "Player-1234-5678ABCD"
end
_G.InCombatLockdown = function()
    return false
end
_G.IsShiftKeyDown = function()
    return false
end
_G.C_Timer = { After = function() end }
_G.CombatLogGetCurrentEventInfo = function()
    return {}
end

-- Mock CreateFrame
local MockFrame = {}
MockFrame.__index = MockFrame
function MockFrame:SetSize() end
function MockFrame:SetPoint() end
function MockFrame:SetFrameStrata() end
function MockFrame:SetMovable() end
function MockFrame:EnableMouse() end
function MockFrame:RegisterForDrag() end
function MockFrame:SetClampedToScreen() end
function MockFrame:SetScript() end
function MockFrame:SetAllPoints() end
function MockFrame:SetAlpha() end
function MockFrame:SetTexture() end
function MockFrame:SetTextColor() end
function MockFrame:SetText() end
function MockFrame:SetFont() end
function MockFrame:SetShadowOffset() end
function MockFrame:ClearAllPoints() end
function MockFrame:StartMoving() end
function MockFrame:StopMovingOrSizing() end
function MockFrame:Hide() end
function MockFrame:Show() end
function MockFrame:IsShown()
    return true
end
function MockFrame:GetFrameLevel()
    return 1
end
function MockFrame:SetFrameLevel() end
function MockFrame:RegisterEvent() end
function MockFrame:UnregisterAllEvents() end
function MockFrame:SetBackdrop() end
function MockFrame:SetBackdropColor() end
function MockFrame:SetBackdropBorderColor() end
function MockFrame:CreateTexture()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:CreateFontString()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:CreateAnimationGroup()
    return setmetatable({}, { __index = MockFrame })
end

_G.CreateFrame = function()
    return setmetatable({}, { __index = MockFrame })
end
_G.UIParent = setmetatable({}, { __index = MockFrame })

local LunarUI = {
    Colors = {
        bgIcon = { 0, 0, 0, 0.8 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
        bgHUD = { 0, 0, 0, 0.6 },
        borderHUD = { 0.3, 0.3, 0.4, 0.8 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    textures = { glow = "Interface\\glow" },
    Easing = {
        OutQuad = function(t, b, c, d)
            t = t / d
            return c * t * (2 - t) + b
        end,
        InQuad = function(t, b, c, d)
            t = t / d
            return c * t * t + b
        end,
    },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetSelectedFont = function()
        return "Fonts\\FRIZQT__.TTF"
    end,
    FormatValue = function(v)
        return tostring(v)
    end,
    GetHUDSetting = function(_key, default)
        return default
    end,
    RegisterHUDFrame = function() end,
    RegisterMovableFrame = function() end,
    iconBackdropTemplate = {},
    RegisterModule = function() end,
    Debug = function() end,
    Print = function() end,
    db = nil, -- will be set per-test
}

loader.loadAddonFile("LunarUI/HUD/FloatingCombatText.lua", LunarUI)

--------------------------------------------------------------------------------
-- Sanitize
--------------------------------------------------------------------------------

describe("Sanitize", function()
    it("returns nil for nil input", function()
        assert.is_nil(LunarUI.Sanitize(nil))
    end)

    it("sanitizes numbers", function()
        local result = LunarUI.Sanitize(42)
        assert.equals(42, result)
        assert.equals("number", type(result))
    end)

    it("sanitizes strings", function()
        local result = LunarUI.Sanitize("hello")
        assert.equals("hello", result)
        assert.equals("string", type(result))
    end)

    it("sanitizes booleans (true)", function()
        assert.is_true(LunarUI.Sanitize(true))
    end)

    it("sanitizes booleans (false)", function()
        assert.is_false(LunarUI.Sanitize(false))
    end)

    it("passes through tables unchanged", function()
        local t = { 1, 2, 3 }
        assert.equals(t, LunarUI.Sanitize(t))
    end)

    it("sanitizes float numbers", function()
        local result = LunarUI.Sanitize(3.14159)
        assert.is_near(3.14159, result, 0.0001)
    end)

    it("sanitizes negative numbers", function()
        assert.equals(-100, LunarUI.Sanitize(-100))
    end)

    it("sanitizes empty string", function()
        assert.equals("", LunarUI.Sanitize(""))
    end)
end)

--------------------------------------------------------------------------------
-- FCTGetSettings
--------------------------------------------------------------------------------

describe("FCTGetSettings", function()
    it("returns defaults when db is nil", function()
        LunarUI.db = nil
        local enabled, fontSize, critScale, duration, dmgOut, dmgIn, heal = LunarUI.FCTGetSettings()
        assert.is_false(enabled)
        assert.equals(24, fontSize)
        assert.equals(1.5, critScale)
        assert.equals(1.5, duration)
        assert.is_true(dmgOut)
        assert.is_true(dmgIn)
        assert.is_true(heal)
    end)

    it("returns defaults when hud is nil", function()
        LunarUI.db = { profile = {} }
        local enabled = LunarUI.FCTGetSettings()
        assert.is_false(enabled)
    end)

    it("reads enabled state from db", function()
        LunarUI.db = { profile = { hud = { fctEnabled = true } } }
        local enabled = LunarUI.FCTGetSettings()
        assert.is_true(enabled)
    end)

    it("reads custom font size from db", function()
        LunarUI.db = { profile = { hud = { fctEnabled = true, fctFontSize = 32 } } }
        local _, fontSize = LunarUI.FCTGetSettings()
        assert.equals(32, fontSize)
    end)

    it("reads damage filter settings", function()
        LunarUI.db = { profile = { hud = { fctEnabled = true, fctDamageOut = false } } }
        local _, _, _, _, dmgOut = LunarUI.FCTGetSettings()
        assert.is_false(dmgOut)
    end)
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("FCT lifecycle", function()
    before_each(function()
        LunarUI.db = nil
    end)

    it("InitFCT does nothing when db is nil", function()
        assert.has_no_errors(function()
            LunarUI.InitFCT()
        end)
    end)

    it("InitFCT does nothing when not enabled", function()
        LunarUI.db = { profile = { hud = { fctEnabled = false } } }
        assert.has_no_errors(function()
            LunarUI.InitFCT()
        end)
    end)

    it("InitFCT initializes when enabled", function()
        LunarUI.db = { profile = { hud = { fctEnabled = true } } }
        assert.has_no_errors(function()
            LunarUI.InitFCT()
        end)
    end)

    it("CleanupFCT does not error when not initialized", function()
        assert.has_no_errors(function()
            LunarUI.CleanupFCT()
        end)
    end)

    it("CleanupFCT cleans up after Init", function()
        LunarUI.db = { profile = { hud = { fctEnabled = true } } }
        LunarUI.InitFCT()
        assert.has_no_errors(function()
            LunarUI.CleanupFCT()
        end)
    end)

    it("can Init/Cleanup multiple times (toggle cycle)", function()
        LunarUI.db = { profile = { hud = { fctEnabled = true } } }
        assert.has_no_errors(function()
            LunarUI.InitFCT()
            LunarUI.CleanupFCT()
            LunarUI.InitFCT()
            LunarUI.CleanupFCT()
        end)
    end)
end)
