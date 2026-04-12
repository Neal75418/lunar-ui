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
