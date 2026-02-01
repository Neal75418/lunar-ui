---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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

local function OnAchievementEarned(_self, _event, ...)
    local cfg = GetAutoConfig()
    if not cfg or not cfg.autoScreenshot then return end

    -- 延遲截圖讓成就提示先顯示
    C_Timer.After(1, function()
        Screenshot()
    end)
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
end

function LunarUI.CleanupAutomation()
    autoRepairFrame:UnregisterAllEvents()
    autoRepairFrame:SetScript("OnEvent", nil)

    autoReleaseFrame:UnregisterAllEvents()
    autoReleaseFrame:SetScript("OnEvent", nil)

    achievementFrame:UnregisterAllEvents()
    achievementFrame:SetScript("OnEvent", nil)
end

LunarUI:RegisterModule("Automation", {
    onEnable = function() LunarUI:InitAutomation() end,
    onDisable = function() LunarUI.CleanupAutomation() end,
})
