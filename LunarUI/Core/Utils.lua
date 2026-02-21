---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Utility Functions
    Shared helper functions for formatting, color calculations, etc.
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local format = format
local floor = math.floor

--------------------------------------------------------------------------------
-- Number Formatting
--------------------------------------------------------------------------------

--[[
    Format large numbers with K/M suffixes
    @param value number - The value to format
    @return string - Formatted string (e.g., "1.5M", "25.3K", "999")

    Usage:
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

--------------------------------------------------------------------------------
-- Duration Formatting
--------------------------------------------------------------------------------

--[[
    Format duration in seconds to human-readable string
    @param seconds number - Duration in seconds
    @return string - Formatted string (e.g., "2h", "15m", "30", "5.5")

    Usage:
        local text = LunarUI.FormatDuration(3700)  -- "1h"
        local text = LunarUI.FormatDuration(90)    -- "1m"
        local text = LunarUI.FormatDuration(5.5)   -- "5.5"
]]
function LunarUI.FormatDuration(seconds)
    if not seconds or seconds <= 0 then
        return ""
    end
    if seconds >= 3600 then
        return format("%dh", floor(seconds / 3600))
    elseif seconds >= 60 then
        return format("%dm", floor(seconds / 60))
    elseif seconds >= 10 then
        return format("%d", floor(seconds))
    else
        return format("%.1f", seconds)
    end
end

--------------------------------------------------------------------------------
-- Status Color
--------------------------------------------------------------------------------

--[[
    Get status color based on value thresholds
    @param value number - Current value
    @param greenThreshold number - Value at which to show green
    @param yellowThreshold number - Value at which to show yellow
    @param invert boolean - If true, lower values are better
    @return number, number - Red and Green color components (Blue is always 0.3)

    Usage:
        local r, g = LunarUI.StatusColor(latency, 100, 200, true)  -- Low is good
        local r, g = LunarUI.StatusColor(fps, 60, 30, false)       -- High is good
]]
function LunarUI.StatusColor(value, greenThreshold, yellowThreshold, invert)
    if not value then
        return 1, 0.3
    end

    local good, warn
    if invert then
        good = value <= greenThreshold
        warn = value <= yellowThreshold
    else
        good = value >= greenThreshold
        warn = value >= yellowThreshold
    end

    if good then
        return 0.3, 1 -- Green
    elseif warn then
        return 1, 0.8 -- Yellow
    else
        return 1, 0.3 -- Red
    end
end

--[[
    Get threshold color from a tiered threshold array (4-tier: green/yellow/orange/red)
    @param value number - Current value
    @param thresholds table - Array of 3 threshold values {good, medium, bad}
    @param ascending boolean - If true, higher values are better (e.g. FPS)
    @return number, number, number - R, G, B color components

    Usage:
        local r, g, b = LunarUI.ThresholdColor(fps, {60, 30, 15}, true)
        local r, g, b = LunarUI.ThresholdColor(latency, {100, 200, 400}, false)
]]
function LunarUI.ThresholdColor(value, thresholds, ascending)
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
-- Nil-safe Table Access
--------------------------------------------------------------------------------

--[[
    Safely access nested table values
    @param tbl table - Root table
    @param ... string - Keys to traverse
    @return any - Value at path or nil

    Usage:
        local value = LunarUI.GetNestedValue(data, "player", "stats", "health")
]]
function LunarUI.GetNestedValue(tbl, ...)
    if type(tbl) ~= "table" then
        return nil
    end
    local current = tbl
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if type(current) ~= "table" then
            return nil
        end
        current = current[key]
        if current == nil then
            return nil
        end
    end
    return current
end

--------------------------------------------------------------------------------
-- Color Utilities
--------------------------------------------------------------------------------

--[[
    Convert hex color to RGB values (0-1 range)
    @param hex string - Hex color (e.g., "#FF0000" or "FF0000")
    @return number, number, number - R, G, B values (0-1)

    Usage:
        local r, g, b = LunarUI.HexToRGB("#8882ff")
]]
function LunarUI.HexToRGB(hex)
    if not hex then
        return 1, 1, 1
    end
    hex = hex:gsub("#", "")
    if #hex ~= 6 then
        return 1, 1, 1
    end

    local r = (tonumber(hex:sub(1, 2), 16) or 255) / 255
    local g = (tonumber(hex:sub(3, 4), 16) or 255) / 255
    local b = (tonumber(hex:sub(5, 6), 16) or 255) / 255

    return r, g, b
end

--[[
    Convert RGB values to hex color
    @param r number - Red (0-1)
    @param g number - Green (0-1)
    @param b number - Blue (0-1)
    @return string - Hex color (e.g., "FF0000")

    Usage:
        local hex = LunarUI.RGBToHex(1, 0, 0)  -- "FF0000"
]]
function LunarUI.RGBToHex(r, g, b)
    r = r or 1
    g = g or 1
    b = b or 1
    return format("%02X%02X%02X", floor(r * 255), floor(g * 255), floor(b * 255))
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
    local db = LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.hud
    if db and db[key] ~= nil then
        return db[key]
    end
    return default
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
    if not ok and LunarUI.Debug then
        LunarUI:Debug((context or "Error") .. ": " .. tostring(err))
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

--------------------------------------------------------------------------------
-- 工具提示
--------------------------------------------------------------------------------

--[[
    顯示格式化工具提示
    @param owner Frame - 提示錨點框架
    @param title string - 標題文字（可選）
    @param lines table - 內容行陣列（可選）
        - 字串：以灰色顯示
        - 表格 {text, r, g, b}：以指定顏色顯示

    Usage:
        LunarUI.ShowTooltip(button, "My Title", {
            "Simple gray line",
            {"Colored line", 1, 0.8, 0},
        })
]]
function LunarUI.ShowTooltip(owner, title, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP", 0, 4)
    GameTooltip:ClearLines()
    if title then
        GameTooltip:AddLine(title, 1, 1, 1)
    end
    if lines then
        for _, line in ipairs(lines) do
            if type(line) == "table" then
                GameTooltip:AddLine(line[1], line[2], line[3], line[4])
            else
                GameTooltip:AddLine(line, 0.7, 0.7, 0.7)
            end
        end
    end
    GameTooltip:Show()
end
