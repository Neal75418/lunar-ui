--[[
    LunarUI - 自訂 oUF Text Tags
    在 oUF 內建 tag 之上擴展格式化 tag，供單位框架文字使用

    使用方式：frame:Tag(fontString, "[lunar:health] [lunar:name:abbrev]")
    oUF 會自動根據 Events 表監聽事件並更新文字
]]

---@diagnostic disable: undefined-field
local _, Engine = ...
local LunarUI = Engine.LunarUI

-- oUF 透過 TOC X-oUF 欄位注入 LunarUF，或 fallback 到 oUF 全域
-- undefined-field disable：Engine 為動態 table，無型別定義；LunarUF/oUF 為
-- TOC runtime 注入的全域，沒有 stub 能宣告這些欄位存在於 _G
local oUF = Engine.oUF or LunarUF or _G.oUF
if not oUF then
    return
end

--------------------------------------------------------------------------------
-- WoW API upvalue（避免重複 global lookup，符合 CLAUDE.md 效能規範）
--------------------------------------------------------------------------------

local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
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
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitIsUnit = UnitIsUnit
local GetMaxLevelForLatestExpansion = GetMaxLevelForLatestExpansion
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local strlenutf8 = strlenutf8
local stringUtf8sub = string.utf8sub

local mathFloor = math.floor
local format = string.format
local tostring = tostring

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

-- 數值縮寫格式化（12345 → "12.3K"、1234567 → "1.5M"）
-- 精度與 Utils.FormatValue 保持一致
local function ShortValue(value)
    if not value then
        return ""
    end
    if value >= 1e6 then
        return format("%.1fM", value / 1e6)
    elseif value >= 1e3 then
        return format("%.1fK", value / 1e3)
    end
    return tostring(value)
end

-- 名稱縮寫（"Arthas Menethil" → "Arthas M."）
local function AbbreviateName(name)
    if not name then
        return ""
    end
    -- 保留第一個單詞，後續單詞縮寫為首字母
    return name:gsub(" (%S)%S+", " %1.")
end

--------------------------------------------------------------------------------
-- 註冊自訂 Tags
--------------------------------------------------------------------------------

local Tags = oUF.Tags
if not Tags or not Tags.Methods or not Tags.Events then
    return
end

-- 安全包裝 tag 函數，避免 WoW API 呼叫失敗導致 oUF 崩潰
local function SafeTag(func)
    return function(...)
        local ok, result = pcall(func, ...)
        if ok then
            return result
        end
        -- 靜默失敗，返回空字串而非 nil（避免 oUF 內部錯誤）
        return ""
    end
end

-- 單位不可用狀態文字（死亡/鬼魂/離線），回傳 nil 表示單位正常
local function UnitStatusText(unit)
    if UnitIsDead(unit) then
        return "|cffcc3333Dead|r"
    end
    if UnitIsGhost(unit) then
        return "|cffcc3333Ghost|r"
    end
    if not UnitIsConnected(unit) then
        return "|cff999999Offline|r"
    end
end

-- [lunar:health] — 格式化當前血量（12.3K / 1.23M）
Tags.Methods["lunar:health"] = SafeTag(function(unit)
    local status = UnitStatusText(unit)
    if status then
        return status
    end
    return ShortValue(UnitHealth(unit) or 0)
end)
Tags.Events["lunar:health"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- [lunar:health:percent] — 血量百分比
Tags.Methods["lunar:health:percent"] = SafeTag(function(unit)
    local status = UnitStatusText(unit)
    if status then
        return status
    end
    local hp, maxHp = UnitHealth(unit), UnitHealthMax(unit)
    local pct = maxHp > 0 and mathFloor(hp / maxHp * 100 + 0.5) or 0
    return format("%d%%", pct)
end)
Tags.Events["lunar:health:percent"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- [lunar:health:current-max] — "12.3K / 45.6K" 格式
Tags.Methods["lunar:health:current-max"] = SafeTag(function(unit)
    local status = UnitStatusText(unit)
    if status then
        return status
    end
    -- H7 效能修復：改用 format 一次性建立結果字串，避免兩個中間 string 物件
    return format("%s / %s", ShortValue(UnitHealth(unit) or 0), ShortValue(UnitHealthMax(unit) or 0))
end)
Tags.Events["lunar:health:current-max"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- [lunar:health:deficit] — 血量不足（僅在非滿血時顯示）
Tags.Methods["lunar:health:deficit"] = SafeTag(function(unit)
    if UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) then
        return ""
    end
    local cur = UnitHealth(unit) or 0
    local max = UnitHealthMax(unit) or 0
    local deficit = max - cur
    if deficit <= 0 then
        return ""
    end
    return "-" .. ShortValue(deficit)
end)
Tags.Events["lunar:health:deficit"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- [lunar:power] — 格式化當前能量
Tags.Methods["lunar:power"] = SafeTag(function(unit)
    local max = UnitPowerMax(unit) or 0
    if max == 0 then
        return ""
    end
    local cur = UnitPower(unit) or 0
    return ShortValue(cur)
end)
Tags.Events["lunar:power"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER"

-- [lunar:power:percent] — 能量百分比
Tags.Methods["lunar:power:percent"] = SafeTag(function(unit)
    local max = UnitPowerMax(unit) or 0
    if max == 0 then
        return ""
    end
    local cur = UnitPower(unit) or 0
    return format("%d%%", mathFloor(cur / max * 100 + 0.5))
end)
Tags.Events["lunar:power:percent"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER"

-- [lunar:name:abbrev] — 縮寫名稱（"Arthas M."）
Tags.Methods["lunar:name:abbrev"] = SafeTag(function(unit, realUnit)
    local name = UnitName(realUnit or unit)
    if not name then
        return ""
    end
    return AbbreviateName(name)
end)
Tags.Events["lunar:name:abbrev"] = "UNIT_NAME_UPDATE"

-- [lunar:name:medium] — 中等長度名稱（截斷至 15 字元，UTF-8 安全）
Tags.Methods["lunar:name:medium"] = SafeTag(function(unit, realUnit)
    local name = UnitName(realUnit or unit)
    if not name then
        return ""
    end
    local len = strlenutf8 and strlenutf8(name) or #name
    if len > 15 then
        if stringUtf8sub then
            return stringUtf8sub(name, 1, 12) .. "..."
        end
        return name:sub(1, 12) .. "..."
    end
    return name
end)
Tags.Events["lunar:name:medium"] = "UNIT_NAME_UPDATE"

-- [lunar:level:smart] — 智慧等級（滿級時隱藏）
Tags.Methods["lunar:level:smart"] = SafeTag(function(unit)
    local level = UnitEffectiveLevel(unit)
    if level <= 0 then
        return "??"
    end
    local maxLevel = GetMaxLevelForLatestExpansion and GetMaxLevelForLatestExpansion() or 80
    if UnitIsPlayer(unit) and level >= maxLevel then
        return ""
    end
    return tostring(level)
end)
Tags.Events["lunar:level:smart"] = "UNIT_LEVEL PLAYER_LEVEL_UP"

-- [lunar:class] — 職業名稱（本地化）
Tags.Methods["lunar:class"] = SafeTag(function(unit)
    if not UnitIsPlayer(unit) then
        return ""
    end
    local class = UnitClass(unit)
    return class or ""
end)
Tags.Events["lunar:class"] = "UNIT_NAME_UPDATE"

-- [lunar:class:color] — 職業色彩前綴（用於著色後續文字）
Tags.Methods["lunar:class:color"] = SafeTag(function(unit)
    if not UnitIsPlayer(unit) then
        return ""
    end
    local _, class = UnitClass(unit)
    if not class then
        return ""
    end
    local color = RAID_CLASS_COLORS[class]
    if not color then
        return ""
    end
    return format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
end)
Tags.Events["lunar:class:color"] = "UNIT_NAME_UPDATE"

-- [lunar:status] — 狀態文字（死亡/鬼魂/離線/暫離）
Tags.Methods["lunar:status"] = SafeTag(function(unit)
    local status = UnitStatusText(unit)
    if status then
        return status
    end
    if UnitIsAFK(unit) then
        return "|cff999999AFK|r"
    end
    return ""
end)
Tags.Events["lunar:status"] = "UNIT_HEALTH UNIT_CONNECTION PLAYER_FLAGS_CHANGED"
-- PLAYER_FLAGS_CHANGED 可能不帶 unit 參數，需註冊為 SharedEvent
if Tags.SharedEvents then
    Tags.SharedEvents["PLAYER_FLAGS_CHANGED"] = true
end

-- [lunar:role] — 職責圖示文字（T/H/D）
Tags.Methods["lunar:role"] = SafeTag(function(unit)
    local role = UnitGroupRolesAssigned(unit)
    if role == "TANK" then
        return "|cff5555ffT|r"
    end
    if role == "HEALER" then
        return "|cff55ff55H|r"
    end
    if role == "DAMAGER" then
        return "|cffff5555D|r"
    end
    return ""
end)
Tags.Events["lunar:role"] = "GROUP_ROSTER_UPDATE"

-- [lunar:group] — 團隊組別編號
-- B6 效能修復：快取 raidIndex → group 映射，避免 40 人 raid 中 O(N²) GetRaidRosterInfo 呼叫
-- 保留 UnitIsUnit 掃描（跨 token 匹配必要），但 GetRaidRosterInfo 只在 dirty 時執行一次
-- GROUP_ROSTER_UPDATE：第一個 tag 呼叫觸發重建（O(N)），後續 39 個 frame 掃描已快取的 index→group
-- #10: 同時建立 raidToken → group 映射，標準 "raid1"~"raid40" token 可直接 O(1) 查詢
local raidIndexToGroup = {}
local raidTokenToGroup = {} -- #10: "raid1"~"raid40" O(1) 快取
local groupCacheDirty = true
if CreateFrame then
    local groupTagFrame = CreateFrame("Frame")
    groupTagFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    groupTagFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    groupTagFrame:SetScript("OnEvent", function()
        groupCacheDirty = true
    end)
end

Tags.Methods["lunar:group"] = SafeTag(function(unit)
    if not IsInRaid() then
        return ""
    end
    if groupCacheDirty then
        groupCacheDirty = false
        wipe(raidIndexToGroup)
        wipe(raidTokenToGroup) -- #10
        for i = 1, GetNumGroupMembers() do
            local _, _, group = GetRaidRosterInfo(i)
            raidIndexToGroup[i] = group
            raidTokenToGroup["raid" .. i] = group -- #10: O(1) 直接查詢
        end
    end
    -- #10: 標準 raid token 直接查表（O(1)），避免 UnitIsUnit 掃描
    local direct = raidTokenToGroup[unit]
    if direct then
        return tostring(direct)
    end
    -- fallback：非標準 token（如跨隊伍匹配）仍走 UnitIsUnit O(N) 掃描
    for i = 1, GetNumGroupMembers() do
        if UnitIsUnit(unit, "raid" .. i) then
            return tostring(raidIndexToGroup[i] or "")
        end
    end
    return ""
end)
Tags.Events["lunar:group"] = "GROUP_ROSTER_UPDATE"

-- 匯出輔助函數供其他模組使用
LunarUI.ShortValue = ShortValue
LunarUI.AbbreviateName = AbbreviateName
LunarUI.UnitStatusText = UnitStatusText
LunarUI.TagMethods = Tags.Methods
