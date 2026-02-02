---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Merchant Frame
    Reskin MerchantFrame (商人介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local merchantHookRegistered = false

local function SkinMerchant()
    local frame = MerchantFrame
    if not frame then return end

    -- 主框架背景
    LunarUI:SkinFrame(frame)

    -- 關閉按鈕
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
    elseif _G.MerchantFrameCloseButton then
        LunarUI:SkinCloseButton(_G.MerchantFrameCloseButton)
    end

    -- 分頁（商人/回購）
    for i = 1, 2 do
        local tab = _G["MerchantFrameTab" .. i]
        if tab then
            LunarUI:SkinTab(tab)
        end
    end

    -- 翻頁按鈕
    if _G.MerchantNextPageButton then
        LunarUI:SkinButton(_G.MerchantNextPageButton)
    end
    if _G.MerchantPrevPageButton then
        LunarUI:SkinButton(_G.MerchantPrevPageButton)
    end

    -- 商品按鈕（每次開啟商人可能會動態建立）
    if not merchantHookRegistered then
        merchantHookRegistered = true
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
            for i = 1, MERCHANT_ITEMS_PER_PAGE or 12 do
                local btn = _G["MerchantItem" .. i]
                if LunarUI:MarkSkinned(btn) then
                    LunarUI.StripTextures(btn)
                    -- TODO(#28): 物品按鈕圖示邊框 — 保留品質著色但縮小邊框
                end
            end
        end)
    end

    -- 修理按鈕
    if _G.MerchantRepairAllButton then
        LunarUI:SkinButton(_G.MerchantRepairAllButton)
    end
    if _G.MerchantRepairItemButton then
        LunarUI:SkinButton(_G.MerchantRepairItemButton)
    end

    -- 購買堆疊框架
    if _G.MerchantBuyBackItem then
        LunarUI.StripTextures(_G.MerchantBuyBackItem)
    end
end

-- MerchantFrame 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI:RegisterSkin("merchant", "PLAYER_ENTERING_WORLD", SkinMerchant)
