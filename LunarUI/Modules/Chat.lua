---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, missing-parameter
--[[
    LunarUI - 聊天模組
    Lunar 主題風格的聊天框架

    功能：
    - 手繪風格邊框
    - 改良頻道顏色
    - 文字複製功能
    - 網址偵測與可點擊連結
    - 職業著色名稱
    - 關鍵字警報（音效 + 標籤閃爍）
    - 短頻道名稱
    - 表情符號替換
    - 角色圖示（坦/治/傷）
    - 連結懸停 Tooltip 預覽
    - 基本垃圾訊息過濾
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors
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

-- 短頻道名稱映射
local SHORT_CHANNEL_NAMES = {
    -- 英文
    ["General"]         = "G",
    ["Trade"]           = "T",
    ["LocalDefense"]    = "LD",
    ["LookingForGroup"] = "LFG",
    ["WorldDefense"]    = "WD",
    ["Newcomers"]       = "New",
    -- 繁中
    ["綜合"]            = "綜",
    ["交易"]            = "交",
    ["本地防務"]        = "防",
    ["尋求組隊"]        = "組",
    ["世界防務"]        = "世",
    ["新手"]            = "新",
}

-- 頻道類型短名稱（聊天類型標頭）
local SHORT_CHANNEL_TYPES = {
    -- 英文
    ["Guild"]                = "G",
    ["Party"]                = "P",
    ["Party Leader"]         = "PL",
    ["Raid"]                 = "R",
    ["Raid Leader"]          = "RL",
    ["Raid Warning"]         = "RW",
    ["Instance"]             = "I",
    ["Instance Leader"]      = "IL",
    ["Officer"]              = "O",
    ["Whisper From"]         = "W",
    ["Whisper To"]           = "W",
    -- 繁中
    ["公會"]                 = "公",
    ["隊伍"]                 = "隊",
    ["隊伍領袖"]             = "隊長",
    ["團隊"]                 = "團",
    ["團隊領袖"]             = "團長",
    ["團隊警告"]             = "團警",
    ["副本"]                 = "副",
    ["副本領袖"]             = "副長",
    ["幹部"]                 = "幹",
    ["悄悄話 來自"]          = "密",
    ["悄悄話 給"]            = "密",
}

-- 表情符號替換表（文字 → 遊戲圖示）
local EMOJI_MAP = {
    [":)"]   = "|TInterface\\AddOns\\LunarUI\\Media\\Textures\\emoji_smile:14:14|t",
    [":D"]   = "|TInterface\\AddOns\\LunarUI\\Media\\Textures\\emoji_grin:14:14|t",
    [":("]   = "|TInterface\\AddOns\\LunarUI\\Media\\Textures\\emoji_sad:14:14|t",
    [";)"]   = "|TInterface\\AddOns\\LunarUI\\Media\\Textures\\emoji_wink:14:14|t",
    [":P"]   = "|TInterface\\AddOns\\LunarUI\\Media\\Textures\\emoji_tongue:14:14|t",
    ["<3"]   = "|TInterface\\AddOns\\LunarUI\\Media\\Textures\\emoji_heart:14:14|t",
    [":O"]   = "|TInterface\\AddOns\\LunarUI\\Media\\Textures\\emoji_surprised:14:14|t",
    ["B)"]   = "|TInterface\\AddOns\\LunarUI\\Media\\Textures\\emoji_cool:14:14|t",
}

-- 若自訂材質不存在，改用遊戲內建圖示作為 fallback
local EMOJI_FALLBACK = {
    [":)"]   = "|TInterface\\Icons\\INV_Misc_Food_11:14:14|t",
    [":D"]   = "|TInterface\\Icons\\Spell_Holy_HolyGuidance:14:14|t",
    [":("]   = "|TInterface\\Icons\\Ability_Hunter_MasterMarksman:14:14|t",
    [";)"]   = "|TInterface\\Icons\\INV_ValentinesCandy:14:14|t",
    [":P"]   = "|TInterface\\Icons\\INV_Misc_Food_19:14:14|t",
    ["<3"]   = "|TInterface\\Icons\\INV_ValentinesCandy:14:14|t",
    [":O"]   = "|TInterface\\Icons\\Spell_Shadow_Skull:14:14|t",
    ["B)"]   = "|TInterface\\Icons\\INV_Helm_Goggles_01:14:14|t",
}

-- 角色圖示材質（坦/治/傷）
local ROLE_ICONS = {
    TANK    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER  = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}

-- 垃圾訊息過濾關鍵字（不區分大小寫）
local SPAM_PATTERNS = {
    "w+w+w%.%S+%.%S+",         -- www.xxx.xxx 網站
    "bit%.ly",                  -- 短網址
    "gold.*cheap",              -- 賣金
    "cheap.*gold",
    "buy.*gold",
    "sell.*gold",
    "power%s*level",            -- 代練
    "boost.*%$",
    "%$.*boost",
    "discord%.gg/",             -- Discord 邀請（垃圾廣告常用）
}

-- 關鍵字警報音效
local KEYWORD_ALERT_SOUND = "Interface\\AddOns\\LunarUI\\Media\\Sounds\\keyword_alert.ogg"
local KEYWORD_ALERT_FALLBACK_SOUND = SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local styledFrames = {}
local copyFrame
local copyEditBox
local chatTempWindowHooked = false  -- 私有狀態（不暴露到 LunarUI 物件）
local savedChannelFormats = {}       -- 用於 Cleanup 還原 CHAT_*_GET 格式字串
-- Emoji 觸發字元 character class（匹配所有可能的 2-char emoji 序列）
local EMOJI_PATTERN = "[%:%;<B][%)%(DPO3]"
local escapedKeywordCache = {} -- Fix 3b: 預快取 keyword escaped pattern

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

-- 檢查 emoji 自訂材質是否存在（若不存在則用 fallback）
local emojiChecked = false
local useEmojiMap = EMOJI_MAP

local function CheckEmojiTextures()
    if emojiChecked then return end
    emojiChecked = true
    -- 嘗試載入第一個自訂材質；若失敗則使用 fallback
    local testTexture = UIParent:CreateTexture()
    testTexture:SetTexture("Interface\\AddOns\\LunarUI\\Media\\Textures\\emoji_smile")
    if not testTexture:GetTexture() then
        useEmojiMap = EMOJI_FALLBACK
    end
    testTexture:Hide()
    testTexture:SetParent(nil)
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
        backdrop:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
        backdrop:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
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

    -- 設定輸入框位置（在聊天視窗下方）
    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", -4, -8)
    editBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 4, -8)
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
        backdrop:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.5)
        backdrop:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.6)
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
                            -- Fix 11: 動畫完成後卸載 OnUpdate
                            bd:SetScript("OnUpdate", nil)
                            bd._fadeUpdate = false
                        end
                    else
                        -- Fix 11: 已到達目標，不需繼續每幀執行
                        bd:SetScript("OnUpdate", nil)
                        bd._fadeUpdate = false
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
    copyFrame:SetBackdropColor(C.bgSolid[1], C.bgSolid[2], C.bgSolid[3], C.bgSolid[4])
    copyFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
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

    -- 逐框架掛鉤超連結處理器（避免覆寫全域 ChatFrame_OnHyperlinkShow 導致 taint）
    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame and not frame._lunarHyperlinkHooked then
            frame._lunarHyperlinkHooked = true
            frame:HookScript("OnHyperlinkClick", function(self, link, text, button)
                HandleURLClick(self, link, text, button)
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- 時間戳記
--------------------------------------------------------------------------------

local function SetupTimestamps()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.showTimestamps then return end

    local fmt = db.timestampFormat or "%H:%M"

    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame and not frame._lunarTimestampHooked then
            frame._lunarTimestampHooked = true
            local origAddMessage = frame.AddMessage
            frame.AddMessage = function(self, msg, ...)
                if msg and type(msg) == "string" then
                    local timestamp = date(fmt)
                    msg = "|cff999999[" .. timestamp .. "]|r " .. msg
                end
                return origAddMessage(self, msg, ...)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 短頻道名稱
--------------------------------------------------------------------------------

local function ShortenChannelNames()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.shortChannelNames then return end

    -- 覆寫頻道標頭格式
    -- 數字頻道：[2. 交易] → [交]
    local origGetChannelName = _G.ChatFrame_MessageEventHandler
    if not origGetChannelName then return end

    -- 替換 CHAT_*_GET 格式字串中的頻道名稱
    -- 這些全域字串控制頻道訊息的前綴格式
    local channelTypes = {
        "CHAT_SAY_GET",
        "CHAT_YELL_GET",
        "CHAT_WHISPER_GET",
        "CHAT_WHISPER_INFORM_GET",
        "CHAT_BN_WHISPER_GET",
        "CHAT_BN_WHISPER_INFORM_GET",
        "CHAT_PARTY_GET",
        "CHAT_PARTY_LEADER_GET",
        "CHAT_RAID_GET",
        "CHAT_RAID_LEADER_GET",
        "CHAT_RAID_WARNING_GET",
        "CHAT_INSTANCE_CHAT_GET",
        "CHAT_INSTANCE_CHAT_LEADER_GET",
        "CHAT_GUILD_GET",
        "CHAT_OFFICER_GET",
        "CHAT_EMOTE_GET",
    }

    -- 替換格式字串中的括號標頭（保留原始值以便 Cleanup 還原）
    for _, chatType in ipairs(channelTypes) do
        local original = _G[chatType]
        if original then
            savedChannelFormats[chatType] = original
            -- 從格式字串中提取方括號內的頻道名稱
            for longName, shortName in pairs(SHORT_CHANNEL_TYPES) do
                if original:find(longName, 1, true) then
                    _G[chatType] = original:gsub(
                        "%[" .. longName .. "%]",
                        "[" .. shortName .. "]"
                    )
                    break
                end
            end
        end
    end

    -- 數字頻道（綜合、交易等）：使用 ChatFrame_AddMessageEventFilter
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", function(_self, _event, msg, ...)
        -- 頻道名稱在第 9 個參數（channelName）
        -- 但我們無法修改額外參數，改用 AddMessage hook
        return false, msg, ...
    end)

    -- Hook ChatFrame.AddMessage 來替換頻道標頭
    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame and not frame._lunarShortChannelHooked then
            frame._lunarShortChannelHooked = true
            local origAddMessage = frame.AddMessage
            frame.AddMessage = function(self, msg, ...)
                if msg and type(msg) == "string" then
                    -- 替換數字頻道名稱：[2. 交易] → [2.交]
                    msg = msg:gsub("%[(%d+)%.%s*(.-)%]", function(num, name)
                        local short = SHORT_CHANNEL_NAMES[name]
                        if short then
                            return "[" .. num .. "." .. short .. "]"
                        end
                        return "[" .. num .. "." .. name .. "]"
                    end)
                end
                return origAddMessage(self, msg, ...)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 表情符號替換
--------------------------------------------------------------------------------

-- 快速檢查：訊息是否包含可能的 emoji 起始字元
local EMOJI_QUICK_CHECK = "[%:%;<B]"

local function AddEmojisToMessage(_self, _event, msg, ...)
    if not msg then return false, msg, ... end

    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.enableEmojis then return false, msg, ... end

    -- 效能優化：先快速檢查是否包含 emoji 起始字元
    if not msg:find(EMOJI_QUICK_CHECK) then
        return false, msg, ...
    end

    CheckEmojiTextures()

    -- 單一 gsub + table lookup 取代逐一迴圈（useEmojiMap 以原始文字為 key）
    local newMsg = msg:gsub(EMOJI_PATTERN, useEmojiMap)

    if newMsg ~= msg then
        return false, newMsg, ...
    end
    return false, msg, ...
end

--------------------------------------------------------------------------------
-- 角色圖示（坦/治/傷）
--------------------------------------------------------------------------------

local function AddRoleIconToMessage(_self, _event, msg, author, ...)
    if not msg or not author then return false, msg, author, ... end

    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.showRoleIcons then return false, msg, author, ... end

    -- 只在隊伍/團隊頻道中顯示角色圖示
    -- 嘗試從隊伍成員中找到對應角色
    local role = nil
    local shortAuthor = Ambiguate(author, "short")

    -- 搜尋隊伍/團隊成員
    local numGroupMembers = GetNumGroupMembers()
    if numGroupMembers > 0 then
        local prefix = IsInRaid() and "raid" or "party"
        local limit = IsInRaid() and numGroupMembers or (numGroupMembers - 1)

        for i = 1, limit do
            local unit = prefix .. i
            local unitName = UnitName(unit)
            if unitName and unitName == shortAuthor then
                role = UnitGroupRolesAssigned(unit)
                break
            end
        end

        -- 檢查玩家自己
        if not role or role == "NONE" then
            local playerName = UnitName("player")
            if playerName == shortAuthor then
                role = UnitGroupRolesAssigned("player")
            end
        end
    end

    if role and role ~= "NONE" and ROLE_ICONS[role] then
        -- 在作者名稱前加上角色圖示
        local iconedAuthor = ROLE_ICONS[role] .. " " .. author
        return false, msg, iconedAuthor, ...
    end

    return false, msg, author, ...
end

--------------------------------------------------------------------------------
-- 關鍵字警報
--------------------------------------------------------------------------------

local lastKeywordAlert = 0

local function CheckKeywordAlert(_self, _event, msg, author, ...)
    if not msg then return false, msg, author, ... end

    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.keywordAlerts then return false, msg, author, ... end

    -- 不對自己的訊息觸發
    local playerName = UnitName("player")
    if author then
        local shortAuthor = Ambiguate(author, "short")
        if shortAuthor == playerName then
            return false, msg, author, ...
        end
    end

    -- 預設關鍵字：玩家名稱
    local keywords = db.keywords or {}
    local checkList = { playerName }
    for _, kw in ipairs(keywords) do
        table.insert(checkList, kw)
    end

    local msgLower = msg:lower()
    local matched = false

    for _, keyword in ipairs(checkList) do
        if keyword and keyword ~= "" and msgLower:find(keyword:lower(), 1, true) then
            matched = true
            break
        end
    end

    if matched then
        local now = GetTime()
        -- 節流：至少間隔 2 秒
        if now - lastKeywordAlert >= 2 then
            lastKeywordAlert = now

            -- 播放音效
            local soundPlayed = false
            if KEYWORD_ALERT_SOUND then
                soundPlayed = PlaySoundFile(KEYWORD_ALERT_SOUND, "Master")
            end
            if not soundPlayed and KEYWORD_ALERT_FALLBACK_SOUND then
                PlaySound(KEYWORD_ALERT_FALLBACK_SOUND, "Master")
            end

            -- 閃爍聊天標籤
            local chatFrame = _G["ChatFrame1"]
            if chatFrame then
                local tab = _G[chatFrame:GetName() .. "Tab"]
                if tab and tab.glow then
                    UIFrameFlash(tab.glow, 0.25, 0.25, 2, false, 0, 0)
                end
            end

            -- 在訊息中高亮關鍵字（加底色）
            -- Fix 3b: 使用預快取的 escaped pattern
            for _, keyword in ipairs(checkList) do
                if keyword and keyword ~= "" then
                    local escaped = escapedKeywordCache[keyword]
                    if not escaped then
                        escaped = keyword:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                        escapedKeywordCache[keyword] = escaped
                    end
                    msg = msg:gsub("(" .. escaped .. ")", "|cffff8800%1|r")
                end
            end
        end
    end

    return false, msg, author, ...
end

--------------------------------------------------------------------------------
-- 垃圾訊息過濾
--------------------------------------------------------------------------------

local function FilterSpamMessage(_self, _event, msg, author, ...)
    if not msg then return false, msg, author, ... end

    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.spamFilter then return false, msg, author, ... end

    local msgLower = msg:lower()

    for _, pattern in ipairs(SPAM_PATTERNS) do
        if msgLower:find(pattern) then
            -- 靜默丟棄垃圾訊息
            return true
        end
    end

    return false, msg, author, ...
end

--------------------------------------------------------------------------------
-- 連結懸停 Tooltip 預覽
--------------------------------------------------------------------------------

local function SetupLinkTooltipPreview()
    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db or not db.linkTooltipPreview then return end

    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame and not frame._lunarLinkPreviewHooked then
            frame._lunarLinkPreviewHooked = true

            frame:HookScript("OnHyperlinkEnter", function(_self, link)
                if not link then return end

                local linkType, linkData = strsplit(":", link, 2)
                if not linkType then return end

                GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")

                if linkType == "item" then
                    local itemID = linkData and linkData:match("^(%d+)")
                    if itemID then
                        pcall(GameTooltip.SetItemByID, GameTooltip, tonumber(itemID))
                    end
                elseif linkType == "spell" then
                    local spellID = linkData and linkData:match("^(%d+)")
                    if spellID then
                        pcall(GameTooltip.SetSpellByID, GameTooltip, tonumber(spellID))
                    end
                else
                    pcall(GameTooltip.SetHyperlink, GameTooltip, link)
                end

                GameTooltip:Show()
            end)

            frame:HookScript("OnHyperlinkLeave", function()
                GameTooltip:Hide()
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- 註冊聊天增強過濾器
--------------------------------------------------------------------------------

local function RegisterChatEnhancementFilters()
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

    local db = LunarUI.db and LunarUI.db.profile.chat
    if not db then return end

    -- 表情符號替換
    if db.enableEmojis then
        for _, event in ipairs(chatEvents) do
            ChatFrame_AddMessageEventFilter(event, AddEmojisToMessage)
        end
    end

    -- 角色圖示（僅隊伍/團隊頻道）
    if db.showRoleIcons then
        local roleEvents = {
            "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
            "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
            "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
        }
        for _, event in ipairs(roleEvents) do
            ChatFrame_AddMessageEventFilter(event, AddRoleIconToMessage)
        end
    end

    -- 關鍵字警報
    if db.keywordAlerts then
        for _, event in ipairs(chatEvents) do
            ChatFrame_AddMessageEventFilter(event, CheckKeywordAlert)
        end
    end

    -- 垃圾訊息過濾（僅公開頻道）
    if db.spamFilter then
        local spamEvents = {
            "CHAT_MSG_SAY", "CHAT_MSG_YELL",
            "CHAT_MSG_CHANNEL",
            "CHAT_MSG_WHISPER",
        }
        for _, event in ipairs(spamEvents) do
            ChatFrame_AddMessageEventFilter(event, FilterSpamMessage)
        end
    end
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

    -- 掛鉤臨時聊天框架（防止重複掛鉤）
    if not chatTempWindowHooked then
        chatTempWindowHooked = true
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for _, frameName in ipairs(CHAT_FRAMES) do
                local frame = _G[frameName]
                if frame and not styledFrames[frameName] then
                    StyleChatFrame(frame)
                end
            end
        end)
    end

    -- 套用頻道顏色
    ApplyChannelColors()

    -- 啟用職業顏色
    EnableClassColoredNames()

    -- 啟用可點擊網址
    RegisterURLFilter()

    -- 新增複製功能
    AddCopyOption()

    -- 短頻道名稱（先 hook，這樣時間戳記會在最外層）
    ShortenChannelNames()

    -- 時間戳記（後 hook，最後包裹所有訊息）
    SetupTimestamps()

    -- 註冊聊天增強過濾器（表情、角色圖示、關鍵字、垃圾過濾）
    RegisterChatEnhancementFilters()

    -- 連結懸停 Tooltip 預覽
    SetupLinkTooltipPreview()

    -- 隱藏聊天按鈕
    if ChatFrameMenuButton then ChatFrameMenuButton:Hide() end
    if ChatFrameChannelButton then ChatFrameChannelButton:Hide() end
    if QuickJoinToastButton then QuickJoinToastButton:Hide() end
end

--------------------------------------------------------------------------------
-- Cleanup（還原全域函數，避免模組停用後汙染）
--------------------------------------------------------------------------------

local function CleanupChat()
    -- HookScript 無法還原，但 LunarURL 是自訂 link type，不影響原始處理器

    -- 還原頻道格式字串
    for chatType, original in pairs(savedChannelFormats) do
        _G[chatType] = original
    end
    wipe(savedChannelFormats)
end

-- 匯出
LunarUI.InitializeChat = InitializeChat
LunarUI.ShowChatCopy = ShowCopyFrame

LunarUI:RegisterModule("Chat", {
    onEnable = InitializeChat,
    onDisable = CleanupChat,
    delay = 0.8,
})
