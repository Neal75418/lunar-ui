---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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
L["CmdHelp"] = "顯示此說明"
L["CmdToggle"] = "切換插件開關"
L["CmdStatus"] = "顯示目前狀態"
L["CmdConfig"] = "開啟設定介面"
L["CmdDebug"] = "切換除錯模式"
L["CmdKeybind"] = "切換快捷鍵編輯模式"
L["CmdExport"] = "匯出設定"
L["CmdImport"] = "匯入設定"
L["CmdInstall"] = "重新執行安裝精靈"
L["CmdMove"] = "切換框架移動模式"
L["CmdReset"] = "重置框架位置"
L["CmdTest"] = "執行測試"
L["UnknownCommand"] = "未知命令：%s"
L["InstallWizardUnavailable"] = "安裝精靈不可用"
L["KeybindModeUnavailable"] = "快捷鍵模式不可用"
L["ExportUnavailable"] = "匯出功能不可用"
L["ImportUnavailable"] = "匯入功能不可用"
L["OpenOptionsHint"] = "請在 ESC → 選項 → 插件 中找到 LunarUI"
L["PositionReset"] = "框架位置已重置為預設值"
L["StatusTitle"] = "|cff8882ffLunarUI 狀態：|r"
L["StatusVersion"] = "版本：%s"
L["StatusEnabled"] = "啟用：%s"
L["StatusDebug"] = "除錯：%s"
L["TestMode"] = "測試模式：%s"
L["AvailableTests"] = "可用測試："
L["CmdTestDesc"] = "顯示測試說明"

-- 戰鬥訊息
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

-- 提示框額外資訊
L["TooltipSpec"] = "專精:"
L["TooltipILvl"] = "裝等:"
L["TooltipTarget"] = "目標:"
L["TooltipRole"] = "角色:"
L["TooltipItemLevel"] = "物品等級:"
L["RoleTank"] = "坦克"
L["RoleHealer"] = "治療"
L["RoleDPS"] = "傷害"

-- 框架移動器
L["MoverResetToDefault"] = "%s 已重設到預設位置"
L["MoverDragToMove"] = "左鍵拖曳移動"
L["MoverCtrlSnap"] = "Ctrl+拖曳 網格對齊"
L["MoverRightReset"] = "右鍵 重設位置"
L["MoverCombatLocked"] = "戰鬥中無法進入移動模式"
L["MoverEnterMode"] = "進入移動模式 — 拖曳藍色框架移動 UI | Ctrl+拖曳對齊網格 | 右鍵重設 | ESC 退出"
L["MoverExitMode"] = "已退出移動模式"
L["MoverAllReset"] = "所有框架位置已重設"

-- 聊天與提示框增強
L["Timestamps"] = "時間戳記"
L["TimestampsDesc"] = "在聊天訊息前顯示時間戳記（需重載）"
L["TimestampFormat"] = "時間戳記格式"
L["ItemCount"] = "物品數量"
L["ItemCountDesc"] = "在滑鼠提示框中顯示物品持有數量（背包/銀行）"

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

-- 安裝精靈
L["InstallWelcome"] = "歡迎使用 |cff8882ffLunar|r|cffffffffUI|r！"
L["InstallSkipped"] = "已跳過設定。使用 |cff8882ff/lunar config|r 隨時設定。"
L["InstallComplete"] = "設定完成！正在重新載入 UI..."
L["InstallReloadText"] = "LunarUI 設定完成。是否重新載入 UI 以套用變更？"
L["InstallReloadBtn"] = "重新載入"
L["InstallReloadLater"] = "稍後"
L["InstallTitle"] = "|cff8882ffLunar|r|cffffffffUI|r 安裝精靈"
L["InstallStep"] = "步驟 %d / %d"
L["InstallWelcomeBody"] = "歡迎使用 |cff8882ffLunar|r|cffffffffUI|r！\n\n此精靈將協助你完成基本設定。你可以隨時透過 |cff8882ff/lunar config|r 修改。\n"
L["InstallUIScale"] = "UI 縮放"
L["InstallUIScaleTip"] = "|cff888888提示：數值越大 UI 元素越大。1920x1080 解析度建議使用 0.75。|r"
L["InstallLayoutTitle"] = "選擇你的主要角色定位，這將調整團隊/隊伍框架的大小與佈局。\n"
L["InstallLayoutDPS"] = "輸出"
L["InstallLayoutDPSDesc"] = "精簡的團隊框架、較大的玩家/目標框、著重減益顯示"
L["InstallLayoutTank"] = "坦克"
L["InstallLayoutTankDesc"] = "較寬的團隊框架（含仇恨顯示）、較大的名牌"
L["InstallLayoutHealer"] = "治療"
L["InstallLayoutHealerDesc"] = "較大的團隊框架（含治療預測）、置中位置"
L["InstallActionBarTitle"] = "動作條選項\n\n設定動作條在非戰鬥狀態下的行為。\n"
L["InstallActionBarFade"] = "非戰鬥時動作條淡出"
L["InstallActionBarFadeDesc"] = "|cff888888非戰鬥時動作條透明度降至 30%，進入戰鬥或滑鼠移到上方時立即顯示。|r"
L["InstallSummaryTitle"] = "|cff8882ff設定完成！|r"
L["InstallSummary"] = "你的設定摘要："
L["InstallSummaryScale"] = "|cff8882ffUI 縮放:|r %s"
L["InstallSummaryLayout"] = "|cff8882ff佈局:|r %s"
L["InstallSummaryFade"] = "|cff8882ff動作條淡出:|r %s"
L["InstallSummaryHint"] = "|cff888888點擊「完成」套用設定並重新載入 UI。\n你可以隨時透過 |cff8882ff/lunar config|r 重新設定。|r"
L["InstallBtnSkip"] = "跳過"
L["InstallBtnBack"] = "上一步"
L["InstallBtnNext"] = "下一步"
L["InstallBtnFinish"] = "完成"

-- 自動化
L["AutoRepair"] = "自動修裝"
L["AutoRepairDesc"] = "在商人處自動修理裝備"
L["AutoRepairGuild"] = "使用公會資金"
L["AutoRepairGuildDesc"] = "優先使用公會銀行支付修理費用"
L["AutoRelease"] = "自動釋放靈魂"
L["AutoReleaseDesc"] = "在戰場中自動釋放靈魂"
L["AutoScreenshot"] = "成就截圖"
L["AutoScreenshotDesc"] = "獲得成就時自動截圖"
L["RepairCost"] = "修理費用 %s"
L["RepairCostGuild"] = "修理費用 %s（公會銀行）"
L["RepairNoFunds"] = "金幣不足，無法修理"

-- 拾取
L["LootTitle"] = "拾取"
L["LootAll"] = "全部拾取"
L["LootFrame"] = "自訂拾取視窗"
L["LootFrameDesc"] = "使用 LunarUI 風格的拾取視窗取代預設拾取框（需重載）"

-- 視覺風格
L["style"] = "視覺風格"
L["styleDesc"] = "自訂 LunarUI 的整體外觀"
L["theme"] = "主題"
L["font"] = "字型"
L["fontDesc"] = "所有 LunarUI 元素使用的字型（需重載）"
L["fontSize"] = "字型大小"
L["fontSizeDesc"] = "LunarUI 元素的基礎字型大小（需重載）"
L["statusBarTexture"] = "狀態條材質"
L["statusBarTextureDesc"] = "血量、能量及其他狀態條使用的材質（需重載）"
L["borderStyle"] = "邊框風格"
L["borderStyleDesc"] = "LunarUI 框架的邊框風格"

-- 效能監控
L["HomeLatency"] = "本地延遲"
L["WorldLatency"] = "世界延遲"
L["ShiftDragToMove"] = "Shift+拖曳 移動位置"
L["PerfMonitorTitle"] = "|cff8882ffLunarUI|r 效能監控"

-- 綁定類型
L["BoE"] = "BoE"
L["BoU"] = "BoU"

-- 錯誤
L["ErrorOUFNotFound"] = "錯誤：找不到 oUF 框架"
L["ErrorAddonInit"] = "錯誤：插件初始化失敗"
