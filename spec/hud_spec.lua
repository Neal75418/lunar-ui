--[[
    Unit tests for HUD module pure functions
    Tests: FormatCooldown, GetSpellCooldownInfo, CDGetSpellTexture, IsSpellKnownByPlayer,
           GetTimerBarColor, Sanitize, ShouldShowBuff, FCTGetSettings
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- 提供 math 全域函數（CooldownTracker 使用 math_ceil / math_floor 的本地化）
_G.math.ceil = math.ceil
_G.math.floor = math.floor

--------------------------------------------------------------------------------
-- FormatCooldown (CooldownTracker.lua)
--------------------------------------------------------------------------------

-- CooldownTracker 需要較多 WoW API stub，單獨載入純函數
local LunarUI_CD = {}
-- 提供 CooldownTracker 需要的最小 stub
LunarUI_CD.GetHUDSetting = function()
    return true
end
LunarUI_CD.Colors = { bgSolid = { 0, 0, 0, 0.8 }, border = { 0, 0, 0, 1 } }
LunarUI_CD.DEBUFF_TYPE_COLORS = {}
LunarUI_CD.CreateEventHandler = function()
    return nil
end
LunarUI_CD.RegisterModule = function() end

-- C_Spell / IsPlayerSpell 在載入時被 local 捕獲，需先設定
_G.C_Spell = _G.C_Spell or {}
_G.C_Spell.GetSpellCooldown = _G.C_Spell.GetSpellCooldown or function()
    return nil
end
_G.C_Spell.GetSpellInfo = _G.C_Spell.GetSpellInfo or function()
    return nil
end
_G.C_Spell.IsSpellUsable = _G.C_Spell.IsSpellUsable or function()
    return false
end
_G._mockIsPlayerSpell = false
_G.IsPlayerSpell = function()
    return _G._mockIsPlayerSpell
end

loader.loadAddonFile("LunarUI/HUD/CooldownTracker.lua", LunarUI_CD)

describe("FormatCooldown", function()
    local FormatCooldown = LunarUI_CD.FormatCooldown

    it("formats minutes for >= 60 seconds", function()
        assert.equals("2m", FormatCooldown(65))
    end)

    it("formats exact minute", function()
        assert.equals("1m", FormatCooldown(60))
    end)

    it("formats integer seconds for >= 10", function()
        assert.equals("30", FormatCooldown(30))
    end)

    it("formats 10 seconds as integer", function()
        assert.equals("10", FormatCooldown(10))
    end)

    it("formats decimal seconds for < 10", function()
        assert.equals("9.5", FormatCooldown(9.5))
    end)

    it("formats sub-second values", function()
        assert.equals("0.3", FormatCooldown(0.3))
    end)
end)

--------------------------------------------------------------------------------
-- GetSpellCooldownInfo (CooldownTracker.lua)
--------------------------------------------------------------------------------

describe("GetSpellCooldownInfo", function()
    local GetSpellCooldownInfo = LunarUI_CD.GetSpellCooldownInfo

    it("returns start and duration from C_Spell", function()
        _G.C_Spell.GetSpellCooldown = function(_spellID)
            return { startTime = 100, duration = 10 }
        end
        local start, duration = GetSpellCooldownInfo(12345)
        assert.equals(100, start)
        assert.equals(10, duration)
    end)

    it("returns 0,0 when pcall fails", function()
        _G.C_Spell.GetSpellCooldown = function()
            error("spell not found")
        end
        local start, duration = GetSpellCooldownInfo(99999)
        assert.equals(0, start)
        assert.equals(0, duration)
    end)

    it("returns 0,0 when spellInfo is nil", function()
        _G.C_Spell.GetSpellCooldown = function()
            return nil
        end
        local start, duration = GetSpellCooldownInfo(99999)
        assert.equals(0, start)
        assert.equals(0, duration)
    end)

    it("handles secret values via tonumber conversion", function()
        _G.C_Spell.GetSpellCooldown = function()
            return { startTime = "500", duration = "15" }
        end
        local start, duration = GetSpellCooldownInfo(12345)
        assert.equals(500, start)
        assert.equals(15, duration)
    end)
end)

--------------------------------------------------------------------------------
-- CDGetSpellTexture (CooldownTracker.lua)
--------------------------------------------------------------------------------

describe("CDGetSpellTexture", function()
    local CDGetSpellTexture = LunarUI_CD.CDGetSpellTexture

    before_each(function()
        LunarUI_CD.ClearSpellTextureCache()
    end)

    it("returns texture for valid spellID", function()
        _G.C_Spell.GetSpellInfo = function()
            return { iconID = 123456 }
        end
        assert.equals(123456, CDGetSpellTexture(100))
    end)

    it("returns nil for invalid spellID (negative cache)", function()
        _G.C_Spell.GetSpellInfo = function()
            return nil
        end
        assert.is_nil(CDGetSpellTexture(99999))
    end)

    it("returns cached value on second call", function()
        local callCount = 0
        _G.C_Spell.GetSpellInfo = function()
            callCount = callCount + 1
            return { iconID = 111 }
        end
        CDGetSpellTexture(100)
        CDGetSpellTexture(100)
        assert.equals(1, callCount)
    end)

    it("returns nil from negative cache on second call", function()
        local callCount = 0
        _G.C_Spell.GetSpellInfo = function()
            callCount = callCount + 1
            return nil
        end
        CDGetSpellTexture(99999)
        local result = CDGetSpellTexture(99999)
        assert.is_nil(result)
        assert.equals(1, callCount)
    end)

    it("returns nil for non-number spellID", function()
        assert.is_nil(CDGetSpellTexture("not a number"))
        assert.is_nil(CDGetSpellTexture(nil))
    end)

    it("clears cache via ClearSpellTextureCache", function()
        _G.C_Spell.GetSpellInfo = function()
            return { iconID = 222 }
        end
        CDGetSpellTexture(100)
        LunarUI_CD.ClearSpellTextureCache()
        local callCount = 0
        _G.C_Spell.GetSpellInfo = function()
            callCount = callCount + 1
            return { iconID = 333 }
        end
        local result = CDGetSpellTexture(100)
        assert.equals(333, result)
        assert.equals(1, callCount)
    end)
end)

--------------------------------------------------------------------------------
-- IsSpellKnownByPlayer (CooldownTracker.lua)
--------------------------------------------------------------------------------

describe("IsSpellKnownByPlayer", function()
    local IsSpellKnownByPlayer = LunarUI_CD.IsSpellKnownByPlayer

    it("returns true when C_Spell.IsSpellUsable returns true", function()
        _G.C_Spell.IsSpellUsable = function()
            return true
        end
        _G._mockIsPlayerSpell = false
        assert.is_true(IsSpellKnownByPlayer(100))
    end)

    it("returns true via IsPlayerSpell fallback", function()
        _G.C_Spell.IsSpellUsable = function()
            return false
        end
        _G._mockIsPlayerSpell = true
        assert.is_true(IsSpellKnownByPlayer(100))
    end)

    it("returns false when both return false", function()
        _G.C_Spell.IsSpellUsable = function()
            return false
        end
        _G._mockIsPlayerSpell = false
        assert.is_false(IsSpellKnownByPlayer(100))
    end)
end)

--------------------------------------------------------------------------------
-- GetTimerBarColor (AuraFrames.lua)
--------------------------------------------------------------------------------

local LunarUI_AF = {}
LunarUI_AF.Colors = { bgSolid = { 0, 0, 0, 0.8 }, border = { 0, 0, 0, 1 } }
LunarUI_AF.DEBUFF_TYPE_COLORS = {}
LunarUI_AF.iconBackdropTemplate = {}
LunarUI_AF.GetHUDSetting = function()
    return true
end
LunarUI_AF.RegisterModule = function() end
LunarUI_AF.CreateEventHandler = function()
    return nil
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

    it("handles nil name without error", function()
        -- pcall protects against nil table index
        local ok, _result = pcall(ShouldShowBuff, nil, 10)
        assert.is_true(ok)
        -- nil key in table lookup via pcall → should not crash
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
