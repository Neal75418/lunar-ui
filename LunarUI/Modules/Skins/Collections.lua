---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Collections Journal
    Reskin CollectionsJournal (收藏介面) with LunarUI theme
    Covers: Mounts, Pets, Toys, Heirlooms, Appearances
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinCollections()
    local frame = LunarUI:SkinStandardFrame("CollectionsJournal", {
        tabPrefix = "CollectionsJournalTab", tabCount = 5,
    })
    if not frame then return end

    -- 坐騎日誌
    if _G.MountJournal then
        LunarUI.StripTextures(_G.MountJournal)

        if _G.MountJournalMountButton then
            LunarUI.SkinButton(_G.MountJournalMountButton)
        end
        if _G.MountJournal.SearchBox then
            LunarUI.StripTextures(_G.MountJournal.SearchBox)
        end
    end

    -- 寵物日誌
    if _G.PetJournal then
        LunarUI.StripTextures(_G.PetJournal)

        if _G.PetJournalSummonButton then
            LunarUI.SkinButton(_G.PetJournalSummonButton)
        end
        if _G.PetJournalFindBattleButton then
            LunarUI.SkinButton(_G.PetJournalFindBattleButton)
        end
        if _G.PetJournal.SearchBox then
            LunarUI.StripTextures(_G.PetJournal.SearchBox)
        end
    end

    -- 玩具盒
    if _G.ToyBox then
        LunarUI.StripTextures(_G.ToyBox)

        if _G.ToyBox.SearchBox then
            LunarUI.StripTextures(_G.ToyBox.SearchBox)
        end
    end

    -- 傳家寶
    if _G.HeirloomsJournal then
        LunarUI.StripTextures(_G.HeirloomsJournal)

        if _G.HeirloomsJournal.SearchBox then
            LunarUI.StripTextures(_G.HeirloomsJournal.SearchBox)
        end
    end

    -- 幻化衣櫥
    if _G.WardrobeCollectionFrame then
        LunarUI.StripTextures(_G.WardrobeCollectionFrame)

        if _G.WardrobeCollectionFrame.SearchBox then
            LunarUI.StripTextures(_G.WardrobeCollectionFrame.SearchBox)
        end
    end
    return true
end

-- CollectionsJournal 透過 Blizzard_Collections 載入
LunarUI.RegisterSkin("collections", "Blizzard_Collections", SkinCollections)
