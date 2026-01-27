--[[
    LunarUI - Configuration (AceDB)
    Database defaults and profile management
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- Database defaults
local defaults = {
    profile = {
        -- General settings
        enabled = true,
        debug = false,

        -- Phase Manager settings
        waningDuration = 10,  -- seconds before NEW after combat

        -- Token overrides (per phase)
        tokens = {
            NEW = {
                alpha = 0.40,
                scale = 0.95,
            },
            WAXING = {
                alpha = 0.65,
                scale = 0.98,
            },
            FULL = {
                alpha = 1.00,
                scale = 1.00,
            },
            WANING = {
                alpha = 0.75,
                scale = 0.98,
            },
        },

        -- UnitFrames settings
        unitframes = {
            player = {
                enabled = true,
                width = 220,
                height = 45,
                x = -300,
                y = -200,
                point = "CENTER",
            },
            target = {
                enabled = true,
                width = 220,
                height = 45,
                x = 300,
                y = -200,
                point = "CENTER",
            },
            focus = {
                enabled = true,
                width = 180,
                height = 35,
                x = -450,
                y = -100,
                point = "CENTER",
            },
            pet = {
                enabled = true,
                width = 120,
                height = 25,
                x = -300,
                y = -260,
                point = "CENTER",
            },
            targettarget = {
                enabled = true,
                width = 120,
                height = 25,
                x = 450,
                y = -200,
                point = "CENTER",
            },
            party = {
                enabled = true,
                width = 150,
                height = 35,
                x = -500,
                y = 0,
                point = "LEFT",
                spacing = 5,
            },
            raid = {
                enabled = true,
                width = 80,
                height = 30,
                x = 20,
                y = -20,
                point = "TOPLEFT",
                spacing = 3,
            },
            boss = {
                enabled = true,
                width = 180,
                height = 40,
                x = -100,
                y = 300,
                point = "RIGHT",
                spacing = 50,
            },
        },

        -- ActionBars settings (future)
        actionbars = {
            bar1 = { enabled = true, buttons = 12, buttonSize = 36 },
            bar2 = { enabled = true, buttons = 12, buttonSize = 36 },
            bar3 = { enabled = false, buttons = 12, buttonSize = 36 },
            bar4 = { enabled = false, buttons = 12, buttonSize = 36 },
            bar5 = { enabled = false, buttons = 12, buttonSize = 36 },
            petbar = { enabled = true },
            stancebar = { enabled = true },
        },

        -- Minimap settings (future)
        minimap = {
            enabled = true,
            size = 175,
            shape = "SQUARE",  -- SQUARE or ROUND
        },

        -- Bags settings (future)
        bags = {
            enabled = true,
            bagWidth = 12,
            sortDirection = "DOWN",
        },

        -- Chat settings (future)
        chat = {
            enabled = true,
            width = 400,
            height = 180,
        },

        -- Tooltip settings (future)
        tooltip = {
            enabled = true,
            anchor = "CURSOR",
        },

        -- Visual style
        style = {
            theme = "lunar",  -- lunar, parchment, minimal
            font = "Fonts\\FRIZQT__.TTF",
            fontSize = 12,
            borderStyle = "ink",  -- ink, clean, none
        },
    },

    global = {
        version = nil,
    },

    char = {
        -- Character-specific settings
    },
}

--[[
    Initialize database
    Called from OnInitialize (in Init.lua)
]]
function LunarUI:InitDB()
    self.db = LibStub("AceDB-3.0"):New("LunarUIDB", defaults, "Default")

    -- Register callbacks for profile changes
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

    -- Store version
    self.db.global.version = self.version
end

--[[
    Profile changed callback
]]
function LunarUI:OnProfileChanged()
    -- Refresh all UI elements
    self:UpdateTokens()

    -- Notify modules to refresh
    self:NotifyPhaseChange(self:GetPhase(), self:GetPhase())

    self:Print("Profile changed, UI refreshed")
end

-- Initialize database on addon load
local function InitializeDB()
    if LunarUI.InitDB then
        LunarUI:InitDB()
    end
end

-- Hook into OnInitialize
hooksecurefunc(LunarUI, "OnInitialize", InitializeDB)
