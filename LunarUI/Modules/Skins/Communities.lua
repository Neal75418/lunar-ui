---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - Skin: Communities (Guild & Communities)
    Reskin CommunitiesFrame with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinCommunities()
    local frame = LunarUI:SkinStandardFrame("CommunitiesFrame", {
        tabProperty = "Tabs",
    })
    if not frame then
        return
    end

    -- Portrait and top-level decorations
    if frame.PortraitOverlay then
        frame.PortraitOverlay:SetAlpha(0)
    end

    -- Member list
    if frame.MemberList then
        LunarUI.StripTextures(frame.MemberList)
        if frame.MemberList.ColumnDisplay then
            LunarUI.StripTextures(frame.MemberList.ColumnDisplay)
        end
    end

    -- Chat area
    if frame.Chat then
        LunarUI.StripTextures(frame.Chat)
        local messageFrame = frame.Chat.MessageFrame
        if messageFrame then
            if messageFrame.ScrollBar then
                LunarUI.StripTextures(messageFrame.ScrollBar)
            end
            if messageFrame.ScrollBox then
                LunarUI.StripTextures(messageFrame.ScrollBox)
            end
        end
    end

    -- Chat edit box
    if frame.ChatEditBox then
        LunarUI.SkinEditBox(frame.ChatEditBox)
        -- StripTextures 移除了撐高度的材質，明確設定高度
        frame.ChatEditBox:SetHeight(22)
    end

    -- 底部按鈕統一 skin
    if frame.InviteButton then
        LunarUI.SkinButton(frame.InviteButton)
    end
    -- 公會招募按鈕（WoW 12.0 CommunitiesFrame.GuildFinderButton 或 CommunitiesControlFrame 內）
    if frame.GuildFinderButton then
        LunarUI.SkinButton(frame.GuildFinderButton)
    end
    if frame.CommunitiesControlFrame then
        if frame.CommunitiesControlFrame.GuildFinderButton then
            LunarUI.SkinButton(frame.CommunitiesControlFrame.GuildFinderButton)
        end
        if frame.CommunitiesControlFrame.GuildRecruitmentButton then
            LunarUI.SkinButton(frame.CommunitiesControlFrame.GuildRecruitmentButton)
        end
        if frame.CommunitiesControlFrame.CommunitiesSettingsButton then
            LunarUI.SkinButton(frame.CommunitiesControlFrame.CommunitiesSettingsButton)
        end
    end

    -- Community list (left sidebar)
    if frame.CommunitiesList then
        LunarUI.StripTextures(frame.CommunitiesList)
        if frame.CommunitiesList.InsetFrame then
            LunarUI.StripTextures(frame.CommunitiesList.InsetFrame)
        end
        -- 左側列表背景統一
        if frame.CommunitiesList.FilligreeOverlay then
            frame.CommunitiesList.FilligreeOverlay:Hide()
        end
        if frame.CommunitiesList.Delimiter then
            frame.CommunitiesList.Delimiter:Hide()
        end
        if frame.CommunitiesList.DecorationOverlay then
            frame.CommunitiesList.DecorationOverlay:Hide()
        end
    end

    -- 主內容區 Inset（減少中間聊天區與左側卡片的對比感）
    if frame.InsetFrame then
        LunarUI.StripTextures(frame.InsetFrame)
    end

    -- 右上角功能按鈕區（減少擁擠感）
    if frame.StreamDropDownMenu then
        LunarUI.StripTextures(frame.StreamDropDownMenu)
    end

    -- Guild member detail frame
    if frame.GuildMemberDetailFrame then
        LunarUI:SkinFrame(frame.GuildMemberDetailFrame)
        if frame.GuildMemberDetailFrame.CloseButton then
            LunarUI.SkinCloseButton(frame.GuildMemberDetailFrame.CloseButton)
        end
    end

    -- Notification settings dialog
    if frame.NotificationSettingsDialog then
        LunarUI:SkinFrame(frame.NotificationSettingsDialog)
        if frame.NotificationSettingsDialog.CloseButton then
            LunarUI.SkinCloseButton(frame.NotificationSettingsDialog.CloseButton)
        end
    end

    -- Guild benefits frame
    if frame.GuildBenefitsFrame then
        LunarUI.StripTextures(frame.GuildBenefitsFrame)
    end

    -- Guild info frame
    if frame.GuildDetailsFrame then
        LunarUI.StripTextures(frame.GuildDetailsFrame)
    end

    -- Guild rewards
    if frame.GuildBenefitsFrame and frame.GuildBenefitsFrame.Rewards then
        LunarUI.StripTextures(frame.GuildBenefitsFrame.Rewards)
    end

    return true
end

-- Communities is loaded on demand
LunarUI.RegisterSkin("communities", "Blizzard_Communities", SkinCommunities)
