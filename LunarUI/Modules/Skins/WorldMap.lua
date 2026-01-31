---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: World Map
    Reskin WorldMapFrame (世界地圖) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinWorldMap()
    local frame = WorldMapFrame
    if not frame then return end

    -- 主框架背景
    LunarUI:SkinFrame(frame)

    -- 邊框容器
    if frame.BorderFrame then
        LunarUI.StripTextures(frame.BorderFrame)

        -- 關閉按鈕
        if frame.BorderFrame.CloseButton then
            LunarUI:SkinCloseButton(frame.BorderFrame.CloseButton)
        end

        -- 最大化/最小化按鈕
        if frame.BorderFrame.MaximizeMinimizeFrame then
            LunarUI.StripTextures(frame.BorderFrame.MaximizeMinimizeFrame)
        end
    end

    -- Overlay 容器
    if frame.ScrollContainer then
        -- 保留地圖材質，僅移除邊框裝飾
        if frame.ScrollContainer.Border then
            frame.ScrollContainer.Border:SetAlpha(0)
        end
    end

    -- 導航欄（麵包屑列）
    if frame.NavBar then
        LunarUI.StripTextures(frame.NavBar)
        -- 返回按鈕
        if frame.NavBar.homeButton then
            LunarUI:SkinButton(frame.NavBar.homeButton)
        end
    end

    -- 側欄（任務追蹤）
    if frame.SidePanelToggle then
        LunarUI:SkinButton(frame.SidePanelToggle)
    end
end

-- WorldMapFrame 透過 Blizzard_WorldMap 載入
LunarUI:RegisterSkin("worldmap", "Blizzard_WorldMap", SkinWorldMap)
