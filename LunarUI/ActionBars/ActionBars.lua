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
-- 常數與輔助函數
--------------------------------------------------------------------------------

local DEFAULT_BUTTON_SIZE = 36
local DEFAULT_BUTTON_SPACING = 4

-- 從設定讀取按鈕大小
local function GetButtonSize()
    return LunarUI.db and LunarUI.db.profile.actionbars.buttonSize or DEFAULT_BUTTON_SIZE
end

-- 從設定讀取按鈕間距
local function GetButtonSpacing()
    return LunarUI.db and LunarUI.db.profile.actionbars.buttonSpacing or DEFAULT_BUTTON_SPACING
end

local backdropTemplate = LunarUI.backdropTemplate

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local bars = {}
local buttons = {}
local keybindMode = false

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
    local alpha = LunarUI.db and LunarUI.db.profile.actionbars.alpha or 1.0
    frame:SetAlpha(alpha)

    -- 背景 / 解鎖 mover（掛在 UIParent 下，避免繼承 bar 的 alpha 和 secure 框架限制）
    -- 使用純 Texture 而非 BackdropTemplate，確保在所有 WoW 版本下可見
    local bg = CreateFrame("Frame", nil, UIParent)
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    bg:SetFrameStrata("TOOLTIP")  -- 最高層級，確保可見
    bg:SetFrameLevel(0)
    -- 背景材質
    local bgTex = bg:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(0.1, 0.2, 0.5, 0.6)
    bg._bgTex = bgTex
    -- 邊框材質（四邊各 1px）
    local borderTop = bg:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT")
    borderTop:SetPoint("TOPRIGHT")
    borderTop:SetColorTexture(0.4, 0.6, 1.0, 1)
    local borderBottom = bg:CreateTexture(nil, "BORDER")
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT")
    borderBottom:SetColorTexture(0.4, 0.6, 1.0, 1)
    local borderLeft = bg:CreateTexture(nil, "BORDER")
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT")
    borderLeft:SetColorTexture(0.4, 0.6, 1.0, 1)
    local borderRight = bg:CreateTexture(nil, "BORDER")
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT")
    borderRight:SetColorTexture(0.4, 0.6, 1.0, 1)
    bg:Hide()
    frame.bg = bg

    return frame
end

local function StyleButton(button)
    if not button then return end

    -- 確認是真正的按鈕（有 GetNormalTexture 方法），非普通 Frame
    if not button.GetNormalTexture then return end

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
        local showHotkeys = LunarUI.db and LunarUI.db.profile.actionbars.showHotkeys
        if showHotkeys == false then
            hotkey:Hide()
        else
            hotkey:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
            hotkey:ClearAllPoints()
            hotkey:SetPoint("TOPRIGHT", -2, -2)
            hotkey:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    -- 巨集名稱
    local macroName = button.Name or _G[name .. "Name"]
    if macroName then
        local showMacroNames = LunarUI.db and LunarUI.db.profile.actionbars.showMacroNames
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

    -- 樣式化一般材質（隱藏預設背景）
    if normalTexture then
        normalTexture:SetTexture(nil)
        normalTexture:Hide()
    end

    -- Hook SetNormalTexture 防止拖動技能時背景重新出現
    if not button._lunarHookedNormal then
        button._lunarHookedNormal = true

        hooksecurefunc(button, "SetNormalTexture", ClearNormalTexture)

        -- WoW 12.0：也可能使用 SetNormalAtlas
        if button.SetNormalAtlas then
            hooksecurefunc(button, "SetNormalAtlas", ClearNormalTexture)
        end

        -- LAB 在 OnButtonUpdate/OnReceiveDrag 後可能重設材質
        -- Fix 6: 用 dirty flag 批次排程，避免每個按鈕都建 closure
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

    -- 冷卻框架：確保 sweep（時鐘轉圈）正常顯示
    local cooldown = button.cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(button)
        cooldown:SetDrawSwipe(true)
        cooldown:SetSwipeColor(0, 0, 0, 0.8)
        cooldown:SetDrawEdge(true)
        cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
    end

    -- 建立自訂邊框（frame level 在 cooldown 之上，但填充透明不遮蓋）
    if not button.LunarBorder then
        local borderFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
        borderFrame:SetAllPoints()
        borderFrame:SetBackdrop(backdropTemplate)
        borderFrame:SetBackdropColor(0, 0, 0, 0)
        borderFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        borderFrame:SetFrameLevel(button:GetFrameLevel() + 3)
        button.LunarBorder = borderFrame
    end

    -- 樣式化按下材質（提高可見度）
    if pushedTexture then
        pushedTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        pushedTexture:SetVertexColor(1, 1, 1, 0.4)
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

    -- 按下閃光反饋（Flash 材質）
    if button.Flash then
        button.Flash:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.Flash:SetVertexColor(1, 0.9, 0.6, 0.4)
        button.Flash:SetAllPoints()
        button.Flash:SetDrawLayer("OVERLAY")
    end
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
        ag:SetScript("OnPlay", function() flash:Show() end)
        ag:SetScript("OnFinished", function() flash:Hide() end)
        button._lunarFlashAG = ag
    end
    if button._lunarFlashAG:IsPlaying() then
        button._lunarFlashAG:Stop()
    end
    button._lunarFlash:Show()
    button._lunarFlashAG:Play()
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
        local rangeDb = LunarUI.db and LunarUI.db.profile.actionbars
        if rangeDb and rangeDb.outOfRangeColoring ~= false and button.UpdateConfig then
            button.config = button.config or {}
            button.config.outOfRangeColoring = "button"
            button.config.colors = button.config.colors or {}
            button.config.colors.range = { 0.8, 0.1, 0.1 }
            button:UpdateConfig()
        end

        bar.buttons[i] = button
        buttons[buttonName] = button
    end

    -- 主動作條（bar1）需要頁面切換 + 覆蓋條/載具隱藏
    if id == 1 then
        -- 頁面切換狀態驅動：bonusbar 用於德魯伊變形/龍騎術等
        bar:SetAttribute("_onstate-page", [[
            self:SetAttribute("state", newstate)
            control:ChildUpdate("state", newstate)
        ]])

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

    bars["bar" .. id] = bar
    return bar
end

-- 更新單個姿態按鈕的圖標和狀態
local function UpdateStanceButton(button, index)
    if not button then return end

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
            icon:SetVertexColor(0.4, 0.4, 0.4)
        end
    end
end

local function CreateStanceBar()
    local db = LunarUI.db and LunarUI.db.profile.actionbars.stancebar
    if not db or not db.enabled then return end

    local numStances = GetNumShapeshiftForms() or 0
    if numStances == 0 then return end

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
    local db = LunarUI.db and LunarUI.db.profile.actionbars.petbar
    if not db or not db.enabled then return end

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
-- 非戰鬥淡入淡出
--------------------------------------------------------------------------------

local isInCombat = false
local isBarsUnlocked = false  -- 解鎖時完全停用淡出
local fadeState = {}  -- { [barKey] = { alpha, targetAlpha, hovered, timer } }

local function GetFadeSettings()
    local db = LunarUI.db and LunarUI.db.profile.actionbars
    if not db then return false, 0.3, 2.0, 0.4 end
    return db.fadeEnabled ~= false,
           db.fadeAlpha or 0.3,
           db.fadeDelay or 2.0,
           db.fadeDuration or 0.4
end

local function IsBarFadeEnabled(barKey)
    if isBarsUnlocked then return false end
    local globalEnabled = GetFadeSettings()
    if not globalEnabled then return false end

    -- 每條 bar 可獨立覆蓋
    local db = LunarUI.db and LunarUI.db.profile.actionbars
    if db and type(db[barKey]) == "table" and db[barKey].fadeEnabled ~= nil then
        return db[barKey].fadeEnabled
    end
    return true  -- 預設跟隨全域設定
end

local function SetBarAlpha(bar, alpha)
    if not bar then return end
    -- 不在戰鬥中才修改透明度（安全考量）
    local baseAlpha = LunarUI.db and LunarUI.db.profile.actionbars.alpha or 1.0
    bar:SetAlpha(alpha * baseAlpha)
end

-- 平滑動畫框架
local fadeAnimFrame = CreateFrame("Frame")
local fadeAnimActive = false

local function UpdateFadeAnimations(_self, elapsed)
    local anyActive = false
    local _, _, _, fadeDuration = GetFadeSettings()

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
        fadeAnimFrame:SetScript("OnUpdate", nil)
    end
end

local function StartFadeAnimation()
    if fadeAnimActive then return end
    fadeAnimActive = true
    fadeAnimFrame:SetScript("OnUpdate", UpdateFadeAnimations)
end

local function FadeBarTo(barKey, targetAlpha)
    if not fadeState[barKey] then
        fadeState[barKey] = { alpha = 1.0, targetAlpha = 1.0, hovered = false, timer = nil }
    end
    fadeState[barKey].targetAlpha = targetAlpha
    StartFadeAnimation()
end

local function FadeAllBarsOut()
    local enabled, targetAlpha = GetFadeSettings()
    if not enabled then return end

    for barKey, bar in pairs(bars) do
        if bar and IsBarFadeEnabled(barKey) then
            if not fadeState[barKey] or not fadeState[barKey].hovered then
                FadeBarTo(barKey, targetAlpha)
            end
        end
    end
end

local function FadeAllBarsIn()
    for barKey, bar in pairs(bars) do
        if bar then
            FadeBarTo(barKey, 1.0)
        end
    end
end

-- 懸停偵測：使用透明遮罩框架覆蓋整條 bar
local function SetupBarHoverDetection(bar, barKey)
    if not bar or bar._lunarFadeHooked then return end
    bar._lunarFadeHooked = true

    -- 建立懸停偵測框架（覆蓋整條 bar + 邊距）
    local hoverFrame = CreateFrame("Frame", nil, bar)
    hoverFrame:SetPoint("TOPLEFT", -8, 8)
    hoverFrame:SetPoint("BOTTOMRIGHT", 8, -8)
    hoverFrame:SetFrameStrata(bar:GetFrameStrata())
    hoverFrame:SetFrameLevel(bar:GetFrameLevel() + 50)
    hoverFrame:EnableMouse(false)  -- 不攔截點擊

    -- 使用 OnUpdate 檢查滑鼠是否在區域內（不攔截點擊的方式）
    local hoverCheckElapsed = 0
    local wasHovering = false

    hoverFrame:SetScript("OnUpdate", function(_self, elapsed)
        local enabled = GetFadeSettings()
        if not enabled or isInCombat then return end
        if not IsBarFadeEnabled(barKey) then return end

        hoverCheckElapsed = hoverCheckElapsed + elapsed
        if hoverCheckElapsed < 0.05 then return end
        hoverCheckElapsed = 0

        -- 使用 MouseIsOver 檢查滑鼠位置
        local isHovering = bar:IsMouseOver(8, -8, -8, 8)

        if isHovering and not wasHovering then
            -- 滑鼠進入
            wasHovering = true
            if not fadeState[barKey] then
                fadeState[barKey] = { alpha = 1.0, targetAlpha = 1.0, hovered = false, timer = nil }
            end
            fadeState[barKey].hovered = true
            -- 取消延遲淡出計時器
            if fadeState[barKey].timer then
                fadeState[barKey].timer:Cancel()
                fadeState[barKey].timer = nil
            end
            FadeBarTo(barKey, 1.0)
        elseif not isHovering and wasHovering then
            -- 滑鼠離開
            wasHovering = false
            if fadeState[barKey] then
                fadeState[barKey].hovered = false
            end
            -- 延遲淡出
            local _, fadeAlpha, fadeDelay = GetFadeSettings()
            if fadeState[barKey] and fadeState[barKey].timer then
                fadeState[barKey].timer:Cancel()
            end
            if not fadeState[barKey] then
                fadeState[barKey] = { alpha = 1.0, targetAlpha = 1.0, hovered = false, timer = nil }
            end
            fadeState[barKey].timer = C_Timer.NewTimer(fadeDelay, function()
                if not isInCombat and not fadeState[barKey].hovered then
                    FadeBarTo(barKey, fadeAlpha)
                end
                fadeState[barKey].timer = nil
            end)
        end
    end)

    bar._lunarHoverFrame = hoverFrame
end

-- 戰鬥事件
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:SetScript("OnEvent", function(_self, event)
    local enabled = GetFadeSettings()
    if not enabled then return end

    if event == "PLAYER_REGEN_DISABLED" then
        -- 進入戰鬥：全部淡入
        isInCombat = true
        FadeAllBarsIn()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 離開戰鬥：延遲淡出
        isInCombat = false
        local _, _, fadeDelay = GetFadeSettings()
        C_Timer.After(fadeDelay, function()
            if not isInCombat then
                FadeAllBarsOut()
            end
        end)
    end
end)

-- 初始化淡出狀態（非戰鬥時啟動淡出）
local function InitializeFade()
    local enabled = GetFadeSettings()
    if not enabled then return end

    -- 為每條 bar 設定懸停偵測
    for barKey, bar in pairs(bars) do
        SetupBarHoverDetection(bar, barKey)
    end

    -- 非戰鬥中立即啟動淡出
    if not InCombatLockdown() then
        isInCombat = false
        local _, _, fadeDelay = GetFadeSettings()
        C_Timer.After(fadeDelay, function()
            if not isInCombat then
                FadeAllBarsOut()
            end
        end)
    else
        isInCombat = true
    end
end

-- 匯出更新函數（供 Config 面板即時更新）
function LunarUI:UpdateActionBarFade()
    local enabled = GetFadeSettings()
    if enabled then
        if not isInCombat then
            FadeAllBarsOut()
        end
    else
        -- 停用時恢復全部透明度
        FadeAllBarsIn()
    end
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

-- 遞迴隱藏框架及其所有子框架/區域
local function HideFrameRecursive(frame)
    if not frame then return end
    -- 跳過 OverrideActionBar，飛龍騎術等需要它
    if frame == OverrideActionBar then return end
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
        for key, value in pairs(MainMenuBarArtFrame) do
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
                local origSetScale = bar.SetScale
                bar.SetScale = function(self, scale, ...)
                    if not scale or scale <= 0 then
                        scale = 0.001
                    end
                    return origSetScale(self, scale, ...)
                end
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
        "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer",
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

    -- 搜尋全域變數中所有可能的獅鷲/EndCap 框架
    local gryphonPatterns = {"Gryphon", "EndCap", "LeftCap", "RightCap", "MainMenuBarArt"}
    for globalName, globalValue in pairs(_G) do
        if type(globalName) == "string" and type(globalValue) == "table" then
            for _, pattern in ipairs(gryphonPatterns) do
                if globalName:find(pattern) then
                    -- 對所有匹配的框架/材質使用強力隱藏
                    HideTextureForcefully(globalValue)
                    if globalValue.SetAlpha then
                        pcall(function() globalValue:SetAlpha(0) end)
                    end
                    if globalValue.Hide then
                        pcall(function() globalValue:Hide() end)
                    end
                    break
                end
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

--------------------------------------------------------------------------------
-- ExtraActionButton 樣式化（世界任務/場景等特殊按鈕）
--------------------------------------------------------------------------------

local function StyleExtraActionButton()
    local db = LunarUI.db and LunarUI.db.profile.actionbars
    if not db or db.extraActionButton == false then return end

    local extra = ExtraActionBarFrame
    if not extra then return end

    -- 重新定位至畫面中下方
    extra:SetParent(UIParent)
    extra:ClearAllPoints()
    extra:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)

    -- 停止暴雪預設進場動畫（intro 是 AnimationGroup，無 SetAlpha）
    if extra.intro and extra.intro.Stop then
        extra.intro:Stop()
    end

    -- 遍歷區域，隱藏裝飾材質
    for _, region in ipairs({ extra:GetRegions() }) do
        if region and region:IsObjectType("Texture") then
            local atlas = region.GetAtlas and region:GetAtlas()
            -- 保留按鈕圖示本身，隱藏背景裝飾
            if atlas and (atlas:find("ExtraAbility") or atlas:find("extraability")) then
                region:SetAlpha(0)
            end
        end
    end

    -- 樣式化 ExtraActionButton1
    local btn = ExtraActionButton1
    if not btn then return end

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
    local db = LunarUI.db and LunarUI.db.profile.actionbars
    if not db or db.extraActionButton == false then return end

    local zone = ZoneAbilityFrame
    if not zone then return end

    -- 重新定位
    zone:SetParent(UIParent)
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
    local db = LunarUI.db and LunarUI.db.profile.actionbars.microBar
    if not db or not db.enabled then return end
    if InCombatLockdown() then return end

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
    }
    for _, btnName in ipairs(microButtonNames) do
        local btn = _G[btnName]
        if btn then
            table.insert(MICRO_BUTTONS, btn)
        end
    end

    if #MICRO_BUTTONS == 0 then return end

    -- 建立容器
    local microBar = CreateFrame("Frame", "LunarUI_MicroBar", UIParent)
    local btnWidth = db.buttonWidth or 28
    local btnHeight = db.buttonHeight or 36
    local spacing = 1
    local totalWidth = #MICRO_BUTTONS * btnWidth + (#MICRO_BUTTONS - 1) * spacing

    microBar:SetSize(totalWidth, btnHeight)
    microBar:SetPoint(
        db.point or "BOTTOM",
        UIParent,
        db.point or "BOTTOM",
        db.x or 0,
        db.y or 2
    )
    microBar:SetFrameStrata("MEDIUM")
    microBar:SetClampedToScreen(true)

    -- 儲存按鈕參照以供清理用
    microBar._buttons = MICRO_BUTTONS

    -- 重新排列微型按鈕
    for i, btn in ipairs(MICRO_BUTTONS) do
        -- 儲存原始父框架以供清理還原
        btn._lunarOriginalParent = btn:GetParent()

        btn:SetParent(microBar)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", microBar, "LEFT", (i - 1) * (btnWidth + spacing), 0)
        btn:SetSize(btnWidth, btnHeight)
        btn:Show()

        -- 隱藏暴雪裝飾材質
        for _, region in ipairs({ btn:GetRegions() }) do
            if region and region:IsObjectType("Texture") then
                local texName = region:GetDebugName() or ""
                -- 保留圖示材質，隱藏背景/邊框/發光
                if texName:find("Background") or texName:find("Flash") or texName:find("Highlight") then
                    region:SetAlpha(0)
                end
            end
        end
    end

    -- 月相感知透明度
    microBar._lunarMinAlpha = 0.3

    bars.microBar = microBar
end

-- 微型按鈕列清理
local function CleanupMicroBar()
    if bars.microBar then
        -- 還原按鈕至原始父框架
        for _, btn in ipairs(bars.microBar._buttons or {}) do
            if btn._lunarOriginalParent then
                btn:SetParent(btn._lunarOriginalParent)
                btn._lunarOriginalParent = nil
            end
        end
        bars.microBar:Hide()
        bars.microBar = nil
    end
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

    -- 樣式化額外動作按鈕
    StyleExtraActionButton()
    StyleZoneAbilityButton()

    -- 微型按鈕列
    CreateMicroBar()

    -- 註冊月相更新
    RegisterBarPhaseCallback()

    -- 套用初始月相
    UpdateAllBarsForPhase()

    -- 初始化淡入淡出系統
    C_Timer.After(1.0, InitializeFade)
end

-- 清理函數
local function CleanupActionBars()
    -- 還原 ExtraActionBarFrame
    if ExtraActionBarFrame and bars.extraActionButton then
        if ExtraActionBarFrame.intro then
            ExtraActionBarFrame.intro:SetAlpha(1)
        end
        bars.extraActionButton = nil
    end

    -- 還原 ZoneAbilityFrame
    if ZoneAbilityFrame and bars.zoneAbilityButton then
        if ZoneAbilityFrame.Style then
            ZoneAbilityFrame.Style:SetAlpha(1)
        end
        bars.zoneAbilityButton = nil
    end

    -- 清理微型按鈕列
    CleanupMicroBar()
end

-- 匯出
LunarUI.SpawnActionBars = SpawnActionBars
LunarUI.EnterKeybindMode = EnterKeybindMode
LunarUI.ExitKeybindMode = ExitKeybindMode
LunarUI.CleanupActionBars = CleanupActionBars
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

--------------------------------------------------------------------------------
-- 動作條拖曳功能
--------------------------------------------------------------------------------

-- 動作條名稱對照
local barNames = {
    bar1 = "動作條 1",
    bar2 = "動作條 2",
    bar3 = "動作條 3",
    bar4 = "動作條 4",
    bar5 = "動作條 5",
    bar6 = "動作條 6",
    petbar = "寵物條",
    stancebar = "姿態條",
}

local function EnableBarDragging(bar)
    if not bar or not bar.bg then return end

    local bg = bar.bg

    -- 顯示 mover
    bg:Show()
    bg:EnableMouse(true)
    bg:SetMovable(true)
    bg:SetClampedToScreen(true)
    bg:RegisterForDrag("LeftButton")

    -- 拖曳邏輯：移動 bg 本身（而非 secure bar），避免 SecureHandlerStateTemplate 限制
    bg:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        -- 解除 bg 對 bar 的錨定，改為固定位置，然後開始移動 bg
        local left, bottom = bar:GetLeft(), bar:GetBottom()
        if not left or not bottom then return end
        self:ClearAllPoints()
        self:SetSize(bar:GetWidth() + 8, bar:GetHeight() + 8)
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - 4, bottom - 4)
        self:StartMoving()
    end)

    bg:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- 從 bg 的位置反推 bar 的 BOTTOM 座標
        local bgLeft = self:GetLeft()
        local bgBottom = self:GetBottom()
        if bgLeft and bgBottom then
            local barLeft = bgLeft + 4
            local barBottom = bgBottom + 4
            local screenCenterX = UIParent:GetWidth() / 2
            local barCenterX = barLeft + bar:GetWidth() / 2
            local x = barCenterX - screenCenterX
            local y = barBottom
            -- 重新定位 bar
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOM", UIParent, "BOTTOM", x, y)
            -- 保存到 DB
            if bar.dbKey and LunarUI.db then
                local db = LunarUI.db.profile.actionbars[bar.dbKey]
                if db then
                    db.x = math.floor(x + 0.5)
                    db.y = math.floor(y + 0.5)
                    LunarUI:Debug("位置已保存: " .. bar.dbKey .. " x=" .. db.x .. " y=" .. db.y)
                end
            end
        end
        -- 重新錨定 bg 到 bar
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
        self:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
    end)

    -- 建立或顯示標籤
    if not bar.label then
        local label = bg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("CENTER")
        label:SetTextColor(1, 1, 1, 1)
        bar.label = label
    end
    local name = barNames[bar.dbKey] or bar.dbKey or "動作條"
    bar.label:SetText(name)
    bar.label:Show()
end

local function DisableBarDragging(bar)
    if not bar then return end

    -- 隱藏標籤
    if bar.label then
        bar.label:Hide()
    end

    -- 停用背景拖曳
    if bar.bg then
        bar.bg:EnableMouse(false)
        bar.bg:SetScript("OnDragStart", nil)
        bar.bg:SetScript("OnDragStop", nil)
        -- 重新錨定 bg 到 bar（確保位置正確）
        bar.bg:ClearAllPoints()
        bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
        bar.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
        bar.bg:Hide()
    end
end

function LunarUI:ToggleActionBarLock(locked)
    if InCombatLockdown() then
        self:Print("戰鬥中無法解鎖動作條")
        return
    end

    for _name, bar in pairs(bars) do
        if bar then
            if locked then
                DisableBarDragging(bar)
            else
                -- 解鎖時先恢復完整透明度（否則 bg 繼承父 alpha 幾乎不可見）
                bar:SetAlpha(1.0)
                EnableBarDragging(bar)
            end
        end
    end

    if locked then
        isBarsUnlocked = false
        -- 重啟淡出系統
        if LunarUI.UpdateActionBarFade then
            LunarUI:UpdateActionBarFade()
        end
        self:Print("動作條已鎖定")
    else
        isBarsUnlocked = true
        -- 完全停用淡出動畫，確保 mover 可見
        fadeAnimActive = false
        fadeAnimFrame:SetScript("OnUpdate", nil)
        for barKey in pairs(fadeState) do
            fadeState[barKey].alpha = 1.0
            fadeState[barKey].targetAlpha = 1.0
        end
        self:Print("動作條已解鎖，可拖曳移動")
    end
end
