---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
--[[
    LunarUI - 浮動戰鬥數字
    顯示傷害、治療及特殊事件的飄字效果

    功能：
    - 傷害數字（白字/暴擊放大）
    - 治療數字（綠字）
    - 特殊事件（閃避/格擋/免疫）
    - 月相感知：NEW 減少數字量
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 效能：快取全域變數
--------------------------------------------------------------------------------

local math_floor = math.floor
local math_random = math.random
local math_sin = math.sin
local math_pi = math.pi
local string_format = string.format
local string_lower = string.lower
local tostring = tostring
local table_insert = table.insert
local table_remove = table.remove
local ipairs = ipairs
local type = type
local wipe = wipe
local GetTime = GetTime
local UnitGUID = UnitGUID
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local select = select

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 動畫設定
local ANIMATION_DURATION = 1.5    -- 飄字持續時間
local ANIMATION_HEIGHT = 80       -- 向上飄動距離
local FADE_START = 0.7            -- 開始淡出的時間點（百分比）

-- 文字大小
local FONT_SIZE_NORMAL = 18
local FONT_SIZE_CRIT = 28
local FONT_SIZE_SMALL = 14

-- 顏色
local COLORS = {
    damage = { 1.0, 1.0, 1.0 },       -- 白色
    damageCrit = { 1.0, 0.8, 0.2 },   -- 金色暴擊
    heal = { 0.2, 1.0, 0.2 },          -- 綠色
    healCrit = { 0.4, 1.0, 0.6 },      -- 亮綠暴擊
    absorb = { 0.8, 0.8, 0.2 },        -- 黃色吸收
    miss = { 0.6, 0.6, 0.6 },          -- 灰色未命中
    dodge = { 0.4, 0.6, 1.0 },         -- 藍色閃避
    parry = { 0.6, 0.4, 1.0 },         -- 紫色招架
    block = { 0.8, 0.6, 0.4 },         -- 棕色格擋
    immune = { 1.0, 1.0, 0.6 },        -- 淡黃免疫
    reflect = { 1.0, 0.4, 1.0 },       -- 粉紫反射
    energize = { 0.2, 0.6, 1.0 },      -- 藍色能量
}

-- 事件文字
local EVENT_TEXT = {
    MISS = "未命中",
    DODGE = "閃避",
    PARRY = "招架",
    BLOCK = "格擋",
    IMMUNE = "免疫",
    REFLECT = "反射",
    ABSORB = "吸收",
    RESIST = "抵抗",
    EVADE = "閃避",
}

-- 物件池大小
local POOL_SIZE = 30

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local fctFrame = nil
local textPool = {}
local activeTexts = {}
local isInitialized = false
local playerGUID = nil  -- 快取玩家 GUID，避免每次事件都查詢

-- 月相過濾器
local phaseFilter = {
    NEW = 0.3,      -- 只顯示 30% 的數字
    WAXING = 0.7,   -- 顯示 70% 的數字
    FULL = 1.0,     -- 顯示全部
    WANING = 0.8,   -- 顯示 80%
}

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function FormatNumber(number)
    if number >= 1000000 then
        return string_format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        return string_format("%.1fK", number / 1000)
    else
        return tostring(math_floor(number))
    end
end

local function ShouldShowNumber()
    local phase = LunarUI:GetPhase()
    local threshold = phaseFilter[phase] or 1
    return math_random() <= threshold
end

--------------------------------------------------------------------------------
-- 文字物件池
--------------------------------------------------------------------------------

local function CreateFloatingText(parent)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, FONT_SIZE_NORMAL, "OUTLINE")
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 0.8)
    text:Hide()

    -- 動畫資料
    text.animData = {
        startTime = 0,
        startX = 0,
        startY = 0,
        duration = ANIMATION_DURATION,
        isCrit = false,
    }

    return text
end

local function GetTextFromPool()
    for _i, text in ipairs(textPool) do
        if not text:IsShown() then
            return text
        end
    end

    -- 池已滿，建立新的
    if #textPool < POOL_SIZE then
        local newText = CreateFloatingText(fctFrame)
        table_insert(textPool, newText)
        return newText
    end

    -- 回收最舊的
    local oldest = activeTexts[1]
    if oldest then
        oldest:Hide()
        table_remove(activeTexts, 1)
        return oldest
    end

    return nil
end

local function ReleaseText(text)
    text:Hide()
    for _i, t in ipairs(activeTexts) do
        if t == text then
            table_remove(activeTexts, _i)
            break
        end
    end
end

--------------------------------------------------------------------------------
-- 動畫更新
--------------------------------------------------------------------------------

local function UpdateAnimations(_elapsed)
    local currentTime = GetTime()

    for _i = #activeTexts, 1, -1 do
        local text = activeTexts[_i]
        local data = text.animData

        local elapsedTime = currentTime - data.startTime
        local progress = elapsedTime / data.duration

        if progress >= 1 then
            -- 動畫完成
            ReleaseText(text)
        else
            -- 計算位置
            local yOffset = data.startY + (ANIMATION_HEIGHT * progress)

            -- 加入少許左右搖擺
            local xOffset = data.startX + (math_sin(progress * math_pi * 2) * 10)

            text:SetPoint("CENTER", fctFrame, "CENTER", xOffset, yOffset)

            -- 計算透明度
            local alpha = 1
            if progress > FADE_START then
                alpha = 1 - ((progress - FADE_START) / (1 - FADE_START))
            end

            -- 暴擊縮放效果
            if data.isCrit and progress < 0.1 then
                local scale = 1 + (0.3 * (1 - progress / 0.1))
                text:SetTextScale(scale)
            elseif data.isCrit then
                text:SetTextScale(1)
            end

            text:SetAlpha(alpha)
        end
    end
end

--------------------------------------------------------------------------------
-- 顯示數字
--------------------------------------------------------------------------------

local function ShowFloatingText(amount, textType, isCrit, offsetX)
    if not fctFrame or not fctFrame:IsShown() then return end

    -- 月相過濾
    if not ShouldShowNumber() then return end

    local text = GetTextFromPool()
    if not text then return end

    -- 設定文字
    local displayText
    local color = COLORS[textType] or COLORS.damage

    if type(amount) == "number" then
        displayText = FormatNumber(amount)
    else
        displayText = amount
    end

    -- 暴擊特殊處理
    if isCrit then
        if textType == "damage" then
            color = COLORS.damageCrit
        elseif textType == "heal" then
            color = COLORS.healCrit
        end
        displayText = "*" .. displayText .. "*"
    end

    text:SetText(displayText)
    text:SetTextColor(color[1], color[2], color[3])

    -- 設定大小
    local fontSize = isCrit and FONT_SIZE_CRIT or FONT_SIZE_NORMAL
    if textType == "miss" or textType == "dodge" or textType == "parry" then
        fontSize = FONT_SIZE_SMALL
    end
    text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")

    -- 設定動畫資料
    local data = text.animData
    data.startTime = GetTime()
    data.startX = (offsetX or 0) + (math.random(-30, 30))
    data.startY = 0
    data.duration = ANIMATION_DURATION
    data.isCrit = isCrit

    -- 初始位置
    text:ClearAllPoints()
    text:SetPoint("CENTER", fctFrame, "CENTER", data.startX, data.startY)
    text:SetAlpha(1)
    text:SetTextScale(1)
    text:Show()

    table_insert(activeTexts, text)
end

local function ShowEvent(eventType)
    local eventText = EVENT_TEXT[eventType] or eventType
    local lowerType = string_lower(eventType)
    ShowFloatingText(eventText, lowerType, false, 0)
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateFCTFrame()
    if fctFrame then return fctFrame end

    -- 重載時重用現有框架
    local existingFrame = _G["LunarUI_FloatingCombatText"]
    if existingFrame then
        fctFrame = existingFrame
    else
        fctFrame = CreateFrame("Frame", "LunarUI_FloatingCombatText", UIParent)
    end

    fctFrame:SetSize(400, 200)
    fctFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    fctFrame:SetFrameStrata("HIGH")

    -- 建立文字池
    for _i = 1, 10 do
        local text = CreateFloatingText(fctFrame)
        table_insert(textPool, text)
    end

    -- OnUpdate 處理
    fctFrame:SetScript("OnUpdate", function(_self, elapsed)
        UpdateAnimations(elapsed)
    end)

    return fctFrame
end

--------------------------------------------------------------------------------
-- 戰鬥日誌處理
--------------------------------------------------------------------------------

local function ProcessCombatLogEvent()
    -- 安全檢查：確保 playerGUID 已快取
    if not playerGUID then
        playerGUID = UnitGUID("player")
        if not playerGUID then return end
    end

    local _timestamp, subevent, _, sourceGUID, _sourceName, _sourceFlags, _sourceRaidFlags,
          destGUID, _destName, _destFlags, _destRaidFlags = CombatLogGetCurrentEventInfo()

    -- 早期過濾：只處理與玩家相關的事件
    local isPlayerSource = sourceGUID == playerGUID
    local isPlayerDest = destGUID == playerGUID
    if not isPlayerSource and not isPlayerDest then
        return  -- 與玩家無關，跳過
    end

    -- 玩家造成的傷害
    if isPlayerSource then
        if subevent == "SWING_DAMAGE" then
            local amount, _overkill, _school, _resisted, _blocked, _absorbed, critical = select(12, CombatLogGetCurrentEventInfo())
            ShowFloatingText(amount, "damage", critical, 50)

        elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
            local _spellId, _spellName, _spellSchool, amount, _overkill, _school, _resisted, _blocked, _absorbed, critical = select(12, CombatLogGetCurrentEventInfo())
            ShowFloatingText(amount, "damage", critical, 50)

        elseif subevent == "SWING_MISSED" or subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" then
            local missType = select(15, CombatLogGetCurrentEventInfo())
            if subevent == "SWING_MISSED" then
                missType = select(12, CombatLogGetCurrentEventInfo())
            end
            if missType then
                ShowEvent(missType)
            end

        elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
            local _spellId, _spellName, _spellSchool, amount, _overhealing, _absorbed, critical = select(12, CombatLogGetCurrentEventInfo())
            -- 只顯示對自己的治療
            if isPlayerDest then
                ShowFloatingText(amount, "heal", critical, -50)
            end
        end
    end

    -- 玩家受到的傷害
    if isPlayerDest then
        if subevent == "SWING_DAMAGE" then
            local amount, _overkill, _school, _resisted, _blocked, _absorbed, _critical = select(12, CombatLogGetCurrentEventInfo())
            ShowFloatingText(amount, "damage", false, -50)

        elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
            local _spellId, _spellName, _spellSchool, amount, _overkill, _school, _resisted, _blocked, _absorbed, _critical = select(12, CombatLogGetCurrentEventInfo())
            ShowFloatingText(amount, "damage", false, -50)

        elseif subevent == "SWING_MISSED" or subevent == "SPELL_MISSED" or subevent == "RANGE_MISSED" then
            -- 玩家閃避/招架等
            local missType = select(15, CombatLogGetCurrentEventInfo())
            if subevent == "SWING_MISSED" then
                missType = select(12, CombatLogGetCurrentEventInfo())
            end
            if missType then
                ShowEvent(missType)
            end

        elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
            local _spellId, _spellName, _spellSchool, amount, _overhealing, _absorbed, critical = select(12, CombatLogGetCurrentEventInfo())
            ShowFloatingText(amount, "heal", critical, -50)

        elseif subevent == "SPELL_ABSORBED" then
            local amount = select(19, CombatLogGetCurrentEventInfo())
            if amount then
                ShowFloatingText(amount, "absorb", false, -50)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local function UpdateForPhase()
    -- 使用共用 ApplyPhaseAlpha
    LunarUI:ApplyPhaseAlpha(fctFrame, "floatingCombatText")
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function Initialize()
    if isInitialized then return end

    -- 快取玩家 GUID
    playerGUID = UnitGUID("player")

    CreateFCTFrame()

    -- 註冊月相變化回呼
    LunarUI:RegisterPhaseCallback(function(_oldPhase, _newPhase)
        UpdateForPhase()
    end)

    -- 初始狀態
    UpdateForPhase()

    isInitialized = true
end

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

eventFrame:SetScript("OnEvent", function(_self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- 每次進入世界時重新快取 playerGUID（處理副本轉換等情況）
        playerGUID = UnitGUID("player")
        if not isInitialized then
            C_Timer.After(1.0, Initialize)
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if isInitialized then
            ProcessCombatLogEvent()
        end
    end
end)

--------------------------------------------------------------------------------
-- 匯出函數
--------------------------------------------------------------------------------

function LunarUI.ShowFloatingCombatText()
    if fctFrame then
        fctFrame:Show()
    end
end

function LunarUI.HideFloatingCombatText()
    if fctFrame then
        fctFrame:Hide()
    end
end

-- 手動顯示數字（供其他模組使用）
function LunarUI.ShowDamageNumber(amount, isCrit)
    ShowFloatingText(amount, "damage", isCrit, 50)
end

function LunarUI.ShowHealNumber(amount, isCrit)
    ShowFloatingText(amount, "heal", isCrit, -50)
end

-- 清理函數
function LunarUI.CleanupFloatingCombatText()
    if fctFrame then
        fctFrame:Hide()
        fctFrame:SetScript("OnUpdate", nil)
    end
    eventFrame:UnregisterAllEvents()
    wipe(activeTexts)
end

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(1.5, Initialize)
end)
