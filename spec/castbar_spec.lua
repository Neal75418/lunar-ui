---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/UnitFrames/CastBar.lua
    Tests CreateCastbar lifecycle, CHANNEL_TICKS data integrity
]]

require("spec.wow_mock")
require("spec.mock_frame")
local loader = require("spec.loader")

-- Mock oUF spawn environment
_G.UnitChannelInfo = function()
    return nil
end
_G.UnitCastingInfo = function()
    return nil
end
_G.GetNetStats = function()
    return 0, 0, 50, 100
end

local LunarUI = {
    Colors = {
        bg = { 0.1, 0.1, 0.1, 0.9 },
        bgIcon = { 0.1, 0.1, 0.1, 0.8 },
        border = { 0.3, 0.3, 0.4, 1 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
        textSecondary = { 0.6, 0.6, 0.6 },
    },
    CASTBAR_COLOR = { 0.4, 0.6, 0.8, 1 },
    BG_DARKEN = { 0, 0, 0, 0.6 },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetModuleDB = function()
        return {
            player = { castbar = { height = 18, showLatency = true, showTicks = true, showEmpowered = true } },
            target = { castbar = { height = 16 } },
        }
    end,
    GetSelectedStatusBarTexture = function()
        return "Interface\\TargetingFrame\\UI-StatusBar"
    end,
    textures = { glow = "Interface\\glow" },
    backdropTemplate = {},
    db = {
        profile = {
            unitframes = {
                player = { castbar = true, castbarHeight = 18, castbarWidth = 200, castbarSpark = true },
            },
        },
    },
    UFGetStatusBarTexture = function()
        return "Interface\\TargetingFrame\\UI-StatusBar"
    end,
    RegisterModule = function() end,
}

loader.loadAddonFile("LunarUI/UnitFrames/CastBar.lua", LunarUI)

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

describe("CastBar", function()
    -- UFCreateCastbar export（assert.is_function）已移除，行為由 CreateCastbar 測試隱含驗證

    describe("CHANNEL_TICKS data integrity", function()
        it("contains only positive integer tick counts", function()
            assert.is_table(LunarUI.CHANNEL_TICKS)
            for spellID, ticks in pairs(LunarUI.CHANNEL_TICKS) do
                assert.is_number(spellID, "spellID should be a number")
                assert.is_number(ticks, "ticks should be a number for spellID " .. tostring(spellID))
                assert.is_true(ticks > 0, "ticks should be positive for spellID " .. tostring(spellID))
                assert.equals(math.floor(ticks), ticks, "ticks should be integer for spellID " .. tostring(spellID))
            end
        end)

        it("has at least one entry", function()
            local count = 0
            for _ in pairs(LunarUI.CHANNEL_TICKS) do
                count = count + 1
            end
            assert.is_true(count > 0)
        end)
    end)

    describe("CreateCastbar", function()
        it("creates a castbar on a mock unit frame", function()
            local unitFrame = CreateFrame()
            unitFrame.unit = "player"
            -- Mock GetModuleDB to return castbar settings
            LunarUI.GetModuleDB = function()
                return {
                    player = { castbar = { height = 18, showLatency = true, showTicks = true, showEmpowered = true } },
                }
            end
            assert.has_no_errors(function()
                LunarUI.UFCreateCastbar(unitFrame, "player")
            end)
        end)

        it("creates castbar with nil GetModuleDB (uses defaults)", function()
            local unitFrame = CreateFrame()
            unitFrame.unit = "player"
            LunarUI.GetModuleDB = function()
                return nil -- no unitframes config
            end
            assert.has_no_errors(function()
                LunarUI.UFCreateCastbar(unitFrame, "player")
            end)
        end)
    end)
end)
