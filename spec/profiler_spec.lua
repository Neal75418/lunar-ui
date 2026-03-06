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
    end)

    it("starts disabled", function()
        assert.is_false(LunarUI:IsProfilingEnabled())
    end)

    it("enables profiling", function()
        LunarUI:EnableProfiling()
        assert.is_true(LunarUI:IsProfilingEnabled())
    end)

    it("disables profiling", function()
        LunarUI:EnableProfiling()
        LunarUI:DisableProfiling()
        assert.is_false(LunarUI:IsProfilingEnabled())
    end)

    it("prints message on enable", function()
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
        local ok = LunarUI:ProfileModuleInit("TestModule", function()
            called = true
        end)
        assert.is_true(called)
        assert.is_true(ok)
    end)

    it("records timing when profiling enabled", function()
        LunarUI:EnableProfiling()
        timestampValue = 1000
        LunarUI:ProfileModuleInit("FastModule", function()
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
        local ok, err = LunarUI:ProfileModuleInit("BadModule", function()
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
        assert.truthy(printLog[1]:find("無分析資料"))
    end)

    it("sorts modules by init time descending", function()
        LunarUI:EnableProfiling()
        -- Module 1: 5ms
        timestampValue = 0
        LunarUI:ProfileModuleInit("SlowModule", function()
            timestampValue = 5000
        end)
        -- Module 2: 50ms
        timestampValue = 10000
        LunarUI:ProfileModuleInit("SlowerModule", function()
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
        LunarUI:ProfileModuleInit("M1", function()
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
            pcall(function()
                LunarUI:DisableEventProfiling()
            end)
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
end)
