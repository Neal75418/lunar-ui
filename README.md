# Lunar UI

**Phase-driven World of Warcraft UI system for WoW 12.0**

以 Phase（月相狀態）為核心的完整介面系統，統一戰鬥與非戰鬥體驗。
長時間遊玩下來「不累、不吵、不分心」。

---

## Phase 狀態模型

所有 UI 行為由 Phase 狀態機驅動 — 控制的是「誰有顯示權」，不是切換畫面。

| Phase      | 情境       | UI 行為        |
|------------|----------|--------------|
| **NEW**    | 非戰鬥 / 探索 | 低存在感、退到背景    |
| **WAXING** | 準備進入戰鬥   | 注意力收斂、關鍵資訊浮出 |
| **FULL**   | 戰鬥中      | 高可讀性、穩定、聚焦   |
| **WANING** | 戰後過渡     | 緩慢退場、回顧、收尾   |

> Phase 架構已完成，視覺過渡尚未啟用，目前固定運行於 FULL。

---

## 模組總覽

**戰鬥核心**
- UnitFrames（oUF） — Player / Target / Focus / Pet / Party / Raid / Boss / TargetTarget
- Nameplates — oUF 名牌
- ActionBars — LibActionButton 動作條
- AuraFrames — Buff / Debuff 框架
- ClassResources — 職業資源條（連擊點、聖能等）
- CooldownTracker — 冷卻追蹤
- FloatingCombatText — 浮動戰鬥文字

**HUD / 輔助**
- PhaseIndicator — 月相圖示
- PhaseGlow — 月光特效
- PerformanceMonitor — FPS / 延遲

**非戰鬥介面**
- Minimap、Bags、Chat、Tooltip、DataBars、DataTexts、FrameMover
- Skins — Blizzard 原生介面換膚（12 個面板）

**設定**
- LunarUI_Options — AceConfig 設定介面（獨立 Addon，LoadOnDemand）

---

## 技術棧

- **Ace3** — Addon 框架、事件、計時器、資料庫、設定介面
- **oUF** — UnitFrames / Nameplates 引擎
- **LibActionButton-1.0** — 動作條
- **LibSharedMedia-3.0** — 字體 / 材質

---

## 安裝

```bash
git clone https://github.com/Neal75418/lunar-ui.git
cd lunar-ui
./scripts/update-libs.sh

cp -r LunarUI LunarUI_Options "/path/to/World of Warcraft/_retail_/Interface/AddOns/"
```

## 指令

| 指令                           | 說明              |
|------------------------------|-----------------|
| `/lunar`                     | 顯示說明            |
| `/lunar config`              | 開啟設定面板          |
| `/lunar status`              | 版本、Phase、Tokens |
| `/lunar move`                | 框架拖曳模式          |
| `/lunar reset [all]`         | 重置框架位置          |
| `/lunar on` / `off`          | 啟用 / 停用         |
| `/lunar debug`               | 除錯模式            |
| `/lunar phase [名稱]`          | 查看 / 切換 Phase   |
| `/lunar test combat\|phases` | 模擬測試            |

別名：`/lui`

---

## 里程碑

| 版本   | 內容                   | 狀態  |
|------|----------------------|-----|
| v0.1 | LunarCore + Phase 系統 | 完成  |
| v0.2 | UnitFrames           | 完成  |
| v0.3 | Nameplates           | 完成  |
| v0.4 | ActionBars           | 完成  |
| v0.5 | 非戰鬥介面                | 完成  |
| v0.6 | 視覺主題                 | 完成  |
| v0.7 | 設定系統                 | 完成  |
| v1.0 | 完整風格套件               | 進行中 |

---

## License

GPL-3.0 — 詳見 [LICENSE](LICENSE)

## Author

NealChen
