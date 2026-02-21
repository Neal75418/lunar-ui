---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Mail Frame
    Reskin MailFrame (郵件介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinMail()
    local frame = LunarUI:SkinStandardFrame("MailFrame", {
        noStrip = true, -- 保留原始背景材質，避免黑底蓋住內容
        -- 不傳 tabPrefix：保留原始標籤外觀，避免 SkinTab 導致透明背景
    })
    if not frame then
        return
    end

    -- 標題文字 fallback
    if not frame.TitleText and _G.MailFrameTitleText then
        LunarUI.SetFontLight(_G.MailFrameTitleText)
    end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.MailFrameCloseButton then
        LunarUI.SkinCloseButton(_G.MailFrameCloseButton)
    end

    -- 收件匣面板（保留原始背景材質，避免黑底蓋住內容）
    if _G.InboxFrame then
        LunarUI:SkinFrameText(_G.InboxFrame, 2)
    end

    -- 信件按鈕（不 StripTextures，保留信件圖示）
    for i = 1, 7 do
        local sender = _G["MailItem" .. i .. "Sender"]
        local subject = _G["MailItem" .. i .. "Subject"]
        if sender then
            LunarUI.SetFontLight(sender)
        end
        if subject then
            LunarUI.SetFontLight(subject)
        end
    end

    -- 翻頁按鈕（保留原始箭頭圖示，不套用 SkinButton 避免變成灰色方塊）

    -- 撰寫面板（保留原始背景材質）
    if _G.SendMailFrame then
        LunarUI:SkinFrameText(_G.SendMailFrame, 2)
    end

    -- 撰寫按鈕（noStrip 模式：保留原始外觀，不套用 SkinButton）

    -- 開信面板（保留信件內容背景，僅隱藏邊框裝飾）
    if _G.OpenMailFrame then
        if _G.OpenMailFrame.NineSlice then
            _G.OpenMailFrame.NineSlice:SetAlpha(0)
        end
        LunarUI:SkinFrameText(_G.OpenMailFrame, 2)

        if _G.OpenMailFrameCloseButton then
            LunarUI.SkinCloseButton(_G.OpenMailFrameCloseButton)
        end
        -- 操作按鈕（noStrip 模式：保留原始外觀，不套用 SkinButton）
    end
    return true
end

-- MailFrame 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI.RegisterSkin("mail", "PLAYER_ENTERING_WORLD", SkinMail)
