---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI Options
    Configuration interface using AceConfig-3.0

    Features:
    - General settings (Phase, animations)
    - UnitFrames configuration
    - ActionBars configuration
    - Nameplates configuration
    - Non-combat UI settings (Minimap, Chat, Bags, Tooltip)
    - Visual style settings
    - Profile management
]]

local ADDON_NAME = "LunarUI_Options"
local LunarUI = LibStub("AceAddon-3.0"):GetAddon("LunarUI")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0", true)

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------

local L = {
    -- General
    general = "General",
    generalDesc = "General LunarUI settings",
    enable = "Enable",
    enableDesc = "Enable this module",

    -- Phase
    phase = "Phase System",
    phaseDesc = "Lunar Phase state machine settings",
    waningDuration = "Waning Duration",
    waningDurationDesc = "Seconds to wait before returning to NEW phase after combat",

    -- Tokens
    tokens = "Phase Tokens",
    tokensDesc = "Visual parameters for each phase",
    alpha = "Alpha",
    alphaDesc = "Transparency level",
    scale = "Scale",
    scaleDesc = "Size multiplier",

    -- UnitFrames
    unitframes = "Unit Frames",
    unitframesDesc = "oUF unit frame settings",
    player = "Player",
    target = "Target",
    focus = "Focus",
    pet = "Pet",
    targettarget = "Target of Target",
    party = "Party",
    raid = "Raid",
    boss = "Boss",
    width = "Width",
    height = "Height",
    spacing = "Spacing",

    -- ActionBars
    actionbars = "Action Bars",
    actionbarsDesc = "Action bar settings",
    buttons = "Buttons",
    buttonSize = "Button Size",

    -- Nameplates
    nameplates = "Nameplates",
    nameplatesDesc = "Nameplate settings",
    enemy = "Enemy",
    friendly = "Friendly",
    showHealth = "Show Health",
    showCastbar = "Show Castbar",
    showAuras = "Show Auras",

    -- Minimap
    minimap = "Minimap",
    minimapDesc = "Minimap settings",
    showCoords = "Show Coordinates",
    showClock = "Show Clock",
    organizeButtons = "Organize Buttons",

    -- Bags
    bags = "Bags",
    bagsDesc = "Bag settings",
    autoSellJunk = "Auto Sell Junk",
    showItemLevel = "Show Item Level",

    -- Chat
    chat = "Chat",
    chatDesc = "Chat frame settings",
    improvedColors = "Improved Colors",
    classColors = "Class Colors",

    -- Tooltip
    tooltip = "Tooltip",
    tooltipDesc = "Tooltip settings",
    showSpellID = "Show Spell ID",
    showTargetTarget = "Show Target of Target",

    -- Style
    style = "Visual Style",
    styleDesc = "Visual appearance settings",
    theme = "Theme",
    moonlightOverlay = "Moonlight Overlay",
    moonlightOverlayDesc = "Subtle screen overlay during FULL phase",
    phaseGlow = "Phase Glow",
    phaseGlowDesc = "Glow effects on frames during combat",
    animations = "Animations",
    animationsDesc = "Enable phase transition animations",

    -- Profiles
    profiles = "Profiles",
    profilesDesc = "Profile management",
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Fix #26: Add nil check for database access
local function GetDB()
    if not LunarUI or not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile
end

local function RefreshUI()
    -- Notify all modules to refresh
    LunarUI:NotifyPhaseChange(LunarUI:GetPhase(), LunarUI:GetPhase())
end

--------------------------------------------------------------------------------
-- Options Table
--------------------------------------------------------------------------------

local options = {
    name = "|cff8882ffLunar|r|cffffffffUI|r",
    type = "group",
    args = {
        -- Header
        header = {
            order = 0,
            type = "description",
            name = "|cff888888Phase-driven UI system inspired by lunar cycles|r\n\n",
            fontSize = "medium",
        },

        -- General Settings
        general = {
            order = 1,
            type = "group",
            name = L.general,
            desc = L.generalDesc,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    desc = "Enable LunarUI",
                    get = function() return GetDB().enabled end,
                    set = function(_, v) GetDB().enabled = v end,
                    width = "full",
                },
                debug = {
                    order = 2,
                    type = "toggle",
                    name = "Debug Mode",
                    desc = "Show debug overlay with phase information",
                    get = function() return GetDB().debug end,
                    set = function(_, v)
                        GetDB().debug = v
                        if v then
                            LunarUI:ShowDebugOverlay()
                        else
                            LunarUI:HideDebugOverlay()
                        end
                    end,
                    width = "full",
                },
                spacer1 = { order = 10, type = "description", name = "\n" },

                -- Phase settings
                phaseHeader = {
                    order = 11,
                    type = "header",
                    name = L.phase,
                },
                waningDuration = {
                    order = 12,
                    type = "range",
                    name = L.waningDuration,
                    desc = L.waningDurationDesc,
                    min = 1,
                    max = 30,
                    step = 1,
                    get = function() return GetDB().waningDuration end,
                    set = function(_, v) GetDB().waningDuration = v end,
                    width = "full",
                },
            },
        },

        -- Phase Tokens
        tokens = {
            order = 2,
            type = "group",
            name = L.tokens,
            desc = L.tokensDesc,
            args = {
                desc = {
                    order = 0,
                    type = "description",
                    name = "Configure visual parameters for each Lunar Phase.\n\n",
                },
                -- NEW phase
                newHeader = {
                    order = 1,
                    type = "header",
                    name = "|cff666688NEW|r (Out of Combat)",
                },
                newAlpha = {
                    order = 2,
                    type = "range",
                    name = L.alpha,
                    desc = L.alphaDesc,
                    min = 0.1,
                    max = 1.0,
                    step = 0.05,
                    get = function() return GetDB().tokens.NEW.alpha end,
                    set = function(_, v)
                        GetDB().tokens.NEW.alpha = v
                        LunarUI:UpdateTokens()
                    end,
                    width = 1.5,
                },
                newScale = {
                    order = 3,
                    type = "range",
                    name = L.scale,
                    desc = L.scaleDesc,
                    min = 0.8,
                    max = 1.2,
                    step = 0.01,
                    get = function() return GetDB().tokens.NEW.scale end,
                    set = function(_, v)
                        GetDB().tokens.NEW.scale = v
                        LunarUI:UpdateTokens()
                    end,
                    width = 1.5,
                },

                -- WAXING phase
                waxingHeader = {
                    order = 10,
                    type = "header",
                    name = "|cff8888aaWAXING|r (Preparing)",
                },
                waxingAlpha = {
                    order = 11,
                    type = "range",
                    name = L.alpha,
                    min = 0.1,
                    max = 1.0,
                    step = 0.05,
                    get = function() return GetDB().tokens.WAXING.alpha end,
                    set = function(_, v)
                        GetDB().tokens.WAXING.alpha = v
                        LunarUI:UpdateTokens()
                    end,
                    width = 1.5,
                },
                waxingScale = {
                    order = 12,
                    type = "range",
                    name = L.scale,
                    min = 0.8,
                    max = 1.2,
                    step = 0.01,
                    get = function() return GetDB().tokens.WAXING.scale end,
                    set = function(_, v)
                        GetDB().tokens.WAXING.scale = v
                        LunarUI:UpdateTokens()
                    end,
                    width = 1.5,
                },

                -- FULL phase
                fullHeader = {
                    order = 20,
                    type = "header",
                    name = "|cffffffffFULL|r (Combat)",
                },
                fullAlpha = {
                    order = 21,
                    type = "range",
                    name = L.alpha,
                    min = 0.1,
                    max = 1.0,
                    step = 0.05,
                    get = function() return GetDB().tokens.FULL.alpha end,
                    set = function(_, v)
                        GetDB().tokens.FULL.alpha = v
                        LunarUI:UpdateTokens()
                    end,
                    width = 1.5,
                },
                fullScale = {
                    order = 22,
                    type = "range",
                    name = L.scale,
                    min = 0.8,
                    max = 1.2,
                    step = 0.01,
                    get = function() return GetDB().tokens.FULL.scale end,
                    set = function(_, v)
                        GetDB().tokens.FULL.scale = v
                        LunarUI:UpdateTokens()
                    end,
                    width = 1.5,
                },

                -- WANING phase
                waningHeader = {
                    order = 30,
                    type = "header",
                    name = "|cffaaaacc WANING|r (Post-Combat)",
                },
                waningAlpha = {
                    order = 31,
                    type = "range",
                    name = L.alpha,
                    min = 0.1,
                    max = 1.0,
                    step = 0.05,
                    get = function() return GetDB().tokens.WANING.alpha end,
                    set = function(_, v)
                        GetDB().tokens.WANING.alpha = v
                        LunarUI:UpdateTokens()
                    end,
                    width = 1.5,
                },
                waningScale = {
                    order = 32,
                    type = "range",
                    name = L.scale,
                    min = 0.8,
                    max = 1.2,
                    step = 0.01,
                    get = function() return GetDB().tokens.WANING.scale end,
                    set = function(_, v)
                        GetDB().tokens.WANING.scale = v
                        LunarUI:UpdateTokens()
                    end,
                    width = 1.5,
                },
            },
        },

        -- Unit Frames
        unitframes = {
            order = 3,
            type = "group",
            name = L.unitframes,
            desc = L.unitframesDesc,
            childGroups = "tab",
            args = {
                player = {
                    order = 1,
                    type = "group",
                    name = L.player,
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function() return GetDB().unitframes.player.enabled end,
                            set = function(_, v) GetDB().unitframes.player.enabled = v; RefreshUI() end,
                            width = "full",
                        },
                        width = {
                            order = 2,
                            type = "range",
                            name = L.width,
                            min = 100,
                            max = 400,
                            step = 5,
                            get = function() return GetDB().unitframes.player.width end,
                            set = function(_, v) GetDB().unitframes.player.width = v; RefreshUI() end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 20,
                            max = 100,
                            step = 1,
                            get = function() return GetDB().unitframes.player.height end,
                            set = function(_, v) GetDB().unitframes.player.height = v; RefreshUI() end,
                        },
                    },
                },
                target = {
                    order = 2,
                    type = "group",
                    name = L.target,
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function() return GetDB().unitframes.target.enabled end,
                            set = function(_, v) GetDB().unitframes.target.enabled = v; RefreshUI() end,
                            width = "full",
                        },
                        width = {
                            order = 2,
                            type = "range",
                            name = L.width,
                            min = 100,
                            max = 400,
                            step = 5,
                            get = function() return GetDB().unitframes.target.width end,
                            set = function(_, v) GetDB().unitframes.target.width = v; RefreshUI() end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 20,
                            max = 100,
                            step = 1,
                            get = function() return GetDB().unitframes.target.height end,
                            set = function(_, v) GetDB().unitframes.target.height = v; RefreshUI() end,
                        },
                    },
                },
                focus = {
                    order = 3,
                    type = "group",
                    name = L.focus,
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function() return GetDB().unitframes.focus.enabled end,
                            set = function(_, v) GetDB().unitframes.focus.enabled = v; RefreshUI() end,
                            width = "full",
                        },
                        width = {
                            order = 2,
                            type = "range",
                            name = L.width,
                            min = 80,
                            max = 300,
                            step = 5,
                            get = function() return GetDB().unitframes.focus.width end,
                            set = function(_, v) GetDB().unitframes.focus.width = v; RefreshUI() end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 15,
                            max = 80,
                            step = 1,
                            get = function() return GetDB().unitframes.focus.height end,
                            set = function(_, v) GetDB().unitframes.focus.height = v; RefreshUI() end,
                        },
                    },
                },
                party = {
                    order = 4,
                    type = "group",
                    name = L.party,
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function() return GetDB().unitframes.party.enabled end,
                            set = function(_, v) GetDB().unitframes.party.enabled = v; RefreshUI() end,
                            width = "full",
                        },
                        width = {
                            order = 2,
                            type = "range",
                            name = L.width,
                            min = 80,
                            max = 250,
                            step = 5,
                            get = function() return GetDB().unitframes.party.width end,
                            set = function(_, v) GetDB().unitframes.party.width = v; RefreshUI() end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 15,
                            max = 60,
                            step = 1,
                            get = function() return GetDB().unitframes.party.height end,
                            set = function(_, v) GetDB().unitframes.party.height = v; RefreshUI() end,
                        },
                        spacing = {
                            order = 4,
                            type = "range",
                            name = L.spacing,
                            min = 0,
                            max = 20,
                            step = 1,
                            get = function() return GetDB().unitframes.party.spacing end,
                            set = function(_, v) GetDB().unitframes.party.spacing = v; RefreshUI() end,
                        },
                    },
                },
                raid = {
                    order = 5,
                    type = "group",
                    name = L.raid,
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function() return GetDB().unitframes.raid.enabled end,
                            set = function(_, v) GetDB().unitframes.raid.enabled = v; RefreshUI() end,
                            width = "full",
                        },
                        width = {
                            order = 2,
                            type = "range",
                            name = L.width,
                            min = 50,
                            max = 150,
                            step = 5,
                            get = function() return GetDB().unitframes.raid.width end,
                            set = function(_, v) GetDB().unitframes.raid.width = v; RefreshUI() end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 15,
                            max = 50,
                            step = 1,
                            get = function() return GetDB().unitframes.raid.height end,
                            set = function(_, v) GetDB().unitframes.raid.height = v; RefreshUI() end,
                        },
                        spacing = {
                            order = 4,
                            type = "range",
                            name = L.spacing,
                            min = 0,
                            max = 10,
                            step = 1,
                            get = function() return GetDB().unitframes.raid.spacing end,
                            set = function(_, v) GetDB().unitframes.raid.spacing = v; RefreshUI() end,
                        },
                    },
                },
                boss = {
                    order = 6,
                    type = "group",
                    name = L.boss,
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function() return GetDB().unitframes.boss.enabled end,
                            set = function(_, v) GetDB().unitframes.boss.enabled = v; RefreshUI() end,
                            width = "full",
                        },
                        width = {
                            order = 2,
                            type = "range",
                            name = L.width,
                            min = 100,
                            max = 300,
                            step = 5,
                            get = function() return GetDB().unitframes.boss.width end,
                            set = function(_, v) GetDB().unitframes.boss.width = v; RefreshUI() end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 20,
                            max = 80,
                            step = 1,
                            get = function() return GetDB().unitframes.boss.height end,
                            set = function(_, v) GetDB().unitframes.boss.height = v; RefreshUI() end,
                        },
                    },
                },
            },
        },

        -- Action Bars
        actionbars = {
            order = 4,
            type = "group",
            name = L.actionbars,
            desc = L.actionbarsDesc,
            childGroups = "tab",
            args = {},
        },

        -- Nameplates
        nameplates = {
            order = 5,
            type = "group",
            name = L.nameplates,
            desc = L.nameplatesDesc,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    get = function() return GetDB().nameplates.enabled end,
                    set = function(_, v) GetDB().nameplates.enabled = v; RefreshUI() end,
                    width = "full",
                },
                width = {
                    order = 2,
                    type = "range",
                    name = L.width,
                    min = 80,
                    max = 200,
                    step = 5,
                    get = function() return GetDB().nameplates.width end,
                    set = function(_, v) GetDB().nameplates.width = v; RefreshUI() end,
                },
                height = {
                    order = 3,
                    type = "range",
                    name = L.height,
                    min = 6,
                    max = 30,
                    step = 1,
                    get = function() return GetDB().nameplates.height end,
                    set = function(_, v) GetDB().nameplates.height = v; RefreshUI() end,
                },
                spacer1 = { order = 10, type = "description", name = "\n" },
                enemyHeader = {
                    order = 11,
                    type = "header",
                    name = "Enemy Nameplates",
                },
                enemyEnabled = {
                    order = 12,
                    type = "toggle",
                    name = L.enable,
                    get = function() return GetDB().nameplates.enemy.enabled end,
                    set = function(_, v) GetDB().nameplates.enemy.enabled = v; RefreshUI() end,
                },
                enemyShowCastbar = {
                    order = 13,
                    type = "toggle",
                    name = L.showCastbar,
                    get = function() return GetDB().nameplates.enemy.showCastbar end,
                    set = function(_, v) GetDB().nameplates.enemy.showCastbar = v; RefreshUI() end,
                },
                enemyShowAuras = {
                    order = 14,
                    type = "toggle",
                    name = L.showAuras,
                    get = function() return GetDB().nameplates.enemy.showAuras end,
                    set = function(_, v) GetDB().nameplates.enemy.showAuras = v; RefreshUI() end,
                },
                spacer2 = { order = 20, type = "description", name = "\n" },
                friendlyHeader = {
                    order = 21,
                    type = "header",
                    name = "Friendly Nameplates",
                },
                friendlyEnabled = {
                    order = 22,
                    type = "toggle",
                    name = L.enable,
                    get = function() return GetDB().nameplates.friendly.enabled end,
                    set = function(_, v) GetDB().nameplates.friendly.enabled = v; RefreshUI() end,
                },
                friendlyShowHealth = {
                    order = 23,
                    type = "toggle",
                    name = L.showHealth,
                    get = function() return GetDB().nameplates.friendly.showHealth end,
                    set = function(_, v) GetDB().nameplates.friendly.showHealth = v; RefreshUI() end,
                },
            },
        },

        -- Minimap
        minimap = {
            order = 6,
            type = "group",
            name = L.minimap,
            desc = L.minimapDesc,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    get = function() return GetDB().minimap.enabled end,
                    set = function(_, v) GetDB().minimap.enabled = v end,
                    width = "full",
                },
                size = {
                    order = 2,
                    type = "range",
                    name = "Size",
                    min = 120,
                    max = 250,
                    step = 5,
                    get = function() return GetDB().minimap.size end,
                    set = function(_, v) GetDB().minimap.size = v end,
                },
                showCoords = {
                    order = 3,
                    type = "toggle",
                    name = L.showCoords,
                    get = function() return GetDB().minimap.showCoords end,
                    set = function(_, v) GetDB().minimap.showCoords = v end,
                },
                showClock = {
                    order = 4,
                    type = "toggle",
                    name = L.showClock,
                    get = function() return GetDB().minimap.showClock end,
                    set = function(_, v) GetDB().minimap.showClock = v end,
                },
                organizeButtons = {
                    order = 5,
                    type = "toggle",
                    name = L.organizeButtons,
                    get = function() return GetDB().minimap.organizeButtons end,
                    set = function(_, v) GetDB().minimap.organizeButtons = v end,
                },
            },
        },

        -- Bags
        bags = {
            order = 7,
            type = "group",
            name = L.bags,
            desc = L.bagsDesc,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    get = function() return GetDB().bags.enabled end,
                    set = function(_, v) GetDB().bags.enabled = v end,
                    width = "full",
                },
                slotsPerRow = {
                    order = 2,
                    type = "range",
                    name = "Slots Per Row",
                    min = 8,
                    max = 16,
                    step = 1,
                    get = function() return GetDB().bags.slotsPerRow end,
                    set = function(_, v) GetDB().bags.slotsPerRow = v end,
                },
                slotSize = {
                    order = 3,
                    type = "range",
                    name = "Slot Size",
                    min = 28,
                    max = 48,
                    step = 1,
                    get = function() return GetDB().bags.slotSize end,
                    set = function(_, v) GetDB().bags.slotSize = v end,
                },
                autoSellJunk = {
                    order = 4,
                    type = "toggle",
                    name = L.autoSellJunk,
                    get = function() return GetDB().bags.autoSellJunk end,
                    set = function(_, v) GetDB().bags.autoSellJunk = v end,
                },
                showItemLevel = {
                    order = 5,
                    type = "toggle",
                    name = L.showItemLevel,
                    get = function() return GetDB().bags.showItemLevel end,
                    set = function(_, v) GetDB().bags.showItemLevel = v end,
                },
            },
        },

        -- Chat
        chat = {
            order = 8,
            type = "group",
            name = L.chat,
            desc = L.chatDesc,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    get = function() return GetDB().chat.enabled end,
                    set = function(_, v) GetDB().chat.enabled = v end,
                    width = "full",
                },
                width = {
                    order = 2,
                    type = "range",
                    name = L.width,
                    min = 200,
                    max = 600,
                    step = 10,
                    get = function() return GetDB().chat.width end,
                    set = function(_, v) GetDB().chat.width = v end,
                },
                height = {
                    order = 3,
                    type = "range",
                    name = L.height,
                    min = 100,
                    max = 400,
                    step = 10,
                    get = function() return GetDB().chat.height end,
                    set = function(_, v) GetDB().chat.height = v end,
                },
                improvedColors = {
                    order = 4,
                    type = "toggle",
                    name = L.improvedColors,
                    get = function() return GetDB().chat.improvedColors end,
                    set = function(_, v) GetDB().chat.improvedColors = v end,
                },
                classColors = {
                    order = 5,
                    type = "toggle",
                    name = L.classColors,
                    get = function() return GetDB().chat.classColors end,
                    set = function(_, v) GetDB().chat.classColors = v end,
                },
            },
        },

        -- Tooltip
        tooltip = {
            order = 9,
            type = "group",
            name = L.tooltip,
            desc = L.tooltipDesc,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    get = function() return GetDB().tooltip.enabled end,
                    set = function(_, v) GetDB().tooltip.enabled = v end,
                    width = "full",
                },
                anchorCursor = {
                    order = 2,
                    type = "toggle",
                    name = "Anchor to Cursor",
                    get = function() return GetDB().tooltip.anchorCursor end,
                    set = function(_, v) GetDB().tooltip.anchorCursor = v end,
                },
                showItemLevel = {
                    order = 3,
                    type = "toggle",
                    name = L.showItemLevel,
                    get = function() return GetDB().tooltip.showItemLevel end,
                    set = function(_, v) GetDB().tooltip.showItemLevel = v end,
                },
                showSpellID = {
                    order = 4,
                    type = "toggle",
                    name = L.showSpellID,
                    get = function() return GetDB().tooltip.showSpellID end,
                    set = function(_, v) GetDB().tooltip.showSpellID = v end,
                },
                showItemID = {
                    order = 5,
                    type = "toggle",
                    name = "Show Item ID",
                    get = function() return GetDB().tooltip.showItemID end,
                    set = function(_, v) GetDB().tooltip.showItemID = v end,
                },
                showTargetTarget = {
                    order = 6,
                    type = "toggle",
                    name = L.showTargetTarget,
                    get = function() return GetDB().tooltip.showTargetTarget end,
                    set = function(_, v) GetDB().tooltip.showTargetTarget = v end,
                },
            },
        },

        -- Visual Style
        style = {
            order = 10,
            type = "group",
            name = L.style,
            desc = L.styleDesc,
            args = {
                theme = {
                    order = 1,
                    type = "select",
                    name = L.theme,
                    values = {
                        lunar = "Lunar (Default)",
                        parchment = "Parchment",
                        minimal = "Minimal",
                    },
                    get = function() return GetDB().style.theme end,
                    set = function(_, v) GetDB().style.theme = v; RefreshUI() end,
                    width = "full",
                },
                spacer1 = { order = 5, type = "description", name = "\n" },
                effectsHeader = {
                    order = 6,
                    type = "header",
                    name = "Effects",
                },
                moonlightOverlay = {
                    order = 7,
                    type = "toggle",
                    name = L.moonlightOverlay,
                    desc = L.moonlightOverlayDesc,
                    get = function() return GetDB().style.moonlightOverlay end,
                    set = function(_, v) GetDB().style.moonlightOverlay = v end,
                    width = "full",
                },
                phaseGlow = {
                    order = 8,
                    type = "toggle",
                    name = L.phaseGlow,
                    desc = L.phaseGlowDesc,
                    get = function() return GetDB().style.phaseGlow end,
                    set = function(_, v) GetDB().style.phaseGlow = v end,
                    width = "full",
                },
                animations = {
                    order = 9,
                    type = "toggle",
                    name = L.animations,
                    desc = L.animationsDesc,
                    get = function() return GetDB().style.animations end,
                    set = function(_, v) GetDB().style.animations = v end,
                    width = "full",
                },
            },
        },
    },
}

-- Build Action Bars options dynamically
for i = 1, 6 do
    options.args.actionbars.args["bar" .. i] = {
        order = i,
        type = "group",
        name = "Bar " .. i,
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = L.enable,
                get = function() return GetDB().actionbars["bar" .. i].enabled end,
                set = function(_, v) GetDB().actionbars["bar" .. i].enabled = v; RefreshUI() end,
                width = "full",
            },
            buttons = {
                order = 2,
                type = "range",
                name = L.buttons,
                min = 1,
                max = 12,
                step = 1,
                get = function() return GetDB().actionbars["bar" .. i].buttons end,
                set = function(_, v) GetDB().actionbars["bar" .. i].buttons = v; RefreshUI() end,
            },
            buttonSize = {
                order = 3,
                type = "range",
                name = L.buttonSize,
                min = 24,
                max = 48,
                step = 1,
                get = function() return GetDB().actionbars["bar" .. i].buttonSize end,
                set = function(_, v) GetDB().actionbars["bar" .. i].buttonSize = v; RefreshUI() end,
            },
        },
    }
end

-- Add pet bar and stance bar
options.args.actionbars.args.petbar = {
    order = 10,
    type = "group",
    name = "Pet Bar",
    args = {
        enabled = {
            order = 1,
            type = "toggle",
            name = L.enable,
            get = function() return GetDB().actionbars.petbar.enabled end,
            set = function(_, v) GetDB().actionbars.petbar.enabled = v; RefreshUI() end,
            width = "full",
        },
    },
}

options.args.actionbars.args.stancebar = {
    order = 11,
    type = "group",
    name = "Stance Bar",
    args = {
        enabled = {
            order = 1,
            type = "toggle",
            name = L.enable,
            get = function() return GetDB().actionbars.stancebar.enabled end,
            set = function(_, v) GetDB().actionbars.stancebar.enabled = v; RefreshUI() end,
            width = "full",
        },
    },
}

--------------------------------------------------------------------------------
-- Profile Options
--------------------------------------------------------------------------------

local function GetProfileOptions()
    if AceDBOptions then
        return AceDBOptions:GetOptionsTable(LunarUI.db)
    end
    return nil
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local function RegisterOptions()
    -- Register main options
    AceConfig:RegisterOptionsTable("LunarUI", options)

    -- Add to Blizzard options
    AceConfigDialog:AddToBlizOptions("LunarUI", "LunarUI")

    -- Register profile options
    local profileOptions = GetProfileOptions()
    if profileOptions then
        AceConfig:RegisterOptionsTable("LunarUI_Profiles", profileOptions)
        AceConfigDialog:AddToBlizOptions("LunarUI_Profiles", L.profiles, "LunarUI")
    end
end

--------------------------------------------------------------------------------
-- Slash Command
--------------------------------------------------------------------------------

local function OpenConfig()
    -- Load the options addon if not loaded
    if not IsAddOnLoaded("LunarUI_Options") then
        LoadAddOn("LunarUI_Options")
    end

    -- Open the config dialog
    AceConfigDialog:Open("LunarUI")
end

-- Register with main addon
LunarUI.OpenConfig = OpenConfig

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

-- Fix #27: Clean up frame after registration
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
    if addon == "LunarUI_Options" then
        RegisterOptions()
        self:UnregisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", nil)
        -- Frame can be garbage collected now
    end
end)
