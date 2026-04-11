---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch
--[[
    LunarUI - Skin: Communities (Guild & Communities)
    Reskin CommunitiesFrame with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local mathMax = math.max
local C = LunarUI.Colors

-- 為子面板建立內嵌 backdrop（區分層次）
local function AddPanelBackdrop(panel)
    if not panel or panel._lunarPanelBG or panel._lunarSkinBG then
        return
    end
    panel._lunarPanelBG = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel._lunarPanelBG:SetAllPoints()
    panel._lunarPanelBG:SetFrameLevel(mathMax(panel:GetFrameLevel() - 1, 0))
    LunarUI.ApplyBackdrop(panel._lunarPanelBG, nil, C.bgIcon, C.borderSubtle)
end

local function SkinCommunities()
    local frame = LunarUI:SkinStandardFrame("CommunitiesFrame", {
        tabProperty = "Tabs",
    })
    if not frame then
        return
    end

    -- 頭像與頂層裝飾
    if frame.PortraitOverlay then
        frame.PortraitOverlay:SetAlpha(0)
    end

    -- 成員列表
    if frame.MemberList then
        LunarUI.StripTextures(frame.MemberList)
        AddPanelBackdrop(frame.MemberList)
        if frame.MemberList.ColumnDisplay then
            LunarUI.StripTextures(frame.MemberList.ColumnDisplay)
        end
        if frame.MemberList.ScrollBar then
            LunarUI.SkinScrollBar(frame.MemberList.ScrollBar)
        end
        -- 列表內的分隔線（ColumnDisplay header）
        if frame.MemberList.ColumnDisplay then
            local headerCount = select("#", frame.MemberList.ColumnDisplay:GetChildren())
            if headerCount > 0 then
                local headers = { frame.MemberList.ColumnDisplay:GetChildren() }
                for i = 1, headerCount do
                    if headers[i] then
                        LunarUI.StripTextures(headers[i])
                    end
                end
            end
        end
    end

    -- 聊天區域
    if frame.Chat then
        LunarUI.StripTextures(frame.Chat)
        AddPanelBackdrop(frame.Chat)
        local messageFrame = frame.Chat.MessageFrame
        if messageFrame then
            if messageFrame.ScrollBar then
                LunarUI.SkinScrollBar(messageFrame.ScrollBar)
            end
            if messageFrame.ScrollBox then
                LunarUI.StripTextures(messageFrame.ScrollBox)
                AddPanelBackdrop(messageFrame.ScrollBox)
            end
        end
    end

    -- 聊天輸入框
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

    -- 社群列表（左側欄）
    if frame.CommunitiesList then
        LunarUI.StripTextures(frame.CommunitiesList)
        AddPanelBackdrop(frame.CommunitiesList)
        if frame.CommunitiesList.InsetFrame then
            LunarUI.StripTextures(frame.CommunitiesList.InsetFrame)
        end
        if frame.CommunitiesList.ScrollBar then
            LunarUI.SkinScrollBar(frame.CommunitiesList.ScrollBar)
        end
        -- 左側列表裝飾
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

    -- 主內容區 Inset
    if frame.InsetFrame then
        LunarUI.StripTextures(frame.InsetFrame)
    end

    -- 右上角功能按鈕區
    if frame.StreamDropDownMenu then
        LunarUI.StripTextures(frame.StreamDropDownMenu)
    end

    -- 公會成員詳情框架
    if frame.GuildMemberDetailFrame then
        LunarUI:SkinFrame(frame.GuildMemberDetailFrame)
        if frame.GuildMemberDetailFrame.CloseButton then
            LunarUI.SkinCloseButton(frame.GuildMemberDetailFrame.CloseButton)
        end
    end

    -- 通知設定對話框
    if frame.NotificationSettingsDialog then
        LunarUI:SkinFrame(frame.NotificationSettingsDialog)
        if frame.NotificationSettingsDialog.CloseButton then
            LunarUI.SkinCloseButton(frame.NotificationSettingsDialog.CloseButton)
        end
    end

    -- 公會福利框架
    if frame.GuildBenefitsFrame then
        LunarUI.StripTextures(frame.GuildBenefitsFrame)
        AddPanelBackdrop(frame.GuildBenefitsFrame)
    end

    -- 公會資訊框架
    if frame.GuildDetailsFrame then
        LunarUI.StripTextures(frame.GuildDetailsFrame)
        AddPanelBackdrop(frame.GuildDetailsFrame)
    end

    -- 公會獎勵
    if frame.GuildBenefitsFrame and frame.GuildBenefitsFrame.Rewards then
        LunarUI.StripTextures(frame.GuildBenefitsFrame.Rewards)
    end

    return true
end

-- 社群為延遲載入
LunarUI.RegisterSkin("communities", "Blizzard_Communities", SkinCommunities)
