---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter
--[[
    Unit tests for LunarUI_Options/Options.lua pure functions
    Tests: SafeGetField, BuildSearchIndex, FilterSearchResults
]]

require("spec.wow_mock")

--------------------------------------------------------------------------------
-- WoW API stubs required by Options.lua at load time
--------------------------------------------------------------------------------

local LunarUI = {
    version = "test",
    db = nil,
    L = {},
    Print = function() end,
    GetProfileDB = function()
        return {}
    end,
    ApplyHUDScale = function() end,
    GetSelectedFont = function()
        return "Fonts\\FRIZQT__.TTF"
    end,
}

-- LibStub mock: AceAddon-3.0 returns our LunarUI stub;
-- AceConfig-3.0, AceConfigDialog-3.0, AceDBOptions-3.0 return minimal stubs.
_G.LibStub = function(name, _silent)
    if name == "AceAddon-3.0" then
        return {
            GetAddon = function()
                return LunarUI
            end,
        }
    elseif name == "AceConfig-3.0" then
        return {
            RegisterOptionsTable = function() end,
        }
    elseif name == "AceConfigDialog-3.0" then
        return {
            AddToBlizOptions = function() end,
            SetDefaultSize = function() end,
            Open = function() end,
            OpenFrames = {},
        }
    elseif name == "AceDBOptions-3.0" then
        return nil -- optional lib
    end
    return nil
end

-- Minimal WoW frame stubs
_G.CreateFrame = function(_frameType, _name, _parent, _template)
    return {
        RegisterEvent = function() end,
        UnregisterEvent = function() end,
        SetScript = function() end,
        Show = function() end,
        Hide = function() end,
        GetParent = function()
            return nil
        end,
    }
end

_G.C_AddOns = {
    IsAddOnLoaded = function()
        return false
    end,
    LoadAddOn = function() end,
}

_G.C_Timer = { After = function() end }
_G.GetNumSpecializations = function()
    return 0
end
_G.GetSpecializationInfo = function()
    return nil, nil
end

-- Load every section builder first so Private.sections.* is populated. Each
-- section file gets the same (addonName, Private) varargs via loadfile+chunk,
-- so they all write into the shared Private.sections table.
-- Options.lua then reads those builders and calls ApplySection for each — this
-- is what verifies every section is wired into options.args (regression guard
-- against Phase 3 Wave 4 where builder files existed but ApplySection calls
-- were missing, leaving the options panel silently empty).
local Private = {}

local sectionFiles = {
    "General",
    "UnitFrames",
    "ActionBars",
    "Nameplates",
    "HUD",
    "Minimap",
    "Bags",
    "Chat",
    "Tooltip",
    "FrameMover",
    "Style",
    "Loot",
    "DataBars",
    "DataTexts",
    "Automation",
    "Skins",
}

for _, name in ipairs(sectionFiles) do
    local path = "LunarUI_Options/sections/" .. name .. ".lua"
    local sc, serr = loadfile(path)
    if not sc then
        error("Failed to load " .. path .. ": " .. tostring(serr))
    end
    sc("LunarUI_Options", Private)
end

-- Load shared helpers (Search.lua / Frame.lua) so Private.search.* and
-- Private.frame.* are populated before Options.lua consumes them.
for _, helper in ipairs({ "Search", "Frame" }) do
    local path = "LunarUI_Options/" .. helper .. ".lua"
    local sc, serr = loadfile(path)
    if not sc then
        error("Failed to load " .. path .. ": " .. tostring(serr))
    end
    sc("LunarUI_Options", Private)
end

-- Load Options.lua with the populated Private table so ApplySection wires the
-- builders into options.args.
local chunk, err = loadfile("LunarUI_Options/Options.lua")
if not chunk then
    error("Failed to load LunarUI_Options/Options.lua: " .. tostring(err))
end
chunk("LunarUI_Options", Private)

-- Grab exported functions from LunarUI
local SafeGetField = LunarUI.Options_SafeGetField
local BuildSearchIndex = LunarUI.Options_BuildSearchIndex
local FilterSearchResults = LunarUI.Options_FilterSearchResults
local SetSearchIndex = LunarUI.Options_SetSearchIndex
local GetOptionsTable = LunarUI.Options_GetOptionsTable

--------------------------------------------------------------------------------
-- SafeGetField
--------------------------------------------------------------------------------

describe("SafeGetField", function()
    it("returns string value for string field", function()
        assert.equals("Hello", SafeGetField("Hello"))
    end)

    it("returns empty string for empty string field", function()
        assert.equals("", SafeGetField(""))
    end)

    it("returns result of callable field when it returns a string", function()
        local result = SafeGetField(function()
            return "from callable"
        end)
        assert.equals("from callable", result)
    end)

    it("returns empty string for callable that returns non-string", function()
        local result = SafeGetField(function()
            return 42
        end)
        assert.equals("", result)
    end)

    it("returns empty string for nil field", function()
        assert.equals("", SafeGetField(nil))
    end)

    it("returns empty string for numeric field", function()
        assert.equals("", SafeGetField(123))
    end)

    it("handles callable field that errors (returns empty string, not crash)", function()
        assert.has_no_errors(function()
            local result = SafeGetField(function()
                error("boom")
            end)
            assert.equals("", result)
        end)
    end)

    it("returns empty string when callable returns nil", function()
        local result = SafeGetField(function()
            return nil
        end)
        assert.equals("", result)
    end)
end)

--------------------------------------------------------------------------------
-- BuildSearchIndex
--------------------------------------------------------------------------------

describe("BuildSearchIndex", function()
    it("returns empty table for nil args", function()
        local results = BuildSearchIndex(nil, "", {})
        assert.same({}, results)
    end)

    it("returns empty table for empty args", function()
        local results = BuildSearchIndex({}, "", {})
        assert.same({}, results)
    end)

    it("indexes a simple flat toggle option", function()
        local args = {
            myToggle = {
                type = "toggle",
                name = "My Toggle",
                desc = "Toggle something",
            },
        }
        local results = BuildSearchIndex(args, "", {})
        assert.equals(1, #results)
        assert.equals("My Toggle", results[1].name)
        assert.equals("Toggle something", results[1].desc)
        assert.is_false(results[1].isGroup)
    end)

    it("indexes a range option as a leaf node", function()
        local args = {
            myRange = {
                type = "range",
                name = "Font Size",
                desc = "Adjust font size",
            },
        }
        local results = BuildSearchIndex(args, "", {})
        assert.equals(1, #results)
        assert.equals("Font Size", results[1].name)
        assert.is_false(results[1].isGroup)
    end)

    it("indexes a group entry as isGroup=true", function()
        local args = {
            myGroup = {
                type = "group",
                name = "My Group",
                desc = "Group desc",
                args = {},
            },
        }
        local results = BuildSearchIndex(args, "", {})
        -- At minimum the group itself should be indexed
        local found = nil
        for _, r in ipairs(results) do
            if r.name == "My Group" then
                found = r
            end
        end
        assert.is_not_nil(found)
        assert.is_true(found.isGroup)
    end)

    it("indexes nested groups recursively", function()
        local args = {
            outer = {
                type = "group",
                name = "Outer",
                desc = "",
                args = {
                    inner = {
                        type = "group",
                        name = "Inner",
                        desc = "",
                        args = {
                            leaf = {
                                type = "toggle",
                                name = "Leaf Option",
                                desc = "",
                            },
                        },
                    },
                },
            },
        }
        local results = BuildSearchIndex(args, "", {})
        -- Should have: outer group, inner group, leaf toggle
        assert.is_true(#results >= 3)

        local names = {}
        for _, r in ipairs(results) do
            names[r.name] = true
        end
        assert.is_true(names["Outer"])
        assert.is_true(names["Inner"])
        assert.is_true(names["Leaf Option"])
    end)

    it("strips WoW color codes from option names", function()
        local args = {
            colored = {
                type = "toggle",
                name = "|cff8882ffLunar|r|cffffffffUI|r",
                desc = "|cff888888Some description|r",
            },
        }
        local results = BuildSearchIndex(args, "", {})
        assert.equals(1, #results)
        assert.equals("LunarUI", results[1].name)
        assert.equals("Some description", results[1].desc)
    end)

    it("breadcrumb path is correct for a flat option", function()
        local args = {
            myOpt = {
                type = "toggle",
                name = "My Option",
                desc = "",
            },
        }
        local results = BuildSearchIndex(args, "General", {})
        assert.equals(1, #results)
        assert.equals("General > My Option", results[1].breadcrumbs)
    end)

    it("breadcrumb path is correct for nested entries", function()
        local args = {
            grp = {
                type = "group",
                name = "Settings",
                desc = "",
                args = {
                    opt = {
                        type = "toggle",
                        name = "Option A",
                        desc = "",
                    },
                },
            },
        }
        local results = BuildSearchIndex(args, "", {})
        -- Find "Option A" entry
        local optEntry = nil
        for _, r in ipairs(results) do
            if r.name == "Option A" then
                optEntry = r
            end
        end
        assert.is_not_nil(optEntry)
        assert.equals("Settings > Option A", optEntry.breadcrumbs)
    end)

    it("skips header and description type entries", function()
        local args = {
            myHeader = {
                type = "header",
                name = "Section Header",
            },
            myDesc = {
                type = "description",
                name = "Some description text",
            },
            myOpt = {
                type = "toggle",
                name = "Real Option",
                desc = "",
            },
        }
        local results = BuildSearchIndex(args, "", {})
        -- Only the real toggle should appear
        assert.equals(1, #results)
        assert.equals("Real Option", results[1].name)
    end)

    it("includes path in result entries", function()
        local args = {
            grp = {
                type = "group",
                name = "MyGroup",
                desc = "",
                args = {
                    opt = {
                        type = "toggle",
                        name = "My Option",
                        desc = "",
                    },
                },
            },
        }
        local results = BuildSearchIndex(args, "", {})
        -- Find the leaf option
        local leaf = nil
        for _, r in ipairs(results) do
            if r.name == "My Option" then
                leaf = r
            end
        end
        assert.is_not_nil(leaf)
        -- path should contain "grp" (the parent group key)
        assert.equals("grp", leaf.path[1])
    end)

    it("handles callable name fields", function()
        local args = {
            dynOpt = {
                type = "toggle",
                name = function()
                    return "Dynamic Name"
                end,
                desc = "",
            },
        }
        local results = BuildSearchIndex(args, "", {})
        assert.equals(1, #results)
        assert.equals("Dynamic Name", results[1].name)
    end)
end)

--------------------------------------------------------------------------------
-- FilterSearchResults
--------------------------------------------------------------------------------

describe("FilterSearchResults", function()
    -- Build a fixed index for deterministic tests
    local testIndex = {
        {
            name = "Font Size",
            desc = "Adjust font size",
            breadcrumbs = "Style > Font Size",
            path = { "style" },
            isGroup = false,
        },
        {
            name = "Font Family",
            desc = "Choose font",
            breadcrumbs = "Style > Font Family",
            path = { "style" },
            isGroup = false,
        },
        { name = "Scale", desc = "Adjust HUD scale", breadcrumbs = "HUD > Scale", path = { "hud" }, isGroup = false },
        { name = "Style", desc = "Visual style settings", breadcrumbs = "Style", path = {}, isGroup = true },
        {
            name = "Enable",
            desc = "Enable the module",
            breadcrumbs = "General > Enable",
            path = { "general" },
            isGroup = false,
        },
        {
            name = "Debug Mode",
            desc = "Show debug info",
            breadcrumbs = "General > Debug Mode",
            path = { "general" },
            isGroup = false,
        },
        {
            name = "Button Spacing",
            desc = "Space between buttons",
            breadcrumbs = "ActionBars > Button Spacing",
            path = { "actionbars" },
            isGroup = false,
        },
    }

    before_each(function()
        SetSearchIndex(testIndex)
    end)

    it("returns empty table for empty query", function()
        local results = FilterSearchResults("")
        assert.same({}, results)
    end)

    it("returns empty table for nil query", function()
        local results = FilterSearchResults(nil)
        assert.same({}, results)
    end)

    it("returns matching entries for a valid query", function()
        local results = FilterSearchResults("font")
        -- "Font Size" and "Font Family" both match by name
        assert.is_true(#results >= 2)
    end)

    it("matches are case-insensitive", function()
        local results = FilterSearchResults("FONT")
        assert.is_true(#results >= 2)

        local results2 = FilterSearchResults("Font")
        assert.equals(#results, #results2)
    end)

    it("returns empty table when no match exists", function()
        local results = FilterSearchResults("zzznomatch")
        assert.same({}, results)
    end)

    it("matches by description", function()
        -- "Debug Mode" has desc "Show debug info"
        local results = FilterSearchResults("debug info")
        local found = false
        for _, r in ipairs(results) do
            if r.name == "Debug Mode" then
                found = true
            end
        end
        assert.is_true(found)
    end)

    it("matches by breadcrumb path", function()
        -- "Scale" lives under "HUD > Scale"
        local results = FilterSearchResults("hud")
        local found = false
        for _, r in ipairs(results) do
            if r.name == "Scale" then
                found = true
            end
        end
        assert.is_true(found)
    end)

    it("name match has higher priority than description-only match", function()
        -- "Scale" matches by name; "Adjust HUD scale" would match desc for "scale"
        -- "Font Size" matches name for "size"; "Button Spacing" matches desc for "space"
        -- Inject simple index: one name match, one desc match
        SetSearchIndex({
            { name = "Name Match", desc = "irrelevant", breadcrumbs = "Name Match", path = {}, isGroup = false },
            { name = "Other", desc = "Contains scale in desc", breadcrumbs = "Other", path = {}, isGroup = false },
        })
        local results = FilterSearchResults("name match")
        -- First result should be the name match
        assert.equals("Name Match", results[1].name)
    end)

    it("sorts results: name match (priority 1) before desc match (priority 2)", function()
        SetSearchIndex({
            { name = "Alpha", desc = "Contains scale word", breadcrumbs = "Alpha", path = {}, isGroup = false },
            { name = "scale", desc = "no match here", breadcrumbs = "scale", path = {}, isGroup = false },
        })
        local results = FilterSearchResults("scale")
        assert.equals("scale", results[1].name) -- name match comes first
        assert.equals("Alpha", results[2].name) -- desc match second
    end)

    it("within same priority, results are sorted alphabetically by name", function()
        SetSearchIndex({
            { name = "Zebra Font", desc = "", breadcrumbs = "Zebra Font", path = {}, isGroup = false },
            { name = "Alpha Font", desc = "", breadcrumbs = "Alpha Font", path = {}, isGroup = false },
            { name = "Middle Font", desc = "", breadcrumbs = "Middle Font", path = {}, isGroup = false },
        })
        local results = FilterSearchResults("font")
        assert.equals(3, #results)
        assert.equals("Alpha Font", results[1].name)
        assert.equals("Middle Font", results[2].name)
        assert.equals("Zebra Font", results[3].name)
    end)

    it("limits results to at most 20 entries", function()
        -- Build an index with 25 matching entries
        local bigIndex = {}
        for i = 1, 25 do
            bigIndex[i] = {
                name = "Option " .. i,
                desc = "test option",
                breadcrumbs = "Option " .. i,
                path = {},
                isGroup = false,
            }
        end
        SetSearchIndex(bigIndex)
        local results = FilterSearchResults("option")
        assert.is_true(#results <= 20)
    end)

    it("returns all matching entries when under limit", function()
        -- testIndex was reset in before_each to 7 entries; query "e" should match several
        SetSearchIndex(testIndex)
        local results = FilterSearchResults("enable")
        -- Only "Enable" has "enable" in name; check it's returned
        local found = false
        for _, r in ipairs(results) do
            if r.name == "Enable" then
                found = true
            end
        end
        assert.is_true(found)
    end)
end)

--------------------------------------------------------------------------------
-- Section wiring — regression guard for Phase 3 refactor
--
-- These tests ensure every extracted sections/*.lua builder is registered via
-- ApplySection in Options.lua. Without them, a section file can exist and
-- populate Private.sections.X but never get wired into options.args, leaving
-- that tab silently missing from the in-game panel.
--------------------------------------------------------------------------------

describe("Section wiring", function()
    local expectedSectionKeys = {
        "general",
        "unitframes",
        "actionbars",
        "nameplates",
        "hud",
        "minimap",
        "bags",
        "chat",
        "tooltip",
        "frameMover",
        "style",
        "loot",
        "databars",
        "datatexts",
        "automation",
        "skins",
    }

    it("GetOptionsTable is exported", function()
        assert.is_function(GetOptionsTable)
    end)

    it("options.args contains every extracted section", function()
        local opts = GetOptionsTable()
        assert.is_not_nil(opts)
        assert.is_not_nil(opts.args)
        for _, key in ipairs(expectedSectionKeys) do
            assert.is_not_nil(opts.args[key], "missing options.args." .. key)
            assert.equals("group", opts.args[key].type, key .. " should be a group")
        end
    end)

    it("ActionBars dynamic bars are populated (bar1..bar6 / petbar / stancebar)", function()
        local opts = GetOptionsTable()
        local ab = opts.args.actionbars
        assert.is_not_nil(ab, "actionbars section not wired")
        assert.is_not_nil(ab.args, "actionbars.args missing")
        for i = 1, 6 do
            assert.is_not_nil(ab.args["bar" .. i], "missing actionbars.args.bar" .. i)
        end
        assert.is_not_nil(ab.args.petbar, "missing actionbars.args.petbar")
        assert.is_not_nil(ab.args.stancebar, "missing actionbars.args.stancebar")
    end)
end)
