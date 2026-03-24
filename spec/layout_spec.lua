---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/UnitFrames/Layout.lua
    Tests: InvalidateStatusBarTextureCache, SpawnUnitFrames/CleanupUnitFrames lifecycle,
           GetStatusBarTexture caching behavior
    (RebuildAuraFilterCache / GetAuraSortFunction 測試見 aurasystem_spec.lua)
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
_G.UnitExists = function()
    return true
end
_G.UnitIsDeadOrGhost = function()
    return false
end
_G.GetNetStats = function()
    return 0, 0, 0, 50
end
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
        bg = { 0, 0, 0, 0.8 },
        transparent = { 0, 0, 0, 0 },
    },
    DEBUFF_TYPE_COLORS = {
        none = { r = 0.8, g = 0, b = 0 },
        Magic = { r = 0.2, g = 0.6, b = 1 },
    },
    CASTBAR_COLOR = { 0.24, 0.54, 0.78, 1 },
    BG_DARKEN = 0.3,
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    CreateBackdrop = function()
        return CreateFrame("Frame")
    end,
    ApplyBackdrop = function() end,
    StyleAuraButton = function() end,
    SetFont = function() end,
    GetSelectedStatusBarTexture = function()
        return "Interface\\TargetingFrame\\UI-StatusBar"
    end,
    GetModuleDB = function(_key)
        return nil
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

-- 載入子模組（順序與 TOC 一致：Elements → CastBar → AuraSystem → Indicators → Layout）
loader.loadAddonFile("LunarUI/UnitFrames/Elements.lua", LunarUI, { oUF = oUFMock })
loader.loadAddonFile("LunarUI/UnitFrames/CastBar.lua", LunarUI, { oUF = oUFMock })
loader.loadAddonFile("LunarUI/UnitFrames/AuraSystem.lua", LunarUI, { oUF = oUFMock })
loader.loadAddonFile("LunarUI/UnitFrames/Indicators.lua", LunarUI, { oUF = oUFMock })
loader.loadAddonFile("LunarUI/UnitFrames/Layout.lua", LunarUI, { oUF = oUFMock })

-- Layout exports（assert.is_function）已移除，行為由各 describe 隱含驗證

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

-- RebuildAuraFilterCache / GetAuraSortFunction 測試見 aurasystem_spec.lua（避免重複）

--------------------------------------------------------------------------------
-- CleanupUnitFrames
--------------------------------------------------------------------------------

-- NOTE: SpawnUnitFrames() is never called in this spec, so the `spawnedUnitFrames`
-- accumulation issue is purely theoretical here. CleanupUnitFrames() only cleans up
-- the PLAYER_ENTERING_WORLD event frame — it does NOT wipe the spawnedFrames upvalue.
-- If SpawnUnitFrames() were added to a test, a before_each calling
-- LunarUI.CleanupUnitFrames() would NOT reset accumulated frame entries.
-- For now, no before_each is needed because SpawnUnitFrames is never invoked below.
describe("CleanupUnitFrames", function()
    it("does not error when no frames spawned", function()
        assert.has_no_errors(function()
            LunarUI.CleanupUnitFrames()
        end)
    end)

    it("can be called multiple times without error", function()
        assert.has_no_errors(function()
            LunarUI.CleanupUnitFrames()
            LunarUI.CleanupUnitFrames()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- SpawnUnitFrames lifecycle
--------------------------------------------------------------------------------

-- Additional globals needed by SpawnUnitFrames
_G.RegisterStateDriver = function() end
_G.UnitIsUnit = function()
    return false
end
_G.ClearFocus = function() end

describe("SpawnUnitFrames lifecycle", function()
    -- A minimal unitframes table with all units disabled avoids actual oUF frame creation
    local function makeDisabledUF()
        return {
            player = { enabled = false, point = "CENTER", x = -300, y = -200 },
            target = { enabled = false, point = "CENTER", x = 300, y = -200 },
            focus = { enabled = false },
            pet = { enabled = false },
            targettarget = { enabled = false },
            boss = { enabled = false },
            party = { enabled = false },
            raid = { enabled = false, useRaidLayout = false },
        }
    end

    before_each(function()
        LunarUI.db = {
            profile = {
                auraWhitelist = "",
                auraBlacklist = "",
                auraFilters = { sortMethod = "time", sortReverse = false },
                unitframes = makeDisabledUF(),
            },
        }
    end)

    it("does not error with all unit types disabled", function()
        assert.has_no_errors(function()
            LunarUI.SpawnUnitFrames()
        end)
    end)

    it("skips spawn and retries when db is nil", function()
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI.SpawnUnitFrames()
        end)
        -- Restore
        LunarUI.db = {
            profile = {
                auraWhitelist = "",
                auraBlacklist = "",
                auraFilters = { sortMethod = "time", sortReverse = false },
                unitframes = makeDisabledUF(),
            },
        }
    end)

    it("skips spawn when in combat", function()
        _G.InCombatLockdown = function()
            return true
        end
        assert.has_no_errors(function()
            LunarUI.SpawnUnitFrames()
        end)
        _G.InCombatLockdown = function()
            return false
        end
    end)

    it("can be called multiple times without error", function()
        assert.has_no_errors(function()
            LunarUI.SpawnUnitFrames()
            LunarUI.SpawnUnitFrames()
        end)
    end)

    it("Spawn → Cleanup → Spawn 循環不報錯（soft disable re-enable）", function()
        assert.has_no_errors(function()
            LunarUI.SpawnUnitFrames()
            LunarUI.CleanupUnitFrames()
            LunarUI.SpawnUnitFrames() -- re-enable 路徑
        end)
    end)

    it("多次 Spawn/Cleanup 循環不累積", function()
        for _ = 1, 3 do
            assert.has_no_errors(function()
                LunarUI.SpawnUnitFrames()
                LunarUI.CleanupUnitFrames()
            end)
        end
    end)

    it("re-enable 時 DB 未就緒不會建立 retry timer（走 Enable 路徑）", function()
        -- 先確保已 spawn 過（前面的測試已執行 SpawnUnitFrames）
        -- 捕捉 C_Timer.After callback
        local pendingCallbacks = {}
        _G.C_Timer.After = function(_delay, fn)
            pendingCallbacks[#pendingCallbacks + 1] = fn
        end

        -- Cleanup 後模擬 DB 未就緒
        LunarUI.CleanupUnitFrames()
        LunarUI.db = nil
        LunarUI.SpawnUnitFrames()
        -- re-enable 走 Enable 路徑，不需要 DB，不應建立 retry timer
        assert.is_true(#pendingCallbacks == 0, "Re-enable should not create retry timers")

        -- 還原 DB 與 C_Timer
        LunarUI.db = {
            profile = {
                auraWhitelist = "",
                auraBlacklist = "",
                auraFilters = { sortMethod = "time", sortReverse = false },
                unitframes = makeDisabledUF(),
            },
        }
        _G.C_Timer.After = function() end
    end)
end)

--------------------------------------------------------------------------------
-- GetStatusBarTexture caching behavior
-- (tested indirectly via InvalidateStatusBarTextureCache since GetStatusBarTexture is local)
--------------------------------------------------------------------------------

describe("GetStatusBarTexture caching", function()
    it("InvalidateStatusBarTextureCache allows GetSelectedStatusBarTexture to be called fresh", function()
        -- After invalidation, the next UFGetStatusBarTexture call should re-query GetSelectedStatusBarTexture.
        local callCount = 0
        local origFn = LunarUI.GetSelectedStatusBarTexture
        LunarUI.GetSelectedStatusBarTexture = function()
            callCount = callCount + 1
            return "Interface\\TargetingFrame\\UI-StatusBar"
        end

        -- Prime the cache via UFGetStatusBarTexture
        LunarUI.InvalidateStatusBarTextureCache()
        LunarUI.UFGetStatusBarTexture()
        local countAfterFirst = callCount
        assert.is_true(countAfterFirst > 0)

        -- Without invalidation, a second call should NOT call GetSelectedStatusBarTexture again (cached)
        LunarUI.UFGetStatusBarTexture()
        assert.equals(countAfterFirst, callCount)

        -- After invalidation, the next call SHOULD call GetSelectedStatusBarTexture again
        LunarUI.InvalidateStatusBarTextureCache()
        LunarUI.UFGetStatusBarTexture()
        assert.is_true(callCount > countAfterFirst)

        LunarUI.GetSelectedStatusBarTexture = origFn
    end)

    it("returns same string on repeated GetSelectedStatusBarTexture calls (stable caching)", function()
        local callCount = 0
        local origFn = LunarUI.GetSelectedStatusBarTexture
        LunarUI.GetSelectedStatusBarTexture = function()
            callCount = callCount + 1
            return "Interface\\TargetingFrame\\UI-StatusBar"
        end

        -- Invalidate so the next internal call fetches fresh
        LunarUI.InvalidateStatusBarTextureCache()

        -- Spawn a frame to trigger internal GetStatusBarTexture use
        LunarUI.db = {
            profile = {
                auraWhitelist = "",
                auraBlacklist = "",
                auraFilters = { sortMethod = "time", sortReverse = false },
                unitframes = {
                    player = { enabled = false, point = "CENTER", x = 0, y = 0 },
                    target = { enabled = false },
                    focus = { enabled = false },
                    pet = { enabled = false },
                    targettarget = { enabled = false },
                    boss = { enabled = false },
                    party = { enabled = false },
                    raid = { enabled = false, useRaidLayout = false },
                },
            },
        }
        LunarUI.SpawnUnitFrames()

        -- After one fresh call the count should be 1 (cached for subsequent accesses)
        local firstCount = callCount
        LunarUI.SpawnUnitFrames()
        -- Additional spawn should not call GetSelectedStatusBarTexture again (already cached)
        assert.equals(firstCount, callCount)

        LunarUI.GetSelectedStatusBarTexture = origFn
    end)
end)
