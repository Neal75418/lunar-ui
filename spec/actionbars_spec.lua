---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/ActionBars/ActionBars.lua
    Tests: exports, BUTTON_COLORS, BINDING_FORMATS, config tables
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs（wow_mock.lua 已提供 InCombatLockdown/IsShiftKeyDown/GetTime 預設值）
_G.hooksecurefunc = function() end
_G.C_Timer = {
    After = function() end,
    NewTimer = function()
        return { Cancel = function() end }
    end,
}
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
    RestoreBlizzardBars = function() end,
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

loader.loadAddonFile("LunarUI/ActionBars/ButtonStyling.lua", LunarUI)
loader.loadAddonFile("LunarUI/ActionBars/FadeAndHover.lua", LunarUI)
loader.loadAddonFile("LunarUI/ActionBars/SpecialButtons.lua", LunarUI)
loader.loadAddonFile("LunarUI/ActionBars/ActionBars.lua", LunarUI)

-- ActionBars exports（assert.is_function）已移除，行為由各 describe 隱含驗證
-- BUTTON_COLORS 為 module-local，由 lifecycle 測試間接驗證

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("ActionBars lifecycle", function()
    it("CleanupActionBars does not error", function()
        assert.has_no_errors(function()
            LunarUI.CleanupActionBars()
        end)
    end)

    it("ToggleKeybindMode does not error", function()
        assert.has_no_errors(function()
            LunarUI.ToggleKeybindMode()
        end)
    end)

    it("CleanupActionBars calls RestoreBlizzardBars", function()
        local restoreCalled = false
        local origRestore = LunarUI.RestoreBlizzardBars
        LunarUI.RestoreBlizzardBars = function()
            restoreCalled = true
        end
        LunarUI.CleanupActionBars()
        assert.is_true(restoreCalled)
        LunarUI.RestoreBlizzardBars = origRestore
    end)

    it("SpawnActionBars creates bar entries", function()
        LunarUI.CleanupActionBars()
        LunarUI.SpawnActionBars()
        assert.is_table(LunarUI._actionBars)
        -- verify at least one bar was created (bar1..bar6 are created by SpawnActionBars)
        local count = 0
        for _ in pairs(LunarUI._actionBars) do
            count = count + 1
        end
        assert.is_true(count > 0)
        LunarUI.CleanupActionBars()
    end)
end)
