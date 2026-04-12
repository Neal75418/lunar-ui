---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter
--[[
    Unit tests for LunarUI/Modules/DataBars.lua
    Tests: FormatBarText, GetStatusBarTexture, STANDING_COLORS,
           InitializeDataBars lifecycle, CleanupDataBars lifecycle
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- FormatBarText 依賴 LunarUI.FormatValue，先載入 Utils.lua
local LunarUI = {}
loader.loadAddonFile("LunarUI/Core/Utils.lua", LunarUI)

-- Mock frame factory（DataBars CreateDataBar 需要 StatusBar 型別 frame）
local function CreateMockStatusBar()
    local bar = {}
    bar.SetStatusBarTexture = function() end
    bar.SetSize = function() end
    bar.SetPoint = function() end
    bar.SetMinMaxValues = function() end
    bar.SetValue = function() end
    bar.SetFrameStrata = function() end
    bar.SetFrameLevel = function() end
    bar.SetStatusBarColor = function() end
    bar.GetWidth = function()
        return 400
    end
    bar.GetHeight = function()
        return 8
    end
    bar.GetStatusBarTexture = function()
        return bar
    end
    bar.SetWidth = function() end
    bar.SetHeight = function() end
    bar.ClearAllPoints = function() end
    bar.Show = function() end
    bar.Hide = function() end
    bar.IsShown = function()
        return false
    end
    bar.SetScript = function() end
    bar.HookScript = function() end
    bar.RegisterEvent = function() end
    bar.UnregisterEvent = function() end
    bar.UnregisterAllEvents = function() end
    bar.EnableMouse = function() end
    bar.SetBackdrop = function() end
    bar.SetBackdropColor = function() end
    bar.SetBackdropBorderColor = function() end
    bar.SetAlpha = function() end
    bar.SetAllPoints = function() end
    bar.SetTexture = function() end
    bar.SetVertexColor = function() end
    bar.SetDrawLayer = function() end
    bar.SetColorTexture = function() end
    bar.SetTexCoord = function() end
    bar.CreateTexture = function()
        local tex = {}
        tex.SetAllPoints = function() end
        tex.SetTexture = function() end
        tex.SetVertexColor = function() end
        tex.SetHeight = function() end
        tex.SetWidth = function() end
        tex.SetPoint = function() end
        tex.ClearAllPoints = function() end
        tex.Hide = function() end
        tex.Show = function() end
        return tex
    end
    bar.CreateFontString = function()
        local fs = {}
        fs.SetText = function() end
        fs.SetTextColor = function() end
        fs.SetJustifyH = function() end
        fs.SetPoint = function() end
        fs.SetFont = function() end
        fs.SetFontObject = function() end
        fs.Hide = function() end
        fs.Show = function() end
        fs.GetFontString = function()
            return fs
        end
        return fs
    end
    bar.GetFontString = function()
        return bar.CreateFontString()
    end
    return bar
end

_G.UIParent = CreateMockStatusBar()
_G.CreateFrame = function()
    return CreateMockStatusBar()
end
_G.UnitLevel = function()
    return 1
end
_G.GetMaxPlayerLevel = function()
    return 70
end
_G.UnitXP = function()
    return 0
end
_G.UnitXPMax = function()
    return 0
end
_G.GetXPExhaustion = function()
    return 0
end
_G.UnitHonor = function()
    return 0
end
_G.UnitHonorMax = function()
    return 0
end
_G.UnitHonorLevel = function()
    return 0
end
_G.C_Reputation = {
    GetWatchedFactionData = function()
        return nil
    end,
}
_G.GetWatchedFactionInfo = nil

-- 提供 DataBars 需要的最小 stub
LunarUI.Colors = {
    bgSolid = { 0, 0, 0, 0.8 },
    border = { 0, 0, 0, 1 },
    bgIcon = { 0.1, 0.1, 0.1, 0.6 },
}
LunarUI.RegisterModule = function() end
LunarUI.CreateEventHandler = function()
    return nil
end
LunarUI.GetSelectedStatusBarTexture = function()
    return "Interface\\TargetingFrame\\UI-StatusBar"
end
LunarUI.ApplyBackdrop = function() end
LunarUI.SetFont = function() end
LunarUI.Debug = function() end
LunarUI.db = {
    profile = {
        databars = {
            enabled = true,
            experience = { enabled = true, width = 400, height = 8, showText = false },
            reputation = { enabled = true, width = 400, height = 8, showText = false },
            honor = { enabled = true, width = 400, height = 8, showText = false },
        },
    },
}

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
        assert.truthy(result:find("1.5K"))
        assert.truthy(result:find("remaining"))
    end)

    it("formats default with extra label", function()
        assert.equals("Level 10 50%", FormatBarText(nil, 50, 100, "Level 10"))
    end)

    it("formats default without extra label", function()
        assert.equals("50%", FormatBarText(nil, 50, 100))
    end)
end)

--------------------------------------------------------------------------------
-- GetStatusBarTexture
--------------------------------------------------------------------------------

describe("GetStatusBarTexture", function()
    it("returns texture from GetSelectedStatusBarTexture", function()
        local result = LunarUI.GetStatusBarTexture()
        assert.equals("Interface\\TargetingFrame\\UI-StatusBar", result)
    end)

    it("returns same cached value on second call", function()
        local first = LunarUI.GetStatusBarTexture()
        local second = LunarUI.GetStatusBarTexture()
        assert.equals(first, second)
    end)
end)

--------------------------------------------------------------------------------
-- STANDING_COLORS
--------------------------------------------------------------------------------

describe("STANDING_COLORS", function()
    it("has entries for all 8 standings", function()
        for i = 1, 8 do
            assert.is_not_nil(LunarUI.STANDING_COLORS[i])
            assert.is_number(LunarUI.STANDING_COLORS[i].r)
            assert.is_number(LunarUI.STANDING_COLORS[i].g)
            assert.is_number(LunarUI.STANDING_COLORS[i].b)
        end
    end)

    it("returns nil for non-existent standing", function()
        assert.is_nil(LunarUI.STANDING_COLORS[0])
        assert.is_nil(LunarUI.STANDING_COLORS[9])
    end)
end)

--------------------------------------------------------------------------------
-- FormatBarText edge cases
--------------------------------------------------------------------------------

describe("FormatBarText edge cases", function()
    local FormatBarText = LunarUI.FormatBarText

    it("formats 0% correctly", function()
        assert.equals("0%", FormatBarText("percent", 0, 100))
    end)

    it("formats 100% correctly", function()
        assert.equals("100%", FormatBarText("percent", 100, 100))
    end)

    it("truncates fractional percent (floor)", function()
        -- 1/3 = 33.33...% should be 33%
        assert.equals("33%", FormatBarText("percent", 1, 3))
    end)

    it("formats remaining mode returns correct remaining amount", function()
        local result = FormatBarText("remaining", 500, 1000)
        assert.truthy(result:find("500"))
    end)

    it("formats default mode with nil extra returns just percent", function()
        assert.equals("75%", FormatBarText(nil, 75, 100, nil))
    end)
end)

--------------------------------------------------------------------------------
-- InitializeDataBars / CleanupDataBars lifecycle
--------------------------------------------------------------------------------

describe("InitializeDataBars lifecycle", function()
    it("does not error when db is nil (guard test)", function()
        local savedDb = LunarUI.db
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI.InitializeDataBars()
        end)
        LunarUI.db = savedDb
    end)

    it("does not error when db.enabled is false", function()
        local savedDb = LunarUI.db
        LunarUI.db = { profile = { databars = { enabled = false } } }
        assert.has_no_errors(function()
            LunarUI.InitializeDataBars()
        end)
        LunarUI.db = savedDb
    end)

    it("does not error with all bars enabled", function()
        assert.has_no_errors(function()
            LunarUI.InitializeDataBars()
        end)
    end)

    it("does not error with all bars disabled individually", function()
        local savedDb = LunarUI.db
        LunarUI.db = {
            profile = {
                databars = {
                    enabled = true,
                    experience = { enabled = false },
                    reputation = { enabled = false },
                    honor = { enabled = false },
                },
            },
        }
        assert.has_no_errors(function()
            LunarUI.InitializeDataBars()
        end)
        LunarUI.db = savedDb
    end)
end)

describe("CleanupDataBars lifecycle", function()
    it("does not error when called without prior init", function()
        assert.has_no_errors(function()
            LunarUI.CleanupDataBars()
        end)
    end)

    it("does not error after InitializeDataBars", function()
        assert.has_no_errors(function()
            LunarUI.InitializeDataBars()
            LunarUI.CleanupDataBars()
        end)
    end)

    it("can be called multiple times without error", function()
        assert.has_no_errors(function()
            LunarUI.CleanupDataBars()
            LunarUI.CleanupDataBars()
        end)
    end)
end)
