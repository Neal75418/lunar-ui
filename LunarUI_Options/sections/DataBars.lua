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
    local LunarUI = ctx.LunarUI

    -- enabled / textFormat / height 等子條設定都在 CreateDataBar / InitializeDataBars 時讀 DB，
    -- 必須 teardown + rebuild 才能即時套用（例如 OFF→ON 時 Initialize 已跳過建立 bar，
    -- 只靠 cache refresh 無法讓 UpdateBar 拿到可見的 frame）
    local function rebuild()
        if LunarUI.RebuildDataBars then
            LunarUI.RebuildDataBars()
        end
    end

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
                    LunarUI:Print(L["RequiresReload"] or "需要重新載入介面才能生效")
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
                            rebuild()
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
                            rebuild()
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
                            rebuild()
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
                            rebuild()
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
                            rebuild()
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
                            rebuild()
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
                            rebuild()
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
                            rebuild()
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
                            rebuild()
                        end,
                    },
                },
            },
        },
    }
end
