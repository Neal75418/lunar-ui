--[[
    LunarUI Options - DataBars section builder
    Experience / reputation / honor bar settings
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.DataBars = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local RefreshUI = ctx.RefreshUI
    local LunarUI = ctx.LunarUI

    return {
        order = 10.35,
        type = "group",
        name = L["DataBars"] or "Data Bars",
        desc = L["DataBarsDesc"] or "Experience, reputation, and honor bar settings",
        childGroups = "tab",
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L.enable,
                desc = L["DataBarsEnableDesc"] or "Enable LunarUI data bars",
                get = function()
                    return GetDB().databars.enabled
                end,
                set = function(_, v)
                    GetDB().databars.enabled = v
                    RefreshUI()
                end,
                width = "full",
            },
            experience = {
                order = 2,
                type = "group",
                name = L["Experience"] or "Experience",
                args = {
                    enabled = {
                        order = 1,
                        type = "toggle",
                        name = L.enable,
                        get = function()
                            return GetDB().databars.experience.enabled
                        end,
                        set = function(_, v)
                            GetDB().databars.experience.enabled = v
                            if LunarUI.RefreshDataBarsCache then
                                LunarUI.RefreshDataBarsCache()
                            end
                            RefreshUI()
                        end,
                        width = "full",
                    },
                    textFormat = {
                        order = 2,
                        type = "select",
                        name = L["TextFormat"] or "Text Format",
                        values = {
                            percent = L["FormatPercent"] or "Percent",
                            curmax = L["FormatCurrentMax"] or "Current / Max",
                            cur = L["FormatCurrent"] or "Current",
                            remaining = L["FormatRemaining"] or "Remaining",
                        },
                        get = function()
                            return GetDB().databars.experience.textFormat
                        end,
                        set = function(_, v)
                            GetDB().databars.experience.textFormat = v
                            if LunarUI.RefreshDataBarsCache then
                                LunarUI.RefreshDataBarsCache()
                            end
                            RefreshUI()
                        end,
                    },
                    height = {
                        order = 3,
                        type = "range",
                        name = L.height,
                        min = 4,
                        max = 20,
                        step = 1,
                        get = function()
                            return GetDB().databars.experience.height
                        end,
                        set = function(_, v)
                            GetDB().databars.experience.height = v
                            RefreshUI()
                        end,
                    },
                },
            },
            reputation = {
                order = 3,
                type = "group",
                name = L["Reputation"] or "Reputation",
                args = {
                    enabled = {
                        order = 1,
                        type = "toggle",
                        name = L.enable,
                        get = function()
                            return GetDB().databars.reputation.enabled
                        end,
                        set = function(_, v)
                            GetDB().databars.reputation.enabled = v
                            if LunarUI.RefreshDataBarsCache then
                                LunarUI.RefreshDataBarsCache()
                            end
                            RefreshUI()
                        end,
                        width = "full",
                    },
                    textFormat = {
                        order = 2,
                        type = "select",
                        name = L["TextFormat"] or "Text Format",
                        values = {
                            percent = L["FormatPercent"] or "Percent",
                            curmax = L["FormatCurrentMax"] or "Current / Max",
                            cur = L["FormatCurrent"] or "Current",
                            remaining = L["FormatRemaining"] or "Remaining",
                        },
                        get = function()
                            return GetDB().databars.reputation.textFormat
                        end,
                        set = function(_, v)
                            GetDB().databars.reputation.textFormat = v
                            if LunarUI.RefreshDataBarsCache then
                                LunarUI.RefreshDataBarsCache()
                            end
                            RefreshUI()
                        end,
                    },
                    height = {
                        order = 3,
                        type = "range",
                        name = L.height,
                        min = 4,
                        max = 20,
                        step = 1,
                        get = function()
                            return GetDB().databars.reputation.height
                        end,
                        set = function(_, v)
                            GetDB().databars.reputation.height = v
                            RefreshUI()
                        end,
                    },
                },
            },
            honor = {
                order = 4,
                type = "group",
                name = L["Honor"] or "Honor",
                args = {
                    enabled = {
                        order = 1,
                        type = "toggle",
                        name = L.enable,
                        get = function()
                            return GetDB().databars.honor.enabled
                        end,
                        set = function(_, v)
                            GetDB().databars.honor.enabled = v
                            if LunarUI.RefreshDataBarsCache then
                                LunarUI.RefreshDataBarsCache()
                            end
                            RefreshUI()
                        end,
                        width = "full",
                    },
                    textFormat = {
                        order = 2,
                        type = "select",
                        name = L["TextFormat"] or "Text Format",
                        values = {
                            percent = L["FormatPercent"] or "Percent",
                            curmax = L["FormatCurrentMax"] or "Current / Max",
                            cur = L["FormatCurrent"] or "Current",
                            remaining = L["FormatRemaining"] or "Remaining",
                        },
                        get = function()
                            return GetDB().databars.honor.textFormat
                        end,
                        set = function(_, v)
                            GetDB().databars.honor.textFormat = v
                            if LunarUI.RefreshDataBarsCache then
                                LunarUI.RefreshDataBarsCache()
                            end
                            RefreshUI()
                        end,
                    },
                    height = {
                        order = 3,
                        type = "range",
                        name = L.height,
                        min = 4,
                        max = 20,
                        step = 1,
                        get = function()
                            return GetDB().databars.honor.height
                        end,
                        set = function(_, v)
                            GetDB().databars.honor.height = v
                            RefreshUI()
                        end,
                    },
                },
            },
        },
    }
end
