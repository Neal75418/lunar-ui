---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Merchant Frame
    Reskin MerchantFrame (商人介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local merchantHookRegistered = false

--- 修復商品物品的文字顏色
local function SkinMerchantItem(btn, index)
    if not btn then return end

    -- 物品名稱
    local nameFrame = _G["MerchantItem" .. index .. "Name"]
    if nameFrame then
        LunarUI:SetFontLight(nameFrame)
    end

    -- 物品數量文字
    local countFrame = _G["MerchantItem" .. index .. "Count"]
    if countFrame then
        LunarUI:SetFontLight(countFrame)
    end

    -- 金錢文字
    local moneyFrame = _G["MerchantItem" .. index .. "MoneyFrame"]
    if moneyFrame then
        LunarUI:SkinFrameText(moneyFrame, 1)
    end
end

local function SkinMerchant()
    local frame = LunarUI:SkinStandardFrame("MerchantFrame", {
        tabPrefix = "MerchantFrameTab", tabCount = 2,
    })
    if not frame then return end

    -- 標題文字 fallback
    if not frame.TitleText and _G.MerchantFrameTitleText then
        LunarUI:SetFontLight(_G.MerchantFrameTitleText)
    end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.MerchantFrameCloseButton then
        LunarUI:SkinCloseButton(_G.MerchantFrameCloseButton)
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
                if btn then
                    if LunarUI:MarkSkinned(btn) then
                        LunarUI.StripTextures(btn)
                    end
                    -- 每次更新都修復文字顏色（物品可能改變）
                    SkinMerchantItem(btn, i)
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
        -- 回購物品名稱
        if _G.MerchantBuyBackItemName then
            LunarUI:SetFontLight(_G.MerchantBuyBackItemName)
        end
    end

    -- 頁碼文字
    if _G.MerchantPageText then
        LunarUI:SetFontLight(_G.MerchantPageText)
    end

    -- 金錢框架
    if _G.MerchantMoneyFrame then
        LunarUI:SkinFrameText(_G.MerchantMoneyFrame, 1)
    end
    return true
end

-- MerchantFrame 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI:RegisterSkin("merchant", "PLAYER_ENTERING_WORLD", SkinMerchant)
