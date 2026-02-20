---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Quest Log / Quest Map
    Reskin QuestMapFrame (任務日誌) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinQuest()
    -- QuestMapFrame（任務地圖/日誌 — 嵌在世界地圖中）
    local frame = _G.QuestMapFrame
    if not frame then return end

    -- QuestMapFrame 本身是子框架，skin 其細節面板
    if frame.DetailsFrame then
        LunarUI.StripTextures(frame.DetailsFrame)
        LunarUI:SkinFrameText(frame.DetailsFrame, 3)

        -- 完成按鈕
        if frame.DetailsFrame.CompleteQuestFrame then
            local completeBtn = frame.DetailsFrame.CompleteQuestFrame.CompleteButton
            if completeBtn then
                LunarUI.SkinButton(completeBtn)
            end
        end

        -- 放棄/分享按鈕
        if frame.DetailsFrame.AbandonButton then
            LunarUI.SkinButton(frame.DetailsFrame.AbandonButton)
        end
        if frame.DetailsFrame.ShareButton then
            LunarUI.SkinButton(frame.DetailsFrame.ShareButton)
        end
        if frame.DetailsFrame.TrackButton then
            LunarUI.SkinButton(frame.DetailsFrame.TrackButton)
        end
    end

    -- QuestLogFrame（獨立任務日誌，若存在）
    LunarUI:SkinStandardFrame("QuestLogFrame")

    -- QuestFrame（NPC 任務對話框）— 保留羊皮紙原始風格
    -- 只隱藏 NineSlice 邊框並套用 LunarUI 外框，內容區域完全不動
    if _G.QuestFrame then
        LunarUI:SkinFrame(_G.QuestFrame, { noStrip = true, fixText = false })
    end
    return true
end

-- QuestFrame 在 PLAYER_ENTERING_WORLD 時已存在
-- QuestMapFrame 透過 Blizzard_QuestLog 載入
LunarUI.RegisterSkin("quest", "PLAYER_ENTERING_WORLD", SkinQuest)
