---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, unused-local
--[[
    LunarUI - Skin: Weekly Rewards (Great Vault)
    Reskin WeeklyRewardsFrame (每週寶庫) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinWeeklyRewards()
    local frame = LunarUI:SkinStandardFrame("WeeklyRewardsFrame")
    if not frame then
        return
    end

    -- 選擇獎勵按鈕
    if frame.SelectRewardButton then
        LunarUI.SkinButton(frame.SelectRewardButton)
    end

    -- 確認對話框
    if frame.ConcessionFrame then
        local concession = frame.ConcessionFrame
        if concession.AcceptButton then
            LunarUI.SkinButton(concession.AcceptButton)
        end
        if concession.CancelButton then
            LunarUI.SkinButton(concession.CancelButton)
        end
    end

    return true
end

-- WeeklyRewardsFrame 透過 Blizzard_WeeklyRewards 載入
LunarUI.RegisterSkin("weeklyrewards", "Blizzard_WeeklyRewards", SkinWeeklyRewards)
