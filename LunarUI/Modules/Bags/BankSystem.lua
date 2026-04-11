---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, missing-parameter
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

-- Fixed viewport dimensions for scrollable bank (WoW 12.0: 6 tabs × 98 slots is
-- too large to fit on screen at once — use scroll instead of dynamic sizing).
-- Visible area = 14 columns × 14 rows = 196 slots; overflow uses the scroll bar.
local BANK_VIEWPORT_COLS = 14
local BANK_VIEWPORT_ROWS = 14
local BANK_SCROLLBAR_WIDTH = 18 -- UIPanelScrollFrameTemplate scroll bar reserves this much

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

-- 計算銀行每行格數。新架構（scrollable bank）下，橫向視窗寬度固定為
-- BANK_VIEWPORT_COLS，此函數僅用於舊的測試和 layout 呼叫點。回傳值永遠不
-- 超過 BANK_VIEWPORT_COLS；不足則回退到 SLOTS_PER_ROW。
local function GetBankSlotsPerRow(totalSlots)
    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE
    local SLOT_SPACING = c.SLOT_SPACING
    local SLOTS_PER_ROW = c.SLOTS_PER_ROW
    local PADDING = c.PADDING
    local HEADER_HEIGHT = c.HEADER_HEIGHT
    local FOOTER_HEIGHT = c.FOOTER_HEIGHT

    -- 僅在 viewport 範圍內計算 needed columns（scroll 負責處理縱向溢出）
    local screenHeight = GetScreenHeight()
    local maxHeight = screenHeight * 0.80
    local overhead = PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT
    local maxRows = mathFloor((maxHeight - overhead + SLOT_SPACING) / (SLOT_SIZE + SLOT_SPACING))
    maxRows = mathMax(maxRows, 1)

    local neededCols = mathCeil(totalSlots / maxRows)
    return mathMin(mathMax(SLOTS_PER_ROW, neededCols), BANK_VIEWPORT_COLS)
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

-- Scrollable bank：viewport（bankFrame）大小固定，slotContainer 依實際
-- slot 數決定高度，超出 viewport 的部分透過 ScrollFrame 捲動顯示。
local function ResizeBankFrame(actualSlotCount)
    if not bankFrame or not actualSlotCount or actualSlotCount == 0 then
        return
    end
    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE
    local SLOT_SPACING = c.SLOT_SPACING

    -- viewport 固定為 BANK_VIEWPORT_COLS 欄；slotContainer 高度隨 slot 數增長
    local bankCols = BANK_VIEWPORT_COLS
    bankFrame.bankCols = bankCols

    local totalRows = mathCeil(actualSlotCount / bankCols)
    totalRows = mathMax(totalRows, 1)

    -- slotContainer 實際高度（可能 > viewport → 觸發捲軸）
    local contentHeight = totalRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
    if bankFrame.slotContainer then
        bankFrame.slotContainer:SetHeight(mathMax(contentHeight, 1))
    end

    -- 所有 slot 都透過捲軸可見；displaySlots 等同實際 slot 數（保留欄位名稱相容）
    bankFrame.displaySlots = actualSlotCount
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

    -- Scrollable bank：固定 viewport 尺寸（BANK_VIEWPORT_COLS × BANK_VIEWPORT_ROWS
    -- 可見格子），slotContainer 可以比 viewport 更高，用 ScrollFrame 捲動
    local bankCols = BANK_VIEWPORT_COLS
    local viewportContentWidth = bankCols * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
    local viewportContentHeight = BANK_VIEWPORT_ROWS * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
    local frameWidth = viewportContentWidth + PADDING * 2 + BANK_SCROLLBAR_WIDTH
    local frameHeight = viewportContentHeight + PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT

    -- 建立主框架（固定 viewport 大小）
    bankFrame = CreateFrame("Frame", "LunarUI_Bank", UIParent, "BackdropTemplate")
    bankFrame:SetSize(frameWidth, frameHeight)
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
    bankFrame:SetFrameLevel(20) -- 略高於背包（預設 ~1），避免同層重疊時互相穿透
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

    -- 排序按鈕（與背包相同風格：UIPanelButtonTemplate + SkinButton）
    local bankSortButton = CreateFrame("Button", nil, bankFrame, "UIPanelButtonTemplate")
    bankSortButton:SetSize(60, 20)
    bankSortButton:SetPoint("TOPLEFT", title, "TOPRIGHT", 10, 2)
    bankSortButton:SetText(L["Sort"] or "Sort")
    LunarUI.SkinButton(bankSortButton)

    bankSortButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            return
        end
        LunarUI.BagsSetSorting(true)
        C_Container.SortBankBags()
    end)

    -- ScrollFrame wrapper：固定可視範圍，超出的 slot 透過捲軸可見
    -- （WoW 12.0 銀行分頁可達 600+ 格，不能再用動態 SetSize 否則撐破螢幕）
    local scrollFrame = CreateFrame("ScrollFrame", "LunarUI_BankScroll", bankFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    scrollFrame:SetPoint("BOTTOMRIGHT", -PADDING - BANK_SCROLLBAR_WIDTH, FOOTER_HEIGHT)
    scrollFrame:EnableMouseWheel(true)

    -- 捲動速度：每次滾輪 = 1 列高度（SLOT_SIZE + SLOT_SPACING = 41px）
    local scrollStep = SLOT_SIZE + SLOT_SPACING
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = current - delta * scrollStep
        if newScroll < 0 then
            newScroll = 0
        elseif newScroll > maxScroll then
            newScroll = maxScroll
        end
        self:SetVerticalScroll(newScroll)
    end)

    -- 格子容器（scrollFrame 的 scroll child）
    local slotContainer = CreateFrame("Frame", nil, scrollFrame)
    slotContainer:SetSize(viewportContentWidth, 1) -- 高度稍後由 ResizeBankFrame 設定
    slotContainer:EnableMouse(false) -- 讓滑鼠事件穿透到子按鈕
    scrollFrame:SetScrollChild(slotContainer)

    bankFrame.scrollFrame = scrollFrame
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

    -- 依實際格子數調整 slotContainer 高度（觸發 ScrollFrame 捲軸）
    ResizeBankFrame(slotID)

    -- 銀行搜尋過濾（委託共用 SearchSlots）
    ApplyBankSearch = function()
        SearchSlots(bankSearchBox, bankSlots, "BankSearchError")
    end

    -- 空格指示器
    local freeSlots = bankFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(freeSlots, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(0.7, 0.7, 0.7)
    bankFrame.freeSlots = freeSlots

    return bankFrame
end

--------------------------------------------------------------------------------
-- 批次更新銀行格子避免 FPS 下降
--------------------------------------------------------------------------------

local bankUpdateQueue = {}
local bankUpdateGeneration = 0
local BANK_BATCH_SIZE = 10

local function ProcessBankUpdateBatch()
    if #bankUpdateQueue == 0 then
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

    -- generation 遞增使前一批次 callback 失效，直接啟動新批次
    if #bankUpdateQueue > 0 then
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

    -- 更新 slotContainer 高度（會觸發 ScrollFrame 重算捲軸範圍）
    local bankCols = ResizeBankFrame(slotID) or BANK_VIEWPORT_COLS

    -- 重新定位所有格子（全部可見，超出 viewport 的部分由 ScrollFrame 捲動顯示）
    for i = 1, slotID do
        local button = bankSlots[i]
        if button then
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

        -- 並排：把背包錨定到銀行右側（ElvUI 模式）
        local bagFrame = LunarUI.BagsGetBagFrame and LunarUI.BagsGetBagFrame()
        if bagFrame and bagFrame:IsShown() then
            bagFrame._savedPoint = { bagFrame:GetPoint() }
            bagFrame:ClearAllPoints()
            bagFrame:SetPoint("TOPLEFT", bankFrame, "TOPRIGHT", 10, 0)
        end
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

        -- 重設排序旗標：銀行關閉時排序事件可能不再到達，避免 isSorting 永遠為 true
        LunarUI.BagsSetSorting(false)

        -- 並排恢復：背包回到原位
        local bagFrame = LunarUI.BagsGetBagFrame and LunarUI.BagsGetBagFrame()
        if bagFrame and bagFrame._savedPoint then
            bagFrame:ClearAllPoints()
            bagFrame:SetPoint(unpack(bagFrame._savedPoint))
            bagFrame._savedPoint = nil
        end
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
    -- 清除銀行批次更新佇列（generation 遞增使 pending callback 失效）
    wipe(bankUpdateQueue)
    bankUpdateGeneration = bankUpdateGeneration + 1

    if bankFrame then
        CloseBank()
        bankFrame:Hide()
        bankFrame = nil
    end

    wipe(bankSlots)
    bankSearchBox = nil
end
