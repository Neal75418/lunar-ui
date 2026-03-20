---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Core/Utils.lua
    Tests pure logic utility functions: FormatValue, FormatDuration,
    StatusColor, ThresholdColor, GetNestedValue, HexToRGB, RGBToHex,
    FormatGameTime, FormatCoordinates, EscapePattern
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

-- Mock GameTooltip for ShowTooltip
_G.GameTooltip = {
    _owner = nil,
    _lines = {},
    _shown = false,
    SetOwner = function(self, owner, anchor, x, y)
        self._owner = owner
        self._anchor = anchor
        self._x = x
        self._y = y
    end,
    ClearLines = function(self)
        self._lines = {}
    end,
    AddLine = function(self, text, r, g, b)
        table.insert(self._lines, { text = text, r = r, g = g, b = b })
    end,
    Show = function(self)
        self._shown = true
    end,
}

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
-- FormatDuration
--------------------------------------------------------------------------------

describe("FormatDuration", function()
    it("formats hours", function()
        assert.equals("1h", LunarUI.FormatDuration(3600))
    end)

    it("formats multiple hours", function()
        assert.equals("2h", LunarUI.FormatDuration(7200))
    end)

    it("formats hours with remainder (truncated)", function()
        assert.equals("1h", LunarUI.FormatDuration(3700))
    end)

    it("formats minutes", function()
        assert.equals("1m", LunarUI.FormatDuration(60))
    end)

    it("formats minutes with remainder", function()
        assert.equals("1m", LunarUI.FormatDuration(90))
    end)

    it("formats seconds >= 10 (integer)", function()
        assert.equals("30", LunarUI.FormatDuration(30))
    end)

    it("formats seconds < 10 with decimal", function()
        assert.equals("5.5", LunarUI.FormatDuration(5.5))
    end)

    it("returns empty string for nil", function()
        assert.equals("", LunarUI.FormatDuration(nil))
    end)

    it("returns empty string for zero", function()
        assert.equals("", LunarUI.FormatDuration(0))
    end)

    it("returns empty string for negative", function()
        assert.equals("", LunarUI.FormatDuration(-5))
    end)
end)

--------------------------------------------------------------------------------
-- StatusColor
--------------------------------------------------------------------------------

describe("StatusColor", function()
    it("returns green for high FPS (non-inverted)", function()
        local r, g = LunarUI.StatusColor(60, 60, 30, false)
        assert.equals(0.3, r)
        assert.equals(1, g)
    end)

    it("returns yellow for medium FPS", function()
        local r, g = LunarUI.StatusColor(45, 60, 30, false)
        assert.equals(1, r)
        assert.equals(0.8, g)
    end)

    it("returns red for low FPS", function()
        local r, g = LunarUI.StatusColor(20, 60, 30, false)
        assert.equals(1, r)
        assert.equals(0.3, g)
    end)

    it("returns green for low latency (inverted)", function()
        local r, g = LunarUI.StatusColor(50, 100, 200, true)
        assert.equals(0.3, r)
        assert.equals(1, g)
    end)

    it("returns red for high latency (inverted)", function()
        local r, g = LunarUI.StatusColor(300, 100, 200, true)
        assert.equals(1, r)
        assert.equals(0.3, g)
    end)

    it("returns yellow for mid-range latency (inverted)", function()
        -- value > greenThreshold 但 <= yellowThreshold：warn band
        local r, g = LunarUI.StatusColor(150, 100, 200, true)
        assert.equals(1, r)
        assert.equals(0.8, g)
    end)

    it("returns red for nil value", function()
        local r, g = LunarUI.StatusColor(nil, 60, 30, false)
        assert.equals(1, r)
        assert.equals(0.3, g)
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
-- GetNestedValue
--------------------------------------------------------------------------------

describe("GetNestedValue", function()
    it("accesses top-level value", function()
        local t = { name = "test" }
        assert.equals("test", LunarUI.GetNestedValue(t, "name"))
    end)

    it("accesses nested value", function()
        local t = { player = { stats = { health = 100 } } }
        assert.equals(100, LunarUI.GetNestedValue(t, "player", "stats", "health"))
    end)

    it("returns nil for missing path", function()
        local t = { a = { b = 1 } }
        assert.is_nil(LunarUI.GetNestedValue(t, "a", "c", "d"))
    end)

    it("returns nil for non-table input", function()
        assert.is_nil(LunarUI.GetNestedValue("not a table", "key"))
    end)

    it("returns nil for nil input", function()
        assert.is_nil(LunarUI.GetNestedValue(nil, "key"))
    end)

    it("returns the table itself with no keys", function()
        local t = { a = 1 }
        assert.same({ a = 1 }, LunarUI.GetNestedValue(t))
    end)
end)

--------------------------------------------------------------------------------
-- HexToRGB
--------------------------------------------------------------------------------

describe("HexToRGB", function()
    it("converts red", function()
        local r, g, b = LunarUI.HexToRGB("#FF0000")
        assert.equals(1, r)
        assert.equals(0, g)
        assert.equals(0, b)
    end)

    it("converts green without hash", function()
        local r, g, b = LunarUI.HexToRGB("00FF00")
        assert.near(0, r, 0.01)
        assert.near(1, g, 0.01)
        assert.near(0, b, 0.01)
    end)

    it("converts blue", function()
        local r, g, b = LunarUI.HexToRGB("#0000FF")
        assert.near(0, r, 0.01)
        assert.near(0, g, 0.01)
        assert.near(1, b, 0.01)
    end)

    it("converts LunarUI purple", function()
        local r, g, b = LunarUI.HexToRGB("#8882ff")
        assert.near(0.533, r, 0.01)
        assert.near(0.510, g, 0.01)
        assert.near(1.0, b, 0.01)
    end)

    it("returns white for nil", function()
        local r, g, b = LunarUI.HexToRGB(nil)
        assert.equals(1, r)
        assert.equals(1, g)
        assert.equals(1, b)
    end)

    it("returns white for invalid hex (wrong length)", function()
        local r, g, b = LunarUI.HexToRGB("#FFF")
        assert.equals(1, r)
        assert.equals(1, g)
        assert.equals(1, b)
    end)
end)

--------------------------------------------------------------------------------
-- RGBToHex
--------------------------------------------------------------------------------

describe("RGBToHex", function()
    it("converts pure red", function()
        assert.equals("FF0000", LunarUI.RGBToHex(1, 0, 0))
    end)

    it("converts pure green", function()
        assert.equals("00FF00", LunarUI.RGBToHex(0, 1, 0))
    end)

    it("converts pure blue", function()
        assert.equals("0000FF", LunarUI.RGBToHex(0, 0, 1))
    end)

    it("converts white", function()
        assert.equals("FFFFFF", LunarUI.RGBToHex(1, 1, 1))
    end)

    it("converts black", function()
        assert.equals("000000", LunarUI.RGBToHex(0, 0, 0))
    end)

    it("defaults nil components to 1 (white)", function()
        assert.equals("FFFFFF", LunarUI.RGBToHex(nil, nil, nil))
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

    it("calls Debug when available and function errors", function()
        local debugMsg = nil
        LunarUI.Debug = function(_self, msg)
            debugMsg = msg
        end
        LunarUI.SafeCall(function()
            error("test error")
        end, "TestContext")
        assert.is_not_nil(debugMsg)
        assert.truthy(debugMsg:match("TestContext"))
        LunarUI.Debug = nil
    end)

    it("does not call Debug on success", function()
        local called = false
        LunarUI.Debug = function()
            called = true
        end
        LunarUI.SafeCall(function() end, "TestContext")
        assert.is_false(called)
        LunarUI.Debug = nil
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

--------------------------------------------------------------------------------
-- ShowTooltip
--------------------------------------------------------------------------------

describe("ShowTooltip", function()
    before_each(function()
        _G.GameTooltip._lines = {}
        _G.GameTooltip._shown = false
        _G.GameTooltip._owner = nil
    end)

    it("shows tooltip with title and lines", function()
        local owner = {}
        LunarUI.ShowTooltip(owner, "Test Title", {
            "Simple line",
            { "Colored line", 1, 0.8, 0 },
        })
        assert.equals(owner, _G.GameTooltip._owner)
        assert.is_true(_G.GameTooltip._shown)
        assert.equals(3, #_G.GameTooltip._lines)
        -- Title
        assert.equals("Test Title", _G.GameTooltip._lines[1].text)
        assert.equals(1, _G.GameTooltip._lines[1].r)
        -- Simple line (gray)
        assert.equals("Simple line", _G.GameTooltip._lines[2].text)
        assert.equals(0.7, _G.GameTooltip._lines[2].r)
        -- Colored line
        assert.equals("Colored line", _G.GameTooltip._lines[3].text)
        assert.equals(1, _G.GameTooltip._lines[3].r)
        assert.equals(0.8, _G.GameTooltip._lines[3].g)
    end)

    it("shows tooltip without title", function()
        LunarUI.ShowTooltip({}, nil, { "Line 1" })
        assert.equals(1, #_G.GameTooltip._lines)
        assert.equals("Line 1", _G.GameTooltip._lines[1].text)
    end)

    it("shows tooltip without lines", function()
        LunarUI.ShowTooltip({}, "Title Only", nil)
        assert.equals(1, #_G.GameTooltip._lines)
        assert.equals("Title Only", _G.GameTooltip._lines[1].text)
    end)
end)
