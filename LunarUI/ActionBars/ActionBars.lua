---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - 動作條
    基於 LibActionButton 的動作條系統，具有月相感知

    功能：
    - 主動作條（1-6）
    - 姿態條 / 寵物條 / 載具條
    - 冷卻文字顯示
    - 快捷鍵懸停模式
    - 可設定按鈕大小與間距

    子模組（載入順序在本檔之前）：
    - ButtonStyling.lua  → LunarUI.ABStyleButton, LunarUI.ABPlayPressFlash
    - FadeAndHover.lua   → LunarUI.ABInitializeFade, LunarUI.ABCleanupFade, ...
    - SpecialButtons.lua → LunarUI.ABStyleExtraActionButton, LunarUI.ABCreateMicroBar, ...
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- 等待 LibActionButton
local LAB = LibStub("LibActionButton-1.0", true)
if not LAB then
    -- 函式庫不可用，跳過動作條
    return
end

-- Masque 支援（可選）
local Masque = LibStub("Masque", true)
local masqueGroups = {}

local function GetMasqueGroup(barName)
    if not Masque or InCombatLockdown() then
        return nil
    end
    if not masqueGroups[barName] then
        masqueGroups[barName] = Masque:Group("LunarUI", barName)
    end
    return masqueGroups[barName]
end

--------------------------------------------------------------------------------
-- 常數與輔助函數
--------------------------------------------------------------------------------

local DEFAULT_BUTTON_SIZE = 36
local DEFAULT_BUTTON_SPACING = 4

-- 按鈕樣式顏色常數（CreateBarFrame 背景用）
local BUTTON_COLORS = {
    flyoutBg = { 0.1, 0.2, 0.5, 0.6 },
    flyoutBorder = { 0.4, 0.6, 1.0, 1 },
    disabled = { 0.4, 0.4, 0.4 },
}

-- 從設定讀取按鈕大小
local function GetButtonSize()
    local db = LunarUI.GetModuleDB("actionbars")
    return db and db.buttonSize or DEFAULT_BUTTON_SIZE
end

-- 從設定讀取按鈕間距
local function GetButtonSpacing()
    local db = LunarUI.GetModuleDB("actionbars")
    return db and db.buttonSpacing or DEFAULT_BUTTON_SPACING
end

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

---@type table<string, Frame?>
local bars = {}
local buttons = {}

-- SpawnActionBars 延遲初始化 fade 的 timer handle（供 CleanupActionBars 取消）
local fadeInitTimer = nil
local actionBarsCombatWaitFrame = nil

-- 共享狀態：供子模組透過 lazy resolution 存取
LunarUI._actionBars = bars
LunarUI._actionBarButtons = buttons

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function CreateBarFrame(name, numButtons, parent, orientation)
    local buttonSize = GetButtonSize()
    local buttonSpacing = GetButtonSpacing()
    orientation = orientation or "horizontal"

    -- 使用 SecureHandlerStateTemplate 以支援 WrapScript（LAB 需要）
    local frame = CreateFrame("Frame", name, parent or UIParent, "SecureHandlerStateTemplate")
    if orientation == "vertical" then
        frame:SetSize(buttonSize, numButtons * buttonSize + (numButtons - 1) * buttonSpacing)
    else
        frame:SetSize(numButtons * buttonSize + (numButtons - 1) * buttonSpacing, buttonSize)
    end
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)

    -- 提高框架層級，確保在暴雪隱藏框架之上
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(100)

    -- 設定透明度
    local abDB = LunarUI.GetModuleDB("actionbars")
    local alpha = abDB and abDB.alpha or 1.0
    frame:SetAlpha(alpha)

    -- 背景 / 解鎖 mover（掛在 UIParent 下，避免繼承 bar 的 alpha 和 secure 框架限制）
    -- 使用純 Texture 而非 BackdropTemplate，確保在所有 WoW 版本下可見
    local bg = CreateFrame("Frame", nil, UIParent)
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    bg:SetFrameStrata("MEDIUM")
    bg:SetFrameLevel(2) -- 低於 vigor bar widget(70/121)，低於動作條按鈕(100)
    -- 背景材質
    local bgTex = bg:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(unpack(BUTTON_COLORS.flyoutBg))
    bg._bgTex = bgTex
    -- 邊框材質（四邊各 1px）
    local borderTop = bg:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT")
    borderTop:SetPoint("TOPRIGHT")
    borderTop:SetColorTexture(unpack(BUTTON_COLORS.flyoutBorder))
    local borderBottom = bg:CreateTexture(nil, "BORDER")
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT")
    borderBottom:SetColorTexture(unpack(BUTTON_COLORS.flyoutBorder))
    local borderLeft = bg:CreateTexture(nil, "BORDER")
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT")
    borderLeft:SetColorTexture(unpack(BUTTON_COLORS.flyoutBorder))
    local borderRight = bg:CreateTexture(nil, "BORDER")
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT")
    borderRight:SetColorTexture(unpack(BUTTON_COLORS.flyoutBorder))
    bg:Hide()
    frame.bg = bg

    return frame
end

--------------------------------------------------------------------------------
-- 動作條建立
--------------------------------------------------------------------------------

-- 建立並配置動作條的所有按鈕
local function CreateActionBarButtons(bar, page, numButtons, buttonSize, buttonSpacing, orientation, name)
    local rangeDb = LunarUI.GetModuleDB("actionbars")
    bar.buttons = {}
    for i = 1, numButtons do
        local buttonName = name .. "Button" .. i
        local button = LAB:CreateButton(i, buttonName, bar, nil)

        -- 告知 LAB 我們自行處理邊框，讓 cooldown 正確填滿按鈕
        button.config = button.config or {}
        button.config.hideElements = button.config.hideElements or {}
        button.config.hideElements.border = true
        button.config.hideElements.borderIfEmpty = true
        if button.UpdateConfig then
            button:UpdateConfig()
        end

        button:SetSize(buttonSize, buttonSize)
        if orientation == "vertical" then
            button:SetPoint("TOP", bar, "TOP", 0, -((i - 1) * (buttonSize + buttonSpacing)))
        else
            button:SetPoint("LEFT", bar, "LEFT", (i - 1) * (buttonSize + buttonSpacing), 0)
        end

        -- 設定此動作條的頁面
        button:SetState(0, "action", (page - 1) * 12 + i)
        for state = 1, 14 do
            button:SetState(state, "action", (state - 1) * 12 + i)
        end

        -- 樣式化
        LunarUI.ABStyleButton(button)

        -- 按下閃光回饋
        if not button._lunarHookedPress then
            button._lunarHookedPress = true
            button:HookScript("OnMouseDown", function(self)
                LunarUI.ABPlayPressFlash(self)
            end)
        end

        -- 技能距離著色（超出範圍時按鈕變紅）
        if rangeDb and rangeDb.outOfRangeColoring ~= false and button.UpdateConfig then
            button.config = button.config or {}
            button.config.outOfRangeColoring = "button"
            button.config.colors = button.config.colors or {}
            button.config.colors.range = { 0.8, 0.1, 0.1 }
            button:UpdateConfig()
        end

        -- Masque 換膚（如果可用）
        local masqueGroup = GetMasqueGroup(name)
        if masqueGroup then
            masqueGroup:AddButton(button)
        end

        bar.buttons[i] = button
        buttons[buttonName] = button
    end
end

-- 設定主動作條（bar1）的頁面切換與覆蓋條隱藏狀態驅動
local function SetupBar1StateDrivers(bar)
    -- 頁面切換狀態驅動：bonusbar 用於德魯伊變形/龍騎術等
    bar:SetAttribute(
        "_onstate-page",
        [[
        self:SetAttribute("state", newstate)
        control:ChildUpdate("state", newstate)
    ]]
    )

    local pageCondition = table.concat({
        "[bar:2] 2",
        "[bar:3] 3",
        "[bar:4] 4",
        "[bar:5] 5",
        "[bar:6] 6",
        "[bonusbar:1] 7",
        "[bonusbar:2] 8",
        "[bonusbar:3] 9",
        "[bonusbar:4] 10",
        "[bonusbar:5] 11",
        "1",
    }, "; ")
    RegisterStateDriver(bar, "page", pageCondition)

    -- 覆蓋條/載具時隱藏（讓暴雪原生覆蓋條顯示飛龍騎術等技能）
    RegisterStateDriver(bar, "visibility", "[overridebar] hide; [vehicleui] hide; [possessbar] hide; show")
end

local function CreateActionBar(id, page)
    local abDB = LunarUI.GetModuleDB("actionbars")
    local db = abDB and abDB["bar" .. id]
    if not db or not db.enabled then
        return
    end

    local numButtons = db.buttons or 12
    local buttonSize = GetButtonSize()
    local buttonSpacing = GetButtonSpacing()
    local orientation = db.orientation or "horizontal"
    local name = "LunarUI_ActionBar" .. id

    -- 建立動作條框架
    local bar = CreateBarFrame(name, numButtons, UIParent, orientation)
    bar.id = id
    bar.page = page
    bar.dbKey = "bar" .. id

    -- 位置（從設定讀取）
    local x = db.x or 0
    local y = db.y or (100 + (id - 1) * (buttonSize + 8))
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", x, y)

    -- 建立按鈕
    CreateActionBarButtons(bar, page, numButtons, buttonSize, buttonSpacing, orientation, name)

    -- 主動作條（bar1）需要頁面切換 + 覆蓋條/載具隱藏
    if id == 1 then
        SetupBar1StateDrivers(bar)
    end

    bars["bar" .. id] = bar
    return bar
end

-- 更新單個姿態按鈕的圖標和狀態
---@param button any
---@param index number
local function UpdateStanceButton(button, index)
    if not button then
        return
    end

    local texture, isActive, isCastable = GetShapeshiftFormInfo(index)

    -- 設置圖標
    local icon = button.icon or _G[button:GetName() .. "Icon"]
    if icon then
        if texture then
            icon:SetTexture(texture)
            icon:Show()
        else
            icon:Hide()
        end
    end

    -- 設置選中狀態
    button:SetChecked(isActive)

    -- 設置可用狀態（灰色/正常）
    if icon then
        if isCastable then
            icon:SetVertexColor(1, 1, 1)
        else
            icon:SetVertexColor(unpack(BUTTON_COLORS.disabled))
        end
    end
end

local function CreateStanceBar()
    local abDB = LunarUI.GetModuleDB("actionbars")
    local db = abDB and abDB.stancebar
    if not db or not db.enabled then
        return
    end

    local numStances = GetNumShapeshiftForms() or 0
    if numStances == 0 then
        return
    end

    local buttonSize = 30
    local buttonSpacing = 4

    local bar = CreateBarFrame("LunarUI_StanceBar", numStances, UIParent)
    bar.dbKey = "stancebar"

    -- 位置（從設定讀取）
    local x = db.x or -400
    local y = db.y or 200
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", x, y)

    bar.buttons = {}
    for i = 1, numStances do
        local button = CreateFrame("CheckButton", "LunarUI_StanceButton" .. i, bar, "StanceButtonTemplate")
        button:SetSize(buttonSize, buttonSize)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * (buttonSize + buttonSpacing), 0)
        button:SetID(i)

        -- 初始化圖標
        UpdateStanceButton(button, i)

        LunarUI.ABStyleButton(button)

        local masqueGroup = GetMasqueGroup("Stance Bar")
        if masqueGroup then
            masqueGroup:AddButton(button)
        end

        bar.buttons[i] = button
    end

    -- 更新所有姿態按鈕
    local function UpdateAllStanceButtons()
        local newNum = GetNumShapeshiftForms() or 0
        for i, btn in ipairs(bar.buttons) do
            if i <= newNum then
                UpdateStanceButton(btn, i)
                btn:Show()
            else
                btn:Hide()
            end
        end
    end

    -- 姿態變化時更新姿態條
    bar:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    bar:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    bar:RegisterEvent("PLAYER_ENTERING_WORLD")
    bar:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
    bar:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
    bar:SetScript("OnEvent", UpdateAllStanceButtons)

    -- 初始更新
    C_Timer.After(0.1, UpdateAllStanceButtons)

    bars.stancebar = bar
    return bar
end

local function CreatePetBar()
    local abDB = LunarUI.GetModuleDB("actionbars")
    local db = abDB and abDB.petbar
    if not db or not db.enabled then
        return
    end

    local numButtons = 10
    local bar = CreateBarFrame("LunarUI_PetBar", numButtons, UIParent)
    bar.dbKey = "petbar"

    -- 位置（從設定讀取）
    local x = db.x or 0
    local y = db.y or 160
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", x, y)

    bar.buttons = {}
    for i = 1, numButtons do
        local button = CreateFrame("CheckButton", "LunarUI_PetButton" .. i, bar, "PetActionButtonTemplate")
        button:SetSize(30, 30)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * 34, 0)
        button:SetID(i)

        LunarUI.ABStyleButton(button)

        local masqueGroup = GetMasqueGroup("Pet Bar")
        if masqueGroup then
            masqueGroup:AddButton(button)
        end

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
-- 初始化
--------------------------------------------------------------------------------

local function SpawnActionBars()
    local db = LunarUI.GetModuleDB("actionbars")
    if not db then
        return
    end

    -- 檢查是否啟用自訂動作條
    if db.enabled == false then
        return -- 使用暴雪預設動作條
    end

    -- 使用事件驅動重試而非固定計時器處理戰鬥鎖定（singleton 防止框架洩漏）
    if InCombatLockdown() then
        if not actionBarsCombatWaitFrame then
            actionBarsCombatWaitFrame = CreateFrame("Frame")
        end
        actionBarsCombatWaitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        actionBarsCombatWaitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            SpawnActionBars()
        end)
        return
    end

    -- 延遲重試隱藏暴雪動作條
    LunarUI.HideBlizzardBarsDelayed()

    -- 建立主動作條（bar1 = 頁面 1，bar2 = 頁面 2，以此類推）
    for i = 1, 6 do
        CreateActionBar(i, i)
    end

    -- 建立特殊動作條
    CreateStanceBar()
    CreatePetBar()

    -- 樣式化額外動作按鈕
    LunarUI.ABStyleExtraActionButton()
    LunarUI.ABStyleZoneAbilityButton()

    -- 微型按鈕列
    LunarUI.ABCreateMicroBar()

    -- 初始化淡入淡出系統
    fadeInitTimer = C_Timer.NewTimer(1.0, function()
        fadeInitTimer = nil
        LunarUI.ABInitializeFade()
    end)
end

-- 清理函數
local function CleanupActionBars()
    -- 取消尚未執行的 InitializeFade 計時器（防止 cleanup 後 fadeInitialized 被重設為 true）
    if fadeInitTimer then
        fadeInitTimer:Cancel()
        fadeInitTimer = nil
    end

    -- 停止淡出動畫（委託給 FadeAndHover 子模組）
    LunarUI.ABCleanupFade()

    -- 重置 ButtonStyling 批次處理旗標
    LunarUI._ABButtonStylingState.resetBatchFlags()
    LunarUI._ABButtonStylingState.wipePendingNormalClear()
    LunarUI._ABButtonStylingState.wipePendingDesaturate()

    -- 清理姿態條事件
    if bars.stancebar then
        bars.stancebar:UnregisterAllEvents()
        bars.stancebar:SetScript("OnEvent", nil)
        bars.stancebar:Hide()
        bars.stancebar = nil
    end

    -- 清理寵物條事件
    if bars.petbar then
        bars.petbar:UnregisterAllEvents()
        bars.petbar:SetScript("OnEvent", nil)
        bars.petbar:Hide()
        bars.petbar = nil
    end

    -- 還原 ExtraActionBarFrame
    if _G.ExtraActionBarFrame and bars.extraActionButton then
        -- intro 是 AnimationGroup，無 SetAlpha；Play() 重新觸發暴雪進場動畫
        if _G.ExtraActionBarFrame.intro and _G.ExtraActionBarFrame.intro.Play then
            _G.ExtraActionBarFrame.intro:Play()
        end
        -- M4: 還原原始位置
        local savedExtraActionPos = LunarUI.ABSavedExtraActionPos()
        if savedExtraActionPos and not InCombatLockdown() then
            LunarUI.ABRestoreFramePoints(_G.ExtraActionBarFrame, savedExtraActionPos)
            LunarUI._ABSpecialButtonsState.clearSavedExtraActionPos()
        end
        bars.extraActionButton = nil
    end

    -- 還原 ZoneAbilityFrame
    if _G.ZoneAbilityFrame and bars.zoneAbilityButton then
        if _G.ZoneAbilityFrame.Style then
            _G.ZoneAbilityFrame.Style:SetAlpha(1)
        end
        -- M4: 還原原始位置
        local savedZoneAbilityPos = LunarUI.ABSavedZoneAbilityPos()
        if savedZoneAbilityPos and not InCombatLockdown() then
            LunarUI.ABRestoreFramePoints(_G.ZoneAbilityFrame, savedZoneAbilityPos)
            LunarUI._ABSpecialButtonsState.clearSavedZoneAbilityPos()
        end
        bars.zoneAbilityButton = nil
    end

    -- 清理微型按鈕列
    LunarUI.ABCleanupMicroBar()

    -- 若 keybind 模式仍啟動，先退出（ExitKeybindMode 需遍歷 buttons，必須在 wipe 前執行）
    -- 戰鬥中無法 SetScript，改為直接重置旗標
    if LunarUI._ABSpecialButtonsState.isKeybindMode() then
        if not InCombatLockdown() then
            LunarUI.ABExitKeybindMode()
        else
            LunarUI._ABSpecialButtonsState.resetKeybindMode() -- 戰鬥中只重置旗標，略過 SetScript 操作
        end
    end

    -- 取消 bar1 的 StateDriver（避免 disable 後繼續觸發、且下次 enable 重複累積）
    if bars["bar1"] then
        UnregisterStateDriver(bars["bar1"], "page")
        UnregisterStateDriver(bars["bar1"], "visibility")
    end

    -- 清理主動作條（bar1-6）的懸停框架旗標並重置 bars 表
    for barKey, bar in pairs(bars) do
        if type(bar) == "table" and bar._lunarHoverFrame then
            bar._lunarHoverFrame:Hide()
            bar._lunarHoverFrame = nil
        end
        if type(bar) == "table" then
            bar._lunarFadeHooked = nil
            bar:Hide() -- Disable 後隱藏動作條（WoW frame 不可 destroy）
        end
        bars[barKey] = nil
    end
    wipe(buttons) -- 清理全域按鈕表，避免 KeybindMode 累積陳舊參照
    wipe(masqueGroups) -- 清理 Masque 群組（下次 enable 重新建立）

    -- 清理戰鬥等待框架（防止脫戰後 SpawnActionBars 回魂）
    -- 不 nil 變數：frame 為 singleton，SpawnActionBars 的 nil check 只防重複 CreateFrame
    if actionBarsCombatWaitFrame then
        actionBarsCombatWaitFrame:UnregisterAllEvents()
        actionBarsCombatWaitFrame:SetScript("OnEvent", nil)
    end

    -- 清理 Vigor debug trace
    if LunarUI.CleanupVigorTrace then
        LunarUI.CleanupVigorTrace()
    end
end

-- 微型按鈕診斷（/lunar debugmicro）
function LunarUI:DebugMicroButtons()
    self:Print("|cff8882ff=== MicroButton Debug ===|r")

    -- 檢查 microBar 狀態
    local mb = bars.microBar
    self:Print(string.format("  LunarUI_MicroBar: %s", mb and "exists" or "|cffff0000nil|r"))
    if mb then
        self:Print(
            string.format(
                "    shown=%s alpha=%.2f buttons=%d",
                tostring(mb:IsShown()),
                mb:GetAlpha(),
                mb._buttons and #mb._buttons or 0
            )
        )
    end

    -- 檢查第一個按鈕的狀態和 parent chain
    local testBtn = _G.CharacterMicroButton
    if not testBtn then
        self:Print("  CharacterMicroButton: |cffff0000not found|r")
        return
    end

    self:Print(
        string.format(
            "  CharacterMicroButton: shown=%s visible=%s alpha=%.2f",
            tostring(testBtn:IsShown()),
            tostring(testBtn:IsVisible()),
            testBtn:GetAlpha()
        )
    )

    -- 走訪 parent chain
    self:Print("  Parent chain:")
    local frame = testBtn
    local depth = 0
    while frame do
        local name = frame:GetName() or "(anonymous)"
        local shown = frame:IsShown()
        local visible = frame:IsVisible()
        local alpha = frame:GetAlpha()
        local x, y = frame:GetCenter()
        local color = (not shown or not visible or alpha < 0.01) and "|cffff4444" or "|cff00ff00"
        self:Print(
            string.format(
                "    %s%s%s|r shown=%s visible=%s alpha=%.2f pos=(%.0f,%.0f)",
                string.rep("  ", depth),
                color,
                name,
                tostring(shown),
                tostring(visible),
                alpha,
                x or 0,
                y or 0
            )
        )
        frame = frame:GetParent()
        depth = depth + 1
        if depth > 10 then
            break
        end
    end

    -- 檢查 MicroMenu
    if _G.MicroMenu then
        local mm = _G.MicroMenu
        self:Print(
            string.format(
                "  MicroMenu: name=%s shown=%s visible=%s alpha=%.2f",
                mm:GetName() or "nil",
                tostring(mm:IsShown()),
                tostring(mm:IsVisible()),
                mm:GetAlpha()
            )
        )
    else
        self:Print("  MicroMenu: |cffff0000nil|r")
    end
end

-- 匯出
LunarUI.SpawnActionBars = SpawnActionBars
LunarUI.EnterKeybindMode = LunarUI.ABEnterKeybindMode
LunarUI.ExitKeybindMode = LunarUI.ABExitKeybindMode
LunarUI.CleanupActionBars = CleanupActionBars
LunarUI.actionBars = bars

LunarUI:RegisterModule("ActionBars", {
    onEnable = SpawnActionBars,
    onDisable = CleanupActionBars,
    delay = 0.3,
})

-- 註冊快捷鍵切換函數
function LunarUI.ToggleKeybindMode()
    if LunarUI._ABSpecialButtonsState.isKeybindMode() then
        LunarUI.ABExitKeybindMode()
    else
        LunarUI.ABEnterKeybindMode()
    end
end
