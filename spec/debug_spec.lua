---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Core/Debug.lua
    Tests debug output, warn/error, and debug overlay
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.GetFramerate = function()
    return 60
end
_G.InCombatLockdown = function()
    return false
end

-- Mock CreateFrame with visibility tracking for debug overlay tests
local mock_frame = require("spec.mock_frame")
local DebugMock = setmetatable({}, { __index = mock_frame.MockFrame })
DebugMock.__index = DebugMock
function DebugMock:Hide()
    self._shown = false
end
function DebugMock:Show()
    self._shown = true
end
function DebugMock:IsShown()
    return self._shown or false
end
_G.CreateFrame = function()
    return setmetatable({}, { __index = DebugMock })
end
_G.UIParent = setmetatable({}, { __index = DebugMock })

-- Track print output
local printLog = {}

local LunarUI = {
    db = {
        profile = {
            debug = false,
        },
    },
    Print = function(_self, msg)
        printLog[#printLog + 1] = msg
    end,
    RegisterModule = function() end,
}

loader.loadAddonFile("LunarUI/Core/Debug.lua", LunarUI)

--------------------------------------------------------------------------------
-- Debug output
--------------------------------------------------------------------------------

describe("Debug output", function()
    before_each(function()
        wipe(printLog)
    end)

    it("does not print when debug is off", function()
        LunarUI.db.profile.debug = false
        LunarUI:Debug("test message")
        assert.equals(0, #printLog)
    end)

    it("prints when debug is on", function()
        LunarUI.db.profile.debug = true
        LunarUI:Debug("test message")
        assert.equals(1, #printLog)
        assert.truthy(printLog[1]:find("test message"))
    end)

    it("includes debug prefix", function()
        LunarUI.db.profile.debug = true
        LunarUI:Debug("hello")
        assert.truthy(printLog[1]:find("除錯"))
    end)

    it("handles non-string input via tostring", function()
        LunarUI.db.profile.debug = true
        LunarUI:Debug(42)
        assert.truthy(printLog[1]:find("42"))
    end)
end)

--------------------------------------------------------------------------------
-- IsDebugMode
--------------------------------------------------------------------------------

describe("IsDebugMode", function()
    it("returns false when debug is off", function()
        LunarUI.db.profile.debug = false
        assert.is_falsy(LunarUI:IsDebugMode())
    end)

    it("returns true when debug is on", function()
        LunarUI.db.profile.debug = true
        assert.is_truthy(LunarUI:IsDebugMode())
    end)
end)

--------------------------------------------------------------------------------
-- Warn / Error
--------------------------------------------------------------------------------

describe("Warn output", function()
    before_each(function()
        wipe(printLog)
    end)

    it("always prints regardless of debug flag", function()
        LunarUI.db.profile.debug = false
        LunarUI:Warn("warning msg")
        assert.equals(1, #printLog)
    end)

    it("includes warning prefix", function()
        LunarUI:Warn("test")
        assert.truthy(printLog[1]:find("警告"))
    end)
end)

describe("Error output", function()
    before_each(function()
        wipe(printLog)
    end)

    it("always prints regardless of debug flag", function()
        LunarUI.db.profile.debug = false
        LunarUI:Error("error msg")
        assert.equals(1, #printLog)
    end)

    it("includes error prefix", function()
        LunarUI:Error("test")
        assert.truthy(printLog[1]:find("錯誤"))
    end)
end)

--------------------------------------------------------------------------------
-- Debug Overlay
--------------------------------------------------------------------------------

describe("Debug overlay", function()
    -- NOTE: CreateDebugFrame 使用 module-local upvalue 快取，無法從外部重置。
    -- 測試依序執行：先建立、再顯示/隱藏。

    it("UpdateDebugOverlay creates and shows frame when debug on", function()
        LunarUI.db.profile.debug = true
        LunarUI.UpdateDebugOverlay()
        assert.truthy(LunarUI.DebugFrame)
        assert.is_true(LunarUI.DebugFrame:IsShown())
    end)

    it("UpdateDebugOverlay hides frame when debug off", function()
        LunarUI.db.profile.debug = false
        LunarUI.UpdateDebugOverlay()
        assert.truthy(LunarUI.DebugFrame)
        assert.is_false(LunarUI.DebugFrame:IsShown())
    end)

    it("ShowDebugOverlay shows frame", function()
        LunarUI.ShowDebugOverlay()
        assert.truthy(LunarUI.DebugFrame)
        assert.is_true(LunarUI.DebugFrame:IsShown())
    end)

    it("HideDebugOverlay hides frame", function()
        LunarUI.HideDebugOverlay()
        assert.truthy(LunarUI.DebugFrame)
        assert.is_false(LunarUI.DebugFrame:IsShown())
    end)

    it("exports all overlay functions", function()
        assert.is_function(LunarUI.UpdateDebugOverlay)
        assert.is_function(LunarUI.ShowDebugOverlay)
        assert.is_function(LunarUI.HideDebugOverlay)
    end)
end)
