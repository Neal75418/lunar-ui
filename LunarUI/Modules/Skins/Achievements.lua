---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Achievements Frame
    Reskin AchievementFrame (成就介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinAchievements()
    local frame = AchievementFrame
    if not frame then return end

    -- 主框架背景
    LunarUI:SkinFrame(frame)

    -- 關閉按鈕
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
    elseif _G.AchievementFrameCloseButton then
        LunarUI:SkinCloseButton(_G.AchievementFrameCloseButton)
    end

    -- 標題裝飾
    if frame.Header then
        LunarUI.StripTextures(frame.Header)
    end

    -- 分頁（成就/統計）
    for i = 1, 3 do
        local tab = _G["AchievementFrameTab" .. i]
        if tab then
            LunarUI:SkinTab(tab)
        end
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
        LunarUI:SkinButton(frame.FilterButton)
    end
end

-- AchievementFrame 透過 Blizzard_AchievementUI 載入
LunarUI:RegisterSkin("achievements", "Blizzard_AchievementUI", SkinAchievements)
