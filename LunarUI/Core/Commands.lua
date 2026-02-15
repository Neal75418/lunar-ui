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

    elseif cmd == "debugvigor" then
        local sub = args[2]
        if not sub then
            -- 無參數：執行一次性診斷 + 切換持續監控
            self:DebugVigorFrames()
            if not self.db.global then self.db.global = {} end
            self.db.global._debugVigor = not self.db.global._debugVigor
            if self.db.global._debugVigor then
                if LunarUI.SetupVigorTrace then LunarUI.SetupVigorTrace() end
                self:Print("|cffffcc00[DebugVigor]|r 持續監控 |cff00ff00ON|r（VigorTrace/DeepDiag 訊息已啟用）")
            else
                if LunarUI.CleanupVigorTrace then LunarUI.CleanupVigorTrace() end
                self:Print("|cffffcc00[DebugVigor]|r 持續監控 |cffff0000OFF|r")
            end
        elseif sub == "on" then
            if not self.db.global then self.db.global = {} end
            self.db.global._debugVigor = true
            if LunarUI.SetupVigorTrace then LunarUI.SetupVigorTrace() end
            self:Print("|cffffcc00[DebugVigor]|r 持續監控 |cff00ff00ON|r")
        elseif sub == "off" then
            if not self.db.global then self.db.global = {} end
            self.db.global._debugVigor = false
            if LunarUI.CleanupVigorTrace then LunarUI.CleanupVigorTrace() end
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
end

--[[
    顯示目前狀態
]]
function LunarUI:PrintStatus()
    local L = Engine.L or {}
    self:Print(L["StatusTitle"] or "|cff8882ffLunarUI Status:|r")
    self:Print("  " .. string.format(L["StatusVersion"] or "Version: %s", self.version))
    self:Print("  " .. string.format(L["StatusEnabled"] or "Enabled: %s", self.db.profile.enabled and ("|cff00ff00" .. (L["Yes"] or "Yes") .. "|r") or ("|cffff0000" .. (L["No"] or "No") .. "|r")))
    self:Print("  " .. string.format(L["StatusDebug"] or "Debug: %s", self.db.profile.debug and ("|cff00ff00" .. (L["On"] or "ON") .. "|r") or ("|cffff0000" .. (L["Off"] or "OFF") .. "|r")))
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
        if ok then return end
        -- 如果失敗，嘗試舊版 API
    end

    -- 備用方案：舊版介面選項 API
    if _G.InterfaceOptionsFrame_OpenToCategory then
        _G.InterfaceOptionsFrame_OpenToCategory("LunarUI")
        _G.InterfaceOptionsFrame_OpenToCategory("LunarUI")  -- 呼叫兩次確保打開
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
    if not self.db or not self.db.defaults or not self.db.defaults.profile then return end
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
-- 活力條偵錯
--------------------------------------------------------------------------------

function LunarUI:DebugVigorFrames()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
    end

    -- 安全取值輔助（避免 secret taint）
    local function safeNum(val) return tonumber(tostring(val or 0)) or 0 end
    local function safeStr(val) return tostring(val or "?") end

    -- 取得框架完整診斷資訊
    local function describeFrame(frame, indent)
        indent = indent or ""
        local info = {}
        pcall(function()
            local shown = frame:IsShown() and "shown" or "HIDDEN"
            local visible = frame:IsVisible() and "visible" or "INVISIBLE"
            info.shown = shown .. "/" .. visible
        end)
        pcall(function() info.alpha = string.format("%.2f", safeNum(frame:GetAlpha())) end)
        pcall(function() info.effAlpha = string.format("%.2f", safeNum(frame:GetEffectiveAlpha())) end)
        pcall(function() info.scale = string.format("%.2f", safeNum(frame:GetScale())) end)
        pcall(function() info.effScale = string.format("%.3f", safeNum(frame:GetEffectiveScale())) end)
        pcall(function()
            local w, h = frame:GetSize()
            info.size = string.format("%.0fx%.0f", safeNum(w), safeNum(h))
        end)
        pcall(function()
            local p, rel, _, px, py = frame:GetPoint(1)
            local relName = "?"
            if rel then relName = safeStr(rel:GetName() or "unnamed") end
            info.pos = safeStr(p) .. "(" .. string.format("%.0f", safeNum(px)) .. "," .. string.format("%.0f", safeNum(py)) .. ")@" .. relName
        end)
        pcall(function()
            local l, b, w, h = frame:GetBoundsRect()
            if l then
                info.bounds = string.format("L=%.0f B=%.0f W=%.0f H=%.0f", safeNum(l), safeNum(b), safeNum(w), safeNum(h))
            end
        end)
        pcall(function()
            local parent = frame:GetParent()
            info.parent = parent and safeStr(parent:GetName() or "unnamed") or "nil"
        end)
        pcall(function() info.strata = safeStr(frame:GetFrameStrata()) end)
        pcall(function() info.level = safeNum(frame:GetFrameLevel()) end)

        -- LunarUI 標記檢查
        if frame._lunarUIForceHidden then info.flags = (info.flags or "") .. " FORCE_HIDDEN" end
        if frame._lunarSkinBG then info.flags = (info.flags or "") .. " SKINNED" end

        local line = indent .. (info.shown or "?") ..
            " a=" .. (info.alpha or "?") ..
            " eff=" .. (info.effAlpha or "?") ..
            " sc=" .. (info.scale or "?") ..
            " effSc=" .. (info.effScale or "?") ..
            " sz=" .. (info.size or "?") ..
            " " .. (info.pos or "?") ..
            " parent=" .. (info.parent or "?") ..
            " strata=" .. (info.strata or "?") .. "/" .. (info.level or "?")
        if info.bounds then line = line .. " [" .. info.bounds .. "]" end
        if info.flags then line = line .. " FLAGS:" .. info.flags end
        return line
    end

    add("=== Vigor Bar Debug v5 ===")

    -- 1) 核心 vigor 框架詳細診斷
    add("--- Core Vigor Frames ---")
    local coreFrames = {
        "EncounterBar",
        "UIWidgetPowerBarContainerFrame",
        "PlayerPowerBarAlt",
        "OverrideActionBar",
        "UIParentBottomManagedFrameContainer",
        "UIParentRightManagedFrameContainer",
    }
    for _, name in ipairs(coreFrames) do
        local frame = _G[name]
        if frame then
            add(name .. ": " .. describeFrame(frame))
            -- 子框架（含大小與位置）
            local ok, children = pcall(function() return { frame:GetChildren() } end)
            if ok and children then
                for i, child in ipairs(children) do
                    if i > 10 then
                        add("  ... +" .. (#children - 10) .. " more children")
                        break
                    end
                    local cName = "child#" .. i
                    pcall(function() cName = child:GetName() or cName end)
                    add("  -> " .. cName .. ": " .. describeFrame(child, "     "))
                end
            end
            -- Region（材質/文字）
            local ok2, regions = pcall(function() return { frame:GetRegions() } end)
            if ok2 and regions then
                local texCount, visCount = 0, 0
                for _, r in ipairs(regions) do
                    texCount = texCount + 1
                    pcall(function()
                        if r:IsShown() and r:GetAlpha() > 0 then visCount = visCount + 1 end
                    end)
                end
                if texCount > 0 then
                    add("     regions: " .. texCount .. " total, " .. visCount .. " visible")
                end
            end
        else
            add(name .. ": NOT FOUND")
        end
    end

    -- 2) Parent chain walk（從 EncounterBar 一路到 UIParent）
    add("--- Parent Chain (EncounterBar -> UIParent) ---")
    local eb = _G["EncounterBar"]
    if eb then
        local current = eb
        local depth = 0
        while current and depth < 15 do
            local cName = "?"
            pcall(function() cName = current:GetName() or "unnamed" end)
            add("[" .. depth .. "] " .. safeStr(cName) .. ": " .. describeFrame(current))
            pcall(function() current = current:GetParent() end)
            depth = depth + 1
            if current == nil then break end
        end
    else
        add("EncounterBar not found, cannot walk parent chain")
    end

    -- 3) 其他可能相關的框架
    add("--- Other Frames ---")
    local otherFrames = {
        "MainMenuBar",
        "MainMenuBarArtFrame",
        "StatusTrackingBarManager",
        "MainStatusTrackingBarContainer",
        "MinimapCluster",
    }
    for _, name in ipairs(otherFrames) do
        local frame = _G[name]
        if frame then
            add(name .. ": " .. describeFrame(frame))
        else
            add(name .. ": NOT FOUND")
        end
    end

    -- 4) 搜尋全域 Vigor/Skyriding/PowerBar 框架
    add("--- Global scan (Vigor/Skyriding/PowerBar) ---")
    local found = 0
    for k, v in pairs(_G) do
        local ok, line = pcall(function()
            if type(k) ~= "string" or type(v) ~= "table" or not v.GetAlpha then return nil end
            local safeKey = tostring(k)
            if not (safeKey:match("[Vv]igor") or safeKey:match("[Ss]kyriding") or safeKey:match("PowerBar")) then return nil end
            return "[GLOBAL] " .. safeKey .. ": " .. describeFrame(v)
        end)
        if ok and line then
            add(tostring(line))
            found = found + 1
        end
    end
    if found == 0 then
        add("(no global frames matching Vigor/Skyriding/PowerBar)")
    end

    -- 5) UIWidgetPowerBarContainerFrame 深層遍歷（找出 vigor widget 內容）
    add("--- Deep Widget Scan (UIWidgetPowerBarContainerFrame) ---")
    local uwpbcf = _G["UIWidgetPowerBarContainerFrame"]
    if uwpbcf then
        local totalFrames, totalVisible, totalWithTex = 0, 0, 0
        local function scanDeep(frame, depth, prefix)
            if depth > 5 then return end  -- 最多 5 層
            local ok, children = pcall(function() return { frame:GetChildren() } end)
            if not ok or not children then return end
            for i, child in ipairs(children) do
                totalFrames = totalFrames + 1
                local cName = "?"
                pcall(function() cName = child:GetName() or ("child#" .. i) end)
                local isVis = false
                pcall(function() isVis = child:IsVisible() end)
                if isVis then totalVisible = totalVisible + 1 end
                -- 檢查是否有材質
                local texCount = 0
                pcall(function()
                    local regions = { child:GetRegions() }
                    for _, r in ipairs(regions) do
                        if r and r.IsObjectType and r:IsObjectType("Texture") then
                            texCount = texCount + 1
                        end
                    end
                end)
                if texCount > 0 then totalWithTex = totalWithTex + 1 end
                -- 只輸出有內容或有名字的框架
                if texCount > 0 or cName ~= ("child#" .. i) or depth <= 2 then
                    add(prefix .. cName .. ": " .. describeFrame(child, prefix) .. " tex=" .. texCount)
                end
                scanDeep(child, depth + 1, prefix .. "  ")
            end
        end
        scanDeep(uwpbcf, 0, "  ")
        add(string.format("  TOTAL: %d frames, %d visible, %d with textures", totalFrames, totalVisible, totalWithTex))
    else
        add("UIWidgetPowerBarContainerFrame: NOT FOUND")
    end

    -- 6) LunarUI 動作條 bg 框架掃描（檢查是否遮擋 vigor bar）
    add("--- LunarUI ActionBar BG Scan ---")
    local bgCount = 0
    for k, v in pairs(_G) do
        local ok, line = pcall(function()
            if type(k) ~= "string" or type(v) ~= "table" or not v.GetFrameStrata then return nil end
            if not tostring(k):match("LunarUI.*[Bb]ar") then return nil end
            local strata = v:GetFrameStrata()
            if strata == "TOOLTIP" or strata == "FULLSCREEN_DIALOG" then
                return "[WARNING] " .. tostring(k) .. " strata=" .. strata
            end
            return nil
        end)
        if ok and line then
            add(tostring(line))
            bgCount = bgCount + 1
        end
    end
    if bgCount == 0 then
        add("(no LunarUI bar frames at TOOLTIP/FULLSCREEN_DIALOG strata)")
    end

    -- 7) UIWidget API 診斷（直接查詢 WoW 的 widget 系統）
    add("--- UIWidget API ---")
    pcall(function()
        if not C_UIWidgetManager then
            add("C_UIWidgetManager: NOT AVAILABLE")
        else
            -- 查詢所有 widget set 的 power bar 類型 widget
            local widgetSets = { 1, 2, 3, 283 }  -- 常見 widget set ID
            for _, setID in ipairs(widgetSets) do
                local ok, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
                if ok and widgets then
                    local count = #widgets
                    if count > 0 then
                        add("WidgetSet " .. setID .. ": " .. count .. " widgets")
                        for _, w in ipairs(widgets) do
                            local wType = safeNum(w.widgetType)
                            local wID = safeNum(w.widgetID)
                            -- Type 3 = StatusBar (vigor is this type)
                            -- Type 0 = IconAndText, Type 2 = CaptureBar, etc.
                            add("  widgetID=" .. wID .. " type=" .. wType ..
                                (wType == 3 and " (StatusBar/VIGOR?)" or ""))
                            -- 嘗試獲取 StatusBar 詳細資訊
                            if wType == 3 then
                                local ok2, info = pcall(C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo, wID)
                                if ok2 and info then
                                    add("    -> barValue=" .. safeNum(info.barValue) ..
                                        " barMin=" .. safeNum(info.barMin) ..
                                        " barMax=" .. safeNum(info.barMax) ..
                                        " text=" .. safeStr(info.text))
                                end
                            end
                        end
                    end
                end
            end

            -- 查詢所有 widget container 框架
            add("--- Widget Container Frames ---")
            local containerNames = {
                "UIWidgetPowerBarContainerFrame",
                "UIWidgetBelowMinimapContainerFrame",
                "UIWidgetTopCenterContainerFrame",
                "UIWidgetCenterDisplayFrame",
                "UIWidgetAboveOverlayContainerFrame",
            }
            for _, cName in ipairs(containerNames) do
                local cf = _G[cName]
                if cf then
                    local childCount = 0
                    local texCount = 0
                    pcall(function()
                        childCount = select("#", cf:GetChildren())
                        local regions = { cf:GetRegions() }
                        for _, r in ipairs(regions) do
                            if r and r.IsObjectType and r:IsObjectType("Texture") then
                                texCount = texCount + 1
                            end
                        end
                    end)
                    add(cName .. ": children=" .. childCount .. " textures=" .. texCount)
                else
                    add(cName .. ": NOT FOUND")
                end
            end
        end
    end)

    -- 8) UnitPowerBarAlt API（最重要！vigor 是透過此系統顯示）
    add("--- UnitPowerBarAlt API ---")
    pcall(function()
        -- 檢查玩家是否有替代能量條（vigor = alternative power bar）
        if UnitPowerBarAlt_GetCurrentPowerBar then
            local barInfo = UnitPowerBarAlt_GetCurrentPowerBar("player")
            add("UnitPowerBarAlt_GetCurrentPowerBar: " .. safeStr(barInfo))
        else
            add("UnitPowerBarAlt_GetCurrentPowerBar: API NOT FOUND")
        end
    end)
    pcall(function()
        if GetUnitPowerBarInfo then
            local barID, minPower, startInset, endInset, smooth, hideFromOthers, showOnRaid = GetUnitPowerBarInfo("player")
            add("GetUnitPowerBarInfo: barID=" .. safeStr(barID) ..
                " minPower=" .. safeStr(minPower))
        else
            add("GetUnitPowerBarInfo: API NOT FOUND")
        end
    end)
    pcall(function()
        if GetUnitPowerBarInfoByID then
            -- Vigor barID 通常是一個特定值
            add("GetUnitPowerBarInfoByID: API EXISTS")
        end
    end)
    pcall(function()
        if UnitPowerBarAltStatus_GetPowerBarInfo then
            local info = UnitPowerBarAltStatus_GetPowerBarInfo("player")
            add("UnitPowerBarAltStatus: " .. safeStr(info))
        end
    end)
    pcall(function()
        -- 直接檢查 PlayerPowerBarAlt 內部狀態
        local ppba = _G["PlayerPowerBarAlt"]
        if ppba then
            add("PlayerPowerBarAlt.barID=" .. safeStr(ppba.barID))
            add("PlayerPowerBarAlt.isActive=" .. safeStr(ppba.isActive))
            add("PlayerPowerBarAlt.barType=" .. safeStr(ppba.barType))
            -- 檢查 OnEvent 腳本是否存在
            local onEvent = ppba:GetScript("OnEvent")
            add("PlayerPowerBarAlt OnEvent: " .. (onEvent and "SET" or "NIL!"))
            -- 檢查事件註冊
            local events = { "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE",
                "UNIT_POWER_BAR_TIMER_UPDATE", "PLAYER_ENTERING_WORLD" }
            for _, ev in ipairs(events) do
                local registered = ppba:IsEventRegistered(ev)
                if registered then
                    add("  event " .. ev .. ": REGISTERED")
                else
                    add("  event " .. ev .. ": NOT registered")
                end
            end
        end
    end)
    pcall(function()
        -- EncounterBar 事件/腳本檢查
        local eb = _G["EncounterBar"]
        if eb then
            local onEvent = eb:GetScript("OnEvent")
            add("EncounterBar OnEvent: " .. (onEvent and "SET" or "NIL!"))
            local onShow = eb:GetScript("OnShow")
            add("EncounterBar OnShow: " .. (onShow and "SET" or "nil"))
            -- 檢查重要事件
            local ebEvents = { "UPDATE_ENCOUNTER_BAR", "PLAYER_ENTERING_WORLD",
                "UPDATE_UI_WIDGET", "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE" }
            for _, ev in ipairs(ebEvents) do
                local ok, registered = pcall(function() return eb:IsEventRegistered(ev) end)
                if ok then
                    add("  event " .. ev .. ": " .. (registered and "REGISTERED" or "NOT registered"))
                end
            end
        end
    end)

    -- 9) Skyriding / Mount 資訊
    add("--- Mount Info ---")
    pcall(function()
        add("IsMounted=" .. tostring(IsMounted and IsMounted()))
        add("IsFlying=" .. tostring(IsFlying and IsFlying()))
        add("IsFalling=" .. tostring(IsFalling and IsFalling()))
        -- Skyriding 相關 API（WoW 11.0+）
        if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
            local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
            add("GlidingInfo: isGliding=" .. tostring(isGliding) ..
                " canGlide=" .. tostring(canGlide) ..
                " forwardSpeed=" .. safeStr(forwardSpeed))
        else
            add("C_PlayerInfo.GetGlidingInfo: NOT AVAILABLE")
        end
        if C_Spell and C_Spell.DoesSpellExist then
            -- Skyriding 被動技能 spell ID
            local skyridingSpells = { 404468, 404464, 404462 }  -- 常見 Skyriding 相關 spell
            for _, spellID in ipairs(skyridingSpells) do
                local exists = C_Spell.DoesSpellExist(spellID)
                if exists then
                    add("Spell " .. spellID .. ": EXISTS")
                end
            end
        end
    end)

    -- 10) LunarUI 狀態
    add("--- LunarUI State ---")
    pcall(function()
        local db = LunarUI.db and LunarUI.db.profile
        if db then
            add("enabled=" .. tostring(db.enabled))
            add("actionbars.enabled=" .. tostring(db.actionbars and db.actionbars.enabled))
        else
            add("db.profile not available")
        end
    end)

    add("=== End Debug v5 ===")

    -- 顯示在可複製的 EditBox 彈窗（tostring 確保所有值都是純字串，避免 secret taint）
    local safeLines = {}
    for i = 1, #lines do
        safeLines[i] = tostring(lines[i])
    end
    local text = table.concat(safeLines, "\n")

    -- 清理舊框架避免重複創建
    local oldFrame = _G["LunarUI_DebugVigorPopup"]
    if oldFrame then
        oldFrame:Hide()
        oldFrame:SetParent(nil)
    end

    local f = CreateFrame("Frame", "LunarUI_DebugVigorPopup", UIParent, "BackdropTemplate")
    f:SetSize(600, 400)
    f:SetPoint("CENTER")
    f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", -30, 40)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetWidth(540)
    editBox:SetAutoFocus(false)
    editBox:SetText(text)
    editBox:HighlightText()
    scroll:SetScrollChild(editBox)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    self:Print("Debug output shown in popup - Ctrl+A then Ctrl+C to copy")
end

--------------------------------------------------------------------------------
-- Vigor 測試模式
--------------------------------------------------------------------------------

--- 切換 testvigor 模式：暫停所有暴雪動作條隱藏，用於診斷 vigor bar 問題
function LunarUI:ToggleTestVigor()
    if not self.db.global then self.db.global = {} end
    self.db.global._testVigorMode = not self.db.global._testVigorMode

    if self.db.global._testVigorMode then
        self:Print("|cffff0000[TEST MODE ON]|r 暴雪動作條隱藏 + SetScale hooks 全部暫停。")
        self:Print("此模式移除所有可能汙染安全框架的 rawset hooks，")
        self:Print("讓 WoW 的 override bar 轉換流程在乾淨狀態下運作。")
        self:Print("請輸入 |cffffd100/reload|r 使設定生效，然後騎上飛龍檢查 vigor bar。")
        self:Print("完成後輸入 |cffffd100/lunar testvigor|r 關閉測試模式。")
    else
        self:Print("|cff00ff00[TEST MODE OFF]|r 恢復暴雪動作條隱藏。")
        self:Print("請輸入 |cffffd100/reload|r 使設定生效。")
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
