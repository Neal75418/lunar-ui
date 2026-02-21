---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Professions Frame
    Reskin ProfessionsFrame (專業技能面板) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinProfessionsFrame()
    local frame = LunarUI:SkinStandardFrame("ProfessionsFrame", {
        useTabSystem = true,
        textDepth = 3,
    })
    if not frame then
        return
    end

    -- 製造頁面
    if frame.CraftingPage then
        LunarUI.StripTextures(frame.CraftingPage)
        LunarUI:SkinFrameText(frame.CraftingPage, 3)

        -- 配方列表
        if frame.CraftingPage.RecipeList then
            LunarUI.StripTextures(frame.CraftingPage.RecipeList)
        end

        -- 搜尋框
        if frame.CraftingPage.RecipeList and frame.CraftingPage.RecipeList.SearchBox then
            LunarUI.SkinEditBox(frame.CraftingPage.RecipeList.SearchBox)
        end

        -- 製作詳情面板
        if frame.CraftingPage.SchematicForm then
            LunarUI.StripTextures(frame.CraftingPage.SchematicForm)
            LunarUI:SkinFrameText(frame.CraftingPage.SchematicForm, 2)
        end

        -- 製作按鈕
        if frame.CraftingPage.CreateButton then
            LunarUI.SkinButton(frame.CraftingPage.CreateButton)
        end
        if frame.CraftingPage.CreateAllButton then
            LunarUI.SkinButton(frame.CraftingPage.CreateAllButton)
        end
    end

    -- 訂單頁面
    if frame.OrdersPage then
        LunarUI.StripTextures(frame.OrdersPage)
        LunarUI:SkinFrameText(frame.OrdersPage, 2)
    end

    -- 專精頁面
    if frame.SpecPage then
        LunarUI.StripTextures(frame.SpecPage)
        LunarUI:SkinFrameText(frame.SpecPage, 2)
    end

    return true
end

-- ProfessionsFrame 為延遲載入 addon
LunarUI.RegisterSkin("professions", "Blizzard_Professions", SkinProfessionsFrame)
