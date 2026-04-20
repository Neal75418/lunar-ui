---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/Modules/Automation.lua
    Tests lifecycle, config guards, and toggle symmetry
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs（wow_mock.lua 已提供 GetTime/InCombatLockdown/UnitIsDeadOrGhost 預設值）
_G.IsInGuild = function()
    return false
end
_G.IsInInstance = function()
    return false, "none"
end
_G.UnitIsFeignDeath = function()
    return false
end
_G.GetRepairAllCost = function()
    return 0, false
end
_G.RepairAllItems = function() end
_G.GetMoney = function()
    return 1000000
end
_G.GetCoinTextureString = function()
    return "1g"
end
_G.AcceptQuest = function() end
_G.CompleteQuest = function() end
_G.IsQuestCompletable = function()
    return false
end
_G.GetNumQuestChoices = function()
    return 0
end
_G.GetQuestReward = function() end
_G.AcceptProposal = function() end
_G.RepopMe = function() end
_G.Screenshot = function() end
-- C_Timer mock：刻意同步執行 callback 並記錄 delay 供斷言使用
-- 同步執行是必要的：automation 測試需要在觸發事件後立即驗證 timer callback 的效果
_G._timerLog = {}
_G.C_Timer = {
    After = function(delay, fn)
        _G._timerLog[#_G._timerLog + 1] = { delay = delay }
        if fn then
            fn()
        end
    end,
}

-- Mock CreateFrame with event tracking
local mock_frame = require("spec.mock_frame")
local AutoMock = setmetatable({}, { __index = mock_frame.MockFrame })
AutoMock.__index = AutoMock
function AutoMock:SetScript(name, fn)
    self["_script_" .. name] = fn
end
function AutoMock:RegisterEvent(event)
    self._events = self._events or {}
    self._events[event] = true
end
function AutoMock:UnregisterAllEvents()
    self._events = {}
end
function AutoMock:GetRegisteredEvents()
    return self._events or {}
end

-- 追蹤所有 CreateFrame 呼叫，以便取得 automationFrame 參照
local createdFrames = {}
_G.CreateFrame = function()
    local frame = setmetatable({ _events = {} }, { __index = AutoMock })
    createdFrames[#createdFrames + 1] = frame
    return frame
end

-- 找到設有 OnEvent handler 的 automation 事件框架（不依賴 createdFrames 順序）
local function findAutomationFrame()
    for _, f in ipairs(createdFrames) do
        if f._script_OnEvent then
            return f
        end
    end
    return createdFrames[1] -- fallback
end
_G.UIParent = setmetatable({}, { __index = AutoMock })

local automationDB = {
    autoRepair = true,
    useGuildRepair = false,
    autoRelease = true,
    autoScreenshot = true,
    autoAcceptQuest = true,
    autoAcceptQueue = true,
}

local LunarUI = {
    db = {
        profile = {
            automation = automationDB,
        },
    },
    Print = function() end,
    RegisterModule = function() end,
}
LunarUI.GetModuleDB = function(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

loader.loadAddonFile("LunarUI/Modules/Automation.lua", LunarUI)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("Automation lifecycle", function()
    it("InitAutomation does not error", function()
        assert.has_no_errors(function()
            LunarUI.InitAutomation()
        end)
    end)

    it("CleanupAutomation does not error after Init", function()
        LunarUI.InitAutomation()
        assert.has_no_errors(function()
            LunarUI.CleanupAutomation()
        end)
    end)

    it("can toggle Init/Cleanup multiple times", function()
        assert.has_no_errors(function()
            LunarUI.InitAutomation()
            LunarUI.CleanupAutomation()
            LunarUI.InitAutomation()
            LunarUI.CleanupAutomation()
            LunarUI.InitAutomation()
            LunarUI.CleanupAutomation()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Config Guard
--------------------------------------------------------------------------------

describe("Automation config guard", function()
    it("InitAutomation does nothing when db is nil", function()
        local saved = LunarUI.db
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI.InitAutomation()
        end)
        LunarUI.db = saved
    end)

    it("InitAutomation does nothing when profile is nil", function()
        local saved = LunarUI.db
        LunarUI.db = {}
        assert.has_no_errors(function()
            LunarUI.InitAutomation()
        end)
        LunarUI.db = saved
    end)

    it("InitAutomation does nothing when automation config is nil", function()
        local saved = LunarUI.db
        LunarUI.db = { profile = {} }
        assert.has_no_errors(function()
            LunarUI.InitAutomation()
        end)
        LunarUI.db = saved
    end)
end)

--------------------------------------------------------------------------------
-- Auto Repair
--------------------------------------------------------------------------------

describe("Automation auto repair", function()
    -- automationFrame 是 loadAddonFile 執行時建立的第一個框架
    local automationFrame

    before_each(function()
        LunarUI.CleanupAutomation()
        automationFrame = findAutomationFrame()
        LunarUI.InitAutomation()
    end)

    after_each(function()
        LunarUI.CleanupAutomation()
        _G.GetRepairAllCost = function()
            return 0, false
        end
        _G.RepairAllItems = function() end
        _G.GetMoney = function()
            return 1000000
        end
    end)

    it("calls RepairAllItems when merchant shows and can repair", function()
        local repaired = false
        _G.GetRepairAllCost = function()
            return 5000, true
        end
        _G.GetMoney = function()
            return 100000
        end
        _G.RepairAllItems = function()
            repaired = true
        end

        automationFrame._script_OnEvent(automationFrame, "MERCHANT_SHOW")
        assert.is_true(repaired)
    end)

    it("does not repair when canRepair is false", function()
        local repaired = false
        _G.GetRepairAllCost = function()
            return 0, false
        end
        _G.RepairAllItems = function()
            repaired = true
        end

        automationFrame._script_OnEvent(automationFrame, "MERCHANT_SHOW")
        assert.is_false(repaired)
    end)

    it("does not repair when not enough gold", function()
        local repaired = false
        _G.GetRepairAllCost = function()
            return 5000, true
        end
        _G.GetMoney = function()
            return 100
        end -- not enough
        _G.RepairAllItems = function()
            repaired = true
        end

        automationFrame._script_OnEvent(automationFrame, "MERCHANT_SHOW")
        assert.is_false(repaired)
    end)
end)

--------------------------------------------------------------------------------
-- Auto Release (BG only)
--------------------------------------------------------------------------------

describe("Automation auto release", function()
    local automationFrame

    before_each(function()
        LunarUI.CleanupAutomation()
        automationFrame = findAutomationFrame()
        LunarUI.InitAutomation()
    end)

    after_each(function()
        LunarUI.CleanupAutomation()
        _G.IsInInstance = function()
            return false, "none"
        end
        _G.UnitIsDeadOrGhost = function()
            return false
        end
        _G.RepopMe = function() end
    end)

    it("calls RepopMe in PvP instance on PLAYER_DEAD", function()
        local released = false
        _G.IsInInstance = function()
            return true, "pvp"
        end
        _G.UnitIsDeadOrGhost = function()
            return true
        end
        _G.UnitIsFeignDeath = function()
            return false
        end
        _G.RepopMe = function()
            released = true
        end

        automationFrame._script_OnEvent(automationFrame, "PLAYER_DEAD")
        -- C_Timer.After 在 mock 中立即執行
        assert.is_true(released)
    end)

    it("does not release outside PvP instance", function()
        local released = false
        _G.IsInInstance = function()
            return false, "none"
        end
        _G.RepopMe = function()
            released = true
        end

        automationFrame._script_OnEvent(automationFrame, "PLAYER_DEAD")
        assert.is_false(released)
    end)
end)

--------------------------------------------------------------------------------
-- DB Toggle: autoRepair = false
--------------------------------------------------------------------------------

describe("Automation autoRepair toggle off", function()
    local automationFrame

    before_each(function()
        LunarUI.CleanupAutomation()
        automationFrame = findAutomationFrame()
        automationDB.autoRepair = false
        LunarUI.InitAutomation()
    end)

    after_each(function()
        LunarUI.CleanupAutomation()
        automationDB.autoRepair = true
        _G.GetRepairAllCost = function()
            return 0, false
        end
        _G.RepairAllItems = function() end
        _G.GetMoney = function()
            return 1000000
        end
    end)

    it("does NOT call RepairAllItems when autoRepair is false", function()
        local repaired = false
        _G.GetRepairAllCost = function()
            return 5000, true
        end
        _G.GetMoney = function()
            return 100000
        end
        _G.RepairAllItems = function()
            repaired = true
        end

        automationFrame._script_OnEvent(automationFrame, "MERCHANT_SHOW")
        assert.is_false(repaired)
    end)
end)

--------------------------------------------------------------------------------
-- DB Toggle: autoRelease = false
--------------------------------------------------------------------------------

describe("Automation autoRelease toggle off", function()
    local automationFrame

    before_each(function()
        LunarUI.CleanupAutomation()
        automationFrame = findAutomationFrame()
        automationDB.autoRelease = false
        LunarUI.InitAutomation()
    end)

    after_each(function()
        LunarUI.CleanupAutomation()
        automationDB.autoRelease = true
        _G.IsInInstance = function()
            return false, "none"
        end
        _G.UnitIsDeadOrGhost = function()
            return false
        end
        _G.RepopMe = function() end
    end)

    it("does NOT call RepopMe when autoRelease is false in PvP", function()
        local released = false
        _G.IsInInstance = function()
            return true, "pvp"
        end
        _G.UnitIsDeadOrGhost = function()
            return true
        end
        _G.UnitIsFeignDeath = function()
            return false
        end
        _G.RepopMe = function()
            released = true
        end

        automationFrame._script_OnEvent(automationFrame, "PLAYER_DEAD")
        assert.is_false(released)
    end)
end)

--------------------------------------------------------------------------------
-- Quest Auto Accept
--------------------------------------------------------------------------------

describe("Automation quest handling", function()
    local automationFrame

    before_each(function()
        LunarUI.CleanupAutomation()
        automationFrame = findAutomationFrame()
        LunarUI.InitAutomation()
    end)

    after_each(function()
        LunarUI.CleanupAutomation()
        _G.AcceptQuest = function() end
        _G.GetNumQuestChoices = function()
            return 0
        end
        _G.GetQuestReward = function() end
    end)

    it("calls AcceptQuest when QUEST_DETAIL fires", function()
        local accepted = false
        _G.AcceptQuest = function()
            accepted = true
        end

        automationFrame._script_OnEvent(automationFrame, "QUEST_DETAIL")
        assert.is_true(accepted)
    end)

    it("calls GetQuestReward on QUEST_COMPLETE with no choices", function()
        local rewarded = false
        _G.GetNumQuestChoices = function()
            return 0
        end
        _G.GetQuestReward = function()
            rewarded = true
        end

        automationFrame._script_OnEvent(automationFrame, "QUEST_COMPLETE")
        assert.is_true(rewarded)
    end)

    it("calls GetQuestReward(1) on QUEST_COMPLETE with exactly 1 choice", function()
        local rewardedIndex = nil
        _G.GetNumQuestChoices = function()
            return 1
        end
        _G.GetQuestReward = function(idx)
            rewardedIndex = idx
        end

        automationFrame._script_OnEvent(automationFrame, "QUEST_COMPLETE")
        assert.equals(1, rewardedIndex)
    end)

    it("does not call GetQuestReward on QUEST_COMPLETE with 2+ choices", function()
        local rewarded = false
        _G.GetNumQuestChoices = function()
            return 2
        end
        _G.GetQuestReward = function()
            rewarded = true
        end

        automationFrame._script_OnEvent(automationFrame, "QUEST_COMPLETE")
        assert.is_false(rewarded)
    end)
end)

--------------------------------------------------------------------------------
-- LFG Auto Accept
--------------------------------------------------------------------------------

describe("Automation LFG queue", function()
    local automationFrame

    before_each(function()
        LunarUI.CleanupAutomation()
        automationFrame = findAutomationFrame()
        LunarUI.InitAutomation()
    end)

    after_each(function()
        LunarUI.CleanupAutomation()
        _G.AcceptProposal = function() end
    end)

    it("calls AcceptProposal on LFG_PROPOSAL_SHOW", function()
        local accepted = false
        _G.AcceptProposal = function()
            accepted = true
        end

        automationFrame._script_OnEvent(automationFrame, "LFG_PROPOSAL_SHOW")
        assert.is_true(accepted)
    end)
end)
