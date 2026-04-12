---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Addon File Loader for busted tests
    Simulates WoW's addon loading environment by providing
    the (_ADDON_NAME, Engine) varargs that WoW passes to each Lua file
]]

local M = {}

--- Load a LunarUI addon source file with mocked addon environment
--- @param filepath string - Relative path from project root (e.g., "LunarUI/Core/Utils.lua")
--- @param LunarUI table - The LunarUI addon table to populate
--- @param extraEngine? table - Additional Engine fields to inject
--- @return table Engine - The Engine table used during loading
function M.loadAddonFile(filepath, LunarUI, extraEngine)
    local Engine = { LunarUI = LunarUI }
    if extraEngine then
        for k, v in pairs(extraEngine) do
            Engine[k] = v
        end
    end

    local chunk, err = loadfile(filepath)
    if not chunk then
        error("Failed to load " .. filepath .. ": " .. tostring(err))
    end

    -- Simulate WoW's addon varargs: (_ADDON_NAME, Engine)
    chunk("LunarUI", Engine)

    return Engine
end

return M
