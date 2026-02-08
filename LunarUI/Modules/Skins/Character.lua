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
        LunarUI:SkinCloseButton(_G.CharacterFrameCloseButton)
    end

    -- 角色名稱文字 fallback
    if not frame.TitleText and _G.CharacterFrameTitleText then
        LunarUI:SetFontLight(_G.CharacterFrameTitleText)
    end

    -- CharacterModelScene 背景（角色模型區域）
    if CharacterModelScene then
        local bg = CharacterModelScene:CreateTexture(nil, "BACKGROUND", nil, -8)
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
                border:SetBackdropBorderColor(unpack(C.border))
                border:SetFrameLevel(slot:GetFrameLevel() + 1)
                slot._lunarBorder = border
            end
        end
    end

    -- PaperDollFrame 內頁裝飾移除並修復文字
    if PaperDollFrame then
        LunarUI.StripTextures(PaperDollFrame)
        LunarUI:SkinFrameText(PaperDollFrame, 2)
    end

    -- CharacterStatsPane 屬性面板（重要：屬性文字需要修復）
    if CharacterStatsPane then
        LunarUI.StripTextures(CharacterStatsPane)
        LunarUI:SkinFrameText(CharacterStatsPane, 3)

        -- 特別處理屬性分類標題
        if CharacterStatsPane.ClassBackground then
            CharacterStatsPane.ClassBackground:SetAlpha(0)
        end
    end

    -- 裝備等級文字（WoW 12.0）
    if PaperDollFrame and PaperDollFrame.EquipmentManagerPane then
        LunarUI:SkinFrameText(PaperDollFrame.EquipmentManagerPane, 2)
    end
    return true
end

-- 註冊 skin（角色面板在 PLAYER_ENTERING_WORLD 時可用）
LunarUI:RegisterSkin("character", "PLAYER_ENTERING_WORLD", SkinCharacterFrame)
