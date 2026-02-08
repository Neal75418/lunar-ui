---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Achievements Frame
    Reskin AchievementFrame (成就介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinAchievements()
    local frame = LunarUI:SkinStandardFrame("AchievementFrame", {
        tabPrefix = "AchievementFrameTab", tabCount = 3,
    })
    if not frame then return end

    -- 標題文字 fallback
    if not frame.TitleText and frame.Header and frame.Header.Title then
        LunarUI.SetFontLight(frame.Header.Title)
    end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.AchievementFrameCloseButton then
        LunarUI.SkinCloseButton(_G.AchievementFrameCloseButton)
    end

    -- 標題裝飾
    if frame.Header then
        LunarUI.StripTextures(frame.Header)
        LunarUI:SkinFrameText(frame.Header, 1)
    end

    -- 分類面板
    if _G.AchievementFrameCategories then
        LunarUI.StripTextures(_G.AchievementFrameCategories)
    end

    -- 成就列表面板
    if _G.AchievementFrameAchievements then
        LunarUI.StripTextures(_G.AchievementFrameAchievements)
    end

    -- 搜尋框
    if frame.SearchBox then
        LunarUI.StripTextures(frame.SearchBox)
    end

    -- 篩選下拉選單按鈕
    if frame.FilterButton then
        LunarUI.SkinButton(frame.FilterButton)
    end
    return true
end

-- AchievementFrame 透過 Blizzard_AchievementUI 載入
LunarUI.RegisterSkin("achievements", "Blizzard_AchievementUI", SkinAchievements)
