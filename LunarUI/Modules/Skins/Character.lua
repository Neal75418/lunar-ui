---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Character Frame
    Reskin CharacterFrame (角色面板) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors

local function SkinCharacterFrame()
    local frame = LunarUI:SkinStandardFrame("CharacterFrame", {
        tabPrefix = "CharacterFrameTab", tabCount = 4,
    })
    if not frame then return end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.CharacterFrameCloseButton then
        LunarUI.SkinCloseButton(_G.CharacterFrameCloseButton)
    end

    -- 角色名稱文字 fallback
    if not frame.TitleText and _G.CharacterFrameTitleText then
        LunarUI.SetFontLight(_G.CharacterFrameTitleText)
    end

    -- CharacterModelScene 背景（角色模型區域）
    if _G.CharacterModelScene then
        local bg = _G.CharacterModelScene:CreateTexture(nil, "BACKGROUND", nil, -8)
        if bg then
            bg:SetAllPoints()
            bg:SetColorTexture(0.03, 0.03, 0.03, 0.9)
        end
    end

    -- 裝備槽樣式化
    local slots = {
        "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot",
        "CharacterBackSlot", "CharacterChestSlot", "CharacterShirtSlot",
        "CharacterTabardSlot", "CharacterWristSlot", "CharacterHandsSlot",
        "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
        "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot",
        "CharacterTrinket1Slot", "CharacterMainHandSlot", "CharacterSecondaryHandSlot",
    }
    for _, slotName in ipairs(slots) do
        local slot = _G[slotName]
        if slot then
            -- 隱藏原始邊框材質
            if slot.IconBorder then
                slot.IconBorder:SetAlpha(0)
            end
            -- 新增 LunarUI 邊框
            if not slot._lunarBorder and BackdropTemplateMixin then
                local border = CreateFrame("Frame", nil, slot, "BackdropTemplate")
                border:SetPoint("TOPLEFT", -1, 1)
                border:SetPoint("BOTTOMRIGHT", 1, -1)
                border:SetBackdrop(LunarUI.iconBackdropTemplate)
                border:SetBackdropColor(0, 0, 0, 0)
                border:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
                border:SetFrameLevel(slot:GetFrameLevel() + 1)
                slot._lunarBorder = border
            end
        end
    end

    -- PaperDollFrame 內頁裝飾移除並修復文字
    if _G.PaperDollFrame then
        LunarUI.StripTextures(_G.PaperDollFrame)
        LunarUI:SkinFrameText(_G.PaperDollFrame, 2)
    end

    -- CharacterStatsPane 屬性面板（重要：屬性文字需要修復）
    if _G.CharacterStatsPane then
        LunarUI.StripTextures(_G.CharacterStatsPane)
        LunarUI:SkinFrameText(_G.CharacterStatsPane, 3)

        -- 特別處理屬性分類標題
        if _G.CharacterStatsPane.ClassBackground then
            _G.CharacterStatsPane.ClassBackground:SetAlpha(0)
        end
    end

    -- 裝備等級文字（WoW 12.0）
    if _G.PaperDollFrame and _G.PaperDollFrame.EquipmentManagerPane then
        LunarUI:SkinFrameText(_G.PaperDollFrame.EquipmentManagerPane, 2)
    end
    return true
end

-- 註冊 skin（角色面板在 PLAYER_ENTERING_WORLD 時可用）
LunarUI.RegisterSkin("character", "PLAYER_ENTERING_WORLD", SkinCharacterFrame)
