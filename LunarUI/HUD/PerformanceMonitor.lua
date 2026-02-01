---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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

-- 通用門檻色彩：ascending=true 值越大越好（FPS），false 值越小越好（延遲）
local function GetThresholdColor(value, thresholds, ascending)
    if ascending then
        if value >= thresholds[1] then return 0.2, 0.8, 0.2
        elseif value >= thresholds[2] then return 0.9, 0.9, 0.2
        elseif value >= thresholds[3] then return 0.9, 0.5, 0.1
        else return 0.9, 0.2, 0.2 end
    else
        if value <= thresholds[1] then return 0.2, 0.8, 0.2
        elseif value <= thresholds[2] then return 0.9, 0.9, 0.2
        elseif value <= thresholds[3] then return 0.9, 0.5, 0.1
        else return 0.9, 0.2, 0.2 end
    end
end

local FPS_THRESHOLDS = { 60, 30, 15 }
local LATENCY_THRESHOLDS_LIST = {
    LATENCY_THRESHOLDS.good, LATENCY_THRESHOLDS.medium, LATENCY_THRESHOLDS.bad
}

local function GetFPSColor(fps)
    return GetThresholdColor(fps, FPS_THRESHOLDS, true)
end

local function GetLatencyColor(ms)
    return GetThresholdColor(ms, LATENCY_THRESHOLDS_LIST, false)
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
    perfFrame:SetBackdrop(LunarUI.iconBackdropTemplate)
    perfFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.75)
    perfFrame:SetBackdropBorderColor(0.20, 0.18, 0.30, 0.9)

    -- FPS 文字（左側）
    local fpsText = perfFrame:CreateFontString(nil, "OVERLAY")
    fpsText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    fpsText:SetPoint("LEFT", 8, 5)
    fpsText:SetJustifyH("LEFT")
    perfFrame.fpsText = fpsText

    -- FPS 標籤
    local fpsLabel = perfFrame:CreateFontString(nil, "OVERLAY")
    fpsLabel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    fpsLabel:SetPoint("TOPLEFT", fpsText, "BOTTOMLEFT", 0, -1)
    fpsLabel:SetText("|cff666688FPS|r")
    perfFrame.fpsLabel = fpsLabel

    -- 延遲文字（右側）
    local latencyText = perfFrame:CreateFontString(nil, "OVERLAY")
    latencyText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    latencyText:SetPoint("RIGHT", -8, 5)
    latencyText:SetJustifyH("RIGHT")
    perfFrame.latencyText = latencyText

    -- 延遲標籤
    local latencyLabel = perfFrame:CreateFontString(nil, "OVERLAY")
    latencyLabel:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    latencyLabel:SetPoint("TOPRIGHT", latencyText, "BOTTOMRIGHT", 0, -1)
    latencyLabel:SetText("|cff666688MS|r")
    perfFrame.latencyLabel = latencyLabel

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

LunarUI:RegisterModule("PerformanceMonitor", {
    onEnable = Initialize,
    onDisable = LunarUI.CleanupPerformanceMonitor,
    delay = 0.5,
})
