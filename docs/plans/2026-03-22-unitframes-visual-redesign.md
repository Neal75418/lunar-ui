# UnitFrames Visual Redesign

## Goal

ElvUI-inspired flat style, with class colors and compact proportions.

## Size

| Frame | Old | New | Health + Power |
|---|---|---|---|
| player | 220x45 | 220x26 | 20 + 6 |
| target | 220x45 | 220x26 | 20 + 6 |
| focus | 180x35 | 180x22 | 16 + 6 |
| pet | 120x25 | 120x16 | 16 + 0 |
| targettarget | 120x25 | 120x16 | 16 + 0 |
| boss | 180x40 | 180x24 | 18 + 6 |
| party | 150x35 | 150x22 | 16 + 6 |
| raid | 80x30 | 80x20 | 16 + 4 |

- Castbar: 16px -> 12px
- pet/targettarget: no power bar
- raid power bar: 4px (thinner)

## Class Colors

All player frames use class colors. Priority (oUF built-in):

```
disconnect > tapping > class > reaction
```

Settings on all Health elements:

```lua
health.colorClass = true
health.colorReaction = true
health.colorTapping = true
health.colorDisconnected = true
```

## Text Layout

```
Player:
+--------------------------------------+
| Name                            95%  | 20px health
+--------------------------------------+
| power bar                            | 6px power
+--------------------------------------+

Target:
+--------------------------------------+
| 80 TargetName                   95%  | 20px health
+--------------------------------------+
| power bar                            | 6px power
+--------------------------------------+
```

- Name: left-aligned, 11px OUTLINE
- HP%: right-aligned, 11px OUTLINE
- Level: target/focus/boss only (prepended to name)
- Power bar: no text
- focus/boss/party: 10px font
- raid/pet/targettarget: 9px font, no HP%

## Visual Style

- 1px thin border, dark gray (0.15, 0.12, 0.08)
- Flat, no shadow, no gradient, no rounded corners
- Health/power use same bar texture (user-selectable)
- Background: same texture darkened (BG_DARKEN = 0.3)

## Files to Modify

- `LunarUI/Core/Defaults.lua` — height/width defaults
- `LunarUI/UnitFrames/Layout.lua` — health/power sizing, colorClass, text layout
- `spec/layout_spec.lua` — update tests if needed
