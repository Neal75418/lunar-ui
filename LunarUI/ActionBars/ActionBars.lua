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

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function CreateBarFrame(name, numButtons, parent)
    local frame = CreateFrame("Frame", name, parent or UIParent)
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

local function UpdateCooldownText(button)
    if not button then return end

    -- Create cooldown text if not exists
    if not button.CooldownText then
        local text = button.cooldown:CreateFontString(nil, "OVERLAY")
        text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        text:SetPoint("CENTER", 0, 0)
        text:SetTextColor(1, 1, 0.6)
        button.CooldownText = text
    end

    -- Update text based on cooldown
    local start, duration, enable = GetActionCooldown(button._state_action)
    if start and duration and duration > 1.5 and enable == 1 then
        local remaining = start + duration - GetTime()
        if remaining > 0 then
            if remaining > 60 then
                button.CooldownText:SetText(math.floor(remaining / 60) .. "m")
            elseif remaining > 3 then
                button.CooldownText:SetText(math.floor(remaining))
            else
                button.CooldownText:SetFormattedText("%.1f", remaining)
            end
            button.CooldownText:Show()
        else
            button.CooldownText:Hide()
        end
    else
        if button.CooldownText then
            button.CooldownText:Hide()
        end
    end
end

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

        -- Cooldown text update
        button:HookScript("OnUpdate", function(self, elapsed)
            self._cdElapsed = (self._cdElapsed or 0) + elapsed
            if self._cdElapsed > 0.1 then
                self._cdElapsed = 0
                UpdateCooldownText(self)
            end
        end)

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

local function HideBlizzardBars()
    -- Hide main menu bar
    if MainMenuBar then
        MainMenuBar:SetAlpha(0)
        MainMenuBar:UnregisterAllEvents()
        MainMenuBar:Hide()
    end

    -- Hide action bars
    for i = 1, 8 do
        local bar = _G["MultiBarBottomLeft"]
        if bar then bar:Hide() end
        bar = _G["MultiBarBottomRight"]
        if bar then bar:Hide() end
        bar = _G["MultiBarRight"]
        if bar then bar:Hide() end
        bar = _G["MultiBarLeft"]
        if bar then bar:Hide() end
    end

    -- Hide stance bar
    if StanceBar then
        StanceBar:Hide()
    end

    -- Hide pet bar
    if PetActionBar then
        PetActionBar:Hide()
    end

    -- Hide micro buttons
    if MicroButtonAndBagsBar then
        MicroButtonAndBagsBar:Hide()
    end

    -- Hide bags bar
    if BagsBar then
        BagsBar:Hide()
    end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local function SpawnActionBars()
    local db = LunarUI.db and LunarUI.db.profile.actionbars
    if not db then return end

    -- Hide Blizzard bars first
    HideBlizzardBars()

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

-- Add keybind command
hooksecurefunc(LunarUI, "RegisterCommands", function(self)
    -- Add /lunar keybind command
end)
