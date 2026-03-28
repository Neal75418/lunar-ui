---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Core/Profiler.lua
    Tests profiling enable/disable, module init timing, event profiling, and output
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
local timestampValue = 0
_G.debugprofilestop = function()
    return timestampValue
end

-- Mock CreateFrame with SetScript that stores handler for event profiling
local mock_frame = require("spec.mock_frame")
local ProfilerMock = setmetatable({}, { __index = mock_frame.MockFrame })
ProfilerMock.__index = ProfilerMock
function ProfilerMock:SetScript(_, handler)
    self._onEvent = handler
end
_G.CreateFrame = function()
    return setmetatable({}, { __index = ProfilerMock })
end

-- Track print output
local printLog = {}

local LunarUI = {
    Print = function(_self, msg)
        printLog[#printLog + 1] = msg
    end,
    RegisterModule = function() end,
}

loader.loadAddonFile("LunarUI/Core/Profiler.lua", LunarUI)

--------------------------------------------------------------------------------
-- Enable / Disable
--------------------------------------------------------------------------------

describe("Profiler enable/disable", function()
    before_each(function()
        wipe(printLog)
        pcall(function()
            LunarUI:DisableProfiling()
        end)
    end)

    it("enables profiling and prints ON", function()
        LunarUI:EnableProfiling()
        assert.truthy(printLog[#printLog]:find("ON"))
    end)

    it("prints message on disable", function()
        LunarUI:EnableProfiling()
        LunarUI:DisableProfiling()
        assert.truthy(printLog[#printLog]:find("OFF"))
    end)
end)

--------------------------------------------------------------------------------
-- ProfileModuleInit
--------------------------------------------------------------------------------

describe("ProfileModuleInit", function()
    before_each(function()
        wipe(printLog)
        LunarUI:DisableProfiling()
    end)

    it("calls initFunc via pcall when profiling disabled", function()
        local called = false
        local ok = LunarUI.ProfileModuleInit("TestModule", function()
            called = true
        end)
        assert.is_true(called)
        assert.is_true(ok)
    end)

    it("records timing when profiling enabled", function()
        LunarUI:EnableProfiling()
        timestampValue = 1000
        LunarUI.ProfileModuleInit("FastModule", function()
            timestampValue = 2000 -- 1ms elapsed (1000 μs / 1000)
        end)
        -- Verify by printing results
        LunarUI:PrintProfilingResults()
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("FastModule") then
                found = true
            end
        end
        assert.is_true(found)
    end)

    it("catches errors from initFunc", function()
        LunarUI:EnableProfiling()
        local ok, err = LunarUI.ProfileModuleInit("BadModule", function()
            error("test error")
        end)
        assert.is_false(ok)
        assert.truthy(err)
    end)
end)

--------------------------------------------------------------------------------
-- PrintProfilingResults
--------------------------------------------------------------------------------

describe("PrintProfilingResults", function()
    before_each(function()
        wipe(printLog)
        -- EnableProfiling wipes moduleTimings, then disable to restore state
        LunarUI:EnableProfiling()
        LunarUI:DisableProfiling()
        wipe(printLog)
    end)

    it("prints no-data message when empty", function()
        LunarUI:PrintProfilingResults()
        assert.truthy(printLog[1]:find("No profiling data"))
    end)

    it("sorts modules by init time descending", function()
        LunarUI:EnableProfiling()
        -- Module 1: 5ms
        timestampValue = 0
        LunarUI.ProfileModuleInit("SlowModule", function()
            timestampValue = 5000
        end)
        -- Module 2: 50ms
        timestampValue = 10000
        LunarUI.ProfileModuleInit("SlowerModule", function()
            timestampValue = 60000
        end)

        wipe(printLog)
        LunarUI:PrintProfilingResults()

        -- Find positions of module names in output
        local slowerIdx, slowIdx
        for i, msg in ipairs(printLog) do
            if msg:find("SlowerModule") then
                slowerIdx = i
            end
            if msg:find("SlowModule") and not msg:find("SlowerModule") then
                slowIdx = i
            end
        end
        assert.truthy(slowerIdx)
        assert.truthy(slowIdx)
        assert.is_true(slowerIdx < slowIdx) -- SlowerModule first (higher time)
    end)

    it("shows total line", function()
        LunarUI:EnableProfiling()
        timestampValue = 0
        LunarUI.ProfileModuleInit("M1", function()
            timestampValue = 1000
        end)
        wipe(printLog)
        LunarUI:PrintProfilingResults()
        local found = false
        for _, msg in ipairs(printLog) do
            if msg:find("Total") then
                found = true
            end
        end
        assert.is_true(found)
    end)
end)

--------------------------------------------------------------------------------
-- Event Profiling
--------------------------------------------------------------------------------

describe("Event profiling", function()
    before_each(function()
        wipe(printLog)
        if LunarUI.DisableEventProfiling then
            LunarUI:DisableEventProfiling()
        end
    end)

    it("prints ON message when enabled", function()
        LunarUI:EnableEventProfiling()
        assert.truthy(printLog[#printLog]:find("ON"))
    end)

    it("prints already-active message on double enable", function()
        LunarUI:EnableEventProfiling()
        wipe(printLog)
        LunarUI:EnableEventProfiling()
        assert.truthy(printLog[#printLog]:find("already active"))
    end)

    it("prints OFF message when disabled", function()
        LunarUI:EnableEventProfiling()
        wipe(printLog)
        LunarUI:DisableEventProfiling()
        assert.truthy(printLog[#printLog]:find("OFF"))
    end)

    it("prints not-active message when disabling without enabling", function()
        LunarUI:DisableEventProfiling()
        assert.truthy(printLog[#printLog]:find("not active"))
    end)

    it("prints no-data message with empty event counts", function()
        LunarUI:PrintEventTimings()
        assert.truthy(printLog[#printLog]:find("No event data"))
    end)

    it("prints rate with correct color thresholds", function()
        LunarUI:EnableEventProfiling()
        -- 模擬事件計數（直接寫入內部 eventCounts）
        if LunarUI._eventCounts then
            LunarUI._eventCounts["TEST_EVENT_HIGH"] = 501 -- 高頻事件（>100/sec threshold）
            LunarUI._eventCounts["TEST_EVENT_LOW"] = 5 -- 低頻事件
        end
        -- 推進時間 5 秒（5,000,000 微秒）
        timestampValue = 5000000
        wipe(printLog)
        LunarUI:PrintEventTimings()

        -- 驗證有輸出（非 "No event data"）
        local hasOutput = false
        local hasRedColor = false
        local hasGreenColor = false
        for _, msg in ipairs(printLog) do
            if msg:find("TEST_EVENT_HIGH") then
                hasOutput = true
                -- 500/5sec = 100/sec → 超過 EVENT_RATE_CRIT (100) → 紅色
                if msg:find("ff4444") then
                    hasRedColor = true
                end
            end
            if msg:find("TEST_EVENT_LOW") then
                -- 5/5sec = 1/sec → 低於 EVENT_RATE_WARN (30) → 綠色
                if msg:find("00ff00") then
                    hasGreenColor = true
                end
            end
        end
        assert.is_true(hasOutput, "PrintEventTimings should output event data")
        assert.is_true(hasRedColor, "High-rate events should be red (>100/sec)")
        assert.is_true(hasGreenColor, "Low-rate events should be green (<30/sec)")
    end)
end)
