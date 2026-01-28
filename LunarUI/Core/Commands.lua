--[[
    LunarUI - Slash Commands
    /lunar command implementation
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--[[
    Register slash commands
    Called from OnEnable
]]
function LunarUI:RegisterCommands()
    self:RegisterChatCommand("lunar", "SlashCommand")
    self:RegisterChatCommand("lui", "SlashCommand")
end

--[[
    Handle slash command
    @param input string - Command arguments
]]
function LunarUI:SlashCommand(input)
    local args = {}
    for word in input:gmatch("%S+") do
        table.insert(args, word:lower())
    end

    local cmd = args[1]

    if not cmd or cmd == "help" then
        self:PrintHelp()

    elseif cmd == "toggle" or cmd == "on" or cmd == "off" then
        self:ToggleAddon(cmd)

    elseif cmd == "phase" then
        local phase = args[2]
        if phase then
            self:SetPhase(phase:upper())
        else
            self:Print("Current phase: |cff8882ff" .. self:GetPhase() .. "|r")
        end

    elseif cmd == "waxing" then
        self:ToggleWaxing()
        self:Print("Toggled WAXING. Current phase: |cff8882ff" .. self:GetPhase() .. "|r")

    elseif cmd == "debug" then
        self:ToggleDebug()

    elseif cmd == "status" then
        self:PrintStatus()

    elseif cmd == "config" or cmd == "options" then
        self:OpenOptions()

    elseif cmd == "reset" then
        self:ResetPosition()

    elseif cmd == "test" then
        self:RunTest(args[2])

    elseif cmd == "keybind" then
        -- Fix #44: Add keybind mode command
        if self.ToggleKeybindMode then
            self:ToggleKeybindMode()
        else
            self:Print("Keybind mode not available")
        end

    elseif cmd == "export" then
        -- Fix #45: Export settings
        if self.ShowExportFrame then
            self:ShowExportFrame()
        else
            self:Print("Export not available")
        end

    elseif cmd == "import" then
        -- Fix #45: Import settings
        if self.ShowImportFrame then
            self:ShowImportFrame()
        else
            self:Print("Import not available")
        end

    else
        self:Print("Unknown command: " .. cmd)
        self:PrintHelp()
    end
end

--[[
    Print help message
]]
function LunarUI:PrintHelp()
    self:Print("|cff8882ffLunarUI Commands:|r")
    print("  |cffffd100/lunar|r - Show this help")
    print("  |cffffd100/lunar toggle|r - Enable/disable addon")
    print("  |cffffd100/lunar phase [NEW|WAXING|FULL|WANING]|r - Show/set current phase")
    print("  |cffffd100/lunar waxing|r - Toggle WAXING phase (pre-combat prep)")
    print("  |cffffd100/lunar debug|r - Toggle debug mode")
    print("  |cffffd100/lunar status|r - Show current status")
    print("  |cffffd100/lunar config|r - Open configuration panel")
    print("  |cffffd100/lunar keybind|r - Toggle keybind edit mode")
    print("  |cffffd100/lunar export|r - Export settings to string")
    print("  |cffffd100/lunar import|r - Import settings from string")
    print("  |cffffd100/lunar reset|r - Reset frame positions")
    print("  |cffffd100/lunar test [combat]|r - Run test scenarios")
end

--[[
    Toggle addon on/off
]]
function LunarUI:ToggleAddon(cmd)
    if cmd == "on" then
        self.db.profile.enabled = true
        self:Print("Enabled")
    elseif cmd == "off" then
        self.db.profile.enabled = false
        self:Print("Disabled")
    else
        self.db.profile.enabled = not self.db.profile.enabled
        self:Print(self.db.profile.enabled and "Enabled" or "Disabled")
    end
end

--[[
    Toggle debug mode
]]
function LunarUI:ToggleDebug()
    self.db.profile.debug = not self.db.profile.debug
    self:Print("Debug mode: " .. (self.db.profile.debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))

    -- Show/hide debug overlay
    if self.UpdateDebugOverlay then
        self:UpdateDebugOverlay()
    end
end

--[[
    Print current status
]]
function LunarUI:PrintStatus()
    self:Print("|cff8882ffLunarUI Status:|r")
    print("  Version: " .. self.version)
    print("  Enabled: " .. (self.db.profile.enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print("  Debug: " .. (self.db.profile.debug and "|cff00ff00ON|r" or "|cffff0000OFF|r"))
    print("  Current Phase: |cff8882ff" .. self:GetPhase() .. "|r")

    local tokens = self:GetTokens()
    print("  Alpha: " .. string.format("%.2f", tokens.alpha))
    print("  Scale: " .. string.format("%.2f", tokens.scale))

    if self:GetPhase() == self.PHASES.WANING then
        local remaining = self:GetWaningTimeRemaining()
        print("  Waning Timer: " .. string.format("%.1fs", remaining) .. " remaining")
    end
end

--[[
    Open options panel
]]
function LunarUI:OpenOptions()
    -- Load options addon if not loaded
    local loaded = C_AddOns.IsAddOnLoaded("LunarUI_Options")
    if not loaded then
        local success = C_AddOns.LoadAddOn("LunarUI_Options")
        if not success then
            self:Print("Options panel not available yet. Coming soon!")
            return
        end
    end

    -- Open settings (Fix #17: add error handling for Settings API)
    if not Settings or type(Settings.OpenToCategory) ~= "function" then
        self:Print("Settings API not available")
        return
    end

    local ok, err = pcall(Settings.OpenToCategory, "LunarUI")
    if not ok then
        self:Print("Failed to open settings: " .. tostring(err))
    end
end

--[[
    Reset frame positions
]]
function LunarUI:ResetPosition()
    -- Reset to default positions
    if self.db then
        -- Reset unitframe positions to defaults
        for unit, data in pairs(self.db.defaults.profile.unitframes) do
            if self.db.profile.unitframes[unit] then
                self.db.profile.unitframes[unit].x = data.x
                self.db.profile.unitframes[unit].y = data.y
                self.db.profile.unitframes[unit].point = data.point
            end
        end
    end

    self:Print("Frame positions reset to default")

    -- Trigger UI refresh
    self:NotifyPhaseChange(self:GetPhase(), self:GetPhase())
end

--[[
    Run test scenarios
]]
function LunarUI:RunTest(scenario)
    if scenario == "combat" then
        self:Print("Simulating combat cycle...")
        -- Simulate entering combat
        self:SetPhase(self.PHASES.FULL)
        self:Print("  -> FULL (combat)")

        -- After 3 seconds, exit combat
        self:ScheduleTimer(function()
            self:SetPhase(self.PHASES.WANING)
            self:Print("  -> WANING (post-combat)")
            self:StartWaningTimer()
        end, 3)

    elseif scenario == "phases" then
        self:Print("Cycling through all phases...")
        local phases = { "NEW", "WAXING", "FULL", "WANING" }
        for i, phase in ipairs(phases) do
            self:ScheduleTimer(function()
                self:SetPhase(phase)
                self:Print("  -> " .. phase)
            end, (i - 1) * 2)
        end

    else
        self:Print("Available tests:")
        print("  |cffffd100/lunar test combat|r - Simulate combat cycle")
        print("  |cffffd100/lunar test phases|r - Cycle through all phases")
    end
end
