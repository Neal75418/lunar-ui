--[[
    LunarUI Options - Minimap section builder
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Minimap = function(ctx)
    local L = ctx.L
    local GetDB = ctx.GetDB
    local RefreshUI = ctx.RefreshUI
    local LunarUI = ctx.LunarUI

    return {
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
                values = { ["24h"] = L["Clock24h"] or "24-Hour", ["12h"] = L["Clock12h"] or "12-Hour" },
                get = function()
                    return GetDB().minimap.clockFormat
                end,
                set = function(_, v)
                    GetDB().minimap.clockFormat = v
                    if LunarUI.RefreshMinimap then
                        LunarUI:RefreshMinimap()
                    end
                    -- 同步 DataTexts clock 快取（P4-perf 快取需要手動失效）
                    if LunarUI.RefreshClockFormat then
                        LunarUI.RefreshClockFormat()
                    end
                end,
            },
            zoneTextDisplay = {
                order = 24,
                type = "select",
                name = L.zoneText,
                desc = L.zoneTextDesc,
                values = {
                    ["SHOW"] = L["ZoneTextShow"] or "Always Show",
                    ["MOUSEOVER"] = L["ZoneTextMouseover"] or "Show on Mouseover",
                    ["HIDE"] = L["ZoneTextHide"] or "Hidden",
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
                    ["NONE"] = L["OutlineNone"] or "None",
                    ["OUTLINE"] = L["OutlineOutline"] or "Outline",
                    ["THICKOUTLINE"] = L["OutlineThick"] or "Thick Outline",
                    ["MONOCHROMEOUTLINE"] = L["OutlineMonochrome"] or "Monochrome",
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

            coordFontOutline = {
                order = 34,
                type = "select",
                name = L["CoordFontOutline"] or "Coordinate Font Outline",
                values = {
                    NONE = L["OutlineNone"] or "None",
                    OUTLINE = L["OutlineOutline"] or "Outline",
                    THICKOUTLINE = L["OutlineThick"] or "Thick Outline",
                    MONOCHROMEOUTLINE = L["OutlineMonochrome"] or "Monochrome",
                },
                get = function()
                    return GetDB().minimap.coordFontOutline
                end,
                set = function(_, v)
                    GetDB().minimap.coordFontOutline = v
                    RefreshUI()
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
                        { key = "calendar", name = L.MinimapIconCalendar },
                        { key = "tracking", name = L.MinimapIconTracking },
                        { key = "mail", name = L.MinimapIconMail },
                        { key = "difficulty", name = L.MinimapIconDifficulty },
                        { key = "lfg", name = L.MinimapIconLFG },
                        { key = "expansion", name = L.MinimapIconExpansion },
                        { key = "compartment", name = L.MinimapIconCompartment },
                    }

                    local POSITION_VALUES = {
                        TOPLEFT = L.AnchorTopLeft,
                        TOP = L.AnchorTop,
                        TOPRIGHT = L.AnchorTopRight,
                        LEFT = L.AnchorLeft,
                        CENTER = L.AnchorCenter,
                        RIGHT = L.AnchorRight,
                        BOTTOMLEFT = L.AnchorBottomLeft,
                        BOTTOM = L.AnchorBottom,
                        BOTTOMRIGHT = L.AnchorBottomRight,
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
    }
end
