--[[
    Unit tests for LunarUI/Core/Utils.lua
    Tests pure logic utility functions: FormatValue, FormatDuration,
    StatusColor, ThresholdColor, GetNestedValue, HexToRGB, RGBToHex
]]

require("spec.wow_mock")
local loader = require("spec.loader")

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

        it("returns red for high values", function()
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
