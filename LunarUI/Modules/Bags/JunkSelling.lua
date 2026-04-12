---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, redundant-parameter, unused-local
--[[
    LunarUI - 垃圾販賣
    自動販賣垃圾物品功能
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local format = string.format
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 延遲解析
--------------------------------------------------------------------------------

local function GetBagDB()
    return LunarUI.GetModuleDB("bags")
end

--------------------------------------------------------------------------------
-- 垃圾販賣
--------------------------------------------------------------------------------

local sellJunkGeneration = 0

--[[
    增強型自動販賣：包含安全檢查與統計資訊
]]
local function SellJunk()
    if not LunarUI._modulesEnabled then
        return
    end
    sellJunkGeneration = sellJunkGeneration + 1
    local myGen = sellJunkGeneration
    local db = GetBagDB()
    if not db or not db.autoSellJunk then
        return
    end

    -- 第一步：收集所有垃圾物品
    local junkItems = {}
    local totalValue = 0

    for bag = 0, 5 do -- 含材料袋（bag 5）
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
            if containerInfo and containerInfo.quality == 0 and not containerInfo.hasNoValue then
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, _, _, _, _, _, _, _, _, itemPrice = C_Item.GetItemInfo(itemLink)
                    if itemPrice and itemPrice > 0 then
                        local stackCount = containerInfo.stackCount or 1
                        local stackValue = itemPrice * stackCount
                        totalValue = totalValue + stackValue
                        junkItems[#junkItems + 1] = { bag = bag, slot = slot, value = stackValue }
                    end
                end
            end
        end
    end

    if #junkItems == 0 then
        return
    end

    -- 第二步：逐件販賣（C_Timer 分批避免伺服器節流）
    local itemCount = #junkItems
    local index = 0
    local function SellNext()
        -- generation counter：防止多個 SellJunk 呼叫產生重疊的販賣鏈
        if myGen ~= sellJunkGeneration then
            return
        end
        -- 全域停用時中止販賣鏈
        if not LunarUI._modulesEnabled then
            return
        end
        -- 確保商人視窗仍然開啟，玩家可能在販賣過程中關閉商人
        if not MerchantFrame or not MerchantFrame:IsShown() then
            return
        end
        index = index + 1
        if index > #junkItems then
            -- 所有垃圾已販賣，輸出統計
            local coinStr = GetCoinTextureString(totalValue)

            local msg = L["SoldJunkItems"] or "Sold %d junk items for %s"
            LunarUI:Print(format(msg, itemCount, coinStr))
            return
        end

        local item = junkItems[index]
        if not item then
            return
        end
        C_Container.UseContainerItem(item.bag, item.slot)
        C_Timer.After(0.2, SellNext)
    end
    SellNext()
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.BagsSellJunk = SellJunk
-- 供 CleanupBags 使飛行中販賣鏈失效
LunarUI.InvalidateSellJunk = function()
    sellJunkGeneration = sellJunkGeneration + 1
end
