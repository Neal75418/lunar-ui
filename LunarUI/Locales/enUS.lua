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
L["BagTitle"] = "Bags"
L["BankTitle"] = "Bank"
L["ReagentBank"] = "Reagent"
L["Sort"] = "Sort"
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

-- Auras
L["Auras"] = "Auras"
L["UnitFrameAuras"] = "Unit Frame Auras"
L["Buffs"] = "Buffs"
L["Debuffs"] = "Debuffs"
L["ShowBuffs"] = "Show Buffs"
L["ShowDebuffs"] = "Show Debuffs"
L["OnlyPlayerDebuffs"] = "Only Player Debuffs"
L["AuraSize"] = "Aura Icon Size"
L["PlayerBuffs"] = "Player Buffs"
L["PlayerBuffsDesc"] = "Show buffs beside player frame (requires reload)"
L["TargetDebuffs"] = "Target Debuffs"
L["TargetDebuffsDesc"] = "Show debuffs above target frame (requires reload)"
L["OnlyPlayerDebuffsDesc"] = "Only show debuffs cast by you on target (requires reload)"
L["AuraSizeDesc"] = "Buff/debuff icon size (requires reload)"
L["FocusDebuffs"] = "Focus Debuffs"
L["FocusDebuffsDesc"] = "Show debuffs above focus frame (requires reload)"
L["PartyDebuffs"] = "Party Debuffs"
L["PartyDebuffsDesc"] = "Show debuffs above party frames (requires reload)"

-- Nameplates
L["Nameplates"] = "Enable Nameplates"
L["NameplatesDesc"] = "Use LunarUI custom nameplates (requires reload)"
L["NPHealthText"] = "Health Text"
L["NPHealthTextDesc"] = "Show health text on nameplates (requires reload)"
L["NPHealthTextFormat"] = "Health Text Format"
L["NPHealthTextFormatDesc"] = "Format for health text display (requires reload)"
L["Percent"] = "Percent"
L["Current"] = "Current"
L["Both"] = "Both"
L["NPEnemyBuffs"] = "Enemy Buffs"
L["NPEnemyBuffsDesc"] = "Show stealable buffs on enemy nameplates (requires reload)"

-- DataBars
L["DataBars"] = "Data Bars"
L["DataBarsDesc"] = "Experience, reputation, and honor progress bars"
L["Experience"] = "Experience"
L["Reputation"] = "Reputation"
L["Honor"] = "Honor"
L["HonorLevel"] = "Honor Level"
L["Standing"] = "Standing"
L["Remaining"] = "Remaining"
L["Rested"] = "Rested"
L["ShowText"] = "Show Text"
L["TextFormat"] = "Text Format"
L["BarWidth"] = "Bar Width"
L["BarHeight"] = "Bar Height"

-- DataTexts
L["DataTexts"] = "Data Texts"
L["DataTextsDesc"] = "Configurable info panels (FPS, latency, gold, durability, etc.)"
L["DTBottomPanel"] = "Bottom Panel"
L["DTBottomPanelDesc"] = "Show data text panel at bottom of screen (requires reload)"
L["DTSlot"] = "Slot"
L["Latency"] = "Latency"
L["Gold"] = "Gold"
L["Durability"] = "Durability"
L["BagSlots"] = "Bag Slots"
L["Friends"] = "Friends"
L["Guild"] = "Guild"
L["Spec"] = "Specialization"
L["Clock"] = "Clock"
L["Coords"] = "Coordinates"
L["Online"] = "online"
L["LocalTime"] = "Local"
L["ServerTime"] = "Server"
L["Backpack"] = "Backpack"
L["Zone"] = "Zone"

-- Chat & Tooltip enhancements
L["Timestamps"] = "Timestamps"
L["TimestampsDesc"] = "Show timestamps before chat messages (requires reload)"
L["TimestampFormat"] = "Timestamp Format"
L["ItemCount"] = "Item Count"
L["ItemCountDesc"] = "Show item count (bags/bank) in tooltips"
L["BankTitle"] = "Bank"

-- UnitFrame enhancements
L["ClassPower"] = "Class Power"
L["ClassPowerDesc"] = "Show class resource bar above player frame (combo points, holy power, runes, etc.) (requires reload)"
L["HealPrediction"] = "Heal Prediction"
L["HealPredictionDesc"] = "Show incoming heal prediction overlay on health bars (requires reload)"

-- ActionBars
L["OutOfRange"] = "Out of Range Coloring"
L["OutOfRangeDesc"] = "Color buttons red when the target is out of range (requires reload)"
L["ExtraActionButton"] = "Extra Action Button"
L["ExtraActionButtonDesc"] = "Style the Extra Action Button with LunarUI theme (requires reload)"
L["MicroBar"] = "Micro Bar"
L["MicroBarDesc"] = "Rearrange system micro buttons into a compact bar (requires reload)"
L["NameplateLevel"] = "Level Text"
L["NameplateLevelDesc"] = "Show level text next to name on nameplates (requires reload)"
L["StackingDetection"] = "Stacking Detection"
L["StackingDetectionDesc"] = "Offset overlapping nameplates so they don't cover each other (requires reload)"
L["QuestIcon"] = "Quest Icon"
L["QuestIconDesc"] = "Show quest objective icon on enemy nameplates (requires reload)"

-- Skins
L["Skins"] = "Skins"
L["SkinsDesc"] = "Restyle Blizzard UI frames to match LunarUI theme (requires reload)"

-- Profile
L["ProfileChanged"] = "Profile changed, UI refreshed"

-- Errors
L["ErrorOUFNotFound"] = "Error: oUF framework not found"
L["ErrorAddonInit"] = "Error: Failed to initialize addon"

-- Export
Engine.L = L
