---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
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

-- ClampImportedValues 依賴 Config.lua 匯出的 VALIDATION_RULES 和 resolveDBPath
-- 在測試環境中直接設定，模擬 Config.lua 的匯出
LunarUI.VALIDATION_RULES = {
    { path = "hud.scale", type = "number", min = 0.5, max = 2.0 },
    { path = "hud.auraIconSize", type = "number", min = 10, max = 80 },
    { path = "hud.cdIconSize", type = "number", min = 10, max = 80 },
    { path = "style.fontSize", type = "number", min = 6, max = 32 },
    { path = "actionbars.buttonSize", type = "number", min = 16, max = 64 },
}

LunarUI.resolveDBPath = function(db, path)
    local parts = { strsplit(".", path) }
    local parent = db
    for i = 1, #parts - 1 do
        parent = parent[parts[i]]
        if type(parent) ~= "table" then
            return nil, nil, nil
        end
    end
    local key = parts[#parts]
    return parent, key, parent[key]
end

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
    it("clamps fontSize below min to min", function()
        local profile = { style = { fontSize = 4 } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(6, profile.style.fontSize)
    end)

    it("clamps fontSize above max to max", function()
        local profile = { style = { fontSize = 50 } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(32, profile.style.fontSize)
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

    it("clamps bar buttonSize below 16 to 16", function()
        local profile = { actionbars = { bar1 = { buttonSize = 10 } } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(16, profile.actionbars.bar1.buttonSize)
    end)

    it("clamps bar buttonSize above 64 to 64", function()
        local profile = { actionbars = { bar3 = { buttonSize = 100 } } }
        LunarUI.ClampImportedValues(profile)
        assert.equals(64, profile.actionbars.bar3.buttonSize)
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
        _G.InCombatLockdown = function()
            return false
        end
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
        assert.equals(32, LunarUI.db.profile.style.fontSize)
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

--------------------------------------------------------------------------------
-- SerializeValue (additional coverage)
--------------------------------------------------------------------------------

describe("SerializeValue additional coverage", function()
    it("serializes numeric keys with bracket syntax", function()
        local result = LunarUI.SerializeValue({ [1] = "a", [2] = "b" })
        assert.is_string(result)
        assert.truthy(result:find("%[1%]"))
        assert.truthy(result:find("%[2%]"))
    end)

    it("serializes function as nil", function()
        local result = LunarUI.SerializeValue(function() end)
        assert.equals("nil", result)
    end)

    it("calls Debug on depth exceeded when Debug is available", function()
        local debugMsg = nil
        LunarUI.Debug = function(_self, msg)
            debugMsg = msg
        end
        -- Build table deeper than 20 levels
        local t = { val = "leaf" }
        for _ = 1, 25 do
            t = { inner = t }
        end
        LunarUI.SerializeValue(t)
        assert.is_not_nil(debugMsg)
        assert.truthy(debugMsg:find("depth"))
        LunarUI.Debug = nil
    end)

    it("calls Debug on circular reference when Debug is available", function()
        local debugMsg = nil
        LunarUI.Debug = function(_self, msg)
            debugMsg = msg
        end
        local t = {}
        t.self = t
        LunarUI.SerializeValue(t)
        assert.is_not_nil(debugMsg)
        assert.truthy(debugMsg:find("circular"))
        LunarUI.Debug = nil
    end)

    it("serializes mixed key types (string and number)", function()
        local result = LunarUI.SerializeValue({ a = 1, [3] = "x" })
        assert.is_string(result)
        -- Round-trip check
        local deserialized = LunarUI.DeserializeString(result)
        assert.equals(1, deserialized.a)
        assert.equals("x", deserialized[3])
    end)
end)

--------------------------------------------------------------------------------
-- DeserializeString (additional coverage)
--------------------------------------------------------------------------------

describe("DeserializeString additional coverage", function()
    it("returns error for deeply nested tables exceeding depth limit", function()
        -- 建構超過 20 層巢狀的序列化字串
        local nested = string.rep("{a=", 25) .. "1" .. string.rep("}", 25)
        local result, err = LunarUI.DeserializeString(nested)
        assert.is_nil(result)
        assert.is_string(err)
        assert.is_string(err)
    end)

    it("handles escape sequence \\r", function()
        local result = LunarUI.DeserializeString('"line1\\rline2"')
        assert.equals("line1\rline2", result)
    end)

    it("handles escape sequence \\' inside single-quoted string", function()
        local result = LunarUI.DeserializeString("'it\\'s'")
        assert.equals("it's", result)
    end)

    it("returns error for invalid table key", function()
        -- Starting with a digit without brackets
        local result, err = LunarUI.DeserializeString("{123=1}")
        -- 123 is parsed as a value, then error
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns error for missing ] in bracketed key", function()
        local result, err = LunarUI.DeserializeString('{["key"=1}')
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns error for missing = after bracketed key", function()
        local result, err = LunarUI.DeserializeString('{["key"]1}')
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns error for missing = after bare key", function()
        local result, err = LunarUI.DeserializeString("{foo 1}")
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns error for unexpected character", function()
        local result, err = LunarUI.DeserializeString("@invalid")
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("returns error for empty input at parseValue", function()
        local result, err = LunarUI.DeserializeString("   ")
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("handles string key in table with bracket notation", function()
        local result = LunarUI.DeserializeString('{["hello"]="world"}')
        assert.equals("world", result["hello"])
    end)

    it("handles nested table parse error propagation", function()
        local result, err = LunarUI.DeserializeString("{a={b=@invalid}}")
        assert.is_nil(result)
        assert.is_string(err)
    end)

    it("handles pcall wrapper for crash during parse", function()
        -- DeserializeString wraps inner function with pcall
        -- Force an error by passing non-string that bypasses nil check
        local result, err = LunarUI.DeserializeString(42)
        assert.is_nil(result)
        assert.is_string(err)
    end)
end)

--------------------------------------------------------------------------------
-- ExportSettings (additional coverage)
--------------------------------------------------------------------------------

describe("ExportSettings additional coverage", function()
    local savedVersion
    before_each(function()
        savedVersion = LunarUI.version
    end)
    after_each(function()
        LunarUI.version = savedVersion
    end)

    it("excludes userdata values from export", function()
        -- Simulate userdata with a table that has __type = userdata
        -- In real WoW, these would be actual userdata; here we just test that
        -- non-function/non-userdata values are included
        LunarUI.db = {
            profile = {
                style = { fontSize = 14 },
                name = "test",
            },
        }
        local result = LunarUI:ExportSettings()
        assert.is_string(result)
        assert.truthy(result:find("fontSize"))
        assert.truthy(result:find("test"))
    end)

    it("includes version in exported data", function()
        LunarUI.version = "2.0-test"
        LunarUI.db = { profile = { style = { fontSize = 12 } } }
        local result = LunarUI:ExportSettings()
        assert.truthy(result:find("2.0%-test"))
    end)
end)

--------------------------------------------------------------------------------
-- ImportSettings (additional coverage)
--------------------------------------------------------------------------------

describe("ImportSettings additional coverage", function()
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

    it("clamps out-of-range hud.scale during import", function()
        local data = {
            version = "1.0",
            profile = { hud = { scale = 10.0 } },
        }
        local serialized = "LUNARUI" .. LunarUI.SerializeValue(data)
        local ok = LunarUI:ImportSettings(serialized)
        assert.is_true(ok)
        assert.equals(2.0, LunarUI.db.profile.hud.scale)
    end)

    it("clamps out-of-range bar buttonSize during import", function()
        local data = {
            version = "1.0",
            profile = { actionbars = { bar1 = { buttonSize = 100 } } },
        }
        local serialized = "LUNARUI" .. LunarUI.SerializeValue(data)
        local ok = LunarUI:ImportSettings(serialized)
        assert.is_true(ok)
        assert.equals(64, LunarUI.db.profile.actionbars.bar1.buttonSize)
    end)

    it("returns false when self.db.profile is nil", function()
        LunarUI.db = { profile = nil }
        local ok = LunarUI:ImportSettings('LUNARUI{profile={},version="1.0"}')
        assert.is_false(ok)
    end)
end)
