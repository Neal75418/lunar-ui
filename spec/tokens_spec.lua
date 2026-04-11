---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Core/Tokens.lua
    Tests easing functions: InQuad, OutQuad
]]

require("spec.wow_mock")
local loader = require("spec.loader")

local LunarUI = {}
loader.loadAddonFile("LunarUI/Core/Tokens.lua", LunarUI)

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
