---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - 角色佈局預設
    根據天賦專精自動套用 UI 佈局
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 角色佈局預設
--------------------------------------------------------------------------------

-- 角色佈局預設值（從 Engine.GetLayoutPresets 取得共用資料，映射至 WoW API 角色名稱）
local function BuildRolePresets()
    local presets = Engine.GetLayoutPresets()
    return {
        DAMAGER = presets.dps,
        TANK = presets.tank,
        HEALER = presets.healer,
    }
end
local ROLE_PRESETS = BuildRolePresets()

--[[
    偵測目前天賦角色
    @return string "DAMAGER" / "TANK" / "HEALER"
]]
function LunarUI.GetCurrentRole()
    local specIndex = GetSpecialization()
    if specIndex then
        local ok, role = pcall(GetSpecializationRole, specIndex)
        return (ok and role) or "DAMAGER"
    end
    return "DAMAGER"
end

--[[
    套用角色佈局預設
    @param role string "DAMAGER" / "TANK" / "HEALER"（可選，預設自動偵測）
]]
function LunarUI:ApplyRolePreset(role)
    if InCombatLockdown() then
        return
    end
    role = role or LunarUI.GetCurrentRole()
    local preset = ROLE_PRESETS[role]
    if not preset or not self.db or not self.db.profile then
        return
    end

    -- 套用 unitframes 預設
    local ufDB = self.db.profile.unitframes
    if preset.unitframes and type(ufDB) == "table" then
        for unit, values in pairs(preset.unitframes) do
            if ufDB[unit] then
                for k, v in pairs(values) do
                    ufDB[unit][k] = v
                end
            end
        end
    end

    -- 套用 nameplates 預設
    local npDB = self.db.profile.nameplates
    if preset.nameplates and type(npDB) == "table" then
        for k, v in pairs(preset.nameplates) do
            npDB[k] = v
        end
    end
end
