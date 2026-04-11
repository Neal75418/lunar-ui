--[[
    LunarUI Options - DataTexts section builder
    Bottom-of-screen info panels (FPS, latency, gold, ...)
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.DataTexts = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local RefreshUI = ctx.RefreshUI

    return {
        order = 10.4,
        type = "group",
        name = L["DataTexts"] or "Data Texts",
        desc = L["DataTextsDesc"] or "Information panels displayed at the bottom of the screen",
        args = (function()
            local DATATEXT_VALUES = {
                fps = "FPS",
                latency = "Latency",
                gold = "Gold",
                durability = "Durability",
                bagSlots = "Bag Slots",
                friends = "Friends",
                guild = "Guild",
                spec = "Specialization",
                clock = "Clock",
                coords = "Coordinates",
                none = "None",
            }

            local dtArgs = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    desc = L["DataTextsEnableDesc"] or "Enable LunarUI data text panels",
                    get = function()
                        return GetDB().datatexts.enabled
                    end,
                    set = function(_, v)
                        GetDB().datatexts.enabled = v
                        RefreshUI()
                    end,
                    width = "full",
                },
                bottomHeader = { order = 10, type = "header", name = L["BottomPanel"] or "Bottom Panel" },
                bottomEnabled = {
                    order = 11,
                    type = "toggle",
                    name = L.enable,
                    get = function()
                        return GetDB().datatexts.panels.bottom.enabled
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.bottom.enabled = v
                        RefreshUI()
                    end,
                },
                bottomHeight = {
                    order = 12,
                    type = "range",
                    name = L.height,
                    min = 16,
                    max = 40,
                    step = 1,
                    get = function()
                        return GetDB().datatexts.panels.bottom.height
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.bottom.height = v
                        RefreshUI()
                    end,
                },
                bottomLeft = {
                    order = 13,
                    type = "select",
                    name = L["SlotLeft"] or "Left Slot",
                    values = DATATEXT_VALUES,
                    get = function()
                        return GetDB().datatexts.panels.bottom.slots[1] or "none"
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.bottom.slots[1] = v
                        RefreshUI()
                    end,
                },
                bottomCenter = {
                    order = 14,
                    type = "select",
                    name = L["SlotCenter"] or "Center Slot",
                    values = DATATEXT_VALUES,
                    get = function()
                        return GetDB().datatexts.panels.bottom.slots[2] or "none"
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.bottom.slots[2] = v
                        RefreshUI()
                    end,
                },
                bottomRight = {
                    order = 15,
                    type = "select",
                    name = L["SlotRight"] or "Right Slot",
                    values = DATATEXT_VALUES,
                    get = function()
                        return GetDB().datatexts.panels.bottom.slots[3] or "none"
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.bottom.slots[3] = v
                        RefreshUI()
                    end,
                },
                minimapHeader = {
                    order = 20,
                    type = "header",
                    name = L["MinimapBottomPanel"] or "Minimap Bottom Panel",
                },
                minimapEnabled = {
                    order = 21,
                    type = "toggle",
                    name = L.enable,
                    get = function()
                        return GetDB().datatexts.panels.minimapBottom.enabled
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.minimapBottom.enabled = v
                        RefreshUI()
                    end,
                },
                minimapHeight = {
                    order = 22,
                    type = "range",
                    name = L.height,
                    min = 14,
                    max = 32,
                    step = 1,
                    get = function()
                        return GetDB().datatexts.panels.minimapBottom.height
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.minimapBottom.height = v
                        RefreshUI()
                    end,
                },
                minimapLeft = {
                    order = 23,
                    type = "select",
                    name = L["SlotLeft"] or "Left Slot",
                    values = DATATEXT_VALUES,
                    get = function()
                        return GetDB().datatexts.panels.minimapBottom.slots[1] or "none"
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.minimapBottom.slots[1] = v
                        RefreshUI()
                    end,
                },
                minimapRight = {
                    order = 24,
                    type = "select",
                    name = L["SlotRight"] or "Right Slot",
                    values = DATATEXT_VALUES,
                    get = function()
                        return GetDB().datatexts.panels.minimapBottom.slots[2] or "none"
                    end,
                    set = function(_, v)
                        GetDB().datatexts.panels.minimapBottom.slots[2] = v
                        RefreshUI()
                    end,
                },
            }

            return dtArgs
        end)(),
    }
end
