--[[
    LunarUI Options - Bags section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Bags = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local LunarUI = ctx.LunarUI

    return {
        order = 7,
        type = "group",
        name = L.bags,
        desc = L.bagsDesc,
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L.enable,
                get = function()
                    return GetDB().bags.enabled
                end,
                set = function(_, v)
                    GetDB().bags.enabled = v
                end,
                width = "full",
            },
            layoutHeader = {
                order = 2,
                type = "header",
                name = L.layout,
            },
            slotsPerRow = {
                order = 3,
                type = "range",
                name = L.slotsPerRow,
                min = 6,
                max = 24,
                step = 1,
                get = function()
                    return GetDB().bags.slotsPerRow
                end,
                set = function(_, v)
                    GetDB().bags.slotsPerRow = v
                    if LunarUI.RebuildBags then
                        LunarUI:RebuildBags()
                    end
                end,
            },
            slotSize = {
                order = 4,
                type = "range",
                name = L.slotSize,
                min = 28,
                max = 48,
                step = 1,
                get = function()
                    return GetDB().bags.slotSize
                end,
                set = function(_, v)
                    GetDB().bags.slotSize = v
                    if LunarUI.RebuildBags then
                        LunarUI:RebuildBags()
                    end
                end,
            },
            slotSpacing = {
                order = 5,
                type = "range",
                name = L.slotSpacing,
                min = 0,
                max = 8,
                step = 1,
                get = function()
                    return GetDB().bags.slotSpacing
                end,
                set = function(_, v)
                    GetDB().bags.slotSpacing = v
                    if LunarUI.RebuildBags then
                        LunarUI:RebuildBags()
                    end
                end,
            },
            frameAlpha = {
                order = 6,
                type = "range",
                name = L.backgroundOpacity,
                min = 0.3,
                max = 1.0,
                step = 0.05,
                isPercent = true,
                get = function()
                    return GetDB().bags.frameAlpha
                end,
                set = function(_, v)
                    GetDB().bags.frameAlpha = v
                    if LunarUI.RebuildBags then
                        LunarUI:RebuildBags()
                    end
                end,
            },
            reverseBagSlots = {
                order = 7,
                type = "toggle",
                name = L.reverseBagSlots,
                desc = L.reverseBagSlotsDesc,
                get = function()
                    return GetDB().bags.reverseBagSlots
                end,
                set = function(_, v)
                    GetDB().bags.reverseBagSlots = v
                    if LunarUI.RebuildBags then
                        LunarUI:RebuildBags()
                    end
                end,
            },
            splitBags = {
                order = 8,
                type = "toggle",
                name = L.splitBags,
                desc = L.splitBagsDesc,
                get = function()
                    return GetDB().bags.splitBags
                end,
                set = function(_, v)
                    GetDB().bags.splitBags = v
                    if LunarUI.RebuildBags then
                        LunarUI:RebuildBags()
                    end
                end,
            },
            displayHeader = {
                order = 10,
                type = "header",
                name = L.display,
            },
            showItemLevel = {
                order = 11,
                type = "toggle",
                name = L.showItemLevel,
                get = function()
                    return GetDB().bags.showItemLevel
                end,
                set = function(_, v)
                    GetDB().bags.showItemLevel = v
                end,
            },
            ilvlThreshold = {
                order = 12,
                type = "range",
                name = L.ilvlThreshold,
                desc = L.ilvlThresholdDesc,
                min = 1,
                max = 600,
                step = 1,
                get = function()
                    return GetDB().bags.ilvlThreshold
                end,
                set = function(_, v)
                    GetDB().bags.ilvlThreshold = v
                end,
            },
            showBindType = {
                order = 13,
                type = "toggle",
                name = L.showBindType,
                desc = L.showBindTypeDesc,
                get = function()
                    return GetDB().bags.showBindType
                end,
                set = function(_, v)
                    GetDB().bags.showBindType = v
                end,
            },
            showCooldown = {
                order = 14,
                type = "toggle",
                name = L.showCooldowns,
                desc = L.showCooldownsDesc,
                get = function()
                    return GetDB().bags.showCooldown
                end,
                set = function(_, v)
                    GetDB().bags.showCooldown = v
                end,
            },
            showNewGlow = {
                order = 15,
                type = "toggle",
                name = L.newItemGlow,
                desc = L.newItemGlowDesc,
                get = function()
                    return GetDB().bags.showNewGlow
                end,
                set = function(_, v)
                    GetDB().bags.showNewGlow = v
                end,
            },
            showQuestItems = {
                order = 16,
                type = "toggle",
                name = L.showQuestItems,
                desc = L.showQuestItemsDesc,
                get = function()
                    return GetDB().bags.showQuestItems
                end,
                set = function(_, v)
                    GetDB().bags.showQuestItems = v
                end,
            },
            showProfessionColors = {
                order = 17,
                type = "toggle",
                name = L.professionBagColors,
                desc = L.professionBagColorsDesc,
                get = function()
                    return GetDB().bags.showProfessionColors
                end,
                set = function(_, v)
                    GetDB().bags.showProfessionColors = v
                end,
            },
            showUpgradeArrow = {
                order = 18,
                type = "toggle",
                name = L.upgradeArrow,
                desc = L.upgradeArrowDesc,
                get = function()
                    return GetDB().bags.showUpgradeArrow
                end,
                set = function(_, v)
                    GetDB().bags.showUpgradeArrow = v
                end,
            },
            behaviorHeader = {
                order = 20,
                type = "header",
                name = L.behavior,
            },
            autoSellJunk = {
                order = 21,
                type = "toggle",
                name = L.autoSellJunk,
                get = function()
                    return GetDB().bags.autoSellJunk
                end,
                set = function(_, v)
                    GetDB().bags.autoSellJunk = v
                end,
            },
            clearSearchOnClose = {
                order = 22,
                type = "toggle",
                name = L.clearSearchOnClose,
                desc = L.clearSearchOnCloseDesc,
                get = function()
                    return GetDB().bags.clearSearchOnClose
                end,
                set = function(_, v)
                    GetDB().bags.clearSearchOnClose = v
                end,
            },
            resetPosition = {
                order = 30,
                type = "execute",
                name = L.resetPosition,
                desc = L.resetPositionDesc,
                func = function()
                    local bagDb = GetDB().bags
                    bagDb.bagPosition = nil
                    bagDb.bankPosition = nil
                    if LunarUI.RebuildBags then
                        LunarUI:RebuildBags()
                    end
                end,
            },
        },
    }
end
