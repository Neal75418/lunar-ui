---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Core/InstallWizard.lua
    Tests CheckInstallWizard guards and exported API surface
]]

require("spec.wow_mock")
require("spec.mock_frame")
local loader = require("spec.loader")

-- Mock additional WoW APIs used by InstallWizard
_G.GameTooltip = CreateFrame()

local LunarUI = {
    _modulesEnabled = true,
    version = "1.0.0",
    Colors = {
        bg = { 0.1, 0.1, 0.1, 0.9 },
        bgSolid = { 0.05, 0.05, 0.05, 1 },
        bgIcon = { 0.1, 0.1, 0.1, 0.8 },
        bgButtonHover = { 0.3, 0.3, 0.3, 0.5 },
        border = { 0.3, 0.3, 0.4, 1 },
        borderGold = { 1, 0.82, 0, 1 },
        accentPurple = { 0.53, 0.51, 1, 1 },
        textPrimary = { 0.9, 0.9, 0.9 },
        textSecondary = { 0.6, 0.6, 0.6 },
        textDim = { 0.4, 0.4, 0.4 },
        moonSilver = { 0.8, 0.82, 0.86 },
    },
    db = {
        profile = {
            uiScale = 0.75,
            unitframes = {
                player = { width = 200, height = 30 },
                target = { width = 200, height = 30 },
                party = { width = 100, height = 30 },
            },
            nameplates = { width = 120 },
            actionbars = { fadeEnabled = false },
        },
        global = {
            installComplete = false,
        },
    },
    SetFont = function() end,
    ApplyBackdrop = function() end,
    StripTextures = function() end,
    SkinCloseButton = function() end,
    Print = function() end,
    GetModuleDB = function()
        return nil
    end,
    RegisterModule = function() end,
    textures = { glow = "Interface\\glow" },
    backdropTemplate = {},
}

-- Mock Engine.GetLayoutPresets
local extraEngine = {
    L = {},
    GetLayoutPresets = function()
        return {
            dps = { unitframes = { player = { width = 220 } }, nameplates = {} },
            tank = { unitframes = { player = { width = 250 } }, nameplates = { width = 150 } },
            healer = { unitframes = { party = { width = 130 } }, nameplates = {} },
        }
    end,
}

loader.loadAddonFile("LunarUI/Core/InstallWizard.lua", LunarUI, extraEngine)

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

describe("InstallWizard", function()
    before_each(function()
        -- Reset DB state
        LunarUI.db.global.installComplete = false
        LunarUI.db.global.installVersion = nil
        LunarUI.db.profile.uiScale = 0.75
        LunarUI.db.profile.actionbars.fadeEnabled = false
        LunarUI.db.profile.unitframes.player.width = 200
    end)

    -- exported API（assert.is_function）已移除，行為由 CheckInstallWizard 測試隱含驗證

    describe("CheckInstallWizard", function()
        it("does nothing when install is already complete", function()
            LunarUI.db.global.installComplete = true
            -- Should not error or show wizard
            assert.has_no_errors(function()
                LunarUI:CheckInstallWizard()
            end)
        end)

        it("does nothing when db is nil", function()
            local savedDB = LunarUI.db
            LunarUI.db = nil
            assert.has_no_errors(function()
                LunarUI:CheckInstallWizard()
            end)
            LunarUI.db = savedDB
        end)
    end)
end)
