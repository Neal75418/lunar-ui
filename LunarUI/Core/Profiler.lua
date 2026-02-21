---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 效能分析器
    可選的模組初始化計時與事件處理器效能追蹤
    使用 /lunar profile 命令查看結果
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 分析資料儲存
--------------------------------------------------------------------------------

local profilingEnabled = false
local moduleTimings = {} -- { name = string, initTime = number }

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
function LunarUI:ProfileModuleInit(name, initFunc)
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
        self:Print("|cff8882ff[Profiler]|r 無分析資料。請先 /lunar profile on 然後 /reload")
        return
    end

    self:Print("|cff8882ff=== Module Init Timings ===|r")

    -- 按耗時降序排列
    table.sort(moduleTimings, function(a, b)
        return a.initTime > b.initTime
    end)

    local totalInit = 0
    for _, m in ipairs(moduleTimings) do
        totalInit = totalInit + m.initTime
        -- 顏色標示：> 50ms 紅色、> 10ms 黃色、其餘綠色
        local color = m.initTime > 50 and "|cffff4444" or m.initTime > 10 and "|cffffcc00" or "|cff00ff00"
        self:Print(string.format("  %s%-25s %.2f ms|r", color, m.name, m.initTime))
    end
    self:Print(string.format("  |cffffffff--- Total: %.2f ms (%d modules)|r", totalInit, #moduleTimings))
end

--------------------------------------------------------------------------------
-- 啟用/停用
--------------------------------------------------------------------------------

function LunarUI:EnableProfiling()
    profilingEnabled = true
    wipe(moduleTimings)
    self:Print("|cff8882ff[Profiler]|r Profiling |cff00ff00ON|r — /reload 後再 /lunar profile show 查看結果")
end

function LunarUI:DisableProfiling()
    profilingEnabled = false
    self:Print("|cff8882ff[Profiler]|r Profiling |cffff0000OFF|r")
end

function LunarUI:IsProfilingEnabled()
    return profilingEnabled
end
