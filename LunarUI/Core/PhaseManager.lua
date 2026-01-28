---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field
--[[
    LunarUI - 月相管理器
    驅動整個 UI 行為的核心狀態機

    月相說明：
    - NEW: 非戰鬥，最小化 UI（如新月）
    - WAXING: 準備戰鬥（手動觸發）
    - FULL: 戰鬥中，最大化顯示（如滿月）
    - WANING: 戰鬥結束，逐漸淡出後回到 NEW
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 狀態變數
--------------------------------------------------------------------------------

local currentPhase = LunarUI.PHASES.NEW
local waningTimer = nil
local WANING_DURATION = 10  -- 下弦月持續秒數

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

--[[
    初始化月相管理器
    由 OnEnable 呼叫
]]
function LunarUI:InitPhaseManager()
    -- 根據戰鬥狀態決定初始月相
    if InCombatLockdown() then
        currentPhase = self.PHASES.FULL
    else
        currentPhase = self.PHASES.NEW
    end

    -- 安全地更新 Token（資料庫可能尚未完全初始化）
    if self.UpdateTokens then
        self:UpdateTokens()
    end

    -- 註冊戰鬥事件
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")

    -- 除錯輸出
    self:Debug("月相管理器初始化完成，目前月相：" .. currentPhase)
end

--------------------------------------------------------------------------------
-- 月相查詢
--------------------------------------------------------------------------------

--[[
    取得目前月相
    @return string 目前月相名稱
]]
function LunarUI:GetPhase()
    return currentPhase
end

--[[
    檢查是否處於戰鬥月相（FULL）
]]
function LunarUI:IsInCombat()
    return currentPhase == self.PHASES.FULL
end

--[[
    檢查 UI 是否應完整顯示
]]
function LunarUI:ShouldShowFull()
    return currentPhase == self.PHASES.FULL or currentPhase == self.PHASES.WAXING
end

--[[
    取得下弦月剩餘時間
    @return number 剩餘秒數，非下弦月時回傳 0
]]
function LunarUI:GetWaningTimeRemaining()
    if currentPhase ~= self.PHASES.WANING or not waningTimer then
        return 0
    end
    return self:TimeLeft(waningTimer) or 0
end

--------------------------------------------------------------------------------
-- 月相設定
--------------------------------------------------------------------------------

--[[
    手動設定月相（用於除錯或 WAXING 觸發）
    @param newPhase string 要設定的月相
    @param skipTransition boolean 是否跳過過渡動畫
]]
function LunarUI:SetPhase(newPhase, skipTransition)
    if not self.PHASES[newPhase] then
        self:Print("無效的月相：" .. tostring(newPhase))
        return
    end

    local oldPhase = currentPhase

    -- 取消待執行的計時器
    self:CancelWaningTimer()
    self:CancelTransitionTimer()

    -- 設定新月相
    currentPhase = newPhase

    -- 更新 Token
    self:UpdateTokens()

    -- 通知監聽器
    self:NotifyPhaseChange(oldPhase, newPhase)

    -- 除錯輸出
    self:Debug("月相：" .. oldPhase .. " → " .. newPhase)
end

--[[
    切換 WAXING 月相
    用於開怪前準備
]]
function LunarUI:ToggleWaxing()
    if currentPhase == self.PHASES.NEW then
        self:SetPhase(self.PHASES.WAXING)
    elseif currentPhase == self.PHASES.WAXING then
        self:SetPhase(self.PHASES.NEW)
    end
    -- 在 FULL 或 WANING 時不做任何事
end

--------------------------------------------------------------------------------
-- 戰鬥事件處理
--------------------------------------------------------------------------------

--[[
    進入戰鬥事件
    PLAYER_REGEN_DISABLED 在進入戰鬥時觸發
]]
function LunarUI:OnEnterCombat()
    -- 若重新進入戰鬥，取消下弦計時器
    self:CancelWaningTimer()

    -- 立即進入 FULL 月相
    self:SetPhase(self.PHASES.FULL)
end

--[[
    離開戰鬥事件
    PLAYER_REGEN_ENABLED 在離開戰鬥時觸發
]]
function LunarUI:OnLeaveCombat()
    -- 進入 WANING 月相
    self:SetPhase(self.PHASES.WANING)

    -- 啟動計時器，之後回到 NEW
    self:StartWaningTimer()
end

--------------------------------------------------------------------------------
-- 計時器管理
--------------------------------------------------------------------------------

--[[
    啟動下弦計時器
    經過設定秒數後轉換到 NEW 月相
]]
function LunarUI:StartWaningTimer()
    self:CancelWaningTimer()

    local duration = self.db and self.db.profile.waningDuration or WANING_DURATION

    waningTimer = self:ScheduleTimer(function()
        -- 僅在仍處於 WANING 時轉換
        if currentPhase == self.PHASES.WANING then
            self:SetPhase(self.PHASES.NEW)
        end
        waningTimer = nil
    end, duration)

    self:Debug("下弦計時器啟動：" .. duration .. " 秒")
end

--[[
    取消下弦計時器
]]
function LunarUI:CancelWaningTimer()
    if waningTimer then
        self:CancelTimer(waningTimer)
        waningTimer = nil
    end
end

--[[
    取消過渡計時器
    保留給未來平滑過渡動畫使用
]]
function LunarUI:CancelTransitionTimer()
    -- 目前為空操作，保持 API 一致性
end
