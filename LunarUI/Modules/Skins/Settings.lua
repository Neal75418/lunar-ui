---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Settings Panel
    Reskin SettingsPanel (遊戲設定面板) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinSettingsPanel()
    local frame = LunarUI:SkinStandardFrame("SettingsPanel", {
        textDepth = 3,
    })
    if not frame then
        return
    end

    -- 左側分類列表
    if frame.CategoryList then
        LunarUI.StripTextures(frame.CategoryList)
        LunarUI:SkinFrameText(frame.CategoryList, 3)
    end

    -- 右側設定容器
    if frame.Container then
        LunarUI.StripTextures(frame.Container)
        LunarUI:SkinFrameText(frame.Container, 3)

        -- 設定畫布
        if frame.Container.SettingsCanvas then
            LunarUI.StripTextures(frame.Container.SettingsCanvas)
        end
    end

    -- 搜尋框
    if frame.SearchBox then
        LunarUI.SkinEditBox(frame.SearchBox)
    end

    -- 套用按鈕
    if frame.ApplyButton then
        LunarUI.SkinButton(frame.ApplyButton)
    end

    return true
end

-- SettingsPanel 為延遲載入 addon
LunarUI.RegisterSkin("settings", "Blizzard_Settings", SkinSettingsPanel)
