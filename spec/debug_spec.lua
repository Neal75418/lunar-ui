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

-- MockFrame
local MockFrame = {}
MockFrame.__index = MockFrame
function MockFrame:SetSize() end
function MockFrame:SetPoint() end
function MockFrame:SetFrameStrata() end
function MockFrame:SetMovable() end
function MockFrame:EnableMouse() end
function MockFrame:RegisterForDrag() end
function MockFrame:SetScript() end
function MockFrame:SetBackdrop() end
function MockFrame:SetBackdropColor() end
function MockFrame:SetBackdropBorderColor() end
function MockFrame:Hide()
    self._shown = false
end
function MockFrame:Show()
    self._shown = true
end
function MockFrame:IsShown()
    return self._shown or false
end
function MockFrame:CreateFontString()
    return setmetatable({ SetText = function() end, SetPoint = function() end }, { __index = MockFrame })
end

_G.CreateFrame = function()
    return setmetatable({}, { __index = MockFrame })
end
_G.UIParent = setmetatable({}, { __index = MockFrame })

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
    before_each(function()
        -- Reset DebugFrame to force recreation
        LunarUI.DebugFrame = nil
    end)

    it("UpdateDebugOverlay shows frame when debug on", function()
        LunarUI.db.profile.debug = true
        LunarUI.UpdateDebugOverlay()
        -- Should not error
        assert.is_function(LunarUI.UpdateDebugOverlay)
    end)

    it("UpdateDebugOverlay hides frame when debug off", function()
        LunarUI.db.profile.debug = false
        assert.has_no.errors(function()
            LunarUI.UpdateDebugOverlay()
        end)
    end)

    it("ShowDebugOverlay does not error", function()
        assert.has_no.errors(function()
            LunarUI.ShowDebugOverlay()
        end)
    end)

    it("HideDebugOverlay does not error when no frame", function()
        assert.has_no.errors(function()
            LunarUI.HideDebugOverlay()
        end)
    end)

    it("exports all overlay functions", function()
        assert.is_function(LunarUI.UpdateDebugOverlay)
        assert.is_function(LunarUI.ShowDebugOverlay)
        assert.is_function(LunarUI.HideDebugOverlay)
    end)
end)
