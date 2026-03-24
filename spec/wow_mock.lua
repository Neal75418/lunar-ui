---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    WoW API Mock Environment for busted tests
    Provides minimal mocks for WoW global functions used by LunarUI pure logic modules
]]

-- Lua 5.1/5.4 compatibility
local unpack = table.unpack or unpack -- luacheck: ignore 143
_G.unpack = unpack

-- Lua 5.3+ string.format compatibility: %d/%x/%o require integer arguments
-- WoW uses Lua 5.1 where floats are silently truncated; replicate that behavior
local _origFormat = string.format
local function wowFormat(fmt, ...) -- luacheck: ignore 211
    if type(fmt) ~= "string" then
        return _origFormat(fmt, ...)
    end
    local args = { ... }
    local n = select("#", ...)
    local i = 0
    -- Count format specifiers in order, floor numeric args for integer-type specs
    fmt:gsub("%%[-+ #0]*%d*%.?%d*([diouxXcsqeEfgGaAp%%])", function(spec)
        if spec == "%" then
            return
        end
        i = i + 1
        if i <= n and type(args[i]) == "number" and spec:match("[diouxX]") then
            args[i] = math.floor(args[i])
        end
    end)
    return _origFormat(fmt, unpack(args, 1, n))
end

-- Math aliases (WoW exposes these as globals)
_G.format = wowFormat
string.format = wowFormat -- luacheck: ignore 122 -- override so both format() and (""):format() work
_G.floor = math.floor
_G.ceil = math.ceil
_G.abs = math.abs
_G.min = math.min
_G.max = math.max
_G.random = math.random

-- Table utilities
_G.wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end
_G.tinsert = table.insert
_G.tremove = table.remove

-- strsplit: WoW-specific string splitting function
-- WoW signature: strsplit(delimiter, str) -> ...
-- WoW treats delimiter as a **set of separator characters**, not a literal sequence
-- e.g. strsplit("-+", "a-b+c") returns "a", "b", "c"
_G.strsplit = function(delimiter, str)
    if not str then
        return nil
    end
    local result = {}
    -- Escape Lua pattern magic characters inside [], keeping set-of-chars semantics
    local pattern = "[" .. delimiter:gsub("([%]%^%-%%])", "%%%1") .. "]"
    local from = 1
    while true do
        local pos = str:find(pattern, from)
        if not pos then
            result[#result + 1] = str:sub(from)
            break
        end
        result[#result + 1] = str:sub(from, pos - 1)
        from = pos + 1
    end
    return unpack(result)
end

-- strtrim: WoW-specific whitespace trimming function
_G.strtrim = function(s)
    if type(s) ~= "string" then
        return s
    end
    return s:match("^%s*(.-)%s*$")
end

-- debugstack: WoW debug function (stub)
_G.debugstack = function()
    return "(mock stack)"
end

-- DebuffTypeColor: WoW debuff type color table
_G.DebuffTypeColor = {
    Magic = { r = 0.20, g = 0.60, b = 1.00 },
    Curse = { r = 0.60, g = 0.00, b = 1.00 },
    Disease = { r = 0.60, g = 0.40, b = 0.00 },
    Poison = { r = 0.00, g = 0.60, b = 0.00 },
    none = { r = 0.80, g = 0.00, b = 0.00 },
    [""] = { r = 0.80, g = 0.00, b = 0.00 },
}

-- C_UnitAuras: WoW 10.0+ unit aura API
_G.C_UnitAuras = {
    GetBuffDataByIndex = function(_unit, _index, _filter)
        return nil
    end,
    GetDebuffDataByIndex = function(_unit, _index, _filter)
        return nil
    end,
    CancelAuraByAuraInstanceID = function(_unit, _auraInstanceID)
        return false
    end,
}

-- Common WoW API stubs (centralized to avoid per-spec duplication)
-- Each spec can override these in before_each for custom behavior

_G.GetTime = function()
    return 1000
end

_G.InCombatLockdown = function()
    return _G._TEST_IN_COMBAT or false
end

_G.UnitClass = function()
    return "Warrior", "WARRIOR", 1
end

_G.UnitExists = function()
    return true
end

_G.UnitIsPlayer = function()
    return true
end

_G.UnitIsEnemy = function()
    return false
end

_G.UnitIsDeadOrGhost = function()
    return false
end

_G.UnitReaction = function()
    return 5 -- friendly
end

_G.IsPlayerSpell = function()
    return false
end

_G.IsShiftKeyDown = function()
    return false
end

_G.C_Timer = _G.C_Timer or { After = function() end }

_G.C_Spell = _G.C_Spell
    or {
        GetSpellCooldown = function()
            return { startTime = 0, duration = 0 }
        end,
        GetSpellInfo = function(spellID)
            return { iconID = 100000 + (spellID or 0) }
        end,
        IsSpellUsable = function()
            return false
        end,
    }

_G.C_Item = _G.C_Item
    or {
        GetItemInfo = function()
            return nil
        end,
        GetItemQualityByID = function()
            return nil
        end,
        GetItemQualityColor = function()
            return 1, 1, 1, 1
        end,
    }

_G.C_DateAndTime = _G.C_DateAndTime
    or {
        GetCurrentCalendarTime = function()
            return { hour = 12, minute = 0 }
        end,
    }

_G.RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
    or {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
        PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
        HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
        ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
        PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
        MAGE = { r = 0.41, g = 0.80, b = 0.94 },
        WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    }

_G.CreateColor = _G.CreateColor
    or function(r, g, b, a)
        return { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }
    end

_G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
_G.StaticPopup_Show = _G.StaticPopup_Show or function() end
_G.ReloadUI = _G.ReloadUI or function() end

-- print override to suppress output during tests (optional)
-- _G.print = function() end
