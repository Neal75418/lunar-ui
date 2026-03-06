--[[
    Unit tests for LunarUI/UnitFrames/Layout.lua
    Tests: GetAuraSortFunction, RebuildAuraFilterCache, InvalidateStatusBarTextureCache,
           exported constants, lifecycle
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs used at module scope
_G.UnitIsPlayer = function()
    return false
end
_G.UnitReaction = function()
    return 4
end
_G.UnitClass = function()
    return "Warrior", "WARRIOR", 1
end
_G.UnitIsEnemy = function()
    return false
end
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
    PRIEST = { r = 1, g = 1, b = 1, colorStr = "ffffffff" },
}
_G.C_Timer = { After = function() end }
_G.InCombatLockdown = function()
    return false
end

require("spec.mock_frame")

local LunarUI = {
    Colors = {
        bgIcon = { 0, 0, 0, 0.8 },
        border = { 0.3, 0.3, 0.4, 1 },
        bgOverlay = { 0, 0, 0, 0.6 },
        borderSubtle = { 0.2, 0.2, 0.3, 1 },
    },
    DEBUFF_TYPE_COLORS = {
        none = { r = 0.8, g = 0, b = 0 },
        Magic = { r = 0.2, g = 0.6, b = 1 },
    },
    CreateBackdrop = function()
        return CreateFrame("Frame")
    end,
    StyleAuraButton = function() end,
    SetFont = function() end,
    GetSelectedStatusBarTexture = function()
        return "Interface\\TargetingFrame\\UI-StatusBar"
    end,
    RegisterModule = function() end,
    CreateEventHandler = function()
        return setmetatable({
            _events = {},
            RegisterEvent = function(self, e)
                self._events[e] = true
            end,
            SetScript = function() end,
            UnregisterAllEvents = function() end,
        }, {})
    end,
    db = {
        profile = {
            auraWhitelist = "",
            auraBlacklist = "",
            auraFilters = {
                sortMethod = "time",
                sortReverse = false,
            },
            unitframes = {},
        },
    },
}

-- oUF mock：提供 Layout.lua 模組範圍呼叫所需的方法
local oUFMock = {
    colors = { power = {} },
    RegisterStyle = function() end,
    SetActiveStyle = function() end,
    Spawn = function()
        return CreateFrame("Frame")
    end,
    SpawnHeader = function()
        return CreateFrame("Frame")
    end,
}

-- 載入 Layout.lua — 透過 extraEngine 提供 oUF mock
loader.loadAddonFile("LunarUI/UnitFrames/Layout.lua", LunarUI, { oUF = oUFMock })

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

describe("Layout exports", function()
    it("exports GetAuraSortFunction as function", function()
        assert.is_function(LunarUI.GetAuraSortFunction)
    end)

    it("exports RebuildAuraFilterCache as function", function()
        assert.is_function(LunarUI.RebuildAuraFilterCache)
    end)

    it("exports InvalidateStatusBarTextureCache as function", function()
        assert.is_function(LunarUI.InvalidateStatusBarTextureCache)
    end)

    it("exports SpawnUnitFrames as function", function()
        assert.is_function(LunarUI.SpawnUnitFrames)
    end)

    it("exports CleanupUnitFrames as function", function()
        assert.is_function(LunarUI.CleanupUnitFrames)
    end)

    it("exports spawnedFrames as table", function()
        assert.is_table(LunarUI.spawnedFrames)
    end)
end)

--------------------------------------------------------------------------------
-- InvalidateStatusBarTextureCache
--------------------------------------------------------------------------------

describe("InvalidateStatusBarTextureCache", function()
    it("does not error when called", function()
        assert.has_no_errors(function()
            LunarUI.InvalidateStatusBarTextureCache()
        end)
    end)

    it("can be called multiple times", function()
        assert.has_no_errors(function()
            LunarUI.InvalidateStatusBarTextureCache()
            LunarUI.InvalidateStatusBarTextureCache()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- RebuildAuraFilterCache
--------------------------------------------------------------------------------

describe("RebuildAuraFilterCache", function()
    before_each(function()
        LunarUI.db = {
            profile = {
                auraWhitelist = "",
                auraBlacklist = "",
                auraFilters = { sortMethod = "time", sortReverse = false },
                unitframes = {},
            },
        }
    end)

    it("does not error with empty lists", function()
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)

    it("does not error with populated whitelist", function()
        LunarUI.db.profile.auraWhitelist = "123,456,789"
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)

    it("does not error with populated blacklist", function()
        LunarUI.db.profile.auraBlacklist = "100,200,300"
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)

    it("does not error with both lists populated", function()
        LunarUI.db.profile.auraWhitelist = "123,456"
        LunarUI.db.profile.auraBlacklist = "789,012"
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)

    it("handles whitespace in spell ID lists", function()
        LunarUI.db.profile.auraWhitelist = " 123 , 456 , 789 "
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)

    it("handles nil profile gracefully", function()
        LunarUI.db.profile = nil
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)

    it("can be called repeatedly (cache rebuild)", function()
        LunarUI.db.profile.auraWhitelist = "111,222"
        LunarUI.RebuildAuraFilterCache()
        LunarUI.db.profile.auraWhitelist = "333,444"
        assert.has_no_errors(function()
            LunarUI.RebuildAuraFilterCache()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- GetAuraSortFunction
--------------------------------------------------------------------------------

describe("GetAuraSortFunction", function()
    before_each(function()
        LunarUI.db = {
            profile = {
                auraWhitelist = "",
                auraBlacklist = "",
                auraFilters = { sortMethod = "time", sortReverse = false },
                unitframes = {},
            },
        }
    end)

    -- Helper: create mock aura data
    local function mockAura(overrides)
        local aura = {
            name = "Test",
            expirationTime = 1010,
            duration = 10,
            isPlayerAura = false,
        }
        if overrides then
            for k, v in pairs(overrides) do
                aura[k] = v
            end
        end
        return aura
    end

    ---- sortMethod = "time" ----

    describe("sortMethod = time", function()
        before_each(function()
            LunarUI.db.profile.auraFilters.sortMethod = "time"
            LunarUI.db.profile.auraFilters.sortReverse = false
        end)

        it("returns a function", function()
            local fn = LunarUI.GetAuraSortFunction()
            assert.is_function(fn)
        end)

        it("sorts earlier expiration first", function()
            local fn = LunarUI.GetAuraSortFunction()
            local a = mockAura({ expirationTime = 1005 })
            local b = mockAura({ expirationTime = 1020 })
            assert.is_true(fn(a, b))
            assert.is_false(fn(b, a))
        end)

        it("treats 0 expirationTime as permanent (sorts last)", function()
            local fn = LunarUI.GetAuraSortFunction()
            local permanent = mockAura({ expirationTime = 0 })
            local timed = mockAura({ expirationTime = 1010 })
            -- permanent should sort after timed
            assert.is_false(fn(permanent, timed))
            assert.is_true(fn(timed, permanent))
        end)

        it("handles nil expirationTime as permanent (sorts last)", function()
            local fn = LunarUI.GetAuraSortFunction()
            local nilTime = mockAura()
            nilTime.expirationTime = nil -- pairs() skips nil, so set after construction
            local timed = mockAura({ expirationTime = 1010 })
            -- nil → SanitizeNumber → 0 → math.huge (permanent, sorts last)
            assert.is_false(fn(nilTime, timed))
            assert.is_true(fn(timed, nilTime))
        end)

        it("reverse sorts later expiration first", function()
            LunarUI.db.profile.auraFilters.sortReverse = true
            local fn = LunarUI.GetAuraSortFunction()
            local a = mockAura({ expirationTime = 1005 })
            local b = mockAura({ expirationTime = 1020 })
            assert.is_false(fn(a, b))
            assert.is_true(fn(b, a))
        end)
    end)

    ---- sortMethod = "duration" ----

    describe("sortMethod = duration", function()
        before_each(function()
            LunarUI.db.profile.auraFilters.sortMethod = "duration"
            LunarUI.db.profile.auraFilters.sortReverse = false
        end)

        it("returns a function", function()
            local fn = LunarUI.GetAuraSortFunction()
            assert.is_function(fn)
        end)

        it("sorts shorter duration first", function()
            local fn = LunarUI.GetAuraSortFunction()
            local short = mockAura({ duration = 5 })
            local long = mockAura({ duration = 30 })
            assert.is_true(fn(short, long))
            assert.is_false(fn(long, short))
        end)

        it("handles nil duration as 0", function()
            local fn = LunarUI.GetAuraSortFunction()
            local nilDur = mockAura()
            nilDur.duration = nil -- pairs() skips nil, so set after construction
            local hasDur = mockAura({ duration = 10 })
            assert.is_true(fn(nilDur, hasDur))
        end)

        it("reverse sorts longer duration first", function()
            LunarUI.db.profile.auraFilters.sortReverse = true
            local fn = LunarUI.GetAuraSortFunction()
            local short = mockAura({ duration = 5 })
            local long = mockAura({ duration = 30 })
            assert.is_false(fn(short, long))
            assert.is_true(fn(long, short))
        end)
    end)

    ---- sortMethod = "name" ----

    describe("sortMethod = name", function()
        before_each(function()
            LunarUI.db.profile.auraFilters.sortMethod = "name"
            LunarUI.db.profile.auraFilters.sortReverse = false
        end)

        it("returns a function", function()
            local fn = LunarUI.GetAuraSortFunction()
            assert.is_function(fn)
        end)

        it("sorts alphabetically", function()
            local fn = LunarUI.GetAuraSortFunction()
            local a = mockAura({ name = "Arcane Intellect" })
            local b = mockAura({ name = "Blessing of Might" })
            assert.is_true(fn(a, b))
            assert.is_false(fn(b, a))
        end)

        it("handles nil name as empty string", function()
            local fn = LunarUI.GetAuraSortFunction()
            local nilName = mockAura()
            nilName.name = nil -- pairs() skips nil, so set after construction
            local hasName = mockAura({ name = "Buff" })
            -- "" < "Buff"
            assert.is_true(fn(nilName, hasName))
        end)

        it("reverse sorts reverse alphabetical", function()
            LunarUI.db.profile.auraFilters.sortReverse = true
            local fn = LunarUI.GetAuraSortFunction()
            local a = mockAura({ name = "Arcane Intellect" })
            local b = mockAura({ name = "Blessing of Might" })
            assert.is_false(fn(a, b))
            assert.is_true(fn(b, a))
        end)
    end)

    ---- sortMethod = "player" ----

    describe("sortMethod = player", function()
        before_each(function()
            LunarUI.db.profile.auraFilters.sortMethod = "player"
            LunarUI.db.profile.auraFilters.sortReverse = false
        end)

        it("returns a function", function()
            local fn = LunarUI.GetAuraSortFunction()
            assert.is_function(fn)
        end)

        it("player auras sort before non-player", function()
            local fn = LunarUI.GetAuraSortFunction()
            local playerAura = mockAura({ isPlayerAura = true, expirationTime = 1020 })
            local otherAura = mockAura({ isPlayerAura = false, expirationTime = 1005 })
            assert.is_true(fn(playerAura, otherAura))
            assert.is_false(fn(otherAura, playerAura))
        end)

        it("same category falls back to time sort", function()
            local fn = LunarUI.GetAuraSortFunction()
            local a = mockAura({ isPlayerAura = true, expirationTime = 1005 })
            local b = mockAura({ isPlayerAura = true, expirationTime = 1020 })
            assert.is_true(fn(a, b))
            assert.is_false(fn(b, a))
        end)

        it("reverse puts non-player auras first", function()
            LunarUI.db.profile.auraFilters.sortReverse = true
            local fn = LunarUI.GetAuraSortFunction()
            local playerAura = mockAura({ isPlayerAura = true })
            local otherAura = mockAura({ isPlayerAura = false })
            assert.is_false(fn(playerAura, otherAura))
            assert.is_true(fn(otherAura, playerAura))
        end)
    end)

    ---- Unknown / nil method ----

    describe("unknown method", function()
        it("returns nil for unknown sortMethod", function()
            LunarUI.db.profile.auraFilters.sortMethod = "unknown"
            local fn = LunarUI.GetAuraSortFunction()
            assert.is_nil(fn)
        end)

        it("defaults to time when sortMethod is nil", function()
            LunarUI.db.profile.auraFilters.sortMethod = nil
            local fn = LunarUI.GetAuraSortFunction()
            -- nil → "time" (default via `or "time"`)
            assert.is_function(fn)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- CleanupUnitFrames
--------------------------------------------------------------------------------

describe("CleanupUnitFrames", function()
    it("does not error when no frames spawned", function()
        assert.has_no_errors(function()
            LunarUI.CleanupUnitFrames()
        end)
    end)
end)
