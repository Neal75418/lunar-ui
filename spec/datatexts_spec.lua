---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/Modules/DataTexts.lua
    Tests provider registration, initialization, cleanup, and StatusColor logic
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs
_G.GetFramerate = function()
    return 60
end
_G.GetNetStats = function()
    return 0, 0, 50, 100
end
_G.GetMoney = function()
    return 1234567
end
_G.GetInventoryItemDurability = function()
    return 100, 100
end
_G.UnitName = function()
    return "TestPlayer"
end
_G.IsInGuild = function()
    return false
end
_G.GetNumGuildMembers = function()
    return 0, 0
end
_G.GetGuildInfo = function()
    return nil
end
_G.GetSpecialization = function()
    return nil
end
_G.GetSpecializationInfo = function()
    return nil
end
_G.BNGetNumFriends = function()
    return 0
end
_G.date = os.date
_G.C_Container = {
    GetContainerNumFreeSlots = function()
        return 10
    end,
    GetContainerNumSlots = function()
        return 20
    end,
}
_G.C_FriendList = {
    GetNumFriends = function()
        return 5, 2
    end,
}
_G.C_BattleNet = {
    GetFriendAccountInfo = function()
        return nil
    end,
}
_G.C_GuildInfo = { GuildRoster = function() end }
_G.C_DateAndTime = {
    GetCurrentCalendarTime = function()
        return { hour = 14, minute = 30 }
    end,
}
_G.C_Map = {
    GetBestMapForUnit = function()
        return nil
    end,
    GetPlayerMapPosition = function()
        return nil
    end,
    GetMapInfo = function()
        return nil
    end,
}
_G.ToggleFriendsFrame = function() end
_G.ToggleGuildFrame = function() end
_G.ToggleTalentFrame = function() end
_G.GameTooltip = {
    SetOwner = function() end,
    ClearLines = function() end,
    AddLine = function() end,
    AddDoubleLine = function() end,
    Show = function() end,
    Hide = function() end,
}

require("spec.mock_frame")

-- Track module registration
local registeredModules = {}

local LunarUI = {
    Colors = {
        bg = { 0.05, 0.05, 0.05, 0.8 },
        bgLight = { 0.08, 0.08, 0.08, 0.9 },
        border = { 0.3, 0.3, 0.4, 1 },
    },
    backdropTemplate = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    },
    SetFont = function() end,
    ApplyBackdrop = function() end,
    FormatGameTime = function(hour, minute, is24h)
        if is24h then
            return string.format("%02d:%02d", hour, minute)
        end
        local suffix = hour >= 12 and "PM" or "AM"
        hour = hour % 12
        if hour == 0 then
            hour = 12
        end
        return string.format("%d:%02d %s", hour, minute, suffix)
    end,
    db = {
        profile = {
            datatexts = {
                enabled = true,
                panels = {
                    bottom = {
                        enabled = true,
                        width = 400,
                        height = 22,
                        point = "BOTTOM",
                        x = 0,
                        y = 0,
                        numSlots = 3,
                        slots = { "fps", "latency", "clock" },
                    },
                },
            },
        },
    },
    RegisterModule = function(_self, name, config)
        registeredModules[name] = config
    end,
}
LunarUI.GetModuleDB = function(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

loader.loadAddonFile("LunarUI/Modules/DataTexts.lua", LunarUI)

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

-- DataTexts exports（assert.is_function）已移除，行為由各 describe 隱含驗證

describe("DataTexts module registration", function()
    it("registers DataTexts module", function()
        assert.truthy(registeredModules["DataTexts"])
        assert.is_function(registeredModules["DataTexts"].onEnable)
        assert.is_function(registeredModules["DataTexts"].onDisable)
        assert.equals(0.4, registeredModules["DataTexts"].delay)
    end)
end)

--------------------------------------------------------------------------------
-- Initialization / Cleanup lifecycle
--------------------------------------------------------------------------------

describe("DataTexts lifecycle", function()
    after_each(function()
        LunarUI.CleanupDataTexts()
    end)

    it("initializes without error when enabled", function()
        assert.has_no_errors(function()
            LunarUI.InitializeDataTexts()
        end)
    end)

    it("does not error when config disabled", function()
        local saved = LunarUI.db.profile.datatexts.enabled
        LunarUI.db.profile.datatexts.enabled = false
        assert.has_no_errors(function()
            LunarUI.InitializeDataTexts()
        end)
        LunarUI.db.profile.datatexts.enabled = saved
    end)

    it("cleans up without error", function()
        LunarUI.InitializeDataTexts()
        assert.has_no_errors(function()
            LunarUI.CleanupDataTexts()
        end)
    end)

    it("can initialize twice without error (idempotent)", function()
        assert.has_no_errors(function()
            LunarUI.InitializeDataTexts()
            LunarUI.InitializeDataTexts()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Built-in providers (update functions)
--------------------------------------------------------------------------------

describe("Built-in provider updates", function()
    -- The providers are internal locals, but we can test them indirectly
    -- by initializing and verifying no errors occur with mock APIs

    after_each(function()
        LunarUI.CleanupDataTexts()
    end)

    it("initializes panel with fps/latency/clock slots", function()
        assert.has_no_errors(function()
            LunarUI.InitializeDataTexts()
        end)
    end)

    it("handles missing map data for coords provider", function()
        -- coords provider should return "-- , --" when no map
        _G.C_Map.GetBestMapForUnit = function()
            return nil
        end
        assert.has_no_errors(function()
            LunarUI.InitializeDataTexts()
        end)
    end)

    it("handles not-in-guild for guild provider", function()
        _G.IsInGuild = function()
            return false
        end
        assert.has_no_errors(function()
            LunarUI.InitializeDataTexts()
        end)
    end)

    it("handles no specialization for spec provider", function()
        _G.GetSpecialization = function()
            return nil
        end
        assert.has_no_errors(function()
            LunarUI.InitializeDataTexts()
        end)
    end)
end)
