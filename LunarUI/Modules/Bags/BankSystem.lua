---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 銀行系統
    銀行框架建立、格子管理、開關銀行、批次更新
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local tableInsert = table.insert
local tableRemove = table.remove
local L = Engine.L or {}
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 延遲解析：BankSystem.lua 在 Bags.lua 之前載入，
-- 共用函數透過 LunarUI 命名空間在呼叫時解析（非載入時）
--------------------------------------------------------------------------------

local function GetBagDB()
    return LunarUI.GetModuleDB("bags")
end

local function SetupSlotBase(button, bag, slot)
    return LunarUI.BagsSetupSlotBase(button, bag, slot)
end

local function SearchSlots(searchBoxRef, slotList, errorKey)
    return LunarUI.BagsSearchSlots(searchBoxRef, slotList, errorKey)
end

local function GetConstants()
    return LunarUI.BagsConstants
end

local function UpdateSlotVisuals(button, containerInfo, quality)
    return LunarUI.BagsUpdateSlotVisuals(button, containerInfo, quality)
end

local function UpdateSlotText(button, db, itemLink)
    return LunarUI.BagsUpdateSlotText(button, db, itemLink)
end

local function ClearSlot(button, db, bag)
    return LunarUI.BagsClearSlot(button, db, bag)
end

local function LoadBagSettings()
    return LunarUI.BagsLoadSettings()
end

--------------------------------------------------------------------------------
-- 銀行常數
--------------------------------------------------------------------------------

local BANK_CONTAINER = -1
local FIRST_BANK_BAG = 6 -- CharacterBankTab_1（WoW 12.0: bag 5 = 材料袋，非銀行包）
local LAST_BANK_BAG = 11 -- CharacterBankTab_6
local BANK_BUFFER_ROWS = 1 -- 尾部裁剪時額外保留的空行數

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local bankFrame
local bankSlots = {}
local isBankOpen = false
local bankSearchBox
local bankSearchTimer

local backdropTemplate = LunarUI.backdropTemplate

--------------------------------------------------------------------------------
-- 銀行輔助函數
--------------------------------------------------------------------------------

local function GetTotalBankSlots()
    local total = (C_Container.GetContainerNumSlots(BANK_CONTAINER) or 0)
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        total = total + (C_Container.GetContainerNumSlots(bag) or 0)
    end
    return total
end

local function GetTotalBankFreeSlots()
    local free = (C_Container.GetContainerNumFreeSlots(BANK_CONTAINER) or 0)
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    return free
end

-- 動態計算銀行每行格數，避免框架超出螢幕
local function GetBankSlotsPerRow(totalSlots)
    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE
    local SLOT_SPACING = c.SLOT_SPACING
    local SLOTS_PER_ROW = c.SLOTS_PER_ROW
    local PADDING = c.PADDING
    local HEADER_HEIGHT = c.HEADER_HEIGHT
    local FOOTER_HEIGHT = c.FOOTER_HEIGHT

    local screenHeight = GetScreenHeight()
    local maxHeight = screenHeight * 0.80 -- 留 20% 邊距
    local overhead = PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT
    local maxRows = mathFloor((maxHeight - overhead + SLOT_SPACING) / (SLOT_SIZE + SLOT_SPACING))
    maxRows = mathMax(maxRows, 1)
    local neededCols = mathCeil(totalSlots / maxRows)
    return mathMax(SLOTS_PER_ROW, neededCols)
end

-- 掃描銀行格子，找出最後一個有物品的 slotID
local function GetLastOccupiedSlotID()
    local lastOccupied = 0
    local slotID = 0

    local numMainBankSlots = (C_Container.GetContainerNumSlots(BANK_CONTAINER) or 0)
    for slot = 1, numMainBankSlots do
        slotID = slotID + 1
        if C_Container.GetContainerItemInfo(BANK_CONTAINER, slot) then
            lastOccupied = slotID
        end
    end

    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        local numSlots = (C_Container.GetContainerNumSlots(bag) or 0)
        for slot = 1, numSlots do
            slotID = slotID + 1
            if C_Container.GetContainerItemInfo(bag, slot) then
                lastOccupied = slotID
            end
        end
    end

    return lastOccupied
end

-- 依實際格子數重算並設定框架大小（裁掉尾部空行）
local function ResizeBankFrame(actualSlotCount)
    if not bankFrame or not actualSlotCount or actualSlotCount == 0 then
        return
    end
    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE
    local SLOT_SPACING = c.SLOT_SPACING
    local PADDING = c.PADDING
    local HEADER_HEIGHT = c.HEADER_HEIGHT
    local FOOTER_HEIGHT = c.FOOTER_HEIGHT

    local bankCols = GetBankSlotsPerRow(actualSlotCount)
    bankFrame.bankCols = bankCols

    -- 找出最後有物品的行，加上緩衝行，裁掉剩餘空行
    local lastOccupied = GetLastOccupiedSlotID()
    local lastOccupiedRow = mathCeil(lastOccupied / bankCols)
    local displayRows = lastOccupiedRow + BANK_BUFFER_ROWS
    local totalRows = mathCeil(actualSlotCount / bankCols)
    local numRows = mathMin(displayRows, totalRows)
    numRows = mathMax(numRows, 1) -- 至少 1 行

    -- 記錄顯示的格子數上限（供 caller 隱藏多餘格子）
    bankFrame.displaySlots = numRows * bankCols

    local width = bankCols * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT
    bankFrame:SetSize(width, height)
    return bankCols
end

--------------------------------------------------------------------------------
-- 銀行格子建立
--------------------------------------------------------------------------------

local function CreateBankSlot(parent, slotID, bag, slot)
    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE

    local button = CreateFrame(
        "ItemButton",
        "LunarUI_BankSlot" .. slotID,
        parent,
        "ContainerFrameItemButtonTemplate,SecureActionButtonTemplate"
    )
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- 設定共用基礎（圖示、邊框、物品等級、tooltip）
    SetupSlotBase(button, bag, slot)
    button.isBank = true

    return button
end

local function UpdateBankSlot(button)
    if not button or not button.bag or not button.slot then
        return
    end

    local db = GetBagDB()
    local bag, slot = button.bag, button.slot
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)

    if containerInfo then
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        local quality = containerInfo.quality or 0
        UpdateSlotVisuals(button, containerInfo, quality)
        UpdateSlotText(button, db, itemLink)
        -- 銀行格子不需要 UpdateSlotEffects（無冷卻、新物品發光、垃圾/任務/升級指示）
    else
        ClearSlot(button, db, bag)
    end
end

--------------------------------------------------------------------------------
-- 銀行框架建立
--------------------------------------------------------------------------------

local function CreateBankFrame()
    local db = GetBagDB()
    if not db or not db.enabled then
        return
    end

    if bankFrame then
        return bankFrame
    end

    -- 從 DB 載入設定
    LoadBagSettings()

    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE
    local SLOT_SPACING = c.SLOT_SPACING
    local PADDING = c.PADDING
    local HEADER_HEIGHT = c.HEADER_HEIGHT
    local FOOTER_HEIGHT = c.FOOTER_HEIGHT
    local SEARCH_DEBOUNCE = c.SEARCH_DEBOUNCE
    local FRAME_ALPHA = c.FRAME_ALPHA
    local BORDER_COLOR_BANK = c.BORDER_COLOR_BANK

    -- 預估欄數（實際框架大小會在格子建立後依 slotID 重算）
    local totalSlots = GetTotalBankSlots()
    local bankCols = GetBankSlotsPerRow(totalSlots)

    -- 建立主框架（大小稍後由 ResizeBankFrame 設定）
    bankFrame = CreateFrame("Frame", "LunarUI_Bank", UIParent, "BackdropTemplate")
    bankFrame:SetSize(1, 1) -- 暫時大小
    bankFrame.bankCols = bankCols

    -- 位置記憶：優先讀取已儲存位置
    if db.bankPosition then
        bankFrame:SetPoint(
            db.bankPosition.point,
            UIParent,
            db.bankPosition.relPoint or db.bankPosition.point,
            db.bankPosition.x,
            db.bankPosition.y
        )
    else
        bankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -100)
    end

    bankFrame:SetBackdrop(backdropTemplate)
    bankFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], FRAME_ALPHA)
    bankFrame:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 1) -- 銀行用金色邊框
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
        -- 儲存位置到 DB
        local point, _, relPoint, x, y = self:GetPoint()
        local bankDb = GetBagDB()
        if bankDb then
            bankDb.bankPosition = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- 標題
    local title = bankFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", PADDING, -8)
    title:SetText(L["BankTitle"] or "Bank")
    title:SetTextColor(1, 0.82, 0) -- 金色
    bankFrame.title = title

    -- 關閉按鈕
    local bankCloseButton = CreateFrame("Button", nil, bankFrame, "UIPanelCloseButton")
    bankCloseButton:SetPoint("TOPRIGHT", 2, 2)
    LunarUI.SkinCloseButton(bankCloseButton)
    bankCloseButton:SetScript("OnClick", function()
        if LunarUI.CloseBank then
            LunarUI.CloseBank()
        end
    end)

    -- 搜尋框
    bankSearchBox = CreateFrame("EditBox", "LunarUI_BankSearch", bankFrame, "SearchBoxTemplate")
    bankSearchBox:SetSize(120, 20)
    bankSearchBox:SetPoint("TOPRIGHT", bankCloseButton, "TOPLEFT", -8, -2)

    -- 搜尋過濾函數（forward declare，實際定義在格子建立後）
    local ApplyBankSearch

    -- 搜尋防抖動：使用 HookScript 保留 SearchBoxTemplate 內建的佔位文字隱藏行為
    bankSearchBox:HookScript("OnTextChanged", function(_self)
        if bankSearchTimer then
            bankSearchTimer:Cancel()
            bankSearchTimer = nil
        end
        bankSearchTimer = C_Timer.NewTimer(SEARCH_DEBOUNCE, ApplyBankSearch)
    end)

    -- 排序按鈕
    local bankSortButton = CreateFrame("Button", nil, bankFrame, "BackdropTemplate")
    bankSortButton:SetSize(60, 20)
    bankSortButton:SetPoint("TOPLEFT", title, "TOPRIGHT", 10, 2)
    bankSortButton:SetBackdrop(backdropTemplate)
    bankSortButton:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    bankSortButton:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 1)

    local sortText = bankSortButton:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(sortText, 11, "OUTLINE")
    sortText:SetPoint("CENTER")
    sortText:SetText(L["Sort"] or "Sort")
    sortText:SetTextColor(0.8, 0.8, 0.8)

    bankSortButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            return
        end
        LunarUI.BagsSetSorting(true)
        C_Container.SortBankBags()
    end)

    bankSortButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C.bgButtonHover[1], C.bgButtonHover[2], C.bgButtonHover[3], C.bgButtonHover[4])
    end)

    bankSortButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    end)

    -- 格子容器
    local slotContainer = CreateFrame("Frame", nil, bankFrame)
    slotContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    slotContainer:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_HEIGHT)
    slotContainer:EnableMouse(false) -- 讓滑鼠事件穿透到子按鈕
    bankFrame.slotContainer = slotContainer

    -- 建立主銀行格子（-1）
    local slotID = 0
    local numMainBankSlots = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    for slot = 1, numMainBankSlots do
        slotID = slotID + 1
        local button = CreateBankSlot(slotContainer, slotID, BANK_CONTAINER, slot)

        local row = mathFloor((slotID - 1) / bankCols)
        local col = (slotID - 1) % bankCols

        button:SetPoint(
            "TOPLEFT",
            slotContainer,
            "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )

        button:SetID(slot)
        bankSlots[slotID] = button
    end

    -- 建立銀行包格子（6-11）
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotID = slotID + 1
            local button = CreateBankSlot(slotContainer, slotID, bag, slot)

            local row = mathFloor((slotID - 1) / bankCols)
            local col = (slotID - 1) % bankCols

            button:SetPoint(
                "TOPLEFT",
                slotContainer,
                "TOPLEFT",
                col * (SLOT_SIZE + SLOT_SPACING),
                -row * (SLOT_SIZE + SLOT_SPACING)
            )

            button:SetID(slot)
            bankSlots[slotID] = button
        end
    end

    -- 依實際建立的格子數重算框架大小（裁掉尾部空行）
    ResizeBankFrame(slotID)

    -- 隱藏超出顯示範圍的格子
    local displaySlots = bankFrame.displaySlots or slotID
    for i = displaySlots + 1, slotID do
        if bankSlots[i] then
            bankSlots[i]:Hide()
        end
    end

    -- 銀行搜尋過濾（委託共用 SearchSlots）
    ApplyBankSearch = function()
        SearchSlots(bankSearchBox, bankSlots, "BankSearchError")
    end

    -- 空格指示器
    local freeSlots = bankFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(freeSlots, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(1, 0.82, 0)
    bankFrame.freeSlots = freeSlots

    return bankFrame
end

--------------------------------------------------------------------------------
-- 批次更新銀行格子避免 FPS 下降
--------------------------------------------------------------------------------

local bankUpdateQueue = {}
local bankUpdateInProgress = false
local bankUpdateGeneration = 0
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
    for _ = 1, BANK_BATCH_SIZE do
        local button = tableRemove(bankUpdateQueue)
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

    -- 排程下一批次（使用 generation counter 防止 stale callback）
    local gen = bankUpdateGeneration
    C_Timer.After(0, function()
        if gen == bankUpdateGeneration then
            ProcessBankUpdateBatch()
        end
    end)
end

local function UpdateAllBankSlots()
    -- 使用批次更新處理大型銀行（遞增 generation 使 stale callback 失效）
    bankUpdateGeneration = bankUpdateGeneration + 1
    wipe(bankUpdateQueue)
    for _, button in pairs(bankSlots) do
        if button then
            tableInsert(bankUpdateQueue, button)
        end
    end

    if not bankUpdateInProgress and #bankUpdateQueue > 0 then
        bankUpdateInProgress = true
        ProcessBankUpdateBatch()
    end
end

local function RefreshBankLayout()
    if not bankFrame then
        return
    end

    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE
    local SLOT_SPACING = c.SLOT_SPACING

    -- 先建立/更新所有格子，再依實際數量調整框架大小
    local slotID = 0

    -- 主銀行格子
    local numMainBankSlots = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    for slot = 1, numMainBankSlots do
        slotID = slotID + 1

        local button = bankSlots[slotID]
        if not button then
            button = CreateBankSlot(bankFrame.slotContainer, slotID, BANK_CONTAINER, slot)
            bankSlots[slotID] = button
        end
        button.bag = BANK_CONTAINER
        button.slot = slot
    end

    -- 銀行包格子
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotID = slotID + 1

            local button = bankSlots[slotID]
            if not button then
                button = CreateBankSlot(bankFrame.slotContainer, slotID, bag, slot)
                bankSlots[slotID] = button
            end
            button.bag = bag
            button.slot = slot
        end
    end

    -- 依實際格子數調整框架大小
    local bankCols = ResizeBankFrame(slotID)
    if not bankCols then
        bankCols = c.SLOTS_PER_ROW
    end

    -- 重新定位可見範圍內的格子
    local displaySlots = bankFrame.displaySlots or slotID
    for i = 1, slotID do
        local button = bankSlots[i]
        if button then
            if i <= displaySlots then
                local row = mathFloor((i - 1) / bankCols)
                local col = (i - 1) % bankCols

                button:ClearAllPoints()
                button:SetPoint(
                    "TOPLEFT",
                    bankFrame.slotContainer,
                    "TOPLEFT",
                    col * (SLOT_SIZE + SLOT_SPACING),
                    -row * (SLOT_SIZE + SLOT_SPACING)
                )
                button:Show()
            else
                button:Hide()
            end
        end
    end

    -- 隱藏多餘格子（已刪除的舊格子）
    for i = slotID + 1, #bankSlots do
        if bankSlots[i] then
            bankSlots[i]:Hide()
        end
    end

    UpdateAllBankSlots()
end

--------------------------------------------------------------------------------
-- 開啟/關閉銀行
--------------------------------------------------------------------------------

local function OpenBank()
    if InCombatLockdown() then
        return
    end

    if not bankFrame then
        CreateBankFrame()
    end

    if bankFrame then
        -- 清除專業容器快取（銀行包可能已更換）
        LunarUI.BagsClearBagTypeCache()
        RefreshBankLayout()
        bankFrame:Show()
        isBankOpen = true
    end
end

local function CloseBank()
    if bankFrame then
        bankFrame:Hide()
        isBankOpen = false
        -- 取消銀行搜尋計時器避免洩漏
        if bankSearchTimer then
            bankSearchTimer:Cancel()
            bankSearchTimer = nil
        end
        -- 關閉時清除搜尋
        local db = GetBagDB()
        if db and db.clearSearchOnClose and bankSearchBox then
            bankSearchBox:SetText("")
            for _, button in pairs(bankSlots) do
                if button then
                    button:SetAlpha(1)
                end
            end
        end
        -- 清除銀行批次更新佇列避免洩漏
        wipe(bankUpdateQueue)
        bankUpdateInProgress = false
        -- 重設排序旗標：銀行關閉時排序事件可能不再到達，避免 isSorting 永遠為 true
        LunarUI.BagsSetSorting(false)
    end
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.BagsOpenBank = OpenBank
LunarUI.BagsCloseBank = CloseBank
LunarUI.BagsUpdateAllBankSlots = UpdateAllBankSlots
LunarUI.BagsUpdateBankSlot = UpdateBankSlot
LunarUI.BagsIsBankOpen = function()
    return isBankOpen
end
LunarUI.BagsGetBankFrame = function()
    return bankFrame
end
LunarUI.BagsGetBankSlots = function()
    return bankSlots
end

-- 向後相容匯出
LunarUI.OpenBank = OpenBank
LunarUI.CloseBank = CloseBank
LunarUI.GetBankSlotsPerRow = GetBankSlotsPerRow
LunarUI.GetTotalBankSlots = GetTotalBankSlots
LunarUI.GetTotalBankFreeSlots = GetTotalBankFreeSlots
LunarUI.GetLastOccupiedSlotID = GetLastOccupiedSlotID

-- 供 RebuildBags 使用的清理函數
LunarUI.BankSystemCleanup = function()
    for _, button in pairs(bankSlots) do
        if button then
            if button.newGlowAnim then
                button.newGlowAnim:Stop()
            end
            button:Hide()
            button:ClearAllPoints()
        end
    end
    -- 清除銀行批次更新佇列
    wipe(bankUpdateQueue)
    bankUpdateInProgress = false

    if bankFrame then
        CloseBank()
        bankFrame:Hide()
        bankFrame = nil
    end

    wipe(bankSlots)
    bankSearchBox = nil
end
