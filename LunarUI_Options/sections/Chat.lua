--[[
    LunarUI Options - Chat section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Chat = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local LunarUI = ctx.LunarUI

    return {
        order = 8,
        type = "group",
        name = L.chat,
        desc = L.chatDesc,
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L.enable,
                get = function()
                    return GetDB().chat.enabled
                end,
                set = function(_, v)
                    GetDB().chat.enabled = v
                end,
                width = "full",
            },
            -- chat.width / chat.height 已移除（無生產代碼消費）
            improvedColors = {
                order = 4,
                type = "toggle",
                name = L.improvedColors,
                get = function()
                    return GetDB().chat.improvedColors
                end,
                set = function(_, v)
                    GetDB().chat.improvedColors = v
                end,
            },
            classColors = {
                order = 5,
                type = "toggle",
                name = L.classColors,
                get = function()
                    return GetDB().chat.classColors
                end,
                set = function(_, v)
                    GetDB().chat.classColors = v
                end,
            },
            detectURLs = {
                order = 5.1,
                type = "toggle",
                name = L["DetectURLs"] or "Clickable URLs",
                desc = L["DetectURLsDesc"] or "Make URLs in chat clickable",
                get = function()
                    return GetDB().chat.detectURLs
                end,
                set = function(_, v)
                    GetDB().chat.detectURLs = v
                end,
            },
            enableEmojis = {
                order = 5.2,
                type = "toggle",
                name = L["EnableEmojis"] or "Emoji Replacement",
                desc = L["EnableEmojisDesc"] or "Replace text emoticons with emoji icons",
                get = function()
                    return GetDB().chat.enableEmojis
                end,
                set = function(_, v)
                    GetDB().chat.enableEmojis = v
                end,
            },
            showRoleIcons = {
                order = 5.3,
                type = "toggle",
                name = L["ShowRoleIcons"] or "Role Icons",
                desc = L["ShowRoleIconsDesc"] or "Show tank/healer/DPS role icons in chat",
                get = function()
                    return GetDB().chat.showRoleIcons
                end,
                set = function(_, v)
                    GetDB().chat.showRoleIcons = v
                end,
            },
            keywordAlerts = {
                order = 5.4,
                type = "toggle",
                name = L["KeywordAlerts"] or "Keyword Alerts",
                desc = L["KeywordAlertsDesc"] or "Flash chat frame when keywords are mentioned",
                get = function()
                    return GetDB().chat.keywordAlerts
                end,
                set = function(_, v)
                    GetDB().chat.keywordAlerts = v
                end,
            },
            spamFilter = {
                order = 5.5,
                type = "toggle",
                name = L["SpamFilter"] or "Spam Filter",
                desc = L["SpamFilterDesc"] or "Filter duplicate and spam messages",
                get = function()
                    return GetDB().chat.spamFilter
                end,
                set = function(_, v)
                    GetDB().chat.spamFilter = v
                end,
            },
            linkTooltipPreview = {
                order = 5.6,
                type = "toggle",
                name = L["LinkTooltipPreview"] or "Link Tooltip Preview",
                desc = L["LinkTooltipPreviewDesc"]
                    or "Show tooltip preview when hovering over item/spell links in chat",
                get = function()
                    return GetDB().chat.linkTooltipPreview
                end,
                set = function(_, v)
                    GetDB().chat.linkTooltipPreview = v
                end,
            },
            showTimestamps = {
                order = 5.7,
                type = "toggle",
                name = L["ShowTimestamps"] or "Show Timestamps",
                desc = L["ShowTimestampsDesc"] or "Show timestamps on chat messages",
                get = function()
                    return GetDB().chat.showTimestamps
                end,
                set = function(_, v)
                    GetDB().chat.showTimestamps = v
                end,
            },
            shortChannelNames = {
                order = 5.75,
                type = "toggle",
                name = L["ShortChannelNames"] or "Short Channel Names",
                desc = L["ShortChannelNamesDesc"] or "Abbreviate channel names (e.g., Guild → [G])",
                get = function()
                    return GetDB().chat.shortChannelNames
                end,
                set = function(_, v)
                    GetDB().chat.shortChannelNames = v
                end,
                width = "full",
            },
            timestampFormat = {
                order = 5.8,
                type = "input",
                name = L["TimestampFormat"] or "Timestamp Format",
                desc = L["TimestampFormatDesc"] or "strftime format string for timestamps (e.g. %H:%M, %I:%M %p)",
                disabled = function()
                    return not GetDB().chat.showTimestamps
                end,
                get = function()
                    return GetDB().chat.timestampFormat
                end,
                set = function(_, v)
                    GetDB().chat.timestampFormat = v
                end,
            },
            fadeTime = {
                order = 9,
                type = "range",
                name = L.fadeTime,
                desc = L.fadeTimeDesc,
                min = 0,
                max = 600,
                step = 10,
                get = function()
                    return GetDB().chat.fadeTime
                end,
                set = function(_, v)
                    GetDB().chat.fadeTime = v
                    local ft = v <= 0 and 86400 or v
                    for i = 1, NUM_CHAT_WINDOWS do
                        local cf = _G["ChatFrame" .. i]
                        if cf and cf.SetTimeVisible then
                            cf:SetTimeVisible(ft)
                        end
                    end
                end,
            },
            backdropAlpha = {
                order = 10,
                type = "range",
                name = L.backdropAlpha,
                desc = L.backdropAlphaDesc,
                min = 0,
                max = 1,
                step = 0.05,
                get = function()
                    return GetDB().chat.backdropAlpha
                end,
                set = function(_, v)
                    GetDB().chat.backdropAlpha = v
                    local C = LunarUI.Colors
                    for i = 1, NUM_CHAT_WINDOWS do
                        local cf = _G["ChatFrame" .. i]
                        if cf and cf.LunarBackdrop then
                            cf.LunarBackdrop:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], v)
                        end
                    end
                end,
            },
            inactiveTabAlpha = {
                order = 11,
                type = "range",
                name = L.inactiveTabAlpha,
                desc = L.inactiveTabAlphaDesc,
                min = 0.1,
                max = 1,
                step = 0.05,
                get = function()
                    return GetDB().chat.inactiveTabAlpha
                end,
                set = function(_, v)
                    GetDB().chat.inactiveTabAlpha = v
                    -- 立即更新所有 tab 狀態
                    for i = 1, NUM_CHAT_WINDOWS do
                        local tab = _G["ChatFrame" .. i .. "Tab"]
                        if tab and tab._lunarUpdateActive then
                            tab._lunarUpdateActive()
                        end
                    end
                end,
            },
            editBoxOffset = {
                order = 12,
                type = "range",
                name = L.editBoxOffset,
                desc = L.editBoxOffsetDesc .. " (requires reload)",
                min = 0,
                max = 20,
                step = 1,
                get = function()
                    return GetDB().chat.editBoxOffset
                end,
                set = function(_, v)
                    GetDB().chat.editBoxOffset = v
                end,
            },
            spacerKeywords = { order = 13, type = "description", name = "\n" },
            keywords = {
                order = 14,
                type = "input",
                name = L.chatKeywords,
                desc = L.chatKeywordsDesc,
                multiline = false,
                width = "full",
                get = function()
                    local kw = GetDB().chat.keywords
                    if type(kw) ~= "table" then
                        return ""
                    end
                    return table.concat(kw, ", ")
                end,
                set = function(_, v)
                    local list = {}
                    for word in v:gmatch("[^,]+") do
                        word = word:match("^%s*(.-)%s*$") -- trim
                        if word and word ~= "" then
                            list[#list + 1] = word
                        end
                    end
                    GetDB().chat.keywords = list
                end,
            },
        },
    }
end
