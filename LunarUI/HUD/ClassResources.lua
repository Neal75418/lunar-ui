---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch
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
local L = Engine.L or {}
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
    comboPoints = { 0.9, 0.7, 0.2 }, -- 金色
    runes = { 0.6, 0.2, 0.2 }, -- 深紅
    runeReady = { 0.8, 0.1, 0.1 }, -- 亮紅
    soulShards = { 0.6, 0.3, 0.8 }, -- 紫色
    arcaneCharges = { 0.3, 0.6, 0.9 }, -- 藍色
    insanity = { 0.6, 0.2, 0.8 }, -- 暗紫
    holyPower = { 0.9, 0.8, 0.4 }, -- 金黃
    fury = { 0.8, 0.2, 0.8 }, -- 紫紅
    pain = { 0.8, 0.4, 0.2 }, -- 橙色
    essence = { 0.2, 0.6, 0.5 }, -- 青綠
}

-- 框架大小（初始化時從 DB 讀取，為可變設定值，非常數）
local iconSize = 26
local iconSpacing = 4
local barHeight = 10

local function LoadSettings()
    iconSize = LunarUI.GetHUDSetting("crIconSize", 26)
    iconSpacing = LunarUI.GetHUDSetting("crIconSpacing", 4)
    barHeight = LunarUI.GetHUDSetting("crBarHeight", 10)
end

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

---@type Frame?
local resourceFrame
local resourceIcons = {}
---@type StatusBar?
local resourceBar
---@type integer?
local resourceType
local maxResources = 0
local isInitialized = false
local setupScheduled = false
local useBar = false -- 是否使用進度條而非圖示
-- M5 效能修復：快取資源顏色，避免 UpdateResources 每次 UNIT_POWER_UPDATE 都呼叫 GetClassResourceInfo
-- 職業和顏色在戰鬥中不會改變，SetupResourceDisplay 初始化後一次性設定
local cachedResourceColor = { 1, 1, 1 }

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
        if specID == 3 then -- 風行
            return POWER_TYPE_COMBO_POINTS, 5, false, RESOURCE_COLORS.comboPoints
        end
        return nil, 0, false, nil
    end,
    [CLASS_MAGE] = function(specID)
        if specID == 1 then -- 秘法
            return POWER_TYPE_ARCANE_CHARGES, 4, false, RESOURCE_COLORS.arcaneCharges
        end
        return nil, 0, false, nil
    end,
    [CLASS_PRIEST] = function(specID)
        if specID == 3 then -- 暗影
            return POWER_TYPE_INSANITY, 100, true, RESOURCE_COLORS.insanity
        end
        return nil, 0, false, nil
    end,
    [CLASS_DEMONHUNTER] = function(specID)
        if not specID then
            return nil, 0, false, nil
        end
        if specID == 1 then -- 浩劫
            return POWER_TYPE_FURY, 100, true, RESOURCE_COLORS.fury
        else -- 乘禦
            return POWER_TYPE_PAIN, 100, true, RESOURCE_COLORS.pain
        end
    end,
}

---@return integer?, integer, boolean, number[]?
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

    -- 直接返回配置值（config 此時必為 table）
    local tbl = config --[[@as table]]
    return tbl[1], tbl[2], tbl[3], tbl[4]
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateResourceIcon(parent)
    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(iconSize, iconSize)

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

---@return Frame
local function CreateResourceBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(iconSize * 5 + iconSpacing * 4, barHeight)
    bar:SetStatusBarTexture(LunarUI.GetSelectedStatusBarTexture())
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)

    -- 背景
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    bar.bg = bg

    -- 邊框
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    border:SetBackdropBorderColor(C.borderIcon[1], C.borderIcon[2], C.borderIcon[3], C.borderIcon[4])
    bar.border = border

    -- 文字
    local text = bar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(text, 10, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 1, 1)
    bar.text = text

    return bar
end

---@return Frame
local function CreateResourceFrame()
    if resourceFrame then
        return resourceFrame
    end

    -- 重載時重用現有框架
    local existingFrame = _G["LunarUI_ClassResources"]
    if existingFrame then
        resourceFrame = existingFrame
    else
        resourceFrame = CreateFrame("Frame", "LunarUI_ClassResources", UIParent)
    end
    LunarUI:RegisterHUDFrame("LunarUI_ClassResources")

    resourceFrame:SetSize(iconSize * 6 + iconSpacing * 5, iconSize + 10)
    resourceFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    resourceFrame:SetFrameStrata("HIGH")
    resourceFrame:SetClampedToScreen(true)

    return resourceFrame
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateResourceIcons(current, max, color)
    for i = 1, max do
        local icon = resourceIcons[i]
        if icon then
            local isActive = i <= current
            -- B9 效能修復：只在狀態切換時呼叫 SetVertexColor（顏色為 cachedResourceColor，不會改變）
            -- 避免 UNIT_POWER_UPDATE（高頻）每次對所有圖示無謂呼叫 C API
            if isActive then
                if not icon._isActive then
                    icon._isActive = true
                    icon.fill:SetVertexColor(color[1], color[2], color[3])
                    icon.glow:SetVertexColor(color[1], color[2], color[3], 0.7)
                    icon.fill:Show()
                    icon.glow:Show()
                end
            else
                if icon._isActive ~= false then
                    icon._isActive = false
                    icon.fill:Hide()
                    icon.glow:Hide()
                end
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
    if not resourceBar then
        return
    end

    resourceBar:SetMinMaxValues(0, max)
    resourceBar:SetValue(current)
    resourceBar:SetStatusBarColor(color[1], color[2], color[3])
    resourceBar.text:SetFormattedText("%.0f / %d", current, max)
end

local function UpdateResources()
    if not resourceFrame or not resourceFrame:IsShown() then
        return
    end
    if not resourceType then
        return
    end

    local current, max

    if resourceType == POWER_TYPE_RUNES then
        -- 符文需要特殊處理
        -- #14: GetRuneCooldown 回傳正常數值，不需要 pcall 保護（已驗證 WoW 12.0）
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

    local color = cachedResourceColor -- M5: 使用 SetupResourceDisplay 快取的顏色，無需重複呼叫 GetClassResourceInfo

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
    -- 模組停用後 C_Timer.After 仍可能觸發此函數，需要提前退出
    if not isInitialized then
        return
    end
    if not resourceFrame then
        resourceFrame = CreateResourceFrame()
    end

    -- 清除現有元素（重置 _isActive 讓換職業/天賦後正確重新套色）
    for _, icon in ipairs(resourceIcons) do
        icon:Hide()
        icon._isActive = nil
    end
    if resourceBar then
        resourceBar:Hide()
    end

    -- 取得職業資源資訊
    local powerType, max, usesBar, color = GetClassResourceInfo()

    if not powerType or not color then
        resourceFrame:Hide()
        return
    end

    resourceType = powerType
    maxResources = max
    useBar = usesBar
    -- M5: 快取 color，UpdateResources 直接讀取，不重複呼叫 GetClassResourceInfo
    cachedResourceColor = color

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
        local totalWidth = max * iconSize + (max - 1) * iconSpacing
        local startX = -totalWidth / 2 + iconSize / 2

        for i = 1, max do
            if not resourceIcons[i] then
                resourceIcons[i] = CreateResourceIcon(resourceFrame)
            end
            resourceIcons[i]:ClearAllPoints()
            resourceIcons[i]:SetPoint("CENTER", resourceFrame, "CENTER", startX + (i - 1) * (iconSize + iconSpacing), 0)
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

local _eventFrame = LunarUI.CreateEventHandler({
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
    "RUNE_POWER_UPDATE",
}, function(_self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if LunarUI.GetHUDSetting("classResources", true) == false then
            return
        end
        -- Low: 確保 disable 後 PLAYER_ENTERING_WORLD 不會繞過 isInitialized 重啟模組
        if not isInitialized then
            return
        end
        -- 立即隱藏舊資源，避免專精切換時短暫顯示過期資訊
        for _, icon in ipairs(resourceIcons) do
            icon:Hide()
        end
        if resourceBar then
            resourceBar:Hide()
        end
        if not setupScheduled then
            setupScheduled = true
            C_Timer.After(0.5, function()
                setupScheduled = false
                SetupResourceDisplay()
            end)
        end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        if arg1 == "player" and isInitialized then
            UpdateResources()
        end
    elseif event == "RUNE_POWER_UPDATE" then
        if isInitialized then
            UpdateResources()
        end
    end
end)

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function Initialize()
    if isInitialized then
        return
    end
    if LunarUI.GetHUDSetting("classResources", true) == false then
        return
    end
    LoadSettings()

    -- isInitialized 必須在 SetupResourceDisplay() 之前設為 true，
    -- 否則其內部的 "if not isInitialized then return end" guard 會使首次初始化提前返回
    isInitialized = true
    SetupResourceDisplay()

    -- 註冊至框架移動器
    if resourceFrame then
        LunarUI.RegisterMovableFrame("ClassResources", resourceFrame, L["HUDClassResources"] or "Class Resources")
    end
end

-- 暴露 Initialize 供 Options toggle 即時切換
LunarUI.InitClassResources = Initialize

function LunarUI.RebuildClassResources()
    if InCombatLockdown() then
        return
    end
    LoadSettings()
    SetupResourceDisplay()
end

-- 清理函數
function LunarUI.CleanupClassResources()
    if resourceFrame then
        resourceFrame:Hide()
    end
    isInitialized = false
    -- 不取消事件註冊：OnEvent handler 已有 isInitialized guard，
    -- 保留事件以便 toggle 重新啟用時 Initialize 能被正確呼叫
end

LunarUI:RegisterModule("ClassResources", {
    onEnable = Initialize,
    onDisable = LunarUI.CleanupClassResources,
    delay = 1.0,
    lifecycle = "reversible",
})
