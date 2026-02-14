---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, undefined-global
--[[
    LunarUI - 自訂 oUF Text Tags
    在 oUF 內建 tag 之上擴展格式化 tag，供單位框架文字使用

    使用方式：frame:Tag(fontString, "[lunar:health] [lunar:name:abbrev]")
    oUF 會自動根據 Events 表監聽事件並更新文字
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local oUF = Engine.oUF or _G.LunarUF or _G.oUF
if not oUF then return end

--------------------------------------------------------------------------------
-- WoW API upvalue（避免重複 global lookup，符合 CLAUDE.md 效能規範）
--------------------------------------------------------------------------------

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitIsConnected = UnitIsConnected
local UnitIsAFK = UnitIsAFK
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName
local UnitClass = UnitClass
local UnitEffectiveLevel = UnitEffectiveLevel
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitIsUnit = UnitIsUnit
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local GetMaxLevelForLatestExpansion = GetMaxLevelForLatestExpansion
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local strlenutf8 = strlenutf8
local string_utf8sub = string.utf8sub

local format = string.format
local tostring = tostring

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

-- 數值縮寫格式化（12345 → "12.3K"、1234567 → "1.23M"）
local function ShortValue(value)
    if not value then return "" end
    if value >= 1e6 then
        return format("%.2fM", value / 1e6)
    elseif value >= 1e3 then
        return format("%.1fK", value / 1e3)
    end
    return tostring(value)
end

-- 名稱縮寫（"Arthas Menethil" → "Arthas M."）
local function AbbreviateName(name)
    if not name then return "" end
    -- 保留第一個單詞，後續單詞縮寫為首字母
    return name:gsub(" (%S)%S+", " %1.")
end

--------------------------------------------------------------------------------
-- 註冊自訂 Tags
--------------------------------------------------------------------------------

local Tags = oUF.Tags
if not Tags or not Tags.Methods or not Tags.Events then return end

-- [lunar:health] — 格式化當前血量（12.3K / 1.23M）
Tags.Methods["lunar:health"] = function(unit)
    if UnitIsDead(unit) then return "|cffcc3333Dead|r" end
    if UnitIsGhost(unit) then return "|cffcc3333Ghost|r" end
    if not UnitIsConnected(unit) then return "|cff999999Offline|r" end
    local cur = UnitHealth(unit) or 0
    return ShortValue(cur)
end
Tags.Events["lunar:health"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- [lunar:health:percent] — 血量百分比
Tags.Methods["lunar:health:percent"] = function(unit)
    if UnitIsDead(unit) then return "|cffcc3333Dead|r" end
    if UnitIsGhost(unit) then return "|cffcc3333Ghost|r" end
    if not UnitIsConnected(unit) then return "|cff999999Offline|r" end
    local pct = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    return format("%d%%", pct or 0)
end
Tags.Events["lunar:health:percent"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- [lunar:health:current-max] — "12.3K / 45.6K" 格式
Tags.Methods["lunar:health:current-max"] = function(unit)
    if UnitIsDead(unit) then return "|cffcc3333Dead|r" end
    if UnitIsGhost(unit) then return "|cffcc3333Ghost|r" end
    if not UnitIsConnected(unit) then return "|cff999999Offline|r" end
    local cur = UnitHealth(unit) or 0
    local max = UnitHealthMax(unit) or 0
    return ShortValue(cur) .. " / " .. ShortValue(max)
end
Tags.Events["lunar:health:current-max"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- [lunar:health:deficit] — 血量不足（僅在非滿血時顯示）
Tags.Methods["lunar:health:deficit"] = function(unit)
    if UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) then return "" end
    local cur = UnitHealth(unit) or 0
    local max = UnitHealthMax(unit) or 0
    local deficit = max - cur
    if deficit <= 0 then return "" end
    return "-" .. ShortValue(deficit)
end
Tags.Events["lunar:health:deficit"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- [lunar:power] — 格式化當前能量
Tags.Methods["lunar:power"] = function(unit)
    local max = UnitPowerMax(unit) or 0
    if max == 0 then return "" end
    local cur = UnitPower(unit) or 0
    return ShortValue(cur)
end
Tags.Events["lunar:power"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER"

-- [lunar:power:percent] — 能量百分比
Tags.Methods["lunar:power:percent"] = function(unit)
    local max = UnitPowerMax(unit) or 0
    if max == 0 then return "" end
    local cur = UnitPower(unit) or 0
    return format("%d%%", cur / max * 100)
end
Tags.Events["lunar:power:percent"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER"

-- [lunar:name:abbrev] — 縮寫名稱（"Arthas M."）
Tags.Methods["lunar:name:abbrev"] = function(unit, realUnit)
    local name = UnitName(realUnit or unit)
    if not name then return "" end
    return AbbreviateName(name)
end
Tags.Events["lunar:name:abbrev"] = "UNIT_NAME_UPDATE"

-- [lunar:name:medium] — 中等長度名稱（截斷至 15 字元，UTF-8 安全）
Tags.Methods["lunar:name:medium"] = function(unit, realUnit)
    local name = UnitName(realUnit or unit)
    if not name then return "" end
    local len = strlenutf8 and strlenutf8(name) or #name
    if len > 15 then
        if string_utf8sub then
            return string_utf8sub(name, 1, 14) .. "..."
        end
        return name:sub(1, 14) .. "..."
    end
    return name
end
Tags.Events["lunar:name:medium"] = "UNIT_NAME_UPDATE"

-- [lunar:level:smart] — 智慧等級（滿級時隱藏）
Tags.Methods["lunar:level:smart"] = function(unit)
    local level = UnitEffectiveLevel(unit)
    if level <= 0 then return "??" end
    local maxLevel = GetMaxLevelForLatestExpansion and GetMaxLevelForLatestExpansion() or 80
    if UnitIsPlayer(unit) and level >= maxLevel then return "" end
    return tostring(level)
end
Tags.Events["lunar:level:smart"] = "UNIT_LEVEL PLAYER_LEVEL_UP"

-- [lunar:class] — 職業名稱（本地化）
Tags.Methods["lunar:class"] = function(unit)
    if not UnitIsPlayer(unit) then return "" end
    local class = UnitClass(unit)
    return class or ""
end
Tags.Events["lunar:class"] = "UNIT_NAME_UPDATE"

-- [lunar:class:color] — 職業色彩前綴（用於著色後續文字）
Tags.Methods["lunar:class:color"] = function(unit)
    if not UnitIsPlayer(unit) then return "" end
    local _, class = UnitClass(unit)
    if not class then return "" end
    local color = RAID_CLASS_COLORS[class]
    if not color then return "" end
    return format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end
Tags.Events["lunar:class:color"] = "UNIT_NAME_UPDATE"

-- [lunar:status] — 狀態文字（死亡/鬼魂/離線/暫離）
Tags.Methods["lunar:status"] = function(unit)
    if UnitIsDead(unit) then return "|cffcc3333Dead|r" end
    if UnitIsGhost(unit) then return "|cffcc3333Ghost|r" end
    if not UnitIsConnected(unit) then return "|cff999999Offline|r" end
    if UnitIsAFK(unit) then return "|cff999999AFK|r" end
    return ""
end
Tags.Events["lunar:status"] = "UNIT_HEALTH UNIT_CONNECTION PLAYER_FLAGS_CHANGED"
-- PLAYER_FLAGS_CHANGED 可能不帶 unit 參數，需註冊為 SharedEvent
if Tags.SharedEvents then
    Tags.SharedEvents["PLAYER_FLAGS_CHANGED"] = true
end

-- [lunar:role] — 職責圖示文字（T/H/D）
Tags.Methods["lunar:role"] = function(unit)
    local role = UnitGroupRolesAssigned(unit)
    if role == "TANK" then return "|cff5555ffT|r" end
    if role == "HEALER" then return "|cff55ff55H|r" end
    if role == "DAMAGER" then return "|cffff5555D|r" end
    return ""
end
Tags.Events["lunar:role"] = "GROUP_ROSTER_UPDATE"

-- [lunar:group] — 團隊組別編號
Tags.Methods["lunar:group"] = function(unit)
    if not IsInRaid() then return "" end
    for i = 1, GetNumGroupMembers() do
        if UnitIsUnit(unit, "raid" .. i) then
            local _, _, group = GetRaidRosterInfo(i)
            return tostring(group or "")
        end
    end
    return ""
end
Tags.Events["lunar:group"] = "GROUP_ROSTER_UPDATE"

-- 匯出輔助函數供其他模組使用
LunarUI.ShortValue = ShortValue
LunarUI.AbbreviateName = AbbreviateName
