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
    local LunarUI = ctx.LunarUI

    -- 子面板設定（enabled/height/slot provider）都在 InitializeDataTexts 時讀 DB：
    -- CreateDataPanel 讀 height、BindSlotToProvider 建立 slot 綁定。改完需 rebuild 才生效。
    -- 全域 datatexts.enabled=false 時 Init early-return，等同純 cleanup（語意正確）
    local function rebuild()
        if LunarUI.RebuildDataTexts then
            LunarUI.RebuildDataTexts()
        end
    end

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
                        rebuild()
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
                        rebuild()
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
                        rebuild()
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
                        rebuild()
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
                        rebuild()
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
                        rebuild()
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
                        rebuild()
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
                        rebuild()
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
                        rebuild()
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
                        rebuild()
                    end,
                },
            }

            return dtArgs
        end)(),
    }
end
