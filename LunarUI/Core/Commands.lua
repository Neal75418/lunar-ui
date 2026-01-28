---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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
    local L = Engine.L or {}
    local args = {}
    for word in input:gmatch("%S+") do
        table.insert(args, word:lower())
    end

    local cmd = args[1]

    if not cmd or cmd == "help" then
        self:PrintHelp()

    elseif cmd == "toggle" or cmd == "on" or cmd == "off" then
        self:ToggleAddon(cmd)

    elseif cmd == "phase" then
        local phase = args[2]
        if phase then
            self:SetPhase(phase:upper())
        else
            local msg = L["CurrentPhase"] or "目前月相：%s"
            self:Print(string.format(msg, "|cff8882ff" .. self:GetPhase() .. "|r"))
        end

    elseif cmd == "waxing" then
        self:ToggleWaxing()
        local msg = L["CurrentPhase"] or "目前月相：%s"
        self:Print(string.format(msg, "|cff8882ff" .. self:GetPhase() .. "|r"))

    elseif cmd == "debug" then
        self:ToggleDebug()

    elseif cmd == "status" then
        self:PrintStatus()

    elseif cmd == "config" or cmd == "options" then
        self:OpenOptions()

    elseif cmd == "reset" then
        self:ResetPosition()

    elseif cmd == "test" then
        self:RunTest(args[2])

    elseif cmd == "keybind" then
        if self.ToggleKeybindMode then
            self:ToggleKeybindMode()
        else
            self:Print("快捷鍵模式不可用")
        end

    elseif cmd == "export" then
        if self.ShowExportFrame then
            self:ShowExportFrame()
        else
            self:Print("匯出功能不可用")
        end

    elseif cmd == "import" then
        if self.ShowImportFrame then
            self:ShowImportFrame()
        else
            self:Print("匯入功能不可用")
        end

    else
        self:Print("未知命令：" .. cmd)
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
    self:Print(L["HelpTitle"] or "|cff8882ffLunarUI 命令：|r")
    print("  |cffffd100/lunar|r - 顯示此說明")
    print("  |cffffd100/lunar toggle|r - 切換插件開關")
    print("  |cffffd100/lunar phase [NEW|WAXING|FULL|WANING]|r - 顯示/設定月相")
    print("  |cffffd100/lunar waxing|r - 切換上弦月相（開怪準備）")
    print("  |cffffd100/lunar debug|r - 切換除錯模式")
    print("  |cffffd100/lunar status|r - 顯示目前狀態")
    print("  |cffffd100/lunar config|r - 開啟設定介面")
    print("  |cffffd100/lunar keybind|r - 切換快捷鍵編輯模式")
    print("  |cffffd100/lunar export|r - 匯出設定")
    print("  |cffffd100/lunar import|r - 匯入設定")
    print("  |cffffd100/lunar reset|r - 重置框架位置")
    print("  |cffffd100/lunar test [combat]|r - 執行測試")
end

--[[
    顯示目前狀態
]]
function LunarUI:PrintStatus()
    self:Print("|cff8882ffLunarUI 狀態：|r")
    print("  版本：" .. self.version)
    print("  啟用：" .. (self.db.profile.enabled and "|cff00ff00是|r" or "|cffff0000否|r"))
    print("  除錯：" .. (self.db.profile.debug and "|cff00ff00開|r" or "|cffff0000關|r"))
    print("  月相：|cff8882ff" .. self:GetPhase() .. "|r")

    local tokens = self:GetTokens()
    print("  透明度：" .. string.format("%.2f", tokens.alpha))
    print("  縮放：" .. string.format("%.2f", tokens.scale))

    if self:GetPhase() == self.PHASES.WANING then
        local remaining = self:GetWaningTimeRemaining()
        print("  下弦計時：剩餘 " .. string.format("%.1f", remaining) .. " 秒")
    end
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
        self:Print(L["Enabled"] or "已啟用")
    elseif cmd == "off" then
        self.db.profile.enabled = false
        self:Print(L["Disabled"] or "已停用")
    else
        self.db.profile.enabled = not self.db.profile.enabled
        self:Print(self.db.profile.enabled and (L["Enabled"] or "已啟用") or (L["Disabled"] or "已停用"))
    end
end

--[[
    切換除錯模式
]]
function LunarUI:ToggleDebug()
    local L = Engine.L or {}
    self.db.profile.debug = not self.db.profile.debug

    if self.db.profile.debug then
        self:Print(L["DebugEnabled"] or "除錯模式：|cff00ff00開|r")
    else
        self:Print(L["DebugDisabled"] or "除錯模式：|cffff0000關|r")
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
    -- 載入設定插件（若尚未載入）
    local loaded = C_AddOns.IsAddOnLoaded("LunarUI_Options")
    if not loaded then
        local success = C_AddOns.LoadAddOn("LunarUI_Options")
        if not success then
            self:Print("設定介面尚未可用")
            return
        end
    end

    -- 開啟設定（加入錯誤處理）
    if not Settings or type(Settings.OpenToCategory) ~= "function" then
        self:Print("設定 API 不可用")
        return
    end

    local ok, err = pcall(Settings.OpenToCategory, "LunarUI")
    if not ok then
        self:Print("開啟設定失敗：" .. tostring(err))
    end
end

--[[
    重置框架位置
]]
function LunarUI:ResetPosition()
    if self.db then
        -- 重置單位框架位置為預設值
        for unit, data in pairs(self.db.defaults.profile.unitframes) do
            if self.db.profile.unitframes[unit] then
                self.db.profile.unitframes[unit].x = data.x
                self.db.profile.unitframes[unit].y = data.y
                self.db.profile.unitframes[unit].point = data.point
            end
        end
    end

    self:Print("框架位置已重置為預設值")

    -- 觸發 UI 刷新
    self:NotifyPhaseChange(self:GetPhase(), self:GetPhase())
end

--------------------------------------------------------------------------------
-- 測試功能
--------------------------------------------------------------------------------

--[[
    執行測試情境
]]
function LunarUI:RunTest(scenario)
    if scenario == "combat" then
        self:Print("模擬戰鬥循環...")
        -- 模擬進入戰鬥
        self:SetPhase(self.PHASES.FULL)
        self:Print("  → FULL（戰鬥中）")

        -- 3 秒後離開戰鬥
        self:ScheduleTimer(function()
            self:SetPhase(self.PHASES.WANING)
            self:Print("  → WANING（戰鬥結束）")
            self:StartWaningTimer()
        end, 3)

    elseif scenario == "phases" then
        self:Print("循環所有月相...")
        local phases = { "NEW", "WAXING", "FULL", "WANING" }
        for i, phase in ipairs(phases) do
            self:ScheduleTimer(function()
                self:SetPhase(phase)
                self:Print("  → " .. phase)
            end, (i - 1) * 2)
        end

    else
        self:Print("可用測試：")
        print("  |cffffd100/lunar test combat|r - 模擬戰鬥循環")
        print("  |cffffd100/lunar test phases|r - 循環所有月相")
    end
end
