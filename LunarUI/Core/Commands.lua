---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - 斜線命令
    /lunar 命令實作
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

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
    LunarUI:Print(L["FeatureUnavailable"] or string.format("Feature unavailable: %s", funcName))
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
    C_AddOns.LoadAddOn("LunarUI_Debug")

    -- 未知子命令或無參數時先執行一次性診斷
    if not sub or (sub ~= "on" and sub ~= "off") then
        self:DebugVigorFrames()
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
        self:Print("|cffffcc00[DebugVigor]|r 持續監控 |cff00ff00ON|r")
    else
        if LunarUI.CleanupVigorTrace then
            LunarUI.CleanupVigorTrace()
        end
        self:Print("|cffffcc00[DebugVigor]|r 持續監控 |cffff0000OFF|r")
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
    local args = {}
    for word in input:gmatch("%S+") do
        table.insert(args, word:lower())
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
        self:ToggleAddon(cmd)
    elseif cmd == "reset" then
        if args[2] == "all" then
            LunarUI.ResetAllPositions()
        else
            self:ResetPosition()
        end
    elseif cmd == "test" then
        self:RunTest(args[2])
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
            self:Print("LunarUI_Debug failed to load — ToggleTestVigor unavailable")
        end
    else
        self:Print(string.format(_L["UnknownCommand"] or "Unknown command: %s", cmd))
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
    self:Print("  |cffffd100/lunar test|r - " .. (L["CmdTest"] or "Run test"))
    self:Print("  |cffffd100/lunar profile|r - " .. (L["CmdProfile"] or "Show profiling results"))
    self:Print("  |cffffd100/lunar profile events|r - " .. (L["CmdProfileEvents"] or "Event frequency monitor"))
end

--[[
    顯示目前狀態
]]
function LunarUI:PrintStatus()
    local L = Engine.L or {}
    self:Print(L["StatusTitle"] or "|cff8882ffLunarUI Status:|r")
    self:Print("  " .. string.format(L["StatusVersion"] or "Version: %s", self.version))
    self:Print(
        "  "
            .. string.format(
                L["StatusEnabled"] or "Enabled: %s",
                self.db.profile.enabled and ("|cff00ff00" .. (L["Yes"] or "Yes") .. "|r")
                    or ("|cffff0000" .. (L["No"] or "No") .. "|r")
            )
    )
    self:Print(
        "  "
            .. string.format(
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
        self.db.profile.enabled = false
        self:Print(L["Disabled"] or "Disabled")
    else
        self.db.profile.enabled = not self.db.profile.enabled
        self:Print(self.db.profile.enabled and (L["Enabled"] or "Enabled") or (L["Disabled"] or "Disabled"))
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
    -- 嘗試使用 AceConfigDialog 開啟設定面板
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if AceConfigDialog then
        AceConfigDialog:Open("LunarUI")
        return
    end

    -- 備用方案：使用暴雪 Settings API（WoW 10.0+）
    if _G.Settings and _G.Settings.OpenToCategory then
        local ok, _err = pcall(_G.Settings.OpenToCategory, "LunarUI")
        if ok then
            return
        end
        -- 如果失敗，嘗試舊版 API
    end

    -- 備用方案：舊版介面選項 API
    if _G.InterfaceOptionsFrame_OpenToCategory then
        _G.InterfaceOptionsFrame_OpenToCategory("LunarUI")
        _G.InterfaceOptionsFrame_OpenToCategory("LunarUI") -- 呼叫兩次確保打開
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

--------------------------------------------------------------------------------
-- 測試功能
--------------------------------------------------------------------------------

-- Stub: test runner placeholder for future test scenarios (e.g., /lunar test <name>)
function LunarUI:RunTest(scenario)
    local L = Engine.L or {}
    if scenario then
        self:Print(string.format(L["TestMode"] or "Test mode: %s", scenario))
    else
        self:Print(L["AvailableTests"] or "Available tests:")
        self:Print("  |cffffd100/lunar test|r - " .. (L["CmdTestDesc"] or "Show test help"))
    end
end
