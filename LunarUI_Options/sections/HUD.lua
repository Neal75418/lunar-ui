--[[
    LunarUI Options - HUD section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.HUD = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local LunarUI = ctx.LunarUI

    return {
        order = 5.5,
        type = "group",
        name = L.hud,
        desc = L.hudDesc,
        childGroups = "tab",
        args = {
            -- 總覽分頁
            overview = {
                order = 1,
                type = "group",
                name = L["HUDOverview"],
                args = {
                    desc = {
                        order = 0,
                        type = "description",
                        name = L["HUDOverviewDesc"],
                    },
                    scale = {
                        order = 1,
                        type = "range",
                        name = L["HUDScale"],
                        desc = L["HUDScaleDesc"],
                        min = 0.5,
                        max = 2.0,
                        step = 0.05,
                        get = function()
                            return GetDB().hud.scale or 1.0
                        end,
                        set = function(_, v)
                            GetDB().hud.scale = v
                            if LunarUI.ApplyHUDScale then
                                LunarUI:ApplyHUDScale()
                            end
                        end,
                        width = "full",
                    },
                    modulesHeader = {
                        order = 5,
                        type = "header",
                        name = L["HUDModuleToggles"],
                    },
                    performanceMonitor = {
                        order = 10,
                        type = "toggle",
                        name = L["HUDPerfMonitor"],
                        desc = L["HUDPerfMonitorDesc"],
                        get = function()
                            return GetDB().hud.performanceMonitor
                        end,
                        set = function(_, v)
                            GetDB().hud.performanceMonitor = v
                            if v then
                                if LunarUI.InitPerformanceMonitor then
                                    LunarUI.InitPerformanceMonitor()
                                end
                            else
                                if LunarUI.CleanupPerformanceMonitor then
                                    LunarUI.CleanupPerformanceMonitor()
                                end
                            end
                        end,
                        width = "full",
                    },
                    classResources = {
                        order = 12,
                        type = "toggle",
                        name = L["HUDClassResources"],
                        desc = L["HUDClassResourcesDesc"],
                        get = function()
                            return GetDB().hud.classResources
                        end,
                        set = function(_, v)
                            GetDB().hud.classResources = v
                            if v then
                                if LunarUI.InitClassResources then
                                    LunarUI.InitClassResources()
                                end
                            else
                                if LunarUI.CleanupClassResources then
                                    LunarUI.CleanupClassResources()
                                end
                            end
                        end,
                        width = "full",
                    },
                    cooldownTracker = {
                        order = 13,
                        type = "toggle",
                        name = L["HUDCooldownTracker"],
                        desc = L["HUDCooldownTrackerDesc"],
                        get = function()
                            return GetDB().hud.cooldownTracker
                        end,
                        set = function(_, v)
                            GetDB().hud.cooldownTracker = v
                            if v then
                                if LunarUI.InitCooldownTracker then
                                    LunarUI.InitCooldownTracker()
                                end
                            else
                                if LunarUI.CleanupCooldownTracker then
                                    LunarUI.CleanupCooldownTracker()
                                end
                            end
                        end,
                        width = "full",
                    },
                    auraFrames = {
                        order = 14,
                        type = "toggle",
                        name = L["HUDAuraFrames"],
                        desc = L["HUDAuraFramesDesc"],
                        get = function()
                            return GetDB().hud.auraFrames
                        end,
                        set = function(_, v)
                            GetDB().hud.auraFrames = v
                            if v then
                                if LunarUI.InitAuraFrames then
                                    LunarUI.InitAuraFrames()
                                end
                            else
                                if LunarUI.CleanupAuraFrames then
                                    LunarUI.CleanupAuraFrames()
                                end
                            end
                        end,
                        width = "full",
                    },
                    fctEnabled = {
                        order = 15,
                        type = "toggle",
                        name = L["HUDFCTEnabled"],
                        desc = L["HUDFCTEnabledDesc"],
                        get = function()
                            return GetDB().hud.fctEnabled
                        end,
                        set = function(_, v)
                            GetDB().hud.fctEnabled = v
                            if v then
                                if LunarUI.InitFCT then
                                    LunarUI.InitFCT()
                                end
                            else
                                if LunarUI.CleanupFCT then
                                    LunarUI.CleanupFCT()
                                end
                            end
                        end,
                        width = "full",
                    },
                    fctWarning = {
                        order = 16,
                        type = "description",
                        name = L["HUDFCTWarning"],
                        hidden = function()
                            return not GetDB().hud.fctEnabled
                        end,
                    },
                },
            },

            -- 增減益框架分頁
            auraSettings = {
                order = 2,
                type = "group",
                name = L["HUDAuraFrames"],
                args = {
                    desc = {
                        order = 0,
                        type = "description",
                        name = L["HUDAuraSettingsDesc"],
                    },
                    auraIconSize = {
                        order = 1,
                        type = "range",
                        name = L["HUDIconSize"],
                        desc = L["HUDAuraIconSizeDesc"],
                        min = 24,
                        max = 64,
                        step = 2,
                        get = function()
                            return GetDB().hud.auraIconSize
                        end,
                        set = function(_, v)
                            GetDB().hud.auraIconSize = v
                            if LunarUI.RebuildAuraFrames then
                                LunarUI:RebuildAuraFrames()
                            end
                        end,
                        width = "full",
                    },
                    auraIconSpacing = {
                        order = 2,
                        type = "range",
                        name = L["HUDIconSpacing"],
                        desc = L["HUDIconSpacingDesc"],
                        min = 0,
                        max = 12,
                        step = 1,
                        get = function()
                            return GetDB().hud.auraIconSpacing
                        end,
                        set = function(_, v)
                            GetDB().hud.auraIconSpacing = v
                            if LunarUI.RebuildAuraFrames then
                                LunarUI:RebuildAuraFrames()
                            end
                        end,
                        width = "full",
                    },
                    auraIconsPerRow = {
                        order = 3,
                        type = "range",
                        name = L["HUDIconsPerRow"],
                        desc = L["HUDIconsPerRowDesc"],
                        min = 4,
                        max = 16,
                        step = 1,
                        get = function()
                            return GetDB().hud.auraIconsPerRow
                        end,
                        set = function(_, v)
                            GetDB().hud.auraIconsPerRow = v
                            if LunarUI.RebuildAuraFrames then
                                LunarUI:RebuildAuraFrames()
                            end
                        end,
                        width = "full",
                    },
                    maxBuffs = {
                        order = 4,
                        type = "range",
                        name = L["HUDMaxBuffs"],
                        desc = L["HUDMaxBuffsDesc"],
                        min = 4,
                        max = 40,
                        step = 1,
                        get = function()
                            return GetDB().hud.maxBuffs
                        end,
                        set = function(_, v)
                            GetDB().hud.maxBuffs = v
                            if LunarUI.RebuildAuraFrames then
                                LunarUI:RebuildAuraFrames()
                            end
                        end,
                        width = "full",
                    },
                    maxDebuffs = {
                        order = 5,
                        type = "range",
                        name = L["HUDMaxDebuffs"],
                        desc = L["HUDMaxDebuffsDesc"],
                        min = 4,
                        max = 20,
                        step = 1,
                        get = function()
                            return GetDB().hud.maxDebuffs
                        end,
                        set = function(_, v)
                            GetDB().hud.maxDebuffs = v
                            if LunarUI.RebuildAuraFrames then
                                LunarUI:RebuildAuraFrames()
                            end
                        end,
                        width = "full",
                    },
                    auraBarHeight = {
                        order = 6,
                        type = "range",
                        name = L["HUDAuraBarHeight"],
                        desc = L["HUDAuraBarHeightDesc"],
                        min = 2,
                        max = 10,
                        step = 1,
                        get = function()
                            return GetDB().hud.auraBarHeight
                        end,
                        set = function(_, v)
                            GetDB().hud.auraBarHeight = v
                            if LunarUI.RebuildAuraFrames then
                                LunarUI:RebuildAuraFrames()
                            end
                        end,
                        width = "full",
                    },
                },
            },

            -- 光環過濾分頁
            auraFiltering = {
                order = 2.5,
                type = "group",
                name = L.auraFiltering,
                args = {
                    desc = {
                        order = 0,
                        type = "description",
                        name = L.auraFilteringDesc,
                    },
                    whitelist = {
                        order = 1,
                        type = "input",
                        name = L.auraWhitelist,
                        desc = L.auraWhitelistDesc,
                        multiline = 3,
                        width = "full",
                        get = function()
                            return GetDB().auraWhitelist or ""
                        end,
                        set = function(_, v)
                            GetDB().auraWhitelist = v
                            -- 觸發快取重建
                            if LunarUI.RebuildAuraFilterCache then
                                LunarUI:RebuildAuraFilterCache()
                            end
                        end,
                    },
                    blacklist = {
                        order = 2,
                        type = "input",
                        name = L.auraBlacklist,
                        desc = L.auraBlacklistDesc,
                        multiline = 3,
                        width = "full",
                        get = function()
                            return GetDB().auraBlacklist or ""
                        end,
                        set = function(_, v)
                            GetDB().auraBlacklist = v
                            if LunarUI.RebuildAuraFilterCache then
                                LunarUI:RebuildAuraFilterCache()
                            end
                        end,
                    },
                    filterHeader = { order = 10, type = "header", name = L["FilterOptions"] or "Filter Options" },
                    hidePassive = {
                        order = 11,
                        type = "toggle",
                        name = L["HidePassive"] or "Hide Passive",
                        desc = L["HidePassiveDesc"]
                            or "Hide passive effects (buffs lasting more than 5 minutes or permanent)",
                        get = function()
                            return GetDB().auraFilters.hidePassive
                        end,
                        set = function(_, v)
                            GetDB().auraFilters.hidePassive = v
                            if LunarUI.RebuildAuraFilterCache then
                                LunarUI:RebuildAuraFilterCache()
                            end
                        end,
                    },
                    showStealable = {
                        order = 12,
                        type = "toggle",
                        name = L["ShowStealable"] or "Show Stealable",
                        desc = L["ShowStealableDesc"] or "Show stealable buffs on enemy targets",
                        get = function()
                            return GetDB().auraFilters.showStealable
                        end,
                        set = function(_, v)
                            GetDB().auraFilters.showStealable = v
                            if LunarUI.RebuildAuraFilterCache then
                                LunarUI:RebuildAuraFilterCache()
                            end
                        end,
                    },
                    sortMethod = {
                        order = 13,
                        type = "select",
                        name = L["SortMethod"] or "Sort Method",
                        desc = L["SortMethodDesc"] or "How to sort auras on unit frames",
                        values = {
                            time = L["SortByTime"] or "Time Remaining",
                            duration = L["SortByDuration"] or "Duration",
                            name = L["SortByName"] or "Name",
                            player = L["SortByPlayer"] or "Player First",
                        },
                        get = function()
                            return GetDB().auraFilters.sortMethod
                        end,
                        set = function(_, v)
                            GetDB().auraFilters.sortMethod = v
                            if LunarUI.RebuildAuraFilterCache then
                                LunarUI:RebuildAuraFilterCache()
                            end
                        end,
                    },
                    sortReverse = {
                        order = 14,
                        type = "toggle",
                        name = L["SortReverse"] or "Reverse Sort",
                        desc = L["SortReverseDesc"] or "Reverse the aura sort order",
                        get = function()
                            return GetDB().auraFilters.sortReverse
                        end,
                        set = function(_, v)
                            GetDB().auraFilters.sortReverse = v
                            if LunarUI.RebuildAuraFilterCache then
                                LunarUI:RebuildAuraFilterCache()
                            end
                        end,
                    },
                },
            },

            -- 冷卻追蹤分頁
            cdSettings = {
                order = 4,
                type = "group",
                name = L["HUDCDSettings"],
                args = {
                    desc = {
                        order = 0,
                        type = "description",
                        name = L["HUDCDSettingsDesc"],
                    },
                    cdIconSize = {
                        order = 1,
                        type = "range",
                        name = L["HUDIconSize"],
                        desc = L["HUDCDIconSizeDesc"],
                        min = 24,
                        max = 56,
                        step = 2,
                        get = function()
                            return GetDB().hud.cdIconSize
                        end,
                        set = function(_, v)
                            GetDB().hud.cdIconSize = v
                            if LunarUI.RebuildCooldownTracker then
                                LunarUI:RebuildCooldownTracker()
                            end
                        end,
                        width = "full",
                    },
                    cdIconSpacing = {
                        order = 2,
                        type = "range",
                        name = L["HUDIconSpacing"],
                        desc = L["HUDIconSpacingDesc"],
                        min = 0,
                        max = 12,
                        step = 1,
                        get = function()
                            return GetDB().hud.cdIconSpacing
                        end,
                        set = function(_, v)
                            GetDB().hud.cdIconSpacing = v
                            if LunarUI.RebuildCooldownTracker then
                                LunarUI:RebuildCooldownTracker()
                            end
                        end,
                        width = "full",
                    },
                    cdMaxIcons = {
                        order = 3,
                        type = "range",
                        name = L["HUDCDMaxIcons"],
                        desc = L["HUDCDMaxIconsDesc"],
                        min = 3,
                        max = 16,
                        step = 1,
                        get = function()
                            return GetDB().hud.cdMaxIcons
                        end,
                        set = function(_, v)
                            GetDB().hud.cdMaxIcons = v
                            if LunarUI.RebuildCooldownTracker then
                                LunarUI:RebuildCooldownTracker()
                            end
                        end,
                        width = "full",
                    },
                },
            },

            -- 職業資源分頁
            crSettings = {
                order = 5,
                type = "group",
                name = L["HUDClassResources"],
                args = {
                    desc = {
                        order = 0,
                        type = "description",
                        name = L["HUDCRSettingsDesc"],
                    },
                    crIconSize = {
                        order = 1,
                        type = "range",
                        name = L["HUDIconSize"],
                        desc = L["HUDCRIconSizeDesc"],
                        min = 16,
                        max = 48,
                        step = 2,
                        get = function()
                            return GetDB().hud.crIconSize
                        end,
                        set = function(_, v)
                            GetDB().hud.crIconSize = v
                            if LunarUI.RebuildClassResources then
                                LunarUI:RebuildClassResources()
                            end
                        end,
                        width = "full",
                    },
                    crIconSpacing = {
                        order = 2,
                        type = "range",
                        name = L["HUDIconSpacing"],
                        desc = L["HUDCRIconSpacingDesc"],
                        min = 0,
                        max = 12,
                        step = 1,
                        get = function()
                            return GetDB().hud.crIconSpacing
                        end,
                        set = function(_, v)
                            GetDB().hud.crIconSpacing = v
                            if LunarUI.RebuildClassResources then
                                LunarUI:RebuildClassResources()
                            end
                        end,
                        width = "full",
                    },
                    crBarHeight = {
                        order = 3,
                        type = "range",
                        name = L["HUDCRBarHeight"],
                        desc = L["HUDCRBarHeightDesc"],
                        min = 4,
                        max = 20,
                        step = 1,
                        get = function()
                            return GetDB().hud.crBarHeight
                        end,
                        set = function(_, v)
                            GetDB().hud.crBarHeight = v
                            if LunarUI.RebuildClassResources then
                                LunarUI:RebuildClassResources()
                            end
                        end,
                        width = "full",
                    },
                },
            },
        },
    }
end
