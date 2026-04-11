--[[
    LunarUI Options - Loot section builder
    Builder pattern: returns AceConfig group spec via Private.sections.Loot(ctx)

    ctx fields: L, GetDB, RefreshUI, LunarUI
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Loot = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local LunarUI = ctx.LunarUI

    return {
        order = 10.3,
        type = "group",
        name = L["LootFrame"] or "Loot Frame",
        desc = L["LootFrameDesc"] or "Custom loot frame settings",
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L["LootFrame"] or "Custom Loot Frame",
                desc = L["LootFrameDesc"]
                    or "Replace the default loot window with a LunarUI-styled frame (requires reload)",
                get = function()
                    local db = GetDB()
                    return db and db.loot and db.loot.enabled
                end,
                set = function(_, v)
                    local db = GetDB()
                    if db and db.loot then
                        db.loot.enabled = v
                        -- hooksecurefunc 無法撤銷，需 /reload 生效
                        LunarUI:Print(L["RequiresReload"] or "|cffff8800Requires /reload to take effect|r")
                    end
                end,
                width = "full",
            },
        },
    }
end
