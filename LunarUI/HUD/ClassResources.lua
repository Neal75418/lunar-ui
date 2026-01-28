---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
--[[
    LunarUI - 職業資源條
    顯示職業特定資源（連擊點、符文、碎片等）

    支援職業：
    - 盜賊/德魯伊/武僧：連擊點
    - 死亡騎士：符文
    - 術士：靈魂碎片
    - 法師：秘法充能
    - 牧師（暗影）：瘋狂值
    - 聖騎士：聖能
    - 惡魔獵人：魔怒/痛苦
    - 喚魔師：精華
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 效能：快取全域變數
--------------------------------------------------------------------------------

local math_floor = math.floor
local ipairs = ipairs
local UnitClass = UnitClass
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local GetSpecialization = GetSpecialization
local GetRuneCooldown = GetRuneCooldown

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 職業 ID
local CLASS_ROGUE = 4
local CLASS_DRUID = 11
local CLASS_MONK = 10
local CLASS_DEATHKNIGHT = 6
local CLASS_WARLOCK = 9
local CLASS_MAGE = 8
local CLASS_PRIEST = 5
local CLASS_PALADIN = 2
local CLASS_DEMONHUNTER = 12
local CLASS_EVOKER = 13

-- 能量類型
local POWER_TYPE_COMBO_POINTS = Enum.PowerType.ComboPoints or 4
local POWER_TYPE_RUNES = Enum.PowerType.Runes or 5
local POWER_TYPE_SOUL_SHARDS = Enum.PowerType.SoulShards or 7
local POWER_TYPE_ARCANE_CHARGES = Enum.PowerType.ArcaneCharges or 16
local POWER_TYPE_INSANITY = Enum.PowerType.Insanity or 13
local POWER_TYPE_HOLY_POWER = Enum.PowerType.HolyPower or 9
local POWER_TYPE_FURY = Enum.PowerType.Fury or 17
local POWER_TYPE_PAIN = Enum.PowerType.Pain or 18
local POWER_TYPE_ESSENCE = Enum.PowerType.Essence or 19

-- 資源顏色
local RESOURCE_COLORS = {
    comboPoints = { 0.9, 0.7, 0.2 },      -- 金色
    runes = { 0.6, 0.2, 0.2 },            -- 深紅
    runeReady = { 0.8, 0.1, 0.1 },        -- 亮紅
    soulShards = { 0.6, 0.3, 0.8 },       -- 紫色
    arcaneCharges = { 0.3, 0.6, 0.9 },    -- 藍色
    insanity = { 0.6, 0.2, 0.8 },         -- 暗紫
    holyPower = { 0.9, 0.8, 0.4 },        -- 金黃
    fury = { 0.8, 0.2, 0.8 },             -- 紫紅
    pain = { 0.8, 0.4, 0.2 },             -- 橙色
    essence = { 0.2, 0.6, 0.5 },          -- 青綠
}

-- 框架大小
local ICON_SIZE = 20
local ICON_SPACING = 3
local BAR_HEIGHT = 8

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local resourceFrame = nil
local resourceIcons = {}
local resourceBar = nil
local playerClass = nil
local resourceType = nil
local maxResources = 0
local useBar = false  -- 是否使用進度條而非圖示

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function GetClassResourceInfo()
    local _, _, classID = UnitClass("player")

    if classID == CLASS_ROGUE or classID == CLASS_DRUID then
        return POWER_TYPE_COMBO_POINTS, 5, false, RESOURCE_COLORS.comboPoints
    elseif classID == CLASS_MONK then
        local specID = GetSpecialization()
        if specID == 3 then  -- 風行
            return POWER_TYPE_COMBO_POINTS, 5, false, RESOURCE_COLORS.comboPoints
        end
        return nil, 0, false, nil
    elseif classID == CLASS_DEATHKNIGHT then
        return POWER_TYPE_RUNES, 6, false, RESOURCE_COLORS.runes
    elseif classID == CLASS_WARLOCK then
        return POWER_TYPE_SOUL_SHARDS, 5, false, RESOURCE_COLORS.soulShards
    elseif classID == CLASS_MAGE then
        local specID = GetSpecialization()
        if specID == 1 then  -- 秘法
            return POWER_TYPE_ARCANE_CHARGES, 4, false, RESOURCE_COLORS.arcaneCharges
        end
        return nil, 0, false, nil
    elseif classID == CLASS_PRIEST then
        local specID = GetSpecialization()
        if specID == 3 then  -- 暗影
            return POWER_TYPE_INSANITY, 100, true, RESOURCE_COLORS.insanity
        end
        return nil, 0, false, nil
    elseif classID == CLASS_PALADIN then
        return POWER_TYPE_HOLY_POWER, 5, false, RESOURCE_COLORS.holyPower
    elseif classID == CLASS_DEMONHUNTER then
        local specID = GetSpecialization()
        if specID == 1 then  -- 浩劫
            return POWER_TYPE_FURY, 100, true, RESOURCE_COLORS.fury
        else  -- 乘禦
            return POWER_TYPE_PAIN, 100, true, RESOURCE_COLORS.pain
        end
    elseif classID == CLASS_EVOKER then
        return POWER_TYPE_ESSENCE, 5, false, RESOURCE_COLORS.essence
    end

    return nil, 0, false, nil
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateResourceIcon(parent, _index)
    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    -- 背景
    icon:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    icon:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    icon:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- 填充
    local fill = icon:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetVertexColor(0.5, 0.5, 0.5)
    fill:Hide()
    icon.fill = fill

    -- 光暈（活躍時）
    local glow = icon:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64")
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", 4, -4)
    glow:SetVertexColor(1, 1, 1, 0)
    glow:Hide()
    icon.glow = glow

    return icon
end

local function CreateResourceBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(ICON_SIZE * 5 + ICON_SPACING * 4, BAR_HEIGHT)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)

    -- 背景
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    bar.bg = bg

    -- 邊框
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    bar.border = border

    -- 文字
    local text = bar:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 1, 1)
    bar.text = text

    return bar
end

local function CreateResourceFrame()
    if resourceFrame then return resourceFrame end

    -- 重載時重用現有框架
    local existingFrame = _G["LunarUI_ClassResources"]
    if existingFrame then
        resourceFrame = existingFrame
    else
        resourceFrame = CreateFrame("Frame", "LunarUI_ClassResources", UIParent)
    end

    resourceFrame:SetSize(ICON_SIZE * 6 + ICON_SPACING * 5, ICON_SIZE + 10)
    resourceFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    resourceFrame:SetFrameStrata("HIGH")
    resourceFrame:SetMovable(true)
    resourceFrame:EnableMouse(true)
    resourceFrame:RegisterForDrag("LeftButton")
    resourceFrame:SetClampedToScreen(true)

    -- 拖曳支援
    resourceFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    resourceFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    return resourceFrame
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateResourceIcons(current, max, color)
    for i = 1, max do
        local icon = resourceIcons[i]
        if icon then
            if i <= current then
                icon.fill:SetVertexColor(color[1], color[2], color[3])
                icon.fill:Show()
                icon.glow:SetVertexColor(color[1], color[2], color[3], 0.5)
                icon.glow:Show()
            else
                icon.fill:Hide()
                icon.glow:Hide()
            end
            icon:Show()
        end
    end

    -- 隱藏多餘的圖示
    for i = max + 1, #resourceIcons do
        if resourceIcons[i] then
            resourceIcons[i]:Hide()
        end
    end
end

local function UpdateResourceBar(current, max, color)
    if not resourceBar then return end

    resourceBar:SetMinMaxValues(0, max)
    resourceBar:SetValue(current)
    resourceBar:SetStatusBarColor(color[1], color[2], color[3])
    resourceBar.text:SetFormattedText("%.0f / %d", current, max)
end

local function UpdateResources()
    if not resourceFrame or not resourceFrame:IsShown() then return end
    if not resourceType then return end

    local current, max

    if resourceType == POWER_TYPE_RUNES then
        -- 符文需要特殊處理
        local ready = 0
        for i = 1, 6 do
            local _start, _duration, runeReady = GetRuneCooldown(i)
            if runeReady then
                ready = ready + 1
            end
        end
        current = ready
        max = 6
    else
        current = UnitPower("player", resourceType)
        max = UnitPowerMax("player", resourceType)
    end

    if max == 0 then
        resourceFrame:Hide()
        return
    end

    local color = select(4, GetClassResourceInfo()) or { 1, 1, 1 }

    if useBar then
        if resourceBar then
            UpdateResourceBar(current, max, color)
        end
    else
        UpdateResourceIcons(current, maxResources or max, color)
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function SetupResourceDisplay()
    if not resourceFrame then
        CreateResourceFrame()
    end

    -- 清除現有元素
    for _, icon in ipairs(resourceIcons) do
        icon:Hide()
    end
    if resourceBar then
        resourceBar:Hide()
    end

    -- 取得職業資源資訊
    local powerType, max, usesBar, color = GetClassResourceInfo()

    if not powerType then
        resourceFrame:Hide()
        return
    end

    resourceType = powerType
    maxResources = max
    useBar = usesBar

    if useBar then
        -- 使用進度條
        if not resourceBar then
            resourceBar = CreateResourceBar(resourceFrame)
            resourceBar:SetPoint("CENTER")
        end
        resourceBar:Show()
        resourceBar:SetStatusBarColor(color[1], color[2], color[3])

        -- 隱藏圖示
        for _, icon in ipairs(resourceIcons) do
            icon:Hide()
        end
    else
        -- 使用圖示
        local totalWidth = max * ICON_SIZE + (max - 1) * ICON_SPACING
        local startX = -totalWidth / 2 + ICON_SIZE / 2

        for i = 1, max do
            if not resourceIcons[i] then
                resourceIcons[i] = CreateResourceIcon(resourceFrame, i)
            end
            resourceIcons[i]:SetPoint("CENTER", resourceFrame, "CENTER", startX + (i - 1) * (ICON_SIZE + ICON_SPACING), 0)
            resourceIcons[i]:Show()
        end

        -- 隱藏進度條
        if resourceBar then
            resourceBar:Hide()
        end
    end

    resourceFrame:Show()
    UpdateResources()
end

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("RUNE_POWER_UPDATE")

eventFrame:SetScript("OnEvent", function(_self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        C_Timer.After(0.5, SetupResourceDisplay)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        if arg1 == "player" then
            UpdateResources()
        end
    elseif event == "RUNE_POWER_UPDATE" then
        UpdateResources()
    end
end)

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local function UpdateForPhase()
    if not resourceFrame then return end

    -- 使用共用 ApplyPhaseAlpha
    local alpha = LunarUI:ApplyPhaseAlpha(resourceFrame, "classResources")

    -- 特殊邏輯：無資源類型時隱藏
    if alpha > 0 and not resourceType then
        resourceFrame:Hide()
    end
end

local function OnPhaseChanged(_oldPhase, _newPhase)
    UpdateForPhase()
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function Initialize()
    -- 取得玩家職業
    local _, _, classID = UnitClass("player")
    playerClass = classID

    SetupResourceDisplay()

    -- 註冊月相變化回呼
    LunarUI:RegisterPhaseCallback(OnPhaseChanged)

    -- 初始狀態
    UpdateForPhase()
end

-- 匯出函數
function LunarUI.ShowClassResources()
    if resourceFrame then
        resourceFrame:Show()
    end
end

function LunarUI.HideClassResources()
    if resourceFrame then
        resourceFrame:Hide()
    end
end

function LunarUI.RefreshClassResources()
    SetupResourceDisplay()
end

-- 清理函數
function LunarUI.CleanupClassResources()
    if resourceFrame then
        resourceFrame:Hide()
    end
    eventFrame:UnregisterAllEvents()
end

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(1.0, Initialize)
end)
