# LunarUI

**World of Warcraft 12.0 完整 UI 替換插件**

低存在感、不干擾、長時間遊玩不累。以 Phase（月相）狀態機驅動所有 UI 行為。

---

## 模組

| 類別 | 模組 | 說明 |
|------|------|------|
| **戰鬥核心** | UnitFrames | Player / Target / Focus / Pet / Party / Raid / Boss（oUF） |
| | Nameplates | 敵方 / 友方名牌（oUF） |
| | ActionBars | 動作條 1-6 + 寵物 + 姿態（LibActionButton） |
| | AuraFrames | Buff / Debuff 框架（含計時條） |
| | ClassResources | 職業資源條（連擊點、聖能等） |
| | CooldownTracker | 冷卻追蹤 |
| **HUD** | PerformanceMonitor | FPS / 延遲 / 記憶體 |
| **非戰鬥** | Minimap | 座標、區域文字、按鈕整理 |
| | Bags | 整合背包、裝等顯示、搜尋、自動賣灰 |
| | Chat | 頻道色、職業色、滑鼠滾輪、懸浮背景 |
| | Tooltip | 裝等、職業色邊框、目標的目標、ID 顯示 |
| | DataBars | 經驗 / 榮譽 / 休息 進度條 |
| | DataTexts | 可自訂的文字資訊覆蓋層 |
| | Loot | 拾取框架美化 |
| | Automation | 自動賣灰、自動郵件 |
| | Skins | 14 個 Blizzard 介面換膚 |
| **設定** | LunarUI_Options | AceConfig 設定介面（LoadOnDemand） |

---

## 技術棧

| 依賴 | 用途 |
|------|------|
| Ace3 | Addon 框架、事件、計時器、資料庫、設定 |
| oUF | UnitFrames / Nameplates 引擎 |
| LibActionButton-1.0 | 動作條按鈕 |
| LibSharedMedia-3.0 | 字體 / 材質註冊 |

---

## 安裝

```bash
git clone https://github.com/Neal75418/lunar-ui.git
cd lunar-ui && ./scripts/update-libs.sh
cp -r LunarUI LunarUI_Options "/path/to/World of Warcraft/_retail_/Interface/AddOns/"
```

---

## 指令

`/lunar` 或 `/lui`

| 指令 | 說明 |
|------|------|
| `config` | 開啟設定面板 |
| `install` | 重新執行安裝精靈 |
| `status` | 版本、Phase、Tokens |
| `move` | 框架拖曳模式 |
| `keybind` | 按鍵綁定模式 |
| `reset [all]` | 重置框架位置 |
| `on` / `off` | 啟用 / 停用 |
| `export` / `import` | 匯出 / 匯入設定 |
| `debug` | 除錯模式 |
| `phase [名稱]` | 查看 / 切換 Phase |
| `test combat\|phases` | 模擬測試 |

---

## Phase 狀態模型

所有 UI 行為由 Phase 狀態機驅動 — 控制「誰有顯示權」，不是切換畫面。

| Phase | 情境 | UI 行為 |
|-------|------|---------|
| NEW | 非戰鬥 / 探索 | 低存在感、退到背景 |
| WAXING | 準備進入戰鬥 | 注意力收斂、關鍵資訊浮出 |
| FULL | 戰鬥中 | 高可讀性、穩定、聚焦 |
| WANING | 戰後過渡 | 緩慢退場、回顧、收尾 |

> Phase 架構已完成，視覺過渡尚未啟用，目前固定運行於 FULL。

---

## 里程碑

| 版本 | 內容 | 狀態 |
|------|------|------|
| 0.1 | LunarCore + Phase 系統 | 完成 |
| 0.2 | UnitFrames | 完成 |
| 0.3 | Nameplates | 完成 |
| 0.4 | ActionBars | 完成 |
| 0.5 | 非戰鬥介面 | 完成 |
| 0.6 | 視覺主題 | 完成 |
| 0.7 | 設定系統 | 完成 |
| 0.8 | 穩定性與 12.0 相容性 | 完成 |
| 1.0 | 完整風格套件 | 進行中 |

---

## License

GPL-3.0 — [LICENSE](LICENSE)

## Author

NealChen
