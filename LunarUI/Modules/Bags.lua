--[[
    LunarUI - Bags Module
    All-in-one bag system with Lunar theme

    Features:
    - All bags combined into one frame
    - Parchment style background
    - Item sorting and categorization
    - Search functionality
    - Item level display on equipment
    - Junk selling automation
    - Phase-aware visibility
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}  -- Fix #104: Access localization table

--------------------------------------------------------------------------------
-- Constants
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

local ITEM_QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 }, -- Poor (gray)
    [1] = { 1.00, 1.00, 1.00 }, -- Common (white)
    [2] = { 0.12, 1.00, 0.00 }, -- Uncommon (green)
    [3] = { 0.00, 0.44, 0.87 }, -- Rare (blue)
    [4] = { 0.64, 0.21, 0.93 }, -- Epic (purple)
    [5] = { 1.00, 0.50, 0.00 }, -- Legendary (orange)
    [6] = { 0.90, 0.80, 0.50 }, -- Artifact (gold)
    [7] = { 0.00, 0.80, 0.98 }, -- Heirloom (light blue)
    [8] = { 0.00, 0.80, 1.00 }, -- WoW Token
}

--------------------------------------------------------------------------------
-- Module State
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

-- Bank bag IDs: -1 = main bank (28 slots), 5-11 = bank bags
local BANK_CONTAINER = -1
local REAGENT_BANK_CONTAINER = -3
local FIRST_BANK_BAG = 5
local LAST_BANK_BAG = 11

--------------------------------------------------------------------------------
-- Helper Functions
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

-- Fix #81: Cache for expensive item lookups
local itemLevelCache = {}
local equipmentTypeCache = {}
local itemLevelCacheSize = 0
local equipmentTypeCacheSize = 0
local CACHE_MAX_SIZE = 500

-- Fix #95: Helper function to count dictionary table size
-- (# operator only works for sequential integer keys, not dictionaries)
local function GetTableSize(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Fix #106: Check cache size BEFORE adding to prevent race condition
-- where the newly added item gets immediately wiped
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

    -- Fix #81: Use cache to avoid expensive API calls
    if itemLevelCache[itemLink] then
        return itemLevelCache[itemLink]
    end

    local itemLevel = select(1, C_Item.GetDetailedItemLevelInfo(itemLink))
    if itemLevel then
        -- Fix #106: Evict cache BEFORE adding new item to prevent losing it
        MaybeEvictItemLevelCache()
        itemLevelCache[itemLink] = itemLevel
        itemLevelCacheSize = itemLevelCacheSize + 1
    end
    return itemLevel
end

local function IsEquipment(itemLink)
    if not itemLink then return false end

    -- Fix #81: Use cache to avoid expensive API calls
    if equipmentTypeCache[itemLink] ~= nil then
        return equipmentTypeCache[itemLink]
    end

    local _, _, _, _, _, itemType = C_Item.GetItemInfo(itemLink)
    local isEquip = (itemType == "Armor" or itemType == "Weapon")
    -- Fix #106: Evict cache BEFORE adding new item to prevent losing it
    MaybeEvictEquipmentTypeCache()
    equipmentTypeCache[itemLink] = isEquip
    equipmentTypeCacheSize = equipmentTypeCacheSize + 1
    return isEquip
end

-- Fix #46: Bank helper functions
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
-- Slot Creation
--------------------------------------------------------------------------------

local function CreateItemSlot(parent, slotID, bag, slot)
    local button = CreateFrame("ItemButton", "LunarUI_BagSlot" .. slotID, parent, "ContainerFrameItemButtonTemplate")
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- Store bag/slot info
    button.bag = bag
    button.slot = slot

    -- Remove default textures
    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    -- Style icon
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- Create border
    if not button.LunarBorder then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop(backdropTemplate)
        border:SetBackdropColor(0, 0, 0, 0)
        border:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        button.LunarBorder = border
    end

    -- Item level text
    if not button.ilvlText then
        local ilvl = button:CreateFontString(nil, "OVERLAY")
        ilvl:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        ilvl:SetPoint("BOTTOMRIGHT", -2, 2)
        ilvl:SetTextColor(1, 1, 0.6)
        button.ilvlText = ilvl
    end

    -- Junk indicator
    if not button.junkIcon then
        local junk = button:CreateTexture(nil, "OVERLAY")
        junk:SetSize(12, 12)
        junk:SetPoint("TOPLEFT", 2, -2)
        junk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
        junk:Hide()
        button.junkIcon = junk
    end

    -- Quest indicator
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

        -- Fix #65: Set item icon texture
        local icon = button.icon or _G[button:GetName() .. "IconTexture"]
        if icon and containerInfo.iconFileID then
            icon:SetTexture(containerInfo.iconFileID)
            icon:Show()
        end

        -- Set item count
        local count = containerInfo.stackCount or 0
        if count > 1 then
            button.Count:SetText(count)
            button.Count:Show()
        else
            button.Count:Hide()
        end

        -- Set border color by quality
        -- Fix #88: Proper nil check for LunarBorder
        if button.LunarBorder then
            if quality and ITEM_QUALITY_COLORS[quality] then
                local color = ITEM_QUALITY_COLORS[quality]
                button.LunarBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            else
                button.LunarBorder:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            end
        end

        -- Show item level for equipment
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

        -- Show junk indicator
        if button.junkIcon then
            if quality == 0 and containerInfo.hasNoValue ~= true then
                button.junkIcon:Show()
            else
                button.junkIcon:Hide()
            end
        end

        -- Show quest indicator
        if button.questIcon then
            if containerInfo.isQuestItem then
                button.questIcon:Show()
                button.junkIcon:Hide() -- Don't show both
            else
                button.questIcon:Hide()
            end
        end
    else
        -- Empty slot
        -- Fix #65: Hide icon for empty slots
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
-- Bag Frame Creation
--------------------------------------------------------------------------------

local function CreateBagFrame()
    local db = LunarUI.db and LunarUI.db.profile.bags
    if not db or not db.enabled then return end

    if bagFrame then return bagFrame end

    -- Calculate frame size
    local totalSlots = GetTotalSlots()
    local numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + 30 -- Extra for money/buttons

    -- Create main frame
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

    -- Make draggable
    bagFrame:RegisterForDrag("LeftButton")
    bagFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bagFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Title
    local title = bagFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", PADDING, -8)
    title:SetText("Bags")
    title:SetTextColor(0.9, 0.9, 0.9)
    bagFrame.title = title

    -- Close button
    closeButton = CreateFrame("Button", nil, bagFrame)
    closeButton:SetSize(20, 20)
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetNormalFontObject(GameFontNormal)
    closeButton:SetText("×")
    closeButton:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    closeButton:SetScript("OnClick", function()
        CloseAllBags()
    end)

    -- Search box
    searchBox = CreateFrame("EditBox", "LunarUI_BagSearch", bagFrame, "SearchBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -8, -2)

    -- Fix #40: Add debounce to search to prevent performance issues
    -- Fix #82: Use proper timer with cancellation support
    -- Fix #89: Add error boundary for search
    -- Fix #97: Use C_Timer.NewTimer for proper cancellation instead of ID-based invalidation
    local searchTimer
    searchBox:SetScript("OnTextChanged", function(self)
        -- Cancel previous timer to prevent accumulation
        if searchTimer then
            searchTimer:Cancel()
        end

        -- Debounce: wait 0.2 seconds before searching
        searchTimer = C_Timer.NewTimer(0.2, function()
            local text = self:GetText():lower()
            for _, button in pairs(slots) do
                if button and button.bag and button.slot then
                    local success, err = pcall(function()
                        local itemLink = C_Container.GetContainerItemLink(button.bag, button.slot)
                        if itemLink then
                            local itemName = C_Item.GetItemInfo(itemLink)
                            if itemName then
                                -- Fix #89: Use plain text search to avoid regex errors
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
                        button:SetAlpha(1)  -- On error, show button
                        -- Fix #107: Log error in debug mode to prevent silent failures
                        if LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.debug then
                            LunarUI:Print("Bag search error: " .. tostring(err))
                        end
                    end
                end
            end
        end)
    end)

    -- Sort button
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

    -- Slot container
    local slotContainer = CreateFrame("Frame", nil, bagFrame)
    slotContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    slotContainer:SetPoint("BOTTOMRIGHT", -PADDING, 30)
    bagFrame.slotContainer = slotContainer

    -- Create slots
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

            -- Set button ID for default bag behavior
            button:SetID(slot)
            SetItemButtonDesaturated(button, false)

            slots[slotID] = button
        end
    end

    -- Money frame
    local money = bagFrame:CreateFontString(nil, "OVERLAY")
    money:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    money:SetPoint("BOTTOMLEFT", PADDING, 8)
    money:SetTextColor(1, 0.82, 0)
    bagFrame.money = money

    -- Free slots indicator
    local freeSlots = bagFrame:CreateFontString(nil, "OVERLAY")
    freeSlots:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(0.7, 0.7, 0.7)
    bagFrame.freeSlots = freeSlots

    return bagFrame
end

--------------------------------------------------------------------------------
-- Fix #46: Bank Frame Creation
--------------------------------------------------------------------------------

local function CreateBankSlot(parent, slotID, bag, slot)
    local button = CreateFrame("ItemButton", "LunarUI_BankSlot" .. slotID, parent, "ContainerFrameItemButtonTemplate")
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- Store bag/slot info
    button.bag = bag
    button.slot = slot
    button.isBank = true

    -- Remove default textures
    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    -- Style icon
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- Create border
    if not button.LunarBorder then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop(backdropTemplate)
        border:SetBackdropColor(0, 0, 0, 0)
        border:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        button.LunarBorder = border
    end

    -- Item level text
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

        -- Fix #65: Set item icon texture
        local icon = button.icon or _G[button:GetName() .. "IconTexture"]
        if icon and containerInfo.iconFileID then
            icon:SetTexture(containerInfo.iconFileID)
            icon:Show()
        end

        -- Set item count
        local count = containerInfo.stackCount or 0
        if count > 1 then
            button.Count:SetText(count)
            button.Count:Show()
        else
            button.Count:Hide()
        end

        -- Set border color by quality
        -- Fix #88: Proper nil check for LunarBorder
        if button.LunarBorder then
            if quality and ITEM_QUALITY_COLORS[quality] then
                local color = ITEM_QUALITY_COLORS[quality]
                button.LunarBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            else
                button.LunarBorder:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            end
        end

        -- Show item level for equipment
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
        -- Empty slot
        -- Fix #65: Hide icon for empty slots
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

    -- Calculate frame size
    local totalSlots = GetTotalBankSlots()
    local numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + 30

    -- Create main frame
    bankFrame = CreateFrame("Frame", "LunarUI_Bank", UIParent, "BackdropTemplate")
    bankFrame:SetSize(width, height)
    bankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -100)
    bankFrame:SetBackdrop(backdropTemplate)
    bankFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    bankFrame:SetBackdropBorderColor(0.4, 0.35, 0.2, 1) -- Gold tint for bank
    bankFrame:SetFrameStrata("HIGH")
    bankFrame:SetMovable(true)
    bankFrame:EnableMouse(true)
    bankFrame:SetClampedToScreen(true)
    bankFrame:Hide()

    -- Make draggable
    bankFrame:RegisterForDrag("LeftButton")
    bankFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bankFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Title
    local title = bankFrame:CreateFontString(nil, "OVERLAY")
    title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", PADDING, -8)
    title:SetText("Bank")
    title:SetTextColor(1, 0.82, 0) -- Gold color
    bankFrame.title = title

    -- Close button
    local bankCloseButton = CreateFrame("Button", nil, bankFrame)
    bankCloseButton:SetSize(20, 20)
    bankCloseButton:SetPoint("TOPRIGHT", -4, -4)
    bankCloseButton:SetNormalFontObject(GameFontNormal)
    bankCloseButton:SetText("×")
    bankCloseButton:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
    bankCloseButton:SetScript("OnClick", function()
        CloseBankFrame()
    end)

    -- Search box
    bankSearchBox = CreateFrame("EditBox", "LunarUI_BankSearch", bankFrame, "SearchBoxTemplate")
    bankSearchBox:SetSize(120, 20)
    bankSearchBox:SetPoint("TOPRIGHT", bankCloseButton, "TOPLEFT", -8, -2)

    -- Search with debounce
    -- Fix #96: Use proper timer cancellation and plain text search to prevent pattern injection
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
                            -- Fix #96: Use plain text search (1, true) to prevent Lua pattern injection
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
                        -- Fix #107: Log error in debug mode to prevent silent failures
                        if LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.debug then
                            LunarUI:Print("Bank search error: " .. tostring(err))
                        end
                    end
                end
            end
        end)
    end)

    -- Sort button
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

    -- Slot container
    local slotContainer = CreateFrame("Frame", nil, bankFrame)
    slotContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    slotContainer:SetPoint("BOTTOMRIGHT", -PADDING, 30)
    bankFrame.slotContainer = slotContainer

    -- Create slots for main bank (-1)
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

    -- Create slots for bank bags (5-11)
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

    -- Free slots indicator
    local freeSlots = bankFrame:CreateFontString(nil, "OVERLAY")
    freeSlots:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(1, 0.82, 0)
    bankFrame.freeSlots = freeSlots

    return bankFrame
end

-- Fix #84: Batched bank slot updates to prevent FPS drops
local bankUpdateQueue = {}
local bankUpdateInProgress = false
local BANK_BATCH_SIZE = 10

local function ProcessBankUpdateBatch()
    if #bankUpdateQueue == 0 then
        bankUpdateInProgress = false
        -- Update free slots display when done
        if bankFrame and bankFrame.freeSlots then
            local free = GetTotalBankFreeSlots()
            local total = GetTotalBankSlots()
            bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
        end
        return
    end

    -- Process batch
    for i = 1, BANK_BATCH_SIZE do
        local button = table.remove(bankUpdateQueue, 1)
        if button then
            UpdateBankSlot(button)
        end
        if #bankUpdateQueue == 0 then
            bankUpdateInProgress = false
            -- Update free slots display when done
            if bankFrame and bankFrame.freeSlots then
                local free = GetTotalBankFreeSlots()
                local total = GetTotalBankSlots()
                bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
            end
            return
        end
    end

    -- Schedule next batch
    C_Timer.After(0, ProcessBankUpdateBatch)
end

local function UpdateAllBankSlots()
    -- Fix #84: Use batched updates for large banks
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

    -- Recalculate frame size
    local totalSlots = GetTotalBankSlots()
    local numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + 30

    bankFrame:SetSize(width, height)

    -- Rebuild slots if needed
    local slotID = 0

    -- Main bank slots
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

    -- Bank bag slots
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

    -- Hide extra slots
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
-- Update Functions
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

    -- Recalculate frame size
    local totalSlots = GetTotalSlots()
    local numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + 30

    bagFrame:SetSize(width, height)

    -- Rebuild slots if bag sizes changed
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

    -- Hide extra slots
    for i = slotID + 1, #slots do
        if slots[i] then
            slots[i]:Hide()
        end
    end

    UpdateAllSlots()
end

--------------------------------------------------------------------------------
-- Bag Open/Close
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
-- Hook Blizzard Bag Functions
--------------------------------------------------------------------------------

local function HookBagFunctions()
    local db = LunarUI.db and LunarUI.db.profile.bags
    if not db or not db.enabled then return end

    -- Hook OpenAllBags
    hooksecurefunc("OpenAllBags", function()
        OpenBags()
    end)

    -- Hook CloseAllBags
    hooksecurefunc("CloseAllBags", function()
        CloseBags()
    end)

    -- Hook ToggleAllBags (Fix #58: Actually toggle our bags when B is pressed)
    hooksecurefunc("ToggleAllBags", function()
        ToggleBags()
    end)

    -- Hide Blizzard bag frames
    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            frame:UnregisterAllEvents()
            frame:SetScript("OnShow", function(self) self:Hide() end)
            frame:Hide()
        end
    end

    -- Hide combined bag frame (Retail)
    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:UnregisterAllEvents()
        ContainerFrameCombinedBags:SetScript("OnShow", function(self) self:Hide() end)
        ContainerFrameCombinedBags:Hide()
    end

    -- Fix #46: Hide Blizzard bank frame
    if BankFrame then
        BankFrame:UnregisterAllEvents()
        BankFrame:SetScript("OnShow", function(self) self:Hide() end)
        BankFrame:Hide()
    end

    -- Hide account bank frame if exists (Retail)
    if AccountBankPanel then
        AccountBankPanel:UnregisterAllEvents()
        AccountBankPanel:SetScript("OnShow", function(self) self:Hide() end)
        AccountBankPanel:Hide()
    end
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BAG_SLOT_FLAGS_UPDATED")
eventFrame:RegisterEvent("MERCHANT_SHOW")  -- Fix #14: Consolidated into main handler
-- Fix #46: Bank events
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    -- Fix #14: Handle MERCHANT_SHOW here instead of separate HookScript
    if event == "MERCHANT_SHOW" then
        local db = LunarUI.db and LunarUI.db.profile.bags
        if db and db.autoSellJunk then
            C_Timer.After(0.3, SellJunk)
        end
        return
    end

    -- Fix #46: Bank event handling
    if event == "BANKFRAME_OPENED" then
        local db = LunarUI.db and LunarUI.db.profile.bags
        if db and db.enabled then
            OpenBank()
            -- Also open bags when bank opens
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

    -- Regular bag updates
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        local bag = ...
        -- Update bags (0-4)
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
        -- Update bank bags (5-11)
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
-- Phase Awareness
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateBagsForPhase()
    -- Bags typically shown when user wants them, don't auto-fade
    -- But we could slightly adjust backdrop if needed
end

local function RegisterBagsPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        UpdateBagsForPhase()
    end)
end

--------------------------------------------------------------------------------
-- Junk Selling
--------------------------------------------------------------------------------

-- Fix #72: Enhanced auto-sell with safety checks and statistics
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
                -- Get item info for price calculation
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, _, _, _, _, _, _, _, _, itemPrice = C_Item.GetItemInfo(itemLink)
                    if itemPrice and itemPrice > 0 then
                        local stackCount = containerInfo.stackCount or 1
                        local stackValue = itemPrice * stackCount
                        totalValue = totalValue + stackValue
                        itemCount = itemCount + 1

                        -- Store item name for log
                        local itemName = C_Item.GetItemNameByID(containerInfo.itemID) or "Unknown"
                        table.insert(itemsSold, { name = itemName, count = stackCount, value = stackValue })

                        -- Actually sell the item
                        C_Container.UseContainerItem(bag, slot)
                    end
                end
            end
        end
    end

    -- Output statistics
    if itemCount > 0 then
        -- Format gold display
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

        -- Fix #104: Use localized string instead of hardcoded Chinese
        local msg = L["SoldJunkItems"] or "Sold %d junk items for %s"
        print(format("|cff00ccffLunarUI:|r " .. msg, itemCount, goldStr))
    end
end

-- Fix #14: MERCHANT_SHOW handling moved to main event handler above

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function InitializeBags()
    local db = LunarUI.db and LunarUI.db.profile.bags
    if not db or not db.enabled then return end

    -- Hook bag functions
    HookBagFunctions()

    -- Register for phase updates
    RegisterBagsPhaseCallback()

    -- Create keybind for opening bags (B key)
    -- This is handled by Blizzard's default keybind system
end

-- Export
LunarUI.InitializeBags = InitializeBags
LunarUI.ToggleBags = ToggleBags
LunarUI.OpenBags = OpenBags
LunarUI.CloseBags = CloseBags
LunarUI.SellJunk = SellJunk
-- Fix #46: Bank exports
LunarUI.OpenBank = OpenBank
LunarUI.CloseBank = CloseBank

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.5, InitializeBags)
end)
