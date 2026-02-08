---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Talents Frame
    Reskin ClassTalentFrame with LunarUI theme
    WoW 12.0 integrates talents into PlayerSpellsFrame
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinTalents()
    -- WoW 12.0: 天賦已整合至 PlayerSpellsFrame，分頁之一
    -- 若 PlayerSpellsFrame 存在，則天賦 skin 由 Spellbook.lua 處理
    -- 此檔案處理獨立的 ClassTalentFrame（若存在）
    local frame = LunarUI:SkinStandardFrame("ClassTalentFrame", {
        useTabSystem = true,
    })
    if not frame then return end

    -- 底部按鈕（套用/重設）
    if frame.ApplyButton then
        LunarUI:SkinButton(frame.ApplyButton)
    end
    if frame.UndoButton then
        LunarUI:SkinButton(frame.UndoButton)
    end
    return true
end

-- ClassTalentFrame 透過 ADDON_LOADED "Blizzard_ClassTalentUI" 載入
LunarUI:RegisterSkin("talents", "Blizzard_ClassTalentUI", SkinTalents)
