---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: PVP Frame
    Reskin PVPUIFrame (PVP 面板) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinPVPFrame()
    local frame = LunarUI:SkinStandardFrame("PVPUIFrame", {
        tabPrefix = "PVPUIFrameTab", tabCount = 3,
        textDepth = 3,
    })
    if not frame then return end

    -- 榮譽面板
    if _G.HonorFrame then
        LunarUI.StripTextures(_G.HonorFrame)
        LunarUI:SkinFrameText(_G.HonorFrame, 2)

        if _G.HonorFrame.QueueButton then
            LunarUI.SkinButton(_G.HonorFrame.QueueButton)
        end
    end

    -- 征服面板
    if _G.ConquestFrame then
        LunarUI.StripTextures(_G.ConquestFrame)
        LunarUI:SkinFrameText(_G.ConquestFrame, 2)

        if _G.ConquestFrame.JoinButton then
            LunarUI.SkinButton(_G.ConquestFrame.JoinButton)
        end
    end

    -- 戰場得分面板
    if _G.PVPMatchScoreboard then
        LunarUI:SkinStandardFrame("PVPMatchScoreboard", {
            textDepth = 2,
        })
    end

    return true
end

-- PVP UI 為延遲載入 addon
LunarUI.RegisterSkin("pvp", "Blizzard_PVPUI", SkinPVPFrame)
