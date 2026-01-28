--[[
    LunarUI - Tooltip Module
    Unified style tooltip with Lunar theme

    Features:
    - Custom border and background (Lunar theme)
    - Item level display
    - Spell ID display (optional)
    - Unit class coloring
    - Target of target display
    - Phase-aware anchor position
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local CLASS_COLORS = RAID_CLASS_COLORS

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local tooltipStyled = false

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function GetItemLevel(itemLink)
    if not itemLink then return nil end

    local itemLevel = select(1, C_Item.GetDetailedItemLevelInfo(itemLink))
    return itemLevel
end

local function GetUnitColor(unit)
    if not unit or not UnitExists(unit) then
        return 1, 1, 1
    end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class and CLASS_COLORS[class] then
            return CLASS_COLORS[class].r, CLASS_COLORS[class].g, CLASS_COLORS[class].b
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction then
            if reaction >= 5 then
                return 0.2, 0.8, 0.2 -- Friendly
            elseif reaction == 4 then
                return 1, 1, 0 -- Neutral
            else
                return 0.8, 0.2, 0.2 -- Hostile
            end
        end
    end

    return 1, 1, 1
end

local function FormatNumber(num)
    if num >= 1e9 then
        return string.format("%.2fB", num / 1e9)
    elseif num >= 1e6 then
        return string.format("%.2fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    end
    return tostring(num)
end

--------------------------------------------------------------------------------
-- Tooltip Styling
--------------------------------------------------------------------------------

local function StyleTooltip(tooltip)
    if not tooltip then return end

    -- Apply backdrop
    if tooltip.SetBackdrop then
        tooltip:SetBackdrop(backdropTemplate)
        tooltip:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        tooltip:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    elseif tooltip.NineSlice then
        -- Retail tooltip uses NineSlice
        tooltip.NineSlice:SetAlpha(0)

        if not tooltip.LunarBackdrop then
            local backdrop = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
            backdrop:SetAllPoints()
            backdrop:SetFrameLevel(tooltip:GetFrameLevel())
            backdrop:SetBackdrop(backdropTemplate)
            backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
            backdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            tooltip.LunarBackdrop = backdrop
        end
    end

    -- Style status bar (health bar)
    if tooltip.StatusBar or GameTooltipStatusBar then
        local statusBar = tooltip.StatusBar or GameTooltipStatusBar
        statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        statusBar:SetHeight(4)
        statusBar:ClearAllPoints()
        statusBar:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 2, 2)
        statusBar:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -2, 2)

        -- Add background to status bar
        if not statusBar.LunarBG then
            local bg = statusBar:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(0, 0, 0, 0.5)
            statusBar.LunarBG = bg
        end
    end
end

local function StyleAllTooltips()
    local tooltips = {
        GameTooltip,
        ShoppingTooltip1,
        ShoppingTooltip2,
        ItemRefTooltip,
        ItemRefShoppingTooltip1,
        ItemRefShoppingTooltip2,
        WorldMapTooltip,
        WorldMapCompareTooltip1,
        WorldMapCompareTooltip2,
        SmallTextTooltip,
        EmbeddedItemTooltip,
        NamePlateTooltip,
        QuestScrollFrame and QuestScrollFrame.StoryTooltip,
        BattlePetTooltip,
        FloatingBattlePetTooltip,
        FloatingPetBattleAbilityTooltip,
        PetBattlePrimaryUnitTooltip,
        PetBattlePrimaryAbilityTooltip,
    }

    for _, tooltip in ipairs(tooltips) do
        if tooltip then
            StyleTooltip(tooltip)
        end
    end
end

--------------------------------------------------------------------------------
-- Unit Tooltip Enhancement
--------------------------------------------------------------------------------

local function OnTooltipSetUnit(tooltip)
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end

    local _, unit = tooltip:GetUnit()
    if not unit then return end

    -- Color the tooltip border based on unit
    local r, g, b = GetUnitColor(unit)
    if tooltip.SetBackdropBorderColor then
        tooltip:SetBackdropBorderColor(r, g, b, 1)
    elseif tooltip.LunarBackdrop then
        tooltip.LunarBackdrop:SetBackdropBorderColor(r, g, b, 1)
    end

    -- Color the status bar
    local statusBar = tooltip.StatusBar or GameTooltipStatusBar
    if statusBar then
        statusBar:SetStatusBarColor(r, g, b)
    end

    -- Add target of target
    if db.showTargetTarget and UnitExists(unit .. "target") then
        local targetName = UnitName(unit .. "target")
        if targetName then
            local tr, tg, tb = GetUnitColor(unit .. "target")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffffffTarget:|r " .. targetName, tr, tg, tb)
        end
    end

    -- Add guild info for players
    if UnitIsPlayer(unit) then
        local guildName, guildRank = GetGuildInfo(unit)
        if guildName then
            -- Guild name is usually already shown, but we can style it
        end
    end

    -- Add role for group members
    if UnitInParty(unit) or UnitInRaid(unit) then
        local role = UnitGroupRolesAssigned(unit)
        if role and role ~= "NONE" then
            local roleText = {
                TANK = "|cff5555ffTank|r",
                HEALER = "|cff55ff55Healer|r",
                DAMAGER = "|cffff5555DPS|r",
            }
            if roleText[role] then
                tooltip:AddLine("Role: " .. roleText[role])
            end
        end
    end

    tooltip:Show()
end

--------------------------------------------------------------------------------
-- Item Tooltip Enhancement
--------------------------------------------------------------------------------

local function OnTooltipSetItem(tooltip)
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end

    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    -- Show item level
    if db.showItemLevel then
        local itemLevel = GetItemLevel(itemLink)
        if itemLevel and itemLevel > 1 then
            -- Find the first line that shows item level or add it
            local found = false
            for i = 2, tooltip:NumLines() do
                local line = _G[tooltip:GetName() .. "TextLeft" .. i]
                if line then
                    local text = line:GetText()
                    if text and text:find("Item Level") then
                        found = true
                        break
                    end
                end
            end

            if not found then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff00ff00Item Level: " .. itemLevel .. "|r")
            end
        end
    end

    -- Show item ID (debug option)
    if db.showItemID then
        local itemID = itemLink:match("item:(%d+)")
        if itemID then
            tooltip:AddLine("|cff888888Item ID: " .. itemID .. "|r")
        end
    end

    tooltip:Show()
end

--------------------------------------------------------------------------------
-- Spell Tooltip Enhancement
--------------------------------------------------------------------------------

local function OnTooltipSetSpell(tooltip)
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end
    if not db.showSpellID then return end

    local spellID = select(2, tooltip:GetSpell())
    if spellID then
        tooltip:AddLine("|cff888888Spell ID: " .. spellID .. "|r")
        tooltip:Show()
    end
end

--------------------------------------------------------------------------------
-- Tooltip Positioning
--------------------------------------------------------------------------------

local function SetTooltipPosition()
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end
    if not db.anchorCursor then return end

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if db.anchorCursor then
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        else
            -- Anchor to bottom right
            tooltip:SetOwner(parent, "ANCHOR_NONE")
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 50)
        end
    end)
end

--------------------------------------------------------------------------------
-- Phase Awareness
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateTooltipForPhase()
    -- Tooltips don't need phase awareness as they're transient
    -- But we could adjust backdrop alpha if desired
end

local function RegisterTooltipPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        UpdateTooltipForPhase()
    end)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function InitializeTooltip()
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end

    if tooltipStyled then return end
    tooltipStyled = true

    -- Style all tooltips
    StyleAllTooltips()

    -- Hook GameTooltip
    if GameTooltip then
        -- Unit tooltips
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
            -- Retail 10.0+
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
                OnTooltipSetUnit(tooltip)
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
                OnTooltipSetItem(tooltip)
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
                OnTooltipSetSpell(tooltip)
            end)
        else
            -- Classic / older API
            GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
            GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
            GameTooltip:HookScript("OnTooltipSetSpell", OnTooltipSetSpell)
        end

        -- Restyle on show
        GameTooltip:HookScript("OnShow", function(self)
            StyleTooltip(self)
        end)

        -- Reset border color on clear
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            elseif self.LunarBackdrop then
                self.LunarBackdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            end
        end)
    end

    -- Setup positioning
    SetTooltipPosition()

    -- Register for phase updates
    RegisterTooltipPhaseCallback()
end

-- Export
LunarUI.InitializeTooltip = InitializeTooltip

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.3, InitializeTooltip)
end)
