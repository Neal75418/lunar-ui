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

        -- Nameplates settings
        nameplates = {
            enabled = false,  -- Use Blizzard default nameplates
            width = 120,
            height = 8,
            -- Enemy nameplates
            enemy = {
                enabled = true,
                showHealth = true,
                showCastbar = true,
                showAuras = true,
                auraSize = 18,
                maxAuras = 5,
            },
            -- Friendly nameplates
            friendly = {
                enabled = true,
                showHealth = true,
                showCastbar = false,
                showAuras = false,
            },
            -- Threat colors
            threat = {
                enabled = true,
            },
            -- Important target highlighting
            highlight = {
                rare = true,
                elite = true,
                boss = true,
            },
            -- Classification icons
            classification = {
                enabled = true,
            },
        },

        -- ActionBars settings (future)
        actionbars = {
            enabled = false,  -- Use Blizzard default action bars
            bar1 = { enabled = true, buttons = 12, buttonSize = 36 },
            bar2 = { enabled = true, buttons = 12, buttonSize = 36 },
            bar3 = { enabled = false, buttons = 12, buttonSize = 36 },
            bar4 = { enabled = false, buttons = 12, buttonSize = 36 },
            bar5 = { enabled = false, buttons = 12, buttonSize = 36 },
            petbar = { enabled = true },
            stancebar = { enabled = true },
        },

        -- Minimap settings
        minimap = {
            enabled = true,
            size = 180,
            showCoords = true,
            showClock = true,
            organizeButtons = true,
        },

        -- Bags settings
        bags = {
            enabled = true,
            slotsPerRow = 12,
            slotSize = 37,
            autoSellJunk = true,
            showItemLevel = true,
            showQuestItems = true,
        },

        -- Chat settings
        chat = {
            enabled = true,
            width = 400,
            height = 180,
            improvedColors = true,
            classColors = true,
            fadeTime = 120,
            detectURLs = true,  -- Fix #76: Enable clickable URLs
        },

        -- Tooltip settings
        tooltip = {
            enabled = true,
            anchorCursor = false,
            showItemLevel = true,
            showItemID = false,
            showSpellID = false,
            showTargetTarget = true,
        },

        -- Visual style
        style = {
            theme = "lunar",  -- lunar, parchment, minimal
            font = "Fonts\\FRIZQT__.TTF",
            fontSize = 12,
            borderStyle = "ink",  -- ink, clean, none
            moonlightOverlay = false,  -- Subtle screen overlay during FULL phase
            phaseGlow = true,  -- Glow effects on frames during combat
            animations = true,  -- Enable phase transition animations
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

    -- Register callbacks for profile changes (Fix #1: correct Ace3 callback syntax)
    self.db:RegisterCallback("OnProfileChanged", function()
        self:OnProfileChanged()
    end)
    self.db:RegisterCallback("OnProfileCopied", function()
        self:OnProfileChanged()
    end)
    self.db:RegisterCallback("OnProfileReset", function()
        self:OnProfileChanged()
    end)

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

-- Note: InitDB is now called directly from Init.lua OnInitialize (Fix #2)

--------------------------------------------------------------------------------
-- Settings Import/Export (Fix #45)
--------------------------------------------------------------------------------

-- Simple table serialization (no external dependencies)
local function SerializeValue(val, depth)
    depth = depth or 0
    if depth > 20 then return "nil" end  -- Prevent infinite recursion

    local valType = type(val)
    if valType == "nil" then
        return "nil"
    elseif valType == "boolean" then
        return val and "true" or "false"
    elseif valType == "number" then
        return tostring(val)
    elseif valType == "string" then
        -- Escape special characters
        return string.format("%q", val)
    elseif valType == "table" then
        local parts = {}
        local isArray = #val > 0
        for k, v in pairs(val) do
            local keyStr
            if type(k) == "string" then
                keyStr = string.format("[%q]=", k)
            else
                keyStr = string.format("[%s]=", tostring(k))
            end
            table.insert(parts, keyStr .. SerializeValue(v, depth + 1))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "nil"
    end
end

-- Fix #94: Safe table deserializer without loadstring (prevents code injection)
-- This is a simple recursive descent parser for Lua table literals
local function DeserializeString(str)
    if not str or str == "" then
        return nil, "Empty string"
    end

    local pos = 1
    local len = #str

    -- Helper: skip whitespace
    local function skipWhitespace()
        while pos <= len and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end

    -- Helper: parse a string literal
    local function parseString()
        local quote = str:sub(pos, pos)
        if quote ~= '"' and quote ~= "'" then
            return nil, "Expected string"
        end
        pos = pos + 1
        local startPos = pos
        local result = ""

        while pos <= len do
            local c = str:sub(pos, pos)
            if c == "\\" and pos < len then
                -- Handle escape sequences
                local next = str:sub(pos + 1, pos + 1)
                if next == "n" then result = result .. "\n"
                elseif next == "t" then result = result .. "\t"
                elseif next == "r" then result = result .. "\r"
                elseif next == "\\" then result = result .. "\\"
                elseif next == '"' then result = result .. '"'
                elseif next == "'" then result = result .. "'"
                else result = result .. next
                end
                pos = pos + 2
            elseif c == quote then
                pos = pos + 1
                return result
            else
                result = result .. c
                pos = pos + 1
            end
        end
        return nil, "Unterminated string"
    end

    -- Helper: parse a number
    local function parseNumber()
        local startPos = pos
        if str:sub(pos, pos) == "-" then
            pos = pos + 1
        end
        while pos <= len and str:sub(pos, pos):match("[%d%.eE%+%-]") do
            pos = pos + 1
        end
        local numStr = str:sub(startPos, pos - 1)
        local num = tonumber(numStr)
        if num then
            return num
        end
        return nil, "Invalid number: " .. numStr
    end

    -- Forward declaration for mutual recursion
    local parseValue

    -- Helper: parse a table
    local function parseTable()
        if str:sub(pos, pos) ~= "{" then
            return nil, "Expected table"
        end
        pos = pos + 1
        skipWhitespace()

        local result = {}

        while pos <= len do
            skipWhitespace()
            local c = str:sub(pos, pos)

            if c == "}" then
                pos = pos + 1
                return result
            end

            -- Parse key
            local key
            if c == "[" then
                pos = pos + 1
                skipWhitespace()
                local keyVal, err = parseValue()
                if err then return nil, err end
                key = keyVal
                skipWhitespace()
                if str:sub(pos, pos) ~= "]" then
                    return nil, "Expected ']'"
                end
                pos = pos + 1
                skipWhitespace()
                if str:sub(pos, pos) ~= "=" then
                    return nil, "Expected '='"
                end
                pos = pos + 1
            elseif c:match("[%a_]") then
                -- Bare identifier key
                local startPos = pos
                while pos <= len and str:sub(pos, pos):match("[%w_]") do
                    pos = pos + 1
                end
                key = str:sub(startPos, pos - 1)
                skipWhitespace()
                if str:sub(pos, pos) ~= "=" then
                    return nil, "Expected '='"
                end
                pos = pos + 1
            else
                return nil, "Invalid table key at position " .. pos
            end

            -- Parse value
            skipWhitespace()
            local value, err = parseValue()
            if err then return nil, err end
            result[key] = value

            skipWhitespace()
            c = str:sub(pos, pos)
            if c == "," then
                pos = pos + 1
            elseif c ~= "}" then
                return nil, "Expected ',' or '}'"
            end
        end

        return nil, "Unterminated table"
    end

    -- Main value parser
    parseValue = function()
        skipWhitespace()
        if pos > len then
            return nil, "Unexpected end of input"
        end

        local c = str:sub(pos, pos)

        -- String
        if c == '"' or c == "'" then
            return parseString()
        end

        -- Table
        if c == "{" then
            return parseTable()
        end

        -- Number (including negative)
        if c:match("[%d%-]") then
            return parseNumber()
        end

        -- Boolean/nil keywords
        if str:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        end
        if str:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end
        if str:sub(pos, pos + 2) == "nil" then
            pos = pos + 3
            return nil
        end

        return nil, "Unexpected character: " .. c
    end

    -- Parse the input
    local result, err = parseValue()
    if err then
        return nil, err
    end

    skipWhitespace()
    if pos <= len then
        return nil, "Unexpected data after value"
    end

    return result
end

--[[
    Export current profile to a string
    @return string - Serialized profile string
]]
function LunarUI:ExportSettings()
    if not self.db or not self.db.profile then
        return nil, "Database not initialized"
    end

    -- Create a copy of the profile (excluding functions and userdata)
    local exportData = {
        version = self.version,
        profile = {}
    }

    -- Copy all profile settings
    for k, v in pairs(self.db.profile) do
        if type(v) ~= "function" and type(v) ~= "userdata" then
            exportData.profile[k] = v
        end
    end

    -- Serialize to string
    local serialized = SerializeValue(exportData)

    -- Add header for identification
    local header = "LUNARUI"
    local exportString = header .. serialized

    return exportString
end

--[[
    Import settings from a string
    @param importString string - The exported settings string
    @return boolean, string - Success status and message
]]
function LunarUI:ImportSettings(importString)
    if not importString or importString == "" then
        return false, "No import string provided"
    end

    -- Check header
    local header = "LUNARUI"
    if not importString:find("^" .. header) then
        return false, "Invalid import string (missing header)"
    end

    -- Remove header
    local dataString = importString:sub(#header + 1)

    -- Deserialize
    local data, err = DeserializeString(dataString)
    if not data then
        return false, "Failed to parse: " .. (err or "unknown error")
    end

    -- Validate structure
    if type(data) ~= "table" or not data.profile then
        return false, "Invalid data structure"
    end

    -- Apply imported settings
    if not self.db or not self.db.profile then
        return false, "Database not initialized"
    end

    -- Merge imported profile with current profile
    local function MergeTable(target, source)
        for k, v in pairs(source) do
            if type(v) == "table" and type(target[k]) == "table" then
                MergeTable(target[k], v)
            else
                target[k] = v
            end
        end
    end

    MergeTable(self.db.profile, data.profile)

    -- Trigger profile change to refresh UI
    self:OnProfileChanged()

    return true, "Settings imported successfully (version: " .. (data.version or "unknown") .. ")"
end

--[[
    Copy export string to clipboard (via EditBox)
]]
function LunarUI:ShowExportFrame()
    local exportString, err = self:ExportSettings()
    if not exportString then
        self:Print("Export failed: " .. (err or "unknown"))
        return
    end

    -- Create or show export frame
    if not self.exportFrame then
        local frame = CreateFrame("Frame", "LunarUI_ExportFrame", UIParent, "BackdropTemplate")
        frame:SetSize(500, 200)
        frame:SetPoint("CENTER")
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        frame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY")
        title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -10)
        title:SetText("|cff8882ffLunarUI|r Export Settings")

        -- Close button
        local closeBtn = CreateFrame("Button", nil, frame)
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetNormalFontObject(GameFontNormal)
        closeBtn:SetText("×")
        closeBtn:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        -- Scroll frame
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -35)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

        -- Edit box
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFont(STANDARD_TEXT_FONT, 11, "")
        editBox:SetWidth(scrollFrame:GetWidth())
        editBox:SetAutoFocus(false)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox

        -- Instructions
        local instructions = frame:CreateFontString(nil, "OVERLAY")
        instructions:SetFont(STANDARD_TEXT_FONT, 10, "")
        instructions:SetPoint("BOTTOM", 0, 10)
        instructions:SetText("Ctrl+A to select all, Ctrl+C to copy")
        instructions:SetTextColor(0.6, 0.6, 0.6)

        self.exportFrame = frame
    end

    self.exportFrame.editBox:SetText(exportString)
    self.exportFrame.editBox:HighlightText()
    self.exportFrame.editBox:SetFocus()
    self.exportFrame:Show()
end

--[[
    Show import frame
]]
function LunarUI:ShowImportFrame()
    -- Create or show import frame
    if not self.importFrame then
        local frame = CreateFrame("Frame", "LunarUI_ImportFrame", UIParent, "BackdropTemplate")
        frame:SetSize(500, 200)
        frame:SetPoint("CENTER")
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        frame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY")
        title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -10)
        title:SetText("|cff8882ffLunarUI|r Import Settings")

        -- Close button
        local closeBtn = CreateFrame("Button", nil, frame)
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetNormalFontObject(GameFontNormal)
        closeBtn:SetText("×")
        closeBtn:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        -- Scroll frame
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -35)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 70)

        -- Edit box
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFont(STANDARD_TEXT_FONT, 11, "")
        editBox:SetWidth(scrollFrame:GetWidth())
        editBox:SetAutoFocus(false)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox

        -- Import button
        local importBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        importBtn:SetSize(100, 25)
        importBtn:SetPoint("BOTTOM", 0, 10)
        importBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        importBtn:SetBackdropColor(0.2, 0.4, 0.2, 1)
        importBtn:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)

        local btnText = importBtn:CreateFontString(nil, "OVERLAY")
        btnText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        btnText:SetPoint("CENTER")
        btnText:SetText("Import")

        importBtn:SetScript("OnClick", function()
            local importString = frame.editBox:GetText()
            local success, msg = LunarUI:ImportSettings(importString)
            if success then
                LunarUI:Print("|cff00ff00" .. msg .. "|r")
                frame:Hide()
            else
                LunarUI:Print("|cffff0000" .. msg .. "|r")
            end
        end)

        importBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.5, 0.3, 1)
        end)
        importBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.4, 0.2, 1)
        end)

        -- Instructions
        local instructions = frame:CreateFontString(nil, "OVERLAY")
        instructions:SetFont(STANDARD_TEXT_FONT, 10, "")
        instructions:SetPoint("BOTTOM", 0, 40)
        instructions:SetText("Paste exported string and click Import")
        instructions:SetTextColor(0.6, 0.6, 0.6)

        self.importFrame = frame
    end

    self.importFrame.editBox:SetText("")
    self.importFrame.editBox:SetFocus()
    self.importFrame:Show()
end
