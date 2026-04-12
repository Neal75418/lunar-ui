---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, unused-local
--[[
    LunarUI - Skin: PVP Frame
    Reskin PVPUIFrame (PVP 面板) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinPVPFrame()
    local frame = LunarUI:SkinStandardFrame("PVPUIFrame", {
        tabPrefix = "PVPUIFrameTab",
        tabCount = 3,
    })
    if not frame then
        return
    end

    -- 榮譽面板
    if _G.HonorFrame then
        if _G.HonorFrame.QueueButton then
            LunarUI.SkinButton(_G.HonorFrame.QueueButton)
        end
    end
    if _G.HonorFrameQueueButton then
        LunarUI.SkinButton(_G.HonorFrameQueueButton)
    end

    -- 征服面板
    if _G.ConquestFrame then
        if _G.ConquestFrame.JoinButton then
            LunarUI.SkinButton(_G.ConquestFrame.JoinButton)
        end
    end

    -- 戰場得分面板
    if _G.PVPMatchScoreboard then
        LunarUI:SkinStandardFrame("PVPMatchScoreboard")
    end

    -- 戰場結果面板
    if _G.PVPMatchResults then
        LunarUI:SkinStandardFrame("PVPMatchResults")
    end

    return true
end

-- PVP UI 為延遲載入 addon
LunarUI.RegisterSkin("pvp", "Blizzard_PVPUI", SkinPVPFrame)
