---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
--[[
    LunarUI - 獨立 Buff/Debuff 框架
    在螢幕上顯示玩家的增益和減益效果

    功能：
    - 獨立的增益區塊（非頭像上）
    - 獨立的減益區塊
    - 智慧過濾（隱藏食物等瑣碎 Buff）
    - 月相感知：NEW 只顯示重要增益
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 效能：快取全域變數
--------------------------------------------------------------------------------

local math_floor = math.floor
local string_format = string.format
local _ipairs = ipairs
local GetTime = GetTime
local C_UnitAuras = C_UnitAuras

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local ICON_SIZE = 32
local ICON_SPACING = 3
local ICONS_PER_ROW = 8
local MAX_BUFFS = 16
local MAX_DEBUFFS = 8

-- 過濾的 Buff 類型（瑣碎的增益）
local FILTERED_BUFF_NAMES = {
    -- 食物增益
    ["充分休息"] = true,
    ["Well Rested"] = true,
    -- 騎乘
    ["騎術"] = true,
    ["Riding"] = true,
    -- 死亡後的虛弱
    ["復活虛弱"] = true,
    ["Resurrection Sickness"] = true,
}

-- 重要的增益類型（永遠顯示，保留供未來使用）
local _IMPORTANT_BUFF_TYPES = {
    HELPFUL = true,
}

-- 優先顯示的減益類型
local PRIORITY_DEBUFF_TYPES = {
    Magic = { 0.2, 0.6, 1.0 },    -- 藍色
    Curse = { 0.6, 0.0, 1.0 },    -- 紫色
    Disease = { 0.6, 0.4, 0.0 },  -- 棕色
    Poison = { 0.0, 0.6, 0.0 },   -- 綠色
    [""] = { 0.8, 0.0, 0.0 },     -- 紅色（無類型）
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local buffFrame = nil
local debuffFrame = nil
local buffIcons = {}
local debuffIcons = {}
local isInitialized = false

-- 淡入動畫
local FADE_IN_DURATION = 0.2

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function FormatDuration(seconds)
    if seconds >= 3600 then
        return string_format("%dh", math_floor(seconds / 3600))
    elseif seconds >= 60 then
        return string_format("%dm", math_floor(seconds / 60))
    elseif seconds >= 10 then
        return string_format("%d", math_floor(seconds))
    else
        return string_format("%.1f", seconds)
    end
end

local function ShouldShowBuff(name, duration, _expirationTime, _isStealable, _source)
    -- 過濾瑣碎 Buff（name 已在呼叫端經 tostring 處理）
    if FILTERED_BUFF_NAMES[name] then
        return false
    end

    -- 月相過濾：NEW 月相只顯示重要 Buff
    local phase = LunarUI:GetPhase()
    if phase == "NEW" then
        -- 只顯示短期 Buff（可能是戰鬥相關）
        local dur = tonumber(duration) or 0
        if dur == 0 or dur > 300 then
            return false
        end
    end

    return true
end

local function ShouldShowDebuff(_name, _duration, _debuffType, _source)
    -- 減益通常都要顯示
    return true
end

--------------------------------------------------------------------------------
-- 圖示建立
--------------------------------------------------------------------------------

local function CreateAuraIcon(parent, _index)
    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    -- 背景（使用共用模板）
    icon:SetBackdrop(LunarUI.iconBackdropTemplate)
    icon:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    icon:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- 圖示紋理
    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", -1, 1)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.texture = texture

    -- 冷卻覆蓋
    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetDrawEdge(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.6)
    cooldown:SetHideCountdownNumbers(true)
    icon.cooldown = cooldown

    -- 持續時間文字
    local duration = icon:CreateFontString(nil, "OVERLAY")
    duration:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    duration:SetPoint("BOTTOM", 0, -2)
    duration:SetTextColor(1, 1, 1)
    icon.duration = duration

    -- 堆疊數量
    local count = icon:CreateFontString(nil, "OVERLAY")
    count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    count:SetPoint("TOPRIGHT", -1, -1)
    count:SetTextColor(1, 1, 1)
    icon.count = count

    -- 淡入動畫
    local fadeIn = icon:CreateAnimationGroup()
    local fadeAnim = fadeIn:CreateAnimation("Alpha")
    fadeAnim:SetFromAlpha(0)
    fadeAnim:SetToAlpha(1)
    fadeAnim:SetDuration(FADE_IN_DURATION)
    fadeAnim:SetOrder(1)
    icon.fadeIn = fadeIn
    icon.currentAuraName = nil  -- 追蹤目前顯示的光環名稱

    -- 減益類型邊框顏色
    icon.debuffType = nil

    -- 提示框
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(self)
        if self.auraData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetUnitAura("player", self.auraData.index, self.auraData.filter)
            GameTooltip:Show()
        end
    end)
    icon:SetScript("OnLeave", function(_self)
        GameTooltip:Hide()
    end)

    icon:Hide()
    return icon
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateAuraFrame(name, anchorPoint, offsetX, offsetY)
    -- 重載時重用現有框架
    local existingFrame = _G[name]
    local frame
    if existingFrame then
        frame = existingFrame
    else
        frame = CreateFrame("Frame", name, UIParent)
    end

    frame:SetSize(ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING, ICON_SIZE * 2 + ICON_SPACING)
    frame:SetPoint(anchorPoint, UIParent, anchorPoint, offsetX, offsetY)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    -- 拖曳支援
    frame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    return frame
end

local function SetupFrames()
    -- 增益框架 - 螢幕右上，小地圖左側（小地圖佔 TOPRIGHT ~210px 寬）
    buffFrame = CreateAuraFrame("LunarUI_BuffFrame", "TOPRIGHT", -215, -15)

    -- 減益框架 - 增益下方
    debuffFrame = CreateAuraFrame("LunarUI_DebuffFrame", "TOPRIGHT", -215, -85)

    -- 建立圖示
    for i = 1, MAX_BUFFS do
        buffIcons[i] = CreateAuraIcon(buffFrame, i)
        local row = math_floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        buffIcons[i]:SetPoint("TOPRIGHT", buffFrame, "TOPRIGHT", -col * (ICON_SIZE + ICON_SPACING), -row * (ICON_SIZE + ICON_SPACING))
    end

    for i = 1, MAX_DEBUFFS do
        debuffIcons[i] = CreateAuraIcon(debuffFrame, i)
        local row = math_floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        debuffIcons[i]:SetPoint("TOPRIGHT", debuffFrame, "TOPRIGHT", -col * (ICON_SIZE + ICON_SPACING), -row * (ICON_SIZE + ICON_SPACING))
    end
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateAuraGroup(frame, icons, maxIcons, isDebuff)
    if not frame or not frame:IsShown() then return end

    local getDataFn = isDebuff and C_UnitAuras.GetDebuffDataByIndex or C_UnitAuras.GetBuffDataByIndex
    local filter = isDebuff and "HARMFUL" or "HELPFUL"
    local visibleIndex = 0

    for i = 1, 40 do
        local auraData = getDataFn("player", i)
        if not auraData then break end

        local name = tostring(auraData.name or "")
        local icon = auraData.icon
        local count = tonumber(tostring(auraData.applications or 0)) or 0
        local duration = tonumber(tostring(auraData.duration or 0)) or 0
        local expirationTime = tonumber(tostring(auraData.expirationTime or 0)) or 0
        local source = auraData.sourceUnit

        local debuffType = isDebuff and tostring(auraData.dispelName or "") or nil
        local shouldShow
        if isDebuff then
            shouldShow = ShouldShowDebuff(name, duration, debuffType, source)
        else
            shouldShow = ShouldShowBuff(name, duration, expirationTime, auraData.isStealable, source)
        end

        if shouldShow then
            visibleIndex = visibleIndex + 1

            if visibleIndex <= maxIcons then
                local iconFrame = icons[visibleIndex]
                if iconFrame then
                    iconFrame.texture:SetTexture(icon)

                    -- 邊框顏色：減益依類型著色，增益用灰色
                    if isDebuff then
                        local color = PRIORITY_DEBUFF_TYPES[debuffType] or PRIORITY_DEBUFF_TYPES[""]
                        iconFrame:SetBackdropBorderColor(color[1], color[2], color[3], 1)
                    else
                        iconFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                    end

                    -- 堆疊
                    if count > 1 then
                        iconFrame.count:SetText(count)
                        iconFrame.count:Show()
                    else
                        iconFrame.count:Hide()
                    end

                    -- 持續時間
                    if duration > 0 and expirationTime > 0 then
                        local remaining = expirationTime - GetTime()
                        if remaining > 0 then
                            iconFrame.duration:SetText(FormatDuration(remaining))
                            iconFrame.cooldown:SetCooldown(expirationTime - duration, duration)
                        else
                            iconFrame.duration:SetText("")
                            iconFrame.cooldown:Clear()
                        end
                    else
                        iconFrame.duration:SetText("")
                        iconFrame.cooldown:Clear()
                    end

                    iconFrame.auraData = {
                        index = i,
                        filter = filter,
                    }

                    -- 淡入動畫：新出現的光環觸發
                    if iconFrame.currentAuraName ~= name then
                        iconFrame.currentAuraName = name
                        if iconFrame.fadeIn and not iconFrame:IsShown() then
                            iconFrame.fadeIn:Play()
                        end
                    end

                    iconFrame:Show()
                end
            end
        end
    end

    -- 隱藏多餘的圖示並清除追蹤
    for i = visibleIndex + 1, maxIcons do
        if icons[i] then
            icons[i]:Hide()
            icons[i].currentAuraName = nil
        end
    end
end

local function UpdateAuras()
    UpdateAuraGroup(buffFrame, buffIcons, MAX_BUFFS, false)
    UpdateAuraGroup(debuffFrame, debuffIcons, MAX_DEBUFFS, true)
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local function UpdateForPhase()
    if not buffFrame or not debuffFrame then return end

    -- 使用共用函數套用至兩個框架
    local alpha = LunarUI:ApplyPhaseAlpha(buffFrame, "auraFrames")
    LunarUI:ApplyPhaseAlpha(debuffFrame, "auraFrames")

    -- 額外邏輯：可見時更新光環
    if alpha > 0 then
        UpdateAuras()
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function HideBlizzardBuffFrames()
    -- 隱藏暴雪獨立的增益/減益框架（右上角）
    -- 注意：oUF 只隱藏 PlayerFrame.BuffFrame（頭像附屬的），不隱藏全域 BuffFrame
    local blizzardBuffFrame = _G.BuffFrame
    if blizzardBuffFrame then
        pcall(function() blizzardBuffFrame:UnregisterAllEvents() end)
        pcall(function() blizzardBuffFrame:Hide() end)
        pcall(function() blizzardBuffFrame:SetAlpha(0) end)
        -- 防止暴雪代碼重新顯示
        pcall(function()
            hooksecurefunc(blizzardBuffFrame, "Show", function(self)
                self:Hide()
            end)
        end)
    end

    local blizzardDebuffFrame = _G.DebuffFrame
    if blizzardDebuffFrame then
        pcall(function() blizzardDebuffFrame:UnregisterAllEvents() end)
        pcall(function() blizzardDebuffFrame:Hide() end)
        pcall(function() blizzardDebuffFrame:SetAlpha(0) end)
        pcall(function()
            hooksecurefunc(blizzardDebuffFrame, "Show", function(self)
                self:Hide()
            end)
        end)
    end
end

local function Initialize()
    if isInitialized then return end

    -- 先隱藏暴雪原生 Buff 框架，避免重複顯示
    HideBlizzardBuffFrames()

    SetupFrames()

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

-- 停用：不再註冊事件
local eventFrame = CreateFrame("Frame")
-- eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- eventFrame:RegisterEvent("UNIT_AURA")

-- 效能優化：UNIT_AURA 節流（戰鬥中每秒可觸發數十次）
local auraDirty = false
local AURA_THROTTLE = 0.1  -- 最少間隔 0.1 秒
local lastAuraUpdate = 0

eventFrame:SetScript("OnEvent", function(_self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, Initialize)
    elseif event == "UNIT_AURA" then
        if arg1 == "player" and isInitialized then
            auraDirty = true
        end
    end
end)

-- 使用 OnUpdate 做節流更新
eventFrame:SetScript("OnUpdate", function(_self, _elapsed)
    if not auraDirty then return end
    local now = GetTime()
    if now - lastAuraUpdate < AURA_THROTTLE then return end
    auraDirty = false
    lastAuraUpdate = now
    UpdateAuras()
end)

--------------------------------------------------------------------------------
-- 匯出函數
--------------------------------------------------------------------------------

function LunarUI.ShowAuraFrames()
    if buffFrame then buffFrame:Show() end
    if debuffFrame then debuffFrame:Show() end
end

function LunarUI.HideAuraFrames()
    if buffFrame then buffFrame:Hide() end
    if debuffFrame then debuffFrame:Hide() end
end

function LunarUI.RefreshAuraFrames()
    UpdateAuras()
end

-- 清理函數
function LunarUI.CleanupAuraFrames()
    if buffFrame then buffFrame:Hide() end
    if debuffFrame then debuffFrame:Hide() end
    eventFrame:UnregisterAllEvents()
end

-- 停用自訂 Buff/Debuff 框架，使用暴雪內建 BuffFrame
-- hooksecurefunc(LunarUI, "OnEnable", function()
--     C_Timer.After(1.5, Initialize)
-- end)
