---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 單位框架施法條
    施法條建構、引導法術 tick、強化施法階段標記
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local C = LunarUI.Colors
local CASTBAR_COLOR = LunarUI.CASTBAR_COLOR

--------------------------------------------------------------------------------
-- 引導法術 tick 數據表
--------------------------------------------------------------------------------

-- 引導法術 tick 數據表（spellID → tick 數量）
-- 常見引導法術的 tick 數，用於在施法條上繪製 tick 分隔線
local CHANNEL_TICKS = {
    -- 牧師
    [47540] = 3, -- 苦修
    [64843] = 4, -- 神聖讚美詩
    [15407] = 6, -- 精神鞭笞
    -- 法師
    [5143] = 5, -- 奧術飛彈
    [12051] = 3, -- 喚醒
    [205021] = 5, -- 冰霜射線
    -- 術士
    [198590] = 6, -- 吸取靈魂
    [234153] = 5, -- 吸取生命
    -- 德魯伊
    [740] = 4, -- 寧靜
    -- 武僧
    [117952] = 4, -- 碎玉疾風
    [191837] = 3, -- 精華之泉
}

local MAX_TICKS = 10

--------------------------------------------------------------------------------
-- Tick / Stage 輔助函數
--------------------------------------------------------------------------------

local function HideAllTicks(castbar)
    if not castbar._ticks then
        return
    end
    for i = 1, MAX_TICKS do
        if castbar._ticks[i] then
            castbar._ticks[i]:Hide()
        end
    end
end

local function ShowTickMarks(castbar, numTicks)
    if not castbar._ticks then
        castbar._ticks = {}
    end
    HideAllTicks(castbar)

    if numTicks <= 1 then
        return
    end

    local cbWidth = castbar:GetWidth()
    if cbWidth <= 0 then
        HideAllTicks(castbar)
        return
    end

    for i = 1, numTicks - 1 do
        local tick = castbar._ticks[i]
        if not tick then
            tick = castbar:CreateTexture(nil, "OVERLAY", nil, 7)
            tick:SetWidth(1)
            tick:SetColorTexture(1, 1, 1, 0.6)
            castbar._ticks[i] = tick
        end
        tick:SetHeight(castbar:GetHeight())
        local pct = i / numTicks
        tick:ClearAllPoints()
        tick:SetPoint("LEFT", castbar, "LEFT", cbWidth * pct, 0)
        tick:Show()
    end
end

-- #5: 提升至模組層級，避免 CreateCastbar 每次呼叫產生新 closure（~15 unit frames）
local function HideAllStages(cb)
    if cb._stages then
        for i = 1, MAX_TICKS do
            if cb._stages[i] then
                cb._stages[i]:Hide()
            end
        end
    end
end

-- 強化施法階段標記
local function ShowEmpoweredStages(castbar, numStages)
    if not castbar._stages then
        castbar._stages = {}
    end

    -- 隱藏舊的
    for i = 1, MAX_TICKS do
        if castbar._stages[i] then
            castbar._stages[i]:Hide()
        end
    end

    if not numStages or numStages <= 1 then
        return
    end

    numStages = math.min(numStages, MAX_TICKS) -- 防止超出 _stages 上限導致無法隱藏的洩漏

    local cbWidth = castbar:GetWidth()
    if cbWidth <= 0 then
        HideAllStages(castbar)
        return
    end

    for i = 1, numStages do
        local stage = castbar._stages[i]
        if not stage then
            stage = castbar:CreateTexture(nil, "OVERLAY", nil, 7)
            stage:SetWidth(2)
            stage:SetColorTexture(1, 0.82, 0, 0.8)
            castbar._stages[i] = stage
        end
        stage:SetHeight(castbar:GetHeight())
        local pct = i / (numStages + 1)
        stage:ClearAllPoints()
        stage:SetPoint("LEFT", castbar, "LEFT", cbWidth * pct, 0)
        stage:Show()
    end
end

--------------------------------------------------------------------------------
-- 施法條建構
--------------------------------------------------------------------------------

local function CreateCastbar(frame, unit)
    local GetStatusBarTexture = LunarUI.UFGetStatusBarTexture
    local isPlayer = (unit == "player")
    local unitKey = unit and unit:gsub("%d+$", "") or "player"
    local ufAll = LunarUI.GetModuleDB("unitframes")
    local ufDB = ufAll and ufAll[unitKey]
    local cbDB = ufDB and ufDB.castbar or {}
    local cbHeight = cbDB.height or 16

    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(GetStatusBarTexture())
    castbar:SetStatusBarColor(unpack(CASTBAR_COLOR))

    -- 位於主框架下方
    castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
    castbar:SetHeight(cbHeight)

    -- 背景
    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(GetStatusBarTexture())
    bg:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    castbar.bg = bg

    -- 邊框
    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetAllPoints()
    LunarUI.ApplyBackdrop(border, nil, C.transparent)

    -- 法術圖示
    local icon = castbar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", castbar, "LEFT", 2, 0)
    icon:SetTexCoord(unpack(LunarUI.ICON_TEXCOORD))
    castbar.Icon = icon

    -- 法術名稱
    local text = castbar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(text, 10, "OUTLINE")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetJustifyH("LEFT")
    castbar.Text = text

    -- 施法時間
    local time = castbar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(time, 10, "OUTLINE")
    time:SetPoint("RIGHT", castbar, "RIGHT", -4, 0)
    time:SetJustifyH("RIGHT")
    castbar.Time = time

    -- 玩家施法條：延遲指示區
    local showLatency = cbDB.showLatency ~= false
    if isPlayer and showLatency then
        local latency = castbar:CreateTexture(nil, "OVERLAY", nil, 6)
        latency:SetColorTexture(0.8, 0.2, 0.2, 0.5)
        latency:SetHeight(castbar:GetHeight())
        latency:SetPoint("TOPRIGHT", castbar:GetStatusBarTexture(), "TOPRIGHT")
        latency:SetPoint("BOTTOMRIGHT", castbar:GetStatusBarTexture(), "BOTTOMRIGHT")
        latency:Hide()
        castbar._latency = latency
    end

    local showTicks = cbDB.showTicks ~= false
    local showEmpowered = cbDB.showEmpowered ~= false

    -- WoW 12.0 將 notInterruptible 設為隱藏值
    -- 暴雪故意限制插件存取此資訊
    -- 使用統一的施法條顏色（無法判斷是否可打斷）
    --
    -- oUF 對所有施法類型（普通/引導/強化）統一呼叫 PostCastStart，
    -- 透過 self.channeling / self.empowering / self.spellID 判斷類型
    castbar.PostCastStart = function(self, _unit)
        HideAllTicks(self)
        HideAllStages(self)

        if self.channeling then
            -- 引導法術：顯示 tick 標記、隱藏延遲
            self:SetStatusBarColor(unpack(CASTBAR_COLOR))
            if showTicks then
                local numTicks = self.spellID and CHANNEL_TICKS[self.spellID]
                if numTicks then
                    ShowTickMarks(self, numTicks)
                end
            end
            if self._latency then
                self._latency:Hide()
            end
        elseif self.empowering then
            -- Evoker 強化施法：紫色標識（階段標記由 UpdatePips 處理）
            self:SetStatusBarColor(0.6, 0.4, 0.9, 1)
            if self._latency then
                self._latency:Hide()
            end
        else
            -- 普通施法：顯示延遲
            self:SetStatusBarColor(unpack(CASTBAR_COLOR))
            if self._latency then
                local _, _, _, latencyWorld = GetNetStats()
                if latencyWorld and latencyWorld > 0 then
                    local castTime = self.max or 0
                    if castTime > 0 then
                        local latencyPct = (latencyWorld / 1000) / castTime
                        latencyPct = math.min(latencyPct, 0.5) -- 上限 50%
                        self._latency:SetWidth(self:GetWidth() * latencyPct)
                        self._latency:Show()
                    else
                        self._latency:Hide()
                    end
                else
                    self._latency:Hide()
                end
            end
        end
    end

    -- Evoker 強化施法階段標記（oUF 呼叫 UpdatePips 傳入各階段百分比）
    if isPlayer and showEmpowered then
        castbar.UpdatePips = function(self, stages)
            if not stages or #stages == 0 then
                return
            end
            ShowEmpoweredStages(self, #stages)
        end
    end

    castbar.PostCastStop = function(self)
        HideAllTicks(self)
        HideAllStages(self)
        if self._latency then
            self._latency:Hide()
        end
    end

    -- 火花
    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(20, 20)
    spark:SetBlendMode("ADD")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    castbar.Spark = spark

    frame.Castbar = castbar
    return castbar
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.UFCreateCastbar = CreateCastbar
LunarUI.CHANNEL_TICKS = CHANNEL_TICKS
