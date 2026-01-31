---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Character Frame
    Reskin CharacterFrame (角色面板) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinCharacterFrame()
    local frame = CharacterFrame
    if not frame then return end

    -- 主框架背景
    LunarUI:SkinFrame(frame)

    -- 關閉按鈕
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
    elseif _G.CharacterFrameCloseButton then
        LunarUI:SkinCloseButton(_G.CharacterFrameCloseButton)
    end

    -- 分頁
    for i = 1, 4 do
        local tab = _G["CharacterFrameTab" .. i]
        if tab then
            LunarUI:SkinTab(tab)
        end
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
                border:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
                border:SetFrameLevel(slot:GetFrameLevel() + 1)
                slot._lunarBorder = border
            end
        end
    end

    -- PaperDollFrame 內頁裝飾移除
    if PaperDollFrame then
        LunarUI.StripTextures(PaperDollFrame)
    end

    -- CharacterStatsPane 屬性面板
    if CharacterStatsPane then
        LunarUI.StripTextures(CharacterStatsPane)
    end
end

-- 註冊 skin（角色面板在 PLAYER_ENTERING_WORLD 時可用）
LunarUI:RegisterSkin("character", "PLAYER_ENTERING_WORLD", SkinCharacterFrame)
