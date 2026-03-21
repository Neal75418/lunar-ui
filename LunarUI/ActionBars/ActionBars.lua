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
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}
local C = LunarUI.Colors

-- 等待 LibActionButton
local LAB = LibStub("LibActionButton-1.0", true)
if not LAB then
    -- 函式庫不可用，跳過動作條
    return
end

-- Masque support (optional)
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

-- 按鈕樣式顏色常數
local BUTTON_COLORS = {
    pushed = { 1, 1, 1, 0.4 },
    highlight = { 1, 1, 1, 0.3 },
    checked = { 0.4, 0.6, 0.8, 0.5 },
    flash = { 1, 0.9, 0.6, 0.4 },
    disabled = { 0.4, 0.4, 0.4 },
    hotkeyText = { 0.8, 0.8, 0.8 },
    flyoutBg = { 0.1, 0.2, 0.5, 0.6 },
    flyoutBorder = { 0.4, 0.6, 1.0, 1 },
}

-- WoW 綁定命令映射：bar ID → binding prefix（參照 Bartender4）
-- bar2 是主動作條第二頁，不應獨立綁定（跳過）
local BINDING_FORMATS = {
    [1] = "ACTIONBUTTON%d",
    [3] = "MULTIACTIONBAR3BUTTON%d",
    [4] = "MULTIACTIONBAR4BUTTON%d",
    [5] = "MULTIACTIONBAR2BUTTON%d",
    [6] = "MULTIACTIONBAR1BUTTON%d",
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
local keybindMode = false
local microMenuLayoutHooked = false

-- M6: Blizzard-managed bars 不可由 LunarUI 淡出控制（會造成 secure frame taint）
local BLIZZARD_BAR_KEYS = { extraActionButton = true, zoneAbilityButton = true }

-- M4: 儲存 Blizzard 框架的原始位置，清理時還原
local savedExtraActionPos = nil
local savedZoneAbilityPos = nil

-- 清除按鈕 NormalTexture（提升到模組級供 hook 共用）
local function ClearNormalTexture(self)
    local nt = self:GetNormalTexture()
    if nt then
        nt:SetTexture(nil)
        nt:Hide()
    end
end

-- Fix 6: 批次處理 NormalTexture 清除，避免每個按鈕 Update 都建 closure
local pendingNormalClear = {}
local normalClearScheduled = false

local function ProcessPendingNormalClears()
    normalClearScheduled = false
    for btn in pairs(pendingNormalClear) do
        if btn:GetNormalTexture() then
            ClearNormalTexture(btn)
        end
        pendingNormalClear[btn] = nil
    end
end

-- WoW 12.0 對 GetActionCooldown 回傳密值，即使用 pcall 保護也無法比較
-- 停用自訂冷卻文字，使用內建顯示與 OmniCC 等插件

-- 批次處理冷卻去飽和（避免每次 SetCooldown 都建立 closure）
local pendingDesaturate = {}
local desaturateScheduled = false

local function ProcessPendingDesaturate()
    desaturateScheduled = false
    for btn in pairs(pendingDesaturate) do
        pendingDesaturate[btn] = nil
        local cd = btn.cooldown
        local btnIcon = btn.icon or (btn:GetName() and _G[btn:GetName() .. "Icon"])
        if btnIcon and cd then
            local ok, onCD = pcall(function()
                local s, d = cd:GetCooldownTimes()
                -- 偵測任何冷卻（s > 0 表示有冷卻開始時間，d > 0 表示有冷卻持續時間）
                return s and d and s > 0 and d > 0
            end)
            if ok and onCD then
                btnIcon:SetDesaturated(true)
                btnIcon:SetVertexColor(C.textDim[1], C.textDim[2], C.textDim[3])
            else
                btnIcon:SetDesaturated(false)
                btnIcon:SetVertexColor(1, 1, 1)
            end
        end
    end
end

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

-- 隱藏預設 NormalTexture 並安裝 hook 防止重新出現
local function StyleButtonNormalTexture(button, normalTexture)
    if normalTexture then
        normalTexture:SetTexture(nil)
        normalTexture:Hide()
    end

    if button._lunarHookedNormal then
        return
    end
    button._lunarHookedNormal = true

    hooksecurefunc(button, "SetNormalTexture", ClearNormalTexture)

    if button.SetNormalAtlas then
        hooksecurefunc(button, "SetNormalAtlas", ClearNormalTexture)
    end

    if button.Update then
        hooksecurefunc(button, "Update", function(self)
            pendingNormalClear[self] = true
            if not normalClearScheduled then
                normalClearScheduled = true
                C_Timer.After(0, ProcessPendingNormalClears)
            end
        end)
    end
end

-- 設定冷卻框架樣式與去飽和 hook
local function StyleButtonCooldown(button)
    local cooldown = button.cooldown
    if not cooldown then
        return
    end

    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(button)
    cooldown:SetDrawSwipe(true)
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    cooldown:SetDrawEdge(true)
    cooldown:SetFrameLevel(button:GetFrameLevel() + 1)

    if button._lunarHookedCooldown then
        return
    end
    button._lunarHookedCooldown = true

    hooksecurefunc(cooldown, "SetCooldown", function()
        pendingDesaturate[button] = true
        if not desaturateScheduled then
            desaturateScheduled = true
            C_Timer.After(0, ProcessPendingDesaturate)
        end
    end)

    cooldown:HookScript("OnHide", function()
        local btnIcon = button.icon or (button:GetName() and _G[button:GetName() .. "Icon"])
        if btnIcon then
            btnIcon:SetDesaturated(false)
            btnIcon:SetVertexColor(1, 1, 1)
        end
    end)
end

-- 樣式化按下/高亮/選中/閃光材質
local function StyleButtonOverlays(button, pushedTexture, highlightTexture, checkedTexture)
    if pushedTexture then
        pushedTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        pushedTexture:SetVertexColor(unpack(BUTTON_COLORS.pushed))
        pushedTexture:SetAllPoints()
    end

    if highlightTexture then
        highlightTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        highlightTexture:SetVertexColor(unpack(BUTTON_COLORS.highlight))
        highlightTexture:SetAllPoints()
    end

    if checkedTexture then
        checkedTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        checkedTexture:SetVertexColor(unpack(BUTTON_COLORS.checked))
        checkedTexture:SetAllPoints()
    end

    if button.Flash then
        button.Flash:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.Flash:SetVertexColor(unpack(BUTTON_COLORS.flash))
        button.Flash:SetAllPoints()
        button.Flash:SetDrawLayer("OVERLAY")
    end
end

---@param button any
local function StyleButton(button)
    if not button then
        return
    end

    -- 確認是真正的按鈕（有 GetNormalTexture 方法），非普通 Frame
    if not button.GetNormalTexture then
        return
    end

    -- 取得按鈕元素
    local name = button:GetName()
    local icon = button.icon or (name and _G[name .. "Icon"])
    local count = button.Count or (name and _G[name .. "Count"])
    local hotkey = button.HotKey or (name and _G[name .. "HotKey"])
    local border = button.Border or (name and _G[name .. "Border"])
    local normalTexture = button:GetNormalTexture()
    local pushedTexture = button:GetPushedTexture()
    local highlightTexture = button:GetHighlightTexture()
    local checkedTexture = button:GetCheckedTexture()

    -- 樣式化圖示
    if icon then
        icon:SetTexCoord(unpack(LunarUI.ICON_TEXCOORD))
        icon:SetDrawLayer("ARTWORK")
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- 樣式化數量文字
    if count then
        LunarUI.SetFont(count, 12, "OUTLINE")
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", -2, 2)
    end

    -- 樣式化快捷鍵文字
    local abStyleDB = LunarUI.GetModuleDB("actionbars")
    if hotkey then
        local showHotkeys = abStyleDB and abStyleDB.showHotkeys
        if showHotkeys == false then
            hotkey:Hide()
        else
            LunarUI.SetFont(hotkey, 10, "OUTLINE")
            hotkey:ClearAllPoints()
            hotkey:SetPoint("TOPRIGHT", -2, -2)
            hotkey:SetTextColor(unpack(BUTTON_COLORS.hotkeyText))
        end
    end

    -- 巨集名稱
    local macroName = button.Name or _G[name .. "Name"]
    if macroName then
        local showMacroNames = abStyleDB and abStyleDB.showMacroNames
        if showMacroNames then
            macroName:Show()
        else
            macroName:Hide()
        end
    end

    -- 隱藏預設邊框
    if border then
        border:SetTexture(nil)
    end

    StyleButtonNormalTexture(button, normalTexture)
    StyleButtonCooldown(button)

    -- 建立自訂邊框（frame level 在 cooldown 之上，但填充透明不遮蓋）
    if not button.LunarBorder then
        local borderFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
        borderFrame:SetAllPoints()
        LunarUI.ApplyBackdrop(borderFrame, nil, C.transparent)
        borderFrame:SetFrameLevel(button:GetFrameLevel() + 3)
        button.LunarBorder = borderFrame
    end

    StyleButtonOverlays(button, pushedTexture, highlightTexture, checkedTexture)
end

-- 按鈕按下閃光動畫：短暫白色閃爍提供打擊回饋感
local function PlayPressFlash(button)
    if not button._lunarFlash then
        local flash = button:CreateTexture(nil, "OVERLAY", nil, 7)
        flash:SetAllPoints()
        flash:SetTexture("Interface\\Buttons\\WHITE8x8")
        flash:SetVertexColor(1, 1, 1, 0)
        flash:Hide()
        button._lunarFlash = flash

        -- 建立淡出動畫群組
        local ag = flash:CreateAnimationGroup()
        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(0.5)
        fadeIn:SetDuration(0.05)
        fadeIn:SetOrder(1)
        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(0.5)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.15)
        fadeOut:SetOrder(2)
        ag:SetScript("OnPlay", function()
            button._lunarFlash:Show()
        end)
        ag:SetScript("OnFinished", function()
            button._lunarFlash:Hide()
        end)
        button._lunarFlashAG = ag
    end
    if button._lunarFlashAG and button._lunarFlashAG:IsPlaying() then
        button._lunarFlashAG:Stop()
    end
    if button._lunarFlash and button._lunarFlashAG then
        button._lunarFlash:Show()
        button._lunarFlashAG:Play()
    end
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
        StyleButton(button)

        -- 按下閃光回饋
        if not button._lunarHookedPress then
            button._lunarHookedPress = true
            button:HookScript("OnMouseDown", function(self)
                PlayPressFlash(self)
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

        -- Masque skinning (if available)
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

        StyleButton(button)

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

        StyleButton(button)

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
-- 非戰鬥淡入淡出
--------------------------------------------------------------------------------

local isInCombat = false
local isBarsUnlocked = false -- 解鎖時完全停用淡出
local fadeInitialized = false
local fadeState = {} -- { [barKey] = { alpha, targetAlpha, hovered, timer } }

-- 懸停偵測系統（合併後的全域狀態）
local hoverCheckElapsed = 0
local barHoverStates = {} -- { [barKey] = { wasHovering = bool } }

-- A1/B5 效能修復：快取 fade 設定值，避免 UpdateFadeAndHover（每幀）和 IsBarFadeEnabled（每 bar）重複查 DB
local cachedFadeEnabled = true
local cachedFadeAlpha = 0.3
local cachedFadeDelay = 2.0
local cachedFadeDuration = 0.4
local cachedBaseAlpha = 1.0 -- #3: 快取 bar 基礎透明度，避免 SetBarAlpha 每幀查 DB
local function RefreshFadeSettingsCache()
    local db = LunarUI.GetModuleDB("actionbars") or {}
    cachedFadeEnabled = db.fadeEnabled ~= false
    cachedFadeAlpha = db.fadeAlpha or 0.3
    cachedFadeDelay = db.fadeDelay or 2.0
    cachedFadeDuration = db.fadeDuration or 0.4
    cachedBaseAlpha = db.alpha or 1.0 -- #3
end

local function IsBarFadeEnabled(barKey)
    if isBarsUnlocked then
        return false
    end
    if not cachedFadeEnabled then -- A1/B5: use cached value, avoid per-bar GetFadeSettings() call
        return false
    end

    -- 每條 bar 可獨立覆蓋
    local db = LunarUI.GetModuleDB("actionbars")
    if db and type(db[barKey]) == "table" and db[barKey].fadeEnabled ~= nil then
        return db[barKey].fadeEnabled
    end
    return true -- 預設跟隨全域設定
end

---@param bar Frame?
---@param alpha number
local function SetBarAlpha(bar, alpha)
    if not bar then
        return
    end
    bar:SetAlpha(alpha * cachedBaseAlpha) -- #3: 使用快取，避免動畫每幀查 DB
end

-- 平滑動畫框架
local fadeAnimFrame = CreateFrame("Frame")
local fadeAnimActive = false

-- 前向宣告（UpdateFadeAndHover 需要這些函數）
---@type fun(barKey: string, targetAlpha: number)
local FadeBarTo
---@type fun()
local StartFadeAnimation

-- 淡出動畫處理器（線性插值）
local function UpdateFadeAnimation(fadeEnabled, elapsed)
    if not (fadeAnimActive and fadeEnabled) then
        return false
    end

    local fadeDuration = cachedFadeDuration
    local anyActive = false

    for barKey, state in pairs(fadeState) do
        if state.alpha ~= state.targetAlpha then
            anyActive = true
            local bar = bars[barKey]
            if bar then
                local speed = (1.0 / math.max(fadeDuration, 0.05)) * elapsed
                if state.alpha < state.targetAlpha then
                    state.alpha = math.min(state.alpha + speed, state.targetAlpha)
                else
                    state.alpha = math.max(state.alpha - speed, state.targetAlpha)
                end
                SetBarAlpha(bar, state.alpha)
            end
        end
    end

    if not anyActive then
        fadeAnimActive = false
    end

    return anyActive
end

-- 懸停偵測處理器（節流 0.05 秒）
local function UpdateHoverDetection(fadeEnabled, fadeAlpha, fadeDelay, elapsed)
    if isInCombat or not fadeEnabled or isBarsUnlocked then
        return
    end

    hoverCheckElapsed = hoverCheckElapsed + elapsed
    if hoverCheckElapsed < 0.05 then
        return
    end

    hoverCheckElapsed = 0

    for barKey, bar in pairs(bars) do
        if IsBarFadeEnabled(barKey) then
            -- 初始化懸停狀態
            if not barHoverStates[barKey] then
                barHoverStates[barKey] = { wasHovering = false }
            end
            local hoverState = barHoverStates[barKey]

            local isHovering = bar:IsMouseOver(8, -8, -8, 8)

            -- 滑鼠進入
            if isHovering and not hoverState.wasHovering then
                hoverState.wasHovering = true
                if not fadeState[barKey] then
                    fadeState[barKey] = {
                        alpha = 1.0,
                        targetAlpha = 1.0,
                        hovered = false,
                        timer = nil,
                    }
                end
                fadeState[barKey].hovered = true
                if fadeState[barKey].timer then
                    fadeState[barKey].timer:Cancel()
                    fadeState[barKey].timer = nil
                end
                FadeBarTo(barKey, 1.0)

            -- 滑鼠離開（fadeState[barKey] 已在進入時初始化，此處必然存在）
            elseif not isHovering and hoverState.wasHovering then
                hoverState.wasHovering = false
                local state = fadeState[barKey]
                if state then
                    state.hovered = false
                    if state.timer then
                        state.timer:Cancel()
                    end
                    state.timer = C_Timer.NewTimer(fadeDelay, function()
                        if not isInCombat and fadeState[barKey] and not fadeState[barKey].hovered then
                            FadeBarTo(barKey, fadeAlpha)
                        end
                        if fadeState[barKey] then
                            fadeState[barKey].timer = nil
                        end
                    end)
                end
            end
        end
    end
end

-- 合併的 OnUpdate 處理器（協調淡出動畫與懸停偵測）
local function UpdateFadeAndHover(_self, elapsed)
    -- A1/B5 效能修復：使用快取設定值，避免每幀查 DB
    local fadeEnabled, fadeAlpha, fadeDelay = cachedFadeEnabled, cachedFadeAlpha, cachedFadeDelay

    -- 執行淡出動畫
    local anyAnimActive = UpdateFadeAnimation(fadeEnabled, elapsed)

    -- 執行懸停偵測
    UpdateHoverDetection(fadeEnabled, fadeAlpha, fadeDelay, elapsed)

    -- 自動停止：無動畫且不需要懸停輪詢時（fade 停用、在戰鬥中、或解鎖狀態）
    -- 當 fadeEnabled 且非戰鬥狀態，懸停偵測需持續輪詢，不可停止 OnUpdate
    if not anyAnimActive and (not fadeEnabled or isInCombat or isBarsUnlocked) then
        fadeAnimFrame:SetScript("OnUpdate", nil)
    end
end

function FadeBarTo(barKey, targetAlpha)
    if not fadeState[barKey] then
        fadeState[barKey] = { alpha = 1.0, targetAlpha = 1.0, hovered = false, timer = nil }
    end
    fadeState[barKey].targetAlpha = targetAlpha
    StartFadeAnimation()
end

function StartFadeAnimation()
    if fadeAnimActive then
        return
    end
    fadeAnimActive = true
    RefreshFadeSettingsCache() -- A1/B5: 更新所有快取設定值（包含 duration）
    fadeAnimFrame:SetScript("OnUpdate", UpdateFadeAndHover)
end

local function FadeAllBarsOut()
    if not cachedFadeEnabled then -- A1/B5: use cached value
        return
    end

    for barKey in pairs(bars) do
        if not BLIZZARD_BAR_KEYS[barKey] and IsBarFadeEnabled(barKey) then -- M6: skip Blizzard secure frames
            if not fadeState[barKey] or not fadeState[barKey].hovered then
                FadeBarTo(barKey, cachedFadeAlpha)
            end
        end
    end
end

local function FadeAllBarsIn()
    for barKey in pairs(bars) do
        if not BLIZZARD_BAR_KEYS[barKey] then -- M6: skip Blizzard secure frames
            FadeBarTo(barKey, 1.0)
        end
    end
end

-- 懸停偵測：使用透明遮罩框架覆蓋整條 bar
-- barKey 不再需要傳入，懸停偵測已整合至全域 UpdateFadeAndHover
---@param bar Frame?
local function SetupBarHoverDetection(bar)
    if not bar or bar._lunarFadeHooked then
        return
    end
    bar._lunarFadeHooked = true

    -- 建立懸停偵測框架（覆蓋整條 bar + 邊距）
    local hoverFrame = CreateFrame("Frame", nil, bar)
    hoverFrame:SetPoint("TOPLEFT", -8, 8)
    hoverFrame:SetPoint("BOTTOMRIGHT", 8, -8)
    hoverFrame:SetFrameStrata(bar:GetFrameStrata())
    hoverFrame:SetFrameLevel(bar:GetFrameLevel() + 50)
    hoverFrame:EnableMouse(false) -- 不攔截點擊

    -- 懸停偵測已整合至 UpdateFadeAndHover 的統一 OnUpdate 中
    -- 不再需要每個 bar 獨立的 OnUpdate 腳本

    bar._lunarHoverFrame = hoverFrame
end

-- 戰鬥事件
local combatFrame = LunarUI.CreateEventHandler(
    { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" },
    function(_self, event)
        RefreshFadeSettingsCache() -- A1/B5: 更新快取（戰鬥狀態切換時設定可能已變更）
        if not cachedFadeEnabled then
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            -- 進入戰鬥：全部淡入
            isInCombat = true
            FadeAllBarsIn()
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- 離開戰鬥：延遲淡出
            isInCombat = false
            C_Timer.After(cachedFadeDelay, function()
                if not fadeInitialized then
                    return
                end
                if not isInCombat then
                    FadeAllBarsOut()
                end
            end)
        end
    end
)

-- 初始化淡出狀態（非戰鬥時啟動淡出）
local function InitializeFade()
    if not combatFrame then
        return
    end
    -- 重新註冊戰鬥事件（Cleanup 後重新啟用時需要）
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    RefreshFadeSettingsCache() -- #2: 確保快取最新，避免兩次 GetFadeSettings() 查 DB
    if not cachedFadeEnabled then
        return
    end
    fadeInitialized = true

    -- 為每條 bar 設定懸停偵測
    for _, bar in pairs(bars) do
        SetupBarHoverDetection(bar)
    end

    -- 非戰鬥中立即啟動淡出
    if not InCombatLockdown() then
        isInCombat = false
        C_Timer.After(cachedFadeDelay, function() -- #2: 使用快取值
            if not fadeInitialized then
                return
            end
            if not isInCombat then
                FadeAllBarsOut()
            end
        end)
    else
        isInCombat = true
    end
end

--------------------------------------------------------------------------------
-- 快捷鍵模式
--------------------------------------------------------------------------------

local function EnterKeybindMode()
    if InCombatLockdown() then
        LunarUI:Print(L["KeybindCombatLocked"] or "Cannot change keybinds during combat")
        return
    end
    if keybindMode then
        return
    end
    keybindMode = true

    for _name, button in pairs(buttons) do
        -- 跳過無法獨立綁定的 bar（如 bar2 主動作條第二頁）
        local barId = button:GetParent() and button:GetParent().id
        if not barId or BINDING_FORMATS[barId] then
            -- 高亮按鈕
            if button.LunarBorder then
                button.LunarBorder:SetBackdropBorderColor(unpack(C.highlightBlue))
            end

            -- 啟用鍵盤綁定
            button:EnableKeyboard(true)
            button:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    LunarUI:ExitKeybindMode()
                    return
                end

                -- 設定快捷鍵（根據 bar ID 選擇正確的綁定命令）
                local btnBarId = self:GetParent() and self:GetParent().id
                local bindFormat = btnBarId and BINDING_FORMATS[btnBarId]
                if bindFormat then
                    local action = self._state_action
                    if action then
                        local buttonIndex = ((action - 1) % 12 + 1)
                        SetBinding(key, bindFormat:format(buttonIndex))
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
    if not keybindMode then
        return
    end
    keybindMode = false

    for _name, button in pairs(buttons) do
        -- 重設邊框
        if button.LunarBorder then
            button.LunarBorder:SetBackdropBorderColor(unpack(C.border))
        end

        -- 停用鍵盤
        button:EnableKeyboard(false)
        button:SetScript("OnKeyDown", nil)
    end

    local msg = L["KeybindDisabled"] or "Keybind mode disabled."
    LunarUI:Print(msg)
end

--------------------------------------------------------------------------------
-- 隱藏暴雪動作條（已提取至 HideBlizzardBars.lua）
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ExtraActionButton 樣式化（世界任務/場景等特殊按鈕）
--------------------------------------------------------------------------------

-- M4 helper: 儲存框架所有 anchor 點（清理時還原）
local function SaveFramePoints(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        points[i] = { point, relativeTo, relativePoint, x, y }
    end
    return points
end

-- M4 helper: 還原已儲存的 anchor 點
local function RestoreFramePoints(frame, points)
    frame:ClearAllPoints()
    for _, p in ipairs(points) do
        frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
end

local function StyleExtraActionButton()
    if InCombatLockdown() then
        return
    end -- 防禦性：避免戰鬥中操作 EditMode 管理的框架
    local db = LunarUI.GetModuleDB("actionbars")
    if not db or db.extraActionButton == false then
        return
    end

    local extra = _G.ExtraActionBarFrame
    if not extra then
        return
    end

    -- 重新定位至畫面中下方
    -- 不使用 SetParent（會造成 taint），僅重新定位
    if not savedExtraActionPos then
        savedExtraActionPos = SaveFramePoints(extra) -- M4: 儲存原始位置供清理還原
    end
    extra:ClearAllPoints()
    extra:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)

    -- 停止暴雪預設進場動畫（intro 是 AnimationGroup，無 SetAlpha）
    if extra.intro and extra.intro.Stop then
        extra.intro:Stop()
    end

    -- 遍歷區域，隱藏裝飾材質
    for _, region in ipairs({ extra:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local atlas = region.GetAtlas and region:GetAtlas()
            -- 保留按鈕圖示本身，隱藏背景裝飾
            if atlas and (atlas:find("ExtraAbility") or atlas:find("extraability")) then
                region:SetAlpha(0)
            end
        end
    end

    -- 樣式化 ExtraActionButton1
    local btn = _G.ExtraActionButton1
    if not btn then
        return
    end

    local buttonSize = db.buttonSize or DEFAULT_BUTTON_SIZE
    btn:SetSize(buttonSize * 1.5, buttonSize * 1.5)

    -- 樣式化按鈕（複用現有 StyleButton）
    StyleButton(btn)

    -- 隱藏暴雪按鈕的額外裝飾
    if btn.style then
        btn.style:SetAlpha(0)
    end

    -- 註冊到月相感知（跟隨動作條透明度）
    bars.extraActionButton = extra
end

-- Zone Ability Button（龍島飛行等區域技能）
local function StyleZoneAbilityButton()
    if InCombatLockdown() then
        return
    end -- 防禦性：避免戰鬥中操作 EditMode 管理的框架
    local db = LunarUI.GetModuleDB("actionbars")
    if not db or db.extraActionButton == false then
        return
    end

    local zone = _G.ZoneAbilityFrame
    if not zone then
        return
    end

    -- 重新定位
    -- 不使用 SetParent（會造成 taint），僅重新定位
    if not savedZoneAbilityPos then
        savedZoneAbilityPos = SaveFramePoints(zone) -- M4: 儲存原始位置供清理還原
    end
    zone:ClearAllPoints()
    zone:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 350)

    -- 隱藏裝飾背景
    if zone.Style then
        zone.Style:SetAlpha(0)
    end

    -- 樣式化按鈕
    local btn = zone.SpellButton or zone.SpellButtonContainer
    if btn then
        local buttonSize = db.buttonSize or DEFAULT_BUTTON_SIZE
        btn:SetSize(buttonSize * 1.5, buttonSize * 1.5)
        StyleButton(btn)
    end

    bars.zoneAbilityButton = zone
end

--------------------------------------------------------------------------------
-- 微型按鈕列（角色/法術書/天賦/任務等系統按鈕）
--------------------------------------------------------------------------------

local function CreateMicroBar()
    local abDB = LunarUI.GetModuleDB("actionbars")
    local db = abDB and abDB.microBar
    if not db or not db.enabled then
        return
    end
    if InCombatLockdown() then
        return
    end

    -- WoW 12.0 微型按鈕列表
    local MICRO_BUTTONS = {}
    local microButtonNames = {
        "CharacterMicroButton",
        "ProfessionMicroButton",
        "PlayerSpellsMicroButton",
        "AchievementMicroButton",
        "QuestLogMicroButton",
        "HousingMicroButton",
        "GuildMicroButton",
        "LFDMicroButton",
        "CollectionsMicroButton",
        "EJMicroButton",
        "StoreMicroButton",
        "MainMenuMicroButton",
        "HelpMicroButton",
    }
    for _, btnName in ipairs(microButtonNames) do
        local btn = _G[btnName]
        if btn then
            table.insert(MICRO_BUTTONS, btn)
        end
    end

    if #MICRO_BUTTONS == 0 then
        return
    end

    -- 建立容器
    local microBar = CreateFrame("Frame", "LunarUI_MicroBar", UIParent)
    local btnWidth = db.buttonWidth or 28
    local btnHeight = db.buttonHeight or 36
    local spacing = 1
    local totalWidth = #MICRO_BUTTONS * btnWidth + (#MICRO_BUTTONS - 1) * spacing

    microBar:SetSize(totalWidth, btnHeight)
    microBar:SetPoint(db.point or "BOTTOM", UIParent, db.point or "BOTTOM", db.x or 0, db.y or 2)
    microBar:SetFrameStrata("MEDIUM")
    microBar:SetClampedToScreen(true)

    -- 儲存按鈕參照以供清理用
    microBar._buttons = MICRO_BUTTONS

    -- 重新掛載並排列微型按鈕
    -- SetParent 切斷 MicroMenu→MainMenuBar 的 alpha 繼承鏈，
    -- 使 HideBlizzardBars 對 MainMenuBar 的 SetAlpha(0) 不再連帶隱藏按鈕。
    -- 非戰鬥狀態下 SetParent 不會 taint 安全框架（ElvUI 等主流 addon 亦採用此做法）。
    for i, btn in ipairs(MICRO_BUTTONS) do
        btn:SetParent(microBar)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", microBar, "LEFT", (i - 1) * (btnWidth + spacing), 0)
        btn:SetSize(btnWidth, btnHeight)
        btn:SetAlpha(1)
        btn:Show()

        -- 隱藏暴雪裝飾材質
        for _, region in ipairs({ btn:GetRegions() }) do
            if region:IsObjectType("Texture") then
                local texName = region:GetDebugName() or ""
                -- 保留圖示材質，隱藏背景/邊框/發光
                if texName:find("Background") or texName:find("Flash") or texName:find("Highlight") then
                    region:SetAlpha(0)
                end
            end
        end
    end

    -- 按鈕已 SetParent 到 microBar，MicroMenu 現在是空殼
    -- 隱藏 MicroMenu 避免在原始位置顯示空框架
    if _G.MicroMenu then
        _G.MicroMenu:SetAlpha(0)
        _G.MicroMenu:EnableMouse(false)
        -- Hook Layout 防止暴雪代碼在動態事件中重新排列按鈕位置
        if _G.MicroMenu.Layout and not microMenuLayoutHooked then
            microMenuLayoutHooked = true
            hooksecurefunc(_G.MicroMenu, "Layout", function()
                if bars.microBar and bars.microBar._buttons and not InCombatLockdown() then
                    for idx, mbtn in ipairs(bars.microBar._buttons) do
                        mbtn:SetParent(bars.microBar)
                        mbtn:ClearAllPoints()
                        mbtn:SetPoint("LEFT", bars.microBar, "LEFT", (idx - 1) * (btnWidth + spacing), 0)
                    end
                end
            end)
        end
    end

    bars.microBar = microBar
end

-- 微型按鈕列清理
local function CleanupMicroBar()
    if bars.microBar then
        -- 還原按鈕到 MicroMenu（Layout hook 因 bars.microBar=nil 自動停止介入）
        if bars.microBar._buttons and _G.MicroMenu and not InCombatLockdown() then
            for _, btn in ipairs(bars.microBar._buttons) do
                btn:SetParent(_G.MicroMenu)
            end
            _G.MicroMenu:SetAlpha(1)
            _G.MicroMenu:EnableMouse(true)
        end
        bars.microBar:Hide()
        bars.microBar = nil
    end
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
    LunarUI.HideBlizzardBarsDelayed()

    -- 建立主動作條（bar1 = 頁面 1，bar2 = 頁面 2，以此類推）
    for i = 1, 6 do
        CreateActionBar(i, i)
    end

    -- 建立特殊動作條
    CreateStanceBar()
    CreatePetBar()

    -- 樣式化額外動作按鈕
    StyleExtraActionButton()
    StyleZoneAbilityButton()

    -- 微型按鈕列
    CreateMicroBar()

    -- 初始化淡入淡出系統
    C_Timer.After(1.0, InitializeFade)
end

-- 清理函數
local function CleanupActionBars()
    -- 停止淡出動畫
    fadeInitialized = false
    fadeAnimFrame:SetScript("OnUpdate", nil)
    fadeAnimActive = false

    -- 清理淡出計時器
    for _, state in pairs(fadeState) do
        if state.timer then
            state.timer:Cancel()
            state.timer = nil
        end
    end
    wipe(fadeState)
    wipe(barHoverStates) -- 清理懸停狀態
    wipe(pendingNormalClear)
    wipe(pendingDesaturate)

    -- 解除戰鬥事件監聽（保留 frame 參照，重新啟用時可重新註冊）
    if combatFrame then
        combatFrame:UnregisterAllEvents()
    end

    -- 清理姿態條事件
    if bars.stancebar then
        bars.stancebar:UnregisterAllEvents()
        bars.stancebar:SetScript("OnEvent", nil)
        bars.stancebar = nil
    end

    -- 清理寵物條事件
    if bars.petbar then
        bars.petbar:UnregisterAllEvents()
        bars.petbar:SetScript("OnEvent", nil)
        bars.petbar = nil
    end

    -- 還原 ExtraActionBarFrame
    if _G.ExtraActionBarFrame and bars.extraActionButton then
        if _G.ExtraActionBarFrame.intro then
            _G.ExtraActionBarFrame.intro:SetAlpha(1)
        end
        -- M4: 還原原始位置
        if savedExtraActionPos and not InCombatLockdown() then
            RestoreFramePoints(_G.ExtraActionBarFrame, savedExtraActionPos)
            savedExtraActionPos = nil
        end
        bars.extraActionButton = nil
    end

    -- 還原 ZoneAbilityFrame
    if _G.ZoneAbilityFrame and bars.zoneAbilityButton then
        if _G.ZoneAbilityFrame.Style then
            _G.ZoneAbilityFrame.Style:SetAlpha(1)
        end
        -- M4: 還原原始位置
        if savedZoneAbilityPos and not InCombatLockdown() then
            RestoreFramePoints(_G.ZoneAbilityFrame, savedZoneAbilityPos)
            savedZoneAbilityPos = nil
        end
        bars.zoneAbilityButton = nil
    end

    -- 清理微型按鈕列
    CleanupMicroBar()

    -- 清理主動作條（bar1-6）的懸停框架旗標並重置 bars 表
    for barKey, bar in pairs(bars) do
        if type(bar) == "table" and bar._lunarHoverFrame then
            bar._lunarHoverFrame:Hide()
            bar._lunarHoverFrame = nil
        end
        if type(bar) == "table" then
            bar._lunarFadeHooked = nil
        end
        bars[barKey] = nil
    end
    wipe(buttons) -- 清理全域按鈕表，避免 KeybindMode 累積陳舊參照

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
LunarUI.EnterKeybindMode = EnterKeybindMode
LunarUI.ExitKeybindMode = ExitKeybindMode
LunarUI.CleanupActionBars = CleanupActionBars
LunarUI.actionBars = bars

LunarUI:RegisterModule("ActionBars", {
    onEnable = SpawnActionBars,
    onDisable = CleanupActionBars,
    delay = 0.3,
})

-- 註冊快捷鍵切換函數
function LunarUI.ToggleKeybindMode()
    if keybindMode then
        ExitKeybindMode()
    else
        EnterKeybindMode()
    end
end
