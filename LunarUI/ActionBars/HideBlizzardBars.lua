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

-- 記錄已 hook 的框架，避免重複 hook
local hookedFrames = {}

-- 安全隱藏框架的輔助函數
-- 設置 Alpha(0) 並禁用滑鼠事件，不移動位置以避免影響其他 UI 錨點
local function HideFrameSafely(frame)
    if not frame then return end
    pcall(function() frame:SetAlpha(0) end)
    pcall(function() frame:EnableMouse(false) end)
    pcall(function() frame:EnableKeyboard(false) end)
end

-- 永久隱藏框架（包括 hook SetAlpha 防止重新顯示）
local function HideFramePermanentlyWithHook(frame)
    if not frame then return end
    pcall(function() frame:SetAlpha(0) end)
    pcall(function() frame:EnableMouse(false) end)
    pcall(function() frame:EnableKeyboard(false) end)

    -- Hook SetAlpha 防止暴雪代碼重新設置透明度
    if not hookedFrames[frame] then
        hookedFrames[frame] = true
        pcall(function()
            hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                -- 檢查標記以防止遞迴
                if self._lunarUIForceHidden then return end
                if alpha > 0 then
                    self._lunarUIForceHidden = true
                    pcall(function() self:SetAlpha(0) end)
                    self._lunarUIForceHidden = nil
                end
            end)
        end)
    end
end

-- 隱藏框架的所有區域（材質）- 只設置透明度
local function HideFrameRegions(frame)
    if not frame then return end
    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
        if region and region.SetAlpha then
            pcall(function() region:SetAlpha(0) end)
        end
    end
end

-- 強力隱藏材質（Texture 物件）- 嘗試多種方法
local function HideTextureForcefully(texture)
    if not texture then return end

    -- 方法 1: SetAlpha
    pcall(function() texture:SetAlpha(0) end)

    -- 方法 2: Hide (如果有)
    pcall(function() texture:Hide() end)

    -- 方法 3: SetShown (如果有)
    pcall(function() texture:SetShown(false) end)

    -- 方法 4: SetTexture 清空
    pcall(function() texture:SetTexture(nil) end)

    -- 方法 5: SetTexCoord 設為 0 (讓材質不可見)
    pcall(function() texture:SetTexCoord(0, 0, 0, 0) end)

    -- 方法 6: SetVertexColor 完全透明
    pcall(function() texture:SetVertexColor(0, 0, 0, 0) end)

    -- 方法 7: 縮小到 0
    pcall(function() texture:SetSize(0.001, 0.001) end)

    -- 方法 8: 移到畫面外
    pcall(function()
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", UIParent, "CENTER", -10000, -10000)
    end)

    -- 方法 9: SetAtlas 清空 (如果使用 atlas)
    pcall(function() texture:SetAtlas(nil) end)
end

-- 不應被隱藏的框架白名單（飛行活力條相關）
-- EncounterBar 是 UIWidgetPowerBarContainerFrame 的父框架
-- 如果被遞迴隱藏，活力條即使 alpha=1 也看不到
local VIGOR_PROTECTED_FRAMES = {
    ["PlayerPowerBarAlt"] = true,
    ["UIWidgetPowerBarContainerFrame"] = true,
    ["EncounterBar"] = true,
}

-- 遞迴隱藏框架及其所有子框架/區域
local function HideFrameRecursive(frame)
    if not frame then return end
    -- 跳過 OverrideActionBar，飛龍騎術等需要它
    if frame == OverrideActionBar then return end
    -- 保護飛行活力條框架
    local frameName = frame:GetName()
    if frameName and VIGOR_PROTECTED_FRAMES[frameName] then return end

    HideFrameSafely(frame)
    HideFrameRegions(frame)

    -- 遞迴隱藏所有子框架
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        HideFrameRecursive(child)
    end
end

-- 向後相容別名
local HideFramePermanently = HideFrameSafely

local function HideBlizzardBars()
    -- 戰鬥中不修改框架以避免 taint
    if InCombatLockdown() then return end

    -- WoW 12.0 完全重新設計動作條
    -- 獅鷲/翼手龍圖案現在在 MainMenuBarArtFrame 的 Lua 屬性中
    -- 使用安全的隱藏方式（只設透明度）

    -- 主要動作條框架
    local primaryFrames = {
        "MainMenuBar",
        "MainMenuBarArtFrame",
        "MainMenuBarArtFrameBackground",
    }
    for _, name in ipairs(primaryFrames) do
        local frame = _G[name]
        if frame then
            HideFrameRecursive(frame)
        end
    end

    -- 重要：WoW 現代版本的獅鷲獸是透過 Lua 屬性存取
    -- 不是全域名稱，必須直接從 MainMenuBarArtFrame 取得
    -- 使用帶 hook 的永久隱藏，防止暴雪代碼重新顯示
    if MainMenuBarArtFrame then
        -- 獅鷲裝飾（左右兩側）- 使用多種方法強制隱藏
        if MainMenuBarArtFrame.LeftEndCap then
            HideFramePermanentlyWithHook(MainMenuBarArtFrame.LeftEndCap)
            HideTextureForcefully(MainMenuBarArtFrame.LeftEndCap)
        end
        if MainMenuBarArtFrame.RightEndCap then
            HideFramePermanentlyWithHook(MainMenuBarArtFrame.RightEndCap)
            HideTextureForcefully(MainMenuBarArtFrame.RightEndCap)
        end
        -- 頁碼
        if MainMenuBarArtFrame.PageNumber then
            HideFramePermanentlyWithHook(MainMenuBarArtFrame.PageNumber)
        end
        -- 背景
        if MainMenuBarArtFrame.Background then
            HideFramePermanentlyWithHook(MainMenuBarArtFrame.Background)
        end
        -- 其他子元素
        if MainMenuBarArtFrame.BackgroundLarge then
            HideFramePermanentlyWithHook(MainMenuBarArtFrame.BackgroundLarge)
        end
        if MainMenuBarArtFrame.BackgroundSmall then
            HideFramePermanentlyWithHook(MainMenuBarArtFrame.BackgroundSmall)
        end

        -- 遍歷所有 Lua 屬性，隱藏所有可能的子框架/材質
        for _, value in pairs(MainMenuBarArtFrame) do
            if type(value) == "table" and value.SetAlpha then
                pcall(function() value:SetAlpha(0) end)
            end
        end

        -- 遍歷所有區域（材質），包括獅鷲獸材質
        local regions = {MainMenuBarArtFrame:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.SetAlpha then
                pcall(function() region:SetAlpha(0) end)
            end
            -- 如果是材質，也嘗試隱藏
            if region and region.Hide then
                pcall(function() region:Hide() end)
            end
        end

        -- 遍歷所有子框架
        local children = {MainMenuBarArtFrame:GetChildren()}
        for _, child in ipairs(children) do
            if child then
                HideFrameRecursive(child)
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
            HideFramePermanently(bar)
            -- 防止 EditMode 設定負數 scale 導致報錯
            -- （開專業書等操作會觸發 UpdateRightActionBarPositions）
            if not hookedFrames[bar] then
                hookedFrames[bar] = true
                hooksecurefunc(bar, "SetScale", function(self, scale)
                    if self._lunarFixingScale then return end
                    if not scale or scale <= 0 then
                        self._lunarFixingScale = true
                        self:SetScale(0.001)
                        self._lunarFixingScale = nil
                    end
                end)
            end
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
        "ActionBarController",
        "MainMenuBarVehicleLeaveButton",
    }
    for _, name in ipairs(actionBarContainers) do
        local frame = _G[name]
        if frame then
            HideFrameRecursive(frame)
        end
    end

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
    for _, name in ipairs(artFrames) do
        local frame = _G[name]
        if frame then
            HideFrameRecursive(frame)
        end
    end

    -- 隱藏狀態追蹤條（經驗/聲望/榮譽）
    if StatusTrackingBarManager then
        HideFrameRecursive(StatusTrackingBarManager)
    end

    -- 隱藏姿態條
    if StanceBar then
        HideFramePermanently(StanceBar)
    end

    -- 隱藏寵物條
    if PetActionBar then
        HideFramePermanently(PetActionBar)
    end

    -- 注意：MicroButtonAndBagsBar 和 BagsBar 保持可見
    -- LunarUI 僅替換背包，不替換微型選單

    -- 隱藏 WoW 12.0 特定框架
    -- 注意：OverrideActionBar 不隱藏，由暴雪管理（飛龍騎術等）
    -- bar1 會在覆蓋條啟動時自動隱藏
    local wow12Frames = {
        "MainMenuBarManager",
        "PossessActionBar",
        -- WoW 12.0 獅鷲相關框架
        "MainMenuBarArtFrame",
        "MainMenuBarArtFrameBackground",
        -- 注意：MicroMenu 保持可見
    }
    for _, name in ipairs(wow12Frames) do
        local frame = _G[name]
        if frame then
            HideFramePermanentlyWithHook(frame)
        end
    end

    -- Status Tracking 容器：隱藏並 hook，但允許 Vigor 相關子框架恢復
    -- 使用自訂 hook 而非 HideFramePermanentlyWithHook，避免阻止活力條恢復
    local function HideStatusTrackingBar(frame)
        if not frame then return end
        HideFrameSafely(frame)
        if not hookedFrames[frame] then
            hookedFrames[frame] = true
            pcall(function()
                hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                    if self._lunarUIForceHidden then return end
                    -- 允許 vigor 保護機制恢復 alpha（由 EnsureVigorBarVisible 觸發）
                    -- 僅攔截 Blizzard 自動重新顯示（alpha > 0 且非由 LunarUI 主動設定）
                    if alpha > 0 and not self._lunarUIAllowAlpha then
                        self._lunarUIForceHidden = true
                        pcall(function() self:SetAlpha(0) end)
                        self._lunarUIForceHidden = nil
                    end
                end)
            end)
        end
    end
    if _G.MainStatusTrackingBarContainer then
        HideStatusTrackingBar(_G.MainStatusTrackingBarContainer)
    end
    if _G.SecondaryStatusTrackingBarContainer then
        HideStatusTrackingBar(_G.SecondaryStatusTrackingBarContainer)
    end

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
            local parts = {strsplit(".", path)}
            for i = 2, #parts do
                if frame and frame[parts[i]] then
                    frame = frame[parts[i]]
                else
                    frame = nil
                    break
                end
            end
            if frame and frame.SetAlpha then
                HideFramePermanentlyWithHook(frame)
            end
        end
    end

    -- 直接嘗試常見的 EndCap 材質
    if MainMenuBarArtFrame then
        -- 遍歷所有以 EndCap 或 Gryphon 命名的子元素
        for key, value in pairs(MainMenuBarArtFrame) do
            if type(key) == "string" and (key:find("EndCap") or key:find("Gryphon") or key:find("Art") or key:find("Background")) then
                if type(value) == "table" then
                    if value.SetAlpha then
                        pcall(function() value:SetAlpha(0) end)
                    end
                    if value.Hide then
                        pcall(function() value:Hide() end)
                    end
                end
            end
        end
    end

    -- 直接隱藏動作按鈕（設置透明度並禁用滑鼠）
    -- ActionButton 是安全框架，過度修改會導致 taint
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button then
            pcall(function() button:SetAlpha(0) end)
            pcall(function() button:EnableMouse(false) end)
        end
    end

    -- 隱藏 MultiBar 按鈕並禁用滑鼠
    local multiBarNames = {"MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton"}
    for _, barPrefix in ipairs(multiBarNames) do
        for i = 1, 12 do
            local button = _G[barPrefix .. i]
            if button then
                pcall(function() button:SetAlpha(0) end)
                pcall(function() button:EnableMouse(false) end)
            end
        end
    end

    -- 隱藏已知的獅鷲/EndCap 框架（避免 pairs(_G) 遍歷全域表）
    local gryphonFrameNames = {
        "MainMenuBarArtFrameBackground",
        "MainMenuBarArtFrame",
        "MicroButtonAndBagsBar",
    }
    for _, name in ipairs(gryphonFrameNames) do
        local obj = _G[name]
        if obj then
            HideTextureForcefully(obj)
            if obj.SetAlpha then pcall(function() obj:SetAlpha(0) end) end
            if obj.Hide then pcall(function() obj:Hide() end) end
        end
    end
    -- 處理巢狀子物件（LeftEndCap / RightEndCap）
    local artFrame = _G["MainMenuBarArtFrameBackground"]
    if artFrame then
        for _, childName in ipairs({"LeftEndCap", "RightEndCap"}) do
            local child = artFrame[childName]
            if child then
                HideTextureForcefully(child)
                if child.SetAlpha then pcall(function() child:SetAlpha(0) end) end
                if child.Hide then pcall(function() child:Hide() end) end
            end
        end
    end

    -- 注意：OverrideActionBar 及其 EndCap 不再隱藏，由暴雪管理

    -- 隱藏 WoW 12.0 編輯模式框架
    local editModeFrames = {
        "EditModeExpandedActionBarFrame",
        "QuickKeybindFrame",
    }
    for _, name in ipairs(editModeFrames) do
        local frame = _G[name]
        if frame then
            HideFramePermanently(frame)
        end
    end

    -- 注意：移除了 _G 迭代，因為過度搜尋可能導致 taint
    -- 上面已經明確列出所有需要隱藏的框架

    -- 注意：微型按鈕（角色、法術書、天賦等）保持可見
    -- LunarUI 不替換微型選單
end

-- 延遲隱藏以捕捉初始載入後建立的框架
local function HideBlizzardBarsDelayed()
    HideBlizzardBars()
    -- 延遲後再次執行以捕捉延遲建立的框架
    C_Timer.After(1, HideBlizzardBars)
    C_Timer.After(3, HideBlizzardBars)
end

LunarUI.HideBlizzardBarsDelayed = HideBlizzardBarsDelayed
