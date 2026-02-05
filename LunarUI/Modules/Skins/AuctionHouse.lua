---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Auction House
    Reskin AuctionHouseFrame with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinAuctionHouse()
    local frame = _G.AuctionHouseFrame
    if not frame then return end

    -- Main frame（啟用文字修復）
    LunarUI:SkinFrame(frame, { textDepth = 3 })

    -- 標題文字
    if frame.TitleText then
        LunarUI:SetFontLight(frame.TitleText)
    end

    -- Close button
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
    end

    -- Tabs
    if frame.Tabs then
        for _, tab in ipairs(frame.Tabs) do
            LunarUI:SkinTab(tab)
            if tab.Text then
                LunarUI:SetFontLight(tab.Text)
            end
        end
    else
        -- Legacy tab naming
        for i = 1, 4 do
            local tab = _G["AuctionHouseFrameTab" .. i]
            if tab then
                LunarUI:SkinTab(tab)
            end
        end
    end

    -- Search bar
    if frame.SearchBar then
        local searchBar = frame.SearchBar
        if searchBar.SearchBox then
            LunarUI:SkinEditBox(searchBar.SearchBox)
        end
        if searchBar.SearchButton then
            LunarUI:SkinButton(searchBar.SearchButton)
        end
        if searchBar.FavoritesSearchButton then
            LunarUI:SkinButton(searchBar.FavoritesSearchButton)
        end
    end

    -- Buy tab
    if frame.BuyTab then
        LunarUI.StripTextures(frame.BuyTab)
    end

    -- Commodities buy frame
    if frame.CommoditiesBuyFrame then
        LunarUI.StripTextures(frame.CommoditiesBuyFrame)
        if frame.CommoditiesBuyFrame.BuyDisplay then
            LunarUI.StripTextures(frame.CommoditiesBuyFrame.BuyDisplay)
        end
    end

    -- Item buy frame
    if frame.ItemBuyFrame then
        LunarUI.StripTextures(frame.ItemBuyFrame)
    end

    -- Sell frame
    if frame.ItemSellFrame then
        LunarUI.StripTextures(frame.ItemSellFrame)
    end
    if frame.CommoditiesSellFrame then
        LunarUI.StripTextures(frame.CommoditiesSellFrame)
    end

    -- Sell list
    if frame.ItemSellList then
        LunarUI.StripTextures(frame.ItemSellList)
    end
    if frame.CommoditiesSellList then
        LunarUI.StripTextures(frame.CommoditiesSellList)
    end

    -- Auctions frame (My Auctions tab)
    if frame.AuctionsFrame then
        LunarUI.StripTextures(frame.AuctionsFrame)
        -- Summary list
        if frame.AuctionsFrame.SummaryList then
            LunarUI.StripTextures(frame.AuctionsFrame.SummaryList)
        end
        -- All auctions list
        if frame.AuctionsFrame.AllAuctionsList then
            LunarUI.StripTextures(frame.AuctionsFrame.AllAuctionsList)
        end
        -- Bids list
        if frame.AuctionsFrame.BidsList then
            LunarUI.StripTextures(frame.AuctionsFrame.BidsList)
        end
        -- Cancel auction button
        if frame.AuctionsFrame.CancelAuctionButton then
            LunarUI:SkinButton(frame.AuctionsFrame.CancelAuctionButton)
        end
    end

    -- Money displays
    if frame.MoneyFrameBorder then
        frame.MoneyFrameBorder:SetAlpha(0)
    end
    if frame.MoneyFrameInset then
        frame.MoneyFrameInset:SetAlpha(0)
    end
end

-- AuctionHouse is loaded on demand
LunarUI:RegisterSkin("auctionhouse", "Blizzard_AuctionHouseUI", SkinAuctionHouse)
