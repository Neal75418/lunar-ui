--[[
    LunarUI - 小地圖按鈕整理（Button Corral）
    從 Modules/Minimap.lua 抽出，負責：
    - 掃描 Minimap / MinimapBackdrop / MinimapCluster 子框架找 addon 按鈕
    - 跳過系統按鈕與 LunarUI 自己的按鈕
    - 依 addon 名稱優先排序、統一大小、重排到容器 frame
    - 清除邊框材質但保留圖示

    暴露於 LunarUI.MinimapButtons 命名空間：
      SetContainer(frame)  — 主模組建立好容器 frame 後注入
      Scan()               — 掃描 + 排序 + 重排（idempotent，可反覆呼叫）
      Reset()              — cleanup 時清空 collected 狀態
]]

local _, Engine = ...
local LunarUI = Engine.LunarUI
local mathFloor = math.floor
local mathCeil = math.ceil
local mathMin = math.min
local tableInsert = table.insert
local tableSort = table.sort

local collectedButtons = {}
local scannedButtonIDs = {}
local buttonFrame = nil

-- 跳過系統按鈕和由 LunarUI 管理的按鈕（O(1) hash set）
local SKIP_BUTTONS = {
    ["MiniMapTracking"] = true,
    ["MiniMapMailFrame"] = true,
    ["MinimapZoomIn"] = true,
    ["MinimapZoomOut"] = true,
    ["Minimap"] = true,
    ["MinimapBackdrop"] = true,
    ["GameTimeFrame"] = true,
    ["TimeManagerClockButton"] = true,
    ["LunarUI_MinimapButton"] = true,
    ["LunarUI_MinimapMail"] = true,
    ["LunarUI_MinimapDifficulty"] = true,
    ["AddonCompartmentFrame"] = true,
    ["QueueStatusMinimapButton"] = true,
    ["ExpansionLandingPageMinimapButton"] = true,
}

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

-- 掃描前清理過期的按鈕參照（原地壓縮，保留原始順序，避免每次建立新 table）
-- 以框架有效性（GetObjectType 可呼叫）判斷，而非 IsShown()，
-- 避免暫時隱藏的合法按鈕被誤刪
local function ClearStaleButtonReferences()
    local writeIdx = 0
    for i = 1, #collectedButtons do
        local button = collectedButtons[i]
        if button and button.GetObjectType then
            writeIdx = writeIdx + 1
            collectedButtons[writeIdx] = button
        end
    end
    -- 清除尾部殘留的舊參照
    for i = writeIdx + 1, #collectedButtons do
        collectedButtons[i] = nil
    end
    -- 從存活的按鈕重建 scannedButtonIDs（避免下次掃描重複加入）
    wipe(scannedButtonIDs)
    for i = 1, writeIdx do
        local name = collectedButtons[i] and collectedButtons[i]:GetName()
        if name then
            scannedButtonIDs[name] = true
        end
    end
end

local function CollectMinimapButton(button)
    if not button then
        return
    end
    if not (button:IsObjectType("Button") or button:IsObjectType("Frame")) then
        return
    end

    local name = button:GetName()
    if not name then
        return
    end

    -- 使用雜湊表進行 O(1) 重複檢查
    if scannedButtonIDs[name] then
        return
    end

    if SKIP_BUTTONS[name] then
        return
    end

    -- 標記為已掃描並加入集合
    scannedButtonIDs[name] = true
    tableInsert(collectedButtons, button)
end

local function GetButtonPriority(button)
    local name = button:GetName() or ""

    -- 對照優先順序清單
    for addon, priority in pairs(BUTTON_PRIORITY) do
        if name:find(addon) then
            return priority
        end
    end

    -- 預設:按字母排序(優先順序 100+)
    return 100
end

local function SortButtons()
    tableSort(collectedButtons, function(a, b)
        local priorityA = GetButtonPriority(a)
        local priorityB = GetButtonPriority(b)

        if priorityA ~= priorityB then
            return priorityA < priorityB
        end

        -- 同優先順序:按名稱排序
        local nameA = a:GetName() or ""
        local nameB = b:GetName() or ""
        return nameA < nameB
    end)
end

local function OrganizeMinimapButtons()
    if not buttonFrame then
        return
    end

    -- 整理前先依優先順序排序
    SortButtons()

    local buttonsPerRow = 6
    local buttonSize = 24
    local spacing = 2

    -- 戰鬥中不操作 SetParent（minimap 按鈕可能為 protected frame）
    if InCombatLockdown() then
        return
    end

    local visibleIdx = 0
    for _, button in ipairs(collectedButtons) do
        if button and button:IsShown() then
            visibleIdx = visibleIdx + 1
            button:SetParent(buttonFrame)
            button:ClearAllPoints()

            local row = mathFloor((visibleIdx - 1) / buttonsPerRow)
            local col = (visibleIdx - 1) % buttonsPerRow

            button:SetPoint(
                "TOPLEFT",
                buttonFrame,
                "TOPLEFT",
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
                        if
                            lowerPath:find("minimapbutton")
                            or lowerPath:find("trackingborder")
                            or lowerPath:find("border")
                            or lowerPath:find("background")
                        then
                            region:SetTexture(nil)
                            region:SetAlpha(0)
                        end
                    end
                end
            end
        end
    end

    -- 調整按鈕框架大小（只計算可見按鈕）
    local numButtons = visibleIdx
    local numRows = mathCeil(numButtons / buttonsPerRow)
    local width = mathMin(numButtons, buttonsPerRow) * (buttonSize + spacing) - spacing
    local height = numRows * (buttonSize + spacing) - spacing

    if width > 0 and height > 0 then
        buttonFrame:SetSize(width, height)
        buttonFrame:Show()
    else
        buttonFrame:Hide()
    end
end

local function Scan()
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

--- 主模組建立好容器 frame 後呼叫，注入參照給 Organize 使用
local function SetContainer(frame)
    buttonFrame = frame
end

--- Cleanup 時呼叫。清空 state，讓後續 /lunar on 重新掃描乾淨
local function Reset()
    wipe(collectedButtons)
    wipe(scannedButtonIDs)
    buttonFrame = nil
end

LunarUI.MinimapButtons = {
    SetContainer = SetContainer,
    Scan = Scan,
    Reset = Reset,
}
