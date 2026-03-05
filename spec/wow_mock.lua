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
_G.strsplit = function(delimiter, str)
    if not str then
        return nil
    end
    local result = {}
    local from = 1
    local delimLen = #delimiter
    while true do
        local pos = str:find(delimiter, from, true) -- plain find
        if not pos then
            result[#result + 1] = str:sub(from)
            break
        end
        result[#result + 1] = str:sub(from, pos - 1)
        from = pos + delimLen
    end
    return unpack(result)
end

-- debugstack: WoW debug function (stub)
_G.debugstack = function()
    return "(mock stack)"
end

-- print override to suppress output during tests (optional)
-- _G.print = function() end
