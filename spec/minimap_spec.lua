--[[
    Unit tests for LunarUI/Modules/Minimap.lua
    Tests lifecycle, coordinate helpers, cleanup
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Lua 5.3+ compat: unpack was moved to table.unpack
if not _G.unpack then
    _G.unpack = table.unpack -- luacheck: ignore 143
end

-- Mock WoW APIs
_G.GetTime = function()
    return 1000
end
_G.InCombatLockdown = function()
    return false
end
_G.IsShiftKeyDown = function()
    return false
end
_G.GetZoneText = function()
    return "Stormwind"
end
_G.GetSubZoneText = function()
    return "Trade District"
end
_G.GetGameTime = function()
    return 14, 30
end
_G.GetInstanceInfo = function()
    return "Stormwind", "none", 0
end
_G.GetDifficultyInfo = function()
    return "Normal"
end
_G.HasNewMail = function()
    return false
end
_G.hooksecurefunc = function() end
_G.C_PvP = {
    GetZonePVPInfo = function()
        return "friendly"
    end,
}
_G.C_Map = {
    GetBestMapForUnit = function()
        return 84
    end,
    GetPlayerMapPosition = function()
        return {
            GetXY = function()
                return 0.5, 0.5
            end,
        }
    end,
}
_G.C_Timer = {
    After = function() end,
    NewTimer = function()
        return { Cancel = function() end }
    end,
}
_G.C_Calendar = { OpenCalendar = function() end }
_G.Minimap_ZoomIn = function() end
_G.Minimap_ZoomOut = function() end
_G.ToggleDropDownMenu = function() end

local mock_frame = require("spec.mock_frame")
local MockFrame = mock_frame.MockFrame
_G.Minimap = setmetatable({}, { __index = MockFrame })
_G.MinimapBackdrop = setmetatable({}, { __index = MockFrame })
_G.MinimapCluster = nil -- not present in test
_G.MiniMapTracking = nil
_G.MiniMapTrackingBackground = nil
_G.GameTimeFrame = setmetatable({}, { __index = MockFrame })
_G.AddonCompartmentFrame = setmetatable({}, { __index = MockFrame })
_G.QueueStatusMinimapButton = setmetatable({}, { __index = MockFrame })
_G.ExpansionLandingPageMinimapButton = nil
_G.MiniMapMailFrame = setmetatable({}, { __index = MockFrame })
_G.MinimapZoomIn = setmetatable({}, { __index = MockFrame })
_G.MinimapZoomOut = setmetatable({}, { __index = MockFrame })
_G.HybridMinimap = nil
_G.GetMinimapShape = function()
    return "ROUND"
end
_G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    Show = function() end,
    Hide = function() end,
}

local LunarUI = {
    Colors = {
        bg = { 0.05, 0.05, 0.05 },
        border = { 0.3, 0.3, 0.4 },
        bgIcon = { 0, 0, 0, 0.8 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    backdropTemplate = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetSelectedFont = function()
        return "Fonts\\FRIZQT__.TTF"
    end,
    FormatCoordinates = function(x, y)
        return string.format("%.1f, %.1f", x, y)
    end,
    FormatGameTime = function(h, m)
        return string.format("%02d:%02d", h, m)
    end,
    SafeCall = function(fn)
        fn()
    end,
    RegisterHUDFrame = function() end,
    RegisterMovableFrame = function() end,
    RegisterModule = function() end,
    Print = function() end,
    db = {
        profile = {
            minimap = {
                enabled = true,
                size = 180,
                showCoords = true,
                showClock = true,
                organizeButtons = true,
                zoneTextDisplay = "SHOW",
                borderColor = { r = 0.15, g = 0.12, b = 0.08, a = 1 },
            },
        },
    },
}

loader.loadAddonFile("LunarUI/Modules/Minimap.lua", LunarUI)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("Minimap lifecycle", function()
    it("exports InitializeMinimap function", function()
        assert.is_function(LunarUI.InitializeMinimap)
    end)

    it("exports CleanupMinimap function", function()
        assert.is_function(LunarUI.CleanupMinimap)
    end)

    it("exports RefreshMinimap function", function()
        assert.is_function(LunarUI.RefreshMinimap)
    end)

    it("InitializeMinimap does not error", function()
        assert.has_no_errors(function()
            LunarUI.InitializeMinimap()
        end)
    end)

    it("CleanupMinimap does not error after Init", function()
        assert.has_no_errors(function()
            LunarUI.CleanupMinimap()
        end)
    end)

    it("CleanupMinimap does not error when not initialized", function()
        assert.has_no_errors(function()
            LunarUI.CleanupMinimap()
        end)
    end)

    it("RefreshMinimap does nothing when frame not created", function()
        assert.has_no_errors(function()
            LunarUI.RefreshMinimap()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Config Guard
--------------------------------------------------------------------------------

describe("Minimap config guard", function()
    it("does not init when db is nil", function()
        local saved = LunarUI.db
        LunarUI.db = nil
        -- Load fresh instance
        local testLunarUI = {
            Colors = LunarUI.Colors,
            ICON_TEXCOORD = LunarUI.ICON_TEXCOORD,
            backdropTemplate = LunarUI.backdropTemplate,
            ApplyBackdrop = function() end,
            SetFont = function() end,
            GetSelectedFont = LunarUI.GetSelectedFont,
            FormatCoordinates = LunarUI.FormatCoordinates,
            FormatGameTime = LunarUI.FormatGameTime,
            SafeCall = LunarUI.SafeCall,
            RegisterHUDFrame = function() end,
            RegisterMovableFrame = function() end,
            RegisterModule = function() end,
            Print = function() end,
            db = nil,
        }
        loader.loadAddonFile("LunarUI/Modules/Minimap.lua", testLunarUI)
        assert.has_no_errors(function()
            testLunarUI.InitializeMinimap()
        end)
        LunarUI.db = saved
    end)

    it("does not init when minimap is disabled", function()
        local testLunarUI = {
            Colors = LunarUI.Colors,
            ICON_TEXCOORD = LunarUI.ICON_TEXCOORD,
            backdropTemplate = LunarUI.backdropTemplate,
            ApplyBackdrop = function() end,
            SetFont = function() end,
            GetSelectedFont = LunarUI.GetSelectedFont,
            FormatCoordinates = LunarUI.FormatCoordinates,
            FormatGameTime = LunarUI.FormatGameTime,
            SafeCall = LunarUI.SafeCall,
            RegisterHUDFrame = function() end,
            RegisterMovableFrame = function() end,
            RegisterModule = function() end,
            Print = function() end,
            db = { profile = { minimap = { enabled = false } } },
        }
        loader.loadAddonFile("LunarUI/Modules/Minimap.lua", testLunarUI)
        assert.has_no_errors(function()
            testLunarUI.InitializeMinimap()
        end)
    end)
end)
