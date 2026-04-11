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

-- Scrollable bank viewport defaults (WoW 12.0: 6 tabs × 98 slots is too large
-- to fit on screen at once — use scroll instead of dynamic sizing). Visible
-- area defaults to 14 columns × 14 rows = 196 slots; overflow uses the scroll
-- bar. Actual values read from db.bags.bankViewportCols/Rows at runtime so
-- users can customise via /lunar config without requiring a constant change.
local BANK_VIEWPORT_COLS_DEFAULT = 14
local BANK_VIEWPORT_ROWS_DEFAULT = 14
local BANK_VIEWPORT_MIN = 8
local BANK_VIEWPORT_MAX = 20
local BANK_SCROLLBAR_WIDTH = 18 -- UIPanelScrollFrameTemplate scroll bar reserves this much

local function clampViewport(v, fallback)
    if type(v) ~= "number" then
        return fallback
    end
    if v < BANK_VIEWPORT_MIN then
        return BANK_VIEWPORT_MIN
    elseif v > BANK_VIEWPORT_MAX then
        return BANK_VIEWPORT_MAX
    end
    return mathFloor(v)
end

local function GetViewportCols()
    local db = GetBagDB()
    return clampViewport(db and db.bankViewportCols, BANK_VIEWPORT_COLS_DEFAULT)
end

local function GetViewportRows()
    local db = GetBagDB()
    return clampViewport(db and db.bankViewportRows, BANK_VIEWPORT_ROWS_DEFAULT)
end

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
    return mathMin(mathMax(SLOTS_PER_ROW, neededCols), GetViewportCols())
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

-- Compute bank slot layout with row-based sections.
--
-- Each bank container (main bank + 6 tabs) occupies its own block of rows —
-- tabs don't share rows with each other, so each section starts at a clean
-- row boundary. Returns slot positions (row/col), section break rows (for
-- divider rendering), total row count (for ResizeBankFrame), and slot count.
--
-- This is the single source of truth for "where does slotID N go". Both
-- CreateBankFrame and RefreshBankLayout delegate to this helper so flat and
-- refreshed layouts never drift.
local function ComputeBankLayout()
    local bankCols = GetViewportCols()
    local positions = {} -- [slotID] = { bag, slot, row, col }
    local sectionBreaks = {} -- [i] = { row = N, bag = B }  (skip first section)
    local currentRow = 0
    local slotID = 0

    local containers = { BANK_CONTAINER }
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        containers[#containers + 1] = bag
    end

    local firstNonEmptyHandled = false
    for _, bag in ipairs(containers) do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        if numSlots > 0 then
            if firstNonEmptyHandled then
                sectionBreaks[#sectionBreaks + 1] = { row = currentRow, bag = bag }
            end
            firstNonEmptyHandled = true

            for slot = 1, numSlots do
                slotID = slotID + 1
                local rowInSection = mathFloor((slot - 1) / bankCols)
                local col = (slot - 1) % bankCols
                positions[slotID] = {
                    bag = bag,
                    slot = slot,
                    row = currentRow + rowInSection,
                    col = col,
                }
            end
            currentRow = currentRow + mathCeil(numSlots / bankCols)
        end
    end

    return {
        positions = positions,
        sectionBreaks = sectionBreaks,
        totalRows = mathMax(currentRow, 1),
        slotCount = slotID,
        bankCols = bankCols,
    }
end

-- Scrollable bank：viewport（bankFrame）大小固定，slotContainer 依實際
-- slot 數決定高度，超出 viewport 的部分透過 ScrollFrame 捲動顯示。
--
-- `overrideRows` 允許呼叫端傳入預先算好的總列數（例如 ComputeBankLayout 考慮
-- section 邊界後的列數）。若未提供，則退回「slot 數 / cols 向上取整」的 flat
-- 假設（保留給 spec test 和向後相容呼叫點使用）。
local function ResizeBankFrame(actualSlotCount, overrideRows)
    if not bankFrame or not actualSlotCount or actualSlotCount == 0 then
        return
    end
    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE
    local SLOT_SPACING = c.SLOT_SPACING

    -- viewport 欄數由 DB 控制（clamp 到 [8, 20]）；slotContainer 高度隨 slot 數增長
    local bankCols = GetViewportCols()
    bankFrame.bankCols = bankCols

    local totalRows = overrideRows or mathCeil(actualSlotCount / bankCols)
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

-- Draw/update section divider lines between bank containers. Each divider is
-- a thin horizontal texture positioned at a row boundary between two sections.
-- Dividers are kept in bankFrame.sectionDividers for reuse across refreshes.
local function UpdateSectionDividers(sectionBreaks, slotContainer, viewportContentWidth)
    if not bankFrame then
        return
    end
    bankFrame.sectionDividers = bankFrame.sectionDividers or {}
    local dividers = bankFrame.sectionDividers
    local c = GetConstants()
    local SLOT_SIZE = c.SLOT_SIZE
    local SLOT_SPACING = c.SLOT_SPACING
    local rowHeight = SLOT_SIZE + SLOT_SPACING

    for i, section in ipairs(sectionBreaks) do
        local divider = dividers[i]
        if not divider then
            divider = slotContainer:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(C.borderWarm[1], C.borderWarm[2], C.borderWarm[3], 0.45)
            dividers[i] = divider
        end
        divider:Show()
        divider:ClearAllPoints()
        divider:SetHeight(1)
        -- Place the line at the vertical midpoint of the spacing between the
        -- previous section's last row and this section's first row.
        local yOffset = -(section.row * rowHeight) + (SLOT_SPACING / 2)
        divider:SetPoint("TOPLEFT", slotContainer, "TOPLEFT", 0, yOffset)
        divider:SetPoint("TOPRIGHT", slotContainer, "TOPLEFT", viewportContentWidth, yOffset)
    end

    -- Hide any dividers left over from a previous layout with more sections.
    for i = #sectionBreaks + 1, #dividers do
        if dividers[i] then
            dividers[i]:Hide()
        end
    end
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

-- Empty slot visual denoise: when db.bankDimEmpty is true, fade the slot
-- background for empty slots so items stand out more against sparse grids.
-- `slotBg` alpha is used (not button alpha) to avoid fighting with the
-- SearchSlots match-dimming mechanic.
local EMPTY_SLOT_BG_ALPHA = 0.25
local DEFAULT_SLOT_BG_ALPHA = 1

local function ApplyEmptySlotDim(button, isEmpty)
    if not button or not button.slotBg then
        return
    end
    local db = GetBagDB()
    if db and db.bankDimEmpty then
        button.slotBg:SetAlpha(isEmpty and EMPTY_SLOT_BG_ALPHA or DEFAULT_SLOT_BG_ALPHA)
    else
        button.slotBg:SetAlpha(DEFAULT_SLOT_BG_ALPHA)
    end
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
        ApplyEmptySlotDim(button, false)
        -- 銀行格子不需要 UpdateSlotEffects（無冷卻、新物品發光、垃圾/任務/升級指示）
    else
        ClearSlot(button, db, bag)
        ApplyEmptySlotDim(button, true)
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

    -- Scrollable bank：viewport 尺寸由 DB 控制（clamp 到 [8, 20]），
    -- slotContainer 可以比 viewport 更高，用 ScrollFrame 捲動
    local bankCols = GetViewportCols()
    local bankRows = GetViewportRows()
    local viewportContentWidth = bankCols * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
    local viewportContentHeight = bankRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
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

    -- 鍵盤捲動：PgUp/PgDn/Home/End/Esc 支援
    -- SetPropagateKeyboardInput(true) 讓 WASD/T/1-9 等非導覽鍵透傳到遊戲
    bankFrame:EnableKeyboard(true)
    bankFrame:SetPropagateKeyboardInput(true)
    bankFrame:SetScript("OnKeyDown", function(self, key)
        -- 每次事件先重設為透傳（預設讓遊戲處理），下方 nav key 分支再明確
        -- 攔截。避免 propagation state 在 nav key 後 latch 造成下一個按鍵被吃掉。
        self:SetPropagateKeyboardInput(true)

        local scroll = self.scrollFrame
        if not scroll then
            return
        end
        local current = scroll:GetVerticalScroll()
        local maxScroll = scroll:GetVerticalScrollRange()
        local pageHeight = scroll:GetHeight()

        if key == "PAGEUP" then
            self:SetPropagateKeyboardInput(false)
            scroll:SetVerticalScroll(mathMax(0, current - pageHeight))
        elseif key == "PAGEDOWN" then
            self:SetPropagateKeyboardInput(false)
            scroll:SetVerticalScroll(mathMin(maxScroll, current + pageHeight))
        elseif key == "HOME" then
            self:SetPropagateKeyboardInput(false)
            scroll:SetVerticalScroll(0)
        elseif key == "END" then
            self:SetPropagateKeyboardInput(false)
            scroll:SetVerticalScroll(maxScroll)
        elseif key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            if LunarUI.CloseBank then
                LunarUI.CloseBank()
            end
        end
        -- 其他鍵維持入口處設定的 propagation = true，遊戲會接到
    end)

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

    -- Skin search box clear button (X) to match dark theme
    if bankSearchBox.clearButton and LunarUI.SkinCloseButton then
        LunarUI.SkinCloseButton(bankSearchBox.clearButton)
    end

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
    -- EnableMouse(false) 讓 left-click drag 事件透傳到父框架 bankFrame，
    -- 使用者可以從捲動區域任意位置拖曳銀行（而非只能從 header 拖）
    scrollFrame:EnableMouse(false)

    -- 皮膚化預設捲軸以符合 LunarUI 深色主題
    if LunarUI.SkinScrollBar and scrollFrame.ScrollBar then
        LunarUI.SkinScrollBar(scrollFrame.ScrollBar)
    end

    -- 捲動速度：每次滾輪 = 1 列高度，從 GetConstants() 動態讀取以支援
    -- 運行時 slot size 變更（RebuildBags 會在設定改動時整個重建 bankFrame）
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cc = GetConstants()
        local scrollStep = cc.SLOT_SIZE + cc.SLOT_SPACING
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

    -- 捲動位置持久化：使用者捲動後儲存到 DB，下次開啟銀行時恢復
    scrollFrame:SetScript("OnVerticalScroll", function(_self, offset)
        local d = GetBagDB()
        if d then
            d.bankScrollPos = offset
        end
    end)

    -- 格子容器（scrollFrame 的 scroll child）
    local slotContainer = CreateFrame("Frame", nil, scrollFrame)
    slotContainer:SetSize(viewportContentWidth, 1) -- 高度稍後由 ResizeBankFrame 設定
    slotContainer:EnableMouse(false) -- 讓滑鼠事件穿透到子按鈕
    scrollFrame:SetScrollChild(slotContainer)

    bankFrame.scrollFrame = scrollFrame
    bankFrame.slotContainer = slotContainer

    -- Layout 計算：每個銀行容器佔整行邊界，避免 slot 跨越 section 分隔線
    local layout = ComputeBankLayout()
    for i = 1, layout.slotCount do
        local pos = layout.positions[i]
        local button = CreateBankSlot(slotContainer, i, pos.bag, pos.slot)
        button:SetPoint(
            "TOPLEFT",
            slotContainer,
            "TOPLEFT",
            pos.col * (SLOT_SIZE + SLOT_SPACING),
            -pos.row * (SLOT_SIZE + SLOT_SPACING)
        )
        button:SetID(pos.slot)
        bankSlots[i] = button
    end
    local slotID = layout.slotCount

    -- 依實際列數（含 section 邊界 padding）調整 slotContainer 高度
    ResizeBankFrame(slotID, layout.totalRows)

    -- 在 section 交界處畫上細線視覺分隔
    UpdateSectionDividers(layout.sectionBreaks, slotContainer, viewportContentWidth)

    -- 銀行搜尋過濾（委託共用 SearchSlots，並自動捲到第一個符合結果）
    ApplyBankSearch = function()
        SearchSlots(bankSearchBox, bankSlots, "BankSearchError")

        -- 搜尋非空時，找第一個符合的格子並捲動顯示
        local text = bankSearchBox and bankSearchBox:GetText() or ""
        if text == "" or not bankFrame or not bankFrame.scrollFrame then
            return
        end

        local firstMatch
        for i = 1, #bankSlots do
            local button = bankSlots[i]
            if button and button:IsShown() and button.bag and button.slot then
                -- 符合條件：alpha 回到 1（SearchSlots 將符合項目設為 alpha 1）
                -- 用顯式 if 避免 `a and b() or fallback` 在 b() 回傳 0 時的 Lua 陷阱
                local alpha = 1
                if button.GetAlpha then
                    alpha = button:GetAlpha()
                end
                if alpha and alpha >= 0.99 then
                    local ok, link = pcall(C_Container.GetContainerItemLink, button.bag, button.slot)
                    if ok and link then
                        firstMatch = button
                        break
                    end
                end
            end
        end

        if not firstMatch then
            return
        end

        -- 計算 scrollFrame 中 firstMatch 的 Y 偏移並捲動到它
        local scrollChild = bankFrame.slotContainer
        if not scrollChild then
            return
        end
        local buttonTop = firstMatch.GetTop and firstMatch:GetTop()
        local containerTop = scrollChild.GetTop and scrollChild:GetTop()
        if buttonTop and containerTop then
            local offset = containerTop - buttonTop
            local maxScroll = bankFrame.scrollFrame:GetVerticalScrollRange()
            if offset < 0 then
                offset = 0
            elseif offset > maxScroll then
                offset = maxScroll
            end
            bankFrame.scrollFrame:SetVerticalScroll(offset)
        end
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
    local slotContainer = bankFrame.slotContainer
    if not slotContainer then
        return
    end

    -- 重算 layout（考慮 section 邊界 + viewport cols）
    local layout = ComputeBankLayout()
    local slotID = layout.slotCount

    -- 建立/重用 slot button 並根據新 layout 定位
    for i = 1, slotID do
        local pos = layout.positions[i]
        local button = bankSlots[i]
        if not button then
            button = CreateBankSlot(slotContainer, i, pos.bag, pos.slot)
            bankSlots[i] = button
        end
        button.bag = pos.bag
        button.slot = pos.slot
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            slotContainer,
            "TOPLEFT",
            pos.col * (SLOT_SIZE + SLOT_SPACING),
            -pos.row * (SLOT_SIZE + SLOT_SPACING)
        )
        button:SetID(pos.slot)
        button:Show()
    end

    -- 更新 slotContainer 高度（會觸發 ScrollFrame 重算捲軸範圍）
    ResizeBankFrame(slotID, layout.totalRows)

    -- 更新 section 分隔線（跟 viewport 寬度一致）
    local viewportContentWidth = layout.bankCols * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING
    UpdateSectionDividers(layout.sectionBreaks, slotContainer, viewportContentWidth)

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

        -- 恢復上次捲動位置：ScrollFrame 的 GetVerticalScrollRange 需要一個 frame
        -- tick 才會在 Show 後算好，同一 frame 內會回傳 0 導致 savedPos 被錯誤
        -- clamp 成 0（等於每次開銀行都跳回頂部）。用 C_Timer.After(0) 延後到
        -- 下一 frame。若使用者在 tick 前關掉銀行則跳過恢復避免作用在已隱藏的框架。
        if bankFrame.scrollFrame then
            C_Timer.After(0, function()
                if not isBankOpen or not bankFrame or not bankFrame.scrollFrame then
                    return
                end
                local d = GetBagDB()
                local savedPos = (d and d.bankScrollPos) or 0
                local maxScroll = bankFrame.scrollFrame:GetVerticalScrollRange() or 0
                if savedPos > maxScroll then
                    savedPos = maxScroll
                end
                if savedPos < 0 then
                    savedPos = 0
                end
                bankFrame.scrollFrame:SetVerticalScroll(savedPos)
            end)
        end

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

-- Spec-only exports: allow unit tests to exercise the scrollable-bank
-- viewport invariant directly. Underscore prefix marks these as internal.
LunarUI._ResizeBankFrame = ResizeBankFrame
LunarUI._ComputeBankLayout = ComputeBankLayout
LunarUI._GetViewportCols = GetViewportCols
LunarUI._GetViewportRows = GetViewportRows
LunarUI._BANK_VIEWPORT_COLS_DEFAULT = BANK_VIEWPORT_COLS_DEFAULT
LunarUI._BANK_VIEWPORT_ROWS_DEFAULT = BANK_VIEWPORT_ROWS_DEFAULT
LunarUI._BANK_VIEWPORT_MIN = BANK_VIEWPORT_MIN
LunarUI._BANK_VIEWPORT_MAX = BANK_VIEWPORT_MAX
LunarUI._SetBankFrameForTest = function(f)
    bankFrame = f
end

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
