# LunarUI — Claude 上下文

## 專案概要

- WoW 12.0（Interface: 120000）插件，Lua 5.1（LuaJIT）
- 架構：Ace3 + oUF + LibActionButton + LibSharedMedia
- 兩個 Addon：`LunarUI/`（主體）、`LunarUI_Options/`（LoadOnDemand 設定介面）
- TOC 載入順序重要 — `Core/Init.lua` 最先執行，建立 `Engine.LunarUI`
- 所有模組透過 `local _ADDON_NAME, Engine = ...` 再取 `Engine.LunarUI` 存取核心

## 模組系統

```lua
-- 註冊模組（Core/Init.lua:68）
LunarUI:RegisterModule("ModuleName", {
    onEnable = function() ... end,
    onDisable = function() ... end,  -- 可選，反向順序執行
    delay = 0.5,                     -- 可選，延遲初始化（秒）
})

-- 註冊 HUD 框架（Core/Options.lua:18）— 自動納入 ApplyHUDScale
LunarUI:RegisterHUDFrame("FrameName")

-- 註冊可移動框架（Modules/FrameMover.lua:369）— 納入 /lunar move
LunarUI:RegisterMovableFrame("name", frame, "顯示名稱")

-- 註冊皮膚（Modules/Skins.lua）
LunarUI:RegisterSkin("name", "blizzAddonName", function() ... end)
LunarUI:MarkSkinned(frame)  -- 防重複，已處理則回傳 false
```

## 程式碼慣例

- 共用資源在 `Core/Media.lua`：backdrop 模板、DEBUFF_TYPE_COLORS、材質
- oUF 命名空間為 `LunarUF`（透過 TOC 的 `X-oUF` 設定）
- LibActionButton：`local LAB = LibStub("LibActionButton-1.0")`

## WoW 12.0 Taint 避免模式

| 情境 | 錯誤做法 | 正確做法 |
|------|----------|----------|
| Hook 全域函數 | 直接覆寫 `_G.Fn = ...` | `hooksecurefunc(obj, "Method", fn)` |
| Hook 框架腳本 | 替換 `SetScript` | `frame:HookScript("OnEvent", fn)` |
| 操作安全框架方法 | 直接替換（如 `bar.SetScale = ...`） | hooksecurefunc + `_lunarFixingScale` 再入防護旗標 |
| 操作 Blizzard 框架 | 直接操作 | 先 `if InCombatLockdown() then return end` |
| 讀取光環資料 | 直接存取 name/duration | `pcall` 安全讀取（秘密值會導致崩潰） |
| Tooltip 掃描 | `_G[tooltip:GetName().."TextLeft"..i]` | `tooltip:GetTooltipData()` + _G fallback |
| Tooltip 方法呼叫 | 直接呼叫 | `pcall(GameTooltip.SetHyperlink, ...)` |

## 效能慣例

- 模組層級 upvalue，避免重複全域查找
- GC 敏感路徑用平行陣列取代 table-of-tables（如名牌堆疊）
- 髒旗標 + 批次計時器，取代逐事件 closure
- 不需要時卸載 OnUpdate（如 fade 動畫結束即 `SetScript("OnUpdate", nil)`）
- 高頻事件用反向映射表 O(1) 查詢（如 `deathUnitMap[eventUnit]` + 惰性重建）
- 動畫期間快取設定值（如 `cachedFadeDuration`），避免每幀查 DB

## 語言

- 使用者以繁體中文溝通
- 本地化：`enUS.lua`（主要）、`zhTW.lua`
- README 與程式碼註解使用繁體中文
