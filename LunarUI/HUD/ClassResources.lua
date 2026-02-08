---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 效能：快取全域變數
--------------------------------------------------------------------------------

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

-- 框架大小（初始化時從 DB 讀取）
local ICON_SIZE = 26
local ICON_SPACING = 4
local BAR_HEIGHT = 10

local function LoadSettings()
    ICON_SIZE = LunarUI.GetHUDSetting("crIconSize", 26)
    ICON_SPACING = LunarUI.GetHUDSetting("crIconSpacing", 4)
    BAR_HEIGHT = LunarUI.GetHUDSetting("crBarHeight", 10)
end

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

-- 職業資源查詢表（取代 elseif 鏈，提高可維護性）
-- 格式：[classID] = { powerType, maxValue, useBar, color }
-- 或 [classID] = function(specID) return powerType, maxValue, useBar, color end
local CLASS_RESOURCE_CONFIG = {
    [CLASS_ROGUE] = { POWER_TYPE_COMBO_POINTS, 5, false, RESOURCE_COLORS.comboPoints },
    [CLASS_DRUID] = { POWER_TYPE_COMBO_POINTS, 5, false, RESOURCE_COLORS.comboPoints },
    [CLASS_DEATHKNIGHT] = { POWER_TYPE_RUNES, 6, false, RESOURCE_COLORS.runes },
    [CLASS_WARLOCK] = { POWER_TYPE_SOUL_SHARDS, 5, false, RESOURCE_COLORS.soulShards },
    [CLASS_PALADIN] = { POWER_TYPE_HOLY_POWER, 5, false, RESOURCE_COLORS.holyPower },
    [CLASS_EVOKER] = { POWER_TYPE_ESSENCE, 5, false, RESOURCE_COLORS.essence },

    -- 專精依賴的職業
    [CLASS_MONK] = function(specID)
        if specID == 3 then  -- 風行
            return POWER_TYPE_COMBO_POINTS, 5, false, RESOURCE_COLORS.comboPoints
        end
        return nil, 0, false, nil
    end,
    [CLASS_MAGE] = function(specID)
        if specID == 1 then  -- 秘法
            return POWER_TYPE_ARCANE_CHARGES, 4, false, RESOURCE_COLORS.arcaneCharges
        end
        return nil, 0, false, nil
    end,
    [CLASS_PRIEST] = function(specID)
        if specID == 3 then  -- 暗影
            return POWER_TYPE_INSANITY, 100, true, RESOURCE_COLORS.insanity
        end
        return nil, 0, false, nil
    end,
    [CLASS_DEMONHUNTER] = function(specID)
        if specID == 1 then  -- 浩劫
            return POWER_TYPE_FURY, 100, true, RESOURCE_COLORS.fury
        else  -- 乘禦
            return POWER_TYPE_PAIN, 100, true, RESOURCE_COLORS.pain
        end
    end,
}

local function GetClassResourceInfo()
    local _, _, classID = UnitClass("player")
    local config = CLASS_RESOURCE_CONFIG[classID]

    if not config then
        return nil, 0, false, nil
    end

    -- 如果是函數，傳入專精 ID 並執行
    if type(config) == "function" then
        return config(GetSpecialization())
    end

    -- 直接返回配置值
    return config[1], config[2], config[3], config[4]
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateResourceIcon(parent)
    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    -- 背景（使用共用模板）
    LunarUI.ApplyBackdrop(icon, LunarUI.iconBackdropTemplate, C.bgIcon, C.borderIcon)

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
    glow:SetTexture(LunarUI.textures.glow)
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", -8, 8)
    glow:SetPoint("BOTTOMRIGHT", 8, -8)
    glow:SetVertexColor(1, 1, 1, 0)
    glow:Hide()
    icon.glow = glow

    return icon
end

local function CreateResourceBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(ICON_SIZE * 5 + ICON_SPACING * 4, BAR_HEIGHT)
    bar:SetStatusBarTexture(LunarUI.GetSelectedStatusBarTexture())
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)

    -- 背景
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(unpack(C.bgIcon))
    bar.bg = bg

    -- 邊框
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(unpack(C.borderIcon))
    bar.border = border

    -- 文字
    local text = bar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(text, 10, "OUTLINE")
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
    LunarUI:RegisterHUDFrame("LunarUI_ClassResources")

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
                icon.glow:SetVertexColor(color[1], color[2], color[3], 0.7)
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
        -- WoW 12.0：GetRuneCooldown 可能返回密值，用 pcall 保護
        local ready = 0
        for i = 1, 6 do
            local ok, _start, _duration, runeReady = pcall(GetRuneCooldown, i)
            if ok and runeReady then
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

local eventFrame = LunarUI.CreateEventHandler(
    {"PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "RUNE_POWER_UPDATE"},
    function(_self, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
            -- 立即隱藏舊資源，避免專精切換時短暫顯示過期資訊
            for _, icon in ipairs(resourceIcons) do
                icon:Hide()
            end
            if resourceBar then
                resourceBar:Hide()
            end
            C_Timer.After(0.5, SetupResourceDisplay)
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
            if arg1 == "player" then
                UpdateResources()
            end
        elseif event == "RUNE_POWER_UPDATE" then
            UpdateResources()
        end
    end
)

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function Initialize()
    LoadSettings()

    -- 取得玩家職業
    local _, _, classID = UnitClass("player")
    playerClass = classID

    SetupResourceDisplay()

    -- 註冊至框架移動器
    if resourceFrame then
        LunarUI:RegisterMovableFrame("ClassResources", resourceFrame, "職業資源")
    end

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

function LunarUI:RebuildClassResources()
    if InCombatLockdown() then return end
    LoadSettings()
    SetupResourceDisplay()
end

-- 清理函數
function LunarUI.CleanupClassResources()
    if resourceFrame then
        resourceFrame:Hide()
    end
    eventFrame:UnregisterAllEvents()
    eventFrame = nil
end

LunarUI:RegisterModule("ClassResources", {
    onEnable = Initialize,
    onDisable = LunarUI.CleanupClassResources,
    delay = 1.0,
})
