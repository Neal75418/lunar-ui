---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/Modules/Chat.lua
    Tests emoji replacement, URL detection, spam filtering, keyword matching
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs（wow_mock.lua 已提供 GetTime/InCombatLockdown/IsShiftKeyDown/C_Timer 預設值）
_G.UnitName = function()
    return "TestPlayer"
end
_G.IsInRaid = function()
    return false
end
_G.GetNumGroupMembers = function()
    return 0
end
_G.IsControlKeyDown = function()
    return false
end
_G.hooksecurefunc = function() end
_G.NUM_CHAT_WINDOWS = 7
_G.SOUNDKIT = { TELL_MESSAGE = 3081 }
_G.CLOSE = "Close"
_G.Ambiguate = function(name)
    return name
end
_G.PlaySoundFile = function()
    return true
end
_G.PlaySound = function() end
_G.UnitGroupRolesAssigned = function()
    return "NONE"
end
_G.MouseIsOver = function()
    return false
end
_G.ChangeChatColor = function() end
_G.SetChatColorNameByClass = function() end
_G.date = os.date
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function() end
_G.UIFrameFlash = function() end
_G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function() end,
    AddDoubleLine = function() end,
    Show = function() end,
    Hide = function() end,
    SetItemByID = function() end,
    SetSpellByID = function() end,
    SetHyperlink = function() end,
}

-- Capture registered message filters
local registeredFilters = {}
_G.ChatFrame_AddMessageEventFilter = function(event, func)
    registeredFilters[#registeredFilters + 1] = { event = event, func = func }
end

-- Mock CreateFrame with chat-specific defaults
local mock_frame = require("spec.mock_frame")
local MockFrame = mock_frame.MockFrame

-- Mock chat frames
for i = 1, 7 do
    local name = "ChatFrame" .. i
    local frame = setmetatable({}, { __index = MockFrame })
    frame.GetName = function()
        return name
    end
    _G[name] = frame
    _G[name .. "Tab"] = setmetatable({}, { __index = MockFrame })
    _G[name .. "EditBox"] = setmetatable({}, { __index = MockFrame })
end

local chatDB = {
    enabled = true,
    improvedColors = true,
    classColors = true,
    detectURLs = true,
    shortChannelNames = true,
    showTimestamps = true,
    timestampFormat = "%H:%M",
    enableEmojis = true,
    showRoleIcons = false,
    keywordAlerts = true,
    keywords = {},
    spamFilter = true,
    linkTooltipPreview = false,
}

local LunarUI = {
    _modulesEnabled = true,
    Colors = {
        bg = { 0.05, 0.05, 0.05 },
        bgSolid = { 0.05, 0.05, 0.05, 1 },
        border = { 0.3, 0.3, 0.4 },
        borderGold = { 0.4, 0.35, 0.2, 1 },
        textSecondary = { 0.6, 0.6, 0.6 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    backdropTemplate = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetSelectedFont = function()
        return "Fonts\\FRIZQT__.TTF"
    end,
    GetModuleDB = function()
        return chatDB
    end,
    RegisterFontString = function() end,
    SkinCloseButton = function() end,
    SkinScrollBar = function() end,
    EscapePattern = function(s)
        return s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    end,
    SafeCall = function(fn)
        fn()
    end,
    RegisterModule = function() end,
    Print = function() end,
}

loader.loadAddonFile("LunarUI/Modules/Chat/ChatStyling.lua", LunarUI)
loader.loadAddonFile("LunarUI/Modules/Chat/ChatFilters.lua", LunarUI)
loader.loadAddonFile("LunarUI/Modules/Chat.lua", LunarUI)

-- Call InitializeChat to register filters (they're only registered during init)
if LunarUI.InitializeChat then
    LunarUI.InitializeChat()
end

-- 確認 filter 有成功註冊（若此 assert 失敗，代表 InitializeChat 本身有問題，
-- 而非 filter 邏輯：後續 pending() 會 silent pass，這裡提前暴露根本原因）
assert(#registeredFilters > 0, "Chat filters were not registered — InitializeChat may have failed")

--------------------------------------------------------------------------------
-- Emoji Replacement
--------------------------------------------------------------------------------

describe("Chat emoji replacement", function()
    local emojiFilter = LunarUI.ChatEmojiFilter

    it("replaces :) with food icon", function()
        local _, result = emojiFilter(nil, nil, "Hello :)")
        assert.truthy(result:find("INV_Misc_Food_11"))
    end)

    it("replaces :D with guidance icon", function()
        local _, result = emojiFilter(nil, nil, "LOL :D")
        assert.truthy(result:find("Spell_Holy_HolyGuidance"))
    end)

    it("replaces <3 with candy icon", function()
        local _, result = emojiFilter(nil, nil, "I love you <3")
        assert.truthy(result:find("INV_ValentinesCandy"))
    end)

    it("does not modify messages without emojis", function()
        local _, result = emojiFilter(nil, nil, "Hello world")
        assert.equals("Hello world", result)
    end)

    it("handles nil message gracefully", function()
        local blocked, result = emojiFilter(nil, nil, nil)
        assert.is_false(blocked)
        assert.is_nil(result)
    end)

    it("preserves unmatched 2-char sequences (M7 fix)", function()
        -- :X is not in EMOJI_MAP, should be preserved
        local _, result = emojiFilter(nil, nil, "test :X end")
        assert.equals("test :X end", result)
    end)
end)

--------------------------------------------------------------------------------
-- Spam Filter
--------------------------------------------------------------------------------

describe("Chat spam filter", function()
    local spamFilter = LunarUI.ChatSpamFilter

    it("blocks messages with gold selling", function()
        local blocked = spamFilter(nil, nil, "buy gold cheap only $5", "Spammer")
        assert.is_true(blocked)
    end)

    it("blocks messages with www URLs", function()
        local blocked = spamFilter(nil, nil, "visit www.gold-shop.com for deals", "Spammer")
        assert.is_true(blocked)
    end)

    it("blocks power leveling ads", function()
        local blocked = spamFilter(nil, nil, "power level your character fast!", "Spammer")
        assert.is_true(blocked)
    end)

    it("does not block normal messages", function()
        local blocked = spamFilter(nil, nil, "LF healer for mythic+", "Player")
        assert.is_false(blocked)
    end)

    it("handles nil message", function()
        local blocked, _msg = spamFilter(nil, nil, nil, "Player")
        assert.is_false(blocked)
    end)
end)

--------------------------------------------------------------------------------
-- DB Toggle: enableEmojis = false
--------------------------------------------------------------------------------

describe("Chat emoji toggle off", function()
    local emojiFilter = LunarUI.ChatEmojiFilter

    after_each(function()
        chatDB.enableEmojis = true
    end)

    it("passes through emoji text when enableEmojis is false", function()
        chatDB.enableEmojis = false
        local blocked, result = emojiFilter(nil, nil, "Hello :)")
        assert.is_false(blocked)
        assert.equals("Hello :)", result)
    end)

    it("resumes replacement when enableEmojis is toggled back on", function()
        chatDB.enableEmojis = false
        local _, result1 = emojiFilter(nil, nil, "Hello :)")
        assert.equals("Hello :)", result1)

        chatDB.enableEmojis = true
        local _, result2 = emojiFilter(nil, nil, "Hello :)")
        assert.truthy(result2:find("INV_Misc_Food_11"))
    end)
end)

--------------------------------------------------------------------------------
-- DB Toggle: spamFilter = false
--------------------------------------------------------------------------------

describe("Chat spam toggle off", function()
    local spamFilter = LunarUI.ChatSpamFilter

    after_each(function()
        chatDB.spamFilter = true
    end)

    it("passes through spam when spamFilter is false", function()
        chatDB.spamFilter = false
        local blocked = spamFilter(nil, nil, "buy gold cheap only $5", "Spammer")
        assert.is_false(blocked)
    end)

    it("resumes filtering when spamFilter is toggled back on", function()
        chatDB.spamFilter = false
        local blocked1 = spamFilter(nil, nil, "buy gold cheap only $5", "Spammer")
        assert.is_false(blocked1)

        chatDB.spamFilter = true
        local blocked2 = spamFilter(nil, nil, "buy gold cheap only $5", "Spammer")
        assert.is_true(blocked2)
    end)
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("Chat lifecycle", function()
    it("exports InitializeChat function", function()
        assert.is_function(LunarUI.InitializeChat)
    end)

    it("filters passthrough when _modulesEnabled is false", function()
        LunarUI._modulesEnabled = false
        for _, entry in ipairs(registeredFilters) do
            local blocked, result = entry.func(nil, nil, "Hello :)")
            -- Filter should not block and should not modify the message
            assert.is_false(blocked)
            assert.equals("Hello :)", result)
        end
        LunarUI._modulesEnabled = true
    end)
end)

--------------------------------------------------------------------------------
-- FormatURL (Security S-B8: prevent WoW hyperlink injection via URL)
--
-- 輸入一段 URL 字串，回傳 `|cff3399ff|HLunarURL:URL|h[URL]|h|r` 形式的可點擊
-- 彩色超連結。為防止惡意 URL 注入 `|H...|h` 偽造物品/成就連結，所有 `|` 字元
-- 必須先被 strip 掉。
--------------------------------------------------------------------------------

describe("ChatFormatURL", function()
    local FormatURL

    before_each(function()
        FormatURL = LunarUI.ChatFormatURL
    end)

    it("wraps plain URL into a clickable LunarURL hyperlink", function()
        local result = FormatURL("https://example.com")
        -- 應包含 color code、LunarURL prefix、雙份 URL、正確封閉
        assert.truthy(result:find("|cff3399ff", 1, true))
        assert.truthy(result:find("|HLunarURL:https://example.com|h", 1, true))
        assert.truthy(result:find("[https://example.com]", 1, true))
        assert.truthy(result:find("|h|r", 1, true))
    end)

    it("strips pipe chars to prevent hyperlink injection (S-B8)", function()
        -- 惡意 URL 嘗試注入假物品連結
        local malicious = "https://x.com|Hitem:1234::::::::1:::::|h[假物品]|h"
        local result = FormatURL(malicious)
        -- 輸出中 URL 部分應已無 | 字元（只剩我們自己 wrap 的 |c / |H / |h / |r）
        -- 取出 LunarURL 裡的 URL 部分
        local urlInside = result:match("|HLunarURL:([^|]+)|h")
        assert.truthy(urlInside)
        assert.is_nil(urlInside:find("|", 1, true))
        -- 顯示文字內也不應有 | 字元
        local displayText = result:match("|h%[([^|]*)%]|h")
        assert.truthy(displayText)
        assert.is_nil(displayText:find("|", 1, true))
    end)

    it("handles URLs with colon and path (no special chars)", function()
        local result = FormatURL("http://foo.bar/path?q=1&r=2")
        assert.truthy(result:find("|HLunarURL:http://foo.bar/path?q=1&r=2|h", 1, true))
    end)

    it("handles URLs with multiple pipes", function()
        local result = FormatURL("a|b|c|d")
        assert.truthy(result:find("|HLunarURL:abcd|h", 1, true))
        assert.truthy(result:find("[abcd]", 1, true))
    end)

    it("handles empty URL without crashing", function()
        assert.has_no_errors(function()
            local result = FormatURL("")
            -- 應產生空 URL 但格式仍正確
            assert.truthy(result:find("|HLunarURL:|h", 1, true))
        end)
    end)

    it("preserves color escape balance in output", function()
        -- output 必須有一個 |cAARRGGBB 開色 + 一個 |r 關色
        -- WoW color prefix 是 |c + 8 hex chars（alpha 2 + RGB 6）
        local result = FormatURL("a")
        local _, openCount = result:gsub("|c%x%x%x%x%x%x%x%x", "")
        local _, resetCount = result:gsub("|r", "")
        assert.equals(1, openCount)
        assert.equals(1, resetCount)
    end)
end)

--------------------------------------------------------------------------------
-- AddURLsToMessage trailing punctuation (H1 fix: 結尾 .,;:!? 不該吃進連結)
--------------------------------------------------------------------------------

describe("ChatAddURLsToMessage trailing punctuation", function()
    local AddURLs

    before_each(function()
        AddURLs = LunarUI.ChatAddURLsToMessage
    end)

    -- helper：取出 LunarURL 內部的 URL 字串
    local function extractWrappedURL(msg)
        return msg:match("|HLunarURL:([^|]+)|h")
    end

    it("strips trailing comma from URL", function()
        local _, newMsg = AddURLs(nil, "CHAT_MSG_SAY", "see https://example.com,")
        local wrapped = extractWrappedURL(newMsg)
        assert.equals("https://example.com", wrapped) -- 逗號不在連結內
        assert.truthy(newMsg:find(",$")) -- 訊息結尾仍保留逗號
    end)

    it("strips trailing period from URL", function()
        local _, newMsg = AddURLs(nil, "CHAT_MSG_SAY", "go to https://example.com.")
        local wrapped = extractWrappedURL(newMsg)
        assert.equals("https://example.com", wrapped)
        assert.truthy(newMsg:find("%.$"))
    end)

    it("strips multiple trailing punctuation characters", function()
        local _, newMsg = AddURLs(nil, "CHAT_MSG_SAY", "what?! https://example.com?!")
        local wrapped = extractWrappedURL(newMsg)
        assert.equals("https://example.com", wrapped)
        assert.truthy(newMsg:find("%?!$"))
    end)

    it("preserves trailing closing paren (Wikipedia/MDN URL pattern)", function()
        -- 維基 URL 例：https://en.wikipedia.org/wiki/Foo_(bar) — 括號是 URL 的一部分
        local _, newMsg = AddURLs(nil, "CHAT_MSG_SAY", "see https://en.wikipedia.org/wiki/Foo_(bar)")
        local wrapped = extractWrappedURL(newMsg)
        assert.equals("https://en.wikipedia.org/wiki/Foo_(bar)", wrapped) -- ) 仍在連結內
    end)

    it("does not strip punctuation in middle of URL", function()
        -- query string 裡的 , 應該保留：?ids=1,2,3 是合法 URL
        local _, newMsg = AddURLs(nil, "CHAT_MSG_SAY", "go https://x.com/a?ids=1,2,3 done")
        local wrapped = extractWrappedURL(newMsg)
        assert.equals("https://x.com/a?ids=1,2,3", wrapped) -- 中間逗號保留
    end)
end)

--------------------------------------------------------------------------------
-- ChatStyling — StyleChatFrame guards + AddCopyOption hook semantics
--
-- 本檔不測 StyleChatFrame 完整 frame-creation 流水線（CHANGELOG 規則：
-- "UI frame-creation 不適合 mock 測試"）— 只測 guard / 冪等 / 右鍵 trigger 等
-- 純邏輯部分。
--------------------------------------------------------------------------------

describe("ChatStyleChatFrame guards", function()
    local setFontCalls
    local originalSetFont

    before_each(function()
        LunarUI._chatStyledFrames = {}
        -- Reviewer 抓的：marker 在 function 結尾無條件設定，光看 marker 不能證明
        -- early-return。改 spy SetFont call count — StyleChatTab + StyleChatEditBox
        -- 內無 inner guard、每次跑都會呼叫；二次呼叫若 early-return，count 不增。
        originalSetFont = LunarUI.SetFont
        setFontCalls = 0
        LunarUI.SetFont = function()
            setFontCalls = setFontCalls + 1
        end
    end)

    after_each(function()
        LunarUI.SetFont = originalSetFont
    end)

    it("returns without error on nil chatFrame", function()
        assert.has_no_errors(function()
            LunarUI.ChatStyleChatFrame(nil)
        end)
        -- 沒任何 frame 被標記為 styled
        local cnt = 0
        for _ in pairs(LunarUI._chatStyledFrames) do
            cnt = cnt + 1
        end
        assert.equals(0, cnt)
        assert.equals(0, setFontCalls)
    end)

    it("marks frame as styled after first call (sets _chatStyledFrames[name])", function()
        -- 第一次呼叫應該成功完成（不關心內部副作用），_chatStyledFrames 應有對應 key
        local frame = _G.ChatFrame1
        assert.has_no_errors(function()
            LunarUI.ChatStyleChatFrame(frame)
        end)
        assert.is_true(LunarUI._chatStyledFrames["ChatFrame1"])
        assert.is_true(setFontCalls >= 1) -- StyleChatTab + StyleChatEditBox 至少呼叫過
    end)

    it("is idempotent: second call on same frame is a no-op (proven via SetFont not re-called)", function()
        local frame = _G.ChatFrame1
        LunarUI.ChatStyleChatFrame(frame)
        local firstPassCount = setFontCalls
        assert.is_true(firstPassCount >= 1, "first call should trigger SetFont at least once")
        assert.is_true(LunarUI._chatStyledFrames["ChatFrame1"])

        -- 第二次呼叫：若 early-return 移除，body 會重跑、SetFont 會再被呼叫。
        -- 此 assertion 真正鎖定「marker guard 是 first-line early-return」契約。
        assert.has_no_errors(function()
            LunarUI.ChatStyleChatFrame(frame)
        end)
        assert.equals(firstPassCount, setFontCalls)
    end)
end)

describe("ChatAddCopyOption hook semantics", function()
    local capturedHandlers

    before_each(function()
        -- 重置每個 tab 的 _lunarCopyHooked + 攔截 HookScript("OnClick", ...) 取得 handler
        capturedHandlers = {}
        for i = 1, 7 do
            local tab = _G["ChatFrame" .. i .. "Tab"]
            tab._lunarCopyHooked = nil
            -- 重置 _scripts（避免上個 test 殘留）
            rawset(tab, "_scripts", {})
            local origHookScript = mock_frame.MockFrame.HookScript
            tab.HookScript = function(self, name, fn)
                if name == "OnClick" then
                    capturedHandlers[i] = fn
                end
                return origHookScript(self, name, fn)
            end
        end
    end)

    it("sets _lunarCopyHooked = true on every chat tab on first call", function()
        LunarUI.ChatAddCopyOption()
        for i = 1, 7 do
            local tab = _G["ChatFrame" .. i .. "Tab"]
            assert.is_true(tab._lunarCopyHooked, "ChatFrame" .. i .. "Tab missing _lunarCopyHooked")
        end
    end)

    it("is idempotent: second call does not re-hook already-hooked tabs", function()
        LunarUI.ChatAddCopyOption()
        -- 清掉 capturedHandlers，看第二次有沒有再 hook
        local firstPassCount = 0
        for i = 1, 7 do
            if capturedHandlers[i] then
                firstPassCount = firstPassCount + 1
            end
        end
        assert.equals(7, firstPassCount)

        capturedHandlers = {}
        LunarUI.ChatAddCopyOption()
        local secondPassCount = 0
        for i = 1, 7 do
            if capturedHandlers[i] then
                secondPassCount = secondPassCount + 1
            end
        end
        assert.equals(0, secondPassCount) -- 第二次完全不該 hook
    end)

    it("right-button click on tab triggers copy flow (calls GetNumMessages on the chat frame)", function()
        local gnMsgCalls = 0
        _G.ChatFrame1.GetNumMessages = function()
            gnMsgCalls = gnMsgCalls + 1
            return 0 -- 無訊息 → 空字串 SetText（不關心內容，只關心 trigger）
        end

        LunarUI.ChatAddCopyOption()
        local clickHandler = capturedHandlers[1]
        assert.is_not_nil(clickHandler)
        -- 右鍵：應觸發 ShowCopyFrame → GetNumMessages 被呼叫
        clickHandler(_G.ChatFrame1Tab, "RightButton")
        assert.is_true(gnMsgCalls >= 1)
    end)

    it("left-button click on tab does NOT trigger copy flow", function()
        local gnMsgCalls = 0
        _G.ChatFrame1.GetNumMessages = function()
            gnMsgCalls = gnMsgCalls + 1
            return 0
        end

        LunarUI.ChatAddCopyOption()
        local clickHandler = capturedHandlers[1]
        assert.is_not_nil(clickHandler)
        clickHandler(_G.ChatFrame1Tab, "LeftButton")
        assert.equals(0, gnMsgCalls)
    end)
end)

--------------------------------------------------------------------------------
-- ChatFilters — ApplyChannelColors / RoleIconFilter / ShortenChannelNames
--
-- 既有 chat_spec 已覆蓋 ChatEmojiFilter / ChatSpamFilter / ChatFormatURL /
-- ChatAddURLsToMessage（4 個 export）。本段補另外 3 個 export 的測試。
--------------------------------------------------------------------------------

describe("ChatApplyChannelColors DB toggle", function()
    local changeChatColorCalls
    local originalChangeChatColor

    before_each(function()
        originalChangeChatColor = _G.ChangeChatColor
        changeChatColorCalls = 0
        _G.ChangeChatColor = function()
            changeChatColorCalls = changeChatColorCalls + 1
        end
    end)

    after_each(function()
        _G.ChangeChatColor = originalChangeChatColor
    end)

    it("does NOT call ChangeChatColor when improvedColors is false", function()
        chatDB.improvedColors = false
        LunarUI.ChatApplyChannelColors()
        assert.equals(0, changeChatColorCalls)
        chatDB.improvedColors = true -- restore
    end)

    it("calls ChangeChatColor for every CHANNEL_COLORS entry when improvedColors is true", function()
        chatDB.improvedColors = true
        LunarUI.ChatApplyChannelColors()
        -- CHANNEL_COLORS has 22 entries (SAY/YELL/EMOTE/WHISPER/...);
        -- 不寫死特定數字，只驗證 N > 0（DB toggle 真的有觸發迴圈）
        assert.is_true(changeChatColorCalls > 0)
        -- 但實際值應該不小於 SAY/YELL/PARTY/RAID 等基本頻道，至少 20+
        assert.is_true(changeChatColorCalls >= 20)
    end)
end)

describe("ChatRoleIconFilter", function()
    local roleFilter

    before_each(function()
        roleFilter = LunarUI.ChatRoleIconFilter
        chatDB.showRoleIcons = true
        -- 重置 internal cache（CleanupFilterState 會把 roleIconCacheDirty 設回 true）
        if LunarUI.ChatCleanupFilterState then
            LunarUI.ChatCleanupFilterState()
        end
    end)

    after_each(function()
        chatDB.showRoleIcons = false -- 還原預設
    end)

    it("passes through unchanged when showRoleIcons is false", function()
        chatDB.showRoleIcons = false
        local blocked, msg, author = roleFilter(nil, nil, "hi", "Alice")
        assert.is_false(blocked)
        assert.equals("hi", msg)
        assert.equals("Alice", author)
    end)

    it("passes through unchanged when msg is nil", function()
        local blocked, msg, author = roleFilter(nil, nil, nil, "Alice")
        assert.is_false(blocked)
        assert.is_nil(msg)
        assert.equals("Alice", author)
    end)

    it("passes through unchanged when author is nil", function()
        local blocked, msg, author = roleFilter(nil, nil, "hi", nil)
        assert.is_false(blocked)
        assert.equals("hi", msg)
        assert.is_nil(author)
    end)

    it("inserts TANK role icon prefix when author is a tank group member", function()
        -- 模擬 1 人小隊，party1 = "Alice"，role = TANK
        local origInRaid = _G.IsInRaid
        local origNumGroupMembers = _G.GetNumGroupMembers
        local origUnitName = _G.UnitName
        local origUnitRole = _G.UnitGroupRolesAssigned

        _G.IsInRaid = function()
            return false
        end
        _G.GetNumGroupMembers = function()
            return 2 -- 1 player + 1 group member (party1)
        end
        _G.UnitName = function(unit)
            if unit == "party1" then
                return "Alice"
            end
            if unit == "player" then
                return "TestPlayer"
            end
            return nil
        end
        _G.UnitGroupRolesAssigned = function(unit)
            if unit == "party1" then
                return "TANK"
            end
            return "NONE"
        end

        local blocked, msg, author = roleFilter(nil, nil, "hi", "Alice")
        assert.is_false(blocked)
        assert.equals("hi", msg)
        -- 應在 author 前加上 TANK icon + 空格
        assert.truthy(author:find("|TInterface\\LFGFrame", 1, true))
        assert.truthy(author:find("Alice", 1, true))
        -- icon 在前，author 在後
        assert.is_true(author:find("|t Alice", 1, true) ~= nil)

        -- restore
        _G.IsInRaid = origInRaid
        _G.GetNumGroupMembers = origNumGroupMembers
        _G.UnitName = origUnitName
        _G.UnitGroupRolesAssigned = origUnitRole
    end)

    it("does NOT insert icon when role assignment is NONE", function()
        local origNumGroupMembers = _G.GetNumGroupMembers
        local origUnitName = _G.UnitName
        local origUnitRole = _G.UnitGroupRolesAssigned

        _G.GetNumGroupMembers = function()
            return 2
        end
        _G.UnitName = function(unit)
            if unit == "party1" then
                return "Bob"
            end
            if unit == "player" then
                return "TestPlayer"
            end
            return nil
        end
        _G.UnitGroupRolesAssigned = function()
            return "NONE"
        end

        local _, _, author = roleFilter(nil, nil, "hi", "Bob")
        -- author 應原樣返回（無 icon 前綴）
        assert.equals("Bob", author)

        _G.GetNumGroupMembers = origNumGroupMembers
        _G.UnitName = origUnitName
        _G.UnitGroupRolesAssigned = origUnitRole
    end)
end)

describe("ChatShortenChannelNames", function()
    -- 注意：ChatShortenChannelNames 改全域 _G[chatType] + wrap _G.ChatFrameN.AddMessage。
    -- 此 describe 重點測 wrapped AddMessage 對 [N. ChannelName] 的 gsub 行為。
    local origAddMessages
    local capturedMessages

    before_each(function()
        chatDB.shortChannelNames = true
        capturedMessages = {}
        origAddMessages = {}
        -- ShortenChannelNames 有 early-return `if not ChatFrame_MessageEventHandler then return end`
        -- 測試環境沒有這個 Blizzard global，stub 成 truthy 讓 wrap 邏輯實際跑
        _G.ChatFrame_MessageEventHandler = _G.ChatFrame_MessageEventHandler or function() end
        -- ChatShortenChannelNames 會 wrap _chatFrames 內每個 frame 的 AddMessage。
        -- 但 _chatFrames 在 Chat.lua 初始化時設定，這個 spec 載入時已就緒。
        -- 我們直接準備 ChatFrame1 的 AddMessage 為可攔截版本後呼叫 ShortenChannelNames。
        _G.ChatFrame1._lunarShortChannelHooked = nil -- 強制重 wrap
        origAddMessages[1] = _G.ChatFrame1.AddMessage
        _G.ChatFrame1.AddMessage = function(_, msg)
            capturedMessages[#capturedMessages + 1] = msg
        end
        -- _chatSavedAddMessageFuncs / _chatFrames 在 Chat.lua init 時設定。
        -- 確保它們存在（chat_spec 已 load Chat.lua）：
        if not LunarUI._chatSavedAddMessageFuncs then
            LunarUI._chatSavedAddMessageFuncs = {}
        end
        if not LunarUI._chatFrames then
            LunarUI._chatFrames = { "ChatFrame1" }
        end
        LunarUI._chatSavedAddMessageFuncs["ChatFrame1"] = nil -- force fresh save
    end)

    after_each(function()
        _G.ChatFrame1.AddMessage = origAddMessages[1]
        _G.ChatFrame1._lunarShortChannelHooked = nil
    end)

    it("rewrites known numeric channel format [2. 交易] to short form", function()
        -- 先把 _G.CHAT_SAY_GET 等設一個會被 SHORT_CHANNEL_TYPES 命中的值
        -- 但 numeric channel 的 wrap 不靠 _G[chatType]，而是直接攔截 AddMessage 的 msg
        -- 並做 [(%d+)%.%s*(.-)%] gsub。需要 SHORT_CHANNEL_NAMES["交易"] 有對應。
        LunarUI.ChatShortenChannelNames()
        -- 模擬一條原始 chat 訊息傳進 AddMessage（含 [2. 交易] 前綴）
        _G.ChatFrame1:AddMessage("[2. 交易] Hello world")
        assert.equals(1, #capturedMessages)
        -- 訊息應已被縮短：[2.交]（SHORT_CHANNEL_NAMES["交易"] = "交"）
        -- 反向 assert（原前綴消失）+ 正向 assert（短前綴存在）+ body 保留
        -- 三條一起防 gsub 靜默產出空字串 / 錯誤替換的 regression class
        assert.is_nil(capturedMessages[1]:find("[2. 交易]", 1, true))
        assert.truthy(capturedMessages[1]:find("[2.交]", 1, true))
        assert.truthy(capturedMessages[1]:find("Hello world", 1, true))
    end)

    it("preserves unknown channel names with the numeric prefix intact", function()
        LunarUI.ChatShortenChannelNames()
        _G.ChatFrame1:AddMessage("[5. UnknownChannel] body")
        assert.equals(1, #capturedMessages)
        -- 未知 channel 不在 SHORT_CHANNEL_NAMES 表中：保留原名（但 gsub 仍會
        -- 把 "[5. UnknownChannel]" 重組成 "[5.UnknownChannel]"（少了空格）
        -- 這是 production gsub 的副作用，不是 bug — 驗證即可
        assert.truthy(capturedMessages[1]:find("UnknownChannel", 1, true))
        assert.truthy(capturedMessages[1]:find("body", 1, true))
    end)
end)
