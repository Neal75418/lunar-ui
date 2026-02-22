--[[
    Unit tests for LunarUI/Core/Tags.lua
    Tests: ShortValue, AbbreviateName, UnitStatusText, Tag Methods
]]

require("spec.wow_mock")
local loader = require("spec.loader")

--------------------------------------------------------------------------------
-- WoW API mocks（Tags.lua 在載入時用 local 捕獲，需在此預設）
--------------------------------------------------------------------------------

-- 可變 mock 狀態（透過 _G 存取以便在測試中修改）
_G._mockUnit = {
    health = 30000,
    healthMax = 100000,
    healthPercent = 30,
    power = 5000,
    powerMax = 10000,
    isDead = false,
    isGhost = false,
    isConnected = true,
    isAFK = false,
    isPlayer = true,
    name = "Arthas",
    className = "Warrior",
    classToken = "WARRIOR",
    level = 80,
    role = "NONE",
}

_G.UnitHealth = function()
    return _G._mockUnit.health
end
_G.UnitHealthMax = function()
    return _G._mockUnit.healthMax
end
_G.UnitHealthPercent = function()
    return _G._mockUnit.healthPercent
end
_G.UnitPower = function()
    return _G._mockUnit.power
end
_G.UnitPowerMax = function()
    return _G._mockUnit.powerMax
end
_G.UnitIsDead = function()
    return _G._mockUnit.isDead
end
_G.UnitIsGhost = function()
    return _G._mockUnit.isGhost
end
_G.UnitIsConnected = function()
    return _G._mockUnit.isConnected
end
_G.UnitIsAFK = function()
    return _G._mockUnit.isAFK
end
_G.UnitIsPlayer = function()
    return _G._mockUnit.isPlayer
end
_G.UnitName = function()
    return _G._mockUnit.name
end
_G.UnitClass = function()
    return _G._mockUnit.className, _G._mockUnit.classToken
end
_G.UnitEffectiveLevel = function()
    return _G._mockUnit.level
end
_G.UnitGroupRolesAssigned = function()
    return _G._mockUnit.role
end
_G.UnitIsUnit = function()
    return false
end
_G.IsInRaid = function()
    return false
end
_G.GetNumGroupMembers = function()
    return 0
end
_G.GetRaidRosterInfo = function()
    return nil
end
_G.GetMaxLevelForLatestExpansion = function()
    return 80
end
-- 使用能產生整數的色值（避免 Lua 5.3+ 的 %02x 浮點數問題）
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 200 / 255, g = 155 / 255, b = 110 / 255 },
    MAGE = { r = 65 / 255, g = 200 / 255, b = 235 / 255 },
}
_G.strlenutf8 = function(s)
    return #s
end
_G.string.utf8sub = function(s, i, j)
    return s:sub(i, j)
end
_G.CurveConstants = { ScaleTo100 = 1 }

-- Tags.lua 需要 oUF Tags 環境
local LunarUI = {}
local extraEngine = {
    oUF = {
        Tags = {
            Methods = {},
            Events = {},
            SharedEvents = {},
        },
    },
}
loader.loadAddonFile("LunarUI/Core/Tags.lua", LunarUI, extraEngine)

-- 取得 TagMethods 供測試使用
local TagMethods = LunarUI.TagMethods

-- 每個測試前重置 mock 狀態
local function resetMockUnit()
    _G._mockUnit = {
        health = 30000,
        healthMax = 100000,
        healthPercent = 30,
        power = 5000,
        powerMax = 10000,
        isDead = false,
        isGhost = false,
        isConnected = true,
        isAFK = false,
        isPlayer = true,
        name = "Arthas",
        className = "Warrior",
        classToken = "WARRIOR",
        level = 80,
        role = "NONE",
    }
end

--------------------------------------------------------------------------------
-- ShortValue
--------------------------------------------------------------------------------

describe("ShortValue", function()
    local ShortValue = LunarUI.ShortValue

    it("returns empty string for nil", function()
        assert.equals("", ShortValue(nil))
    end)

    it("returns '0' for zero", function()
        assert.equals("0", ShortValue(0))
    end)

    it("returns raw number below 1000", function()
        assert.equals("999", ShortValue(999))
    end)

    it("formats thousands with K suffix", function()
        assert.equals("1.0K", ShortValue(1000))
    end)

    it("formats mid-thousands correctly", function()
        assert.equals("25.3K", ShortValue(25300))
    end)

    it("formats millions with M suffix", function()
        assert.equals("1.50M", ShortValue(1500000))
    end)

    it("formats exact million", function()
        assert.equals("1.00M", ShortValue(1000000))
    end)

    it("formats large millions", function()
        assert.equals("12.35M", ShortValue(12345678))
    end)
end)

--------------------------------------------------------------------------------
-- AbbreviateName
--------------------------------------------------------------------------------

describe("AbbreviateName", function()
    local AbbreviateName = LunarUI.AbbreviateName

    it("returns empty string for nil", function()
        assert.equals("", AbbreviateName(nil))
    end)

    it("returns single word unchanged", function()
        assert.equals("Thrall", AbbreviateName("Thrall"))
    end)

    it("abbreviates second word", function()
        assert.equals("Arthas M.", AbbreviateName("Arthas Menethil"))
    end)

    it("abbreviates multiple words", function()
        assert.equals("John S. J.", AbbreviateName("John Smith Junior"))
    end)

    it("returns empty string for empty input", function()
        assert.equals("", AbbreviateName(""))
    end)
end)

--------------------------------------------------------------------------------
-- UnitStatusText
--------------------------------------------------------------------------------

describe("UnitStatusText", function()
    local UnitStatusText = LunarUI.UnitStatusText

    before_each(function()
        resetMockUnit()
    end)

    it("returns Dead for dead unit", function()
        _G._mockUnit.isDead = true
        local result = UnitStatusText("player")
        assert.equals("|cffcc3333Dead|r", result)
    end)

    it("returns Ghost for ghost unit", function()
        _G._mockUnit.isGhost = true
        local result = UnitStatusText("player")
        assert.equals("|cffcc3333Ghost|r", result)
    end)

    it("returns Offline for disconnected unit", function()
        _G._mockUnit.isConnected = false
        local result = UnitStatusText("player")
        assert.equals("|cff999999Offline|r", result)
    end)

    it("returns nil for normal unit", function()
        assert.is_nil(UnitStatusText("player"))
    end)

    it("prioritizes Dead over Ghost", function()
        _G._mockUnit.isDead = true
        _G._mockUnit.isGhost = true
        local result = UnitStatusText("player")
        assert.equals("|cffcc3333Dead|r", result)
    end)

    it("prioritizes Dead over Offline", function()
        _G._mockUnit.isDead = true
        _G._mockUnit.isConnected = false
        local result = UnitStatusText("player")
        assert.equals("|cffcc3333Dead|r", result)
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:health
--------------------------------------------------------------------------------

describe("Tag lunar:health", function()
    local tag = TagMethods["lunar:health"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns ShortValue for normal unit", function()
        _G._mockUnit.health = 12300
        assert.equals("12.3K", tag("player"))
    end)

    it("returns Dead for dead unit", function()
        _G._mockUnit.isDead = true
        assert.equals("|cffcc3333Dead|r", tag("player"))
    end)

    it("returns '0' when UnitHealth returns 0", function()
        _G._mockUnit.health = 0
        assert.equals("0", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:health:percent
--------------------------------------------------------------------------------

describe("Tag lunar:health:percent", function()
    local tag = TagMethods["lunar:health:percent"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns percent for normal unit", function()
        _G._mockUnit.healthPercent = 75
        assert.equals("75%", tag("player"))
    end)

    it("returns Dead for dead unit", function()
        _G._mockUnit.isDead = true
        assert.equals("|cffcc3333Dead|r", tag("player"))
    end)

    it("returns 0% when UnitHealthPercent returns nil", function()
        _G._mockUnit.healthPercent = nil
        _G.UnitHealthPercent = function()
            return nil
        end
        assert.equals("0%", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:health:current-max
--------------------------------------------------------------------------------

describe("Tag lunar:health:current-max", function()
    local tag = TagMethods["lunar:health:current-max"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns formatted current / max", function()
        _G._mockUnit.health = 12300
        _G._mockUnit.healthMax = 45600
        assert.equals("12.3K / 45.6K", tag("player"))
    end)

    it("returns Dead for dead unit", function()
        _G._mockUnit.isDead = true
        assert.equals("|cffcc3333Dead|r", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:health:deficit
--------------------------------------------------------------------------------

describe("Tag lunar:health:deficit", function()
    local tag = TagMethods["lunar:health:deficit"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns deficit when not full", function()
        _G._mockUnit.health = 50000
        _G._mockUnit.healthMax = 100000
        assert.equals("-50.0K", tag("player"))
    end)

    it("returns empty when full health", function()
        _G._mockUnit.health = 100000
        _G._mockUnit.healthMax = 100000
        assert.equals("", tag("player"))
    end)

    it("returns empty when dead", function()
        _G._mockUnit.isDead = true
        assert.equals("", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:power
--------------------------------------------------------------------------------

describe("Tag lunar:power", function()
    local tag = TagMethods["lunar:power"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns ShortValue for normal unit", function()
        _G._mockUnit.power = 5000
        _G._mockUnit.powerMax = 10000
        assert.equals("5.0K", tag("player"))
    end)

    it("returns empty when maxPower is 0", function()
        _G._mockUnit.powerMax = 0
        assert.equals("", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:power:percent
--------------------------------------------------------------------------------

describe("Tag lunar:power:percent", function()
    local tag = TagMethods["lunar:power:percent"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns percent for normal unit", function()
        _G._mockUnit.power = 5000
        _G._mockUnit.powerMax = 10000
        assert.equals("50%", tag("player"))
    end)

    it("returns empty when maxPower is 0", function()
        _G._mockUnit.powerMax = 0
        assert.equals("", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:name:abbrev
--------------------------------------------------------------------------------

describe("Tag lunar:name:abbrev", function()
    local tag = TagMethods["lunar:name:abbrev"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns abbreviated name", function()
        _G._mockUnit.name = "Arthas Menethil"
        assert.equals("Arthas M.", tag("player"))
    end)

    it("returns empty for nil name", function()
        _G._mockUnit.name = nil
        _G.UnitName = function()
            return nil
        end
        assert.equals("", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:name:medium
--------------------------------------------------------------------------------

describe("Tag lunar:name:medium", function()
    local tag = TagMethods["lunar:name:medium"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns short name unchanged", function()
        _G._mockUnit.name = "Thrall"
        assert.equals("Thrall", tag("player"))
    end)

    it("truncates long name with ellipsis", function()
        _G._mockUnit.name = "VeryLongCharacterName"
        local result = tag("player")
        assert.equals("VeryLongCharac...", result)
    end)

    it("returns empty for nil name", function()
        _G._mockUnit.name = nil
        _G.UnitName = function()
            return nil
        end
        assert.equals("", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:level:smart
--------------------------------------------------------------------------------

describe("Tag lunar:level:smart", function()
    local tag = TagMethods["lunar:level:smart"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns level number for normal unit", function()
        _G._mockUnit.level = 50
        assert.equals("50", tag("player"))
    end)

    it("returns empty for max-level player", function()
        _G._mockUnit.level = 80
        _G._mockUnit.isPlayer = true
        assert.equals("", tag("player"))
    end)

    it("returns ?? for level 0", function()
        _G._mockUnit.level = 0
        assert.equals("??", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:class
--------------------------------------------------------------------------------

describe("Tag lunar:class", function()
    local tag = TagMethods["lunar:class"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns class name for player", function()
        assert.equals("Warrior", tag("player"))
    end)

    it("returns empty for non-player", function()
        _G._mockUnit.isPlayer = false
        assert.equals("", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:class:color
--------------------------------------------------------------------------------

describe("Tag lunar:class:color", function()
    local tag = TagMethods["lunar:class:color"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns color code for valid class", function()
        local result = tag("player")
        assert.is_not_nil(result)
        assert.truthy(result:match("^|cff"))
    end)

    it("returns empty for non-player", function()
        _G._mockUnit.isPlayer = false
        assert.equals("", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:status
--------------------------------------------------------------------------------

describe("Tag lunar:status", function()
    local tag = TagMethods["lunar:status"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns AFK for AFK unit", function()
        _G._mockUnit.isAFK = true
        assert.equals("|cff999999AFK|r", tag("player"))
    end)

    it("returns empty for normal unit", function()
        assert.equals("", tag("player"))
    end)

    it("returns Dead for dead unit (status priority)", function()
        _G._mockUnit.isDead = true
        assert.equals("|cffcc3333Dead|r", tag("player"))
    end)
end)

--------------------------------------------------------------------------------
-- Tag: lunar:role
--------------------------------------------------------------------------------

describe("Tag lunar:role", function()
    local tag = TagMethods["lunar:role"]

    before_each(function()
        resetMockUnit()
    end)

    it("returns T for TANK", function()
        _G._mockUnit.role = "TANK"
        assert.equals("|cff5555ffT|r", tag("player"))
    end)

    it("returns H for HEALER", function()
        _G._mockUnit.role = "HEALER"
        assert.equals("|cff55ff55H|r", tag("player"))
    end)

    it("returns D for DAMAGER", function()
        _G._mockUnit.role = "DAMAGER"
        assert.equals("|cffff5555D|r", tag("player"))
    end)

    it("returns empty for NONE", function()
        assert.equals("", tag("player"))
    end)
end)
