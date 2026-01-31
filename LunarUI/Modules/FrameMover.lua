---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if, unused-local, deprecated
--[[
    LunarUI - 框架移動器
    統一的 UI 框架位置管理系統

    功能：
    - /lunar move 進入移動模式
    - 所有可移動框架顯示藍色半透明 mover
    - 網格對齊（按住 Ctrl）
    - ESC 退出移動模式
    - 位置儲存至 AceDB
    - 重設所有位置到預設值
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local GRID_SIZE = 10  -- Ctrl 吸附時的網格大小
local MOVER_ALPHA = 0.6
local MOVER_COLOR = { 0.2, 0.4, 0.8 }  -- 藍色
local MOVER_BORDER_COLOR = { 0.4, 0.6, 1.0 }
local MOVER_TEXT_COLOR = { 1, 1, 1, 0.9 }

local backdropTemplate = LunarUI.backdropTemplate

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local isMoving = false  -- 是否處於移動模式
local movers = {}       -- { name = { frame, mover, defaultPoint } }
local gridFrame = nil   -- 網格背景框架

--------------------------------------------------------------------------------
-- 位置存取
--------------------------------------------------------------------------------

local function GetSavedPositions()
    if not LunarUI.db or not LunarUI.db.profile then return {} end
    if not LunarUI.db.profile.framePositions then
        LunarUI.db.profile.framePositions = {}
    end
    return LunarUI.db.profile.framePositions
end

local function SavePosition(name, point, _relativeTo, relativePoint, x, y)
    local positions = GetSavedPositions()
    positions[name] = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function LoadPosition(name)
    local positions = GetSavedPositions()
    return positions[name]
end

local function ClearPosition(name)
    local positions = GetSavedPositions()
    positions[name] = nil
end

--------------------------------------------------------------------------------
-- 網格背景
--------------------------------------------------------------------------------

local function ShowGrid()
    if gridFrame then
        gridFrame:Show()
        return
    end

    gridFrame = CreateFrame("Frame", "LunarUI_MoverGrid", UIParent)
    gridFrame:SetAllPoints(UIParent)
    gridFrame:SetFrameStrata("BACKGROUND")

    -- 半透明黑色背景
    local bg = gridFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0, 0, 0, 0.4)

    -- 繪製網格線
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local step = GRID_SIZE * 4  -- 每 40 像素一條線

    for x = 0, screenWidth, step do
        local line = gridFrame:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetVertexColor(0.3, 0.4, 0.6, 0.15)
        line:SetSize(1, screenHeight)
        line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", x, 0)
    end

    for y = 0, screenHeight, step do
        local line = gridFrame:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetVertexColor(0.3, 0.4, 0.6, 0.15)
        line:SetSize(screenWidth, 1)
        line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -y)
    end

    -- 中心十字線
    local centerV = gridFrame:CreateTexture(nil, "OVERLAY")
    centerV:SetTexture("Interface\\Buttons\\WHITE8x8")
    centerV:SetVertexColor(0.6, 0.3, 0.3, 0.3)
    centerV:SetSize(1, screenHeight)
    centerV:SetPoint("CENTER", gridFrame, "CENTER", 0, 0)

    local centerH = gridFrame:CreateTexture(nil, "OVERLAY")
    centerH:SetTexture("Interface\\Buttons\\WHITE8x8")
    centerH:SetVertexColor(0.6, 0.3, 0.3, 0.3)
    centerH:SetSize(screenWidth, 1)
    centerH:SetPoint("CENTER", gridFrame, "CENTER", 0, 0)

    gridFrame:Show()
end

local function HideGrid()
    if gridFrame then
        gridFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Snap to Grid
--------------------------------------------------------------------------------

local function SnapToGrid(value)
    return math.floor(value / GRID_SIZE + 0.5) * GRID_SIZE
end

--------------------------------------------------------------------------------
-- Mover 建立
--------------------------------------------------------------------------------

local function CreateMover(name, targetFrame, label)
    if movers[name] then return movers[name].mover end
    if not targetFrame then return nil end

    -- 儲存原始錨點
    local numPoints = targetFrame:GetNumPoints()
    local defaultPoints = {}
    for i = 1, numPoints do
        defaultPoints[i] = { targetFrame:GetPoint(i) }
    end

    -- 建立 mover 框架
    local mover = CreateFrame("Frame", "LunarUI_Mover_" .. name, UIParent, "BackdropTemplate")
    mover:SetSize(targetFrame:GetWidth(), targetFrame:GetHeight())
    mover:SetFrameStrata("DIALOG")
    mover:SetFrameLevel(100)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:SetClampedToScreen(true)
    mover:RegisterForDrag("LeftButton")
    mover:Hide()

    -- 背景
    mover:SetBackdrop(backdropTemplate)
    mover:SetBackdropColor(MOVER_COLOR[1], MOVER_COLOR[2], MOVER_COLOR[3], MOVER_ALPHA)
    mover:SetBackdropBorderColor(MOVER_BORDER_COLOR[1], MOVER_BORDER_COLOR[2], MOVER_BORDER_COLOR[3], 0.9)

    -- 名稱標籤
    local text = mover:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetTextColor(MOVER_TEXT_COLOR[1], MOVER_TEXT_COLOR[2], MOVER_TEXT_COLOR[3], MOVER_TEXT_COLOR[4])
    text:SetText(label or name)
    mover.label = text

    -- 拖曳
    mover:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        -- 取得目前位置
        local point, _, relativePoint, x, y = self:GetPoint(1)

        -- Ctrl 按住時吸附網格
        if IsControlKeyDown() then
            x = SnapToGrid(x)
            y = SnapToGrid(y)
            self:ClearAllPoints()
            self:SetPoint(point, UIParent, relativePoint, x, y)
        end

        -- 同步目標框架位置
        targetFrame:ClearAllPoints()
        targetFrame:SetPoint(point, UIParent, relativePoint, x, y)

        -- 儲存位置
        SavePosition(name, point, nil, relativePoint, x, y)
    end)

    -- 右鍵重設
    mover:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            -- 重設到預設位置
            ClearPosition(name)
            targetFrame:ClearAllPoints()
            for _, pt in ipairs(defaultPoints) do
                targetFrame:SetPoint(unpack(pt))
            end
            -- 同步 mover 位置
            self:ClearAllPoints()
            self:SetPoint("CENTER", targetFrame, "CENTER", 0, 0)
            LunarUI:Print(name .. " 已重設到預設位置")
        end
    end)

    -- Tooltip
    mover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("|cff8882ffLunarUI|r " .. (label or name))
        GameTooltip:AddLine("左鍵拖曳移動", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Ctrl+拖曳 網格對齊", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("右鍵 重設位置", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    mover:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    movers[name] = {
        frame = targetFrame,
        mover = mover,
        defaultPoints = defaultPoints,
        label = label,
    }

    return mover
end

--------------------------------------------------------------------------------
-- 位置套用（載入時）
--------------------------------------------------------------------------------

local function ApplySavedPosition(name)
    local data = movers[name]
    if not data then return end

    local saved = LoadPosition(name)
    if saved then
        data.frame:ClearAllPoints()
        data.frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    end
end

local function ApplyAllSavedPositions()
    for name in pairs(movers) do
        ApplySavedPosition(name)
    end
end

--------------------------------------------------------------------------------
-- 移動模式控制
--------------------------------------------------------------------------------

local function EnterMoveMode()
    if InCombatLockdown() then
        LunarUI:Print("戰鬥中無法進入移動模式")
        return
    end

    if isMoving then return end
    isMoving = true

    ShowGrid()

    -- 顯示所有 mover 並同步位置
    for _, data in pairs(movers) do
        local frame = data.frame
        local mover = data.mover

        if frame and frame:IsShown() then
            -- 同步 mover 大小和位置到目標框架
            mover:SetSize(
                math.max(frame:GetWidth(), 40),
                math.max(frame:GetHeight(), 20)
            )
            mover:ClearAllPoints()
            mover:SetPoint("CENTER", frame, "CENTER", 0, 0)
            mover:Show()
        end
    end

    LunarUI:Print("進入移動模式 — 拖曳藍色框架移動 UI | Ctrl+拖曳對齊網格 | 右鍵重設 | ESC 退出")
end

local function ExitMoveMode()
    if not isMoving then return end
    isMoving = false

    HideGrid()

    -- 隱藏所有 mover
    for _, data in pairs(movers) do
        data.mover:Hide()
    end

    LunarUI:Print("已退出移動模式")
end

local function ToggleMoveMode()
    if isMoving then
        ExitMoveMode()
    else
        EnterMoveMode()
    end
end

--------------------------------------------------------------------------------
-- ESC 退出支援
--------------------------------------------------------------------------------

local escFrame = CreateFrame("Frame", "LunarUI_MoverEscHandler", UIParent)
escFrame:SetScript("OnKeyDown", function(_self, key)
    if key == "ESCAPE" and isMoving then
        ExitMoveMode()
        escFrame:SetPropagateKeyboardInput(false)
    else
        escFrame:SetPropagateKeyboardInput(true)
    end
end)
escFrame:EnableKeyboard(false)

local function UpdateEscHandler()
    escFrame:EnableKeyboard(isMoving)
end

-- 覆寫 EnterMoveMode/ExitMoveMode 以更新 ESC handler
local originalEnter = EnterMoveMode
EnterMoveMode = function()
    originalEnter()
    UpdateEscHandler()
end

local originalExit = ExitMoveMode
ExitMoveMode = function()
    originalExit()
    UpdateEscHandler()
end

--------------------------------------------------------------------------------
-- 框架註冊 API
--------------------------------------------------------------------------------

--[[
    註冊一個框架為可移動
    @param name string 唯一識別名稱
    @param frame Frame 目標框架
    @param label string 顯示名稱（可選）
]]
function LunarUI:RegisterMovableFrame(name, frame, label)
    if not name or not frame then return end

    CreateMover(name, frame, label)

    -- 載入已儲存的位置
    C_Timer.After(0, function()
        ApplySavedPosition(name)
    end)
end

--[[
    取消註冊可移動框架
    @param name string 識別名稱
]]
function LunarUI:UnregisterMovableFrame(name)
    if movers[name] then
        movers[name].mover:Hide()
        movers[name] = nil
    end
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.ToggleMoveMode = ToggleMoveMode
LunarUI.EnterMoveMode = EnterMoveMode
LunarUI.ExitMoveMode = ExitMoveMode

function LunarUI.ResetAllPositions()
    if not LunarUI.db or not LunarUI.db.profile then return end
    LunarUI.db.profile.framePositions = {}

    -- 重設所有框架到預設位置
    for _, data in pairs(movers) do
        data.frame:ClearAllPoints()
        for _, pt in ipairs(data.defaultPoints) do
            data.frame:SetPoint(unpack(pt))
        end
    end

    LunarUI:Print("所有框架位置已重設")
end

-- 清理函數
function LunarUI.CleanupFrameMover()
    ExitMoveMode()
end

-- 掛鉤至插件啟用（延遲以確保其他模組已註冊框架）
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(2.0, ApplyAllSavedPositions)
end)
