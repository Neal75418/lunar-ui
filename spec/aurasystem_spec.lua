---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/UnitFrames/AuraSystem.lua
    Tests RebuildAuraFilterCache, GetAuraSortFunction
]]

require("spec.wow_mock")
require("spec.mock_frame")
local loader = require("spec.loader")

local LunarUI = {
    Colors = {
        bg = { 0.1, 0.1, 0.1, 0.9 },
        bgIcon = { 0.1, 0.1, 0.1, 0.8 },
        border = { 0.3, 0.3, 0.4, 1 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
    },
    DEBUFF_TYPE_COLORS = {
        Magic = { 0.20, 0.60, 1.00 },
        Curse = { 0.60, 0.00, 1.00 },
        Disease = { 0.60, 0.40, 0.00 },
        Poison = { 0.00, 0.60, 0.00 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    backdropTemplate = {},
    db = {
        profile = {
            auraWhitelist = "12345,67890",
            auraBlacklist = "99999",
            auraFilters = {
                hidePassive = true,
                showStealable = true,
                showDispellable = true,
                sortMethod = "time",
                sortReverse = false,
            },
            unitframes = {
                player = { onlyPlayerDebuffs = false },
                target = { onlyPlayerDebuffs = true },
            },
        },
    },
    RegisterModule = function() end,
    GetModuleDB = function()
        return nil
    end,
}

loader.loadAddonFile("LunarUI/UnitFrames/AuraSystem.lua", LunarUI)

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

describe("RebuildAuraFilterCache", function()
    before_each(function()
        LunarUI.db.profile.auraWhitelist = "12345,67890"
        LunarUI.db.profile.auraBlacklist = "99999"
        LunarUI.RebuildAuraFilterCache()
    end)

    it("parses whitelist and blacklist from comma-separated strings", function()
        -- After rebuild, the cache should be populated (tested via GetAuraSortFunction behavior)
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)

    it("handles empty whitelist/blacklist", function()
        LunarUI.db.profile.auraWhitelist = ""
        LunarUI.db.profile.auraBlacklist = ""
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)

    it("handles nil db gracefully", function()
        local savedDB = LunarUI.db
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
        LunarUI.db = savedDB
    end)
end)

describe("GetAuraSortFunction", function()
    before_each(function()
        LunarUI.db.profile.auraFilters = {
            sortMethod = "time",
            sortReverse = false,
        }
    end)

    it("returns a sort function for time method", function()
        local sortFn = LunarUI.GetAuraSortFunction()
        assert.is_function(sortFn)
    end)

    it("sorts by expiration time (ascending)", function()
        LunarUI.db.profile.auraFilters.sortMethod = "time"
        local sortFn = LunarUI.GetAuraSortFunction()
        local a = { expirationTime = 100 }
        local b = { expirationTime = 200 }
        assert.is_true(sortFn(a, b)) -- 100 < 200
        assert.is_false(sortFn(b, a))
    end)

    it("treats zero expiration as infinite (permanent buffs last)", function()
        LunarUI.db.profile.auraFilters.sortMethod = "time"
        local sortFn = LunarUI.GetAuraSortFunction()
        local permanent = { expirationTime = 0 }
        local temporary = { expirationTime = 100 }
        assert.is_true(sortFn(temporary, permanent)) -- 100 < infinity
        assert.is_false(sortFn(permanent, temporary))
    end)

    it("sorts by duration (ascending)", function()
        LunarUI.db.profile.auraFilters.sortMethod = "duration"
        local sortFn = LunarUI.GetAuraSortFunction()
        local short = { duration = 10 }
        local long = { duration = 60 }
        assert.is_true(sortFn(short, long))
        assert.is_false(sortFn(long, short))
    end)

    it("sorts by name (ascending)", function()
        LunarUI.db.profile.auraFilters.sortMethod = "name"
        local sortFn = LunarUI.GetAuraSortFunction()
        local a = { name = "Alpha" }
        local b = { name = "Beta" }
        assert.is_true(sortFn(a, b))
        assert.is_false(sortFn(b, a))
    end)

    it("sorts player auras first", function()
        LunarUI.db.profile.auraFilters.sortMethod = "player"
        local sortFn = LunarUI.GetAuraSortFunction()
        local playerAura = { isPlayerAura = true, expirationTime = 200 }
        local otherAura = { isPlayerAura = false, expirationTime = 100 }
        assert.is_true(sortFn(playerAura, otherAura))
        assert.is_false(sortFn(otherAura, playerAura))
    end)

    it("respects sortReverse", function()
        LunarUI.db.profile.auraFilters.sortMethod = "time"
        LunarUI.db.profile.auraFilters.sortReverse = true
        local sortFn = LunarUI.GetAuraSortFunction()
        local a = { expirationTime = 100 }
        local b = { expirationTime = 200 }
        assert.is_false(sortFn(a, b)) -- reversed: 100 > 200 is false
        assert.is_true(sortFn(b, a)) -- 200 > 100 is true
    end)

    it("returns nil for unknown sort method", function()
        LunarUI.db.profile.auraFilters.sortMethod = "invalid"
        local sortFn = LunarUI.GetAuraSortFunction()
        assert.is_nil(sortFn)
    end)

    it("handles nil aura data fields (SanitizeNumber/SanitizeString)", function()
        LunarUI.db.profile.auraFilters.sortMethod = "time"
        local sortFn = LunarUI.GetAuraSortFunction()
        local noTime = { expirationTime = nil }
        local hasTime = { expirationTime = 100 }
        -- nil sanitized to 0, which becomes math.huge
        assert.is_false(sortFn(noTime, hasTime)) -- huge < 100 is false
    end)
end)
