---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, unused-local, deprecated
-- deprecated: 使用 GetLeft/GetBottom 等舊式定位 API（替代方案不適用於跨框架對齊計算）
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
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local format = string.format
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 預設值（初始化時從 DB 讀取）
local GRID_SIZE = 10 -- Ctrl 吸附時的網格大小
local MOVER_ALPHA = 0.6
local MOVER_COLOR = { 0.2, 0.4, 0.8 } -- 藍色
local MOVER_BORDER_COLOR = { 0.4, 0.6, 1.0 }
local MOVER_TEXT_COLOR = { 1, 1, 1, 0.9 }

local function LoadFrameMoverSettings()
    local db = LunarUI.GetModuleDB("frameMover")
    if db then
        GRID_SIZE = db.gridSize or 10
        MOVER_ALPHA = db.moverAlpha or 0.6
    end
end

local backdropTemplate = LunarUI.backdropTemplate

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local isMoving = false -- 是否處於移動模式
local movers = {} -- { name = { frame, mover, defaultPoint } }
local gridFrame = nil -- 網格背景框架

--------------------------------------------------------------------------------
-- 位置存取
--------------------------------------------------------------------------------

local function GetSavedPositions()
    if not LunarUI.db or not LunarUI.db.profile then
        return {}
    end
    if not LunarUI.db.profile.framePositions then
        LunarUI.db.profile.framePositions = {}
    end
    return LunarUI.db.profile.framePositions
end

local function SavePosition(name, point, relativePoint, x, y)
    local positions = GetSavedPositions()
    -- 儲存座標時一併記錄 UIParent scale，以便 scale 變更後等比例換算
    positions[name] = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        scale = UIParent:GetScale() or 1.0,
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

local gridCachedSize -- 上次建構的 GRID_SIZE，用於判斷是否需要重建
local gridTextures = {} -- 快取已建立的材質，避免洩漏

local function ShowGrid()
    if gridFrame and gridCachedSize == GRID_SIZE then
        gridFrame:Show()
        return
    end
    -- GRID_SIZE 變更：隱藏舊材質（WoW frame/texture 無法 GC，重用而非重建）
    if gridFrame then
        for _, tex in ipairs(gridTextures) do
            tex:Hide()
        end
        wipe(gridTextures)
    end

    if not gridFrame then
        gridFrame = CreateFrame("Frame", nil, UIParent) -- 匿名 frame，避免全域命名衝突
        gridFrame:SetAllPoints(UIParent)
        gridFrame:SetFrameStrata("BACKGROUND")
    end

    -- 半透明黑色背景
    local bg = gridFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0, 0, 0, 0.4)
    gridTextures[#gridTextures + 1] = bg

    -- 繪製網格線
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local step = GRID_SIZE * 4 -- 每 N 像素一條線

    for x = 0, screenWidth, step do
        local line = gridFrame:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetVertexColor(0.3, 0.4, 0.6, 0.15)
        line:SetSize(1, screenHeight)
        line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", x, 0)
        gridTextures[#gridTextures + 1] = line
    end

    for y = 0, screenHeight, step do
        local line = gridFrame:CreateTexture(nil, "ARTWORK")
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetVertexColor(0.3, 0.4, 0.6, 0.15)
        line:SetSize(screenWidth, 1)
        line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -y)
        gridTextures[#gridTextures + 1] = line
    end

    -- 中心十字線
    local centerV = gridFrame:CreateTexture(nil, "OVERLAY")
    centerV:SetTexture("Interface\\Buttons\\WHITE8x8")
    centerV:SetVertexColor(0.6, 0.3, 0.3, 0.3)
    centerV:SetSize(1, screenHeight)
    centerV:SetPoint("CENTER", gridFrame, "CENTER", 0, 0)
    gridTextures[#gridTextures + 1] = centerV

    local centerH = gridFrame:CreateTexture(nil, "OVERLAY")
    centerH:SetTexture("Interface\\Buttons\\WHITE8x8")
    centerH:SetVertexColor(0.6, 0.3, 0.3, 0.3)
    centerH:SetSize(screenWidth, 1)
    centerH:SetPoint("CENTER", gridFrame, "CENTER", 0, 0)
    gridTextures[#gridTextures + 1] = centerH

    gridCachedSize = GRID_SIZE
    gridFrame:Show()
end

local function HideGrid()
    if gridFrame then
        gridFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- 對齊格線
--------------------------------------------------------------------------------

local function SnapToGrid(value)
    return mathFloor(value / GRID_SIZE + 0.5) * GRID_SIZE
end

--------------------------------------------------------------------------------
-- Mover 建立
--------------------------------------------------------------------------------

local function CreateMover(name, targetFrame, label)
    if movers[name] then
        return movers[name].mover
    end
    if not targetFrame then
        return nil
    end

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
        if InCombatLockdown() then
            return
        end
        self:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        -- 取得目前位置
        local point, _, relativePoint, x, y = self:GetPoint(1)
        if not point then
            return
        end -- 防止無錨點時錯誤

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
            LunarUI:Print(format(L["MoverResetToDefault"] or "%s reset to default position", label or name))
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
    if not data then
        return
    end

    local saved = LoadPosition(name)
    if saved then
        -- saved.point 型別驗證（防止手動編輯 SavedVariables 導致 SetPoint 傳入 nil）
        if type(saved.point) ~= "string" or type(saved.relativePoint) ~= "string" then
            return
        end
        local x = type(saved.x) == "number" and saved.x or 0
        local y = type(saved.y) == "number" and saved.y or 0

        -- Scale 換算：若儲存時的 scale 與當前不同，等比例縮放座標以維持螢幕位置不變
        local savedScale = type(saved.scale) == "number" and saved.scale or 1.0
        local currentScale = UIParent:GetScale() or 1.0
        if savedScale ~= currentScale and currentScale > 0 then
            x = x * savedScale / currentScale
            y = y * savedScale / currentScale
        end

        -- 限制座標在螢幕範圍內（0 到螢幕尺寸，處理解析度變更後舊資料超出邊界的情況）
        local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
        x = mathMax(-screenW, mathMin(screenW, x))
        y = mathMax(-screenH, mathMin(screenH, y))

        data.frame:ClearAllPoints()
        data.frame:SetPoint(saved.point, UIParent, saved.relativePoint, x, y)
    end
end

local function ApplyAllSavedPositions()
    if InCombatLockdown() then
        return
    end
    for name in pairs(movers) do
        ApplySavedPosition(name)
    end
end

--------------------------------------------------------------------------------
-- 移動模式控制
--------------------------------------------------------------------------------

---@type function
local UpdateEscHandler -- 前向宣告（定義於 ESC 退出支援區段）

local function EnterMoveMode()
    if InCombatLockdown() then
        LunarUI:Print(L["MoverCombatLocked"] or "Cannot enter move mode during combat")
        return
    end

    if isMoving then
        return
    end
    isMoving = true

    ShowGrid()

    -- 顯示所有 mover 並同步位置
    for _, data in pairs(movers) do
        local frame = data.frame
        local mover = data.mover

        if frame and frame:IsShown() then
            -- 同步 mover 大小和位置到目標框架
            mover:SetSize(mathMax(frame:GetWidth(), 40), mathMax(frame:GetHeight(), 20))
            mover:ClearAllPoints()
            mover:SetPoint("CENTER", frame, "CENTER", 0, 0)
            mover:Show()
        end
    end

    LunarUI:Print(
        L["MoverEnterMode"] or "Move mode — drag blue frames | Ctrl+drag snap | Right-click reset | ESC exit"
    )
    UpdateEscHandler()
end

local function ExitMoveMode()
    if not isMoving then
        return
    end
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
function LunarUI.RegisterMovableFrame(name, frame, label)
    if not name or not frame then
        return
    end

    LoadFrameMoverSettings()
    CreateMover(name, frame, label)

    -- 同步載入已儲存的位置（SetPoint 是同步 API，無需延遲）
    ApplySavedPosition(name)
end

--[[
    取消註冊可移動框架
    @param name string 識別名稱
]]
function LunarUI.UnregisterMovableFrame(name)
    if movers[name] then
        local mover = movers[name].mover
        mover:Hide()
        mover:SetScript("OnDragStart", nil)
        mover:SetScript("OnDragStop", nil)
        mover:SetScript("OnMouseUp", nil)
        mover:SetScript("OnEnter", nil)
        mover:SetScript("OnLeave", nil)
        movers[name] = nil
    end
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.ToggleMoveMode = ToggleMoveMode
LunarUI.EnterMoveMode = EnterMoveMode
LunarUI.ExitMoveMode = ExitMoveMode

-- 進入戰鬥時自動退出移動模式（防止在戰鬥中拖拽安全框架觸發 lockdown 錯誤）
local combatExitFrame = CreateFrame("Frame")
combatExitFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatExitFrame:SetScript("OnEvent", function()
    if isMoving then
        ExitMoveMode()
        LunarUI:Print(L["MoverCombatLocked"] or "Cannot enter move mode during combat")
    end
end)

function LunarUI.LoadFrameMoverSettings()
    LoadFrameMoverSettings()
end

function LunarUI.ResetAllPositions()
    if InCombatLockdown() then
        LunarUI:Print(L["MoverCombatLocked"] or "Cannot enter move mode during combat")
        return
    end
    if not LunarUI.db or not LunarUI.db.profile then
        return
    end
    LunarUI.db.profile.framePositions = {}

    -- 重設所有框架到預設位置，並同步 mover 位置（若在移動模式中）
    for _, data in pairs(movers) do
        data.frame:ClearAllPoints()
        for _, pt in ipairs(data.defaultPoints) do
            data.frame:SetPoint(unpack(pt))
        end
        if isMoving and data.mover then
            data.mover:ClearAllPoints()
            data.mover:SetPoint("CENTER", data.frame, "CENTER", 0, 0)
        end
    end

    LunarUI:Print(L["MoverAllReset"] or "All frame positions reset")
end

-- 清理函數
function LunarUI.CleanupFrameMover()
    ExitMoveMode()
    -- 不 wipe(movers)：WoW 框架不可銷毀，wipe 會遺棄永久框架並導致 re-enable 時 stale closures
    -- 不拔 mover 腳本：Hide() 後已無法觸發，re-enable 時需要腳本仍完好才能正常互動
    for _, data in pairs(movers) do
        if data.mover then
            data.mover:Hide()
        end
    end
end

-- 暴露給 Config.lua 的 OnProfileChanged，確保切換 profile 後立即套用框架位置
LunarUI.ApplyAllSavedPositions = ApplyAllSavedPositions

LunarUI:RegisterModule("FrameMover", {
    onEnable = ApplyAllSavedPositions,
    onDisable = LunarUI.CleanupFrameMover,
    delay = 2.0,
    lifecycle = "reversible",
})
