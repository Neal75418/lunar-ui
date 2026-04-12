---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, unused-local
--[[
    LunarUI - Skin: Trade Frame
    Reskin TradeFrame (交易視窗) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinTradeFrame()
    local frame = LunarUI:SkinStandardFrame("TradeFrame", {
        textDepth = 3,
    })
    if not frame then
        return
    end

    -- 交易按鈕
    if _G.TradeFrameTradeButton then
        LunarUI.SkinButton(_G.TradeFrameTradeButton)
    end
    if _G.TradeFrameCancelButton then
        LunarUI.SkinButton(_G.TradeFrameCancelButton)
    end

    -- 交易欄位（玩家方 + 對方各 7 欄）
    for i = 1, 7 do
        local playerSlot = _G["TradePlayerItem" .. i .. "ItemButton"]
        if playerSlot then
            LunarUI.StripTextures(playerSlot)
            LunarUI.CreateIconBorder(playerSlot)
        end

        local recipientSlot = _G["TradeRecipientItem" .. i .. "ItemButton"]
        if recipientSlot then
            LunarUI.StripTextures(recipientSlot)
            LunarUI.CreateIconBorder(recipientSlot)
        end
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
