---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 單位框架指示器
    職業資源、替代能量、休息/戰鬥/死亡指示器、仇恨/距離指示器
    隊長/助理/團隊角色/職責/準備確認/召喚/復活指示器、分類標記
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- 效能：快取全域變數
local mathFloor = math.floor
local format = string.format

local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 職業資源（連擊點/聖能/符文等）
--------------------------------------------------------------------------------

local function CreateClassPower(frame)
    local ufAll = LunarUI.GetModuleDB("unitframes")
    local db = ufAll and ufAll.player
    if db and db.showClassPower == false then
        return
    end

    local GetStatusBarTexture = LunarUI.UFGetStatusBarTexture
    local oUF = Engine.oUF or _G.LunarUF or _G.oUF

    local MAX_POINTS = 10 -- 最多 10（盜賊可到 7+，術士 5 靈魂碎片等）
    local barWidth = frame:GetWidth()
    local barHeight = 6
    local spacing = 2

    local classPower = {}
    for i = 1, MAX_POINTS do
        local bar = CreateFrame("StatusBar", nil, frame)
        bar:SetStatusBarTexture(GetStatusBarTexture())
        bar:SetHeight(barHeight)

        -- 背景
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetTexture(GetStatusBarTexture())
        bar.bg:SetVertexColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])

        classPower[i] = bar
    end

    -- 佈局更新：根據實際點數重排寬度和位置
    -- #6: 快取 maxVisible/powerType，跳過無變化的 layout/color 操作（高頻：UNIT_POWER_FREQUENT）
    classPower.PostUpdate = function(element, _cur, _max, _hasMaxChanged, powerType)
        local maxVisible = 0
        for idx = 1, MAX_POINTS do
            if element[idx]:IsShown() then
                maxVisible = idx
            end
        end
        if maxVisible == 0 then
            return
        end

        -- 只在 maxVisible 改變時重算 layout（避免每幀 ClearAllPoints/SetPoint/SetSize）
        local prevMaxVisible = element._lastMaxVisible or 0
        if maxVisible ~= prevMaxVisible then
            element._lastMaxVisible = maxVisible
            if barWidth <= 0 then
                return
            end
            local singleWidth = (barWidth - (maxVisible - 1) * spacing) / maxVisible
            for idx = 1, maxVisible do
                element[idx]:ClearAllPoints()
                element[idx]:SetSize(singleWidth, barHeight)
                if idx == 1 then
                    element[idx]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
                else
                    element[idx]:SetPoint("LEFT", element[idx - 1], "RIGHT", spacing, 0)
                end
            end
        end

        -- 只在 powerType 改變或 maxVisible 增加時重新著色
        if powerType ~= element._lastPowerType or maxVisible > (element._lastColoredMax or 0) then
            element._lastPowerType = powerType
            element._lastColoredMax = maxVisible
            local colors = oUF and oUF.colors and oUF.colors.power
            if colors and powerType and colors[powerType] then
                local c = colors[powerType]
                for idx = 1, maxVisible do
                    element[idx]:SetStatusBarColor(c[1] or c.r, c[2] or c.g, c[3] or c.b)
                end
            end
        end
    end

    frame.ClassPower = classPower
    return classPower
end

--------------------------------------------------------------------------------
-- 替代能量條（BOSS 戰特殊資源）
--------------------------------------------------------------------------------

local function CreateAlternativePower(frame)
    local GetStatusBarTexture = LunarUI.UFGetStatusBarTexture

    local altPower = CreateFrame("StatusBar", nil, frame)
    altPower:SetStatusBarTexture(GetStatusBarTexture())
    altPower:SetSize(frame:GetWidth(), 6)
    altPower:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    altPower:SetStatusBarColor(0.20, 0.60, 1.0)

    altPower.bg = altPower:CreateTexture(nil, "BACKGROUND")
    altPower.bg:SetAllPoints()
    altPower.bg:SetTexture(GetStatusBarTexture())
    altPower.bg:SetVertexColor(0.05, 0.05, 0.10, 0.8)

    -- 數值文字
    altPower.text = altPower:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(altPower.text, 9, "OUTLINE")
    altPower.text:SetPoint("CENTER")

    altPower.PostUpdate = function(element, _unit, cur, _min, max)
        if element.text then
            if max and max > 0 then
                element.text:SetText(format("%d%%", mathFloor(cur / max * 100 + 0.5)))
            else
                element.text:SetText("")
            end
        end
    end

    frame.AlternativePower = altPower
    return altPower
end

--------------------------------------------------------------------------------
-- 休息指示器
--------------------------------------------------------------------------------

local function CreateRestingIndicator(frame)
    local resting = frame.Health:CreateTexture(nil, "OVERLAY")
    resting:SetSize(16, 16)
    resting:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
    resting:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    resting:SetTexCoord(0.09, 0.43, 0.08, 0.42)
    frame.RestingIndicator = resting
    return resting
end

--------------------------------------------------------------------------------
-- 戰鬥指示器
--------------------------------------------------------------------------------

local function CreateCombatIndicator(frame)
    local combat = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    combat:SetSize(24, 24)
    combat:SetPoint("CENTER", frame, "TOPRIGHT", 0, 0)
    combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    combat:SetTexCoord(0.58, 0.90, 0.08, 0.41)
    frame.CombatIndicator = combat
    return combat
end

--------------------------------------------------------------------------------
-- 分類（菁英/稀有）
--------------------------------------------------------------------------------

local function CreateClassification(frame)
    local class = frame.Health:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(class, 10, "OUTLINE")
    class:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, 10)
    class:SetTextColor(1, 0.82, 0)

    frame:Tag(class, "[classification]")
    frame.Classification = class
    return class
end

--------------------------------------------------------------------------------
-- 仇恨指示器
--------------------------------------------------------------------------------

local function CreateThreatIndicator(frame)
    local threat = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    threat:SetAllPoints()
    threat:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    threat:SetBackdropBorderColor(0, 0, 0, 0)
    threat:SetFrameLevel(frame:GetFrameLevel() + 5)

    threat.PostUpdate = function(self, _unit, status, r, g, b)
        if status and status > 0 then
            self:SetBackdropBorderColor(r, g, b, 0.8)
        else
            self:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end

    frame.ThreatIndicator = threat
    return threat
end

--------------------------------------------------------------------------------
-- 距離指示器（用於隊伍/團隊）
--------------------------------------------------------------------------------

local function CreateRangeIndicator(frame)
    frame.Range = {
        insideAlpha = 1,
        outsideAlpha = 0.4,
    }
    return frame.Range
end

--------------------------------------------------------------------------------
-- 隊長/助理指示器
--------------------------------------------------------------------------------

local function CreateLeaderIndicator(frame)
    local leader = frame.Health:CreateTexture(nil, "OVERLAY")
    leader:SetSize(12, 12)
    leader:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    frame.LeaderIndicator = leader
    return leader
end

local function CreateAssistantIndicator(frame)
    local assist = frame.Health:CreateTexture(nil, "OVERLAY")
    assist:SetSize(12, 12)
    -- 往右偏移 16px 避免與 LeaderIndicator (-4, 4) 重疊
    assist:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, 4)
    frame.AssistantIndicator = assist
    return assist
end

--------------------------------------------------------------------------------
-- 團隊角色指示器
--------------------------------------------------------------------------------

local function CreateRaidRoleIndicator(frame)
    local role = frame.Health:CreateTexture(nil, "OVERLAY")
    role:SetSize(12, 12)
    role:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
    frame.RaidRoleIndicator = role
    return role
end

--------------------------------------------------------------------------------
-- 職責指示器（坦克/治療/輸出）
--------------------------------------------------------------------------------

local function CreateGroupRoleIndicator(frame)
    local role = frame.Health:CreateTexture(nil, "OVERLAY")
    role:SetSize(14, 14)
    role:SetPoint("LEFT", frame.Health, "LEFT", 2, 0)
    frame.GroupRoleIndicator = role
    return role
end

--------------------------------------------------------------------------------
-- 準備確認指示器
--------------------------------------------------------------------------------

local function CreateReadyCheckIndicator(frame)
    local ready = frame:CreateTexture(nil, "OVERLAY")
    ready:SetSize(20, 20)
    ready:SetPoint("CENTER")
    frame.ReadyCheckIndicator = ready
    return ready
end

--------------------------------------------------------------------------------
-- 召喚指示器
--------------------------------------------------------------------------------

local function CreateSummonIndicator(frame)
    local summon = frame:CreateTexture(nil, "OVERLAY")
    summon:SetSize(24, 24)
    summon:SetPoint("CENTER")
    frame.SummonIndicator = summon
    return summon
end

--------------------------------------------------------------------------------
-- 復活指示器
--------------------------------------------------------------------------------

local function CreateResurrectIndicator(frame)
    local res = frame:CreateTexture(nil, "OVERLAY")
    res:SetSize(20, 20)
    res:SetPoint("CENTER")
    frame.ResurrectIndicator = res
    return res
end

--------------------------------------------------------------------------------
-- 死亡指示器
--------------------------------------------------------------------------------

-- 死亡指示器：純 UI 元素（骷髏圖示 + 灰色覆蓋）
-- oUF 無內建 DeadIndicator element，由 Health.PostUpdate 驅動顯示/隱藏
local function CreateDeathIndicator(frame, _unit)
    local dead = frame:CreateTexture(nil, "OVERLAY")
    dead:SetSize(20, 20)
    dead:SetPoint("CENTER", frame.Health, "CENTER")
    dead:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    dead:Hide()
    frame.DeadIndicator = dead

    local deadOverlay = frame.Health:CreateTexture(nil, "OVERLAY")
    deadOverlay:SetAllPoints(frame.Health)
    deadOverlay:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    deadOverlay:Hide()
    frame.DeadOverlay = deadOverlay

    return dead
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.UFCreateClassPower = CreateClassPower
LunarUI.UFCreateAlternativePower = CreateAlternativePower
LunarUI.UFCreateRestingIndicator = CreateRestingIndicator
LunarUI.UFCreateCombatIndicator = CreateCombatIndicator
LunarUI.UFCreateClassification = CreateClassification
LunarUI.UFCreateThreatIndicator = CreateThreatIndicator
LunarUI.UFCreateRangeIndicator = CreateRangeIndicator
LunarUI.UFCreateLeaderIndicator = CreateLeaderIndicator
LunarUI.UFCreateAssistantIndicator = CreateAssistantIndicator
LunarUI.UFCreateRaidRoleIndicator = CreateRaidRoleIndicator
LunarUI.UFCreateGroupRoleIndicator = CreateGroupRoleIndicator
LunarUI.UFCreateReadyCheckIndicator = CreateReadyCheckIndicator
LunarUI.UFCreateSummonIndicator = CreateSummonIndicator
LunarUI.UFCreateResurrectIndicator = CreateResurrectIndicator
LunarUI.UFCreateDeathIndicator = CreateDeathIndicator
