---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 效能監控
    顯示 FPS 與延遲資訊

    功能：
    - FPS 即時顯示
    - 本地/世界延遲顯示
    - 可拖曳位置
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}
local C = LunarUI.Colors

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

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local FPS_THRESHOLDS = { 60, 30, 15 }
local LATENCY_THRESHOLDS_LIST = {
    LATENCY_THRESHOLDS.good, LATENCY_THRESHOLDS.medium, LATENCY_THRESHOLDS.bad
}

local function GetFPSColor(fps)
    return LunarUI.ThresholdColor(fps, FPS_THRESHOLDS, true)
end

local function GetLatencyColor(ms)
    return LunarUI.ThresholdColor(ms, LATENCY_THRESHOLDS_LIST, false)
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

---@return Frame
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
    LunarUI:RegisterHUDFrame("LunarUI_PerformanceMonitor")

    perfFrame:SetSize(120, 40)
    perfFrame:ClearAllPoints()
    perfFrame:SetPoint("TOPRIGHT", Minimap or UIParent, "BOTTOMRIGHT", 0, -24)
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
    LunarUI.ApplyBackdrop(perfFrame, LunarUI.iconBackdropTemplate, C.bgHUD, C.borderHUD)

    -- FPS 文字（左側）
    local fpsText = perfFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(fpsText, 13, "OUTLINE")
    fpsText:SetPoint("LEFT", 8, 5)
    fpsText:SetJustifyH("LEFT")
    perfFrame.fpsText = fpsText

    -- FPS 標籤
    local fpsLabel = perfFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(fpsLabel, 9, "OUTLINE")
    fpsLabel:SetPoint("TOPLEFT", fpsText, "BOTTOMLEFT", 0, -1)
    fpsLabel:SetText("|cff666688FPS|r")
    perfFrame.fpsLabel = fpsLabel

    -- 延遲文字（右側）
    local latencyText = perfFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(latencyText, 13, "OUTLINE")
    latencyText:SetPoint("RIGHT", -8, 5)
    latencyText:SetJustifyH("RIGHT")
    perfFrame.latencyText = latencyText

    -- 延遲標籤
    local latencyLabel = perfFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(latencyLabel, 9, "OUTLINE")
    latencyLabel:SetPoint("TOPRIGHT", latencyText, "BOTTOMRIGHT", 0, -1)
    latencyLabel:SetText("|cff666688MS|r")
    perfFrame.latencyLabel = latencyLabel

    -- 提示
    perfFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["PerfMonitorTitle"] or "|cff8882ffLunarUI|r Performance Monitor")
        GameTooltip:AddLine(" ")

        local fps = GetFramerate()
        local _, _, homeMs, worldMs = GetNetStats()

        GameTooltip:AddDoubleLine("FPS", string.format("%.0f", fps), 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine(L["HomeLatency"] or "Home Latency", string.format("%d ms", homeMs), 0.7, 0.7, 0.7, GetLatencyColor(homeMs))
        GameTooltip:AddDoubleLine(L["WorldLatency"] or "World Latency", string.format("%d ms", worldMs), 0.7, 0.7, 0.7, GetLatencyColor(worldMs))

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["ShiftDragToMove"] or "Shift+drag to reposition", 0.5, 0.5, 0.5)
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

    -- 更新 FPS（僅顯示數字，標籤獨立）
    local r, g, b = GetFPSColor(fps)
    perfFrame.fpsText:SetFormattedText("%.0f", fps)
    perfFrame.fpsText:SetTextColor(r, g, b)

    -- 更新延遲（顯示較高的那個）
    local latency = math.max(homeMs, worldMs)
    r, g, b = GetLatencyColor(latency)
    perfFrame.latencyText:SetFormattedText("%d", latency)
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
    elapsed = 0
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function Initialize()
    CreatePerfFrame()

    -- 註冊至框架移動器
    LunarUI:RegisterMovableFrame("PerformanceMonitor", perfFrame, "效能監控")

    -- 啟動更新
    StartUpdating()
end

-- 匯出函數
function LunarUI.ShowPerformanceMonitor()
    if not perfFrame then
        perfFrame = CreatePerfFrame()
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

LunarUI:RegisterModule("PerformanceMonitor", {
    onEnable = Initialize,
    onDisable = LunarUI.CleanupPerformanceMonitor,
    delay = 0.5,
})
