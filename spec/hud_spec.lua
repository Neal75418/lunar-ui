---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for HUD module pure functions
    Tests: GetTimerBarColor, Sanitize, ShouldShowBuff, FCTGetSettings
]]

require("spec.wow_mock")
local loader = require("spec.loader")

--------------------------------------------------------------------------------
-- GetTimerBarColor (AuraFrames.lua)
--------------------------------------------------------------------------------

local mock_frame = require("spec.mock_frame")

local LunarUI_AF = {}
LunarUI_AF.Colors = {
    bgSolid = { 0, 0, 0, 0.8 },
    border = { 0, 0, 0, 1 },
    bgIcon = { 0, 0, 0, 0.8 },
}
LunarUI_AF.DEBUFF_TYPE_COLORS = { [""] = { r = 0.8, g = 0, b = 0 } }
LunarUI_AF.iconBackdropTemplate = {}
LunarUI_AF.ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }
LunarUI_AF.GetHUDSetting = function(_key, default)
    -- Return the provided default (enables auraFrames = true, returns numeric defaults correctly)
    if default == false then
        return false
    end
    return default
end
LunarUI_AF.SetFont = function() end
LunarUI_AF.RegisterModule = function() end
LunarUI_AF.RegisterHUDFrame = function() end
LunarUI_AF.RegisterMovableFrame = function() end
LunarUI_AF.GetModuleDB = function(key)
    if not LunarUI_AF.db or not LunarUI_AF.db.profile then
        return nil
    end
    return LunarUI_AF.db.profile[key]
end
LunarUI_AF.CreateEventHandler = function()
    return mock_frame.newFrame()
end

loader.loadAddonFile("LunarUI/HUD/AuraFrames.lua", LunarUI_AF)

describe("GetTimerBarColor", function()
    local GetTimerBarColor = LunarUI_AF.GetTimerBarColor

    it("returns grey for nil remaining", function()
        local r, g, b = GetTimerBarColor(nil, 10)
        assert.equals(0.5, r)
        assert.equals(0.5, g)
        assert.equals(0.5, b)
    end)

    it("returns grey for nil duration", function()
        local r, g, b = GetTimerBarColor(5, nil)
        assert.equals(0.5, r)
        assert.equals(0.5, g)
        assert.equals(0.5, b)
    end)

    it("returns grey for zero duration", function()
        local r, g, b = GetTimerBarColor(5, 0)
        assert.equals(0.5, r)
        assert.equals(0.5, g)
        assert.equals(0.5, b)
    end)

    it("returns green for > 50% remaining", function()
        local r, g, b = GetTimerBarColor(8, 10)
        assert.equals(0.2, r)
        assert.equals(0.7, g)
        assert.equals(0.2, b)
    end)

    it("returns yellow for 20-50% remaining", function()
        local r, g, b = GetTimerBarColor(4, 10)
        assert.equals(0.9, r)
        assert.equals(0.7, g)
        assert.equals(0.1, b)
    end)

    it("returns red for < 20% remaining", function()
        local r, g, b = GetTimerBarColor(1, 10)
        assert.equals(0.9, r)
        assert.equals(0.2, g)
        assert.equals(0.2, b)
    end)

    it("returns yellow at exactly 50% boundary", function()
        local r, g, b = GetTimerBarColor(5, 10)
        assert.equals(0.9, r)
        assert.equals(0.7, g)
        assert.equals(0.1, b)
    end)

    it("returns red at exactly 20% boundary", function()
        local r, g, b = GetTimerBarColor(2, 10)
        assert.equals(0.9, r)
        assert.equals(0.2, g)
        assert.equals(0.2, b)
    end)
end)

--------------------------------------------------------------------------------
-- Sanitize (FloatingCombatText.lua)
--------------------------------------------------------------------------------

local LunarUI_FCT = {}
LunarUI_FCT.db = { profile = { hud = { fctEnabled = false } } }
LunarUI_FCT.Easing = { OutQuad = function() end, InQuad = function() end }
LunarUI_FCT.RegisterModule = function() end
LunarUI_FCT.GetModuleDB = function(key)
    if not LunarUI_FCT.db or not LunarUI_FCT.db.profile then
        return nil
    end
    return LunarUI_FCT.db.profile[key]
end
LunarUI_FCT.CreateEventHandler = function()
    return nil
end

loader.loadAddonFile("LunarUI/HUD/FloatingCombatText.lua", LunarUI_FCT)

describe("Sanitize", function()
    local Sanitize = LunarUI_FCT.Sanitize

    it("returns nil for nil input", function()
        assert.is_nil(Sanitize(nil))
    end)

    it("sanitizes numbers", function()
        assert.equals(123, Sanitize(123))
    end)

    it("sanitizes zero", function()
        assert.equals(0, Sanitize(0))
    end)

    it("sanitizes negative numbers", function()
        assert.equals(-50, Sanitize(-50))
    end)

    it("sanitizes strings", function()
        assert.equals("test", Sanitize("test"))
    end)

    it("sanitizes empty string", function()
        assert.equals("", Sanitize(""))
    end)

    it("sanitizes true", function()
        assert.is_true(Sanitize(true))
    end)

    it("sanitizes false", function()
        assert.is_false(Sanitize(false))
    end)

    it("passes through tables unchanged", function()
        local t = { 1, 2, 3 }
        assert.equals(t, Sanitize(t))
    end)
end)

--------------------------------------------------------------------------------
-- ShouldShowBuff (AuraFrames.lua)
--------------------------------------------------------------------------------

describe("ShouldShowBuff", function()
    local ShouldShowBuff = LunarUI_AF.ShouldShowBuff

    it("returns true for normal buff", function()
        assert.is_true(ShouldShowBuff("Power Word: Fortitude", 3600))
    end)

    it("returns false for Well Rested", function()
        assert.is_false(ShouldShowBuff("Well Rested", 0))
    end)

    it("returns false for 充分休息", function()
        assert.is_false(ShouldShowBuff("充分休息", 0))
    end)

    it("returns false for Resurrection Sickness", function()
        assert.is_false(ShouldShowBuff("Resurrection Sickness", 600))
    end)

    it("returns false for 復活虛弱", function()
        assert.is_false(ShouldShowBuff("復活虛弱", 600))
    end)

    it("returns true for nil name (not in filter list)", function()
        -- rawget(FILTERED_BUFF_NAMES, nil) = nil → not filtered → return true
        local result = ShouldShowBuff(nil, 10)
        assert.is_true(result)
    end)
end)

--------------------------------------------------------------------------------
-- FCTGetSettings (FloatingCombatText.lua)
--------------------------------------------------------------------------------

describe("FCTGetSettings", function()
    local FCTGetSettings = LunarUI_FCT.FCTGetSettings

    it("returns defaults when db is nil", function()
        local origDb = LunarUI_FCT.db
        LunarUI_FCT.db = nil
        local enabled, fontSize, critScale, duration, dmgOut, dmgIn, healing = FCTGetSettings()
        assert.is_false(enabled)
        assert.equals(24, fontSize)
        assert.equals(1.5, critScale)
        assert.equals(1.5, duration)
        assert.is_true(dmgOut)
        assert.is_true(dmgIn)
        assert.is_true(healing)
        LunarUI_FCT.db = origDb
    end)

    it("returns defaults when profile.hud is nil", function()
        local origDb = LunarUI_FCT.db
        LunarUI_FCT.db = { profile = {} }
        local enabled, fontSize = FCTGetSettings()
        assert.is_false(enabled)
        assert.equals(24, fontSize)
        LunarUI_FCT.db = origDb
    end)

    it("returns actual values from db", function()
        local origDb = LunarUI_FCT.db
        LunarUI_FCT.db = {
            profile = {
                hud = {
                    fctEnabled = true,
                    fctFontSize = 18,
                    fctCritScale = 2.0,
                    fctDuration = 2.0,
                    fctDamageOut = false,
                    fctDamageIn = true,
                    fctHealing = false,
                },
            },
        }
        local enabled, fontSize, critScale, duration, dmgOut, dmgIn, healing = FCTGetSettings()
        assert.is_true(enabled)
        assert.equals(18, fontSize)
        assert.equals(2.0, critScale)
        assert.equals(2.0, duration)
        assert.is_false(dmgOut)
        assert.is_true(dmgIn)
        assert.is_false(healing)
        LunarUI_FCT.db = origDb
    end)

    it("fctEnabled defaults to false when not set", function()
        local origDb = LunarUI_FCT.db
        LunarUI_FCT.db = { profile = { hud = {} } }
        local enabled = FCTGetSettings()
        assert.is_false(enabled)
        LunarUI_FCT.db = origDb
    end)

    it("uses fallback for nil individual settings", function()
        local origDb = LunarUI_FCT.db
        LunarUI_FCT.db = { profile = { hud = { fctEnabled = true } } }
        local enabled, fontSize, critScale, duration, dmgOut, dmgIn, healing = FCTGetSettings()
        assert.is_true(enabled)
        assert.equals(24, fontSize)
        assert.equals(1.5, critScale)
        assert.equals(1.5, duration)
        assert.is_true(dmgOut)
        assert.is_true(dmgIn)
        assert.is_true(healing)
        LunarUI_FCT.db = origDb
    end)
end)
