--[[
    Unit tests for LunarUI/Core/Presets.lua
    Tests role preset structure, ApplyRolePreset behavior, and GetCurrentRole
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.GetSpecialization = function()
    return nil
end
_G.GetSpecializationRole = function()
    return "DAMAGER"
end

-- 載入 Defaults（提供 GetLayoutPresets）再載入 Presets
local LunarUI = {
    db = nil, -- will be set per-test
    RegisterModule = function() end,
}
local Engine = loader.loadAddonFile("LunarUI/Core/Defaults.lua", LunarUI)
-- Presets.lua 在載入時呼叫 Engine.GetLayoutPresets()，需透過 extraEngine 傳入
loader.loadAddonFile("LunarUI/Core/Presets.lua", LunarUI, { GetLayoutPresets = Engine.GetLayoutPresets })

-- Helper: 建立具有完整 defaults 的測試用 db
local function makeTestDB()
    -- Deep copy relevant defaults
    return {
        profile = {
            unitframes = {
                player = { enabled = true, width = 220, height = 45 },
                target = { enabled = true, width = 220, height = 45 },
                raid = { width = 80, height = 30, spacing = 3 },
                raid1 = { width = 100, height = 36, spacing = 3 },
                raid2 = { width = 80, height = 30, spacing = 3 },
                raid3 = { width = 68, height = 26, spacing = 2 },
                party = { width = 150, height = 35, spacing = 5 },
            },
            nameplates = {
                height = 8,
            },
        },
    }
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

describe("Presets exports", function()
    it("exports GetCurrentRole as function", function()
        assert.is_function(LunarUI.GetCurrentRole)
    end)

    it("exports ApplyRolePreset as function", function()
        assert.is_function(LunarUI.ApplyRolePreset)
    end)
end)

--------------------------------------------------------------------------------
-- GetCurrentRole
--------------------------------------------------------------------------------

describe("GetCurrentRole", function()
    it("returns DAMAGER when no specialization", function()
        _G.GetSpecialization = function()
            return nil
        end
        assert.equals("DAMAGER", LunarUI.GetCurrentRole())
    end)

    it("returns correct role when specialization exists", function()
        _G.GetSpecialization = function()
            return 1
        end
        _G.GetSpecializationRole = function()
            return "TANK"
        end
        assert.equals("TANK", LunarUI.GetCurrentRole())
    end)

    it("returns HEALER for healer spec", function()
        _G.GetSpecialization = function()
            return 2
        end
        _G.GetSpecializationRole = function()
            return "HEALER"
        end
        assert.equals("HEALER", LunarUI.GetCurrentRole())
    end)

    it("returns DAMAGER when GetSpecializationRole errors", function()
        _G.GetSpecialization = function()
            return 1
        end
        _G.GetSpecializationRole = function()
            error("API unavailable")
        end
        assert.equals("DAMAGER", LunarUI.GetCurrentRole())
    end)

    it("returns DAMAGER when GetSpecializationRole returns nil", function()
        _G.GetSpecialization = function()
            return 1
        end
        _G.GetSpecializationRole = function()
            return nil
        end
        assert.equals("DAMAGER", LunarUI.GetCurrentRole())
    end)
end)

--------------------------------------------------------------------------------
-- ApplyRolePreset
--------------------------------------------------------------------------------

describe("ApplyRolePreset", function()
    before_each(function()
        LunarUI.db = makeTestDB()
        -- Reset mocks
        _G.GetSpecialization = function()
            return nil
        end
        _G.GetSpecializationRole = function()
            return "DAMAGER"
        end
    end)

    it("applies DPS preset to raid frames", function()
        LunarUI:ApplyRolePreset("DAMAGER")
        local raid = LunarUI.db.profile.unitframes.raid
        assert.equals(72, raid.width)
        assert.equals(28, raid.height)
        assert.equals(3, raid.spacing)
    end)

    it("applies DPS preset to party frames", function()
        LunarUI:ApplyRolePreset("DAMAGER")
        local party = LunarUI.db.profile.unitframes.party
        assert.equals(140, party.width)
        assert.equals(32, party.height)
    end)

    it("applies Tank preset with nameplate override", function()
        LunarUI:ApplyRolePreset("TANK")
        assert.equals(10, LunarUI.db.profile.nameplates.height)
    end)

    it("applies Tank preset to raid frames", function()
        LunarUI:ApplyRolePreset("TANK")
        local raid = LunarUI.db.profile.unitframes.raid
        assert.equals(85, raid.width)
        assert.equals(32, raid.height)
    end)

    it("applies Healer preset with larger party frames", function()
        LunarUI:ApplyRolePreset("HEALER")
        local party = LunarUI.db.profile.unitframes.party
        assert.equals(165, party.width)
        assert.equals(42, party.height)
    end)

    it("does not modify player frame", function()
        local origWidth = LunarUI.db.profile.unitframes.player.width
        LunarUI:ApplyRolePreset("DAMAGER")
        assert.equals(origWidth, LunarUI.db.profile.unitframes.player.width)
    end)

    it("does not modify nameplates for DPS preset", function()
        local origHeight = LunarUI.db.profile.nameplates.height
        LunarUI:ApplyRolePreset("DAMAGER")
        assert.equals(origHeight, LunarUI.db.profile.nameplates.height)
    end)

    it("does not crash with nil db", function()
        LunarUI.db = nil
        assert.has_no_errors(function()
            LunarUI:ApplyRolePreset("DAMAGER")
        end)
    end)

    it("does not crash with invalid role", function()
        assert.has_no_errors(function()
            LunarUI:ApplyRolePreset("INVALID")
        end)
    end)

    it("does not modify db with invalid role", function()
        local origWidth = LunarUI.db.profile.unitframes.raid.width
        LunarUI:ApplyRolePreset("INVALID")
        assert.equals(origWidth, LunarUI.db.profile.unitframes.raid.width)
    end)

    it("auto-detects role when no argument given", function()
        _G.GetSpecialization = function()
            return 1
        end
        _G.GetSpecializationRole = function()
            return "HEALER"
        end
        LunarUI:ApplyRolePreset()
        -- Should apply healer preset
        assert.equals(165, LunarUI.db.profile.unitframes.party.width)
    end)
end)
