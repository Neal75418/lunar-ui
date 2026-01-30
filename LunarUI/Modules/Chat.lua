---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if, missing-parameter
--[[
    LunarUI - 聊天模組
    Lunar 主題風格的聊天框架

    功能：
    - 手繪風格邊框
    - 改良頻道顏色
    - 文字複製功能
    - 網址偵測與可點擊連結
    - 職業著色名稱
    - 月相感知淡出
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local CHAT_FRAMES = { "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4", "ChatFrame5", "ChatFrame6", "ChatFrame7" }

local backdropTemplate = LunarUI.backdropTemplate

-- 改良頻道顏色
local CHANNEL_COLORS = {
    SAY = { 1.0, 1.0, 1.0 },
    YELL = { 1.0, 0.25, 0.25 },
    EMOTE = { 1.0, 0.5, 0.25 },
    WHISPER = { 1.0, 0.5, 1.0 },
    WHISPER_INFORM = { 1.0, 0.5, 1.0 },
    BN_WHISPER = { 0.0, 0.7, 1.0 },
    BN_WHISPER_INFORM = { 0.0, 0.7, 1.0 },
    PARTY = { 0.67, 0.67, 1.0 },
    PARTY_LEADER = { 0.47, 0.78, 1.0 },
    RAID = { 1.0, 0.5, 0.0 },
    RAID_LEADER = { 1.0, 0.28, 0.04 },
    RAID_WARNING = { 1.0, 0.28, 0.0 },
    INSTANCE_CHAT = { 1.0, 0.5, 0.0 },
    INSTANCE_CHAT_LEADER = { 1.0, 0.28, 0.04 },
    GUILD = { 0.25, 1.0, 0.25 },
    OFFICER = { 0.25, 0.75, 0.25 },
    CHANNEL = { 1.0, 0.75, 0.75 },
    LOOT = { 0.0, 0.67, 0.0 },
    MONEY = { 1.0, 1.0, 0.0 },
    COMBAT_XP_GAIN = { 0.43, 0.43, 1.0 },
    COMBAT_HONOR_GAIN = { 0.88, 0.67, 0.22 },
    SYSTEM = { 1.0, 1.0, 0.0 },
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local styledFrames = {}
local copyFrame
local copyEditBox

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

-- 保留供未來使用
local function _GetClassColor(class)
    if class and RAID_CLASS_COLORS[class] then
        return RAID_CLASS_COLORS[class]
    end
    return { r = 1, g = 1, b = 1 }
end

--------------------------------------------------------------------------------
-- 聊天框架樣式
--------------------------------------------------------------------------------

local function StyleChatTab(chatFrame)
    local tab = _G[chatFrame:GetName() .. "Tab"]
    if not tab then return end

    -- 簡化標籤外觀
    local tabText = _G[chatFrame:GetName() .. "TabText"] or tab.Text
    if tabText then
        tabText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    end

    -- 隱藏標籤材質
    local textures = {
        "Left", "Middle", "Right",
        "SelectedLeft", "SelectedMiddle", "SelectedRight",
        "HighlightLeft", "HighlightMiddle", "HighlightRight",
        "ActiveLeft", "ActiveMiddle", "ActiveRight",
    }

    for _, texName in ipairs(textures) do
        local tex = _G[tab:GetName() .. texName] or tab[texName]
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
        end
    end

    -- 樣式化光暈
    if tab.glow then
        tab.glow:SetTexture(nil)
    end
end

local function StyleChatEditBox(chatFrame)
    local editBox = _G[chatFrame:GetName() .. "EditBox"]
    if not editBox then return end

    -- 建立背景
    if not editBox.LunarBackdrop then
        local backdrop = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
        backdrop:SetPoint("TOPLEFT", -4, 4)
        backdrop:SetPoint("BOTTOMRIGHT", 4, -4)
        backdrop:SetBackdrop(backdropTemplate)
        backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
        backdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        backdrop:SetFrameLevel(editBox:GetFrameLevel() - 1)
        editBox.LunarBackdrop = backdrop
    end

    -- 隱藏預設材質
    local textures = {
        "Left", "Mid", "Right",
        "FocusLeft", "FocusMid", "FocusRight",
    }

    for _, texName in ipairs(textures) do
        local tex = _G[editBox:GetName() .. texName] or editBox[texName]
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
        end
    end

    -- 設定輸入框位置
    editBox:ClearAllPoints()
    editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -4, 8)
    editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 4, 8)
    editBox:SetHeight(22)

    -- 設定文字樣式
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
end

local function StyleChatFrame(chatFrame)
    if not chatFrame then return end

    local name = chatFrame:GetName()
    if styledFrames[name] then return end

    -- 建立背景
    if not chatFrame.LunarBackdrop then
        local backdrop = CreateFrame("Frame", nil, chatFrame, "BackdropTemplate")
        backdrop:SetPoint("TOPLEFT", -4, 4)
        backdrop:SetPoint("BOTTOMRIGHT", 4, -4)
        backdrop:SetBackdrop(backdropTemplate)
        backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
        backdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.6)
        backdrop:SetFrameLevel(chatFrame:GetFrameLevel() - 1)
        backdrop:SetAlpha(0)
        backdrop:Hide()
        chatFrame.LunarBackdrop = backdrop
    end

    -- 滑鼠懸停時淡入/淡出背景
    chatFrame:HookScript("OnEnter", function(self)
        if self.LunarBackdrop then
            self.LunarBackdrop:Show()
            self.LunarBackdrop._fadeTarget = 1
            if not self.LunarBackdrop._fadeUpdate then
                self.LunarBackdrop._fadeUpdate = true
                self.LunarBackdrop:SetScript("OnUpdate", function(bd, dt)
                    local target = bd._fadeTarget or 0
                    local current = bd:GetAlpha()
                    local speed = 4 * dt  -- ~0.25s fade
                    if current < target then
                        bd:SetAlpha(math.min(current + speed, target))
                    elseif current > target then
                        bd:SetAlpha(math.max(current - speed, target))
                        if bd:GetAlpha() <= 0.01 then
                            bd:SetAlpha(0)
                            bd:Hide()
                        end
                    end
                end)
            end
            self.LunarBackdrop:SetAlpha(self.LunarBackdrop:GetAlpha() or 0)
        end
    end)

    chatFrame:HookScript("OnLeave", function(self)
        if self.LunarBackdrop and not MouseIsOver(self) then
            self.LunarBackdrop._fadeTarget = 0
        end
    end)

    -- 隱藏預設材質
    for _, texName in ipairs({ "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
                               "LeftTexture", "RightTexture", "TopTexture", "BottomTexture" }) do
        local tex = _G[name .. texName]
        if tex then
            tex:SetTexture(nil)
        end
    end

    -- 樣式化按鈕框架
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
    chatFrame:SetFont(font or STANDARD_TEXT_FONT, 13, flags or "")

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

    styledFrames[name] = true
end

--------------------------------------------------------------------------------
-- 複製框架
--------------------------------------------------------------------------------

local function CreateCopyFrame()
    if copyFrame then return copyFrame end

    copyFrame = CreateFrame("Frame", "LunarUI_ChatCopy", UIParent, "BackdropTemplate")
    copyFrame:SetSize(500, 300)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetBackdrop(backdropTemplate)
    copyFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    copyFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
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
    titleBar:SetScript("OnDragStart", function() copyFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() copyFrame:StopMovingOrSizing() end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    titleText:SetPoint("LEFT", 8, 0)
    titleText:SetText("Copy Chat")
    titleText:SetTextColor(0.9, 0.9, 0.9)

    -- 關閉按鈕
    local closeBtn = CreateFrame("Button", nil, copyFrame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -4, -2)
    closeBtn:SetNormalFontObject(GameFontNormal)
    closeBtn:SetText("×")
    closeBtn:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    closeBtn:SetScript("OnClick", function() copyFrame:Hide() end)

    -- 捲動框架
    local scrollFrame = CreateFrame("ScrollFrame", "LunarUI_ChatCopyScroll", copyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -28)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    -- 編輯框
    copyEditBox = CreateFrame("EditBox", "LunarUI_ChatCopyEdit", scrollFrame)
    copyEditBox:SetMultiLine(true)
    copyEditBox:SetMaxLetters(99999)
    copyEditBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    copyEditBox:SetWidth(scrollFrame:GetWidth())
    copyEditBox:SetAutoFocus(false)
    copyEditBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    scrollFrame:SetScrollChild(copyEditBox)

    -- 樣式化捲軸
    local scrollBar = _G["LunarUI_ChatCopyScrollScrollBar"]
    if scrollBar then
        scrollBar:SetWidth(12)
    end

    return copyFrame
end

local function ShowCopyFrame(chatFrame)
    if not chatFrame then return end

    CreateCopyFrame()

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
-- 頻道顏色
--------------------------------------------------------------------------------

local function ApplyChannelColors()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.improvedColors then return end

    for channel, color in pairs(CHANNEL_COLORS) do
        ChangeChatColor(channel, color[1], color[2], color[3])
    end
end

--------------------------------------------------------------------------------
-- 職業著色名稱
--------------------------------------------------------------------------------

local function EnableClassColoredNames()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.classColors then return end

    -- 由暴雪選項處理，我們只需啟用它
    for _, chatType in ipairs({
        "SAY", "EMOTE", "YELL", "WHISPER", "WHISPER_INFORM",
        "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
        "GUILD", "OFFICER", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
        "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5",
    }) do
        SetChatColorNameByClass(chatType, true)
    end
end

--------------------------------------------------------------------------------
-- 網址偵測
--------------------------------------------------------------------------------

-- 可點擊網址
local URL_PATTERNS = {
    -- 完整網址（含協定）
    "(https?://[%w%.%-_~:/?#%[%]@!$&'()*+,;=%%]+)",
    -- www 網址
    "(www%.[%w%.%-_~:/?#%[%]@!$&'()*+,;=%%]+)",
    -- 電子郵件
    "([%w%.%-_]+@[%w%.%-_]+%.%w+)",
}

-- 格式化網址為可點擊的超連結
local function FormatURL(url)
    -- 使用 LunarURL 作為自訂超連結類型
    return format("|cff3399ff|HLunarURL:%s|h[%s]|h|r", url, url)
end

-- 過濾函數：偵測網址並轉換為可點擊連結
local function AddURLsToMessage(_self, _event, msg, ...)
    if not msg then return false, msg, ... end

    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.detectURLs then return false, msg, ... end

    local newMsg = msg
    for _, pattern in ipairs(URL_PATTERNS) do
        newMsg = newMsg:gsub(pattern, FormatURL)
    end

    if newMsg ~= msg then
        return false, newMsg, ...
    end

    return false, msg, ...
end

-- 處理網址超連結點擊
local function HandleURLClick(_self, link, _text, _button)
    if not link then return end

    local linkType, url = strsplit(":", link, 2)
    if linkType == "LunarURL" and url then
        -- 使用本地化字串顯示網址複製彈窗
        local popupText = L["PressToCopyURL"] or "Press Ctrl+C to copy URL:"
        local closeText = CLOSE or "Close"  -- 使用暴雪全域 CLOSE 字串

        -- 建立彈窗以顯示並複製網址
        StaticPopupDialogs["LUNARUI_URL_COPY"] = StaticPopupDialogs["LUNARUI_URL_COPY"] or {
            text = popupText,
            button1 = closeText,
            hasEditBox = true,
            editBoxWidth = 280,
            OnShow = function(popup, data)
                popup.editBox:SetText(data)
                popup.editBox:HighlightText()
                popup.editBox:SetFocus()
            end,
            EditBoxOnEnterPressed = function(editBox)
                editBox:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(editBox)
                editBox:GetParent():Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }

        StaticPopup_Show("LUNARUI_URL_COPY", nil, nil, url)
        return true
    end
end

-- 為所有聊天事件註冊網址過濾器
local function RegisterURLFilter()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.detectURLs then return end

    local chatEvents = {
        "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
        "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
        "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
        "CHAT_MSG_CHANNEL",
    }

    for _, event in ipairs(chatEvents) do
        ChatFrame_AddMessageEventFilter(event, AddURLsToMessage)
    end

    -- 掛鉤所有聊天框架的超連結處理器
    local originalHandler = ChatFrame_OnHyperlinkShow
    ---@diagnostic disable-next-line: lowercase-global
    ChatFrame_OnHyperlinkShow = function(self, link, text, button)
        if HandleURLClick(self, link, text, button) then
            return
        end
        if originalHandler then
            return originalHandler(self, link, text, button)
        end
    end
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateChatForPhase()
    local tokens = LunarUI:GetTokens()

    -- 聊天即使在新月階段也應保持較高可見度
    local minAlpha = 0.7
    local alpha = math.max(tokens.alpha, minAlpha)

    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame and frame:IsShown() then
            -- 僅調整背景透明度，不影響聊天文字
            if frame.LunarBackdrop then
                local r, g, b = frame.LunarBackdrop:GetBackdropColor()
                frame.LunarBackdrop:SetBackdropColor(r or 0.05, g or 0.05, b or 0.05, 0.5 * alpha)
            end
        end
    end
end

local function RegisterChatPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(_oldPhase, _newPhase)
        UpdateChatForPhase()
    end)
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
-- 初始化
--------------------------------------------------------------------------------

local function InitializeChat()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.enabled then return end

    -- 樣式化所有聊天框架
    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame then
            StyleChatFrame(frame)
        end
    end

    -- 掛鉤臨時聊天框架
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        for _, frameName in ipairs(CHAT_FRAMES) do
            local frame = _G[frameName]
            if frame and not styledFrames[frameName] then
                StyleChatFrame(frame)
            end
        end
    end)

    -- 套用頻道顏色
    ApplyChannelColors()

    -- 啟用職業顏色
    EnableClassColoredNames()

    -- 啟用可點擊網址
    RegisterURLFilter()

    -- 新增複製功能
    AddCopyOption()

    -- 註冊月相更新
    RegisterChatPhaseCallback()

    -- 套用初始月相
    UpdateChatForPhase()

    -- 隱藏聊天按鈕
    if ChatFrameMenuButton then ChatFrameMenuButton:Hide() end
    if ChatFrameChannelButton then ChatFrameChannelButton:Hide() end
    if QuickJoinToastButton then QuickJoinToastButton:Hide() end

    -- 移除硬編碼的 ChatFrame1 位置，保留使用者設定
end

-- 匯出
LunarUI.InitializeChat = InitializeChat
LunarUI.ShowChatCopy = ShowCopyFrame

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.8, InitializeChat)
end)

-- 新增複製命令
hooksecurefunc(LunarUI, "RegisterCommands", function(_self)
    -- /lunar copy - 複製目前聊天
end)
