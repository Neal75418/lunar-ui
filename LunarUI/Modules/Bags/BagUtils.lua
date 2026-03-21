---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 背包工具函數
    物品分析工具：裝等快取、裝備判斷、升級判斷、專業容器顏色
    無 UI 依賴，純資料層
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local bit_band = bit.band -- LuaJIT built-in（LLS 環境限制，快取為 local）

--------------------------------------------------------------------------------
-- 快取機制：避免重複呼叫昂貴的物品資訊 API
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- GetItemLevel
--------------------------------------------------------------------------------

local function GetItemLevel(itemLink)
    if not itemLink then
        return nil
    end

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

--------------------------------------------------------------------------------
-- IsEquipment
--------------------------------------------------------------------------------

local function IsEquipment(itemLink)
    if not itemLink then
        return false
    end

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

--------------------------------------------------------------------------------
-- IsItemUpgrade（裝等升級判斷）
--------------------------------------------------------------------------------

-- 裝備槽位 ID 對應（用於升級判斷）
local EQUIP_LOC_TO_SLOT = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 16 },
    INVTYPE_RANGEDRIGHT = { 16 },
}

-- 快取裝備中的物品等級（開啟背包時刷新）
local equippedItemLevels = {}
local equippedIlvlDirty = true

-- 刷新裝備物品等級快取
local function RefreshEquippedItemLevels()
    if not equippedIlvlDirty then
        return
    end
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
    if not itemLink then
        return false
    end

    local db = LunarUI.GetModuleDB("bags")
    if not db or not db.showUpgradeArrow then
        return false
    end

    -- 取得物品裝備位置
    local _, _, _, _, _, _, _, _, equipLoc = C_Item.GetItemInfo(itemLink)
    if not equipLoc or equipLoc == "" then
        return false
    end

    local slotIDs = EQUIP_LOC_TO_SLOT[equipLoc]
    if not slotIDs then
        return false
    end

    -- 取得此物品的等級
    local itemIlvl = select(1, C_Item.GetDetailedItemLevelInfo(itemLink))
    if not itemIlvl or itemIlvl <= 1 then
        return false
    end

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

--------------------------------------------------------------------------------
-- GetBagTypeColor（專業容器背景著色）
--------------------------------------------------------------------------------

-- 專業容器背景著色
-- 透過 C_Container.GetContainerNumFreeSlots 的第二個返回值 bagType 判斷
-- bagType 是位元遮罩（flag），對應 Enum.BagFamily
local PROFESSION_BAG_COLORS = {
    -- bagType 旗標 → { r, g, b, a }
    [0x0008] = { 0.18, 0.55, 0.18, 0.25 }, -- 草藥（Herbs）綠色
    [0x0010] = { 0.55, 0.28, 0.55, 0.25 }, -- 附魔（Enchanting）紫色
    [0x0020] = { 0.45, 0.45, 0.55, 0.25 }, -- 工程（Engineering）灰藍
    [0x0040] = { 0.20, 0.50, 0.70, 0.25 }, -- 珠寶（Gems）藍色
    [0x0080] = { 0.50, 0.40, 0.25, 0.25 }, -- 礦石（Mining）褐色
    [0x0200] = { 0.60, 0.45, 0.30, 0.25 }, -- 製皮（Leatherworking）皮革色
    [0x0400] = { 0.50, 0.50, 0.50, 0.25 }, -- 銘文（Inscription）灰色
    [0x0800] = { 0.30, 0.55, 0.45, 0.25 }, -- 釣魚（Fishing/Tackle）青色
    [0x1000] = { 0.55, 0.35, 0.20, 0.25 }, -- 烹飪（Cooking）橘棕色
}

-- 取得背包類型顏色（專業容器）
local bagTypeCache = {}

local function GetBagTypeColor(bag)
    local db = LunarUI.GetModuleDB("bags")
    if not db or not db.showProfessionColors then
        return false
    end

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

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.BagsGetItemLevel = GetItemLevel
LunarUI.BagsIsEquipment = IsEquipment
LunarUI.BagsIsItemUpgrade = IsItemUpgrade
LunarUI.BagsRefreshEquippedItemLevels = RefreshEquippedItemLevels
LunarUI.BagsGetBagTypeColor = GetBagTypeColor
LunarUI.BagsEquippedIlvlDirty = { value = equippedIlvlDirty }
LunarUI.BagsClearBagTypeCache = function()
    wipe(bagTypeCache)
end
LunarUI.MaybeEvictCache = MaybeEvictCache

-- 向後相容匯出（主 Bags.lua 使用的名稱）
LunarUI.BagsGetItemLevel = GetItemLevel
LunarUI.IsEquipment = IsEquipment
LunarUI.IsItemUpgrade = IsItemUpgrade
LunarUI.GetBagTypeColor = GetBagTypeColor
LunarUI.BagsResetEquippedIlvlDirty = function()
    equippedIlvlDirty = true
    LunarUI.BagsEquippedIlvlDirty.value = true
end
LunarUI.BagsClearItemLevelCache = function()
    wipe(itemLevelCache)
    itemLevelCacheMeta.n = 0
end
LunarUI.BagsClearEquipmentTypeCache = function()
    wipe(equipmentTypeCache)
    equipmentTypeCacheMeta.n = 0
end
LunarUI.BagsClearAllCaches = function()
    wipe(itemLevelCache)
    wipe(equipmentTypeCache)
    itemLevelCacheMeta.n = 0
    equipmentTypeCacheMeta.n = 0
end
