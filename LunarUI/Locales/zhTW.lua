---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 繁體中文本地化
]]

local _ADDON_NAME, Engine = ...
local L = Engine.L or {}

-- 僅在繁中客戶端覆蓋
if GetLocale() ~= "zhTW" then return end

-- 一般
L["Enabled"] = "已啟用"
L["Disabled"] = "已停用"
L["Debug"] = "除錯"
L["Yes"] = "是"
L["No"] = "否"
L["On"] = "開"
L["Off"] = "關"

-- 月相
L["Phase"] = "月相"
L["NEW"] = "新月"
L["WAXING"] = "上弦月"
L["FULL"] = "滿月"
L["WANING"] = "下弦月"

-- 命令
L["Commands"] = "命令"
L["Help"] = "說明"
L["Toggle"] = "切換"
L["Status"] = "狀態"
L["Config"] = "設定"
L["Reset"] = "重置"

-- 單位框架
L["Player"] = "玩家"
L["Target"] = "目標"
L["Focus"] = "焦點"
L["Pet"] = "寵物"
L["Party"] = "隊伍"
L["Raid"] = "團隊"
L["Boss"] = "首領"

-- 設定分類
L["General"] = "一般"
L["UnitFrames"] = "單位框架"
L["ActionBars"] = "動作條"
L["Minimap"] = "小地圖"
L["Bags"] = "背包"
L["Chat"] = "聊天"
L["Tooltip"] = "滑鼠提示"

-- 系統訊息
L["AddonLoaded"] = "插件載入完成"
L["AddonEnabled"] = "已啟用。輸入 |cff8882ff/lunar|r 查看命令"
L["DebugEnabled"] = "除錯模式：已開啟"
L["DebugDisabled"] = "除錯模式：已關閉"

-- 命令訊息
L["HelpTitle"] = "LunarUI 命令："
L["CmdToggle"] = "切換插件開關"
L["CmdStatus"] = "顯示目前狀態"
L["CmdConfig"] = "開啟設定介面"
L["CmdDebug"] = "切換除錯模式"
L["CmdReset"] = "重置為預設值"
L["CmdTest"] = "執行戰鬥模擬"

-- 月相訊息
L["PhaseChanged"] = "月相：%s → %s"
L["CurrentPhase"] = "目前月相：%s"
L["CombatEnter"] = "進入戰鬥"
L["CombatLeave"] = "脫離戰鬥"

-- 快捷鍵訊息
L["KeybindEnabled"] = "快捷鍵模式：移動滑鼠至按鈕並按下按鍵綁定"
L["KeybindDisabled"] = "快捷鍵模式：已關閉"
L["KeybindSet"] = "已綁定 %s 至 %s"
L["KeybindCleared"] = "已清除 %s 的綁定"

-- 背包
L["BagTitle"] = "背包"
L["BankTitle"] = "銀行"
L["ReagentBank"] = "材料"
L["Sort"] = "整理"
L["SoldJunkItems"] = "已販賣 %d 件垃圾物品，獲得 %s"
L["BagSearchError"] = "背包搜尋錯誤"
L["BankSearchError"] = "銀行搜尋錯誤"

-- 聊天
L["PressToCopyURL"] = "按 Ctrl+C 複製網址："
L["KeywordAlert"] = "關鍵字警報"
L["SpamFiltered"] = "垃圾訊息已過濾"

-- 設定
L["SettingsImported"] = "設定匯入成功"
L["SettingsExported"] = "設定已匯出至剪貼簿"
L["InvalidSettings"] = "無效的設定格式"

-- 錯誤
L["ErrorOUFNotFound"] = "錯誤：找不到 oUF 框架"
L["ErrorAddonInit"] = "錯誤：插件初始化失敗"
