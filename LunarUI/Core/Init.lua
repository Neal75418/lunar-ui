---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 現代化戰鬥 UI 系統
    使用 Ace3 框架的核心初始化模組
]]

local ADDON_NAME, Engine = ...

--------------------------------------------------------------------------------
-- 建立 Ace3 插件
--------------------------------------------------------------------------------

local LunarUI =
    LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")

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

-- oUF 參照（oUF 載入後設定）
LunarUI.oUF = nil

--------------------------------------------------------------------------------
-- 模組註冊系統
--------------------------------------------------------------------------------

local moduleRegistry = {}

--[[
    ExecuteModuleCallback - 執行模組的 onEnable 回呼（含延遲支援）
    @param entry table  模組註冊表項目
]]
local pendingDelayedModules = 0
local modulesReadyFired = false

local function ExecuteModuleCallback(entry)
    if entry.delay > 0 then
        pendingDelayedModules = pendingDelayedModules + 1
        C_Timer.After(entry.delay, function()
            -- 延遲期間若插件已停用，跳過初始化但仍遞減計數器
            if not LunarUI:IsEnabled() then
                pendingDelayedModules = pendingDelayedModules - 1
                return
            end
            local ok, err
            if LunarUI.ProfileModuleInit then
                ok, err = LunarUI:ProfileModuleInit(entry.name, entry.onEnable)
            else
                ok, err = pcall(entry.onEnable)
            end
            if not ok then
                print("|cffff6666[LunarUI]|r Module '" .. (entry.name or "?") .. "' failed: " .. tostring(err))
                print("|cffff6666[LunarUI]|r Stack trace:")
                print(debugstack(2))
            end
            pendingDelayedModules = pendingDelayedModules - 1
            if pendingDelayedModules == 0 and not modulesReadyFired then
                modulesReadyFired = true
                LunarUI:SendMessage("LUNARUI_MODULES_READY")
            end
        end)
    else
        local ok, err
        if LunarUI.ProfileModuleInit then
            ok, err = LunarUI:ProfileModuleInit(entry.name, entry.onEnable)
        else
            ok, err = pcall(entry.onEnable)
        end
        if not ok then
            print("|cffff6666[LunarUI]|r Module '" .. (entry.name or "?") .. "' failed: " .. tostring(err))
            print("|cffff6666[LunarUI]|r Stack trace:")
            print(debugstack(2))
        end
    end
end

-- SafeCall 定義在 Core/Utils.lua（統一版本）

--[[
    RegisterModule - 註冊模組至中央管理表
    @param name     string   模組名稱（用於除錯與記錄）
    @param callbacks table   回呼表：
        onEnable   function  插件啟用時呼叫（可選）
        onDisable  function  插件停用時呼叫（可選）
        delay      number    onEnable 延遲秒數，預設 0（可選）
]]
function LunarUI:RegisterModule(name, callbacks)
    if not name or not callbacks then
        return
    end
    local entry = {
        name = name,
        onEnable = callbacks.onEnable or function() end,
        onDisable = callbacks.onDisable or function() end,
        delay = callbacks.delay or 0,
    }
    moduleRegistry[#moduleRegistry + 1] = entry

    -- 若 OnEnable 已觸發（例如延遲載入的模組），立即執行初始化
    if self._modulesEnabled then
        ExecuteModuleCallback(entry)
    end
end

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
    local msg = L["AddonLoaded"] or "Addon loaded"
    self:Print("|cff8882ffLunar|r|cffffffffUI|r v" .. self.version .. " " .. msg)
end

--[[
    OnEnable - 插件啟用時呼叫
]]
function LunarUI:OnEnable()
    -- 取得 oUF 參照（TOC 中設定 X-oUF: LunarUF）
    self.oUF = Engine.oUF or _G.LunarUF or _G.oUF

    -- 註冊斜線命令
    self:RegisterCommands()

    -- 設置 ESC 選項面板
    self:SetupOptions()

    -- 設置 ESC 主選單按鈕
    self:SetupGameMenuButton()

    -- 全域開關檢查：若停用則跳過模組啟用（保留命令與選項面板以便重新啟用）
    if self.db and self.db.profile and self.db.profile.enabled == false then
        local L = Engine.L or {}
        self:Print(L["AddonDisabled"] or "|cffff6666LunarUI disabled|r (type /lunar on to enable)")
        return
    end

    -- 啟用所有已註冊的模組
    self._modulesEnabled = true
    for _, mod in ipairs(moduleRegistry) do
        ExecuteModuleCallback(mod)
    end

    -- 若無延遲模組，立即標記就緒
    if pendingDelayedModules == 0 then
        modulesReadyFired = true
        self:SendMessage("LUNARUI_MODULES_READY")
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
    -- 取消所有計時器
    self:CancelAllTimers()

    -- 隱藏除錯面板
    if self.HideDebugOverlay then
        self:HideDebugOverlay()
    end

    -- 停用所有已註冊的模組（反向迭代，後啟用的先清理）
    for i = #moduleRegistry, 1, -1 do
        local mod = moduleRegistry[i]
        if mod then
            local ok, err = pcall(mod.onDisable)
            if not ok then
                print("|cffff6666[LunarUI]|r Module '" .. (mod.name or "?") .. "' cleanup failed: " .. tostring(err))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- ESC 主選單按鈕 (WoW 11.0+)
--------------------------------------------------------------------------------

local gameMenuHooked = false
local gameMenuButtonAdded = false

function LunarUI.SetupGameMenuButton()
    if gameMenuHooked then
        return
    end
    if not _G.GameMenuFrame or not _G.GameMenuFrame.InitButtons then
        return
    end
    gameMenuHooked = true

    -- WoW 11.0+ 使用 GameMenuFrame:AddButton() API
    -- Hook InitButtons 在按鈕初始化後新增 LunarUI 按鈕
    -- 注意：不交換 buttonPool 中的按鈕位置，避免 taint 風險
    hooksecurefunc(_G.GameMenuFrame, "InitButtons", function(self)
        -- 防止重複添加按鈕（InitButtons 可能被多次調用）
        if gameMenuButtonAdded then
            return
        end
        gameMenuButtonAdded = true

        self:AddButton("LunarUI", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            if _G.HideUIPanel then
                _G.HideUIPanel(_G.GameMenuFrame)
            end
            local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
            if AceConfigDialog then
                AceConfigDialog:Open("LunarUI")
            end
        end)
    end)
end
