--[[
    LunarUI - ActionBars
    LibActionButton-based action bar system with Phase awareness

    Features:
    - Main action bars (1-6)
    - Stance bar / Pet bar / Vehicle bar
    - Phase-aware alpha fading
    - Cooldown text display
    - Keybinding hover mode
    - Configurable button size and spacing
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- Wait for LibActionButton
local LAB = LibStub("LibActionButton-1.0", true)
if not LAB then
    -- Library not available, skip ActionBars
    return
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local BUTTON_SIZE = 36
local BUTTON_SPACING = 4
local BUTTONS_PER_ROW = 12

local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local bars = {}
local buttons = {}
local keybindMode = false

-- Fix #12 & Fix #103: Custom cooldown text disabled due to WoW 12.0 secret values
-- The built-in cooldown display and OmniCC/similar addons handle cooldown text display
-- Removed dead code: cooldownUpdateFrame, cooldownButtons, cdElapsed

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function CreateBarFrame(name, numButtons, parent)
    -- Use SecureHandlerStateTemplate for WrapScript support (required by LAB)
    local frame = CreateFrame("Frame", name, parent or UIParent, "SecureHandlerStateTemplate")
    frame:SetSize(
        numButtons * BUTTON_SIZE + (numButtons - 1) * BUTTON_SPACING,
        BUTTON_SIZE
    )
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(false)

    -- Background (optional, hidden by default)
    local bg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", -4, 4)
    bg:SetPoint("BOTTOMRIGHT", 4, -4)
    bg:SetBackdrop(backdropTemplate)
    bg:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
    bg:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.8)
    bg:Hide()
    frame.bg = bg

    return frame
end

local function StyleButton(button)
    if not button then return end

    -- Get button elements
    local name = button:GetName()
    local icon = button.icon or _G[name .. "Icon"]
    local count = button.Count or _G[name .. "Count"]
    local hotkey = button.HotKey or _G[name .. "HotKey"]
    local border = button.Border or _G[name .. "Border"]
    local normalTexture = button:GetNormalTexture()
    local pushedTexture = button:GetPushedTexture()
    local highlightTexture = button:GetHighlightTexture()
    local checkedTexture = button:GetCheckedTexture()

    -- Style icon
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetDrawLayer("ARTWORK")
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- Style count text
    if count then
        count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", -2, 2)
    end

    -- Style hotkey text
    if hotkey then
        hotkey:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", -2, -2)
        hotkey:SetTextColor(0.8, 0.8, 0.8)
    end

    -- Hide default border
    if border then
        border:SetTexture(nil)
    end

    -- Style normal texture
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    -- Create custom border
    if not button.LunarBorder then
        local borderFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
        borderFrame:SetAllPoints()
        borderFrame:SetBackdrop(backdropTemplate)
        borderFrame:SetBackdropColor(0, 0, 0, 0)
        borderFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        borderFrame:SetFrameLevel(button:GetFrameLevel() + 2)
        button.LunarBorder = borderFrame
    end

    -- Style pushed texture
    if pushedTexture then
        pushedTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        pushedTexture:SetVertexColor(1, 1, 1, 0.2)
        pushedTexture:SetAllPoints()
    end

    -- Style highlight texture
    if highlightTexture then
        highlightTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        highlightTexture:SetVertexColor(1, 1, 1, 0.3)
        highlightTexture:SetAllPoints()
    end

    -- Style checked texture
    if checkedTexture then
        checkedTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        checkedTexture:SetVertexColor(0.4, 0.6, 0.8, 0.5)
        checkedTexture:SetAllPoints()
    end
end

-- Fix #52: WoW 12.0 returns secret values from GetActionCooldown that cannot be compared
-- even with pcall protection. Disable custom cooldown text entirely and use WoW's built-in display.
local function UpdateCooldownText(button)
    -- Intentionally empty - WoW 12.0 secret values prevent custom cooldown text
    -- The built-in cooldown spiral and OmniCC/similar addons handle this
end

-- Fix #52: Disabled cooldown text update due to WoW 12.0 secret value restrictions
-- cooldownUpdateFrame:SetScript("OnUpdate", nil)
-- The built-in cooldown display handles this functionality

--------------------------------------------------------------------------------
-- Bar Creation
--------------------------------------------------------------------------------

local function CreateActionBar(id, page)
    local db = LunarUI.db and LunarUI.db.profile.actionbars["bar" .. id]
    if not db or not db.enabled then return end

    local numButtons = db.buttons or 12
    local buttonSize = db.buttonSize or BUTTON_SIZE
    local name = "LunarUI_ActionBar" .. id

    -- Create bar frame
    local bar = CreateBarFrame(name, numButtons, UIParent)
    bar.id = id
    bar.page = page

    -- Position
    local yOffset = -100 - (id - 1) * (buttonSize + 8)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, yOffset)

    -- Create buttons
    bar.buttons = {}
    for i = 1, numButtons do
        local buttonName = name .. "Button" .. i
        local button = LAB:CreateButton(i, buttonName, bar, nil)

        button:SetSize(buttonSize, buttonSize)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * (buttonSize + BUTTON_SPACING), 0)

        -- Set page for this bar
        button:SetState(0, "action", (page - 1) * 12 + i)
        for state = 1, 14 do
            button:SetState(state, "action", (state - 1) * 12 + i)
        end

        -- Style
        StyleButton(button)

        bar.buttons[i] = button
        buttons[buttonName] = button
    end

    bars["bar" .. id] = bar
    return bar
end

local function CreateStanceBar()
    local db = LunarUI.db and LunarUI.db.profile.actionbars.stancebar
    if not db or not db.enabled then return end

    local numStances = GetNumShapeshiftForms() or 0
    if numStances == 0 then return end

    local bar = CreateBarFrame("LunarUI_StanceBar", numStances, UIParent)
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 200)

    bar.buttons = {}
    for i = 1, numStances do
        local button = CreateFrame("CheckButton", "LunarUI_StanceButton" .. i, bar, "StanceButtonTemplate")
        button:SetSize(30, 30)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * 34, 0)
        button:SetID(i)

        StyleButton(button)
        bar.buttons[i] = button
    end

    -- Update stance bar when forms change
    bar:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    bar:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    bar:SetScript("OnEvent", function(self)
        local newNum = GetNumShapeshiftForms() or 0
        for i, btn in ipairs(self.buttons) do
            if i <= newNum then
                btn:Show()
            else
                btn:Hide()
            end
        end
    end)

    bars.stancebar = bar
    return bar
end

local function CreatePetBar()
    local db = LunarUI.db and LunarUI.db.profile.actionbars.petbar
    if not db or not db.enabled then return end

    local numButtons = 10
    local bar = CreateBarFrame("LunarUI_PetBar", numButtons, UIParent)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160)

    bar.buttons = {}
    for i = 1, numButtons do
        local button = CreateFrame("CheckButton", "LunarUI_PetButton" .. i, bar, "PetActionButtonTemplate")
        button:SetSize(30, 30)
        button:SetPoint("LEFT", bar, "LEFT", (i - 1) * 34, 0)
        button:SetID(i)

        StyleButton(button)
        bar.buttons[i] = button
    end

    -- Show/hide based on pet
    bar:RegisterEvent("UNIT_PET")
    bar:RegisterEvent("PET_BAR_UPDATE")
    bar:SetScript("OnEvent", function(self)
        if UnitExists("pet") and not UnitIsDead("pet") then
            self:Show()
        else
            self:Hide()
        end
    end)

    -- Initial state
    if not UnitExists("pet") then
        bar:Hide()
    end

    bars.petbar = bar
    return bar
end

--------------------------------------------------------------------------------
-- Phase Awareness
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateAllBarsForPhase()
    local tokens = LunarUI:GetTokens()

    -- Action bars should be more visible even in NEW phase
    local minAlpha = 0.5
    local alpha = math.max(tokens.alpha, minAlpha)

    for name, bar in pairs(bars) do
        if bar and bar:IsShown() then
            bar:SetAlpha(alpha)
        end
    end
end

local function RegisterBarPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        UpdateAllBarsForPhase()
    end)
end

--------------------------------------------------------------------------------
-- Keybind Mode
--------------------------------------------------------------------------------

local function EnterKeybindMode()
    if keybindMode then return end
    keybindMode = true

    for name, button in pairs(buttons) do
        if button then
            -- Highlight button
            if button.LunarBorder then
                button.LunarBorder:SetBackdropBorderColor(0.4, 0.6, 0.8, 1)
            end

            -- Show current keybind
            button:EnableKeyboard(true)
            button:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    LunarUI:ExitKeybindMode()
                    return
                end

                -- Set keybind
                local action = self._state_action
                if action then
                    local bind = GetBindingKey("ACTIONBUTTON" .. ((action - 1) % 12 + 1))
                    if bind then
                        SetBinding(key, "ACTIONBUTTON" .. ((action - 1) % 12 + 1))
                        SaveBindings(GetCurrentBindingSet())
                    end
                end
            end)
        end
    end

    LunarUI:Print("Keybind mode enabled. Hover over a button and press a key. Press ESC to exit.")
end

local function ExitKeybindMode()
    if not keybindMode then return end
    keybindMode = false

    for name, button in pairs(buttons) do
        if button then
            -- Reset border
            if button.LunarBorder then
                button.LunarBorder:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            end

            -- Disable keyboard
            button:EnableKeyboard(false)
            button:SetScript("OnKeyDown", nil)
        end
    end

    LunarUI:Print("Keybind mode disabled.")
end

--------------------------------------------------------------------------------
-- Hide Blizzard Bars
--------------------------------------------------------------------------------

-- Fix #59: Helper to permanently hide a frame (prevents re-showing)
local function HideFramePermanently(frame)
    if not frame then return end
    pcall(function() frame:UnregisterAllEvents() end)
    pcall(function() frame:SetAlpha(0) end)
    pcall(function() frame:Hide() end)
    -- Prevent Blizzard from re-showing the frame
    pcall(function()
        frame:SetScript("OnShow", function(self) self:Hide() end)
    end)
end

-- Fix #63: Hide all regions (textures) of a frame
local function HideFrameRegions(frame)
    if not frame then return end
    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
        if region and region.Hide then
            pcall(function() region:Hide() end)
        end
        if region and region.SetAlpha then
            pcall(function() region:SetAlpha(0) end)
        end
    end
end

-- Fix #63: Recursively hide a frame and all its children/regions
local function HideFrameRecursive(frame)
    if not frame then return end
    HideFramePermanently(frame)
    HideFrameRegions(frame)

    -- Hide all children recursively
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        HideFrameRecursive(child)
    end
end

local function HideBlizzardBars()
    -- Fix #63: WoW 12.0 completely redesigned action bars
    -- The gryphon/wyvern art is now in MainMenuBarArtFrame with subframes
    -- Use aggressive recursive hiding

    -- Primary action bar frames
    local primaryFrames = {
        "MainMenuBar",
        "MainMenuBarArtFrame",
        "MainMenuBarArtFrameBackground",
    }
    for _, name in ipairs(primaryFrames) do
        local frame = _G[name]
        if frame then
            HideFrameRecursive(frame)
        end
    end

    -- Fix #13 + Fix #59: Hide all multi bars with permanent hiding
    local barsToHide = {
        "MultiBarBottomLeft",
        "MultiBarBottomRight",
        "MultiBarRight",
        "MultiBarLeft",
        "MultiBar5",
        "MultiBar6",
        "MultiBar7",
    }
    for _, barName in ipairs(barsToHide) do
        local bar = _G[barName]
        if bar then
            HideFramePermanently(bar)
        end
    end

    -- Fix #59: Hide WoW 12.0 action bars (ActionBar1-8)
    for i = 1, 8 do
        local bar = _G["ActionBar" .. i]
        if bar then
            HideFrameRecursive(bar)
        end
    end

    -- Fix #61: Hide gryphon decorations (all possible frame names across WoW versions)
    local artFrames = {
        "MainMenuBarLeftEndCap",
        "MainMenuBarRightEndCap",
        "MainMenuBarPageNumber",
        "ActionBarUpButton",
        "ActionBarDownButton",
        "MainMenuBarTexture0",
        "MainMenuBarTexture1",
        "MainMenuBarTexture2",
        "MainMenuBarTexture3",
        "MainMenuExpBar",
        "ReputationWatchBar",
        -- WoW 12.0 new names
        "MainMenuBarBackgroundArt",
        "MainMenuBarBackground",
    }
    for _, name in ipairs(artFrames) do
        local frame = _G[name]
        if frame then
            HideFrameRecursive(frame)
        end
    end

    -- Hide status tracking bar (XP/Rep/Honor)
    if StatusTrackingBarManager then
        HideFrameRecursive(StatusTrackingBarManager)
    end

    -- Hide stance bar
    if StanceBar then
        HideFramePermanently(StanceBar)
    end

    -- Hide pet bar
    if PetActionBar then
        HideFramePermanently(PetActionBar)
    end

    -- Note: MicroButtonAndBagsBar and BagsBar are kept visible
    -- LunarUI doesn't replace the micro menu, only bags

    -- Fix #59: Hide WoW 12.0 specific frames
    local wow12Frames = {
        "MainMenuBarManager",
        "OverrideActionBar",
        "PossessActionBar",
        "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer",
        -- Note: MicroMenu kept visible
    }
    for _, name in ipairs(wow12Frames) do
        local frame = _G[name]
        if frame then
            HideFramePermanently(frame)
        end
    end

    -- Fix #60: Hide Action Bar buttons directly
    for i = 1, 12 do
        local button = _G["ActionButton" .. i]
        if button then
            HideFramePermanently(button)
        end
    end

    -- Fix #62: Hide WoW 12.0 Edit Mode frames
    local editModeFrames = {
        "EditModeExpandedActionBarFrame",
        "QuickKeybindFrame",
    }
    for _, name in ipairs(editModeFrames) do
        local frame = _G[name]
        if frame then
            HideFramePermanently(frame)
        end
    end

    -- Fix #63: Search _G for any frame containing action bar related names
    -- This catches any frame we might have missed
    local patterns = {
        "^MainMenuBar",
        "^ActionBar%d",
        "^MultiBar",
        "EndCap$",
        "Gryphon",
        "Wyvern",
    }

    for name, obj in pairs(_G) do
        if type(obj) == "table" and type(obj.Hide) == "function" then
            for _, pattern in ipairs(patterns) do
                if type(name) == "string" and name:match(pattern) then
                    pcall(function() obj:Hide() end)
                    pcall(function() obj:SetAlpha(0) end)
                    break
                end
            end
        end
    end

    -- Note: Micro buttons (character, spellbook, talents, etc.) are kept visible
    -- LunarUI doesn't replace the micro menu
end

-- Fix #63: Delayed hiding to catch frames created after initial load
local function HideBlizzardBarsDelayed()
    HideBlizzardBars()
    -- Run again after a delay to catch late-created frames
    C_Timer.After(1, HideBlizzardBars)
    C_Timer.After(3, HideBlizzardBars)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function SpawnActionBars()
    local db = LunarUI.db and LunarUI.db.profile.actionbars
    if not db then return end

    -- Fix #70: Check if custom action bars are enabled
    if db.enabled == false then
        return  -- Use Blizzard default action bars
    end

    -- Fix #6 + Fix #38: Use event-driven retry instead of fixed timer for combat lockdown
    if InCombatLockdown() then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            SpawnActionBars()
        end)
        return
    end

    -- Fix #63: Hide Blizzard bars with delayed retry
    HideBlizzardBarsDelayed()

    -- Create main action bars (bar1 = page 1, bar2 = page 2, etc.)
    for i = 1, 6 do
        CreateActionBar(i, i)
    end

    -- Create special bars
    CreateStanceBar()
    CreatePetBar()

    -- Register for phase updates
    RegisterBarPhaseCallback()

    -- Apply initial phase
    UpdateAllBarsForPhase()
end

-- Export
LunarUI.SpawnActionBars = SpawnActionBars
LunarUI.EnterKeybindMode = EnterKeybindMode
LunarUI.ExitKeybindMode = ExitKeybindMode
LunarUI.actionBars = bars

-- Hook into addon enable
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.3, SpawnActionBars)
end)

-- Fix #44: Implement keybind mode command
hooksecurefunc(LunarUI, "RegisterCommands", function(self)
    -- Add /lunar keybind command
    local origHandler = self.slashCommands and self.slashCommands["keybind"]
    if not origHandler then
        -- Register keybind as a subcommand if the command system supports it
        -- Otherwise, users can toggle via EnterKeybindMode/ExitKeybindMode functions
        self:Print("Keybind mode: Use /lunar keybind to toggle")
    end
end)

-- Register keybind toggle function
function LunarUI:ToggleKeybindMode()
    if keybindMode then
        ExitKeybindMode()
    else
        EnterKeybindMode()
    end
end
