---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 斜線命令
    /lunar 命令實作
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

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

    if not cmd or cmd == "help" then
        self:PrintHelp()
    elseif cmd == "toggle" or cmd == "on" or cmd == "off" then
        self:ToggleAddon(cmd)
    elseif cmd == "debug" then
        self:ToggleDebug()
    elseif cmd == "status" then
        self:PrintStatus()
    elseif cmd == "config" or cmd == "options" then
        self:OpenOptions()
    elseif cmd == "reset" then
        if args[2] == "all" then
            LunarUI.ResetAllPositions()
        else
            self:ResetPosition()
        end
    elseif cmd == "test" then
        self:RunTest(args[2])
    elseif cmd == "install" then
        -- 重置安裝完成旗標並重新顯示精靈
        if self.db.global then
            self.db.global.installComplete = false
        end
        if self.ShowInstallWizard then
            self:ShowInstallWizard()
        else
            self:Print(_L["InstallWizardUnavailable"] or "Install wizard unavailable")
        end
    elseif cmd == "move" then
        LunarUI.ToggleMoveMode()
    elseif cmd == "keybind" then
        if self.ToggleKeybindMode then
            self:ToggleKeybindMode()
        else
            self:Print(_L["KeybindModeUnavailable"] or "Keybind mode unavailable")
        end
    elseif cmd == "export" then
        if self.ShowExportFrame then
            self:ShowExportFrame()
        else
            self:Print(_L["ExportUnavailable"] or "Export unavailable")
        end
    elseif cmd == "import" then
        if self.ShowImportFrame then
            self:ShowImportFrame()
        else
            self:Print(_L["ImportUnavailable"] or "Import unavailable")
        end
    elseif cmd == "profile" then
        local sub = args[2]
        if sub == "events" then
            local sub2 = args[3]
            if sub2 == "on" then
                self:EnableEventProfiling()
            elseif sub2 == "off" then
                self:DisableEventProfiling()
            else
                self:PrintEventTimings()
            end
        elseif sub == "on" then
            self:EnableProfiling()
        elseif sub == "off" then
            self:DisableProfiling()
        elseif sub == "show" or not sub then
            self:PrintProfilingResults()
        end
    elseif cmd == "debugauras" then
        if self.DebugAuraFrames then
            self.DebugAuraFrames()
        else
            self:Print("DebugAuraFrames not available")
        end
    elseif cmd == "debugvigor" then
        local sub = args[2]
        if not sub then
            -- 無參數：執行一次性診斷 + 切換持續監控
            self:DebugVigorFrames()
            if not self.db.global then
                self.db.global = {}
            end
            self.db.global._debugVigor = not self.db.global._debugVigor
            if self.db.global._debugVigor then
                if LunarUI.SetupVigorTrace then
                    LunarUI.SetupVigorTrace()
                end
                self:Print(
                    "|cffffcc00[DebugVigor]|r 持續監控 |cff00ff00ON|r（VigorTrace/DeepDiag 訊息已啟用）"
                )
            else
                if LunarUI.CleanupVigorTrace then
                    LunarUI.CleanupVigorTrace()
                end
                self:Print("|cffffcc00[DebugVigor]|r 持續監控 |cffff0000OFF|r")
            end
        elseif sub == "on" then
            if not self.db.global then
                self.db.global = {}
            end
            self.db.global._debugVigor = true
            if LunarUI.SetupVigorTrace then
                LunarUI.SetupVigorTrace()
            end
            self:Print("|cffffcc00[DebugVigor]|r 持續監控 |cff00ff00ON|r")
        elseif sub == "off" then
            if not self.db.global then
                self.db.global = {}
            end
            self.db.global._debugVigor = false
            if LunarUI.CleanupVigorTrace then
                LunarUI.CleanupVigorTrace()
            end
            self:Print("|cffffcc00[DebugVigor]|r 持續監控 |cffff0000OFF|r")
        else
            self:DebugVigorFrames()
        end
    elseif cmd == "testvigor" then
        self:ToggleTestVigor()
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
    -- 重置單位框架位置為預設值
    if not self.db or not self.db.defaults or not self.db.defaults.profile then
        return
    end
    for unit, data in pairs(self.db.defaults.profile.unitframes) do
        if self.db.profile.unitframes[unit] then
            self.db.profile.unitframes[unit].x = data.x
            self.db.profile.unitframes[unit].y = data.y
            self.db.profile.unitframes[unit].point = data.point
        end
    end

    local L = Engine.L or {}
    self:Print(L["PositionReset"] or "Frame positions reset to defaults")
end

--------------------------------------------------------------------------------
-- 測試功能
--------------------------------------------------------------------------------

--[[
    執行測試情境
]]
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
