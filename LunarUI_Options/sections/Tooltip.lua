--[[
    LunarUI Options - Tooltip section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Tooltip = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local LunarUI = ctx.LunarUI

    return {
        order = 9,
        type = "group",
        name = L.tooltip,
        desc = L.tooltipDesc,
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L.enable,
                get = function()
                    return GetDB().tooltip.enabled
                end,
                set = function(_, v)
                    GetDB().tooltip.enabled = v
                    -- reversible 模組：直接走 Init/Cleanup 即時套用。
                    -- Init 內部會跳過已註冊 hooks；Cleanup 還原樣式並停 inspect 事件，
                    -- 永久性 HookScript 回呼在內部有 db.enabled guard，Cleanup 後不會再 re-style
                    if v then
                        if LunarUI.InitializeTooltip then
                            LunarUI.InitializeTooltip()
                        end
                    else
                        if LunarUI.CleanupTooltip then
                            LunarUI.CleanupTooltip()
                        end
                    end
                end,
                width = "full",
            },
            anchorCursor = {
                order = 2,
                type = "toggle",
                name = L.anchorToCursor,
                get = function()
                    return GetDB().tooltip.anchorCursor
                end,
                set = function(_, v)
                    GetDB().tooltip.anchorCursor = v
                end,
            },
            showItemLevel = {
                order = 3,
                type = "toggle",
                name = L.showItemLevel,
                get = function()
                    return GetDB().tooltip.showItemLevel
                end,
                set = function(_, v)
                    GetDB().tooltip.showItemLevel = v
                end,
            },
            showSpellID = {
                order = 4,
                type = "toggle",
                name = L.showSpellID,
                get = function()
                    return GetDB().tooltip.showSpellID
                end,
                set = function(_, v)
                    GetDB().tooltip.showSpellID = v
                end,
            },
            showItemID = {
                order = 5,
                type = "toggle",
                name = L.showItemID,
                get = function()
                    return GetDB().tooltip.showItemID
                end,
                set = function(_, v)
                    GetDB().tooltip.showItemID = v
                end,
            },
            showTargetTarget = {
                order = 6,
                type = "toggle",
                name = L.showTargetTarget,
                get = function()
                    return GetDB().tooltip.showTargetTarget
                end,
                set = function(_, v)
                    GetDB().tooltip.showTargetTarget = v
                end,
            },
            showItemCount = {
                order = 7,
                type = "toggle",
                name = L["ShowItemCount"] or "Show Item Count",
                desc = L["ShowItemCountDesc"] or "Show how many of an item you own across your characters",
                get = function()
                    return GetDB().tooltip.showItemCount
                end,
                set = function(_, v)
                    GetDB().tooltip.showItemCount = v
                end,
            },
        },
    }
end
