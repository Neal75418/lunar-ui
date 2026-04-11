---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, missing-parameter
--[[
    LunarUI - 動作條按鈕樣式
    按鈕外觀樣式化：NormalTexture 清除、冷卻去飽和、疊層材質、按壓閃光
    自包含模組，不依賴動作條狀態
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors

-- 按鈕樣式顏色常數
local BUTTON_COLORS = {
    pushed = { 1, 1, 1, 0.4 },
    highlight = { 1, 1, 1, 0.3 },
    checked = { 0.4, 0.6, 0.8, 0.5 },
    flash = { 1, 0.9, 0.6, 0.4 },
    disabled = { 0.4, 0.4, 0.4 },
    hotkeyText = { 0.8, 0.8, 0.8 },
}

--------------------------------------------------------------------------------
-- NormalTexture 清除
--------------------------------------------------------------------------------

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
    local snapshot = pendingNormalClear
    pendingNormalClear = {}
    for btn in pairs(snapshot) do
        if btn:GetNormalTexture() then
            ClearNormalTexture(btn)
        end
    end
end

--------------------------------------------------------------------------------
-- 冷卻去飽和批次處理
--------------------------------------------------------------------------------

-- WoW 12.0 對 GetActionCooldown 回傳密值，即使用 pcall 保護也無法比較
-- 停用自訂冷卻文字，使用內建顯示與 OmniCC 等插件

-- 批次處理冷卻去飽和（避免每次 SetCooldown 都建立 closure）
local pendingDesaturate = {}
local desaturateScheduled = false

-- P-perf: 命名函式供 pcall 呼叫，避免每 button 每 GCD 建新 closure
local function GetCooldownActive(cd)
    local s, d = cd:GetCooldownTimes()
    return s and d and s > 0 and d > 0
end

local function ProcessPendingDesaturate()
    desaturateScheduled = false
    local snapshot = pendingDesaturate
    pendingDesaturate = {}
    for btn in pairs(snapshot) do
        local cd = btn.cooldown
        local btnIcon = btn.icon or (btn:GetName() and _G[btn:GetName() .. "Icon"])
        if btnIcon and cd then
            local ok, onCD = pcall(GetCooldownActive, cd)
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
-- 按鈕樣式化函數
--------------------------------------------------------------------------------

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
    local macroName = button.Name or (name and _G[name .. "Name"])
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
-- 匯出
--------------------------------------------------------------------------------

LunarUI.ABStyleButton = StyleButton
LunarUI.ABPlayPressFlash = PlayPressFlash

-- 內部存取點：供 CleanupActionBars 重置批次處理旗標
LunarUI._ABButtonStylingState = {
    resetBatchFlags = function()
        normalClearScheduled = false
        desaturateScheduled = false
    end,
    wipePendingNormalClear = function()
        wipe(pendingNormalClear)
    end,
    wipePendingDesaturate = function()
        wipe(pendingDesaturate)
    end,
}
