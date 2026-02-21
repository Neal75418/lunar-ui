--[[
    Unit tests for LunarUI/Core/Serialization.lua
    Tests SerializeValue and DeserializeString round-trip integrity
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

loader.loadAddonFile("LunarUI/Core/Serialization.lua", LunarUI)

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
