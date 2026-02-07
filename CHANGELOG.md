# Changelog

All notable changes to LunarUI will be documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) &middot; Versioning: [SemVer](https://semver.org/spec/v2.0.0.html)

---

## [Unreleased]

### Planned

- Custom moon phase textures (hand-drawn)

---

## [0.9.0] &mdash; 2026-02-07

### Added

- **自定義字體** &mdash; Options 新增 LSM 字體選擇器，即時切換所有 UI 文字字體
  - `LunarUI.SetFont(fs, size, flags)` &mdash; 統一字體設定 + 自動註冊
  - `LunarUI:ApplyFontSettings()` &mdash; 批次更新已註冊 FontString
  - Weak table `fontRegistry` 避免記憶體洩漏
- **FloatingCombatText** (`HUD/FloatingCombatText.lua`)
  - 輸出傷害 / 受到傷害 / 治療量浮動顯示
  - 暴擊放大 + 白色高亮
  - 向上飄動 + 淡出動畫（OutQuad / InQuad easing）
  - 框架池回收機制（20 個預建 FontString，避免 GC）
  - Options 完整設定（啟用、類別過濾、字體大小、暴擊倍數、動畫時長）

### Changed

- 18 個檔案（86 處）的 `STANDARD_TEXT_FONT` 硬編碼改為 `LunarUI.SetFont()` 動態字體

---

## [0.8.0] &mdash; 2026-02-07

### Added

- **HUD 戰鬥模組**
  - `HUD/PerformanceMonitor.lua` &mdash; FPS、延遲、記憶體即時顯示
  - `HUD/ClassResources.lua` &mdash; 職業資源條（連擊點、符文等）
  - `HUD/CooldownTracker.lua` &mdash; 技能冷卻追蹤
  - `HUD/AuraFrames.lua` &mdash; Buff / Debuff 顯示框架（含計時條）
- **Skins** &mdash; 14 個 Blizzard 介面皮膚（角色、法術書、天賦、任務、商人、社群等）
- **DataBars** &mdash; 經驗值、榮譽、神器能量進度條
- **DataTexts** &mdash; 可自訂的文字資訊覆蓋層
- **Loot** &mdash; 拾取框架美化
- **Automation** &mdash; 自動賣灰色物品、自動郵件
- **Configuration Import / Export** (`Core/Serialization.lua`)
- **Layout Presets** (`Core/Presets.lua`) &mdash; DPS / Tank / Healer 佈局預設

### Changed

- Phase 系統簡化：移除月相循環機制，保留戰鬥狀態驅動
- 提取 `Core/Utils.lua` 共用工具函數（SafeCall、StripTextures、SkinStandardFrame）
- 提取 `ActionBars/HideBlizzardBars.lua` 為獨立模組
- Tooltip 掃描改用 `GetTooltipData()` 結構化 API（保留 `_G` fallback）
- Communities ScrollBar 皮膚新增 ScrollBox 分支（WoW 12.0）
- HUD 框架從硬編碼列表改為 `RegisterHUDFrame()` 自動註冊
- 所有模組新增 `onDisable` cleanup 函數
- Skin 系統重構：所有 skin 檔案新增 nil guard 防護

### Fixed

- **WoW 12.0 相容性**（10 項）
  - `HideBlizzardBars` &mdash; `bar.SetScale` 改用 `hooksecurefunc` 防止 taint
  - `Chat` &mdash; `ChatFrame_OnHyperlinkShow` 改用 per-frame `HookScript`
  - `ActionBars` &mdash; `EnterKeybindMode` / `StyleExtraActionButton` / `StyleZoneAbilityButton` 加入 `InCombatLockdown()` 防護
  - `Nameplates` &mdash; `UpdateNameplateStacking` 加入戰鬥鎖定檢查
  - `AuraFrames` &mdash; 移除已棄用的 `CancelUnitBuff` fallback
  - `Bags` &mdash; `SetHyperlink` 加入 pcall 保護
  - `Chat` &mdash; Tooltip 方法統一 pcall 包裹
- **Code Smell**（40 項）
  - 死代碼移除、重複函數合併、硬編碼顏色提取為常數
  - Temporal coupling 修復、magic number 命名
  - 36 個邏輯錯誤修復（四輪代碼審查）
- Skins 黑底黑字問題修復並啟用 Skins 模組
- FrameMover runtime error 修復
- Commands 本地化 fallback 改為英文
- Serialization 負號邊界修復

### Performance

- `ActionBars` &mdash; 快取 `fadeDuration`，避免每幀查詢 DB
- `Layout` &mdash; `deathUnitMap` 反向映射 + 惰性重建，`UNIT_HEALTH` O(1) 查詢
- `Tooltip` &mdash; Inspect cache 雙次迭代合併為單次
- `AuraFrames` &mdash; `GetTimerBarColor` nil 防護

---

## [0.7.0] &mdash; 2026-01-28

### Added

- **Installation Wizard** (`Core/InstallWizard.lua`)
  - 4-step setup guide（UI Scale → Layout → ActionBar → Summary）
  - Layout presets（DPS / Tank / Healer）
  - 透過 `/lunar install` 觸發
- **LunarUI_Options** &mdash; 完整設定 GUI
  - General / Phase / UnitFrames / ActionBars / Nameplates
  - Minimap / Bags / Chat / Tooltip / Visual Style
  - Profile management（AceDBOptions-3.0）

### Changed

- 主體 Addon 載入 AceConfig 支援 Options
- `/lunar config` 開啟完整設定面板

---

## [0.6.0] &mdash; 2026-01-28

### Added

- **Media System** (`Media/Media.lua`)
  - LibSharedMedia-3.0 註冊（材質、邊框、字體）
  - Lunar 色票 + Phase 專用色彩
  - Backdrop 模板 + 材質 / 字體 getter
- **Phase Glow Effects** (`Effects/PhaseGlow.lua`)
  - Moonlight glow（FULL phase）
  - Pulse 動畫 + 三種 glow 類型（simple / corner / edge）
  - 可選螢幕 moonlight overlay
- **Enhanced Phase Indicator**
  - 月亮圖示隨 Phase 切換
  - FULL pulse + WANING countdown
  - Shift+drag 重新定位

### Changed

- `Config.lua` 擴充 style options（moonlightOverlay / phaseGlow / animations）

---

## [0.5.0] &mdash; 2026-01-28

### Added

- **Minimap** &mdash; Lunar 邊框、座標、區域文字、PvP 色、時鐘、按鈕整理、Phase alpha
- **Tooltip** &mdash; 統一邊框、職業 / 陣營色、裝等、Spell / Item ID、目標的目標
- **Chat** &mdash; 懸浮背景、頻道色、職業色名字、滑鼠滾輪
- **Bags** &mdash; 整合背包、裝等、垃圾 / 任務標記、搜尋、自動賣灰

---

## [0.4.0] &mdash; 2026-01-27

### Added

- **ActionBars** &mdash; LibActionButton-1.0 整合
  - 主動作條 1-6 + 寵物 + 姿態
  - Phase alpha 淡入淡出 + 按鍵綁定 + 冷卻顯示
  - 隱藏 Blizzard 預設動作條

---

## [0.3.0] &mdash; 2026-01-27

### Added

- **Nameplates** &mdash; oUF 名牌整合
  - 敵方名牌（血量、施法條、Debuff）+ 友方名牌（簡化）
  - Phase alpha + 重要目標高亮 + 威脅色

---

## [0.2.0] &mdash; 2026-01-27

### Added

- **UnitFrames** &mdash; 完整 oUF Layout
  - Player / Target / Focus / Pet / TargetTarget
  - Party（SpawnHeader, 5人）/ Raid（10 / 20 / 40）/ Boss（1-8）
  - Castbar / Auras / 威脅指示器 / 距離淡出 / 戰鬥指示器

### Changed

- 所有框架回應 Phase 變化（alpha / scale）
- 全域 Phase callback 效能優化

---

## [0.1.0] &mdash; 2026-01-27

### Added

- **LunarCore** &mdash; Phase 狀態機（NEW → WAXING → FULL → WANING）
- **Token System** &mdash; 每 Phase 的 design tokens（alpha / scale / contrast / glowIntensity）
- **Commands** (`/lunar`) &mdash; toggle / phase / debug / status / config / reset / test
- **Debug Overlay** &mdash; Phase、Tokens、Timer、戰鬥狀態
- **Phase Indicator HUD** &mdash; 月相視覺指示器
- **Localization** &mdash; enUS + zhTW
- **UnitFrames Skeleton** &mdash; Player / Target 基礎框架

---

<!-- Link references -->
[Unreleased]: https://github.com/Neal75418/lunar-ui/compare/v0.9.0...HEAD
[0.9.0]: https://github.com/Neal75418/lunar-ui/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/Neal75418/lunar-ui/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/Neal75418/lunar-ui/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Neal75418/lunar-ui/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Neal75418/lunar-ui/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Neal75418/lunar-ui/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Neal75418/lunar-ui/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Neal75418/lunar-ui/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Neal75418/lunar-ui/releases/tag/v0.1.0
