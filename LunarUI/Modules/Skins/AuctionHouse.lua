---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch
--[[
    LunarUI - Skin: Auction House
    Reskin AuctionHouseFrame with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinAuctionHouse()
    local frame = LunarUI:SkinStandardFrame("AuctionHouseFrame", {
        tabProperty = "Tabs",
    })
    if not frame then
        return
    end

    -- 舊版分頁命名備援
    if not frame.Tabs then
        for i = 1, 4 do
            local tab = _G["AuctionHouseFrameTab" .. i]
            if tab then
                LunarUI.SkinTab(tab)
            end
        end
    end

    -- 搜尋列
    if frame.SearchBar then
        local searchBar = frame.SearchBar
        if searchBar.SearchBox then
            LunarUI.SkinEditBox(searchBar.SearchBox)
        end
        if searchBar.SearchButton then
            LunarUI.SkinButton(searchBar.SearchButton)
        end
        if searchBar.FavoritesSearchButton then
            LunarUI.SkinButton(searchBar.FavoritesSearchButton)
        end
    end

    -- 底部模式切換 tab（購買 / 賣出 / 拍賣）
    for _, tabKey in ipairs({ "BuyTab", "SellTab", "AuctionsTab" }) do
        if frame[tabKey] then
            LunarUI.SkinTab(frame[tabKey])
        end
    end

    -- 商品購買框架
    if frame.CommoditiesBuyFrame then
        LunarUI.StripTextures(frame.CommoditiesBuyFrame)
        if frame.CommoditiesBuyFrame.BuyDisplay then
            LunarUI.StripTextures(frame.CommoditiesBuyFrame.BuyDisplay)
        end
    end

    -- 物品購買框架
    if frame.ItemBuyFrame then
        LunarUI.StripTextures(frame.ItemBuyFrame)
    end

    -- 賣出框架
    if frame.ItemSellFrame then
        LunarUI.StripTextures(frame.ItemSellFrame)
    end
    if frame.CommoditiesSellFrame then
        LunarUI.StripTextures(frame.CommoditiesSellFrame)
    end

    -- 賣出列表
    if frame.ItemSellList then
        LunarUI.StripTextures(frame.ItemSellList)
    end
    if frame.CommoditiesSellList then
        LunarUI.StripTextures(frame.CommoditiesSellList)
    end

    -- 拍賣框架（我的拍賣分頁）
    if frame.AuctionsFrame then
        LunarUI.StripTextures(frame.AuctionsFrame)
        -- 摘要列表
        if frame.AuctionsFrame.SummaryList then
            LunarUI.StripTextures(frame.AuctionsFrame.SummaryList)
        end
        -- 所有拍賣列表
        if frame.AuctionsFrame.AllAuctionsList then
            LunarUI.StripTextures(frame.AuctionsFrame.AllAuctionsList)
        end
        -- 競標列表
        if frame.AuctionsFrame.BidsList then
            LunarUI.StripTextures(frame.AuctionsFrame.BidsList)
        end
        -- 取消拍賣按鈕
        if frame.AuctionsFrame.CancelAuctionButton then
            LunarUI.SkinButton(frame.AuctionsFrame.CancelAuctionButton)
        end
    end

    -- 金幣顯示
    if frame.MoneyFrameBorder then
        frame.MoneyFrameBorder:SetAlpha(0)
    end
    if frame.MoneyFrameInset then
        frame.MoneyFrameInset:SetAlpha(0)
    end
    return true
end

-- 拍賣場為延遲載入
LunarUI.RegisterSkin("auctionhouse", "Blizzard_AuctionHouseUI", SkinAuctionHouse)
