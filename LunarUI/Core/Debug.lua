--[[
    LunarUI - Debug Overlay
    Visual debug information showing current phase and tokens
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local debugFrame = nil
local updateInterval = 0.1
local elapsed = 0

-- Moon phase icons (ASCII representation for debug)
local PHASE_ICONS = {
    NEW = "|cff333333\226\151\143|r",      -- Dark circle
    WAXING = "|cff888888\226\151\144|r",   -- Half moon
    FULL = "|cffffff00\226\151\143|r",     -- Bright circle
    WANING = "|cff666666\226\151\145|r",   -- Half moon (other side)
}

--[[
    Create the debug overlay frame
    Fix #31: Check for existing named frame on reload to prevent leaks
]]
local function CreateDebugFrame()
    -- Fix #31: Reuse existing frame if it survived a reload
    if debugFrame then return debugFrame end

    -- Check if frame exists from previous session (reload scenario)
    local existingFrame = _G["LunarUIDebugFrame"]
    if existingFrame then
        debugFrame = existingFrame
        -- Clear old OnUpdate to prevent duplicates
        debugFrame:SetScript("OnUpdate", nil)
    else
        debugFrame = CreateFrame("Frame", "LunarUIDebugFrame", UIParent, "BackdropTemplate")
    end
    debugFrame:SetSize(200, 120)
    debugFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -200)
    debugFrame:SetFrameStrata("HIGH")
    debugFrame:SetMovable(true)
    debugFrame:EnableMouse(true)
    debugFrame:RegisterForDrag("LeftButton")
    debugFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    debugFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Backdrop
    debugFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    debugFrame:SetBackdropColor(0, 0, 0, 0.8)
    debugFrame:SetBackdropBorderColor(0.5, 0.4, 0.8, 1)

    -- Title
    local title = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
    title:SetText("|cff8882ffLunarUI Debug|r")
    debugFrame.title = title

    -- Phase display
    local phaseText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    phaseText:SetPoint("TOPLEFT", 10, -25)
    debugFrame.phaseText = phaseText

    -- Tokens display
    local tokensText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tokensText:SetPoint("TOPLEFT", 10, -45)
    debugFrame.tokensText = tokensText

    -- Timer display
    local timerText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("TOPLEFT", 10, -75)
    debugFrame.timerText = timerText

    -- Combat status
    local combatText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    combatText:SetPoint("TOPLEFT", 10, -95)
    debugFrame.combatText = combatText

    -- Update script
    debugFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < updateInterval then return end
        elapsed = 0

        if not LunarUI.db or not LunarUI.db.profile.debug then
            self:Hide()
            return
        end

        local phase = LunarUI:GetPhase()
        local tokens = LunarUI:GetTokens()
        local icon = PHASE_ICONS[phase] or "?"

        -- Update phase
        self.phaseText:SetText("Phase: " .. icon .. " |cff8882ff" .. phase .. "|r")

        -- Update tokens
        self.tokensText:SetText(string.format(
            "Alpha: %.2f  Scale: %.2f",
            tokens.alpha or 0,
            tokens.scale or 0
        ))

        -- Update timer
        if phase == LunarUI.PHASES.WANING then
            local remaining = LunarUI:GetWaningTimeRemaining()
            self.timerText:SetText(string.format("Waning: %.1fs remaining", remaining))
            self.timerText:SetTextColor(1, 0.8, 0.3)
        else
            self.timerText:SetText("Timer: idle")
            self.timerText:SetTextColor(0.5, 0.5, 0.5)
        end

        -- Update combat status
        if InCombatLockdown() then
            self.combatText:SetText("Combat: |cffff0000IN COMBAT|r")
        else
            self.combatText:SetText("Combat: |cff00ff00Safe|r")
        end
    end)

    return debugFrame
end

--[[
    Update debug overlay visibility
]]
function LunarUI:UpdateDebugOverlay()
    if not debugFrame then
        debugFrame = CreateDebugFrame()
    end

    if self.db and self.db.profile.debug then
        debugFrame:Show()
    else
        debugFrame:Hide()
    end
end

--[[
    Show debug overlay
]]
function LunarUI:ShowDebugOverlay()
    if not debugFrame then
        debugFrame = CreateDebugFrame()
    end
    debugFrame:Show()
end

--[[
    Hide debug overlay
    Fix #31: Clean up OnUpdate script when hiding
]]
function LunarUI:HideDebugOverlay()
    if debugFrame then
        debugFrame:SetScript("OnUpdate", nil)
        debugFrame:Hide()
    end
end
