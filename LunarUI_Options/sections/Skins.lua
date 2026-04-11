--[[
    LunarUI Options - Skins section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Skins = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB

    return {
        order = 11,
        type = "group",
        name = L.skins,
        desc = L.skinsDesc,
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L.enable,
                desc = L.skinsDesc,
                get = function()
                    return GetDB().skins.enabled
                end,
                set = function(_, v)
                    GetDB().skins.enabled = v
                end,
                width = "full",
            },
            character = {
                order = 2,
                type = "toggle",
                name = L.skinCharacter,
                get = function()
                    return GetDB().skins.blizzard.character
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.character = v
                end,
            },
            spellbook = {
                order = 3,
                type = "toggle",
                name = L.skinSpellbook,
                get = function()
                    return GetDB().skins.blizzard.spellbook
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.spellbook = v
                end,
            },
            talents = {
                order = 4,
                type = "toggle",
                name = L.skinTalents,
                get = function()
                    return GetDB().skins.blizzard.talents
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.talents = v
                end,
            },
            quest = {
                order = 5,
                type = "toggle",
                name = L.skinQuest,
                get = function()
                    return GetDB().skins.blizzard.quest
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.quest = v
                end,
            },
            merchant = {
                order = 6,
                type = "toggle",
                name = L.skinMerchant,
                get = function()
                    return GetDB().skins.blizzard.merchant
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.merchant = v
                end,
            },
            gossip = {
                order = 7,
                type = "toggle",
                name = L.skinGossip,
                get = function()
                    return GetDB().skins.blizzard.gossip
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.gossip = v
                end,
            },
            worldmap = {
                order = 8,
                type = "toggle",
                name = L.skinWorldMap,
                get = function()
                    return GetDB().skins.blizzard.worldmap
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.worldmap = v
                end,
            },
            achievements = {
                order = 9,
                type = "toggle",
                name = L.skinAchievements,
                get = function()
                    return GetDB().skins.blizzard.achievements
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.achievements = v
                end,
            },
            mail = {
                order = 10,
                type = "toggle",
                name = L.skinMail,
                get = function()
                    return GetDB().skins.blizzard.mail
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.mail = v
                end,
            },
            collections = {
                order = 11,
                type = "toggle",
                name = L.skinCollections,
                get = function()
                    return GetDB().skins.blizzard.collections
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.collections = v
                end,
            },
            lfg = {
                order = 12,
                type = "toggle",
                name = L.skinLFG,
                get = function()
                    return GetDB().skins.blizzard.lfg
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.lfg = v
                end,
            },
            encounterjournal = {
                order = 13,
                type = "toggle",
                name = L.skinEncounterJournal,
                get = function()
                    return GetDB().skins.blizzard.encounterjournal
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.encounterjournal = v
                end,
            },
            auctionhouse = {
                order = 14,
                type = "toggle",
                name = L.skinAuctionHouse,
                get = function()
                    return GetDB().skins.blizzard.auctionhouse
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.auctionhouse = v
                end,
            },
            communities = {
                order = 15,
                type = "toggle",
                name = L.skinCommunities,
                get = function()
                    return GetDB().skins.blizzard.communities
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.communities = v
                end,
            },
            calendar = {
                order = 16,
                type = "toggle",
                name = L.skinCalendar,
                get = function()
                    return GetDB().skins.blizzard.calendar
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.calendar = v
                end,
            },
            weeklyrewards = {
                order = 17,
                type = "toggle",
                name = L.skinWeeklyRewards,
                get = function()
                    return GetDB().skins.blizzard.weeklyrewards
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.weeklyrewards = v
                end,
            },
            addonlist = {
                order = 18,
                type = "toggle",
                name = L.skinAddonList,
                get = function()
                    return GetDB().skins.blizzard.addonlist
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.addonlist = v
                end,
            },
            housing = {
                order = 19,
                type = "toggle",
                name = L.skinHousing,
                get = function()
                    return GetDB().skins.blizzard.housing
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.housing = v
                end,
            },
            professions = {
                order = 20,
                type = "toggle",
                name = L.skinProfessions,
                get = function()
                    return GetDB().skins.blizzard.professions
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.professions = v
                end,
            },
            pvp = {
                order = 21,
                type = "toggle",
                name = L.skinPVP,
                get = function()
                    return GetDB().skins.blizzard.pvp
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.pvp = v
                end,
            },
            settings = {
                order = 22,
                type = "toggle",
                name = L.skinSettings,
                get = function()
                    return GetDB().skins.blizzard.settings
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.settings = v
                end,
            },
            trade = {
                order = 23,
                type = "toggle",
                name = L.skinTrade,
                get = function()
                    return GetDB().skins.blizzard.trade
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.trade = v
                end,
            },
            questmap = {
                order = 24,
                type = "toggle",
                name = L.skinQuestMap,
                get = function()
                    return GetDB().skins.blizzard.questmap
                end,
                set = function(_, v)
                    GetDB().skins.blizzard.questmap = v
                end,
            },
        },
    }
end
