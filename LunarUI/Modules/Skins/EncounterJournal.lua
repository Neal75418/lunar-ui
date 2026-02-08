---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Encounter Journal
    Reskin EncounterJournal (冒險指南) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinEncounterJournal()
    local frame = LunarUI:SkinStandardFrame("EncounterJournal")
    if not frame then return end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.EncounterJournalCloseButton then
        LunarUI:SkinCloseButton(_G.EncounterJournalCloseButton)
    end

    -- 搜尋框
    if frame.SearchBox then
        LunarUI.StripTextures(frame.SearchBox)
    end

    -- 導航欄
    if frame.NavBar then
        LunarUI.StripTextures(frame.NavBar)
        if frame.NavBar.homeButton then
            LunarUI:SkinButton(frame.NavBar.homeButton)
        end
    end

    -- 副本列表面板
    if frame.instanceSelect then
        LunarUI.StripTextures(frame.instanceSelect)

        -- 分頁（地城/團隊）
        if frame.instanceSelect.dungeonsTab then
            LunarUI:SkinTab(frame.instanceSelect.dungeonsTab)
        end
        if frame.instanceSelect.raidsTab then
            LunarUI:SkinTab(frame.instanceSelect.raidsTab)
        end
        if frame.instanceSelect.suggestTab then
            LunarUI:SkinTab(frame.instanceSelect.suggestTab)
        end
        if frame.instanceSelect.LootJournalTab then
            LunarUI:SkinTab(frame.instanceSelect.LootJournalTab)
        end
    end

    -- 首領詳細資訊面板
    if frame.encounter then
        LunarUI.StripTextures(frame.encounter)

        if frame.encounter.info then
            LunarUI.StripTextures(frame.encounter.info)

            -- 難度下拉選單
            if frame.encounter.info.difficulty then
                LunarUI:SkinButton(frame.encounter.info.difficulty)
            end

            -- 分頁（概覽/技能/戰利品）
            if frame.encounter.info.overviewTab then
                LunarUI:SkinTab(frame.encounter.info.overviewTab)
            end
            if frame.encounter.info.bossTab then
                LunarUI:SkinTab(frame.encounter.info.bossTab)
            end
            if frame.encounter.info.lootTab then
                LunarUI:SkinTab(frame.encounter.info.lootTab)
            end
            if frame.encounter.info.modelTab then
                LunarUI:SkinTab(frame.encounter.info.modelTab)
            end
        end
    end
    return true
end

-- EncounterJournal 透過 Blizzard_EncounterJournal 載入
LunarUI:RegisterSkin("encounterjournal", "Blizzard_EncounterJournal", SkinEncounterJournal)
