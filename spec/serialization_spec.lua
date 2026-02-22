--[[
    Unit tests for LunarUI/Core/Serialization.lua
    Tests SerializeValue, DeserializeString, MergeTable round-trip integrity
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Serialization.lua references LunarUI.Colors, need to provide it
local LunarUI = {
    Colors = {
        bgSolid = { 0, 0, 0, 0.9 },
        border = { 0.3, 0.3, 0.4, 1 },
        textDim = { 0.5, 0.5, 0.5 },
    },
}

-- Stub WoW frame creation functions (not needed for serialize/deserialize logic)
_G.CreateFrame = function()
    return {
        SetSize = function() end,
        SetPoint = function() end,
        SetFrameStrata = function() end,
        SetMovable = function() end,
        EnableMouse = function() end,
        RegisterForDrag = function() end,
        SetScript = function() end,
        SetBackdrop = function() end,
        SetBackdropColor = function() end,
        SetBackdropBorderColor = function() end,
        CreateFontString = function()
            return {
                SetPoint = function() end,
                SetText = function() end,
                SetTextColor = function() end,
            }
        end,
        Hide = function() end,
        Show = function() end,
        GetWidth = function()
            return 400
        end,
        SetMultiLine = function() end,
        SetWidth = function() end,
        SetAutoFocus = function() end,
        SetScrollChild = function() end,
        StartMoving = function() end,
        StopMovingOrSizing = function() end,
        SetNormalFontObject = function() end,
        GetFontString = function()
            return {}
        end,
        SetText = function() end,
        HighlightText = function() end,
        SetFocus = function() end,
        GetText = function()
            return ""
        end,
    }
end
_G.UIParent = {}
_G.GameFontNormal = {}
_G.GameTooltip =
    { SetOwner = function() end, ClearLines = function() end, AddLine = function() end, Show = function() end }

-- Stub LunarUI methods used during loading
LunarUI.ApplyBackdrop = function() end
LunarUI.SetFont = function() end
LunarUI.version = "1.0-test"
LunarUI.Print = function() end
LunarUI.OnProfileChanged = function() end

-- Defaults template for ImportSettings tests
local testDefaults = {
    profile = {
        style = { fontSize = 12, theme = "lunar" },
        hud = { scale = 1.0, enabled = true },
        actionbars = {
            bar1 = { buttonSize = 36, enabled = true },
            bar2 = { buttonSize = 36, enabled = true },
        },
        unitframes = {
            player = { enabled = true, width = 220 },
        },
    },
}

loader.loadAddonFile("LunarUI/Core/Serialization.lua", LunarUI, { _defaults = testDefaults })

--------------------------------------------------------------------------------
-- SerializeValue
--------------------------------------------------------------------------------

describe("SerializeValue", function()
    it("serializes nil", function()
        assert.equals("nil", LunarUI.SerializeValue(nil))
    end)

    it("serializes boolean true", function()
        assert.equals("true", LunarUI.SerializeValue(true))
    end)

    it("serializes boolean false", function()
        assert.equals("false", LunarUI.SerializeValue(false))
    end)

    it("serializes integer", function()
        assert.equals("42", LunarUI.SerializeValue(42))
    end)

    it("serializes float", function()
        assert.equals("3.14", LunarUI.SerializeValue(3.14))
    end)

    it("serializes string", function()
        local result = LunarUI.SerializeValue("hello")
        assert.is_string(result)
        assert.truthy(result:find("hello"))
    end)

    it("serializes empty table", function()
        assert.equals("{}", LunarUI.SerializeValue({}))
    end)

    it("serializes simple table", function()
        local result = LunarUI.SerializeValue({ a = 1 })
        assert.is_string(result)
        assert.truthy(result:find("a"))
    end)

    it("handles circular references without crashing", function()
        local t = {}
        t.self = t
        local result = LunarUI.SerializeValue(t)
        assert.is_string(result)
    end)

    it("handles deep nesting up to limit", function()
        local t = { val = "leaf" }
        for _ = 1, 25 do
            t = { inner = t }
        end
        local result = LunarUI.SerializeValue(t)
        assert.is_string(result)
    end)
end)

--------------------------------------------------------------------------------
-- DeserializeString
--------------------------------------------------------------------------------

describe("DeserializeString", function()
    it("deserializes nil", function()
        local result = LunarUI.DeserializeString("nil")
        assert.is_nil(result)
    end)

    it("deserializes true", function()
        local result = LunarUI.DeserializeString("true")
        assert.is_true(result)
    end)

    it("deserializes false", function()
        local result = LunarUI.DeserializeString("false")
        assert.equals(false, result)
    end)

    it("deserializes integer", function()
        local result = LunarUI.DeserializeString("42")
        assert.equals(42, result)
    end)

    it("deserializes negative number", function()
        local result = LunarUI.DeserializeString("-3.14")
        assert.near(-3.14, result, 0.001)
    end)

    it("deserializes quoted string", function()
        local result = LunarUI.DeserializeString('"hello"')
        assert.equals("hello", result)
    end)

    it("deserializes empty table", function()
        local result = LunarUI.DeserializeString("{}")
        assert.same({}, result)
    end)

    it("returns error for empty input", function()
        local result, err = LunarUI.DeserializeString("")
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns error for nil input", function()
        local result, err = LunarUI.DeserializeString(nil)
        assert.is_nil(result)
        assert.is_string(err)
    end)
end)

--------------------------------------------------------------------------------
-- Round-trip tests
--------------------------------------------------------------------------------

describe("Serialization round-trip", function()
    it("preserves simple table", function()
        local input = { a = 1, b = "hello", c = true }
        local serialized = LunarUI.SerializeValue(input)
        local result = LunarUI.DeserializeString(serialized)
        assert.same(input, result)
    end)

    it("preserves nested tables", function()
        local input = { nested = { deep = { value = 42 } } }
        local serialized = LunarUI.SerializeValue(input)
        local result = LunarUI.DeserializeString(serialized)
        assert.same(input, result)
    end)

    it("preserves boolean values", function()
        local input = { enabled = true, debug = false }
        local serialized = LunarUI.SerializeValue(input)
        local result = LunarUI.DeserializeString(serialized)
        assert.same(input, result)
    end)

    it("preserves numeric values", function()
        local input = { integer = 42, float = 3.14, negative = -10 }
        local serialized = LunarUI.SerializeValue(input)
        local result = LunarUI.DeserializeString(serialized)
        assert.equals(42, result.integer)
        assert.near(3.14, result.float, 0.001)
        assert.equals(-10, result.negative)
    end)

    it("preserves string with special characters", function()
        local input = { text = 'hello "world"\nnewline' }
        local serialized = LunarUI.SerializeValue(input)
        local result = LunarUI.DeserializeString(serialized)
        assert.same(input, result)
    end)

    it("preserves LunarUI-like config structure", function()
        local input = {
            unitframes = {
                player = { enabled = true, width = 220, height = 45 },
                target = { enabled = true, width = 220, height = 45 },
            },
            hud = { scale = 1.0 },
            style = { theme = "lunar" },
        }
        local serialized = LunarUI.SerializeValue(input)
        local result = LunarUI.DeserializeString(serialized)
        assert.same(input, result)
    end)
end)

--------------------------------------------------------------------------------
-- DeserializeString edge cases
--------------------------------------------------------------------------------

describe("DeserializeString edge cases", function()
    it("handles escape sequence \\n", function()
        local result = LunarUI.DeserializeString('"line1\\nline2"')
        assert.equals("line1\nline2", result)
    end)

    it("handles escape sequence \\t", function()
        local result = LunarUI.DeserializeString('"col1\\tcol2"')
        assert.equals("col1\tcol2", result)
    end)

    it("handles escape sequence \\\\", function()
        local result = LunarUI.DeserializeString('"back\\\\slash"')
        assert.equals("back\\slash", result)
    end)

    it('handles escape sequence \\"', function()
        local result = LunarUI.DeserializeString('"say \\"hello\\""')
        assert.equals('say "hello"', result)
    end)

    it("parses single-quoted string", function()
        local result = LunarUI.DeserializeString("'hello world'")
        assert.equals("hello world", result)
    end)

    it("parses bare identifier key", function()
        local result = LunarUI.DeserializeString("{foo=42}")
        assert.equals(42, result.foo)
    end)

    it("parses numeric key with brackets", function()
        local result = LunarUI.DeserializeString('{[1]="a"}')
        assert.equals("a", result[1])
    end)

    it("returns error for unterminated string", function()
        local result, err = LunarUI.DeserializeString('"no end')
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns error for unterminated table", function()
        local result, err = LunarUI.DeserializeString("{foo=1")
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns error for trailing data after value", function()
        local result, err = LunarUI.DeserializeString("42 extra")
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("parses comma-separated table entries", function()
        local result = LunarUI.DeserializeString("{a=1,b=2}")
        assert.equals(1, result.a)
        assert.equals(2, result.b)
    end)

    it("returns error for table with missing comma between entries", function()
        local result, err = LunarUI.DeserializeString("{ a = 1  b = 2 }")
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("parses nested tables", function()
        local result = LunarUI.DeserializeString("{outer={inner=true}}")
        assert.is_true(result.outer.inner)
    end)

    it("returns error for standalone minus sign", function()
        local result, err = LunarUI.DeserializeString("-")
        assert.is_nil(result)
        assert.is_string(err)
    end)
end)

--------------------------------------------------------------------------------
-- MergeTable
--------------------------------------------------------------------------------

describe("MergeTable", function()
    it("merges matching-type number values", function()
        local target = { a = 10 }
        LunarUI.MergeTable(target, { a = 20 }, { a = 0 })
        assert.equals(20, target.a)
    end)

    it("merges matching-type string values", function()
        local target = { name = "old" }
        LunarUI.MergeTable(target, { name = "new" }, { name = "" })
        assert.equals("new", target.name)
    end)

    it("merges matching-type boolean values", function()
        local target = { enabled = false }
        LunarUI.MergeTable(target, { enabled = true }, { enabled = false })
        assert.is_true(target.enabled)
    end)

    it("skips keys not in template", function()
        local target = { a = 1 }
        LunarUI.MergeTable(target, { a = 2, unknown = 99 }, { a = 0 })
        assert.equals(2, target.a)
        assert.is_nil(target.unknown)
    end)

    it("recursively merges nested tables", function()
        local target = { sub = { x = 1, y = 2 } }
        LunarUI.MergeTable(target, { sub = { x = 10 } }, { sub = { x = 0, y = 0 } })
        assert.equals(10, target.sub.x)
        assert.equals(2, target.sub.y)
    end)

    it("skips when source type differs from template", function()
        local target = { a = 10 }
        LunarUI.MergeTable(target, { a = "wrong type" }, { a = 0 })
        assert.equals(10, target.a)
    end)

    it("allows extra keys (nilDefaultKeys) with any type", function()
        local target = { pos = nil }
        LunarUI.MergeTable(target, { pos = { x = 100 } }, {}, { pos = true })
        assert.same({ x = 100 }, target.pos)
    end)

    it("no-op when template is nil", function()
        local target = { a = 1 }
        LunarUI.MergeTable(target, { a = 99 }, nil)
        assert.equals(1, target.a)
    end)

    it("no-op when source is empty", function()
        local target = { a = 1 }
        LunarUI.MergeTable(target, {}, { a = 0 })
        assert.equals(1, target.a)
    end)

    it("handles deep extra keys for nested paths", function()
        local target = { bars = { bar1 = { fade = nil } } }
        local source = { bars = { bar1 = { fade = true } } }
        local template = { bars = { bar1 = {} } }
        local extra = { bars = { bar1 = { fade = true } } }
        LunarUI.MergeTable(target, source, template, extra)
        assert.is_true(target.bars.bar1.fade)
    end)
end)

--------------------------------------------------------------------------------
-- ClampImportedValues
--------------------------------------------------------------------------------

describe("ClampImportedValues", function()
    it("clamps fontSize below 8 to 8", function()
        local profile = { style = { fontSize = 4 } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(8, profile.style.fontSize)
    end)

    it("clamps fontSize above 24 to 24", function()
        local profile = { style = { fontSize = 50 } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(24, profile.style.fontSize)
    end)

    it("leaves fontSize in range unchanged", function()
        local profile = { style = { fontSize = 14 } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(14, profile.style.fontSize)
    end)

    it("clamps hud.scale below 0.5", function()
        local profile = { hud = { scale = 0.1 } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(0.5, profile.hud.scale)
    end)

    it("clamps hud.scale above 2.0", function()
        local profile = { hud = { scale = 5.0 } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(2.0, profile.hud.scale)
    end)

    it("clamps bar buttonSize below 24 to 24", function()
        local profile = { actionbars = { bar1 = { buttonSize = 10 } } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(24, profile.actionbars.bar1.buttonSize)
    end)

    it("clamps bar buttonSize above 48 to 48", function()
        local profile = { actionbars = { bar3 = { buttonSize = 100 } } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(48, profile.actionbars.bar3.buttonSize)
    end)

    it("does nothing when profile has no style/hud/actionbars", function()
        local profile = { unitframes = { player = {} } }
        LunarUI.ClampImportedValues(profile)
        assert.same({ unitframes = { player = {} } }, profile)
    end)

    it("ignores non-number fontSize", function()
        local profile = { style = { fontSize = "big" } }
        LunarUI.ClampImportedValues(profile)
        assert.equals("big", profile.style.fontSize)
    end)
end)

--------------------------------------------------------------------------------
-- ExportSettings
--------------------------------------------------------------------------------

describe("ExportSettings", function()
    it("returns nil with error when db is nil", function()
        LunarUI.db = nil
        local result, err = LunarUI:ExportSettings()
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns nil with error when db.profile is nil", function()
        LunarUI.db = { profile = nil }
        local result, err = LunarUI:ExportSettings()
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns string starting with LUNARUI header", function()
        LunarUI.db = { profile = { style = { fontSize = 12 } } }
        local result = LunarUI:ExportSettings()
        assert.is_string(result)
        assert.truthy(result:find("^LUNARUI"))
    end)

    it("excludes function values from export", function()
        LunarUI.db = { profile = { callback = function() end, name = "test" } }
        local result = LunarUI:ExportSettings()
        assert.is_string(result)
        assert.is_nil(result:find("callback"))
    end)
end)

--------------------------------------------------------------------------------
-- ImportSettings
--------------------------------------------------------------------------------

describe("ImportSettings", function()
    before_each(function()
        LunarUI.db = {
            profile = {
                style = { fontSize = 12, theme = "lunar" },
                hud = { scale = 1.0, enabled = true },
                actionbars = {
                    bar1 = { buttonSize = 36, enabled = true },
                    bar2 = { buttonSize = 36, enabled = true },
                },
                unitframes = {
                    player = { enabled = true, width = 220 },
                },
            },
        }
    end)

    it("returns false for nil input", function()
        local ok = LunarUI:ImportSettings(nil)
        assert.is_false(ok)
    end)

    it("returns false for empty string", function()
        local ok = LunarUI:ImportSettings("")
        assert.is_false(ok)
    end)

    it("returns false for string exceeding 100KB", function()
        local huge = "LUNARUI" .. string.rep("x", 102401)
        local ok = LunarUI:ImportSettings(huge)
        assert.is_false(ok)
    end)

    it("returns false for missing LUNARUI header", function()
        local ok = LunarUI:ImportSettings("INVALID{profile={}}")
        assert.is_false(ok)
    end)

    it("returns false for invalid serialized data", function()
        local ok = LunarUI:ImportSettings("LUNARUI!!invalid!!")
        assert.is_false(ok)
    end)

    it("returns false for data without profile key", function()
        local ok = LunarUI:ImportSettings('LUNARUI{version="1.0"}')
        assert.is_false(ok)
    end)

    it("returns false when self.db is nil", function()
        LunarUI.db = nil
        local ok = LunarUI:ImportSettings('LUNARUI{profile={},version="1.0"}')
        assert.is_false(ok)
    end)

    it("succeeds with round-trip export then import", function()
        LunarUI.db.profile.style.fontSize = 16
        local exported = LunarUI:ExportSettings()
        -- Reset to defaults
        LunarUI.db.profile.style.fontSize = 12
        local ok, msg = LunarUI:ImportSettings(exported)
        assert.is_true(ok)
        assert.is_string(msg)
        assert.equals(16, LunarUI.db.profile.style.fontSize)
    end)

    it("clamps out-of-range fontSize during import", function()
        local data = {
            version = "1.0",
            profile = { style = { fontSize = 100 } },
        }
        local serialized = "LUNARUI" .. LunarUI.SerializeValue(data)
        local ok = LunarUI:ImportSettings(serialized)
        assert.is_true(ok)
        assert.equals(24, LunarUI.db.profile.style.fontSize)
    end)

    it("skips unknown keys not in defaults template", function()
        local data = {
            version = "1.0",
            profile = { style = { fontSize = 14 }, hackedKey = "evil" },
        }
        local serialized = "LUNARUI" .. LunarUI.SerializeValue(data)
        LunarUI:ImportSettings(serialized)
        assert.is_nil(LunarUI.db.profile.hackedKey)
    end)

    it("includes version in success message", function()
        local data = {
            version = "2.5",
            profile = { style = { fontSize = 14 } },
        }
        local serialized = "LUNARUI" .. LunarUI.SerializeValue(data)
        local ok, msg = LunarUI:ImportSettings(serialized)
        assert.is_true(ok)
        assert.truthy(msg:find("2.5"))
    end)

    it("calls OnProfileChanged on successful import", function()
        local called = false
        local origOnProfileChanged = LunarUI.OnProfileChanged
        LunarUI.OnProfileChanged = function()
            called = true
        end
        local data = {
            version = "1.0",
            profile = { style = { fontSize = 14 } },
        }
        local serialized = "LUNARUI" .. LunarUI.SerializeValue(data)
        LunarUI:ImportSettings(serialized)
        assert.is_true(called)
        LunarUI.OnProfileChanged = origOnProfileChanged
    end)

    it("preserves special characters in profile string values", function()
        LunarUI.db.profile.style.theme = "lunar"
        local data = {
            version = "1.0",
            profile = { style = { theme = "parchment" } },
        }
        local serialized = "LUNARUI" .. LunarUI.SerializeValue(data)
        local ok = LunarUI:ImportSettings(serialized)
        assert.is_true(ok)
    end)

    it("handles import with no version field", function()
        local data = {
            profile = { style = { fontSize = 14 } },
        }
        local serialized = "LUNARUI" .. LunarUI.SerializeValue(data)
        local ok, msg = LunarUI:ImportSettings(serialized)
        assert.is_true(ok)
        assert.is_string(msg)
    end)
end)

--------------------------------------------------------------------------------
-- MergeTable type guard
--------------------------------------------------------------------------------

describe("MergeTable type guard", function()
    it("handles string source gracefully", function()
        local target = { a = 1 }
        LunarUI.MergeTable(target, "not a table", { a = 0 })
        assert.equals(1, target.a)
    end)

    it("handles numeric source gracefully", function()
        local target = { a = 1 }
        LunarUI.MergeTable(target, 42, { a = 0 })
        assert.equals(1, target.a)
    end)

    it("handles boolean source gracefully", function()
        local target = { a = 1 }
        LunarUI.MergeTable(target, true, { a = 0 })
        assert.equals(1, target.a)
    end)
end)
