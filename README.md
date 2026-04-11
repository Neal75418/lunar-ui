<p align="center">
  <img src="https://img.shields.io/github/actions/workflow/status/Neal75418/lunar-ui/build.yml?branch=main&style=flat-square&label=build" alt="Build" />
  <img src="https://img.shields.io/badge/tests-passing-brightgreen?style=flat-square" alt="Tests" />
  <img src="https://img.shields.io/badge/WoW-12.0.1-0074e0?style=flat-square&logo=battledotnet&logoColor=white" alt="WoW 12.0.1" />
  <img src="https://img.shields.io/badge/Lua-5.1-2C2D72?style=flat-square&logo=lua&logoColor=white" alt="Lua 5.1" />
  <img src="https://img.shields.io/badge/skins-23-e67e22?style=flat-square" alt="23 Skins" />
  <img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="GPL-3.0" />
</p>

<h1 align="center">🌙 LunarUI</h1>

<p align="center">
  <strong>低存在感、不干擾、長時間遊玩不累。</strong><br/>
  World of Warcraft 12.0 完整 UI 替換插件。
</p>

<p align="center">
  <a href="#特色">特色</a> ·
  <a href="#安裝">安裝</a> ·
  <a href="#指令">指令</a> ·
  <a href="#相容性">相容性</a> ·
  <a href="#故障排除">故障排除</a> ·
  <a href="#開發">開發</a>
</p>

## 特色

- **完整戰鬥 UI** — UnitFrames / Nameplates / ActionBars / AuraFrames / ClassResources / CooldownTracker / FloatingCombatText（基於 oUF + LibActionButton）
- **23 個 Blizzard 換膚** — 角色、天賦、任務、拍賣、郵件、收藏、公會、成就等原生介面統一深色主題
- **整合模組** — Minimap、Bags（裝等 / 搜尋 / 自動賣灰）、Chat、Tooltip、DataBars、DataTexts、Loot、Automation、FrameMover
- **Phase 狀態機** — 戰鬥前後自動調整顯示策略
- **完整可配置** — AceConfig GUI、設定匯入匯出、DPS / Tank / Healer 佈局預設
- **效能優先** — 框架池回收、材質快取、髒旗標批次處理

> 附帶兩個 LoadOnDemand 插件：`LunarUI_Options`（設定介面）與 `LunarUI_Debug`（Vigor 診斷工具），分別在 `/lunar config` 和 `/lunar debugvigor` 時自動載入。

## 安裝

```bash
# 1. Clone 並安裝依賴庫
git clone https://github.com/Neal75418/lunar-ui.git
cd lunar-ui && ./scripts/update-libs.sh

# 2. 複製到 AddOns 目錄
ADDONS="/path/to/World of Warcraft/_retail_/Interface/AddOns"
cp -r LunarUI LunarUI_Options LunarUI_Debug "$ADDONS/"
```

<details>
<summary><strong>使用 Symlink（開發用途）</strong></summary>

```bash
ADDONS="/path/to/World of Warcraft/_retail_/Interface/AddOns"
ln -s "$(pwd)/LunarUI" "$ADDONS/LunarUI"
ln -s "$(pwd)/LunarUI_Options" "$ADDONS/LunarUI_Options"
ln -s "$(pwd)/LunarUI_Debug" "$ADDONS/LunarUI_Debug"
```

</details>

## 指令

`/lunar` 或 `/lui`

| 指令 | 說明 |
|:---|:---|
| `/lunar config` | 開啟設定面板 |
| `/lunar install` | 重新執行安裝精靈 |
| `/lunar move` | 框架拖曳模式 |
| `/lunar keybind` | 按鍵綁定模式 |
| `/lunar reset [all]` | 重置框架位置 |
| `/lunar toggle` / `on` / `off` | 切換 / 啟用 / 停用 |

> 其他命令（`status`、`export`、`import`、`debug`、`profile`、`debugvigor`）輸入 `/lunar` 查看完整列表。

## 相容性

- **WoW 12.0.1**（The War Within，Interface 120001）
- **語言**：English、繁體中文
- **衝突插件**：不建議與其他完整 UI 套件（ElvUI / TukUI）或功能重疊模組（Bartender、Plater、SUF、Bagnon、Prat 等）同時使用

## 依賴庫

所有第三方庫位於 `LunarUI/Libs/`，由根目錄 [.pkgmeta](.pkgmeta) 管理，不納入版本控制。

| 庫 | 版本 | 用途 |
|:---|:---|:---|
| [oUF](https://github.com/oUF-wow/oUF) | 13.1.1 | UnitFrames / Nameplates |
| [Ace3](https://github.com/WoWUIDev/Ace3) | r1390 | 框架 / 事件 / DB / 設定 |
| [LibSharedMedia-3.0](https://www.curseforge.com/wow/addons/libsharedmedia-3-0) | 11.2.1 | 材質 / 字體 |
| [LibActionButton-1.0](https://github.com/Nevcairiel/LibActionButton-1.0) | 0.57 | ActionBars |

> 更新執行 `./scripts/update-libs.sh`；若失敗參考 [.pkgmeta](.pkgmeta) 手動處理。

## 故障排除

| 問題 | 解決方式 |
|:---|:---|
| **Taint 錯誤** | LunarUI 內建 taint 過濾器，可安全忽略 |
| **插件衝突** | 停用衝突插件的對應模組 |
| **Skin 載入錯誤** | `/lunar config` → Skins → 個別停用問題 Skin |
| **重置設定** | `/lunar reset all` 或刪除 `WTF/.../LunarUI.lua` |
| **字體顯示異常** | `/lunar config` → General → 重選字體 |

## 開發

```bash
make check            # lint + format + locale-check + test（提交前必跑）
make test             # 單元測試
make coverage         # 覆蓋率 + ratchet 檢查
make coverage-update  # 提升覆蓋率後更新 baseline
make format-fix       # 自動修正格式
```

詳見 [CONTRIBUTING.md](CONTRIBUTING.md) 與 [CLAUDE.md](CLAUDE.md)。

## 授權

[GPL-3.0](LICENSE)

---

<p align="center">
  Made with 🌙 by <strong><a href="https://github.com/Neal75418">NealChen</a></strong>
</p>
