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

-- 光環
L["Auras"] = "光環"
L["UnitFrameAuras"] = "單位框架光環"
L["Buffs"] = "增益"
L["Debuffs"] = "減益"
L["ShowBuffs"] = "顯示增益"
L["ShowDebuffs"] = "顯示減益"
L["OnlyPlayerDebuffs"] = "僅顯示玩家減益"
L["AuraSize"] = "光環圖示大小"
L["PlayerBuffs"] = "玩家增益"
L["PlayerBuffsDesc"] = "在玩家框架旁顯示增益效果（需重載）"
L["TargetDebuffs"] = "目標減益"
L["TargetDebuffsDesc"] = "在目標框架上方顯示減益效果（需重載）"
L["OnlyPlayerDebuffsDesc"] = "目標框僅顯示自己施放的減益效果（需重載）"
L["AuraSizeDesc"] = "增益/減益圖示大小（需重載）"
L["FocusDebuffs"] = "焦點減益"
L["FocusDebuffsDesc"] = "在焦點框架上方顯示減益效果（需重載）"
L["PartyDebuffs"] = "隊伍減益"
L["PartyDebuffsDesc"] = "在隊伍框架上方顯示減益效果（需重載）"

-- 名牌
L["Nameplates"] = "啟用名牌"
L["NameplatesDesc"] = "使用 LunarUI 自訂名牌（需重載）"
L["NPHealthText"] = "生命值文字"
L["NPHealthTextDesc"] = "在名牌上顯示生命值文字（需重載）"
L["NPHealthTextFormat"] = "生命值格式"
L["NPHealthTextFormatDesc"] = "生命值文字的顯示格式（需重載）"
L["Percent"] = "百分比"
L["Current"] = "數值"
L["Both"] = "數值+百分比"
L["NPEnemyBuffs"] = "敵方增益"
L["NPEnemyBuffsDesc"] = "在敵方名牌上顯示可竊取的增益效果（需重載）"

-- 資料條
L["DataBars"] = "資料條"
L["DataBarsDesc"] = "經驗值、聲望、榮譽進度條"
L["Experience"] = "經驗值"
L["Reputation"] = "聲望"
L["Honor"] = "榮譽"
L["HonorLevel"] = "榮譽等級"
L["Standing"] = "階級"
L["Remaining"] = "剩餘"
L["Rested"] = "休息加成"
L["ShowText"] = "顯示文字"
L["TextFormat"] = "文字格式"
L["BarWidth"] = "條寬度"
L["BarHeight"] = "條高度"

-- 資料文字
L["DataTexts"] = "資料文字"
L["DataTextsDesc"] = "可配置的資訊面板（FPS、延遲、金幣、耐久度等）"
L["DTBottomPanel"] = "底部面板"
L["DTBottomPanelDesc"] = "在畫面底部顯示資料文字面板（需重載）"
L["DTSlot"] = "欄位"
L["Latency"] = "延遲"
L["Gold"] = "金幣"
L["Durability"] = "耐久度"
L["BagSlots"] = "背包空位"
L["Friends"] = "好友"
L["Guild"] = "公會"
L["Spec"] = "專精"
L["Clock"] = "時鐘"
L["Coords"] = "座標"
L["Online"] = "線上"
L["LocalTime"] = "本地時間"
L["ServerTime"] = "伺服器時間"
L["Backpack"] = "背包"
L["Zone"] = "區域"

-- 聊天與提示框增強
L["Timestamps"] = "時間戳記"
L["TimestampsDesc"] = "在聊天訊息前顯示時間戳記（需重載）"
L["TimestampFormat"] = "時間戳記格式"
L["ItemCount"] = "物品數量"
L["ItemCountDesc"] = "在滑鼠提示框中顯示物品持有數量（背包/銀行）"
L["BankTitle"] = "銀行"

-- 單位框架增強
L["ClassPower"] = "職業資源"
L["ClassPowerDesc"] = "在玩家框架上方顯示職業資源條（連擊點、聖能、符文等）（需重載）"
L["HealPrediction"] = "治療預測"
L["HealPredictionDesc"] = "在生命條上顯示即將到來的治療預測覆蓋層（需重載）"

-- 動作條
L["OutOfRange"] = "超出距離著色"
L["OutOfRangeDesc"] = "目標超出技能距離時按鈕變紅（需重載）"
L["ExtraActionButton"] = "額外動作按鈕"
L["ExtraActionButtonDesc"] = "套用 LunarUI 主題至額外動作按鈕（需重載）"
L["MicroBar"] = "微型按鈕列"
L["MicroBarDesc"] = "將系統微型按鈕重新排列成緊湊列（需重載）"
L["NameplateLevel"] = "等級文字"
L["NameplateLevelDesc"] = "在名牌名稱旁顯示等級文字（需重載）"
L["StackingDetection"] = "堆疊偵測"
L["StackingDetectionDesc"] = "偏移重疊的名牌使其不互相遮擋（需重載）"
L["QuestIcon"] = "任務圖示"
L["QuestIconDesc"] = "在敵方名牌上顯示任務目標圖示（需重載）"

-- 外觀替換
L["Skins"] = "外觀替換"
L["SkinsDesc"] = "將暴雪預設 UI 框架重新造型以符合 LunarUI 主題（需重載）"

-- 設定檔
L["ProfileChanged"] = "設定檔已變更，UI 已重新整理"

-- 錯誤
L["ErrorOUFNotFound"] = "錯誤：找不到 oUF 框架"
L["ErrorAddonInit"] = "錯誤：插件初始化失敗"
