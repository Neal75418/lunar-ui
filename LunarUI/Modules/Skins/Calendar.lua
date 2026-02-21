---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Calendar Frame
    Reskin CalendarFrame (行事曆介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinCalendar()
    local frame = LunarUI:SkinStandardFrame("CalendarFrame")
    if not frame then
        return
    end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.CalendarCloseButton then
        LunarUI.SkinCloseButton(_G.CalendarCloseButton)
    end

    -- 月份導航按鈕
    if _G.CalendarPrevMonthButton then
        LunarUI.SkinButton(_G.CalendarPrevMonthButton)
    end
    if _G.CalendarNextMonthButton then
        LunarUI.SkinButton(_G.CalendarNextMonthButton)
    end

    -- 篩選按鈕
    if frame.FilterButton then
        LunarUI.SkinButton(frame.FilterButton)
    end

    -- 事件建立/檢視面板
    if _G.CalendarCreateEventFrame then
        LunarUI.StripTextures(_G.CalendarCreateEventFrame)
        if _G.CalendarCreateEventCreateButton then
            LunarUI.SkinButton(_G.CalendarCreateEventCreateButton)
        end
        if _G.CalendarCreateEventCloseButton then
            LunarUI.SkinCloseButton(_G.CalendarCreateEventCloseButton)
        end
    end

    if _G.CalendarViewEventFrame then
        LunarUI.StripTextures(_G.CalendarViewEventFrame)
        if _G.CalendarViewEventCloseButton then
            LunarUI.SkinCloseButton(_G.CalendarViewEventCloseButton)
        end
    end

    return true
end

-- CalendarFrame 透過 Blizzard_Calendar 載入
LunarUI.RegisterSkin("calendar", "Blizzard_Calendar", SkinCalendar)
