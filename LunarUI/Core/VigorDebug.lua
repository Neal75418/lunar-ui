---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Vigor 偵錯工具
    /lunar debugvigor 與 /lunar testvigor 的實作
    包含一次性診斷、持續監控（VigorTrace）、測試模式
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 偵錯輸出
--------------------------------------------------------------------------------

-- 動作條診斷輸出（只在 debugvigor 模式下顯示，避免正常使用時洗頻）
local function VigorDebugPrint(msg)
    if LunarUI.db and LunarUI.db.global and LunarUI.db.global._debugVigor then
        LunarUI:Print(msg)
    end
end

--------------------------------------------------------------------------------
-- 一次性診斷（/lunar debugvigor）
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
        local function scanDeep(frame, scanDepth, prefix)
            if scanDepth > 5 then return end  -- 最多 5 層
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
                if texCount > 0 or cName ~= ("child#" .. i) or scanDepth <= 2 then
                    add(prefix .. cName .. ": " .. describeFrame(child, prefix) .. " tex=" .. texCount)
                end
                scanDeep(child, scanDepth + 1, prefix .. "  ")
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
                                local ok2, wInfo = pcall(C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo, wID)
                                if ok2 and wInfo then
                                    add("    -> barValue=" .. safeNum(wInfo.barValue) ..
                                        " barMin=" .. safeNum(wInfo.barMin) ..
                                        " barMax=" .. safeNum(wInfo.barMax) ..
                                        " text=" .. safeStr(wInfo.text))
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
            local barID, _minPower = GetUnitPowerBarInfo("player")
            add("GetUnitPowerBarInfo: barID=" .. safeStr(barID) ..
                " minPower=" .. safeStr(_minPower))
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
        local ebCheck = _G["EncounterBar"]
        if ebCheck then
            local onEvent = ebCheck:GetScript("OnEvent")
            add("EncounterBar OnEvent: " .. (onEvent and "SET" or "NIL!"))
            local onShow = ebCheck:GetScript("OnShow")
            add("EncounterBar OnShow: " .. (onShow and "SET" or "nil"))
            -- 檢查重要事件
            local ebEvents = { "UPDATE_ENCOUNTER_BAR", "PLAYER_ENTERING_WORLD",
                "UPDATE_UI_WIDGET", "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE" }
            for _, ev in ipairs(ebEvents) do
                local ok, registered = pcall(function() return ebCheck:IsEventRegistered(ev) end)
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
-- 持續監控（VigorTrace）
--------------------------------------------------------------------------------

-- 動作條事件監控：使用坐騎事件追蹤相關框架的狀態（debug-only 診斷）
-- 不依賴 ActionBarController_UpdateAll（WoW 12.0 可能是 local 或延遲載入）
-- 改用 PLAYER_MOUNT_DISPLAY_CHANGED + 定時檢查
local vigorTraceHooked = false
local vigorTraceOutputCount = 0  -- 限制輸出次數避免洗頻
local vigorTraceFrame             -- module scope 引用，供 cleanup 使用

local function SetupVigorTrace()
    if vigorTraceHooked then return end
    vigorTraceHooked = true

    local function DumpVigorState(trigger)
        -- 限制每次騎乘最多輸出 3 次
        if vigorTraceOutputCount >= 3 then return end
        vigorTraceOutputCount = vigorTraceOutputCount + 1

        local lines = {}
        local function tr(msg) lines[#lines + 1] = msg end

        tr("trigger=" .. trigger)

        -- 飛行狀態
        pcall(function()
            local flying = IsFlying and IsFlying() or false
            local falling = IsFalling and IsFalling() or false
            tr("fly=" .. tostring(flying) .. " fall=" .. tostring(falling))
        end)

        -- OverrideActionBar
        local oab = _G.OverrideActionBar
        if oab then
            tr("OAB:" .. (oab:IsShown() and "Y" or "N") .. "/" .. (oab:IsVisible() and "Y" or "N"))
        else
            tr("OAB:nil")
        end

        -- EncounterBar
        local eb = _G.EncounterBar
        if eb then
            local a = string.format("%.1f", eb:GetAlpha())
            local ea = string.format("%.1f", eb:GetEffectiveAlpha())
            local w, h = eb:GetSize()
            tr("EB:" .. (eb:IsShown() and "Y" or "N") .. "/" .. (eb:IsVisible() and "Y" or "N")
                .. " a=" .. a .. " ea=" .. ea .. " sz=" .. math.floor(w) .. "x" .. math.floor(h))
            -- 子框架詳細資訊（名稱、大小、可見性）
            local cc = select("#", eb:GetChildren())
            tr("EB.ch=" .. cc)
            if cc > 0 then
                local children = {eb:GetChildren()}
                for ci = 1, cc do
                    local child = children[ci]
                    if child then
                        local cName = child:GetName() or ("ch" .. ci)
                        if #cName > 20 then cName = cName:sub(1, 20) .. ".." end
                        local cw, ch2 = child:GetSize()
                        tr("EB[" .. ci .. "]" .. cName .. ":" .. math.floor(cw) .. "x" .. math.floor(ch2)
                            .. (child:IsVisible() and "V" or "H"))
                    end
                end
            end
            -- 父框架（大小 + alpha chain）
            local parent = eb:GetParent()
            if parent then
                local pName = parent:GetName() or "unnamed"
                local pa = string.format("%.1f", parent:GetAlpha())
                local pea = string.format("%.1f", parent:GetEffectiveAlpha())
                local pw, ph = parent:GetSize()
                tr("EB.parent=" .. pName .. " a=" .. pa .. " ea=" .. pea
                    .. " sz=" .. math.floor(pw) .. "x" .. math.floor(ph))
            end
        else
            tr("EB:nil")
        end

        -- UIWidgetPowerBarContainerFrame（vigor 小工具的容器）
        local uwp = _G.UIWidgetPowerBarContainerFrame
        if uwp then
            local uw, uh = uwp:GetSize()
            local uwpCC = select("#", uwp:GetChildren())
            local regSetID = uwp.registeredWidgetSetID
            tr("UWP:" .. (uwp:IsShown() and "Y" or "N") .. "/" .. (uwp:IsVisible() and "Y" or "N")
                .. " sz=" .. math.floor(uw) .. "x" .. math.floor(uh) .. " ch=" .. uwpCC
                .. " regSet=" .. tostring(regSetID))
            -- UWP 子框架（vigor widget bars）+ 深層子框架
            if uwpCC > 0 then
                local uwpChildren = {uwp:GetChildren()}
                for ui = 1, uwpCC do
                    local uc = uwpChildren[ui]
                    if uc then
                        local ucName = uc:GetName() or ("uwp" .. ui)
                        if #ucName > 20 then ucName = ucName:sub(1, 20) .. ".." end
                        local ucw, uch = uc:GetSize()
                        local ucChildCount = select("#", uc:GetChildren())
                        local ucRegionCount = select("#", uc:GetRegions())
                        tr("UWP[" .. ui .. "]" .. ucName .. ":" .. math.floor(ucw) .. "x" .. math.floor(uch)
                            .. (uc:IsVisible() and "V" or "H")
                            .. " ch=" .. ucChildCount .. " rg=" .. ucRegionCount)
                        -- 深層：顯示每個 UWP 子框架的子框架（actual vigor widgets）
                        if ucChildCount > 0 then
                            local deepChildren = {uc:GetChildren()}
                            for di = 1, math.min(ucChildCount, 5) do
                                local dc = deepChildren[di]
                                if dc then
                                    local dcName = dc:GetName() or ("d" .. di)
                                    if #dcName > 25 then dcName = dcName:sub(1, 25) .. ".." end
                                    local dcw, dch = dc:GetSize()
                                    local dcAlpha = string.format("%.1f", dc:GetAlpha())
                                    tr("  UWP[" .. ui .. "][" .. di .. "]" .. dcName
                                        .. ":" .. math.floor(dcw) .. "x" .. math.floor(dch)
                                        .. (dc:IsVisible() and "V" or "H")
                                        .. " a=" .. dcAlpha)
                                end
                            end
                        end
                    end
                end
            end
        else
            tr("UWP:nil")
        end

        -- PlayerPowerBarAlt
        local ppba = _G.PlayerPowerBarAlt
        if ppba then
            tr("PPBA:" .. (ppba:IsShown() and "Y" or "N") .. "/" .. (ppba:IsVisible() and "Y" or "N"))
        else
            tr("PPBA:nil")
        end

        -- UIWidget 容器框架（vigor 可能在這些之中）
        local containers = {
            "UIWidgetBelowMinimapContainerFrame",
            "UIWidgetTopCenterContainerFrame",
        }
        for _, cName in ipairs(containers) do
            local cf = _G[cName]
            if cf then
                local cc = select("#", cf:GetChildren())
                local shortName = cName:sub(1, 8)
                tr(shortName .. ":" .. (cf:IsVisible() and "V" or "H") .. " ch=" .. cc)
                -- 列出子框架名稱（尋找 vigor/power bar widget）
                if cc > 0 then
                    local cfChildren = {cf:GetChildren()}
                    for ci = 1, math.min(cc, 5) do
                        local child = cfChildren[ci]
                        if child then
                            local chName = child:GetName() or ("c" .. ci)
                            if #chName > 30 then chName = chName:sub(1, 30) .. ".." end
                            local chw, chh = child:GetSize()
                            tr("  " .. shortName .. "[" .. ci .. "]" .. chName
                                .. ":" .. math.floor(chw) .. "x" .. math.floor(chh)
                                .. (child:IsVisible() and "V" or "H"))
                        end
                    end
                end
            end
        end

        -- HasOverrideActionBar / HasVehicleActionBar
        pcall(function()
            tr("hasOAB=" .. tostring(HasOverrideActionBar and HasOverrideActionBar()))
            tr("hasVAB=" .. tostring(HasVehicleActionBar and HasVehicleActionBar()))
            tr("bonusBar=" .. tostring(GetBonusBarIndex and GetBonusBarIndex()))
        end)

        -- C_UIWidgetManager：查詢 WoW C++ 側是否有活躍的 vigor/power widget
        pcall(function()
            if C_UIWidgetManager then
                local powerSetID = C_UIWidgetManager.GetPowerBarWidgetSetID
                    and C_UIWidgetManager.GetPowerBarWidgetSetID()
                tr("powerSetID=" .. tostring(powerSetID))
                if powerSetID and powerSetID > 0 then
                    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(powerSetID)
                    tr("powerWidgets=" .. (widgets and #widgets or 0))
                    if widgets then
                        for wi = 1, math.min(#widgets, 5) do
                            local w = widgets[wi]
                            tr("pw[" .. wi .. "]id=" .. (w.widgetID or "?")
                                .. " type=" .. (w.widgetType or "?"))
                        end
                    end
                end
            end
        end)

        -- MainMenuBarManager 狀態
        pcall(function()
            local mgr = _G.MainMenuBarManager
            if mgr then
                tr("MMBMgr:" .. (mgr:IsShown() and "Y" or "N") .. "/"
                    .. (mgr:IsVisible() and "Y" or "N")
                    .. " a=" .. string.format("%.1f", mgr:GetAlpha()))
            else
                tr("MMBMgr:nil")
            end
        end)

        VigorDebugPrint("|cff88aaff[VigorTrace]|r " .. table.concat(lines, " | "))
    end

    vigorTraceFrame = CreateFrame("Frame")
    vigorTraceFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    vigorTraceFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    vigorTraceFrame:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    vigorTraceFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    vigorTraceFrame:SetScript("OnEvent", function(_, event)
        -- 騎上坐騎時重設計數器
        if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            vigorTraceOutputCount = 0
        end
        -- 延遲 0.5 秒等待框架狀態穩定
        C_Timer.After(0.5, function()
            if IsMounted and IsMounted() then
                DumpVigorState(event)
            end
        end)
        -- 延遲 5 秒再檢查一次（捕捉起飛後的狀態）
        if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            C_Timer.After(5, function()
                if IsMounted and IsMounted() then
                    DumpVigorState("FLIGHT_CHECK_5s")
                end
            end)
        end
    end)
end

-- Vigor trace 清理（解除事件，允許重新建立）
local function CleanupVigorTrace()
    if vigorTraceFrame then
        vigorTraceFrame:UnregisterAllEvents()
        vigorTraceFrame:SetScript("OnEvent", nil)
        vigorTraceFrame = nil
        vigorTraceHooked = false
        vigorTraceOutputCount = 0
    end
end

--------------------------------------------------------------------------------
-- 測試模式
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
-- 匯出
--------------------------------------------------------------------------------

LunarUI.SetupVigorTrace = SetupVigorTrace
LunarUI.CleanupVigorTrace = CleanupVigorTrace
