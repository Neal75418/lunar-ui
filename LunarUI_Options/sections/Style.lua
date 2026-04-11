--[[
    LunarUI Options - Visual Style section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Style = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local RefreshUI = ctx.RefreshUI

    return {
        order = 10,
        type = "group",
        name = L.style,
        desc = L.styleDesc,
        args = {
            font = {
                order = 1,
                type = "select",
                name = L.font,
                desc = L.fontDesc,
                values = function()
                    local LSM = LibStub("LibSharedMedia-3.0", true)
                    if not LSM then
                        return {}
                    end
                    local fonts = LSM:List("font")
                    local t = {}
                    for _, name in ipairs(fonts) do
                        t[name] = name
                    end
                    return t
                end,
                get = function()
                    return GetDB().style.font
                end,
                set = function(_, v)
                    GetDB().style.font = v
                    RefreshUI()
                end,
                width = "full",
            },
            statusBarTexture = {
                order = 2,
                type = "select",
                name = L.statusBarTexture,
                desc = L.statusBarTextureDesc,
                values = function()
                    local LSM = LibStub("LibSharedMedia-3.0", true)
                    if not LSM then
                        return {}
                    end
                    local bars = LSM:List("statusbar")
                    local t = {}
                    for _, name in ipairs(bars) do
                        t[name] = name
                    end
                    return t
                end,
                get = function()
                    return GetDB().style.statusBarTexture
                end,
                set = function(_, v)
                    GetDB().style.statusBarTexture = v
                    RefreshUI()
                end,
                width = "full",
            },
            -- theme/fontSize/borderStyle 已移除（無生產代碼消費）
        },
    }
end
