# LunarUI — Claude 上下文

## 專案概要
- WoW 12.0（Interface: 120000）插件，Lua 程式碼
- 架構：Ace3 + oUF + LibActionButton
- 兩個 Addon：`LunarUI/`（主體）與 `LunarUI_Options/`（LoadOnDemand 設定介面）
- TOC 載入順序很重要 — Core/Init.lua 最先執行，建立 `Engine.LunarUI`
- 所有模組透過 `local _ADDON_NAME, Engine = ...` 再取 `Engine.LunarUI` 存取核心

## 程式碼慣例
- 共用資源集中在 `Core/Media.lua`（backdrop 模板、DEBUFF_TYPE_COLORS、材質）
- Skin 模組使用 `LunarUI:RegisterSkin(name, blizzAddon, callback)` 註冊
- Skin 防重複：`LunarUI:MarkSkinned(frame)` 已處理過則回傳 false
- oUF 命名空間為 `LunarUF`（非預設 `oUF`）— 透過 TOC 的 X-oUF 設定
- LibActionButton 引用方式：`local LAB = LibStub("LibActionButton-1.0")`

## WoW 12.0 注意事項
- 部分光環 API 值為「秘密值」— 對其做數學/串接會崩潰，但 type()/tostring() 正常
- 必須用 pcall 安全讀取光環的 name/duration 欄位
- `DebuffTypeColor` 全域變數在 12.0 可能不存在，Core/Media.lua 已定義 fallback
- `C_Timer.After(0, fn)` 用於下一幀批次處理（如 NormalTexture 清除）

## 效能慣例
- 優先使用模組層級 upvalue，避免重複全域查找
- GC 敏感路徑用平行陣列取代 table-of-tables（如名牌堆疊）
- 髒旗標 + 批次計時器模式，取代逐事件 closure
- 不需要時卸載 OnUpdate 腳本（如 waning 計時器、冷卻追蹤）

## 語言
- 使用者以繁體中文溝通
- 本地化檔案：enUS.lua（主要）、zhTW.lua
- README 與程式碼註解使用繁體中文
