--[[
    LunarUI - Phase Manager
    The core state machine that drives the entire UI behavior

    Phases:
    - NEW: Non-combat, minimal UI presence (like new moon)
    - WAXING: Preparing for combat (optional, manual trigger)
    - FULL: In combat, maximum clarity (like full moon)
    - WANING: Post-combat, graceful fadeout before returning to NEW
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- Current phase state
local currentPhase = LunarUI.PHASES.NEW
local waningTimer = nil
local transitionTimer = nil

-- Configuration
local WANING_DURATION = 10 -- seconds before returning to NEW

--[[
    Initialize the Phase Manager
    Called from OnEnable
]]
function LunarUI:InitPhaseManager()
    -- Determine initial phase based on combat state
    if InCombatLockdown() then
        currentPhase = self.PHASES.FULL
    else
        currentPhase = self.PHASES.NEW
    end

    -- Update tokens for initial phase
    self:UpdateTokens()

    -- Register combat events
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")

    -- Debug output
    if self.db and self.db.profile.debug then
        self:Print("PhaseManager initialized. Current phase: " .. currentPhase)
    end
end

--[[
    Get current phase
    @return string - Current phase name
]]
function LunarUI:GetPhase()
    return currentPhase
end

--[[
    Set phase manually (for debug/testing or WAXING trigger)
    @param newPhase string - Phase to set
    @param skipTransition boolean - Skip smooth transition
]]
function LunarUI:SetPhase(newPhase, skipTransition)
    if not self.PHASES[newPhase] then
        self:Print("Invalid phase: " .. tostring(newPhase))
        return
    end

    local oldPhase = currentPhase

    -- Cancel any pending timers
    self:CancelWaningTimer()
    self:CancelTransitionTimer()

    -- Set new phase
    currentPhase = newPhase

    -- Update tokens
    self:UpdateTokens()

    -- Notify listeners
    self:NotifyPhaseChange(oldPhase, newPhase)

    -- Debug output
    if self.db and self.db.profile.debug then
        self:Print("Phase: " .. oldPhase .. " -> " .. newPhase)
    end
end

--[[
    Event: Enter Combat
    PLAYER_REGEN_DISABLED fires when entering combat
]]
function LunarUI:OnEnterCombat()
    -- Cancel waning timer if re-entering combat
    self:CancelWaningTimer()

    -- Immediately go to FULL phase
    self:SetPhase(self.PHASES.FULL)
end

--[[
    Event: Leave Combat
    PLAYER_REGEN_ENABLED fires when leaving combat
]]
function LunarUI:OnLeaveCombat()
    -- Go to WANING phase
    self:SetPhase(self.PHASES.WANING)

    -- Start timer to return to NEW
    self:StartWaningTimer()
end

--[[
    Start the waning timer
    After WANING_DURATION seconds, transition to NEW
]]
function LunarUI:StartWaningTimer()
    self:CancelWaningTimer()

    local duration = self.db and self.db.profile.waningDuration or WANING_DURATION

    waningTimer = self:ScheduleTimer(function()
        -- Only transition if still in WANING
        if currentPhase == self.PHASES.WANING then
            self:SetPhase(self.PHASES.NEW)
        end
        waningTimer = nil
    end, duration)

    -- Debug output
    if self.db and self.db.profile.debug then
        self:Print("Waning timer started: " .. duration .. "s")
    end
end

--[[
    Cancel the waning timer
]]
function LunarUI:CancelWaningTimer()
    if waningTimer then
        self:CancelTimer(waningTimer)
        waningTimer = nil
    end
end

--[[
    Cancel the transition timer
]]
function LunarUI:CancelTransitionTimer()
    if transitionTimer then
        self:CancelTimer(transitionTimer)
        transitionTimer = nil
    end
end

--[[
    Get remaining waning time
    @return number - Seconds remaining, or 0 if not in waning
]]
function LunarUI:GetWaningTimeRemaining()
    if currentPhase ~= self.PHASES.WANING or not waningTimer then
        return 0
    end
    return self:TimeLeft(waningTimer) or 0
end

--[[
    Check if currently in combat phase (FULL)
]]
function LunarUI:IsInCombat()
    return currentPhase == self.PHASES.FULL
end

--[[
    Check if UI should be fully visible
]]
function LunarUI:ShouldShowFull()
    return currentPhase == self.PHASES.FULL or currentPhase == self.PHASES.WAXING
end

--[[
    Toggle WAXING phase manually
    Useful for preparing before a pull
]]
function LunarUI:ToggleWaxing()
    if currentPhase == self.PHASES.NEW then
        self:SetPhase(self.PHASES.WAXING)
    elseif currentPhase == self.PHASES.WAXING then
        self:SetPhase(self.PHASES.NEW)
    end
    -- Do nothing if in FULL or WANING
end
