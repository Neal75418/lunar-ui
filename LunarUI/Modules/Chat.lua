---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, missing-parameter
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

    檔案結構：
    - Chat/ChatStyling.lua  — 框架外觀、標籤、輸入框、複製功能
    - Chat/ChatFilters.lua  — 過濾器、頻道顏色、網址偵測、時間戳記等
    - Chat.lua（本檔案）    — 協調初始化與清理，模組註冊
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- DB 存取
--------------------------------------------------------------------------------

local function GetChatDB()
    return LunarUI.GetModuleDB("chat")
end

--------------------------------------------------------------------------------
-- 常數（共享）
--------------------------------------------------------------------------------

local CHAT_FRAMES = { "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4", "ChatFrame5", "ChatFrame6", "ChatFrame7" }

--------------------------------------------------------------------------------
-- 共享狀態（透過 LunarUI 物件跨檔案共享）
--------------------------------------------------------------------------------

-- 供 ChatStyling.lua 讀寫
LunarUI._chatStyledFrames = {}

-- 供 ChatFilters.lua 讀寫，Chat.lua cleanup 讀取
LunarUI._chatSavedAddMessageFuncs = {}
LunarUI._chatSavedChannelFormats = {}
LunarUI._chatFiltersRegistered = false

-- 供 ChatFilters.lua 和 ChatStyling.lua 讀取
LunarUI._chatFrames = CHAT_FRAMES

--------------------------------------------------------------------------------
-- 模組狀態（僅本檔案使用）
--------------------------------------------------------------------------------

local chatTempWindowHooked = false -- 私有狀態（不暴露到 LunarUI 物件）
-- C1: 用於監聯 GROUP_ROSTER_UPDATE 的事件框架
local chatRoleIconEventFrame

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeChat()
    local db = GetChatDB()
    if not db or not db.enabled then
        return
    end

    -- 預先在 ADDON_LOADED 階段（而非 click handler）註冊彈窗，避免在 click 事件中寫入
    -- StaticPopupDialogs 全域表（可能在 secure 執行路徑中觸發 taint）
    StaticPopupDialogs["LUNARUI_URL_COPY"] = StaticPopupDialogs["LUNARUI_URL_COPY"]
        or {
            text = L["PressToCopyURL"] or "Press Ctrl+C to copy URL:",
            button1 = CLOSE or "Close",
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

    -- 樣式化所有聊天框架
    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame then
            LunarUI.ChatStyleChatFrame(frame)
        end
    end

    -- 掛鉤臨時聊天框架（防止重複掛鉤）
    if not chatTempWindowHooked then
        chatTempWindowHooked = true
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for _, frameName in ipairs(CHAT_FRAMES) do
                local frame = _G[frameName]
                if frame and not LunarUI._chatStyledFrames[frameName] then
                    LunarUI.ChatStyleChatFrame(frame)
                end
            end
        end)
    end

    -- 套用頻道顏色
    LunarUI.ChatApplyChannelColors()

    -- 啟用職業顏色
    LunarUI.ChatEnableClassColoredNames()

    -- 啟用可點擊網址
    LunarUI.ChatRegisterURLFilter()

    -- 新增複製功能
    LunarUI.ChatAddCopyOption()

    -- 短頻道名稱（先 hook，這樣時間戳記會在最外層）
    LunarUI.ChatShortenChannelNames()

    -- 時間戳記（後 hook，最後包裹所有訊息）
    LunarUI.ChatSetupTimestamps()

    -- 註冊聊天增強過濾器（表情、角色圖示、關鍵字、垃圾過濾）
    LunarUI.ChatRegisterEnhancementFilters()

    -- 連結懸停 Tooltip 預覽
    LunarUI.ChatSetupLinkTooltipPreview()

    -- C1: 監聽隊伍變動以清除 role icon 名稱快取
    if not chatRoleIconEventFrame then
        chatRoleIconEventFrame = CreateFrame("Frame")
        chatRoleIconEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        chatRoleIconEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        chatRoleIconEventFrame:SetScript("OnEvent", function()
            LunarUI.ChatOnRoleIconEvent()
        end)
    end

    -- 隱藏聊天按鈕
    if ChatFrameMenuButton then
        ChatFrameMenuButton:Hide()
    end
    if ChatFrameChannelButton then
        ChatFrameChannelButton:Hide()
    end
    if QuickJoinToastButton then
        QuickJoinToastButton:Hide()
    end
end

--------------------------------------------------------------------------------
-- 清理（還原全域函數，避免模組停用後汙染）
--------------------------------------------------------------------------------

local function CleanupChat()
    -- HookScript 無法還原，但 LunarURL 是自訂 link type，不影響原始處理器

    -- 還原頻道格式字串
    for chatType, original in pairs(LunarUI._chatSavedChannelFormats) do
        _G[chatType] = original
    end
    wipe(LunarUI._chatSavedChannelFormats)

    -- 還原 AddMessage 覆寫並清除 hook 旗標
    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        if frame then
            -- 還原原始 AddMessage 函數
            if LunarUI._chatSavedAddMessageFuncs[frameName] then
                frame.AddMessage = LunarUI._chatSavedAddMessageFuncs[frameName]
            end
            -- 清除 hook 旗標，允許重新 hook
            frame._lunarTimestampHooked = nil
            frame._lunarShortChannelHooked = nil
        end
    end
    wipe(LunarUI._chatSavedAddMessageFuncs)

    -- 清理 ChatFilters 擁有的快取狀態
    LunarUI.ChatCleanupFilterState()

    -- chatFiltersRegistered 不重置：ChatFrame_AddMessageEventFilter 無法移除，
    -- 保留旗標可防止 disable+enable 循環時重複累積相同 filter

    -- 清理角色圖示事件框架（避免 disable 後仍持續回應事件）
    if chatRoleIconEventFrame then
        chatRoleIconEventFrame:UnregisterAllEvents()
        chatRoleIconEventFrame:SetScript("OnEvent", nil)
        chatRoleIconEventFrame = nil
    end
end

-- 匯出
LunarUI.InitializeChat = InitializeChat
LunarUI:RegisterModule("Chat", {
    onEnable = InitializeChat,
    onDisable = CleanupChat,
    delay = 0.1,
    lifecycle = "reload_required",
})
