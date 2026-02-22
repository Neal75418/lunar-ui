--[[
    Unit tests for LunarUI/Core/Config.lua
    Tests resolveDBPath, ValidateDB, GetModuleConfig, GetConfigValue
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
_G.GetSpecialization = function()
    return 1
end

local LunarUI = {
    version = "test",
    db = nil,
    RegisterEvent = function() end,
    Print = function() end,
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
        assert.equals("lunar", LunarUI.db.profile.style.theme)
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
        LunarUI.db = makeDB({ ["style.theme"] = "invalid_theme" })
        LunarUI:ValidateDB()
        assert.equals("lunar", LunarUI.db.profile.style.theme)
    end)

    it("accepts valid enum value", function()
        LunarUI.db = makeDB({ ["style.theme"] = "parchment" })
        LunarUI:ValidateDB()
        assert.equals("parchment", LunarUI.db.profile.style.theme)
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
-- GetModuleConfig
--------------------------------------------------------------------------------

describe("GetModuleConfig", function()
    it("returns nil when db is nil", function()
        local origDb = LunarUI.db
        LunarUI.db = nil
        assert.is_nil(LunarUI:GetModuleConfig("hud"))
        LunarUI.db = origDb
    end)

    it("returns module config when it exists", function()
        LunarUI.db = { profile = { hud = { scale = 1.5 } } }
        local config = LunarUI:GetModuleConfig("hud")
        assert.same({ scale = 1.5 }, config)
    end)

    it("returns nil for non-existent module", function()
        LunarUI.db = { profile = { hud = { scale = 1.0 } } }
        assert.is_nil(LunarUI:GetModuleConfig("nonexistent"))
    end)
end)

--------------------------------------------------------------------------------
-- GetConfigValue
--------------------------------------------------------------------------------

describe("GetConfigValue", function()
    it("returns nil when db is nil", function()
        local origDb = LunarUI.db
        LunarUI.db = nil
        assert.is_nil(LunarUI:GetConfigValue("hud", "scale"))
        LunarUI.db = origDb
    end)

    it("returns single-level value", function()
        LunarUI.db = { profile = { enabled = true } }
        assert.is_true(LunarUI:GetConfigValue("enabled"))
    end)

    it("returns multi-level value", function()
        LunarUI.db = { profile = { hud = { scale = 1.5 } } }
        assert.equals(1.5, LunarUI:GetConfigValue("hud", "scale"))
    end)

    it("returns nil for broken path", function()
        LunarUI.db = { profile = { hud = { scale = 1.0 } } }
        assert.is_nil(LunarUI:GetConfigValue("hud", "missing", "deep"))
    end)

    it("returns nil when intermediate is not a table", function()
        LunarUI.db = { profile = { hud = "not a table" } }
        assert.is_nil(LunarUI:GetConfigValue("hud", "scale"))
    end)
end)
