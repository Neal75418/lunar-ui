---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Modules/Chat.lua
    Tests emoji replacement, URL detection, spam filtering, keyword matching
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.GetTime = function()
    return 1000
end
_G.UnitName = function()
    return "TestPlayer"
end
_G.IsInRaid = function()
    return false
end
_G.GetNumGroupMembers = function()
    return 0
end
_G.InCombatLockdown = function()
    return false
end
_G.IsShiftKeyDown = function()
    return false
end
_G.IsControlKeyDown = function()
    return false
end
_G.C_Timer = { After = function() end }
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
    Colors = {
        bg = { 0.05, 0.05, 0.05 },
        bgSolid = { 0.05, 0.05, 0.05, 1 },
        border = { 0.3, 0.3, 0.4 },
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
    -- Find the emoji filter in registered filters
    local emojiFilter
    for _, entry in ipairs(registeredFilters) do
        -- Call each filter with a smiley face and check if it returns the icon
        local _blocked, result = entry.func(nil, nil, ":)")
        if result and result:find("INV_Misc_Food_11") then
            emojiFilter = entry.func
            break
        end
    end

    if not emojiFilter then
        -- Filters were registered, let's find any emoji-related one
        -- Try all filters to find the one that handles emojis
        for _, entry in ipairs(registeredFilters) do
            local ok, _blocked, result = pcall(entry.func, nil, nil, ":)")
            if ok and result and type(result) == "string" and result ~= ":)" then
                emojiFilter = entry.func
                break
            end
        end
    end

    it("replaces :) with food icon", function()
        if not emojiFilter then
            error("emoji filter not captured — filter discovery failed")
            return
        end
        local _, result = emojiFilter(nil, nil, "Hello :)")
        assert.truthy(result:find("INV_Misc_Food_11"))
    end)

    it("replaces :D with guidance icon", function()
        if not emojiFilter then
            error("emoji filter not captured — filter discovery failed")
            return
        end
        local _, result = emojiFilter(nil, nil, "LOL :D")
        assert.truthy(result:find("Spell_Holy_HolyGuidance"))
    end)

    it("replaces <3 with candy icon", function()
        if not emojiFilter then
            error("emoji filter not captured — filter discovery failed")
            return
        end
        local _, result = emojiFilter(nil, nil, "I love you <3")
        assert.truthy(result:find("INV_ValentinesCandy"))
    end)

    it("does not modify messages without emojis", function()
        if not emojiFilter then
            error("emoji filter not captured — filter discovery failed")
            return
        end
        local _, result = emojiFilter(nil, nil, "Hello world")
        assert.equals("Hello world", result)
    end)

    it("handles nil message gracefully", function()
        if not emojiFilter then
            error("emoji filter not captured — filter discovery failed")
            return
        end
        local blocked, result = emojiFilter(nil, nil, nil)
        assert.is_false(blocked)
        assert.is_nil(result)
    end)

    it("preserves unmatched 2-char sequences (M7 fix)", function()
        if not emojiFilter then
            error("emoji filter not captured — filter discovery failed")
            return
        end
        -- :X is not in EMOJI_MAP, should be preserved
        local _, result = emojiFilter(nil, nil, "test :X end")
        assert.equals("test :X end", result)
    end)
end)

--------------------------------------------------------------------------------
-- Spam Filter
--------------------------------------------------------------------------------

describe("Chat spam filter", function()
    local spamFilter
    for _, entry in ipairs(registeredFilters) do
        -- Find the filter that blocks spam
        local ok, blocked = pcall(entry.func, nil, nil, "buy gold cheap www.gold.com", "Spammer")
        if ok and blocked == true then
            spamFilter = entry.func
            break
        end
    end

    it("blocks messages with gold selling", function()
        if not spamFilter then
            error("spam filter not captured — filter discovery failed")
            return
        end
        local blocked = spamFilter(nil, nil, "buy gold cheap only $5", "Spammer")
        assert.is_true(blocked)
    end)

    it("blocks messages with www URLs", function()
        if not spamFilter then
            error("spam filter not captured — filter discovery failed")
            return
        end
        local blocked = spamFilter(nil, nil, "visit www.gold-shop.com for deals", "Spammer")
        assert.is_true(blocked)
    end)

    it("blocks power leveling ads", function()
        if not spamFilter then
            error("spam filter not captured — filter discovery failed")
            return
        end
        local blocked = spamFilter(nil, nil, "power level your character fast!", "Spammer")
        assert.is_true(blocked)
    end)

    it("does not block normal messages", function()
        if not spamFilter then
            error("spam filter not captured — filter discovery failed")
            return
        end
        local blocked = spamFilter(nil, nil, "LF healer for mythic+", "Player")
        assert.is_false(blocked)
    end)

    it("handles nil message", function()
        if not spamFilter then
            error("spam filter not captured — filter discovery failed")
            return
        end
        local blocked, _msg = spamFilter(nil, nil, nil, "Player")
        assert.is_false(blocked)
    end)
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("Chat lifecycle", function()
    it("exports InitializeChat function", function()
        assert.is_function(LunarUI.InitializeChat)
    end)

    it("exports ShowChatCopy function", function()
        assert.is_function(LunarUI.ShowChatCopy)
    end)
end)
