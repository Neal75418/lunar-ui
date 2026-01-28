--[[
    LunarUI - Phase-driven combat UI system
    Core initialization using Ace3 framework
]]

local ADDON_NAME, Engine = ...

-- Create Ace3 addon
local LunarUI = LibStub("AceAddon-3.0"):NewAddon(
    ADDON_NAME,
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceTimer-3.0",
    "AceHook-3.0"
)

if not LunarUI then
    print("|cffff0000[LunarUI] ERROR:|r Failed to create addon!")
    return
end

print("|cff8882ff[LunarUI]|r Addon created successfully")

-- Export to global and engine
_G.LunarUI = LunarUI
Engine.LunarUI = LunarUI

-- Addon info
LunarUI.name = ADDON_NAME
LunarUI.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

-- Phase constants
LunarUI.PHASES = {
    NEW = "NEW",         -- Non-combat, minimal presence
    WAXING = "WAXING",   -- Preparing for combat
    FULL = "FULL",       -- In combat, maximum clarity
    WANING = "WANING",   -- Post-combat, fading out
}

-- oUF reference (will be set after oUF loads)
LunarUI.oUF = nil

-- Callbacks for phase changes
LunarUI.phaseCallbacks = {}

--[[
    Ace3 Lifecycle: OnInitialize
    Called when addon is loaded
]]
function LunarUI:OnInitialize()
    -- Initialize database directly (Fix #2: remove hooksecurefunc race condition)
    if self.InitDB then
        self:InitDB()
    end

    self:Print("|cff8882ffLunar|r|cffffffffUI|r v" .. self.version .. " loaded")
end

--[[
    Ace3 Lifecycle: OnEnable
    Called when addon is enabled
]]
function LunarUI:OnEnable()
    -- Get oUF reference (X-oUF: LunarUF in TOC)
    self.oUF = Engine.oUF or _G.LunarUF or _G.oUF

    -- Initialize phase manager
    if self.InitPhaseManager then
        self:InitPhaseManager()
    end

    -- Register slash commands
    if self.RegisterCommands then
        self:RegisterCommands()
    end

    self:Print("Enabled. Use |cff8882ff/lunar|r for commands.")
end

--[[
    Ace3 Lifecycle: OnDisable
    Called when addon is disabled
]]
function LunarUI:OnDisable()
    -- Unregister combat events (Fix #3: prevent memory leak)
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")

    -- Cancel all timers
    self:CancelAllTimers()

    -- Clear phase callbacks
    if self.phaseCallbacks then
        wipe(self.phaseCallbacks)
    end

    -- Hide debug overlay
    if self.HideDebugOverlay then
        self:HideDebugOverlay()
    end

    -- Cleanup minimap
    if self.CleanupMinimap then
        self:CleanupMinimap()
    end

    -- Cleanup phase indicator
    if self.CleanupPhaseIndicator then
        self:CleanupPhaseIndicator()
    end

    -- Fix #35: Cleanup nameplates event handlers
    if self.CleanupNameplates then
        self:CleanupNameplates()
    end

    -- Fix #36: Stop phase glow animations
    if self.StopGlowAnimation then
        self:StopGlowAnimation()
    end
end

--[[
    Register a callback for phase changes
    @param callback function(oldPhase, newPhase)
]]
function LunarUI:RegisterPhaseCallback(callback)
    if type(callback) == "function" then
        table.insert(self.phaseCallbacks, callback)
    end
end

--[[
    Notify all registered callbacks of phase change
]]
function LunarUI:NotifyPhaseChange(oldPhase, newPhase)
    for _, callback in ipairs(self.phaseCallbacks) do
        pcall(callback, oldPhase, newPhase)
    end
end
