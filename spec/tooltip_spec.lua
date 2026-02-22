--[[
    Unit tests for Tooltip module pure functions
    Tests: GetLevelDifficultyColor, GetUnitColor, GetInspectItemLevel, GetInspectSpec,
           TooltipGetItemLevel, GetCachedInspectData, CacheInspectData, RequestInspect
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

--------------------------------------------------------------------------------
-- TooltipGetItemLevel
--------------------------------------------------------------------------------

describe("TooltipGetItemLevel", function()
    before_each(function()
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return nil
        end
    end)

    it("returns item level for valid link", function()
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return 489
        end
        assert.equals(489, LunarUI.TooltipGetItemLevel("item:12345"))
    end)

    it("returns nil when API returns nil", function()
        assert.is_nil(LunarUI.TooltipGetItemLevel("item:99999"))
    end)
end)

--------------------------------------------------------------------------------
-- GetCachedInspectData
--------------------------------------------------------------------------------

describe("GetCachedInspectData", function()
    before_each(function()
        LunarUI.ClearInspectCache()
        _G.GetTime = function()
            return 1000
        end
    end)

    it("returns nil for unknown guid", function()
        assert.is_nil(LunarUI.GetCachedInspectData("unknown-guid"))
    end)

    it("returns cached data within TTL", function()
        LunarUI.CacheInspectData("Player-1234", 480, "Arcane")
        local data = LunarUI.GetCachedInspectData("Player-1234")
        assert.is_truthy(data)
        assert.equals(480, data.ilvl)
        assert.equals("Arcane", data.spec)
    end)

    it("returns nil for expired data", function()
        LunarUI.CacheInspectData("Player-1234", 480, "Arcane")
        -- Advance time past TTL (30 seconds)
        _G.GetTime = function()
            return 1031
        end
        assert.is_nil(LunarUI.GetCachedInspectData("Player-1234"))
    end)

    it("returns nil after cache clear", function()
        LunarUI.CacheInspectData("Player-1234", 480, "Arcane")
        LunarUI.ClearInspectCache()
        assert.is_nil(LunarUI.GetCachedInspectData("Player-1234"))
    end)

    it("returns data at TTL boundary (29 seconds)", function()
        LunarUI.CacheInspectData("Player-1234", 480, "Arcane")
        _G.GetTime = function()
            return 1029
        end
        local data = LunarUI.GetCachedInspectData("Player-1234")
        assert.is_truthy(data)
    end)
end)

--------------------------------------------------------------------------------
-- CacheInspectData
--------------------------------------------------------------------------------

describe("CacheInspectData", function()
    before_each(function()
        LunarUI.ClearInspectCache()
        _G.GetTime = function()
            return 1000
        end
    end)

    it("stores ilvl, spec, and time correctly", function()
        LunarUI.CacheInspectData("Player-1234", 480, "Arcane")
        local data = LunarUI.GetCachedInspectData("Player-1234")
        assert.equals(480, data.ilvl)
        assert.equals("Arcane", data.spec)
        assert.equals(1000, data.time)
    end)

    it("overwrites existing entry for same guid", function()
        LunarUI.CacheInspectData("Player-1234", 480, "Arcane")
        LunarUI.CacheInspectData("Player-1234", 500, "Fire")
        local data = LunarUI.GetCachedInspectData("Player-1234")
        assert.equals(500, data.ilvl)
        assert.equals("Fire", data.spec)
    end)

    it("evicts expired entries during insert", function()
        LunarUI.CacheInspectData("Player-OLD", 400, "Frost")
        -- Advance past TTL
        _G.GetTime = function()
            return 1031
        end
        LunarUI.CacheInspectData("Player-NEW", 500, "Fire")
        -- Old entry should be evicted
        _G.GetTime = function()
            return 1031
        end
        assert.is_nil(LunarUI.GetCachedInspectData("Player-OLD"))
        assert.is_truthy(LunarUI.GetCachedInspectData("Player-NEW"))
    end)

    it("evicts oldest when exceeding max entries", function()
        -- Fill cache to max (50 entries)
        for i = 1, 50 do
            _G.GetTime = function()
                return 1000 + i
            end
            LunarUI.CacheInspectData("Player-" .. i, 400 + i, "Spec")
        end
        -- Add one more (should evict oldest = Player-1 at time 1001)
        _G.GetTime = function()
            return 1051
        end
        LunarUI.CacheInspectData("Player-51", 500, "Fire")
        -- Player-1 (oldest) should be evicted
        assert.is_nil(LunarUI.GetCachedInspectData("Player-1"))
        -- Player-51 (newest) should exist
        assert.is_truthy(LunarUI.GetCachedInspectData("Player-51"))
    end)

    it("handles nil spec gracefully", function()
        LunarUI.CacheInspectData("Player-1234", 480, nil)
        local data = LunarUI.GetCachedInspectData("Player-1234")
        assert.equals(480, data.ilvl)
        assert.is_nil(data.spec)
    end)
end)

--------------------------------------------------------------------------------
-- RequestInspect
--------------------------------------------------------------------------------

describe("RequestInspect", function()
    local notifyCalled
    -- 使用遞增時間基準，避免跨測試 lastInspectTime 殘留導致節流
    local timeBase = 100000

    before_each(function()
        timeBase = timeBase + 100
        LunarUI.ClearInspectCache()
        notifyCalled = false
        _G.CanInspect = function()
            return true
        end
        _G.InCombatLockdown = function()
            return false
        end
        _G.UnitGUID = function()
            return "Player-5678"
        end
        _G.NotifyInspect = function()
            notifyCalled = true
        end
        -- 用遞增時間確保不被前次測試節流
        _G.GetTime = function()
            return timeBase
        end
        -- 先發一次請求來重置 lastInspectTime
        LunarUI.RequestInspect("target")
        notifyCalled = false
        -- 推進時間超過節流間隔
        _G.GetTime = function()
            return timeBase + 2
        end
        -- 清除快取
        LunarUI.ClearInspectCache()
    end)

    it("calls NotifyInspect when all conditions pass", function()
        _G.UnitGUID = function()
            return "Player-NEW"
        end
        LunarUI.RequestInspect("target")
        assert.is_true(notifyCalled)
    end)

    it("does not call NotifyInspect when CanInspect is false", function()
        _G.CanInspect = function()
            return false
        end
        LunarUI.RequestInspect("target")
        assert.is_false(notifyCalled)
    end)

    it("does not call NotifyInspect in combat", function()
        _G.InCombatLockdown = function()
            return true
        end
        LunarUI.RequestInspect("target")
        assert.is_false(notifyCalled)
    end)

    it("does not call NotifyInspect when guid is nil", function()
        _G.UnitGUID = function()
            return nil
        end
        LunarUI.RequestInspect("target")
        assert.is_false(notifyCalled)
    end)

    it("does not call NotifyInspect when cache hit", function()
        local guid = "Player-CACHED"
        _G.UnitGUID = function()
            return guid
        end
        LunarUI.CacheInspectData(guid, 480, "Arcane")
        LunarUI.RequestInspect("target")
        assert.is_false(notifyCalled)
    end)

    it("throttles rapid requests", function()
        _G.UnitGUID = function()
            return "Player-A"
        end
        LunarUI.RequestInspect("target")
        assert.is_true(notifyCalled)
        -- 不推進時間，嘗試第二次請求
        notifyCalled = false
        _G.UnitGUID = function()
            return "Player-B"
        end
        LunarUI.RequestInspect("target")
        assert.is_false(notifyCalled)
    end)
end)
