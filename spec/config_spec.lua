---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/Core/Config.lua
    Tests resolveDBPath, ValidateDB, RegisterHUDFrame, ApplyHUDScale
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Need to stub LibStub and AceDB for Config.lua loading
_G.LibStub = function()
    return {
        New = function()
            return {
                RegisterCallback = function() end,
                profile = {},
                global = {},
                char = {},
                GetCurrentProfile = function()
                    return "Default"
                end,
                SetProfile = function() end,
            }
        end,
    }
end
-- wow_mock.lua 已提供 InCombatLockdown 預設值
_G.GetSpecialization = function()
    return 1
end

local LunarUI = {
    version = "test",
    db = nil,
    RegisterEvent = function() end,
    Print = function() end,
    Warn = function() end,
    Error = function() end,
    IsEnabled = function()
        return true
    end,
    ApplyHUDScale = function() end,
}

-- Provide defaults for ValidateDB
local defaults = {
    profile = {
        hud = {
            scale = 1.0,
            auraIconSize = 30,
            cdIconSize = 30,
            fctFontSize = 18,
            fctCritScale = 1.5,
            fctDuration = 1.5,
        },
        actionbars = {
            alpha = 1,
            fadeAlpha = 0.3,
            fadeDelay = 2,
            fadeDuration = 0.3,
            buttonSize = 32,
            buttonSpacing = 2,
        },
        minimap = {
            size = 180,
            fadeAlpha = 0.3,
            pinScale = 1.0,
            resetZoomTimer = 5,
            zoneFontSize = 12,
            coordFontSize = 10,
            clockFormat = "24h",
            zoneTextDisplay = "SHOW",
            zoneFontOutline = "OUTLINE",
            coordFontOutline = "OUTLINE",
        },
        bags = { slotsPerRow = 12, slotSize = 37, slotSpacing = 4, frameAlpha = 1, ilvlThreshold = 1 },
        chat = { width = 400, height = 200, fadeTime = 120 },
        style = { theme = "lunar", fontSize = 12, borderStyle = "ink" },
        nameplates = { healthTextFormat = "percent" },
        auraFilters = { sortMethod = "time" },
        frameMover = { gridSize = 10, moverAlpha = 0.5 },
    },
}

loader.loadAddonFile("LunarUI/Core/Config.lua", LunarUI, { _defaults = defaults, L = {} })

--------------------------------------------------------------------------------
-- resolveDBPath
--------------------------------------------------------------------------------

describe("resolveDBPath", function()
    it("resolves simple path", function()
        local db = { hud = { scale = 1.5 } }
        local parent, key, value = LunarUI.resolveDBPath(db, "hud.scale")
        assert.same(db.hud, parent)
        assert.equals("scale", key)
        assert.equals(1.5, value)
    end)

    it("resolves single-level path", function()
        local db = { enabled = true }
        local parent, key, value = LunarUI.resolveDBPath(db, "enabled")
        assert.same(db, parent)
        assert.equals("enabled", key)
        assert.equals(true, value)
    end)

    it("resolves deep path", function()
        local db = { a = { b = { c = "deep" } } }
        local parent, key, value = LunarUI.resolveDBPath(db, "a.b.c")
        assert.same(db.a.b, parent)
        assert.equals("c", key)
        assert.equals("deep", value)
    end)

    it("returns nil for missing intermediate path", function()
        local db = { a = { x = 1 } }
        local parent, key, value = LunarUI.resolveDBPath(db, "a.b.c")
        assert.is_nil(parent)
        assert.is_nil(key)
        assert.is_nil(value)
    end)

    it("returns nil for non-table intermediate", function()
        local db = { a = "not a table" }
        local parent, key, value = LunarUI.resolveDBPath(db, "a.b")
        assert.is_nil(parent)
        assert.is_nil(key)
        assert.is_nil(value)
    end)
end)

--------------------------------------------------------------------------------
-- ValidateDB
--------------------------------------------------------------------------------

describe("ValidateDB", function()
    local function makeDB(overrides)
        -- Deep copy defaults profile
        local profile = {}
        for module, settings in pairs(defaults.profile) do
            profile[module] = {}
            for k, v in pairs(settings) do
                profile[module][k] = v
            end
        end
        -- Apply overrides
        if overrides then
            for path, value in pairs(overrides) do
                local parts = {}
                for part in path:gmatch("[^.]+") do
                    parts[#parts + 1] = part
                end
                local target = profile
                for i = 1, #parts - 1 do
                    target = target[parts[i]]
                end
                target[parts[#parts]] = value
            end
        end
        return {
            profile = profile,
            global = {},
            char = {},
        }
    end

    it("does not modify valid settings", function()
        LunarUI.db = makeDB()
        LunarUI:ValidateDB()
        assert.equals(1.0, LunarUI.db.profile.hud.scale)
        assert.equals("24h", LunarUI.db.profile.minimap.clockFormat)
    end)

    it("fixes number below minimum", function()
        LunarUI.db = makeDB({ ["hud.scale"] = 0.1 })
        LunarUI:ValidateDB()
        assert.equals(defaults.profile.hud.scale, LunarUI.db.profile.hud.scale)
    end)

    it("fixes number above maximum", function()
        LunarUI.db = makeDB({ ["hud.scale"] = 10.0 })
        LunarUI:ValidateDB()
        assert.equals(defaults.profile.hud.scale, LunarUI.db.profile.hud.scale)
    end)

    it("fixes wrong type (string where number expected)", function()
        LunarUI.db = makeDB({ ["hud.scale"] = "not a number" })
        LunarUI:ValidateDB()
        assert.equals(defaults.profile.hud.scale, LunarUI.db.profile.hud.scale)
    end)

    it("fixes invalid enum value", function()
        LunarUI.db = makeDB({ ["minimap.clockFormat"] = "invalid" })
        LunarUI:ValidateDB()
        assert.equals("24h", LunarUI.db.profile.minimap.clockFormat)
    end)

    it("accepts valid enum value", function()
        LunarUI.db = makeDB({ ["minimap.clockFormat"] = "12h" })
        LunarUI:ValidateDB()
        assert.equals("12h", LunarUI.db.profile.minimap.clockFormat)
    end)

    it("fixes invalid clock format", function()
        LunarUI.db = makeDB({ ["minimap.clockFormat"] = "military" })
        LunarUI:ValidateDB()
        assert.equals("24h", LunarUI.db.profile.minimap.clockFormat)
    end)

    it("accepts valid clock format", function()
        LunarUI.db = makeDB({ ["minimap.clockFormat"] = "12h" })
        LunarUI:ValidateDB()
        assert.equals("12h", LunarUI.db.profile.minimap.clockFormat)
    end)
end)

--------------------------------------------------------------------------------
-- OnProfileChanged
--------------------------------------------------------------------------------

describe("OnProfileChanged", function()
    local origApply, origPrint

    before_each(function()
        origApply = LunarUI.ApplyHUDScale
        origPrint = LunarUI.Print
    end)

    after_each(function()
        LunarUI.ApplyHUDScale = origApply
        LunarUI.Print = origPrint
    end)

    it("calls ApplyHUDScale if available", function()
        local called = false
        LunarUI.ApplyHUDScale = function()
            called = true
        end
        LunarUI.Print = function() end

        LunarUI:OnProfileChanged()
        assert.is_true(called)
    end)

    it("prints profile changed message", function()
        local printed = nil
        LunarUI.Print = function(_self, msg)
            printed = msg
        end

        LunarUI:OnProfileChanged()
        assert.is_not_nil(printed)
    end)
end)

--------------------------------------------------------------------------------
-- RegisterHUDFrame
--------------------------------------------------------------------------------

describe("RegisterHUDFrame", function()
    it("registers frame name and applies scale", function()
        local mockFrame = {
            _scale = 1,
            SetScale = function(self, s)
                self._scale = s
            end,
        }
        _G["LunarUI_TestHUDFrame"] = mockFrame

        LunarUI.db = { profile = { hud = { scale = 1.5 } } }
        LunarUI:RegisterHUDFrame("LunarUI_TestHUDFrame")
        assert.equals(1.5, mockFrame._scale)

        _G["LunarUI_TestHUDFrame"] = nil
    end)

    it("handles missing frame gracefully", function()
        LunarUI.db = { profile = { hud = { scale = 1.5 } } }
        assert.has_no_errors(function()
            LunarUI:RegisterHUDFrame("LunarUI_NonExistentFrame")
        end)
    end)

    it("handles nil db gracefully", function()
        local origDB = LunarUI.db
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI:RegisterHUDFrame("LunarUI_SomeFrame")
        end)
        LunarUI.db = origDB
    end)
end)

--------------------------------------------------------------------------------
-- ApplyHUDScale
--------------------------------------------------------------------------------

describe("ApplyHUDScale", function()
    it("applies scale to registered HUD frames", function()
        local mockFrame = {
            _scale = 1,
            SetScale = function(self, s)
                self._scale = s
            end,
        }
        _G["LunarUI_TestScaleFrame"] = mockFrame

        LunarUI.db = { profile = { hud = { scale = 1.5 } } }
        LunarUI:RegisterHUDFrame("LunarUI_TestScaleFrame")
        -- Reset and re-apply
        mockFrame._scale = 1
        LunarUI.db.profile.hud.scale = 2.0
        LunarUI:ApplyHUDScale()
        assert.equals(2.0, mockFrame._scale)

        _G["LunarUI_TestScaleFrame"] = nil
    end)

    it("handles nil db gracefully", function()
        local origDB = LunarUI.db
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI:ApplyHUDScale()
        end)
        LunarUI.db = origDB
    end)

    it("uses default scale 1.0 when not set", function()
        local mockFrame = {
            _scale = 2,
            SetScale = function(self, s)
                self._scale = s
            end,
        }
        _G["LunarUI_TestDefaultScale"] = mockFrame

        LunarUI.db = { profile = { hud = {} } }
        LunarUI:RegisterHUDFrame("LunarUI_TestDefaultScale")
        assert.equals(1.0, mockFrame._scale)

        _G["LunarUI_TestDefaultScale"] = nil
    end)
end)

--------------------------------------------------------------------------------
-- ValidateDB (additional edge cases)
--------------------------------------------------------------------------------

describe("ValidateDB edge cases", function()
    it("handles nil db gracefully", function()
        local origDB = LunarUI.db
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI:ValidateDB()
        end)
        LunarUI.db = origDB
    end)

    it("fixes wrong type for string field (number where string expected)", function()
        LunarUI.db = {
            profile = {
                style = defaults.profile.style,
                hud = defaults.profile.hud,
                actionbars = defaults.profile.actionbars,
                minimap = { clockFormat = 123 }, -- number where string expected
                bags = defaults.profile.bags,
                chat = defaults.profile.chat,
                nameplates = defaults.profile.nameplates,
                auraFilters = defaults.profile.auraFilters,
                frameMover = defaults.profile.frameMover,
            },
            global = {},
            char = {},
        }
        LunarUI:ValidateDB()
        assert.equals("24h", LunarUI.db.profile.minimap.clockFormat)
    end)

    it("fixes boolean type violation", function()
        -- No boolean rules in current config, but ensure the branch is safe
        LunarUI.db = {
            profile = {
                hud = defaults.profile.hud,
                actionbars = defaults.profile.actionbars,
                minimap = defaults.profile.minimap,
                bags = defaults.profile.bags,
                chat = defaults.profile.chat,
                style = defaults.profile.style,
                nameplates = defaults.profile.nameplates,
                auraFilters = defaults.profile.auraFilters,
                frameMover = defaults.profile.frameMover,
            },
            global = {},
            char = {},
        }
        assert.has_no_errors(function()
            LunarUI:ValidateDB()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- OnDisable
--------------------------------------------------------------------------------

describe("OnDisable", function()
    it("is NOT defined in Config.lua (handled by Init.lua to avoid shadowing)", function()
        -- Config.lua 不應定義 OnDisable，否則會覆蓋 Init.lua 的完整清理邏輯
        -- Init.lua:185 已包含 UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        -- 設定 sentinel 函數，模擬 Init.lua 的 OnDisable
        local sentinel = function() end
        LunarUI.OnDisable = sentinel

        -- 重新載入 Config.lua，確認它不會覆蓋 sentinel
        loader.loadAddonFile("LunarUI/Core/Config.lua", LunarUI, { _defaults = defaults })

        assert.equals(sentinel, LunarUI.OnDisable)
    end)
end)
