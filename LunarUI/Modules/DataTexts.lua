---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - DataTexts 模組
    可配置的文字資訊面板（FPS、延遲、金幣、耐久度、背包空位等）

    Features:
    - Provider-based architecture (register custom data sources)
    - Multiple panel positions (bottom, minimap bottom)
    - Configurable slot assignments
    - Click handlers and tooltips per provider
    - Phase-aware alpha
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local backdropTemplate = LunarUI.backdropTemplate

local format = string.format
local floor = math.floor

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local providers = {} -- 已註冊的資料文字 provider
local onUpdateProviders = {} -- 僅包含 onUpdate=true 的 provider（Fix 1）
local panels = {} -- 已建立的面板框架
local panelFrameCache = {} -- 命名 frame 快取，防止 off/on 重名
local slotsByProvider = {} -- 反向查找：providerName → { slot1, slot2, ... }（Fix 5）
local eventFrame -- 共用事件處理框架
local eventToProviders = {} -- event → { providerName1, providerName2, ... }（Fix 2）

--------------------------------------------------------------------------------
-- Provider 註冊
--------------------------------------------------------------------------------

local function RegisterProvider(name, config)
    providers[name] = config
    config.name = name -- 確保 provider 知道自己的名字
    -- Fix 1: 分離 onUpdate provider
    if config.onUpdate then
        onUpdateProviders[name] = config
    end
    -- Fix 2: 預建 event → provider 查找表
    if config.events then
        for _, event in ipairs(config.events) do
            if not eventToProviders[event] then
                eventToProviders[event] = {}
            end
            eventToProviders[event][#eventToProviders[event] + 1] = name
        end
    end
end

--------------------------------------------------------------------------------
-- 內建 Provider
--------------------------------------------------------------------------------

-- 門檻色彩：值越好越綠，越差越紅
-- invert=true: 值越小越好（latency）; false: 值越大越好（fps）
---@return number, number
local function StatusColor(value, greenThreshold, yellowThreshold, invert)
    local good, warn
    if invert then
        good = value <= greenThreshold
        warn = value <= yellowThreshold
    else
        good = value >= greenThreshold
        warn = value >= yellowThreshold
    end
    if good then
        return 0.3, 1
    elseif warn then
        return 1, 0.8
    else
        return 1, 0.3
    end
end

-- FPS
RegisterProvider("fps", {
    label = "FPS",
    events = {},
    onUpdate = true,
    updateInterval = 1,
    update = function()
        local fps = floor(GetFramerate())
        local r, g = StatusColor(fps, 60, 30, false)
        return format("|cff%02x%02x00%d|r FPS", math.floor(r * 255), math.floor(g * 255), fps)
    end,
    tooltip = function(slot)
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine("FPS", 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Current"] or "Current", floor(GetFramerate()) .. " FPS", 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:Show()
    end,
})

-- 延遲
RegisterProvider("latency", {
    label = L["Latency"] or "Latency",
    events = {},
    onUpdate = true,
    updateInterval = 30,
    update = function()
        local _, _, latencyHome, latencyWorld = GetNetStats()
        local ms = latencyWorld > 0 and latencyWorld or latencyHome
        local r, g = StatusColor(ms, 100, 200, true)
        return format("|cff%02x%02x00%d|r ms", math.floor(r * 255), math.floor(g * 255), ms)
    end,
    tooltip = function(slot)
        local _, _, latencyHome, latencyWorld = GetNetStats()
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Latency"] or "Latency", 1, 1, 1)
        GameTooltip:AddDoubleLine(L["LatencyHome"] or "Home", latencyHome .. " ms", 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:AddDoubleLine(L["LatencyWorld"] or "World", latencyWorld .. " ms", 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:Show()
    end,
})

-- 金幣
RegisterProvider("gold", {
    label = L["Gold"] or "Gold",
    events = { "PLAYER_MONEY", "PLAYER_ENTERING_WORLD" },
    update = function()
        local money = GetMoney()
        local gold = floor(money / 10000)
        local silver = floor((money % 10000) / 100)
        local copper = money % 100
        return format(
            "|cffffd700%d|r|TInterface\\MoneyFrame\\UI-GoldIcon:0|t |cffc7c7cf%d|r|TInterface\\MoneyFrame\\UI-SilverIcon:0|t |cffeda55f%d|r|TInterface\\MoneyFrame\\UI-CopperIcon:0|t",
            gold,
            silver,
            copper
        )
    end,
    tooltip = function(slot)
        local money = GetMoney()
        local gold = floor(money / 10000)
        local silver = floor((money % 10000) / 100)
        local copper = money % 100
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Gold"] or "Gold", 1, 0.84, 0)
        GameTooltip:AddDoubleLine(
            UnitName("player"),
            format(
                "|cffffd700%d|r|TInterface\\MoneyFrame\\UI-GoldIcon:0|t |cffc7c7cf%d|r|TInterface\\MoneyFrame\\UI-SilverIcon:0|t |cffeda55f%d|r|TInterface\\MoneyFrame\\UI-CopperIcon:0|t",
                gold,
                silver,
                copper
            ),
            1,
            1,
            1,
            1,
            1,
            1
        )
        GameTooltip:Show()
    end,
})

-- 耐久度
RegisterProvider("durability", {
    label = L["Durability"] or "Durability",
    events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_ENTERING_WORLD" },
    update = function()
        local lowestDur = 100
        for slot = 1, 18 do
            local cur, max = GetInventoryItemDurability(slot)
            if cur and max and max > 0 then
                local pct = floor(cur / max * 100)
                if pct < lowestDur then
                    lowestDur = pct
                end
            end
        end
        local r, g
        if lowestDur < 25 then
            r, g = 1, 0.3
        elseif lowestDur < 50 then
            r, g = 1, 0.8
        else
            r, g = 0.3, 1
        end
        return format(
            "%s: |cff%02x%02x00%d%%|r",
            L["Durability"] or "Dur",
            math.floor(r * 255),
            math.floor(g * 255),
            lowestDur
        )
    end,
    tooltip = function(slot)
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Durability"] or "Durability", 1, 1, 1)
        local slots = {
            [1] = HEADSLOT or "Head",
            [3] = SHOULDERSLOT or "Shoulder",
            [5] = CHESTSLOT or "Chest",
            [6] = WAISTSLOT or "Waist",
            [7] = LEGSSLOT or "Legs",
            [8] = FEETSLOT or "Feet",
            [9] = WRISTSLOT or "Wrist",
            [10] = HANDSSLOT or "Hands",
            [16] = MAINHANDSLOT or "Main Hand",
            [17] = SECONDARYHANDSLOT or "Off Hand",
        }
        for slotID, name in pairs(slots) do
            local cur, max = GetInventoryItemDurability(slotID)
            if cur and max and max > 0 then
                local pct = floor(cur / max * 100)
                local r, g
                if pct < 25 then
                    r, g = 1, 0.3
                elseif pct < 50 then
                    r, g = 1, 0.8
                else
                    r, g = 0.3, 1
                end
                GameTooltip:AddDoubleLine(name, pct .. "%", 1, 1, 1, r, g, 0)
            end
        end
        GameTooltip:Show()
    end,
})

-- 背包空位
RegisterProvider("bagSlots", {
    label = L["BagSlots"] or "Bag Slots",
    events = { "BAG_UPDATE", "PLAYER_ENTERING_WORLD" },
    update = function()
        local totalFree, totalSlots = 0, 0
        for bag = 0, 4 do
            local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
            local numSlots = C_Container.GetContainerNumSlots(bag)
            totalFree = totalFree + (freeSlots or 0)
            totalSlots = totalSlots + (numSlots or 0)
        end
        local r, g
        if totalFree < 5 then
            r, g = 1, 0.3
        elseif totalFree < 15 then
            r, g = 1, 0.8
        else
            r, g = 0.3, 1
        end
        return format(
            "%s: |cff%02x%02x00%d/%d|r",
            L["BagSlots"] or "Bags",
            math.floor(r * 255),
            math.floor(g * 255),
            totalFree,
            totalSlots
        )
    end,
    tooltip = function(slot)
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["BagSlots"] or "Bag Slots", 1, 1, 1)
        for bag = 0, 4 do
            local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
            local numSlots = C_Container.GetContainerNumSlots(bag)
            if numSlots and numSlots > 0 then
                local name = bag == 0 and (L["Backpack"] or "Backpack") or format("%s %d", L["BagTitle"] or "Bag", bag)
                GameTooltip:AddDoubleLine(name, format("%d / %d", freeSlots or 0, numSlots), 1, 1, 1, 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end,
})

-- 好友上線
RegisterProvider("friends", {
    label = L["Friends"] or "Friends",
    events = {
        "FRIENDLIST_UPDATE",
        "BN_FRIEND_INFO_CHANGED",
        "BN_FRIEND_ACCOUNT_ONLINE",
        "BN_FRIEND_ACCOUNT_OFFLINE",
        "PLAYER_ENTERING_WORLD",
    },
    update = function()
        local _, onlineFriends = C_FriendList.GetNumFriends()
        local bnOnline = 0
        local numBN = BNGetNumFriends() or 0
        for i = 1, numBN do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
                bnOnline = bnOnline + 1
            end
        end
        local total = (onlineFriends or 0) + bnOnline
        return format("%s: |cff00ff00%d|r", L["Friends"] or "Friends", total)
    end,
    click = function()
        ToggleFriendsFrame(1)
    end,
    tooltip = function(slot)
        local _, onlineFriends = C_FriendList.GetNumFriends()
        local numBN = BNGetNumFriends() or 0
        local bnOnline = 0
        for i = 1, numBN do
            local accountInfo = C_BattleNet.GetFriendAccountInfo(i)
            if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
                bnOnline = bnOnline + 1
            end
        end
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Friends"] or "Friends", 1, 1, 1)
        local wowLabel = _G.FRIENDS_LIST_WOW or "WoW"
        local bnetLabel = _G.FRIENDS_LIST_BNET or "Battle.net"
        GameTooltip:AddDoubleLine(
            wowLabel,
            (onlineFriends or 0) .. " " .. (L["Online"] or "online"),
            1,
            1,
            1,
            0.3,
            1,
            0.3
        )
        GameTooltip:AddDoubleLine(bnetLabel, bnOnline .. " " .. (L["Online"] or "online"), 1, 1, 1, 0, 0.7, 1)
        GameTooltip:Show()
    end,
})

-- 公會
RegisterProvider("guild", {
    label = L["Guild"] or "Guild",
    events = { "GUILD_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" },
    update = function()
        if not IsInGuild() then
            return format("%s: |cff999999-|r", L["Guild"] or "Guild")
        end
        -- H1 效能修復：移除 GuildRoster() 網路請求，避免在 GUILD_ROSTER_UPDATE 事件中
        -- 自觸發下一次 GUILD_ROSTER_UPDATE，形成事件風暴
        -- 已快取的 GetNumGuildMembers() 資料已足夠顯示人數
        local _, numOnline = GetNumGuildMembers()
        return format("%s: |cff00ff00%d|r", L["Guild"] or "Guild", numOnline or 0)
    end,
    click = function()
        if IsInGuild() then
            ToggleGuildFrame()
        end
    end,
    tooltip = function(slot)
        if not IsInGuild() then
            return
        end
        local guildName = GetGuildInfo("player")
        local _, numOnline = GetNumGuildMembers()
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(guildName or (L["Guild"] or "Guild"), 0, 0.8, 0)
        GameTooltip:AddDoubleLine(L["Online"] or "Online", numOnline or 0, 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:Show()
    end,
})

-- 專精
RegisterProvider("spec", {
    label = L["Spec"] or "Spec",
    events = { "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_ENTERING_WORLD" },
    update = function()
        local specIndex = GetSpecialization()
        if not specIndex then
            return L["Spec"] or "Spec"
        end
        local _, specName = GetSpecializationInfo(specIndex)
        return specName or (L["Spec"] or "Spec")
    end,
    click = function()
        -- M-8: ToggleTalentFrame 在 WoW 12.0 已改為 C_ClassTalents API
        if _G.ToggleTalentFrame then
            ToggleTalentFrame()
        elseif C_ClassTalents and C_ClassTalents.OpenTalentUI then
            C_ClassTalents.OpenTalentUI()
        end
    end,
    tooltip = function(slot)
        local specIndex = GetSpecialization()
        if not specIndex then
            return
        end
        local _, specName, _, _icon = GetSpecializationInfo(specIndex)
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Spec"] or "Specialization", 1, 1, 1)
        if specName then
            GameTooltip:AddDoubleLine(L["Current"] or "Current", specName, 1, 1, 1, 0.3, 1, 0.3)
        end
        GameTooltip:Show()
    end,
})

-- 時鐘
RegisterProvider("clock", {
    label = L["Clock"] or "Clock",
    events = {},
    onUpdate = true,
    updateInterval = 1,
    update = function()
        local db = LunarUI.GetModuleDB("minimap")
        local is24h = not (db and db.clockFormat == "12h")
        local t = date("*t")
        return LunarUI.FormatGameTime(t.hour, t.min, is24h)
    end,
    tooltip = function(slot)
        local db = LunarUI.GetModuleDB("minimap")
        local is24h = not (db and db.clockFormat == "12h")
        local t = date("*t")
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Clock"] or "Clock", 1, 1, 1)
        GameTooltip:AddDoubleLine(
            L["LocalTime"] or "Local",
            LunarUI.FormatGameTime(t.hour, t.min, is24h),
            1,
            1,
            1,
            1,
            1,
            1
        )
        local serverTime = C_DateAndTime.GetCurrentCalendarTime()
        if serverTime then
            GameTooltip:AddDoubleLine(
                L["ServerTime"] or "Server",
                LunarUI.FormatGameTime(serverTime.hour, serverTime.minute, is24h),
                1,
                1,
                1,
                0.7,
                0.7,
                0.7
            )
        end
        GameTooltip:Show()
    end,
})

-- 座標
RegisterProvider("coords", {
    label = L["Coords"] or "Coords",
    events = {},
    onUpdate = true,
    updateInterval = 0.2,
    update = function()
        local map = C_Map.GetBestMapForUnit("player")
        if not map then
            return "-- , --"
        end
        local pos = C_Map.GetPlayerMapPosition(map, "player")
        if not pos then
            return "-- , --"
        end
        local x, y = pos:GetXY()
        return format("%.1f, %.1f", (x or 0) * 100, (y or 0) * 100)
    end,
    tooltip = function(slot)
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Coords"] or "Coordinates", 1, 1, 1)
        local map = C_Map.GetBestMapForUnit("player")
        if map then
            local info = C_Map.GetMapInfo(map)
            if info then
                GameTooltip:AddDoubleLine(L["Zone"] or "Zone", info.name, 1, 1, 1, 0.7, 0.7, 0.7)
            end
        end
        GameTooltip:Show()
    end,
})

--------------------------------------------------------------------------------
-- 面板建立
--------------------------------------------------------------------------------

local function CreateDataPanel(name, db)
    local frameName = "LunarUI_DataPanel_" .. name
    local panel = panelFrameCache[frameName]
    if panel then
        -- 重用既有 frame，更新尺寸/位置後 Show
        panel:SetSize(db.width or 400, db.height or 22)
        panel:SetPoint(db.point or "BOTTOM", UIParent, db.point or "BOTTOM", db.x or 0, db.y or 0)
        panel:Show()
        return panel
    end
    panel = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    panelFrameCache[frameName] = panel
    panel:SetSize(db.width or 400, db.height or 22)
    panel:SetPoint(db.point or "BOTTOM", UIParent, db.point or "BOTTOM", db.x or 0, db.y or 0)
    panel:SetFrameStrata("LOW")
    panel:SetFrameLevel(1)

    -- 背景框
    if backdropTemplate then
        LunarUI.ApplyBackdrop(panel, nil, C.bgLight)
    else
        -- 備用：簡單背景
        panel.bg = panel:CreateTexture(nil, "BACKGROUND")
        panel.bg:SetAllPoints()
        panel.bg:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], C.bgLight[4])
    end

    -- 建立欄位
    panel.slots = {}
    local numSlots = db.numSlots or 3
    local slotWidth = (db.width or 400) / numSlots

    for i = 1, numSlots do
        local slot = CreateFrame("Button", nil, panel)
        slot:SetSize(slotWidth, db.height or 22)
        slot:SetPoint("LEFT", panel, "LEFT", (i - 1) * slotWidth, 0)

        -- 文字（限制寬度避免溢出）
        slot.text = slot:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(slot.text, 11, "OUTLINE")
        slot.text:SetPoint("CENTER")
        slot.text:SetWidth(slotWidth - 8)
        slot.text:SetWordWrap(false)
        slot.text:SetTextColor(0.9, 0.9, 0.9)

        -- 滑鼠懸停高亮
        slot.highlight = slot:CreateTexture(nil, "HIGHLIGHT")
        slot.highlight:SetAllPoints()
        slot.highlight:SetColorTexture(1, 1, 1, 0.05)

        -- 分隔線（第一欄除外）
        if i > 1 then
            local sep = panel:CreateTexture(nil, "ARTWORK")
            sep:SetSize(1, (db.height or 22) - 6)
            sep:SetPoint("LEFT", slot, "LEFT", 0, 0)
            sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        end

        -- 儲存欄位索引
        slot.slotIndex = i
        slot.panelName = name

        panel.slots[i] = slot
    end

    panel:EnableMouse(true)
    return panel
end

--------------------------------------------------------------------------------
-- Slot 繫結（將欄位連接到 provider）
--------------------------------------------------------------------------------

local function BindSlotToProvider(slot, providerName)
    local provider = providers[providerName]
    if not provider then
        slot.text:SetText("|cff666666-|r")
        slot.providerName = nil
        return
    end

    slot.providerName = providerName
    slot.provider = provider

    -- Fix 5: 登記到反查表
    if not slotsByProvider[providerName] then
        slotsByProvider[providerName] = {}
    end
    slotsByProvider[providerName][#slotsByProvider[providerName] + 1] = slot

    -- 點擊處理
    slot:SetScript("OnClick", function(_self, button)
        if provider.click then
            provider.click(button)
        end
    end)
    slot:RegisterForClicks("AnyUp")

    -- 滑鼠提示
    slot:SetScript("OnEnter", function(btn)
        if provider.tooltip then
            provider.tooltip(btn)
        end
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 初始更新
    if provider.update then
        local text = provider.update()
        if text then
            slot.text:SetText(text)
        end
    end
end

--------------------------------------------------------------------------------
-- 更新系統
--------------------------------------------------------------------------------

local function UpdateProvider(providerName)
    local provider = providers[providerName]
    if not provider or not provider.update then
        return
    end

    local text = provider.update()
    if not text then
        return
    end

    -- Fix 5: 直接查反查表，不遍歷所有面板/欄位
    local slots = slotsByProvider[providerName]
    if slots then
        for i = 1, #slots do
            slots[i].text:SetText(text)
        end
    end
end

local function UpdateAllProviders()
    for name, _ in pairs(providers) do
        UpdateProvider(name)
    end
end

--------------------------------------------------------------------------------
-- OnUpdate 節流（FPS、延遲、時鐘、座標）
--------------------------------------------------------------------------------

local onUpdateFrame
local onUpdateElapsed = {}

local function SetupOnUpdate()
    if onUpdateFrame then
        return
    end

    onUpdateFrame = CreateFrame("Frame")
    -- Fix 1: 只遍歷 onUpdateProviders，不遍歷全部 providers
    onUpdateFrame:SetScript("OnUpdate", function(_, elapsed)
        for name, provider in pairs(onUpdateProviders) do
            onUpdateElapsed[name] = (onUpdateElapsed[name] or 0) + elapsed
            if onUpdateElapsed[name] >= (provider.updateInterval or 1) then
                onUpdateElapsed[name] = 0
                UpdateProvider(name)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- 事件系統
--------------------------------------------------------------------------------

local function SetupEvents()
    if eventFrame then
        return
    end

    eventFrame = CreateFrame("Frame")

    -- Fix 2: 直接使用 RegisterProvider 已建好的 eventToProviders 查找表
    for event, _ in pairs(eventToProviders) do
        eventFrame:RegisterEvent(event)
    end

    -- Fix 2: O(1) 查表取代 O(n×m) 雙迴圈
    eventFrame:SetScript("OnEvent", function(_self, event)
        local providerNames = eventToProviders[event]
        if providerNames then
            for i = 1, #providerNames do
                UpdateProvider(providerNames[i])
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeDataTexts()
    -- 先清理現有面板（防止切換設定檔時產生重複）
    if next(panels) then
        LunarUI.CleanupDataTexts()
    end

    local db = LunarUI.GetModuleDB("datatexts")
    if not db or not db.enabled then
        return
    end

    -- 從設定建立面板
    if db.panels then
        for panelName, panelDB in pairs(db.panels) do
            if panelDB.enabled then
                local panel = CreateDataPanel(panelName, panelDB)
                panels[panelName] = panel

                -- 將欄位繫結到 provider
                local slotAssignments = panelDB.slots or {}
                for i, providerName in ipairs(slotAssignments) do
                    if panel.slots[i] then
                        BindSlotToProvider(panel.slots[i], providerName)
                    end
                end
            end
        end
    end

    -- 設定事件驅動更新
    SetupEvents()

    -- 設定定時 provider 的 OnUpdate
    SetupOnUpdate()

    -- 初始完整更新
    UpdateAllProviders()
end

--------------------------------------------------------------------------------
-- 清理
--------------------------------------------------------------------------------

function LunarUI.CleanupDataTexts()
    -- 停止 OnUpdate
    if onUpdateFrame then
        onUpdateFrame:SetScript("OnUpdate", nil)
    end

    -- 取消註冊事件
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end

    -- 隱藏並清理面板
    for _, panel in pairs(panels) do
        if panel then
            if panel.slots then
                for _, slot in ipairs(panel.slots) do
                    slot:SetScript("OnClick", nil)
                    slot:SetScript("OnEnter", nil)
                    slot:SetScript("OnLeave", nil)
                end
            end
            panel:Hide()
        end
    end
    wipe(panels)

    wipe(onUpdateElapsed)
    wipe(slotsByProvider)
    -- eventToProviders / onUpdateProviders 由模組載入時的 RegisterProvider 靜態建立，
    -- 不隨 profile 改變，不可 wipe（wipe 後重新 enable 時無法重建，providers 停止更新）
    eventFrame = nil
    onUpdateFrame = nil
end

-- 匯出
LunarUI.InitializeDataTexts = InitializeDataTexts

LunarUI:RegisterModule("DataTexts", {
    onEnable = InitializeDataTexts,
    onDisable = function()
        LunarUI.CleanupDataTexts()
    end,
    delay = 0.4,
})
