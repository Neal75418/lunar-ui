--[[
    LunarUI - Minimap Module
    Unified style minimap with Lunar theme

    Features:
    - Custom border frame (Lunar theme)
    - Button organization (LibDBIcon support)
    - Coordinate display
    - Zone text styling
    - Phase-aware alpha
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local MINIMAP_SIZE = 180
local BORDER_SIZE = 4
local COORD_UPDATE_INTERVAL = 0.2

local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local minimapFrame
local coordText
local zoneText
local clockText
local buttonFrame
local collectedButtons = {}
local coordUpdateTimer

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function GetPlayerCoords()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return nil, nil end

    local x, y = position:GetXY()
    if x and y then
        return x * 100, y * 100
    end
    return nil, nil
end

-- Fix #83: Cache last values to avoid unnecessary updates
local lastCoordString = nil
local lastClockString = nil

local function UpdateCoordinates()
    if not coordText then return end

    local x, y = GetPlayerCoords()
    if x and y then
        local coordString = string.format("%.1f, %.1f", x, y)
        -- Fix #83: Only update if value changed
        if coordString ~= lastCoordString then
            coordText:SetText(coordString)
            lastCoordString = coordString
            if not coordText:IsShown() then
                coordText:Show()
            end
        end
    else
        if lastCoordString ~= nil then
            coordText:SetText("")
            coordText:Hide()
            lastCoordString = nil
        end
    end
end

local function UpdateZoneText()
    if not zoneText then return end

    local zone = GetZoneText() or ""
    local subzone = GetSubZoneText() or ""

    if subzone and subzone ~= "" and subzone ~= zone then
        zoneText:SetText(subzone)
    else
        zoneText:SetText(zone)
    end

    -- Color based on PvP status
    local pvpType = C_PvP.GetZonePVPInfo()
    if pvpType == "sanctuary" then
        zoneText:SetTextColor(0.41, 0.8, 0.94) -- Light blue
    elseif pvpType == "friendly" then
        zoneText:SetTextColor(0.1, 1.0, 0.1) -- Green
    elseif pvpType == "hostile" then
        zoneText:SetTextColor(1.0, 0.1, 0.1) -- Red
    elseif pvpType == "contested" then
        zoneText:SetTextColor(1.0, 0.7, 0.0) -- Orange
    else
        zoneText:SetTextColor(0.9, 0.9, 0.9) -- White/Gray
    end
end

local function UpdateClock()
    if not clockText then return end

    local hour, minute = GetGameTime()
    local clockString = string.format("%02d:%02d", hour, minute)
    -- Fix #83: Only update if value changed
    if clockString ~= lastClockString then
        clockText:SetText(clockString)
        lastClockString = clockString
    end
end

--------------------------------------------------------------------------------
-- Minimap Button Collection
--------------------------------------------------------------------------------

-- Fix #86: Use hash map for O(1) deduplication lookup
local scannedButtonIDs = {}

-- Fix #86: Clean up stale button references before scanning
local function ClearStaleButtonReferences()
    local validButtons = {}
    for _, button in ipairs(collectedButtons) do
        if button and button:IsShown() then
            validButtons[#validButtons + 1] = button
        end
    end
    collectedButtons = validButtons
    wipe(scannedButtonIDs)
end

local function CollectMinimapButton(button)
    if not button then return end
    if not (button:IsObjectType("Button") or button:IsObjectType("Frame")) then
        return
    end

    local name = button:GetName()
    if not name then return end

    -- Fix #86: Use hash map for O(1) duplicate check
    if scannedButtonIDs[name] then return end

    -- Skip certain buttons
    local skipButtons = {
        "MiniMapTracking",
        "MiniMapMailFrame",
        "MinimapZoomIn",
        "MinimapZoomOut",
        "Minimap",
        "MinimapBackdrop",
        "GameTimeFrame",
        "TimeManagerClockButton",
        "LunarUI_MinimapButton",
    }

    for _, skip in ipairs(skipButtons) do
        if name:find(skip) then return end
    end

    -- Mark as scanned and add to collection
    scannedButtonIDs[name] = true
    table.insert(collectedButtons, button)
end

-- Fix #77: Button priority for common addons
local BUTTON_PRIORITY = {
    ["DBM"] = 1,
    ["DeadlyBoss"] = 1,
    ["BigWigs"] = 2,
    ["Details"] = 3,
    ["Skada"] = 4,
    ["Recount"] = 5,
    ["WeakAuras"] = 6,
    ["Plater"] = 7,
    ["Bartender"] = 8,
    ["ElvUI"] = 9,
    ["Bagnon"] = 10,
    ["AdiBags"] = 11,
    ["AtlasLoot"] = 12,
    ["GTFO"] = 13,
    ["Pawn"] = 14,
    ["Simulationcraft"] = 15,
}

local function GetButtonPriority(button)
    local name = button:GetName() or ""

    -- Check against priority list
    for addon, priority in pairs(BUTTON_PRIORITY) do
        if name:find(addon) then
            return priority
        end
    end

    -- Default: sort alphabetically (priority 100+)
    return 100
end

local function SortButtons()
    table.sort(collectedButtons, function(a, b)
        local priorityA = GetButtonPriority(a)
        local priorityB = GetButtonPriority(b)

        if priorityA ~= priorityB then
            return priorityA < priorityB
        end

        -- Same priority: sort by name
        local nameA = a:GetName() or ""
        local nameB = b:GetName() or ""
        return nameA < nameB
    end)
end

local function OrganizeMinimapButtons()
    if not buttonFrame then return end

    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not db.organizeButtons then return end

    -- Fix #77: Sort buttons by priority before organizing
    SortButtons()

    local buttonsPerRow = 6
    local buttonSize = 24
    local spacing = 2

    for i, button in ipairs(collectedButtons) do
        if button and button:IsShown() then
            button:SetParent(buttonFrame)
            button:ClearAllPoints()

            local row = math.floor((i - 1) / buttonsPerRow)
            local col = (i - 1) % buttonsPerRow

            button:SetPoint("TOPLEFT", buttonFrame, "TOPLEFT",
                col * (buttonSize + spacing),
                -row * (buttonSize + spacing)
            )

            -- Normalize button size
            button:SetSize(buttonSize, buttonSize)

            -- Style button
            local regions = { button:GetRegions() }
            for _, region in ipairs(regions) do
                if region:IsObjectType("Texture") then
                    local texturePath = region:GetTexture()
                    if texturePath and type(texturePath) == "string" then
                        if texturePath:find("MinimapButton") or texturePath:find("TrackingBorder") then
                            region:SetTexture(nil)
                        end
                    end
                end
            end
        end
    end

    -- Resize button frame
    local numButtons = #collectedButtons
    local numRows = math.ceil(numButtons / buttonsPerRow)
    local width = math.min(numButtons, buttonsPerRow) * (buttonSize + spacing) - spacing
    local height = numRows * (buttonSize + spacing) - spacing

    if width > 0 and height > 0 then
        buttonFrame:SetSize(width, height)
        buttonFrame:Show()
    else
        buttonFrame:Hide()
    end
end

local function ScanForMinimapButtons()
    -- Fix #86: Clear stale references before rescanning
    ClearStaleButtonReferences()

    -- Scan Minimap children
    local children = { Minimap:GetChildren() }
    for _, child in ipairs(children) do
        CollectMinimapButton(child)
    end

    -- Scan MinimapBackdrop children
    if MinimapBackdrop then
        children = { MinimapBackdrop:GetChildren() }
        for _, child in ipairs(children) do
            CollectMinimapButton(child)
        end
    end

    -- Scan MinimapCluster children
    if MinimapCluster then
        children = { MinimapCluster:GetChildren() }
        for _, child in ipairs(children) do
            CollectMinimapButton(child)
        end
    end

    OrganizeMinimapButtons()
end

--------------------------------------------------------------------------------
-- Phase Awareness
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateMinimapForPhase()
    if not minimapFrame then return end

    local tokens = LunarUI:GetTokens()

    -- Minimap should be more visible even in NEW phase
    local minAlpha = 0.6
    local alpha = math.max(tokens.alpha, minAlpha)

    minimapFrame:SetAlpha(alpha)
end

local function RegisterMinimapPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        UpdateMinimapForPhase()
    end)
end

--------------------------------------------------------------------------------
-- Minimap Styling
--------------------------------------------------------------------------------

local function HideBlizzardMinimapElements()
    -- Hide default border/decorations
    local elementsToHide = {
        MinimapBorder,
        MinimapBorderTop,
        MinimapZoomIn,
        MinimapZoomOut,
        MinimapZoneTextButton,
        MinimapToggleButton,
        MiniMapWorldMapButton,
        GameTimeFrame,
        MiniMapMailBorder,
    }

    for _, element in ipairs(elementsToHide) do
        if element then
            element:Hide()
            element:UnregisterAllEvents()
        end
    end

    -- Hide cluster elements (Retail)
    if MinimapCluster then
        local clusterElements = {
            MinimapCluster.BorderTop,
            MinimapCluster.ZoneTextButton,
            MinimapCluster.Tracking,
        }
        for _, element in ipairs(clusterElements) do
            if element then
                element:Hide()
            end
        end
    end

    -- Make minimap square
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8x8")

    -- Disable default zoom behavior
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            Minimap_ZoomIn()
        else
            Minimap_ZoomOut()
        end
    end)
end

local function CreateMinimapFrame()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not db.enabled then return end

    -- Create main container
    minimapFrame = CreateFrame("Frame", "LunarUI_Minimap", UIParent, "BackdropTemplate")
    minimapFrame:SetSize(MINIMAP_SIZE + BORDER_SIZE * 2, MINIMAP_SIZE + BORDER_SIZE * 2)
    minimapFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    minimapFrame:SetBackdrop(backdropTemplate)
    minimapFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    minimapFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    minimapFrame:SetFrameStrata("LOW")
    minimapFrame:SetMovable(true)
    minimapFrame:EnableMouse(true)
    minimapFrame:SetClampedToScreen(true)

    -- Drag support
    minimapFrame:RegisterForDrag("LeftButton")
    minimapFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    minimapFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- Reparent and resize Minimap
    Minimap:SetParent(minimapFrame)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", minimapFrame, "CENTER", 0, 0)
    Minimap:SetSize(MINIMAP_SIZE, MINIMAP_SIZE)
    Minimap:SetFrameLevel(minimapFrame:GetFrameLevel() + 1)

    -- Create zone text
    zoneText = minimapFrame:CreateFontString(nil, "OVERLAY")
    zoneText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    zoneText:SetPoint("TOP", minimapFrame, "BOTTOM", 0, -4)
    zoneText:SetTextColor(0.9, 0.9, 0.9)
    zoneText:SetJustifyH("CENTER")
    zoneText:SetWidth(MINIMAP_SIZE)
    zoneText:SetWordWrap(false)

    -- Create coordinate text
    if db.showCoords then
        coordText = minimapFrame:CreateFontString(nil, "OVERLAY")
        coordText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        coordText:SetPoint("BOTTOM", minimapFrame, "BOTTOM", 0, 4)
        coordText:SetTextColor(0.8, 0.8, 0.6)
        coordText:SetJustifyH("CENTER")
    end

    -- Create clock text
    if db.showClock then
        clockText = minimapFrame:CreateFontString(nil, "OVERLAY")
        clockText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        clockText:SetPoint("BOTTOMRIGHT", minimapFrame, "BOTTOMRIGHT", -4, 4)
        clockText:SetTextColor(0.7, 0.7, 0.7)
        clockText:SetJustifyH("RIGHT")
    end

    -- Create button organization frame
    if db.organizeButtons then
        buttonFrame = CreateFrame("Frame", "LunarUI_MinimapButtons", minimapFrame, "BackdropTemplate")
        buttonFrame:SetPoint("TOPRIGHT", minimapFrame, "TOPLEFT", -8, 0)
        buttonFrame:SetSize(100, 50)
        buttonFrame:SetBackdrop(backdropTemplate)
        buttonFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
        buttonFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.8)
        buttonFrame:Hide()
    end

    -- Register events
    minimapFrame:RegisterEvent("ZONE_CHANGED")
    minimapFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    minimapFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    minimapFrame:SetScript("OnEvent", function(self, event)
        UpdateZoneText()
    end)

    -- Update timer for coordinates and clock
    minimapFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= COORD_UPDATE_INTERVAL then
            self.elapsed = 0
            UpdateCoordinates()
            UpdateClock()
        end
    end)

    -- Right-click menu for tracking
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button then
                MinimapCluster.Tracking.Button:Click()
            elseif MiniMapTracking then
                ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
            end
        elseif button == "MiddleButton" then
            -- Toggle calendar
            if C_Calendar and C_Calendar.OpenCalendar then
                C_Calendar.OpenCalendar()
            end
        end
    end)

    return minimapFrame
end

--------------------------------------------------------------------------------
-- Mail Indicator
--------------------------------------------------------------------------------

local function CreateMailIndicator()
    if not minimapFrame then return end

    local mail = CreateFrame("Frame", "LunarUI_MinimapMail", minimapFrame)
    mail:SetSize(18, 18)
    mail:SetPoint("BOTTOMLEFT", minimapFrame, "BOTTOMLEFT", 4, 4)

    local icon = mail:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    mail.icon = icon

    -- Glow effect
    local glow = mail:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER")
    glow:SetSize(24, 24)
    glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    glow:SetVertexColor(1, 0.8, 0, 0.3)
    glow:SetBlendMode("ADD")
    mail.glow = glow

    mail:RegisterEvent("UPDATE_PENDING_MAIL")
    mail:SetScript("OnEvent", function(self)
        if HasNewMail() then
            self:Show()
        else
            self:Hide()
        end
    end)

    mail:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("You have mail!")
        GameTooltip:Show()
    end)

    mail:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Initial state
    if HasNewMail() then
        mail:Show()
    else
        mail:Hide()
    end

    -- Hide default mail frame
    if MiniMapMailFrame then
        MiniMapMailFrame:Hide()
        MiniMapMailFrame:UnregisterAllEvents()
    end
end

--------------------------------------------------------------------------------
-- Difficulty Indicator
--------------------------------------------------------------------------------

local function CreateDifficultyIndicator()
    if not minimapFrame then return end

    local diff = CreateFrame("Frame", "LunarUI_MinimapDifficulty", minimapFrame)
    diff:SetSize(24, 12)
    diff:SetPoint("TOPLEFT", minimapFrame, "TOPLEFT", 4, -4)

    local text = diff:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    text:SetAllPoints()
    text:SetJustifyH("LEFT")
    diff.text = text

    local function UpdateDifficulty()
        local _, instanceType = GetInstanceInfo()
        local difficulty = select(3, GetInstanceInfo())
        local diffName = GetDifficultyInfo(difficulty) or ""

        if instanceType == "none" then
            diff:Hide()
            return
        end

        -- Color based on instance type
        if instanceType == "raid" then
            text:SetTextColor(1, 0.5, 0)
        elseif instanceType == "party" then
            text:SetTextColor(0.5, 0.5, 1)
        elseif instanceType == "pvp" or instanceType == "arena" then
            text:SetTextColor(1, 0.2, 0.2)
        else
            text:SetTextColor(0.8, 0.8, 0.8)
        end

        -- Abbreviate difficulty name
        local abbrev = diffName:gsub("Heroic", "H"):gsub("Mythic", "M"):gsub("Normal", "N"):gsub("Looking For Raid", "LFR")
        text:SetText(abbrev)
        diff:Show()
    end

    diff:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    diff:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    diff:RegisterEvent("PLAYER_ENTERING_WORLD")
    diff:SetScript("OnEvent", UpdateDifficulty)

    -- Initial update
    C_Timer.After(0.5, UpdateDifficulty)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function InitializeMinimap()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not db.enabled then return end

    -- Hide Blizzard elements first
    HideBlizzardMinimapElements()

    -- Create our frame
    CreateMinimapFrame()

    -- Create indicators
    CreateMailIndicator()
    CreateDifficultyIndicator()

    -- Fix #62: Scan for buttons multiple times to catch late-loading addons (DBM, etc.)
    C_Timer.After(2, ScanForMinimapButtons)
    C_Timer.After(5, ScanForMinimapButtons)
    C_Timer.After(10, ScanForMinimapButtons)

    -- Register for phase updates
    RegisterMinimapPhaseCallback()

    -- Apply initial phase
    UpdateMinimapForPhase()

    -- Initial updates
    UpdateZoneText()
    UpdateCoordinates()
    UpdateClock()
end

-- Fix #15: Cleanup function for OnUpdate
function LunarUI:CleanupMinimap()
    if minimapFrame then
        minimapFrame:SetScript("OnUpdate", nil)
        minimapFrame:SetScript("OnEvent", nil)
    end
end

-- Export
LunarUI.InitializeMinimap = InitializeMinimap
LunarUI.minimapFrame = minimapFrame

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.5, InitializeMinimap)
end)
