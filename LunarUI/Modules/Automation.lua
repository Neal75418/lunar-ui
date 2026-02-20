---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 自動化 QoL 模組
    自動修裝、戰場自動釋放靈魂、成就截圖等便利功能
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 設定快取
--------------------------------------------------------------------------------

local function GetAutoConfig()
    if LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.automation then
        return LunarUI.db.profile.automation
    end
    return nil
end

--------------------------------------------------------------------------------
-- 自動修裝
--------------------------------------------------------------------------------

local autoRepairFrame = CreateFrame("Frame")

local function OnMerchantShow()
    local cfg = GetAutoConfig()
    if not cfg or not cfg.autoRepair then return end

    local L = Engine.L or {}
    local repairAllCost, canRepair = GetRepairAllCost()

    if canRepair and repairAllCost > 0 then
        -- 嘗試公會修理
        if cfg.useGuildRepair and IsInGuild() then
            local guildBankWithdraw = 0
            if _G.GetGuildBankWithdrawMoney then
                local ok, result = pcall(_G.GetGuildBankWithdrawMoney)
                if ok and result then guildBankWithdraw = result end
            end
            if guildBankWithdraw == -1 or guildBankWithdraw >= repairAllCost then
                RepairAllItems(true)  -- true = 使用公會資金
                local costStr = GetCoinTextureString(repairAllCost)
                LunarUI:Print(string.format(L["RepairCostGuild"] or "Repaired for %s (Guild Bank)", costStr))
                return
            end
        end

        -- 個人修理
        if GetMoney() >= repairAllCost then
            RepairAllItems(false)
            local costStr = GetCoinTextureString(repairAllCost)
            LunarUI:Print(string.format(L["RepairCost"] or "Repaired for %s", costStr))
        else
            LunarUI:Print(L["RepairNoFunds"] or "Not enough gold to repair")
        end
    end
end

--------------------------------------------------------------------------------
-- 戰場自動釋放靈魂
--------------------------------------------------------------------------------

local autoReleaseFrame = CreateFrame("Frame")

local function OnPlayerDead()
    local cfg = GetAutoConfig()
    if not cfg or not cfg.autoRelease then return end

    -- 僅在戰場中自動釋放
    local instanceType = select(2, IsInInstance())
    if instanceType == "pvp" then
        -- 延遲一小段時間再釋放（避免復活技能衝突）
        C_Timer.After(0.3, function()
            if UnitIsDeadOrGhost("player") and not UnitIsFeignDeath("player") then
                RepopMe()
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- 成就截圖
--------------------------------------------------------------------------------

local achievementFrame = CreateFrame("Frame")

local function OnAchievementEarned(_self, _event)
    local cfg = GetAutoConfig()
    if not cfg or not cfg.autoScreenshot then return end

    -- 延遲截圖讓成就提示先顯示
    C_Timer.After(1, function()
        Screenshot()
    end)
end

--------------------------------------------------------------------------------
-- 自動接受/繳交任務
--------------------------------------------------------------------------------

local autoQuestFrame = CreateFrame("Frame")

local function OnQuestDetail()
    local cfg = GetAutoConfig()
    if not cfg or not cfg.autoAcceptQuest then return end
    AcceptQuest()
end

local function OnQuestProgress()
    local cfg = GetAutoConfig()
    if not cfg or not cfg.autoAcceptQuest then return end
    if IsQuestCompletable() then
        CompleteQuest()
    end
end

local function OnQuestComplete()
    local cfg = GetAutoConfig()
    if not cfg or not cfg.autoAcceptQuest then return end
    -- 只有無獎勵選擇或僅一個獎勵時才自動繳交（避免選錯獎勵）
    local numChoices = GetNumQuestChoices()
    if numChoices <= 1 then
        GetQuestReward(numChoices > 0 and 1 or nil)
    end
end

--------------------------------------------------------------------------------
-- 自動接受副本/戰場佇列
--------------------------------------------------------------------------------

local autoQueueFrame = CreateFrame("Frame")

local function OnLFGProposalShow()
    local cfg = GetAutoConfig()
    if not cfg or not cfg.autoAcceptQueue then return end
    AcceptProposal()
end

--------------------------------------------------------------------------------
-- 初始化與清理
--------------------------------------------------------------------------------

function LunarUI:InitAutomation()
    if not self.db or not self.db.profile or not self.db.profile.automation then return end

    -- 自動修裝
    autoRepairFrame:RegisterEvent("MERCHANT_SHOW")
    autoRepairFrame:SetScript("OnEvent", OnMerchantShow)

    -- 自動釋放靈魂
    autoReleaseFrame:RegisterEvent("PLAYER_DEAD")
    autoReleaseFrame:SetScript("OnEvent", OnPlayerDead)

    -- 成就截圖
    achievementFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    achievementFrame:SetScript("OnEvent", OnAchievementEarned)

    -- 自動接受/繳交任務
    autoQuestFrame:RegisterEvent("QUEST_DETAIL")
    autoQuestFrame:RegisterEvent("QUEST_PROGRESS")
    autoQuestFrame:RegisterEvent("QUEST_COMPLETE")
    autoQuestFrame:SetScript("OnEvent", function(_self, event)
        if event == "QUEST_DETAIL" then
            OnQuestDetail()
        elseif event == "QUEST_PROGRESS" then
            OnQuestProgress()
        elseif event == "QUEST_COMPLETE" then
            OnQuestComplete()
        end
    end)

    -- 自動接受副本/戰場佇列
    autoQueueFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
    autoQueueFrame:SetScript("OnEvent", OnLFGProposalShow)
end

function LunarUI.CleanupAutomation()
    autoRepairFrame:UnregisterAllEvents()
    autoRepairFrame:SetScript("OnEvent", nil)

    autoReleaseFrame:UnregisterAllEvents()
    autoReleaseFrame:SetScript("OnEvent", nil)

    achievementFrame:UnregisterAllEvents()
    achievementFrame:SetScript("OnEvent", nil)

    autoQuestFrame:UnregisterAllEvents()
    autoQuestFrame:SetScript("OnEvent", nil)

    autoQueueFrame:UnregisterAllEvents()
    autoQueueFrame:SetScript("OnEvent", nil)
end

LunarUI:RegisterModule("Automation", {
    onEnable = function() LunarUI:InitAutomation() end,
    onDisable = function() LunarUI.CleanupAutomation() end,
})
