---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Trade Frame
    Reskin TradeFrame (交易視窗) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors

local function SkinTradeFrame()
    local frame = LunarUI:SkinStandardFrame("TradeFrame", {
        textDepth = 3,
    })
    if not frame then return end

    -- 交易按鈕
    if _G.TradeFrameTradeButton then
        LunarUI.SkinButton(_G.TradeFrameTradeButton)
    end
    if _G.TradeFrameCancelButton then
        LunarUI.SkinButton(_G.TradeFrameCancelButton)
    end

    -- 交易欄位（玩家方 + 對方各 7 欄）
    for i = 1, 7 do
        pcall(function()
            local playerSlot = _G["TradePlayerItem" .. i .. "ItemButton"]
            if playerSlot then
                LunarUI.StripTextures(playerSlot)
                if not playerSlot._lunarBorder and BackdropTemplateMixin then
                    local border = CreateFrame("Frame", nil, playerSlot, "BackdropTemplate")
                    border:SetPoint("TOPLEFT", -1, 1)
                    border:SetPoint("BOTTOMRIGHT", 1, -1)
                    border:SetBackdrop(LunarUI.iconBackdropTemplate)
                    border:SetBackdropColor(0, 0, 0, 0)
                    border:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
                    border:SetFrameLevel(playerSlot:GetFrameLevel() + 1)
                    playerSlot._lunarBorder = border
                end
            end

            local recipientSlot = _G["TradeRecipientItem" .. i .. "ItemButton"]
            if recipientSlot then
                LunarUI.StripTextures(recipientSlot)
                if not recipientSlot._lunarBorder and BackdropTemplateMixin then
                    local border = CreateFrame("Frame", nil, recipientSlot, "BackdropTemplate")
                    border:SetPoint("TOPLEFT", -1, 1)
                    border:SetPoint("BOTTOMRIGHT", 1, -1)
                    border:SetBackdrop(LunarUI.iconBackdropTemplate)
                    border:SetBackdropColor(0, 0, 0, 0)
                    border:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
                    border:SetFrameLevel(recipientSlot:GetFrameLevel() + 1)
                    recipientSlot._lunarBorder = border
                end
            end
        end)
    end

    -- 金幣輸入框
    if _G.TradePlayerInputMoneyFrameGold then
        LunarUI.SkinEditBox(_G.TradePlayerInputMoneyFrameGold)
    end
    if _G.TradePlayerInputMoneyFrameSilver then
        LunarUI.SkinEditBox(_G.TradePlayerInputMoneyFrameSilver)
    end
    if _G.TradePlayerInputMoneyFrameCopper then
        LunarUI.SkinEditBox(_G.TradePlayerInputMoneyFrameCopper)
    end

    return true
end

-- TradeFrame 為延遲載入 addon
LunarUI.RegisterSkin("trade", "Blizzard_TradeUI", SkinTradeFrame)
