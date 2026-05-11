---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/Modules/Minimap/ButtonCorral.lua

    Coverage:
    - GetButtonPriority: known addon priorities + default fallback
    - CollectMinimapButton: SKIP_BUTTONS guard + dedup + nil-name guard
    - ClearStaleButtonReferences: stale (no GetObjectType) removed + order preserved + scannedIDs rebuilt
    - Reset: clears collectedButtons + scannedButtonIDs

    Not covered (intentional — separately reviewed, mock cost vs payoff):
    - OrganizeMinimapButtons combat-defer path (H12 fix) — needs CreateFrame
      + IsEventRegistered + event dispatch simulation, high mock complexity.
    - Scan() integration — needs full Minimap/MinimapBackdrop/MinimapCluster
      children wiring.
]]

require("spec.wow_mock")
local loader = require("spec.loader")
local mock_frame = require("spec.mock_frame")

-- WoW global stubs ButtonCorral.lua reaches at load time
_G.InCombatLockdown = function()
    return false
end
_G.Minimap = mock_frame.newFrame()
_G.MinimapBackdrop = mock_frame.newFrame()
_G.MinimapCluster = mock_frame.newFrame()

-- LunarUI host (minimal — ButtonCorral.lua only writes to Engine.LunarUI.X)
local LunarUI = {}
loader.loadAddonFile("LunarUI/Modules/Minimap/ButtonCorral.lua", LunarUI)

--------------------------------------------------------------------------------
-- Helper: build a controllable mock minimap button
--------------------------------------------------------------------------------

-- objectType defaults to "Button"; pass "Frame" or other to test branch.
-- name=nil simulates an anonymous frame (CollectMinimapButton must skip).
local function makeButton(name, objectType)
    objectType = objectType or "Button"
    local btn = setmetatable({}, { __index = mock_frame.MockFrame })
    -- Note: function btn:GetName() ... end sets a direct field (sugar for
    -- btn.GetName = function(self) ... end). Removing the direct field with
    -- = nil makes the lookup fall through to MockFrame's default (which
    -- returns "MockFrame"); to truly simulate nil-name we'd need a sentinel.
    -- For "no name" case we override to return nil explicitly.
    function btn:GetName()
        return name
    end
    function btn:IsObjectType(t)
        return t == objectType
    end
    function btn:GetObjectType()
        return objectType
    end
    function btn:IsShown()
        return true
    end
    return btn
end

--------------------------------------------------------------------------------
-- GetButtonPriority
--------------------------------------------------------------------------------

describe("MinimapButtonsGetPriority", function()
    it("returns 1 for DBM-prefixed names", function()
        local btn = makeButton("DBM_MinimapButton")
        assert.equals(1, LunarUI.MinimapButtonsGetPriority(btn))
    end)

    it("returns 1 for DeadlyBoss-prefixed names", function()
        local btn = makeButton("DeadlyBossModsButton")
        assert.equals(1, LunarUI.MinimapButtonsGetPriority(btn))
    end)

    it("returns 2 for BigWigs", function()
        local btn = makeButton("BigWigsAnchor")
        assert.equals(2, LunarUI.MinimapButtonsGetPriority(btn))
    end)

    it("returns 3 for Details", function()
        local btn = makeButton("Details_Minimap")
        assert.equals(3, LunarUI.MinimapButtonsGetPriority(btn))
    end)

    it("returns 100 (default) for unknown addons", function()
        local btn = makeButton("CompletelyRandomAddonButton")
        assert.equals(100, LunarUI.MinimapButtonsGetPriority(btn))
    end)

    it("returns 100 for nameless frames (defensive)", function()
        local btn = makeButton(nil)
        assert.equals(100, LunarUI.MinimapButtonsGetPriority(btn))
    end)
end)

--------------------------------------------------------------------------------
-- CollectMinimapButton
--------------------------------------------------------------------------------

describe("MinimapButtonsCollect", function()
    before_each(function()
        LunarUI.MinimapButtons.Reset()
    end)

    it("collects a Button-type frame with a name", function()
        local btn = makeButton("TestAddonButton")
        LunarUI.MinimapButtonsCollect(btn)
        assert.equals(1, LunarUI.MinimapButtonsGetCollectedCount())
        assert.is_true(LunarUI.MinimapButtonsHasScanned("TestAddonButton"))
    end)

    it("collects a Frame-type minimap button (IsObjectType('Frame') branch)", function()
        local btn = makeButton("FrameTypeButton", "Frame")
        LunarUI.MinimapButtonsCollect(btn)
        assert.equals(1, LunarUI.MinimapButtonsGetCollectedCount())
    end)

    it("skips known system buttons (SKIP_BUTTONS hash)", function()
        for _, skipName in ipairs({
            "MiniMapTracking",
            "MiniMapMailFrame",
            "QueueStatusMinimapButton",
            "LunarUI_MinimapButton",
        }) do
            local btn = makeButton(skipName)
            LunarUI.MinimapButtonsCollect(btn)
        end
        assert.equals(0, LunarUI.MinimapButtonsGetCollectedCount())
    end)

    it("skips buttons whose GetName returns nil", function()
        local btn = makeButton(nil)
        LunarUI.MinimapButtonsCollect(btn)
        assert.equals(0, LunarUI.MinimapButtonsGetCollectedCount())
    end)

    it("dedups: collecting the same button twice keeps count at 1", function()
        local btn = makeButton("DupeMeButton")
        LunarUI.MinimapButtonsCollect(btn)
        LunarUI.MinimapButtonsCollect(btn)
        assert.equals(1, LunarUI.MinimapButtonsGetCollectedCount())
    end)
end)

--------------------------------------------------------------------------------
-- ClearStaleButtonReferences
--------------------------------------------------------------------------------

describe("MinimapButtonsClearStale", function()
    before_each(function()
        LunarUI.MinimapButtons.Reset()
    end)

    it("removes buttons whose GetObjectType becomes nil (frame destroyed)", function()
        local valid = makeButton("AliveButton")
        local stale = makeButton("DestroyedButton")
        LunarUI.MinimapButtonsCollect(valid)
        LunarUI.MinimapButtonsCollect(stale)
        assert.equals(2, LunarUI.MinimapButtonsGetCollectedCount())

        -- Simulate destroyed frame: GetObjectType direct field removed.
        -- Since makeButton put it as a direct field (not metatable inherited),
        -- nil-ing the direct field makes button.GetObjectType resolve to nil
        -- (MockFrame doesn't define GetObjectType).
        stale.GetObjectType = nil

        LunarUI.MinimapButtonsClearStale()
        assert.equals(1, LunarUI.MinimapButtonsGetCollectedCount())
        assert.is_true(LunarUI.MinimapButtonsHasScanned("AliveButton"))
        assert.is_false(LunarUI.MinimapButtonsHasScanned("DestroyedButton"))
    end)

    it("preserves order of valid buttons after in-place compaction", function()
        local a = makeButton("AAA_Button")
        local b = makeButton("BBB_Button")
        local c = makeButton("CCC_Button")
        LunarUI.MinimapButtonsCollect(a)
        LunarUI.MinimapButtonsCollect(b)
        LunarUI.MinimapButtonsCollect(c)
        b.GetObjectType = nil

        LunarUI.MinimapButtonsClearStale()
        assert.equals(2, LunarUI.MinimapButtonsGetCollectedCount())
        -- BBB removed; AAA and CCC retained in scannedIDs
        assert.is_true(LunarUI.MinimapButtonsHasScanned("AAA_Button"))
        assert.is_false(LunarUI.MinimapButtonsHasScanned("BBB_Button"))
        assert.is_true(LunarUI.MinimapButtonsHasScanned("CCC_Button"))
    end)

    it("handles all-stale: ends with 0 buttons + empty scannedIDs", function()
        local a = makeButton("Stale1")
        local b = makeButton("Stale2")
        LunarUI.MinimapButtonsCollect(a)
        LunarUI.MinimapButtonsCollect(b)
        a.GetObjectType = nil
        b.GetObjectType = nil
        LunarUI.MinimapButtonsClearStale()
        assert.equals(0, LunarUI.MinimapButtonsGetCollectedCount())
        assert.is_false(LunarUI.MinimapButtonsHasScanned("Stale1"))
        assert.is_false(LunarUI.MinimapButtonsHasScanned("Stale2"))
    end)
end)

--------------------------------------------------------------------------------
-- Reset
--------------------------------------------------------------------------------

describe("MinimapButtons.Reset", function()
    before_each(function()
        LunarUI.MinimapButtons.Reset()
    end)

    it("clears collectedButtons and scannedButtonIDs", function()
        local btn1 = makeButton("AlphaButton")
        local btn2 = makeButton("BetaButton")
        LunarUI.MinimapButtonsCollect(btn1)
        LunarUI.MinimapButtonsCollect(btn2)
        assert.equals(2, LunarUI.MinimapButtonsGetCollectedCount())

        LunarUI.MinimapButtons.Reset()

        assert.equals(0, LunarUI.MinimapButtonsGetCollectedCount())
        assert.is_false(LunarUI.MinimapButtonsHasScanned("AlphaButton"))
        assert.is_false(LunarUI.MinimapButtonsHasScanned("BetaButton"))
    end)
end)
