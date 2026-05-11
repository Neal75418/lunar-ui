---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/UnitFrames/Indicators.lua

    Scope rationale: 15 of the 15 exports are factory functions that mostly
    do CreateTexture + SetPoint + SetSize — pure frame creation, NOT testable
    without test theatre (per CHANGELOG: "UI frame-creation 不適合 mock 測試").

    What this spec DOES test (real logic hidden in closures + DB toggles):
    - CreateClassPower: `db.showClassPower == false` short-circuit
    - AlternativePower.PostUpdate: percentage text formatting + 0/nil max
    - ThreatIndicator.PostUpdate: status>0 sets border color, else clears
    - CreateRangeIndicator: returns the documented alpha values

    What this spec deliberately defers:
    - ClassPower.PostUpdate cache-invalidation (#6) — perf optimization,
      mocking maxVisible/powerType transitions across multi-call sequences
      with element index access has high cost; the optimization itself
      doesn't have a correctness regression mode visible to user.
    - All factory-creation-only indicators (Resting / Combat / Classification
      / Leader / Assistant / RaidRole / GroupRole / ReadyCheck / Summon
      / Resurrect / Death) — CreateTexture + position assertions are test
      theatre.
]]

require("spec.wow_mock")
local loader = require("spec.loader")
local mock_frame = require("spec.mock_frame")

--------------------------------------------------------------------------------
-- WoW global stubs Indicators.lua reaches at module load (none needed —
-- all functions are factories invoked from layout code, not at load time)
--------------------------------------------------------------------------------

-- Minimal LunarUI host. Indicators.lua reads:
--   LunarUI.Colors (early bind at load)
--   LunarUI.GetModuleDB (CreateClassPower db toggle)
--   LunarUI.UFGetStatusBarTexture (CreateClassPower / CreateAlternativePower)
--   LunarUI.SetFont (CreateAlternativePower / CreateClassification)
local LunarUI = {
    Colors = {
        bgIcon = { 0.05, 0.05, 0.05, 0.8 },
    },
}
function LunarUI.GetModuleDB(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end
function LunarUI.UFGetStatusBarTexture()
    return "Interface\\Buttons\\WHITE8x8"
end
function LunarUI.SetFont() end

LunarUI.db = {
    profile = {
        unitframes = {
            player = { showClassPower = true },
        },
    },
}

-- Minimal Engine.oUF for ClassPower color lookup (won't be exercised
-- by spec — only the DB-toggle code path is tested for ClassPower).
local oUFStub = {
    colors = {
        power = {
            COMBO_POINTS = { 0.9, 0.1, 0.1 },
        },
    },
}

-- Helper: build a UnitFrame-like mock that satisfies Indicators' field reads
local function makeUnitFrame()
    local frame = setmetatable({}, { __index = mock_frame.MockFrame })

    function frame:GetWidth()
        return 200
    end
    function frame:GetFrameLevel()
        return 1
    end

    -- frame.Health is referenced by many factories (CreateTexture / CreateFontString)
    local health = setmetatable({}, { __index = mock_frame.MockFrame })
    frame.Health = health

    -- frame:Tag is oUF's tag binding; Classification factory calls it
    function frame:Tag(_fs, _tagString) end

    return frame
end

loader.loadAddonFile("LunarUI/UnitFrames/Indicators.lua", LunarUI, { oUF = oUFStub })

--------------------------------------------------------------------------------
-- CreateClassPower — DB toggle
--------------------------------------------------------------------------------

describe("UFCreateClassPower", function()
    it("returns nil and does not attach element when showClassPower == false", function()
        LunarUI.db.profile.unitframes.player.showClassPower = false
        local frame = makeUnitFrame()
        local result = LunarUI.UFCreateClassPower(frame)
        assert.is_nil(result)
        assert.is_nil(frame.ClassPower)
    end)

    it("creates element when showClassPower flag is true", function()
        LunarUI.db.profile.unitframes.player.showClassPower = true
        local frame = makeUnitFrame()
        local result = LunarUI.UFCreateClassPower(frame)
        assert.is_not_nil(result)
        assert.equals(result, frame.ClassPower)
    end)

    it("creates element when showClassPower flag is absent (default-allow)", function()
        LunarUI.db.profile.unitframes.player.showClassPower = nil
        local frame = makeUnitFrame()
        local result = LunarUI.UFCreateClassPower(frame)
        assert.is_not_nil(result)
    end)
end)

--------------------------------------------------------------------------------
-- AlternativePower.PostUpdate — percentage text formatting
--------------------------------------------------------------------------------

describe("UFCreateAlternativePower PostUpdate text format", function()
    local frame, altPower, capturedTexts

    before_each(function()
        frame = makeUnitFrame()
        altPower = LunarUI.UFCreateAlternativePower(frame)
        -- altPower.text inherits MockFrame's no-op SetText; override to capture
        capturedTexts = {}
        altPower.text.SetText = function(_self, t)
            capturedTexts[#capturedTexts + 1] = t
        end
    end)

    it("formats cur/max as a rounded percentage", function()
        altPower.PostUpdate(altPower, "boss1", 50, 0, 100)
        assert.equals("50%", capturedTexts[#capturedTexts])
    end)

    it("rounds to nearest integer (mathFloor(x + 0.5))", function()
        -- 33/100 * 100 + 0.5 = 33.5 → floor = 33
        altPower.PostUpdate(altPower, "boss1", 33, 0, 100)
        assert.equals("33%", capturedTexts[#capturedTexts])
        -- 67/100 * 100 + 0.5 = 67.5 → floor = 67
        altPower.PostUpdate(altPower, "boss1", 67, 0, 100)
        assert.equals("67%", capturedTexts[#capturedTexts])
        -- 749/1000 * 100 + 0.5 = 75.4 → floor = 75
        altPower.PostUpdate(altPower, "boss1", 749, 0, 1000)
        assert.equals("75%", capturedTexts[#capturedTexts])
    end)

    it("shows 100% at full", function()
        altPower.PostUpdate(altPower, "boss1", 100, 0, 100)
        assert.equals("100%", capturedTexts[#capturedTexts])
    end)

    it("renders empty string when max is 0 (divide-by-zero guard)", function()
        altPower.PostUpdate(altPower, "boss1", 0, 0, 0)
        assert.equals("", capturedTexts[#capturedTexts])
    end)

    it("renders empty string when max is nil", function()
        altPower.PostUpdate(altPower, "boss1", 10, 0, nil)
        assert.equals("", capturedTexts[#capturedTexts])
    end)
end)

--------------------------------------------------------------------------------
-- ThreatIndicator.PostUpdate — border color toggle
--------------------------------------------------------------------------------

describe("UFCreateThreatIndicator PostUpdate", function()
    local frame, threat, lastColor

    before_each(function()
        frame = makeUnitFrame()
        threat = LunarUI.UFCreateThreatIndicator(frame)
        lastColor = nil
        threat.SetBackdropBorderColor = function(_self, r, g, b, a)
            lastColor = { r, g, b, a }
        end
    end)

    it("sets visible border color with 0.8 alpha when status > 0", function()
        threat.PostUpdate(threat, "target", 3, 1.0, 0.2, 0.0)
        assert.same({ 1.0, 0.2, 0.0, 0.8 }, lastColor)
    end)

    it("clears border (alpha 0) when status is 0", function()
        threat.PostUpdate(threat, "target", 0, 1.0, 0.5, 0.5)
        assert.same({ 0, 0, 0, 0 }, lastColor)
    end)

    it("clears border (alpha 0) when status is nil", function()
        threat.PostUpdate(threat, "target", nil, 1.0, 0.5, 0.5)
        assert.same({ 0, 0, 0, 0 }, lastColor)
    end)

    it("uses caller-supplied RGB when status > 0 (passes through, no overrides)", function()
        threat.PostUpdate(threat, "target", 1, 0.5, 0.5, 0.5)
        assert.same({ 0.5, 0.5, 0.5, 0.8 }, lastColor)
    end)
end)

--------------------------------------------------------------------------------
-- CreateRangeIndicator — config value sanity
--------------------------------------------------------------------------------

describe("UFCreateRangeIndicator", function()
    it("attaches a Range table with the documented alpha values", function()
        local frame = makeUnitFrame()
        local range = LunarUI.UFCreateRangeIndicator(frame)
        assert.same({ insideAlpha = 1, outsideAlpha = 0.4 }, range)
        assert.equals(range, frame.Range)
    end)
end)
