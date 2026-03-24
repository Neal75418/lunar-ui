---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Modules/Loot.lua
    Tests initialization, cleanup, event handling, and module registration
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.InCombatLockdown = function()
    return false
end
_G.hooksecurefunc = function() end
_G.GetCursorPosition = function()
    return 500, 400
end
_G.CloseLoot = function() end
_G.LootSlot = function() end
_G.GetNumLootItems = function()
    return 0
end
_G.GetLootSlotInfo = function()
    return nil
end
_G.GameTooltip = {
    SetOwner = function() end,
    SetLootItem = function() end,
    Show = function() end,
    Hide = function() end,
}

-- Mock CreateFrame with event tracking.
-- NOTE: This mock is installed BEFORE loadAddonFile runs (below), so the module
-- creates its loot frame via this mock. RegisterEvent writes to the spec-local
-- `registeredEvents` table, which the tests then assert on.  This is intentional:
-- the tests exercise the module's event registration through the mock, not by
-- inspecting module-internal state directly.
local mock_frame = require("spec.mock_frame")
local registeredEvents = {}
local LootMock = setmetatable({}, { __index = mock_frame.MockFrame })
LootMock.__index = LootMock
function LootMock:RegisterEvent(event)
    registeredEvents[event] = true
end
function LootMock:UnregisterAllEvents()
    wipe(registeredEvents)
end
_G.CreateFrame = function()
    return setmetatable({}, { __index = LootMock })
end
_G.UIParent = setmetatable({}, { __index = LootMock })
_G.LootFrame = setmetatable({ Show = function() end }, { __index = LootMock })

-- Track module registration
local registeredModules = {}

local LunarUI = {
    Colors = {
        bg = { 0.05, 0.05, 0.05, 0.8 },
        border = { 0.3, 0.3, 0.4, 1 },
        inkDark = { 0.1, 0.1, 0.1 },
        borderWarm = { 0.5, 0.4, 0.3, 1 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    QUALITY_COLORS = {
        [0] = { 0.62, 0.62, 0.62 },
        [1] = { 1, 1, 1 },
        [2] = { 0.12, 1, 0 },
        [3] = { 0, 0.44, 0.87 },
        [4] = { 0.64, 0.21, 0.93 },
    },
    backdropTemplate = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    },
    SetFont = function() end,
    ApplyBackdrop = function() end,
    db = {
        profile = {
            loot = { enabled = true },
        },
    },
    RegisterModule = function(_self, name, config)
        registeredModules[name] = config
    end,
}
LunarUI.GetModuleDB = function(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

loader.loadAddonFile("LunarUI/Modules/Loot.lua", LunarUI)

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

describe("Loot module registration", function()
    it("registers Loot module", function()
        assert.truthy(registeredModules["Loot"])
        assert.is_function(registeredModules["Loot"].onEnable)
        assert.is_function(registeredModules["Loot"].onDisable)
    end)
end)

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

describe("Loot initialization", function()
    before_each(function()
        wipe(registeredEvents)
    end)

    it("registers loot events when enabled", function()
        LunarUI.db.profile.loot.enabled = true
        LunarUI.InitializeLoot()
        assert.is_true(registeredEvents["LOOT_OPENED"] or false)
        assert.is_true(registeredEvents["LOOT_SLOT_CLEARED"] or false)
        assert.is_true(registeredEvents["LOOT_CLOSED"] or false)
    end)

    it("does not register events when disabled", function()
        LunarUI.db.profile.loot.enabled = false
        wipe(registeredEvents)
        LunarUI.InitializeLoot()
        assert.is_nil(registeredEvents["LOOT_OPENED"])
        LunarUI.db.profile.loot.enabled = true
    end)
end)

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

describe("Loot cleanup", function()
    it("unregisters all events", function()
        LunarUI.db.profile.loot.enabled = true
        LunarUI.InitializeLoot()
        assert.is_true(registeredEvents["LOOT_OPENED"] or false)
        LunarUI.CleanupLoot()
        assert.is_nil(registeredEvents["LOOT_OPENED"])
    end)
end)
