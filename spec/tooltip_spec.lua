--[[
    Unit tests for Tooltip module pure functions
    Tests: GetLevelDifficultyColor, GetUnitColor, GetInspectItemLevel, GetInspectSpec
]]

require("spec.wow_mock")
local loader = require("spec.loader")

_G.math.floor = math.floor

-- WoW API stubs
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    PRIEST = { r = 1.0, g = 1.0, b = 1.0 },
}

_G.UnitLevel = function()
    return 70
end
_G.UnitIsPlayer = function()
    return false
end
_G.UnitClass = function()
    return "Unknown", "UNKNOWN"
end
_G.UnitReaction = function()
    return nil
end
_G.UnitExists = function()
    return true
end
_G.UnitGUID = function()
    return "Player-1234"
end
_G.CanInspect = function()
    return false
end
_G.InCombatLockdown = function()
    return false
end
_G.NotifyInspect = function() end
_G.GetTime = function()
    return 1000
end
_G.GetInventoryItemLink = function()
    return nil
end
_G.GetInspectSpecialization = function()
    return 0
end
_G.GetSpecializationInfoByID = function()
    return nil, nil
end
_G.ClearInspectPlayer = function() end
_G.IsShiftKeyDown = function()
    return false
end

_G.C_Item = {
    GetDetailedItemLevelInfo = function()
        return nil
    end,
}
_G.C_TooltipInfo = {
    GetHyperlink = function()
        return nil
    end,
}

-- GameTooltip stub
_G.GameTooltip = {
    IsShown = function()
        return false
    end,
    GetUnit = function()
        return nil, nil
    end,
    GetItem = function()
        return nil
    end,
    HookScript = function() end,
    SetBackdrop = function() end,
    SetBackdropColor = function() end,
    SetBackdropBorderColor = function() end,
    NumLines = function()
        return 0
    end,
}

_G.hooksecurefunc = function() end

-- LunarUI addon table
local LunarUI = {}
LunarUI.Colors = {
    bgSolid = { 0, 0, 0, 0.8 },
    border = { 0.15, 0.12, 0.08, 1 },
}
LunarUI.SetFont = function() end
LunarUI.SetFontLight = function() end
LunarUI.ApplyBackdrop = function() end
LunarUI.RegisterModule = function() end
LunarUI.CreateEventHandler = function()
    return nil
end
LunarUI.Debug = function() end
LunarUI.IsDebugMode = function()
    return false
end
LunarUI.db = { profile = { tooltip = { enabled = true } } }

loader.loadAddonFile("LunarUI/Modules/Tooltip.lua", LunarUI)

--------------------------------------------------------------------------------
-- GetLevelDifficultyColor
--------------------------------------------------------------------------------

describe("GetLevelDifficultyColor", function()
    before_each(function()
        _G.UnitLevel = function()
            return 70
        end
    end)

    it("returns red for 5+ levels higher", function()
        local r, g, b = LunarUI.GetLevelDifficultyColor(75)
        assert.equals(0.9, r)
        assert.equals(0.2, g)
        assert.equals(0.2, b)
    end)

    it("returns orange for 3-4 levels higher", function()
        local r, g, b = LunarUI.GetLevelDifficultyColor(73)
        assert.equals(0.9, r)
        assert.equals(0.5, g)
        assert.equals(0.1, b)
    end)

    it("returns yellow for same level range (-2 to +2)", function()
        local r, g, b = LunarUI.GetLevelDifficultyColor(70)
        assert.equals(0.9, r)
        assert.equals(0.9, g)
        assert.equals(0.2, b)
    end)

    it("returns green for lower level (-8 to -3)", function()
        local r, g, b = LunarUI.GetLevelDifficultyColor(65)
        assert.equals(0.2, r)
        assert.equals(0.8, g)
        assert.equals(0.2, b)
    end)

    it("returns grey for very low level (< -8)", function()
        local r, g, b = LunarUI.GetLevelDifficultyColor(50)
        assert.equals(0.6, r)
        assert.equals(0.6, g)
        assert.equals(0.6, b)
    end)

    it("handles boundary: exactly +5 (red)", function()
        local r = LunarUI.GetLevelDifficultyColor(75)
        assert.equals(0.9, r)
    end)

    it("handles boundary: exactly -2 (yellow)", function()
        local r, g = LunarUI.GetLevelDifficultyColor(68)
        assert.equals(0.9, r)
        assert.equals(0.9, g)
    end)

    it("handles boundary: exactly -3 (green)", function()
        local r, g = LunarUI.GetLevelDifficultyColor(67)
        assert.equals(0.2, r)
        assert.equals(0.8, g)
    end)
end)

--------------------------------------------------------------------------------
-- GetUnitColor
--------------------------------------------------------------------------------

describe("GetUnitColor", function()
    before_each(function()
        _G.UnitIsPlayer = function()
            return false
        end
        _G.UnitClass = function()
            return "Unknown", "UNKNOWN"
        end
        _G.UnitReaction = function()
            return nil
        end
    end)

    it("returns class color for player unit", function()
        _G.UnitIsPlayer = function()
            return true
        end
        _G.UnitClass = function()
            return "Mage", "MAGE"
        end
        local r, g, b = LunarUI.GetUnitColor("target")
        assert.equals(0.25, r)
        assert.equals(0.78, g)
        assert.equals(0.92, b)
    end)

    it("returns green for friendly NPC (reaction >= 5)", function()
        _G.UnitReaction = function()
            return 5
        end
        local r, g, b = LunarUI.GetUnitColor("target")
        assert.equals(0.2, r)
        assert.equals(0.8, g)
        assert.equals(0.2, b)
    end)

    it("returns yellow for neutral NPC (reaction = 4)", function()
        _G.UnitReaction = function()
            return 4
        end
        local r, g, b = LunarUI.GetUnitColor("target")
        assert.equals(1, r)
        assert.equals(1, g)
        assert.equals(0, b)
    end)

    it("returns red for hostile NPC (reaction < 4)", function()
        _G.UnitReaction = function()
            return 2
        end
        local r, g, b = LunarUI.GetUnitColor("target")
        assert.equals(0.8, r)
        assert.equals(0.2, g)
        assert.equals(0.2, b)
    end)

    it("returns white when no reaction data", function()
        local r, g, b = LunarUI.GetUnitColor("target")
        assert.equals(1, r)
        assert.equals(1, g)
        assert.equals(1, b)
    end)
end)

--------------------------------------------------------------------------------
-- GetInspectItemLevel
--------------------------------------------------------------------------------

describe("GetInspectItemLevel", function()
    before_each(function()
        _G.GetInventoryItemLink = function()
            return nil
        end
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return nil
        end
    end)

    it("returns nil when no items equipped", function()
        assert.is_nil(LunarUI.GetInspectItemLevel("target"))
    end)

    it("calculates average ilvl for fully equipped unit", function()
        _G.GetInventoryItemLink = function()
            return "item:12345"
        end
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return 480
        end
        -- 16 slots all at ilvl 480 → average = 480
        assert.equals(480, LunarUI.GetInspectItemLevel("target"))
    end)

    it("averages only equipped slots", function()
        local equipped = { [1] = 500, [5] = 450 } -- head=500, chest=450
        _G.GetInventoryItemLink = function(_, slot)
            if equipped[slot] then
                return "item:" .. slot
            end
            return nil
        end
        _G.C_Item.GetDetailedItemLevelInfo = function(link)
            local slot = tonumber(link:match("item:(%d+)"))
            return equipped[slot]
        end
        -- (500 + 450) / 2 = 475
        assert.equals(475, LunarUI.GetInspectItemLevel("target"))
    end)

    it("rounds to nearest integer", function()
        local equipped = { [1] = 501, [5] = 500 }
        _G.GetInventoryItemLink = function(_, slot)
            if equipped[slot] then
                return "item:" .. slot
            end
            return nil
        end
        _G.C_Item.GetDetailedItemLevelInfo = function(link)
            local slot = tonumber(link:match("item:(%d+)"))
            return equipped[slot]
        end
        -- (501 + 500) / 2 = 500.5 → rounds to 501
        assert.equals(501, LunarUI.GetInspectItemLevel("target"))
    end)
end)

--------------------------------------------------------------------------------
-- GetInspectSpec
--------------------------------------------------------------------------------

describe("GetInspectSpec", function()
    before_each(function()
        _G.GetInspectSpecialization = function()
            return 0
        end
        _G.GetSpecializationInfoByID = function()
            return nil, nil
        end
    end)

    it("returns nil when specID is 0", function()
        assert.is_nil(LunarUI.GetInspectSpec("target"))
    end)

    it("returns spec name for valid specID", function()
        _G.GetInspectSpecialization = function()
            return 62
        end
        _G.GetSpecializationInfoByID = function()
            return 62, "Arcane"
        end
        assert.equals("Arcane", LunarUI.GetInspectSpec("target"))
    end)

    it("returns nil when GetInspectSpecialization not available", function()
        _G.GetInspectSpecialization = nil
        assert.is_nil(LunarUI.GetInspectSpec("target"))
    end)

    it("returns nil when specID is nil", function()
        _G.GetInspectSpecialization = function()
            return nil
        end
        assert.is_nil(LunarUI.GetInspectSpec("target"))
    end)
end)
