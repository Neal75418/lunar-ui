---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Spellbook / Player Spells Frame
    Reskin SpellBookFrame / PlayerSpellsFrame with LunarUI theme
    WoW 12.0 uses PlayerSpellsFrame (new talent/spellbook combo)
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinSpellbook()
    -- WoW 12.0: PlayerSpellsFrame（合併法術書+天賦）
    local frame = PlayerSpellsFrame or SpellBookFrame
    if not frame then return end

    LunarUI:SkinFrame(frame)

    -- 關閉按鈕
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
    end

    -- 分頁
    if frame.TabSystem and frame.TabSystem.tabs then
        for _, tab in ipairs(frame.TabSystem.tabs) do
            if tab then
                LunarUI:SkinTab(tab)
            end
        end
    end

    -- 舊版法術書分頁（WoW < 12.0 備用）
    for i = 1, 8 do
        local tab = _G["SpellBookFrameTabButton" .. i]
        if tab then
            LunarUI:SkinTab(tab)
        end
    end

    -- SpellBook 頁面按鈕
    for i = 1, 2 do
        local prev = _G["SpellBookPrevPageButton" .. i] or _G["SpellBookPrevPageButton"]
        local next = _G["SpellBookNextPageButton" .. i] or _G["SpellBookNextPageButton"]
        if prev then LunarUI:SkinButton(prev) end
        if next then LunarUI:SkinButton(next) end
    end
end

-- PlayerSpellsFrame 透過 ADDON_LOADED "Blizzard_PlayerSpells" 載入
LunarUI:RegisterSkin("spellbook", "Blizzard_PlayerSpells", SkinSpellbook)
