--[[
    Unit tests for LunarUI/Core/Commands.lua
    Tests slash command dispatch, toggle logic, and help output
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.GetTime = function()
    return 1000
end
_G.InCombatLockdown = function()
    return false
end
_G.C_AddOns = { LoadAddOn = function() end }

-- Track print output
local printLog = {}

local LunarUI = {
    version = "1.0.0",
    db = {
        profile = {
            enabled = true,
            debug = false,
        },
        global = {},
        defaults = {
            profile = {
                unitframes = {
                    player = { x = 0, y = 0, point = "CENTER" },
                },
            },
        },
    },
    Print = function(_self, msg)
        printLog[#printLog + 1] = msg
    end,
    RegisterChatCommand = function() end,
    RegisterModule = function() end,
    UpdateDebugOverlay = function() end,
    ResetAllPositions = function() end,
}

-- Provide a LibStub mock that returns nil
_G.LibStub = function()
    return nil
end

-- Provide Settings mock
_G.Settings = nil

loader.loadAddonFile("LunarUI/Core/Commands.lua", LunarUI)

--------------------------------------------------------------------------------
-- RegisterCommands
--------------------------------------------------------------------------------

describe("RegisterCommands", function()
    it("registers /lunar and /lui commands", function()
        local registered = {}
        LunarUI.RegisterChatCommand = function(_self, cmd, handler)
            registered[cmd] = handler
        end
        LunarUI:RegisterCommands()
        assert.truthy(registered["lunar"])
        assert.truthy(registered["lui"])
    end)
end)

--------------------------------------------------------------------------------
-- SlashCommand dispatch
--------------------------------------------------------------------------------

describe("SlashCommand dispatch", function()
    before_each(function()
        wipe(printLog)
        LunarUI.db.profile.enabled = true
        LunarUI.db.profile.debug = false
    end)

    it("shows help for empty input", function()
        LunarUI:SlashCommand("")
        assert.truthy(#printLog > 0)
        -- Should contain command list
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("/lunar") then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)

    it("shows help for 'help' command", function()
        LunarUI:SlashCommand("help")
        assert.truthy(#printLog > 0)
    end)

    it("handles unknown command", function()
        LunarUI:SlashCommand("unknowncommand123")
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("unknown") or msg:find("Unknown") then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)
end)

--------------------------------------------------------------------------------
-- ToggleAddon
--------------------------------------------------------------------------------

describe("ToggleAddon", function()
    before_each(function()
        LunarUI.db.profile.enabled = true
        wipe(printLog)
    end)

    it("toggles addon off", function()
        LunarUI:ToggleAddon("off")
        assert.is_false(LunarUI.db.profile.enabled)
    end)

    it("toggles addon on", function()
        LunarUI.db.profile.enabled = false
        LunarUI:ToggleAddon("on")
        assert.is_true(LunarUI.db.profile.enabled)
    end)

    it("toggles addon state", function()
        LunarUI.db.profile.enabled = true
        LunarUI:ToggleAddon("toggle")
        assert.is_false(LunarUI.db.profile.enabled)
    end)

    it("toggle again restores state", function()
        LunarUI.db.profile.enabled = false
        LunarUI:ToggleAddon("toggle")
        assert.is_true(LunarUI.db.profile.enabled)
    end)
end)

--------------------------------------------------------------------------------
-- ToggleDebug
--------------------------------------------------------------------------------

describe("ToggleDebug", function()
    before_each(function()
        LunarUI.db.profile.debug = false
        wipe(printLog)
    end)

    it("enables debug mode", function()
        LunarUI:ToggleDebug()
        assert.is_true(LunarUI.db.profile.debug)
    end)

    it("disables debug mode", function()
        LunarUI.db.profile.debug = true
        LunarUI:ToggleDebug()
        assert.is_false(LunarUI.db.profile.debug)
    end)

    it("calls UpdateDebugOverlay", function()
        local called = false
        LunarUI.UpdateDebugOverlay = function()
            called = true
        end
        LunarUI:ToggleDebug()
        assert.is_true(called)
    end)
end)

--------------------------------------------------------------------------------
-- PrintStatus
--------------------------------------------------------------------------------

describe("PrintStatus", function()
    before_each(function()
        wipe(printLog)
    end)

    it("outputs version info", function()
        LunarUI:PrintStatus()
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("1.0.0") then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)

    it("outputs enabled status", function()
        LunarUI.db.profile.enabled = true
        LunarUI:PrintStatus()
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("Yes") or msg:find("00ff00") then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)
end)

--------------------------------------------------------------------------------
-- ResetPosition
--------------------------------------------------------------------------------

describe("ResetPosition", function()
    before_each(function()
        wipe(printLog)
        LunarUI.db.profile.unitframes = {
            player = { x = 100, y = 200, point = "TOPLEFT" },
        }
    end)

    it("resets positions to defaults", function()
        LunarUI:ResetPosition()
        assert.equals(0, LunarUI.db.profile.unitframes.player.x)
        assert.equals(0, LunarUI.db.profile.unitframes.player.y)
        assert.equals("CENTER", LunarUI.db.profile.unitframes.player.point)
    end)

    it("does nothing when defaults missing", function()
        local saved = LunarUI.db.defaults
        LunarUI.db.defaults = nil
        assert.has_no_errors(function()
            LunarUI:ResetPosition()
        end)
        LunarUI.db.defaults = saved
    end)
end)

--------------------------------------------------------------------------------
-- SlashCommand integration
--------------------------------------------------------------------------------

describe("SlashCommand integration", function()
    before_each(function()
        wipe(printLog)
        LunarUI.db.profile.enabled = true
        LunarUI.db.profile.debug = false
    end)

    it("dispatches 'toggle' command", function()
        LunarUI:SlashCommand("toggle")
        assert.is_false(LunarUI.db.profile.enabled)
    end)

    it("dispatches 'on' command", function()
        LunarUI.db.profile.enabled = false
        LunarUI:SlashCommand("on")
        assert.is_true(LunarUI.db.profile.enabled)
    end)

    it("dispatches 'off' command", function()
        LunarUI:SlashCommand("off")
        assert.is_false(LunarUI.db.profile.enabled)
    end)

    it("dispatches 'debug' command", function()
        LunarUI:SlashCommand("debug")
        assert.is_true(LunarUI.db.profile.debug)
    end)

    it("dispatches 'status' command", function()
        LunarUI:SlashCommand("status")
        assert.truthy(#printLog > 0)
    end)

    it("dispatches 'test' without args", function()
        LunarUI:SlashCommand("test")
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("test") or msg:find("Test") then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)

    it("dispatches 'test' with scenario arg", function()
        LunarUI:SlashCommand("test mytest")
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("mytest") then
                found = true
                break
            end
        end
        assert.is_true(found)
    end)

    it("dispatches 'config' command without error", function()
        assert.has_no_errors(function()
            LunarUI:SlashCommand("config")
        end)
    end)

    it("case insensitive command matching", function()
        LunarUI:SlashCommand("TOGGLE")
        assert.is_false(LunarUI.db.profile.enabled)
    end)
end)
