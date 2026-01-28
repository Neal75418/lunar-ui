--[[
    LunarUI - Chat Module
    Styled chat frames with Lunar theme

    Features:
    - Hand-drawn style border
    - Improved channel colors
    - Copy text functionality
    - URL detection and clickable links
    - Class colored names
    - Phase-aware fading
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}  -- Fix #104: Access localization table

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local CHAT_FRAMES = { "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4", "ChatFrame5", "ChatFrame6", "ChatFrame7" }

local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- Improved channel colors
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
-- Module State
--------------------------------------------------------------------------------

local styledFrames = {}
local copyFrame
local copyEditBox

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function GetClassColor(class)
    if class and RAID_CLASS_COLORS[class] then
        return RAID_CLASS_COLORS[class]
    end
    return { r = 1, g = 1, b = 1 }
end

--------------------------------------------------------------------------------
-- Chat Frame Styling
--------------------------------------------------------------------------------

local function StyleChatTab(chatFrame)
    local tab = _G[chatFrame:GetName() .. "Tab"]
    if not tab then return end

    -- Simplify tab appearance
    local tabText = _G[chatFrame:GetName() .. "TabText"] or tab.Text
    if tabText then
        tabText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    end

    -- Hide tab textures
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

    -- Style glow
    if tab.glow then
        tab.glow:SetTexture(nil)
    end
end

local function StyleChatEditBox(chatFrame)
    local editBox = _G[chatFrame:GetName() .. "EditBox"]
    if not editBox then return end

    -- Create backdrop
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

    -- Hide default textures
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

    -- Position edit box
    editBox:ClearAllPoints()
    editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -4, 8)
    editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 4, 8)
    editBox:SetHeight(22)

    -- Style text
    editBox:SetFont(STANDARD_TEXT_FONT, 12, "")
end

local function StyleChatFrame(chatFrame)
    if not chatFrame then return end

    local name = chatFrame:GetName()
    if styledFrames[name] then return end

    -- Create backdrop
    if not chatFrame.LunarBackdrop then
        local backdrop = CreateFrame("Frame", nil, chatFrame, "BackdropTemplate")
        backdrop:SetPoint("TOPLEFT", -4, 4)
        backdrop:SetPoint("BOTTOMRIGHT", 4, -4)
        backdrop:SetBackdrop(backdropTemplate)
        backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
        backdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.6)
        backdrop:SetFrameLevel(chatFrame:GetFrameLevel() - 1)
        backdrop:Hide()
        chatFrame.LunarBackdrop = backdrop
    end

    -- Show backdrop on hover
    chatFrame:HookScript("OnEnter", function(self)
        if self.LunarBackdrop then
            self.LunarBackdrop:Show()
        end
    end)

    chatFrame:HookScript("OnLeave", function(self)
        if self.LunarBackdrop and not MouseIsOver(self) then
            self.LunarBackdrop:Hide()
        end
    end)

    -- Hide default textures
    for _, texName in ipairs({ "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
                               "LeftTexture", "RightTexture", "TopTexture", "BottomTexture" }) do
        local tex = _G[name .. texName]
        if tex then
            tex:SetTexture(nil)
        end
    end

    -- Style button frame
    local buttonFrame = _G[name .. "ButtonFrame"]
    if buttonFrame then
        buttonFrame:Hide()
    end

    -- Style tab
    StyleChatTab(chatFrame)

    -- Style edit box
    StyleChatEditBox(chatFrame)

    -- Set font
    local font, _, flags = chatFrame:GetFont()
    chatFrame:SetFont(font or STANDARD_TEXT_FONT, 13, flags or "")

    -- Enable mouse wheel scrolling (Fix #10: use HookScript instead of SetScript)
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
-- Copy Frame
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

    -- Title bar
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

    -- Close button
    local closeBtn = CreateFrame("Button", nil, copyFrame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", -4, -2)
    closeBtn:SetNormalFontObject(GameFontNormal)
    closeBtn:SetText("×")
    closeBtn:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    closeBtn:SetScript("OnClick", function() copyFrame:Hide() end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "LunarUI_ChatCopyScroll", copyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -28)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    -- Edit box
    copyEditBox = CreateFrame("EditBox", "LunarUI_ChatCopyEdit", scrollFrame)
    copyEditBox:SetMultiLine(true)
    copyEditBox:SetMaxLetters(99999)
    copyEditBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    copyEditBox:SetWidth(scrollFrame:GetWidth())
    copyEditBox:SetAutoFocus(false)
    copyEditBox:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    scrollFrame:SetScrollChild(copyEditBox)

    -- Style scroll bar
    local scrollBar = _G["LunarUI_ChatCopyScrollScrollBar"]
    if scrollBar then
        scrollBar:SetWidth(12)
    end

    return copyFrame
end

local function ShowCopyFrame(chatFrame)
    if not chatFrame then return end

    CreateCopyFrame()

    -- Collect chat lines
    local lines = {}
    local numMessages = chatFrame:GetNumMessages()

    for i = 1, numMessages do
        local message = chatFrame:GetMessageInfo(i)
        if message then
            table.insert(lines, message)
        end
    end

    -- Set text
    copyEditBox:SetText(table.concat(lines, "\n"))
    copyEditBox:HighlightText()
    copyEditBox:SetFocus()

    copyFrame:Show()
end

--------------------------------------------------------------------------------
-- Channel Colors
--------------------------------------------------------------------------------

local function ApplyChannelColors()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.improvedColors then return end

    for channel, color in pairs(CHANNEL_COLORS) do
        ChangeChatColor(channel, color[1], color[2], color[3])
    end
end

--------------------------------------------------------------------------------
-- Class Colored Names
--------------------------------------------------------------------------------

local function EnableClassColoredNames()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.classColors then return end

    -- This is handled by Blizzard's option, we just enable it
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
-- URL Detection
--------------------------------------------------------------------------------

-- Fix #76: Clickable URLs in chat
local URL_PATTERNS = {
    -- Full URLs with protocol
    "(https?://[%w%.%-_~:/?#%[%]@!$&'()*+,;=%%]+)",
    -- www URLs
    "(www%.[%w%.%-_~:/?#%[%]@!$&'()*+,;=%%]+)",
    -- Email addresses
    "([%w%.%-_]+@[%w%.%-_]+%.%w+)",
}

-- Format URL as clickable hyperlink
local function FormatURL(url)
    -- Use LunarURL as custom hyperlink type
    return format("|cff3399ff|HLunarURL:%s|h[%s]|h|r", url, url)
end

-- Filter function to detect and convert URLs to clickable links
local function AddURLsToMessage(self, event, msg, ...)
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

-- Handle URL hyperlink clicks
local function HandleURLClick(self, link, text, button)
    if not link then return end

    local linkType, url = strsplit(":", link, 2)
    if linkType == "LunarURL" and url then
        -- Fix #104: Use localized strings for URL copy popup
        local popupText = L["PressToCopyURL"] or "Press Ctrl+C to copy URL:"
        local closeText = CLOSE or "Close"  -- Use Blizzard's global CLOSE string

        -- Create a popup to show and copy URL
        StaticPopupDialogs["LUNARUI_URL_COPY"] = StaticPopupDialogs["LUNARUI_URL_COPY"] or {
            text = popupText,
            button1 = closeText,
            hasEditBox = true,
            editBoxWidth = 280,
            OnShow = function(self, data)
                self.editBox:SetText(data)
                self.editBox:HighlightText()
                self.editBox:SetFocus()
            end,
            EditBoxOnEnterPressed = function(self)
                self:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
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

-- Register URL filter for all chat events
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

    -- Hook hyperlink handler for all chat frames
    local originalHandler = ChatFrame_OnHyperlinkShow
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
-- Phase Awareness
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateChatForPhase()
    local tokens = LunarUI:GetTokens()

    -- Chat should be more visible even in NEW phase
    local minAlpha = 0.7
    local alpha = math.max(tokens.alpha, minAlpha)

    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame and frame:IsShown() then
            -- Only adjust backdrop alpha, not the chat text
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

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        UpdateChatForPhase()
    end)
end

--------------------------------------------------------------------------------
-- Context Menu
--------------------------------------------------------------------------------

-- Fix #43: Implement chat copy functionality via right-click on tab
local function AddCopyOption()
    -- Hook chat tab right-click to show copy frame
    -- WoW 12.0: Hook each tab's OnClick directly instead of global FCFTab_OnClick
    for i = 1, NUM_CHAT_WINDOWS do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then
            tab:HookScript("OnClick", function(self, button)
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
-- Initialization
--------------------------------------------------------------------------------

local function InitializeChat()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.enabled then return end

    -- Style all chat frames
    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame then
            StyleChatFrame(frame)
        end
    end

    -- Hook temporary chat frames
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        for _, frameName in ipairs(CHAT_FRAMES) do
            local frame = _G[frameName]
            if frame and not styledFrames[frameName] then
                StyleChatFrame(frame)
            end
        end
    end)

    -- Apply channel colors
    ApplyChannelColors()

    -- Enable class colors
    EnableClassColoredNames()

    -- Fix #76: Enable clickable URLs
    RegisterURLFilter()

    -- Add copy functionality
    AddCopyOption()

    -- Register for phase updates
    RegisterChatPhaseCallback()

    -- Apply initial phase
    UpdateChatForPhase()

    -- Hide chat buttons
    if ChatFrameMenuButton then ChatFrameMenuButton:Hide() end
    if ChatFrameChannelButton then ChatFrameChannelButton:Hide() end
    if QuickJoinToastButton then QuickJoinToastButton:Hide() end

    -- Fix #28: Removed hardcoded ChatFrame1 position to preserve user settings
    -- Users can position chat frames as they prefer
end

-- Export
LunarUI.InitializeChat = InitializeChat
LunarUI.ShowChatCopy = ShowCopyFrame

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.8, InitializeChat)
end)

-- Add slash command for copy
hooksecurefunc(LunarUI, "RegisterCommands", function(self)
    -- /lunar copy - copy current chat
end)
