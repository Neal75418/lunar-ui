---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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
-- Constants
--------------------------------------------------------------------------------

local backdropTemplate = LunarUI.backdropTemplate

local format = string.format
local floor = math.floor

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local providers = {}          -- Registered data text providers
local onUpdateProviders = {}  -- Only providers with onUpdate=true (Fix 1)
local panels = {}             -- Created panel frames
local slotsByProvider = {}    -- Reverse lookup: providerName → { slot1, slot2, ... } (Fix 5)
local _updateTimers = {}       -- OnUpdate throttle timers
local eventFrame              -- Shared event handler frame
local eventToProviders = {}   -- event → { providerName1, providerName2, ... } (Fix 2)

--------------------------------------------------------------------------------
-- Provider Registration
--------------------------------------------------------------------------------

local function RegisterProvider(name, config)
    providers[name] = config
    config.name = name  -- 確保 provider 知道自己的名字
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
-- Built-in Providers
--------------------------------------------------------------------------------

-- 門檻色彩：值越好越綠，越差越紅
-- invert=true: 值越小越好（latency）; false: 值越大越好（fps）
local function StatusColor(value, greenThreshold, yellowThreshold, invert)
    local good, warn
    if invert then
        good = value <= greenThreshold
        warn = value <= yellowThreshold
    else
        good = value >= greenThreshold
        warn = value >= yellowThreshold
    end
    if good then return 0.3, 1
    elseif warn then return 1, 0.8
    else return 1, 0.3 end
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
        return format("|cff%02x%02x00%d|r FPS", r * 255, g * 255, fps)
    end,
    tooltip = function(slot)
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine("FPS", 1, 1, 1)
        GameTooltip:AddDoubleLine(L["Current"] or "Current", floor(GetFramerate()) .. " FPS", 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:Show()
    end,
})

-- Latency
RegisterProvider("latency", {
    label = L["Latency"] or "Latency",
    events = {},
    onUpdate = true,
    updateInterval = 30,
    update = function()
        local _, _, latencyHome, latencyWorld = GetNetStats()
        local ms = latencyWorld > 0 and latencyWorld or latencyHome
        local r, g = StatusColor(ms, 100, 200, true)
        return format("|cff%02x%02x00%d|r ms", r * 255, g * 255, ms)
    end,
    tooltip = function(slot)
        local _, _, latencyHome, latencyWorld = GetNetStats()
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Latency"] or "Latency", 1, 1, 1)
        GameTooltip:AddDoubleLine("Home", latencyHome .. " ms", 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:AddDoubleLine("World", latencyWorld .. " ms", 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:Show()
    end,
})

-- Gold
RegisterProvider("gold", {
    label = L["Gold"] or "Gold",
    events = { "PLAYER_MONEY", "PLAYER_ENTERING_WORLD" },
    update = function()
        local money = GetMoney()
        local gold = floor(money / 10000)
        local silver = floor((money % 10000) / 100)
        local copper = money % 100
        return format("|cffffd700%d|r|TInterface\\MoneyFrame\\UI-GoldIcon:0|t |cffc7c7cf%d|r|TInterface\\MoneyFrame\\UI-SilverIcon:0|t |cffeda55f%d|r|TInterface\\MoneyFrame\\UI-CopperIcon:0|t", gold, silver, copper)
    end,
    tooltip = function(slot)
        local money = GetMoney()
        local gold = floor(money / 10000)
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Gold"] or "Gold", 1, 0.84, 0)
        GameTooltip:AddDoubleLine(UnitName("player"), format("%d gold", gold), 1, 1, 1, 1, 0.84, 0)
        GameTooltip:Show()
    end,
})

-- Durability
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
        local r, g = 1, 1
        if lowestDur < 25 then
            r, g = 1, 0.3
        elseif lowestDur < 50 then
            r, g = 1, 0.8
        else
            r, g = 0.3, 1
        end
        return format("%s: |cff%02x%02x00%d%%|r", L["Durability"] or "Dur", r * 255, g * 255, lowestDur)
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
                local r, g = 1, 1
                if pct < 25 then r, g = 1, 0.3
                elseif pct < 50 then r, g = 1, 0.8
                else r, g = 0.3, 1 end
                GameTooltip:AddDoubleLine(name, pct .. "%", 1, 1, 1, r, g, 0)
            end
        end
        GameTooltip:Show()
    end,
})

-- Bag Slots
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
        local r, g = 1, 1
        if totalFree < 5 then
            r, g = 1, 0.3
        elseif totalFree < 15 then
            r, g = 1, 0.8
        else
            r, g = 0.3, 1
        end
        return format("%s: |cff%02x%02x00%d/%d|r", L["BagSlots"] or "Bags", r * 255, g * 255, totalFree, totalSlots)
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

-- Friends Online
RegisterProvider("friends", {
    label = L["Friends"] or "Friends",
    events = { "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "PLAYER_ENTERING_WORLD" },
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
        GameTooltip:AddDoubleLine("WoW", (onlineFriends or 0) .. " " .. (L["Online"] or "online"), 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:AddDoubleLine("Battle.net", bnOnline .. " " .. (L["Online"] or "online"), 1, 1, 1, 0, 0.7, 1)
        GameTooltip:Show()
    end,
})

-- Guild
RegisterProvider("guild", {
    label = L["Guild"] or "Guild",
    events = { "GUILD_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" },
    update = function()
        if not IsInGuild() then
            return format("%s: |cff999999-|r", L["Guild"] or "Guild")
        end
        if C_GuildInfo.GuildRoster then
            C_GuildInfo.GuildRoster()
        end
        local _, numOnline = GetNumGuildMembers()
        return format("%s: |cff00ff00%d|r", L["Guild"] or "Guild", numOnline or 0)
    end,
    click = function()
        if IsInGuild() then
            ToggleGuildFrame()
        end
    end,
    tooltip = function(slot)
        if not IsInGuild() then return end
        local guildName = GetGuildInfo("player")
        local _, numOnline = GetNumGuildMembers()
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(guildName or (L["Guild"] or "Guild"), 0, 0.8, 0)
        GameTooltip:AddDoubleLine(L["Online"] or "Online", numOnline or 0, 1, 1, 1, 0.3, 1, 0.3)
        GameTooltip:Show()
    end,
})

-- Specialization
RegisterProvider("spec", {
    label = L["Spec"] or "Spec",
    events = { "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_ENTERING_WORLD" },
    update = function()
        local specIndex = GetSpecialization()
        if not specIndex then return L["Spec"] or "Spec" end
        local _, specName = GetSpecializationInfo(specIndex)
        return specName or (L["Spec"] or "Spec")
    end,
    click = function()
        ToggleTalentFrame()
    end,
    tooltip = function(slot)
        local specIndex = GetSpecialization()
        if not specIndex then return end
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

-- Clock
RegisterProvider("clock", {
    label = L["Clock"] or "Clock",
    events = {},
    onUpdate = true,
    updateInterval = 1,
    update = function()
        return date("%H:%M")
    end,
    tooltip = function(slot)
        GameTooltip:SetOwner(slot, "ANCHOR_TOP", 0, 4)
        GameTooltip:ClearLines()
        GameTooltip:AddLine(L["Clock"] or "Clock", 1, 1, 1)
        GameTooltip:AddDoubleLine(L["LocalTime"] or "Local", date("%H:%M:%S"), 1, 1, 1, 1, 1, 1)
        local serverTime = C_DateAndTime.GetCurrentCalendarTime()
        if serverTime then
            GameTooltip:AddDoubleLine(L["ServerTime"] or "Server", format("%02d:%02d", serverTime.hour, serverTime.minute), 1, 1, 1, 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end,
})

-- Coordinates
RegisterProvider("coords", {
    label = L["Coords"] or "Coords",
    events = {},
    onUpdate = true,
    updateInterval = 0.2,
    update = function()
        local map = C_Map.GetBestMapForUnit("player")
        if not map then return "-- , --" end
        local pos = C_Map.GetPlayerMapPosition(map, "player")
        if not pos then return "-- , --" end
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
-- Panel Creation
--------------------------------------------------------------------------------

local function CreateDataPanel(name, db)
    local panel = CreateFrame("Frame", "LunarUI_DataPanel_" .. name, UIParent, "BackdropTemplate")
    panel:SetSize(db.width or 400, db.height or 22)
    panel:SetPoint(db.point or "BOTTOM", UIParent, db.point or "BOTTOM", db.x or 0, db.y or 0)
    panel:SetFrameStrata("LOW")
    panel:SetFrameLevel(1)

    -- Backdrop
    if backdropTemplate then
        panel:SetBackdrop(backdropTemplate)
        panel:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], C.bgLight[4])
        panel:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    else
        -- Fallback: simple background
        panel.bg = panel:CreateTexture(nil, "BACKGROUND")
        panel.bg:SetAllPoints()
        panel.bg:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], C.bgLight[4])
    end

    -- Create slots
    panel.slots = {}
    local numSlots = db.numSlots or 3
    local slotWidth = (db.width or 400) / numSlots

    for i = 1, numSlots do
        local slot = CreateFrame("Button", nil, panel)
        slot:SetSize(slotWidth, db.height or 22)
        slot:SetPoint("LEFT", panel, "LEFT", (i - 1) * slotWidth, 0)

        -- Text
        slot.text = slot:CreateFontString(nil, "OVERLAY")
        slot.text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        slot.text:SetPoint("CENTER")
        slot.text:SetTextColor(0.9, 0.9, 0.9)

        -- Hover highlight
        slot.highlight = slot:CreateTexture(nil, "HIGHLIGHT")
        slot.highlight:SetAllPoints()
        slot.highlight:SetColorTexture(1, 1, 1, 0.05)

        -- Separator (except first slot)
        if i > 1 then
            local sep = panel:CreateTexture(nil, "ARTWORK")
            sep:SetSize(1, (db.height or 22) - 6)
            sep:SetPoint("LEFT", slot, "LEFT", 0, 0)
            sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        end

        -- Store slot index
        slot.slotIndex = i
        slot.panelName = name

        panel.slots[i] = slot
    end

    panel:EnableMouse(true)
    return panel
end

--------------------------------------------------------------------------------
-- Slot Binding (connect slots to providers)
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

    -- Click handler
    slot:SetScript("OnClick", function(_self, button)
        if provider.click then
            provider.click(button)
        end
    end)
    slot:RegisterForClicks("AnyUp")

    -- Tooltip
    slot:SetScript("OnEnter", function(btn)
        if provider.tooltip then
            provider.tooltip(btn)
        end
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Initial update
    if provider.update then
        local text = provider.update()
        if text then
            slot.text:SetText(text)
        end
    end
end

--------------------------------------------------------------------------------
-- Update System
--------------------------------------------------------------------------------

local function UpdateProvider(providerName)
    local provider = providers[providerName]
    if not provider or not provider.update then return end

    local text = provider.update()
    if not text then return end

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
-- OnUpdate Throttle (for FPS, latency, clock, coords)
--------------------------------------------------------------------------------

local onUpdateFrame
local onUpdateElapsed = {}

local function SetupOnUpdate()
    if onUpdateFrame then return end

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
-- Event System
--------------------------------------------------------------------------------

local function SetupEvents()
    if eventFrame then return end

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
-- Initialize
--------------------------------------------------------------------------------

local function InitializeDataTexts()
    -- Clean up existing panels first (prevents duplicates on profile change)
    if next(panels) then
        LunarUI.CleanupDataTexts()
    end

    local db = LunarUI.db and LunarUI.db.profile.datatexts
    if not db or not db.enabled then return end

    -- Create panels from config
    if db.panels then
        for panelName, panelDB in pairs(db.panels) do
            if panelDB.enabled then
                local panel = CreateDataPanel(panelName, panelDB)
                panels[panelName] = panel

                -- Bind slots to providers
                local slotAssignments = panelDB.slots or {}
                for i, providerName in ipairs(slotAssignments) do
                    if panel.slots[i] then
                        BindSlotToProvider(panel.slots[i], providerName)
                    end
                end
            end
        end
    end

    -- Setup event-driven updates
    SetupEvents()

    -- Setup OnUpdate for timed providers
    SetupOnUpdate()

    -- Initial full update
    UpdateAllProviders()

end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function LunarUI.CleanupDataTexts()
    -- Stop OnUpdate
    if onUpdateFrame then
        onUpdateFrame:SetScript("OnUpdate", nil)
    end

    -- Unregister events
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end

    -- Hide and clean panels
    for name, panel in pairs(panels) do
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
        panels[name] = nil
    end

    wipe(onUpdateElapsed)
end

-- Export
LunarUI.InitializeDataTexts = InitializeDataTexts

LunarUI:RegisterModule("DataTexts", {
    onEnable = InitializeDataTexts,
    onDisable = function() LunarUI.CleanupDataTexts() end,
    delay = 0.4,
})
