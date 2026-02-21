--[[
    Unit tests for LunarUI/Core/Tags.lua
    Tests pure formatting functions: ShortValue, AbbreviateName
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Tags.lua 需要 oUF Tags 環境，提供 minimal stub
local LunarUI = {}
local extraEngine = {
    oUF = {
        Tags = {
            Methods = {},
            Events = {},
        },
    },
}
loader.loadAddonFile("LunarUI/Core/Tags.lua", LunarUI, extraEngine)

--------------------------------------------------------------------------------
-- ShortValue
--------------------------------------------------------------------------------

describe("ShortValue", function()
    local ShortValue = LunarUI.ShortValue

    it("returns empty string for nil", function()
        assert.equals("", ShortValue(nil))
    end)

    it("returns '0' for zero", function()
        assert.equals("0", ShortValue(0))
    end)

    it("returns raw number below 1000", function()
        assert.equals("999", ShortValue(999))
    end)

    it("formats thousands with K suffix", function()
        assert.equals("1.0K", ShortValue(1000))
    end)

    it("formats mid-thousands correctly", function()
        assert.equals("25.3K", ShortValue(25300))
    end)

    it("formats millions with M suffix", function()
        assert.equals("1.50M", ShortValue(1500000))
    end)

    it("formats exact million", function()
        assert.equals("1.00M", ShortValue(1000000))
    end)

    it("formats large millions", function()
        assert.equals("12.35M", ShortValue(12345678))
    end)
end)

--------------------------------------------------------------------------------
-- AbbreviateName
--------------------------------------------------------------------------------

describe("AbbreviateName", function()
    local AbbreviateName = LunarUI.AbbreviateName

    it("returns empty string for nil", function()
        assert.equals("", AbbreviateName(nil))
    end)

    it("returns single word unchanged", function()
        assert.equals("Thrall", AbbreviateName("Thrall"))
    end)

    it("abbreviates second word", function()
        assert.equals("Arthas M.", AbbreviateName("Arthas Menethil"))
    end)

    it("abbreviates multiple words", function()
        assert.equals("John S. J.", AbbreviateName("John Smith Junior"))
    end)

    it("returns empty string for empty input", function()
        assert.equals("", AbbreviateName(""))
    end)
end)
