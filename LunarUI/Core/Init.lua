---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - 現代化戰鬥 UI 系統
    使用 Ace3 框架的核心初始化模組
]]

local ADDON_NAME, Engine = ...
local format = string.format

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

-- 設定 locale table（Locales 已在 TOC 中先載入）
-- 必須在此處設定，因為 Locales/enUS.lua 執行時 Engine.LunarUI 還不存在
LunarUI.L = Engine.L

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
local enableGeneration = 0 -- 每次 OnDisable 遞增，使飛行中的 C_Timer.After callback 失效

local function ExecuteModuleCallback(entry)
    if entry.delay > 0 then
        local gen = enableGeneration -- 捕捉當前世代，callback 可藉此判斷是否已過期
        pendingDelayedModules = pendingDelayedModules + 1
        C_Timer.After(entry.delay, function()
            -- 世代不符代表 OnDisable 已被呼叫，此 callback 已過期，直接忽略
            if gen ~= enableGeneration then
                return
            end
            -- 延遲期間若插件已停用，跳過初始化但仍遞減計數器並檢查是否觸發 READY
            if not LunarUI:IsEnabled() then
                pendingDelayedModules = pendingDelayedModules - 1
                if pendingDelayedModules == 0 and not modulesReadyFired then
                    modulesReadyFired = true
                    LunarUI:SendMessage("LUNARUI_MODULES_READY")
                end
                return
            end
            local ok, err
            if LunarUI.ProfileModuleInit then
                ok, err = LunarUI.ProfileModuleInit(entry.name, entry.onEnable)
            else
                ok, err = pcall(entry.onEnable)
            end
            if not ok then
                LunarUI:Error(
                    format(
                        (Engine.L or {})["ModuleInitFailed"] or "Module '%s' failed: %s",
                        entry.name or "?",
                        tostring(err)
                    )
                )
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
            ok, err = LunarUI.ProfileModuleInit(entry.name, entry.onEnable)
        else
            ok, err = pcall(entry.onEnable)
        end
        if not ok then
            LunarUI:Error(
                format(
                    (Engine.L or {})["ModuleInitFailed"] or "Module '%s' failed: %s",
                    entry.name or "?",
                    tostring(err)
                )
            )
            print(debugstack(2))
        end
    end
end

-- SafeCall 定義在 Core/Utils.lua（統一版本）

-- 模組生命週期類型（contract：定義 /lunar off 的停用語義）
-- reversible:       /lunar off 後同 session 可完整恢復 Blizzard 原生狀態
-- soft_disable:     停掉 LunarUI 邏輯，但不保證回到 Blizzard 原生
-- reload_required:  停用後需要 /reload 才能完全回到原生
local VALID_LIFECYCLES = {
    ["reversible"] = true,
    ["soft_disable"] = true,
    ["reload_required"] = true,
}

--[[
    RegisterModule - 註冊模組至中央管理表
    @param name     string   模組名稱（用於除錯與記錄）
    @param callbacks table   回呼表：
        onEnable   function  插件啟用時呼叫（可選）
        onDisable  function  插件停用時呼叫（可選）
        delay      number    onEnable 延遲秒數，預設 0（可選）
        lifecycle  string    "reversible"（預設）/ "soft_disable" / "reload_required"
]]
function LunarUI:RegisterModule(name, callbacks)
    if not name or not callbacks then
        return
    end
    local lifecycle = callbacks.lifecycle or "reversible"
    if not VALID_LIFECYCLES[lifecycle] then
        self:Error(format("Module '%s': invalid lifecycle '%s'", name, tostring(lifecycle)))
        lifecycle = "reversible"
    end
    if lifecycle == "reversible" and not callbacks.onDisable then
        self:Error(format("Module '%s': lifecycle 'reversible' requires onDisable", name))
    end
    local entry = {
        name = name,
        onEnable = callbacks.onEnable or function() end,
        onDisable = callbacks.onDisable or function() end,
        delay = callbacks.delay or 0,
        lifecycle = lifecycle,
    }
    moduleRegistry[#moduleRegistry + 1] = entry

    -- 若 OnEnable 已觸發（例如延遲載入的模組），立即執行初始化
    if self._modulesEnabled then
        ExecuteModuleCallback(entry)
    end
end

-- 測試用：重置模組登錄表（僅供 spec 環境）
LunarUI._resetModuleRegistry = function()
    wipe(moduleRegistry)
    enableGeneration = enableGeneration + 1
    pendingDelayedModules = 0
    modulesReadyFired = false
end

--[[
    EnableModules - 啟用所有已註冊的模組並標記就緒
    供 OnEnable 和 /lunar on（ToggleAddon）共用，確保模組只啟用一次
]]
function LunarUI.EnableModules()
    if LunarUI._modulesEnabled then
        return
    end
    LunarUI._modulesEnabled = true
    for _, mod in ipairs(moduleRegistry) do
        ExecuteModuleCallback(mod)
    end
    if pendingDelayedModules == 0 then
        modulesReadyFired = true
        LunarUI:SendMessage("LUNARUI_MODULES_READY")
    end
end

--[[
    DisableModules - 停用所有已註冊的模組（反向迭代）
    供 /lunar off（ToggleAddon）呼叫，讓「停用」語義完整
]]
function LunarUI.DisableModules()
    if not LunarUI._modulesEnabled then
        return
    end
    LunarUI._modulesEnabled = false
    -- 遞增世代，使飛行中的 C_Timer.After 延遲模組 callback 失效
    enableGeneration = enableGeneration + 1
    modulesReadyFired = false
    pendingDelayedModules = 0

    -- 反向停用所有模組
    for i = #moduleRegistry, 1, -1 do
        local mod = moduleRegistry[i]
        if mod then
            local ok, err = pcall(mod.onDisable)
            if not ok then
                LunarUI:Error(
                    format(
                        (Engine.L or {})["ModuleCleanupFailed"] or "Module '%s' cleanup failed: %s",
                        mod.name or "?",
                        tostring(err)
                    )
                )
            end
        end
    end

    -- 根據已註冊模組的 lifecycle 類型決定提示訊息
    local needsReload = false
    for _, mod in ipairs(moduleRegistry) do
        if mod.lifecycle ~= "reversible" then
            needsReload = true
            break
        end
    end

    local L = Engine.L or {}
    if needsReload then
        LunarUI:Print(L["LunarUIDisabledReload"] or "LunarUI disabled (requires UI reload)")
    else
        LunarUI:Print(L["LunarUIDisabled"] or "LunarUI disabled")
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

    -- 載入 Options 插件以註冊到 Blizzard 介面選項（LoadOnDemand）
    if not C_AddOns.IsAddOnLoaded("LunarUI_Options") then
        C_AddOns.LoadAddOn("LunarUI_Options")
    end

    -- 設置 ESC 主選單按鈕
    self:SetupGameMenuButton()

    -- 全域開關檢查：若停用則跳過模組啟用（保留命令與選項面板以便重新啟用）
    if self.db and self.db.profile and self.db.profile.enabled == false then
        local L = Engine.L or {}
        self:Print(L["AddonDisabled"] or "|cffff6666LunarUI disabled|r (type /lunar on to enable)")
        return
    end

    -- 啟用所有已註冊的模組
    LunarUI.EnableModules()

    local L = Engine.L or {}
    local msg = L["AddonEnabled"] or "已啟用。輸入 |cff8882ff/lunar|r 查看命令"
    self:Print(msg)
end

-- ESC 主選單按鈕旗標
local gameMenuHooked = false

--[[
    OnDisable - 插件停用時呼叫
    清理所有事件與計時器以防止記憶體洩漏
]]
function LunarUI:OnDisable()
    -- 取消所有計時器
    self:CancelAllTimers()

    -- 取消事件註冊（防止記憶體洩漏）
    -- Config.lua:43 註冊的專精切換事件
    self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    -- 隱藏除錯面板
    if self.HideDebugOverlay then
        self:HideDebugOverlay()
    end

    -- 統一走 DisableModules 路徑（設 _modulesEnabled=false、遞增 generation、反向停用所有模組）
    self.DisableModules()
end

--------------------------------------------------------------------------------
-- ESC 主選單按鈕 (WoW 11.0+)
--------------------------------------------------------------------------------

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
    -- WoW 11.0+ InitButtons 每次開啟選單都會重建按鈕，
    -- 須每次 hook 觸發時重新加入；reentrancy guard 防止 AddButton 觸發遞迴
    local addingButton = false
    hooksecurefunc(_G.GameMenuFrame, "InitButtons", function(self)
        if addingButton then
            return
        end
        addingButton = true
        self:AddButton("LunarUI", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            _G.HideUIPanel(_G.GameMenuFrame)
            local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
            if AceConfigDialog then
                AceConfigDialog:Open("LunarUI")
            end
        end)
        addingButton = false
    end)
end
