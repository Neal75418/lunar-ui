---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: LFG / PVE Frame
    Reskin PVEFrame (地城查找/團隊查找/PvP) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinLFG()
    local frame = PVEFrame
    if not frame then return end

    -- 主框架背景（啟用文字修復）
    LunarUI:SkinFrame(frame, { textDepth = 3 })

    -- 標題文字
    if frame.TitleText then
        LunarUI:SetFontLight(frame.TitleText)
    end

    -- 關閉按鈕
    if frame.CloseButton then
        LunarUI:SkinCloseButton(frame.CloseButton)
    elseif _G.PVEFrameCloseButton then
        LunarUI:SkinCloseButton(_G.PVEFrameCloseButton)
    end

    -- 分頁（地城/團隊/PvP）
    for i = 1, 4 do
        local tab = _G["PVEFrameTab" .. i]
        if tab then
            LunarUI:SkinTab(tab)
            if tab.Text then
                LunarUI:SetFontLight(tab.Text)
            end
        end
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
