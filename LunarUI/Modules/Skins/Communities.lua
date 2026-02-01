---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Communities (Guild & Communities)
    Reskin CommunitiesFrame with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinCommunities()
    local frame = _G.CommunitiesFrame
    if not frame then return end

    -- Main frame
    LunarUI:SkinFrame(frame)

    -- Close button
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
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
        if messageFrame and messageFrame.ScrollBar then
            LunarUI.StripTextures(messageFrame.ScrollBar)
        end
    end

    -- Chat edit box
    if frame.ChatEditBox then
        LunarUI:SkinEditBox(frame.ChatEditBox)
    end

    -- Invite button
    if frame.InviteButton then
        LunarUI:SkinButton(frame.InviteButton)
    end

    -- Community list (left sidebar)
    if frame.CommunitiesList then
        LunarUI.StripTextures(frame.CommunitiesList)
        -- Inset
        if frame.CommunitiesList.InsetFrame then
            LunarUI.StripTextures(frame.CommunitiesList.InsetFrame)
        end
    end

    -- Guild member detail frame
    if frame.GuildMemberDetailFrame then
        LunarUI:SkinFrame(frame.GuildMemberDetailFrame)
        if frame.GuildMemberDetailFrame.CloseButton then
            LunarUI:SkinCloseButton(frame.GuildMemberDetailFrame.CloseButton)
        end
    end

    -- Notification settings dialog
    if frame.NotificationSettingsDialog then
        LunarUI:SkinFrame(frame.NotificationSettingsDialog)
        if frame.NotificationSettingsDialog.CloseButton then
            LunarUI:SkinCloseButton(frame.NotificationSettingsDialog.CloseButton)
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

    -- Tabs within the frame
    if frame.Tabs then
        for _, tab in ipairs(frame.Tabs) do
            LunarUI:SkinTab(tab)
        end
    end
end

-- Communities is loaded on demand
LunarUI:RegisterSkin("communities", "Blizzard_Communities", SkinCommunities)
