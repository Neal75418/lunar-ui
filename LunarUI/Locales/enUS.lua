---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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
L["CmdHelp"] = "Show this help"
L["CmdToggle"] = "Toggle addon on/off"
L["CmdStatus"] = "Show current status"
L["CmdConfig"] = "Open settings"
L["CmdDebug"] = "Toggle debug mode"
L["CmdKeybind"] = "Toggle keybind edit mode"
L["CmdExport"] = "Export settings"
L["CmdImport"] = "Import settings"
L["CmdInstall"] = "Re-run install wizard"
L["CmdMove"] = "Toggle frame mover"
L["CmdReset"] = "Reset frame positions"
L["CmdTest"] = "Run test"
L["UnknownCommand"] = "Unknown command: %s"
L["InstallWizardUnavailable"] = "Install wizard unavailable"
L["KeybindModeUnavailable"] = "Keybind mode unavailable"
L["ExportUnavailable"] = "Export unavailable"
L["ImportUnavailable"] = "Import unavailable"
L["OpenOptionsHint"] = "Open ESC > Options > AddOns to find LunarUI"
L["PositionReset"] = "Frame positions reset to defaults"
L["StatusTitle"] = "|cff8882ffLunarUI Status:|r"
L["StatusVersion"] = "Version: %s"
L["StatusEnabled"] = "Enabled: %s"
L["StatusDebug"] = "Debug: %s"
L["TestMode"] = "Test mode: %s"
L["AvailableTests"] = "Available tests:"
L["CmdTestDesc"] = "Show test help"

-- Combat Messages
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

-- Tooltip extras
L["TooltipSpec"] = "Spec:"
L["TooltipILvl"] = "iLvl:"
L["TooltipTarget"] = "Target:"
L["TooltipRole"] = "Role:"
L["TooltipItemLevel"] = "Item Level:"
L["RoleTank"] = "Tank"
L["RoleHealer"] = "Healer"
L["RoleDPS"] = "DPS"

-- Frame Mover
L["MoverResetToDefault"] = "%s reset to default position"
L["MoverDragToMove"] = "Left-click drag to move"
L["MoverCtrlSnap"] = "Ctrl+drag to snap to grid"
L["MoverRightReset"] = "Right-click to reset"
L["MoverCombatLocked"] = "Cannot enter move mode during combat"
L["MoverEnterMode"] = "Move mode — drag blue frames | Ctrl+drag snap | Right-click reset | ESC exit"
L["MoverExitMode"] = "Exited move mode"
L["MoverAllReset"] = "All frame positions reset"

-- Chat & Tooltip enhancements
L["Timestamps"] = "Timestamps"
L["TimestampsDesc"] = "Show timestamps before chat messages (requires reload)"
L["TimestampFormat"] = "Timestamp Format"
L["ItemCount"] = "Item Count"
L["ItemCountDesc"] = "Show item count (bags/bank) in tooltips"

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

-- Install Wizard
L["InstallWelcome"] = "Welcome to |cff8882ffLunar|r|cffffffffUI|r!"
L["InstallSkipped"] = "Setup skipped. Use |cff8882ff/lunar config|r to configure later."
L["InstallComplete"] = "Setup complete! Reloading UI..."
L["InstallReloadText"] = "LunarUI setup complete. Reload UI to apply changes?"
L["InstallReloadBtn"] = "Reload"
L["InstallReloadLater"] = "Later"
L["InstallTitle"] = "|cff8882ffLunar|r|cffffffffUI|r Setup"
L["InstallStep"] = "Step %d / %d"
L["InstallWelcomeBody"] = "Welcome to |cff8882ffLunar|r|cffffffffUI|r!\n\nThis wizard will help you configure the essential settings. You can always change these later via |cff8882ff/lunar config|r.\n"
L["InstallUIScale"] = "UI Scale"
L["InstallUIScaleTip"] = "|cff888888Tip: Higher values = bigger UI elements. The recommended value is 0.75 for 1920x1080.|r"
L["InstallLayoutTitle"] = "Choose your primary role. This adjusts the size and layout of raid/party frames to match your playstyle.\n"
L["InstallLayoutDPS"] = "DPS"
L["InstallLayoutDPSDesc"] = "Compact raid frames, large player/target, debuff-focused"
L["InstallLayoutTank"] = "Tank"
L["InstallLayoutTankDesc"] = "Wider raid frames with threat, large nameplates"
L["InstallLayoutHealer"] = "Healer"
L["InstallLayoutHealerDesc"] = "Large raid frames with heal prediction, centered position"
L["InstallActionBarTitle"] = "Action Bar Options\n\nConfigure how your action bars behave outside of combat.\n"
L["InstallActionBarFade"] = "Fade action bars when out of combat"
L["InstallActionBarFadeDesc"] = "|cff888888Action bars will fade to 30% opacity when you are not in combat, and instantly appear when entering combat or hovering over them.|r"
L["InstallSummaryTitle"] = "|cff8882ffSetup Complete!|r"
L["InstallSummary"] = "Your settings summary:"
L["InstallSummaryScale"] = "|cff8882ffUI Scale:|r %s"
L["InstallSummaryLayout"] = "|cff8882ffLayout:|r %s"
L["InstallSummaryFade"] = "|cff8882ffAction Bar Fade:|r %s"
L["InstallSummaryHint"] = "|cff888888Click \"Finish\" to apply settings and reload the UI.\nYou can always reconfigure via |cff8882ff/lunar config|r.|r"
L["InstallBtnSkip"] = "Skip"
L["InstallBtnBack"] = "Back"
L["InstallBtnNext"] = "Next"
L["InstallBtnFinish"] = "Finish"

-- Automation
L["AutoRepair"] = "Auto Repair"
L["AutoRepairDesc"] = "Automatically repair equipment when visiting a vendor"
L["AutoRepairGuild"] = "Use Guild Funds"
L["AutoRepairGuildDesc"] = "Prefer guild bank for repair costs when available"
L["AutoRelease"] = "Auto Release Spirit"
L["AutoReleaseDesc"] = "Automatically release spirit in battlegrounds"
L["AutoScreenshot"] = "Achievement Screenshot"
L["AutoScreenshotDesc"] = "Automatically take a screenshot when earning an achievement"
L["RepairCost"] = "Repaired for %s"
L["RepairCostGuild"] = "Repaired for %s (Guild Bank)"
L["RepairNoFunds"] = "Not enough gold to repair"

-- Loot
L["LootTitle"] = "Loot"
L["LootAll"] = "Loot All"
L["LootFrame"] = "Custom Loot Frame"
L["LootFrameDesc"] = "Replace the default loot window with a LunarUI-styled frame (requires reload)"

-- Visual Style
L["style"] = "Visual Style"
L["styleDesc"] = "Customize the overall appearance of LunarUI"
L["theme"] = "Theme"
L["font"] = "Font"
L["fontDesc"] = "Font used across all LunarUI elements (requires reload)"
L["fontSize"] = "Font Size"
L["fontSizeDesc"] = "Base font size for LunarUI elements (requires reload)"
L["statusBarTexture"] = "Status Bar Texture"
L["statusBarTextureDesc"] = "Texture used for health, power, and other status bars (requires reload)"
L["borderStyle"] = "Border Style"
L["borderStyleDesc"] = "Border style for LunarUI frames"

-- Performance Monitor
L["HomeLatency"] = "Home Latency"
L["WorldLatency"] = "World Latency"
L["ShiftDragToMove"] = "Shift+drag to reposition"
L["PerfMonitorTitle"] = "|cff8882ffLunarUI|r Performance Monitor"

-- Bind Type
L["BoE"] = "BoE"
L["BoU"] = "BoU"

-- Errors
L["ErrorOUFNotFound"] = "Error: oUF framework not found"
L["ErrorAddonInit"] = "Error: Failed to initialize addon"

-- HUD Options
L["HUDOverview"] = "Overview"
L["HUDOverviewDesc"] = "HUD overlay element settings. Some changes require /reload to take effect.\n\n"
L["HUDScale"] = "HUD Scale"
L["HUDScaleDesc"] = "Scale all HUD elements"
L["HUDModuleToggles"] = "Module Toggles"
L["HUDPerfMonitor"] = "Performance Monitor"
L["HUDPerfMonitorDesc"] = "Show FPS and latency"
L["HUDClassResources"] = "Class Resources"
L["HUDClassResourcesDesc"] = "Class-specific resource display (combo points, runes, etc.)"
L["HUDCooldownTracker"] = "Cooldown Tracker"
L["HUDCooldownTrackerDesc"] = "Track important ability cooldowns"
L["HUDAuraFrames"] = "Aura Frames"
L["HUDAuraFramesDesc"] = "Independent Buff/Debuff display"
L["HUDAuraSettingsDesc"] = "Buff/Debuff icon size and layout settings. Changes take effect immediately.\n\n"
L["HUDIconSize"] = "Icon Size"
L["HUDAuraIconSizeDesc"] = "Pixel size of each aura icon"
L["HUDIconSpacing"] = "Icon Spacing"
L["HUDIconSpacingDesc"] = "Distance between icons"
L["HUDIconsPerRow"] = "Icons Per Row"
L["HUDIconsPerRowDesc"] = "Number of icons displayed per row"
L["HUDMaxBuffs"] = "Max Buffs"
L["HUDMaxBuffsDesc"] = "Maximum number of Buffs to display"
L["HUDMaxDebuffs"] = "Max Debuffs"
L["HUDMaxDebuffsDesc"] = "Maximum number of Debuffs to display"
L["HUDAuraBarHeight"] = "Timer Bar Height"
L["HUDAuraBarHeightDesc"] = "Height of the timer bar below icons"
L["HUDCDSettings"] = "Cooldown Tracker"
L["HUDCDSettingsDesc"] = "Cooldown tracker icon settings. Changes take effect immediately.\n\n"
L["HUDCDIconSizeDesc"] = "Pixel size of cooldown tracker icons"
L["HUDCDMaxIcons"] = "Max Icons"
L["HUDCDMaxIconsDesc"] = "Maximum number of cooldowns displayed simultaneously"
L["HUDCRSettingsDesc"] = "Class resource (combo points, runes, etc.) display settings. Changes take effect immediately.\n\n"
L["HUDCRIconSizeDesc"] = "Pixel size of resource point icons"
L["HUDCRIconSpacingDesc"] = "Distance between resource points"
L["HUDCRBarHeight"] = "Bar Height"
L["HUDCRBarHeightDesc"] = "Height of the resource bar (when using bar display)"

-- Frame Mover Options
L["FrameMover"] = "Frame Mover"
L["FrameMoverDesc"] = "Frame dragging and snap grid settings"
L["FrameMoverSettingsDesc"] = "Frame mover alignment and appearance settings.\n\n"
L["GridSize"] = "Grid Size"
L["GridSizeDesc"] = "Snap grid spacing when dragging (pixels)"
L["MoverAlpha"] = "Mover Opacity"
L["MoverAlphaDesc"] = "Opacity of mover blocks when unlocked"

-- Options Panel
L["OptionsDesc"] = "Modern combat UI replacement with Lunar theme"
L["EnableLunarUI"] = "Enable LunarUI"
L["DebugModeDesc"] = "Show debug overlay with FPS and memory info"
L["RolePresets"] = "Role Presets"
L["RolePresetsDesc"] = "Quickly adjust raid/party frame layout for your role."
L["DPSLayout"] = "DPS Layout"
L["DPSLayoutDesc"] = "Compact raid frames, optimized for damage dealers"
L["TankLayout"] = "Tank Layout"
L["TankLayoutDesc"] = "Wider frames with larger nameplates for threat awareness"
L["HealerLayout"] = "Healer Layout"
L["HealerLayoutDesc"] = "Large raid frames centered for heal targeting"

-- Export
Engine.L = L
if Engine.LunarUI then
    Engine.LunarUI.L = L
end
