---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, unused-local
--[[
    LunarUI - Skin: LFG / PVE Frame
    Reskin PVEFrame (地城查找/團隊查找/PvP) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinLFG()
    local frame = LunarUI:SkinStandardFrame("PVEFrame", {
        tabPrefix = "PVEFrameTab",
        tabCount = 4,
    })
    if not frame then
        return
    end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.PVEFrameCloseButton then
        LunarUI.SkinCloseButton(_G.PVEFrameCloseButton)
    end

    -- LFDParentFrame（地城查找）
    if _G.LFDParentFrame then
        LunarUI.StripTextures(_G.LFDParentFrame)
    end

    -- 地城查找佇列按鈕
    if _G.LFDQueueFrameFindGroupButton then
        LunarUI.SkinButton(_G.LFDQueueFrameFindGroupButton)
    end

    -- LFRBrowseFrame（團隊查找）
    if _G.LFRBrowseFrame then
        LunarUI.StripTextures(_G.LFRBrowseFrame)
    end

    -- RaidFinderFrame（團隊查找器）
    if _G.RaidFinderFrame then
        LunarUI.StripTextures(_G.RaidFinderFrame)

        if _G.RaidFinderFrameFindRaidButton then
            LunarUI.SkinButton(_G.RaidFinderFrameFindRaidButton)
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
        local searchPanel = _G.LFGListFrame.SearchPanel
        if searchPanel then
            LunarUI.StripTextures(searchPanel)

            if searchPanel.SearchBox then
                LunarUI.StripTextures(searchPanel.SearchBox)
            end
            if searchPanel.SignUpButton then
                LunarUI.SkinButton(searchPanel.SignUpButton)
            end
            if searchPanel.BackButton then
                LunarUI.SkinButton(searchPanel.BackButton)
            end
        end

        -- 申請面板
        if _G.LFGListFrame.ApplicationViewer then
            LunarUI.StripTextures(_G.LFGListFrame.ApplicationViewer)
        end
    end
    return true
end

-- PVEFrame 透過 Blizzard_GroupFinder 載入
LunarUI.RegisterSkin("lfg", "Blizzard_GroupFinder", SkinLFG)
