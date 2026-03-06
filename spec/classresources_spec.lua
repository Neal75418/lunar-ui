--[[
    Unit tests for LunarUI/HUD/ClassResources.lua
    Tests class resource configuration lookup, lifecycle functions,
    and class/specialization resource type mapping
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
local mockClassID = 4 -- default: Rogue
local mockSpecIndex = nil

_G.UnitClass = function()
    return "Rogue", "ROGUE", mockClassID
end
_G.GetSpecialization = function()
    return mockSpecIndex
end
_G.GetSpecializationRole = function()
    return "DAMAGER"
end
_G.UnitPower = function()
    return 3
end
_G.UnitPowerMax = function()
    return 5
end
_G.GetRuneCooldown = function()
    return 0, 0, true
end
_G.GetTime = function()
    return 1000
end
_G.InCombatLockdown = function()
    return false
end
_G.IsShiftKeyDown = function()
    return false
end
_G.C_Timer = { After = function() end }

-- Mock Enum
_G.Enum = {
    PowerType = {
        ComboPoints = 4,
        Runes = 5,
        SoulShards = 7,
        ArcaneCharges = 16,
        Insanity = 13,
        HolyPower = 9,
        Fury = 17,
        Pain = 18,
        Essence = 19,
    },
}

-- Mock CreateFrame
local MockFrame = {}
MockFrame.__index = MockFrame
function MockFrame:SetSize() end
function MockFrame:SetPoint() end
function MockFrame:SetFrameStrata() end
function MockFrame:SetMovable() end
function MockFrame:EnableMouse() end
function MockFrame:RegisterForDrag() end
function MockFrame:SetClampedToScreen() end
function MockFrame:SetScript() end
function MockFrame:SetAllPoints() end
function MockFrame:SetAlpha() end
function MockFrame:SetTexture() end
function MockFrame:SetTexCoord() end
function MockFrame:SetBlendMode() end
function MockFrame:SetTextColor() end
function MockFrame:SetText() end
function MockFrame:SetFormattedText() end
function MockFrame:ClearAllPoints() end
function MockFrame:StartMoving() end
function MockFrame:StopMovingOrSizing() end
function MockFrame:Hide() end
function MockFrame:Show() end
function MockFrame:IsShown()
    return true
end
function MockFrame:GetFrameLevel()
    return 1
end
function MockFrame:SetFrameLevel() end
function MockFrame:SetMinMaxValues() end
function MockFrame:SetValue() end
function MockFrame:SetStatusBarTexture() end
function MockFrame:SetStatusBarColor() end
function MockFrame:SetVertexColor() end
function MockFrame:SetBackdrop() end
function MockFrame:SetBackdropColor() end
function MockFrame:SetBackdropBorderColor() end
function MockFrame:RegisterEvent() end
function MockFrame:UnregisterAllEvents() end
function MockFrame:CreateTexture()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:CreateFontString()
    return setmetatable({}, { __index = MockFrame })
end

_G.CreateFrame = function()
    return setmetatable({}, { __index = MockFrame })
end
_G.UIParent = setmetatable({}, { __index = MockFrame })

local LunarUI = {
    Colors = {
        bgIcon = { 0, 0, 0, 0.8 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    textures = { glow = "Interface\\glow" },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetHUDSetting = function(_key, default)
        return default
    end,
    RegisterHUDFrame = function() end,
    RegisterMovableFrame = function() end,
    iconBackdropTemplate = {},
    GetSelectedStatusBarTexture = function()
        return "Interface\\StatusBar"
    end,
    RegisterModule = function() end,
    CreateEventHandler = function()
        return setmetatable({
            _events = {},
            _scripts = {},
            RegisterEvent = function(self, e)
                self._events[e] = true
            end,
            SetScript = function(self, name, fn)
                self._scripts[name] = fn
            end,
            UnregisterAllEvents = function() end,
        }, {})
    end,
}

loader.loadAddonFile("LunarUI/HUD/ClassResources.lua", LunarUI)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("ClassResources lifecycle", function()
    it("exports Init function", function()
        assert.is_function(LunarUI.InitClassResources)
    end)

    it("exports Cleanup function", function()
        assert.is_function(LunarUI.CleanupClassResources)
    end)

    it("exports Rebuild function", function()
        assert.is_function(LunarUI.RebuildClassResources)
    end)

    it("Init does not error", function()
        assert.has_no_errors(function()
            LunarUI.InitClassResources()
        end)
    end)

    it("Cleanup does not error after Init", function()
        assert.has_no_errors(function()
            LunarUI.CleanupClassResources()
        end)
    end)

    it("Cleanup does not error when not initialized", function()
        assert.has_no_errors(function()
            LunarUI.CleanupClassResources()
        end)
    end)

    it("RebuildClassResources does nothing in combat", function()
        local origFn = _G.InCombatLockdown
        _G.InCombatLockdown = function()
            return true
        end
        assert.has_no_errors(function()
            LunarUI.RebuildClassResources()
        end)
        _G.InCombatLockdown = origFn
    end)
end)

--------------------------------------------------------------------------------
-- Class Resource Config (tested indirectly via reload)
--------------------------------------------------------------------------------

describe("ClassResources class configs", function()
    -- Each test loads a fresh module instance with a specific class
    local function loadWithClass(classID, specIndex)
        mockClassID = classID
        mockSpecIndex = specIndex

        local testLunarUI = {
            Colors = LunarUI.Colors,
            ICON_TEXCOORD = LunarUI.ICON_TEXCOORD,
            textures = LunarUI.textures,
            ApplyBackdrop = function() end,
            SetFont = function() end,
            GetHUDSetting = function(_key, default)
                return default
            end,
            RegisterHUDFrame = function() end,
            RegisterMovableFrame = function() end,
            iconBackdropTemplate = {},
            GetSelectedStatusBarTexture = function()
                return "Interface\\StatusBar"
            end,
            RegisterModule = function() end,
            CreateEventHandler = LunarUI.CreateEventHandler,
        }

        loader.loadAddonFile("LunarUI/HUD/ClassResources.lua", testLunarUI)
        return testLunarUI
    end

    it("loads for Rogue (class 4)", function()
        local lui = loadWithClass(4, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Death Knight (class 6)", function()
        local lui = loadWithClass(6, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Warlock (class 9)", function()
        local lui = loadWithClass(9, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Monk Windwalker (class 10, spec 3)", function()
        local lui = loadWithClass(10, 3)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Monk non-Windwalker (class 10, spec 2)", function()
        local lui = loadWithClass(10, 2)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Mage Arcane (class 8, spec 1)", function()
        local lui = loadWithClass(8, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Mage non-Arcane (class 8, spec 2)", function()
        local lui = loadWithClass(8, 2)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Priest Shadow (class 5, spec 3)", function()
        local lui = loadWithClass(5, 3)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Demon Hunter Havoc (class 12, spec 1)", function()
        local lui = loadWithClass(12, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Demon Hunter Vengeance (class 12, spec 2)", function()
        local lui = loadWithClass(12, 2)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("loads for Evoker (class 13)", function()
        local lui = loadWithClass(13, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("handles unsupported class gracefully (class 1 Warrior)", function()
        local lui = loadWithClass(1, 1)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)

    it("handles nil specialization", function()
        local lui = loadWithClass(10, nil)
        assert.has_no_errors(function()
            lui.InitClassResources()
        end)
        lui.CleanupClassResources()
    end)
end)
