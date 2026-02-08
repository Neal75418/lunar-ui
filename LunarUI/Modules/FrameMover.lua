---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unused-local, deprecated
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
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 預設值（初始化時從 DB 讀取）
local GRID_SIZE = 10  -- Ctrl 吸附時的網格大小
local MOVER_ALPHA = 0.6
local MOVER_COLOR = { 0.2, 0.4, 0.8 }  -- 藍色
local MOVER_BORDER_COLOR = { 0.4, 0.6, 1.0 }
local MOVER_TEXT_COLOR = { 1, 1, 1, 0.9 }

local function LoadFrameMoverSettings()
    local db = LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.frameMover
    if db then
        GRID_SIZE = db.gridSize or 10
        MOVER_ALPHA = db.moverAlpha or 0.6
    end
end

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

local function SavePosition(name, point, relativePoint, x, y)
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
    LunarUI.SetFont(text, 10, "OUTLINE")
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
        if not point then return end  -- 防止無錨點時錯誤

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
        SavePosition(name, point, relativePoint, x, y)
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
            LunarUI:Print(string.format(L["MoverResetToDefault"] or "%s reset to default position", name))
        end
    end)

    -- Tooltip
    mover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("|cff8882ffLunarUI|r " .. (label or name))
        GameTooltip:AddLine(L["MoverDragToMove"] or "Left-click drag to move", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["MoverCtrlSnap"] or "Ctrl+drag to snap to grid", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["MoverRightReset"] or "Right-click to reset", 0.7, 0.7, 0.7)
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

---@type function
local UpdateEscHandler  -- forward declaration（定義於 ESC 退出支援區段）

local function EnterMoveMode()
    if InCombatLockdown() then
        LunarUI:Print(L["MoverCombatLocked"] or "Cannot enter move mode during combat")
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

    LunarUI:Print(L["MoverEnterMode"] or "Move mode — drag blue frames | Ctrl+drag snap | Right-click reset | ESC exit")
    UpdateEscHandler()
end

local function ExitMoveMode()
    if not isMoving then return end
    isMoving = false

    HideGrid()

    -- 隱藏所有 mover
    for _, data in pairs(movers) do
        data.mover:Hide()
    end

    LunarUI:Print(L["MoverExitMode"] or "Exited move mode")
    UpdateEscHandler()
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

---@diagnostic disable-next-line: unused-local
UpdateEscHandler = function()
    escFrame:EnableKeyboard(isMoving)
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

    LoadFrameMoverSettings()
    CreateMover(name, frame, label)

    -- 同步載入已儲存的位置（SetPoint 是同步 API，無需延遲）
    ApplySavedPosition(name)
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

function LunarUI:LoadFrameMoverSettings()
    LoadFrameMoverSettings()
end

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

    LunarUI:Print(L["MoverAllReset"] or "All frame positions reset")
end

-- 清理函數
function LunarUI.CleanupFrameMover()
    ExitMoveMode()
    wipe(movers)
end

LunarUI:RegisterModule("FrameMover", {
    onEnable = ApplyAllSavedPositions,
    onDisable = LunarUI.CleanupFrameMover,
    delay = 2.0,
})
