---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 小地圖模組
    Lunar 主題風格的統一小地圖

    功能：
    - 自訂邊框（Lunar 主題）
    - 按鈕整理（LibDBIcon 支援）
    - 座標顯示
    - 區域文字樣式化
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors

-- 覆寫形狀函數（備份原始版本以便清理時還原）
local originalGetMinimapShape = GetMinimapShape
function GetMinimapShape() return "SQUARE" end

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local MINIMAP_SIZE = 180
local BORDER_SIZE = 4
local COORD_UPDATE_INTERVAL = 0.2

local backdropTemplate = LunarUI.backdropTemplate
local format = string.format

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local minimapFrame
local coordText
local zoneText
local clockText
local buttonFrame
local collectedButtons = {}
local zoomResetHandle       -- 縮放自動重置計時器
local addonLoadedFrame      -- ADDON_LOADED 事件監聽框架
local buttonScanTimers = {} -- 按鈕掃描延遲計時器

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
        local coordString = format("%.1f, %.1f", x, y)
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

    local db = LunarUI.db and LunarUI.db.profile.minimap
    local hour, minute = GetGameTime()
    local clockString

    if db and db.clockFormat == "12h" then
        local suffix = hour >= 12 and "PM" or "AM"
        hour = hour % 12
        if hour == 0 then hour = 12 end
        clockString = format("%d:%02d %s", hour, minute, suffix)
    else
        clockString = format("%02d:%02d", hour, minute)
    end

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

    -- 跳過系統按鈕和由 ApplyIconSettings 管理的按鈕
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
        "LunarUI_MinimapMail",
        "LunarUI_MinimapDifficulty",
        "AddonCompartmentFrame",
        "QueueStatusMinimapButton",
        "ExpansionLandingPageMinimapButton",
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
-- 小地圖樣式化
--------------------------------------------------------------------------------

local function HideBlizzardMinimapElements()
    -- 1. 把有用的 MinimapCluster 子元素 reparent 到 Minimap 並重設位置
    -- 原始錨點可能指向 MinimapCluster（即將移走），必須重設
    local SafeCall = LunarUI.SafeCall
    local function ReparentButton(button, anchor, relFrame, relAnchor, x, y)
        if not button then return end
        SafeCall(function()
            button:SetParent(Minimap)
            button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
            button:ClearAllPoints()
            button:SetPoint(anchor, relFrame or Minimap, relAnchor or anchor, x or 0, y or 0)
            button:SetAlpha(1)
            button:Show()
        end, "ReparentButton")
    end

    SafeCall(function()
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
            local btn = ExpansionLandingPageMinimapButton
            ReparentButton(btn, "TOPLEFT", Minimap, "TOPLEFT", -4, 4)

            -- title/description fallback 防止 SetTooltip nil 錯誤
            if not btn.title then btn.title = "" end
            if not btn.description then btn.description = "" end

            -- 縮小按鈕到合理大小，同時讓內部材質跟著縮
            local TARGET_SIZE = 36
            btn:SetSize(TARGET_SIZE, TARGET_SIZE)
            btn:SetHitRectInsets(0, 0, 0, 0)

            -- 讓內部材質與子框架都填滿按鈕範圍（修正點擊/高亮區域不一致）
            for _, region in ipairs({ btn:GetRegions() }) do
                if region:IsObjectType("Texture") then
                    SafeCall(function()
                        region:ClearAllPoints()
                        region:SetAllPoints(btn)
                    end, "ExpansionButton region")
                end
            end
            for _, child in ipairs({ btn:GetChildren() }) do
                SafeCall(function()
                    child:SetSize(TARGET_SIZE, TARGET_SIZE)
                    child:ClearAllPoints()
                    child:SetAllPoints(btn)
                end, "ExpansionButton child")
            end

            -- 防止暴雪把大小改回去
            local settingSize = false
            hooksecurefunc(btn, "SetSize", function(self, w, h)
                if settingSize then return end
                if w ~= TARGET_SIZE or h ~= TARGET_SIZE then
                    settingSize = true
                    self:SetSize(TARGET_SIZE, TARGET_SIZE)
                    settingSize = false
                end
            end)
        end
    end, "MinimapCluster reparent")

    -- 2. 隱藏 MinimapCluster（裝飾性框架）
    if MinimapCluster then
        SafeCall(function()
            MinimapCluster:EnableMouse(false)
            MinimapCluster:SetAlpha(0)
            MinimapCluster:ClearAllPoints()
            MinimapCluster:SetPoint("TOP", UIParent, "BOTTOM", 0, -2000)

            -- 隱藏剩餘的子框架（有用的已 reparent 走）
            for _, child in ipairs({ MinimapCluster:GetChildren() }) do
                if child and child ~= Minimap then
                    SafeCall(function()
                        child:SetAlpha(0)
                        child:EnableMouse(false)
                    end, "MinimapCluster child")
                end
            end

            -- 隱藏所有 regions（材質/字型等）
            for _, region in ipairs({ MinimapCluster:GetRegions() }) do
                SafeCall(function()
                    region:SetAlpha(0)
                    if region.Hide then region:Hide() end
                end, "MinimapCluster region")
            end
        end, "MinimapCluster hide")
    end

    -- 舊版追蹤按鈕
    if MiniMapTracking then
        SafeCall(function()
            MiniMapTracking:SetParent(Minimap)
            if MiniMapTrackingBackground then
                MiniMapTrackingBackground:Hide()
            end
        end, "MiniMapTracking")
    end

    -- 3. ★ 隱藏 Minimap 自身的裝飾子框架（MinimapBackdrop 就是圓形邊框）
    SafeCall(function()
        if MinimapBackdrop then
            MinimapBackdrop:Hide()
            MinimapBackdrop:SetAlpha(0)
        end
    end, "MinimapBackdrop")
    -- 隱藏 Minimap 的所有非必要子框架
    for _, child in ipairs({ Minimap:GetChildren() }) do
        local name = child:GetName()
        if name and (name:find("Backdrop") or name:find("Border") or name:find("Background")) then
            SafeCall(function()
                child:Hide()
                child:SetAlpha(0)
            end, "Minimap child " .. name)
        end
    end

    -- 隱藏縮放按鈕（已有滑鼠滾輪縮放，避免與時鐘文字重疊）
    SafeCall(function()
        if MinimapZoomIn then MinimapZoomIn:Hide(); MinimapZoomIn:SetAlpha(0) end
        if MinimapZoomOut then MinimapZoomOut:Hide(); MinimapZoomOut:SetAlpha(0) end
    end, "MinimapZoom")

    -- 4. 方形遮罩（使用已驗證的 WHITE8X8 材質）
    Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")



    -- 6b. ★ 關鍵：覆蓋 Minimap.Layout 防止 WoW 重設遮罩/位置
    -- BasicMinimap 同樣這麼做，這是防止系統持續重設小地圖的關鍵
    Minimap.Layout = function() end

    -- 7. 完整清除 blob 環形（Scalar + Alpha 都要）
    SafeCall(function() Minimap:SetArchBlobRingScalar(0) end, "ArchBlobRingScalar")
    SafeCall(function() Minimap:SetArchBlobRingAlpha(0) end, "ArchBlobRingAlpha")
    SafeCall(function() Minimap:SetQuestBlobRingScalar(0) end, "QuestBlobRingScalar")
    SafeCall(function() Minimap:SetQuestBlobRingAlpha(0) end, "QuestBlobRingAlpha")
    SafeCall(function() Minimap:SetArchBlobInsideTexture("") end, "ArchBlobInside")
    SafeCall(function() Minimap:SetArchBlobOutsideTexture("") end, "ArchBlobOutside")
    SafeCall(function() Minimap:SetQuestBlobInsideTexture("") end, "QuestBlobInside")
    SafeCall(function() Minimap:SetQuestBlobOutsideTexture("") end, "QuestBlobOutside")

    -- 8. ★ 關鍵：處理 HybridMinimap（室內/副本地圖覆蓋層的圓形遮罩）
    if HybridMinimap and HybridMinimap.CircleMask and HybridMinimap.MapCanvas then
        SafeCall(function()
            HybridMinimap.CircleMask:SetTexture("Interface\\BUTTONS\\WHITE8X8")
            HybridMinimap.MapCanvas:SetUseMaskTexture(false)
            HybridMinimap.MapCanvas:SetUseMaskTexture(true)
        end, "HybridMinimap mask")
    end

    -- 9. 縮放
    Minimap:EnableMouseWheel(true)
    Minimap:HookScript("OnMouseWheel", function(_self, delta)
        if delta > 0 then
            Minimap_ZoomIn()
        else
            Minimap_ZoomOut()
        end
        -- 縮放自動重置計時器
        local db = LunarUI.db and LunarUI.db.profile.minimap
        local delay = db and db.resetZoomTimer or 0
        if delay > 0 then
            if zoomResetHandle then
                zoomResetHandle:Cancel()
            end
            zoomResetHandle = C_Timer.NewTimer(delay, function()
                Minimap:SetZoom(0)
                zoomResetHandle = nil
            end)
        end
    end)
end

local function CreateMinimapFrame()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not db.enabled then return end

    local size = db.size or MINIMAP_SIZE
    local bc = db.borderColor or { r = 0.15, g = 0.12, b = 0.08, a = 1 }
    local zoneFontSize = db.zoneFontSize or 12
    local zoneFontOutline = db.zoneFontOutline or "OUTLINE"
    local coordFontSize = db.coordFontSize or 10
    local coordFontOutline = db.coordFontOutline or "OUTLINE"

    -- 建立主容器
    minimapFrame = CreateFrame("Frame", "LunarUI_Minimap", UIParent, "BackdropTemplate")
    minimapFrame:SetSize(size + BORDER_SIZE * 2, size + BORDER_SIZE * 2)
    minimapFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    minimapFrame:SetBackdrop(backdropTemplate)
    minimapFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.8)
    minimapFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
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
    minimapFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- 拖曳結束後重新檢查淡出狀態（OnLeave 在拖曳期間不會觸發）
        local onLeave = self:GetScript("OnLeave")
        if onLeave and not self:IsMouseOver() then
            onLeave(self)
        end
    end)

    -- 重新設定 Minimap 父框架與大小
    Minimap:SetParent(minimapFrame)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", minimapFrame, "CENTER", 0, 0)
    Minimap:SetSize(size, size)
    Minimap:SetFrameLevel(minimapFrame:GetFrameLevel() + 1)

    -- 建立區域文字
    zoneText = minimapFrame:CreateFontString(nil, "OVERLAY")
    zoneText:SetFont(STANDARD_TEXT_FONT, zoneFontSize, zoneFontOutline)
    zoneText:SetPoint("TOP", minimapFrame, "BOTTOM", 0, -4)
    zoneText:SetTextColor(0.9, 0.9, 0.9)
    zoneText:SetJustifyH("CENTER")
    zoneText:SetWidth(size)
    zoneText:SetWordWrap(false)

    -- 建立座標文字（掛在 Minimap 上，避免被 Minimap 的較高 frame level 遮住）
    coordText = Minimap:CreateFontString(nil, "OVERLAY")
    coordText:SetFont(STANDARD_TEXT_FONT, coordFontSize, coordFontOutline)
    coordText:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 4)
    coordText:SetTextColor(0.8, 0.8, 0.6)
    coordText:SetJustifyH("CENTER")
    if not db.showCoords then coordText:Hide() end

    -- 建立時鐘文字（掛在 Minimap 上，避免被遮住；左下角避免與右側圖示重疊）
    clockText = Minimap:CreateFontString(nil, "OVERLAY")
    clockText:SetFont(STANDARD_TEXT_FONT, coordFontSize, coordFontOutline)
    clockText:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 4, 4)
    clockText:SetTextColor(0.7, 0.7, 0.7)
    clockText:SetJustifyH("LEFT")
    if not db.showClock then clockText:Hide() end

    -- 建立按鈕整理框架（MinimapCluster 已隱藏，必須重新掛載按鈕）
    buttonFrame = CreateFrame("Frame", "LunarUI_MinimapButtons", minimapFrame, "BackdropTemplate")
    buttonFrame:SetPoint("TOPLEFT", minimapFrame, "BOTTOMLEFT", 0, -6)
    buttonFrame:SetSize(100, 50)
    buttonFrame:SetBackdrop(backdropTemplate)
    buttonFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.6)
    buttonFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a * 0.8)
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
            -- 使用安全的選單 API 而非直接 Click() 安全按鈕（避免 taint）
            if MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button then
                local btn = MinimapCluster.Tracking.Button
                if btn.OpenMenu then
                    btn:OpenMenu()
                elseif btn.ToggleMenu then
                    btn:ToggleMenu()
                else
                    -- 最後手段：包在 SafeCall 中避免戰鬥中報錯
                    LunarUI.SafeCall(function() btn:Click() end, "TrackingButton Click")
                end
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
-- 區域文字顯示模式
--------------------------------------------------------------------------------

local function ApplyZoneTextDisplayMode(mode)
    if not zoneText or not minimapFrame then return end

    if mode == "HIDE" then
        zoneText:Hide()
    elseif mode == "MOUSEOVER" then
        zoneText:SetAlpha(0)
        zoneText:Show()
    else -- "SHOW"
        zoneText:SetAlpha(1)
        zoneText:Show()
    end
end

--------------------------------------------------------------------------------
-- 每個圖示獨立設定
--------------------------------------------------------------------------------

local function GetIconFrameMap()
    return {
        calendar    = GameTimeFrame,
        tracking    = MinimapCluster and MinimapCluster.Tracking,
        mail        = _G["LunarUI_MinimapMail"],
        difficulty  = _G["LunarUI_MinimapDifficulty"],
        lfg         = QueueStatusMinimapButton,
        expansion   = ExpansionLandingPageMinimapButton,
        compartment = AddonCompartmentFrame,
    }
end

-- mail 和 difficulty 由自身事件處理器控制顯示/隱藏（HasNewMail / GetInstanceInfo）
-- ApplyIconSettings 不應對它們強制 Show()，只設定位置和縮放
local SELF_MANAGED_ICONS = { mail = true, difficulty = true }

local function ApplyIconSettings()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not db.icons then return end

    local map = GetIconFrameMap()
    for key, iconDB in pairs(db.icons) do
        if type(iconDB) ~= "table" then break end
        local frame = map[key]
        if frame then
            if iconDB.hide then
                frame:Hide()
                frame:SetAlpha(0)
            else
                frame:SetAlpha(1)
                frame:ClearAllPoints()
                frame:SetPoint(
                    iconDB.position or "CENTER",
                    Minimap,
                    iconDB.position or "CENTER",
                    iconDB.xOffset or 0,
                    iconDB.yOffset or 0
                )
                frame:SetScale(iconDB.scale or 1.0)
                -- mail/difficulty 由自身事件決定顯示，其餘圖示直接 Show
                if not SELF_MANAGED_ICONS[key] then
                    frame:Show()
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 滑鼠離開淡出
--------------------------------------------------------------------------------

-- 安全的淡入淡出輔助（使用 AnimationGroup 避免 UIFrameFade taint）
local function FadeTo(frame, targetAlpha, duration)
    if not frame then return end
    -- 停止進行中的淡出動畫
    if frame._lunarFader and frame._lunarFader:IsPlaying() then
        frame._lunarFader:Stop()
    end

    if not duration or duration <= 0 then
        frame:SetAlpha(targetAlpha)
        return
    end

    -- 建立或重用 AnimationGroup
    if not frame._lunarFader then
        frame._lunarFader = frame:CreateAnimationGroup()
        frame._lunarFadeAnim = frame._lunarFader:CreateAnimation("Alpha")
        local function applyTargetAlpha()
            frame:SetAlpha(frame._lunarFadeTarget or targetAlpha)
        end
        frame._lunarFader:SetScript("OnFinished", applyTargetAlpha)
        frame._lunarFader:SetScript("OnStop", applyTargetAlpha)
    end

    local anim = frame._lunarFadeAnim
    local currentAlpha = frame:GetAlpha()
    frame._lunarFadeTarget = targetAlpha

    anim:SetFromAlpha(currentAlpha)
    anim:SetToAlpha(targetAlpha)
    anim:SetDuration(duration)
    frame._lunarFader:Play()
end

local function ApplyMouseFade()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not minimapFrame then return end

    local fadeEnabled = db.fadeOnMouseLeave
    local zoneMode = db.zoneTextDisplay or "SHOW"
    local fadeAlpha = db.fadeAlpha or 0.5
    local fadeDuration = db.fadeDuration or 0.3

    -- 統一 OnEnter/OnLeave handler（同時處理 zone text mouseover + frame fade）
    minimapFrame:SetScript("OnEnter", function(self)
        if fadeEnabled then
            FadeTo(self, 1.0, fadeDuration)
        end
        if zoneMode == "MOUSEOVER" and zoneText then
            FadeTo(zoneText, 1.0, 0.2)
        end
    end)

    minimapFrame:SetScript("OnLeave", function(self)
        if fadeEnabled then
            FadeTo(self, fadeAlpha, fadeDuration)
        end
        if zoneMode == "MOUSEOVER" and zoneText then
            FadeTo(zoneText, 0, 0.2)
        end
    end)

    -- 初始狀態：如果淡出啟用且滑鼠不在上面
    if fadeEnabled and not minimapFrame:IsMouseOver() then
        minimapFrame:SetAlpha(fadeAlpha)
    end
end

--------------------------------------------------------------------------------
-- 圖釘縮放
--------------------------------------------------------------------------------

local function ApplyPinScale()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    local scale = db and db.pinScale or 1.0
    if Minimap.SetPinScale then
        Minimap:SetPinScale(scale)
    end
end

--------------------------------------------------------------------------------
-- RefreshMinimap — 原地刷新所有設定（不重建框架）
--------------------------------------------------------------------------------

function LunarUI.RefreshMinimap()
    local db = LunarUI.db and LunarUI.db.profile.minimap
    if not db or not minimapFrame then return end

    local size = db.size or MINIMAP_SIZE
    local bc = db.borderColor or { r = 0.15, g = 0.12, b = 0.08, a = 1 }

    -- 調整大小
    minimapFrame:SetSize(size + BORDER_SIZE * 2, size + BORDER_SIZE * 2)
    Minimap:SetSize(size, size)

    -- 邊框顏色
    minimapFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
    if buttonFrame then
        buttonFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a * 0.8)
    end

    -- 區域文字字體 + 寬度
    if zoneText then
        local zoneFontSize = db.zoneFontSize or 12
        local zoneFontOutline = db.zoneFontOutline or "OUTLINE"
        zoneText:SetFont(STANDARD_TEXT_FONT, zoneFontSize, zoneFontOutline)
        zoneText:SetWidth(size)
    end
    ApplyZoneTextDisplayMode(db.zoneTextDisplay or "SHOW")

    -- 座標文字
    if coordText then
        local coordFontSize = db.coordFontSize or 10
        local coordFontOutline = db.coordFontOutline or "OUTLINE"
        coordText:SetFont(STANDARD_TEXT_FONT, coordFontSize, coordFontOutline)
        if db.showCoords then
            coordText:Show()
        else
            coordText:Hide()
        end
    end

    -- 時鐘文字
    if clockText then
        local coordFontSize = db.coordFontSize or 10
        local coordFontOutline = db.coordFontOutline or "OUTLINE"
        clockText:SetFont(STANDARD_TEXT_FONT, coordFontSize, coordFontOutline)
        if db.showClock then
            clockText:Show()
            lastClockString = nil  -- 強制重繪（格式可能改變）
        else
            clockText:Hide()
        end
    end

    -- 每個圖示獨立設定
    ApplyIconSettings()

    -- 滑鼠離開淡出
    ApplyMouseFade()

    -- 圖釘縮放
    ApplyPinScale()

    -- 重新整理按鈕
    if db.organizeButtons then
        ScanForMinimapButtons()
    end
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
    addonLoadedFrame = CreateFrame("Frame")
    addonLoadedFrame:RegisterEvent("ADDON_LOADED")
    addonLoadedFrame:SetScript("OnEvent", function(self, _event, addon)
        if addon == "Blizzard_HybridMinimap" then
            self:UnregisterEvent("ADDON_LOADED")
            if HybridMinimap and HybridMinimap.CircleMask and HybridMinimap.MapCanvas then
                LunarUI.SafeCall(function()
                    HybridMinimap.MapCanvas:SetUseMaskTexture(false)
                    HybridMinimap.CircleMask:SetTexture("Interface\\BUTTONS\\WHITE8X8")
                    HybridMinimap.MapCanvas:SetUseMaskTexture(true)
                end, "HybridMinimap ADDON_LOADED")
            end
        end
    end)

    -- 註冊至框架移動器
    if minimapFrame then
        LunarUI:RegisterMovableFrame("Minimap", minimapFrame, "小地圖")
    end

    -- 建立指示器（必須在 ApplyIconSettings 之前，否則自訂指示器框架尚未建立）
    CreateMailIndicator()
    CreateDifficultyIndicator()

    -- 套用每個圖示獨立設定（必須在指示器建立之後）
    ApplyIconSettings()

    -- 早期掃描：在隱藏 Cluster 之前按鈕仍可見
    ScanForMinimapButtons()

    -- 多次掃描按鈕以捕捉延遲載入的插件（如 DBM）
    wipe(buttonScanTimers)
    buttonScanTimers[1] = C_Timer.NewTimer(2, ScanForMinimapButtons)
    buttonScanTimers[2] = C_Timer.NewTimer(5, ScanForMinimapButtons)
    buttonScanTimers[3] = C_Timer.NewTimer(10, ScanForMinimapButtons)

    -- 套用區域文字顯示模式
    ApplyZoneTextDisplayMode(db.zoneTextDisplay or "SHOW")

    -- 套用滑鼠離開淡出
    ApplyMouseFade()

    -- 套用圖釘縮放
    ApplyPinScale()

    -- 初始更新
    UpdateZoneText()
    UpdateCoordinates()
    UpdateClock()
end

-- OnUpdate 清理函數
function LunarUI.CleanupMinimap()
    -- 取消縮放重置計時器
    if zoomResetHandle then
        zoomResetHandle:Cancel()
        zoomResetHandle = nil
    end
    -- 取消按鈕掃描計時器
    if buttonScanTimers then
        for _, handle in ipairs(buttonScanTimers) do
            if handle and handle.Cancel then handle:Cancel() end
        end
        wipe(buttonScanTimers)
    end
    if minimapFrame then
        minimapFrame:SetScript("OnUpdate", nil)
        minimapFrame:SetScript("OnEvent", nil)
    end
    -- 清理 ADDON_LOADED 框架
    if addonLoadedFrame then
        addonLoadedFrame:UnregisterAllEvents()
        addonLoadedFrame:SetScript("OnEvent", nil)
        addonLoadedFrame = nil
    end
    -- 還原 GetMinimapShape 全域函數
    if originalGetMinimapShape then
        GetMinimapShape = originalGetMinimapShape
    end
end

-- 匯出
LunarUI.InitializeMinimap = InitializeMinimap
LunarUI.minimapFrame = minimapFrame
-- RefreshMinimap 已在上方定義為 LunarUI:RefreshMinimap()

LunarUI:RegisterModule("Minimap", {
    onEnable = InitializeMinimap,
    onDisable = function() LunarUI:CleanupMinimap() end,
    delay = 0.5,
})
