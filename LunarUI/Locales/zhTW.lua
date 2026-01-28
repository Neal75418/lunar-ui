--[[
    LunarUI - Traditional Chinese (Taiwan) Localization
]]

local ADDON_NAME, Engine = ...
local L = Engine.L or {}

-- Only override if client is zhTW
if GetLocale() ~= "zhTW" then return end

-- General
L["Enabled"] = "已啟用"
L["Disabled"] = "已停用"
L["Debug"] = "除錯"

-- Phases
L["Phase"] = "月相"
L["NEW"] = "新月"
L["WAXING"] = "上弦月"
L["FULL"] = "滿月"
L["WANING"] = "下弦月"

-- Commands
L["Commands"] = "命令"
L["Help"] = "說明"
L["Toggle"] = "切換"
L["Status"] = "狀態"
L["Config"] = "設定"
L["Reset"] = "重置"

-- UnitFrames
L["Player"] = "玩家"
L["Target"] = "目標"
L["Focus"] = "焦點"
L["Pet"] = "寵物"
L["Party"] = "隊伍"
L["Raid"] = "團隊"
L["Boss"] = "首領"

-- Settings
L["General"] = "一般"
L["UnitFrames"] = "單位框架"
L["ActionBars"] = "動作條"
L["Minimap"] = "小地圖"
L["Bags"] = "背包"
L["Chat"] = "聊天"
L["Tooltip"] = "滑鼠提示"

-- Fix #104: Bags module messages
L["SoldJunkItems"] = "已販賣 %d 件垃圾物品，獲得 %s"

-- Fix #104: Chat module messages
L["PressToCopyURL"] = "按 Ctrl+C 複製網址:"
