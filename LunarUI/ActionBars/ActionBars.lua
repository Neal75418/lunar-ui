---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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
    if not Masque or InCombatLockdown() then return nil end
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
    return LunarUI.db.profile.actionbars.buttonSize or DEFAULT_BUTTON_SIZE
end

-- 從設定讀取按鈕間距
local function GetButtonSpacing()
    return LunarUI.db.profile.actionbars.buttonSpacing or DEFAULT_BUTTON_SPACING
end



--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local bars = {}
local buttons = {}
local keybindMode = false
local microMenuLayoutHooked = false

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
    local alpha = LunarUI.db.profile.actionbars.alpha or 1.0
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
    if hotkey then
        local showHotkeys = LunarUI.db.profile.actionbars.showHotkeys
        if showHotkeys == false then
            hotkey:Hide()
        else
            LunarUI.SetFont(hotkey, 10, "OUTLINE")
            hotkey:ClearAllPoints()
            hotkey:SetPoint("TOPRIGHT", -2, -2)
            hotkey:SetTextColor(0.8, 0.8, 0.8)
        end
    end

    -- 巨集名稱
    local macroName = button.Name or _G[name .. "Name"]
    if macroName then
        local showMacroNames = LunarUI.db.profile.actionbars.showMacroNames
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

        -- 冷卻中圖示去飽和（變灰）— 使用 dirty flag 批次處理避免 GC 壓力
        if not button._lunarHookedCooldown then
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
    end

    -- 建立自訂邊框（frame level 在 cooldown 之上，但填充透明不遮蓋）
    if not button.LunarBorder then
        local borderFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
        borderFrame:SetAllPoints()
        LunarUI.ApplyBackdrop(borderFrame, nil, C.transparent)
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
        ag:SetScript("OnPlay", function() button._lunarFlash:Show() end)
        ag:SetScript("OnFinished", function() button._lunarFlash:Hide() end)
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

local function CreateActionBar(id, page)
    local db = LunarUI.db.profile.actionbars["bar" .. id]
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
        local rangeDb = LunarUI.db.profile.actionbars
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
    local db = LunarUI.db.profile.actionbars.stancebar
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
    local db = LunarUI.db.profile.actionbars.petbar
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
local isBarsUnlocked = false  -- 解鎖時完全停用淡出
local fadeInitialized = false
local fadeState = {}  -- { [barKey] = { alpha, targetAlpha, hovered, timer } }

local function GetFadeSettings()
    local db = LunarUI.db.profile.actionbars
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
    local db = LunarUI.db.profile.actionbars
    if db and type(db[barKey]) == "table" and db[barKey].fadeEnabled ~= nil then
        return db[barKey].fadeEnabled
    end
    return true  -- 預設跟隨全域設定
end

local function SetBarAlpha(bar, alpha)
    if not bar then return end
    -- 不在戰鬥中才修改透明度（安全考量）
    local baseAlpha = LunarUI.db.profile.actionbars.alpha or 1.0
    bar:SetAlpha(alpha * baseAlpha)
end

-- 平滑動畫框架
local fadeAnimFrame = CreateFrame("Frame")
local fadeAnimActive = false
local cachedFadeDuration = 0.4  -- 由 StartFadeAnimation 快取，動畫期間設定不會變

local function UpdateFadeAnimations(_self, elapsed)
    local anyActive = false
    local fadeDuration = cachedFadeDuration

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
    local _, _, _, dur = GetFadeSettings()
    cachedFadeDuration = dur or 0.4
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
local combatFrame = LunarUI.CreateEventHandler(
    {"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"},
    function(_self, event)
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
                if not fadeInitialized then return end
                if not isInCombat then
                    FadeAllBarsOut()
                end
            end)
        end
    end
)

-- 初始化淡出狀態（非戰鬥時啟動淡出）
local function InitializeFade()
    if not combatFrame then return end  -- 模組已 cleanup
    local enabled = GetFadeSettings()
    if not enabled then return end
    fadeInitialized = true

    -- 為每條 bar 設定懸停偵測
    for barKey, bar in pairs(bars) do
        SetupBarHoverDetection(bar, barKey)
    end

    -- 非戰鬥中立即啟動淡出
    if not InCombatLockdown() then
        isInCombat = false
        local _, _, fadeDelay = GetFadeSettings()
        C_Timer.After(fadeDelay, function()
            if not fadeInitialized then return end
            if not isInCombat then
                FadeAllBarsOut()
            end
        end)
    else
        isInCombat = true
    end
end

-- 匯出更新函數（供 Config 面板即時更新）
function LunarUI.UpdateActionBarFade()
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
    if InCombatLockdown() then
        LunarUI:Print(L["KeybindCombatLocked"] or "Cannot change keybinds during combat")
        return
    end
    if keybindMode then return end
    keybindMode = true

    for _name, button in pairs(buttons) do
        -- 跳過無法獨立綁定的 bar（如 bar2 主動作條第二頁）
        local barId = button and button:GetParent() and button:GetParent().id
        if button and (not barId or BINDING_FORMATS[barId]) then
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
    if not keybindMode then return end
    keybindMode = false

    for _name, button in pairs(buttons) do
        if button then
            -- 重設邊框
            if button.LunarBorder then
                button.LunarBorder:SetBackdropBorderColor(unpack(C.border))
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
-- 隱藏暴雪動作條（已提取至 HideBlizzardBars.lua）
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- ExtraActionButton 樣式化（世界任務/場景等特殊按鈕）
--------------------------------------------------------------------------------

local function StyleExtraActionButton()
    if InCombatLockdown() then return end  -- 防禦性：避免戰鬥中操作 EditMode 管理的框架
    local db = LunarUI.db.profile.actionbars
    if db.extraActionButton == false then return end

    local extra = _G.ExtraActionBarFrame
    if not extra then return end

    -- 重新定位至畫面中下方
    -- 不使用 SetParent（會造成 taint），僅重新定位
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
    local btn = _G.ExtraActionButton1
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
    if InCombatLockdown() then return end  -- 防禦性：避免戰鬥中操作 EditMode 管理的框架
    local db = LunarUI.db.profile.actionbars
    if db.extraActionButton == false then return end

    local zone = _G.ZoneAbilityFrame
    if not zone then return end

    -- 重新定位
    -- 不使用 SetParent（會造成 taint），僅重新定位
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
    local db = LunarUI.db.profile.actionbars.microBar
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
        "HelpMicroButton",
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
        -- 不使用 SetParent（會造成 taint），僅重新定位按鈕
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

    -- 不使用 Hide()（會連帶隱藏子按鈕）也不用 SetParent（造成 taint）
    -- 將 MicroMenu 移至螢幕外，按鈕仍以 SetPoint 錨定至 microBar 正常顯示
    if _G.MicroMenu then
        _G.MicroMenu:ClearAllPoints()
        _G.MicroMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -9999, -9999)
        _G.MicroMenu:EnableMouse(false)
        -- Hook Layout 防止暴雪代碼重新排列按鈕位置
        if _G.MicroMenu.Layout and not microMenuLayoutHooked then
            microMenuLayoutHooked = true
            hooksecurefunc(_G.MicroMenu, "Layout", function()
                if bars.microBar and bars.microBar._buttons and not InCombatLockdown() then
                    for idx, mbtn in ipairs(bars.microBar._buttons) do
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
        bars.microBar:Hide()
        bars.microBar = nil
        -- 還原 MicroMenu（Layout hook 因 bars.microBar=nil 自動停止介入）
        if _G.MicroMenu and not InCombatLockdown() then
            _G.MicroMenu:EnableMouse(true)
            -- 完整恢復 MicroMenu 位置與按鈕佈局需 /reload
        end
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function SpawnActionBars()
    local db = LunarUI.db.profile.actionbars
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
        if state and state.timer then
            state.timer:Cancel()
            state.timer = nil
        end
    end
    wipe(fadeState)
    wipe(pendingNormalClear)
    wipe(pendingDesaturate)

    -- 解除戰鬥事件監聽
    if combatFrame then
        combatFrame:UnregisterAllEvents()
        combatFrame = nil
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
        bars.extraActionButton = nil
    end

    -- 還原 ZoneAbilityFrame
    if _G.ZoneAbilityFrame and bars.zoneAbilityButton then
        if _G.ZoneAbilityFrame.Style then
            _G.ZoneAbilityFrame.Style:SetAlpha(1)
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
            LunarUI.UpdateActionBarFade()
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
