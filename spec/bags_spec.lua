--[[
    Unit tests for Bags module pure functions
    Tests: GetItemLevel, IsEquipment, IsItemUpgrade, GetBagTypeColor, GetBankSlotsPerRow
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

loader.loadAddonFile("LunarUI/Modules/Bags.lua", LunarUI)

--------------------------------------------------------------------------------
-- GetItemLevel (Bags)
--------------------------------------------------------------------------------

describe("BagsGetItemLevel", function()
    before_each(function()
        -- Reset C_Item mock for each test
        _G.C_Item.GetDetailedItemLevelInfo = function()
            return nil
        end
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

    -- equippedIlvlDirty 是內部單次消耗狀態，首次 RefreshEquippedItemLevels 後
    -- 就不會再刷新。此測試放最後：觸發唯一的 dirty refresh，所有槽位為空→升級。
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
end)
