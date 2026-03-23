---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - 效能分析器
    可選的模組初始化計時與事件處理器效能追蹤
    使用 /lunar profile 命令查看結果
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 分析資料儲存
--------------------------------------------------------------------------------

local profilingEnabled = false
local moduleTimings = {} -- { name = string, initTime = number }

-- 效能門檻常數（用於顏色標示）
local INIT_CRIT_MS = 50 -- 模組初始化：紅色門檻
local INIT_WARN_MS = 10 -- 模組初始化：黃色門檻
local EVENT_RATE_CRIT = 100 -- 事件頻率：紅色門檻（次/秒）
local EVENT_RATE_WARN = 30 -- 事件頻率：黃色門檻（次/秒）

--------------------------------------------------------------------------------
-- 計時工具
--------------------------------------------------------------------------------

-- debugprofilestop() 返回自 UI 載入以來的微秒數（僅 WoW 客戶端可用）
local function GetTimestamp()
    if debugprofilestop then
        return debugprofilestop()
    end
    return 0
end

--------------------------------------------------------------------------------
-- 模組初始化計時
--------------------------------------------------------------------------------

--[[
    包裝模組初始化函數，記錄執行耗時
    @param name string - 模組名稱
    @param initFunc function - 模組的 onEnable 函數
    @return boolean, string|nil - pcall 的返回值
]]
function LunarUI.ProfileModuleInit(name, initFunc)
    if not profilingEnabled then
        return pcall(initFunc)
    end

    local startTime = GetTimestamp()
    local ok, err = pcall(initFunc)
    local elapsed = (GetTimestamp() - startTime) / 1000 -- 微秒轉毫秒

    moduleTimings[#moduleTimings + 1] = {
        name = name,
        initTime = elapsed,
    }

    return ok, err
end

--------------------------------------------------------------------------------
-- 結果輸出
--------------------------------------------------------------------------------

--[[
    輸出分析結果至聊天視窗
    模組按初始化耗時降序排列，以顏色標示效能等級
]]
function LunarUI:PrintProfilingResults()
    if #moduleTimings == 0 then
        self:Print(
            "|cff8882ff[Profiler]|r "
                .. (L["ProfilerNoData"] or "No profiling data. Run /lunar profile on then /reload")
        )
        return
    end

    self:Print("|cff8882ff=== " .. (L["ProfilerInitHeader"] or "Module Init Timings") .. " ===|r")

    -- 按耗時降序排列
    table.sort(moduleTimings, function(a, b)
        return a.initTime > b.initTime
    end)

    local totalInit = 0
    for _, m in ipairs(moduleTimings) do
        totalInit = totalInit + m.initTime
        local color = m.initTime > INIT_CRIT_MS and "|cffff4444"
            or m.initTime > INIT_WARN_MS and "|cffffcc00"
            or "|cff00ff00"
        self:Print(string.format("  %s%-25s %.2f ms|r", color, m.name, m.initTime))
    end
    self:Print(
        string.format(
            "  |cffffffff--- " .. (L["ProfilerTotal"] or "Total") .. ": %.2f ms (%d modules)|r",
            totalInit,
            #moduleTimings
        )
    )
end

--------------------------------------------------------------------------------
-- 啟用/停用
--------------------------------------------------------------------------------

function LunarUI:EnableProfiling()
    profilingEnabled = true
    wipe(moduleTimings)
    self:Print(
        "|cff8882ff[Profiler]|r Profiling |cff00ff00ON|r — "
            .. (L["ProfilerReloadHint"] or "/reload then /lunar profile show")
    )
end

function LunarUI:DisableProfiling()
    profilingEnabled = false
    self:Print("|cff8882ff[Profiler]|r Profiling |cffff0000OFF|r")
end

function LunarUI.IsProfilingEnabled()
    return profilingEnabled
end

--------------------------------------------------------------------------------
-- 事件頻率監控
--------------------------------------------------------------------------------

local eventProfilingEnabled = false
local eventCounts = {} -- { [eventName] = number }
local eventProfilingFrame = nil
local eventProfilingStart = 0 -- 啟用時的時間戳（微秒）
local eventProfilingEnd = nil -- 停用時的時間戳（微秒），nil 代表仍在監控中

--[[
    啟用事件頻率監控
    註冊常見高頻事件，記錄觸發次數
]]
function LunarUI:EnableEventProfiling()
    if eventProfilingEnabled then
        self:Print("|cff8882ff[Profiler]|r " .. (L["ProfilerEventActive"] or "Event profiling already active"))
        return
    end

    wipe(eventCounts)
    eventProfilingEnabled = true
    eventProfilingStart = GetTimestamp()
    eventProfilingEnd = nil -- 重置結束時間戳

    if not eventProfilingFrame then
        eventProfilingFrame = CreateFrame("Frame")
    end

    -- 註冊常見高頻事件
    local trackedEvents = {
        "UNIT_HEALTH",
        "UNIT_POWER_UPDATE",
        "UNIT_AURA",
        "COMBAT_LOG_EVENT_UNFILTERED",
        "UNIT_TARGET",
        "NAME_PLATE_UNIT_ADDED",
        "NAME_PLATE_UNIT_REMOVED",
        "GROUP_ROSTER_UPDATE",
        "PLAYER_TARGET_CHANGED",
        "SPELL_UPDATE_COOLDOWN",
        "ACTIONBAR_UPDATE_STATE",
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_SUCCEEDED",
        "UPDATE_MOUSEOVER_UNIT",
    }

    local failed = 0
    for _, event in ipairs(trackedEvents) do
        local ok = pcall(function()
            eventProfilingFrame:RegisterEvent(event)
        end)
        if not ok then
            failed = failed + 1
        end
    end

    eventProfilingFrame:SetScript("OnEvent", function(_self, event)
        eventCounts[event] = (eventCounts[event] or 0) + 1
    end)

    local msg = "|cff8882ff[Profiler]|r Event profiling |cff00ff00ON|r — "
        .. (L["ProfilerEventViewHint"] or "/lunar profile events to view")
    if failed > 0 then
        msg = msg .. string.format(" |cffffcc00(%d events failed to register)|r", failed)
    end
    self:Print(msg)
end

--[[
    停用事件頻率監控
]]
function LunarUI:DisableEventProfiling()
    if not eventProfilingEnabled then
        self:Print("|cff8882ff[Profiler]|r " .. (L["ProfilerEventNotActive"] or "Event profiling not active"))
        return
    end
    eventProfilingEnabled = false
    eventProfilingEnd = GetTimestamp() -- 記錄結束時間，確保 PrintEventTimings 使用正確的 elapsed

    if eventProfilingFrame then
        eventProfilingFrame:UnregisterAllEvents()
        eventProfilingFrame:SetScript("OnEvent", nil)
    end

    self:Print("|cff8882ff[Profiler]|r Event profiling |cffff0000OFF|r")
end

--[[
    輸出事件頻率統計
    按觸發次數降序排列，以顏色標示頻率等級
]]
function LunarUI:PrintEventTimings()
    local sorted = {}
    for event, count in pairs(eventCounts) do
        sorted[#sorted + 1] = { event = event, count = count }
    end

    if #sorted == 0 then
        self:Print(
            "|cff8882ff[Profiler]|r "
                .. (L["ProfilerNoEventData"] or "No event data. Use /lunar profile events on first")
        )
        return
    end

    table.sort(sorted, function(a, b)
        return a.count > b.count
    end)

    -- 使用記錄的結束時間（若已停用），否則使用當前時間（仍在監控中）
    local elapsed = ((eventProfilingEnd or GetTimestamp()) - eventProfilingStart) / 1000000 -- 微秒轉秒
    self:Print(
        string.format(
            "|cff8882ff=== " .. (L["ProfilerEventHeader"] or "Event Frequency") .. " (%.1f sec) ===|r",
            elapsed
        )
    )

    for _, e in ipairs(sorted) do
        local rate = elapsed > 0 and (e.count / elapsed) or 0
        local color = rate > EVENT_RATE_CRIT and "|cffff4444" or rate > EVENT_RATE_WARN and "|cffffcc00" or "|cff00ff00"
        local firesLabel = L["ProfilerFires"] or "fires"
        self:Print(string.format("  %s%-35s %6d " .. firesLabel .. "  (%.1f/sec)|r", color, e.event, e.count, rate))
    end
end
