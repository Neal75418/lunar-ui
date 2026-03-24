---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Core/Defaults.lua
    Validates config structure completeness, type consistency, and value ranges
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Defaults.lua 不直接使用 LunarUI，僅掛載到 Engine
local LunarUI = {}
local Engine = loader.loadAddonFile("LunarUI/Core/Defaults.lua", LunarUI)
local defaults = Engine._defaults
local presets = Engine.GetLayoutPresets()

--------------------------------------------------------------------------------
-- Top-level structure
--------------------------------------------------------------------------------

describe("Defaults top-level structure", function()
    it("has profile table", function()
        assert.is_table(defaults.profile)
    end)

    it("has global table", function()
        assert.is_table(defaults.global)
    end)

    it("has char table", function()
        assert.is_table(defaults.char)
    end)

    it("global has installComplete as boolean", function()
        assert.is_false(defaults.global.installComplete)
    end)

    it("char has specProfiles as table", function()
        assert.is_table(defaults.char.specProfiles)
    end)
end)

--------------------------------------------------------------------------------
-- Module keys
--------------------------------------------------------------------------------

describe("Defaults module completeness", function()
    local p = defaults.profile

    local requiredModules = {
        "unitframes",
        "nameplates",
        "actionbars",
        "automation",
        "minimap",
        "bags",
        "chat",
        "tooltip",
        "databars",
        "datatexts",
        "hud",
        "skins",
        "style",
        "frameMover",
        "loot",
        "auraFilters",
    }

    for _, mod in ipairs(requiredModules) do
        it("has " .. mod .. " module", function()
            assert.is_not_nil(p[mod], "Missing module: " .. mod)
        end)
    end

    it("has enabled as boolean", function()
        assert.is_true(p.enabled)
    end)

    it("has debug as boolean", function()
        assert.is_false(p.debug)
    end)
end)

--------------------------------------------------------------------------------
-- UnitFrames sub-structure
--------------------------------------------------------------------------------

describe("Defaults unitframes", function()
    local uf = defaults.profile.unitframes

    local unitTypes = {
        "player",
        "target",
        "focus",
        "pet",
        "targettarget",
        "party",
        "raid",
        "raid1",
        "raid2",
        "raid3",
        "boss",
    }

    for _, unit in ipairs(unitTypes) do
        it("has " .. unit .. " config", function()
            assert.is_table(uf[unit], "Missing unit: " .. unit)
        end)
    end

    -- Full unit frames (player/target/focus/boss/party) have extensive fields
    local fullUnits = { "player", "target", "focus" }
    for _, unit in ipairs(fullUnits) do
        it(unit .. " has required dimension fields", function()
            assert.is_number(uf[unit].width)
            assert.is_number(uf[unit].height)
            assert.is_true(uf[unit].width > 0)
            assert.is_true(uf[unit].height > 0)
        end)

        it(unit .. " has position fields", function()
            assert.is_number(uf[unit].x)
            assert.is_number(uf[unit].y)
            assert.is_string(uf[unit].point)
        end)

        it(unit .. " has enabled as boolean", function()
            assert.is_boolean(uf[unit].enabled)
        end)
    end

    -- Raid size variants have minimal fields
    local raidVariants = { "raid1", "raid2", "raid3" }
    for _, unit in ipairs(raidVariants) do
        it(unit .. " has width/height/spacing", function()
            assert.is_number(uf[unit].width)
            assert.is_number(uf[unit].height)
            assert.is_number(uf[unit].spacing)
            assert.is_true(uf[unit].width > 0)
            assert.is_true(uf[unit].height > 0)
            assert.is_true(uf[unit].spacing > 0)
        end)
    end

    it("player has castbar config", function()
        assert.is_table(uf.player.castbar)
        assert.is_number(uf.player.castbar.height)
        assert.is_boolean(uf.player.castbar.showLatency)
    end)
end)

--------------------------------------------------------------------------------
-- Nameplates
--------------------------------------------------------------------------------

describe("Defaults nameplates", function()
    local np = defaults.profile.nameplates

    it("has enabled boolean", function()
        assert.is_boolean(np.enabled)
    end)

    it("has dimension fields", function()
        assert.is_number(np.width)
        assert.is_number(np.height)
        assert.is_true(np.width > 0)
        assert.is_true(np.height > 0)
    end)

    it("has enemy config", function()
        assert.is_table(np.enemy)
        assert.is_boolean(np.enemy.enabled)
        assert.is_boolean(np.enemy.showHealth)
        assert.is_boolean(np.enemy.showCastbar)
    end)

    it("has friendly config", function()
        assert.is_table(np.friendly)
        assert.is_boolean(np.friendly.enabled)
    end)

    it("has threat config", function()
        assert.is_table(np.threat)
        assert.is_boolean(np.threat.enabled)
    end)

    it("has npcColors config with RGB tables", function()
        assert.is_table(np.npcColors)
        assert.is_boolean(np.npcColors.enabled)
        assert.is_number(np.npcColors.caster.r)
        assert.is_number(np.npcColors.caster.g)
        assert.is_number(np.npcColors.caster.b)
        assert.is_number(np.npcColors.miniboss.r)
    end)

    it("healthTextFormat is valid enum", function()
        local valid = { percent = true, current = true, both = true }
        assert.is_true(valid[np.healthTextFormat] or false)
    end)
end)

--------------------------------------------------------------------------------
-- ActionBars
--------------------------------------------------------------------------------

describe("Defaults actionbars", function()
    local ab = defaults.profile.actionbars

    it("has enabled boolean", function()
        assert.is_boolean(ab.enabled)
    end)

    it("has buttonSize as positive number", function()
        assert.is_number(ab.buttonSize)
        assert.is_true(ab.buttonSize > 0)
    end)

    it("has fade settings", function()
        assert.is_boolean(ab.fadeEnabled)
        assert.is_number(ab.fadeAlpha)
        assert.is_true(ab.fadeAlpha >= 0 and ab.fadeAlpha <= 1)
    end)

    -- bar1-6 from CreateBarDefaults
    for i = 1, 6 do
        local barKey = "bar" .. i
        it(barKey .. " has required fields", function()
            assert.is_table(ab[barKey], "Missing bar: " .. barKey)
            assert.is_boolean(ab[barKey].enabled)
            assert.is_number(ab[barKey].buttons)
            assert.is_number(ab[barKey].x)
            assert.is_number(ab[barKey].y)
            assert.is_string(ab[barKey].orientation)
        end)
    end

    it("petbar exists", function()
        assert.is_table(ab.petbar)
        assert.is_boolean(ab.petbar.enabled)
    end)

    it("stancebar exists", function()
        assert.is_table(ab.stancebar)
        assert.is_boolean(ab.stancebar.enabled)
    end)

    it("microBar exists with dimensions", function()
        assert.is_table(ab.microBar)
        assert.is_number(ab.microBar.buttonWidth)
        assert.is_number(ab.microBar.buttonHeight)
    end)
end)

--------------------------------------------------------------------------------
-- Style & Enums
--------------------------------------------------------------------------------

describe("Defaults style enums", function()
    local s = defaults.profile.style

    it("theme is valid enum", function()
        local valid = { lunar = true, parchment = true, minimal = true }
        assert.is_true(valid[s.theme] or false)
    end)

    it("borderStyle is valid enum", function()
        local valid = { ink = true, clean = true, none = true }
        assert.is_true(valid[s.borderStyle] or false)
    end)

    it("font is a string", function()
        assert.is_string(s.font)
    end)

    it("fontSize is a positive number", function()
        assert.is_number(s.fontSize)
        assert.is_true(s.fontSize > 0)
    end)
end)

describe("Defaults minimap enums", function()
    local mm = defaults.profile.minimap

    it("clockFormat is valid enum", function()
        local valid = { ["12h"] = true, ["24h"] = true }
        assert.is_true(valid[mm.clockFormat] or false)
    end)

    it("zoneTextDisplay is valid enum", function()
        local valid = { SHOW = true, MOUSEOVER = true, HIDE = true }
        assert.is_true(valid[mm.zoneTextDisplay] or false)
    end)

    it("size is positive number", function()
        assert.is_number(mm.size)
        assert.is_true(mm.size > 0)
    end)

    it("borderColor has r/g/b/a fields", function()
        local bc = mm.borderColor
        assert.is_number(bc.r)
        assert.is_number(bc.g)
        assert.is_number(bc.b)
        assert.is_number(bc.a)
    end)
end)

--------------------------------------------------------------------------------
-- Aura Filters
--------------------------------------------------------------------------------

describe("Defaults aura filters", function()
    local af = defaults.profile.auraFilters

    it("sortMethod is valid enum", function()
        local valid = { time = true, duration = true, name = true, player = true }
        assert.is_true(valid[af.sortMethod] or false)
    end)

    it("sortReverse is boolean", function()
        assert.is_boolean(af.sortReverse)
    end)

    it("hidePassive is boolean", function()
        assert.is_boolean(af.hidePassive)
    end)
end)

--------------------------------------------------------------------------------
-- Skins
--------------------------------------------------------------------------------

describe("Defaults skins", function()
    local sk = defaults.profile.skins

    it("has enabled boolean", function()
        assert.is_boolean(sk.enabled)
    end)

    it("has blizzard table", function()
        assert.is_table(sk.blizzard)
    end)

    local skinNames = {
        "character",
        "spellbook",
        "talents",
        "quest",
        "merchant",
        "gossip",
        "worldmap",
        "achievements",
        "mail",
        "collections",
        "lfg",
        "encounterjournal",
        "auctionhouse",
        "communities",
        "housing",
        "professions",
        "pvp",
        "settings",
        "trade",
        "calendar",
        "weeklyrewards",
        "addonlist",
    }

    for _, name in ipairs(skinNames) do
        it("blizzard." .. name .. " is boolean", function()
            assert.is_boolean(sk.blizzard[name], "Missing or non-boolean skin: " .. name)
        end)
    end

    it("blizzard skin count matches registered skins", function()
        local actualCount = 0
        for _ in pairs(sk.blizzard) do
            actualCount = actualCount + 1
        end
        -- 動態計算：skinNames 列舉的數量應與實際註冊的 skin 數量一致
        assert.equals(
            #skinNames,
            actualCount,
            "skinNames list out of sync: expected " .. #skinNames .. ", got " .. actualCount
        )
        -- 確保每個實際 skin 都在 skinNames 中被驗證
        local nameSet = {}
        for _, name in ipairs(skinNames) do
            nameSet[name] = true
        end
        for key in pairs(sk.blizzard) do
            assert.is_true(nameSet[key] ~= nil, "Unverified skin in defaults: " .. key)
        end
    end)
end)

--------------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------------

describe("Defaults HUD", function()
    local h = defaults.profile.hud

    it("scale is number in valid range", function()
        assert.is_number(h.scale)
        assert.is_true(h.scale >= 0.5 and h.scale <= 2.0)
    end)

    it("icon sizes are positive numbers", function()
        assert.is_number(h.auraIconSize)
        assert.is_true(h.auraIconSize > 0)
        assert.is_number(h.cdIconSize)
        assert.is_true(h.cdIconSize > 0)
        assert.is_number(h.crIconSize)
        assert.is_true(h.crIconSize > 0)
    end)

    it("FCT defaults are sane", function()
        assert.is_false(h.fctEnabled)
        assert.is_number(h.fctFontSize)
        assert.is_true(h.fctFontSize > 0)
        assert.is_number(h.fctCritScale)
        assert.is_true(h.fctCritScale >= 1.0)
        assert.is_number(h.fctDuration)
        assert.is_true(h.fctDuration > 0)
    end)
end)

--------------------------------------------------------------------------------
-- DataBars
--------------------------------------------------------------------------------

describe("Defaults databars", function()
    local db = defaults.profile.databars
    local barNames = { "experience", "reputation", "honor" }

    for _, name in ipairs(barNames) do
        it(name .. " has required fields", function()
            assert.is_table(db[name])
            assert.is_boolean(db[name].enabled)
            assert.is_number(db[name].width)
            assert.is_number(db[name].height)
            assert.is_true(db[name].width > 0)
            assert.is_true(db[name].height > 0)
        end)

        it(name .. " textFormat is valid enum", function()
            local valid = { percent = true, curmax = true, cur = true, remaining = true }
            assert.is_true(valid[db[name].textFormat] or false)
        end)
    end
end)

--------------------------------------------------------------------------------
-- GetLayoutPresets
--------------------------------------------------------------------------------

describe("GetLayoutPresets", function()
    local roles = { "dps", "tank", "healer" }

    for _, role in ipairs(roles) do
        it(role .. " preset exists", function()
            assert.is_table(presets[role])
        end)

        it(role .. " has unitframes", function()
            assert.is_table(presets[role].unitframes)
        end)

        local raidUnits = { "raid", "raid1", "raid2", "raid3", "party" }
        for _, unit in ipairs(raidUnits) do
            it(role .. "." .. unit .. " has width/height/spacing", function()
                local u = presets[role].unitframes[unit]
                assert.is_table(u, role .. " missing " .. unit)
                assert.is_number(u.width)
                assert.is_number(u.height)
                assert.is_number(u.spacing)
                assert.is_true(u.width > 0)
                assert.is_true(u.height > 0)
                assert.is_true(u.spacing > 0)
            end)
        end
    end

    it("tank preset has nameplates override", function()
        assert.is_table(presets.tank.nameplates)
        assert.is_number(presets.tank.nameplates.height)
    end)

    it("dps and healer have no nameplates override", function()
        assert.is_nil(presets.dps.nameplates)
        assert.is_nil(presets.healer.nameplates)
    end)

    it("healer party is larger than dps party", function()
        assert.is_true(presets.healer.unitframes.party.width > presets.dps.unitframes.party.width)
        assert.is_true(presets.healer.unitframes.party.height > presets.dps.unitframes.party.height)
    end)
end)
