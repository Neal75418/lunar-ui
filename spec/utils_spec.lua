---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Core/Utils.lua
    Tests pure logic utility functions: FormatValue,
    ThresholdColor, FormatGameTime, FormatCoordinates, EscapePattern
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock CreateFrame for CreateEventHandler
local MockFrame = {
    _events = {},
    _scripts = {},
}
function MockFrame:RegisterEvent(event)
    self._events[event] = true
end
function MockFrame:SetScript(name, fn)
    self._scripts[name] = fn
end
_G.CreateFrame = function()
    return setmetatable({
        _events = {},
        _scripts = {},
    }, { __index = MockFrame })
end

local LunarUI = {}
loader.loadAddonFile("LunarUI/Core/Utils.lua", LunarUI)

--------------------------------------------------------------------------------
-- FormatValue
--------------------------------------------------------------------------------

describe("FormatValue", function()
    it("formats millions", function()
        assert.equals("1.5M", LunarUI.FormatValue(1500000))
    end)

    it("formats exact million", function()
        assert.equals("1.0M", LunarUI.FormatValue(1000000))
    end)

    it("formats thousands", function()
        assert.equals("25.3K", LunarUI.FormatValue(25300))
    end)

    it("formats exact thousand", function()
        assert.equals("1.0K", LunarUI.FormatValue(1000))
    end)

    it("formats small numbers as-is", function()
        assert.equals("999", LunarUI.FormatValue(999))
    end)

    it("formats zero", function()
        assert.equals("0", LunarUI.FormatValue(0))
    end)

    it("returns '0' for nil", function()
        assert.equals("0", LunarUI.FormatValue(nil))
    end)
end)

--------------------------------------------------------------------------------
-- ThresholdColor
--------------------------------------------------------------------------------

describe("ThresholdColor", function()
    describe("ascending (higher is better)", function()
        it("returns green for high values", function()
            local r, g, b = LunarUI.ThresholdColor(80, { 60, 30, 15 }, true)
            assert.equals(0.2, r)
            assert.equals(0.8, g)
            assert.equals(0.2, b)
        end)

        it("returns yellow for medium values", function()
            local r, g, b = LunarUI.ThresholdColor(45, { 60, 30, 15 }, true)
            assert.equals(0.9, r)
            assert.equals(0.9, g)
            assert.equals(0.2, b)
        end)

        it("returns orange for low values", function()
            local r, g, b = LunarUI.ThresholdColor(20, { 60, 30, 15 }, true)
            assert.equals(0.9, r)
            assert.equals(0.5, g)
            assert.equals(0.1, b)
        end)

        it("returns red for very low values", function()
            local r, g, b = LunarUI.ThresholdColor(10, { 60, 30, 15 }, true)
            assert.equals(0.9, r)
            assert.equals(0.2, g)
            assert.equals(0.2, b)
        end)
    end)

    describe("descending (lower is better)", function()
        it("returns green for low values", function()
            local r, g, b = LunarUI.ThresholdColor(50, { 100, 200, 400 }, false)
            assert.equals(0.2, r)
            assert.equals(0.8, g)
            assert.equals(0.2, b)
        end)

        it("returns yellow for medium values", function()
            local r, g, b = LunarUI.ThresholdColor(150, { 100, 200, 400 }, false)
            assert.equals(0.9, r)
            assert.equals(0.9, g)
            assert.equals(0.2, b)
        end)

        it("returns orange for high values", function()
            local r, g, b = LunarUI.ThresholdColor(300, { 100, 200, 400 }, false)
            assert.equals(0.9, r)
            assert.equals(0.5, g)
            assert.equals(0.1, b)
        end)

        it("returns red for very high values", function()
            local r, g, b = LunarUI.ThresholdColor(500, { 100, 200, 400 }, false)
            assert.equals(0.9, r)
            assert.equals(0.2, g)
            assert.equals(0.2, b)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- FormatGameTime
--------------------------------------------------------------------------------

describe("FormatGameTime", function()
    it("formats 24h midnight", function()
        assert.equals("00:00", LunarUI.FormatGameTime(0, 0, true))
    end)

    it("formats 24h afternoon", function()
        assert.equals("14:30", LunarUI.FormatGameTime(14, 30, true))
    end)

    it("formats 24h with zero-padded hour", function()
        assert.equals("09:05", LunarUI.FormatGameTime(9, 5, true))
    end)

    it("formats 12h midnight as 12:00 AM", function()
        assert.equals("12:00 AM", LunarUI.FormatGameTime(0, 0, false))
    end)

    it("formats 12h noon as 12:00 PM", function()
        assert.equals("12:00 PM", LunarUI.FormatGameTime(12, 0, false))
    end)

    it("formats 12h afternoon", function()
        assert.equals("1:00 PM", LunarUI.FormatGameTime(13, 0, false))
    end)

    it("formats 12h morning", function()
        assert.equals("11:59 AM", LunarUI.FormatGameTime(11, 59, false))
    end)
end)

--------------------------------------------------------------------------------
-- FormatCoordinates
--------------------------------------------------------------------------------

describe("FormatCoordinates", function()
    it("formats typical coordinates", function()
        assert.equals("45.2, 67.8", LunarUI.FormatCoordinates(45.23, 67.81))
    end)

    it("formats zero coordinates", function()
        assert.equals("0.0, 0.0", LunarUI.FormatCoordinates(0, 0))
    end)

    it("formats max coordinates", function()
        assert.equals("100.0, 100.0", LunarUI.FormatCoordinates(100, 100))
    end)
end)

--------------------------------------------------------------------------------
-- EscapePattern
--------------------------------------------------------------------------------

describe("EscapePattern", function()
    it("escapes parentheses", function()
        assert.equals("hello%(world%)", LunarUI.EscapePattern("hello(world)"))
    end)

    it("escapes percent", function()
        assert.equals("100%%", LunarUI.EscapePattern("100%"))
    end)

    it("escapes dots", function()
        assert.equals("a%.b%.c", LunarUI.EscapePattern("a.b.c"))
    end)

    it("escapes brackets", function()
        assert.equals("%[test%]", LunarUI.EscapePattern("[test]"))
    end)

    it("does not escape plain text", function()
        assert.equals("hello", LunarUI.EscapePattern("hello"))
    end)

    it("escapes plus and star", function()
        assert.equals("a%+b%*c", LunarUI.EscapePattern("a+b*c"))
    end)
end)

--------------------------------------------------------------------------------
-- GetModuleDB
--------------------------------------------------------------------------------

describe("GetModuleDB", function()
    local savedDB

    before_each(function()
        savedDB = LunarUI.db
    end)

    after_each(function()
        LunarUI.db = savedDB
    end)

    it("returns module profile data", function()
        LunarUI.db = { profile = { chat = { fontSize = 14 } } }
        local result = LunarUI.GetModuleDB("chat")
        assert.same({ fontSize = 14 }, result)
    end)

    it("returns nil for missing module key", function()
        LunarUI.db = { profile = {} }
        assert.is_nil(LunarUI.GetModuleDB("nonexistent"))
    end)

    it("returns nil when db is nil", function()
        LunarUI.db = nil
        assert.is_nil(LunarUI.GetModuleDB("chat"))
    end)

    it("returns nil when profile is nil", function()
        LunarUI.db = { profile = nil }
        assert.is_nil(LunarUI.GetModuleDB("chat"))
    end)

    it("returns correct data for different modules", function()
        LunarUI.db = {
            profile = {
                unitframes = { enabled = true },
                minimap = { scale = 1.2 },
            },
        }
        assert.same({ enabled = true }, LunarUI.GetModuleDB("unitframes"))
        assert.same({ scale = 1.2 }, LunarUI.GetModuleDB("minimap"))
    end)
end)

--------------------------------------------------------------------------------
-- GetHUDSetting
--------------------------------------------------------------------------------

describe("GetHUDSetting", function()
    local savedDB

    before_each(function()
        savedDB = LunarUI.db
    end)

    after_each(function()
        LunarUI.db = savedDB
    end)

    it("returns value from hud config", function()
        LunarUI.db = { profile = { hud = { auraIconSize = 40 } } }
        assert.equals(40, LunarUI.GetHUDSetting("auraIconSize", 30))
    end)

    it("returns default when key is missing", function()
        LunarUI.db = { profile = { hud = {} } }
        assert.equals(30, LunarUI.GetHUDSetting("auraIconSize", 30))
    end)

    it("returns default when hud module is nil", function()
        LunarUI.db = { profile = {} }
        assert.equals(30, LunarUI.GetHUDSetting("auraIconSize", 30))
    end)

    it("returns default when db is nil", function()
        LunarUI.db = nil
        assert.equals(30, LunarUI.GetHUDSetting("auraIconSize", 30))
    end)

    it("returns false value (not default) when key exists as false", function()
        LunarUI.db = { profile = { hud = { showAuras = false } } }
        assert.equals(false, LunarUI.GetHUDSetting("showAuras", true))
    end)
end)

--------------------------------------------------------------------------------
-- SafeCall
--------------------------------------------------------------------------------

describe("SafeCall", function()
    local savedDebug
    before_each(function()
        savedDebug = LunarUI.Debug
    end)
    after_each(function()
        LunarUI.Debug = savedDebug
    end)

    it("returns true for successful call", function()
        local result = LunarUI.SafeCall(function() end)
        assert.is_true(result)
    end)

    it("returns false for erroring call", function()
        local result = LunarUI.SafeCall(function()
            error("boom")
        end)
        assert.is_false(result)
    end)

    it("calls Debug when debug mode is active and function errors", function()
        local debugMsg = nil
        LunarUI.IsDebugMode = function()
            return true
        end
        LunarUI.Debug = function(_self, msg)
            debugMsg = msg
        end
        LunarUI.SafeCall(function()
            error("test error")
        end, "TestContext")
        assert.is_not_nil(debugMsg)
        assert.truthy(debugMsg:match("TestContext"))
        LunarUI.IsDebugMode = nil
    end)

    it("does not call Debug on success", function()
        local called = false
        LunarUI.Debug = function()
            called = true
        end
        LunarUI.SafeCall(function() end, "TestContext")
        assert.is_false(called)
    end)
end)

--------------------------------------------------------------------------------
-- CreateEventHandler
--------------------------------------------------------------------------------

describe("CreateEventHandler", function()
    it("registers events and sets script", function()
        local callback = function() end
        local frame = LunarUI.CreateEventHandler({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED" }, callback)
        assert.is_not_nil(frame)
        assert.is_true(frame._events["PLAYER_ENTERING_WORLD"])
        assert.is_true(frame._events["ZONE_CHANGED"])
        assert.equals(callback, frame._scripts["OnEvent"])
    end)

    it("handles empty event list", function()
        local frame = LunarUI.CreateEventHandler({}, function() end)
        assert.is_not_nil(frame)
    end)
end)
