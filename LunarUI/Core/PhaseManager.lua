---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
--[[
    LunarUI - 月相管理器
    驅動整個 UI 行為的核心狀態機

    月相說明：
    - NEW: 非戰鬥，最小化 UI（如新月）
    - WAXING: 準備戰鬥（手動觸發）
    - FULL: 戰鬥中，最大化顯示（如滿月）
    - WANING: 戰鬥結束，逐漸淡出後回到 NEW
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 狀態變數
--------------------------------------------------------------------------------

local currentPhase = LunarUI.PHASES.NEW
local targetPhase = nil  -- 目標月相（過渡期間使用）
local fadingFromTokens = nil -- 過渡起始狀態
local transitionTimer = nil
local transitionStart = 0
local transitionDuration = 0.5 -- 預設過渡時間

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

    -- 註冊 WAXING 感知事件
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "CheckWaxingCondition")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "CheckWaxingCondition")
    self:RegisterEvent("UNIT_SPELLCAST_START", "OnSpellCast")

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
function LunarUI.GetPhase()
    -- 如果正在過渡，回傳目標月相，讓 UI 邏輯可以預先反應
    return targetPhase or currentPhase
end

--[[
    檢查是否處於戰鬥月相（FULL）
]]
function LunarUI:IsInCombat()
    return self.GetPhase() == self.PHASES.FULL
end

--[[
    檢查 UI 是否應完整顯示
]]
function LunarUI:ShouldShowFull()
    local phase = self.GetPhase()
    return phase == self.PHASES.FULL or phase == self.PHASES.WAXING
end

--[[
    取得下弦月剩餘時間
    @return number 剩餘秒數，非下弦月時回傳 0
]]
function LunarUI:GetWaningTimeRemaining()
    if self.GetPhase() ~= self.PHASES.WANING or not waningTimer then
        return 0
    end
    return self:TimeLeft(waningTimer) or 0
end

--------------------------------------------------------------------------------
-- 月相設定與過渡動畫
--------------------------------------------------------------------------------

--[[
    取消過渡計時器
]]
function LunarUI:CancelTransitionTimer()
    if transitionTimer then
        transitionTimer:Cancel()
        transitionTimer = nil
    end
end

--[[
    執行過渡動畫的一幀
]]
local function OnTransitionStep()
    local self = LunarUI
    local now = GetTime()
    local elapsed = now - transitionStart
    local progress = elapsed / transitionDuration

    if progress >= 1 then
        -- 過渡結束
        self:CancelTransitionTimer()
        currentPhase = targetPhase
        targetPhase = nil
        fadingFromTokens = nil
        self:UpdateTokens() -- 確保設為最終準確值
        return
    end

    -- 計算插值
    -- 使用 OutQuad 讓結束時減速，感覺比較自然
    local ease = self.Easing and self.Easing.OutQuad or function(t) return t end
    local easedProgress = ease(progress, 0, 1, 1)

    local startTokens = fadingFromTokens
    local endTokens = self:GetTokensForPhase(targetPhase)
    
    -- 計算當前幀的 tokens
    local currentTokens = self.InterpolateTokens(startTokens, endTokens, easedProgress)
    
    -- 直接寫入目前的 tokens 表供 UI 使用
    self.tokens = currentTokens
    
    -- 通知 UI 更新
    -- 這裡不呼叫 NotifyPhaseChange 因為那通常是狀態改變的一次性通知
    -- 我們需要一個新的通知機制或依賴 Layout 的 Update Loop
    -- 由於 Layout.lua 已經有 ProcessUpdateBatch 機制，我們只要更新 self.tokens 
    -- 並觸發 Layout 的 UpdateAllFramesForPhase 即可
    
    -- 注意：頻繁呼叫這行可能會導致效能問題，但 Layout.lua 有做優化
    self:NotifyPhaseChange(currentPhase, targetPhase, true) 
end

--[[
    設定月相
    @param newPhase string 要設定的月相
    @param duration number 過渡時間 (秒)，nil 則使用預設值，0 則瞬間切換
]]
function LunarUI:SetPhase(newPhase, duration)
    if not self.PHASES[newPhase] then
        self:Print("無效的月相：" .. tostring(newPhase))
        return
    end

    -- 如果已經是目標月相，什麼都不做
    if newPhase == (targetPhase or currentPhase) then
        return
    end

    local oldPhase = targetPhase or currentPhase
    
    -- 設定過渡參數
    duration = duration or 0.5
    
    -- 戰鬥開始 (FULL) 總是瞬間切換，不應有延遲
    if newPhase == self.PHASES.FULL then
        duration = 0
    end

    -- 下弦月 (WANING) 可以慢一點
    if newPhase == self.PHASES.WANING then
        duration = 1.0
    end

    -- 取消正在跑的計時器
    self:CancelWaningTimer()
    self:CancelTransitionTimer()

    -- 記錄起始狀態（如果正在過渡，就從當前中間狀態開始）
    fadingFromTokens = self.tokens or self:GetTokensForPhase(oldPhase)
    targetPhase = newPhase
    
    if duration <= 0 then
        -- 瞬間切換
        currentPhase = newPhase
        targetPhase = nil
        fadingFromTokens = nil
        self:UpdateTokens()
        self:NotifyPhaseChange(oldPhase, newPhase)
    else
        -- 開始過渡動畫
        transitionStart = GetTime()
        transitionDuration = duration
        
        -- 每 0.03 秒更新一次 (約 30 FPS)
        -- 使用 C_Timer 而非 AceTimer 以獲得更輕量的 Loop
        transitionTimer = C_Timer.NewTicker(0.03, OnTransitionStep)
        
        -- 通知系統即使在過渡中，邏輯上的月相已經變了
        self:NotifyPhaseChange(oldPhase, newPhase)
    end

    -- 除錯輸出
    self:Debug("月相切換：" .. oldPhase .. " → " .. newPhase .. " (" .. duration .. "s)")
end

--[[
    切換 WAXING 月相
    用於開怪前準備
]]
function LunarUI:ToggleWaxing()
    local phase = self:GetPhase()
    if phase == self.PHASES.NEW then
        self:SetPhase(self.PHASES.WAXING)
    elseif phase == self.PHASES.WAXING then
        self:SetPhase(self.PHASES.NEW)
    end
end

--------------------------------------------------------------------------------
-- 智能觸發條件 (Smart Triggers)
--------------------------------------------------------------------------------

--[[
    檢查是否符合 WAXING 條件
    由 PLAYER_TARGET_CHANGED 等事件觸發
]]
function LunarUI:CheckWaxingCondition()
    -- 如果已經在戰鬥或下弦月，不要干擾
    local phase = self:GetPhase()
    if phase == self.PHASES.FULL or phase == self.PHASES.WANING then
        return
    end

    local shouldWax = false

    -- 條件 1: 有目標且目標有敵意
    if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
        shouldWax = true
    end

    -- 條件 2: 處於特定姿態 (如潛行)
    -- 此處可擴充

    if shouldWax and phase == self.PHASES.NEW then
        self:SetPhase(self.PHASES.WAXING)
    elseif not shouldWax and phase == self.PHASES.WAXING then
        -- 沒目標了，回到 NEW
        -- 給一點延遲，以免切換目標時閃爍
        C_Timer.After(0.5, function()
            -- 再次檢查確認真的沒目標
            if not UnitExists("target") and self:GetPhase() == self.PHASES.WAXING then
                self:SetPhase(self.PHASES.NEW)
            end
        end)
    end
end

--[[
    施法事件監聽
    如果玩家對敵對目標施法，也要進入 WAXING
]]
function LunarUI:OnSpellCast(_event, unit, _castGUID, _spellID)
    if unit ~= "player" then return end
    
    -- 只有在 NEW 狀態才需要檢查
    if self:GetPhase() ~= self.PHASES.NEW then return end

    if UnitCanAttack("player", "target") then
        self:SetPhase(self.PHASES.WAXING)
    end
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

    -- 立即進入 FULL 月相 (0秒延遲)
    self:SetPhase(self.PHASES.FULL, 0)
end

--[[
    離開戰鬥事件
    PLAYER_REGEN_ENABLED 在離開戰鬥時觸發
]]
function LunarUI:OnLeaveCombat()
    -- 進入 WANING 月相 (慢速過渡)
    self:SetPhase(self.PHASES.WANING, 1.0)

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
        if self:GetPhase() == self.PHASES.WANING then
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

