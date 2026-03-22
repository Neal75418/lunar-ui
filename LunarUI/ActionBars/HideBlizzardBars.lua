---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - 隱藏暴雪動作條
    安全隱藏暴雪預設動作條，避免 UI taint
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 隱藏暴雪動作條
--------------------------------------------------------------------------------

-- ★ 還原追蹤表（所有 mutation 都記錄在這裡，RestoreBlizzardBars 從這裡還原）
-- 每個追蹤表對應一種 mutation 類型：
--   savedBarStates  → MultiBar parent + EditMode 方法覆蓋
--   hiddenFrames    → SetAlpha(0) + EnableMouse/Keyboard(false) 的框架
--   hiddenRegions   → SetAlpha(0) 的 regions
--   explicitlyHidden→ Hide() 的 regions/子物件
--   hiddenTextures  → SetTexture(nil) + 原始材質路徑
local savedBarStates = {} -- { [frame] = { parent, onEditModeEnter, onEditModeExit } }
local hiddenFrames = {} -- { [frame] = true }
local hiddenRegions = {} -- { [region] = true }
local explicitlyHidden = {} -- { [obj] = true }
local hiddenTextures = {} -- { [texture] = originalTexturePath | false }
local hideGeneration = 0 -- 世代計數器：防止 disable 後延遲 timer 仍執行 HideBlizzardBars

--------------------------------------------------------------------------------
-- Hide 操作（一次性 mutation，不 hook，不持續修改安全框架）
--------------------------------------------------------------------------------

-- 安全隱藏框架：透明度為 0 + 禁用互動
local function HideFrameSafely(frame)
    if not frame then
        return
    end
    hiddenFrames[frame] = true
    pcall(function()
        frame:SetAlpha(0)
        frame:EnableMouse(false)
        frame:EnableKeyboard(false)
    end)
end

-- 隱藏框架的所有區域（材質 alpha）
local function HideFrameRegions(frame)
    if not frame then
        return
    end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.SetAlpha then
            hiddenRegions[region] = true
            pcall(function()
                region:SetAlpha(0)
            end)
        end
    end
end

-- 強力隱藏材質：透明 + 隱藏 + 清除材質路徑（儲存原始路徑供還原）
local function HideTextureForcefully(texture)
    if not texture then
        return
    end
    -- 只在首次隱藏時儲存原始狀態（延遲重試會多次呼叫）
    if hiddenTextures[texture] == nil then
        local path = texture:GetTexture()
        hiddenTextures[texture] = path or false -- false = 原本就沒有材質
    end
    pcall(function()
        texture:SetAlpha(0)
        texture:Hide()
        texture:SetTexture(nil)
    end)
end

-- 不應被隱藏的框架白名單（encounter / boss 技能條相關）
-- 注意：WoW 12.0 已移除 Vigor Bar（飛龍能量條），Skyriding 改用固定充能機制
-- EncounterBar / PlayerPowerBarAlt 仍用於 boss encounter 技能條等場景
local VIGOR_PROTECTED_FRAMES = {
    ["PlayerPowerBarAlt"] = true,
    ["UIWidgetPowerBarContainerFrame"] = true,
    ["EncounterBar"] = true,
    ["MicroMenu"] = true, -- ActionBars 模組會重新定位微型選單按鈕
}

-- 隱藏用父框架：將 MultiBar 框架 SetParent 至此隱藏框架
-- Edit Mode 的 secureexecuterange 對 IsVisible()=false 的框架可能跳過 scale 計算
-- 此策略與 ElvUI 相同：不修改框架自身屬性（避免 taint），只透過父框架隱藏
local HiddenBarParent = CreateFrame("Frame", "LunarUIHiddenBars", UIParent)
HiddenBarParent:SetAllPoints()
HiddenBarParent:Hide()

-- MultiBar 名稱清單（Edit Mode 保護 + HideMultiActionBars 共用）
-- 這些框架不能用 SetAlpha(0) 隱藏（會導致 Edit Mode scale=0 錯誤），
-- 必須用 SetParent(HiddenBarParent) + 覆蓋 OnEditModeEnter/Exit 為 no-op
local MULTIBAR_NAMES = {
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
}

-- Edit Mode 保護查詢表（HideFrameRecursive 用，從 MULTIBAR_NAMES 生成）
local EDIT_MODE_PROTECTED_FRAMES = {}
for _, name in ipairs(MULTIBAR_NAMES) do
    EDIT_MODE_PROTECTED_FRAMES[name] = true
end

-- 遞迴隱藏框架及其所有子框架/區域
-- 回傳 true 代表此框架或其後代包含 vigor 保護框架
-- 若有保護後代，只隱藏材質不設 alpha=0（避免乘法 alpha 連帶隱藏 vigor bar）
local function HideFrameRecursive(frame)
    if not frame then
        return false
    end
    -- 跳過 OverrideActionBar，飛龍騎術等需要它
    if frame == OverrideActionBar then
        return true
    end
    -- 保護微型選單（ActionBars 模組會重新定位按鈕）
    -- MicroMenu 用物件比對（GetName() 可能為 nil），個別按鈕用名稱比對
    if _G.MicroMenu and frame == _G.MicroMenu then
        return true
    end
    local frameName = frame:GetName()
    if frameName then
        if VIGOR_PROTECTED_FRAMES[frameName] then
            return true
        end
        -- 微型按鈕（CharacterMicroButton 等）可能是 MainMenuBar 的直接子 frame
        if frameName:find("MicroButton") then
            return true
        end
    end

    -- 先遞迴子框架，判斷是否有保護後代
    -- 使用 select("#", ...) 安全遍歷，避免 ipairs 在 nil gap 中斷導致跳過 vigor 保護框架
    local hasProtectedDescendant = false
    local childCount = select("#", frame:GetChildren())
    if childCount > 0 then
        local children = { frame:GetChildren() }
        for i = 1, childCount do
            local child = children[i]
            if child and HideFrameRecursive(child) then
                hasProtectedDescendant = true
            end
        end
    end

    -- Edit Mode 保護框架：SetParent 至隱藏父框架（避免 secureexecuterange scale=0 錯誤）
    local isEditModeProtected = frameName and EDIT_MODE_PROTECTED_FRAMES[frameName]

    if isEditModeProtected then
        -- MultiBar 框架：移到隱藏父框架，不觸碰自身屬性
        pcall(function()
            frame:SetParent(HiddenBarParent)
        end)
    elseif hasProtectedDescendant then
        -- 有保護後代：只隱藏自身材質，保持 alpha=1 讓後代可見
        HideFrameRegions(frame)
        pcall(function()
            frame:EnableMouse(false)
        end)
        pcall(function()
            frame:EnableKeyboard(false)
        end)
    else
        -- 無保護後代：完全隱藏
        HideFrameSafely(frame)
        HideFrameRegions(frame)
    end

    return hasProtectedDescendant or isEditModeProtected
end

-- 以全域名稱清單批次隱藏框架
local function HideFramesByName(names, hideFunc)
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame then
            hideFunc(frame)
        end
    end
end

-- 注意：不要觸碰 EncounterBar、PlayerPowerBarAlt、UIParentBottomManagedFrameContainer！
-- 這些是安全/受管理框架，用於 boss encounter 技能條等場景。
-- 對它們呼叫 SetAlpha/EnableMouse 會產生 taint，阻止 WoW C++ 側正常管理狀態轉換。

-- Taint 副作用管理：
-- 1. "Scale must be > 0" → SetScale clamp 覆蓋從源頭攔截（不需要 error filter）
-- 2. "secret number value tainted"：
--    a. Tooltip 路徑 → Tooltip.lua 的 pcall(tooltip.Show) 從源頭捕捉
--    b. CompactUnitFrame 路徑 → 無法源頭修復（oUF 修改血條顏色，Blizzard 在 Edit Mode
--       退出的 secure context 讀回 tainted color value），必須用 error filter 抑制
-- 3. ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN → UIParent:UnregisterEvent 抑制黃字
--
-- ★ error filter 設計：
-- - 只攔截 "secret number value"（CompactUnitFrame/SecureUtil 路徑無法源頭修復）
-- - 使用 active flag 控制：active=true 時過濾，active=false 時透傳
-- - 延遲 3 秒重新安裝到 chain 頂部（確保在 BugSack 等之後）
local taintEventsUnregistered = false
local taintFilterActive = false
local taintFilterFn -- 過濾函數引用（用於辨識是否已在 chain 頂部）
local function InstallTaintErrorFilter()
    taintFilterActive = true
    -- 如果已在 chain 頂部，不重複安裝
    if taintFilterFn and geterrorhandler() == taintFilterFn then
        return
    end
    local prevHandler = geterrorhandler()
    -- 避免自我鏈接（prevHandler 是自己的舊版本）
    if prevHandler == taintFilterFn then
        prevHandler = nil
    end
    taintFilterFn = function(msg, ...)
        if taintFilterActive then
            local msgStr = tostring(msg or "")
            if msgStr:find("secret number value") then
                return
            end
        end
        if prevHandler then
            return prevHandler(msg, ...)
        end
    end
    seterrorhandler(taintFilterFn)
end

local function InstallTaintEventFilter()
    -- 抑制 "介面功能因插件而失效" 黃字訊息
    if not taintEventsUnregistered then
        taintEventsUnregistered = true
        UIParent:UnregisterEvent("ADDON_ACTION_BLOCKED")
        UIParent:UnregisterEvent("ADDON_ACTION_FORBIDDEN")
    end
    -- 立即安裝 error filter
    InstallTaintErrorFilter()
    -- 延遲 3 秒重新安裝（確保在 BugSack 等 addon 載入後仍在 chain 頂部）
    C_Timer.After(3, InstallTaintErrorFilter)
end

local function UninstallTaintEventFilter()
    taintFilterActive = false
    if taintEventsUnregistered then
        taintEventsUnregistered = false
        UIParent:RegisterEvent("ADDON_ACTION_BLOCKED")
        UIParent:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    end
end

-- 隱藏主動作條裝飾（獅鷲獸/EndCap/背景/頁碼等）
-- 微型按鈕已由 ActionBars 模組 SetParent 至自訂框架，不在 MainMenuBar 子樹中
--
-- WoW 12.0 框架結構：
--   MainMenuBar（C++ engine 框架，仍然存在）
--   MainActionBar（10.0+ 取代 MainMenuBarArtFrame）
--     ├ EndCaps.LeftEndCap / RightEndCap（取代 MainMenuBarLeftEndCap/RightEndCap）
--     ├ ActionBarPageNumber.UpButton / DownButton（取代 ActionBarUpButton/DownButton）
--     └ BorderArt（取代 MainMenuBarBackgroundArt）
--   MainMenuBarArtFrame 在 12.0 可能已不存在，但保留 fallback 避免降級
local function HideArtFrameCompletely(artFrame)
    if not artFrame then
        return
    end
    -- 1. 已知子元素（explicit list）
    local knownChildren = {
        "LeftEndCap",
        "RightEndCap",
        "PageNumber",
        "ActionBarPageNumber",
        "Background",
        "BackgroundLarge",
        "BackgroundSmall",
        "BorderArt",
        "BarArt",
    }
    for _, key in ipairs(knownChildren) do
        local child = artFrame[key]
        if child then
            HideFrameSafely(child)
            -- HideTextureForcefully 只適用於 Texture 物件（有 GetTexture 方法）
            if child.GetTexture then
                HideTextureForcefully(child)
            end
        end
    end
    -- EndCaps 容器
    if artFrame.EndCaps then
        HideFrameSafely(artFrame.EndCaps)
        if artFrame.EndCaps.LeftEndCap then
            HideTextureForcefully(artFrame.EndCaps.LeftEndCap)
        end
        if artFrame.EndCaps.RightEndCap then
            HideTextureForcefully(artFrame.EndCaps.RightEndCap)
        end
    end

    -- 2. Pattern match 掃描（捕捉未知的 EndCap/Gryphon/Art/Background 子元素）
    for key, value in pairs(artFrame) do
        if type(key) == "string" and type(value) == "table" and value.SetAlpha then
            if key:find("EndCap") or key:find("Gryphon") or key:find("Art") or key:find("Background") then
                hiddenRegions[value] = true
                pcall(value.SetAlpha, value, 0)
                if value.Hide then
                    explicitlyHidden[value] = true
                    pcall(value.Hide, value)
                end
            end
        end
    end

    -- 3. 所有 regions（材質）
    for _, region in ipairs({ artFrame:GetRegions() }) do
        if region then
            if region.SetAlpha then
                hiddenRegions[region] = true
                pcall(region.SetAlpha, region, 0)
            end
            if region.Hide then
                explicitlyHidden[region] = true
                pcall(region.Hide, region)
            end
        end
    end

    -- 4. 遞迴子框架
    local childCount = select("#", artFrame:GetChildren())
    if childCount > 0 then
        local children = { artFrame:GetChildren() }
        for i = 1, childCount do
            if children[i] then
                HideFrameRecursive(children[i])
            end
        end
    end
end

local function HideMainActionBar()
    -- MainMenuBar（C++ engine 框架）
    if MainMenuBar then
        HideFrameRecursive(MainMenuBar)
    end
    -- MainActionBar（WoW 12.0+ 裝飾框架）
    HideArtFrameCompletely(_G.MainActionBar)
    -- MainMenuBarArtFrame（pre-12.0 fallback，可能已不存在）
    HideArtFrameCompletely(MainMenuBarArtFrame)
end

-- 隱藏多重動作條、WoW 12.0 動作條、容器
-- MultiBar 框架的 Edit Mode 問題核心：
--   Edit Mode 透過 secureexecuterange(registeredSystemFrames, callOnEditModeEnter) 迭代所有已註冊的系統框架，
--   呼叫每個框架的 OnEditModeEnter()。裡面的 UpdateRightActionBarPositions 計算：
--     newScale = multiBarHeight > availableSpace and availableSpace / multiBarHeight or 1
--   當 availableSpace=0 時，scale=0 → C++ 層拋出 "Scale must be > 0"（無法用 seterrorhandler 攔截）。
-- 嘗試過的失敗策略：
-- ❌ SetAlpha(0) — 框架仍在 registeredSystemFrames 中，OnEditModeEnter 仍被呼叫
-- ❌ 替換 SetScale — taint SecureUtil "secret number" 運算
-- ❌ hooksecurefunc("seterrorhandler") — WoW 禁止 hook 此全域函數
-- ❌ SetParent(HiddenFrame) — Edit Mode 用 registeredSystemFrames 列表找框架，不看 parent
-- ✓ 覆蓋 OnEditModeEnter/OnEditModeExit 為 no-op — secureexecuterange 呼叫時什麼都不做
-- ✓ 覆蓋 SetScale 攔截負值 — UpdateRightActionBarPositions 也從 ActionBar visibility 路徑
--   被呼叫（上坐騎等），OnEditModeEnter no-op 擋不住這條路徑
local function HideMultiActionBars()
    -- 使用共用的 MULTIBAR_NAMES（與 EDIT_MODE_PROTECTED_FRAMES 同步）
    for _, barName in ipairs(MULTIBAR_NAMES) do
        local bar = _G[barName]
        if bar then
            -- 儲存原始狀態（供還原）
            if not savedBarStates[bar] then
                savedBarStates[bar] = {
                    parent = bar:GetParent(),
                    onEditModeEnter = bar.OnEditModeEnter,
                    onEditModeExit = bar.OnEditModeExit,
                    setScale = rawget(bar, "SetScale"), -- nil = 使用 metatable 的 C 方法
                }
            end
            -- 1. 移到隱藏父框架：視覺上隱藏（由父框架 Hide() 使其不可見）
            pcall(function()
                bar:SetParent(HiddenBarParent)
            end)
            -- 2. 中和 Edit Mode：覆蓋為 no-op，防止 scale 計算
            bar.OnEditModeEnter = function() end
            bar.OnEditModeExit = function() end
            -- 3. 攔截負值 SetScale：UpdateRightActionBarPositions 在多條路徑被呼叫
            --    （Edit Mode 進入、上坐騎 visibility 變化等），隱藏後 availableSpace
            --    可能為負 → newScale < 0 → C++ 層拋出 "Scale must be > 0"
            bar.SetScale = function(self, scale)
                if scale and scale > 0 then
                    -- 呼叫 C 方法（繞過我們的 Lua 覆蓋）
                    getmetatable(self).__index.SetScale(self, scale)
                end
            end
        end
    end

    -- WoW TWW: 動作條容器系統（ActionBar1-8 只是 Edit Mode display name，不是 frame name）
    for i = 1, 12 do
        local container = _G["MainActionBarButtonContainer" .. i]
        if container then
            HideFrameRecursive(container)
        end
    end

    HideFramesByName({
        "MainActionBarButtonContainer",
        "MainActionBarContainerFrame",
        "MainMenuBarVehicleLeaveButton",
    }, HideFrameRecursive)
end

-- 隱藏狀態條、姿態條、寵物條、PossessActionBar
-- 注意：OverrideActionBar 不隱藏（飛龍騎術等需要），MainMenuBarManager 不隱藏（encounter bar 生命週期）
-- 裝飾框架（獅鷲/EndCap/背景）已由 HideMainActionBar → HideArtFrameCompletely 處理
local function HideBarDecorations()
    if StatusTrackingBarManager then
        HideFrameRecursive(StatusTrackingBarManager)
    end
    if StanceBar then
        HideFrameSafely(StanceBar)
    end
    if PetActionBar then
        HideFrameSafely(PetActionBar)
    end
    if PossessActionBar then
        HideFrameSafely(PossessActionBar)
    end
end

-- 隱藏動作按鈕與 MultiBar 按鈕
local function HideActionButtons()
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button then
            HideFrameSafely(button)
        end
    end

    local multiBarNames =
        { "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton" }
    for _, barPrefix in ipairs(multiBarNames) do
        for i = 1, 12 do
            local button = _G[barPrefix .. i]
            if button then
                HideFrameSafely(button)
            end
        end
    end

    -- QuickKeybindFrame（快速綁定 UI，非動作條但視覺上重疊）
    if _G.QuickKeybindFrame then
        HideFrameSafely(_G.QuickKeybindFrame)
    end
end

local function HideBlizzardBars()
    -- 戰鬥中不修改框架以避免 taint
    if InCombatLockdown() then
        return
    end

    -- 抑制 taint 警告事件（ADDON_ACTION_BLOCKED/FORBIDDEN）
    InstallTaintEventFilter()

    -- testvigor 模式：暫停所有隱藏操作，讓暴雪動作條完全顯示
    if LunarUI.db and LunarUI.db.global and LunarUI.db.global._testVigorMode then
        return
    end

    -- 四階段掃描（所有操作冪等，延遲重試 1s/3s 會再次執行整個流程）：
    -- 1. HideMainActionBar — MainMenuBar + MainActionBar/MainMenuBarArtFrame 裝飾
    -- 2. HideMultiActionBars — MultiBar 1-7 + EditMode workaround + 容器
    -- 3. HideBarDecorations — 狀態條/姿態條/寵物條/PossessActionBar
    -- 4. HideActionButtons — ActionButton 1-12 + MultiBar 按鈕
    HideMainActionBar()
    HideMultiActionBars()
    HideBarDecorations()
    HideActionButtons()

    -- MainMenuBarManager：完全不觸碰！
    -- 它管理 encounter bar / UIWidgetPowerBarContainerFrame 的生命週期，
    -- 隱藏它會阻止 boss encounter 技能條等 UI 元素正常顯示。
end

-- 隱藏策略：
-- ❌ rawset hooks — 在安全框架上產生 taint
-- ❌ hooksecurefunc(SetAlpha) — 持續重新 taint 安全框架狀態
-- ❌ RegisterStateDriver("visibility", "hide") — 破壞 EditMode 佈局（負數 scale）
-- ❌ MultiBar SetAlpha(0) — Edit Mode secureexecuterange 計算 scale=0（無法攔截）
-- ❌ MultiBar SetScale 替換/hook — taint SecureUtil 的 "secret number" 運算
-- ❌ hooksecurefunc("seterrorhandler") — WoW 禁止 hook 此函數
-- ❌ SetParent(HiddenFrame) 單獨使用 — Edit Mode 用 registeredSystemFrames 列表找框架
-- ✓ 一般框架：SetAlpha(0) + EnableMouse(false)
-- ✓ MultiBar 框架：SetParent(HiddenBarParent) + 覆蓋 OnEditModeEnter/Exit 為 no-op

-- 延遲隱藏以捕捉初始載入後建立的框架
local function HideBlizzardBarsDelayed()
    -- testvigor 模式：完全跳過隱藏操作，讓暴雪動作條完全顯示
    local isTestMode = LunarUI.db and LunarUI.db.global and LunarUI.db.global._testVigorMode

    -- 轉換追蹤：只在 debug 模式才註冊事件（避免常駐開銷）
    local isDebug = LunarUI.db and LunarUI.db.global and LunarUI.db.global._debugVigor
    if isDebug or isTestMode then
        if LunarUI.SetupVigorTrace then
            LunarUI.SetupVigorTrace()
        end
    end

    if isTestMode then
        return
    end

    hideGeneration = hideGeneration + 1
    local gen = hideGeneration

    HideBlizzardBars()
    -- 延遲後再次執行以捕捉延遲建立的框架
    -- 使用世代計數器：如果 disable 後 generation 已遞增，延遲回呼不再執行
    C_Timer.After(1, function()
        if hideGeneration == gen then
            HideBlizzardBars()
        end
    end)
    C_Timer.After(3, function()
        if hideGeneration == gen then
            HideBlizzardBars()
        end
    end)
end

LunarUI.HideBlizzardBarsDelayed = HideBlizzardBarsDelayed

--------------------------------------------------------------------------------
-- 還原暴雪動作條（/lunar off 時呼叫）
--------------------------------------------------------------------------------

local function RestoreBlizzardBars()
    if InCombatLockdown() then
        return
    end

    -- 遞增世代計數器，使 HideBlizzardBarsDelayed 的延遲 timer 不再執行
    hideGeneration = hideGeneration + 1

    -- 1. 還原 MultiBar 框架：parent + OnEditModeEnter/Exit + SetScale
    for bar, state in pairs(savedBarStates) do
        pcall(function()
            bar:SetParent(state.parent)
            bar:Show()
        end)
        bar.OnEditModeEnter = state.onEditModeEnter
        bar.OnEditModeExit = state.onEditModeExit
        bar.SetScale = state.setScale -- nil = 移除 Lua 覆蓋，恢復 metatable 的 C 方法
    end
    wipe(savedBarStates)

    -- 2. 還原被 SetAlpha(0) 的框架（HideFrameSafely 設了 alpha + mouse + keyboard）
    for frame in pairs(hiddenFrames) do
        pcall(function()
            frame:SetAlpha(1)
            frame:EnableMouse(true)
            frame:EnableKeyboard(true)
        end)
    end
    wipe(hiddenFrames)

    -- 3. 還原被 HideFrameRegions 設為 alpha=0 的 regions
    for region in pairs(hiddenRegions) do
        pcall(function()
            region:SetAlpha(1)
        end)
    end
    wipe(hiddenRegions)

    -- 4. 還原被 Hide() 呼叫的 regions 和子物件
    for obj in pairs(explicitlyHidden) do
        pcall(function()
            obj:Show()
        end)
    end
    wipe(explicitlyHidden)

    -- 5. 還原被 HideTextureForcefully 處理的材質（精確恢復原始材質路徑）
    for texture, originalPath in pairs(hiddenTextures) do
        pcall(function()
            if originalPath and originalPath ~= false then
                texture:SetTexture(originalPath)
            end
            texture:SetAlpha(1)
            texture:Show()
        end)
    end
    wipe(hiddenTextures)

    -- 5. 還原全域副作用（error handler + UIParent 事件）
    UninstallTaintEventFilter()
end

LunarUI.RestoreBlizzardBars = RestoreBlizzardBars
