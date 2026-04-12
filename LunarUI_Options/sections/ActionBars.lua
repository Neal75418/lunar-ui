--[[
    LunarUI Options - ActionBars section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.ActionBars = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local RefreshUI = ctx.RefreshUI
    local format = string.format

    -- args is assembled incrementally so we can mix the static `global` subgroup
    -- with dynamically-generated bar1..bar6 / petbar / stancebar groups below.
    local args = {
        global = {
            order = 0,
            type = "group",
            name = L["GlobalSettings"] or "Global Settings",
            args = {
                enabled = {
                    order = 1,
                    type = "toggle",
                    name = L.enable,
                    desc = L["ActionBarsEnableDesc"] or "Enable LunarUI action bars (disable to use Blizzard default)",
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
                    desc = L["OutOfRangeColoringDesc"] or "Color action buttons red when the target is out of range",
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
    }

    -- Build Action Bars 1-6 dynamically
    for i = 1, 6 do
        args["bar" .. i] = {
            order = i,
            type = "group",
            -- L is metatable-backed; dead-code `or` fallback removed
            name = format(L.ActionBarN, i),
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

    -- Pet bar and stance bar
    args.petbar = {
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

    args.stancebar = {
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

    return {
        order = 4,
        type = "group",
        name = L.actionbars,
        desc = L.actionbarsDesc,
        childGroups = "tab",
        args = args,
    }
end
