---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, unused-local
--[[
    LunarUI - 斜線命令
    /lunar 命令實作
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local format = string.format
local tableInsert = table.insert

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

--[[
    安全呼叫可選模組函數（減少重複的存在性檢查）
    @param funcName string - 函數名稱
    @param ... any - 函數參數
    @return boolean - 是否成功執行
]]
local function SafeCallModule(funcName, ...)
    local func = LunarUI[funcName]
    if func and type(func) == "function" then
        func(LunarUI, ...)
        return true
    end
    local L = Engine.L or {}
    LunarUI:Print(L["FeatureUnavailable"] or format("Feature unavailable: %s", funcName))
    return false
end

--------------------------------------------------------------------------------
-- 命令註冊
--------------------------------------------------------------------------------

--[[
    註冊斜線命令
    由 OnEnable 呼叫
]]
function LunarUI:RegisterCommands()
    self:RegisterChatCommand("lunar", "SlashCommand")
    self:RegisterChatCommand("lui", "SlashCommand")
end

--------------------------------------------------------------------------------
-- 命令 Dispatch Table
--------------------------------------------------------------------------------

-- 直接呼叫 self:Method() 的簡單命令
local SELF_COMMANDS = {
    help = "PrintHelp",
    debug = "ToggleDebug",
    status = "PrintStatus",
    config = "OpenOptions",
    options = "OpenOptions",
}

-- 呼叫 SafeCallModule() 的簡單命令
local MODULE_COMMANDS = {
    move = "ToggleMoveMode",
    keybind = "ToggleKeybindMode",
    export = "ShowExportFrame",
    import = "ShowImportFrame",
    debugauras = "DebugAuraFrames",
    debugmicro = "DebugMicroButtons",
}

--------------------------------------------------------------------------------
-- 子命令處理函數
--------------------------------------------------------------------------------

local function HandleProfile(sub, sub2)
    if sub == "events" then
        local EVENT_PROFILE_ACTIONS = { on = "EnableEventProfiling", off = "DisableEventProfiling" }
        SafeCallModule(EVENT_PROFILE_ACTIONS[sub2] or "PrintEventTimings")
    elseif sub == "on" then
        SafeCallModule("EnableProfiling")
    elseif sub == "off" then
        SafeCallModule("DisableProfiling")
    elseif sub == "show" or not sub then
        SafeCallModule("PrintProfilingResults")
    end
end

local function HandleDebugVigor(self, sub)
    local _L = Engine.L or {}
    C_AddOns.LoadAddOn("LunarUI_Debug")

    -- 未知子命令或無參數時先執行一次性診斷
    if not sub or (sub ~= "on" and sub ~= "off") then
        if self.DebugVigorFrames then
            self:DebugVigorFrames()
        end
    end

    -- 純診斷指令（非 on/off/toggle）就結束
    if sub and sub ~= "on" and sub ~= "off" then
        return
    end

    -- 設定持續監控狀態
    if not self.db.global then
        self.db.global = {}
    end

    local enable = sub == "on" or (not sub and not self.db.global._debugVigor)
    self.db.global._debugVigor = enable

    if enable then
        if LunarUI.SetupVigorTrace then
            LunarUI.SetupVigorTrace()
        end
        self:Print(
            "|cffffcc00[DebugVigor]|r "
                .. (_L["DebugVigorOn"] or "Continuous monitoring")
                .. " |cff00ff00"
                .. (_L["On"] or "ON")
                .. "|r"
        )
    else
        if LunarUI.CleanupVigorTrace then
            LunarUI.CleanupVigorTrace()
        end
        self:Print(
            "|cffffcc00[DebugVigor]|r "
                .. (_L["DebugVigorOff"] or "Continuous monitoring")
                .. " |cffff0000"
                .. (_L["Off"] or "OFF")
                .. "|r"
        )
    end
end

--------------------------------------------------------------------------------
-- 命令處理
--------------------------------------------------------------------------------

--[[
    處理斜線命令
    @param input string 命令參數
]]
function LunarUI:SlashCommand(input)
    local _L = Engine.L or {}
    -- 防止超長輸入造成不必要的解析開銷（WoW slash command 上限通常遠低於此值）
    if #input > 256 then
        return
    end
    local args = {}
    for word in input:gmatch("%S+") do
        tableInsert(args, word:lower())
    end

    local cmd = args[1]

    -- 無參數 → 顯示說明
    if not cmd then
        self:PrintHelp()
        return
    end

    -- 簡單方法呼叫
    local method = SELF_COMMANDS[cmd]
    if method then
        self[method](self)
        return
    end

    -- 簡單模組呼叫
    local moduleFn = MODULE_COMMANDS[cmd]
    if moduleFn then
        SafeCallModule(moduleFn)
        return
    end

    -- 需要子命令的命令
    if cmd == "toggle" or cmd == "on" or cmd == "off" then
        if InCombatLockdown() then
            self:Print(_L["CombatLocked"] or "戰鬥中無法變更插件狀態")
            return
        end
        self:ToggleAddon(cmd)
    elseif cmd == "reset" then
        if InCombatLockdown() then
            self:Print(_L["CombatLocked"] or "Cannot reset positions during combat")
            return
        end
        if args[2] == "all" then
            LunarUI.ResetAllPositions()
        else
            self:ResetPosition()
        end
    elseif cmd == "install" then
        if self.db.global then
            self.db.global.installComplete = false
        end
        SafeCallModule("ShowInstallWizard")
    elseif cmd == "profile" then
        HandleProfile(args[2], args[3])
    elseif cmd == "debugvigor" then
        HandleDebugVigor(self, args[2])
    elseif cmd == "testvigor" then
        C_AddOns.LoadAddOn("LunarUI_Debug")
        if self.ToggleTestVigor then
            self:ToggleTestVigor()
        else
            self:Print(_L["DebugLoadFailed"] or "LunarUI_Debug failed to load")
        end
    else
        self:Print(format(_L["UnknownCommand"] or "Unknown command: %s", cmd))
        self:PrintHelp()
    end
end

--------------------------------------------------------------------------------
-- 說明與狀態
--------------------------------------------------------------------------------

--[[
    顯示說明訊息
]]
function LunarUI:PrintHelp()
    local L = Engine.L or {}
    self:Print(L["HelpTitle"] or "LunarUI Commands:")
    self:Print("  |cffffd100/lunar|r - " .. (L["CmdHelp"] or "Show this help"))
    self:Print("  |cffffd100/lunar toggle|r - " .. (L["CmdToggle"] or "Toggle addon on/off"))
    self:Print("  |cffffd100/lunar debug|r - " .. (L["CmdDebug"] or "Toggle debug mode"))
    self:Print("  |cffffd100/lunar status|r - " .. (L["CmdStatus"] or "Show current status"))
    self:Print("  |cffffd100/lunar config|r - " .. (L["CmdConfig"] or "Open settings"))
    self:Print("  |cffffd100/lunar keybind|r - " .. (L["CmdKeybind"] or "Toggle keybind edit mode"))
    self:Print("  |cffffd100/lunar export|r - " .. (L["CmdExport"] or "Export settings"))
    self:Print("  |cffffd100/lunar import|r - " .. (L["CmdImport"] or "Import settings"))
    self:Print("  |cffffd100/lunar install|r - " .. (L["CmdInstall"] or "Re-run install wizard"))
    self:Print("  |cffffd100/lunar move|r - " .. (L["CmdMove"] or "Toggle frame mover"))
    self:Print("  |cffffd100/lunar reset|r - " .. (L["CmdReset"] or "Reset frame positions"))
    self:Print("  |cffffd100/lunar profile|r - " .. (L["CmdProfile"] or "Show profiling results"))
    self:Print("  |cffffd100/lunar profile events|r - " .. (L["CmdProfileEvents"] or "Event frequency monitor"))
end

--[[
    顯示目前狀態
]]
function LunarUI:PrintStatus()
    if not self.db or not self.db.profile then
        return
    end
    local L = Engine.L or {}
    self:Print(L["StatusTitle"] or "|cff8882ffLunarUI Status:|r")
    self:Print("  " .. format(L["StatusVersion"] or "Version: %s", self.version))
    self:Print(
        "  "
            .. format(
                L["StatusEnabled"] or "Enabled: %s",
                self.db.profile.enabled and ("|cff00ff00" .. (L["Yes"] or "Yes") .. "|r")
                    or ("|cffff0000" .. (L["No"] or "No") .. "|r")
            )
    )
    self:Print(
        "  "
            .. format(
                L["StatusDebug"] or "Debug: %s",
                self.db.profile.debug and ("|cff00ff00" .. (L["On"] or "ON") .. "|r")
                    or ("|cffff0000" .. (L["Off"] or "OFF") .. "|r")
            )
    )
end

--------------------------------------------------------------------------------
-- 功能切換
--------------------------------------------------------------------------------

--[[
    實際停用：關閉 db.enabled 旗標並跑 DisableModules
    （抽出為 helper 以便 confirm dialog 的 OnAccept 呼叫）
]]
local function PerformDisable()
    LunarUI.db.profile.enabled = false
    if LunarUI.DisableModules then
        LunarUI.DisableModules()
    end
end

--[[
    首次 /lunar off 確認對話框（只在 non-reversible 模組存在時出現）
    使用 StaticPopupDialogs 以支援 Escape / 取消 / 不再提醒
]]
local function EnsureDisableConfirmDialog()
    local L = Engine.L or {}
    if not StaticPopupDialogs["LUNARUI_DISABLE_CONFIRM"] then
        StaticPopupDialogs["LUNARUI_DISABLE_CONFIRM"] = {
            text = L["DisableConfirmText"]
                or "停用 LunarUI 後，部分模組（UnitFrames / Nameplates / 換膚）需要 /reload 才能完全還原 Blizzard 原生 UI。是否繼續？",
            button1 = L["DisableConfirmContinue"] or "繼續停用",
            button2 = L["DisableConfirmCancel"] or "取消",
            button3 = L["DisableConfirmDontShow"] or "繼續並不再提醒",
            OnAccept = function()
                PerformDisable()
            end,
            OnAlt = function()
                -- button3：不再提醒 + 繼續停用
                LunarUI.db.profile.warnedOnDisable = true
                PerformDisable()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            -- 不設 exclusive：user-initiated /lunar off 不應被其他 popup 無聲吃掉
        }
    end
end

--[[
    執行 /lunar off 流程：視模組 lifecycle 與使用者偏好決定是否彈 dialog
]]
local function RequestDisable()
    -- 所有模組都是 reversible：/lunar off 無副作用，直接停用不彈 dialog
    if not LunarUI.RequiresReloadForDisable or not LunarUI.RequiresReloadForDisable() then
        PerformDisable()
        return
    end

    -- 使用者已選「不再提醒」：直接停用
    if LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.warnedOnDisable then
        PerformDisable()
        return
    end

    -- 首次 /lunar off 遇到 non-reversible：彈 dialog 讓使用者確認
    EnsureDisableConfirmDialog()
    StaticPopup_Show("LUNARUI_DISABLE_CONFIRM")
end

--[[
    切換插件開關
]]
function LunarUI:ToggleAddon(cmd)
    local L = Engine.L or {}
    if cmd == "on" then
        self.db.profile.enabled = true
        -- 若模組尚未啟用（因 enabled==false 而跳過），立即啟動
        if LunarUI.EnableModules then
            LunarUI.EnableModules()
        end
        self:Print(L["Enabled"] or "Enabled")
    elseif cmd == "off" then
        -- RequestDisable 處理 confirm dialog + 實際停用
        RequestDisable()
    else
        if self.db.profile.enabled then
            RequestDisable()
        else
            self.db.profile.enabled = true
            if LunarUI.EnableModules then
                LunarUI.EnableModules()
            end
            self:Print(L["Enabled"] or "Enabled")
        end
    end
end

--[[
    切換除錯模式
]]
function LunarUI:ToggleDebug()
    local L = Engine.L or {}
    self.db.profile.debug = not self.db.profile.debug

    if self.db.profile.debug then
        self:Print(L["DebugEnabled"] or "Debug mode: ON")
    else
        self:Print(L["DebugDisabled"] or "Debug mode: OFF")
    end

    -- 顯示/隱藏除錯面板
    if self.UpdateDebugOverlay then
        self:UpdateDebugOverlay()
    end
end

--------------------------------------------------------------------------------
-- 設定與重置
--------------------------------------------------------------------------------

--[[
    開啟設定介面
]]
function LunarUI:OpenOptions()
    -- 統一走 LunarUI_Options 提供的 OpenConfig（含 LoadOnDemand + 搜尋 UI + 樣式化）
    if LunarUI.OpenConfig then
        LunarUI.OpenConfig()
        return
    end

    -- Fallback：LunarUI_Options 尚未載入，嘗試直接開 AceConfigDialog
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if AceConfigDialog then
        AceConfigDialog:Open("LunarUI")
        return
    end

    local L = Engine.L or {}
    self:Print(L["OpenOptionsHint"] or "Open ESC > Options > AddOns to find LunarUI")
end

--[[
    重置框架位置
]]
function LunarUI:ResetPosition()
    -- 委派給 FrameMover 的 ResetAllPositions（含 defaultPoints 還原與訊息輸出）
    if LunarUI.ResetAllPositions then
        LunarUI.ResetAllPositions()
    end
end
