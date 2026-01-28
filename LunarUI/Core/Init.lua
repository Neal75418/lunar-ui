---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 月相驅動的戰鬥 UI 系統
    使用 Ace3 框架的核心初始化模組
]]

local ADDON_NAME, Engine = ...

--------------------------------------------------------------------------------
-- 建立 Ace3 插件
--------------------------------------------------------------------------------

local LunarUI = LibStub("AceAddon-3.0"):NewAddon(
    ADDON_NAME,
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceTimer-3.0",
    "AceHook-3.0"
)

if not LunarUI then
    print("|cffff0000[LunarUI]|r 插件建立失敗！")
    return
end

-- 匯出至全域和引擎
_G.LunarUI = LunarUI
Engine.LunarUI = LunarUI

--------------------------------------------------------------------------------
-- 插件資訊與常數
--------------------------------------------------------------------------------

LunarUI.name = ADDON_NAME
LunarUI.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

-- 月相常數
LunarUI.PHASES = {
    NEW = "NEW",         -- 非戰鬥，最小化顯示
    WAXING = "WAXING",   -- 準備戰鬥
    FULL = "FULL",       -- 戰鬥中，最大化顯示
    WANING = "WANING",   -- 戰鬥結束，逐漸淡出
}

-- oUF 參照（oUF 載入後設定）
LunarUI.oUF = nil

-- 月相變化回呼函數
LunarUI.phaseCallbacks = {}

--------------------------------------------------------------------------------
-- Ace3 生命週期
--------------------------------------------------------------------------------

--[[
    OnInitialize - 插件載入時呼叫
]]
function LunarUI:OnInitialize()
    -- 初始化資料庫
    if self.InitDB then
        self:InitDB()
    end

    local L = Engine.L or {}
    local msg = L["AddonLoaded"] or "插件載入完成"
    self:Print("|cff8882ffLunar|r|cffffffffUI|r v" .. self.version .. " " .. msg)
end

--[[
    OnEnable - 插件啟用時呼叫
]]
function LunarUI:OnEnable()
    -- 取得 oUF 參照（TOC 中設定 X-oUF: LunarUF）
    self.oUF = Engine.oUF or _G.LunarUF or _G.oUF

    -- 初始化月相管理器
    if self.InitPhaseManager then
        self:InitPhaseManager()
    end

    -- 註冊斜線命令
    if self.RegisterCommands then
        self:RegisterCommands()
    end

    local L = Engine.L or {}
    local msg = L["AddonEnabled"] or "已啟用。輸入 |cff8882ff/lunar|r 查看命令"
    self:Print(msg)
end

--[[
    OnDisable - 插件停用時呼叫
    清理所有事件與計時器以防止記憶體洩漏
]]
function LunarUI:OnDisable()
    -- 取消註冊戰鬥事件
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")

    -- 取消所有計時器
    self:CancelAllTimers()

    -- 清除月相回呼
    if self.phaseCallbacks then
        wipe(self.phaseCallbacks)
    end

    -- 隱藏除錯面板
    if self.HideDebugOverlay then
        self:HideDebugOverlay()
    end

    -- 清理小地圖
    if self.CleanupMinimap then
        self:CleanupMinimap()
    end

    -- 清理月相指示器
    if self.CleanupPhaseIndicator then
        self:CleanupPhaseIndicator()
    end

    -- 清理名牌事件
    if self.CleanupNameplates then
        self:CleanupNameplates()
    end

    -- 停止月相光暈動畫
    if self.StopGlowAnimation then
        self:StopGlowAnimation()
    end
end

--------------------------------------------------------------------------------
-- 月相回呼系統
--------------------------------------------------------------------------------

--[[
    註冊月相變化回呼
    @param callback function(oldPhase, newPhase)
]]
function LunarUI:RegisterPhaseCallback(callback)
    if type(callback) == "function" then
        table.insert(self.phaseCallbacks, callback)
    end
end

--[[
    通知所有回呼月相已變化
]]
function LunarUI:NotifyPhaseChange(oldPhase, newPhase)
    for _, callback in ipairs(self.phaseCallbacks) do
        pcall(callback, oldPhase, newPhase)
    end
end
