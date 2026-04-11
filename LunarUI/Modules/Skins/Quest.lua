---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch
--[[
    LunarUI - Skin: Quest Log / Quest Map
    Reskin QuestMapFrame (任務日誌) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- QuestFrame（NPC 任務對話框）— 保留羊皮紙原始風格
-- 在 PLAYER_ENTERING_WORLD 時已存在，獨立於 Blizzard_QuestLog
local function SkinQuest()
    if not _G.QuestFrame then
        return
    end
    LunarUI:SkinFrame(_G.QuestFrame, { noStrip = true, fixText = false })
    return true
end

-- QuestMapFrame（任務地圖/日誌）+ QuestLogFrame
-- 透過 Blizzard_QuestLog LoD addon 載入，需獨立觸發以免被 quest skin 提早標記成功
-- 跟隨 "quest" toggle：若使用者停用 quest skin，此 skin 也不套用
local function SkinQuestMap()
    local skinsDB = LunarUI.GetModuleDB("skins")
    if skinsDB and skinsDB.blizzard and skinsDB.blizzard.quest == false then
        return true -- 視為已處理（不重試），跟隨 quest toggle 的停用
    end
    local frame = _G.QuestMapFrame
    if not frame then
        return
    end

    if frame.DetailsFrame then
        LunarUI.StripTextures(frame.DetailsFrame)
        LunarUI:SkinFrameText(frame.DetailsFrame, 3)

        if frame.DetailsFrame.CompleteQuestFrame then
            local completeBtn = frame.DetailsFrame.CompleteQuestFrame.CompleteButton
            if completeBtn then
                LunarUI.SkinButton(completeBtn)
            end
        end

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

    LunarUI:SkinStandardFrame("QuestLogFrame")
    return true
end

-- QuestFrame 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI.RegisterSkin("quest", "PLAYER_ENTERING_WORLD", SkinQuest)
-- QuestMapFrame 透過 Blizzard_QuestLog 載入後觸發；跟隨 "quest" toggle 的啟用狀態
LunarUI.RegisterSkin("questmap", "Blizzard_QuestLog", SkinQuestMap)
