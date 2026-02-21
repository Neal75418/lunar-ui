---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Housing Frame
    Reskin HousingEditorFrame (WoW 12.0 家園系統) with LunarUI theme
    注意：框架名稱和 addon 名稱基於 12.0 PTR 資料，正式上線時需確認
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinHousingFrame()
    local frame = LunarUI:SkinStandardFrame("HousingEditorFrame", {
        textDepth = 3,
    })
    if not frame then
        return
    end

    -- 分類選擇面板
    if frame.CategoryList then
        LunarUI.StripTextures(frame.CategoryList)
        LunarUI:SkinFrameText(frame.CategoryList, 2)
    end

    -- 物件放置工具列
    if frame.PlacementBar then
        LunarUI.StripTextures(frame.PlacementBar)
    end

    -- 搜尋框
    if frame.SearchBox then
        LunarUI.SkinEditBox(frame.SearchBox)
    end

    -- 物件預覽面板
    if frame.PreviewFrame then
        LunarUI.StripTextures(frame.PreviewFrame)
    end

    return true
end

-- Housing UI 為延遲載入 addon（addon 名稱需 12.0 正式版確認）
LunarUI.RegisterSkin("housing", "Blizzard_HousingUI", SkinHousingFrame)
