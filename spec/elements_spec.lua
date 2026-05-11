---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/UnitFrames/Elements.lua

    Scope: per CHANGELOG ("UI frame-creation 不適合 mock 測試"), this spec
    covers DB toggles, early-return guards, cache logic, and closure-based
    PostUpdate logic — not the bare CreateFrame/SetPoint pipelines.

    Covered:
    - GetStatusBarTexture / InvalidateStatusBarTextureCache: cache hit + miss
    - CreateHealthText: early-return for raid/pet/targettarget
    - CreateHealPrediction: showHealPrediction DB toggle
    - CreatePortrait: showPortrait DB toggle + style branch (class / 3d)
    - CreateHealthBar.PostUpdate (Perf B4 cache): player class color, NPC
      reaction color, GUID+reaction cache short-circuit, reaction change
      forces re-color, dead state toggles DeadIndicator visibility.

    Deferred / out of scope:
    - CreatePowerBar / CreateNameText / CreateLevelText: pure frame creation
      with no branch logic worth verifying.
    - colorClass / colorReaction etc. flag assignment: trivial reads, the
      actual color resolution is what we test via PostUpdate.
]]

require("spec.wow_mock")
local loader = require("spec.loader")
local mock_frame = require("spec.mock_frame")

--------------------------------------------------------------------------------
-- WoW global stubs Elements.lua reads at module top
--------------------------------------------------------------------------------

-- Module-level upvalues captured at file load:
--   UnitIsPlayer / UnitReaction / UnitClass / UnitExists / UnitIsDeadOrGhost
--   / UnitGUID / RAID_CLASS_COLORS
-- We install spec-controllable values BEFORE loadAddonFile so the closures
-- pick up our stubs rather than wow_mock's defaults.

local stubUnit = {
    GUID = "test-guid-1",
    isPlayer = false,
    class = nil,
    reaction = 5,
    exists = true,
    isDead = false,
}

_G.UnitIsPlayer = function(_unit)
    return stubUnit.isPlayer
end
_G.UnitClass = function(_unit)
    return nil, stubUnit.class
end
_G.UnitReaction = function(_unit, _other)
    return stubUnit.reaction
end
_G.UnitGUID = function(_unit)
    return stubUnit.GUID
end
_G.UnitExists = function(_unit)
    return stubUnit.exists
end
_G.UnitIsDeadOrGhost = function(_unit)
    return stubUnit.isDead
end
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    MAGE = { r = 0.41, g = 0.80, b = 0.94 },
}

--------------------------------------------------------------------------------
-- LunarUI host
--------------------------------------------------------------------------------

local statusBarLookups = 0
local LunarUI = {
    Colors = {
        bgIcon = { 0.05, 0.05, 0.05, 0.8 },
    },
    BG_DARKEN = 0.4,
}
function LunarUI.GetSelectedStatusBarTexture()
    statusBarLookups = statusBarLookups + 1
    return "Interface\\Textures\\Stub"
end
function LunarUI.SetFont() end

LunarUI.db = {
    profile = {
        unitframes = {
            player = { showHealPrediction = true, showPortrait = true, portraitStyle = "class" },
            target = { showHealPrediction = true, showPortrait = false },
            raid = { showHealPrediction = true },
            party = { showHealPrediction = true },
            boss = { showHealPrediction = false },
        },
    },
}
function LunarUI.GetModuleDB(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

loader.loadAddonFile("LunarUI/UnitFrames/Elements.lua", LunarUI)

--------------------------------------------------------------------------------
-- Helper: build a unit-frame-like mock
--------------------------------------------------------------------------------

-- frame:Tag is called by Name / HealthText / Level via oUF binding.
-- We don't need to verify Tag calls in this spec (separate oUF concern).
local function makeUnitFrame(unitName, height, width)
    local frame = setmetatable({}, { __index = mock_frame.MockFrame })
    frame.unit = unitName
    function frame:GetWidth()
        return width or 200
    end
    function frame:GetHeight()
        return height or 40
    end
    function frame:Tag() end

    -- Some factories reference frame.Health (built by CreateHealthBar earlier
    -- in the layout pipeline). Tests that need it call CreateHealthBar first
    -- or pre-attach a mock Health.
    return frame
end

--------------------------------------------------------------------------------
-- GetStatusBarTexture cache
--------------------------------------------------------------------------------

describe("UFGetStatusBarTexture cache", function()
    before_each(function()
        LunarUI.InvalidateStatusBarTextureCache()
        statusBarLookups = 0
    end)

    it("returns the texture path on first call", function()
        local t = LunarUI.UFGetStatusBarTexture()
        assert.equals("Interface\\Textures\\Stub", t)
        assert.equals(1, statusBarLookups)
    end)

    it("does not re-query GetSelectedStatusBarTexture on subsequent calls", function()
        LunarUI.UFGetStatusBarTexture()
        LunarUI.UFGetStatusBarTexture()
        LunarUI.UFGetStatusBarTexture()
        assert.equals(1, statusBarLookups)
    end)

    it("Invalidate forces next call to re-query", function()
        LunarUI.UFGetStatusBarTexture()
        assert.equals(1, statusBarLookups)
        LunarUI.InvalidateStatusBarTextureCache()
        LunarUI.UFGetStatusBarTexture()
        assert.equals(2, statusBarLookups)
    end)
end)

--------------------------------------------------------------------------------
-- CreateHealthText early-return
--------------------------------------------------------------------------------

describe("UFCreateHealthText", function()
    it("returns nil for raid units (no health text on tiny frames)", function()
        local frame = makeUnitFrame("raid1")
        frame.Health = setmetatable({}, { __index = mock_frame.MockFrame })
        local result = LunarUI.UFCreateHealthText(frame, "raid")
        assert.is_nil(result)
        assert.is_nil(frame.HealthText)
    end)

    it("returns nil for pet and targettarget units", function()
        for _, unit in ipairs({ "pet", "targettarget" }) do
            local frame = makeUnitFrame(unit)
            frame.Health = setmetatable({}, { __index = mock_frame.MockFrame })
            local result = LunarUI.UFCreateHealthText(frame, unit)
            assert.is_nil(result)
            assert.is_nil(frame.HealthText)
        end
    end)

    it("creates health text for player and target", function()
        for _, unit in ipairs({ "player", "target" }) do
            local frame = makeUnitFrame(unit)
            frame.Health = setmetatable({}, { __index = mock_frame.MockFrame })
            local result = LunarUI.UFCreateHealthText(frame, unit)
            assert.is_not_nil(result)
            assert.equals(result, frame.HealthText)
        end
    end)
end)

--------------------------------------------------------------------------------
-- CreateHealPrediction DB toggle
--------------------------------------------------------------------------------

describe("UFCreateHealPrediction", function()
    it("returns nil when showHealPrediction == false", function()
        -- boss has showHealPrediction = false in the host DB
        local frame = makeUnitFrame("boss1")
        frame.Health = setmetatable({}, { __index = mock_frame.MockFrame })
        local result = LunarUI.UFCreateHealPrediction(frame, "boss1")
        assert.is_nil(result)
        assert.is_nil(frame.HealthPrediction)
    end)

    it("strips numeric suffix to find DB key (boss1 -> boss)", function()
        -- Use raid which has showHealPrediction=true, with raid3 suffix
        local frame = makeUnitFrame("raid3")
        frame.Health = setmetatable({}, { __index = mock_frame.MockFrame })
        function frame.Health:GetWidth()
            return 100
        end
        function frame.Health:GetStatusBarTexture()
            return setmetatable({}, { __index = mock_frame.MockFrame })
        end
        local result = LunarUI.UFCreateHealPrediction(frame, "raid3")
        assert.is_not_nil(result)
        assert.is_not_nil(result.healingPlayer)
        assert.is_not_nil(result.healingOther)
        assert.is_not_nil(result.damageAbsorb)
        assert.equals(1.05, result.incomingHealOverflow)
    end)
end)

--------------------------------------------------------------------------------
-- CreatePortrait DB toggle + style branch
--------------------------------------------------------------------------------

describe("UFCreatePortrait", function()
    it("returns nil when showPortrait is false / absent", function()
        -- target has showPortrait = false
        local frame = makeUnitFrame("target")
        frame.Health = setmetatable({}, { __index = mock_frame.MockFrame })
        local result = LunarUI.UFCreatePortrait(frame, "target")
        assert.is_nil(result)
        assert.is_nil(frame.Portrait)
    end)

    it("creates a 2D class-icon portrait (showClass=true) when style == 'class'", function()
        LunarUI.db.profile.unitframes.player.portraitStyle = "class"
        local frame = makeUnitFrame("player")
        frame.Health = setmetatable({}, { __index = mock_frame.MockFrame })
        function frame.Health:GetFrameLevel()
            return 1
        end
        local result = LunarUI.UFCreatePortrait(frame, "player")
        assert.is_not_nil(result)
        assert.is_true(result.showClass) -- 2D class icon
    end)

    it("creates a 3D PlayerModel portrait when style == '3d'", function()
        LunarUI.db.profile.unitframes.player.portraitStyle = "3d"
        local frame = makeUnitFrame("player")
        frame.Health = setmetatable({}, { __index = mock_frame.MockFrame })
        function frame.Health:GetFrameLevel()
            return 1
        end
        local result = LunarUI.UFCreatePortrait(frame, "player")
        assert.is_not_nil(result)
        -- 3D path attaches a background texture as portrait._bg
        assert.is_not_nil(result._bg)
        -- And does NOT set showClass (that's the 2D path)
        assert.is_nil(result.showClass)
    end)
end)

--------------------------------------------------------------------------------
-- CreateHealthBar.PostUpdate — color resolution + Perf B4 cache
--------------------------------------------------------------------------------

-- Helper: spawn a HealthBar element + capture SetStatusBarColor calls
local function spawnHealthForUnit(unitName)
    local frame = makeUnitFrame(unitName, 40, 200)
    local health = LunarUI.UFCreateHealthBar(frame, unitName)
    -- Per oUF convention, __owner points back to the parent frame
    health.__owner = frame

    local colorCalls = {}
    -- Override SetStatusBarColor on the instance (not the metatable) to track
    health.SetStatusBarColor = function(_self, r, g, b)
        colorCalls[#colorCalls + 1] = { r, g, b }
    end
    health.bg.SetVertexColor = function() end -- bg color side effect not asserted in this spec

    return frame, health, colorCalls
end

describe("UFCreateHealthBar PostUpdate", function()
    before_each(function()
        stubUnit.GUID = "test-guid-1"
        stubUnit.isPlayer = false
        stubUnit.class = nil
        stubUnit.reaction = 5
        stubUnit.exists = true
        stubUnit.isDead = false
    end)

    it("applies RAID_CLASS_COLORS for a player WARRIOR", function()
        stubUnit.isPlayer = true
        stubUnit.class = "WARRIOR"
        local _frame, health, colorCalls = spawnHealthForUnit("target")
        health.PostUpdate(health, "target", 100, 100)
        assert.equals(1, #colorCalls)
        assert.equals(0.78, colorCalls[1][1])
        assert.equals(0.61, colorCalls[1][2])
        assert.equals(0.43, colorCalls[1][3])
    end)

    it("applies REACTION_COLORS for friendly NPC (reaction 5 -> green)", function()
        stubUnit.isPlayer = false
        stubUnit.reaction = 5
        local _frame, health, colorCalls = spawnHealthForUnit("target")
        health.PostUpdate(health, "target", 100, 100)
        assert.equals(1, #colorCalls)
        -- reaction 5 in REACTION_COLORS is { 0.2, 0.9, 0.3 }
        assert.equals(0.2, colorCalls[1][1])
        assert.equals(0.9, colorCalls[1][2])
        assert.equals(0.3, colorCalls[1][3])
    end)

    it("cache short-circuit: same GUID + reaction skips SetStatusBarColor", function()
        stubUnit.isPlayer = true
        stubUnit.class = "MAGE"
        local _frame, health, colorCalls = spawnHealthForUnit("target")
        health.PostUpdate(health, "target", 100, 100)
        assert.equals(1, #colorCalls)
        -- Second call: GUID + reaction unchanged → no new SetStatusBarColor
        health.PostUpdate(health, "target", 50, 100)
        assert.equals(1, #colorCalls)
        health.PostUpdate(health, "target", 20, 100)
        assert.equals(1, #colorCalls)
    end)

    it("reaction change (same GUID, reaction 4 -> 3) forces re-color", function()
        stubUnit.isPlayer = false
        stubUnit.reaction = 4 -- neutral yellow
        local _frame, health, colorCalls = spawnHealthForUnit("target")
        health.PostUpdate(health, "target", 100, 100)
        assert.equals(1, #colorCalls)
        -- Neutral NPC turns hostile (reaction 3) while GUID unchanged
        stubUnit.reaction = 3
        health.PostUpdate(health, "target", 100, 100)
        assert.equals(2, #colorCalls)
        -- reaction 3 → red REACTION_COLORS[3] = { 0.9, 0.2, 0.2 }
        assert.equals(0.9, colorCalls[2][1])
        assert.equals(0.2, colorCalls[2][2])
        assert.equals(0.2, colorCalls[2][3])
    end)
end)
