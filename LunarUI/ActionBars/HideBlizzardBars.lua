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

-- Edit Mode 保護框架：HideFrameRecursive 遇到這些框架時不設 SetAlpha(0)
-- 改為 SetParent(HiddenBarParent)，讓 Edit Mode 看不到它們
local EDIT_MODE_PROTECTED_FRAMES = {
    ["MultiBarBottomLeft"] = true,
    ["MultiBarBottomRight"] = true,
    ["MultiBarRight"] = true,
    ["MultiBarLeft"] = true,
    ["MultiBar5"] = true,
    ["MultiBar6"] = true,
    ["MultiBar7"] = true,
}

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

-- 過濾已知無害的 Blizzard 錯誤與 taint 警告：
-- 1. UpdateRightActionBarPositions 的 "Scale must be > 0"（隱藏動作條後佈局計算出負數 scale）
-- 2. Backdrop.lua "secret number value tainted by 'LunarUI'"（addon 觸發 tooltip 時 backdrop 使用 tainted width）
-- 3. ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN（UIErrorsFrame 的 "介面功能因插件而失效" 訊息）
-- 以上皆為 UI addon 修改 Blizzard 框架的正常副作用，無功能影響
-- error/taint 過濾器狀態
-- ★ 設計：filter 函數安裝後永遠不從 handler chain 中移除（避免斷鏈風險）。
-- 改用 active flag 控制：active=true 時過濾已知無害錯誤，active=false 時直接透傳。
-- 這樣無論 BugSack 等 addon 是否在中間插入 handler，filter 都能正確停工。
local scaleErrorFilterActive = false
local scaleErrorFilterInstalled = false
local taintEventsUnregistered = false
local function InstallScaleErrorFilter()
    -- 抑制 "介面功能因插件而失效" 黃字訊息（ADDON_ACTION_BLOCKED 事件）
    if not taintEventsUnregistered then
        taintEventsUnregistered = true
        UIParent:UnregisterEvent("ADDON_ACTION_BLOCKED")
        UIParent:UnregisterEvent("ADDON_ACTION_FORBIDDEN")
    end

    -- 啟用過濾
    scaleErrorFilterActive = true

    -- filter 函數只安裝一次（永久駐留在 handler chain 中）
    if scaleErrorFilterInstalled then
        return
    end
    scaleErrorFilterInstalled = true

    local prevHandler = geterrorhandler()
    seterrorhandler(function(msg, ...)
        -- active=false 時直接透傳（不吃任何錯誤）
        if scaleErrorFilterActive then
            local msgStr = tostring(msg or "")
            if msgStr:find("Scale must be > 0") or msgStr:find("secret number value tainted") then
                return
            end
        end
        if prevHandler then
            return prevHandler(msg, ...)
        end
    end)
end

-- 停用過濾（不移除 handler，只關閉 active flag）
local function UninstallScaleErrorFilter()
    scaleErrorFilterActive = false

    -- 重新註冊 UIParent 事件
    if taintEventsUnregistered then
        taintEventsUnregistered = false
        UIParent:RegisterEvent("ADDON_ACTION_BLOCKED")
        UIParent:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    end
end

-- 隱藏主動作條及 ArtFrame 裝飾（獅鷲獸/背景/頁碼等）
-- 微型按鈕已由 ActionBars 模組 SetParent 至自訂框架，不在 MainMenuBar 子樹中
local function HideMainActionBar()
    HideFramesByName({
        "MainMenuBar",
        "MainMenuBarArtFrame",
        "MainMenuBarArtFrameBackground",
    }, HideFrameRecursive)

    -- WoW 現代版本的獅鷲獸是透過 Lua 屬性存取，必須直接從 MainMenuBarArtFrame 取得
    if not MainMenuBarArtFrame then
        return
    end

    -- 獅鷲裝飾（左右兩側）- 使用多種方法強制隱藏
    if MainMenuBarArtFrame.LeftEndCap then
        HideFrameSafely(MainMenuBarArtFrame.LeftEndCap)
        HideTextureForcefully(MainMenuBarArtFrame.LeftEndCap)
    end
    if MainMenuBarArtFrame.RightEndCap then
        HideFrameSafely(MainMenuBarArtFrame.RightEndCap)
        HideTextureForcefully(MainMenuBarArtFrame.RightEndCap)
    end

    -- 頁碼、背景、其他子元素
    local namedElements = { "PageNumber", "Background", "BackgroundLarge", "BackgroundSmall" }
    for _, elemName in ipairs(namedElements) do
        if MainMenuBarArtFrame[elemName] then
            HideFrameSafely(MainMenuBarArtFrame[elemName])
        end
    end

    -- 遍歷所有 Lua 屬性，隱藏所有可能的子框架/材質
    for _, value in pairs(MainMenuBarArtFrame) do
        if type(value) == "table" and value.SetAlpha then
            hiddenRegions[value] = true
            pcall(function()
                value:SetAlpha(0)
            end)
        end
    end

    -- 遍歷所有區域（材質），包括獅鷲獸材質
    local regions = { MainMenuBarArtFrame:GetRegions() }
    for _, region in ipairs(regions) do
        if region then
            if region.SetAlpha then
                hiddenRegions[region] = true
                pcall(function()
                    region:SetAlpha(0)
                end)
            end
            if region.Hide then
                explicitlyHidden[region] = true
                pcall(function()
                    region:Hide()
                end)
            end
        end
    end

    -- 遍歷所有子框架（使用 select 安全遍歷，避免 nil gap）
    local artChildCount = select("#", MainMenuBarArtFrame:GetChildren())
    if artChildCount > 0 then
        local children = { MainMenuBarArtFrame:GetChildren() }
        for i = 1, artChildCount do
            if children[i] then
                HideFrameRecursive(children[i])
            end
        end
    end
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
-- ✓ 覆蓋 OnEditModeEnter/OnEditModeExit 為 no-op — secureexecuterange 呼叫時什麼都不做，
--   scale 計算永遠不會執行。沒有 UnregisterSystemFrame API，但直接覆蓋方法不需要修改列表。
local function HideMultiActionBars()
    local barsToHide = {
        "MultiBarBottomLeft",
        "MultiBarBottomRight",
        "MultiBarRight",
        "MultiBarLeft",
        "MultiBar5",
        "MultiBar6",
        "MultiBar7",
    }
    for _, barName in ipairs(barsToHide) do
        local bar = _G[barName]
        if bar then
            -- 儲存原始狀態（供還原）
            if not savedBarStates[bar] then
                savedBarStates[bar] = {
                    parent = bar:GetParent(),
                    onEditModeEnter = bar.OnEditModeEnter,
                    onEditModeExit = bar.OnEditModeExit,
                }
            end
            -- 1. 移到隱藏父框架：視覺上隱藏（由父框架 Hide() 使其不可見）
            pcall(function()
                bar:SetParent(HiddenBarParent)
            end)
            -- 2. 中和 Edit Mode：覆蓋為 no-op，防止 scale 計算
            bar.OnEditModeEnter = function() end
            bar.OnEditModeExit = function() end
        end
    end

    -- WoW 12.0 動作條（ActionBar1-8）
    for i = 1, 8 do
        local bar = _G["ActionBar" .. i]
        if bar then
            HideFrameRecursive(bar)
        end
    end

    -- WoW TWW: 新的動作條容器系統
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

-- 隱藏舊版裝飾、狀態條、姿態條、寵物條、WoW 12.0 特定框架
local function HideBarDecorations()
    -- 舊版獅鷲裝飾（跨 WoW 版本的所有可能框架名稱）
    local artFrames = {
        "MainMenuBarLeftEndCap",
        "MainMenuBarRightEndCap",
        "MainMenuBarPageNumber",
        "ActionBarUpButton",
        "ActionBarDownButton",
        "MainMenuBarTexture0",
        "MainMenuBarTexture1",
        "MainMenuBarTexture2",
        "MainMenuBarTexture3",
        "MainMenuExpBar",
        "ReputationWatchBar",
        "MainMenuBarBackgroundArt",
        "MainMenuBarBackground",
    }
    HideFramesByName(artFrames, HideFrameRecursive)

    -- 狀態追蹤條（經驗/聲望/榮譽）
    if StatusTrackingBarManager then
        HideFrameRecursive(StatusTrackingBarManager)
    end
    if StanceBar then
        HideFrameSafely(StanceBar)
    end
    if PetActionBar then
        HideFrameSafely(PetActionBar)
    end

    -- WoW 12.0 特定框架
    -- 注意：OverrideActionBar 不隱藏，由暴雪管理（飛龍騎術等）
    -- 注意：MainMenuBarManager 不隱藏！它管理 encounter bar / widget bar 生命週期
    HideFramesByName({
        "PossessActionBar",
        "MainMenuBarArtFrame",
        "MainMenuBarArtFrameBackground",
    }, HideFrameSafely)

    -- WoW 12.0 TWW: 嘗試更多可能的獅鷲容器
    local gryphonContainers = {
        "MainMenuBarArtFrame.EndCapContainer",
        "MainMenuBarArtFrame.BorderArt",
        "MainMenuBarArtFrame.BarArt",
    }
    for _, path in ipairs(gryphonContainers) do
        local frame = MainMenuBarArtFrame
        if frame then
            local parts = { strsplit(".", path) }
            for i = 2, #parts do
                if frame and frame[parts[i]] then
                    frame = frame[parts[i]]
                else
                    frame = nil
                    break
                end
            end
            if frame and frame.SetAlpha then
                HideFrameSafely(frame)
            end
        end
    end

    -- 遍歷 MainMenuBarArtFrame 所有以 EndCap/Gryphon/Art/Background 命名的子元素
    if MainMenuBarArtFrame then
        for key, value in pairs(MainMenuBarArtFrame) do
            if
                type(key) == "string"
                and (key:find("EndCap") or key:find("Gryphon") or key:find("Art") or key:find("Background"))
            then
                if type(value) == "table" then
                    if value.SetAlpha then
                        hiddenRegions[value] = true
                        pcall(function()
                            value:SetAlpha(0)
                        end)
                    end
                    if value.Hide then
                        explicitlyHidden[value] = true
                        pcall(function()
                            value:Hide()
                        end)
                    end
                end
            end
        end
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

    -- 獅鷲/EndCap 框架（重複呼叫以確保跨版本相容）
    HideFramesByName({
        "MainMenuBarArtFrameBackground",
        "MainMenuBarArtFrame",
    }, HideFrameSafely)

    -- WoW 12.0 編輯模式框架
    HideFramesByName({
        "EditModeExpandedActionBarFrame",
        "QuickKeybindFrame",
    }, HideFrameSafely)
end

local function HideBlizzardBars()
    -- 戰鬥中不修改框架以避免 taint
    if InCombatLockdown() then
        return
    end

    -- 安裝 SetScale 錯誤過濾器（首次呼叫即安裝，確保在錯誤發生前就位）
    InstallScaleErrorFilter()

    -- testvigor 模式：暫停所有隱藏操作，讓暴雪動作條完全顯示
    if LunarUI.db and LunarUI.db.global and LunarUI.db.global._testVigorMode then
        return
    end

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
            -- 在所有 addon 載入後安裝錯誤過濾（確保在 BugSack 等之後）
            InstallScaleErrorFilter()
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

    -- 1. 還原 MultiBar 框架：parent + OnEditModeEnter/Exit
    for bar, state in pairs(savedBarStates) do
        pcall(function()
            bar:SetParent(state.parent)
            bar:Show()
        end)
        bar.OnEditModeEnter = state.onEditModeEnter
        bar.OnEditModeExit = state.onEditModeExit
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
    UninstallScaleErrorFilter()
end

LunarUI.RestoreBlizzardBars = RestoreBlizzardBars
