---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Nameplates/Nameplates.lua
    Tests: exports, CLASSIFICATION_COLORS, NPC_ROLE_COLORS, GetNPCRoleColor, lifecycle
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
local mockIsPlayer = false
local mockClassification = "normal"
local mockPowerType = 1

_G.UnitIsPlayer = function()
    return mockIsPlayer
end
_G.UnitReaction = function()
    return 4
end
_G.UnitClassification = function()
    return mockClassification
end
_G.UnitPowerType = function()
    return mockPowerType
end
-- wow_mock.lua 已提供 UnitClass/UnitIsEnemy/InCombatLockdown/IsShiftKeyDown/GetTime 預設值
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}
_G.C_Timer = {
    After = function() end,
    NewTimer = function()
        return { Cancel = function() end }
    end,
    NewTicker = function()
        return { Cancel = function() end }
    end,
}
_G.C_NamePlate = {
    GetNamePlates = function()
        return {}
    end,
}
_G.hooksecurefunc = function() end

require("spec.mock_frame")

local LunarUI = {
    Colors = {
        bgIcon = { 0, 0, 0, 0.8 },
        border = { 0.3, 0.3, 0.4, 1 },
        borderSubtle = { 0.2, 0.2, 0.3, 1 },
        bgOverlay = { 0, 0, 0, 0.6 },
    },
    DEBUFF_TYPE_COLORS = {
        none = { r = 0.8, g = 0, b = 0 },
        Magic = { r = 0.2, g = 0.6, b = 1 },
    },
    CreateBackdrop = function()
        return CreateFrame("Frame")
    end,
    StyleAuraButton = function() end,
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetSelectedFont = function()
        return "Fonts\\FRIZQT__.TTF"
    end,
    GetSelectedStatusBarTexture = function()
        return "Interface\\StatusBar"
    end,
    RegisterModule = function() end,
    CreateEventHandler = function()
        return setmetatable({
            _events = {},
            RegisterEvent = function(self, e)
                self._events[e] = true
            end,
            SetScript = function() end,
            UnregisterAllEvents = function() end,
        }, {})
    end,
    db = {
        profile = {
            nameplates = {
                enabled = true,
                width = 120,
                height = 8,
                showCastbar = true,
                showDebuffs = true,
                classColor = true,
                npcColors = {
                    enabled = true,
                    caster = { r = 0.55, g = 0.35, b = 0.85 },
                    miniboss = { r = 0.8, g = 0.6, b = 0.2 },
                },
            },
        },
    },
}

LunarUI.GetModuleDB = function(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

-- oUF mock
local oUFMock = {
    colors = { power = {} },
    RegisterStyle = function() end,
    SetActiveStyle = function() end,
    Spawn = function()
        return CreateFrame("Frame")
    end,
    SpawnHeader = function()
        return CreateFrame("Frame")
    end,
    SpawnNamePlates = function()
        return {
            SetAddedCallback = function() end,
            SetRemovedCallback = function() end,
        }
    end,
}

loader.loadAddonFile("LunarUI/Nameplates/Nameplates.lua", LunarUI, { oUF = oUFMock })

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

describe("Nameplates exports", function()
    it("exports SpawnNameplates as function", function()
        assert.is_function(LunarUI.SpawnNameplates)
    end)

    it("exports CleanupNameplates as function", function()
        assert.is_function(LunarUI.CleanupNameplates)
    end)

    it("exports CLASSIFICATION_COLORS as table", function()
        assert.is_table(LunarUI.CLASSIFICATION_COLORS)
    end)

    it("exports NPC_ROLE_COLORS as table", function()
        assert.is_table(LunarUI.NPC_ROLE_COLORS)
    end)

    it("exports GetNPCRoleColor as function", function()
        assert.is_function(LunarUI.GetNPCRoleColor)
    end)
end)

--------------------------------------------------------------------------------
-- CLASSIFICATION_COLORS
--------------------------------------------------------------------------------

describe("CLASSIFICATION_COLORS", function()
    local colors = LunarUI.CLASSIFICATION_COLORS

    it("has all 6 classification entries", function()
        local expected = { "worldboss", "rareelite", "elite", "rare", "normal", "trivial" }
        for _, key in ipairs(expected) do
            assert.is_not_nil(colors[key], "Missing classification: " .. key)
        end
    end)

    it("each entry has r/g/b values", function()
        for key, color in pairs(colors) do
            assert.is_number(color.r, key .. ".r should be number")
            assert.is_number(color.g, key .. ".g should be number")
            assert.is_number(color.b, key .. ".b should be number")
        end
    end)

    it("all color values are in 0-1 range", function()
        for key, color in pairs(colors) do
            assert.is_true(color.r >= 0 and color.r <= 1, key .. ".r out of range")
            assert.is_true(color.g >= 0 and color.g <= 1, key .. ".g out of range")
            assert.is_true(color.b >= 0 and color.b <= 1, key .. ".b out of range")
        end
    end)
end)

--------------------------------------------------------------------------------
-- NPC_ROLE_COLORS
--------------------------------------------------------------------------------

describe("NPC_ROLE_COLORS", function()
    local colors = LunarUI.NPC_ROLE_COLORS

    it("has caster and miniboss entries", function()
        assert.is_not_nil(colors.caster)
        assert.is_not_nil(colors.miniboss)
    end)

    it("caster has r/g/b values", function()
        assert.is_number(colors.caster.r)
        assert.is_number(colors.caster.g)
        assert.is_number(colors.caster.b)
    end)

    it("miniboss has r/g/b values", function()
        assert.is_number(colors.miniboss.r)
        assert.is_number(colors.miniboss.g)
        assert.is_number(colors.miniboss.b)
    end)
end)

--------------------------------------------------------------------------------
-- GetNPCRoleColor
--------------------------------------------------------------------------------

describe("GetNPCRoleColor", function()
    local db = LunarUI.db.profile.nameplates

    before_each(function()
        mockIsPlayer = false
        mockClassification = "normal"
        mockPowerType = 1
    end)

    it("returns nil for nil unit", function()
        assert.is_nil(LunarUI.GetNPCRoleColor(nil, db))
    end)

    it("returns nil for player unit", function()
        mockIsPlayer = true
        assert.is_nil(LunarUI.GetNPCRoleColor("target", db))
    end)

    it("returns nil when npcColors is disabled", function()
        local disabledDb = { npcColors = { enabled = false } }
        assert.is_nil(LunarUI.GetNPCRoleColor("target", disabledDb))
    end)

    it("returns nil when npcColors is nil", function()
        assert.is_nil(LunarUI.GetNPCRoleColor("target", {}))
    end)

    it("returns miniboss color for elite unit", function()
        mockClassification = "elite"
        local color = LunarUI.GetNPCRoleColor("target", db)
        assert.is_not_nil(color)
        assert.equals(db.npcColors.miniboss.r, color.r)
    end)

    it("returns miniboss color for worldboss", function()
        mockClassification = "worldboss"
        local color = LunarUI.GetNPCRoleColor("target", db)
        assert.is_not_nil(color)
        assert.equals(db.npcColors.miniboss.r, color.r)
    end)

    it("returns miniboss color for rareelite", function()
        mockClassification = "rareelite"
        local color = LunarUI.GetNPCRoleColor("target", db)
        assert.is_not_nil(color)
        assert.equals(db.npcColors.miniboss.r, color.r)
    end)

    it("returns caster color for mana user (powerType 0)", function()
        mockPowerType = 0
        local color = LunarUI.GetNPCRoleColor("target", db)
        assert.is_not_nil(color)
        assert.equals(db.npcColors.caster.r, color.r)
    end)

    it("returns nil for melee NPC (non-mana, non-elite)", function()
        mockClassification = "normal"
        mockPowerType = 1
        assert.is_nil(LunarUI.GetNPCRoleColor("target", db))
    end)

    it("returns nil for rare NPC (not elite tier)", function()
        mockClassification = "rare"
        mockPowerType = 1
        assert.is_nil(LunarUI.GetNPCRoleColor("target", db))
    end)
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("Nameplates lifecycle", function()
    it("CleanupNameplates does not error when not initialized", function()
        assert.has_no_errors(function()
            LunarUI.CleanupNameplates()
        end)
    end)

    it("Spawn → Cleanup → Spawn 循環不報錯（soft disable re-enable）", function()
        assert.has_no_errors(function()
            LunarUI.SpawnNameplates()
            LunarUI.CleanupNameplates()
            LunarUI.SpawnNameplates() -- re-enable 路徑
        end)
    end)

    it("多次 Spawn/Cleanup 循環不累積", function()
        for _ = 1, 3 do
            assert.has_no_errors(function()
                LunarUI.SpawnNameplates()
                LunarUI.CleanupNameplates()
            end)
        end
    end)
end)
