---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 隱藏暴雪動作條
    安全隱藏暴雪預設動作條，避免 UI taint
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 隱藏暴雪動作條
--------------------------------------------------------------------------------

-- 安全隱藏框架：設置透明度為 0 並禁用互動
-- 不使用 RegisterStateDriver（會破壞 EditMode 佈局計算導致負數 scale）
-- 不使用 hooksecurefunc 或 rawset（會在安全框架上產生 taint）
-- 只做一次性 SetAlpha(0)，不 hook，不持續修改安全框架狀態
local function HideFrameSafely(frame)
    if not frame then
        return
    end
    pcall(function()
        frame:SetAlpha(0)
    end)
    pcall(function()
        frame:EnableMouse(false)
    end)
    pcall(function()
        frame:EnableKeyboard(false)
    end)
end

-- 隱藏框架的所有區域（材質）- 只設置透明度
local function HideFrameRegions(frame)
    if not frame then
        return
    end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.SetAlpha then
            pcall(function()
                region:SetAlpha(0)
            end)
        end
    end
end

-- 強力隱藏材質（Texture 物件）
-- 精簡為 3 種有效方法：透明 + 隱藏 + 清除材質
-- 原先 9 種方法（SetTexCoord/SetVertexColor/SetSize/ClearAllPoints/SetAtlas）為過度防禦，
-- 每個 pcall 都有開銷，且此函數在 HideBlizzardBars() 的延遲重試中會執行 3 次。
local function HideTextureForcefully(texture)
    if not texture then
        return
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
    -- 保護飛行活力條框架
    local frameName = frame:GetName()
    if frameName and VIGOR_PROTECTED_FRAMES[frameName] then
        return true
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

    if hasProtectedDescendant then
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

    return hasProtectedDescendant
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
local scaleErrorFilter -- 當前安裝的過濾函數引用（用於避免自我鏈接）
local taintEventsUnregistered = false
local function InstallScaleErrorFilter()
    -- 抑制 "介面功能因插件而失效" 黃字訊息（ADDON_ACTION_BLOCKED 事件）
    -- Blizzard 在 UIParent 的 OnEvent 處理此事件並顯示警告
    -- seterrorhandler 無法攔截（非 Lua 錯誤），需從 UIParent 取消註冊
    if not taintEventsUnregistered then
        taintEventsUnregistered = true
        UIParent:UnregisterEvent("ADDON_ACTION_BLOCKED")
        UIParent:UnregisterEvent("ADDON_ACTION_FORBIDDEN")
    end

    local prevHandler = geterrorhandler()
    -- 已是我們的過濾器，跳過（避免自我鏈接）
    if prevHandler == scaleErrorFilter then
        return
    end
    scaleErrorFilter = function(msg, ...)
        if type(msg) == "string" then
            if msg:find("Scale must be > 0") then
                return
            end
            if msg:find("secret number value tainted") then
                return
            end
        end
        if prevHandler then
            return prevHandler(msg, ...)
        end
    end
    seterrorhandler(scaleErrorFilter)
end

local function HideBlizzardBars()
    -- 戰鬥中不修改框架以避免 taint
    if InCombatLockdown() then
        return
    end

    -- 安裝 SetScale 錯誤過濾器（首次呼叫即安裝，確保在錯誤發生前就位）
    InstallScaleErrorFilter()

    -- testvigor 模式：暫停所有隱藏操作，讓暴雪動作條完全顯示
    -- 用於診斷 vigor bar 不可見是否由隱藏操作引起的 taint 所導致
    if LunarUI.db and LunarUI.db.global and LunarUI.db.global._testVigorMode then
        return
    end

    -- WoW 12.0 完全重新設計動作條
    -- 獅鷲/翼手龍圖案現在在 MainMenuBarArtFrame 的 Lua 屬性中
    -- 使用安全的隱藏方式（只設透明度）

    -- 主要動作條框架
    local primaryFrames = {
        "MainMenuBar",
        "MainMenuBarArtFrame",
        "MainMenuBarArtFrameBackground",
    }
    HideFramesByName(primaryFrames, HideFrameRecursive)

    -- 重要：WoW 現代版本的獅鷲獸是透過 Lua 屬性存取
    -- 不是全域名稱，必須直接從 MainMenuBarArtFrame 取得
    -- 使用帶 hook 的永久隱藏，防止暴雪代碼重新顯示
    if MainMenuBarArtFrame then
        -- 獅鷲裝飾（左右兩側）- 使用多種方法強制隱藏
        if MainMenuBarArtFrame.LeftEndCap then
            HideFrameSafely(MainMenuBarArtFrame.LeftEndCap)
            HideTextureForcefully(MainMenuBarArtFrame.LeftEndCap)
        end
        if MainMenuBarArtFrame.RightEndCap then
            HideFrameSafely(MainMenuBarArtFrame.RightEndCap)
            HideTextureForcefully(MainMenuBarArtFrame.RightEndCap)
        end
        -- 頁碼
        if MainMenuBarArtFrame.PageNumber then
            HideFrameSafely(MainMenuBarArtFrame.PageNumber)
        end
        -- 背景
        if MainMenuBarArtFrame.Background then
            HideFrameSafely(MainMenuBarArtFrame.Background)
        end
        -- 其他子元素
        if MainMenuBarArtFrame.BackgroundLarge then
            HideFrameSafely(MainMenuBarArtFrame.BackgroundLarge)
        end
        if MainMenuBarArtFrame.BackgroundSmall then
            HideFrameSafely(MainMenuBarArtFrame.BackgroundSmall)
        end

        -- 遍歷所有 Lua 屬性，隱藏所有可能的子框架/材質
        for _, value in pairs(MainMenuBarArtFrame) do
            if type(value) == "table" and value.SetAlpha then
                pcall(function()
                    value:SetAlpha(0)
                end)
            end
        end

        -- 遍歷所有區域（材質），包括獅鷲獸材質
        local regions = { MainMenuBarArtFrame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.SetAlpha then
                pcall(function()
                    region:SetAlpha(0)
                end)
            end
            -- 如果是材質，也嘗試隱藏
            if region and region.Hide then
                pcall(function()
                    region:Hide()
                end)
            end
        end

        -- 遍歷所有子框架（使用 select 安全遍歷，避免 nil gap）
        local artChildCount = select("#", MainMenuBarArtFrame:GetChildren())
        if artChildCount > 0 then
            local children = { MainMenuBarArtFrame:GetChildren() }
            for i = 1, artChildCount do
                local child = children[i]
                if child then
                    HideFrameRecursive(child)
                end
            end
        end
    end

    -- 隱藏所有多重動作條並永久隱藏
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
            HideFrameSafely(bar)
        end
    end

    -- 隱藏 WoW 12.0 動作條（ActionBar1-8）
    for i = 1, 8 do
        local bar = _G["ActionBar" .. i]
        if bar then
            HideFrameRecursive(bar)
        end
    end

    -- WoW TWW: 新的動作條容器系統
    -- MainActionBarButtonContainer 包含動作條按鈕
    for i = 1, 12 do
        local container = _G["MainActionBarButtonContainer" .. i]
        if container then
            HideFrameRecursive(container)
        end
    end

    -- 隱藏主動作條容器（可能包含獅鷲）
    local actionBarContainers = {
        "MainActionBarButtonContainer",
        "MainActionBarContainerFrame",
        "MainMenuBarVehicleLeaveButton",
    }
    HideFramesByName(actionBarContainers, HideFrameRecursive)

    -- 隱藏舊版獅鷲裝飾（跨 WoW 版本的所有可能框架名稱）
    -- 這些是舊版的全域名稱，保留以相容舊版本
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
        -- WoW 12.0 新名稱
        "MainMenuBarBackgroundArt",
        "MainMenuBarBackground",
    }
    HideFramesByName(artFrames, HideFrameRecursive)

    -- 隱藏狀態追蹤條（經驗/聲望/榮譽）
    if StatusTrackingBarManager then
        HideFrameRecursive(StatusTrackingBarManager)
    end

    -- 隱藏姿態條
    if StanceBar then
        HideFrameSafely(StanceBar)
    end

    -- 隱藏寵物條
    if PetActionBar then
        HideFrameSafely(PetActionBar)
    end

    -- 注意：MicroButtonAndBagsBar 和 BagsBar 保持可見
    -- LunarUI 僅替換背包，不替換微型選單

    -- 隱藏 WoW 12.0 特定框架
    -- 注意：OverrideActionBar 不隱藏，由暴雪管理（飛龍騎術等）
    -- bar1 會在覆蓋條啟動時自動隱藏
    -- 注意：MainMenuBarManager 不隱藏！它管理 encounter bar / widget bar 生命週期
    -- 永久 hook SetAlpha(0) 會阻止 WoW C++ 側在 EncounterBar 中生成 vigor widget
    local wow12Frames = {
        "PossessActionBar",
        -- WoW 12.0 獅鷲相關框架
        "MainMenuBarArtFrame",
        "MainMenuBarArtFrameBackground",
        -- 注意：MicroMenu 保持可見
    }
    HideFramesByName(wow12Frames, HideFrameSafely)

    -- WoW 12.0 TWW: 嘗試更多可能的獅鷲容器
    local gryphonContainers = {
        "MainMenuBarArtFrame.EndCapContainer",
        "MainMenuBarArtFrame.BorderArt",
        "MainMenuBarArtFrame.BarArt",
    }
    for _, path in ipairs(gryphonContainers) do
        -- 嘗試從路徑獲取框架
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

    -- 直接嘗試常見的 EndCap 材質
    if MainMenuBarArtFrame then
        -- 遍歷所有以 EndCap 或 Gryphon 命名的子元素
        for key, value in pairs(MainMenuBarArtFrame) do
            if
                type(key) == "string"
                and (key:find("EndCap") or key:find("Gryphon") or key:find("Art") or key:find("Background"))
            then
                if type(value) == "table" then
                    if value.SetAlpha then
                        pcall(function()
                            value:SetAlpha(0)
                        end)
                    end
                    if value.Hide then
                        pcall(function()
                            value:Hide()
                        end)
                    end
                end
            end
        end
    end

    -- 隱藏動作按鈕（使用 SetAlpha(0) 避免 taint）
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button then
            HideFrameSafely(button)
        end
    end

    -- 隱藏 MultiBar 按鈕
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

    -- 隱藏獅鷲/EndCap 框架（WoW 12.0 中 MainMenuBarArtFrame 已不存在）
    -- 注意：MicroButtonAndBagsBar 保持可見（LunarUI 不替換微型選單）
    local gryphonFrameNames = {
        "MainMenuBarArtFrameBackground",
        "MainMenuBarArtFrame",
    }
    HideFramesByName(gryphonFrameNames, HideFrameSafely)

    -- 注意：OverrideActionBar 及其 EndCap 不再隱藏，由暴雪管理

    -- 隱藏 WoW 12.0 編輯模式框架
    local editModeFrames = {
        "EditModeExpandedActionBarFrame",
        "QuickKeybindFrame",
    }
    HideFramesByName(editModeFrames, HideFrameSafely)

    -- 注意：移除了 _G 迭代，因為過度搜尋可能導致 taint
    -- 上面已經明確列出所有需要隱藏的框架

    -- 注意：微型按鈕（角色、法術書、天賦等）保持可見
    -- LunarUI 不替換微型選單

    -- MainMenuBarManager：完全不觸碰！
    -- 它管理 encounter bar / UIWidgetPowerBarContainerFrame 的生命週期，
    -- 隱藏它會阻止 boss encounter 技能條等 UI 元素正常顯示。
end

-- 隱藏策略：只用一次性 SetAlpha(0)，不使用任何 hooks
-- ❌ rawset hooks — 在安全框架上產生 taint
-- ❌ hooksecurefunc(SetAlpha) — 持續重新 taint 安全框架狀態
-- ❌ RegisterStateDriver("visibility", "hide") — 破壞 EditMode 佈局（負數 scale）
-- ✓ SetAlpha(0) + EnableMouse(false) — 框架保持有效尺寸，不產生 taint

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

    HideBlizzardBars()
    -- 延遲後再次執行以捕捉延遲建立的框架
    C_Timer.After(1, HideBlizzardBars)
    C_Timer.After(3, function()
        HideBlizzardBars()
        -- 在所有 addon 載入後安裝錯誤過濾（確保在 BugSack 等之後）
        InstallScaleErrorFilter()
    end)
end

LunarUI.HideBlizzardBarsDelayed = HideBlizzardBarsDelayed
