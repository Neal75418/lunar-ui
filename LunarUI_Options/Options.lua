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

    -- Skins
    skins = L["Skins"] or "Skins",
    skinsDesc = L["SkinsDesc"] or "Restyle Blizzard UI frames to match LunarUI theme",
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
            args = (function()
                -- 工廠函數：生成單位框架設定組
                local function MakeUnitFrameGroup(unit, ord, displayName, opts)
                    local args = {
                        enabled = {
                            order = 1, type = "toggle", name = L.enable, width = "full",
                            get = function() return GetDB().unitframes[unit].enabled end,
                            set = function(_, v) GetDB().unitframes[unit].enabled = v; RefreshUI() end,
                        },
                        width = {
                            order = 2, type = "range", name = L.width,
                            min = opts.wMin, max = opts.wMax, step = 5,
                            get = function() return GetDB().unitframes[unit].width end,
                            set = function(_, v) GetDB().unitframes[unit].width = v; RefreshUI() end,
                        },
                        height = {
                            order = 3, type = "range", name = L.height,
                            min = opts.hMin, max = opts.hMax, step = 1,
                            get = function() return GetDB().unitframes[unit].height end,
                            set = function(_, v) GetDB().unitframes[unit].height = v; RefreshUI() end,
                        },
                    }
                    if opts.spacingMax then
                        args.spacing = {
                            order = 4, type = "range", name = L.spacing,
                            min = 0, max = opts.spacingMax, step = 1,
                            get = function() return GetDB().unitframes[unit].spacing end,
                            set = function(_, v) GetDB().unitframes[unit].spacing = v; RefreshUI() end,
                        }
                    end
                    return { order = ord, type = "group", name = displayName, args = args }
                end

                local UNIT_FRAME_DEFS = {
                    { "player", 1, L.player, { wMin=100, wMax=400, hMin=20, hMax=100 } },
                    { "target", 2, L.target, { wMin=100, wMax=400, hMin=20, hMax=100 } },
                    { "focus",  3, L.focus,  { wMin=80,  wMax=300, hMin=15, hMax=80 } },
                    { "party",  4, L.party,  { wMin=80,  wMax=250, hMin=15, hMax=60, spacingMax=20 } },
                    { "raid",   5, L.raid,   { wMin=50,  wMax=150, hMin=15, hMax=50, spacingMax=10 } },
                    { "boss",   6, L.boss,   { wMin=100, wMax=300, hMin=20, hMax=80 } },
                }

                local result = {}
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
                stackingDetection = {
                    order = 4,
                    type = "toggle",
                    name = L.StackingDetection or "Stacking Detection",
                    desc = L.StackingDetectionDesc or "Offset overlapping nameplates so they don't cover each other (requires reload)",
                    get = function() return GetDB().nameplates.stackingDetection end,
                    set = function(_, v) GetDB().nameplates.stackingDetection = v; RefreshUI() end,
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
                enemyShowLevel = {
                    order = 15,
                    type = "toggle",
                    name = L.NameplateLevel or "Level Text",
                    desc = L.NameplateLevelDesc or "Show level text next to name on enemy nameplates (requires reload)",
                    get = function() return GetDB().nameplates.enemy.showLevel end,
                    set = function(_, v) GetDB().nameplates.enemy.showLevel = v; RefreshUI() end,
                },
                enemyShowQuestIcon = {
                    order = 16,
                    type = "toggle",
                    name = L.QuestIcon or "Quest Icon",
                    desc = L.QuestIconDesc or "Show quest objective icon on enemy nameplates (requires reload)",
                    get = function() return GetDB().nameplates.enemy.showQuestIcon end,
                    set = function(_, v) GetDB().nameplates.enemy.showQuestIcon = v; RefreshUI() end,
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
                friendlyShowLevel = {
                    order = 24,
                    type = "toggle",
                    name = L.NameplateLevel or "Level Text",
                    desc = L.NameplateLevelDesc or "Show level text next to name on friendly nameplates (requires reload)",
                    get = function() return GetDB().nameplates.friendly.showLevel end,
                    set = function(_, v) GetDB().nameplates.friendly.showLevel = v; RefreshUI() end,
                },
            },
        },

        -- HUD
        hud = {
            order = 5.5,
            type = "group",
            name = "HUD",
            desc = "Head-Up Display settings",
            childGroups = "tab",
            args = {
                -- 總覽分頁
                overview = {
                    order = 1,
                    type = "group",
                    name = "總覽",
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = "HUD 覆蓋層元素設定。修改部分設定需要 /reload 才能生效。\n\n",
                        },
                        scale = {
                            order = 1,
                            type = "range",
                            name = "HUD 縮放",
                            desc = "縮放所有 HUD 元素",
                            min = 0.5, max = 2.0, step = 0.05,
                            get = function() return GetDB().hud.scale or 1.0 end,
                            set = function(_, v)
                                GetDB().hud.scale = v
                                if LunarUI.ApplyHUDScale then LunarUI:ApplyHUDScale() end
                            end,
                            width = "full",
                        },
                        modulesHeader = {
                            order = 5,
                            type = "header",
                            name = "模組開關",
                        },
                        phaseIndicator = {
                            order = 10,
                            type = "toggle",
                            name = "月相指示器",
                            desc = "顯示目前月相的月亮圖示",
                            get = function() return GetDB().hud.phaseIndicator end,
                            set = function(_, v)
                                GetDB().hud.phaseIndicator = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        performanceMonitor = {
                            order = 11,
                            type = "toggle",
                            name = "效能監控器",
                            desc = "顯示 FPS 與延遲",
                            get = function() return GetDB().hud.performanceMonitor end,
                            set = function(_, v)
                                GetDB().hud.performanceMonitor = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        classResources = {
                            order = 12,
                            type = "toggle",
                            name = "職業資源",
                            desc = "職業專屬資源顯示（連擊點、符文等）",
                            get = function() return GetDB().hud.classResources end,
                            set = function(_, v)
                                GetDB().hud.classResources = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        cooldownTracker = {
                            order = 13,
                            type = "toggle",
                            name = "冷卻追蹤器",
                            desc = "追蹤重要技能冷卻",
                            get = function() return GetDB().hud.cooldownTracker end,
                            set = function(_, v)
                                GetDB().hud.cooldownTracker = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        floatingCombatText = {
                            order = 14,
                            type = "toggle",
                            name = "浮動戰鬥文字",
                            desc = "顯示傷害與治療數字",
                            get = function() return GetDB().hud.floatingCombatText end,
                            set = function(_, v)
                                GetDB().hud.floatingCombatText = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                        auraFrames = {
                            order = 15,
                            type = "toggle",
                            name = "增減益框架",
                            desc = "獨立的 Buff/Debuff 顯示",
                            get = function() return GetDB().hud.auraFrames end,
                            set = function(_, v)
                                GetDB().hud.auraFrames = v
                                RefreshUI()
                            end,
                            width = "full",
                        },
                    },
                },

                -- 增減益框架分頁
                auraSettings = {
                    order = 2,
                    type = "group",
                    name = "增減益框架",
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = "Buff/Debuff 圖示大小與佈局設定。修改後即時生效。\n\n",
                        },
                        auraIconSize = {
                            order = 1,
                            type = "range",
                            name = "圖示大小",
                            desc = "每個增減益圖示的像素大小",
                            min = 24, max = 64, step = 2,
                            get = function() return GetDB().hud.auraIconSize end,
                            set = function(_, v)
                                GetDB().hud.auraIconSize = v
                                if LunarUI.RebuildAuraFrames then LunarUI:RebuildAuraFrames() end
                            end,
                            width = "full",
                        },
                        auraIconSpacing = {
                            order = 2,
                            type = "range",
                            name = "圖示間距",
                            desc = "圖示之間的距離",
                            min = 0, max = 12, step = 1,
                            get = function() return GetDB().hud.auraIconSpacing end,
                            set = function(_, v)
                                GetDB().hud.auraIconSpacing = v
                                if LunarUI.RebuildAuraFrames then LunarUI:RebuildAuraFrames() end
                            end,
                            width = "full",
                        },
                        auraIconsPerRow = {
                            order = 3,
                            type = "range",
                            name = "每行圖示數",
                            desc = "每行顯示多少個圖示",
                            min = 4, max = 16, step = 1,
                            get = function() return GetDB().hud.auraIconsPerRow end,
                            set = function(_, v)
                                GetDB().hud.auraIconsPerRow = v
                                if LunarUI.RebuildAuraFrames then LunarUI:RebuildAuraFrames() end
                            end,
                            width = "full",
                        },
                        maxBuffs = {
                            order = 4,
                            type = "range",
                            name = "最大增益數",
                            desc = "最多顯示多少個 Buff",
                            min = 4, max = 40, step = 1,
                            get = function() return GetDB().hud.maxBuffs end,
                            set = function(_, v)
                                GetDB().hud.maxBuffs = v
                                if LunarUI.RebuildAuraFrames then LunarUI:RebuildAuraFrames() end
                            end,
                            width = "full",
                        },
                        maxDebuffs = {
                            order = 5,
                            type = "range",
                            name = "最大減益數",
                            desc = "最多顯示多少個 Debuff",
                            min = 4, max = 20, step = 1,
                            get = function() return GetDB().hud.maxDebuffs end,
                            set = function(_, v)
                                GetDB().hud.maxDebuffs = v
                                if LunarUI.RebuildAuraFrames then LunarUI:RebuildAuraFrames() end
                            end,
                            width = "full",
                        },
                        auraBarHeight = {
                            order = 6,
                            type = "range",
                            name = "計時條高度",
                            desc = "圖示下方計時條的高度",
                            min = 2, max = 10, step = 1,
                            get = function() return GetDB().hud.auraBarHeight end,
                            set = function(_, v)
                                GetDB().hud.auraBarHeight = v
                                if LunarUI.RebuildAuraFrames then LunarUI:RebuildAuraFrames() end
                            end,
                            width = "full",
                        },
                    },
                },

                -- 浮動戰鬥文字分頁
                fctSettings = {
                    order = 3,
                    type = "group",
                    name = "浮動戰鬥文字",
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = "戰鬥數字的字體大小與動畫設定。即時生效。\n\n",
                        },
                        fctFontSizeNormal = {
                            order = 1,
                            type = "range",
                            name = "一般字體大小",
                            desc = "普通傷害/治療數字的字體大小",
                            min = 10, max = 36, step = 1,
                            get = function() return GetDB().hud.fctFontSizeNormal end,
                            set = function(_, v)
                                GetDB().hud.fctFontSizeNormal = v
                                if LunarUI.ReloadFCTSettings then LunarUI:ReloadFCTSettings() end
                            end,
                            width = "full",
                        },
                        fctFontSizeCrit = {
                            order = 2,
                            type = "range",
                            name = "暴擊字體大小",
                            desc = "暴擊傷害/治療數字的字體大小",
                            min = 14, max = 48, step = 1,
                            get = function() return GetDB().hud.fctFontSizeCrit end,
                            set = function(_, v)
                                GetDB().hud.fctFontSizeCrit = v
                                if LunarUI.ReloadFCTSettings then LunarUI:ReloadFCTSettings() end
                            end,
                            width = "full",
                        },
                        fctFontSizeSmall = {
                            order = 3,
                            type = "range",
                            name = "小字體大小",
                            desc = "次要事件文字的字體大小",
                            min = 8, max = 24, step = 1,
                            get = function() return GetDB().hud.fctFontSizeSmall end,
                            set = function(_, v)
                                GetDB().hud.fctFontSizeSmall = v
                                if LunarUI.ReloadFCTSettings then LunarUI:ReloadFCTSettings() end
                            end,
                            width = "full",
                        },
                        fctAnimationDuration = {
                            order = 4,
                            type = "range",
                            name = "動畫時長",
                            desc = "數字浮動的持續時間（秒）",
                            min = 0.5, max = 4.0, step = 0.1,
                            get = function() return GetDB().hud.fctAnimationDuration end,
                            set = function(_, v)
                                GetDB().hud.fctAnimationDuration = v
                                if LunarUI.ReloadFCTSettings then LunarUI:ReloadFCTSettings() end
                            end,
                            width = "full",
                        },
                        fctAnimationHeight = {
                            order = 5,
                            type = "range",
                            name = "動畫高度",
                            desc = "數字浮動的高度（像素）",
                            min = 30, max = 200, step = 5,
                            get = function() return GetDB().hud.fctAnimationHeight end,
                            set = function(_, v)
                                GetDB().hud.fctAnimationHeight = v
                                if LunarUI.ReloadFCTSettings then LunarUI:ReloadFCTSettings() end
                            end,
                            width = "full",
                        },
                    },
                },

                -- 冷卻追蹤分頁
                cdSettings = {
                    order = 4,
                    type = "group",
                    name = "冷卻追蹤",
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = "冷卻追蹤器的圖示設定。修改後即時生效。\n\n",
                        },
                        cdIconSize = {
                            order = 1,
                            type = "range",
                            name = "圖示大小",
                            desc = "冷卻追蹤圖示的像素大小",
                            min = 24, max = 56, step = 2,
                            get = function() return GetDB().hud.cdIconSize end,
                            set = function(_, v)
                                GetDB().hud.cdIconSize = v
                                if LunarUI.RebuildCooldownTracker then LunarUI:RebuildCooldownTracker() end
                            end,
                            width = "full",
                        },
                        cdIconSpacing = {
                            order = 2,
                            type = "range",
                            name = "圖示間距",
                            desc = "圖示之間的距離",
                            min = 0, max = 12, step = 1,
                            get = function() return GetDB().hud.cdIconSpacing end,
                            set = function(_, v)
                                GetDB().hud.cdIconSpacing = v
                                if LunarUI.RebuildCooldownTracker then LunarUI:RebuildCooldownTracker() end
                            end,
                            width = "full",
                        },
                        cdMaxIcons = {
                            order = 3,
                            type = "range",
                            name = "最大圖示數",
                            desc = "同時顯示的最大冷卻數量",
                            min = 3, max = 16, step = 1,
                            get = function() return GetDB().hud.cdMaxIcons end,
                            set = function(_, v)
                                GetDB().hud.cdMaxIcons = v
                                if LunarUI.RebuildCooldownTracker then LunarUI:RebuildCooldownTracker() end
                            end,
                            width = "full",
                        },
                    },
                },

                -- 職業資源分頁
                crSettings = {
                    order = 5,
                    type = "group",
                    name = "職業資源",
                    args = {
                        desc = {
                            order = 0,
                            type = "description",
                            name = "職業資源（連擊點、符文等）的顯示設定。修改後即時生效。\n\n",
                        },
                        crIconSize = {
                            order = 1,
                            type = "range",
                            name = "圖示大小",
                            desc = "資源點圖示的像素大小",
                            min = 16, max = 48, step = 2,
                            get = function() return GetDB().hud.crIconSize end,
                            set = function(_, v)
                                GetDB().hud.crIconSize = v
                                if LunarUI.RebuildClassResources then LunarUI:RebuildClassResources() end
                            end,
                            width = "full",
                        },
                        crIconSpacing = {
                            order = 2,
                            type = "range",
                            name = "圖示間距",
                            desc = "資源點之間的距離",
                            min = 0, max = 12, step = 1,
                            get = function() return GetDB().hud.crIconSpacing end,
                            set = function(_, v)
                                GetDB().hud.crIconSpacing = v
                                if LunarUI.RebuildClassResources then LunarUI:RebuildClassResources() end
                            end,
                            width = "full",
                        },
                        crBarHeight = {
                            order = 3,
                            type = "range",
                            name = "條狀高度",
                            desc = "資源條的高度（使用條狀顯示時）",
                            min = 4, max = 20, step = 1,
                            get = function() return GetDB().hud.crBarHeight end,
                            set = function(_, v)
                                GetDB().hud.crBarHeight = v
                                if LunarUI.RebuildClassResources then LunarUI:RebuildClassResources() end
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
                    get = function() return GetDB().minimap.enabled end,
                    set = function(_, v) GetDB().minimap.enabled = v end,
                    width = "full",
                },

                -- Layout
                layoutHeader = {
                    order = 10,
                    type = "header",
                    name = "Layout",
                },
                size = {
                    order = 11,
                    type = "range",
                    name = "Size",
                    min = 120, max = 250, step = 5,
                    get = function() return GetDB().minimap.size end,
                    set = function(_, v)
                        GetDB().minimap.size = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                borderColor = {
                    order = 12,
                    type = "color",
                    name = "Border Color",
                    hasAlpha = true,
                    get = function()
                        local c = GetDB().minimap.borderColor
                        return c.r, c.g, c.b, c.a
                    end,
                    set = function(_, r, g, b, a)
                        local c = GetDB().minimap.borderColor
                        c.r, c.g, c.b, c.a = r, g, b, a
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                pinScale = {
                    order = 13,
                    type = "range",
                    name = "Pin Scale",
                    desc = "Scale of minimap pins (quests, herbs, nodes)",
                    min = 0.5, max = 2.0, step = 0.1,
                    get = function() return GetDB().minimap.pinScale end,
                    set = function(_, v)
                        GetDB().minimap.pinScale = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },

                -- Display
                displayHeader = {
                    order = 20,
                    type = "header",
                    name = "Display",
                },
                showCoords = {
                    order = 21,
                    type = "toggle",
                    name = L.showCoords,
                    get = function() return GetDB().minimap.showCoords end,
                    set = function(_, v)
                        GetDB().minimap.showCoords = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                showClock = {
                    order = 22,
                    type = "toggle",
                    name = L.showClock,
                    get = function() return GetDB().minimap.showClock end,
                    set = function(_, v)
                        GetDB().minimap.showClock = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                clockFormat = {
                    order = 23,
                    type = "select",
                    name = "Clock Format",
                    values = { ["24h"] = "24-Hour", ["12h"] = "12-Hour" },
                    get = function() return GetDB().minimap.clockFormat end,
                    set = function(_, v)
                        GetDB().minimap.clockFormat = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                zoneTextDisplay = {
                    order = 24,
                    type = "select",
                    name = "Zone Text",
                    desc = "Show zone text always, on mouseover, or hide",
                    values = {
                        ["SHOW"] = "Always Show",
                        ["MOUSEOVER"] = "Show on Mouseover",
                        ["HIDE"] = "Hidden",
                    },
                    get = function() return GetDB().minimap.zoneTextDisplay end,
                    set = function(_, v)
                        GetDB().minimap.zoneTextDisplay = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                organizeButtons = {
                    order = 25,
                    type = "toggle",
                    name = L.organizeButtons,
                    get = function() return GetDB().minimap.organizeButtons end,
                    set = function(_, v)
                        GetDB().minimap.organizeButtons = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },

                -- Fonts
                fontHeader = {
                    order = 30,
                    type = "header",
                    name = "Fonts",
                },
                zoneFontSize = {
                    order = 31,
                    type = "range",
                    name = "Zone Text Size",
                    min = 8, max = 24, step = 1,
                    get = function() return GetDB().minimap.zoneFontSize end,
                    set = function(_, v)
                        GetDB().minimap.zoneFontSize = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                zoneFontOutline = {
                    order = 32,
                    type = "select",
                    name = "Zone Text Outline",
                    values = {
                        ["NONE"] = "None",
                        ["OUTLINE"] = "Outline",
                        ["THICKOUTLINE"] = "Thick Outline",
                        ["MONOCHROMEOUTLINE"] = "Monochrome",
                    },
                    get = function() return GetDB().minimap.zoneFontOutline end,
                    set = function(_, v)
                        GetDB().minimap.zoneFontOutline = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                coordFontSize = {
                    order = 33,
                    type = "range",
                    name = "Coord / Clock Text Size",
                    min = 8, max = 18, step = 1,
                    get = function() return GetDB().minimap.coordFontSize end,
                    set = function(_, v)
                        GetDB().minimap.coordFontSize = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },

                -- Behavior
                behaviorHeader = {
                    order = 40,
                    type = "header",
                    name = "Behavior",
                },
                resetZoomTimer = {
                    order = 41,
                    type = "range",
                    name = "Reset Zoom Timer",
                    desc = "Auto zoom-out after this many seconds (0 = disabled)",
                    min = 0, max = 15, step = 1,
                    get = function() return GetDB().minimap.resetZoomTimer end,
                    set = function(_, v) GetDB().minimap.resetZoomTimer = v end,
                },
                fadeOnMouseLeave = {
                    order = 42,
                    type = "toggle",
                    name = "Fade on Mouse Leave",
                    desc = "Fade the minimap when the mouse is not over it",
                    get = function() return GetDB().minimap.fadeOnMouseLeave end,
                    set = function(_, v)
                        GetDB().minimap.fadeOnMouseLeave = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },
                fadeAlpha = {
                    order = 43,
                    type = "range",
                    name = "Fade Alpha",
                    min = 0.1, max = 0.9, step = 0.05,
                    isPercent = true,
                    disabled = function() return not GetDB().minimap.fadeOnMouseLeave end,
                    get = function() return GetDB().minimap.fadeAlpha end,
                    set = function(_, v)
                        GetDB().minimap.fadeAlpha = v
                        if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                    end,
                },

                -- Icons
                iconsGroup = {
                    order = 50,
                    type = "group",
                    name = "Icon Settings",
                    inline = true,
                    args = (function()
                        local ICON_NAMES = {
                            { key = "calendar",    name = "Calendar" },
                            { key = "tracking",    name = "Tracking" },
                            { key = "mail",        name = "Mail Indicator" },
                            { key = "difficulty",  name = "Difficulty Text" },
                            { key = "lfg",         name = "LFG Queue" },
                            { key = "expansion",   name = "Expansion Button" },
                            { key = "compartment", name = "Addon Compartment" },
                        }

                        local POSITION_VALUES = {
                            TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right",
                            LEFT = "Left", CENTER = "Center", RIGHT = "Right",
                            BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right",
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
                                name = "Hide",
                                width = "half",
                                get = function() return GetDB().minimap.icons[iconKey].hide end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].hide = v
                                    if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                                end,
                            }
                            args[iconKey .. "Position"] = {
                                order = o + 2,
                                type = "select",
                                name = "Anchor",
                                values = POSITION_VALUES,
                                disabled = function() return GetDB().minimap.icons[iconKey].hide end,
                                get = function() return GetDB().minimap.icons[iconKey].position end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].position = v
                                    if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                                end,
                            }
                            args[iconKey .. "Scale"] = {
                                order = o + 3,
                                type = "range",
                                name = "Scale",
                                min = 0.5, max = 2.0, step = 0.1,
                                disabled = function() return GetDB().minimap.icons[iconKey].hide end,
                                get = function() return GetDB().minimap.icons[iconKey].scale end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].scale = v
                                    if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                                end,
                            }
                            args[iconKey .. "XOffset"] = {
                                order = o + 4,
                                type = "range",
                                name = "X Offset",
                                min = -50, max = 50, step = 1,
                                disabled = function() return GetDB().minimap.icons[iconKey].hide end,
                                get = function() return GetDB().minimap.icons[iconKey].xOffset end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].xOffset = v
                                    if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
                                end,
                            }
                            args[iconKey .. "YOffset"] = {
                                order = o + 5,
                                type = "range",
                                name = "Y Offset",
                                min = -50, max = 50, step = 1,
                                disabled = function() return GetDB().minimap.icons[iconKey].hide end,
                                get = function() return GetDB().minimap.icons[iconKey].yOffset end,
                                set = function(_, v)
                                    GetDB().minimap.icons[iconKey].yOffset = v
                                    if LunarUI.RefreshMinimap then LunarUI:RefreshMinimap() end
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
                    get = function() return GetDB().bags.enabled end,
                    set = function(_, v) GetDB().bags.enabled = v end,
                    width = "full",
                },
                layoutHeader = {
                    order = 2,
                    type = "header",
                    name = "Layout",
                },
                slotsPerRow = {
                    order = 3,
                    type = "range",
                    name = "Slots Per Row",
                    min = 8, max = 16, step = 1,
                    get = function() return GetDB().bags.slotsPerRow end,
                    set = function(_, v)
                        GetDB().bags.slotsPerRow = v
                        if LunarUI.RebuildBags then LunarUI:RebuildBags() end
                    end,
                },
                slotSize = {
                    order = 4,
                    type = "range",
                    name = "Slot Size",
                    min = 28, max = 48, step = 1,
                    get = function() return GetDB().bags.slotSize end,
                    set = function(_, v)
                        GetDB().bags.slotSize = v
                        if LunarUI.RebuildBags then LunarUI:RebuildBags() end
                    end,
                },
                slotSpacing = {
                    order = 5,
                    type = "range",
                    name = "Slot Spacing",
                    min = 0, max = 8, step = 1,
                    get = function() return GetDB().bags.slotSpacing end,
                    set = function(_, v)
                        GetDB().bags.slotSpacing = v
                        if LunarUI.RebuildBags then LunarUI:RebuildBags() end
                    end,
                },
                frameAlpha = {
                    order = 6,
                    type = "range",
                    name = "Background Opacity",
                    min = 0.3, max = 1.0, step = 0.05,
                    isPercent = true,
                    get = function() return GetDB().bags.frameAlpha end,
                    set = function(_, v)
                        GetDB().bags.frameAlpha = v
                        if LunarUI.RebuildBags then LunarUI:RebuildBags() end
                    end,
                },
                reverseBagSlots = {
                    order = 7,
                    type = "toggle",
                    name = "Reverse Bag Slots",
                    desc = "Reverse the order of items in the bag",
                    get = function() return GetDB().bags.reverseBagSlots end,
                    set = function(_, v)
                        GetDB().bags.reverseBagSlots = v
                        if LunarUI.RebuildBags then LunarUI:RebuildBags() end
                    end,
                },
                splitBags = {
                    order = 8,
                    type = "toggle",
                    name = "Split Bags",
                    desc = "Show each bag as a separate section with visual gaps",
                    get = function() return GetDB().bags.splitBags end,
                    set = function(_, v)
                        GetDB().bags.splitBags = v
                        if LunarUI.RebuildBags then LunarUI:RebuildBags() end
                    end,
                },
                displayHeader = {
                    order = 10,
                    type = "header",
                    name = "Display",
                },
                showItemLevel = {
                    order = 11,
                    type = "toggle",
                    name = L.showItemLevel,
                    get = function() return GetDB().bags.showItemLevel end,
                    set = function(_, v) GetDB().bags.showItemLevel = v end,
                },
                ilvlThreshold = {
                    order = 12,
                    type = "range",
                    name = "Item Level Threshold",
                    desc = "Only show item level for items at or above this level",
                    min = 1, max = 600, step = 1,
                    get = function() return GetDB().bags.ilvlThreshold end,
                    set = function(_, v) GetDB().bags.ilvlThreshold = v end,
                },
                showBindType = {
                    order = 13,
                    type = "toggle",
                    name = "Show Bind Type",
                    desc = "Show BoE/BoU text on item slots",
                    get = function() return GetDB().bags.showBindType end,
                    set = function(_, v) GetDB().bags.showBindType = v end,
                },
                showCooldown = {
                    order = 14,
                    type = "toggle",
                    name = "Show Cooldowns",
                    desc = "Show cooldown animation on items in bags",
                    get = function() return GetDB().bags.showCooldown end,
                    set = function(_, v) GetDB().bags.showCooldown = v end,
                },
                showNewGlow = {
                    order = 15,
                    type = "toggle",
                    name = "New Item Glow",
                    desc = "Show a glow animation on newly acquired items",
                    get = function() return GetDB().bags.showNewGlow end,
                    set = function(_, v) GetDB().bags.showNewGlow = v end,
                },
                showQuestItems = {
                    order = 16,
                    type = "toggle",
                    name = "Show Quest Items",
                    desc = "Show quest item indicator on bag slots",
                    get = function() return GetDB().bags.showQuestItems end,
                    set = function(_, v) GetDB().bags.showQuestItems = v end,
                },
                showProfessionColors = {
                    order = 17,
                    type = "toggle",
                    name = "Profession Bag Colors",
                    desc = "Color-code profession bag slots",
                    get = function() return GetDB().bags.showProfessionColors end,
                    set = function(_, v) GetDB().bags.showProfessionColors = v end,
                },
                showUpgradeArrow = {
                    order = 18,
                    type = "toggle",
                    name = "Upgrade Arrow",
                    desc = "Show green arrow on items that are an upgrade",
                    get = function() return GetDB().bags.showUpgradeArrow end,
                    set = function(_, v) GetDB().bags.showUpgradeArrow = v end,
                },
                behaviorHeader = {
                    order = 20,
                    type = "header",
                    name = "Behavior",
                },
                autoSellJunk = {
                    order = 21,
                    type = "toggle",
                    name = L.autoSellJunk,
                    get = function() return GetDB().bags.autoSellJunk end,
                    set = function(_, v) GetDB().bags.autoSellJunk = v end,
                },
                clearSearchOnClose = {
                    order = 22,
                    type = "toggle",
                    name = "Clear Search On Close",
                    desc = "Automatically clear the search box when closing bags",
                    get = function() return GetDB().bags.clearSearchOnClose end,
                    set = function(_, v) GetDB().bags.clearSearchOnClose = v end,
                },
                resetPosition = {
                    order = 30,
                    type = "execute",
                    name = "Reset Position",
                    desc = "Reset bag and bank frame positions to default",
                    func = function()
                        local bagDb = GetDB().bags
                        bagDb.bagPosition = nil
                        bagDb.bankPosition = nil
                        if LunarUI.RebuildBags then LunarUI:RebuildBags() end
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

        -- 框架移動器
        frameMover = {
            order = 9.5,
            type = "group",
            name = "框架移動器",
            desc = "框架拖曳與對齊格線設定",
            args = {
                desc = {
                    order = 0,
                    type = "description",
                    name = "框架移動器的對齊與外觀設定。\n\n",
                },
                gridSize = {
                    order = 1,
                    type = "range",
                    name = "格線大小",
                    desc = "拖曳時對齊格線的間距（像素）",
                    min = 1, max = 40, step = 1,
                    get = function() return GetDB().frameMover and GetDB().frameMover.gridSize or 10 end,
                    set = function(_, v)
                        if not GetDB().frameMover then GetDB().frameMover = {} end
                        GetDB().frameMover.gridSize = v
                        if LunarUI.LoadFrameMoverSettings then LunarUI:LoadFrameMoverSettings() end
                    end,
                    width = "full",
                },
                moverAlpha = {
                    order = 2,
                    type = "range",
                    name = "移動器透明度",
                    desc = "解鎖時移動器方塊的透明度",
                    min = 0.1, max = 1.0, step = 0.05,
                    get = function() return GetDB().frameMover and GetDB().frameMover.moverAlpha or 0.6 end,
                    set = function(_, v)
                        if not GetDB().frameMover then GetDB().frameMover = {} end
                        GetDB().frameMover.moverAlpha = v
                        if LunarUI.LoadFrameMoverSettings then LunarUI:LoadFrameMoverSettings() end
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
                    get = function() return GetDB().skins.enabled end,
                    set = function(_, v) GetDB().skins.enabled = v end,
                    width = "full",
                },
                character = {
                    order = 2,
                    type = "toggle",
                    name = L.skinCharacter,
                    get = function() return GetDB().skins.blizzard.character end,
                    set = function(_, v) GetDB().skins.blizzard.character = v end,
                },
                spellbook = {
                    order = 3,
                    type = "toggle",
                    name = L.skinSpellbook,
                    get = function() return GetDB().skins.blizzard.spellbook end,
                    set = function(_, v) GetDB().skins.blizzard.spellbook = v end,
                },
                talents = {
                    order = 4,
                    type = "toggle",
                    name = L.skinTalents,
                    get = function() return GetDB().skins.blizzard.talents end,
                    set = function(_, v) GetDB().skins.blizzard.talents = v end,
                },
                quest = {
                    order = 5,
                    type = "toggle",
                    name = L.skinQuest,
                    get = function() return GetDB().skins.blizzard.quest end,
                    set = function(_, v) GetDB().skins.blizzard.quest = v end,
                },
                merchant = {
                    order = 6,
                    type = "toggle",
                    name = L.skinMerchant,
                    get = function() return GetDB().skins.blizzard.merchant end,
                    set = function(_, v) GetDB().skins.blizzard.merchant = v end,
                },
                gossip = {
                    order = 7,
                    type = "toggle",
                    name = L.skinGossip,
                    get = function() return GetDB().skins.blizzard.gossip end,
                    set = function(_, v) GetDB().skins.blizzard.gossip = v end,
                },
                worldmap = {
                    order = 8,
                    type = "toggle",
                    name = L.skinWorldMap,
                    get = function() return GetDB().skins.blizzard.worldmap end,
                    set = function(_, v) GetDB().skins.blizzard.worldmap = v end,
                },
                achievements = {
                    order = 9,
                    type = "toggle",
                    name = L.skinAchievements,
                    get = function() return GetDB().skins.blizzard.achievements end,
                    set = function(_, v) GetDB().skins.blizzard.achievements = v end,
                },
                mail = {
                    order = 10,
                    type = "toggle",
                    name = L.skinMail,
                    get = function() return GetDB().skins.blizzard.mail end,
                    set = function(_, v) GetDB().skins.blizzard.mail = v end,
                },
                collections = {
                    order = 11,
                    type = "toggle",
                    name = L.skinCollections,
                    get = function() return GetDB().skins.blizzard.collections end,
                    set = function(_, v) GetDB().skins.blizzard.collections = v end,
                },
                lfg = {
                    order = 12,
                    type = "toggle",
                    name = L.skinLFG,
                    get = function() return GetDB().skins.blizzard.lfg end,
                    set = function(_, v) GetDB().skins.blizzard.lfg = v end,
                },
                encounterjournal = {
                    order = 13,
                    type = "toggle",
                    name = L.skinEncounterJournal,
                    get = function() return GetDB().skins.blizzard.encounterjournal end,
                    set = function(_, v) GetDB().skins.blizzard.encounterjournal = v end,
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

    -- Register profile options with spec auto-switch
    local profileOptions = GetProfileOptions()
    if profileOptions then
        -- 注入專精自動切換選項
        profileOptions.args.specHeader = {
            order = 100,
            type = "header",
            name = "Specialization Auto-Switch",
        }
        profileOptions.args.specDesc = {
            order = 101,
            type = "description",
            name = "Automatically switch profiles when changing specialization.\n\n",
        }
        local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
        for i = 1, numSpecs do
            local _, specName = GetSpecializationInfo(i)
            profileOptions.args["spec" .. i] = {
                order = 101 + i,
                type = "select",
                name = (specName or ("Spec " .. i)),
                desc = "Profile to use for this specialization",
                values = function()
                    local t = { [""] = "(None)" }
                    for _, p in ipairs(LunarUI.db:GetProfiles()) do
                        t[p] = p
                    end
                    return t
                end,
                get = function()
                    return LunarUI.db.char.specProfiles and LunarUI.db.char.specProfiles[i] or ""
                end,
                set = function(_, v)
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
    if not aceFrame then return end

    local dialogFrame = aceFrame.frame
    if not dialogFrame or dialogFrame._lunarStyled then return end
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
        aceFrame.titletext:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE")
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
        aceFrame.statustext:SetFont(STANDARD_TEXT_FONT, 10, "")
        aceFrame.statustext:SetTextColor(0.5, 0.5, 0.5)
    end
end

local function OpenConfig()
    -- Load the options addon if not loaded
    if not IsAddOnLoaded("LunarUI_Options") then
        LoadAddOn("LunarUI_Options")
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
