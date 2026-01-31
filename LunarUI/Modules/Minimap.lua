---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
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

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- 覆寫形狀函數（必須在模組範圍定義以避免 Lint 錯誤）
function GetMinimapShape() return "SQUARE" end

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local MINIMAP_SIZE = 180
local BORDER_SIZE = 4
local COORD_UPDATE_INTERVAL = 0.2

local backdropTemplate = LunarUI.backdropTemplate

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local minimapFrame
local coordText
local zoneText
local clockText
local buttonFrame
local collectedButtons = {}
local _coordUpdateTimer  -- 保留供未來使用

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

            -- 樣式化按鈕：只移除邊框材質，保留圖示
            local regions = { button:GetRegions() }
            for _, region in ipairs(regions) do
                if region:IsObjectType("Texture") then
                    local texturePath = region:GetTexture()
                    -- 只移除字串型路徑中包含邊框關鍵字的材質
                    -- WoW 12.0 的 atlas 材質返回 fileID（數字），跳過以保留圖示
                    if texturePath and type(texturePath) == "string" then
                        local lowerPath = texturePath:lower()
                        if lowerPath:find("minimapbutton") or lowerPath:find("trackingborder")
                            or lowerPath:find("border") or lowerPath:find("background") then
                            region:SetTexture(nil)
                            region:SetAlpha(0)
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

    LunarUI:RegisterPhaseCallback(function(_oldPhase, _newPhase)
        UpdateMinimapForPhase()
    end)
end

--------------------------------------------------------------------------------
-- 小地圖樣式化
--------------------------------------------------------------------------------

local function HideBlizzardMinimapElements()
    -- 1. 把有用的 MinimapCluster 子元素 reparent 到 Minimap 並重設位置
    -- 原始錨點可能指向 MinimapCluster（即將移走），必須重設
    local function ReparentButton(button, anchor, relFrame, relAnchor, x, y)
        if not button then return end
        pcall(function()
            button:SetParent(Minimap)
            button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
            button:ClearAllPoints()
            button:SetPoint(anchor, relFrame or Minimap, relAnchor or anchor, x or 0, y or 0)
            button:SetAlpha(1)
            button:Show()
        end)
    end

    pcall(function()
        if MinimapCluster then
            -- 追蹤按鈕（右鍵選單）
            if MinimapCluster.Tracking then
                ReparentButton(MinimapCluster.Tracking, "TOPRIGHT", Minimap, "TOPRIGHT", -2, -2)
            end
            -- 副本難度
            if MinimapCluster.InstanceDifficulty then
                ReparentButton(MinimapCluster.InstanceDifficulty, "TOPLEFT", Minimap, "TOPLEFT", 2, -2)
            end
            -- 郵件/製作訂單指示器
            if MinimapCluster.IndicatorFrame then
                ReparentButton(MinimapCluster.IndicatorFrame, "BOTTOMLEFT", Minimap, "BOTTOMLEFT", 2, 2)
            end
        end
        -- 插件隔間
        ReparentButton(AddonCompartmentFrame, "TOPRIGHT", Minimap, "TOPRIGHT", -2, -20)
        -- 行事曆
        ReparentButton(GameTimeFrame, "TOPRIGHT", Minimap, "TOPRIGHT", -22, -2)
        -- 排隊狀態
        ReparentButton(QueueStatusMinimapButton, "BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -2, 2)

        -- ExpansionLandingPageMinimapButton（雙刀按鈕）
        if ExpansionLandingPageMinimapButton then
            pcall(function()
                ExpansionLandingPageMinimapButton:SetParent(Minimap)
                ExpansionLandingPageMinimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 5)
                ExpansionLandingPageMinimapButton:ClearAllPoints()
                ExpansionLandingPageMinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, 4)
                ExpansionLandingPageMinimapButton:SetSize(32, 32)
                ExpansionLandingPageMinimapButton:SetAlpha(1)
                ExpansionLandingPageMinimapButton:Show()

                -- 暴雪的 SetTooltip 在 reparent 後會報錯（nil text）
                -- 用 pcall 包裝原始 OnEnter 來壓制
                local origOnEnter = ExpansionLandingPageMinimapButton:GetScript("OnEnter")
                if origOnEnter then
                    ExpansionLandingPageMinimapButton:SetScript("OnEnter", function(self, ...)
                        pcall(origOnEnter, self, ...)
                    end)
                end
            end)
        end
    end)

    -- 2. 隱藏 MinimapCluster（裝飾性框架）
    if MinimapCluster then
        pcall(function()
            MinimapCluster:EnableMouse(false)
            MinimapCluster:SetAlpha(0)
            MinimapCluster:ClearAllPoints()
            MinimapCluster:SetPoint("TOP", UIParent, "BOTTOM", 0, -2000)

            -- 隱藏剩餘的子框架（有用的已 reparent 走）
            for _, child in ipairs({ MinimapCluster:GetChildren() }) do
                if child and child ~= Minimap then
                    pcall(function()
                        child:SetAlpha(0)
                        child:EnableMouse(false)
                    end)
                end
            end

            -- 隱藏所有 regions（材質/字型等）
            for _, region in ipairs({ MinimapCluster:GetRegions() }) do
                pcall(function()
                    region:SetAlpha(0)
                    if region.Hide then region:Hide() end
                end)
            end
        end)
    end

    -- 舊版追蹤按鈕
    if MiniMapTracking then
        pcall(function()
            MiniMapTracking:SetParent(Minimap)
            if MiniMapTrackingBackground then
                MiniMapTrackingBackground:Hide()
            end
        end)
    end

    -- 3. ★ 隱藏 Minimap 自身的裝飾子框架（MinimapBackdrop 就是圓形邊框）
    pcall(function()
        if MinimapBackdrop then
            MinimapBackdrop:Hide()
            MinimapBackdrop:SetAlpha(0)
        end
    end)
    -- 隱藏 Minimap 的所有非必要子框架
    for _, child in ipairs({ Minimap:GetChildren() }) do
        local name = child:GetName()
        if name and (name:find("Backdrop") or name:find("Border") or name:find("Background")) then
            pcall(function()
                child:Hide()
                child:SetAlpha(0)
            end)
        end
    end

    -- 4. 方形遮罩（使用已驗證的 WHITE8X8 材質）
    Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")



    -- 6b. ★ 關鍵：覆蓋 Minimap.Layout 防止 WoW 重設遮罩/位置
    -- BasicMinimap 同樣這麼做，這是防止系統持續重設小地圖的關鍵
    Minimap.Layout = function() end

    -- 7. 完整清除 blob 環形（Scalar + Alpha 都要）
    pcall(function() Minimap:SetArchBlobRingScalar(0) end)
    pcall(function() Minimap:SetArchBlobRingAlpha(0) end)
    pcall(function() Minimap:SetQuestBlobRingScalar(0) end)
    pcall(function() Minimap:SetQuestBlobRingAlpha(0) end)
    pcall(function() Minimap:SetArchBlobInsideTexture("") end)
    pcall(function() Minimap:SetArchBlobOutsideTexture("") end)
    pcall(function() Minimap:SetQuestBlobInsideTexture("") end)
    pcall(function() Minimap:SetQuestBlobOutsideTexture("") end)

    -- 8. ★ 關鍵：處理 HybridMinimap（室內/副本地圖覆蓋層的圓形遮罩）
    if HybridMinimap then
        pcall(function()
            HybridMinimap.CircleMask:SetTexture("Interface\\BUTTONS\\WHITE8X8")
            HybridMinimap.MapCanvas:SetUseMaskTexture(false)
            HybridMinimap.MapCanvas:SetUseMaskTexture(true)
        end)
    end

    -- 9. 縮放
    Minimap:EnableMouseWheel(true)
    Minimap:HookScript("OnMouseWheel", function(_self, delta)
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
    minimapFrame:SetScript("OnDragStart", function(_self)
        if IsShiftKeyDown() then
            minimapFrame:StartMoving()
        end
    end)
    minimapFrame:SetScript("OnDragStop", function(_self)
        minimapFrame:StopMovingOrSizing()
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

    -- 建立按鈕整理框架（MinimapCluster 已隱藏，必須重新掛載按鈕）
    buttonFrame = CreateFrame("Frame", "LunarUI_MinimapButtons", minimapFrame, "BackdropTemplate")
    buttonFrame:SetPoint("TOPLEFT", minimapFrame, "BOTTOMLEFT", 0, -6)
    buttonFrame:SetSize(100, 50)
    buttonFrame:SetBackdrop(backdropTemplate)
    buttonFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
    buttonFrame:SetBackdropBorderColor(0.15, 0.12, 0.08, 0.8)
    buttonFrame:Hide()

    -- 註冊事件
    minimapFrame:RegisterEvent("ZONE_CHANGED")
    minimapFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    minimapFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    minimapFrame:SetScript("OnEvent", function(_self, _event)
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
    -- 使用 HookScript 而非 SetScript 以避免 taint
    Minimap:HookScript("OnMouseUp", function(_self, button)
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
    mail:SetScript("OnEvent", function(_self)
        if HasNewMail() then
            mail:Show()
        else
            mail:Hide()
        end
    end)

    mail:SetScript("OnEnter", function(_self)
        GameTooltip:SetOwner(mail, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("You have mail!")
        GameTooltip:Show()
    end)

    mail:SetScript("OnLeave", function(_self)
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

    CreateMinimapFrame()           -- 先建立框架、reparent Minimap
    HideBlizzardMinimapElements()  -- 再隱藏裝飾

    -- 監聽 Blizzard_HybridMinimap 按需載入
    -- HybridMinimap 在進入副本/室內時才載入，需要在載入時套用方形遮罩
    local addonLoadedFrame = CreateFrame("Frame")
    addonLoadedFrame:RegisterEvent("ADDON_LOADED")
    addonLoadedFrame:SetScript("OnEvent", function(self, _event, addon)
        if addon == "Blizzard_HybridMinimap" then
            self:UnregisterEvent("ADDON_LOADED")
            if HybridMinimap then
                pcall(function()
                    HybridMinimap.MapCanvas:SetUseMaskTexture(false)
                    HybridMinimap.CircleMask:SetTexture("Interface\\BUTTONS\\WHITE8X8")
                    HybridMinimap.MapCanvas:SetUseMaskTexture(true)
                end)
            end
        end
    end)

    -- 註冊至框架移動器
    if minimapFrame then
        LunarUI:RegisterMovableFrame("Minimap", minimapFrame, "小地圖")
    end

    -- 建立指示器
    CreateMailIndicator()
    CreateDifficultyIndicator()

    -- 早期掃描：在隱藏 Cluster 之前按鈕仍可見
    ScanForMinimapButtons()

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
function LunarUI.CleanupMinimap()
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
