---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
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
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

loader.loadAddonFile("LunarUI/Modules/FrameMover.lua", LunarUI)

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

-- FrameMover exports（assert.is_function）已移除，行為由各 describe 隱含驗證

describe("FrameMover module registration", function()
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
        assert.has_no_errors(function()
            LunarUI.RegisterMovableFrame("test", frame, "Test Frame")
        end)
    end)

    it("ignores nil name", function()
        local frame = setmetatable({}, { __index = MoverMock })
        assert.has_no_errors(function()
            LunarUI.RegisterMovableFrame(nil, frame, "Test")
        end)
    end)

    it("ignores nil frame", function()
        assert.has_no_errors(function()
            LunarUI.RegisterMovableFrame("test", nil, "Test")
        end)
    end)

    it("unregisters a movable frame", function()
        local frame = setmetatable({}, { __index = MoverMock })
        LunarUI.RegisterMovableFrame("test", frame, "Test")
        assert.has_no_errors(function()
            LunarUI.UnregisterMovableFrame("test")
        end)
    end)

    it("unregister is safe for non-existing name", function()
        assert.has_no_errors(function()
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
        assert.is_true(#printLog > 0)
        LunarUI.ExitMoveMode()
    end)

    it("exits move mode", function()
        LunarUI.EnterMoveMode()
        wipe(printLog)
        LunarUI.ExitMoveMode()
        assert.is_true(#printLog > 0)
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
        assert.is_not.equal(enterMsg, exitMsg)
    end)

    it("blocks move mode during combat", function()
        _G.InCombatLockdown = function()
            return true
        end
        -- 使用 pcall 確保即使 assert 失敗，cleanup 仍會還原 InCombatLockdown，
        -- 避免污染後續測試。
        local ok, err = pcall(function()
            LunarUI.EnterMoveMode()
            local found = false
            for _, msg in ipairs(printLog) do
                -- 比對繁中 fallback 字串（CombatLockdown 類訊息）
                if msg:find("戰鬥中", 1, true) then
                    found = true
                end
            end
            assert.is_true(found)
        end)
        _G.InCombatLockdown = function()
            return false
        end
        if not ok then
            error(err)
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
        assert.is_true(#printLog > 0)
    end)
end)

--------------------------------------------------------------------------------
-- Position Save/Load Roundtrip
--------------------------------------------------------------------------------

describe("Position save/load roundtrip", function()
    before_each(function()
        LunarUI.CleanupFrameMover()
        LunarUI.db.profile.framePositions = {}
        wipe(printLog)
    end)

    it("ApplyAllSavedPositions applies saved position to registered frame", function()
        local frame = setmetatable({}, { __index = MoverMock })
        LunarUI.RegisterMovableFrame("roundtrip_test", frame, "Test")

        -- 模擬拖曳結束後儲存的位置資料
        LunarUI.db.profile.framePositions["roundtrip_test"] = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        }

        -- 套用儲存的位置（重現登入後 ApplyAllSavedPositions 的行為）
        LunarUI.ApplyAllSavedPositions()

        -- 驗證框架的錨點已更新（ApplySavedPosition 呼叫 ClearAllPoints + SetPoint）
        assert.is_not_nil(frame._points)
        assert.equals(1, #frame._points)
        assert.equals("CENTER", frame._points[1][1]) -- point
    end)

    it("ApplyAllSavedPositions ignores unregistered frames", function()
        -- framePositions 有資料但框架未註冊
        LunarUI.db.profile.framePositions["ghost_frame"] = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        }
        assert.has_no_errors(function()
            LunarUI.ApplyAllSavedPositions()
        end)
    end)
end)
