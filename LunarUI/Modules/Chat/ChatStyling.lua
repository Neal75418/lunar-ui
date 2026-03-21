---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 聊天樣式
    聊天框架外觀、標籤、輸入框樣式化及文字複製功能
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local copyFrame
local copyEditBox

local backdropTemplate = LunarUI.backdropTemplate

--------------------------------------------------------------------------------
-- 聊天框架樣式
--------------------------------------------------------------------------------

local function StyleChatTab(chatFrame)
    local tab = _G[chatFrame:GetName() .. "Tab"]
    if not tab then
        return
    end

    -- 簡化標籤外觀
    local tabText = _G[chatFrame:GetName() .. "TabText"] or tab.Text
    if tabText then
        LunarUI.SetFont(tabText, 12, "OUTLINE")
    end

    -- 隱藏標籤材質
    local textures = {
        "Left",
        "Middle",
        "Right",
        "SelectedLeft",
        "SelectedMiddle",
        "SelectedRight",
        "HighlightLeft",
        "HighlightMiddle",
        "HighlightRight",
        "ActiveLeft",
        "ActiveMiddle",
        "ActiveRight",
    }

    for _, texName in ipairs(textures) do
        local tex = _G[tab:GetName() .. texName] or tab[texName]
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
        end
    end

    -- 樣式化光暈：隱藏但保留材質，UIFrameFlash 可在關鍵字警報時讓其閃爍
    if tab.glow then
        tab.glow:SetAlpha(0)
    end
end

local function StyleChatEditBox(chatFrame)
    local editBox = _G[chatFrame:GetName() .. "EditBox"]
    if not editBox then
        return
    end

    -- 建立背景
    if not editBox.LunarBackdrop then
        local backdrop = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
        backdrop:SetPoint("TOPLEFT", -4, 4)
        backdrop:SetPoint("BOTTOMRIGHT", 4, -4)
        LunarUI.ApplyBackdrop(backdrop)
        backdrop:SetFrameLevel(editBox:GetFrameLevel() - 1)
        editBox.LunarBackdrop = backdrop
    end

    -- 隱藏預設材質
    local textures = {
        "Left",
        "Mid",
        "Right",
        "FocusLeft",
        "FocusMid",
        "FocusRight",
    }

    for _, texName in ipairs(textures) do
        local tex = _G[editBox:GetName() .. texName] or editBox[texName]
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
        end
    end

    -- 設定輸入框位置（在聊天視窗下方）
    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -4, -8)
    editBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 4, -8)
    editBox:SetHeight(22)

    -- 設定文字樣式
    LunarUI.SetFont(editBox, 12, "")
end

local function StyleChatFrame(chatFrame)
    if not chatFrame then
        return
    end

    local name = chatFrame:GetName()
    if LunarUI._chatStyledFrames[name] then
        return
    end

    -- 建立背景
    if not chatFrame.LunarBackdrop then
        local backdrop = CreateFrame("Frame", nil, chatFrame, "BackdropTemplate")
        backdrop:SetPoint("TOPLEFT", -4, 4)
        backdrop:SetPoint("BOTTOMRIGHT", 4, -4)
        backdrop:SetBackdrop(backdropTemplate)
        backdrop:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.5)
        backdrop:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)
        backdrop:SetFrameLevel(chatFrame:GetFrameLevel() - 1)
        backdrop:SetAlpha(0)
        backdrop:Hide()
        chatFrame.LunarBackdrop = backdrop
    end

    -- 淡入淡出動畫 handler（可被 OnEnter/OnLeave 共用）
    local function startFadeAnimation(bd)
        if bd._fadeUpdate then
            return
        end
        bd._fadeUpdate = true
        bd:SetScript("OnUpdate", function(self, dt)
            local target = self._fadeTarget or 0
            local current = self:GetAlpha()
            local speed = 4 * dt -- ~0.25s fade
            if current < target then
                self:SetAlpha(math.min(current + speed, target))
            elseif current > target then
                self:SetAlpha(math.max(current - speed, target))
                if self:GetAlpha() <= 0.01 then
                    self:SetAlpha(0)
                    self:Hide()
                    self:SetScript("OnUpdate", nil)
                    self._fadeUpdate = false
                end
            else
                -- 已到達目標（淡入或淡出皆完成），卸載 OnUpdate
                self:SetScript("OnUpdate", nil)
                self._fadeUpdate = false
            end
        end)
    end

    -- 滑鼠懸停時淡入/淡出背景
    chatFrame:HookScript("OnEnter", function(self)
        if self.LunarBackdrop then
            self.LunarBackdrop:Show()
            self.LunarBackdrop._fadeTarget = 1
            self.LunarBackdrop:SetAlpha(self.LunarBackdrop:GetAlpha() or 0)
            startFadeAnimation(self.LunarBackdrop)
        end
    end)

    chatFrame:HookScript("OnLeave", function(self)
        if self.LunarBackdrop and not MouseIsOver(self) then
            self.LunarBackdrop._fadeTarget = 0
            startFadeAnimation(self.LunarBackdrop)
        end
    end)

    -- 隱藏預設材質
    for _, texName in ipairs({
        "TopLeftTexture",
        "TopRightTexture",
        "BottomLeftTexture",
        "BottomRightTexture",
        "LeftTexture",
        "RightTexture",
        "TopTexture",
        "BottomTexture",
    }) do
        local tex = _G[name .. texName]
        if tex then
            tex:SetTexture(nil)
        end
    end

    -- 隱藏預設按鈕框架（捲動/最小化按鈕）
    local buttonFrame = _G[name .. "ButtonFrame"]
    if buttonFrame then
        buttonFrame:Hide()
    end

    -- 樣式化標籤
    StyleChatTab(chatFrame)

    -- 樣式化輸入框
    StyleChatEditBox(chatFrame)

    -- 設定字型
    local font, _, flags = chatFrame:GetFont()
    chatFrame:SetFont(font or LunarUI.GetSelectedFont(), 13, flags or "")
    LunarUI.RegisterFontString(chatFrame)

    -- 啟用滑鼠滾輪捲動（使用 HookScript 避免覆蓋原有腳本）
    chatFrame:EnableMouseWheel(true)
    chatFrame:HookScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if IsShiftKeyDown() then
                self:ScrollToTop()
            elseif IsControlKeyDown() then
                self:PageUp()
            else
                self:ScrollUp()
                self:ScrollUp()
                self:ScrollUp()
            end
        else
            if IsShiftKeyDown() then
                self:ScrollToBottom()
            elseif IsControlKeyDown() then
                self:PageDown()
            else
                self:ScrollDown()
                self:ScrollDown()
                self:ScrollDown()
            end
        end
    end)

    -- 移動支援：透過標籤拖曳移動聊天框架
    chatFrame:SetMovable(true)
    chatFrame:SetClampedToScreen(true)
    local tab = _G[name .. "Tab"]
    if tab then
        tab:RegisterForDrag("LeftButton")
        tab:HookScript("OnDragStart", function()
            chatFrame:StartMoving()
        end)
        tab:HookScript("OnDragStop", function()
            chatFrame:StopMovingOrSizing()
            if _G.FCF_SavePositionAndDimensions then
                _G.FCF_SavePositionAndDimensions(chatFrame)
            end
        end)
    end

    -- 調整大小支援：右下角拖曳手柄
    if chatFrame.SetResizeBounds then
        chatFrame:SetResizeBounds(200, 80, 800, 600)
    elseif chatFrame.SetMinResize then
        chatFrame:SetMinResize(200, 80)
        chatFrame:SetMaxResize(800, 600)
    end
    local grip = CreateFrame("Button", nil, chatFrame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", 0, 0)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function()
        chatFrame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        chatFrame:StopMovingOrSizing()
        if _G.FCF_SavePositionAndDimensions then
            _G.FCF_SavePositionAndDimensions(chatFrame)
        end
    end)

    LunarUI._chatStyledFrames[name] = true
end

--------------------------------------------------------------------------------
-- 複製框架
--------------------------------------------------------------------------------

local function CreateCopyFrame()
    if copyFrame then
        return copyFrame
    end

    copyFrame = CreateFrame("Frame", "LunarUI_ChatCopy", UIParent, "BackdropTemplate")
    copyFrame:SetSize(500, 300)
    copyFrame:SetPoint("CENTER")
    LunarUI.ApplyBackdrop(copyFrame, nil, C.bgSolid)
    copyFrame:SetFrameStrata("DIALOG")
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:SetClampedToScreen(true)
    copyFrame:Hide()

    -- 標題列
    local titleBar = CreateFrame("Frame", nil, copyFrame)
    titleBar:SetHeight(24)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        copyFrame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        copyFrame:StopMovingOrSizing()
    end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(titleText, 12, "OUTLINE")
    titleText:SetPoint("LEFT", 8, 0)
    titleText:SetText("Copy Chat")
    titleText:SetTextColor(C.textSecondary[1], C.textSecondary[2], C.textSecondary[3])

    -- 關閉按鈕（使用標準模板確保點擊區域正確）
    local closeBtn = CreateFrame("Button", nil, copyFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)

    -- 捲動框架
    local scrollFrame = CreateFrame("ScrollFrame", "LunarUI_ChatCopyScroll", copyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -28)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    -- 編輯框
    copyEditBox = CreateFrame("EditBox", "LunarUI_ChatCopyEdit", scrollFrame)
    copyEditBox:SetMultiLine(true)
    copyEditBox:SetMaxLetters(99999)
    LunarUI.SetFont(copyEditBox, 12, "")
    copyEditBox:SetWidth(scrollFrame:GetWidth())
    copyEditBox:SetAutoFocus(false)
    copyEditBox:SetScript("OnEscapePressed", function()
        copyFrame:Hide()
    end)
    scrollFrame:SetScrollChild(copyEditBox)

    -- 樣式化捲軸
    local scrollBar = _G["LunarUI_ChatCopyScrollScrollBar"]
    if scrollBar then
        scrollBar:SetWidth(12)
    end

    return copyFrame
end

local function ShowCopyFrame(chatFrame)
    if not chatFrame then
        return
    end

    CreateCopyFrame()
    if not copyEditBox or not copyFrame then
        return
    end

    -- 收集聊天訊息
    local lines = {}
    local numMessages = chatFrame:GetNumMessages()

    for i = 1, numMessages do
        local message = chatFrame:GetMessageInfo(i)
        if message then
            table.insert(lines, message)
        end
    end

    -- 設定文字
    copyEditBox:SetText(table.concat(lines, "\n"))
    copyEditBox:HighlightText()
    copyEditBox:SetFocus()

    copyFrame:Show()
end

--------------------------------------------------------------------------------
-- 右鍵選單
--------------------------------------------------------------------------------

-- 透過右鍵標籤實現聊天複製功能
local function AddCopyOption()
    -- WoW 12.0：直接掛鉤每個標籤的 OnClick，而非全域 FCFTab_OnClick
    for i = 1, NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then
            tab:HookScript("OnClick", function(_self, button)
                if button == "RightButton" then
                    local chatFrame = _G["ChatFrame" .. i]
                    if chatFrame then
                        ShowCopyFrame(chatFrame)
                    end
                end
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.ChatStyleChatTab = StyleChatTab
LunarUI.ChatStyleChatEditBox = StyleChatEditBox
LunarUI.ChatStyleChatFrame = StyleChatFrame
LunarUI.ChatCreateCopyFrame = CreateCopyFrame
LunarUI.ChatShowCopyFrame = ShowCopyFrame
LunarUI.ChatAddCopyOption = AddCopyOption
