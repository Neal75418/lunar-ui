---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for Bags module pure functions
    Tests: GetItemLevel, IsEquipment, IsItemUpgrade, GetBagTypeColor, GetBankSlotsPerRow,
           MaybeEvictCache, GetTotalSlots, GetTotalFreeSlots, GetTotalBankSlots, GetTotalBankFreeSlots
]]

require("spec.wow_mock")
local loader = require("spec.loader")

_G.math.ceil = math.ceil
_G.math.floor = math.floor
_G.math.max = math.max

-- bit library (LuaJIT built-in, available in busted via LuaJIT)
if not _G.bit then
    _G.bit = {
        band = function(a, b)
            return a % (b + b) >= b and b or 0
        end,
    }
end

-- WoW API stubs
_G.C_Container = {
    GetContainerNumSlots = function()
        return 0
    end,
    GetContainerNumFreeSlots = function()
        return 0, 0
    end,
    GetContainerItemLink = function()
        return nil
    end,
    GetContainerItemInfo = function()
        return nil
    end,
}

_G.C_Item = {
    GetDetailedItemLevelInfo = function()
        return nil
    end,
    GetItemInfo = function()
        return nil
    end,
    GetItemQualityColor = function()
        return 1, 1, 1, 1
    end,
}

_G.C_Timer = {
    After = function() end,
    NewTimer = function()
        return { Cancel = function() end }
    end,
}

_G.C_NewItems = {
    IsNewItem = function()
        return false
    end,
}
_G.C_ArtifactUI = {
    GetEquippedArtifactInfo = function()
        return nil
    end,
}
_G.C_TransmogCollection = {
    GetItemInfo = function()
        return nil
    end,
}

_G.GetScreenHeight = function()
    return 1080
end
_G.GetScreenWidth = function()
    return 1920
end
_G.GetInventoryItemLink = function()
    return nil
end
_G.InCombatLockdown = function()
    return false
end
_G.hooksecurefunc = function() end
_G.IsShiftKeyDown = function()
    return false
end
_G.PlaySound = function() end
_G.CloseAllBags = function() end
_G.GetMoney = function()
    return 0
end
_G.GetCoinTextureString = function()
    return ""
end

_G.SOUNDKIT = { IG_BACKPACK_OPEN = 1, IG_BACKPACK_CLOSE = 2 }
_G.LE_ITEM_QUALITY_POOR = 0
_G.LE_ITEM_QUALITY_COMMON = 1
_G.LE_ITEM_QUALITY_UNCOMMON = 2

-- Mock frame object
local function CreateMockFrame()
    local frame = {}
    frame.SetScript = function() end
    frame.HookScript = function() end
    frame.RegisterEvent = function() end
    frame.UnregisterEvent = function() end
    frame.UnregisterAllEvents = function() end
    frame.Show = function() end
    frame.Hide = function() end
    frame.IsShown = function()
        return false
    end
    frame.SetSize = function() end
    frame.SetPoint = function() end
    frame.SetAllPoints = function() end
    frame.SetAlpha = function() end
    frame.SetFrameStrata = function() end
    frame.SetFrameLevel = function() end
    frame.GetFrameLevel = function()
        return 1
    end
    frame.CreateTexture = function()
        return CreateMockFrame()
    end
    frame.CreateFontString = function()
        local fs = CreateMockFrame()
        fs.SetText = function() end
        fs.SetTextColor = function() end
        fs.SetJustifyH = function() end
        fs.GetFontString = function()
            return fs
        end
        return fs
    end
    frame.GetFontString = function()
        return frame.CreateFontString()
    end
    frame.SetTexture = function() end
    frame.SetTexCoord = function() end
    frame.SetVertexColor = function() end
    frame.SetDrawLayer = function() end
    frame.SetColorTexture = function() end
    frame.SetBackdrop = function() end
    frame.SetBackdropColor = function() end
    frame.SetBackdropBorderColor = function() end
    frame.SetNormalTexture = function() end
    frame.SetHighlightTexture = function() end
    frame.SetPushedTexture = function() end
    frame.SetEnabled = function() end
    frame.EnableMouse = function() end
    frame.SetMovable = function() end
    frame.SetClampedToScreen = function() end
    frame.RegisterForDrag = function() end
    frame.SetText = function() end
    frame.SetWidth = function() end
    frame.SetHeight = function() end
    frame.GetWidth = function()
        return 100
    end
    frame.GetHeight = function()
        return 100
    end
    frame.ClearAllPoints = function() end
    frame.SetID = function() end
    frame.GetObjectType = function()
        return "Frame"
    end
    return frame
end

_G.CreateFrame = function()
    return CreateMockFrame()
end

-- LunarUI addon table with required stubs
local LunarUI = {}
LunarUI.Colors = {
    bgSolid = { 0, 0, 0, 0.8 },
    border = { 0.15, 0.12, 0.08, 1 },
    borderGold = { 0.4, 0.35, 0.2, 1 },
    bg = { 0.05, 0.05, 0.05, 0.95 },
    bgIcon = { 0.1, 0.1, 0.1, 0.6 },
    bgButton = { 0.15, 0.15, 0.15, 0.8 },
    bgButtonHover = { 0.25, 0.25, 0.25, 0.8 },
}
LunarUI.QUALITY_COLORS = {}
LunarUI.ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }
LunarUI.backdropTemplate = {}
LunarUI.textures = { glow = "" }
LunarUI.SetFont = function() end
LunarUI.SetFontLight = function() end
LunarUI.RegisterModule = function() end
LunarUI.RegisterMovableFrame = function() end
LunarUI.CreateEventHandler = function()
    return nil
end
LunarUI.MarkSkinned = function()
    return true
end
LunarUI.ApplyBackdrop = function() end
LunarUI.SkinButton = function() end
LunarUI.StripTextures = function() end
LunarUI.Debug = function() end
LunarUI.IsDebugMode = function()
    return false
end
LunarUI.db = { profile = { bags = { enabled = true, showProfessionColors = true, showUpgradeArrow = true } } }

-- Load Utils.lua first to get GetModuleDB
loader.loadAddonFile("LunarUI/Core/Utils.lua", LunarUI)
-- Load sub-modules before main Bags.lua (matches TOC order)
loader.loadAddonFile("LunarUI/Modules/Bags/BagUtils.lua", LunarUI)
loader.loadAddonFile("LunarUI/Modules/Bags/BankSystem.lua", LunarUI)
loader.loadAddonFile("LunarUI/Modules/Bags/JunkSelling.lua", LunarUI)
loader.loadAddonFile("LunarUI/Modules/Bags.lua", LunarUI)

--------------------------------------------------------------------------------
-- GetItemLevel (Bags)
--------------------------------------------------------------------------------

describe("BagsGetItemLevel", function()
    before_each(function()
        -- Reset C_Item mock and flush module-level cache for each test
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return nil
        end
        LunarUI.BagsClearItemLevelCache()
    end)

    it("returns nil for nil input", function()
        assert.is_nil(LunarUI.BagsGetItemLevel(nil))
    end)

    it("returns item level for valid link", function()
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return 489
        end
        assert.equals(489, LunarUI.BagsGetItemLevel("item:12345"))
    end)

    it("returns nil when API returns nil", function()
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return nil
        end
        assert.is_nil(LunarUI.BagsGetItemLevel("item:99999"))
    end)

    it("caches item level on subsequent calls", function()
        local callCount = 0
        _G.C_Item.GetDetailedItemLevelInfo = function()
            callCount = callCount + 1
            return 500
        end
        LunarUI.BagsGetItemLevel("item:cached_test")
        LunarUI.BagsGetItemLevel("item:cached_test")
        -- Second call should use cache (callCount should be 1)
        assert.equals(1, callCount)
    end)
end)

--------------------------------------------------------------------------------
-- IsEquipment
--------------------------------------------------------------------------------

describe("IsEquipment", function()
    before_each(function()
        LunarUI.BagsClearAllCaches()
        _G.C_Item.GetItemInfo = function()
            return nil
        end
    end)

    it("returns false for nil input", function()
        assert.is_false(LunarUI.IsEquipment(nil))
    end)

    it("returns true for armor (itemClassID = 4)", function()
        _G.C_Item.GetItemInfo = function()
            return "Helm", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 4
        end
        assert.is_true(LunarUI.IsEquipment("item:armor"))
    end)

    it("returns true for weapon (itemClassID = 2)", function()
        _G.C_Item.GetItemInfo = function()
            return "Sword", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 2
        end
        assert.is_true(LunarUI.IsEquipment("item:weapon"))
    end)

    it("returns false for consumable (itemClassID = 0)", function()
        _G.C_Item.GetItemInfo = function()
            return "Potion", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 0
        end
        assert.is_false(LunarUI.IsEquipment("item:potion"))
    end)

    it("returns false when item info not loaded (nil classID)", function()
        _G.C_Item.GetItemInfo = function()
            return nil
        end
        assert.is_false(LunarUI.IsEquipment("item:unknown"))
    end)

    it("caches result and only calls API once per link", function()
        local callCount = 0
        _G.C_Item.GetItemInfo = function()
            callCount = callCount + 1
            return "Ring", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 4
        end
        LunarUI.IsEquipment("item:cache_ring")
        LunarUI.IsEquipment("item:cache_ring")
        assert.equals(1, callCount)
    end)

    it("does not cache when classID is nil (item not yet loaded)", function()
        local callCount = 0
        _G.C_Item.GetItemInfo = function()
            callCount = callCount + 1
            return nil
        end
        LunarUI.IsEquipment("item:not_loaded_yet")
        LunarUI.IsEquipment("item:not_loaded_yet")
        -- Should call API twice because nil result is not cached
        assert.equals(2, callCount)
    end)
end)

--------------------------------------------------------------------------------
-- IsItemUpgrade
--------------------------------------------------------------------------------

describe("IsItemUpgrade", function()
    before_each(function()
        _G.C_Item.GetItemInfo = function()
            return nil
        end
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return nil
        end
        _G.GetInventoryItemLink = function()
            return nil
        end
        -- Ensure upgrade feature is enabled
        LunarUI.db.profile.bags.showUpgradeArrow = true
        -- Reset internal dirty flag so each test gets a fresh equipped-levels cache
        LunarUI.BagsResetEquippedIlvlDirty()
    end)

    it("returns false for nil input", function()
        assert.is_false(LunarUI.IsItemUpgrade(nil))
    end)

    it("returns false when feature disabled", function()
        LunarUI.db.profile.bags.showUpgradeArrow = false
        _G.C_Item.GetItemInfo = function()
            return "Helm", nil, nil, nil, nil, nil, nil, nil, "INVTYPE_HEAD"
        end
        assert.is_false(LunarUI.IsItemUpgrade("item:helm"))
    end)

    it("returns false for non-equipment item", function()
        _G.C_Item.GetItemInfo = function()
            return "Potion", nil, nil, nil, nil, nil, nil, nil, ""
        end
        assert.is_false(LunarUI.IsItemUpgrade("item:potion"))
    end)

    it("returns false when bag item ilvl is lower than equipped", function()
        _G.C_Item.GetItemInfo = function()
            return "Helm", nil, nil, nil, nil, nil, nil, nil, "INVTYPE_HEAD"
        end
        local bagLink = "item:bag_helm_300"
        local equippedLink = "item:equipped_helm_400"
        _G.GetInventoryItemLink = function(_unit, slot)
            if slot == 1 then -- INVTYPE_HEAD = slotID 1
                return equippedLink
            end
            return nil
        end
        _G.C_Item.GetDetailedItemLevelInfo = function(link)
            if link == bagLink then
                return 300
            elseif link == equippedLink then
                return 400
            end
            return nil
        end
        assert.is_false(LunarUI.IsItemUpgrade(bagLink))
        -- Reset
        _G.GetInventoryItemLink = function()
            return nil
        end
    end)

    it("returns false when bag item ilvl equals equipped ilvl (not strictly greater)", function()
        _G.C_Item.GetItemInfo = function()
            return "Helm", nil, nil, nil, nil, nil, nil, nil, "INVTYPE_HEAD"
        end
        local link = "item:helm_equal_ilvl"
        local equippedLink = "item:equipped_equal_helm"
        _G.GetInventoryItemLink = function(_unit, slot)
            if slot == 1 then
                return equippedLink
            end
            return nil
        end
        _G.C_Item.GetDetailedItemLevelInfo = function(l)
            if l == link then
                return 400
            elseif l == equippedLink then
                return 400
            end
            return nil
        end
        assert.is_false(LunarUI.IsItemUpgrade(link))
        _G.GetInventoryItemLink = function()
            return nil
        end
    end)

    it("returns false when bag item ilvl is <= 1", function()
        _G.C_Item.GetItemInfo = function()
            return "Helm", nil, nil, nil, nil, nil, nil, nil, "INVTYPE_HEAD"
        end
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return 1
        end
        assert.is_false(LunarUI.IsItemUpgrade("item:ilvl_1_helm"))
    end)

    it("returns false when equipLoc is not in EQUIP_LOC_TO_SLOT mapping", function()
        _G.C_Item.GetItemInfo = function()
            return "Special", nil, nil, nil, nil, nil, nil, nil, "INVTYPE_NON_EQUIP"
        end
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return 400
        end
        assert.is_false(LunarUI.IsItemUpgrade("item:non_equip"))
    end)

    -- equippedIlvlDirty 是內部單次消耗狀態（before_each 已重設 dirty flag，測試順序無關）
    it("returns true when slot is empty (first dirty refresh)", function()
        _G.C_Item.GetItemInfo = function()
            return "Helm", nil, nil, nil, nil, nil, nil, nil, "INVTYPE_HEAD"
        end
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return 300
        end
        -- No equipped items (GetInventoryItemLink returns nil by default)
        assert.is_true(LunarUI.IsItemUpgrade("item:any_helm"))
    end)
end)

--------------------------------------------------------------------------------
-- GetBagTypeColor
--------------------------------------------------------------------------------

describe("GetBagTypeColor", function()
    before_each(function()
        LunarUI.BagsClearBagTypeCache()
        _G.C_Container.GetContainerNumFreeSlots = function()
            return 0, 0
        end
        LunarUI.db.profile.bags.showProfessionColors = true
    end)

    it("returns false when feature disabled", function()
        LunarUI.db.profile.bags.showProfessionColors = false
        assert.is_false(LunarUI.GetBagTypeColor(1))
    end)

    it("returns false for normal bag (bagType = 0)", function()
        _G.C_Container.GetContainerNumFreeSlots = function()
            return 10, 0
        end
        assert.is_false(LunarUI.GetBagTypeColor(99))
    end)

    it("returns green color for herb bag (flag 0x0008)", function()
        _G.C_Container.GetContainerNumFreeSlots = function()
            return 10, 0x0008
        end
        local color = LunarUI.GetBagTypeColor(100)
        assert.is_truthy(color)
        assert.are.same({ 0.18, 0.55, 0.18, 0.25 }, color)
    end)

    it("returns purple color for enchanting bag (flag 0x0010)", function()
        _G.C_Container.GetContainerNumFreeSlots = function()
            return 10, 0x0010
        end
        local color = LunarUI.GetBagTypeColor(101)
        assert.is_truthy(color)
        assert.are.same({ 0.55, 0.28, 0.55, 0.25 }, color)
    end)

    it("caches bag type color and returns same value on second call", function()
        local callCount = 0
        _G.C_Container.GetContainerNumFreeSlots = function()
            callCount = callCount + 1
            return 10, 0x0008
        end
        local first = LunarUI.GetBagTypeColor(200)
        local second = LunarUI.GetBagTypeColor(200)
        assert.equals(first, second)
        -- Second call should use cache (callCount should be 1)
        assert.equals(1, callCount)
    end)

    it("returns false for bag with unknown flag bits", function()
        -- bagType > 0 but no matching flag in PROFESSION_BAG_COLORS
        _G.C_Container.GetContainerNumFreeSlots = function()
            return 10, 0x0001
        end
        assert.is_false(LunarUI.GetBagTypeColor(201))
    end)
end)

--------------------------------------------------------------------------------
-- GetBankSlotsPerRow
--------------------------------------------------------------------------------

describe("GetBankSlotsPerRow", function()
    it("returns default SLOTS_PER_ROW for small bank", function()
        _G.GetScreenHeight = function()
            return 1080
        end
        -- Small bank, should use default 12
        local result = LunarUI.GetBankSlotsPerRow(24)
        assert.equals(12, result)
    end)

    it("increases columns for very large bank", function()
        _G.GetScreenHeight = function()
            return 600
        end
        -- Small screen + many slots should need more columns
        local result = LunarUI.GetBankSlotsPerRow(200)
        assert.is_true(result >= 12)
    end)

    it("handles minimum case (1 slot)", function()
        _G.GetScreenHeight = function()
            return 1080
        end
        local result = LunarUI.GetBankSlotsPerRow(1)
        assert.equals(12, result) -- should not go below default
    end)

    it("legacy helper caps at BANK_VIEWPORT_COLS for very large banks", function()
        _G.GetScreenHeight = function()
            return 1080
        end
        _G.GetScreenWidth = function()
            return 1920
        end
        -- Legacy path: GetBankSlotsPerRow is still callable by old code but
        -- must also respect the scrollable-bank cap.
        local result = LunarUI.GetBankSlotsPerRow(600)
        assert.is_true(result <= 14, "bank cols should cap at 14, got " .. tostring(result))
        assert.is_true(result >= 12, "bank cols should not go below SLOTS_PER_ROW default")
    end)
end)

--------------------------------------------------------------------------------
-- ResizeBankFrame: scrollable-bank viewport invariant
-- Directly exercises the production path that actually sets bankFrame.bankCols
-- during OpenBank, independently of the legacy GetBankSlotsPerRow helper.
--------------------------------------------------------------------------------

describe("ResizeBankFrame viewport invariant", function()
    local function makeFakeBank()
        local calls = { setHeight = {} }
        local fake = {
            slotContainer = {
                SetHeight = function(_, h)
                    calls.setHeight[#calls.setHeight + 1] = h
                end,
            },
        }
        return fake, calls
    end

    it("pins bankFrame.bankCols to BANK_VIEWPORT_COLS (14) regardless of slot count", function()
        local fake = makeFakeBank()
        LunarUI._SetBankFrameForTest(fake)
        LunarUI._ResizeBankFrame(600) -- simulate WoW 12.0 fully-unlocked character bank
        assert.equals(14, LunarUI._BANK_VIEWPORT_COLS)
        assert.equals(14, fake.bankCols, "bankCols must stay at viewport width, got " .. tostring(fake.bankCols))
        assert.equals(600, fake.displaySlots, "all slots reachable via scroll; displaySlots = actual count")
        LunarUI._SetBankFrameForTest(nil) -- cleanup
    end)

    it("sets slotContainer height based on totalRows, not total slot count", function()
        local fake, calls = makeFakeBank()
        LunarUI._SetBankFrameForTest(fake)
        LunarUI._ResizeBankFrame(200)
        -- With 14 cols and 200 slots, totalRows = ceil(200/14) = 15
        -- contentHeight = 15 * (37+4) - 4 = 611
        assert.equals(1, #calls.setHeight, "SetHeight should be called exactly once")
        local h = calls.setHeight[1]
        assert.is_true(h > 0, "contentHeight must be positive")
        assert.equals(611, h, "contentHeight for 200 slots should be 611, got " .. tostring(h))
        LunarUI._SetBankFrameForTest(nil)
    end)

    it("guards against empty bank (actualSlotCount = 0)", function()
        local fake, calls = makeFakeBank()
        LunarUI._SetBankFrameForTest(fake)
        LunarUI._ResizeBankFrame(0)
        assert.equals(0, #calls.setHeight, "no SetHeight call for empty bank")
        assert.is_nil(fake.bankCols, "bankCols untouched when actualSlotCount is 0")
        LunarUI._SetBankFrameForTest(nil)
    end)
end)

--------------------------------------------------------------------------------
-- MaybeEvictCache
--------------------------------------------------------------------------------

describe("MaybeEvictCache", function()
    it("does nothing when under limit", function()
        local cache = { a = 1, b = 2 }
        local sizeRef = { n = 5 }
        LunarUI.MaybeEvictCache(cache, sizeRef)
        assert.equals(1, cache.a)
        assert.equals(5, sizeRef.n)
    end)

    it("clears cache and resets counter at limit", function()
        local cache = { a = 1, b = 2, c = 3 }
        local sizeRef = { n = 1000 }
        LunarUI.MaybeEvictCache(cache, sizeRef)
        assert.is_nil(cache.a)
        assert.equals(0, sizeRef.n)
    end)

    it("clears cache when over limit", function()
        local cache = { x = "test" }
        local sizeRef = { n = 1500 }
        LunarUI.MaybeEvictCache(cache, sizeRef)
        assert.is_nil(cache.x)
        assert.equals(0, sizeRef.n)
    end)

    it("handles empty cache at limit", function()
        local cache = {}
        local sizeRef = { n = 1000 }
        LunarUI.MaybeEvictCache(cache, sizeRef)
        assert.equals(0, sizeRef.n)
    end)
end)

--------------------------------------------------------------------------------
-- GetTotalSlots
--------------------------------------------------------------------------------

describe("GetTotalSlots", function()
    before_each(function()
        _G.C_Container.GetContainerNumSlots = function()
            return 0
        end
    end)

    it("returns 0 when all bags empty", function()
        assert.equals(0, LunarUI.GetTotalSlots())
    end)

    it("sums slots across bags 0-5 including reagent bag", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            local sizes = { [0] = 16, [1] = 28, [2] = 32, [3] = 32, [4] = 30, [5] = 18 }
            return sizes[bag] or 0
        end
        assert.equals(156, LunarUI.GetTotalSlots())
    end)

    it("handles single bag with slots", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            if bag == 0 then
                return 16
            end
            return 0
        end
        assert.equals(16, LunarUI.GetTotalSlots())
    end)
end)

--------------------------------------------------------------------------------
-- GetTotalFreeSlots
--------------------------------------------------------------------------------

describe("GetTotalFreeSlots", function()
    before_each(function()
        _G.C_Container.GetContainerNumFreeSlots = function()
            return 0, 0
        end
    end)

    it("returns 0 when no free slots", function()
        assert.equals(0, LunarUI.GetTotalFreeSlots())
    end)

    it("sums free slots across bags 0-5 including reagent bag", function()
        _G.C_Container.GetContainerNumFreeSlots = function(bag)
            local free = { [0] = 5, [1] = 10, [2] = 0, [3] = 8, [4] = 3, [5] = 6 }
            return free[bag] or 0, 0
        end
        assert.equals(32, LunarUI.GetTotalFreeSlots())
    end)

    it("handles all bags full", function()
        _G.C_Container.GetContainerNumFreeSlots = function()
            return 0, 0
        end
        assert.equals(0, LunarUI.GetTotalFreeSlots())
    end)
end)

--------------------------------------------------------------------------------
-- GetTotalBankSlots
--------------------------------------------------------------------------------

describe("GetTotalBankSlots", function()
    before_each(function()
        _G.C_Container.GetContainerNumSlots = function()
            return 0
        end
    end)

    it("returns 0 when bank empty", function()
        assert.equals(0, LunarUI.GetTotalBankSlots())
    end)

    it("sums main bank and bank bags", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            -- bag -1 = main bank, bags 6-11 = bank bags (WoW 12.0: bag 5 = reagent bag)
            local sizes = { [-1] = 28, [6] = 32, [7] = 32, [8] = 0, [9] = 0, [10] = 0, [11] = 0 }
            return sizes[bag] or 0
        end
        assert.equals(92, LunarUI.GetTotalBankSlots())
    end)

    it("handles only main bank with no bank bags", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            if bag == -1 then
                return 28
            end
            return 0
        end
        assert.equals(28, LunarUI.GetTotalBankSlots())
    end)

    it("excludes bag 5 (reagent bag in WoW 12.0)", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            local sizes = { [-1] = 28, [5] = 100, [6] = 32 }
            return sizes[bag] or 0
        end
        -- bag 5 的 100 格不應被計入（28 + 32 = 60）
        assert.equals(60, LunarUI.GetTotalBankSlots())
    end)
end)

--------------------------------------------------------------------------------
-- GetTotalBankFreeSlots
--------------------------------------------------------------------------------

describe("GetTotalBankFreeSlots", function()
    before_each(function()
        _G.C_Container.GetContainerNumFreeSlots = function()
            return 0, 0
        end
    end)

    it("returns 0 when no free bank slots", function()
        assert.equals(0, LunarUI.GetTotalBankFreeSlots())
    end)

    it("sums free slots across bank containers", function()
        _G.C_Container.GetContainerNumFreeSlots = function(bag)
            local free = { [-1] = 10, [6] = 5, [7] = 8 }
            return free[bag] or 0, 0
        end
        assert.equals(23, LunarUI.GetTotalBankFreeSlots())
    end)

    it("excludes bag 5 free slots (reagent bag in WoW 12.0)", function()
        _G.C_Container.GetContainerNumFreeSlots = function(bag)
            local free = { [-1] = 10, [5] = 50, [6] = 5 }
            return free[bag] or 0, 0
        end
        -- bag 5 的 50 空格不應被計入（10 + 5 = 15）
        assert.equals(15, LunarUI.GetTotalBankFreeSlots())
    end)
end)

--------------------------------------------------------------------------------
-- GetLastOccupiedSlotID
--------------------------------------------------------------------------------

describe("GetLastOccupiedSlotID", function()
    before_each(function()
        _G.C_Container.GetContainerNumSlots = function()
            return 0
        end
        _G.C_Container.GetContainerItemInfo = function()
            return nil
        end
    end)

    it("returns 0 when bank is completely empty", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            local sizes = { [-1] = 28, [6] = 98 }
            return sizes[bag] or 0
        end
        assert.equals(0, LunarUI.GetLastOccupiedSlotID())
    end)

    it("returns correct slotID for items only in main bank", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            local sizes = { [-1] = 28 }
            return sizes[bag] or 0
        end
        _G.C_Container.GetContainerItemInfo = function(bag, slot)
            if bag == -1 and slot == 10 then
                return { iconFileID = 123 }
            end
            return nil
        end
        assert.equals(10, LunarUI.GetLastOccupiedSlotID())
    end)

    it("returns correct cumulative slotID for items in bank bags", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            local sizes = { [-1] = 28, [6] = 98 }
            return sizes[bag] or 0
        end
        _G.C_Container.GetContainerItemInfo = function(bag, slot)
            -- 物品在 bag 6 的第 5 格 → 累計 slotID = 28 + 5 = 33
            if bag == 6 and slot == 5 then
                return { iconFileID = 456 }
            end
            return nil
        end
        assert.equals(33, LunarUI.GetLastOccupiedSlotID())
    end)

    it("returns last item across multiple containers", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            local sizes = { [-1] = 28, [6] = 98, [7] = 98 }
            return sizes[bag] or 0
        end
        _G.C_Container.GetContainerItemInfo = function(bag, slot)
            -- 主銀行第 1 格有物品
            if bag == -1 and slot == 1 then
                return { iconFileID = 100 }
            end
            -- bag 7 第 3 格有物品 → 累計 slotID = 28 + 98 + 3 = 129
            if bag == 7 and slot == 3 then
                return { iconFileID = 200 }
            end
            return nil
        end
        assert.equals(129, LunarUI.GetLastOccupiedSlotID())
    end)

    it("handles item in last slot of last bag", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            local sizes = { [-1] = 28, [6] = 98, [7] = 98, [8] = 98, [9] = 98, [10] = 98, [11] = 98 }
            return sizes[bag] or 0
        end
        _G.C_Container.GetContainerItemInfo = function(bag, slot)
            -- 最後一格 bag 11 slot 98 → 累計 slotID = 28 + 6*98 = 616
            if bag == 11 and slot == 98 then
                return { iconFileID = 999 }
            end
            return nil
        end
        assert.equals(616, LunarUI.GetLastOccupiedSlotID())
    end)

    it("excludes bag 5 items (reagent bag in WoW 12.0)", function()
        _G.C_Container.GetContainerNumSlots = function(bag)
            local sizes = { [-1] = 28, [5] = 98, [6] = 32 }
            return sizes[bag] or 0
        end
        _G.C_Container.GetContainerItemInfo = function(bag, slot)
            -- bag 5 的物品不應被計入
            if bag == 5 and slot == 1 then
                return { iconFileID = 999 }
            end
            if bag == 6 and slot == 5 then
                return { iconFileID = 456 }
            end
            return nil
        end
        -- 應為 28 + 5 = 33（排除 bag 5），非 28 + 98 + 5 = 131
        assert.equals(33, LunarUI.GetLastOccupiedSlotID())
    end)
end)
