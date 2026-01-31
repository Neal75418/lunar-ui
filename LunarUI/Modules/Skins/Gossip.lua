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

    -- 主框架背景
    LunarUI:SkinFrame(frame)

    -- 關閉按鈕
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
    elseif _G.GossipFrameCloseButton then
        LunarUI:SkinCloseButton(_G.GossipFrameCloseButton)
    end

    -- Greeting 面板
    if frame.GreetingPanel then
        LunarUI.StripTextures(frame.GreetingPanel)

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
end

-- GossipFrame 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI:RegisterSkin("gossip", "PLAYER_ENTERING_WORLD", SkinGossip)
