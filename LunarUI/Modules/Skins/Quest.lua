---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Quest Log / Quest Map
    Reskin QuestMapFrame (任務日誌) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinQuest()
    -- QuestMapFrame（任務地圖/日誌 — 嵌在世界地圖中）
    local frame = QuestMapFrame
    if not frame then return end

    -- QuestMapFrame 本身是子框架，skin 其細節面板
    if frame.DetailsFrame then
        LunarUI.StripTextures(frame.DetailsFrame)
        LunarUI:SkinFrameText(frame.DetailsFrame, 3)

        -- 完成按鈕
        if frame.DetailsFrame.CompleteQuestFrame then
            local completeBtn = frame.DetailsFrame.CompleteQuestFrame.CompleteButton
            if completeBtn then
                LunarUI:SkinButton(completeBtn)
            end
        end

        -- 放棄/分享按鈕
        if frame.DetailsFrame.AbandonButton then
            LunarUI:SkinButton(frame.DetailsFrame.AbandonButton)
        end
        if frame.DetailsFrame.ShareButton then
            LunarUI:SkinButton(frame.DetailsFrame.ShareButton)
        end
        if frame.DetailsFrame.TrackButton then
            LunarUI:SkinButton(frame.DetailsFrame.TrackButton)
        end
    end

    -- QuestLogFrame（獨立任務日誌，若存在）
    local questLog = QuestLogFrame
    if questLog then
        LunarUI:SkinFrame(questLog, { textDepth = 3 })
        if questLog.CloseButton then
            LunarUI:SkinCloseButton(questLog.CloseButton)
        end
    end

    -- QuestFrame（NPC 任務對話框）— 這是最重要的任務框架
    local questFrame = QuestFrame
    if questFrame then
        LunarUI:SkinFrame(questFrame, { textDepth = 4 })

        -- 標題文字
        if questFrame.TitleText then
            LunarUI:SetFontLight(questFrame.TitleText)
        elseif _G.QuestFrameTitleText then
            LunarUI:SetFontLight(_G.QuestFrameTitleText)
        end

        if questFrame.CloseButton then
            LunarUI:SkinCloseButton(questFrame.CloseButton)
        elseif _G.QuestFrameCloseButton then
            LunarUI:SkinCloseButton(_G.QuestFrameCloseButton)
        end

        -- 接受/完成按鈕
        if _G.QuestFrameAcceptButton then
            LunarUI:SkinButton(_G.QuestFrameAcceptButton)
        end
        if _G.QuestFrameDeclineButton then
            LunarUI:SkinButton(_G.QuestFrameDeclineButton)
        end
        if _G.QuestFrameCompleteButton then
            LunarUI:SkinButton(_G.QuestFrameCompleteButton)
        end
        if _G.QuestFrameCompleteQuestButton then
            LunarUI:SkinButton(_G.QuestFrameCompleteQuestButton)
        end
        if _G.QuestFrameGoodbyeButton then
            LunarUI:SkinButton(_G.QuestFrameGoodbyeButton)
        end

        -- 任務描述文字（重要！）
        if _G.QuestInfoDescriptionText then
            LunarUI:SetFontLight(_G.QuestInfoDescriptionText)
        end
        if _G.QuestInfoObjectivesText then
            LunarUI:SetFontLight(_G.QuestInfoObjectivesText)
        end
        if _G.QuestInfoRewardText then
            LunarUI:SetFontLight(_G.QuestInfoRewardText)
        end

        -- 任務標題
        if _G.QuestInfoTitleHeader then
            LunarUI:SetFontLight(_G.QuestInfoTitleHeader)
        end
        if _G.QuestInfoObjectivesHeader then
            LunarUI:SetFontLight(_G.QuestInfoObjectivesHeader)
        end
        if _G.QuestInfoRewardsFrame then
            LunarUI:SkinFrameText(_G.QuestInfoRewardsFrame, 2)
        end

        -- 進度框架
        if _G.QuestProgressTitleText then
            LunarUI:SetFontLight(_G.QuestProgressTitleText)
        end
        if _G.QuestProgressText then
            LunarUI:SetFontLight(_G.QuestProgressText)
        end
        if _G.QuestProgressRequiredItemsText then
            LunarUI:SetFontLight(_G.QuestProgressRequiredItemsText)
        end
    end
end

-- QuestFrame 在 PLAYER_ENTERING_WORLD 時已存在
-- QuestMapFrame 透過 Blizzard_QuestLog 載入
LunarUI:RegisterSkin("quest", "PLAYER_ENTERING_WORLD", SkinQuest)
