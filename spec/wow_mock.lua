--[[
    WoW API Mock Environment for busted tests
    Provides minimal mocks for WoW global functions used by LunarUI pure logic modules
]]

-- Lua 5.1/5.4 compatibility
local unpack = table.unpack or unpack -- luacheck: ignore 143

-- Math aliases (WoW exposes these as globals)
_G.format = string.format
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
