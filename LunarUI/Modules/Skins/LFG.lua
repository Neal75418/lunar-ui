---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: LFG / PVE Frame
    Reskin PVEFrame (地城查找/團隊查找/PvP) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinLFG()
    local frame = LunarUI:SkinStandardFrame("PVEFrame", {
        tabPrefix = "PVEFrameTab", tabCount = 4,
    })
    if not frame then return end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.PVEFrameCloseButton then
        LunarUI:SkinCloseButton(_G.PVEFrameCloseButton)
    end

    -- LFDParentFrame（地城查找）
    if _G.LFDParentFrame then
        LunarUI.StripTextures(_G.LFDParentFrame)
    end

    -- 地城查找佇列按鈕
    if _G.LFDQueueFrameFindGroupButton then
        LunarUI:SkinButton(_G.LFDQueueFrameFindGroupButton)
    end

    -- LFRBrowseFrame（團隊查找）
    if _G.LFRBrowseFrame then
        LunarUI.StripTextures(_G.LFRBrowseFrame)
    end

    -- RaidFinderFrame（團隊查找器）
    if _G.RaidFinderFrame then
        LunarUI.StripTextures(_G.RaidFinderFrame)

        if _G.RaidFinderFrameFindRaidButton then
            LunarUI:SkinButton(_G.RaidFinderFrameFindRaidButton)
        end
    end

    -- ScenarioQueueFrame（事件佇列）
    if _G.ScenarioQueueFrame then
        LunarUI.StripTextures(_G.ScenarioQueueFrame)
    end

    -- LFGListFrame（預組隊伍）
    if _G.LFGListFrame then
        LunarUI.StripTextures(_G.LFGListFrame)

        -- 搜尋面板
        if _G.LFGListFrame.SearchPanel then
            LunarUI.StripTextures(_G.LFGListFrame.SearchPanel)

            if _G.LFGListFrame.SearchPanel.SearchBox then
                LunarUI.StripTextures(_G.LFGListFrame.SearchPanel.SearchBox)
            end
            if _G.LFGListFrame.SearchPanel.SignUpButton then
                LunarUI:SkinButton(_G.LFGListFrame.SearchPanel.SignUpButton)
            end
            if _G.LFGListFrame.SearchPanel.BackButton then
                LunarUI:SkinButton(_G.LFGListFrame.SearchPanel.BackButton)
            end
        end

        -- 申請面板
        if _G.LFGListFrame.ApplicationViewer then
            LunarUI.StripTextures(_G.LFGListFrame.ApplicationViewer)
        end
    end
end

-- PVEFrame 透過 Blizzard_GroupFinder 載入
LunarUI:RegisterSkin("lfg", "Blizzard_GroupFinder", SkinLFG)
