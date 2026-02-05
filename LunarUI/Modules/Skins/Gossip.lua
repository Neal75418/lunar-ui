---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Gossip Frame
    Reskin GossipFrame (NPC 對話介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinGossip()
    local frame = GossipFrame
    if not frame then return end

    -- 主框架背景（啟用文字修復，深度 4 以覆蓋對話選項）
    LunarUI:SkinFrame(frame, { textDepth = 4 })

    -- 標題文字
    if frame.TitleText then
        LunarUI:SetFontLight(frame.TitleText)
    elseif _G.GossipFrameTitleText then
        LunarUI:SetFontLight(_G.GossipFrameTitleText)
    end

    -- 關閉按鈕
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
    elseif _G.GossipFrameCloseButton then
        LunarUI:SkinCloseButton(_G.GossipFrameCloseButton)
    end

    -- Greeting 面板
    if frame.GreetingPanel then
        LunarUI.StripTextures(frame.GreetingPanel)
        LunarUI:SkinFrameText(frame.GreetingPanel, 3)

        -- 再見按鈕
        if frame.GreetingPanel.GoodbyeButton then
            LunarUI:SkinButton(frame.GreetingPanel.GoodbyeButton)
        end
    end

    -- 舊版再見按鈕
    if _G.GossipFrameGreetingGoodbyeButton then
        LunarUI:SkinButton(_G.GossipFrameGreetingGoodbyeButton)
    end

    -- NPC 模型區域背景
    if frame.FriendshipStatusBar then
        LunarUI.StripTextures(frame.FriendshipStatusBar)
    end

    -- 對話文字（重要！NPC 說的話）
    if _G.GossipGreetingText then
        LunarUI:SetFontLight(_G.GossipGreetingText)
    end

    -- 對話選項按鈕（WoW 12.0 使用 ScrollFrame）
    if frame.GreetingPanel and frame.GreetingPanel.ScrollBox then
        -- 對於每個對話選項，需要 hook 來處理動態內容
        hooksecurefunc(frame.GreetingPanel.ScrollBox, "Update", function(self)
            local n = select("#", self:GetChildren())
            if n > 0 then
                local children = { self:GetChildren() }
                for i = 1, n do
                    local child = children[i]
                    if child then
                        -- 確保選項文字可讀
                        LunarUI:SkinFrameText(child, 1)
                    end
                end
            end
        end)
    end
end

-- GossipFrame 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI:RegisterSkin("gossip", "PLAYER_ENTERING_WORLD", SkinGossip)
