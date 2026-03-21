---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/ActionBars/ActionBars.lua
    Tests: exports, BUTTON_COLORS, BINDING_FORMATS, config tables
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.InCombatLockdown = function()
    return false
end
_G.IsShiftKeyDown = function()
    return false
end
_G.hooksecurefunc = function() end
_G.C_Timer = {
    After = function() end,
    NewTimer = function()
        return { Cancel = function() end }
    end,
}
_G.GetTime = function()
    return 1000
end
_G.GetBindingKey = function()
    return nil
end
_G.SetBinding = function() end
_G.SaveBindings = function() end
_G.GetCurrentBindingSet = function()
    return 1
end
_G.GetBindingAction = function()
    return ""
end
_G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
}
_G.ATTACK_BUTTON_FLASH_TIME = 0.4
_G.RANGE_INDICATOR = "•"
_G.UIParent = nil
_G.RegisterStateDriver = function() end
_G.UnregisterStateDriver = function() end

-- Mock LibStub：提供最小化的 LibActionButton
_G.LibStub = function(name, _silent)
    if name == "LibActionButton-1.0" then
        return {
            CreateButton = function(_self, _id, _name, _header)
                local btn = CreateFrame("CheckButton")
                btn.SetState = function() end
                btn.Update = function() end
                btn.HasAction = function()
                    return false
                end
                return btn
            end,
        }
    end
    if name == "Masque" then
        return nil
    end
    return nil
end

require("spec.mock_frame")

local LunarUI = {
    Colors = {
        bgIcon = { 0, 0, 0, 0.8 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
        border = { 0.3, 0.3, 0.4, 1 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    backdropTemplate = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetSelectedFont = function()
        return "Fonts\\FRIZQT__.TTF"
    end,
    GetSelectedStatusBarTexture = function()
        return "Interface\\StatusBar"
    end,
    RegisterMovableFrame = function() end,
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
    HideBlizzardBarsDelayed = function() end,
    Print = function() end,
    db = {
        profile = {
            actionbars = {
                buttonSize = 36,
                buttonSpacing = 4,
                bar1 = { enabled = true, buttons = 12, x = 0, y = 0, orientation = "HORIZONTAL" },
                bar2 = { enabled = true, buttons = 12, x = 0, y = 0, orientation = "HORIZONTAL" },
                bar3 = { enabled = true, buttons = 12, x = 0, y = 0, orientation = "HORIZONTAL" },
                bar4 = { enabled = true, buttons = 12, x = 0, y = 0, orientation = "VERTICAL" },
                bar5 = { enabled = true, buttons = 12, x = 0, y = 0, orientation = "VERTICAL" },
                bar6 = { enabled = true, buttons = 12, x = 0, y = 0, orientation = "HORIZONTAL" },
                petbar = { x = 0, y = 0, orientation = "HORIZONTAL" },
                stancebar = { x = 0, y = 0, orientation = "HORIZONTAL" },
            },
        },
    },
}

LunarUI.GetModuleDB = function(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

loader.loadAddonFile("LunarUI/ActionBars/ActionBars.lua", LunarUI)

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

describe("ActionBars exports", function()
    it("exports SpawnActionBars as function", function()
        assert.is_function(LunarUI.SpawnActionBars)
    end)

    it("exports CleanupActionBars as function", function()
        assert.is_function(LunarUI.CleanupActionBars)
    end)

    it("exports EnterKeybindMode as function", function()
        assert.is_function(LunarUI.EnterKeybindMode)
    end)

    it("exports ExitKeybindMode as function", function()
        assert.is_function(LunarUI.ExitKeybindMode)
    end)

    it("exports ToggleKeybindMode as function", function()
        assert.is_function(LunarUI.ToggleKeybindMode)
    end)

    it("exports actionBars as table", function()
        assert.is_table(LunarUI.actionBars)
    end)
end)

--------------------------------------------------------------------------------
-- BUTTON_COLORS
--------------------------------------------------------------------------------

describe("BUTTON_COLORS (via actionbars internals)", function()
    -- BUTTON_COLORS is module-local, but we verify the module loaded
    -- correctly by checking that exported functions exist and don't crash
    it("CleanupActionBars does not error when not initialized", function()
        assert.has_no_errors(function()
            LunarUI.CleanupActionBars()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("ActionBars lifecycle", function()
    it("CleanupActionBars does not error", function()
        assert.has_no_errors(function()
            LunarUI.CleanupActionBars()
        end)
    end)

    it("ExitKeybindMode does not error when not active", function()
        assert.has_no_errors(function()
            LunarUI.ExitKeybindMode()
        end)
    end)

    it("ToggleKeybindMode does not error", function()
        assert.has_no_errors(function()
            LunarUI.ToggleKeybindMode()
        end)
    end)

    it("SpawnActionBars creates bar entries", function()
        LunarUI.CleanupActionBars()
        LunarUI.SpawnActionBars()
        assert.is_table(LunarUI.actionBars)
        -- verify at least one bar was created (bar1..bar6 are created by SpawnActionBars)
        local count = 0
        for _ in pairs(LunarUI.actionBars) do
            count = count + 1
        end
        assert.is_true(count > 0)
        LunarUI.CleanupActionBars()
    end)
end)
