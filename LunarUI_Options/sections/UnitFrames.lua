--[[
    LunarUI Options - UnitFrames section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.UnitFrames = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local RefreshUI = ctx.RefreshUI
    local LunarUI = ctx.LunarUI

    return {
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
                    args.portraitHeader = { order = 20, type = "header", name = L["PortraitSettings"] or "Portrait" }
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
                end

                if opts.hasHealPrediction then
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

                -- Arena-specific toggles
                if opts.hasArenaOptions then
                    args.arenaHeader = { order = 25, type = "header", name = L["Arena"] or "Arena" }
                    args.showPowerBar = {
                        order = 26,
                        type = "toggle",
                        name = L["ShowPowerBar"] or "Show Power Bar",
                        desc = L["ShowPowerBarDesc"] or "Show mana/energy bar below health",
                        get = function()
                            return GetDB().unitframes[unit].showPowerBar
                        end,
                        set = function(_, v)
                            GetDB().unitframes[unit].showPowerBar = v
                            RefreshUI()
                        end,
                    }
                    args.showCastbar = {
                        order = 27,
                        type = "toggle",
                        name = L["ShowCastbar"] or "Show Cast Bar",
                        desc = L["ShowCastbarDesc"] or "Show enemy cast bar",
                        get = function()
                            return GetDB().unitframes[unit].showCastbar
                        end,
                        set = function(_, v)
                            GetDB().unitframes[unit].showCastbar = v
                            RefreshUI()
                        end,
                    }
                    args.showClassIcon = {
                        order = 28,
                        type = "toggle",
                        name = L["ShowClassIcon"] or "Show Class Icon",
                        desc = L["ShowClassIconDesc"] or "Show class icon next to the frame",
                        get = function()
                            return GetDB().unitframes[unit].showClassIcon
                        end,
                        set = function(_, v)
                            GetDB().unitframes[unit].showClassIcon = v
                            RefreshUI()
                        end,
                    }
                end

                -- Raid-only: autoSwitchSize
                if opts.hasAutoSwitchSize then
                    args.autoSwitchSize = {
                        order = 40,
                        type = "toggle",
                        name = L["AutoSwitchSize"] or "Auto Switch Size",
                        desc = L["AutoSwitchSizeDesc"] or "Automatically adjust raid frame size based on group size",
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
                        hasHealPrediction = true,
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
                {
                    "arena",
                    7,
                    L["Arena"] or "Arena",
                    { wMin = 100, wMax = 300, hMin = 15, hMax = 60, hasAuras = true, hasArenaOptions = true },
                },
                { "pet", 8, L["Pet"] or "Pet", { wMin = 80, wMax = 250, hMin = 15, hMax = 60 } },
                {
                    "targettarget",
                    9,
                    L["TargetOfTarget"] or "Target of Target",
                    { wMin = 80, wMax = 250, hMin = 15, hMax = 60 },
                },
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
                            name = (L["RolePresetsDesc"] or "Quickly adjust raid/party frame layout for your role.")
                                .. "\n",
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
                            desc = L["TankLayoutDesc"] or "Wider frames with larger nameplates for threat awareness",
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
    }
end
