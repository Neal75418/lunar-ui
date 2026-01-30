---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
--[[
    LunarUI - 效能監控
    顯示 FPS 與延遲資訊

    功能：
    - FPS 即時顯示
    - 本地/世界延遲顯示
    - 月相感知（NEW 隱藏，FULL 顯示）
    - 可拖曳位置
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local perfFrame = nil
local updateInterval = 0.5  -- 更新間隔（秒）
local elapsed = 0

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 延遲門檻（毫秒）
local LATENCY_THRESHOLDS = {
    good = 100,    -- 綠色
    medium = 200,  -- 黃色
    bad = 400,     -- 紅色
}

-- 效能監控專用透明度（停用月相：全部顯示）
local PERF_PHASE_ALPHA = {
    NEW = 1.0,
    WAXING = 1.0,
    FULL = 1.0,
    WANING = 1.0,
}

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function GetLatencyColor(ms)
    if ms <= LATENCY_THRESHOLDS.good then
        return 0.2, 0.8, 0.2  -- 綠色
    elseif ms <= LATENCY_THRESHOLDS.medium then
        return 0.9, 0.9, 0.2  -- 黃色
    elseif ms <= LATENCY_THRESHOLDS.bad then
        return 0.9, 0.5, 0.1  -- 橙色
    else
        return 0.9, 0.2, 0.2  -- 紅色
    end
end

local function GetFPSColor(fps)
    if fps >= 60 then
        return 0.2, 0.8, 0.2  -- 綠色
    elseif fps >= 30 then
        return 0.9, 0.9, 0.2  -- 黃色
    elseif fps >= 15 then
        return 0.9, 0.5, 0.1  -- 橙色
    else
        return 0.9, 0.2, 0.2  -- 紅色
    end
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreatePerfFrame()
    if perfFrame then return perfFrame end

    -- 重載時重用現有框架
    local existingFrame = _G["LunarUI_PerformanceMonitor"]
    if existingFrame then
        perfFrame = existingFrame
        perfFrame:SetScript("OnUpdate", nil)
    else
        perfFrame = CreateFrame("Frame", "LunarUI_PerformanceMonitor", UIParent, "BackdropTemplate")
    end

    perfFrame:SetSize(100, 36)
    perfFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -100)
    perfFrame:SetFrameStrata("HIGH")
    perfFrame:SetMovable(true)
    perfFrame:EnableMouse(true)
    perfFrame:RegisterForDrag("LeftButton")
    perfFrame:SetClampedToScreen(true)

    -- 拖曳支援
    perfFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    perfFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- 背景樣式
    perfFrame:SetBackdrop(LunarUI.iconBackdropTemplate)
    perfFrame:SetBackdropColor(0, 0, 0, 0.6)
    perfFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.8)

    -- FPS 文字
    local fpsText = perfFrame:CreateFontString(nil, "OVERLAY")
    fpsText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    fpsText:SetPoint("TOPLEFT", 6, -6)
    fpsText:SetJustifyH("LEFT")
    perfFrame.fpsText = fpsText

    -- 延遲文字
    local latencyText = perfFrame:CreateFontString(nil, "OVERLAY")
    latencyText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    latencyText:SetPoint("TOPLEFT", 6, -20)
    latencyText:SetJustifyH("LEFT")
    perfFrame.latencyText = latencyText

    -- 提示
    perfFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cff8882ffLunarUI|r 效能監控")
        GameTooltip:AddLine(" ")

        local fps = GetFramerate()
        local _, _, homeMs, worldMs = GetNetStats()

        GameTooltip:AddDoubleLine("FPS", string.format("%.0f", fps), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine("本地延遲", string.format("%d ms", homeMs), 0.7, 0.7, 0.7, GetLatencyColor(homeMs))
        GameTooltip:AddDoubleLine("世界延遲", string.format("%d ms", worldMs), 0.7, 0.7, 0.7, GetLatencyColor(worldMs))

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Shift+拖曳 移動位置", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)

    perfFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return perfFrame
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdatePerformance()
    if not perfFrame then return end

    -- 取得效能資訊
    local fps = GetFramerate()
    local _, _, homeMs, worldMs = GetNetStats()

    -- 更新 FPS
    local r, g, b = GetFPSColor(fps)
    perfFrame.fpsText:SetFormattedText("|cff888888FPS:|r %.0f", fps)
    perfFrame.fpsText:SetTextColor(r, g, b)

    -- 更新延遲（顯示較高的那個）
    local latency = math.max(homeMs, worldMs)
    r, g, b = GetLatencyColor(latency)
    perfFrame.latencyText:SetFormattedText("|cff888888MS:|r %d", latency)
    perfFrame.latencyText:SetTextColor(r, g, b)
end

local function StartUpdating()
    if not perfFrame then return end

    perfFrame:SetScript("OnUpdate", function(_self, delta)
        elapsed = elapsed + delta
        if elapsed < updateInterval then return end
        elapsed = 0

        UpdatePerformance()
    end)

    -- 立即更新一次
    UpdatePerformance()
end

local function StopUpdating()
    if perfFrame then
        perfFrame:SetScript("OnUpdate", nil)
    end
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local function UpdateForPhase()
    if not perfFrame then return end

    -- 使用共用函數，但用自訂透明度表
    local alpha = LunarUI:ApplyPhaseAlpha(perfFrame, "performanceMonitor", PERF_PHASE_ALPHA)

    -- 根據可見性控制更新
    if alpha > 0 then
        StartUpdating()
    else
        StopUpdating()
    end
end

local function OnPhaseChanged(_oldPhase, _newPhase)
    UpdateForPhase()
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function Initialize()
    CreatePerfFrame()

    -- 註冊月相變化回呼
    LunarUI:RegisterPhaseCallback(OnPhaseChanged)

    -- 初始狀態
    UpdateForPhase()
end

-- 匯出函數
function LunarUI.ShowPerformanceMonitor()
    if not perfFrame then
        CreatePerfFrame()
    end
    perfFrame:Show()
    StartUpdating()
end

function LunarUI.HidePerformanceMonitor()
    if perfFrame then
        perfFrame:Hide()
        StopUpdating()
    end
end

function LunarUI.TogglePerformanceMonitor()
    if perfFrame and perfFrame:IsShown() then
        LunarUI.HidePerformanceMonitor()
    else
        LunarUI.ShowPerformanceMonitor()
    end
end

-- 清理函數
function LunarUI.CleanupPerformanceMonitor()
    StopUpdating()
    if perfFrame then
        perfFrame:Hide()
    end
end

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.5, Initialize)
end)
