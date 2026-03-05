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

-- MockFrame
local MockFrame = {}
MockFrame.__index = MockFrame

local registeredEvents = {}

function MockFrame:SetSize() end
function MockFrame:SetPoint() end
function MockFrame:SetFrameStrata() end
function MockFrame:SetFrameLevel() end
function MockFrame:SetClampedToScreen() end
function MockFrame:SetMovable() end
function MockFrame:EnableMouse() end
function MockFrame:RegisterForDrag() end
function MockFrame:RegisterForClicks() end
function MockFrame:SetScript() end
function MockFrame:HookScript() end
function MockFrame:SetBackdrop() end
function MockFrame:SetBackdropColor() end
function MockFrame:SetBackdropBorderColor() end
function MockFrame:SetAllPoints() end
function MockFrame:Hide() end
function MockFrame:Show() end
function MockFrame:IsShown()
    return true
end
function MockFrame:GetFrameLevel()
    return 1
end
function MockFrame:GetWidth()
    return 200
end
function MockFrame:GetHeight()
    return 100
end
function MockFrame:GetEffectiveScale()
    return 1
end
function MockFrame:ClearAllPoints() end
function MockFrame:SetHeight() end
function MockFrame:SetWidth() end
function MockFrame:SetTexture() end
function MockFrame:SetVertexColor() end
function MockFrame:SetTexCoord() end
function MockFrame:SetText() end
function MockFrame:SetTextColor() end
function MockFrame:SetFont() end
function MockFrame:SetJustifyH() end
function MockFrame:SetWordWrap() end
function MockFrame:SetNormalTexture() end
function MockFrame:SetPushedTexture() end
function MockFrame:SetHighlightTexture() end
function MockFrame:CreateTexture()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:CreateFontString()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:RegisterEvent(event)
    registeredEvents[event] = true
end
function MockFrame:UnregisterAllEvents()
    wipe(registeredEvents)
end

_G.CreateFrame = function()
    return setmetatable({}, { __index = MockFrame })
end
_G.UIParent = setmetatable({}, { __index = MockFrame })
_G.LootFrame = setmetatable({ Show = function() end }, { __index = MockFrame })

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

loader.loadAddonFile("LunarUI/Modules/Loot.lua", LunarUI)

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

describe("Loot exports", function()
    it("exports InitializeLoot", function()
        assert.is_function(LunarUI.InitializeLoot)
    end)

    it("exports CleanupLoot", function()
        assert.is_function(LunarUI.CleanupLoot)
    end)

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
