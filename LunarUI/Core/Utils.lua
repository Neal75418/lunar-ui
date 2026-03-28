---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - 工具函式
    共用輔助函式：數值格式化、顏色計算等
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local format = string.format

--------------------------------------------------------------------------------
-- 數值格式化
--------------------------------------------------------------------------------

--[[
    大數字格式化（K/M 後綴）
    @param value number - 要格式化的數值
    @return string - 格式化字串（如 "1.5M"、"25.3K"、"999"）

    用法：
        local text = LunarUI.FormatValue(1500000)  -- "1.5M"
]]
function LunarUI.FormatValue(value)
    if not value then
        return "0"
    end
    if value >= 1e6 then
        return format("%.1fM", value / 1e6)
    elseif value >= 1e3 then
        return format("%.1fK", value / 1e3)
    end
    return tostring(value)
end

--[[
    四階門檻顏色（綠/黃/橙/紅）
    @param value number - 當前數值
    @param thresholds table - 三個門檻值陣列 {好, 中, 差}
    @param ascending boolean - true 表示數值越高越好（如 FPS）
    @return number, number, number - R, G, B 顏色分量

    用法：
        local r, g, b = LunarUI.ThresholdColor(fps, {60, 30, 15}, true)
        local r, g, b = LunarUI.ThresholdColor(latency, {100, 200, 400}, false)
]]
function LunarUI.ThresholdColor(value, thresholds, ascending)
    if not value or not thresholds then
        return 0.9, 0.9, 0.2
    end
    if ascending then
        if value >= thresholds[1] then
            return 0.2, 0.8, 0.2
        elseif value >= thresholds[2] then
            return 0.9, 0.9, 0.2
        elseif value >= thresholds[3] then
            return 0.9, 0.5, 0.1
        else
            return 0.9, 0.2, 0.2
        end
    else
        if value <= thresholds[1] then
            return 0.2, 0.8, 0.2
        elseif value <= thresholds[2] then
            return 0.9, 0.9, 0.2
        elseif value <= thresholds[3] then
            return 0.9, 0.5, 0.1
        else
            return 0.9, 0.2, 0.2
        end
    end
end

--------------------------------------------------------------------------------
-- HUD 設定存取
--------------------------------------------------------------------------------

--[[
    取得 HUD 設定值（含預設值回退）
    @param key string - 設定鍵名
    @param default any - 找不到時的預設值
    @return any - 設定值或預設值

    Usage:
        local size = LunarUI.GetHUDSetting("auraIconSize", 30)
]]
function LunarUI.GetHUDSetting(key, default)
    local db = LunarUI.GetModuleDB("hud")
    if db and db[key] ~= nil then
        return db[key]
    end
    return default
end

--[[
    統一模組 DB 存取介面（避免重複的 nil 檢查）
    @param moduleName string - 模組名稱（如 "unitframes", "nameplates", "hud"）
    @return table|nil - 模組設定表，若不存在則返回 nil

    Usage:
        local db = LunarUI.GetModuleDB("unitframes")
        if not db or not db.enabled then return end
]]
function LunarUI.GetModuleDB(moduleName)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[moduleName]
end

--------------------------------------------------------------------------------
-- 格式化工具
--------------------------------------------------------------------------------

--[[
    格式化遊戲時間為 12h 或 24h 格式
    @param hour number - 小時（0-23）
    @param minute number - 分鐘（0-59）
    @param is24h boolean - 是否使用 24 小時制
    @return string - 格式化時間字串
]]
function LunarUI.FormatGameTime(hour, minute, is24h)
    if not is24h then
        local suffix = hour >= 12 and (TIMEMANAGER_PM or "PM") or (TIMEMANAGER_AM or "AM")
        hour = hour % 12
        if hour == 0 then
            hour = 12
        end
        return format("%d:%02d %s", hour, minute, suffix)
    end
    return format("%02d:%02d", hour, minute)
end

--[[
    格式化地圖座標為 "x, y" 字串
    @param x number - X 座標（0-100）
    @param y number - Y 座標（0-100）
    @return string - 格式化座標字串
]]
function LunarUI.FormatCoordinates(x, y)
    if not x or not y then
        return "-, -"
    end
    return format("%.1f, %.1f", x, y)
end

--[[
    轉義 Lua pattern 特殊字元
    @param str string - 原始字串
    @return string - 轉義後的字串（可安全用於 gsub pattern）
]]
function LunarUI.EscapePattern(str)
    return str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

--------------------------------------------------------------------------------
-- 安全呼叫
--------------------------------------------------------------------------------

--[[
    統一錯誤處理包裝器，以 pcall 執行函式並在失敗時輸出偵錯訊息
    @param func function - 要執行的函式
    @param context string - 錯誤時的上下文描述（可選）
    @return boolean - 是否執行成功

    Usage:
        LunarUI.SafeCall(function() DoSomethingRisky() end, "MyModule:Init")
]]
function LunarUI.SafeCall(func, context)
    local ok, err = pcall(func)
    if not ok then
        -- 生產環境也輸出錯誤，避免靜默吞掉問題
        local msg = (context or "Error") .. ": " .. tostring(err)
        if LunarUI.IsDebugMode and LunarUI:IsDebugMode() then
            LunarUI:Debug(msg)
        elseif LunarUI.Print then
            LunarUI:Print("|cffff6060" .. msg .. "|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff6060LunarUI:|r " .. msg)
        end
    end
    return ok
end

--------------------------------------------------------------------------------
-- 事件處理器
--------------------------------------------------------------------------------

--[[
    建立並註冊多個事件的框架處理器
    @param events table - 事件名稱陣列
    @param callback function - 事件回呼函式 (self, event, ...)
    @return Frame - 已註冊事件的框架

    Usage:
        local frame = LunarUI.CreateEventHandler(
            {"PLAYER_ENTERING_WORLD", "ZONE_CHANGED"},
            function(self, event, ...) print(event) end
        )
]]
function LunarUI.CreateEventHandler(events, callback)
    local frame = CreateFrame("Frame")
    for _, event in ipairs(events) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", callback)
    return frame
end
