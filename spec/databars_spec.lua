--[[
    Unit tests for LunarUI/Modules/DataBars.lua
    Tests pure formatting function: FormatBarText
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- FormatBarText 依賴 LunarUI.FormatValue，先載入 Utils.lua
local LunarUI = {}
loader.loadAddonFile("LunarUI/Core/Utils.lua", LunarUI)

-- 提供 DataBars 需要的最小 stub
LunarUI.Colors = { bgSolid = { 0, 0, 0, 0.8 }, border = { 0, 0, 0, 1 } }
LunarUI.RegisterModule = function() end
LunarUI.CreateEventHandler = function()
    return nil
end

loader.loadAddonFile("LunarUI/Modules/DataBars.lua", LunarUI)

--------------------------------------------------------------------------------
-- FormatBarText
--------------------------------------------------------------------------------

describe("FormatBarText", function()
    local FormatBarText = LunarUI.FormatBarText

    it("returns empty string for nil current", function()
        assert.equals("", FormatBarText("percent", nil, 100))
    end)

    it("returns empty string for nil max", function()
        assert.equals("", FormatBarText("percent", 50, nil))
    end)

    it("returns empty string for zero max", function()
        assert.equals("", FormatBarText("percent", 50, 0))
    end)

    it("formats percent mode", function()
        assert.equals("50%", FormatBarText("percent", 50, 100))
    end)

    it("formats curmax mode", function()
        local result = FormatBarText("curmax", 1500, 3000)
        assert.equals("1.5K / 3.0K", result)
    end)

    it("formats cur mode", function()
        assert.equals("1.5K", FormatBarText("cur", 1500, 3000))
    end)

    it("formats remaining mode", function()
        local result = FormatBarText("remaining", 1500, 3000)
        assert.equals("1.5K remaining", result)
    end)

    it("formats default with extra label", function()
        assert.equals("Level 10 50%", FormatBarText(nil, 50, 100, "Level 10"))
    end)

    it("formats default without extra label", function()
        assert.equals("50%", FormatBarText(nil, 50, 100))
    end)
end)
