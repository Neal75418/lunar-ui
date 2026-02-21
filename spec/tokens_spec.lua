--[[
    Unit tests for LunarUI/Core/Tokens.lua
    Tests easing functions: Linear, InQuad, OutQuad, InOutQuad
]]

require("spec.wow_mock")
local loader = require("spec.loader")

local LunarUI = {}
loader.loadAddonFile("LunarUI/Core/Tokens.lua", LunarUI)

--------------------------------------------------------------------------------
-- Easing: Linear
--------------------------------------------------------------------------------

describe("Easing.Linear", function()
    local Linear = LunarUI.Easing.Linear

    it("returns begin value at t=0", function()
        assert.equals(0, Linear(0, 0, 1, 1))
    end)

    it("returns begin+change at t=duration", function()
        assert.equals(1, Linear(1, 0, 1, 1))
    end)

    it("returns midpoint at half duration", function()
        assert.equals(0.5, Linear(0.5, 0, 1, 1))
    end)

    it("works with custom begin and change", function()
        assert.equals(15, Linear(0.5, 10, 10, 1))
    end)

    it("works with non-unit duration", function()
        assert.equals(5, Linear(1, 0, 10, 2))
    end)

    it("handles negative change", function()
        assert.equals(-0.5, Linear(0.5, 0, -1, 1))
    end)
end)

--------------------------------------------------------------------------------
-- Easing: InQuad
--------------------------------------------------------------------------------

describe("Easing.InQuad", function()
    local InQuad = LunarUI.Easing.InQuad

    it("returns begin value at t=0", function()
        assert.equals(0, InQuad(0, 0, 1, 1))
    end)

    it("returns begin+change at t=duration", function()
        assert.equals(1, InQuad(1, 0, 1, 1))
    end)

    it("returns less than linear at midpoint (ease in)", function()
        -- (0.5/1)^2 * 1 + 0 = 0.25
        assert.equals(0.25, InQuad(0.5, 0, 1, 1))
    end)

    it("works with custom begin and change", function()
        -- 10 + 10 * (0.5)^2 = 12.5
        assert.equals(12.5, InQuad(0.5, 10, 10, 1))
    end)

    it("works with non-unit duration", function()
        -- (1/2)^2 * 10 + 0 = 2.5
        assert.equals(2.5, InQuad(1, 0, 10, 2))
    end)
end)

--------------------------------------------------------------------------------
-- Easing: OutQuad
--------------------------------------------------------------------------------

describe("Easing.OutQuad", function()
    local OutQuad = LunarUI.Easing.OutQuad

    it("returns begin value at t=0", function()
        assert.equals(0, OutQuad(0, 0, 1, 1))
    end)

    it("returns begin+change at t=duration", function()
        assert.equals(1, OutQuad(1, 0, 1, 1))
    end)

    it("returns more than linear at midpoint (ease out)", function()
        -- -1 * (0.5) * (0.5 - 2) + 0 = -0.5 * -1.5 = 0.75
        assert.equals(0.75, OutQuad(0.5, 0, 1, 1))
    end)

    it("works with custom begin and change", function()
        -- 10 + (-10) * 0.5 * (0.5 - 2) = 10 + -10 * -0.75 = 17.5
        assert.equals(17.5, OutQuad(0.5, 10, 10, 1))
    end)

    it("works with non-unit duration", function()
        -- -10 * (0.5) * (0.5 - 2) + 0 = -10 * -0.75 = 7.5
        assert.equals(7.5, OutQuad(1, 0, 10, 2))
    end)
end)

--------------------------------------------------------------------------------
-- Easing: InOutQuad
--------------------------------------------------------------------------------

describe("Easing.InOutQuad", function()
    local InOutQuad = LunarUI.Easing.InOutQuad

    it("returns begin value at t=0", function()
        assert.equals(0, InOutQuad(0, 0, 1, 1))
    end)

    it("returns begin+change at t=duration", function()
        assert.equals(1, InOutQuad(1, 0, 1, 1))
    end)

    it("returns exactly midpoint at half duration", function()
        -- t = 0.5/(0.5) = 1, t < 1 boundary: c/2 * 1^2 + b = 0.5
        assert.equals(0.5, InOutQuad(0.5, 0, 1, 1))
    end)

    it("first half behaves like ease-in", function()
        -- t = 0.25/0.5 = 0.5, t < 1: c/2 * 0.5^2 = 0.5 * 0.25 = 0.125
        assert.equals(0.125, InOutQuad(0.25, 0, 1, 1))
    end)

    it("second half behaves like ease-out", function()
        -- t = 0.75/0.5 = 1.5, t >= 1: t-1 = 0.5
        -- -c/2 * (0.5*(0.5-2) - 1) = -0.5 * (0.5*-1.5 - 1) = -0.5 * (-0.75-1) = -0.5 * -1.75 = 0.875
        assert.equals(0.875, InOutQuad(0.75, 0, 1, 1))
    end)

    it("is symmetric around midpoint", function()
        local quarter = InOutQuad(0.25, 0, 1, 1)
        local threeQuarter = InOutQuad(0.75, 0, 1, 1)
        -- quarter + threeQuarter should equal 1 (symmetric)
        assert.near(1.0, quarter + threeQuarter, 0.0001)
    end)

    it("works with custom begin and change", function()
        -- t=0.25, b=10, c=20, d=1: 10 + 20 * 0.125 = 12.5
        assert.equals(12.5, InOutQuad(0.25, 10, 20, 1))
    end)
end)
