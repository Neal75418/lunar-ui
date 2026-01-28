---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
--[[
    LunarUI - 冷卻追蹤器
    監控重要技能冷卻並顯示於螢幕

    功能：
    - 追蹤指定技能冷卻
    - 可拖曳圖示列
    - 冷卻結束閃光提示
    - 月相感知顯示
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 效能：快取全域變數
--------------------------------------------------------------------------------

local math_ceil = math.ceil
local math_floor = math.floor
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local ipairs = ipairs
local type = type
local wipe = wipe
local GetTime = GetTime
local UnitClass = UnitClass
local GetSpecialization = GetSpecialization
local C_Spell = C_Spell
local IsPlayerSpell = IsPlayerSpell

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local ICON_SIZE = 36
local ICON_SPACING = 4
local MAX_ICONS = 8
local UPDATE_INTERVAL = 0.1  -- 更新頻率（秒）
local _FLASH_DURATION = 0.5   -- 閃光持續時間（保留供未來使用）

-- 預設追蹤的重要技能（按職業）
-- 這些是常見的主要冷卻技能
local DEFAULT_TRACKED_SPELLS = {
    -- 戰士
    [1] = {
        100,    -- 衝鋒
        1719,   -- 魯莽
        107574, -- 天神下凡
        227847, -- 劍刃風暴
        12292,  -- 血怒
        23920,  -- 法術反射
        871,    -- 盾牆
        12975,  -- 破釜沉舟
    },
    -- 聖騎士
    [2] = {
        31884,  -- 復仇之怒
        31850,  -- 聖佑術
        642,    -- 聖盾術
        1022,   -- 保護祝福
        6940,   -- 犧牲祝福
        498,    -- 聖佑術
        31821,  -- 光環精通
        633,    -- 聖療術
    },
    -- 獵人
    [3] = {
        193530, -- 野性面向
        19574,  -- 狂野怒火
        288613, -- 嗜血術
        186265, -- 靈龜
        109304, -- 意氣風發
        264735, -- 生存本能
    },
    -- 盜賊
    [4] = {
        13750,  -- 腎上腺素激增
        51690,  -- 影舞
        121471, -- 暗影之刃
        1856,   -- 消失
        31224,  -- 暗影披風
        2983,   -- 衝刺
        5277,   -- 閃避
        185311, -- 赤紅乙醇
    },
    -- 牧師
    [5] = {
        47788,  -- 守護之魂
        33206,  -- 痛苦鎮壓
        62618,  -- 力量壁壘
        64843,  -- 神聖讚美詩
        10060,  -- 能量灌注
        8122,   -- 心靈尖嘯
        34433,  -- 暗影魔
        228260, -- 虛無噴發
    },
    -- 死亡騎士
    [6] = {
        47568,  -- 強力符文武器
        49028,  -- 舞蹈符文武器
        55233,  -- 吸血鬼之血
        48792,  -- 冰錮堅韌
        49576,  -- 死亡之握
        48707,  -- 反魔法護罩
        51052,  -- 反魔法地帶
        42650,  -- 亡者大軍
    },
    -- 薩滿
    [7] = {
        114050, -- 升騰
        198067, -- 火元素
        108271, -- 星界轉移
        108281, -- 祖靈指引
        98008,  -- 靈魂連結圖騰
        192077, -- 風颯圖騰
        16191,  -- 法力之潮圖騰
        79206,  -- 靈行者之賜
    },
    -- 法師
    [8] = {
        12472,  -- 冰冷之血
        190319, -- 燃燒
        365350, -- 秘法飛彈
        45438,  -- 寒冰屏障
        66,     -- 隱形術
        235450, -- 熾焰鎧甲
        113724, -- 火焰之環
    },
    -- 術士
    [9] = {
        205180, -- 召喚惡魔領主
        113860, -- 黑暗靈魂：苦難
        113858, -- 黑暗靈魂：不穩定
        104773, -- 不滅決心
        48020,  -- 惡魔傳送門
        108416, -- 暗門
        333889, -- 靈魂烈焰
    },
    -- 武僧
    [10] = {
        115203, -- 壯膽
        122278, -- 卸勁訣
        115176, -- 業報之觸
        116849, -- 雷射甘露
        122470, -- 業報之觸
        119381, -- 掃堂腿
        137639, -- 風暴、大地與火
        115078, -- 癱瘓
    },
    -- 德魯伊
    [11] = {
        194223, -- 化身：叢林之王
        102560, -- 化身：群星之主
        102558, -- 化身：烏索爾之子
        33891,  -- 化身：生命之樹
        22812,  -- 乘柱護甲
        61336,  -- 生存本能
        106951, -- 乘柱護甲
        77764,  -- 狂奔突襲
    },
    -- 惡魔獵人
    [12] = {
        191427, -- 乘柱護甲
        200166, -- 乘柱護甲
        187827, -- 乘柱護甲
        196555, -- 虛空行走
        198589, -- 地獄血脈
        179057, -- 混沌新星
        206803, -- 雨刃
    },
    -- 喚魔師
    [13] = {
        363916, -- 時空倒流
        357210, -- 深呼吸
        370553, -- 先祖回響
        359816, -- 翠玉之夢
        358267, -- 刺穿力場
        370665, -- 急迫
        374348, -- 壓制咆哮
    },
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local cooldownFrame = nil
local cooldownIcons = {}
local trackedSpells = {}
local updateTimer = 0
local isInitialized = false
local spellTextureCache = {}  -- 法術圖示快取，避免重複查詢 API

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function GetPlayerClassID()
    local _, _, classID = UnitClass("player")
    return classID
end

local function GetSpellCooldownInfo(spellID)
    local spellInfo = C_Spell.GetSpellCooldown(spellID)
    if spellInfo then
        return spellInfo.startTime, spellInfo.duration, spellInfo.isEnabled
    end
    return 0, 0, true
end

-- 無效法術的標記值
local INVALID_TEXTURE = false

local function GetSpellTexture(spellID)
    -- 輸入驗證
    if type(spellID) ~= "number" then
        return nil
    end

    -- 檢查快取（包括負面快取）
    local cached = spellTextureCache[spellID]
    if cached ~= nil then
        if cached == INVALID_TEXTURE then
            return nil
        end
        return cached
    end

    -- 查詢並快取
    local info = C_Spell.GetSpellInfo(spellID)
    local texture = info and info.iconID or nil
    if texture then
        spellTextureCache[spellID] = texture
    else
        -- 負面快取：避免重複查詢無效法術
        spellTextureCache[spellID] = INVALID_TEXTURE
    end
    return texture
end

local function IsSpellKnownByPlayer(spellID)
    -- 注意：不能用 IsSpellKnown 作為函數名，會造成遞迴
    local known = C_Spell.IsSpellUsable(spellID)
    return known or IsPlayerSpell(spellID)
end

local function FormatCooldown(seconds)
    if seconds >= 60 then
        return string_format("%dm", math_ceil(seconds / 60))
    elseif seconds >= 10 then
        return string_format("%d", math_floor(seconds))
    else
        return string_format("%.1f", seconds)
    end
end

--------------------------------------------------------------------------------
-- 圖示建立
--------------------------------------------------------------------------------

local function CreateCooldownIcon(parent, _index)
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

    -- 技能圖示
    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", -1, 1)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.texture = texture

    -- 冷卻遮罩
    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    icon.cooldown = cooldown

    -- 冷卻文字
    local text = icon:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    text:SetPoint("CENTER", 0, 0)
    text:SetTextColor(1, 1, 1)
    icon.text = text

    -- 閃光效果
    local flash = icon:CreateTexture(nil, "OVERLAY")
    flash:SetTexture("Interface\\GLUES\\MODELS\\UI_Draenei\\GenericGlow64")
    flash:SetBlendMode("ADD")
    flash:SetPoint("TOPLEFT", -8, 8)
    flash:SetPoint("BOTTOMRIGHT", 8, -8)
    flash:SetAlpha(0)
    icon.flash = flash

    -- 閃光動畫群組
    local flashAnim = flash:CreateAnimationGroup()
    local fadeIn = flashAnim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.15)
    fadeIn:SetOrder(1)
    local fadeOut = flashAnim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.35)
    fadeOut:SetOrder(2)
    icon.flashAnim = flashAnim

    icon:Hide()
    return icon
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateCooldownFrame()
    if cooldownFrame then return cooldownFrame end

    -- 重載時重用現有框架
    local existingFrame = _G["LunarUI_CooldownTracker"]
    if existingFrame then
        cooldownFrame = existingFrame
    else
        cooldownFrame = CreateFrame("Frame", "LunarUI_CooldownTracker", UIParent)
    end

    cooldownFrame:SetSize(MAX_ICONS * (ICON_SIZE + ICON_SPACING) - ICON_SPACING, ICON_SIZE + 10)
    cooldownFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
    cooldownFrame:SetFrameStrata("HIGH")
    cooldownFrame:SetMovable(true)
    cooldownFrame:EnableMouse(true)
    cooldownFrame:RegisterForDrag("LeftButton")
    cooldownFrame:SetClampedToScreen(true)

    -- 拖曳支援
    cooldownFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    cooldownFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- 建立圖示
    for i = 1, MAX_ICONS do
        cooldownIcons[i] = CreateCooldownIcon(cooldownFrame, i)
    end

    return cooldownFrame
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateCooldownIcons()
    if not cooldownFrame or not cooldownFrame:IsShown() then return end

    local visibleIndex = 0
    local currentTime = GetTime()

    for _, spellID in ipairs(trackedSpells) do
        if IsSpellKnownByPlayer(spellID) then
            local start, duration, enabled = GetSpellCooldownInfo(spellID)

            if enabled and duration > 1.5 then  -- 忽略 GCD
                local remaining = start + duration - currentTime

                if remaining > 0 then
                    visibleIndex = visibleIndex + 1

                    if visibleIndex <= MAX_ICONS then
                        local icon = cooldownIcons[visibleIndex]
                        if icon then
                            -- 設定圖示
                            local texture = GetSpellTexture(spellID)
                            if texture then
                                icon.texture:SetTexture(texture)
                            end

                            -- 設定冷卻
                            icon.cooldown:SetCooldown(start, duration)

                            -- 設定文字
                            icon.text:SetText(FormatCooldown(remaining))

                            -- 顏色：根據剩餘時間
                            if remaining <= 5 then
                                icon.text:SetTextColor(0.2, 1, 0.2)  -- 綠色：即將完成
                            elseif remaining <= 15 then
                                icon.text:SetTextColor(1, 1, 0.2)   -- 黃色：快了
                            else
                                icon.text:SetTextColor(1, 1, 1)     -- 白色：還久
                            end

                            -- 位置
                            local x = (visibleIndex - 1) * (ICON_SIZE + ICON_SPACING)
                            icon:ClearAllPoints()
                            icon:SetPoint("LEFT", cooldownFrame, "LEFT", x, 0)
                            icon:Show()

                            -- 儲存 spellID 用於閃光
                            icon.spellID = spellID
                            icon.wasOnCooldown = true
                        end
                    end
                else
                    -- 冷卻剛結束，觸發閃光
                    for i = 1, MAX_ICONS do
                        local icon = cooldownIcons[i]
                        if icon and icon.spellID == spellID and icon.wasOnCooldown then
                            icon.flashAnim:Play()
                            icon.wasOnCooldown = false
                        end
                    end
                end
            end
        end
    end

    -- 隱藏多餘的圖示
    for i = visibleIndex + 1, MAX_ICONS do
        if cooldownIcons[i] then
            cooldownIcons[i]:Hide()
            cooldownIcons[i].spellID = nil
        end
    end

    -- 調整框架寬度
    if visibleIndex > 0 then
        local width = visibleIndex * (ICON_SIZE + ICON_SPACING) - ICON_SPACING
        cooldownFrame:SetWidth(width)
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function SetupTrackedSpells()
    local classID = GetPlayerClassID()
    trackedSpells = DEFAULT_TRACKED_SPELLS[classID] or {}
end

local function Initialize()
    if isInitialized then return end

    CreateCooldownFrame()
    SetupTrackedSpells()

    -- 註冊月相變化回呼
    LunarUI:RegisterPhaseCallback(function(_oldPhase, _newPhase)
        UpdateForPhase()
    end)

    -- 初始狀態
    UpdateForPhase()

    isInitialized = true
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local function UpdateForPhase()
    -- 使用共用 ApplyPhaseAlpha
    LunarUI:ApplyPhaseAlpha(cooldownFrame, "cooldownTracker")
end

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("SPELLS_CHANGED")

eventFrame:SetScript("OnEvent", function(_self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, Initialize)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "SPELLS_CHANGED" then
        SetupTrackedSpells()
    end
end)

-- OnUpdate 處理（節流）
eventFrame:SetScript("OnUpdate", function(_self, elapsed)
    if not isInitialized then return end

    updateTimer = updateTimer + elapsed
    if updateTimer >= UPDATE_INTERVAL then
        updateTimer = 0
        UpdateCooldownIcons()
    end
end)

--------------------------------------------------------------------------------
-- 匯出函數
--------------------------------------------------------------------------------

function LunarUI.ShowCooldownTracker()
    if cooldownFrame then
        cooldownFrame:Show()
    end
end

function LunarUI.HideCooldownTracker()
    if cooldownFrame then
        cooldownFrame:Hide()
    end
end

function LunarUI.RefreshCooldownTracker()
    SetupTrackedSpells()
    UpdateCooldownIcons()
end

-- 新增自訂追蹤技能
function LunarUI.AddTrackedSpell(spellID)
    if type(spellID) == "number" then
        table_insert(trackedSpells, spellID)
    end
end

-- 移除追蹤技能
function LunarUI.RemoveTrackedSpell(spellID)
    for i, id in ipairs(trackedSpells) do
        if id == spellID then
            table_remove(trackedSpells, i)
            return
        end
    end
end

-- 清理函數
function LunarUI.CleanupCooldownTracker()
    if cooldownFrame then
        cooldownFrame:Hide()
    end
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnUpdate", nil)
    wipe(spellTextureCache)  -- 清理圖示快取
end

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(1.5, Initialize)
end)
