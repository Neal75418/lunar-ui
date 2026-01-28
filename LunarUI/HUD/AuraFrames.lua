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

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function FormatDuration(seconds)
    if seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    elseif seconds >= 10 then
        return string.format("%d", math.floor(seconds))
    else
        return string.format("%.1f", seconds)
    end
end

local function ShouldShowBuff(name, duration, _expirationTime, _isStealable, _source)
    -- 過濾瑣碎 Buff
    if FILTERED_BUFF_NAMES[name] then
        return false
    end

    -- 月相過濾：NEW 月相只顯示重要 Buff
    local phase = LunarUI:GetPhase()
    if phase == "NEW" then
        -- 只顯示短期 Buff（可能是戰鬥相關）
        if duration == 0 or duration > 300 then
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

    -- 背景
    icon:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
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
    -- 增益框架 - 螢幕右上
    buffFrame = CreateAuraFrame("LunarUI_BuffFrame", "TOPRIGHT", -200, -30)

    -- 減益框架 - 增益下方
    debuffFrame = CreateAuraFrame("LunarUI_DebuffFrame", "TOPRIGHT", -200, -100)

    -- 建立圖示
    for i = 1, MAX_BUFFS do
        buffIcons[i] = CreateAuraIcon(buffFrame, i)
        local row = math.floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        buffIcons[i]:SetPoint("TOPRIGHT", buffFrame, "TOPRIGHT", -col * (ICON_SIZE + ICON_SPACING), -row * (ICON_SIZE + ICON_SPACING))
    end

    for i = 1, MAX_DEBUFFS do
        debuffIcons[i] = CreateAuraIcon(debuffFrame, i)
        local row = math.floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        debuffIcons[i]:SetPoint("TOPRIGHT", debuffFrame, "TOPRIGHT", -col * (ICON_SIZE + ICON_SPACING), -row * (ICON_SIZE + ICON_SPACING))
    end
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateBuffs()
    if not buffFrame or not buffFrame:IsShown() then return end

    local visibleIndex = 0

    for i = 1, 40 do
        local auraData = C_UnitAuras.GetBuffDataByIndex("player", i)
        if not auraData then break end

        local name = auraData.name
        local icon = auraData.icon
        local count = auraData.applications or 0
        local duration = auraData.duration or 0
        local expirationTime = auraData.expirationTime or 0
        local source = auraData.sourceUnit
        local isStealable = auraData.isStealable

        if ShouldShowBuff(name, duration, expirationTime, isStealable, source) then
            visibleIndex = visibleIndex + 1

            if visibleIndex <= MAX_BUFFS then
                local iconFrame = buffIcons[visibleIndex]
                if iconFrame then
                    iconFrame.texture:SetTexture(icon)
                    iconFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

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
                        filter = "HELPFUL",
                    }
                    iconFrame:Show()
                end
            end
        end
    end

    -- 隱藏多餘的圖示
    for i = visibleIndex + 1, MAX_BUFFS do
        if buffIcons[i] then
            buffIcons[i]:Hide()
        end
    end
end

local function UpdateDebuffs()
    if not debuffFrame or not debuffFrame:IsShown() then return end

    local visibleIndex = 0

    for i = 1, 40 do
        local auraData = C_UnitAuras.GetDebuffDataByIndex("player", i)
        if not auraData then break end

        local name = auraData.name
        local icon = auraData.icon
        local count = auraData.applications or 0
        local duration = auraData.duration or 0
        local expirationTime = auraData.expirationTime or 0
        local debuffType = auraData.dispelName or ""
        local source = auraData.sourceUnit

        if ShouldShowDebuff(name, duration, debuffType, source) then
            visibleIndex = visibleIndex + 1

            if visibleIndex <= MAX_DEBUFFS then
                local iconFrame = debuffIcons[visibleIndex]
                if iconFrame then
                    iconFrame.texture:SetTexture(icon)

                    -- 減益類型邊框顏色
                    local color = PRIORITY_DEBUFF_TYPES[debuffType] or PRIORITY_DEBUFF_TYPES[""]
                    iconFrame:SetBackdropBorderColor(color[1], color[2], color[3], 1)

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
                        filter = "HARMFUL",
                    }
                    iconFrame:Show()
                end
            end
        end
    end

    -- 隱藏多餘的圖示
    for i = visibleIndex + 1, MAX_DEBUFFS do
        if debuffIcons[i] then
            debuffIcons[i]:Hide()
        end
    end
end

local function UpdateAuras()
    UpdateBuffs()
    UpdateDebuffs()
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local PHASE_ALPHA = {
    NEW = 0.4,
    WAXING = 0.7,
    FULL = 1.0,
    WANING = 0.8,
}

local function UpdateForPhase()
    if not buffFrame or not debuffFrame then return end

    local phase = LunarUI:GetPhase()
    local alpha = PHASE_ALPHA[phase] or 1

    -- 檢查設定
    local db = LunarUI.db and LunarUI.db.profile.hud
    if db and db.auraFrames == false then
        alpha = 0
    end

    buffFrame:SetAlpha(alpha)
    debuffFrame:SetAlpha(alpha)

    if alpha > 0 then
        buffFrame:Show()
        debuffFrame:Show()
        UpdateAuras()
    else
        buffFrame:Hide()
        debuffFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function Initialize()
    if isInitialized then return end

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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function(_self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, Initialize)
    elseif event == "UNIT_AURA" then
        if arg1 == "player" and isInitialized then
            UpdateAuras()
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

-- 清理函數
function LunarUI.CleanupAuraFrames()
    if buffFrame then buffFrame:Hide() end
    if debuffFrame then debuffFrame:Hide() end
    eventFrame:UnregisterAllEvents()
end

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(1.5, Initialize)
end)
