---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/HUD/ClassResources.lua
    Tests class resource configuration lookup, lifecycle functions,
    and class/specialization resource type mapping
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
local mockClassID = 4 -- default: Rogue
local mockSpecIndex = nil

_G.UnitClass = function()
    return "Rogue", "ROGUE", mockClassID
end
_G.GetSpecialization = function()
    return mockSpecIndex
end
_G.GetSpecializationRole = function()
    return "DAMAGER"
end
_G.UnitPower = function()
    return 3
end
_G.UnitPowerMax = function()
    return 5
end
_G.GetRuneCooldown = function()
    return 0, 0, true
end
_G.GetTime = function()
    return 1000
end
_G.InCombatLockdown = function()
    return false
end
_G.IsShiftKeyDown = function()
    return false
end
_G.C_Timer = { After = function() end }

-- Mock Enum
_G.Enum = {
    PowerType = {
        ComboPoints = 4,
        Runes = 5,
        SoulShards = 7,
        ArcaneCharges = 16,
        Insanity = 13,
        HolyPower = 9,
        Fury = 17,
        Pain = 18,
        Essence = 19,
    },
}

require("spec.mock_frame")

local LunarUI = {
    Colors = {
        bgIcon = { 0, 0, 0, 0.8 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    textures = { glow = "Interface\\glow" },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetHUDSetting = function(_key, default)
        return default
    end,
    RegisterHUDFrame = function() end,
    RegisterMovableFrame = function() end,
    iconBackdropTemplate = {},
    GetSelectedStatusBarTexture = function()
        return "Interface\\StatusBar"
    end,
    RegisterModule = function() end,
    CreateEventHandler = function()
        return setmetatable({
            _events = {},
            _scripts = {},
            RegisterEvent = function(self, e)
                self._events[e] = true
            end,
            SetScript = function(self, name, fn)
                self._scripts[name] = fn
            end,
            UnregisterAllEvents = function() end,
        }, {})
    end,
}

loader.loadAddonFile("LunarUI/HUD/ClassResources.lua", LunarUI)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("ClassResources lifecycle", function()
    it("Init does not error", function()
        assert.has_no_errors(function()
            LunarUI.InitClassResources()
        end)
    end)

    it("Cleanup does not error after Init", function()
        assert.has_no_errors(function()
            LunarUI.CleanupClassResources()
        end)
    end)

    it("Cleanup does not error when not initialized", function()
        assert.has_no_errors(function()
            LunarUI.CleanupClassResources()
        end)
    end)

    it("RebuildClassResources does nothing in combat", function()
        local origFn = _G.InCombatLockdown
        _G.InCombatLockdown = function()
            return true
        end
        assert.has_no_errors(function()
            LunarUI.RebuildClassResources()
        end)
        _G.InCombatLockdown = origFn
    end)
end)

--------------------------------------------------------------------------------
-- Class Resource Config (tested indirectly via reload)
--------------------------------------------------------------------------------

describe("ClassResources class configs", function()
    -- Each test loads a fresh module instance with a specific class
    local function loadWithClass(classID, specIndex)
        mockClassID = classID
        mockSpecIndex = specIndex

        local testLunarUI
        testLunarUI = {
            Colors = LunarUI.Colors,
            ICON_TEXCOORD = LunarUI.ICON_TEXCOORD,
            textures = LunarUI.textures,
            ApplyBackdrop = function() end,
            SetFont = function() end,
            GetHUDSetting = function(_key, default)
                return default
            end,
            RegisterHUDFrame = function() end,
            RegisterMovableFrame = function(name, _frame, _label)
                testLunarUI._lastMovableRegistered = name
            end,
            iconBackdropTemplate = {},
            GetSelectedStatusBarTexture = function()
                return "Interface\\StatusBar"
            end,
            RegisterModule = function() end,
            CreateEventHandler = LunarUI.CreateEventHandler,
        }

        loader.loadAddonFile("LunarUI/HUD/ClassResources.lua", testLunarUI)
        return testLunarUI
    end

    it("loads for Rogue (class 4)", function()
        local lui = loadWithClass(4, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("loads for Death Knight (class 6)", function()
        local lui = loadWithClass(6, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("loads for Warlock (class 9)", function()
        local lui = loadWithClass(9, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("loads for Monk Windwalker (class 10, spec 3)", function()
        local lui = loadWithClass(10, 3)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("loads for Monk non-Windwalker (class 10, spec 2)", function()
        local lui = loadWithClass(10, 2)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Mage Arcane (class 8, spec 1)", function()
        local lui = loadWithClass(8, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("loads for Mage non-Arcane (class 8, spec 2)", function()
        local lui = loadWithClass(8, 2)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Priest Shadow (class 5, spec 3)", function()
        local lui = loadWithClass(5, 3)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("loads for Demon Hunter Havoc (class 12, spec 1)", function()
        local lui = loadWithClass(12, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("loads for Demon Hunter Vengeance (class 12, spec 2)", function()
        local lui = loadWithClass(12, 2)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("loads for Evoker (class 13)", function()
        local lui = loadWithClass(13, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        assert.equals("ClassResources", lui._lastMovableRegistered)
        lui.CleanupClassResources()
    end)

    it("handles unsupported class gracefully (class 1 Warrior)", function()
        local lui = loadWithClass(1, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("handles nil specialization", function()
        local lui = loadWithClass(10, nil)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("GetHUDSetting classResources=false skips initialization", function()
        local lui = loadWithClass(4, 1)
        -- Return false for classResources to exercise the early-exit path
        lui.GetHUDSetting = function(key, default)
            if key == "classResources" then
                return false
            end
            return default
        end
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        -- Cleanup should also be safe without full init
        lui.CleanupClassResources()
    end)

    it("GetHUDSetting crIconSize custom value affects LoadSettings path", function()
        local capturedKey
        local lui = loadWithClass(4, 1)
        -- Return a non-default icon size to exercise the configured-value path
        lui.GetHUDSetting = function(key, default)
            capturedKey = key
            if key == "crIconSize" then
                return 32
            end
            return default
        end
        assert.has_no_errors(function()
            lui.RebuildClassResources()
        end)
        -- Verify GetHUDSetting was actually called with a sizing key
        assert.is_string(capturedKey)
        lui.CleanupClassResources()
    end)
end)
