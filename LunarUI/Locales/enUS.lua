---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - English (US) Localization
]]

local _ADDON_NAME, Engine = ...
local L = {}

-- General
L["Enabled"] = "Enabled"
L["Disabled"] = "Disabled"
L["Debug"] = "Debug"
L["Yes"] = "Yes"
L["No"] = "No"
L["On"] = "ON"
L["Off"] = "OFF"

-- Phases
L["Phase"] = "Phase"
L["NEW"] = "New Moon"
L["WAXING"] = "Waxing"
L["FULL"] = "Full Moon"
L["WANING"] = "Waning"

-- Commands
L["Commands"] = "Commands"
L["Help"] = "Help"
L["Toggle"] = "Toggle"
L["Status"] = "Status"
L["Config"] = "Config"
L["Reset"] = "Reset"

-- UnitFrames
L["Player"] = "Player"
L["Target"] = "Target"
L["Focus"] = "Focus"
L["Pet"] = "Pet"
L["Party"] = "Party"
L["Raid"] = "Raid"
L["Boss"] = "Boss"

-- Settings
L["General"] = "General"
L["UnitFrames"] = "Unit Frames"
L["ActionBars"] = "Action Bars"
L["Minimap"] = "Minimap"
L["Bags"] = "Bags"
L["Chat"] = "Chat"
L["Tooltip"] = "Tooltip"

-- System Messages
L["AddonLoaded"] = "Addon loaded"
L["AddonEnabled"] = "Enabled. Type |cff8882ff/lunar|r for commands"
L["DebugEnabled"] = "Debug mode: ON"
L["DebugDisabled"] = "Debug mode: OFF"

-- Command Messages
L["HelpTitle"] = "LunarUI Commands:"
L["CmdToggle"] = "Toggle addon on/off"
L["CmdStatus"] = "Show current status"
L["CmdConfig"] = "Open settings"
L["CmdDebug"] = "Toggle debug mode"
L["CmdReset"] = "Reset to defaults"
L["CmdTest"] = "Run combat simulation"

-- Phase Messages
L["PhaseChanged"] = "Phase: %s → %s"
L["CurrentPhase"] = "Current phase: %s"
L["CombatEnter"] = "Entering combat"
L["CombatLeave"] = "Leaving combat"

-- Keybind Messages
L["KeybindEnabled"] = "Keybind mode: Hover over a button and press a key to bind"
L["KeybindDisabled"] = "Keybind mode: Disabled"
L["KeybindSet"] = "Bound %s to %s"
L["KeybindCleared"] = "Cleared binding for %s"

-- Bags
L["SoldJunkItems"] = "Sold %d junk items for %s"
L["BagSearchError"] = "Bag search error"
L["BankSearchError"] = "Bank search error"

-- Chat
L["PressToCopyURL"] = "Press Ctrl+C to copy URL:"
L["KeywordAlert"] = "Keyword Alert"
L["SpamFiltered"] = "Spam message filtered"

-- Config
L["SettingsImported"] = "Settings imported successfully"
L["SettingsExported"] = "Settings exported to clipboard"
L["InvalidSettings"] = "Invalid settings format"

-- Errors
L["ErrorOUFNotFound"] = "Error: oUF framework not found"
L["ErrorAddonInit"] = "Error: Failed to initialize addon"

-- Export
Engine.L = L
