---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, missing-parameter
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
-- Constants
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
-- State
--------------------------------------------------------------------------------

local lootFrame
local lootSlots = {}
local lootAllButton

--------------------------------------------------------------------------------
-- Slot Creation
--------------------------------------------------------------------------------

local function CreateLootSlot(parent, index)
    local slot = CreateFrame("Button", "LunarUI_LootSlot" .. index, parent)
    slot:SetSize(FRAME_WIDTH - FRAME_PADDING * 2, SLOT_HEIGHT)
    slot:EnableMouse(true)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background highlight
    local highlight = slot:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    highlight:SetVertexColor(1, 1, 1, 0.1)

    -- Icon
    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", slot, "LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.icon = icon

    -- Icon border (quality color)
    local iconBorder = slot:CreateTexture(nil, "OVERLAY")
    iconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    iconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    iconBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    iconBorder:SetVertexColor(0.3, 0.3, 0.3, 1)
    slot.iconBorder = iconBorder

    -- Icon background (behind icon for border effect)
    local iconBg = slot:CreateTexture(nil, "BORDER")
    iconBg:SetAllPoints(iconBorder)
    iconBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    iconBg:SetVertexColor(0, 0, 0, 1)
    slot.iconBg = iconBg

    -- Item name
    local name = slot:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(name, 11, "")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetPoint("RIGHT", slot, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    slot.name = name

    -- Quantity text (on the icon)
    local count = slot:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(count, 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    count:SetJustifyH("RIGHT")
    slot.count = count

    -- Click handler
    slot:SetScript("OnClick", function(self)
        if self.slotIndex then
            _G.LootSlot(self.slotIndex)
        end
    end)

    -- Tooltip
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
-- Frame Creation
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

    -- Backdrop
    if backdropTemplate then
        frame:SetBackdrop(backdropTemplate)
        frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.92)
        frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end

    -- Title bar (drag handle)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetHeight(TITLE_HEIGHT)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PADDING, -FRAME_PADDING)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FRAME_PADDING, -FRAME_PADDING)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Title text
    local title = titleBar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 12, "OUTLINE")
    title:SetPoint("LEFT", titleBar, "LEFT", 0, 0)
    title:SetText(L["LootTitle"] or "Loot")
    title:SetTextColor(0.9, 0.85, 0.7, 1)
    frame.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -FRAME_PADDING, -FRAME_PADDING)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    closeBtn:SetScript("OnClick", function()
        _G.CloseLoot()
    end)

    -- Loot All button
    local lootAllBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    lootAllBtn:SetSize(FRAME_WIDTH - FRAME_PADDING * 2, BUTTON_HEIGHT)
    lootAllBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, FRAME_PADDING)
    if backdropTemplate then
        lootAllBtn:SetBackdrop(backdropTemplate)
        lootAllBtn:SetBackdropColor(0.12, 0.10, 0.08, 0.9)
        lootAllBtn:SetBackdropBorderColor(0.25, 0.22, 0.18, 1)
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
    lootAllButton = lootAllBtn

    return frame
end

--------------------------------------------------------------------------------
-- Update Logic
--------------------------------------------------------------------------------

local function UpdateLootFrame()
    if not lootFrame then return end

    local numItems = _G.GetNumLootItems()
    if numItems == 0 then
        lootFrame:Hide()
        return
    end

    -- Ensure enough slots
    for i = #lootSlots + 1, numItems do
        lootSlots[i] = CreateLootSlot(lootFrame, i)
    end

    -- Position and fill slots
    local visibleCount = 0
    for i = 1, numItems do
        local slot = lootSlots[i]
        local lootIcon, lootName, lootQuantity, _, lootQuality, _, _, _, _ = _G.GetLootSlotInfo(i)

        if lootName then
            visibleCount = visibleCount + 1
            slot.slotIndex = i

            -- Icon
            slot.icon:SetTexture(lootIcon)

            -- Quality border color
            local qc = QUALITY_COLORS[lootQuality] or QUALITY_COLORS[1]
            slot.iconBorder:SetVertexColor(qc[1], qc[2], qc[3], 1)

            -- Name with quality color
            slot.name:SetText(lootName)
            slot.name:SetTextColor(qc[1], qc[2], qc[3], 1)

            -- Quantity
            if lootQuantity and lootQuantity > 1 then
                slot.count:SetText(lootQuantity)
                slot.count:Show()
            else
                slot.count:SetText("")
                slot.count:Hide()
            end

            -- Position
            slot:ClearAllPoints()
            slot:SetPoint("TOPLEFT", lootFrame, "TOPLEFT", FRAME_PADDING,
                -(FRAME_PADDING + TITLE_HEIGHT + (visibleCount - 1) * (SLOT_HEIGHT + SLOT_PADDING)))
            slot:Show()
        else
            slot:Hide()
            slot.slotIndex = nil
        end
    end

    -- Hide extra slots
    for i = numItems + 1, #lootSlots do
        lootSlots[i]:Hide()
        lootSlots[i].slotIndex = nil
    end

    -- Nothing visible (all slots cleared but LOOT_CLOSED not yet fired)
    if visibleCount == 0 then
        lootFrame:Hide()
        return
    end

    -- Resize frame
    local contentHeight = TITLE_HEIGHT + visibleCount * (SLOT_HEIGHT + SLOT_PADDING) + BUTTON_HEIGHT + FRAME_PADDING
    lootFrame:SetHeight(contentHeight + FRAME_PADDING * 2)

    -- Reposition loot all button
    lootAllButton:ClearAllPoints()
    lootAllButton:SetPoint("BOTTOM", lootFrame, "BOTTOM", 0, FRAME_PADDING)

    lootFrame:Show()
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local function OnEvent(_self, event, ...)
    if event == "LOOT_OPENED" then
        -- Check if module is enabled
        local db = LunarUI.db and LunarUI.db.profile
        if not db or not db.loot or not db.loot.enabled then return end

        -- Hide Blizzard loot frame
        if _G.LootFrame then
            _G.LootFrame:Hide()
        end

        -- Create our frame on first use
        if not lootFrame then
            lootFrame = CreateLootFrame()
        end

        -- Position near cursor
        lootFrame:ClearAllPoints()
        local x, y = _G.GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        lootFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 40, y / scale + 20)
        lootFrame:SetClampedToScreen(true)

        UpdateLootFrame()

    elseif event == "LOOT_SLOT_CLEARED" then
        local db = LunarUI.db and LunarUI.db.profile
        if not db or not db.loot or not db.loot.enabled then return end
        UpdateLootFrame()

    elseif event == "LOOT_CLOSED" then
        if lootFrame then
            lootFrame:Hide()
        end
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

--------------------------------------------------------------------------------
-- Hook Blizzard Loot Frame
--------------------------------------------------------------------------------

local blizzardLootHooked = false

local function HookBlizzardLoot()
    if blizzardLootHooked then return end
    blizzardLootHooked = true

    -- Prevent Blizzard LootFrame from showing when our module is active
    if _G.LootFrame and _G.LootFrame.Show then
        hooksecurefunc(_G.LootFrame, "Show", function(self)
            local db = LunarUI.db and LunarUI.db.profile
            if db and db.loot and db.loot.enabled then
                self:Hide()
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- Initialization & Cleanup
--------------------------------------------------------------------------------

local function InitializeLoot()
    local db = LunarUI.db and LunarUI.db.profile
    if not db or not db.loot or not db.loot.enabled then return end

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

-- Export
LunarUI.InitializeLoot = InitializeLoot
LunarUI.CleanupLoot = CleanupLoot

LunarUI:RegisterModule("Loot", {
    onEnable = InitializeLoot,
    onDisable = CleanupLoot,
})
