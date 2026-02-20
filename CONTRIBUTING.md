# Contributing to LunarUI

## Development Setup

```bash
git clone https://github.com/Neal75418/lunar-ui.git
cd lunar-ui
./scripts/update-libs.sh
```

Symlink 到 WoW AddOns 目錄：

```bash
ln -s $(pwd)/LunarUI "/path/to/World of Warcraft/_retail_/Interface/AddOns/LunarUI"
ln -s $(pwd)/LunarUI_Options "/path/to/World of Warcraft/_retail_/Interface/AddOns/LunarUI_Options"
```

## Code Style

- **語言**：Lua 5.1（LuaJIT），WoW 12.0.1（Interface: 120001）
- **縮排**：4 spaces
- **行寬**：無限制
- **命名**：
  - 全域函數：`LunarUI.FunctionName` 或 `LunarUI:MethodName`
  - 區域函數：`camelCase`
  - 常數表：`UPPER_SNAKE_CASE`
  - 未使用變數：加 `_` 前綴（如 `_self`, `_event`）
- **註解語言**：繁體中文

## Linting

專案使用 [luacheck](https://github.com/mpeterv/luacheck) 進行靜態分析。

```bash
# 安裝
luarocks install luacheck

# 執行（自動讀取 .luacheckrc）
luacheck .
```

CI 要求零警告。提交前請確認 `luacheck .` 通過。

## Architecture

### TOC 載入順序

```
Libs → Locales → Core（Init→Tokens→Defaults→Config→Utils→...）
→ Media → UnitFrames → Nameplates → ActionBars
→ HUD → Modules → Skins
```

### Module 註冊

所有模組透過 `LunarUI:RegisterModule(name, initFunc)` 註冊，在 `PLAYER_ENTERING_WORLD` 時初始化。

### Taint 規避

WoW 的安全框架有嚴格的 taint 機制。修改暴雪框架時：

- 使用 `hooksecurefunc` 而非直接覆寫
- 戰鬥中不修改框架（`InCombatLockdown()` 檢查）
- 使用 `pcall` 包裹對暴雪框架的存取
- 不使用 `rawset` 或 `RegisterStateDriver` 修改安全框架

### Skin 模組

新增 Skin 的模式：

```lua
local function SkinMyFrame()
    local frame = LunarUI:SkinStandardFrame("MyFrameName", { textDepth = 3 })
    if not frame then return end
    -- ... 自訂邏輯
    return true
end

-- 對於延遲載入 addon：
LunarUI.RegisterSkin("myframe", "Blizzard_MyAddon", SkinMyFrame)

-- 對於 PLAYER_ENTERING_WORLD 時已存在的框架：
LunarUI.RegisterSkin("myframe", "PLAYER_ENTERING_WORLD", SkinMyFrame)
```

## Commit Convention

使用 [Conventional Commits](https://www.conventionalcommits.org/)：

```
feat: 新增功能
fix: 修正錯誤
refactor: 重構（不改變行為）
style: 格式調整
perf: 效能改善
docs: 文件更新
chore: 維護任務
ci: CI/CD 變更
```

## Pull Request

1. Fork 後建立 feature branch
2. 確認 `luacheck .` 零警告
3. 在遊戲內測試（至少載入 + 基本操作）
4. 提交 PR 並說明變更內容

## License

貢獻的程式碼將以 [GPL-3.0](LICENSE) 授權釋出。
