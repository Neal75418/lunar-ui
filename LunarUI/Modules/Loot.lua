---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - Loot Module
    Custom loot frame with Lunar theme styling

    Features:
    - Replaces Blizzard default loot frame
    - Item quality colored borders
    - Compact layout with icon + name + quantity
    - Loot All button
    - Auto-close on empty
    - Phase-aware opacity
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local SLOT_HEIGHT = 32
local SLOT_PADDING = 2
local ICON_SIZE = 28
local FRAME_WIDTH = 220
local FRAME_PADDING = 8
local TITLE_HEIGHT = 24
local BUTTON_HEIGHT = 22

-- 使用集中定義的品質顏色
local QUALITY_COLORS = LunarUI.QUALITY_COLORS

local backdropTemplate = LunarUI.backdropTemplate

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local lootFrame
local lootSlots = {}

--------------------------------------------------------------------------------
-- 格子建立
--------------------------------------------------------------------------------

local function CreateLootSlot(parent, index)
    local slot = CreateFrame("Button", "LunarUI_LootSlot" .. index, parent)
    slot:SetSize(FRAME_WIDTH - FRAME_PADDING * 2, SLOT_HEIGHT)
    slot:EnableMouse(true)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- 背景高亮
    local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    highlight:SetVertexColor(1, 1, 1, 0.1)

    -- 圖示
    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", slot, "LEFT", 2, 0)
    icon:SetTexCoord(unpack(LunarUI.ICON_TEXCOORD))
    slot.icon = icon

    -- 圖示邊框（品質顏色）
    local iconBorder = slot:CreateTexture(nil, "OVERLAY")
    iconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    iconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    iconBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    iconBorder:SetVertexColor(0.3, 0.3, 0.3, 1)
    slot.iconBorder = iconBorder

    -- 圖示背景（邊框效果）
    local iconBg = slot:CreateTexture(nil, "BORDER")
    iconBg:SetAllPoints(iconBorder)
    iconBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    iconBg:SetVertexColor(0, 0, 0, 1)
    slot.iconBg = iconBg

    -- 物品名稱
    local name = slot:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(name, 11, "")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetPoint("RIGHT", slot, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    slot.name = name

    -- 數量文字（顯示在圖示上）
    local count = slot:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(count, 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    count:SetJustifyH("RIGHT")
    slot.count = count

    -- 點擊處理
    slot:SetScript("OnClick", function(self)
        if self.slotIndex then
            _G.LootSlot(self.slotIndex)
        end
    end)

    -- 滑鼠提示
    slot:SetScript("OnEnter", function(self)
        if self.slotIndex then
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetLootItem(self.slotIndex)
            _G.GameTooltip:Show()
        end
    end)

    slot:SetScript("OnLeave", function()
        _G.GameTooltip:Hide()
    end)

    slot.slotIndex = nil
    return slot
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateLootFrame()
    local frame = CreateFrame("Frame", "LunarUI_LootFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, 100)
    frame:SetPoint("CURSOR")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(10)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()

    -- 背景框
    if backdropTemplate then
        frame:SetBackdrop(backdropTemplate)
        frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.92)
        frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end

    -- 標題列（拖曳把手）
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(TITLE_HEIGHT)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PADDING, -FRAME_PADDING)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FRAME_PADDING, -FRAME_PADDING)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        frame._lunarUserMoved = true
    end)

    -- 標題文字
    local title = titleBar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 12, "OUTLINE")
    title:SetPoint("LEFT", titleBar, "LEFT", 0, 0)
    title:SetText(L["LootTitle"] or "Loot")
    title:SetTextColor(0.9, 0.85, 0.7, 1)
    frame.title = title

    -- 關閉按鈕
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", 2, 2)
    LunarUI.SkinCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function()
        _G.CloseLoot()
    end)

    -- 全部拾取按鈕
    local lootAllBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    lootAllBtn:SetSize(FRAME_WIDTH - FRAME_PADDING * 2, BUTTON_HEIGHT)
    lootAllBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, FRAME_PADDING)
    if backdropTemplate then
        lootAllBtn:SetBackdrop(backdropTemplate)
        lootAllBtn:SetBackdropColor(C.inkDark[1], C.inkDark[2], C.inkDark[3], 0.9)
        lootAllBtn:SetBackdropBorderColor(C.borderWarm[1], C.borderWarm[2], C.borderWarm[3], C.borderWarm[4])
    end

    local lootAllText = lootAllBtn:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(lootAllText, 10, "OUTLINE")
    lootAllText:SetPoint("CENTER")
    lootAllText:SetText(L["LootAll"] or "Loot All")
    lootAllText:SetTextColor(0.9, 0.85, 0.7, 1)

    local lootAllHighlight = lootAllBtn:CreateTexture(nil, "HIGHLIGHT")
    lootAllHighlight:SetAllPoints()
    lootAllHighlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    lootAllHighlight:SetVertexColor(1, 1, 1, 0.08)

    lootAllBtn:SetScript("OnClick", function()
        for i = _G.GetNumLootItems(), 1, -1 do
            _G.LootSlot(i)
        end
    end)
    return frame
end

--------------------------------------------------------------------------------
-- 更新邏輯
--------------------------------------------------------------------------------

local function UpdateLootFrame()
    if not lootFrame then
        return
    end

    local numItems = _G.GetNumLootItems()
    if numItems == 0 then
        lootFrame:Hide()
        return
    end

    -- 確保欄位數量足夠
    for i = #lootSlots + 1, numItems do
        lootSlots[i] = CreateLootSlot(lootFrame, i)
    end

    -- 定位並填充欄位
    local visibleCount = 0
    for i = 1, numItems do
        local slot = lootSlots[i]
        if not slot then
            break
        end
        local lootIcon, lootName, lootQuantity, lootQuality, _, _, _, _ = _G.GetLootSlotInfo(i)

        if lootName then
            visibleCount = visibleCount + 1
            slot.slotIndex = i

            -- 圖示
            slot.icon:SetTexture(lootIcon)

            -- 品質邊框顏色
            local qc = QUALITY_COLORS[lootQuality] or QUALITY_COLORS[1]
            slot.iconBorder:SetVertexColor(qc[1], qc[2], qc[3], 1)

            -- 帶品質顏色的名稱
            slot.name:SetText(lootName)
            slot.name:SetTextColor(qc[1], qc[2], qc[3], 1)

            -- 數量
            if lootQuantity and lootQuantity > 1 then
                slot.count:SetText(lootQuantity)
                slot.count:Show()
            else
                slot.count:SetText("")
                slot.count:Hide()
            end

            -- 定位
            slot:ClearAllPoints()
            slot:SetPoint(
                "TOPLEFT",
                lootFrame,
                "TOPLEFT",
                FRAME_PADDING,
                -(FRAME_PADDING + TITLE_HEIGHT + (visibleCount - 1) * (SLOT_HEIGHT + SLOT_PADDING))
            )
            slot:Show()
        else
            slot:Hide()
            slot.slotIndex = nil
        end
    end

    -- 隱藏多餘欄位
    for i = numItems + 1, #lootSlots do
        lootSlots[i]:Hide()
        lootSlots[i].slotIndex = nil
    end

    -- 無可見內容（所有欄位已清除但 LOOT_CLOSED 尚未觸發）
    if visibleCount == 0 then
        lootFrame:Hide()
        return
    end

    -- 調整框架大小
    local contentHeight = TITLE_HEIGHT + visibleCount * (SLOT_HEIGHT + SLOT_PADDING) + BUTTON_HEIGHT + FRAME_PADDING
    lootFrame:SetHeight(contentHeight + FRAME_PADDING * 2)

    lootFrame:Show()
end

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local function OnEvent(_self, event)
    if event == "LOOT_OPENED" then
        -- 檢查模組是否啟用
        local db = LunarUI.GetModuleDB("loot")
        if not db or not db.enabled then
            return
        end

        -- 隱藏暴雪拾取框架（LootFrame 是 protected frame，戰鬥中不可 Hide）
        if _G.LootFrame then
            if not InCombatLockdown() then
                _G.LootFrame:Hide()
            else
                _G.LootFrame:SetAlpha(0)
            end
        end

        -- 首次使用時建立框架
        if not lootFrame then
            lootFrame = CreateLootFrame()
        end

        -- 定位：若使用者曾拖曳則保留位置，否則跟隨游標
        if not lootFrame._lunarUserMoved then
            lootFrame:ClearAllPoints()
            local x, y = _G.GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            lootFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 40, y / scale + 20)
        end
        lootFrame:SetClampedToScreen(true)

        UpdateLootFrame()
    elseif event == "LOOT_SLOT_CLEARED" then
        local db = LunarUI.GetModuleDB("loot")
        if not db or not db.enabled then
            return
        end
        UpdateLootFrame()
    elseif event == "LOOT_CLOSED" then
        if lootFrame then
            lootFrame:Hide()
        end
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

--------------------------------------------------------------------------------
-- 掛鉤暴雪拾取框架
--------------------------------------------------------------------------------

local blizzardLootHooked = false
local lootCombatRestoreFrame = nil

local function HookBlizzardLoot()
    if blizzardLootHooked then
        return
    end
    blizzardLootHooked = true

    -- 防止暴雪 LootFrame 在模組啟用時顯示
    -- 戰鬥中不呼叫 Hide()（LootFrame 是保護框架，會造成 taint）
    -- 改用 SetAlpha(0) 讓框架不可見
    if _G.LootFrame and _G.LootFrame.Show then
        hooksecurefunc(_G.LootFrame, "Show", function(self)
            if not LunarUI._modulesEnabled then
                return
            end
            local db = LunarUI.GetModuleDB("loot")
            if db and db.enabled then
                -- 在 Show hook 內呼叫 Hide() 會 taint（在 protected 呼叫堆疊內）
                -- 統一使用 SetAlpha(0) 隱藏，再於下一幀安全 Hide
                self:SetAlpha(0)
                if not InCombatLockdown() then
                    C_Timer.After(0, function()
                        if not InCombatLockdown() and self:IsShown() then
                            self:Hide()
                            self:SetAlpha(1)
                        end
                    end)
                else
                    -- 戰鬥中無法 Hide，等戰鬥結束後還原 alpha 並隱藏
                    if not lootCombatRestoreFrame then
                        lootCombatRestoreFrame = CreateFrame("Frame")
                    end
                    lootCombatRestoreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                    lootCombatRestoreFrame:SetScript("OnEvent", function(f)
                        f:UnregisterAllEvents()
                        if self:IsShown() and not InCombatLockdown() then
                            self:Hide()
                        end
                        self:SetAlpha(1)
                    end)
                end
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- 初始化與清理
--------------------------------------------------------------------------------

local function InitializeLoot()
    local db = LunarUI.GetModuleDB("loot")
    if not db or not db.enabled then
        return
    end

    eventFrame:RegisterEvent("LOOT_OPENED")
    eventFrame:RegisterEvent("LOOT_SLOT_CLEARED")
    eventFrame:RegisterEvent("LOOT_CLOSED")

    HookBlizzardLoot()
end

local function CleanupLoot()
    eventFrame:UnregisterAllEvents()
    if lootFrame then
        lootFrame:Hide()
    end
end

-- 匯出
LunarUI.InitializeLoot = InitializeLoot
LunarUI.CleanupLoot = CleanupLoot

LunarUI:RegisterModule("Loot", {
    onEnable = InitializeLoot,
    onDisable = CleanupLoot,
})
