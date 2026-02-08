---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Mail Frame
    Reskin MailFrame (郵件介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinMail()
    local frame = LunarUI:SkinStandardFrame("MailFrame", {
        tabPrefix = "MailFrameTab", tabCount = 2,
    })
    if not frame then return end

    -- 標題文字 fallback
    if not frame.TitleText and _G.MailFrameTitleText then
        LunarUI:SetFontLight(_G.MailFrameTitleText)
    end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.MailFrameCloseButton then
        LunarUI:SkinCloseButton(_G.MailFrameCloseButton)
    end

    -- 收件匣面板
    if _G.InboxFrame then
        LunarUI.StripTextures(_G.InboxFrame)
        LunarUI:SkinFrameText(_G.InboxFrame, 2)
    end

    -- 信件按鈕
    for i = 1, 7 do
        local btn = _G["MailItem" .. i .. "Button"]
        if btn then
            LunarUI.StripTextures(btn)
        end
        -- 信件標題/寄件人文字
        local sender = _G["MailItem" .. i .. "Sender"]
        local subject = _G["MailItem" .. i .. "Subject"]
        if sender then LunarUI:SetFontLight(sender) end
        if subject then LunarUI:SetFontLight(subject) end
    end

    -- 翻頁按鈕
    if _G.InboxPrevPageButton then
        LunarUI:SkinButton(_G.InboxPrevPageButton)
    end
    if _G.InboxNextPageButton then
        LunarUI:SkinButton(_G.InboxNextPageButton)
    end

    -- 撰寫面板
    if _G.SendMailFrame then
        LunarUI.StripTextures(_G.SendMailFrame)
    end

    -- 撰寫按鈕
    if _G.SendMailMailButton then
        LunarUI:SkinButton(_G.SendMailMailButton)
    end
    if _G.SendMailCancelButton then
        LunarUI:SkinButton(_G.SendMailCancelButton)
    end

    -- 開信面板
    if _G.OpenMailFrame then
        LunarUI:SkinFrame(_G.OpenMailFrame)

        if _G.OpenMailFrameCloseButton then
            LunarUI:SkinCloseButton(_G.OpenMailFrameCloseButton)
        end
        if _G.OpenMailReplyButton then
            LunarUI:SkinButton(_G.OpenMailReplyButton)
        end
        if _G.OpenMailDeleteButton then
            LunarUI:SkinButton(_G.OpenMailDeleteButton)
        end
        if _G.OpenMailReportSpamButton then
            LunarUI:SkinButton(_G.OpenMailReportSpamButton)
        end
        if _G.OpenMailCancelButton then
            LunarUI:SkinButton(_G.OpenMailCancelButton)
        end
    end
    return true
end

-- MailFrame 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI:RegisterSkin("mail", "PLAYER_ENTERING_WORLD", SkinMail)
