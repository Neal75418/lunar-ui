# Changelog

All notable changes to LunarUI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Configuration import/export (string serialization)
- Installation wizard for first-time setup
- Custom moon phase textures (hand-drawn)
- Custom fonts

---

## [0.7.0] - 2026-01-28

### Added
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

| Version | Milestone | Description |
|---------|-----------|-------------|
| 0.7.0 | M7 | Configuration System (LunarUI_Options) |
| 0.6.0 | M6 | Visual Theme (Media, PhaseGlow) |
| 0.5.0 | M5 | Non-combat UI (Minimap, Bags, Chat, Tooltip) |
| 0.4.0 | M4 | ActionBars |
| 0.3.0 | M3 | Nameplates |
| 0.2.0 | M2 | Complete UnitFrames |
| 0.1.0 | M1 | LunarCore + Phase System |

---

[Unreleased]: https://github.com/Neal75418/lunar-ui/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/Neal75418/lunar-ui/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Neal75418/lunar-ui/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Neal75418/lunar-ui/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Neal75418/lunar-ui/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Neal75418/lunar-ui/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Neal75418/lunar-ui/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Neal75418/lunar-ui/releases/tag/v0.1.0
