---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - 首次安裝精靈
    引導新用戶完成基本設定
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local mathAbs = math.abs
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local format = string.format
local L = Engine.L or {}
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 重載確認對話框（延遲建立，等 L 載入）
local function EnsureReloadDialog()
    if not StaticPopupDialogs["LUNARUI_INSTALL_RELOAD"] then
        StaticPopupDialogs["LUNARUI_INSTALL_RELOAD"] = {
            text = L["InstallReloadText"] or "LunarUI setup complete. Reload UI to apply changes?",
            button1 = L["InstallReloadBtn"] or "Reload",
            button2 = L["InstallReloadLater"] or "Later",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
    end
end

local WIZARD_WIDTH = 500
local WIZARD_HEIGHT = 380
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 28
local TOTAL_STEPS = 4

-- 佈局預設值（從 Engine.GetLayoutPresets 取得共用資料，加上 label/desc）
local function GetLayoutPresets()
    if not Engine.GetLayoutPresets then
        return {}
    end
    local presets = Engine.GetLayoutPresets()
    presets.dps.label = L["InstallLayoutDPS"] or "DPS"
    presets.dps.desc = L["InstallLayoutDPSDesc"] or "Compact raid frames, large player/target, debuff-focused"
    presets.tank.label = L["InstallLayoutTank"] or "Tank"
    presets.tank.desc = L["InstallLayoutTankDesc"] or "Wider raid frames with threat, large nameplates"
    presets.healer.label = L["InstallLayoutHealer"] or "Healer"
    presets.healer.desc = L["InstallLayoutHealerDesc"] or "Large raid frames with heal prediction, centered position"
    return presets
end

--------------------------------------------------------------------------------
-- 精靈框架
--------------------------------------------------------------------------------

local wizardFrame = nil
local currentStep = 1

-- 使用者在精靈中的選擇
local wizardChoices = {
    uiScale = 0.75,
    layout = "dps",
    actionBarFade = true,
}

--------------------------------------------------------------------------------
-- UI 建立輔助函數
--------------------------------------------------------------------------------

local function CreateWizardButton(parent, text, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or BUTTON_WIDTH, BUTTON_HEIGHT)
    LunarUI.ApplyBackdrop(btn, nil, C.bg, C.border)

    btn.text = btn:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(btn.text, 12, "OUTLINE")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(1, 1, 1)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C.bgButtonHover[1], C.bgButtonHover[2], C.bgButtonHover[3], C.bgButtonHover[4])
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    end)

    return btn
end

local function CreateLayoutButton(parent, key, preset, x, y)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(140, 70)
    btn:SetPoint("TOPLEFT", x, y)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(btn.label, 14, "OUTLINE")
    btn.label:SetPoint("TOP", 0, -10)
    btn.label:SetText(preset.label)

    btn.desc = btn:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(btn.desc, 9, "")
    btn.desc:SetPoint("TOP", btn.label, "BOTTOM", 0, -6)
    btn.desc:SetWidth(125)
    btn.desc:SetText(preset.desc)
    btn.desc:SetTextColor(C.textSecondary[1], C.textSecondary[2], C.textSecondary[3])

    btn.layoutKey = key

    local function UpdateAppearance()
        if wizardChoices.layout == key then
            btn:SetBackdropColor(C.borderGold[1], C.borderGold[2], C.borderGold[3], 0.3)
            btn:SetBackdropBorderColor(C.borderGold[1], C.borderGold[2], C.borderGold[3], 1)
            btn.label:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
            btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
            btn.label:SetTextColor(C.textSecondary[1], C.textSecondary[2], C.textSecondary[3])
        end
    end

    btn.UpdateAppearance = UpdateAppearance

    btn:SetScript("OnClick", function()
        wizardChoices.layout = key
        -- 更新所有按鈕外觀
        if parent.layoutButtons then
            for _, b in pairs(parent.layoutButtons) do
                b:UpdateAppearance()
            end
        end
    end)

    return btn
end

--------------------------------------------------------------------------------
-- 步驟內容
--------------------------------------------------------------------------------

local stepFrames = {}

local function CreateStepContainer(parent, index)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", 20, -70)
    f:SetPoint("BOTTOMRIGHT", -20, 55)
    f:Hide()
    stepFrames[index] = f
    return f
end

-- Step 1: 歡迎與 UI 縮放
local function BuildStep1(parent)
    local f = CreateStepContainer(parent, 1)

    local welcome = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(welcome, 13, "")
    welcome:SetPoint("TOPLEFT", 0, 0)
    welcome:SetWidth(WIZARD_WIDTH - 60)
    welcome:SetJustifyH("LEFT")
    welcome:SetText(
        L["InstallWelcomeBody"]
            or "Welcome to |cff8882ffLunar|r|cffffffffUI|r!\n\nThis wizard will help you configure the essential settings. You can always change these later via |cff8882ff/lunar config|r.\n"
    )
    welcome:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])

    -- UI Scale 滑桿
    local scaleLabel = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(scaleLabel, 12, "OUTLINE")
    scaleLabel:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -20)
    scaleLabel:SetText(L["InstallUIScale"] or "UI Scale")
    scaleLabel:SetTextColor(C.moonSilver[1], C.moonSilver[2], C.moonSilver[3])

    local scaleValue = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(scaleValue, 12, "OUTLINE")
    scaleValue:SetPoint("LEFT", scaleLabel, "RIGHT", 10, 0)
    scaleValue:SetTextColor(1, 1, 1)

    local slider = CreateFrame("Slider", nil, f, "BackdropTemplate")
    slider:SetSize(WIZARD_WIDTH - 80, 16)
    slider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -10)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0.50, 1.10)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)

    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    slider:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    slider:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(14, 14)
    thumb:SetColorTexture(C.accentPurple[1], C.accentPurple[2], C.accentPurple[3], C.accentPurple[4])
    slider:SetThumbTexture(thumb)

    -- 讀取當前 UI 縮放，並過濾非法值（NaN、Infinity、非數字型別）
    local currentScale = UIParent:GetEffectiveScale()
    if type(currentScale) ~= "number" or currentScale ~= currentScale or mathAbs(currentScale) == math.huge then
        currentScale = 0.75
    end
    currentScale = mathMax(0.5, mathMin(2.0, currentScale))
    wizardChoices.uiScale = mathFloor(currentScale * 20 + 0.5) / 20 -- 四捨五入到 0.05

    slider:SetValue(wizardChoices.uiScale)
    scaleValue:SetText(format("%.2f", wizardChoices.uiScale))

    slider:SetScript("OnValueChanged", function(_, val)
        val = mathFloor(val * 20 + 0.5) / 20
        wizardChoices.uiScale = val
        scaleValue:SetText(format("%.2f", val))
    end)

    -- Min / Max 標籤
    local minLabel = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(minLabel, 9, "")
    minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    minLabel:SetText("0.50")
    minLabel:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

    local maxLabel = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(maxLabel, 9, "")
    maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    maxLabel:SetText("1.10")
    maxLabel:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

    -- 提示
    local hint = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(hint, 10, "")
    hint:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -20)
    hint:SetWidth(WIZARD_WIDTH - 80)
    hint:SetJustifyH("LEFT")
    hint:SetText(
        L["InstallUIScaleTip"]
            or "|cff888888Tip: Higher values = bigger UI elements. The recommended value is 0.75 for 1920x1080.|r"
    )

    -- 暴露 slider 供 ShowInstallWizard 重開時同步值
    parent._scaleSlider = slider
    parent._scaleValue = scaleValue

    return f
end

-- Step 2: 佈局選擇
local function BuildStep2(parent)
    local f = CreateStepContainer(parent, 2)

    local title = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 13, "")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetWidth(WIZARD_WIDTH - 60)
    title:SetJustifyH("LEFT")
    title:SetText(
        L["InstallLayoutTitle"]
            or "Choose your primary role. This adjusts the size and layout of raid/party frames to match your playstyle.\n"
    )
    title:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])

    f.layoutButtons = {}
    local presets = GetLayoutPresets()
    local xPos = 0
    for _, key in ipairs({ "dps", "tank", "healer" }) do
        local btn = CreateLayoutButton(f, key, presets[key], xPos, -50)
        f.layoutButtons[key] = btn
        xPos = xPos + 150
    end

    -- 初始狀態
    for _, btn in pairs(f.layoutButtons) do
        btn:UpdateAppearance()
    end

    return f
end

-- Step 3: 動作條淡出
local function BuildStep3(parent)
    local f = CreateStepContainer(parent, 3)

    local title = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 13, "")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetWidth(WIZARD_WIDTH - 60)
    title:SetJustifyH("LEFT")
    title:SetText(
        L["InstallActionBarTitle"] or "Action Bar Options\n\nConfigure how your action bars behave outside of combat.\n"
    )
    title:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])

    -- 淡出開關
    local fadeCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    fadeCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -15)
    fadeCheck:SetSize(20, 20)
    fadeCheck:SetChecked(wizardChoices.actionBarFade)
    -- LunarUI 風格 checkbox：strip 原生材質 + 自訂邊框
    LunarUI.StripTextures(fadeCheck)
    if fadeCheck.SetNormalTexture then
        fadeCheck:SetNormalTexture("")
    end
    if fadeCheck.SetPushedTexture then
        fadeCheck:SetPushedTexture("")
    end
    if fadeCheck.SetHighlightTexture then
        fadeCheck:SetHighlightTexture("")
    end
    local checkBG = fadeCheck:CreateTexture(nil, "BACKGROUND")
    checkBG:SetAllPoints()
    checkBG:SetColorTexture(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    local checkBorder = CreateFrame("Frame", nil, fadeCheck, "BackdropTemplate")
    checkBorder:SetAllPoints()
    LunarUI.ApplyBackdrop(checkBorder, nil, { 0, 0, 0, 0 }, C.border)
    checkBorder:SetFrameLevel(fadeCheck:GetFrameLevel() + 1)
    -- 勾選標記（使用 Blizzard 材質確保字型相容性）
    local checkMark = fadeCheck:CreateTexture(nil, "OVERLAY")
    checkMark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkMark:SetAllPoints()
    checkMark:SetShown(fadeCheck:GetChecked())
    fadeCheck:SetScript("OnClick", function(self)
        wizardChoices.actionBarFade = self:GetChecked()
        checkMark:SetShown(self:GetChecked())
    end)

    local fadeLabel = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(fadeLabel, 12, "")
    fadeLabel:SetPoint("LEFT", fadeCheck, "RIGHT", 4, 0)
    fadeLabel:SetText(L["InstallActionBarFade"] or "Fade action bars when out of combat")
    fadeLabel:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])

    -- 描述
    local fadeDesc = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(fadeDesc, 10, "")
    fadeDesc:SetPoint("TOPLEFT", fadeCheck, "BOTTOMLEFT", 24, -8)
    fadeDesc:SetWidth(WIZARD_WIDTH - 100)
    fadeDesc:SetJustifyH("LEFT")
    fadeDesc:SetText(
        L["InstallActionBarFadeDesc"]
            or "|cff888888Action bars will fade to 30% opacity when you are not in combat, and instantly appear when entering combat or hovering over them.|r"
    )

    return f
end

-- Step 4: 完成
local function BuildStep4(parent)
    local f = CreateStepContainer(parent, 4)

    local title = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 14, "OUTLINE")
    title:SetPoint("TOP", 0, -20)
    title:SetText(L["InstallSummaryTitle"] or "|cff8882ffSetup Complete!|r")

    local summary = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(summary, 12, "")
    summary:SetPoint("TOP", title, "BOTTOM", 0, -20)
    summary:SetWidth(WIZARD_WIDTH - 80)
    summary:SetJustifyH("CENTER")
    summary:SetTextColor(C.textPrimary[1], C.textPrimary[2], C.textPrimary[3])

    f.summary = summary

    local hint = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(hint, 10, "")
    hint:SetPoint("BOTTOM", 0, 20)
    hint:SetWidth(WIZARD_WIDTH - 80)
    hint:SetJustifyH("CENTER")
    hint:SetText(
        L["InstallSummaryHint"]
            or '|cff888888Click "Finish" to apply settings and reload the UI.\nYou can always reconfigure via |cff8882ff/lunar config|r.|r'
    )

    return f
end

--------------------------------------------------------------------------------
-- 套用精靈選擇
--------------------------------------------------------------------------------

local function ApplyWizardSettings()
    local db = LunarUI.db
    if not db or not db.profile then
        return
    end

    -- 1. UI 縮放（持久化到 DB，確保重載後仍生效）
    db.profile.uiScale = wizardChoices.uiScale
    UIParent:SetScale(wizardChoices.uiScale)

    -- 2. 佈局預設
    local presets = GetLayoutPresets()
    local preset = presets[wizardChoices.layout]
    if preset then
        local ufDB = db.profile.unitframes
        if preset.unitframes and type(ufDB) == "table" then
            for unit, values in pairs(preset.unitframes) do
                if ufDB[unit] then
                    for k, v in pairs(values) do
                        ufDB[unit][k] = v
                    end
                end
            end
        end
        local npDB = db.profile.nameplates
        if preset.nameplates and type(npDB) == "table" then
            for k, v in pairs(preset.nameplates) do
                npDB[k] = v
            end
        end
    end

    -- 3. 動作條淡出
    if db.profile.actionbars then
        db.profile.actionbars.fadeEnabled = wizardChoices.actionBarFade
    end

    -- 4. 標記安裝完成
    db.global.installComplete = true
    db.global.installVersion = LunarUI.version
end

--------------------------------------------------------------------------------
-- 導航
--------------------------------------------------------------------------------

local function UpdateStepDisplay()
    if not wizardFrame then
        return
    end

    -- 隱藏所有步驟
    for i = 1, TOTAL_STEPS do
        if stepFrames[i] then
            stepFrames[i]:Hide()
        end
    end

    -- 顯示當前步驟
    if stepFrames[currentStep] then
        stepFrames[currentStep]:Show()
    end

    -- 更新步驟 4 摘要文字
    if currentStep == TOTAL_STEPS and stepFrames[4] and stepFrames[4].summary then
        local presets = GetLayoutPresets()
        local layoutLabel = presets[wizardChoices.layout] and presets[wizardChoices.layout].label or "DPS"
        local enabledText = L["Enabled"] or "Enabled"
        local disabledText = L["Disabled"] or "Disabled"
        stepFrames[4].summary:SetText(
            (L["InstallSummary"] or "Your settings summary:")
                .. "\n\n"
                .. format(L["InstallSummaryScale"] or "|cff8882ffUI Scale:|r %s", format("%.2f", wizardChoices.uiScale))
                .. "\n"
                .. format(L["InstallSummaryLayout"] or "|cff8882ffLayout:|r %s", layoutLabel)
                .. "\n"
                .. format(
                    L["InstallSummaryFade"] or "|cff8882ffAction Bar Fade:|r %s",
                    wizardChoices.actionBarFade and enabledText or disabledText
                )
        )
    end

    -- 更新進度指示
    for i = 1, TOTAL_STEPS do
        if wizardFrame.dots and wizardFrame.dots[i] then
            if i == currentStep then
                wizardFrame.dots[i]:SetColorTexture(C.accentPurple[1], C.accentPurple[2], C.accentPurple[3], 1)
            elseif i < currentStep then
                wizardFrame.dots[i]:SetColorTexture(C.borderGold[1], C.borderGold[2], C.borderGold[3], 1)
            else
                wizardFrame.dots[i]:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            end
        end
    end

    -- 更新按鈕狀態
    if wizardFrame.prevBtn then
        if currentStep == 1 then
            wizardFrame.prevBtn:Hide()
        else
            wizardFrame.prevBtn:Show()
        end
    end

    if wizardFrame.nextBtn then
        if currentStep == TOTAL_STEPS then
            wizardFrame.nextBtn.text:SetText(L["InstallBtnFinish"] or "Finish")
        else
            wizardFrame.nextBtn.text:SetText(L["InstallBtnNext"] or "Next")
        end
    end

    -- 更新步驟文字
    if wizardFrame.stepText then
        wizardFrame.stepText:SetText(format(L["InstallStep"] or "Step %d / %d", currentStep, TOTAL_STEPS))
    end
end

--------------------------------------------------------------------------------
-- 主框架建立
--------------------------------------------------------------------------------

-- 建立導航按鈕列（Skip / Back / Next）
local function CreateNavigationButtons(f)
    local skipBtn = CreateWizardButton(f, L["InstallBtnSkip"] or "Skip", 80)
    skipBtn:SetPoint("BOTTOM", f, "BOTTOM", -130, 15)
    skipBtn:SetScript("OnClick", function()
        if LunarUI.db and LunarUI.db.global then
            LunarUI.db.global.installComplete = true
            LunarUI.db.global.installVersion = LunarUI.version
        end
        f:Hide()
        LunarUI:Print(L["InstallSkipped"] or "Setup skipped. Use |cff8882ff/lunar config|r to configure later.")
    end)

    local prevBtn = CreateWizardButton(f, L["InstallBtnBack"] or "Back")
    prevBtn:SetPoint("BOTTOM", f, "BOTTOM", -20, 15)
    prevBtn:SetScript("OnClick", function()
        if currentStep > 1 then
            currentStep = currentStep - 1
            UpdateStepDisplay()
        end
    end)
    f.prevBtn = prevBtn

    local nextBtn = CreateWizardButton(f, L["InstallBtnNext"] or "Next")
    nextBtn:SetPoint("BOTTOM", f, "BOTTOM", 110, 15)
    nextBtn:SetScript("OnClick", function()
        if currentStep < TOTAL_STEPS then
            currentStep = currentStep + 1
            UpdateStepDisplay()
        else
            ApplyWizardSettings()
            f:Hide()
            EnsureReloadDialog()
            StaticPopup_Show("LUNARUI_INSTALL_RELOAD")
        end
    end)
    f.nextBtn = nextBtn
end

-- 建立右上角關閉按鈕
local function CreateCloseButton(f)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    LunarUI.SkinCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)
end

---@return Frame
local function CreateWizardFrame()
    -- 優先重用已存在的 WoW 框架（WoW 框架不可銷毀，避免每次開啟洩漏新框架）
    if not wizardFrame then
        wizardFrame = _G["LunarUI_InstallWizard"]
    end
    if wizardFrame then
        return wizardFrame
    end

    local f = CreateFrame("Frame", "LunarUI_InstallWizard", UIParent, "BackdropTemplate")
    f:SetSize(WIZARD_WIDTH, WIZARD_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- 背景
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(C.bgSolid[1], C.bgSolid[2], C.bgSolid[3], C.bgSolid[4])
    f:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])

    -- 頂部漸層
    local gradient = f:CreateTexture(nil, "ARTWORK", nil, 1)
    gradient:SetPoint("TOPLEFT", 1, -1)
    gradient:SetPoint("TOPRIGHT", -1, -1)
    gradient:SetHeight(50)
    gradient:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradient:SetGradient(
        "VERTICAL",
        CreateColor(C.borderGold[1], C.borderGold[2], C.borderGold[3], 0.0),
        CreateColor(C.borderGold[1], C.borderGold[2], C.borderGold[3], 0.08)
    )

    -- 標題
    local title = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 16, "OUTLINE")
    title:SetPoint("TOP", 0, -15)
    title:SetText(L["InstallTitle"] or "|cff8882ffLunar|r|cffffffffUI|r Setup")

    -- 步驟指示（圓點）
    f.dots = {}
    local dotSize = 8
    local dotSpacing = 16
    local totalDotsWidth = TOTAL_STEPS * dotSize + (TOTAL_STEPS - 1) * dotSpacing
    local dotStartX = -totalDotsWidth / 2

    for i = 1, TOTAL_STEPS do
        local dot = f:CreateTexture(nil, "ARTWORK")
        dot:SetSize(dotSize, dotSize)
        dot:SetPoint("TOP", dotStartX + (i - 1) * (dotSize + dotSpacing), -42)
        dot:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        f.dots[i] = dot
    end

    -- 步驟文字
    f.stepText = f:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(f.stepText, 10, "")
    f.stepText:SetPoint("TOP", 0, -55)
    f.stepText:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

    -- 建立各步驟內容
    BuildStep1(f)
    BuildStep2(f)
    BuildStep3(f)
    BuildStep4(f)

    -- 下方導航按鈕與關閉按鈕
    CreateNavigationButtons(f)
    CreateCloseButton(f)

    wizardFrame = f
    return f
end

--------------------------------------------------------------------------------
-- 公開 API
--------------------------------------------------------------------------------

--[[
    顯示安裝精靈
    從 Init.lua 在首次安裝時呼叫
]]
function LunarUI.ShowInstallWizard()
    -- 每次重新開啟精靈時重設狀態，uiScale 讀取當前 UI 縮放
    LunarUI.CleanupInstallWizard()
    currentStep = 1
    local currentScale = UIParent:GetEffectiveScale()
    if type(currentScale) ~= "number" or currentScale ~= currentScale or mathAbs(currentScale) == math.huge then
        currentScale = 0.75
    end
    currentScale = mathMax(0.5, mathMin(2.0, currentScale))
    wizardChoices.uiScale = mathFloor(currentScale * 20 + 0.5) / 20
    wizardChoices.layout = "dps"
    wizardChoices.actionBarFade = true
    local f = CreateWizardFrame()
    -- 重開時同步 slider 到最新 uiScale（CreateWizardFrame 重用舊框架不重跑 BuildStep1）
    if f._scaleSlider then
        f._scaleSlider:SetValue(wizardChoices.uiScale)
    end
    if f._scaleValue then
        f._scaleValue:SetText(format("%.2f", wizardChoices.uiScale))
    end
    f:Show()
    UpdateStepDisplay()
end

--[[
    檢查是否需要顯示安裝精靈
    在 OnEnable 時呼叫
]]
function LunarUI.CleanupInstallWizard()
    -- 隱藏步驟框架（不 wipe：WoW 框架不可銷毀，保留引用讓重用時步驟內容仍可顯示）
    for _, frame in pairs(stepFrames) do
        if frame and frame.Hide then
            frame:Hide()
        end
    end

    -- 隱藏主框架（不 nil：避免 CreateWizardFrame 重用全域框架但跳過 BuildStep 的回歸）
    if wizardFrame then
        wizardFrame:Hide()
    end
end

function LunarUI:CheckInstallWizard()
    if not self.db or not self.db.global then
        return
    end

    if not self.db.global.installComplete then
        -- 延遲顯示，確保所有模組已載入
        C_Timer.After(1, function()
            if not LunarUI._modulesEnabled then
                return
            end
            if self.db and self.db.global and not self.db.global.installComplete then
                self:ShowInstallWizard()
            end
        end)
    end
end

LunarUI:RegisterModule("InstallWizard", {
    onEnable = function()
        LunarUI:CheckInstallWizard()
    end,
    onDisable = function()
        LunarUI:CleanupInstallWizard()
    end,
    lifecycle = "reversible",
})
