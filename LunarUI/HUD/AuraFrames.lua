---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if, unused-local
--[[
    LunarUI - Buff/Debuff 框架（重新設計）
    在螢幕上顯示玩家的增益和減益效果

    功能：
    - 大圖示（40px）+ 倒數計時條
    - 分類標籤（增益 / 減益）
    - 智慧過濾（隱藏食物等瑣碎 Buff）
    - 減益類型著色（魔法/詛咒/疾病/毒）
    - 淡入動畫
    - 月相感知
    - 框架移動器整合
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 效能：快取全域變數
--------------------------------------------------------------------------------

local math_floor = math.floor
local string_format = string.format
local GetTime = GetTime
local C_UnitAuras = C_UnitAuras
local ipairs = ipairs

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local ICON_SIZE = 40
local ICON_SPACING = 4
local ICONS_PER_ROW = 8
local MAX_BUFFS = 16
local MAX_DEBUFFS = 8

-- 倒數計時條
local BAR_HEIGHT = 4
local BAR_OFFSET = 1  -- 圖示與計時條間距

-- 過濾的 Buff 名稱（瑣碎增益）
local FILTERED_BUFF_NAMES = {
    -- 食物 / 休息
    ["充分休息"] = true,
    ["Well Rested"] = true,
    -- 死亡後虛弱
    ["復活虛弱"] = true,
    ["Resurrection Sickness"] = true,
}

-- 減益類型顏色
local DEBUFF_TYPE_COLORS = {
    Magic   = { 0.2, 0.6, 1.0 },   -- 藍色
    Curse   = { 0.6, 0.0, 1.0 },   -- 紫色
    Disease = { 0.6, 0.4, 0.0 },   -- 棕色
    Poison  = { 0.0, 0.6, 0.0 },   -- 綠色
    [""]    = { 0.8, 0.0, 0.0 },   -- 紅色（無類型）
}

-- 計時條顏色（依剩餘時間）
local function GetTimerBarColor(remaining, duration)
    if duration <= 0 then return 0.5, 0.5, 0.5 end
    local pct = remaining / duration
    if pct > 0.5 then
        return 0.2, 0.7, 0.2  -- 綠色
    elseif pct > 0.2 then
        return 0.9, 0.7, 0.1  -- 黃色
    else
        return 0.9, 0.2, 0.2  -- 紅色
    end
end

local backdropTemplate = LunarUI.iconBackdropTemplate

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local buffFrame = nil
local debuffFrame = nil
local buffIcons = {}
local debuffIcons = {}
local isInitialized = false

local auraDirty = false
local AURA_THROTTLE = 0.1
local lastAuraUpdate = 0

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

local function ShouldShowBuff(name, duration)
    if FILTERED_BUFF_NAMES[name] then
        return false
    end
    -- 月相過濾：NEW 月相只顯示短期 Buff
    local phase = LunarUI:GetPhase()
    if phase == "NEW" then
        local dur = tonumber(duration) or 0
        if dur == 0 or dur > 300 then
            return false
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- 圖示建立
--------------------------------------------------------------------------------

local function CreateAuraIcon(parent, index)
    local totalHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT

    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(ICON_SIZE, totalHeight)

    -- 圖示背景
    icon:SetBackdrop(backdropTemplate)
    icon:SetBackdropColor(0.08, 0.08, 0.08, 0.85)
    icon:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.8)

    -- 圖示紋理
    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", 1, -1)
    texture:SetPoint("TOPRIGHT", -1, -1)
    texture:SetHeight(ICON_SIZE - 2)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.texture = texture

    -- 冷卻旋轉覆蓋
    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetPoint("TOPLEFT", 1, -1)
    cooldown:SetPoint("TOPRIGHT", -1, -1)
    cooldown:SetHeight(ICON_SIZE - 2)
    cooldown:SetDrawEdge(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.6)
    cooldown:SetHideCountdownNumbers(true)
    icon.cooldown = cooldown

    -- 倒數計時條背景
    local barBg = icon:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("BOTTOMLEFT", 1, 1)
    barBg:SetPoint("BOTTOMRIGHT", -1, 1)
    barBg:SetHeight(BAR_HEIGHT)
    barBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    barBg:SetVertexColor(0, 0, 0, 0.6)
    icon.barBg = barBg

    -- 倒數計時條前景
    local bar = icon:CreateTexture(nil, "ARTWORK", nil, 1)
    bar:SetPoint("BOTTOMLEFT", 1, 1)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetVertexColor(0.2, 0.7, 0.2)
    bar:SetWidth(ICON_SIZE - 2)
    icon.bar = bar

    -- 持續時間文字（隱藏，只靠計時條和冷卻旋轉顯示）
    local durationText = icon:CreateFontString(nil, "OVERLAY")
    durationText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    durationText:SetPoint("BOTTOM", icon, "BOTTOM", 0, BAR_HEIGHT + BAR_OFFSET + 1)
    durationText:SetTextColor(1, 1, 1)
    durationText:SetShadowOffset(1, -1)
    durationText:Hide()
    icon.duration = durationText

    -- 堆疊數量
    local count = icon:CreateFontString(nil, "OVERLAY")
    count:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    count:SetPoint("TOPRIGHT", -1, -1)
    count:SetTextColor(1, 0.9, 0.5)
    icon.count = count

    -- 淡入動畫
    local fadeIn = icon:CreateAnimationGroup()
    local fadeAnim = fadeIn:CreateAnimation("Alpha")
    fadeAnim:SetFromAlpha(0)
    fadeAnim:SetToAlpha(1)
    fadeAnim:SetDuration(0.25)
    fadeAnim:SetOrder(1)
    icon.fadeIn = fadeIn
    icon.currentAuraName = nil

    -- 光環資料（供 Tooltip 使用）
    icon.auraData = nil

    -- Tooltip
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(self)
        if self.auraData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetUnitAura("player", self.auraData.index, self.auraData.filter)
            GameTooltip:Show()
        end
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 右鍵取消 Buff
    icon:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.auraData and self.auraData.filter == "HELPFUL" then
            -- WoW 12.0+：使用 C_UnitAuras.CancelAuraByIndex 或回退到舊 API
            if C_UnitAuras and C_UnitAuras.CancelAuraByIndex then
                pcall(C_UnitAuras.CancelAuraByIndex, "player", self.auraData.index)
            elseif _G.CancelUnitBuff then
                pcall(_G.CancelUnitBuff, "player", self.auraData.index, self.auraData.filter)
            end
        end
    end)

    icon:Hide()
    return icon
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateAuraFrame(name, label, anchorPoint, offsetX, offsetY)
    local existingFrame = _G[name]
    local frame
    if existingFrame then
        frame = existingFrame
        -- 清除舊的子物件（避免重載時重複）
        for _, child in ipairs({frame:GetRegions()}) do
            if child.lunarLabel then child:Show() end
        end
    else
        frame = CreateFrame("Frame", name, UIParent)
    end

    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT
    frame:SetSize(
        ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING,
        totalIconHeight * 2 + ICON_SPACING + 16  -- 16 = 標籤高度
    )
    frame:SetPoint(anchorPoint, UIParent, anchorPoint, offsetX, offsetY)
    frame:SetFrameStrata("MEDIUM")

    -- 分類標籤（隱藏，只顯示圖示）
    if not frame.label then
        local labelText = frame:CreateFontString(nil, "OVERLAY")
        labelText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        labelText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        labelText:SetTextColor(0.7, 0.7, 0.7, 0.8)
        labelText:SetText(label)
        labelText.lunarLabel = true
        labelText:Hide()
        frame.label = labelText
    end

    return frame
end

local function SetupFrames()
    -- 增益框架 - 螢幕右上
    buffFrame = CreateAuraFrame("LunarUI_BuffFrame", "增益", "TOPRIGHT", -215, -10)

    -- 減益框架 - 增益下方
    local buffHeight = buffFrame:GetHeight()
    debuffFrame = CreateAuraFrame("LunarUI_DebuffFrame", "減益", "TOPRIGHT", -215, -10 - buffHeight - 6)

    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT

    -- 建立 Buff 圖示（從右到左排列）
    for i = 1, MAX_BUFFS do
        buffIcons[i] = CreateAuraIcon(buffFrame, i)
        local row = math_floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        buffIcons[i]:SetPoint(
            "TOPRIGHT", buffFrame, "TOPRIGHT",
            -col * (ICON_SIZE + ICON_SPACING),
            -(row * (totalIconHeight + ICON_SPACING)) - 16  -- 16 = 標籤下方偏移
        )
    end

    -- 建立 Debuff 圖示
    for i = 1, MAX_DEBUFFS do
        debuffIcons[i] = CreateAuraIcon(debuffFrame, i)
        local row = math_floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        debuffIcons[i]:SetPoint(
            "TOPRIGHT", debuffFrame, "TOPRIGHT",
            -col * (ICON_SIZE + ICON_SPACING),
            -(row * (totalIconHeight + ICON_SPACING)) - 16
        )
    end
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateAuraIcon(iconFrame, auraData, index, filter, isDebuff)
    local name = tostring(auraData.name or "")
    local iconTexture = auraData.icon
    local count = tonumber(tostring(auraData.applications or 0)) or 0
    local duration = tonumber(tostring(auraData.duration or 0)) or 0
    local expirationTime = tonumber(tostring(auraData.expirationTime or 0)) or 0

    -- 圖示紋理
    iconFrame.texture:SetTexture(iconTexture)

    -- 邊框顏色
    if isDebuff then
        local debuffType = tostring(auraData.dispelName or "")
        local color = DEBUFF_TYPE_COLORS[debuffType] or DEBUFF_TYPE_COLORS[""]
        iconFrame:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    else
        iconFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.8)
    end

    -- 堆疊數量
    if count > 1 then
        iconFrame.count:SetText(count)
        iconFrame.count:Show()
    else
        iconFrame.count:Hide()
    end

    -- 計時條
    if duration > 0 and expirationTime > 0 then
        local remaining = expirationTime - GetTime()
        if remaining > 0 then
            -- 計時條寬度
            local pct = remaining / duration
            local barWidth = (ICON_SIZE - 2) * pct
            if barWidth < 1 then barWidth = 1 end
            iconFrame.bar:SetWidth(barWidth)

            -- 計時條顏色
            local r, g, b = GetTimerBarColor(remaining, duration)
            iconFrame.bar:SetVertexColor(r, g, b)
            iconFrame.bar:Show()
            iconFrame.barBg:Show()

            -- 冷卻旋轉
            iconFrame.cooldown:SetCooldown(expirationTime - duration, duration)
        else
            iconFrame.duration:SetText("")
            iconFrame.bar:Hide()
            iconFrame.barBg:Hide()
            iconFrame.cooldown:Clear()
        end
    else
        -- 永久 Buff（無持續時間）
        iconFrame.duration:SetText("")
        iconFrame.bar:Hide()
        iconFrame.barBg:Hide()
        iconFrame.cooldown:Clear()
    end

    -- Tooltip 資料
    iconFrame.auraData = {
        index = index,
        filter = filter,
    }

    -- 淡入動畫
    if iconFrame.currentAuraName ~= name then
        iconFrame.currentAuraName = name
        if iconFrame.fadeIn and not iconFrame:IsShown() then
            iconFrame.fadeIn:Play()
        end
    end

    iconFrame:Show()
end

local function UpdateAuraGroup(icons, maxIcons, isDebuff)
    local getDataFn = isDebuff and C_UnitAuras.GetDebuffDataByIndex or C_UnitAuras.GetBuffDataByIndex
    local filter = isDebuff and "HARMFUL" or "HELPFUL"
    local visibleIndex = 0

    for i = 1, 40 do
        local auraData = getDataFn("player", i)
        if not auraData then break end

        local name = tostring(auraData.name or "")
        local duration = tonumber(tostring(auraData.duration or 0)) or 0

        local shouldShow
        if isDebuff then
            shouldShow = true  -- 減益都顯示
        else
            shouldShow = ShouldShowBuff(name, duration)
        end

        if shouldShow then
            visibleIndex = visibleIndex + 1
            if visibleIndex <= maxIcons then
                UpdateAuraIcon(icons[visibleIndex], auraData, i, filter, isDebuff)
            end
        end
    end

    -- 隱藏多餘圖示
    for i = visibleIndex + 1, maxIcons do
        if icons[i] then
            icons[i]:Hide()
            icons[i].currentAuraName = nil
        end
    end
end

local function UpdateAuras()
    if not buffFrame or not debuffFrame then return end
    if not buffFrame:IsShown() and not debuffFrame:IsShown() then return end

    UpdateAuraGroup(buffIcons, MAX_BUFFS, false)
    UpdateAuraGroup(debuffIcons, MAX_DEBUFFS, true)
end

-- 計時條即時更新（每幀更新計時條寬度和顏色）
local function UpdateTimerBars()
    local now = GetTime()

    local function UpdateIconTimers(icons, maxIcons)
        for i = 1, maxIcons do
            local iconFrame = icons[i]
            if not iconFrame or not iconFrame:IsShown() then break end
            if not iconFrame.auraData then break end

            -- 從冷卻框架反推持續時間
            local start, dur = iconFrame.cooldown:GetCooldownTimes()
            if start and dur and start > 0 and dur > 0 then
                start = start / 1000  -- GetCooldownTimes 回傳毫秒
                dur = dur / 1000
                local remaining = (start + dur) - now
                if remaining > 0 then
                    local pct = remaining / dur
                    local barWidth = (ICON_SIZE - 2) * pct
                    if barWidth < 1 then barWidth = 1 end
                    iconFrame.bar:SetWidth(barWidth)
                    local r, g, b = GetTimerBarColor(remaining, dur)
                    iconFrame.bar:SetVertexColor(r, g, b)
                else
                    iconFrame.bar:Hide()
                end
            end
        end
    end

    UpdateIconTimers(buffIcons, MAX_BUFFS)
    UpdateIconTimers(debuffIcons, MAX_DEBUFFS)
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local function UpdateForPhase()
    if not buffFrame or not debuffFrame then return end

    local alpha = LunarUI:ApplyPhaseAlpha(buffFrame, "auraFrames")
    LunarUI:ApplyPhaseAlpha(debuffFrame, "auraFrames")

    if alpha > 0 then
        UpdateAuras()
    end
end

--------------------------------------------------------------------------------
-- 暴雪框架隱藏
--------------------------------------------------------------------------------

local function HideBlizzardBuffFrames()
    local blizzardBuffFrame = _G.BuffFrame
    if blizzardBuffFrame then
        pcall(function() blizzardBuffFrame:UnregisterAllEvents() end)
        pcall(function() blizzardBuffFrame:Hide() end)
        pcall(function() blizzardBuffFrame:SetAlpha(0) end)
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

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function Initialize()
    if isInitialized then return end

    HideBlizzardBuffFrames()
    SetupFrames()

    -- 註冊至框架移動器
    if buffFrame then
        LunarUI:RegisterMovableFrame("BuffFrame", buffFrame, "增益框架")
    end
    if debuffFrame then
        LunarUI:RegisterMovableFrame("DebuffFrame", debuffFrame, "減益框架")
    end

    -- 月相回呼
    LunarUI:RegisterPhaseCallback(function()
        UpdateForPhase()
    end)

    UpdateForPhase()
    isInitialized = true
end

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function(_self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, Initialize)
    elseif event == "UNIT_AURA" then
        if arg1 == "player" and isInitialized then
            auraDirty = true
        end
    end
end)

-- 節流更新 + 計時條即時更新
local timerElapsed = 0
local TIMER_UPDATE_INTERVAL = 0.05  -- 計時條 20 FPS

eventFrame:SetScript("OnUpdate", function(_self, elapsed)
    -- 光環資料節流更新
    if auraDirty then
        local now = GetTime()
        if now - lastAuraUpdate >= AURA_THROTTLE then
            auraDirty = false
            lastAuraUpdate = now
            UpdateAuras()
        end
    end

    -- 計時條平滑更新
    if isInitialized then
        timerElapsed = timerElapsed + elapsed
        if timerElapsed >= TIMER_UPDATE_INTERVAL then
            timerElapsed = 0
            UpdateTimerBars()
        end
    end
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

function LunarUI.CleanupAuraFrames()
    if buffFrame then buffFrame:Hide() end
    if debuffFrame then debuffFrame:Hide() end
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnUpdate", nil)
end

-- 啟用自訂 Buff/Debuff 框架
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(1.5, Initialize)
end)
