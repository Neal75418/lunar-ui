--[[
    LunarUI Options - Automation section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Automation = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB

    return {
        order = 10.5,
        type = "group",
        name = L.automation,
        desc = L.automationDesc,
        args = {
            desc = {
                order = 0,
                type = "description",
                name = L.automationHeader,
            },
            autoRepair = {
                order = 1,
                type = "toggle",
                name = L.autoRepair,
                desc = L.autoRepairDesc,
                get = function()
                    return GetDB().automation.autoRepair
                end,
                set = function(_, v)
                    GetDB().automation.autoRepair = v
                end,
                width = "full",
            },
            useGuildRepair = {
                order = 2,
                type = "toggle",
                name = L.useGuildFunds,
                desc = L.useGuildFundsDesc,
                disabled = function()
                    return not GetDB().automation.autoRepair
                end,
                get = function()
                    return GetDB().automation.useGuildRepair
                end,
                set = function(_, v)
                    GetDB().automation.useGuildRepair = v
                end,
                width = "full",
            },
            spacer1 = { order = 5, type = "description", name = "\n" },
            autoRelease = {
                order = 6,
                type = "toggle",
                name = L.autoRelease,
                desc = L.autoReleaseDesc,
                get = function()
                    return GetDB().automation.autoRelease
                end,
                set = function(_, v)
                    GetDB().automation.autoRelease = v
                end,
                width = "full",
            },
            spacer2 = { order = 10, type = "description", name = "\n" },
            autoScreenshot = {
                order = 11,
                type = "toggle",
                name = L.achievementScreenshot,
                desc = L.achievementScreenshotDesc,
                get = function()
                    return GetDB().automation.autoScreenshot
                end,
                set = function(_, v)
                    GetDB().automation.autoScreenshot = v
                end,
                width = "full",
            },
            spacer3 = { order = 12, type = "description", name = "\n" },
            autoAcceptQuest = {
                order = 13,
                type = "toggle",
                name = L.autoAcceptQuest,
                desc = L.autoAcceptQuestDesc,
                get = function()
                    return GetDB().automation.autoAcceptQuest
                end,
                set = function(_, v)
                    GetDB().automation.autoAcceptQuest = v
                end,
                width = "full",
            },
            autoAcceptQueue = {
                order = 14,
                type = "toggle",
                name = L.autoAcceptQueue,
                desc = L.autoAcceptQueueDesc,
                get = function()
                    return GetDB().automation.autoAcceptQueue
                end,
                set = function(_, v)
                    GetDB().automation.autoAcceptQueue = v
                end,
                width = "full",
            },
        },
    }
end
