--[[
    LunarUI Options - FrameMover section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.FrameMover = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local LunarUI = ctx.LunarUI

    return {
        order = 9.5,
        type = "group",
        name = L["FrameMover"],
        desc = L["FrameMoverDesc"],
        args = {
            desc = {
                order = 0,
                type = "description",
                name = L["FrameMoverSettingsDesc"],
            },
            gridSize = {
                order = 1,
                type = "range",
                name = L["GridSize"],
                desc = L["GridSizeDesc"],
                min = 1,
                max = 40,
                step = 1,
                get = function()
                    local db = GetDB()
                    return db and db.frameMover and db.frameMover.gridSize or 10
                end,
                set = function(_, v)
                    local db = GetDB()
                    if not db then
                        return
                    end
                    if not db.frameMover then
                        db.frameMover = {}
                    end
                    db.frameMover.gridSize = v
                    if LunarUI.LoadFrameMoverSettings then
                        LunarUI.LoadFrameMoverSettings()
                    end
                end,
                width = "full",
            },
            moverAlpha = {
                order = 2,
                type = "range",
                name = L["MoverAlpha"],
                desc = L["MoverAlphaDesc"],
                min = 0.1,
                max = 1.0,
                step = 0.05,
                get = function()
                    local db = GetDB()
                    return db and db.frameMover and db.frameMover.moverAlpha or 0.6
                end,
                set = function(_, v)
                    local db = GetDB()
                    if not db then
                        return
                    end
                    if not db.frameMover then
                        db.frameMover = {}
                    end
                    db.frameMover.moverAlpha = v
                    if LunarUI.LoadFrameMoverSettings then
                        LunarUI.LoadFrameMoverSettings()
                    end
                end,
                width = "full",
            },
        },
    }
end
