---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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
    if not frame then return end

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

    return true
end

-- Communities is loaded on demand
LunarUI:RegisterSkin("communities", "Blizzard_Communities", SkinCommunities)
