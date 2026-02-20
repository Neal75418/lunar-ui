---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, missing-parameter
--[[
    LunarUI - 背包模組
    整合式背包系統，Lunar 主題風格

    功能：
    - 整合所有背包為單一視窗
    - 羊皮紙風格背景
    - 物品排序與分類
    - 搜尋功能
    - 裝備物品等級顯示
    - 垃圾自動販賣
    - 月相感知顯示
    - 專業容器背景著色
    - 裝等升級綠色上箭頭標記
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}
local C = LunarUI.Colors

local bit_band = bit.band  -- LuaJIT built-in（LLS 環境限制，快取為 local）

--------------------------------------------------------------------------------
-- DB 存取
--------------------------------------------------------------------------------

local function GetBagDB()
    return LunarUI.db and LunarUI.db.profile.bags
end

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 可設定常數（由 LoadBagSettings 從 DB 載入，此為 fallback 預設值）
local SLOT_SIZE = 37
local SLOT_SPACING = 4
local SLOTS_PER_ROW = 12
local PADDING = 10
local HEADER_HEIGHT = 30
local FOOTER_HEIGHT = 30
local SEARCH_DEBOUNCE = 0.2       -- 搜尋防抖延遲（秒）
local SEARCH_DIM_ALPHA = 0.3      -- 搜尋不符合時的透明度
local BORDER_COLOR_DEFAULT = C.border      -- { 0.15, 0.12, 0.08, 1 }
local BORDER_COLOR_BANK = C.borderGold     -- { 0.4, 0.35, 0.2, 1 }
local JUNK_SELL_DELAY = 0.3       -- 商人開啟後延遲販賣垃圾（秒）
local INIT_DELAY = 0.5            -- 插件初始化延遲（秒）
local FRAME_ALPHA = 0.95          -- 框架背景透明度
local backdropTemplate = LunarUI.backdropTemplate

-- 使用集中定義的品質顏色
local ITEM_QUALITY_COLORS = LunarUI.QUALITY_COLORS

-- 專業容器背景著色
-- 透過 C_Container.GetContainerNumFreeSlots 的第二個返回值 bagType 判斷
-- bagType 是位元遮罩（flag），對應 Enum.BagFamily
local PROFESSION_BAG_COLORS = {
    -- bagType flag → { r, g, b, a }
    [0x0008]  = { 0.18, 0.55, 0.18, 0.25 },   -- 草藥（Herbs）綠色
    [0x0010]  = { 0.55, 0.28, 0.55, 0.25 },   -- 附魔（Enchanting）紫色
    [0x0020]  = { 0.45, 0.45, 0.55, 0.25 },   -- 工程（Engineering）灰藍
    [0x0040]  = { 0.20, 0.50, 0.70, 0.25 },   -- 珠寶（Gems）藍色
    [0x0080]  = { 0.50, 0.40, 0.25, 0.25 },   -- 礦石（Mining）褐色
    [0x0200]  = { 0.60, 0.45, 0.30, 0.25 },   -- 製皮（Leatherworking）皮革色
    [0x0400]  = { 0.50, 0.50, 0.50, 0.25 },   -- 銘文（Inscription）灰色
    [0x0800]  = { 0.30, 0.55, 0.45, 0.25 },   -- 釣魚（Fishing/Tackle）青色
    [0x1000]  = { 0.55, 0.35, 0.20, 0.25 },   -- 烹飪（Cooking）橘棕色
}

-- 裝備槽位 ID 對應（用於升級判斷）
local EQUIP_LOC_TO_SLOT = {
    INVTYPE_HEAD          = { 1 },
    INVTYPE_NECK          = { 2 },
    INVTYPE_SHOULDER      = { 3 },
    INVTYPE_BODY          = { 4 },
    INVTYPE_CHEST         = { 5 },
    INVTYPE_ROBE          = { 5 },
    INVTYPE_WAIST         = { 6 },
    INVTYPE_LEGS          = { 7 },
    INVTYPE_FEET          = { 8 },
    INVTYPE_WRIST         = { 9 },
    INVTYPE_HAND          = { 10 },
    INVTYPE_FINGER        = { 11, 12 },
    INVTYPE_TRINKET       = { 13, 14 },
    INVTYPE_CLOAK         = { 15 },
    INVTYPE_WEAPON        = { 16, 17 },
    INVTYPE_SHIELD        = { 17 },
    INVTYPE_2HWEAPON      = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE      = { 17 },
    INVTYPE_RANGED        = { 16 },
    INVTYPE_RANGEDRIGHT   = { 16 },
}

-- 快取裝備中的物品等級（開啟背包時刷新）
local equippedItemLevels = {}
local equippedIlvlDirty = true

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local bagFrame
local bankFrame
local slots = {}
local bankSlots = {}
local searchBox
local bankSearchBox
local sortButton
local closeButton
local isOpen = false
local isBankOpen = false
local searchTimer      -- 背包搜尋防抖計時器
local bankSearchTimer  -- 銀行搜尋防抖計時器
local pendingBagUpdates = {}  -- BAG_UPDATE 累積的背包 ID（由 BAG_UPDATE_DELAYED 處理）
local isSorting = false -- 排序進行中標記（排序期間跳過 ITEM_LOCK_CHANGED 全量更新）

-- 銀行容器 ID：-1 = 主銀行（28 格），5-11 = 銀行包
local BANK_CONTAINER = -1
local REAGENT_BANK_CONTAINER = -3
local FIRST_BANK_BAG = 5
local LAST_BANK_BAG = 11

-- 前向宣告（函數定義在下方）
local SellJunk

-- 從 DB 載入背包設定（覆寫模組常數）
local function LoadBagSettings()
    local db = GetBagDB()
    if not db then return end
    SLOT_SIZE = db.slotSize or 37
    SLOT_SPACING = db.slotSpacing or 4
    SLOTS_PER_ROW = db.slotsPerRow or 12
    FRAME_ALPHA = db.frameAlpha or 0.95
end

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function GetTotalSlots()
    local total = 0
    for bag = 0, 4 do
        total = total + C_Container.GetContainerNumSlots(bag)
    end
    return total
end

local function GetTotalFreeSlots()
    local free = 0
    for bag = 0, 4 do
        local freeSlots = C_Container.GetContainerNumFreeSlots(bag)
        free = free + freeSlots
    end
    return free
end

-- 快取機制：避免重複呼叫昂貴的物品資訊 API
local itemLevelCache = {}
local equipmentTypeCache = {}
local CACHE_MAX_SIZE = 1000

-- 在新增項目前檢查快取大小，超過上限時整體清除
local function MaybeEvictCache(cache, sizeRef)
    if sizeRef.n >= CACHE_MAX_SIZE then
        wipe(cache)
        sizeRef.n = 0
    end
end

-- 使用表格追蹤快取大小，方便傳遞引用
local itemLevelCacheMeta = { n = 0 }
local equipmentTypeCacheMeta = { n = 0 }

local function GetItemLevel(itemLink)
    if not itemLink then return nil end

    -- 使用快取避免重複 API 呼叫
    if itemLevelCache[itemLink] then
        return itemLevelCache[itemLink]
    end

    local itemLevel = select(1, C_Item.GetDetailedItemLevelInfo(itemLink))
    if itemLevel then
        MaybeEvictCache(itemLevelCache, itemLevelCacheMeta)
        itemLevelCache[itemLink] = itemLevel
        itemLevelCacheMeta.n = itemLevelCacheMeta.n + 1
    end
    return itemLevel
end

local function IsEquipment(itemLink)
    if not itemLink then return false end

    -- 使用快取避免重複 API 呼叫
    if equipmentTypeCache[itemLink] ~= nil then
        return equipmentTypeCache[itemLink]
    end

    local _, _, _, _, _, _, _, _, _, _, _, itemClassID = C_Item.GetItemInfo(itemLink)
    -- C_Item.GetItemInfo 可能因物品尚未載入而回傳 nil，此時不快取以避免錯誤結果
    if itemClassID == nil then
        return false
    end
    -- 使用 itemClassID 而非本地化字串，確保所有語系客戶端都能正確判斷
    -- Enum.ItemClass.Armor = 4, Enum.ItemClass.Weapon = 2
    local isEquip = (itemClassID == 4 or itemClassID == 2)
    MaybeEvictCache(equipmentTypeCache, equipmentTypeCacheMeta)
    equipmentTypeCache[itemLink] = isEquip
    equipmentTypeCacheMeta.n = equipmentTypeCacheMeta.n + 1
    return isEquip
end

-- 取得背包類型顏色（專業容器）
local bagTypeCache = {}

local function GetBagTypeColor(bag)
    local db = GetBagDB()
    if not db or not db.showProfessionColors then return false end

    if bagTypeCache[bag] ~= nil then
        return bagTypeCache[bag]
    end

    local _, bagType = C_Container.GetContainerNumFreeSlots(bag)
    if bagType and bagType > 0 then
        -- 檢查每個專業 flag
        for flag, color in pairs(PROFESSION_BAG_COLORS) do
            if bit_band(bagType, flag) > 0 then
                bagTypeCache[bag] = color
                return color
            end
        end
    end

    bagTypeCache[bag] = false
    return false
end

-- 刷新裝備物品等級快取
local function RefreshEquippedItemLevels()
    if not equippedIlvlDirty then return end
    equippedIlvlDirty = false
    wipe(equippedItemLevels)

    for slotID = 1, 17 do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local ilvl = select(1, C_Item.GetDetailedItemLevelInfo(itemLink))
            equippedItemLevels[slotID] = ilvl or 0
        else
            equippedItemLevels[slotID] = 0
        end
    end
end

-- 判斷物品是否為裝等升級
local function IsItemUpgrade(itemLink)
    if not itemLink then return false end

    local db = GetBagDB()
    if not db or not db.showUpgradeArrow then return false end

    -- 取得物品裝備位置
    local _, _, _, _, _, _, _, _, equipLoc = C_Item.GetItemInfo(itemLink)
    if not equipLoc or equipLoc == "" then return false end

    local slotIDs = EQUIP_LOC_TO_SLOT[equipLoc]
    if not slotIDs then return false end

    -- 取得此物品的等級
    local itemIlvl = select(1, C_Item.GetDetailedItemLevelInfo(itemLink))
    if not itemIlvl or itemIlvl <= 1 then return false end

    -- 刷新裝備快取
    RefreshEquippedItemLevels()

    -- 與裝備中的對應槽位比較
    local isUpgrade = false
    for _, slotID in ipairs(slotIDs) do
        local equippedIlvl = equippedItemLevels[slotID] or 0
        if equippedIlvl > 0 and itemIlvl > equippedIlvl then
            isUpgrade = true
            break
        elseif equippedIlvl == 0 then
            -- 槽位為空，任何裝備都算升級
            isUpgrade = true
            break
        end
    end

    return isUpgrade
end

-- 銀行輔助函數
local function GetTotalBankSlots()
    local total = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        total = total + C_Container.GetContainerNumSlots(bag)
    end
    return total
end

local function GetTotalBankFreeSlots()
    local free = C_Container.GetContainerNumFreeSlots(BANK_CONTAINER)
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        free = free + C_Container.GetContainerNumFreeSlots(bag)
    end
    return free
end

-- 動態計算銀行每行格數，避免框架超出螢幕
local function GetBankSlotsPerRow(totalSlots)
    local screenHeight = GetScreenHeight()
    local maxHeight = screenHeight * 0.80  -- 留 20% 邊距
    local overhead = PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT
    local maxRows = math.floor((maxHeight - overhead + SLOT_SPACING) / (SLOT_SIZE + SLOT_SPACING))
    maxRows = math.max(maxRows, 1)
    local neededCols = math.ceil(totalSlots / maxRows)
    return math.max(SLOTS_PER_ROW, neededCols)
end

--------------------------------------------------------------------------------
-- 格子建立
--------------------------------------------------------------------------------

-- 共用的 tooltip 顯示邏輯
local function ShowSlotTooltip(self)
    local itemInfo = C_Container.GetContainerItemInfo(self.bag, self.slot)
    if not itemInfo then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetBagItem, GameTooltip, self.bag, self.slot)
    if not ok then
        local link = C_Container.GetContainerItemLink(self.bag, self.slot)
        if link then pcall(GameTooltip.SetHyperlink, GameTooltip, link) end
    end
    GameTooltip:Show()
end

local function HideSlotTooltip()
    GameTooltip:Hide()
end

-- 隱藏格子上的所有指示器（重構：避免重複代碼）
local function HideAllSlotIndicators(button)
    if button.ilvlText then button.ilvlText:Hide() end
    if button.junkIcon then button.junkIcon:Hide() end
    if button.questIcon then button.questIcon:Hide() end
    if button.qualityGlow then button.qualityGlow:Hide() end
    if button.upgradeArrow then button.upgradeArrow:Hide() end
    if button.bindText then button.bindText:Hide() end
    if button.newGlow then
        if button.newGlowAnim then button.newGlowAnim:Stop() end
        button.newGlow:Hide()
    end
end

-- 設定格子按鈕的共用基礎（圖示、邊框、物品等級、tooltip）
local function SetupSlotBase(button, bag, slot)
    button.bag = bag
    button.slot = slot

    -- 移除預設材質
    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    -- 隱藏 ContainerFrameItemButtonTemplate 內建的新物品發光（避免與自訂 newGlow 衝突）
    if button.NewItemTexture then
        button.NewItemTexture:Hide()
        button.NewItemTexture:SetAlpha(0)
    end
    if button.BattlepayItemTexture then
        button.BattlepayItemTexture:Hide()
    end
    if button.flash then
        button.flash:Hide()
    end

    -- 設定圖示樣式
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexCoord(unpack(LunarUI.ICON_TEXCOORD))
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- 建立邊框
    if not button.LunarBorder then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop(backdropTemplate)
        border:SetBackdropColor(0, 0, 0, 0)
        border:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 1)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        border:EnableMouse(false)  -- 讓滑鼠事件穿透到按鈕
        button.LunarBorder = border
    end

    -- 物品等級文字
    if not button.ilvlText then
        local ilvl = button:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(ilvl, 10, "OUTLINE")
        ilvl:SetPoint("BOTTOMRIGHT", -2, 2)
        ilvl:SetTextColor(1, 1, 0.6)
        button.ilvlText = ilvl
    end

    -- 綁定類型文字（BoE/BoP）
    if not button.bindText then
        local bind = button:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(bind, 9, "OUTLINE")
        bind:SetPoint("TOPLEFT", 2, -2)
        bind:SetTextColor(0.1, 1, 0.1)
        bind:Hide()
        button.bindText = bind
    end

    -- 新物品發光動畫
    if not button.newGlow then
        local glow = button:CreateTexture(nil, "OVERLAY", nil, 3)
        glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        glow:SetAllPoints()
        glow:SetVertexColor(1, 1, 1, 0.3)
        glow:SetBlendMode("ADD")
        glow:Hide()
        button.newGlow = glow

        -- 閃爍動畫組
        local ag = glow:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(0.4)
        fadeIn:SetDuration(0.6)
        fadeIn:SetOrder(1)
        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(0.4)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.6)
        fadeOut:SetOrder(2)
        button.newGlowAnim = ag
    end

    -- 修正模板的 GetBagID（預設從 parent chain 查找 ContainerFrame，但我們的 parent 不是）
    function button:GetBagID()
        return self.bag
    end

    -- 覆寫 tooltip
    button:SetScript("OnEnter", ShowSlotTooltip)
    button:SetScript("OnLeave", HideSlotTooltip)
    button.OnEnter = ShowSlotTooltip
    button.OnLeave = HideSlotTooltip
    button.UpdateTooltip = ShowSlotTooltip
end

local function CreateItemSlot(parent, slotID, bag, slot)
    local button = CreateFrame("ItemButton", "LunarUI_BagSlot" .. slotID, parent, "ContainerFrameItemButtonTemplate")
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- 設定共用基礎（圖示、邊框、物品等級、tooltip）
    SetupSlotBase(button, bag, slot)

    -- 垃圾指示器
    if not button.junkIcon then
        local junk = button:CreateTexture(nil, "OVERLAY")
        junk:SetSize(12, 12)
        junk:SetPoint("TOPLEFT", 2, -2)
        junk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
        junk:Hide()
        button.junkIcon = junk
    end

    -- 任務指示器
    if not button.questIcon then
        local quest = button:CreateTexture(nil, "OVERLAY")
        quest:SetSize(12, 12)
        quest:SetPoint("TOPLEFT", 2, -2)
        quest:SetTexture("Interface\\MINIMAP\\TRACKING\\QuestBlob")
        quest:Hide()
        button.questIcon = quest
    end

    -- 品質發光（史詩以上）
    if not button.qualityGlow then
        local glow = button:CreateTexture(nil, "BACKGROUND")
        glow:SetTexture(LunarUI.textures.glow)
        glow:SetBlendMode("ADD")
        glow:SetPoint("TOPLEFT", -6, 6)
        glow:SetPoint("BOTTOMRIGHT", 6, -6)
        glow:SetAlpha(0)
        glow:Hide()
        button.qualityGlow = glow
    end

    -- 升級箭頭指示器
    if not button.upgradeArrow then
        local arrow = button:CreateTexture(nil, "OVERLAY", nil, 2)
        arrow:SetSize(14, 14)
        arrow:SetPoint("TOPRIGHT", -1, -1)
        arrow:SetTexture("Interface\\BUTTONS\\UI-MicroStream-Green")
        arrow:SetTexCoord(0, 1, 1, 0)  -- 翻轉為向上箭頭
        arrow:Hide()
        button.upgradeArrow = arrow
    end

    -- 專業容器背景著色
    if not button.profBg then
        local profBg = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        profBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        profBg:SetAllPoints()
        profBg:SetVertexColor(0, 0, 0, 0)
        profBg:Hide()
        button.profBg = profBg
    end

    -- Hover 高亮
    if not button.hoverHighlight then
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
        highlight:SetPoint("TOPLEFT", 1, -1)
        highlight:SetPoint("BOTTOMRIGHT", -1, 1)
        highlight:SetVertexColor(1, 1, 1, 0.15)
        highlight:SetBlendMode("ADD")
        button.hoverHighlight = highlight
    end

    return button
end

-- 更新格子視覺元素：圖示、數量、品質邊框與發光
local function UpdateSlotVisuals(button, containerInfo, quality)
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon and containerInfo.iconFileID then
        icon:SetTexture(containerInfo.iconFileID)
        icon:Show()
    end

    local count = containerInfo.stackCount or 0
    if count > 1 then
        button.Count:SetText(count)
        button.Count:Show()
    else
        button.Count:Hide()
    end

    if button.LunarBorder then
        if quality and ITEM_QUALITY_COLORS[quality] then
            local color = ITEM_QUALITY_COLORS[quality]
            button.LunarBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        else
            button.LunarBorder:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 1)
        end
    end

    if button.qualityGlow then
        if quality and quality >= 4 and ITEM_QUALITY_COLORS[quality] then
            local color = ITEM_QUALITY_COLORS[quality]
            button.qualityGlow:SetVertexColor(color[1], color[2], color[3], 0.4)
            button.qualityGlow:SetAlpha(0.4)
            button.qualityGlow:Show()
        else
            button.qualityGlow:Hide()
        end
    end
end

-- 更新格子文字覆蓋：裝等、綁定類型
local function UpdateSlotText(button, db, itemLink)
    if button.ilvlText then
        if (not db or db.showItemLevel ~= false) and IsEquipment(itemLink) then
            local ilvl = GetItemLevel(itemLink)
            local threshold = (db and db.ilvlThreshold) or 1
            if ilvl and ilvl >= threshold then
                button.ilvlText:SetText(ilvl)
                button.ilvlText:Show()
            else
                button.ilvlText:Hide()
            end
        else
            button.ilvlText:Hide()
        end
    end

    if button.bindText then
        if db and db.showBindType and itemLink then
            local bindType = select(14, C_Item.GetItemInfo(itemLink))
            if bindType and bindType == 2 then
                button.bindText:SetText(L["BoE"] or "BoE")
                button.bindText:SetTextColor(0.1, 1, 0.1)
                button.bindText:Show()
            elseif bindType == 3 then
                button.bindText:SetText(L["BoU"] or "BoU")
                button.bindText:SetTextColor(0.9, 0.6, 0.2)
                button.bindText:Show()
            else
                button.bindText:Hide()
            end
        else
            button.bindText:Hide()
        end
    end
end

-- 更新格子效果：冷卻、新物品發光、垃圾/任務/升級指示、專業容器背景
local function UpdateSlotEffects(button, db, bag, slot, containerInfo, itemLink, quality)
    if db and db.showCooldown then
        local cooldown = button.Cooldown or button.cooldown
        if cooldown then
            local start, duration, enable = C_Container.GetContainerItemCooldown(bag, slot)
            if start and duration and enable == 1 and duration > 0 then
                CooldownFrame_Set(cooldown, start, duration, enable)
                cooldown:Show()
            else
                cooldown:Hide()
            end
        end
    end

    if button.newGlow then
        if db and db.showNewGlow and C_NewItems.IsNewItem(bag, slot) then
            button.newGlow:Show()
            if button.newGlowAnim and not button.newGlowAnim:IsPlaying() then
                button.newGlowAnim:Play()
            end
        else
            if button.newGlowAnim then
                button.newGlowAnim:Stop()
            end
            button.newGlow:Hide()
        end
    end

    if button.junkIcon then
        if quality == 0 and containerInfo.hasNoValue ~= true then
            button.junkIcon:Show()
        else
            button.junkIcon:Hide()
        end
    end

    if button.questIcon then
        if db and db.showQuestItems ~= false and containerInfo.isQuestItem then
            button.questIcon:Show()
            button.junkIcon:Hide()
        else
            button.questIcon:Hide()
        end
    end

    if button.upgradeArrow then
        if IsItemUpgrade(itemLink) then
            button.upgradeArrow:Show()
        else
            button.upgradeArrow:Hide()
        end
    end

    if button.profBg then
        if db and db.showProfessionColors ~= false then
            local bagColor = GetBagTypeColor(bag)
            if bagColor then
                button.profBg:SetVertexColor(bagColor[1], bagColor[2], bagColor[3], bagColor[4])
                button.profBg:Show()
            else
                button.profBg:Hide()
            end
        else
            button.profBg:Hide()
        end
    end
end

-- 清空格子顯示
local function ClearSlot(button, db, bag)
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexture(nil)
    end
    if button.Count then
        button.Count:Hide()
    end
    if button.LunarBorder then
        button.LunarBorder:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 0.5)
    end
    HideAllSlotIndicators(button)
    local cooldown = button.Cooldown or button.cooldown
    if cooldown then
        cooldown:Hide()
    end

    if button.profBg then
        if db and db.showProfessionColors ~= false then
            local bagColor = GetBagTypeColor(bag)
            if bagColor then
                button.profBg:SetVertexColor(bagColor[1], bagColor[2], bagColor[3], bagColor[4] * 0.5)
                button.profBg:Show()
            else
                button.profBg:Hide()
            end
        else
            button.profBg:Hide()
        end
    end
end

local function UpdateSlot(button)
    if not button or not button.bag or not button.slot then return end

    local db = GetBagDB()
    local bag, slot = button.bag, button.slot
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)

    if containerInfo then
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        local quality = containerInfo.quality or 0
        UpdateSlotVisuals(button, containerInfo, quality)
        UpdateSlotText(button, db, itemLink)
        UpdateSlotEffects(button, db, bag, slot, containerInfo, itemLink, quality)
    else
        ClearSlot(button, db, bag)
    end
end

--------------------------------------------------------------------------------
-- 背包框架建立
--------------------------------------------------------------------------------

local function CreateBagFrame()
    local db = GetBagDB()
    if not db or not db.enabled then return end

    if bagFrame then return bagFrame end

    -- 從 DB 載入設定
    LoadBagSettings()

    -- 計算框架大小
    local totalSlots = GetTotalSlots()
    local numRows
    if db.splitBags then
        -- 分離視圖：每個背包佔獨立行區塊，需預算額外行數
        local layoutIdx = 0
        local prevBag = nil
        for bag = 0, 4 do
            local numBagSlots = C_Container.GetContainerNumSlots(bag)
            if numBagSlots > 0 then
                if prevBag ~= nil then
                    local currentCol = layoutIdx % SLOTS_PER_ROW
                    if currentCol ~= 0 then
                        layoutIdx = layoutIdx + (SLOTS_PER_ROW - currentCol)
                    end
                end
                prevBag = bag
                layoutIdx = layoutIdx + numBagSlots
            end
        end
        numRows = math.ceil(layoutIdx / SLOTS_PER_ROW)
    else
        numRows = math.ceil(totalSlots / SLOTS_PER_ROW)
    end
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT

    -- 建立主框架
    bagFrame = CreateFrame("Frame", "LunarUI_Bags", UIParent, "BackdropTemplate")
    bagFrame:SetSize(width, height)

    -- 位置記憶：優先讀取已儲存位置
    if db.bagPosition then
        bagFrame:SetPoint(db.bagPosition.point, UIParent, db.bagPosition.relPoint or db.bagPosition.point, db.bagPosition.x, db.bagPosition.y)
    else
        bagFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 100)
    end

    bagFrame:SetBackdrop(backdropTemplate)
    bagFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], FRAME_ALPHA)
    bagFrame:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 1)
    bagFrame:SetFrameStrata("HIGH")
    bagFrame:SetMovable(true)
    bagFrame:EnableMouse(true)
    bagFrame:SetClampedToScreen(true)
    bagFrame:Hide()

    -- 可拖曳
    bagFrame:RegisterForDrag("LeftButton")
    bagFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bagFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- 儲存位置到 DB（含 relativePoint 以確保跨解析度正確）
        local point, _, relPoint, x, y = self:GetPoint()
        local bagDb = GetBagDB()
        if bagDb then
            bagDb.bagPosition = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- 標題
    local title = bagFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", PADDING, -8)
    title:SetText(L["BagTitle"] or "Bags")
    title:SetTextColor(0.9, 0.9, 0.9)
    bagFrame.title = title

    -- 關閉按鈕
    closeButton = CreateFrame("Button", nil, bagFrame)
    closeButton:SetSize(20, 20)
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetNormalFontObject(GameFontNormal)
    closeButton:SetText("×")
    LunarUI.SetFont(closeButton:GetFontString(), 16, "OUTLINE")
    closeButton:SetScript("OnClick", function()
        CloseAllBags()
    end)

    -- 搜尋框
    searchBox = CreateFrame("EditBox", "LunarUI_BagSearch", bagFrame, "SearchBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -8, -2)

    -- 搜尋邏輯（提取為 named function 避免每次按鍵建立 closure）
    local function PerformBagSearch()
        if not searchBox then return end
        local text = searchBox:GetText():lower()
        for _, button in pairs(slots) do
            if button and button:IsShown() and button.bag and button.slot then
                local success, err = pcall(function()
                    local itemLink = C_Container.GetContainerItemLink(button.bag, button.slot)
                    if itemLink then
                        local itemName = C_Item.GetItemInfo(itemLink)
                        if itemName then
                            if text == "" or itemName:lower():find(text, 1, true) then
                                button:SetAlpha(1)
                            else
                                button:SetAlpha(SEARCH_DIM_ALPHA)
                            end
                        else
                            button:SetAlpha(1)
                        end
                    else
                        button:SetAlpha(text == "" and 1 or SEARCH_DIM_ALPHA)
                    end
                end)

                if not success then
                    button:SetAlpha(1)
                    if LunarUI:IsDebugMode() then
                        LunarUI:Debug((L["BagSearchError"] or "Bag search error: ") .. tostring(err))
                    end
                end
            end
        end
    end

    -- 搜尋防抖動：使用 HookScript 保留 SearchBoxTemplate 內建的佔位文字隱藏行為
    searchBox:HookScript("OnTextChanged", function()
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end
        searchTimer = C_Timer.NewTimer(SEARCH_DEBOUNCE, PerformBagSearch)
    end)

    -- 排序按鈕
    sortButton = CreateFrame("Button", nil, bagFrame, "BackdropTemplate")
    sortButton:SetSize(60, 20)
    sortButton:SetPoint("TOPLEFT", title, "TOPRIGHT", 10, 2)
    sortButton:SetBackdrop(backdropTemplate)
    sortButton:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    sortButton:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 1)

    local sortText = sortButton:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(sortText, 11, "OUTLINE")
    sortText:SetPoint("CENTER")
    sortText:SetText(L["Sort"] or "Sort")
    sortText:SetTextColor(0.8, 0.8, 0.8)

    sortButton:SetScript("OnClick", function()
        isSorting = true
        C_Container.SortBags()
    end)

    sortButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C.bgButtonHover[1], C.bgButtonHover[2], C.bgButtonHover[3], C.bgButtonHover[4])
    end)

    sortButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    end)

    -- 格子容器
    local slotContainer = CreateFrame("Frame", nil, bagFrame)
    slotContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    slotContainer:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_HEIGHT)
    bagFrame.slotContainer = slotContainer

    -- 收集所有格子的 bag/slot 資料（支援反轉順序）
    local slotList = {}
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotList[#slotList + 1] = { bag = bag, slot = slot }
        end
    end
    if db.reverseBagSlots then
        -- 反轉整個清單
        local n = #slotList
        for i = 1, math.floor(n / 2) do
            slotList[i], slotList[n - i + 1] = slotList[n - i + 1], slotList[i]
        end
    end

    -- 建立格子（支援分離背包視圖）
    local slotID = 0
    local layoutIdx = 0   -- 實際佈局索引（分離視圖可能跳行）
    local prevBag = nil
    for _, slotInfo in ipairs(slotList) do
        slotID = slotID + 1
        local button = CreateItemSlot(slotContainer, slotID, slotInfo.bag, slotInfo.slot)

        -- 分離背包視圖：當 bagID 改變時，跳到下一行起始
        if db.splitBags and prevBag ~= nil and slotInfo.bag ~= prevBag then
            local currentCol = layoutIdx % SLOTS_PER_ROW
            if currentCol ~= 0 then
                layoutIdx = layoutIdx + (SLOTS_PER_ROW - currentCol)
            end
        end
        prevBag = slotInfo.bag

        local row = math.floor(layoutIdx / SLOTS_PER_ROW)
        local col = layoutIdx % SLOTS_PER_ROW

        button:SetPoint("TOPLEFT", slotContainer, "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )

        -- 設定按鈕 ID 以支援預設背包行為
        button:SetID(slotInfo.slot)
        SetItemButtonDesaturated(button, false)

        slots[slotID] = button
        layoutIdx = layoutIdx + 1
    end

    -- 金錢顯示
    local money = bagFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(money, 12, "OUTLINE")
    money:SetPoint("BOTTOMLEFT", PADDING, 8)
    money:SetTextColor(1, 0.82, 0)
    bagFrame.money = money

    -- 空格指示器
    local freeSlots = bagFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(freeSlots, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(0.7, 0.7, 0.7)
    bagFrame.freeSlots = freeSlots

    return bagFrame
end

--------------------------------------------------------------------------------
-- 銀行框架建立
--------------------------------------------------------------------------------

local function CreateBankSlot(parent, slotID, bag, slot)
    local button = CreateFrame("ItemButton", "LunarUI_BankSlot" .. slotID, parent, "ContainerFrameItemButtonTemplate")
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- 設定共用基礎（圖示、邊框、物品等級、tooltip）
    SetupSlotBase(button, bag, slot)
    button.isBank = true

    return button
end

local function UpdateBankSlot(button)
    if not button or not button.bag or not button.slot then return end

    local db = GetBagDB()
    local bag, slot = button.bag, button.slot
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)

    if containerInfo then
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        local quality = containerInfo.quality or 0

        -- 設定物品圖示
        local icon = button.icon or _G[button:GetName() .. "IconTexture"]
        if icon and containerInfo.iconFileID then
            icon:SetTexture(containerInfo.iconFileID)
            icon:Show()
        end

        -- 設定物品數量
        local count = containerInfo.stackCount or 0
        if count > 1 then
            button.Count:SetText(count)
            button.Count:Show()
        else
            button.Count:Hide()
        end

        -- 依品質設定邊框顏色
        if button.LunarBorder then
            if quality and ITEM_QUALITY_COLORS[quality] then
                local color = ITEM_QUALITY_COLORS[quality]
                button.LunarBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            else
                button.LunarBorder:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 1)
            end
        end

        -- 顯示裝備物品等級（支援門檻設定）
        if button.ilvlText then
            if (not db or db.showItemLevel ~= false) and IsEquipment(itemLink) then
                local ilvl = GetItemLevel(itemLink)
                local threshold = (db and db.ilvlThreshold) or 1
                if ilvl and ilvl >= threshold then
                    button.ilvlText:SetText(ilvl)
                    button.ilvlText:Show()
                else
                    button.ilvlText:Hide()
                end
            else
                button.ilvlText:Hide()
            end
        end

        -- 綁定類型文字（BoE/BoP/BoU）
        if button.bindText then
            if db and db.showBindType and itemLink then
                local bindType = select(14, C_Item.GetItemInfo(itemLink))
                -- bindType 可能為 nil 若物品未載入
                if bindType and bindType == 2 then
                    button.bindText:SetText(L["BoE"] or "BoE")
                    button.bindText:SetTextColor(0.1, 1, 0.1)
                    button.bindText:Show()
                elseif bindType and bindType == 3 then
                    button.bindText:SetText(L["BoU"] or "BoU")
                    button.bindText:SetTextColor(0.9, 0.6, 0.2)
                    button.bindText:Show()
                else
                    button.bindText:Hide()
                end
            else
                button.bindText:Hide()
            end
        end
    else
        -- 空格子
        local icon = button.icon or _G[button:GetName() .. "IconTexture"]
        if icon then
            icon:SetTexture(nil)
        end
        if button.Count then
            button.Count:Hide()
        end
        if button.LunarBorder then
            button.LunarBorder:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 0.5)
        end
        -- 使用輔助函數隱藏所有指示器
        HideAllSlotIndicators(button)
    end
end

local function CreateBankFrame()
    local db = GetBagDB()
    if not db or not db.enabled then return end

    if bankFrame then return bankFrame end

    -- 從 DB 載入設定
    LoadBagSettings()

    -- 計算框架大小（動態調整欄數避免超出螢幕）
    local totalSlots = GetTotalBankSlots()
    local bankCols = GetBankSlotsPerRow(totalSlots)
    local numRows = math.ceil(totalSlots / bankCols)
    local width = bankCols * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT

    -- 建立主框架
    bankFrame = CreateFrame("Frame", "LunarUI_Bank", UIParent, "BackdropTemplate")
    bankFrame:SetSize(width, height)
    bankFrame.bankCols = bankCols  -- 記錄銀行欄數供後續使用

    -- 位置記憶：優先讀取已儲存位置
    if db.bankPosition then
        bankFrame:SetPoint(db.bankPosition.point, UIParent, db.bankPosition.relPoint or db.bankPosition.point, db.bankPosition.x, db.bankPosition.y)
    else
        bankFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -100)
    end

    bankFrame:SetBackdrop(backdropTemplate)
    bankFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], FRAME_ALPHA)
    bankFrame:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 1)  -- 銀行用金色邊框
    bankFrame:SetFrameStrata("HIGH")
    bankFrame:SetMovable(true)
    bankFrame:EnableMouse(true)
    bankFrame:SetClampedToScreen(true)
    bankFrame:Hide()

    -- 可拖曳
    bankFrame:RegisterForDrag("LeftButton")
    bankFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bankFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- 儲存位置到 DB
        local point, _, relPoint, x, y = self:GetPoint()
        local bankDb = GetBagDB()
        if bankDb then
            bankDb.bankPosition = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- 標題
    local title = bankFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", PADDING, -8)
    title:SetText(L["BankTitle"] or "Bank")
    title:SetTextColor(1, 0.82, 0)  -- 金色
    bankFrame.title = title

    -- 關閉按鈕
    local bankCloseButton = CreateFrame("Button", nil, bankFrame)
    bankCloseButton:SetSize(20, 20)
    bankCloseButton:SetPoint("TOPRIGHT", -4, -4)
    bankCloseButton:SetNormalFontObject(GameFontNormal)
    bankCloseButton:SetText("×")
    LunarUI.SetFont(bankCloseButton:GetFontString(), 16, "OUTLINE")
    bankCloseButton:SetScript("OnClick", function()
        if LunarUI.CloseBank then
            LunarUI.CloseBank()
        end
    end)

    -- 搜尋框
    bankSearchBox = CreateFrame("EditBox", "LunarUI_BankSearch", bankFrame, "SearchBoxTemplate")
    bankSearchBox:SetSize(120, 20)
    bankSearchBox:SetPoint("TOPRIGHT", bankCloseButton, "TOPLEFT", -8, -2)

    -- 搜尋過濾函數（forward declare，實際定義在 reagentSlots 建立後）
    local ApplyBankSearch

    -- 搜尋防抖動：使用 HookScript 保留 SearchBoxTemplate 內建的佔位文字隱藏行為
    bankSearchBox:HookScript("OnTextChanged", function(_self)
        if bankSearchTimer then
            bankSearchTimer:Cancel()
            bankSearchTimer = nil
        end
        bankSearchTimer = C_Timer.NewTimer(SEARCH_DEBOUNCE, ApplyBankSearch)
    end)

    -- 排序按鈕
    local bankSortButton = CreateFrame("Button", nil, bankFrame, "BackdropTemplate")
    bankSortButton:SetSize(60, 20)
    bankSortButton:SetPoint("TOPLEFT", title, "TOPRIGHT", 10, 2)
    bankSortButton:SetBackdrop(backdropTemplate)
    bankSortButton:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    bankSortButton:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 1)

    local sortText = bankSortButton:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(sortText, 11, "OUTLINE")
    sortText:SetPoint("CENTER")
    sortText:SetText(L["Sort"] or "Sort")
    sortText:SetTextColor(0.8, 0.8, 0.8)

    bankSortButton:SetScript("OnClick", function()
        isSorting = true
        C_Container.SortBankBags()
    end)

    bankSortButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C.bgButtonHover[1], C.bgButtonHover[2], C.bgButtonHover[3], C.bgButtonHover[4])
    end)

    bankSortButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    end)

    -- 頁籤按鈕（銀行 / 材料銀行）
    local tabHeight = 22
    local tabContainer = CreateFrame("Frame", nil, bankFrame)
    tabContainer:SetPoint("BOTTOMLEFT", PADDING, 4)
    tabContainer:SetSize(200, tabHeight)

    local function CreateBankTab(text, order)
        local tab = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
        tab:SetSize(80, tabHeight)
        tab:SetBackdrop(backdropTemplate)
        tab:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
        tab:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 0.6)
        if order == 1 then
            tab:SetPoint("LEFT", tabContainer, "LEFT", 0, 0)
        else
            tab:SetPoint("LEFT", tabContainer, "LEFT", (order - 1) * 84, 0)
        end
        local tabText = tab:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(tabText, 9, "OUTLINE")
        tabText:SetPoint("CENTER")
        tabText:SetText(text)
        tabText:SetTextColor(0.7, 0.7, 0.7)
        tab.text = tabText
        return tab
    end

    local bankTab = CreateBankTab(L["BankTitle"] or "Bank", 1)
    local reagentTab = CreateBankTab(L["ReagentBank"] or "Reagent", 2)
    bankFrame.bankTab = bankTab
    bankFrame.reagentTab = reagentTab

    -- 11.2+ 已移除材料銀行，若無格子則隱藏頁籤
    local numReagentCheck = C_Container.GetContainerNumSlots(REAGENT_BANK_CONTAINER)
    if numReagentCheck == 0 then
        reagentTab:Hide()
    end

    -- 格子容器（主銀行）
    local slotContainer = CreateFrame("Frame", nil, bankFrame)
    slotContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    slotContainer:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_HEIGHT)
    bankFrame.slotContainer = slotContainer

    -- 格子容器（材料銀行）
    local reagentContainer = CreateFrame("Frame", nil, bankFrame)
    reagentContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    reagentContainer:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_HEIGHT)
    reagentContainer:Hide()
    bankFrame.reagentContainer = reagentContainer

    -- 建立主銀行格子（-1）
    local slotID = 0
    local numMainBankSlots = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    for slot = 1, numMainBankSlots do
        slotID = slotID + 1
        local button = CreateBankSlot(slotContainer, slotID, BANK_CONTAINER, slot)

        local row = math.floor((slotID - 1) / bankCols)
        local col = (slotID - 1) % bankCols

        button:SetPoint("TOPLEFT", slotContainer, "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )

        button:SetID(slot)
        bankSlots[slotID] = button
    end

    -- 建立銀行包格子（5-11）
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotID = slotID + 1
            local button = CreateBankSlot(slotContainer, slotID, bag, slot)

            local row = math.floor((slotID - 1) / bankCols)
            local col = (slotID - 1) % bankCols

            button:SetPoint("TOPLEFT", slotContainer, "TOPLEFT",
                col * (SLOT_SIZE + SLOT_SPACING),
                -row * (SLOT_SIZE + SLOT_SPACING)
            )

            button:SetID(slot)
            bankSlots[slotID] = button
        end
    end

    -- 建立材料銀行格子（-3）
    local reagentSlots = {}
    bankFrame.reagentSlots = reagentSlots
    local numReagentSlots = C_Container.GetContainerNumSlots(REAGENT_BANK_CONTAINER)
    for slot = 1, numReagentSlots do
        local button = CreateBankSlot(reagentContainer, 1000 + slot, REAGENT_BANK_CONTAINER, slot)

        local row = math.floor((slot - 1) / bankCols)
        local col = (slot - 1) % bankCols

        button:SetPoint("TOPLEFT", reagentContainer, "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )

        button:SetID(slot)
        reagentSlots[slot] = button
    end

    -- 定義銀行搜尋過濾函數（供 OnTextChanged 與 SetActiveTab 共用）
    ApplyBankSearch = function()
        if not bankSearchBox then return end
        local text = bankSearchBox:GetText():lower()
        local searchSlots = bankFrame.activeTab == "reagent" and bankFrame.reagentSlots or bankSlots
        for _, button in pairs(searchSlots) do
            if button and button:IsShown() then
                local success, err = pcall(function()
                    local itemLink = C_Container.GetContainerItemLink(button.bag, button.slot)
                    if itemLink then
                        local itemName = C_Item.GetItemInfo(itemLink)
                        if itemName then
                            if text == "" or itemName:lower():find(text, 1, true) then
                                button:SetAlpha(1)
                            else
                                button:SetAlpha(SEARCH_DIM_ALPHA)
                            end
                        else
                            button:SetAlpha(1)
                        end
                    else
                        button:SetAlpha(text == "" and 1 or SEARCH_DIM_ALPHA)
                    end
                end)
                if not success then
                    button:SetAlpha(1)
                    if LunarUI:IsDebugMode() then
                        LunarUI:Debug((L["BankSearchError"] or "Bank search error: ") .. tostring(err))
                    end
                end
            end
        end
    end

    -- 頁籤切換邏輯
    local activeTab = "bank"
    bankFrame.activeTab = activeTab

    local function SetActiveTab(tabName)
        bankFrame.activeTab = tabName
        if tabName == "bank" then
            slotContainer:Show()
            reagentContainer:Hide()
            bankTab.text:SetTextColor(1, 0.82, 0)
            bankTab:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 1)
            reagentTab.text:SetTextColor(0.7, 0.7, 0.7)
            reagentTab:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 0.4)
        elseif tabName == "reagent" then
            slotContainer:Hide()
            reagentContainer:Show()
            reagentTab.text:SetTextColor(1, 0.82, 0)
            reagentTab:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 1)
            bankTab.text:SetTextColor(0.7, 0.7, 0.7)
            bankTab:SetBackdropBorderColor(BORDER_COLOR_BANK[1], BORDER_COLOR_BANK[2], BORDER_COLOR_BANK[3], 0.4)
            -- 更新材料銀行格子
            for _, button in pairs(reagentSlots) do
                if button then UpdateBankSlot(button) end
            end
        end
        -- 切換頁籤後重新套用搜尋過濾
        ApplyBankSearch()
    end

    -- 預設啟用銀行頁籤
    SetActiveTab("bank")

    bankTab:SetScript("OnClick", function() SetActiveTab("bank") end)
    reagentTab:SetScript("OnClick", function() SetActiveTab("reagent") end)

    -- 空格指示器
    local freeSlots = bankFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(freeSlots, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(1, 0.82, 0)
    bankFrame.freeSlots = freeSlots

    return bankFrame
end

-- 批次更新銀行格子避免 FPS 下降
local bankUpdateQueue = {}
local bankUpdateInProgress = false
local BANK_BATCH_SIZE = 10

local function ProcessBankUpdateBatch()
    if #bankUpdateQueue == 0 then
        bankUpdateInProgress = false
        -- 完成時更新空格顯示
        if bankFrame and bankFrame.freeSlots then
            local free = GetTotalBankFreeSlots()
            local total = GetTotalBankSlots()
            bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
        end
        return
    end

    -- 處理批次
    for _ = 1, BANK_BATCH_SIZE do
        local button = table.remove(bankUpdateQueue, 1)
        if button then
            UpdateBankSlot(button)
        end
        if #bankUpdateQueue == 0 then
            bankUpdateInProgress = false
            -- 完成時更新空格顯示
            if bankFrame and bankFrame.freeSlots then
                local free = GetTotalBankFreeSlots()
                local total = GetTotalBankSlots()
                bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
            end
            return
        end
    end

    -- 排程下一批次
    C_Timer.After(0, ProcessBankUpdateBatch)
end

local function UpdateAllBankSlots()
    -- 使用批次更新處理大型銀行
    wipe(bankUpdateQueue)
    for _, button in pairs(bankSlots) do
        if button then
            table.insert(bankUpdateQueue, button)
        end
    end

    if not bankUpdateInProgress and #bankUpdateQueue > 0 then
        bankUpdateInProgress = true
        ProcessBankUpdateBatch()
    end
end

local function RefreshBankLayout()
    if not bankFrame then return end

    -- 重新計算框架大小（動態調整欄數避免超出螢幕）
    local totalSlots = GetTotalBankSlots()
    local bankCols = GetBankSlotsPerRow(totalSlots)
    bankFrame.bankCols = bankCols
    local numRows = math.ceil(totalSlots / bankCols)
    local width = bankCols * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT

    bankFrame:SetSize(width, height)

    -- 必要時重建格子
    local slotID = 0

    -- 主銀行格子
    local numMainBankSlots = C_Container.GetContainerNumSlots(BANK_CONTAINER)
    for slot = 1, numMainBankSlots do
        slotID = slotID + 1

        local button = bankSlots[slotID]
        if not button then
            button = CreateBankSlot(bankFrame.slotContainer, slotID, BANK_CONTAINER, slot)
            bankSlots[slotID] = button
        end
        button.bag = BANK_CONTAINER
        button.slot = slot

        local row = math.floor((slotID - 1) / bankCols)
        local col = (slotID - 1) % bankCols

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bankFrame.slotContainer, "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )
        button:Show()
    end

    -- 銀行包格子
    for bag = FIRST_BANK_BAG, LAST_BANK_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotID = slotID + 1

            local button = bankSlots[slotID]
            if not button then
                button = CreateBankSlot(bankFrame.slotContainer, slotID, bag, slot)
                bankSlots[slotID] = button
            end
            button.bag = bag
            button.slot = slot

            local row = math.floor((slotID - 1) / bankCols)
            local col = (slotID - 1) % bankCols

            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", bankFrame.slotContainer, "TOPLEFT",
                col * (SLOT_SIZE + SLOT_SPACING),
                -row * (SLOT_SIZE + SLOT_SPACING)
            )
            button:Show()
        end
    end

    -- 隱藏多餘格子
    for i = slotID + 1, #bankSlots do
        if bankSlots[i] then
            bankSlots[i]:Hide()
        end
    end

    UpdateAllBankSlots()
end

local function OpenBank()
    if InCombatLockdown() then return end

    if not bankFrame then
        CreateBankFrame()
    end

    if bankFrame then
        -- 清除專業容器快取（銀行包可能已更換）
        wipe(bagTypeCache)
        RefreshBankLayout()
        bankFrame:Show()
        isBankOpen = true
    end
end

local function CloseBank()
    if bankFrame then
        bankFrame:Hide()
        isBankOpen = false
        -- 取消銀行搜尋計時器避免洩漏
        if bankSearchTimer then
            bankSearchTimer:Cancel()
            bankSearchTimer = nil
        end
        -- 關閉時清除搜尋
        local db = GetBagDB()
        if db and db.clearSearchOnClose and bankSearchBox then
            bankSearchBox:SetText("")
            for _, button in pairs(bankSlots) do
                if button then button:SetAlpha(1) end
            end
        end
        -- 清除銀行批次更新佇列避免洩漏
        wipe(bankUpdateQueue)
        bankUpdateInProgress = false
    end
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateMoney()
    if not bagFrame or not bagFrame.money then return end

    local money = GetMoney()
    local gold = floor(money / 10000)
    local silver = floor((money % 10000) / 100)
    local copper = money % 100

    bagFrame.money:SetFormattedText("|cffffd700%d|r.|cffc0c0c0%02d|r.|cffeda55f%02d|r", gold, silver, copper)
end

local function UpdateFreeSlots()
    if not bagFrame or not bagFrame.freeSlots then return end

    local free = GetTotalFreeSlots()
    local total = GetTotalSlots()
    bagFrame.freeSlots:SetFormattedText("%d / %d", free, total)
end

local function UpdateAllSlots()
    -- 預計算所有背包的專業容器顏色（避免逐格重複呼叫）
    for bag = 0, 4 do
        GetBagTypeColor(bag)
    end
    for _, button in pairs(slots) do
        if button then
            UpdateSlot(button)
        end
    end
    UpdateMoney()
    UpdateFreeSlots()
end

-- 僅更新升級箭頭（用於 PLAYER_EQUIPMENT_CHANGED，避免全量重繪）
local function UpdateUpgradeArrows()
    for _, button in pairs(slots) do
        if button and button.upgradeArrow then
            local itemLink = C_Container.GetContainerItemLink(button.bag, button.slot)
            if itemLink and IsItemUpgrade(itemLink) then
                button.upgradeArrow:Show()
            else
                button.upgradeArrow:Hide()
            end
        end
    end
end

local function RefreshBagLayout()
    if not bagFrame then return end

    local db = GetBagDB()

    -- 收集所有格子的 bag/slot 資料（支援反轉順序）
    local slotList = {}
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotList[#slotList + 1] = { bag = bag, slot = slot }
        end
    end
    if db and db.reverseBagSlots then
        local n = #slotList
        for i = 1, math.floor(n / 2) do
            slotList[i], slotList[n - i + 1] = slotList[n - i + 1], slotList[i]
        end
    end

    -- 計算框架大小（支援分離背包視圖）
    local numRows
    if db and db.splitBags then
        local layoutIdx = 0
        local prevBag = nil
        for bag = 0, 4 do
            local numBagSlots = C_Container.GetContainerNumSlots(bag)
            if numBagSlots > 0 then
                if prevBag ~= nil then
                    local currentCol = layoutIdx % SLOTS_PER_ROW
                    if currentCol ~= 0 then
                        layoutIdx = layoutIdx + (SLOTS_PER_ROW - currentCol)
                    end
                end
                prevBag = bag
                layoutIdx = layoutIdx + numBagSlots
            end
        end
        numRows = math.ceil(layoutIdx / SLOTS_PER_ROW)
    else
        numRows = math.ceil(#slotList / SLOTS_PER_ROW)
    end
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT

    bagFrame:SetSize(width, height)

    -- 佈局格子（支援分離背包）
    local slotID = 0
    local layoutIdx = 0
    local prevBag = nil
    for _, slotInfo in ipairs(slotList) do
        slotID = slotID + 1

        local button = slots[slotID]
        if not button then
            button = CreateItemSlot(bagFrame.slotContainer, slotID, slotInfo.bag, slotInfo.slot)
            slots[slotID] = button
        end
        button.bag = slotInfo.bag
        button.slot = slotInfo.slot

        -- 分離背包視圖
        if db and db.splitBags and prevBag ~= nil and slotInfo.bag ~= prevBag then
            local currentCol = layoutIdx % SLOTS_PER_ROW
            if currentCol ~= 0 then
                layoutIdx = layoutIdx + (SLOTS_PER_ROW - currentCol)
            end
        end
        prevBag = slotInfo.bag

        local row = math.floor(layoutIdx / SLOTS_PER_ROW)
        local col = layoutIdx % SLOTS_PER_ROW

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", bagFrame.slotContainer, "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )
        button:SetSize(SLOT_SIZE, SLOT_SIZE)
        button:Show()
        layoutIdx = layoutIdx + 1
    end

    -- 隱藏多餘格子
    for i = slotID + 1, #slots do
        if slots[i] then
            slots[i]:Hide()
        end
    end

    UpdateAllSlots()
end

--------------------------------------------------------------------------------
-- 開啟/關閉背包
--------------------------------------------------------------------------------

local function OpenBags()
    if InCombatLockdown() then return end

    if not bagFrame then
        CreateBagFrame()
    end

    if bagFrame then
        -- 刷新裝備等級快取（用於升級箭頭判斷）
        equippedIlvlDirty = true
        RefreshEquippedItemLevels()
        -- 清除背包類型快取（背包可能已更換）
        wipe(bagTypeCache)

        RefreshBagLayout()
        bagFrame:Show()
        isOpen = true
    end
end

local function CloseBags()
    if bagFrame then
        bagFrame:Hide()
        isOpen = false
        -- 取消搜尋計時器避免洩漏
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end
        if bankSearchTimer then
            bankSearchTimer:Cancel()
            bankSearchTimer = nil
        end
        -- 關閉時清除搜尋
        local db = GetBagDB()
        if db and db.clearSearchOnClose and searchBox then
            searchBox:SetText("")
            for _, button in pairs(slots) do
                if button then button:SetAlpha(1) end
            end
        end
        -- 清除待處理的背包更新佇列
        wipe(pendingBagUpdates)
    end
end

local function ToggleBags()
    if isOpen then
        CloseBags()
    else
        OpenBags()
    end
end

-- 完全重建背包框架（設定變更後呼叫）
function LunarUI.RebuildBags()
    local wasOpen = isOpen
    local wasBankOpen = isBankOpen

    -- 隱藏並清理舊格子（WoW 框架不可銷毀，僅隱藏+解除錨定）
    for _, button in pairs(slots) do
        if button then
            if button.newGlowAnim then button.newGlowAnim:Stop() end
            button:Hide()
            button:ClearAllPoints()
        end
    end
    for _, button in pairs(bankSlots) do
        if button then
            if button.newGlowAnim then button.newGlowAnim:Stop() end
            button:Hide()
            button:ClearAllPoints()
        end
    end
    if bankFrame and bankFrame.reagentSlots then
        for _, button in pairs(bankFrame.reagentSlots) do
            if button then
                if button.newGlowAnim then button.newGlowAnim:Stop() end
                button:Hide()
                button:ClearAllPoints()
            end
        end
    end

    -- 隱藏主框架（但不 SetParent(nil)，保留供子框架重新 reparent）
    if bagFrame then
        CloseBags()
        bagFrame:Hide()
        bagFrame = nil
    end
    if bankFrame then
        CloseBank()
        bankFrame:Hide()
        bankFrame = nil
    end

    -- 清空格子參照
    wipe(slots)
    wipe(bankSlots)
    searchBox = nil
    bankSearchBox = nil
    sortButton = nil
    closeButton = nil

    -- 重新載入設定
    LoadBagSettings()

    -- 重建
    if wasOpen then
        OpenBags()
    end
    if wasBankOpen then
        OpenBank()
    end
end

--------------------------------------------------------------------------------
-- 掛鉤暴雪背包函數
--------------------------------------------------------------------------------

local hooksRegistered = false

local function HookBagFunctions()
    if hooksRegistered then return end

    local db = GetBagDB()
    if not db or not db.enabled then return end

    hooksRegistered = true

    -- 掛鉤 OpenAllBags
    hooksecurefunc("OpenAllBags", function()
        OpenBags()
    end)

    -- 掛鉤 CloseAllBags
    hooksecurefunc("CloseAllBags", function()
        CloseBags()
    end)

    -- 掛鉤 ToggleAllBags：按 B 時切換我們的背包
    hooksecurefunc("ToggleAllBags", function()
        ToggleBags()
    end)

    -- 徹底禁用暴雪背包框架（alpha 0 + 移到螢幕外 + 禁用滑鼠）
    -- 只設 alpha 0 不夠：框架仍接收滑鼠事件，會擋住我們的自訂背包
    local function KillBlizzardFrame(frame)
        if not frame then return end
        pcall(function()
            frame:SetAlpha(0)
            frame:EnableMouse(false)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
            for _, child in ipairs({ frame:GetChildren() }) do
                pcall(function() child:EnableMouse(false) end)
            end
        end)
    end

    -- 掛鉤 Show：暴雪每次打開背包都會 Show 這些框架，需持續壓制
    local function KillAndHookShow(frame)
        KillBlizzardFrame(frame)
        pcall(function()
            hooksecurefunc(frame, "Show", function(self)
                KillBlizzardFrame(self)
            end)
        end)
    end

    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then KillAndHookShow(frame) end
    end
    if ContainerFrameCombinedBags then
        KillAndHookShow(ContainerFrameCombinedBags)
    end
    if BankFrame then
        KillAndHookShow(BankFrame)
    end
    -- 戰團銀行：保留原生 UI（C_Bank API 尚未完整整合）
    -- if AccountBankPanel then
    --     KillAndHookShow(AccountBankPanel)
    -- end
end

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlerSet = false  -- 防止重複設定 handler

-- 事件處理函數 (提取到模組層級)
local function OnBagEvent(_self, event, ...)
    -- 商人開啟時自動販賣垃圾
    if event == "MERCHANT_SHOW" then
        local db = GetBagDB()
        if db and db.autoSellJunk then
            C_Timer.After(JUNK_SELL_DELAY, SellJunk)
        end
        return
    end

    -- 銀行事件處理
    if event == "BANKFRAME_OPENED" then
        local db = GetBagDB()
        if db and db.enabled then
            OpenBank()
            -- 開啟銀行時同時開啟背包
            OpenBags()
        end
        return
    end

    if event == "BANKFRAME_CLOSED" then
        CloseBank()
        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED" then
        if bankFrame and bankFrame:IsShown() then
            UpdateAllBankSlots()
        end
        return
    end

    -- 裝備變更時標記快取過期，僅更新升級箭頭（避免全量重繪）
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        equippedIlvlDirty = true
        if bagFrame and bagFrame:IsShown() then
            UpdateUpgradeArrows()
        end
        return
    end

    -- BAG_UPDATE：僅記錄需更新的背包 ID（排序時會密集觸發，不在此處理）
    if event == "BAG_UPDATE" then
        local bag = ...
        if bag then
            pendingBagUpdates[bag] = true
        end
        return
    end

    -- BAG_UPDATE_DELAYED：WoW 原生事件，在一連串 BAG_UPDATE 結束後觸發一次
    -- 這是 Bagnon 使用的模式，比 C_Timer 節流更可靠且零開銷
    if event == "BAG_UPDATE_DELAYED" then
        -- 處理累積的背包更新
        for pendingBag in pairs(pendingBagUpdates) do
            -- 更新背包（0-4）
            if pendingBag >= 0 and pendingBag <= 4 then
                if bagFrame and bagFrame:IsShown() then
                    for _, button in pairs(slots) do
                        if button and button.bag == pendingBag then
                            UpdateSlot(button)
                        end
                    end
                end
            end
            -- 更新銀行包（5-11）
            if pendingBag >= FIRST_BANK_BAG and pendingBag <= LAST_BANK_BAG then
                if bankFrame and bankFrame:IsShown() then
                    for _, button in pairs(bankSlots) do
                        if button and button.bag == pendingBag then
                            UpdateBankSlot(button)
                        end
                    end
                end
            end
        end

        -- 更新計數器
        if bagFrame and bagFrame:IsShown() then
            UpdateFreeSlots()
        end
        if bankFrame and bankFrame:IsShown() and bankFrame.freeSlots then
            local free = GetTotalBankFreeSlots()
            local total = GetTotalBankSlots()
            bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
        end

        wipe(pendingBagUpdates)
        -- 排序後清理物品快取（避免 orphan entries 累積）
        if isSorting then
            wipe(itemLevelCache)
            wipe(equipmentTypeCache)
            itemLevelCacheMeta.n = 0
            equipmentTypeCacheMeta.n = 0
        end
        isSorting = false  -- 排序完成，恢復正常事件處理
        return
    end

    if not bagFrame or not bagFrame:IsShown() then return end

    if event == "PLAYER_MONEY" then
        UpdateMoney()
    elseif event == "ITEM_LOCK_CHANGED" then
        -- 排序期間跳過：SortBags 會密集觸發 ITEM_LOCK_CHANGED（每次物品移動 2 次），
        -- 每次都呼叫 UpdateAllSlots 會造成嚴重卡頓。排序結束後由 BAG_UPDATE_DELAYED 統一更新。
        if not isSorting then
            UpdateAllSlots()
            if bankFrame and bankFrame:IsShown() then
                UpdateAllBankSlots()
            end
        end
    elseif event == "BAG_SLOT_FLAGS_UPDATED" then
        -- 背包類型可能已改變（換包），清除專業容器快取
        wipe(bagTypeCache)
        RefreshBagLayout()
        if bankFrame and bankFrame:IsShown() then
            UpdateAllBankSlots()
        end
    end
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 垃圾販賣
--------------------------------------------------------------------------------

--[[
    增強型自動販賣：包含安全檢查與統計資訊
]]
SellJunk = function()
    local db = GetBagDB()
    if not db or not db.autoSellJunk then return end

    -- 第一步：收集所有垃圾物品
    local junkItems = {}
    local totalValue = 0

    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local containerInfo = C_Container.GetContainerItemInfo(bag, slot)
            if containerInfo and containerInfo.quality == 0 and not containerInfo.hasNoValue then
                local itemLink = C_Container.GetContainerItemLink(bag, slot)
                if itemLink then
                    local _, _, _, _, _, _, _, _, _, _, itemPrice = C_Item.GetItemInfo(itemLink)
                    if itemPrice and itemPrice > 0 then
                        local stackCount = containerInfo.stackCount or 1
                        local stackValue = itemPrice * stackCount
                        totalValue = totalValue + stackValue
                        junkItems[#junkItems + 1] = { bag = bag, slot = slot, value = stackValue }
                    end
                end
            end
        end
    end

    if #junkItems == 0 then return end

    -- 第二步：逐件販賣（C_Timer 分批避免伺服器節流）
    local itemCount = #junkItems
    local index = 0
    local function SellNext()
        -- 確保商人視窗仍然開啟，玩家可能在販賣過程中關閉商人
        if not MerchantFrame or not MerchantFrame:IsShown() then return end
        index = index + 1
        if index > #junkItems then
            -- 所有垃圾已販賣，輸出統計
            local gold = floor(totalValue / 10000)
            local silver = floor((totalValue % 10000) / 100)
            local copper = totalValue % 100

            local goldStr = ""
            if gold > 0 then
                goldStr = format("|cffffd700%d|rg ", gold)
            end
            if silver > 0 or gold > 0 then
                goldStr = goldStr .. format("|cffc0c0c0%d|rs ", silver)
            end
            goldStr = goldStr .. format("|cffeda55f%d|rc", copper)

            local msg = L["SoldJunkItems"] or "Sold %d junk items for %s"
            print(format("|cff00ccffLunarUI:|r " .. msg, itemCount, goldStr))
            return
        end

        local item = junkItems[index]
        if not item then return end
        C_Container.UseContainerItem(item.bag, item.slot)
        C_Timer.After(0.2, SellNext)
    end
    SellNext()
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeBags()
    local db = GetBagDB()
    if not db or not db.enabled then return end

    -- 註冊事件 (移到 InitializeBags 中，確保 disable/enable 可正常工作)
    if not eventHandlerSet then
        eventFrame:SetScript("OnEvent", OnBagEvent)
        eventHandlerSet = true
    end

    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:RegisterEvent("BAG_SLOT_FLAGS_UPDATED")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("BANKFRAME_CLOSED")
    eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

    -- 掛鉤背包函數
    HookBagFunctions()

    -- 快捷鍵開啟背包由暴雪預設按鍵系統處理
end

-- 清理函數
function LunarUI.CleanupBags()
    eventFrame:UnregisterAllEvents()
    CloseBags()
    CloseBank()
end

-- 匯出
LunarUI.InitializeBags = InitializeBags
LunarUI.ToggleBags = ToggleBags
LunarUI.OpenBags = OpenBags
LunarUI.CloseBags = CloseBags
LunarUI.SellJunk = SellJunk
LunarUI.OpenBank = OpenBank
LunarUI.CloseBank = CloseBank

LunarUI:RegisterModule("Bags", {
    onEnable = InitializeBags,
    onDisable = LunarUI.CleanupBags,
    delay = INIT_DELAY,
})
