--[[
    LunarUI Options - Nameplates section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Nameplates = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local LunarUI = ctx.LunarUI
    local RefreshUI = ctx.RefreshUI

    return {
        order = 5,
        type = "group",
        name = L.nameplates,
        desc = L.nameplatesDesc,
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L.enable,
                get = function()
                    return GetDB().nameplates.enabled
                end,
                set = function(_, v)
                    GetDB().nameplates.enabled = v
                    LunarUI:Print(L["RequiresReload"] or "需要重新載入介面才能生效")
                end,
                width = "full",
            },
            width = {
                order = 2,
                type = "range",
                name = L.width,
                min = 80,
                max = 200,
                step = 5,
                get = function()
                    return GetDB().nameplates.width
                end,
                set = function(_, v)
                    GetDB().nameplates.width = v
                    RefreshUI()
                end,
            },
            height = {
                order = 3,
                type = "range",
                name = L.height,
                min = 6,
                max = 30,
                step = 1,
                get = function()
                    return GetDB().nameplates.height
                end,
                set = function(_, v)
                    GetDB().nameplates.height = v
                    RefreshUI()
                end,
            },
            stackingDetection = {
                order = 4,
                type = "toggle",
                name = L.StackingDetection or "Stacking Detection",
                desc = L.StackingDetectionDesc
                    or "Offset overlapping nameplates so they don't cover each other (requires reload)",
                get = function()
                    return GetDB().nameplates.stackingDetection
                end,
                set = function(_, v)
                    GetDB().nameplates.stackingDetection = v
                    RefreshUI()
                end,
            },
            showHealthText = {
                order = 5,
                type = "toggle",
                name = L["ShowHealthText"] or "Show Health Text",
                desc = L["ShowHealthTextDesc"] or "Display health value text on nameplates",
                get = function()
                    return GetDB().nameplates.showHealthText
                end,
                set = function(_, v)
                    GetDB().nameplates.showHealthText = v
                    RefreshUI()
                end,
            },
            healthTextFormat = {
                order = 6,
                type = "select",
                name = L["HealthTextFormat"] or "Health Text Format",
                desc = L["HealthTextFormatDesc"] or "Format for health text display",
                values = {
                    percent = L["FormatPercent"] or "Percent",
                    current = L["FormatCurrent"] or "Current",
                    both = L["FormatCurrentPercent"] or "Current - Percent",
                },
                disabled = function()
                    return not GetDB().nameplates.showHealthText
                end,
                get = function()
                    return GetDB().nameplates.healthTextFormat
                end,
                set = function(_, v)
                    GetDB().nameplates.healthTextFormat = v
                    RefreshUI()
                end,
            },
            spacer1 = { order = 10, type = "description", name = "\n" },
            enemyHeader = {
                order = 11,
                type = "header",
                name = L.enemyNameplates,
            },
            enemyEnabled = {
                order = 12,
                type = "toggle",
                name = L.enable,
                get = function()
                    return GetDB().nameplates.enemy.enabled
                end,
                set = function(_, v)
                    GetDB().nameplates.enemy.enabled = v
                    RefreshUI()
                end,
            },
            enemyShowCastbar = {
                order = 13,
                type = "toggle",
                name = L.showCastbar,
                get = function()
                    return GetDB().nameplates.enemy.showCastbar
                end,
                set = function(_, v)
                    GetDB().nameplates.enemy.showCastbar = v
                    RefreshUI()
                end,
            },
            enemyShowAuras = {
                order = 14,
                type = "toggle",
                name = L.showAuras,
                get = function()
                    return GetDB().nameplates.enemy.showAuras
                end,
                set = function(_, v)
                    GetDB().nameplates.enemy.showAuras = v
                    RefreshUI()
                end,
            },
            enemyShowLevel = {
                order = 15,
                type = "toggle",
                name = L.NameplateLevel or "Level Text",
                desc = L.NameplateLevelDesc or "Show level text next to name on enemy nameplates (requires reload)",
                get = function()
                    return GetDB().nameplates.enemy.showLevel
                end,
                set = function(_, v)
                    GetDB().nameplates.enemy.showLevel = v
                    RefreshUI()
                end,
            },
            enemyShowQuestIcon = {
                order = 16,
                type = "toggle",
                name = L.QuestIcon or "Quest Icon",
                desc = L.QuestIconDesc or "Show quest objective icon on enemy nameplates (requires reload)",
                get = function()
                    return GetDB().nameplates.enemy.showQuestIcon
                end,
                set = function(_, v)
                    GetDB().nameplates.enemy.showQuestIcon = v
                    RefreshUI()
                end,
            },
            enemyShowBuffs = {
                order = 17,
                type = "toggle",
                name = L["ShowBuffs"] or "Show Buffs",
                desc = L["EnemyShowBuffsDesc"] or "Show stealable buffs on enemy nameplates",
                get = function()
                    return GetDB().nameplates.enemy.showBuffs
                end,
                set = function(_, v)
                    GetDB().nameplates.enemy.showBuffs = v
                    RefreshUI()
                end,
            },
            enemyBuffSize = {
                order = 18,
                type = "range",
                name = L["BuffSize"] or "Buff Size",
                min = 8,
                max = 30,
                step = 1,
                disabled = function()
                    return not GetDB().nameplates.enemy.showBuffs
                end,
                get = function()
                    return GetDB().nameplates.enemy.buffSize
                end,
                set = function(_, v)
                    GetDB().nameplates.enemy.buffSize = v
                    RefreshUI()
                end,
            },
            enemyMaxBuffs = {
                order = 19,
                type = "range",
                name = L["MaxBuffs"] or "Max Buffs",
                min = 0,
                max = 8,
                step = 1,
                disabled = function()
                    return not GetDB().nameplates.enemy.showBuffs
                end,
                get = function()
                    return GetDB().nameplates.enemy.maxBuffs
                end,
                set = function(_, v)
                    GetDB().nameplates.enemy.maxBuffs = v
                    RefreshUI()
                end,
            },
            spacer2 = { order = 20, type = "description", name = "\n" },
            friendlyHeader = {
                order = 21,
                type = "header",
                name = L.friendlyNameplates,
            },
            friendlyEnabled = {
                order = 22,
                type = "toggle",
                name = L.enable,
                get = function()
                    return GetDB().nameplates.friendly.enabled
                end,
                set = function(_, v)
                    GetDB().nameplates.friendly.enabled = v
                    RefreshUI()
                end,
            },
            friendlyShowHealth = {
                order = 23,
                type = "toggle",
                name = L.showHealth,
                get = function()
                    return GetDB().nameplates.friendly.showHealth
                end,
                set = function(_, v)
                    GetDB().nameplates.friendly.showHealth = v
                    RefreshUI()
                end,
            },
            friendlyShowLevel = {
                order = 24,
                type = "toggle",
                name = L.NameplateLevel or "Level Text",
                desc = L.NameplateLevelDesc or "Show level text next to name on friendly nameplates (requires reload)",
                get = function()
                    return GetDB().nameplates.friendly.showLevel
                end,
                set = function(_, v)
                    GetDB().nameplates.friendly.showLevel = v
                    RefreshUI()
                end,
            },
            spacer3 = { order = 30, type = "description", name = "\n" },
            npcColorsHeader = {
                order = 31,
                type = "header",
                name = L["NpcColors"] or "NPC Colors",
            },
            npcColorsEnabled = {
                order = 32,
                type = "toggle",
                name = L.enable,
                desc = L["NpcColorsDesc"] or "Color enemy nameplates by NPC role (caster, miniboss, etc.)",
                get = function()
                    return GetDB().nameplates.npcColors.enabled
                end,
                set = function(_, v)
                    GetDB().nameplates.npcColors.enabled = v
                    RefreshUI()
                end,
                width = "full",
            },
            spacer4 = { order = 40, type = "description", name = "\n" },
            highlightHeader = {
                order = 41,
                type = "header",
                name = L["Highlight"] or "Highlight",
            },
            highlightRare = {
                order = 42,
                type = "toggle",
                name = L["HighlightRare"] or "Rare",
                desc = L["HighlightRareDesc"] or "Highlight rare mobs on nameplates",
                get = function()
                    return GetDB().nameplates.highlight.rare
                end,
                set = function(_, v)
                    GetDB().nameplates.highlight.rare = v
                    RefreshUI()
                end,
            },
            highlightElite = {
                order = 43,
                type = "toggle",
                name = L["HighlightElite"] or "Elite",
                desc = L["HighlightEliteDesc"] or "Highlight elite mobs on nameplates",
                get = function()
                    return GetDB().nameplates.highlight.elite
                end,
                set = function(_, v)
                    GetDB().nameplates.highlight.elite = v
                    RefreshUI()
                end,
            },
            highlightBoss = {
                order = 44,
                type = "toggle",
                name = L["HighlightBoss"] or "Boss",
                desc = L["HighlightBossDesc"] or "Highlight boss mobs on nameplates",
                get = function()
                    return GetDB().nameplates.highlight.boss
                end,
                set = function(_, v)
                    GetDB().nameplates.highlight.boss = v
                    RefreshUI()
                end,
            },
        },
    }
end
