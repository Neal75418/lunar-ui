--[[
    LunarUI Options - General section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.General = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local LunarUI = ctx.LunarUI

    return {
        order = 1,
        type = "group",
        name = L.general,
        desc = L.generalDesc,
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L.enable,
                desc = L["EnableLunarUI"] or "Enable LunarUI",
                get = function()
                    return GetDB().enabled
                end,
                set = function(_, v)
                    GetDB().enabled = v
                end,
                width = "full",
            },
            debug = {
                order = 2,
                type = "toggle",
                name = L.debugMode,
                desc = L["DebugModeDesc"] or "Show debug overlay with FPS and memory info",
                get = function()
                    return GetDB().debug
                end,
                set = function(_, v)
                    GetDB().debug = v
                    if v then
                        LunarUI:ShowDebugOverlay()
                    else
                        LunarUI:HideDebugOverlay()
                    end
                end,
                width = "full",
            },
        },
    }
end
