---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field
--[[
    LunarUI - 小地圖模組
    Lunar 主題風格的統一小地圖

    功能：
    - 自訂邊框（Lunar 主題）
    - 按鈕整理（LibDBIcon 支援）
    - 座標顯示
    - 區域文字樣式化
    - 月相感知透明度
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local MINIMAP_SIZE = 180
local BORDER_SIZE = 4
local COORD_UPDATE_INTERVAL = 0.2

local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local minimapFrame
local coordText
local zoneText
local clockText
local buttonFrame
local collectedButtons = {}
local coordUpdateTimer

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function GetPlayerCoords()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then return nil, nil end

    local x, y = position:GetXY()
    if x and y then
        return x * 100, y * 100
    end
    return nil, nil
end

-- 快取最後的值避免不必要的更新
local lastCoordString = nil
local lastClockString = nil

local function UpdateCoordinates()
    if not coordText then return end

    local x, y = GetPlayerCoords()
    if x and y then
        local coordString = string.format("%.1f, %.1f", x, y)
        -- 僅在值改變時更新
        if coordString ~= lastCoordString then
            coordText:SetText(coordString)
            lastCoordString = coordString
            if not coordText:IsShown() then
                coordText:Show()
            end
        end
    else
        if lastCoordString ~= nil then
            coordText:SetText("")
            coordText:Hide()
            lastCoordString = nil
        end
    end
end

local function UpdateZoneText()
    if not zoneText then return end

    local zone = GetZoneText() or ""
    local subzone = GetSubZoneText() or ""

    if subzone and subzone ~= "" and subzone ~= zone then
        zoneText:SetText(subzone)
    else
        zoneText:SetText(zone)
    end

    -- 依 PvP 狀態著色
    local pvpType = C_PvP.GetZonePVPInfo()
    if pvpType == "sanctuary" then
        zoneText:SetTextColor(0.41, 0.8, 0.94)  -- 淺藍
    elseif pvpType == "friendly" then
        zoneText:SetTextColor(0.1, 1.0, 0.1)    -- 綠色
    elseif pvpType == "hostile" then
        zoneText:SetTextColor(1.0, 0.1, 0.1)    -- 紅色
    elseif pvpType == "contested" then
        zoneText:SetTextColor(1.0, 0.7, 0.0)    -- 橙色
    else
        zoneText:SetTextColor(0.9, 0.9, 0.9)    -- 白/灰
    end
end

local function UpdateClock()
    if not clockText then return end

    local hour, minute = GetGameTime()
    local clockString = string.format("%02d:%02d", hour, minute)
    -- 僅在值改變時更新
    if clockString ~= lastClockString then
        clockText:SetText(clockString)
        lastClockString = clockString
    end
end

--------------------------------------------------------------------------------
-- 小地圖按鈕整理
--------------------------------------------------------------------------------

-- 使用雜湊表進行 O(1) 複查重複檢查
local scannedButtonIDs = {}

-- 掃描前清理過期的按鈕參照
local function ClearStaleButtonReferences()
    local validButtons = {}
    for _, button in ipairs(collectedButtons) do
        if button and button:IsShown() then
            validButtons[#validButtons + 1] = button
        end
    end
    collectedButtons = validButtons
    wipe(scannedButtonIDs)
end

local function CollectMinimapButton(button)
    if not button then return end
    if not (button:IsObjectType("Button") or button:IsObjectType("Frame")) then
        return
    end

    local name = button:GetName()
    if not name then return end

    -- 使用雜湊表進行 O(1) 重複檢查
    if scannedButtonIDs[name] then return end

    -- 跳過特定按鈕
    local skipButtons = {
        "MiniMapTracking",
        "MiniMapMailFrame",
        "MinimapZoomIn",
        "MinimapZoomOut",
        "Minimap",
        "MinimapBackdrop",
        "GameTimeFrame",
        "TimeManagerClockButton",
        "LunarUI_MinimapButton",
    }

    for _, skip in ipairs(skipButtons) do
        if name:find(skip) then return end
    end

    -- 標記為已掃描並加入集合
    scannedButtonIDs[name] = true
    table.insert(collectedButtons, button)
end

-- 常見插件的按鈕優先順序
local BUTTON_PRIORITY = {
    ["DBM"] = 1,
    ["DeadlyBoss"] = 1,
    ["BigWigs"] = 2,
    ["Details"] = 3,
    ["Skada"] = 4,
    ["Recount"] = 5,
    ["WeakAuras"] = 6,
    ["Plater"] = 7,
    ["Bartender"] = 8,
    ["ElvUI"] = 9,
    ["Bagnon"] = 10,
    ["AdiBags"] = 11,
    ["AtlasLoot"] = 12,
    ["GTFO"] = 13,
    ["Pawn"] = 14,
    ["Simulationcraft"] = 15,
}

local function GetButtonPriority(button)
    local name = button:GetName() or ""

    -- 對照優先順序清單
    for addon, priority in pairs(BUTTON_PRIORITY) do
        if name:find(addon) then
            return priority
        end
    end

    -- 預設：按字母排序（優先順序 100+）
    return 100
end

local function SortButtons()
    table.sort(collectedButtons, function(a, b)
        local priorityA = GetButtonPriority(a)
        local priorityB = GetButtonPriority(b)

        if priorityA ~= priorityB then
            return priorityA < priorityB
        end

        -- 同優先順序：按名稱排序
        local nameA = a:GetName() or ""
        local nameB = b:GetName() or ""
        return nameA < nameB
    end)
end

local function OrganizeMinimapButtons()
    if not buttonFrame then return end

    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not db.organizeButtons then return end

    -- 整理前先依優先順序排序
    SortButtons()

    local buttonsPerRow = 6
    local buttonSize = 24
    local spacing = 2

    for i, button in ipairs(collectedButtons) do
        if button and button:IsShown() then
            button:SetParent(buttonFrame)
            button:ClearAllPoints()

            local row = math.floor((i - 1) / buttonsPerRow)
            local col = (i - 1) % buttonsPerRow

            button:SetPoint("TOPLEFT", buttonFrame, "TOPLEFT",
                col * (buttonSize + spacing),
                -row * (buttonSize + spacing)
            )

            -- 統一按鈕大小
            button:SetSize(buttonSize, buttonSize)

            -- 樣式化按鈕
            local regions = { button:GetRegions() }
            for _, region in ipairs(regions) do
                if region:IsObjectType("Texture") then
                    local texturePath = region:GetTexture()
                    if texturePath and type(texturePath) == "string" then
                        if texturePath:find("MinimapButton") or texturePath:find("TrackingBorder") then
                            region:SetTexture(nil)
                        end
                    end
                end
            end
        end
    end

    -- 調整按鈕框架大小
    local numButtons = #collectedButtons
    local numRows = math.ceil(numButtons / buttonsPerRow)
    local width = math.min(numButtons, buttonsPerRow) * (buttonSize + spacing) - spacing
    local height = numRows * (buttonSize + spacing) - spacing

    if width > 0 and height > 0 then
        buttonFrame:SetSize(width, height)
        buttonFrame:Show()
    else
        buttonFrame:Hide()
    end
end

local function ScanForMinimapButtons()
    -- 重新掃描前清理過期參照
    ClearStaleButtonReferences()

    -- 掃描 Minimap 子框架
    local children = { Minimap:GetChildren() }
    for _, child in ipairs(children) do
        CollectMinimapButton(child)
    end

    -- 掃描 MinimapBackdrop 子框架
    if MinimapBackdrop then
        children = { MinimapBackdrop:GetChildren() }
        for _, child in ipairs(children) do
            CollectMinimapButton(child)
        end
    end

    -- 掃描 MinimapCluster 子框架
    if MinimapCluster then
        children = { MinimapCluster:GetChildren() }
        for _, child in ipairs(children) do
            CollectMinimapButton(child)
        end
    end

    OrganizeMinimapButtons()
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateMinimapForPhase()
    if not minimapFrame then return end

    local tokens = LunarUI:GetTokens()

    -- 小地圖即使在新月階段也應保持較高可見度
    local minAlpha = 0.6
    local alpha = math.max(tokens.alpha, minAlpha)

    minimapFrame:SetAlpha(alpha)
end

local function RegisterMinimapPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
        UpdateMinimapForPhase()
    end)
end

--------------------------------------------------------------------------------
-- 小地圖樣式化
--------------------------------------------------------------------------------

local function HideBlizzardMinimapElements()
    -- 隱藏預設邊框/裝飾
    local elementsToHide = {
        MinimapBorder,
        MinimapBorderTop,
        MinimapZoomIn,
        MinimapZoomOut,
        MinimapZoneTextButton,
        MinimapToggleButton,
        MiniMapWorldMapButton,
        GameTimeFrame,
        MiniMapMailBorder,
    }

    for _, element in ipairs(elementsToHide) do
        if element then
            element:Hide()
            element:UnregisterAllEvents()
        end
    end

    -- 隱藏 Cluster 元素（正式服）
    if MinimapCluster then
        local clusterElements = {
            MinimapCluster.BorderTop,
            MinimapCluster.ZoneTextButton,
            MinimapCluster.Tracking,
        }
        for _, element in ipairs(clusterElements) do
            if element then
                element:Hide()
            end
        end
    end

    -- 使小地圖變為方形
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8x8")

    -- 停用預設縮放行為
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            Minimap_ZoomIn()
        else
            Minimap_ZoomOut()
        end
    end)
end

local function CreateMinimapFrame()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not db.enabled then return end

    -- 建立主容器
    minimapFrame = CreateFrame("Frame", "LunarUI_Minimap", UIParent, "BackdropTemplate")
    minimapFrame:SetSize(MINIMAP_SIZE + BORDER_SIZE * 2, MINIMAP_SIZE + BORDER_SIZE * 2)
    minimapFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    minimapFrame:SetBackdrop(backdropTemplate)
    minimapFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    minimapFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    minimapFrame:SetFrameStrata("LOW")
    minimapFrame:SetMovable(true)
    minimapFrame:EnableMouse(true)
    minimapFrame:SetClampedToScreen(true)

    -- 拖曳支援
    minimapFrame:RegisterForDrag("LeftButton")
    minimapFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    minimapFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    -- 重新設定 Minimap 父框架與大小
    Minimap:SetParent(minimapFrame)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", minimapFrame, "CENTER", 0, 0)
    Minimap:SetSize(MINIMAP_SIZE, MINIMAP_SIZE)
    Minimap:SetFrameLevel(minimapFrame:GetFrameLevel() + 1)

    -- 建立區域文字
    zoneText = minimapFrame:CreateFontString(nil, "OVERLAY")
    zoneText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    zoneText:SetPoint("TOP", minimapFrame, "BOTTOM", 0, -4)
    zoneText:SetTextColor(0.9, 0.9, 0.9)
    zoneText:SetJustifyH("CENTER")
    zoneText:SetWidth(MINIMAP_SIZE)
    zoneText:SetWordWrap(false)

    -- 建立座標文字
    if db.showCoords then
        coordText = minimapFrame:CreateFontString(nil, "OVERLAY")
        coordText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        coordText:SetPoint("BOTTOM", minimapFrame, "BOTTOM", 0, 4)
        coordText:SetTextColor(0.8, 0.8, 0.6)
        coordText:SetJustifyH("CENTER")
    end

    -- 建立時鐘文字
    if db.showClock then
        clockText = minimapFrame:CreateFontString(nil, "OVERLAY")
        clockText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        clockText:SetPoint("BOTTOMRIGHT", minimapFrame, "BOTTOMRIGHT", -4, 4)
        clockText:SetTextColor(0.7, 0.7, 0.7)
        clockText:SetJustifyH("RIGHT")
    end

    -- 建立按鈕整理框架
    if db.organizeButtons then
        buttonFrame = CreateFrame("Frame", "LunarUI_MinimapButtons", minimapFrame, "BackdropTemplate")
        buttonFrame:SetPoint("TOPRIGHT", minimapFrame, "TOPLEFT", -8, 0)
        buttonFrame:SetSize(100, 50)
        buttonFrame:SetBackdrop(backdropTemplate)
        buttonFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
        buttonFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.8)
        buttonFrame:Hide()
    end

    -- 註冊事件
    minimapFrame:RegisterEvent("ZONE_CHANGED")
    minimapFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    minimapFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    minimapFrame:SetScript("OnEvent", function(self, event)
        UpdateZoneText()
    end)

    -- 座標與時鐘的更新計時器
    minimapFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= COORD_UPDATE_INTERVAL then
            self.elapsed = 0
            UpdateCoordinates()
            UpdateClock()
        end
    end)

    -- 右鍵選單追蹤
    Minimap:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button then
                MinimapCluster.Tracking.Button:Click()
            elseif MiniMapTracking then
                ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, "cursor")
            end
        elseif button == "MiddleButton" then
            -- 切換行事曆
            if C_Calendar and C_Calendar.OpenCalendar then
                C_Calendar.OpenCalendar()
            end
        end
    end)

    return minimapFrame
end

--------------------------------------------------------------------------------
-- 郵件指示器
--------------------------------------------------------------------------------

local function CreateMailIndicator()
    if not minimapFrame then return end

    local mail = CreateFrame("Frame", "LunarUI_MinimapMail", minimapFrame)
    mail:SetSize(18, 18)
    mail:SetPoint("BOTTOMLEFT", minimapFrame, "BOTTOMLEFT", 4, 4)

    local icon = mail:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    mail.icon = icon

    -- 光暈效果
    local glow = mail:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER")
    glow:SetSize(24, 24)
    glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    glow:SetVertexColor(1, 0.8, 0, 0.3)
    glow:SetBlendMode("ADD")
    mail.glow = glow

    mail:RegisterEvent("UPDATE_PENDING_MAIL")
    mail:SetScript("OnEvent", function(self)
        if HasNewMail() then
            self:Show()
        else
            self:Hide()
        end
    end)

    mail:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("You have mail!")
        GameTooltip:Show()
    end)

    mail:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- 初始狀態
    if HasNewMail() then
        mail:Show()
    else
        mail:Hide()
    end

    -- 隱藏預設郵件框架
    if MiniMapMailFrame then
        MiniMapMailFrame:Hide()
        MiniMapMailFrame:UnregisterAllEvents()
    end
end

--------------------------------------------------------------------------------
-- 難度指示器
--------------------------------------------------------------------------------

local function CreateDifficultyIndicator()
    if not minimapFrame then return end

    local diff = CreateFrame("Frame", "LunarUI_MinimapDifficulty", minimapFrame)
    diff:SetSize(24, 12)
    diff:SetPoint("TOPLEFT", minimapFrame, "TOPLEFT", 4, -4)

    local text = diff:CreateFontString(nil, "OVERLAY")
    text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    text:SetAllPoints()
    text:SetJustifyH("LEFT")
    diff.text = text

    local function UpdateDifficulty()
        local _, instanceType = GetInstanceInfo()
        local difficulty = select(3, GetInstanceInfo())
        local diffName = GetDifficultyInfo(difficulty) or ""

        if instanceType == "none" then
            diff:Hide()
            return
        end

        -- 依副本類型著色
        if instanceType == "raid" then
            text:SetTextColor(1, 0.5, 0)
        elseif instanceType == "party" then
            text:SetTextColor(0.5, 0.5, 1)
        elseif instanceType == "pvp" or instanceType == "arena" then
            text:SetTextColor(1, 0.2, 0.2)
        else
            text:SetTextColor(0.8, 0.8, 0.8)
        end

        -- 縮寫難度名稱
        local abbrev = diffName:gsub("Heroic", "H"):gsub("Mythic", "M"):gsub("Normal", "N"):gsub("Looking For Raid", "LFR")
        text:SetText(abbrev)
        diff:Show()
    end

    diff:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
    diff:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    diff:RegisterEvent("PLAYER_ENTERING_WORLD")
    diff:SetScript("OnEvent", UpdateDifficulty)

    -- 初始更新
    C_Timer.After(0.5, UpdateDifficulty)
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeMinimap()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not db.enabled then return end

    -- 先隱藏暴雪元素
    HideBlizzardMinimapElements()

    -- 建立我們的框架
    CreateMinimapFrame()

    -- 建立指示器
    CreateMailIndicator()
    CreateDifficultyIndicator()

    -- 多次掃描按鈕以捕捉延遲載入的插件（如 DBM）
    C_Timer.After(2, ScanForMinimapButtons)
    C_Timer.After(5, ScanForMinimapButtons)
    C_Timer.After(10, ScanForMinimapButtons)

    -- 註冊月相更新
    RegisterMinimapPhaseCallback()

    -- 套用初始月相
    UpdateMinimapForPhase()

    -- 初始更新
    UpdateZoneText()
    UpdateCoordinates()
    UpdateClock()
end

-- OnUpdate 清理函數
function LunarUI:CleanupMinimap()
    if minimapFrame then
        minimapFrame:SetScript("OnUpdate", nil)
        minimapFrame:SetScript("OnEvent", nil)
    end
end

-- 匯出
LunarUI.InitializeMinimap = InitializeMinimap
LunarUI.minimapFrame = minimapFrame

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.5, InitializeMinimap)
end)
