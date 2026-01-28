---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
--[[
    LunarUI - 動作條
    基於 LibActionButton 的動作條系統，具有月相感知

    功能：
    - 主動作條（1-6）
    - 姿態條 / 寵物條 / 載具條
    - 月相感知透明度
    - 冷卻文字顯示
    - 快捷鍵懸停模式
    - 可設定按鈕大小與間距
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}

-- 等待 LibActionButton
local LAB = LibStub("LibActionButton-1.0", true)
if not LAB then
    -- 函式庫不可用，跳過動作條
    return
end

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local BUTTON_SIZE = 36
local BUTTON_SPACING = 4
local _BUTTONS_PER_ROW = 12  -- 保留供未來使用

local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local bars = {}
local buttons = {}
local keybindMode = false

-- WoW 12.0 對 GetActionCooldown 回傳密值，即使用 pcall 保護也無法比較
-- 停用自訂冷卻文字，使用內建顯示與 OmniCC 等插件

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function CreateBarFrame(name, numButtons, parent)
    -- 使用 SecureHandlerStateTemplate 以支援 WrapScript（LAB 需要）
    local frame = CreateFrame("Frame", name, parent or UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(
        numButtons * BUTTON_SIZE + (numButtons - 1) * BUTTON_SPACING,
        BUTTON_SIZE
    )
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)

    -- 背景（可選，預設隱藏）
    local bg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", -4, 4)
    bg:SetPoint("BOTTOMRIGHT", 4, -4)
    bg:SetBackdrop(backdropTemplate)
    bg:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
    bg:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.8)
    bg:Hide()
    frame.bg = bg

    return frame
end

local function StyleButton(button)
    if not button then return end

    -- 取得按鈕元素
    local name = button:GetName()
    local icon = button.icon or _G[name .. "Icon"]
    local count = button.Count or _G[name .. "Count"]
    local hotkey = button.HotKey or _G[name .. "HotKey"]
    local border = button.Border or _G[name .. "Border"]
    local normalTexture = button:GetNormalTexture()
    local pushedTexture = button:GetPushedTexture()
    local highlightTexture = button:GetHighlightTexture()
    local checkedTexture = button:GetCheckedTexture()

    -- 樣式化圖示
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetDrawLayer("ARTWORK")
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- 樣式化數量文字
    if count then
        count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", -2, 2)
    end

    -- 樣式化快捷鍵文字
    if hotkey then
        hotkey:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", -2, -2)
        hotkey:SetTextColor(0.8, 0.8, 0.8)
    end

    -- 隱藏預設邊框
    if border then
        border:SetTexture(nil)
    end

    -- 樣式化一般材質
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    -- 建立自訂邊框
    if not button.LunarBorder then
        local borderFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
        borderFrame:SetAllPoints()
        borderFrame:SetBackdrop(backdropTemplate)
        borderFrame:SetBackdropColor(0, 0, 0, 0)
        borderFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        borderFrame:SetFrameLevel(button:GetFrameLevel() + 2)
        button.LunarBorder = borderFrame
    end

    -- 樣式化按下材質
    if pushedTexture then
        pushedTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        pushedTexture:SetVertexColor(1, 1, 1, 0.2)
        pushedTexture:SetAllPoints()
    end

    -- 樣式化高亮材質
    if highlightTexture then
        highlightTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        highlightTexture:SetVertexColor(1, 1, 1, 0.3)
        highlightTexture:SetAllPoints()
    end

    -- 樣式化選中材質
    if checkedTexture then
        checkedTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        checkedTexture:SetVertexColor(0.4, 0.6, 0.8, 0.5)
        checkedTexture:SetAllPoints()
    end
end

-- WoW 12.0 對 GetActionCooldown 回傳密值，無法進行比較
-- 停用自訂冷卻文字，使用內建冷卻螺旋與 OmniCC 等插件處理
local function _UpdateCooldownText(_button)
    -- 刻意留空 - WoW 12.0 密值阻止自訂冷卻文字
end

--------------------------------------------------------------------------------
-- 動作條建立
--------------------------------------------------------------------------------

local function CreateActionBar(id, page)
    local db = LunarUI.db and LunarUI.db.profile.actionbars["bar" .. id]
    if not db or not db.enabled then return end

    local numButtons = db.buttons or 12
    local buttonSize = db.buttonSize or BUTTON_SIZE
    local name = "LunarUI_ActionBar" .. id

    -- 建立動作條框架
    local bar = CreateBarFrame(name, numButtons, UIParent)
    bar.id = id
    bar.page = page

    -- 位置
    local yOffset = -100 - (id - 1) * (buttonSize + 8)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, yOffset)

    -- 建立按鈕
    bar.buttons = {}
    for i = 1, numButtons do
        local buttonName = name .. "Button" .. i
        local button = LAB:CreateButton(i, buttonName, bar, nil)

        button:SetSize(buttonSize, buttonSize)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * (buttonSize + BUTTON_SPACING), 0)

        -- 設定此動作條的頁面
        button:SetState(0, "action", (page - 1) * 12 + i)
        for state = 1, 14 do
            button:SetState(state, "action", (state - 1) * 12 + i)
        end

        -- 樣式化
        StyleButton(button)

        bar.buttons[i] = button
        buttons[buttonName] = button
    end

    bars["bar" .. id] = bar
    return bar
end

local function CreateStanceBar()
    local db = LunarUI.db and LunarUI.db.profile.actionbars.stancebar
    if not db or not db.enabled then return end

    local numStances = GetNumShapeshiftForms() or 0
    if numStances == 0 then return end

    local bar = CreateBarFrame("LunarUI_StanceBar", numStances, UIParent)
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 200)

    bar.buttons = {}
    for i = 1, numStances do
        local button = CreateFrame("CheckButton", "LunarUI_StanceButton" .. i, bar, "StanceButtonTemplate")
        button:SetSize(30, 30)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * 34, 0)
        button:SetID(i)

        StyleButton(button)
        bar.buttons[i] = button
    end

    -- 姿態變化時更新姿態條
    bar:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    bar:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    bar:SetScript("OnEvent", function(self)
        local newNum = GetNumShapeshiftForms() or 0
        for i, btn in ipairs(self.buttons) do
            if i <= newNum then
                btn:Show()
            else
                btn:Hide()
            end
        end
    end)

    bars.stancebar = bar
    return bar
end

local function CreatePetBar()
    local db = LunarUI.db and LunarUI.db.profile.actionbars.petbar
    if not db or not db.enabled then return end

    local numButtons = 10
    local bar = CreateBarFrame("LunarUI_PetBar", numButtons, UIParent)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160)

    bar.buttons = {}
    for i = 1, numButtons do
        local button = CreateFrame("CheckButton", "LunarUI_PetButton" .. i, bar, "PetActionButtonTemplate")
        button:SetSize(30, 30)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * 34, 0)
        button:SetID(i)

        StyleButton(button)
        bar.buttons[i] = button
    end

    -- 依寵物狀態顯示/隱藏
    bar:RegisterEvent("UNIT_PET")
    bar:RegisterEvent("PET_BAR_UPDATE")
    bar:SetScript("OnEvent", function(self)
        if UnitExists("pet") and not UnitIsDead("pet") then
            self:Show()
        else
            self:Hide()
        end
    end)

    -- 初始狀態
    if not UnitExists("pet") then
        bar:Hide()
    end

    bars.petbar = bar
    return bar
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateAllBarsForPhase()
    local tokens = LunarUI:GetTokens()

    -- 動作條即使在新月階段也應保持較高可見度
    local minAlpha = 0.5
    local alpha = math.max(tokens.alpha, minAlpha)

    for _name, bar in pairs(bars) do
        if bar and bar:IsShown() then
            bar:SetAlpha(alpha)
        end
    end
end

local function RegisterBarPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(_oldPhase, _newPhase)
        UpdateAllBarsForPhase()
    end)
end

--------------------------------------------------------------------------------
-- 快捷鍵模式
--------------------------------------------------------------------------------

local function EnterKeybindMode()
    if keybindMode then return end
    keybindMode = true

    for _name, button in pairs(buttons) do
        if button then
            -- 高亮按鈕
            if button.LunarBorder then
                button.LunarBorder:SetBackdropBorderColor(0.4, 0.6, 0.8, 1)
            end

            -- 顯示目前快捷鍵
            button:EnableKeyboard(true)
            button:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    LunarUI:ExitKeybindMode()
                    return
                end

                -- 設定快捷鍵
                local action = self._state_action
                if action then
                    local bind = GetBindingKey("ACTIONBUTTON" .. ((action - 1) % 12 + 1))
                    if bind then
                        SetBinding(key, "ACTIONBUTTON" .. ((action - 1) % 12 + 1))
                        SaveBindings(GetCurrentBindingSet())
                    end
                end
            end)
        end
    end

    local msg = L["KeybindEnabled"] or "Keybind mode enabled. Hover over a button and press a key. Press ESC to exit."
    LunarUI:Print(msg)
end

local function ExitKeybindMode()
    if not keybindMode then return end
    keybindMode = false

    for _name, button in pairs(buttons) do
        if button then
            -- 重設邊框
            if button.LunarBorder then
                button.LunarBorder:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            end

            -- 停用鍵盤
            button:EnableKeyboard(false)
            button:SetScript("OnKeyDown", nil)
        end
    end

    local msg = L["KeybindDisabled"] or "Keybind mode disabled."
    LunarUI:Print(msg)
end

--------------------------------------------------------------------------------
-- 隱藏暴雪動作條
--------------------------------------------------------------------------------

-- 永久隱藏框架的輔助函數（防止重新顯示）
local function HideFramePermanently(frame)
    if not frame then return end
    pcall(function() frame:UnregisterAllEvents() end)
    pcall(function() frame:SetAlpha(0) end)
    pcall(function() frame:Hide() end)
    -- 防止暴雪重新顯示框架
    pcall(function()
        frame:SetScript("OnShow", function(self) self:Hide() end)
    end)
end

-- 隱藏框架的所有區域（材質）
local function HideFrameRegions(frame)
    if not frame then return end
    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
        if region and region.Hide then
            pcall(function() region:Hide() end)
        end
        if region and region.SetAlpha then
            pcall(function() region:SetAlpha(0) end)
        end
    end
end

-- 遞迴隱藏框架及其所有子框架/區域
local function HideFrameRecursive(frame)
    if not frame then return end
    HideFramePermanently(frame)
    HideFrameRegions(frame)

    -- 遞迴隱藏所有子框架
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        HideFrameRecursive(child)
    end
end

local function HideBlizzardBars()
    -- WoW 12.0 完全重新設計動作條
    -- 獅鷲/翼手龍圖案現在在 MainMenuBarArtFrame 及其子框架中
    -- 使用積極的遞迴隱藏

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
        end
    end

    -- 隱藏 WoW 12.0 動作條（ActionBar1-8）
    for i = 1, 8 do
        local bar = _G["ActionBar" .. i]
        if bar then
            HideFrameRecursive(bar)
        end
    end

    -- 隱藏獅鷲裝飾（跨 WoW 版本的所有可能框架名稱）
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
    local wow12Frames = {
        "MainMenuBarManager",
        "OverrideActionBar",
        "PossessActionBar",
        "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer",
        -- 注意：MicroMenu 保持可見
    }
    for _, name in ipairs(wow12Frames) do
        local frame = _G[name]
        if frame then
            HideFramePermanently(frame)
        end
    end

    -- 直接隱藏動作按鈕
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button then
            HideFramePermanently(button)
        end
    end

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

    -- 搜尋 _G 中包含動作條相關名稱的任何框架
    -- 這可以捕捉到我們可能遺漏的框架
    local patterns = {
        "^MainMenuBar",
        "^ActionBar%d",
        "^MultiBar",
        "EndCap$",
        "Gryphon",
        "Wyvern",
    }

    for name, obj in pairs(_G) do
        if type(obj) == "table" and type(obj.Hide) == "function" then
            for _, pattern in ipairs(patterns) do
                if type(name) == "string" and name:match(pattern) then
                    pcall(function() obj:Hide() end)
                    pcall(function() obj:SetAlpha(0) end)
                    break
                end
            end
        end
    end

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

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function SpawnActionBars()
    local db = LunarUI.db and LunarUI.db.profile.actionbars
    if not db then return end

    -- 檢查是否啟用自訂動作條
    if db.enabled == false then
        return  -- 使用暴雪預設動作條
    end

    -- 使用事件驅動重試而非固定計時器處理戰鬥鎖定
    if InCombatLockdown() then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            SpawnActionBars()
        end)
        return
    end

    -- 延遲重試隱藏暴雪動作條
    HideBlizzardBarsDelayed()

    -- 建立主動作條（bar1 = 頁面 1，bar2 = 頁面 2，以此類推）
    for i = 1, 6 do
        CreateActionBar(i, i)
    end

    -- 建立特殊動作條
    CreateStanceBar()
    CreatePetBar()

    -- 註冊月相更新
    RegisterBarPhaseCallback()

    -- 套用初始月相
    UpdateAllBarsForPhase()
end

-- 匯出
LunarUI.SpawnActionBars = SpawnActionBars
LunarUI.EnterKeybindMode = EnterKeybindMode
LunarUI.ExitKeybindMode = ExitKeybindMode
LunarUI.actionBars = bars

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.3, SpawnActionBars)
end)

-- 實現快捷鍵模式命令
hooksecurefunc(LunarUI, "RegisterCommands", function(self)
    -- 新增 /lunar keybind 命令
    local origHandler = self.slashCommands and self.slashCommands["keybind"]
    if not origHandler then
        -- 如果命令系統支援，將 keybind 註冊為子命令
        -- 否則使用者可透過 EnterKeybindMode/ExitKeybindMode 函數切換
    end
end)

-- 註冊快捷鍵切換函數
function LunarUI.ToggleKeybindMode()
    if keybindMode then
        ExitKeybindMode()
    else
        EnterKeybindMode()
    end
end
