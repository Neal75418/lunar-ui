# Changelog

All notable changes to LunarUI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Custom moon phase textures (hand-drawn)
- Custom fonts

---

## [0.8.0] - 2026-02-07

### Added
- **HUD 戰鬥模組**
  - `HUD/PerformanceMonitor.lua` — FPS、延遲、記憶體即時顯示
  - `HUD/ClassResources.lua` — 職業資源條（連擊點、符文等）
  - `HUD/CooldownTracker.lua` — 技能冷卻追蹤
  - `HUD/AuraFrames.lua` — Buff/Debuff 顯示框架（含計時條）
- **Skins 模組** — 14 個 Blizzard 介面皮膚（角色、法術書、天賦、任務、商人、社群等）
- **DataBars 模組** — 經驗值、榮譽、神器能量進度條
- **DataTexts 模組** — 可自訂的文字資訊覆蓋層
- **Loot 模組** — 拾取框架美化
- **Automation 模組** — 自動賣灰色物品、自動郵件
- **Configuration Import/Export** (`Core/Serialization.lua`) — 設定檔字串序列化與反序列化
- **Layout Presets** (`Core/Presets.lua`) — DPS/Tank/Healer 佈局預設

### Changed
- Phase 系統簡化：移除月相循環機制，保留戰鬥狀態驅動
- 提取 `Core/Utils.lua` 共用工具函數（SafeCall、StripTextures、SkinStandardFrame 等）
- 提取 `ActionBars/HideBlizzardBars.lua` 為獨立模組
- Tooltip 掃描改用 `GetTooltipData()` 結構化 API（保留 _G fallback）
- Communities ScrollBar 皮膚新增 ScrollBox 分支（WoW 12.0）
- HUD 框架從硬編碼列表改為 `RegisterHUDFrame()` 自動註冊
- 所有模組新增 `onDisable` cleanup 函數
- Skin 系統重構：所有 skin 檔案新增 nil guard 防護

### Fixed
- **WoW 12.0 相容性**（10 項）
  - `HideBlizzardBars.lua` — `bar.SetScale` 改用 `hooksecurefunc` 防止 taint
  - `Chat.lua` — `ChatFrame_OnHyperlinkShow` 改用 per-frame `HookScript`
  - `ActionBars.lua` — `EnterKeybindMode` / `StyleExtraActionButton` / `StyleZoneAbilityButton` 加入 `InCombatLockdown()` 防護
  - `Nameplates.lua` — `UpdateNameplateStacking` 加入戰鬥鎖定檢查
  - `AuraFrames.lua` — 移除已棄用的 `CancelUnitBuff` fallback
  - `Bags.lua` — `SetHyperlink` 加入 pcall 保護
  - `Chat.lua` — Tooltip 方法統一 pcall 包裹
- **Code Smell 修復**（40 項）
  - 死代碼移除、重複函數合併、硬編碼顏色提取為常數
  - Temporal coupling 修復、magic number 命名
  - 36 個邏輯錯誤修復（四輪代碼審查）
- **Skins 黑底黑字問題**修復並啟用 Skins 模組
- **FrameMover** runtime error 修復
- **Commands.lua** 本地化 fallback 改為英文
- **Serialization** 負號邊界修復

### Performance
- `ActionBars.lua` — 快取 fadeDuration，避免每幀查詢 DB（O1）
- `Layout.lua` — deathUnitMap 反向映射 + 惰性重建，UNIT_HEALTH O(1) 查詢（O2）
- `Tooltip.lua` — Inspect cache 雙次迭代合併為單次（O3）
- `AuraFrames.lua` — GetTimerBarColor nil 防護（O4）

---

## [0.7.0] - 2026-01-28

### Added
- **Installation Wizard** (`Core/InstallWizard.lua`)
  - 4-step setup guide (UI Scale, Layout, ActionBar, Summary)
  - Layout presets (DPS/Tank/Healer)
  - Triggered via `/lunar install`

- **LunarUI_Options**: Complete configuration GUI
  - General settings (enable/debug/Phase system)
  - Phase token adjustments (alpha/scale per phase)
  - UnitFrames configuration (position, size, elements)
  - ActionBars configuration (bar toggles, button count/size)
  - Nameplates configuration (enemy/friendly, threat, highlights)
  - Minimap/Bags/Chat/Tooltip settings
  - Visual style settings (theme, border style, glow effects)
  - Profile management via AceDBOptions-3.0

### Changed
- Main addon now loads AceConfig libraries for Options support
- `/lunar config` command now opens the full configuration panel

---

## [0.6.0] - 2026-01-28

### Added
- **Media System** (`Media/Media.lua`)
  - LibSharedMedia-3.0 registration for textures, borders, fonts
  - Lunar color palette with phase-specific colors
  - Backdrop templates for consistent styling
  - Texture/font getter functions with fallback support

- **Phase Glow Effects** (`Effects/PhaseGlow.lua`)
  - Moonlight glow during FULL phase
  - Pulse animation with configurable speed
  - Three glow types: simple, corner, edge
  - Optional screen moonlight overlay

- **Enhanced Phase Indicator**
  - Moon icons change per phase (NEW/WAXING/FULL/WANING)
  - Pulse animation during FULL phase
  - WANING countdown timer display
  - Shift+drag repositioning

### Changed
- Config.lua expanded with style options (moonlightOverlay, phaseGlow, animations)

---

## [0.5.0] - 2026-01-28

### Added
- **Minimap Module** (`Modules/Minimap.lua`)
  - Unified Lunar style border
  - Coordinate display
  - Zone text with PvP colors
  - Clock, mail indicator, difficulty indicator
  - Button organization
  - Phase-aware alpha

- **Tooltip Module** (`Modules/Tooltip.lua`)
  - Unified border style
  - Class/reaction colored borders
  - Item level display
  - Spell/Item ID display (optional)
  - Target of target display

- **Chat Module** (`Modules/Chat.lua`)
  - Styled chat frames with hover backdrop
  - Improved channel colors
  - Class-colored player names
  - Mouse wheel scrolling

- **Bags Module** (`Modules/Bags.lua`)
  - All-in-one bag display
  - Item level on equipment
  - Junk/Quest item indicators
  - Search functionality
  - Auto-sell junk at vendors

---

## [0.4.0] - 2026-01-27

### Added
- **ActionBars Module** (`ActionBars/ActionBars.lua`)
  - LibActionButton-1.0 integration
  - Main action bars (1-6)
  - Pet bar and Stance bar
  - Phase-aware alpha fading
  - Keybind mode (hover + press key)
  - Cooldown display
  - Hides Blizzard default action bars

---

## [0.3.0] - 2026-01-27

### Added
- **Nameplates Module** (`Nameplates/Nameplates.lua`)
  - oUF nameplate integration
  - Enemy nameplates (health, castbar, debuffs)
  - Friendly nameplates (simplified)
  - Phase-aware alpha fading
  - Important target highlighting (rare, elite, boss)
  - Target indicator and threat colors

---

## [0.2.0] - 2026-01-27

### Added
- **Complete UnitFrames** (`UnitFrames/Layout.lua`)
  - Player frame (health, power, experience, rested)
  - Target frame (health, power, castbar, classification)
  - Focus frame
  - Pet frame
  - TargetTarget frame
  - Party frames (oUF:SpawnHeader, 5-man)
  - Raid frames (oUF:SpawnHeader, 10/20/40)
  - Boss frames (1-8)

- **Core Elements**
  - Castbar for Player/Target/Focus
  - Auras with smart filtering
  - Threat indicator
  - Range fading
  - Combat indicator

### Changed
- All frames respond to Phase changes (alpha/scale)
- Global Phase callback optimization

---

## [0.1.0] - 2026-01-27

### Added
- **LunarCore**: Phase-driven state machine
  - Four phases: NEW, WAXING, FULL, WANING
  - Combat event binding (PLAYER_REGEN_DISABLED/ENABLED)
  - 10-second delayed return to NEW after combat

- **Token System**
  - Design tokens per phase (alpha, scale, contrast, glowIntensity)
  - Configurable via AceDB

- **Commands** (`/lunar`)
  - toggle, phase, waxing, debug, status, config, reset, test

- **Debug Overlay**
  - Shows current phase, tokens, timer, combat status

- **Phase Indicator HUD**
  - Visual moon phase indicator
  - Click to cycle phases (debug)

- **Localization**
  - English (enUS)
  - Traditional Chinese (zhTW)

- **Basic UnitFrames Skeleton**
  - Player and Target frame foundation

---

## Version History Summary

| Version | Milestone | Description                                  |
|---------|-----------|----------------------------------------------|
| 0.8.0   | M8        | Stability & WoW 12.0 Compatibility           |
| 0.7.0   | M7        | Configuration System (LunarUI_Options)       |
| 0.6.0   | M6        | Visual Theme (Media, PhaseGlow)              |
| 0.5.0   | M5        | Non-combat UI (Minimap, Bags, Chat, Tooltip) |
| 0.4.0   | M4        | ActionBars                                   |
| 0.3.0   | M3        | Nameplates                                   |
| 0.2.0   | M2        | Complete UnitFrames                          |
| 0.1.0   | M1        | LunarCore + Phase System                     |

---

[Unreleased]: https://github.com/Neal75418/lunar-ui/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/Neal75418/lunar-ui/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/Neal75418/lunar-ui/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Neal75418/lunar-ui/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Neal75418/lunar-ui/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Neal75418/lunar-ui/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Neal75418/lunar-ui/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Neal75418/lunar-ui/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Neal75418/lunar-ui/releases/tag/v0.1.0
