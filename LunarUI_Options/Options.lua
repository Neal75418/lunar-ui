---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, return-type-mismatch, unnecessary-if
--[[
    LunarUI Options
    Configuration interface using AceConfig-3.0

    Features:
    - General settings
    - UnitFrames configuration
    - ActionBars configuration
    - Nameplates configuration
    - Non-combat UI settings (Minimap, Chat, Bags, Tooltip)
    - Visual style settings
    - Profile management
]]

local _ADDON_NAME = "LunarUI_Options"
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
    enemyNameplates = "Enemy Nameplates",
    friendlyNameplates = "Friendly Nameplates",
    showHealth = "Show Health",
    showCastbar = "Show Castbar",
    showAuras = "Show Auras",

    -- HUD
    hud = "HUD",
    hudDesc = "Head-Up Display settings",

    -- Aura Filtering
    auraFiltering = "Aura Filtering",
    auraFilteringDesc = "Control which buffs/debuffs are shown on unit frames.\n",
    auraWhitelist = "Whitelist (Always Show)",
    auraWhitelistDesc = "Spell IDs that should always be displayed, bypassing all filters",
    auraBlacklist = "Blacklist (Always Hide)",
    auraBlacklistDesc = "Spell IDs that should never be displayed",

    -- Minimap
    minimap = "Minimap",
    minimapDesc = "Minimap settings",
    showCoords = "Show Coordinates",
    showClock = "Show Clock",
    organizeButtons = "Organize Buttons",
    layout = "Layout",
    size = "Size",
    borderColor = "Border Color",
    pinScale = "Pin Scale",
    pinScaleDesc = "Scale of minimap pins (quests, herbs, nodes)",
    display = "Display",
    clockFormat = "Clock Format",
    zoneText = "Zone Text",
    zoneTextDesc = "Show zone text always, on mouseover, or hide",
    fonts = "Fonts",
    zoneTextSize = "Zone Text Size",
    zoneTextOutline = "Zone Text Outline",
    coordClockTextSize = "Coord / Clock Text Size",
    behavior = "Behavior",
    resetZoomTimer = "Reset Zoom Timer",
    resetZoomTimerDesc = "Auto zoom-out after this many seconds (0 = disabled)",
    fadeOnMouseLeave = "Fade on Mouse Leave",
    fadeOnMouseLeaveDesc = "Fade the minimap when the mouse is not over it",
    fadeAlpha = "Fade Alpha",
    iconSettings = "Icon Settings",
    hide = "Hide",
    anchor = "Anchor",
    scale = "Scale",
    xOffset = "X Offset",
    yOffset = "Y Offset",

    -- Bags
    bags = "Bags",
    bagsDesc = "Bag settings",
    autoSellJunk = "Auto Sell Junk",
    showItemLevel = "Show Item Level",
    slotsPerRow = "Slots Per Row",
    slotSize = "Slot Size",
    slotSpacing = "Slot Spacing",
    backgroundOpacity = "Background Opacity",
    reverseBagSlots = "Reverse Bag Slots",
    reverseBagSlotsDesc = "Reverse the order of items in the bag",
    splitBags = "Split Bags",
    splitBagsDesc = "Show each bag as a separate section with visual gaps",
    ilvlThreshold = "Item Level Threshold",
    ilvlThresholdDesc = "Only show item level for items at or above this level",
    showBindType = "Show Bind Type",
    showBindTypeDesc = "Show BoE/BoU text on item slots",
    showCooldowns = "Show Cooldowns",
    showCooldownsDesc = "Show cooldown animation on items in bags",
    newItemGlow = "New Item Glow",
    newItemGlowDesc = "Show a glow animation on newly acquired items",
    showQuestItems = "Show Quest Items",
    showQuestItemsDesc = "Show quest item indicator on bag slots",
    professionBagColors = "Profession Bag Colors",
    professionBagColorsDesc = "Color-code profession bag slots",
    upgradeArrow = "Upgrade Arrow",
    upgradeArrowDesc = "Show green arrow on items that are an upgrade",
    clearSearchOnClose = "Clear Search On Close",
    clearSearchOnCloseDesc = "Automatically clear the search box when closing bags",
    resetPosition = "Reset Position",
    resetPositionDesc = "Reset bag and bank frame positions to default",

    -- Chat
    chat = "Chat",
    chatDesc = "Chat frame settings",
    improvedColors = "Improved Colors",
    classColors = "Class Colors",
    fadeTime = "Text Fade Time",
    fadeTimeDesc = "Seconds before chat text fades out (0 = never fade)",
    backdropAlpha = "Backdrop Opacity",
    backdropAlphaDesc = "Chat frame backdrop opacity",
    inactiveTabAlpha = "Inactive Tab Opacity",
    inactiveTabAlphaDesc = "Opacity of inactive chat tab text",
    editBoxOffset = "Edit Box Spacing",
    editBoxOffsetDesc = "Spacing between chat frame and input box",
    chatKeywords = "Keyword Alerts",
    chatKeywordsDesc = "Comma-separated list of keywords that trigger chat alerts (e.g. your name, guild name)",

    -- Tooltip
    tooltip = "Tooltip",
    tooltipDesc = "Tooltip settings",
    anchorToCursor = "Anchor to Cursor",
    showSpellID = "Show Spell ID",
    showItemID = "Show Item ID",
    showTargetTarget = "Show Target of Target",

    -- Automation
    automation = "Automation",
    automationDesc = "Quality of life automation features",
    automationHeader = "Convenience features that automate common tasks.\n\n",
    autoRepair = "Auto Repair",
    autoRepairDesc = "Automatically repair equipment when visiting a vendor",
    useGuildFunds = "Use Guild Funds",
    useGuildFundsDesc = "Prefer guild bank for repair costs when available",
    autoRelease = "Auto Release Spirit (BG)",
    autoReleaseDesc = "Automatically release spirit when dying in battlegrounds",
    achievementScreenshot = "Achievement Screenshot",
    achievementScreenshotDesc = "Automatically take a screenshot when earning an achievement",
    autoAcceptQuest = "Auto Accept/Turn-in Quest",
    autoAcceptQuestDesc = "Automatically accept and turn in quests from NPCs",
    autoAcceptQueue = "Auto Accept Queue",
    autoAcceptQueueDesc = "Automatically accept LFG/battleground queue proposals",

    -- ActionBars (extended)
    petBar = "Pet Bar",
    stanceBar = "Stance Bar",

    -- Specialization
    specAutoSwitch = "Specialization Auto-Switch",
    specAutoSwitchDesc = "Automatically switch profiles when changing specialization.\n\n",
    specProfile = "Profile to use for this specialization",

    -- Debug
    debugMode = "Debug Mode",

    -- Style
    style = "Visual Style",
    styleDesc = "Visual appearance settings",
    theme = "Theme",
    font = "Font",
    fontDesc = "Select a font for UI elements",
    fontSize = "Font Size",
    fontSizeDesc = "Adjust the font size for UI elements",
    statusBarTexture = "Status Bar Texture",
    statusBarTextureDesc = "Select a texture for status bars",
    borderStyle = "Border Style",
    borderStyleDesc = "Select a border style for frames",
    -- Skins
    skins = "Skins",
    skinsDesc = "Restyle Blizzard UI frames to match LunarUI theme",
    skinCharacter = "Character Frame",
    skinSpellbook = "Spellbook",
    skinTalents = "Talents",
    skinQuest = "Quest",
    skinMerchant = "Merchant",
    skinGossip = "Gossip",
    skinWorldMap = "World Map",
    skinAchievements = "Achievements",
    skinMail = "Mail",
    skinCollections = "Collections",
    skinLFG = "Group Finder",
    skinEncounterJournal = "Encounter Journal",
    skinAuctionHouse = "Auction House",
    skinCommunities = "Communities",
    skinCalendar = "Calendar",
    skinWeeklyRewards = "Great Vault",
    skinAddonList = "Addon List",
    skinHousing = "Housing",
    skinProfessions = "Professions",
    skinPVP = "PVP",
    skinSettings = "Settings",
    skinTrade = "Trade",
    skinQuestMap = "Quest Map",

    -- Frame Mover
    FrameMover = "Frame Mover",
    FrameMoverDesc = "Configure frame positioning grid and visual aids",
    FrameMoverSettingsDesc = "Adjust grid snapping and overlay visibility for frame positioning",
    GridSize = "Grid Size",
    GridSizeDesc = "Size of the positioning grid in pixels",
    MoverAlpha = "Overlay Opacity",
    MoverAlphaDesc = "Opacity of frame mover overlays (0.1 = transparent, 1.0 = opaque)",

    -- Profiles
    profiles = "Profiles",
    profilesDesc = "Profile management",
}

-- 從主 addon 的 locale 表繼承翻譯（支援 i18n）
-- 嘗試多個來源：
-- 1. LunarUI.L (透過 GetAddon 取得的 addon 對象)
-- 2. _G.LunarUI.L (全域 LunarUI 對象，應該與 LunarUI 相同)
-- 延遲取得以確保主插件已完全載入本地化表
local function GetMainLocale()
    return LunarUI.L or (_G.LunarUI and _G.LunarUI.L)
end

-- 設定 metatable 以支援延遲繼承（每次查找時都檢查主插件的本地化表）
setmetatable(L, {
    __index = function(_, key)
        local mainLocale = GetMainLocale()
        return mainLocale and mainLocale[key]
    end,
})

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Fix #26: DB 未載入時回傳 nil（AceDB 保證 Options panel 開啟時 DB 一定存在）
local getDBWarned = false
local function GetDB()
    local profile = LunarUI.GetProfileDB and LunarUI.GetProfileDB()
    if not profile then
        if not getDBWarned then
            getDBWarned = true
            LunarUI:Print("|cffff0000[Options] DB not ready — settings may not save|r")
        end
        return nil
    end
    return profile
end

local function RefreshUI()
    if LunarUI.ApplyHUDScale then
        LunarUI:ApplyHUDScale()
    end
    -- 字體/字型大小變更時即時生效（批次更新所有已註冊 FontString）
    if LunarUI.ApplyFontSettings then
        LunarUI:ApplyFontSettings()
    end
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
            name = "|cff888888" .. (L["OptionsDesc"] or "Modern combat UI replacement with Lunar theme") .. "|r\n\n",
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
                    desc = L["EnableLunarUI"] or "Enable LunarUI",
                    get = function()
                        return GetDB().enabled
                    end,
                    set = function(_, v)
                        GetDB().enabled = v
                    end,
                    width = "full",
                },
                debug = {
                    order = 2,
                    type = "toggle",
                    name = L.debugMode,
                    desc = L["DebugModeDesc"] or "Show debug overlay with FPS and memory info",
                    get = function()
                        return GetDB().debug
                    end,
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
            },
        },

        -- Unit Frames
        unitframes = {
            order = 3,
            type = "group",
            name = L.unitframes,
            desc = L.unitframesDesc,
            childGroups = "tab",
            args = (function()
                -- 工廠函數：生成單位框架設定組
                local function MakeUnitFrameGroup(unit, ord, displayName, opts)
                    local args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            width = "full",
                            get = function()
                                return GetDB().unitframes[unit].enabled
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].enabled = v
                                RefreshUI()
                            end,
                        },
                        width = {
                            order = 2,
                            type = "range",
                            name = L.width,
                            min = opts.wMin,
                            max = opts.wMax,
                            step = 5,
                            get = function()
                                return GetDB().unitframes[unit].width
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].width = v
                                RefreshUI()
                            end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = opts.hMin,
                            max = opts.hMax,
                            step = 1,
                            get = function()
                                return GetDB().unitframes[unit].height
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].height = v
                                RefreshUI()
                            end,
                        },
                    }
                    if opts.spacingMax then
                        args.spacing = {
                            order = 4,
                            type = "range",
                            name = L.spacing,
                            min = 0,
                            max = opts.spacingMax,
                            step = 1,
                            get = function()
                                return GetDB().unitframes[unit].spacing
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].spacing = v
                                RefreshUI()
                            end,
                        }
                    end

                    -- Aura settings (for units that have showBuffs/showDebuffs in Defaults)
                    if opts.hasAuras then
                        args.auraHeader = { order = 10, type = "header", name = L["AuraSettings"] or "Aura Settings" }
                        args.showBuffs = {
                            order = 11,
                            type = "toggle",
                            name = L["ShowBuffs"] or "Show Buffs",
                            desc = L["ShowBuffsDesc"] or "Display buff icons on this unit frame",
                            get = function()
                                return GetDB().unitframes[unit].showBuffs
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].showBuffs = v
                                RefreshUI()
                            end,
                        }
                        args.buffSize = {
                            order = 12,
                            type = "range",
                            name = L["BuffSize"] or "Buff Size",
                            min = 12,
                            max = 40,
                            step = 1,
                            get = function()
                                return GetDB().unitframes[unit].buffSize
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].buffSize = v
                                RefreshUI()
                            end,
                        }
                        args.maxBuffs = {
                            order = 13,
                            type = "range",
                            name = L["MaxBuffs"] or "Max Buffs",
                            min = 0,
                            max = 40,
                            step = 1,
                            get = function()
                                return GetDB().unitframes[unit].maxBuffs
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].maxBuffs = v
                                RefreshUI()
                            end,
                        }
                        args.showDebuffs = {
                            order = 14,
                            type = "toggle",
                            name = L["ShowDebuffs"] or "Show Debuffs",
                            desc = L["ShowDebuffsDesc"] or "Display debuff icons on this unit frame",
                            get = function()
                                return GetDB().unitframes[unit].showDebuffs
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].showDebuffs = v
                                RefreshUI()
                            end,
                        }
                        args.debuffSize = {
                            order = 15,
                            type = "range",
                            name = L["DebuffSize"] or "Debuff Size",
                            min = 12,
                            max = 40,
                            step = 1,
                            get = function()
                                return GetDB().unitframes[unit].debuffSize
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].debuffSize = v
                                RefreshUI()
                            end,
                        }
                        args.maxDebuffs = {
                            order = 16,
                            type = "range",
                            name = L["MaxDebuffs"] or "Max Debuffs",
                            min = 0,
                            max = 40,
                            step = 1,
                            get = function()
                                return GetDB().unitframes[unit].maxDebuffs
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].maxDebuffs = v
                                RefreshUI()
                            end,
                        }
                        args.onlyPlayerDebuffs = {
                            order = 17,
                            type = "toggle",
                            name = L["OnlyPlayerDebuffs"] or "Only Player Debuffs",
                            desc = L["OnlyPlayerDebuffsDesc"] or "Only show debuffs cast by you",
                            get = function()
                                return GetDB().unitframes[unit].onlyPlayerDebuffs
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].onlyPlayerDebuffs = v
                                RefreshUI()
                            end,
                        }
                    end

                    -- Player-only: portrait, heal prediction, castbar
                    if opts.hasPortrait then
                        args.portraitHeader =
                            { order = 20, type = "header", name = L["PortraitSettings"] or "Portrait" }
                        args.showPortrait = {
                            order = 21,
                            type = "toggle",
                            name = L["ShowPortrait"] or "Show Portrait",
                            desc = L["ShowPortraitDesc"] or "Display character portrait on the unit frame",
                            get = function()
                                return GetDB().unitframes[unit].showPortrait
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].showPortrait = v
                                RefreshUI()
                            end,
                        }
                        args.showHealPrediction = {
                            order = 22,
                            type = "toggle",
                            name = L["ShowHealPrediction"] or "Show Heal Prediction",
                            desc = L["ShowHealPredictionDesc"] or "Show incoming heal prediction bar",
                            get = function()
                                return GetDB().unitframes[unit].showHealPrediction
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].showHealPrediction = v
                                RefreshUI()
                            end,
                        }
                    end

                    -- Player-only: castbar sub-group
                    if opts.hasCastbar then
                        args.castbar = {
                            order = 30,
                            type = "group",
                            name = L["Castbar"] or "Castbar",
                            inline = true,
                            args = {
                                height = {
                                    order = 1,
                                    type = "range",
                                    name = L.height,
                                    min = 6,
                                    max = 30,
                                    step = 1,
                                    get = function()
                                        return GetDB().unitframes[unit].castbar.height
                                    end,
                                    set = function(_, v)
                                        GetDB().unitframes[unit].castbar.height = v
                                        RefreshUI()
                                    end,
                                },
                                showLatency = {
                                    order = 2,
                                    type = "toggle",
                                    name = L["CastbarLatency"] or "Show Latency",
                                    desc = L["CastbarLatencyDesc"] or "Show latency indicator on the castbar",
                                    get = function()
                                        return GetDB().unitframes[unit].castbar.showLatency
                                    end,
                                    set = function(_, v)
                                        GetDB().unitframes[unit].castbar.showLatency = v
                                        RefreshUI()
                                    end,
                                },
                                showTicks = {
                                    order = 3,
                                    type = "toggle",
                                    name = L["CastbarTicks"] or "Show Ticks",
                                    desc = L["CastbarTicksDesc"] or "Show tick marks on channeled spells",
                                    get = function()
                                        return GetDB().unitframes[unit].castbar.showTicks
                                    end,
                                    set = function(_, v)
                                        GetDB().unitframes[unit].castbar.showTicks = v
                                        RefreshUI()
                                    end,
                                },
                                showEmpowered = {
                                    order = 4,
                                    type = "toggle",
                                    name = L["CastbarEmpowered"] or "Show Empowered",
                                    desc = L["CastbarEmpoweredDesc"] or "Show Evoker empowered cast stages",
                                    get = function()
                                        return GetDB().unitframes[unit].castbar.showEmpowered
                                    end,
                                    set = function(_, v)
                                        GetDB().unitframes[unit].castbar.showEmpowered = v
                                        RefreshUI()
                                    end,
                                },
                            },
                        }
                    end

                    -- Raid-only: autoSwitchSize
                    if opts.hasAutoSwitchSize then
                        args.autoSwitchSize = {
                            order = 40,
                            type = "toggle",
                            name = L["AutoSwitchSize"] or "Auto Switch Size",
                            desc = L["AutoSwitchSizeDesc"]
                                or "Automatically adjust raid frame size based on group size",
                            get = function()
                                return GetDB().unitframes[unit].autoSwitchSize
                            end,
                            set = function(_, v)
                                GetDB().unitframes[unit].autoSwitchSize = v
                                RefreshUI()
                            end,
                            width = "full",
                        }
                    end

                    return { order = ord, type = "group", name = displayName, args = args }
                end

                local UNIT_FRAME_DEFS = {
                    {
                        "player",
                        1,
                        L.player,
                        {
                            wMin = 100,
                            wMax = 400,
                            hMin = 20,
                            hMax = 100,
                            hasAuras = true,
                            hasPortrait = true,
                            hasCastbar = true,
                        },
                    },
                    {
                        "target",
                        2,
                        L.target,
                        { wMin = 100, wMax = 400, hMin = 20, hMax = 100, hasAuras = true, hasPortrait = true },
                    },
                    {
                        "focus",
                        3,
                        L.focus,
                        { wMin = 80, wMax = 300, hMin = 15, hMax = 80, hasAuras = true, hasPortrait = true },
                    },
                    {
                        "party",
                        4,
                        L.party,
                        { wMin = 80, wMax = 250, hMin = 15, hMax = 60, spacingMax = 20, hasAuras = true },
                    },
                    {
                        "raid",
                        5,
                        L.raid,
                        {
                            wMin = 50,
                            wMax = 150,
                            hMin = 15,
                            hMax = 50,
                            spacingMax = 10,
                            hasAuras = true,
                            hasAutoSwitchSize = true,
                        },
                    },
                    { "boss", 6, L.boss, { wMin = 100, wMax = 300, hMin = 20, hMax = 80, hasAuras = true } },
                }

                local result = {
                    rolePresets = {
                        order = 0,
                        type = "group",
                        name = L["RolePresets"] or "Role Presets",
                        inline = true,
                        args = {
                            desc = {
                                order = 0,
                                type = "description",
                                name = (
                                    L["RolePresetsDesc"] or "Quickly adjust raid/party frame layout for your role."
                                ) .. "\n",
                            },
                            dps = {
                                order = 1,
                                type = "execute",
                                name = L["DPSLayout"] or "DPS Layout",
                                desc = L["DPSLayoutDesc"] or "Compact raid frames, optimized for damage dealers",
                                func = function()
                                    LunarUI:ApplyRolePreset("DAMAGER")
                                    RefreshUI()
                                end,
                                width = 0.8,
                            },
                            tank = {
                                order = 2,
                                type = "execute",
                                name = L["TankLayout"] or "Tank Layout",
                                desc = L["TankLayoutDesc"]
                                    or "Wider frames with larger nameplates for threat awareness",
                                func = function()
                                    LunarUI:ApplyRolePreset("TANK")
                                    RefreshUI()
                                end,
                                width = 0.8,
                            },
                            healer = {
                                order = 3,
                                type = "execute",
                                name = L["HealerLayout"] or "Healer Layout",
                                desc = L["HealerLayoutDesc"] or "Large raid frames centered for heal targeting",
                                func = function()
                                    LunarUI:ApplyRolePreset("HEALER")
                                    RefreshUI()
                                end,
                                width = 0.8,
                            },
                        },
                    },
                }
                for _, def in ipairs(UNIT_FRAME_DEFS) do
                    result[def[1]] = MakeUnitFrameGroup(def[1], def[2], def[3], def[4])
                end
                return result
            end)(),
        },

        -- Action Bars
        actionbars = {
            order = 4,
            type = "group",
            name = L.actionbars,
            desc = L.actionbarsDesc,
            childGroups = "tab",
            args = {
                global = {
                    order = 0,
                    type = "group",
                    name = L["GlobalSettings"] or "Global Settings",
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            desc = L["ActionBarsEnableDesc"]
                                or "Enable LunarUI action bars (disable to use Blizzard default)",
                            get = function()
                                return GetDB().actionbars.enabled
                            end,
                            set = function(_, v)
                                GetDB().actionbars.enabled = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        buttonSize = {
                            order = 2,
                            type = "range",
                            name = L.buttonSize,
                            desc = L["ButtonSizeDesc"] or "Size of action bar buttons in pixels",
                            min = 24,
                            max = 48,
                            step = 1,
                            get = function()
                                return GetDB().actionbars.buttonSize
                            end,
                            set = function(_, v)
                                GetDB().actionbars.buttonSize = v
                                RefreshUI()
                            end,
                        },
                        buttonSpacing = {
                            order = 3,
                            type = "range",
                            name = L["ButtonSpacing"] or "Button Spacing",
                            desc = L["ButtonSpacingDesc"] or "Space between action bar buttons in pixels",
                            min = 0,
                            max = 12,
                            step = 1,
                            get = function()
                                return GetDB().actionbars.buttonSpacing
                            end,
                            set = function(_, v)
                                GetDB().actionbars.buttonSpacing = v
                                RefreshUI()
                            end,
                        },
                        showHotkeys = {
                            order = 4,
                            type = "toggle",
                            name = L["ShowHotkeys"] or "Show Hotkeys",
                            desc = L["ShowHotkeysDesc"] or "Display keybind text on action buttons",
                            get = function()
                                return GetDB().actionbars.showHotkeys
                            end,
                            set = function(_, v)
                                GetDB().actionbars.showHotkeys = v
                                RefreshUI()
                            end,
                        },
                        showMacroNames = {
                            order = 5,
                            type = "toggle",
                            name = L["ShowMacroNames"] or "Show Macro Names",
                            desc = L["ShowMacroNamesDesc"] or "Display macro name text on action buttons",
                            get = function()
                                return GetDB().actionbars.showMacroNames
                            end,
                            set = function(_, v)
                                GetDB().actionbars.showMacroNames = v
                                RefreshUI()
                            end,
                        },
                        outOfRangeColoring = {
                            order = 6,
                            type = "toggle",
                            name = L["OutOfRangeColoring"] or "Out of Range Coloring",
                            desc = L["OutOfRangeColoringDesc"]
                                or "Color action buttons red when the target is out of range",
                            get = function()
                                return GetDB().actionbars.outOfRangeColoring
                            end,
                            set = function(_, v)
                                GetDB().actionbars.outOfRangeColoring = v
                                RefreshUI()
                            end,
                        },
                        fadeHeader = { order = 10, type = "header", name = L["FadeSettings"] or "Fade Settings" },
                        fadeEnabled = {
                            order = 11,
                            type = "toggle",
                            name = L["FadeEnabled"] or "Fade Out of Combat",
                            desc = L["FadeEnabledDesc"] or "Fade action bars when out of combat",
                            get = function()
                                return GetDB().actionbars.fadeEnabled
                            end,
                            set = function(_, v)
                                GetDB().actionbars.fadeEnabled = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        fadeAlpha = {
                            order = 12,
                            type = "range",
                            name = L.fadeAlpha,
                            desc = L["FadeAlphaDesc"] or "Opacity when faded out",
                            min = 0,
                            max = 1,
                            step = 0.05,
                            isPercent = true,
                            disabled = function()
                                return not GetDB().actionbars.fadeEnabled
                            end,
                            get = function()
                                return GetDB().actionbars.fadeAlpha
                            end,
                            set = function(_, v)
                                GetDB().actionbars.fadeAlpha = v
                                RefreshUI()
                            end,
                        },
                        fadeDelay = {
                            order = 13,
                            type = "range",
                            name = L["FadeDelay"] or "Fade Delay",
                            desc = L["FadeDelayDesc"] or "Seconds to wait after leaving combat before fading",
                            min = 0,
                            max = 10,
                            step = 0.5,
                            disabled = function()
                                return not GetDB().actionbars.fadeEnabled
                            end,
                            get = function()
                                return GetDB().actionbars.fadeDelay
                            end,
                            set = function(_, v)
                                GetDB().actionbars.fadeDelay = v
                                RefreshUI()
                            end,
                        },
                        fadeDuration = {
                            order = 14,
                            type = "range",
                            name = L["FadeDuration"] or "Fade Duration",
                            desc = L["FadeDurationDesc"] or "Duration of the fade animation in seconds",
                            min = 0.1,
                            max = 2.0,
                            step = 0.1,
                            disabled = function()
                                return not GetDB().actionbars.fadeEnabled
                            end,
                            get = function()
                                return GetDB().actionbars.fadeDuration
                            end,
                            set = function(_, v)
                                GetDB().actionbars.fadeDuration = v
                                RefreshUI()
                            end,
                        },
                        microBarHeader = { order = 20, type = "header", name = L["MicroBar"] or "Micro Bar" },
                        microBarEnabled = {
                            order = 21,
                            type = "toggle",
                            name = L.enable,
                            desc = L["MicroBarDesc"] or "Show the micro menu bar",
                            get = function()
                                return GetDB().actionbars.microBar.enabled
                            end,
                            set = function(_, v)
                                GetDB().actionbars.microBar.enabled = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                    },
                },
            },
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
                    get = function()
                        return GetDB().nameplates.enabled
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enabled = v
                        RefreshUI()
                    end,
                    width = "full",
                },
                width = {
                    order = 2,
                    type = "range",
                    name = L.width,
                    min = 80,
                    max = 200,
                    step = 5,
                    get = function()
                        return GetDB().nameplates.width
                    end,
                    set = function(_, v)
                        GetDB().nameplates.width = v
                        RefreshUI()
                    end,
                },
                height = {
                    order = 3,
                    type = "range",
                    name = L.height,
                    min = 6,
                    max = 30,
                    step = 1,
                    get = function()
                        return GetDB().nameplates.height
                    end,
                    set = function(_, v)
                        GetDB().nameplates.height = v
                        RefreshUI()
                    end,
                },
                stackingDetection = {
                    order = 4,
                    type = "toggle",
                    name = L.StackingDetection or "Stacking Detection",
                    desc = L.StackingDetectionDesc
                        or "Offset overlapping nameplates so they don't cover each other (requires reload)",
                    get = function()
                        return GetDB().nameplates.stackingDetection
                    end,
                    set = function(_, v)
                        GetDB().nameplates.stackingDetection = v
                        RefreshUI()
                    end,
                },
                showHealthText = {
                    order = 5,
                    type = "toggle",
                    name = L["ShowHealthText"] or "Show Health Text",
                    desc = L["ShowHealthTextDesc"] or "Display health value text on nameplates",
                    get = function()
                        return GetDB().nameplates.showHealthText
                    end,
                    set = function(_, v)
                        GetDB().nameplates.showHealthText = v
                        RefreshUI()
                    end,
                },
                healthTextFormat = {
                    order = 6,
                    type = "select",
                    name = L["HealthTextFormat"] or "Health Text Format",
                    desc = L["HealthTextFormatDesc"] or "Format for health text display",
                    values = {
                        percent = "Percent",
                        current = "Current",
                        both = "Both",
                    },
                    disabled = function()
                        return not GetDB().nameplates.showHealthText
                    end,
                    get = function()
                        return GetDB().nameplates.healthTextFormat
                    end,
                    set = function(_, v)
                        GetDB().nameplates.healthTextFormat = v
                        RefreshUI()
                    end,
                },
                spacer1 = { order = 10, type = "description", name = "\n" },
                enemyHeader = {
                    order = 11,
                    type = "header",
                    name = L.enemyNameplates,
                },
                enemyEnabled = {
                    order = 12,
                    type = "toggle",
                    name = L.enable,
                    get = function()
                        return GetDB().nameplates.enemy.enabled
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enemy.enabled = v
                        RefreshUI()
                    end,
                },
                enemyShowCastbar = {
                    order = 13,
                    type = "toggle",
                    name = L.showCastbar,
                    get = function()
                        return GetDB().nameplates.enemy.showCastbar
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enemy.showCastbar = v
                        RefreshUI()
                    end,
                },
                enemyShowAuras = {
                    order = 14,
                    type = "toggle",
                    name = L.showAuras,
                    get = function()
                        return GetDB().nameplates.enemy.showAuras
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enemy.showAuras = v
                        RefreshUI()
                    end,
                },
                enemyShowLevel = {
                    order = 15,
                    type = "toggle",
                    name = L.NameplateLevel or "Level Text",
                    desc = L.NameplateLevelDesc or "Show level text next to name on enemy nameplates (requires reload)",
                    get = function()
                        return GetDB().nameplates.enemy.showLevel
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enemy.showLevel = v
                        RefreshUI()
                    end,
                },
                enemyShowQuestIcon = {
                    order = 16,
                    type = "toggle",
                    name = L.QuestIcon or "Quest Icon",
                    desc = L.QuestIconDesc or "Show quest objective icon on enemy nameplates (requires reload)",
                    get = function()
                        return GetDB().nameplates.enemy.showQuestIcon
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enemy.showQuestIcon = v
                        RefreshUI()
                    end,
                },
                enemyShowBuffs = {
                    order = 17,
                    type = "toggle",
                    name = L["ShowBuffs"] or "Show Buffs",
                    desc = L["EnemyShowBuffsDesc"] or "Show stealable buffs on enemy nameplates",
                    get = function()
                        return GetDB().nameplates.enemy.showBuffs
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enemy.showBuffs = v
                        RefreshUI()
                    end,
                },
                enemyBuffSize = {
                    order = 18,
                    type = "range",
                    name = L["BuffSize"] or "Buff Size",
                    min = 8,
                    max = 30,
                    step = 1,
                    disabled = function()
                        return not GetDB().nameplates.enemy.showBuffs
                    end,
                    get = function()
                        return GetDB().nameplates.enemy.buffSize
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enemy.buffSize = v
                        RefreshUI()
                    end,
                },
                enemyMaxBuffs = {
                    order = 19,
                    type = "range",
                    name = L["MaxBuffs"] or "Max Buffs",
                    min = 0,
                    max = 8,
                    step = 1,
                    disabled = function()
                        return not GetDB().nameplates.enemy.showBuffs
                    end,
                    get = function()
                        return GetDB().nameplates.enemy.maxBuffs
                    end,
                    set = function(_, v)
                        GetDB().nameplates.enemy.maxBuffs = v
                        RefreshUI()
                    end,
                },
                spacer2 = { order = 20, type = "description", name = "\n" },
                friendlyHeader = {
                    order = 21,
                    type = "header",
                    name = L.friendlyNameplates,
                },
                friendlyEnabled = {
                    order = 22,
                    type = "toggle",
                    name = L.enable,
                    get = function()
                        return GetDB().nameplates.friendly.enabled
                    end,
                    set = function(_, v)
                        GetDB().nameplates.friendly.enabled = v
                        RefreshUI()
                    end,
                },
                friendlyShowHealth = {
                    order = 23,
                    type = "toggle",
                    name = L.showHealth,
                    get = function()
                        return GetDB().nameplates.friendly.showHealth
                    end,
                    set = function(_, v)
                        GetDB().nameplates.friendly.showHealth = v
                        RefreshUI()
                    end,
                },
                friendlyShowLevel = {
                    order = 24,
                    type = "toggle",
                    name = L.NameplateLevel or "Level Text",
                    desc = L.NameplateLevelDesc
                        or "Show level text next to name on friendly nameplates (requires reload)",
                    get = function()
                        return GetDB().nameplates.friendly.showLevel
                    end,
                    set = function(_, v)
                        GetDB().nameplates.friendly.showLevel = v
                        RefreshUI()
                    end,
                },
                spacer3 = { order = 30, type = "description", name = "\n" },
                npcColorsHeader = {
                    order = 31,
                    type = "header",
                    name = L["NpcColors"] or "NPC Colors",
                },
                npcColorsEnabled = {
                    order = 32,
                    type = "toggle",
                    name = L.enable,
                    desc = L["NpcColorsDesc"] or "Color enemy nameplates by NPC role (caster, miniboss, etc.)",
                    get = function()
                        return GetDB().nameplates.npcColors.enabled
                    end,
                    set = function(_, v)
                        GetDB().nameplates.npcColors.enabled = v
                        RefreshUI()
                    end,
                    width = "full",
                },
                spacer4 = { order = 40, type = "description", name = "\n" },
                highlightHeader = {
                    order = 41,
                    type = "header",
                    name = L["Highlight"] or "Highlight",
                },
                highlightRare = {
                    order = 42,
                    type = "toggle",
                    name = L["HighlightRare"] or "Rare",
                    desc = L["HighlightRareDesc"] or "Highlight rare mobs on nameplates",
                    get = function()
                        return GetDB().nameplates.highlight.rare
                    end,
                    set = function(_, v)
                        GetDB().nameplates.highlight.rare = v
                        RefreshUI()
                    end,
                },
                highlightElite = {
                    order = 43,
                    type = "toggle",
                    name = L["HighlightElite"] or "Elite",
                    desc = L["HighlightEliteDesc"] or "Highlight elite mobs on nameplates",
                    get = function()
                        return GetDB().nameplates.highlight.elite
                    end,
                    set = function(_, v)
                        GetDB().nameplates.highlight.elite = v
                        RefreshUI()
                    end,
                },
                highlightBoss = {
                    order = 44,
                    type = "toggle",
                    name = L["HighlightBoss"] or "Boss",
                    desc = L["HighlightBossDesc"] or "Highlight boss mobs on nameplates",
                    get = function()
                        return GetDB().nameplates.highlight.boss
                    end,
                    set = function(_, v)
                        GetDB().nameplates.highlight.boss = v
                        RefreshUI()
                    end,
                },
            },
        },

        -- HUD
        hud = {
            order = 5.5,
            type = "group",
            name = L.hud,
            desc = L.hudDesc,
            childGroups = "tab",
            args = {
                -- 總覽分頁
                overview = {
                    order = 1,
                    type = "group",
                    name = L["HUDOverview"],
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = L["HUDOverviewDesc"],
                        },
                        scale = {
                            order = 1,
                            type = "range",
                            name = L["HUDScale"],
                            desc = L["HUDScaleDesc"],
                            min = 0.5,
                            max = 2.0,
                            step = 0.05,
                            get = function()
                                return GetDB().hud.scale or 1.0
                            end,
                            set = function(_, v)
                                GetDB().hud.scale = v
                                if LunarUI.ApplyHUDScale then
                                    LunarUI:ApplyHUDScale()
                                end
                            end,
                            width = "full",
                        },
                        modulesHeader = {
                            order = 5,
                            type = "header",
                            name = L["HUDModuleToggles"],
                        },
                        performanceMonitor = {
                            order = 10,
                            type = "toggle",
                            name = L["HUDPerfMonitor"],
                            desc = L["HUDPerfMonitorDesc"],
                            get = function()
                                return GetDB().hud.performanceMonitor
                            end,
                            set = function(_, v)
                                GetDB().hud.performanceMonitor = v
                                if v then
                                    if LunarUI.InitPerformanceMonitor then
                                        LunarUI.InitPerformanceMonitor()
                                    end
                                else
                                    if LunarUI.CleanupPerformanceMonitor then
                                        LunarUI.CleanupPerformanceMonitor()
                                    end
                                end
                            end,
                            width = "full",
                        },
                        classResources = {
                            order = 12,
                            type = "toggle",
                            name = L["HUDClassResources"],
                            desc = L["HUDClassResourcesDesc"],
                            get = function()
                                return GetDB().hud.classResources
                            end,
                            set = function(_, v)
                                GetDB().hud.classResources = v
                                if v then
                                    if LunarUI.InitClassResources then
                                        LunarUI.InitClassResources()
                                    end
                                else
                                    if LunarUI.CleanupClassResources then
                                        LunarUI.CleanupClassResources()
                                    end
                                end
                            end,
                            width = "full",
                        },
                        cooldownTracker = {
                            order = 13,
                            type = "toggle",
                            name = L["HUDCooldownTracker"],
                            desc = L["HUDCooldownTrackerDesc"],
                            get = function()
                                return GetDB().hud.cooldownTracker
                            end,
                            set = function(_, v)
                                GetDB().hud.cooldownTracker = v
                                if v then
                                    if LunarUI.InitCooldownTracker then
                                        LunarUI.InitCooldownTracker()
                                    end
                                else
                                    if LunarUI.CleanupCooldownTracker then
                                        LunarUI.CleanupCooldownTracker()
                                    end
                                end
                            end,
                            width = "full",
                        },
                        auraFrames = {
                            order = 14,
                            type = "toggle",
                            name = L["HUDAuraFrames"],
                            desc = L["HUDAuraFramesDesc"],
                            get = function()
                                return GetDB().hud.auraFrames
                            end,
                            set = function(_, v)
                                GetDB().hud.auraFrames = v
                                if v then
                                    if LunarUI.InitAuraFrames then
                                        LunarUI.InitAuraFrames()
                                    end
                                else
                                    if LunarUI.CleanupAuraFrames then
                                        LunarUI.CleanupAuraFrames()
                                    end
                                end
                            end,
                            width = "full",
                        },
                        fctEnabled = {
                            order = 15,
                            type = "toggle",
                            name = L["HUDFCTEnabled"],
                            desc = L["HUDFCTEnabledDesc"],
                            get = function()
                                return GetDB().hud.fctEnabled
                            end,
                            set = function(_, v)
                                GetDB().hud.fctEnabled = v
                                if v then
                                    if LunarUI.InitFCT then
                                        LunarUI.InitFCT()
                                    end
                                else
                                    if LunarUI.CleanupFCT then
                                        LunarUI.CleanupFCT()
                                    end
                                end
                            end,
                            width = "full",
                        },
                        fctWarning = {
                            order = 16,
                            type = "description",
                            name = L["HUDFCTWarning"],
                            hidden = function()
                                return not GetDB().hud.fctEnabled
                            end,
                        },
                    },
                },

                -- 增減益框架分頁
                auraSettings = {
                    order = 2,
                    type = "group",
                    name = L["HUDAuraFrames"],
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = L["HUDAuraSettingsDesc"],
                        },
                        auraIconSize = {
                            order = 1,
                            type = "range",
                            name = L["HUDIconSize"],
                            desc = L["HUDAuraIconSizeDesc"],
                            min = 24,
                            max = 64,
                            step = 2,
                            get = function()
                                return GetDB().hud.auraIconSize
                            end,
                            set = function(_, v)
                                GetDB().hud.auraIconSize = v
                                if LunarUI.RebuildAuraFrames then
                                    LunarUI:RebuildAuraFrames()
                                end
                            end,
                            width = "full",
                        },
                        auraIconSpacing = {
                            order = 2,
                            type = "range",
                            name = L["HUDIconSpacing"],
                            desc = L["HUDIconSpacingDesc"],
                            min = 0,
                            max = 12,
                            step = 1,
                            get = function()
                                return GetDB().hud.auraIconSpacing
                            end,
                            set = function(_, v)
                                GetDB().hud.auraIconSpacing = v
                                if LunarUI.RebuildAuraFrames then
                                    LunarUI:RebuildAuraFrames()
                                end
                            end,
                            width = "full",
                        },
                        auraIconsPerRow = {
                            order = 3,
                            type = "range",
                            name = L["HUDIconsPerRow"],
                            desc = L["HUDIconsPerRowDesc"],
                            min = 4,
                            max = 16,
                            step = 1,
                            get = function()
                                return GetDB().hud.auraIconsPerRow
                            end,
                            set = function(_, v)
                                GetDB().hud.auraIconsPerRow = v
                                if LunarUI.RebuildAuraFrames then
                                    LunarUI:RebuildAuraFrames()
                                end
                            end,
                            width = "full",
                        },
                        maxBuffs = {
                            order = 4,
                            type = "range",
                            name = L["HUDMaxBuffs"],
                            desc = L["HUDMaxBuffsDesc"],
                            min = 4,
                            max = 40,
                            step = 1,
                            get = function()
                                return GetDB().hud.maxBuffs
                            end,
                            set = function(_, v)
                                GetDB().hud.maxBuffs = v
                                if LunarUI.RebuildAuraFrames then
                                    LunarUI:RebuildAuraFrames()
                                end
                            end,
                            width = "full",
                        },
                        maxDebuffs = {
                            order = 5,
                            type = "range",
                            name = L["HUDMaxDebuffs"],
                            desc = L["HUDMaxDebuffsDesc"],
                            min = 4,
                            max = 20,
                            step = 1,
                            get = function()
                                return GetDB().hud.maxDebuffs
                            end,
                            set = function(_, v)
                                GetDB().hud.maxDebuffs = v
                                if LunarUI.RebuildAuraFrames then
                                    LunarUI:RebuildAuraFrames()
                                end
                            end,
                            width = "full",
                        },
                        auraBarHeight = {
                            order = 6,
                            type = "range",
                            name = L["HUDAuraBarHeight"],
                            desc = L["HUDAuraBarHeightDesc"],
                            min = 2,
                            max = 10,
                            step = 1,
                            get = function()
                                return GetDB().hud.auraBarHeight
                            end,
                            set = function(_, v)
                                GetDB().hud.auraBarHeight = v
                                if LunarUI.RebuildAuraFrames then
                                    LunarUI:RebuildAuraFrames()
                                end
                            end,
                            width = "full",
                        },
                    },
                },

                -- 光環過濾分頁
                auraFiltering = {
                    order = 2.5,
                    type = "group",
                    name = L.auraFiltering,
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = L.auraFilteringDesc,
                        },
                        whitelist = {
                            order = 1,
                            type = "input",
                            name = L.auraWhitelist,
                            desc = L.auraWhitelistDesc,
                            multiline = 3,
                            width = "full",
                            get = function()
                                return GetDB().auraWhitelist or ""
                            end,
                            set = function(_, v)
                                GetDB().auraWhitelist = v
                                -- 觸發快取重建
                                if LunarUI.RebuildAuraFilterCache then
                                    LunarUI:RebuildAuraFilterCache()
                                end
                            end,
                        },
                        blacklist = {
                            order = 2,
                            type = "input",
                            name = L.auraBlacklist,
                            desc = L.auraBlacklistDesc,
                            multiline = 3,
                            width = "full",
                            get = function()
                                return GetDB().auraBlacklist or ""
                            end,
                            set = function(_, v)
                                GetDB().auraBlacklist = v
                                if LunarUI.RebuildAuraFilterCache then
                                    LunarUI:RebuildAuraFilterCache()
                                end
                            end,
                        },
                        filterHeader = { order = 10, type = "header", name = L["FilterOptions"] or "Filter Options" },
                        hidePassive = {
                            order = 11,
                            type = "toggle",
                            name = L["HidePassive"] or "Hide Passive",
                            desc = L["HidePassiveDesc"]
                                or "Hide passive effects (buffs lasting more than 5 minutes or permanent)",
                            get = function()
                                return GetDB().auraFilters.hidePassive
                            end,
                            set = function(_, v)
                                GetDB().auraFilters.hidePassive = v
                                if LunarUI.RebuildAuraFilterCache then
                                    LunarUI:RebuildAuraFilterCache()
                                end
                            end,
                        },
                        showStealable = {
                            order = 12,
                            type = "toggle",
                            name = L["ShowStealable"] or "Show Stealable",
                            desc = L["ShowStealableDesc"] or "Show stealable buffs on enemy targets",
                            get = function()
                                return GetDB().auraFilters.showStealable
                            end,
                            set = function(_, v)
                                GetDB().auraFilters.showStealable = v
                                if LunarUI.RebuildAuraFilterCache then
                                    LunarUI:RebuildAuraFilterCache()
                                end
                            end,
                        },
                        sortMethod = {
                            order = 13,
                            type = "select",
                            name = L["SortMethod"] or "Sort Method",
                            desc = L["SortMethodDesc"] or "How to sort auras on unit frames",
                            values = {
                                time = L["SortByTime"] or "Time Remaining",
                                duration = L["SortByDuration"] or "Duration",
                                name = L["SortByName"] or "Name",
                                player = L["SortByPlayer"] or "Player First",
                            },
                            get = function()
                                return GetDB().auraFilters.sortMethod
                            end,
                            set = function(_, v)
                                GetDB().auraFilters.sortMethod = v
                                if LunarUI.RebuildAuraFilterCache then
                                    LunarUI:RebuildAuraFilterCache()
                                end
                            end,
                        },
                        sortReverse = {
                            order = 14,
                            type = "toggle",
                            name = L["SortReverse"] or "Reverse Sort",
                            desc = L["SortReverseDesc"] or "Reverse the aura sort order",
                            get = function()
                                return GetDB().auraFilters.sortReverse
                            end,
                            set = function(_, v)
                                GetDB().auraFilters.sortReverse = v
                                if LunarUI.RebuildAuraFilterCache then
                                    LunarUI:RebuildAuraFilterCache()
                                end
                            end,
                        },
                    },
                },

                -- 冷卻追蹤分頁
                cdSettings = {
                    order = 4,
                    type = "group",
                    name = L["HUDCDSettings"],
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = L["HUDCDSettingsDesc"],
                        },
                        cdIconSize = {
                            order = 1,
                            type = "range",
                            name = L["HUDIconSize"],
                            desc = L["HUDCDIconSizeDesc"],
                            min = 24,
                            max = 56,
                            step = 2,
                            get = function()
                                return GetDB().hud.cdIconSize
                            end,
                            set = function(_, v)
                                GetDB().hud.cdIconSize = v
                                if LunarUI.RebuildCooldownTracker then
                                    LunarUI:RebuildCooldownTracker()
                                end
                            end,
                            width = "full",
                        },
                        cdIconSpacing = {
                            order = 2,
                            type = "range",
                            name = L["HUDIconSpacing"],
                            desc = L["HUDIconSpacingDesc"],
                            min = 0,
                            max = 12,
                            step = 1,
                            get = function()
                                return GetDB().hud.cdIconSpacing
                            end,
                            set = function(_, v)
                                GetDB().hud.cdIconSpacing = v
                                if LunarUI.RebuildCooldownTracker then
                                    LunarUI:RebuildCooldownTracker()
                                end
                            end,
                            width = "full",
                        },
                        cdMaxIcons = {
                            order = 3,
                            type = "range",
                            name = L["HUDCDMaxIcons"],
                            desc = L["HUDCDMaxIconsDesc"],
                            min = 3,
                            max = 16,
                            step = 1,
                            get = function()
                                return GetDB().hud.cdMaxIcons
                            end,
                            set = function(_, v)
                                GetDB().hud.cdMaxIcons = v
                                if LunarUI.RebuildCooldownTracker then
                                    LunarUI:RebuildCooldownTracker()
                                end
                            end,
                            width = "full",
                        },
                    },
                },

                -- 職業資源分頁
                crSettings = {
                    order = 5,
                    type = "group",
                    name = L["HUDClassResources"],
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = L["HUDCRSettingsDesc"],
                        },
                        crIconSize = {
                            order = 1,
                            type = "range",
                            name = L["HUDIconSize"],
                            desc = L["HUDCRIconSizeDesc"],
                            min = 16,
                            max = 48,
                            step = 2,
                            get = function()
                                return GetDB().hud.crIconSize
                            end,
                            set = function(_, v)
                                GetDB().hud.crIconSize = v
                                if LunarUI.RebuildClassResources then
                                    LunarUI:RebuildClassResources()
                                end
                            end,
                            width = "full",
                        },
                        crIconSpacing = {
                            order = 2,
                            type = "range",
                            name = L["HUDIconSpacing"],
                            desc = L["HUDCRIconSpacingDesc"],
                            min = 0,
                            max = 12,
                            step = 1,
                            get = function()
                                return GetDB().hud.crIconSpacing
                            end,
                            set = function(_, v)
                                GetDB().hud.crIconSpacing = v
                                if LunarUI.RebuildClassResources then
                                    LunarUI:RebuildClassResources()
                                end
                            end,
                            width = "full",
                        },
                        crBarHeight = {
                            order = 3,
                            type = "range",
                            name = L["HUDCRBarHeight"],
                            desc = L["HUDCRBarHeightDesc"],
                            min = 4,
                            max = 20,
                            step = 1,
                            get = function()
                                return GetDB().hud.crBarHeight
                            end,
                            set = function(_, v)
                                GetDB().hud.crBarHeight = v
                                if LunarUI.RebuildClassResources then
                                    LunarUI:RebuildClassResources()
                                end
                            end,
                            width = "full",
                        },
                    },
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
                    get = function()
                        return GetDB().minimap.enabled
                    end,
                    set = function(_, v)
                        GetDB().minimap.enabled = v
                    end,
                    width = "full",
                },

                -- Layout
                layoutHeader = {
                    order = 10,
                    type = "header",
                    name = L.layout,
                },
                size = {
                    order = 11,
                    type = "range",
                    name = L.size,
                    min = 120,
                    max = 250,
                    step = 5,
                    get = function()
                        return GetDB().minimap.size
                    end,
                    set = function(_, v)
                        GetDB().minimap.size = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                borderColor = {
                    order = 12,
                    type = "color",
                    name = L.borderColor,
                    hasAlpha = true,
                    get = function()
                        local c = GetDB().minimap.borderColor
                        return c.r, c.g, c.b, c.a
                    end,
                    set = function(_, r, g, b, a)
                        local c = GetDB().minimap.borderColor
                        c.r, c.g, c.b, c.a = r, g, b, a
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                pinScale = {
                    order = 13,
                    type = "range",
                    name = L.pinScale,
                    desc = L.pinScaleDesc,
                    min = 0.5,
                    max = 2.0,
                    step = 0.1,
                    get = function()
                        return GetDB().minimap.pinScale
                    end,
                    set = function(_, v)
                        GetDB().minimap.pinScale = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },

                -- Display
                displayHeader = {
                    order = 20,
                    type = "header",
                    name = L.display,
                },
                showCoords = {
                    order = 21,
                    type = "toggle",
                    name = L.showCoords,
                    get = function()
                        return GetDB().minimap.showCoords
                    end,
                    set = function(_, v)
                        GetDB().minimap.showCoords = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                showClock = {
                    order = 22,
                    type = "toggle",
                    name = L.showClock,
                    get = function()
                        return GetDB().minimap.showClock
                    end,
                    set = function(_, v)
                        GetDB().minimap.showClock = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                clockFormat = {
                    order = 23,
                    type = "select",
                    name = L.clockFormat,
                    values = { ["24h"] = "24-Hour", ["12h"] = "12-Hour" },
                    get = function()
                        return GetDB().minimap.clockFormat
                    end,
                    set = function(_, v)
                        GetDB().minimap.clockFormat = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                zoneTextDisplay = {
                    order = 24,
                    type = "select",
                    name = L.zoneText,
                    desc = L.zoneTextDesc,
                    values = {
                        ["SHOW"] = "Always Show",
                        ["MOUSEOVER"] = "Show on Mouseover",
                        ["HIDE"] = "Hidden",
                    },
                    get = function()
                        return GetDB().minimap.zoneTextDisplay
                    end,
                    set = function(_, v)
                        GetDB().minimap.zoneTextDisplay = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                organizeButtons = {
                    order = 25,
                    type = "toggle",
                    name = L.organizeButtons,
                    get = function()
                        return GetDB().minimap.organizeButtons
                    end,
                    set = function(_, v)
                        GetDB().minimap.organizeButtons = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },

                -- Fonts
                fontHeader = {
                    order = 30,
                    type = "header",
                    name = L.fonts,
                },
                zoneFontSize = {
                    order = 31,
                    type = "range",
                    name = L.zoneTextSize,
                    min = 8,
                    max = 24,
                    step = 1,
                    get = function()
                        return GetDB().minimap.zoneFontSize
                    end,
                    set = function(_, v)
                        GetDB().minimap.zoneFontSize = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                zoneFontOutline = {
                    order = 32,
                    type = "select",
                    name = L.zoneTextOutline,
                    values = {
                        ["NONE"] = "None",
                        ["OUTLINE"] = "Outline",
                        ["THICKOUTLINE"] = "Thick Outline",
                        ["MONOCHROMEOUTLINE"] = "Monochrome",
                    },
                    get = function()
                        return GetDB().minimap.zoneFontOutline
                    end,
                    set = function(_, v)
                        GetDB().minimap.zoneFontOutline = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                coordFontSize = {
                    order = 33,
                    type = "range",
                    name = L.coordClockTextSize,
                    min = 8,
                    max = 18,
                    step = 1,
                    get = function()
                        return GetDB().minimap.coordFontSize
                    end,
                    set = function(_, v)
                        GetDB().minimap.coordFontSize = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },

                -- Behavior
                behaviorHeader = {
                    order = 40,
                    type = "header",
                    name = L.behavior,
                },
                resetZoomTimer = {
                    order = 41,
                    type = "range",
                    name = L.resetZoomTimer,
                    desc = L.resetZoomTimerDesc,
                    min = 0,
                    max = 15,
                    step = 1,
                    get = function()
                        return GetDB().minimap.resetZoomTimer
                    end,
                    set = function(_, v)
                        GetDB().minimap.resetZoomTimer = v
                    end,
                },
                fadeOnMouseLeave = {
                    order = 42,
                    type = "toggle",
                    name = L.fadeOnMouseLeave,
                    desc = L.fadeOnMouseLeaveDesc,
                    get = function()
                        return GetDB().minimap.fadeOnMouseLeave
                    end,
                    set = function(_, v)
                        GetDB().minimap.fadeOnMouseLeave = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                fadeAlpha = {
                    order = 43,
                    type = "range",
                    name = L.fadeAlpha,
                    min = 0.1,
                    max = 0.9,
                    step = 0.05,
                    isPercent = true,
                    disabled = function()
                        return not GetDB().minimap.fadeOnMouseLeave
                    end,
                    get = function()
                        return GetDB().minimap.fadeAlpha
                    end,
                    set = function(_, v)
                        GetDB().minimap.fadeAlpha = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },
                fadeDuration = {
                    order = 44,
                    type = "range",
                    name = L["FadeDuration"] or "Fade Duration",
                    desc = L["MinimapFadeDurationDesc"] or "Duration of the fade animation in seconds",
                    min = 0.1,
                    max = 2.0,
                    step = 0.1,
                    disabled = function()
                        return not GetDB().minimap.fadeOnMouseLeave
                    end,
                    get = function()
                        return GetDB().minimap.fadeDuration
                    end,
                    set = function(_, v)
                        GetDB().minimap.fadeDuration = v
                        if LunarUI.RefreshMinimap then
                            LunarUI:RefreshMinimap()
                        end
                    end,
                },

                -- Icons
                iconsGroup = {
                    order = 50,
                    type = "group",
                    name = L.iconSettings,
                    inline = true,
                    args = (function()
                        local ICON_NAMES = {
                            { key = "calendar", name = "Calendar" },
                            { key = "tracking", name = "Tracking" },
                            { key = "mail", name = "Mail Indicator" },
                            { key = "difficulty", name = "Difficulty Text" },
                            { key = "lfg", name = "LFG Queue" },
                            { key = "expansion", name = "Expansion Button" },
                            { key = "compartment", name = "Addon Compartment" },
                        }

                        local POSITION_VALUES = {
                            TOPLEFT = "Top Left",
                            TOP = "Top",
                            TOPRIGHT = "Top Right",
                            LEFT = "Left",
                            CENTER = "Center",
                            RIGHT = "Right",
                            BOTTOMLEFT = "Bottom Left",
                            BOTTOM = "Bottom",
                            BOTTOMRIGHT = "Bottom Right",
                        }

                        local args = {}
                        for idx, info in ipairs(ICON_NAMES) do
                            local iconKey = info.key
                            local o = idx * 10
                            args[iconKey .. "Header"] = {
                                order = o,
                                type = "header",
                                name = info.name,
                            }
                            args[iconKey .. "Hide"] = {
                                order = o + 1,
                                type = "toggle",
                                name = L.hide,
                                width = "half",
                                get = function()
                                    return GetDB().minimap.icons[iconKey].hide
                                end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].hide = v
                                    if LunarUI.RefreshMinimap then
                                        LunarUI:RefreshMinimap()
                                    end
                                end,
                            }
                            args[iconKey .. "Position"] = {
                                order = o + 2,
                                type = "select",
                                name = L.anchor,
                                values = POSITION_VALUES,
                                disabled = function()
                                    return GetDB().minimap.icons[iconKey].hide
                                end,
                                get = function()
                                    return GetDB().minimap.icons[iconKey].position
                                end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].position = v
                                    if LunarUI.RefreshMinimap then
                                        LunarUI:RefreshMinimap()
                                    end
                                end,
                            }
                            args[iconKey .. "Scale"] = {
                                order = o + 3,
                                type = "range",
                                name = L.scale,
                                min = 0.5,
                                max = 2.0,
                                step = 0.1,
                                disabled = function()
                                    return GetDB().minimap.icons[iconKey].hide
                                end,
                                get = function()
                                    return GetDB().minimap.icons[iconKey].scale
                                end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].scale = v
                                    if LunarUI.RefreshMinimap then
                                        LunarUI:RefreshMinimap()
                                    end
                                end,
                            }
                            args[iconKey .. "XOffset"] = {
                                order = o + 4,
                                type = "range",
                                name = L.xOffset,
                                min = -50,
                                max = 50,
                                step = 1,
                                disabled = function()
                                    return GetDB().minimap.icons[iconKey].hide
                                end,
                                get = function()
                                    return GetDB().minimap.icons[iconKey].xOffset
                                end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].xOffset = v
                                    if LunarUI.RefreshMinimap then
                                        LunarUI:RefreshMinimap()
                                    end
                                end,
                            }
                            args[iconKey .. "YOffset"] = {
                                order = o + 5,
                                type = "range",
                                name = L.yOffset,
                                min = -50,
                                max = 50,
                                step = 1,
                                disabled = function()
                                    return GetDB().minimap.icons[iconKey].hide
                                end,
                                get = function()
                                    return GetDB().minimap.icons[iconKey].yOffset
                                end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].yOffset = v
                                    if LunarUI.RefreshMinimap then
                                        LunarUI:RefreshMinimap()
                                    end
                                end,
                            }
                        end
                        return args
                    end)(),
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
                    get = function()
                        return GetDB().bags.enabled
                    end,
                    set = function(_, v)
                        GetDB().bags.enabled = v
                    end,
                    width = "full",
                },
                layoutHeader = {
                    order = 2,
                    type = "header",
                    name = L.layout,
                },
                slotsPerRow = {
                    order = 3,
                    type = "range",
                    name = L.slotsPerRow,
                    min = 8,
                    max = 16,
                    step = 1,
                    get = function()
                        return GetDB().bags.slotsPerRow
                    end,
                    set = function(_, v)
                        GetDB().bags.slotsPerRow = v
                        if LunarUI.RebuildBags then
                            LunarUI:RebuildBags()
                        end
                    end,
                },
                slotSize = {
                    order = 4,
                    type = "range",
                    name = L.slotSize,
                    min = 28,
                    max = 48,
                    step = 1,
                    get = function()
                        return GetDB().bags.slotSize
                    end,
                    set = function(_, v)
                        GetDB().bags.slotSize = v
                        if LunarUI.RebuildBags then
                            LunarUI:RebuildBags()
                        end
                    end,
                },
                slotSpacing = {
                    order = 5,
                    type = "range",
                    name = L.slotSpacing,
                    min = 0,
                    max = 8,
                    step = 1,
                    get = function()
                        return GetDB().bags.slotSpacing
                    end,
                    set = function(_, v)
                        GetDB().bags.slotSpacing = v
                        if LunarUI.RebuildBags then
                            LunarUI:RebuildBags()
                        end
                    end,
                },
                frameAlpha = {
                    order = 6,
                    type = "range",
                    name = L.backgroundOpacity,
                    min = 0.3,
                    max = 1.0,
                    step = 0.05,
                    isPercent = true,
                    get = function()
                        return GetDB().bags.frameAlpha
                    end,
                    set = function(_, v)
                        GetDB().bags.frameAlpha = v
                        if LunarUI.RebuildBags then
                            LunarUI:RebuildBags()
                        end
                    end,
                },
                reverseBagSlots = {
                    order = 7,
                    type = "toggle",
                    name = L.reverseBagSlots,
                    desc = L.reverseBagSlotsDesc,
                    get = function()
                        return GetDB().bags.reverseBagSlots
                    end,
                    set = function(_, v)
                        GetDB().bags.reverseBagSlots = v
                        if LunarUI.RebuildBags then
                            LunarUI:RebuildBags()
                        end
                    end,
                },
                splitBags = {
                    order = 8,
                    type = "toggle",
                    name = L.splitBags,
                    desc = L.splitBagsDesc,
                    get = function()
                        return GetDB().bags.splitBags
                    end,
                    set = function(_, v)
                        GetDB().bags.splitBags = v
                        if LunarUI.RebuildBags then
                            LunarUI:RebuildBags()
                        end
                    end,
                },
                displayHeader = {
                    order = 10,
                    type = "header",
                    name = L.display,
                },
                showItemLevel = {
                    order = 11,
                    type = "toggle",
                    name = L.showItemLevel,
                    get = function()
                        return GetDB().bags.showItemLevel
                    end,
                    set = function(_, v)
                        GetDB().bags.showItemLevel = v
                    end,
                },
                ilvlThreshold = {
                    order = 12,
                    type = "range",
                    name = L.ilvlThreshold,
                    desc = L.ilvlThresholdDesc,
                    min = 1,
                    max = 600,
                    step = 1,
                    get = function()
                        return GetDB().bags.ilvlThreshold
                    end,
                    set = function(_, v)
                        GetDB().bags.ilvlThreshold = v
                    end,
                },
                showBindType = {
                    order = 13,
                    type = "toggle",
                    name = L.showBindType,
                    desc = L.showBindTypeDesc,
                    get = function()
                        return GetDB().bags.showBindType
                    end,
                    set = function(_, v)
                        GetDB().bags.showBindType = v
                    end,
                },
                showCooldown = {
                    order = 14,
                    type = "toggle",
                    name = L.showCooldowns,
                    desc = L.showCooldownsDesc,
                    get = function()
                        return GetDB().bags.showCooldown
                    end,
                    set = function(_, v)
                        GetDB().bags.showCooldown = v
                    end,
                },
                showNewGlow = {
                    order = 15,
                    type = "toggle",
                    name = L.newItemGlow,
                    desc = L.newItemGlowDesc,
                    get = function()
                        return GetDB().bags.showNewGlow
                    end,
                    set = function(_, v)
                        GetDB().bags.showNewGlow = v
                    end,
                },
                showQuestItems = {
                    order = 16,
                    type = "toggle",
                    name = L.showQuestItems,
                    desc = L.showQuestItemsDesc,
                    get = function()
                        return GetDB().bags.showQuestItems
                    end,
                    set = function(_, v)
                        GetDB().bags.showQuestItems = v
                    end,
                },
                showProfessionColors = {
                    order = 17,
                    type = "toggle",
                    name = L.professionBagColors,
                    desc = L.professionBagColorsDesc,
                    get = function()
                        return GetDB().bags.showProfessionColors
                    end,
                    set = function(_, v)
                        GetDB().bags.showProfessionColors = v
                    end,
                },
                showUpgradeArrow = {
                    order = 18,
                    type = "toggle",
                    name = L.upgradeArrow,
                    desc = L.upgradeArrowDesc,
                    get = function()
                        return GetDB().bags.showUpgradeArrow
                    end,
                    set = function(_, v)
                        GetDB().bags.showUpgradeArrow = v
                    end,
                },
                behaviorHeader = {
                    order = 20,
                    type = "header",
                    name = L.behavior,
                },
                autoSellJunk = {
                    order = 21,
                    type = "toggle",
                    name = L.autoSellJunk,
                    get = function()
                        return GetDB().bags.autoSellJunk
                    end,
                    set = function(_, v)
                        GetDB().bags.autoSellJunk = v
                    end,
                },
                clearSearchOnClose = {
                    order = 22,
                    type = "toggle",
                    name = L.clearSearchOnClose,
                    desc = L.clearSearchOnCloseDesc,
                    get = function()
                        return GetDB().bags.clearSearchOnClose
                    end,
                    set = function(_, v)
                        GetDB().bags.clearSearchOnClose = v
                    end,
                },
                resetPosition = {
                    order = 30,
                    type = "execute",
                    name = L.resetPosition,
                    desc = L.resetPositionDesc,
                    func = function()
                        local bagDb = GetDB().bags
                        bagDb.bagPosition = nil
                        bagDb.bankPosition = nil
                        if LunarUI.RebuildBags then
                            LunarUI:RebuildBags()
                        end
                    end,
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
                    get = function()
                        return GetDB().chat.enabled
                    end,
                    set = function(_, v)
                        GetDB().chat.enabled = v
                    end,
                    width = "full",
                },
                width = {
                    order = 2,
                    type = "range",
                    name = L.width,
                    hidden = true, -- 尚未接到聊天框實際佈局
                    min = 200,
                    max = 600,
                    step = 10,
                    get = function()
                        return GetDB().chat.width
                    end,
                    set = function(_, v)
                        GetDB().chat.width = v
                    end,
                },
                height = {
                    order = 3,
                    type = "range",
                    name = L.height,
                    hidden = true, -- 尚未接到聊天框實際佈局
                    min = 100,
                    max = 400,
                    step = 10,
                    get = function()
                        return GetDB().chat.height
                    end,
                    set = function(_, v)
                        GetDB().chat.height = v
                    end,
                },
                improvedColors = {
                    order = 4,
                    type = "toggle",
                    name = L.improvedColors,
                    get = function()
                        return GetDB().chat.improvedColors
                    end,
                    set = function(_, v)
                        GetDB().chat.improvedColors = v
                    end,
                },
                classColors = {
                    order = 5,
                    type = "toggle",
                    name = L.classColors,
                    get = function()
                        return GetDB().chat.classColors
                    end,
                    set = function(_, v)
                        GetDB().chat.classColors = v
                    end,
                },
                detectURLs = {
                    order = 5.1,
                    type = "toggle",
                    name = L["DetectURLs"] or "Clickable URLs",
                    desc = L["DetectURLsDesc"] or "Make URLs in chat clickable",
                    get = function()
                        return GetDB().chat.detectURLs
                    end,
                    set = function(_, v)
                        GetDB().chat.detectURLs = v
                    end,
                },
                enableEmojis = {
                    order = 5.2,
                    type = "toggle",
                    name = L["EnableEmojis"] or "Emoji Replacement",
                    desc = L["EnableEmojisDesc"] or "Replace text emoticons with emoji icons",
                    get = function()
                        return GetDB().chat.enableEmojis
                    end,
                    set = function(_, v)
                        GetDB().chat.enableEmojis = v
                    end,
                },
                showRoleIcons = {
                    order = 5.3,
                    type = "toggle",
                    name = L["ShowRoleIcons"] or "Role Icons",
                    desc = L["ShowRoleIconsDesc"] or "Show tank/healer/DPS role icons in chat",
                    get = function()
                        return GetDB().chat.showRoleIcons
                    end,
                    set = function(_, v)
                        GetDB().chat.showRoleIcons = v
                    end,
                },
                keywordAlerts = {
                    order = 5.4,
                    type = "toggle",
                    name = L["KeywordAlerts"] or "Keyword Alerts",
                    desc = L["KeywordAlertsDesc"] or "Flash chat frame when keywords are mentioned",
                    get = function()
                        return GetDB().chat.keywordAlerts
                    end,
                    set = function(_, v)
                        GetDB().chat.keywordAlerts = v
                    end,
                },
                spamFilter = {
                    order = 5.5,
                    type = "toggle",
                    name = L["SpamFilter"] or "Spam Filter",
                    desc = L["SpamFilterDesc"] or "Filter duplicate and spam messages",
                    get = function()
                        return GetDB().chat.spamFilter
                    end,
                    set = function(_, v)
                        GetDB().chat.spamFilter = v
                    end,
                },
                linkTooltipPreview = {
                    order = 5.6,
                    type = "toggle",
                    name = L["LinkTooltipPreview"] or "Link Tooltip Preview",
                    desc = L["LinkTooltipPreviewDesc"]
                        or "Show tooltip preview when hovering over item/spell links in chat",
                    get = function()
                        return GetDB().chat.linkTooltipPreview
                    end,
                    set = function(_, v)
                        GetDB().chat.linkTooltipPreview = v
                    end,
                },
                showTimestamps = {
                    order = 5.7,
                    type = "toggle",
                    name = L["ShowTimestamps"] or "Show Timestamps",
                    desc = L["ShowTimestampsDesc"] or "Show timestamps on chat messages",
                    get = function()
                        return GetDB().chat.showTimestamps
                    end,
                    set = function(_, v)
                        GetDB().chat.showTimestamps = v
                    end,
                },
                timestampFormat = {
                    order = 5.8,
                    type = "input",
                    name = L["TimestampFormat"] or "Timestamp Format",
                    desc = L["TimestampFormatDesc"] or "strftime format string for timestamps (e.g. %H:%M, %I:%M %p)",
                    disabled = function()
                        return not GetDB().chat.showTimestamps
                    end,
                    get = function()
                        return GetDB().chat.timestampFormat
                    end,
                    set = function(_, v)
                        GetDB().chat.timestampFormat = v
                    end,
                },
                fadeTime = {
                    order = 9,
                    type = "range",
                    name = L.fadeTime,
                    desc = L.fadeTimeDesc,
                    min = 0,
                    max = 600,
                    step = 10,
                    get = function()
                        return GetDB().chat.fadeTime
                    end,
                    set = function(_, v)
                        GetDB().chat.fadeTime = v
                        local ft = v <= 0 and 86400 or v
                        for i = 1, NUM_CHAT_WINDOWS do
                            local cf = _G["ChatFrame" .. i]
                            if cf and cf.SetTimeVisible then
                                cf:SetTimeVisible(ft)
                            end
                        end
                    end,
                },
                backdropAlpha = {
                    order = 10,
                    type = "range",
                    name = L.backdropAlpha,
                    desc = L.backdropAlphaDesc,
                    min = 0,
                    max = 1,
                    step = 0.05,
                    get = function()
                        return GetDB().chat.backdropAlpha
                    end,
                    set = function(_, v)
                        GetDB().chat.backdropAlpha = v
                        local C = LunarUI.Colors
                        for i = 1, NUM_CHAT_WINDOWS do
                            local cf = _G["ChatFrame" .. i]
                            if cf and cf.LunarBackdrop then
                                cf.LunarBackdrop:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], v)
                            end
                        end
                    end,
                },
                inactiveTabAlpha = {
                    order = 11,
                    type = "range",
                    name = L.inactiveTabAlpha,
                    desc = L.inactiveTabAlphaDesc,
                    min = 0.1,
                    max = 1,
                    step = 0.05,
                    get = function()
                        return GetDB().chat.inactiveTabAlpha
                    end,
                    set = function(_, v)
                        GetDB().chat.inactiveTabAlpha = v
                        -- 立即更新所有 tab 狀態
                        for i = 1, NUM_CHAT_WINDOWS do
                            local tab = _G["ChatFrame" .. i .. "Tab"]
                            if tab and tab._lunarUpdateActive then
                                tab._lunarUpdateActive()
                            end
                        end
                    end,
                },
                editBoxOffset = {
                    order = 12,
                    type = "range",
                    name = L.editBoxOffset,
                    desc = L.editBoxOffsetDesc .. " (requires reload)",
                    min = 0,
                    max = 20,
                    step = 1,
                    get = function()
                        return GetDB().chat.editBoxOffset
                    end,
                    set = function(_, v)
                        GetDB().chat.editBoxOffset = v
                    end,
                },
                spacerKeywords = { order = 13, type = "description", name = "\n" },
                keywords = {
                    order = 14,
                    type = "input",
                    name = L.chatKeywords,
                    desc = L.chatKeywordsDesc,
                    multiline = false,
                    width = "full",
                    get = function()
                        local kw = GetDB().chat.keywords
                        if type(kw) ~= "table" then
                            return ""
                        end
                        return table.concat(kw, ", ")
                    end,
                    set = function(_, v)
                        local list = {}
                        for word in v:gmatch("[^,]+") do
                            word = word:match("^%s*(.-)%s*$") -- trim
                            if word and word ~= "" then
                                list[#list + 1] = word
                            end
                        end
                        GetDB().chat.keywords = list
                    end,
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
                    get = function()
                        return GetDB().tooltip.enabled
                    end,
                    set = function(_, v)
                        GetDB().tooltip.enabled = v
                    end,
                    width = "full",
                },
                anchorCursor = {
                    order = 2,
                    type = "toggle",
                    name = L.anchorToCursor,
                    get = function()
                        return GetDB().tooltip.anchorCursor
                    end,
                    set = function(_, v)
                        GetDB().tooltip.anchorCursor = v
                    end,
                },
                showItemLevel = {
                    order = 3,
                    type = "toggle",
                    name = L.showItemLevel,
                    get = function()
                        return GetDB().tooltip.showItemLevel
                    end,
                    set = function(_, v)
                        GetDB().tooltip.showItemLevel = v
                    end,
                },
                showSpellID = {
                    order = 4,
                    type = "toggle",
                    name = L.showSpellID,
                    get = function()
                        return GetDB().tooltip.showSpellID
                    end,
                    set = function(_, v)
                        GetDB().tooltip.showSpellID = v
                    end,
                },
                showItemID = {
                    order = 5,
                    type = "toggle",
                    name = L.showItemID,
                    get = function()
                        return GetDB().tooltip.showItemID
                    end,
                    set = function(_, v)
                        GetDB().tooltip.showItemID = v
                    end,
                },
                showTargetTarget = {
                    order = 6,
                    type = "toggle",
                    name = L.showTargetTarget,
                    get = function()
                        return GetDB().tooltip.showTargetTarget
                    end,
                    set = function(_, v)
                        GetDB().tooltip.showTargetTarget = v
                    end,
                },
                showItemCount = {
                    order = 7,
                    type = "toggle",
                    name = L["ShowItemCount"] or "Show Item Count",
                    desc = L["ShowItemCountDesc"] or "Show how many of an item you own across your characters",
                    get = function()
                        return GetDB().tooltip.showItemCount
                    end,
                    set = function(_, v)
                        GetDB().tooltip.showItemCount = v
                    end,
                },
            },
        },

        -- 框架移動器
        frameMover = {
            order = 9.5,
            type = "group",
            name = L["FrameMover"],
            desc = L["FrameMoverDesc"],
            args = {
                desc = {
                    order = 0,
                    type = "description",
                    name = L["FrameMoverSettingsDesc"],
                },
                gridSize = {
                    order = 1,
                    type = "range",
                    name = L["GridSize"],
                    desc = L["GridSizeDesc"],
                    min = 1,
                    max = 40,
                    step = 1,
                    get = function()
                        local db = GetDB()
                        return db and db.frameMover and db.frameMover.gridSize or 10
                    end,
                    set = function(_, v)
                        local db = GetDB()
                        if not db then
                            return
                        end
                        if not db.frameMover then
                            db.frameMover = {}
                        end
                        db.frameMover.gridSize = v
                        if LunarUI.LoadFrameMoverSettings then
                            LunarUI.LoadFrameMoverSettings()
                        end
                    end,
                    width = "full",
                },
                moverAlpha = {
                    order = 2,
                    type = "range",
                    name = L["MoverAlpha"],
                    desc = L["MoverAlphaDesc"],
                    min = 0.1,
                    max = 1.0,
                    step = 0.05,
                    get = function()
                        local db = GetDB()
                        return db and db.frameMover and db.frameMover.moverAlpha or 0.6
                    end,
                    set = function(_, v)
                        local db = GetDB()
                        if not db then
                            return
                        end
                        if not db.frameMover then
                            db.frameMover = {}
                        end
                        db.frameMover.moverAlpha = v
                        if LunarUI.LoadFrameMoverSettings then
                            LunarUI.LoadFrameMoverSettings()
                        end
                    end,
                    width = "full",
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
                font = {
                    order = 1,
                    type = "select",
                    name = L.font,
                    desc = L.fontDesc,
                    values = function()
                        local LSM = LibStub("LibSharedMedia-3.0", true)
                        if not LSM then
                            return {}
                        end
                        local fonts = LSM:List("font")
                        local t = {}
                        for _, name in ipairs(fonts) do
                            t[name] = name
                        end
                        return t
                    end,
                    get = function()
                        return GetDB().style.font
                    end,
                    set = function(_, v)
                        GetDB().style.font = v
                        RefreshUI()
                    end,
                    width = "full",
                },
                statusBarTexture = {
                    order = 2,
                    type = "select",
                    name = L.statusBarTexture,
                    desc = L.statusBarTextureDesc,
                    values = function()
                        local LSM = LibStub("LibSharedMedia-3.0", true)
                        if not LSM then
                            return {}
                        end
                        local bars = LSM:List("statusbar")
                        local t = {}
                        for _, name in ipairs(bars) do
                            t[name] = name
                        end
                        return t
                    end,
                    get = function()
                        return GetDB().style.statusBarTexture
                    end,
                    set = function(_, v)
                        GetDB().style.statusBarTexture = v
                        RefreshUI()
                    end,
                    width = "full",
                },
                -- theme/fontSize/borderStyle 已移除（無生產代碼消費）
            },
        },
        -- Loot
        loot = {
            order = 10.3,
            type = "group",
            name = L["LootFrame"] or "Loot Frame",
            desc = L["LootFrameDesc"] or "Custom loot frame settings",
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L["LootFrame"] or "Custom Loot Frame",
                    desc = L["LootFrameDesc"]
                        or "Replace the default loot window with a LunarUI-styled frame (requires reload)",
                    get = function()
                        local db = GetDB()
                        return db and db.loot and db.loot.enabled
                    end,
                    set = function(_, v)
                        local db = GetDB()
                        if db and db.loot then
                            db.loot.enabled = v
                        end
                    end,
                    width = "full",
                },
            },
        },
        -- Data Bars
        databars = {
            order = 10.35,
            type = "group",
            name = L["DataBars"] or "Data Bars",
            desc = L["DataBarsDesc"] or "Experience, reputation, and honor bar settings",
            childGroups = "tab",
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    desc = L["DataBarsEnableDesc"] or "Enable LunarUI data bars",
                    get = function()
                        return GetDB().databars.enabled
                    end,
                    set = function(_, v)
                        GetDB().databars.enabled = v
                        RefreshUI()
                    end,
                    width = "full",
                },
                experience = {
                    order = 2,
                    type = "group",
                    name = L["Experience"] or "Experience",
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function()
                                return GetDB().databars.experience.enabled
                            end,
                            set = function(_, v)
                                GetDB().databars.experience.enabled = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        textFormat = {
                            order = 2,
                            type = "select",
                            name = L["TextFormat"] or "Text Format",
                            values = {
                                percent = "Percent",
                                curmax = "Current / Max",
                                cur = "Current",
                                remaining = "Remaining",
                            },
                            get = function()
                                return GetDB().databars.experience.textFormat
                            end,
                            set = function(_, v)
                                GetDB().databars.experience.textFormat = v
                                RefreshUI()
                            end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 4,
                            max = 20,
                            step = 1,
                            get = function()
                                return GetDB().databars.experience.height
                            end,
                            set = function(_, v)
                                GetDB().databars.experience.height = v
                                RefreshUI()
                            end,
                        },
                    },
                },
                reputation = {
                    order = 3,
                    type = "group",
                    name = L["Reputation"] or "Reputation",
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function()
                                return GetDB().databars.reputation.enabled
                            end,
                            set = function(_, v)
                                GetDB().databars.reputation.enabled = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        textFormat = {
                            order = 2,
                            type = "select",
                            name = L["TextFormat"] or "Text Format",
                            values = {
                                percent = "Percent",
                                curmax = "Current / Max",
                                cur = "Current",
                                remaining = "Remaining",
                            },
                            get = function()
                                return GetDB().databars.reputation.textFormat
                            end,
                            set = function(_, v)
                                GetDB().databars.reputation.textFormat = v
                                RefreshUI()
                            end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 4,
                            max = 20,
                            step = 1,
                            get = function()
                                return GetDB().databars.reputation.height
                            end,
                            set = function(_, v)
                                GetDB().databars.reputation.height = v
                                RefreshUI()
                            end,
                        },
                    },
                },
                honor = {
                    order = 4,
                    type = "group",
                    name = L["Honor"] or "Honor",
                    args = {
                        enabled = {
                            order = 1,
                            type = "toggle",
                            name = L.enable,
                            get = function()
                                return GetDB().databars.honor.enabled
                            end,
                            set = function(_, v)
                                GetDB().databars.honor.enabled = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        textFormat = {
                            order = 2,
                            type = "select",
                            name = L["TextFormat"] or "Text Format",
                            values = {
                                percent = "Percent",
                                curmax = "Current / Max",
                                cur = "Current",
                                remaining = "Remaining",
                            },
                            get = function()
                                return GetDB().databars.honor.textFormat
                            end,
                            set = function(_, v)
                                GetDB().databars.honor.textFormat = v
                                RefreshUI()
                            end,
                        },
                        height = {
                            order = 3,
                            type = "range",
                            name = L.height,
                            min = 4,
                            max = 20,
                            step = 1,
                            get = function()
                                return GetDB().databars.honor.height
                            end,
                            set = function(_, v)
                                GetDB().databars.honor.height = v
                                RefreshUI()
                            end,
                        },
                    },
                },
            },
        },

        -- Data Texts
        datatexts = {
            order = 10.4,
            type = "group",
            name = L["DataTexts"] or "Data Texts",
            desc = L["DataTextsDesc"] or "Information panels displayed at the bottom of the screen",
            args = (function()
                local DATATEXT_VALUES = {
                    fps = "FPS",
                    latency = "Latency",
                    gold = "Gold",
                    durability = "Durability",
                    bagSlots = "Bag Slots",
                    friends = "Friends",
                    guild = "Guild",
                    spec = "Specialization",
                    clock = "Clock",
                    coords = "Coordinates",
                    none = "None",
                }

                local dtArgs = {
                    enabled = {
                        order = 1,
                        type = "toggle",
                        name = L.enable,
                        desc = L["DataTextsEnableDesc"] or "Enable LunarUI data text panels",
                        get = function()
                            return GetDB().datatexts.enabled
                        end,
                        set = function(_, v)
                            GetDB().datatexts.enabled = v
                            RefreshUI()
                        end,
                        width = "full",
                    },
                    bottomHeader = { order = 10, type = "header", name = L["BottomPanel"] or "Bottom Panel" },
                    bottomEnabled = {
                        order = 11,
                        type = "toggle",
                        name = L.enable,
                        get = function()
                            return GetDB().datatexts.panels.bottom.enabled
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.bottom.enabled = v
                            RefreshUI()
                        end,
                    },
                    bottomHeight = {
                        order = 12,
                        type = "range",
                        name = L.height,
                        min = 16,
                        max = 40,
                        step = 1,
                        get = function()
                            return GetDB().datatexts.panels.bottom.height
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.bottom.height = v
                            RefreshUI()
                        end,
                    },
                    bottomLeft = {
                        order = 13,
                        type = "select",
                        name = L["SlotLeft"] or "Left Slot",
                        values = DATATEXT_VALUES,
                        get = function()
                            return GetDB().datatexts.panels.bottom.slots[1] or "none"
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.bottom.slots[1] = v
                            RefreshUI()
                        end,
                    },
                    bottomCenter = {
                        order = 14,
                        type = "select",
                        name = L["SlotCenter"] or "Center Slot",
                        values = DATATEXT_VALUES,
                        get = function()
                            return GetDB().datatexts.panels.bottom.slots[2] or "none"
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.bottom.slots[2] = v
                            RefreshUI()
                        end,
                    },
                    bottomRight = {
                        order = 15,
                        type = "select",
                        name = L["SlotRight"] or "Right Slot",
                        values = DATATEXT_VALUES,
                        get = function()
                            return GetDB().datatexts.panels.bottom.slots[3] or "none"
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.bottom.slots[3] = v
                            RefreshUI()
                        end,
                    },
                    minimapHeader = {
                        order = 20,
                        type = "header",
                        name = L["MinimapBottomPanel"] or "Minimap Bottom Panel",
                    },
                    minimapEnabled = {
                        order = 21,
                        type = "toggle",
                        name = L.enable,
                        get = function()
                            return GetDB().datatexts.panels.minimapBottom.enabled
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.minimapBottom.enabled = v
                            RefreshUI()
                        end,
                    },
                    minimapHeight = {
                        order = 22,
                        type = "range",
                        name = L.height,
                        min = 14,
                        max = 32,
                        step = 1,
                        get = function()
                            return GetDB().datatexts.panels.minimapBottom.height
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.minimapBottom.height = v
                            RefreshUI()
                        end,
                    },
                    minimapLeft = {
                        order = 23,
                        type = "select",
                        name = L["SlotLeft"] or "Left Slot",
                        values = DATATEXT_VALUES,
                        get = function()
                            return GetDB().datatexts.panels.minimapBottom.slots[1] or "none"
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.minimapBottom.slots[1] = v
                            RefreshUI()
                        end,
                    },
                    minimapRight = {
                        order = 24,
                        type = "select",
                        name = L["SlotRight"] or "Right Slot",
                        values = DATATEXT_VALUES,
                        get = function()
                            return GetDB().datatexts.panels.minimapBottom.slots[2] or "none"
                        end,
                        set = function(_, v)
                            GetDB().datatexts.panels.minimapBottom.slots[2] = v
                            RefreshUI()
                        end,
                    },
                }

                return dtArgs
            end)(),
        },

        -- Automation
        automation = {
            order = 10.5,
            type = "group",
            name = L.automation,
            desc = L.automationDesc,
            args = {
                desc = {
                    order = 0,
                    type = "description",
                    name = L.automationHeader,
                },
                autoRepair = {
                    order = 1,
                    type = "toggle",
                    name = L.autoRepair,
                    desc = L.autoRepairDesc,
                    get = function()
                        return GetDB().automation.autoRepair
                    end,
                    set = function(_, v)
                        GetDB().automation.autoRepair = v
                    end,
                    width = "full",
                },
                useGuildRepair = {
                    order = 2,
                    type = "toggle",
                    name = L.useGuildFunds,
                    desc = L.useGuildFundsDesc,
                    disabled = function()
                        return not GetDB().automation.autoRepair
                    end,
                    get = function()
                        return GetDB().automation.useGuildRepair
                    end,
                    set = function(_, v)
                        GetDB().automation.useGuildRepair = v
                    end,
                    width = "full",
                },
                spacer1 = { order = 5, type = "description", name = "\n" },
                autoRelease = {
                    order = 6,
                    type = "toggle",
                    name = L.autoRelease,
                    desc = L.autoReleaseDesc,
                    get = function()
                        return GetDB().automation.autoRelease
                    end,
                    set = function(_, v)
                        GetDB().automation.autoRelease = v
                    end,
                    width = "full",
                },
                spacer2 = { order = 10, type = "description", name = "\n" },
                autoScreenshot = {
                    order = 11,
                    type = "toggle",
                    name = L.achievementScreenshot,
                    desc = L.achievementScreenshotDesc,
                    get = function()
                        return GetDB().automation.autoScreenshot
                    end,
                    set = function(_, v)
                        GetDB().automation.autoScreenshot = v
                    end,
                    width = "full",
                },
                spacer3 = { order = 12, type = "description", name = "\n" },
                autoAcceptQuest = {
                    order = 13,
                    type = "toggle",
                    name = L.autoAcceptQuest,
                    desc = L.autoAcceptQuestDesc,
                    get = function()
                        return GetDB().automation.autoAcceptQuest
                    end,
                    set = function(_, v)
                        GetDB().automation.autoAcceptQuest = v
                    end,
                    width = "full",
                },
                autoAcceptQueue = {
                    order = 14,
                    type = "toggle",
                    name = L.autoAcceptQueue,
                    desc = L.autoAcceptQueueDesc,
                    get = function()
                        return GetDB().automation.autoAcceptQueue
                    end,
                    set = function(_, v)
                        GetDB().automation.autoAcceptQueue = v
                    end,
                    width = "full",
                },
            },
        },

        -- Skins
        skins = {
            order = 11,
            type = "group",
            name = L.skins,
            desc = L.skinsDesc,
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    desc = L.skinsDesc,
                    get = function()
                        return GetDB().skins.enabled
                    end,
                    set = function(_, v)
                        GetDB().skins.enabled = v
                    end,
                    width = "full",
                },
                character = {
                    order = 2,
                    type = "toggle",
                    name = L.skinCharacter,
                    get = function()
                        return GetDB().skins.blizzard.character
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.character = v
                    end,
                },
                spellbook = {
                    order = 3,
                    type = "toggle",
                    name = L.skinSpellbook,
                    get = function()
                        return GetDB().skins.blizzard.spellbook
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.spellbook = v
                    end,
                },
                talents = {
                    order = 4,
                    type = "toggle",
                    name = L.skinTalents,
                    get = function()
                        return GetDB().skins.blizzard.talents
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.talents = v
                    end,
                },
                quest = {
                    order = 5,
                    type = "toggle",
                    name = L.skinQuest,
                    get = function()
                        return GetDB().skins.blizzard.quest
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.quest = v
                    end,
                },
                merchant = {
                    order = 6,
                    type = "toggle",
                    name = L.skinMerchant,
                    get = function()
                        return GetDB().skins.blizzard.merchant
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.merchant = v
                    end,
                },
                gossip = {
                    order = 7,
                    type = "toggle",
                    name = L.skinGossip,
                    get = function()
                        return GetDB().skins.blizzard.gossip
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.gossip = v
                    end,
                },
                worldmap = {
                    order = 8,
                    type = "toggle",
                    name = L.skinWorldMap,
                    get = function()
                        return GetDB().skins.blizzard.worldmap
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.worldmap = v
                    end,
                },
                achievements = {
                    order = 9,
                    type = "toggle",
                    name = L.skinAchievements,
                    get = function()
                        return GetDB().skins.blizzard.achievements
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.achievements = v
                    end,
                },
                mail = {
                    order = 10,
                    type = "toggle",
                    name = L.skinMail,
                    get = function()
                        return GetDB().skins.blizzard.mail
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.mail = v
                    end,
                },
                collections = {
                    order = 11,
                    type = "toggle",
                    name = L.skinCollections,
                    get = function()
                        return GetDB().skins.blizzard.collections
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.collections = v
                    end,
                },
                lfg = {
                    order = 12,
                    type = "toggle",
                    name = L.skinLFG,
                    get = function()
                        return GetDB().skins.blizzard.lfg
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.lfg = v
                    end,
                },
                encounterjournal = {
                    order = 13,
                    type = "toggle",
                    name = L.skinEncounterJournal,
                    get = function()
                        return GetDB().skins.blizzard.encounterjournal
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.encounterjournal = v
                    end,
                },
                auctionhouse = {
                    order = 14,
                    type = "toggle",
                    name = L.skinAuctionHouse,
                    get = function()
                        return GetDB().skins.blizzard.auctionhouse
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.auctionhouse = v
                    end,
                },
                communities = {
                    order = 15,
                    type = "toggle",
                    name = L.skinCommunities,
                    get = function()
                        return GetDB().skins.blizzard.communities
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.communities = v
                    end,
                },
                calendar = {
                    order = 16,
                    type = "toggle",
                    name = L.skinCalendar,
                    get = function()
                        return GetDB().skins.blizzard.calendar
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.calendar = v
                    end,
                },
                weeklyrewards = {
                    order = 17,
                    type = "toggle",
                    name = L.skinWeeklyRewards,
                    get = function()
                        return GetDB().skins.blizzard.weeklyrewards
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.weeklyrewards = v
                    end,
                },
                addonlist = {
                    order = 18,
                    type = "toggle",
                    name = L.skinAddonList,
                    get = function()
                        return GetDB().skins.blizzard.addonlist
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.addonlist = v
                    end,
                },
                housing = {
                    order = 19,
                    type = "toggle",
                    name = L.skinHousing,
                    get = function()
                        return GetDB().skins.blizzard.housing
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.housing = v
                    end,
                },
                professions = {
                    order = 20,
                    type = "toggle",
                    name = L.skinProfessions,
                    get = function()
                        return GetDB().skins.blizzard.professions
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.professions = v
                    end,
                },
                pvp = {
                    order = 21,
                    type = "toggle",
                    name = L.skinPVP,
                    get = function()
                        return GetDB().skins.blizzard.pvp
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.pvp = v
                    end,
                },
                settings = {
                    order = 22,
                    type = "toggle",
                    name = L.skinSettings,
                    get = function()
                        return GetDB().skins.blizzard.settings
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.settings = v
                    end,
                },
                trade = {
                    order = 23,
                    type = "toggle",
                    name = L.skinTrade,
                    get = function()
                        return GetDB().skins.blizzard.trade
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.trade = v
                    end,
                },
                questmap = {
                    order = 24,
                    type = "toggle",
                    name = L.skinQuestMap,
                    get = function()
                        return GetDB().skins.blizzard.questmap
                    end,
                    set = function(_, v)
                        GetDB().skins.blizzard.questmap = v
                    end,
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
                get = function()
                    return GetDB().actionbars["bar" .. i].enabled
                end,
                set = function(_, v)
                    GetDB().actionbars["bar" .. i].enabled = v
                    RefreshUI()
                end,
                width = "full",
            },
            buttons = {
                order = 2,
                type = "range",
                name = L.buttons,
                min = 1,
                max = 12,
                step = 1,
                get = function()
                    return GetDB().actionbars["bar" .. i].buttons
                end,
                set = function(_, v)
                    GetDB().actionbars["bar" .. i].buttons = v
                    RefreshUI()
                end,
            },
        },
    }
end

-- Add pet bar and stance bar
options.args.actionbars.args.petbar = {
    order = 10,
    type = "group",
    name = L.petBar,
    args = {
        enabled = {
            order = 1,
            type = "toggle",
            name = L.enable,
            get = function()
                return GetDB().actionbars.petbar.enabled
            end,
            set = function(_, v)
                GetDB().actionbars.petbar.enabled = v
                RefreshUI()
            end,
            width = "full",
        },
    },
}

options.args.actionbars.args.stancebar = {
    order = 11,
    type = "group",
    name = L.stanceBar,
    args = {
        enabled = {
            order = 1,
            type = "toggle",
            name = L.enable,
            get = function()
                return GetDB().actionbars.stancebar.enabled
            end,
            set = function(_, v)
                GetDB().actionbars.stancebar.enabled = v
                RefreshUI()
            end,
            width = "full",
        },
    },
}

--------------------------------------------------------------------------------
-- Options 搜尋功能
--------------------------------------------------------------------------------

local searchIndex = nil
local searchFrame = nil
local searchTimer = nil

--- 安全取得可能為函數的 AceConfig 欄位值
--- AceConfig 的 name/desc 回呼期望 (info) 參數，此處無法提供，以 pcall 保護
local function SafeGetField(field)
    if type(field) == "function" then
        local ok, val = pcall(field)
        return ok and type(val) == "string" and val or ""
    end
    return type(field) == "string" and field or ""
end

--- 淺拷貝 table 陣列部分
local function CopyPath(src)
    local copy = {}
    for i = 1, #src do
        copy[i] = src[i]
    end
    return copy
end

--- 遞迴走訪 options.args 表，建構搜尋索引
--- @param args table      AceConfig args 表
--- @param breadcrumbs string 當前的麵包屑路徑（"General > Debug"）
--- @param groupPath table   當前的 group key 路徑（{"general"}）
local function BuildSearchIndex(args, breadcrumbs, groupPath)
    local results = {}
    if not args then
        return results
    end

    for key, entry in pairs(args) do
        if type(entry) == "table" and entry.type then
            local name = SafeGetField(entry.name)
            local desc = SafeGetField(entry.desc)

            -- 去除 WoW 色碼（|cXXXXXXXX ... |r）
            local cleanName = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local cleanDesc = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

            if entry.type == "group" then
                local newCrumbs = breadcrumbs ~= "" and (breadcrumbs .. " > " .. cleanName) or cleanName
                local newPath = CopyPath(groupPath)
                newPath[#newPath + 1] = key

                results[#results + 1] = {
                    name = cleanName,
                    desc = cleanDesc,
                    breadcrumbs = newCrumbs,
                    path = newPath,
                    isGroup = true,
                }

                -- 遞迴進入子 args
                if type(entry.args) == "table" then
                    local subResults = BuildSearchIndex(entry.args, newCrumbs, newPath)
                    for _, r in ipairs(subResults) do
                        results[#results + 1] = r
                    end
                end
            elseif entry.type ~= "header" and entry.type ~= "description" then
                -- 葉節點設定項（toggle, range, select, execute 等）
                local crumb = breadcrumbs ~= "" and (breadcrumbs .. " > " .. cleanName) or cleanName
                results[#results + 1] = {
                    name = cleanName,
                    desc = cleanDesc,
                    breadcrumbs = crumb,
                    path = CopyPath(groupPath), -- 導航到父 group（淺拷貝防止共用參照）
                    isGroup = false,
                }
            end
        end
    end

    return results
end

--- 重建搜尋索引（每次開啟面板時呼叫，確保索引反映最新狀態）
local function RebuildSearchIndex()
    searchIndex = BuildSearchIndex(options.args, "", {})
end

--- 模糊匹配過濾搜尋結果
--- @param query string 使用者輸入的搜尋文字
--- @return table 過濾後的搜尋結果
local function FilterSearchResults(query)
    if not searchIndex then
        RebuildSearchIndex()
    end

    if not query or query == "" then
        return {}
    end

    query = query:lower()
    local matches = {}

    for _, entry in ipairs(searchIndex) do
        local nameMatch = entry.name:lower():find(query, 1, true)
        local descMatch = entry.desc:lower():find(query, 1, true)
        local crumbMatch = entry.breadcrumbs:lower():find(query, 1, true)

        if nameMatch or descMatch or crumbMatch then
            -- 優先順序：名稱匹配 > 描述匹配 > 麵包屑匹配
            local priority = nameMatch and 1 or (descMatch and 2 or 3)
            matches[#matches + 1] = {
                entry = entry,
                priority = priority,
            }
        end
    end

    -- 排序：priority 升序，同 priority 按名稱字母序
    table.sort(matches, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.entry.name < b.entry.name
    end)

    -- 限制最多 20 筆結果
    local limited = {}
    for i = 1, min(#matches, 20) do
        limited[i] = matches[i].entry
    end

    return limited
end

--- 建立搜尋 UI（EditBox + 結果清單疊層）
--- @param dialogFrame Frame AceConfigDialog 的實際框架
local function CreateSearchUI(dialogFrame)
    -- 每次開啟時重建索引，確保反映最新的 options 狀態
    RebuildSearchIndex()

    -- 若搜尋框已存在且父框架相同，直接顯示
    if searchFrame then
        if searchFrame:GetParent() == dialogFrame then
            searchFrame:Show()
            return
        end
        -- 父框架已變更（AceConfigDialog 重建），重新建立
        searchFrame = nil
    end

    -- 搜尋框
    local searchBox = CreateFrame("EditBox", "LunarUIOptionsSearchBox", dialogFrame, "InputBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("TOPRIGHT", dialogFrame, "TOPRIGHT", -40, -8)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(GameFontNormalSmall)

    -- 占位文字
    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
    placeholder:SetText("Search settings...")
    searchBox._placeholder = placeholder

    -- 結果下拉面板
    local resultsPanel = CreateFrame("Frame", nil, dialogFrame, "BackdropTemplate")
    resultsPanel:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -2)
    resultsPanel:SetSize(340, 0)
    resultsPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    resultsPanel:SetBackdropColor(0.08, 0.08, 0.10, 0.98)
    resultsPanel:SetBackdropBorderColor(0.20, 0.16, 0.30, 1)
    resultsPanel:SetFrameStrata("DIALOG")
    resultsPanel:Hide()

    local resultButtons = {}

    local function UpdateResults(query)
        local results = FilterSearchResults(query)

        -- 隱藏所有既有按鈕
        for _, btn in ipairs(resultButtons) do
            btn:Hide()
        end

        if #results == 0 then
            resultsPanel:Hide()
            return
        end

        local buttonHeight = 24
        local maxResults = min(#results, 15)

        for i = 1, maxResults do
            local result = results[i]
            local btn = resultButtons[i]

            if not btn then
                btn = CreateFrame("Button", nil, resultsPanel)
                btn:SetHeight(buttonHeight)
                btn:SetPoint("TOPLEFT", resultsPanel, "TOPLEFT", 2, -(i - 1) * buttonHeight - 2)
                btn:SetPoint("TOPRIGHT", resultsPanel, "TOPRIGHT", -2, -(i - 1) * buttonHeight - 2)

                btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT", 6, 0)
                btn.text:SetPoint("RIGHT", -6, 0)
                btn.text:SetJustifyH("LEFT")

                local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
                highlight:SetVertexColor(0.53, 0.51, 1.0, 0.15)

                resultButtons[i] = btn
            end

            -- 顯示文字：group 用紫色，leaf 用白色
            local displayText = result.breadcrumbs
            if result.isGroup then
                displayText = "|cff8882ff" .. displayText .. "|r"
            end
            btn.text:SetText(displayText)

            -- 點擊導航到對應面板
            btn:SetScript("OnClick", function()
                if AceConfigDialog and #result.path > 0 then
                    AceConfigDialog:SelectGroup("LunarUI", unpack(result.path))
                end
                searchBox:SetText("")
                searchBox:ClearFocus()
                resultsPanel:Hide()
            end)

            btn:Show()
        end

        resultsPanel:SetHeight(maxResults * buttonHeight + 4)
        resultsPanel:Show()
    end

    -- EditBox 事件（節流 0.15 秒，減少 GC 壓力）
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text == "" then
            placeholder:Show()
            resultsPanel:Hide()
            if searchTimer then
                searchTimer:Cancel()
                searchTimer = nil
            end
        else
            placeholder:Hide()
            if searchTimer then
                searchTimer:Cancel()
            end
            searchTimer = C_Timer.NewTimer(0.15, function()
                searchTimer = nil
                UpdateResults(text)
            end)
        end
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        resultsPanel:Hide()
    end)

    searchBox:SetScript("OnEditFocusGained", function()
        placeholder:Hide()
    end)

    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            placeholder:Show()
        end
    end)

    searchFrame = searchBox
end

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

    -- Register profile options with spec auto-switch
    local profileOptions = GetProfileOptions()
    if profileOptions then
        -- 注入專精自動切換選項
        profileOptions.args.specHeader = {
            order = 100,
            type = "header",
            name = L.specAutoSwitch,
        }
        profileOptions.args.specDesc = {
            order = 101,
            type = "description",
            name = L.specAutoSwitchDesc,
        }
        local numSpecs = GetNumSpecializations and GetNumSpecializations(false) or 0
        for i = 1, numSpecs do
            local _, specName = GetSpecializationInfo(i)
            profileOptions.args["spec" .. i] = {
                order = 101 + i,
                type = "select",
                name = (specName or ("Spec " .. i)),
                desc = L.specProfile,
                values = function()
                    local t = { [""] = "(None)" }
                    for _, p in ipairs(LunarUI.db:GetProfiles()) do
                        t[p] = p
                    end
                    return t
                end,
                get = function()
                    if not LunarUI.db or not LunarUI.db.char then
                        return ""
                    end
                    return LunarUI.db.char.specProfiles and LunarUI.db.char.specProfiles[i] or ""
                end,
                set = function(_, v)
                    if not LunarUI.db or not LunarUI.db.char then
                        return
                    end
                    if not LunarUI.db.char.specProfiles then
                        LunarUI.db.char.specProfiles = {}
                    end
                    LunarUI.db.char.specProfiles[i] = (v ~= "") and v or nil
                end,
                width = "full",
            }
        end

        AceConfig:RegisterOptionsTable("LunarUI_Profiles", profileOptions)
        AceConfigDialog:AddToBlizOptions("LunarUI_Profiles", L.profiles, "LunarUI")
    end
end

--------------------------------------------------------------------------------
-- Slash Command
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 設定框架美化
--------------------------------------------------------------------------------

local function StyleConfigFrame()
    -- 取得 AceConfigDialog 開啟的框架
    local openFrames = AceConfigDialog and AceConfigDialog.OpenFrames
    local aceFrame = openFrames and openFrames["LunarUI"]
    if not aceFrame then
        return
    end

    local dialogFrame = aceFrame.frame
    if not dialogFrame or dialogFrame._lunarStyled then
        return
    end
    dialogFrame._lunarStyled = true

    -- 替換 backdrop 為 LunarUI 風格
    if dialogFrame.SetBackdrop then
        dialogFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        dialogFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
        dialogFrame:SetBackdropBorderColor(0.20, 0.16, 0.30, 1)
    end

    -- 標題字體美化
    if aceFrame.titletext then
        aceFrame.titletext:SetFont(LunarUI.GetSelectedFont(), 15, "OUTLINE")
        aceFrame.titletext:SetTextColor(0.53, 0.51, 1.0)
    end

    -- 頂部漸層裝飾
    local gradient = dialogFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    gradient:SetPoint("TOPLEFT", 1, -1)
    gradient:SetPoint("TOPRIGHT", -1, -1)
    gradient:SetHeight(36)
    gradient:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradient:SetGradient("VERTICAL", CreateColor(0.53, 0.51, 1.0, 0.0), CreateColor(0.53, 0.51, 1.0, 0.06))

    -- 底部狀態文字
    if aceFrame.statustext then
        aceFrame.statustext:SetFont(LunarUI.GetSelectedFont(), 10, "")
        aceFrame.statustext:SetTextColor(0.5, 0.5, 0.5)
    end

    -- 搜尋 UI
    CreateSearchUI(dialogFrame)
end

local function OpenConfig()
    -- Load the options addon if not loaded
    if not C_AddOns.IsAddOnLoaded("LunarUI_Options") then
        C_AddOns.LoadAddOn("LunarUI_Options")
    end

    -- 設定更大的視窗尺寸
    if AceConfigDialog then
        AceConfigDialog:SetDefaultSize("LunarUI", 900, 650)
        AceConfigDialog:Open("LunarUI")
        -- 延遲 0.1 秒美化（確保 AceConfigDialog 完成框架建立）
        C_Timer.After(0.1, StyleConfigFrame)
    end
end

-- Register with main addon
LunarUI.OpenConfig = OpenConfig

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

-- Fix #27: Clean up frame after registration
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _event, addon)
    if addon == "LunarUI_Options" then
        RegisterOptions()
        self:UnregisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", nil)
        -- Frame can be garbage collected now
    end
end)

--------------------------------------------------------------------------------
-- Test Exports (pure functions exposed for unit testing)
--------------------------------------------------------------------------------

LunarUI.Options_SafeGetField = SafeGetField
LunarUI.Options_BuildSearchIndex = BuildSearchIndex
LunarUI.Options_FilterSearchResults = FilterSearchResults
--- Inject a custom search index for testing FilterSearchResults in isolation
LunarUI.Options_SetSearchIndex = function(idx)
    searchIndex = idx
end
