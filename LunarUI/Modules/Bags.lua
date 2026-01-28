---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field
--[[
    LunarUI - 背包模組
    整合式背包系統，Lunar 主題風格

    功能：
    - 整合所有背包為單一視窗
    - 羊皮紙風格背景
    - 物品排序與分類
    - 搜尋功能
    - 裝備物品等級顯示
    - 垃圾自動販賣
    - 月相感知顯示
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local SLOT_SIZE = 37
local SLOT_SPACING = 4
local SLOTS_PER_ROW = 12
local PADDING = 10
local HEADER_HEIGHT = 30

local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

-- 物品品質顏色
local ITEM_QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },  -- 粗糙（灰）
    [1] = { 1.00, 1.00, 1.00 },  -- 普通（白）
    [2] = { 0.12, 1.00, 0.00 },  -- 優秀（綠）
    [3] = { 0.00, 0.44, 0.87 },  -- 精良（藍）
    [4] = { 0.64, 0.21, 0.93 },  -- 史詩（紫）
    [5] = { 1.00, 0.50, 0.00 },  -- 傳說（橙）
    [6] = { 0.90, 0.80, 0.50 },  -- 神器（金）
    [7] = { 0.00, 0.80, 0.98 },  -- 傳家寶（淺藍）
    [8] = { 0.00, 0.80, 1.00 },  -- WoW 代幣
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local bagFrame
local bankFrame
local slots = {}
local bankSlots = {}
local searchBox
local bankSearchBox
local moneyFrame
local sortButton
local closeButton
local isOpen = false
local isBankOpen = false

-- 銀行容器 ID：-1 = 主銀行（28 格），5-11 = 銀行包
local BANK_CONTAINER = -1
local REAGENT_BANK_CONTAINER = -3
local FIRST_BANK_BAG = 5
local LAST_BANK_BAG = 11

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function GetTotalSlots()
    local total = 0
    for bag = 0, 4 do
        total = total + C_Container.GetContainerNumSlots(bag)
    end
    return total
end

local function GetTotalFreeSlots()
    local free = 0
    for bag = 0, 4 do
        local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
        free = free + freeSlots
    end
    return free
end

-- 快取機制：避免重複呼叫昂貴的物品資訊 API
local itemLevelCache = {}
local equipmentTypeCache = {}
local itemLevelCacheSize = 0
local equipmentTypeCacheSize = 0
local CACHE_MAX_SIZE = 500

--[[
    計算字典表大小
    Lua 的 # 運算子僅適用於連續整數鍵，字典需要手動計數
]]
local function GetTableSize(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- 在新增項目前檢查快取大小，避免新項目立即被清除的競爭條件
local function MaybeEvictItemLevelCache()
    if itemLevelCacheSize >= CACHE_MAX_SIZE then
        wipe(itemLevelCache)
        itemLevelCacheSize = 0
    end
end

local function MaybeEvictEquipmentTypeCache()
    if equipmentTypeCacheSize >= CACHE_MAX_SIZE then
        wipe(equipmentTypeCache)
        equipmentTypeCacheSize = 0
    end
end

local function GetItemLevel(itemLink)
    if not itemLink then return nil end

    -- 使用快取避免重複 API 呼叫
    if itemLevelCache[itemLink] then
        return itemLevelCache[itemLink]
    end

    local itemLevel = select(1, C_Item.GetDetailedItemLevelInfo(itemLink))
    if itemLevel then
        -- 新增前先清理快取
        MaybeEvictItemLevelCache()
        itemLevelCache[itemLink] = itemLevel
        itemLevelCacheSize = itemLevelCacheSize + 1
    end
    return itemLevel
end

local function IsEquipment(itemLink)
    if not itemLink then return false end

    -- 使用快取避免重複 API 呼叫
    if equipmentTypeCache[itemLink] ~= nil then
        return equipmentTypeCache[itemLink]
    end

    local _, _, _, _, _, itemType = C_Item.GetItemInfo(itemLink)
    local isEquip = (itemType == "Armor" or itemType == "Weapon")
    -- 新增前先清理快取
    MaybeEvictEquipmentTypeCache()
    equipmentTypeCache[itemLink] = isEquip
    equipmentTypeCacheSize = equipmentTypeCacheSize + 1
    return isEquip
end

-- 銀行輔助函數
local function GetTotalBankSlots()
    local total = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        total = total + C_Container.GetContainerNumSlots(bag)
    end
    return total
end

local function GetTotalBankFreeSlots()
    local free = C_Container.GetContainerNumFreeSlots(BANK_CONTAINER)
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        free = free + C_Container.GetContainerNumFreeSlots(bag)
    end
    return free
end

--------------------------------------------------------------------------------
-- 格子建立
--------------------------------------------------------------------------------

local function CreateItemSlot(parent, slotID, bag, slot)
    local button = CreateFrame("ItemButton", "LunarUI_BagSlot" .. slotID, parent, "ContainerFrameItemButtonTemplate")
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- 儲存背包/格子資訊
    button.bag = bag
    button.slot = slot

    -- 移除預設材質
    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    -- 設定圖示樣式
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- 建立邊框
    if not button.LunarBorder then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop(backdropTemplate)
        border:SetBackdropColor(0, 0, 0, 0)
        border:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        button.LunarBorder = border
    end

    -- 物品等級文字
    if not button.ilvlText then
        local ilvl = button:CreateFontString(nil, "OVERLAY")
        ilvl:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        ilvl:SetPoint("BOTTOMRIGHT", -2, 2)
        ilvl:SetTextColor(1, 1, 0.6)
        button.ilvlText = ilvl
    end

    -- 垃圾指示器
    if not button.junkIcon then
        local junk = button:CreateTexture(nil, "OVERLAY")
        junk:SetSize(12, 12)
        junk:SetPoint("TOPLEFT", 2, -2)
        junk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
        junk:Hide()
        button.junkIcon = junk
    end

    -- 任務指示器
    if not button.questIcon then
        local quest = button:CreateTexture(nil, "OVERLAY")
        quest:SetSize(12, 12)
        quest:SetPoint("TOPLEFT", 2, -2)
        quest:SetTexture("Interface\\MINIMAP\\TRACKING\\QuestBlob")
        quest:Hide()
        button.questIcon = quest
    end

    return button
end

local function UpdateSlot(button)
    if not button or not button.bag or not button.slot then return end

    local bag, slot = button.bag, button.slot
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)

    if containerInfo then
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        local quality = containerInfo.quality or 0

        -- 設定物品圖示
        local icon = button.icon or _G[button:GetName() .. "IconTexture"]
        if icon and containerInfo.iconFileID then
            icon:SetTexture(containerInfo.iconFileID)
            icon:Show()
        end

        -- 設定物品數量
        local count = containerInfo.stackCount or 0
        if count > 1 then
            button.Count:SetText(count)
            button.Count:Show()
        else
            button.Count:Hide()
        end

        -- 依品質設定邊框顏色
        if button.LunarBorder then
            if quality and ITEM_QUALITY_COLORS[quality] then
                local color = ITEM_QUALITY_COLORS[quality]
                button.LunarBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            else
                button.LunarBorder:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            end
        end

        -- 顯示裝備物品等級
        if button.ilvlText then
            if IsEquipment(itemLink) then
                local ilvl = GetItemLevel(itemLink)
                if ilvl and ilvl > 1 then
                    button.ilvlText:SetText(ilvl)
                    button.ilvlText:Show()
                else
                    button.ilvlText:Hide()
                end
            else
                button.ilvlText:Hide()
            end
        end

        -- 顯示垃圾指示器
        if button.junkIcon then
            if quality == 0 and containerInfo.hasNoValue ~= true then
                button.junkIcon:Show()
            else
                button.junkIcon:Hide()
            end
        end

        -- 顯示任務指示器
        if button.questIcon then
            if containerInfo.isQuestItem then
                button.questIcon:Show()
                button.junkIcon:Hide()  -- 不同時顯示兩者
            else
                button.questIcon:Hide()
            end
        end
    else
        -- 空格子
        local icon = button.icon or _G[button:GetName() .. "IconTexture"]
        if icon then
            icon:SetTexture(nil)
        end
        if button.Count then
            button.Count:Hide()
        end
        if button.LunarBorder then
            button.LunarBorder:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.5)
        end
        if button.ilvlText then
            button.ilvlText:Hide()
        end
        if button.junkIcon then
            button.junkIcon:Hide()
        end
        if button.questIcon then
            button.questIcon:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- 背包框架建立
--------------------------------------------------------------------------------

local function CreateBagFrame()
    local db = LunarUI.db and LunarUI.db.profile.bags
    if not db or not db.enabled then return end

    if bagFrame then return bagFrame end

    -- 計算框架大小
    local totalSlots = GetTotalSlots()
    local numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + 30

    -- 建立主框架
    bagFrame = CreateFrame("Frame", "LunarUI_Bags", UIParent, "BackdropTemplate")
    bagFrame:SetSize(width, height)
    bagFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 100)
    bagFrame:SetBackdrop(backdropTemplate)
    bagFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    bagFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    bagFrame:SetFrameStrata("HIGH")
    bagFrame:SetMovable(true)
    bagFrame:EnableMouse(true)
    bagFrame:SetClampedToScreen(true)
    bagFrame:Hide()

    -- 可拖曳
    bagFrame:RegisterForDrag("LeftButton")
    bagFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bagFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- 標題
    local title = bagFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", PADDING, -8)
    title:SetText("Bags")
    title:SetTextColor(0.9, 0.9, 0.9)
    bagFrame.title = title

    -- 關閉按鈕
    closeButton = CreateFrame("Button", nil, bagFrame)
    closeButton:SetSize(20, 20)
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetNormalFontObject(GameFontNormal)
    closeButton:SetText("×")
    closeButton:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    closeButton:SetScript("OnClick", function()
        CloseAllBags()
    end)

    -- 搜尋框
    searchBox = CreateFrame("EditBox", "LunarUI_BagSearch", bagFrame, "SearchBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -8, -2)

    -- 搜尋防抖動：使用 C_Timer.NewTimer 以支援正確的取消機制
    local searchTimer
    searchBox:SetScript("OnTextChanged", function(self)
        -- 取消前一個計時器避免累積
        if searchTimer then
            searchTimer:Cancel()
        end

        -- 延遲 0.2 秒後執行搜尋
        searchTimer = C_Timer.NewTimer(0.2, function()
            local text = self:GetText():lower()
            for _, button in pairs(slots) do
                if button and button.bag and button.slot then
                    -- 使用 pcall 保護搜尋邏輯
                    local success, err = pcall(function()
                        local itemLink = C_Container.GetContainerItemLink(button.bag, button.slot)
                        if itemLink then
                            local itemName = C_Item.GetItemInfo(itemLink)
                            if itemName then
                                -- 使用純文字搜尋避免正規表達式錯誤
                                if text == "" or itemName:lower():find(text, 1, true) then
                                    button:SetAlpha(1)
                                else
                                    button:SetAlpha(0.3)
                                end
                            else
                                button:SetAlpha(text == "" and 1 or 0.3)
                            end
                        else
                            button:SetAlpha(text == "" and 1 or 0.3)
                        end
                    end)

                    if not success then
                        button:SetAlpha(1)  -- 發生錯誤時顯示按鈕
                        -- 除錯模式下記錄錯誤
                        if LunarUI:IsDebugMode() then
                            LunarUI:Debug(L["BagSearchError"] or "Bag search error: " .. tostring(err))
                        end
                    end
                end
            end
        end)
    end)

    -- 排序按鈕
    sortButton = CreateFrame("Button", nil, bagFrame, "BackdropTemplate")
    sortButton:SetSize(60, 20)
    sortButton:SetPoint("TOPLEFT", title, "TOPRIGHT", 10, 2)
    sortButton:SetBackdrop(backdropTemplate)
    sortButton:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    sortButton:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)

    local sortText = sortButton:CreateFontString(nil, "OVERLAY")
    sortText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    sortText:SetPoint("CENTER")
    sortText:SetText("Sort")
    sortText:SetTextColor(0.8, 0.8, 0.8)

    sortButton:SetScript("OnClick", function()
        C_Container.SortBags()
    end)

    sortButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    end)

    sortButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    end)

    -- 格子容器
    local slotContainer = CreateFrame("Frame", nil, bagFrame)
    slotContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    slotContainer:SetPoint("BOTTOMRIGHT", -PADDING, 30)
    bagFrame.slotContainer = slotContainer

    -- 建立格子
    local slotID = 0
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotID = slotID + 1
            local button = CreateItemSlot(slotContainer, slotID, bag, slot)

            local row = math.floor((slotID - 1) / SLOTS_PER_ROW)
            local col = (slotID - 1) % SLOTS_PER_ROW

            button:SetPoint("TOPLEFT", slotContainer, "TOPLEFT",
                col * (SLOT_SIZE + SLOT_SPACING),
                -row * (SLOT_SIZE + SLOT_SPACING)
            )

            -- 設定按鈕 ID 以支援預設背包行為
            button:SetID(slot)
            SetItemButtonDesaturated(button, false)

            slots[slotID] = button
        end
    end

    -- 金錢顯示
    local money = bagFrame:CreateFontString(nil, "OVERLAY")
    money:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    money:SetPoint("BOTTOMLEFT", PADDING, 8)
    money:SetTextColor(1, 0.82, 0)
    bagFrame.money = money

    -- 空格指示器
    local freeSlots = bagFrame:CreateFontString(nil, "OVERLAY")
    freeSlots:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(0.7, 0.7, 0.7)
    bagFrame.freeSlots = freeSlots

    return bagFrame
end

--------------------------------------------------------------------------------
-- 銀行框架建立
--------------------------------------------------------------------------------

local function CreateBankSlot(parent, slotID, bag, slot)
    local button = CreateFrame("ItemButton", "LunarUI_BankSlot" .. slotID, parent, "ContainerFrameItemButtonTemplate")
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- 儲存背包/格子資訊
    button.bag = bag
    button.slot = slot
    button.isBank = true

    -- 移除預設材質
    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    -- 設定圖示樣式
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- 建立邊框
    if not button.LunarBorder then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop(backdropTemplate)
        border:SetBackdropColor(0, 0, 0, 0)
        border:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        button.LunarBorder = border
    end

    -- 物品等級文字
    if not button.ilvlText then
        local ilvl = button:CreateFontString(nil, "OVERLAY")
        ilvl:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        ilvl:SetPoint("BOTTOMRIGHT", -2, 2)
        ilvl:SetTextColor(1, 1, 0.6)
        button.ilvlText = ilvl
    end

    return button
end

local function UpdateBankSlot(button)
    if not button or not button.bag or not button.slot then return end

    local bag, slot = button.bag, button.slot
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)

    if containerInfo then
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        local quality = containerInfo.quality or 0

        -- 設定物品圖示
        local icon = button.icon or _G[button:GetName() .. "IconTexture"]
        if icon and containerInfo.iconFileID then
            icon:SetTexture(containerInfo.iconFileID)
            icon:Show()
        end

        -- 設定物品數量
        local count = containerInfo.stackCount or 0
        if count > 1 then
            button.Count:SetText(count)
            button.Count:Show()
        else
            button.Count:Hide()
        end

        -- 依品質設定邊框顏色
        if button.LunarBorder then
            if quality and ITEM_QUALITY_COLORS[quality] then
                local color = ITEM_QUALITY_COLORS[quality]
                button.LunarBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            else
                button.LunarBorder:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            end
        end

        -- 顯示裝備物品等級
        if button.ilvlText then
            if IsEquipment(itemLink) then
                local ilvl = GetItemLevel(itemLink)
                if ilvl and ilvl > 1 then
                    button.ilvlText:SetText(ilvl)
                    button.ilvlText:Show()
                else
                    button.ilvlText:Hide()
                end
            else
                button.ilvlText:Hide()
            end
        end
    else
        -- 空格子
        local icon = button.icon or _G[button:GetName() .. "IconTexture"]
        if icon then
            icon:SetTexture(nil)
        end
        if button.Count then
            button.Count:Hide()
        end
        if button.LunarBorder then
            button.LunarBorder:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.5)
        end
        if button.ilvlText then
            button.ilvlText:Hide()
        end
    end
end

local function CreateBankFrame()
    local db = LunarUI.db and LunarUI.db.profile.bags
    if not db or not db.enabled then return end

    if bankFrame then return bankFrame end

    -- 計算框架大小
    local totalSlots = GetTotalBankSlots()
    local numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + 30

    -- 建立主框架
    bankFrame = CreateFrame("Frame", "LunarUI_Bank", UIParent, "BackdropTemplate")
    bankFrame:SetSize(width, height)
    bankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -100)
    bankFrame:SetBackdrop(backdropTemplate)
    bankFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    bankFrame:SetBackdropBorderColor(0.4, 0.35, 0.2, 1)  -- 銀行用金色邊框
    bankFrame:SetFrameStrata("HIGH")
    bankFrame:SetMovable(true)
    bankFrame:EnableMouse(true)
    bankFrame:SetClampedToScreen(true)
    bankFrame:Hide()

    -- 可拖曳
    bankFrame:RegisterForDrag("LeftButton")
    bankFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bankFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- 標題
    local title = bankFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", PADDING, -8)
    title:SetText("Bank")
    title:SetTextColor(1, 0.82, 0)  -- 金色
    bankFrame.title = title

    -- 關閉按鈕
    local bankCloseButton = CreateFrame("Button", nil, bankFrame)
    bankCloseButton:SetSize(20, 20)
    bankCloseButton:SetPoint("TOPRIGHT", -4, -4)
    bankCloseButton:SetNormalFontObject(GameFontNormal)
    bankCloseButton:SetText("×")
    bankCloseButton:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    bankCloseButton:SetScript("OnClick", function()
        CloseBankFrame()
    end)

    -- 搜尋框
    bankSearchBox = CreateFrame("EditBox", "LunarUI_BankSearch", bankFrame, "SearchBoxTemplate")
    bankSearchBox:SetSize(120, 20)
    bankSearchBox:SetPoint("TOPRIGHT", bankCloseButton, "TOPLEFT", -8, -2)

    -- 搜尋防抖動
    local bankSearchTimer
    bankSearchBox:SetScript("OnTextChanged", function(self)
        if bankSearchTimer then
            bankSearchTimer:Cancel()
        end
        bankSearchTimer = C_Timer.NewTimer(0.2, function()
            local text = self:GetText():lower()
            for _, button in pairs(bankSlots) do
                if button then
                    local success, err = pcall(function()
                        local itemLink = C_Container.GetContainerItemLink(button.bag, button.slot)
                        if itemLink then
                            local itemName = C_Item.GetItemInfo(itemLink)
                            -- 使用純文字搜尋避免 Lua 模式注入
                            if itemName and (text == "" or itemName:lower():find(text, 1, true)) then
                                button:SetAlpha(1)
                            else
                                button:SetAlpha(0.3)
                            end
                        else
                            button:SetAlpha(text == "" and 1 or 0.3)
                        end
                    end)
                    if not success then
                        button:SetAlpha(1)
                        -- 除錯模式下記錄錯誤
                        if LunarUI:IsDebugMode() then
                            LunarUI:Debug(L["BankSearchError"] or "Bank search error: " .. tostring(err))
                        end
                    end
                end
            end
        end)
    end)

    -- 排序按鈕
    local bankSortButton = CreateFrame("Button", nil, bankFrame, "BackdropTemplate")
    bankSortButton:SetSize(60, 20)
    bankSortButton:SetPoint("TOPLEFT", title, "TOPRIGHT", 10, 2)
    bankSortButton:SetBackdrop(backdropTemplate)
    bankSortButton:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    bankSortButton:SetBackdropBorderColor(0.4, 0.35, 0.2, 1)

    local sortText = bankSortButton:CreateFontString(nil, "OVERLAY")
    sortText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    sortText:SetPoint("CENTER")
    sortText:SetText("Sort")
    sortText:SetTextColor(0.8, 0.8, 0.8)

    bankSortButton:SetScript("OnClick", function()
        C_Container.SortBankBags()
    end)

    bankSortButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    end)

    bankSortButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    end)

    -- 格子容器
    local slotContainer = CreateFrame("Frame", nil, bankFrame)
    slotContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    slotContainer:SetPoint("BOTTOMRIGHT", -PADDING, 30)
    bankFrame.slotContainer = slotContainer

    -- 建立主銀行格子（-1）
    local slotID = 0
    local numMainBankSlots = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    for slot = 1, numMainBankSlots do
        slotID = slotID + 1
        local button = CreateBankSlot(slotContainer, slotID, BANK_CONTAINER, slot)

        local row = math.floor((slotID - 1) / SLOTS_PER_ROW)
        local col = (slotID - 1) % SLOTS_PER_ROW

        button:SetPoint("TOPLEFT", slotContainer, "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )

        button:SetID(slot)
        bankSlots[slotID] = button
    end

    -- 建立銀行包格子（5-11）
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotID = slotID + 1
            local button = CreateBankSlot(slotContainer, slotID, bag, slot)

            local row = math.floor((slotID - 1) / SLOTS_PER_ROW)
            local col = (slotID - 1) % SLOTS_PER_ROW

            button:SetPoint("TOPLEFT", slotContainer, "TOPLEFT",
                col * (SLOT_SIZE + SLOT_SPACING),
                -row * (SLOT_SIZE + SLOT_SPACING)
            )

            button:SetID(slot)
            bankSlots[slotID] = button
        end
    end

    -- 空格指示器
    local freeSlots = bankFrame:CreateFontString(nil, "OVERLAY")
    freeSlots:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(1, 0.82, 0)
    bankFrame.freeSlots = freeSlots

    return bankFrame
end

-- 批次更新銀行格子避免 FPS 下降
local bankUpdateQueue = {}
local bankUpdateInProgress = false
local BANK_BATCH_SIZE = 10

local function ProcessBankUpdateBatch()
    if #bankUpdateQueue == 0 then
        bankUpdateInProgress = false
        -- 完成時更新空格顯示
        if bankFrame and bankFrame.freeSlots then
            local free = GetTotalBankFreeSlots()
            local total = GetTotalBankSlots()
            bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
        end
        return
    end

    -- 處理批次
    for i = 1, BANK_BATCH_SIZE do
        local button = table.remove(bankUpdateQueue, 1)
        if button then
            UpdateBankSlot(button)
        end
        if #bankUpdateQueue == 0 then
            bankUpdateInProgress = false
            -- 完成時更新空格顯示
            if bankFrame and bankFrame.freeSlots then
                local free = GetTotalBankFreeSlots()
                local total = GetTotalBankSlots()
                bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
            end
            return
        end
    end

    -- 排程下一批次
    C_Timer.After(0, ProcessBankUpdateBatch)
end

local function UpdateAllBankSlots()
    -- 使用批次更新處理大型銀行
    wipe(bankUpdateQueue)
    for _, button in pairs(bankSlots) do
        if button then
            table.insert(bankUpdateQueue, button)
        end
    end

    if not bankUpdateInProgress and #bankUpdateQueue > 0 then
        bankUpdateInProgress = true
        ProcessBankUpdateBatch()
    end
end

local function RefreshBankLayout()
    if not bankFrame then return end

    -- 重新計算框架大小
    local totalSlots = GetTotalBankSlots()
    local numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + 30

    bankFrame:SetSize(width, height)

    -- 必要時重建格子
    local slotID = 0

    -- 主銀行格子
    local numMainBankSlots = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    for slot = 1, numMainBankSlots do
        slotID = slotID + 1

        if not bankSlots[slotID] then
            local button = CreateBankSlot(bankFrame.slotContainer, slotID, BANK_CONTAINER, slot)
            bankSlots[slotID] = button
        end

        local button = bankSlots[slotID]
        button.bag = BANK_CONTAINER
        button.slot = slot

        local row = math.floor((slotID - 1) / SLOTS_PER_ROW)
        local col = (slotID - 1) % SLOTS_PER_ROW

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bankFrame.slotContainer, "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )
        button:Show()
    end

    -- 銀行包格子
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotID = slotID + 1

            if not bankSlots[slotID] then
                local button = CreateBankSlot(bankFrame.slotContainer, slotID, bag, slot)
                bankSlots[slotID] = button
            end

            local button = bankSlots[slotID]
            button.bag = bag
            button.slot = slot

            local row = math.floor((slotID - 1) / SLOTS_PER_ROW)
            local col = (slotID - 1) % SLOTS_PER_ROW

            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", bankFrame.slotContainer, "TOPLEFT",
                col * (SLOT_SIZE + SLOT_SPACING),
                -row * (SLOT_SIZE + SLOT_SPACING)
            )
            button:Show()
        end
    end

    -- 隱藏多餘格子
    for i = slotID + 1, #bankSlots do
        if bankSlots[i] then
            bankSlots[i]:Hide()
        end
    end

    UpdateAllBankSlots()
end

local function OpenBank()
    if not bankFrame then
        CreateBankFrame()
    end

    if bankFrame then
        RefreshBankLayout()
        bankFrame:Show()
        isBankOpen = true
    end
end

local function CloseBank()
    if bankFrame then
        bankFrame:Hide()
        isBankOpen = false
    end
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateMoney()
    if not bagFrame or not bagFrame.money then return end

    local money = GetMoney()
    local gold = floor(money / 10000)
    local silver = floor((money % 10000) / 100)
    local copper = money % 100

    bagFrame.money:SetFormattedText("|cffffd700%d|r.|cffc0c0c0%02d|r.|cffeda55f%02d|r", gold, silver, copper)
end

local function UpdateFreeSlots()
    if not bagFrame or not bagFrame.freeSlots then return end

    local free = GetTotalFreeSlots()
    local total = GetTotalSlots()
    bagFrame.freeSlots:SetFormattedText("%d / %d", free, total)
end

local function UpdateAllSlots()
    for _, button in pairs(slots) do
        if button then
            UpdateSlot(button)
        end
    end
    UpdateMoney()
    UpdateFreeSlots()
end

local function RefreshBagLayout()
    if not bagFrame then return end

    -- 重新計算框架大小
    local totalSlots = GetTotalSlots()
    local numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + 30

    bagFrame:SetSize(width, height)

    -- 背包大小改變時重建格子
    local slotID = 0
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotID = slotID + 1

            if not slots[slotID] then
                local button = CreateItemSlot(bagFrame.slotContainer, slotID, bag, slot)
                slots[slotID] = button
            end

            local button = slots[slotID]
            button.bag = bag
            button.slot = slot

            local row = math.floor((slotID - 1) / SLOTS_PER_ROW)
            local col = (slotID - 1) % SLOTS_PER_ROW

            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", bagFrame.slotContainer, "TOPLEFT",
                col * (SLOT_SIZE + SLOT_SPACING),
                -row * (SLOT_SIZE + SLOT_SPACING)
            )
            button:Show()
        end
    end

    -- 隱藏多餘格子
    for i = slotID + 1, #slots do
        if slots[i] then
            slots[i]:Hide()
        end
    end

    UpdateAllSlots()
end

--------------------------------------------------------------------------------
-- 開啟/關閉背包
--------------------------------------------------------------------------------

local function OpenBags()
    if not bagFrame then
        CreateBagFrame()
    end

    if bagFrame then
        RefreshBagLayout()
        bagFrame:Show()
        isOpen = true
    end
end

local function CloseBags()
    if bagFrame then
        bagFrame:Hide()
        isOpen = false
    end
end

local function ToggleBags()
    if isOpen then
        CloseBags()
    else
        OpenBags()
    end
end

--------------------------------------------------------------------------------
-- 掛鉤暴雪背包函數
--------------------------------------------------------------------------------

local function HookBagFunctions()
    local db = LunarUI.db and LunarUI.db.profile.bags
    if not db or not db.enabled then return end

    -- 掛鉤 OpenAllBags
    hooksecurefunc("OpenAllBags", function()
        OpenBags()
    end)

    -- 掛鉤 CloseAllBags
    hooksecurefunc("CloseAllBags", function()
        CloseBags()
    end)

    -- 掛鉤 ToggleAllBags：按 B 時切換我們的背包
    hooksecurefunc("ToggleAllBags", function()
        ToggleBags()
    end)

    -- 隱藏暴雪背包框架
    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            frame:UnregisterAllEvents()
            frame:SetScript("OnShow", function(self) self:Hide() end)
            frame:Hide()
        end
    end

    -- 隱藏整合背包框架（正式服）
    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:UnregisterAllEvents()
        ContainerFrameCombinedBags:SetScript("OnShow", function(self) self:Hide() end)
        ContainerFrameCombinedBags:Hide()
    end

    -- 隱藏暴雪銀行框架
    if BankFrame then
        BankFrame:UnregisterAllEvents()
        BankFrame:SetScript("OnShow", function(self) self:Hide() end)
        BankFrame:Hide()
    end

    -- 隱藏帳號銀行框架（正式服）
    if AccountBankPanel then
        AccountBankPanel:UnregisterAllEvents()
        AccountBankPanel:SetScript("OnShow", function(self) self:Hide() end)
        AccountBankPanel:Hide()
    end
end

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BAG_SLOT_FLAGS_UPDATED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    -- 商人開啟時自動販賣垃圾
    if event == "MERCHANT_SHOW" then
        local db = LunarUI.db and LunarUI.db.profile.bags
        if db and db.autoSellJunk then
            C_Timer.After(0.3, SellJunk)
        end
        return
    end

    -- 銀行事件處理
    if event == "BANKFRAME_OPENED" then
        local db = LunarUI.db and LunarUI.db.profile.bags
        if db and db.enabled then
            OpenBank()
            -- 開啟銀行時同時開啟背包
            OpenBags()
        end
        return
    end

    if event == "BANKFRAME_CLOSED" then
        CloseBank()
        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED" then
        if bankFrame and bankFrame:IsShown() then
            UpdateAllBankSlots()
        end
        return
    end

    -- 一般背包更新
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        local bag = ...
        -- 更新背包（0-4）
        if bag and bag >= 0 and bag <= 4 then
            if bagFrame and bagFrame:IsShown() then
                for _, button in pairs(slots) do
                    if button and button.bag == bag then
                        UpdateSlot(button)
                    end
                end
                UpdateFreeSlots()
            end
        end
        -- 更新銀行包（5-11）
        if bag and bag >= FIRST_BANK_BAG and bag <= LAST_BANK_BAG then
            if bankFrame and bankFrame:IsShown() then
                for _, button in pairs(bankSlots) do
                    if button and button.bag == bag then
                        UpdateBankSlot(button)
                    end
                end
                if bankFrame.freeSlots then
                    local free = GetTotalBankFreeSlots()
                    local total = GetTotalBankSlots()
                    bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
                end
            end
        end
        return
    end

    if not bagFrame or not bagFrame:IsShown() then return end

    if event == "PLAYER_MONEY" then
        UpdateMoney()
    elseif event == "ITEM_LOCK_CHANGED" then
        UpdateAllSlots()
        if bankFrame and bankFrame:IsShown() then
            UpdateAllBankSlots()
        end
    elseif event == "BAG_SLOT_FLAGS_UPDATED" then
        RefreshBagLayout()
    end
end)

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateBagsForPhase()
    -- 背包通常在使用者需要時顯示，不自動淡出
end

local function RegisterBagsPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        UpdateBagsForPhase()
    end)
end

--------------------------------------------------------------------------------
-- 垃圾販賣
--------------------------------------------------------------------------------

--[[
    增強型自動販賣：包含安全檢查與統計資訊
]]
local function SellJunk()
    local db = LunarUI.db and LunarUI.db.profile.bags
    if not db or not db.autoSellJunk then return end

    local totalValue = 0
    local itemCount = 0
    local itemsSold = {}

    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
            if containerInfo and containerInfo.quality == 0 and not containerInfo.hasNoValue then
                -- 取得物品資訊計算價格
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, _, _, _, _, _, _, _, _, itemPrice = C_Item.GetItemInfo(itemLink)
                    if itemPrice and itemPrice > 0 then
                        local stackCount = containerInfo.stackCount or 1
                        local stackValue = itemPrice * stackCount
                        totalValue = totalValue + stackValue
                        itemCount = itemCount + 1

                        -- 儲存物品名稱供日誌使用
                        local itemName = C_Item.GetItemNameByID(containerInfo.itemID) or "Unknown"
                        table.insert(itemsSold, { name = itemName, count = stackCount, value = stackValue })

                        -- 實際販賣物品
                        C_Container.UseContainerItem(bag, slot)
                    end
                end
            end
        end
    end

    -- 輸出統計
    if itemCount > 0 then
        -- 格式化金額顯示
        local gold = floor(totalValue / 10000)
        local silver = floor((totalValue % 10000) / 100)
        local copper = totalValue % 100

        local goldStr = ""
        if gold > 0 then
            goldStr = format("|cffffd700%d|rg ", gold)
        end
        if silver > 0 or gold > 0 then
            goldStr = goldStr .. format("|cffc0c0c0%d|rs ", silver)
        end
        goldStr = goldStr .. format("|cffeda55f%d|rc", copper)

        -- 使用本地化字串
        local msg = L["SoldJunkItems"] or "Sold %d junk items for %s"
        print(format("|cff00ccffLunarUI:|r " .. msg, itemCount, goldStr))
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeBags()
    local db = LunarUI.db and LunarUI.db.profile.bags
    if not db or not db.enabled then return end

    -- 掛鉤背包函數
    HookBagFunctions()

    -- 註冊月相更新
    RegisterBagsPhaseCallback()

    -- 快捷鍵開啟背包由暴雪預設按鍵系統處理
end

-- 匯出
LunarUI.InitializeBags = InitializeBags
LunarUI.ToggleBags = ToggleBags
LunarUI.OpenBags = OpenBags
LunarUI.CloseBags = CloseBags
LunarUI.SellJunk = SellJunk
LunarUI.OpenBank = OpenBank
LunarUI.CloseBank = CloseBank

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.5, InitializeBags)
end)
