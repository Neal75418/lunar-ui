---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Modules/FrameMover.lua
    Tests frame registration, move mode, position save/load, and reset
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.InCombatLockdown = function()
    return false
end
_G.IsControlKeyDown = function()
    return false
end
_G.GetScreenWidth = function()
    return 1920
end
_G.GetScreenHeight = function()
    return 1080
end
_G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
}

-- Mock CreateFrame with point tracking for frame mover tests
local mock_frame = require("spec.mock_frame")
local MoverMock = setmetatable({}, { __index = mock_frame.MockFrame })
MoverMock.__index = MoverMock
function MoverMock:SetPoint(...)
    self._points = self._points or {}
    self._points[#self._points + 1] = { ... }
end
function MoverMock:GetPoint(i)
    if self._points and self._points[i] then
        return unpack(self._points[i])
    end
    return "CENTER", nil, "CENTER", 0, 0
end
function MoverMock:GetNumPoints()
    return self._points and #self._points or 1
end
function MoverMock:ClearAllPoints()
    self._points = {}
end
_G.CreateFrame = function()
    return setmetatable({}, { __index = MoverMock })
end
_G.UIParent = setmetatable({}, { __index = MoverMock })

-- Track prints
local printLog = {}

-- Track module registration
local registeredModules = {}

local LunarUI = {
    Colors = {
        bg = { 0.05, 0.05, 0.05, 0.8 },
        border = { 0.3, 0.3, 0.4, 1 },
    },
    backdropTemplate = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    },
    SetFont = function() end,
    Print = function(_self, msg)
        printLog[#printLog + 1] = msg
    end,
    db = {
        profile = {
            framePositions = {},
            frameMover = { gridSize = 10, moverAlpha = 0.6 },
        },
    },
    RegisterModule = function(_self, name, config)
        registeredModules[name] = config
    end,
}
LunarUI.GetModuleDB = function(key)
    if not LunarUI.db or not LunarUI.db.profile then return nil end
    return LunarUI.db.profile[key]
end

loader.loadAddonFile("LunarUI/Modules/FrameMover.lua", LunarUI)

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

describe("FrameMover exports", function()
    it("exports ToggleMoveMode", function()
        assert.is_function(LunarUI.ToggleMoveMode)
    end)

    it("exports EnterMoveMode", function()
        assert.is_function(LunarUI.EnterMoveMode)
    end)

    it("exports ExitMoveMode", function()
        assert.is_function(LunarUI.ExitMoveMode)
    end)

    it("exports RegisterMovableFrame", function()
        assert.is_function(LunarUI.RegisterMovableFrame)
    end)

    it("exports UnregisterMovableFrame", function()
        assert.is_function(LunarUI.UnregisterMovableFrame)
    end)

    it("exports ResetAllPositions", function()
        assert.is_function(LunarUI.ResetAllPositions)
    end)

    it("exports CleanupFrameMover", function()
        assert.is_function(LunarUI.CleanupFrameMover)
    end)

    it("registers FrameMover module", function()
        assert.truthy(registeredModules["FrameMover"])
        assert.equals(2.0, registeredModules["FrameMover"].delay)
    end)
end)

--------------------------------------------------------------------------------
-- Frame Registration
--------------------------------------------------------------------------------

describe("Frame registration", function()
    before_each(function()
        LunarUI.CleanupFrameMover()
        LunarUI.db.profile.framePositions = {}
        wipe(printLog)
    end)

    it("registers a movable frame without error", function()
        local frame = setmetatable({}, { __index = MoverMock })
        assert.has_no.errors(function()
            LunarUI.RegisterMovableFrame("test", frame, "Test Frame")
        end)
    end)

    it("ignores nil name", function()
        local frame = setmetatable({}, { __index = MoverMock })
        assert.has_no.errors(function()
            LunarUI.RegisterMovableFrame(nil, frame, "Test")
        end)
    end)

    it("ignores nil frame", function()
        assert.has_no.errors(function()
            LunarUI.RegisterMovableFrame("test", nil, "Test")
        end)
    end)

    it("unregisters a movable frame", function()
        local frame = setmetatable({}, { __index = MoverMock })
        LunarUI.RegisterMovableFrame("test", frame, "Test")
        assert.has_no.errors(function()
            LunarUI.UnregisterMovableFrame("test")
        end)
    end)

    it("unregister is safe for non-existing name", function()
        assert.has_no.errors(function()
            LunarUI.UnregisterMovableFrame("nonexistent")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Move Mode
--------------------------------------------------------------------------------

describe("Move mode", function()
    before_each(function()
        LunarUI.CleanupFrameMover()
        LunarUI.db.profile.framePositions = {}
        wipe(printLog)
    end)

    it("enters move mode", function()
        LunarUI.EnterMoveMode()
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("Move mode") or msg:find("drag") then
                found = true
            end
        end
        assert.is_true(found)
        LunarUI.ExitMoveMode()
    end)

    it("exits move mode", function()
        LunarUI.EnterMoveMode()
        wipe(printLog)
        LunarUI.ExitMoveMode()
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("Exited") or msg:find("exit") then
                found = true
            end
        end
        assert.is_true(found)
    end)

    it("toggles between enter and exit", function()
        wipe(printLog)
        LunarUI.ToggleMoveMode() -- enter
        local enterMsg = printLog[#printLog]
        assert.truthy(enterMsg)

        wipe(printLog)
        LunarUI.ToggleMoveMode() -- exit
        local exitMsg = printLog[#printLog]
        assert.truthy(exitMsg)
        assert.are_not.equal(enterMsg, exitMsg)
    end)

    it("blocks move mode during combat", function()
        _G.InCombatLockdown = function()
            return true
        end
        LunarUI.EnterMoveMode()
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("combat") or msg:find("Cannot") then
                found = true
            end
        end
        assert.is_true(found)
        _G.InCombatLockdown = function()
            return false
        end
    end)
end)

--------------------------------------------------------------------------------
-- ResetAllPositions
--------------------------------------------------------------------------------

describe("ResetAllPositions", function()
    before_each(function()
        LunarUI.CleanupFrameMover()
        LunarUI.db.profile.framePositions = {}
        wipe(printLog)
    end)

    it("clears framePositions", function()
        LunarUI.db.profile.framePositions = { test = { point = "CENTER", x = 100, y = 200 } }
        LunarUI.ResetAllPositions()
        assert.same({}, LunarUI.db.profile.framePositions)
    end)

    it("prints reset message", function()
        LunarUI.ResetAllPositions()
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("reset") then
                found = true
            end
        end
        assert.is_true(found)
    end)
end)
