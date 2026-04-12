---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, redundant-parameter, unused-local
--[[
    LunarUI - 特殊按鈕系統
    ExtraActionButton、ZoneAbilityButton、微型按鈕列、快捷鍵模式
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local tableInsert = table.insert
local L = Engine.L or {}
local C = LunarUI.Colors

local DEFAULT_BUTTON_SIZE = 36

-- WoW 綁定命令映射：bar ID → binding prefix（參照 Bartender4）
-- bar2 是主動作條第二頁，不應獨立綁定（跳過）
local BINDING_FORMATS = {
    [1] = "ACTIONBUTTON%d",
    [3] = "MULTIACTIONBAR3BUTTON%d",
    [4] = "MULTIACTIONBAR4BUTTON%d",
    [5] = "MULTIACTIONBAR2BUTTON%d",
    [6] = "MULTIACTIONBAR1BUTTON%d",
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local keybindMode = false
local keybindCombatFrame = nil -- 戰鬥自動退出 keybind mode（避免 secure button taint）
local microMenuLayoutHooked = false
local editModeExitHooked = false -- Edit Mode 退出重新套用位置（singleton hook）
local savedExtraActionPos = nil
local savedZoneAbilityPos = nil

--------------------------------------------------------------------------------
-- 框架位置儲存/還原
--------------------------------------------------------------------------------

-- M4 helper: 儲存框架所有 anchor 點（清理時還原）
local function SaveFramePoints(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
        points[i] = { point, relativeTo, relativePoint, x, y }
    end
    return points
end

-- M4 helper: 還原已儲存的 anchor 點
local function RestoreFramePoints(frame, points)
    frame:ClearAllPoints()
    for _, p in ipairs(points) do
        frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
end

-- Edit Mode 退出時重新套用 ExtraAction/ZoneAbility 位置
-- Blizzard 的 EditModeManager:ExitEditMode() 會重新套用 saved layout，覆蓋我們的 SetPoint
local function HookEditModeExit()
    if editModeExitHooked then
        return
    end
    if not _G.EditModeManagerFrame or not _G.EditModeManagerFrame.ExitEditMode then
        return
    end
    editModeExitHooked = true
    hooksecurefunc(_G.EditModeManagerFrame, "ExitEditMode", function()
        if not LunarUI._modulesEnabled then
            return
        end
        if InCombatLockdown() then
            return
        end
        -- 延遲一幀：讓 Blizzard 先完成 layout 套用，再覆蓋
        C_Timer.After(0, function()
            if not LunarUI._modulesEnabled or InCombatLockdown() then
                return
            end
            LunarUI.ABStyleExtraActionButton()
            LunarUI.ABStyleZoneAbilityButton()
        end)
    end)
end

--------------------------------------------------------------------------------
-- ExtraActionButton 樣式化（世界任務/場景等特殊按鈕）
--------------------------------------------------------------------------------

local function StyleExtraActionButton()
    if InCombatLockdown() then
        return
    end -- 防禦性：避免戰鬥中操作 EditMode 管理的框架
    local db = LunarUI.GetModuleDB("actionbars")
    if not db or db.extraActionButton == false then
        return
    end

    local extra = _G.ExtraActionBarFrame
    if not extra then
        return
    end

    -- 重新定位至畫面中下方
    -- 不使用 SetParent（會造成 taint），僅重新定位
    if not savedExtraActionPos then
        savedExtraActionPos = SaveFramePoints(extra) -- M4: 儲存原始位置供清理還原
    end
    extra:ClearAllPoints()
    extra:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 300)

    -- 停止暴雪預設進場動畫（intro 是 AnimationGroup，無 SetAlpha）
    if extra.intro and extra.intro.Stop then
        extra.intro:Stop()
    end

    -- 遍歷區域，隱藏裝飾材質
    for _, region in ipairs({ extra:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local atlas = region.GetAtlas and region:GetAtlas()
            -- 保留按鈕圖示本身，隱藏背景裝飾
            if atlas and (atlas:find("ExtraAbility") or atlas:find("extraability")) then
                region:SetAlpha(0)
            end
        end
    end

    -- 樣式化 ExtraActionButton1
    local btn = _G.ExtraActionButton1
    if not btn then
        return
    end

    local StyleButton = LunarUI.ABStyleButton
    local buttonSize = db.buttonSize or DEFAULT_BUTTON_SIZE
    btn:SetSize(buttonSize * 1.5, buttonSize * 1.5)

    -- 樣式化按鈕（複用現有 StyleButton）
    StyleButton(btn)

    -- 隱藏暴雪按鈕的額外裝飾
    if btn.style then
        btn.style:SetAlpha(0)
    end

    -- 註冊到月相感知（跟隨動作條透明度）
    local bars = LunarUI._actionBars
    bars.extraActionButton = extra

    -- Edit Mode 退出時重新套用位置（singleton hook，只安裝一次）
    HookEditModeExit()
end

-- Zone Ability Button（龍島飛行等區域技能）
local function StyleZoneAbilityButton()
    if InCombatLockdown() then
        return
    end -- 防禦性：避免戰鬥中操作 EditMode 管理的框架
    local db = LunarUI.GetModuleDB("actionbars")
    if not db or db.extraActionButton == false then
        return
    end

    local zone = _G.ZoneAbilityFrame
    if not zone then
        return
    end

    -- 重新定位
    -- 不使用 SetParent（會造成 taint），僅重新定位
    if not savedZoneAbilityPos then
        savedZoneAbilityPos = SaveFramePoints(zone) -- M4: 儲存原始位置供清理還原
    end
    zone:ClearAllPoints()
    zone:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 350)

    -- 隱藏裝飾背景
    if zone.Style then
        zone.Style:SetAlpha(0)
    end

    -- 樣式化按鈕
    local StyleButton = LunarUI.ABStyleButton
    local btn = zone.SpellButton or zone.SpellButtonContainer
    if btn then
        local buttonSize = db.buttonSize or DEFAULT_BUTTON_SIZE
        btn:SetSize(buttonSize * 1.5, buttonSize * 1.5)
        StyleButton(btn)
    end

    local bars = LunarUI._actionBars
    bars.zoneAbilityButton = zone
end

--------------------------------------------------------------------------------
-- 微型按鈕列（角色/法術書/天賦/任務等系統按鈕）
--------------------------------------------------------------------------------

local function CreateMicroBar()
    local abDB = LunarUI.GetModuleDB("actionbars")
    local db = abDB and abDB.microBar
    if not db or not db.enabled then
        return
    end
    if InCombatLockdown() then
        return
    end

    -- WoW 12.0 微型按鈕列表
    local MICRO_BUTTONS = {}
    local microButtonNames = {
        "CharacterMicroButton",
        "ProfessionMicroButton",
        "PlayerSpellsMicroButton",
        "AchievementMicroButton",
        "QuestLogMicroButton",
        "HousingMicroButton",
        "GuildMicroButton",
        "LFDMicroButton",
        "CollectionsMicroButton",
        "EJMicroButton",
        "StoreMicroButton",
        "MainMenuMicroButton",
    }
    for _, btnName in ipairs(microButtonNames) do
        local btn = _G[btnName]
        if btn then
            tableInsert(MICRO_BUTTONS, btn)
        end
    end

    if #MICRO_BUTTONS == 0 then
        return
    end

    -- 建立定位容器
    local microBar = CreateFrame("Frame", "LunarUI_MicroBar", UIParent)
    local btnWidth = db.buttonWidth or 28
    local btnHeight = db.buttonHeight or 36
    local spacing = 1
    local totalWidth = #MICRO_BUTTONS * btnWidth + (#MICRO_BUTTONS - 1) * spacing

    microBar:SetSize(totalWidth, btnHeight)
    microBar:SetPoint(db.point or "BOTTOM", UIParent, db.point or "BOTTOM", db.x or 0, db.y or 2)
    microBar:SetFrameStrata("MEDIUM")
    microBar:SetClampedToScreen(true)

    -- 儲存按鈕參照以供清理用
    microBar._buttons = MICRO_BUTTONS

    local bars = LunarUI._actionBars

    -- 將 MicroMenu 整體從 MainMenuBar 移到 microBar
    -- 切斷 MainMenuBar→MicroMenu 的 alpha 繼承鏈（避免 HideBlizzardBars 連帶隱藏按鈕）
    -- 按鈕保持為 MicroMenu 的子框架，Blizzard Layout/GetEdgeButton 正常運作
    if _G.MicroMenu then
        bars._microMenuOrigParent = _G.MicroMenu:GetParent()
        _G.MicroMenu:SetParent(microBar)
        _G.MicroMenu:ClearAllPoints()
        _G.MicroMenu:SetAllPoints(microBar)
        _G.MicroMenu:SetAlpha(1)
        _G.MicroMenu:Show()
    end

    -- 在 MicroMenu 內重新排列按鈕（不 reparent 個別按鈕，避免破壞 Layout/GetEdgeButton）
    for i, btn in ipairs(MICRO_BUTTONS) do
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", _G.MicroMenu or microBar, "LEFT", (i - 1) * (btnWidth + spacing), 0)
        btn:SetSize(btnWidth, btnHeight)
        btn:SetAlpha(1)
        btn:Show()

        -- 隱藏暴雪裝飾材質
        for _, region in ipairs({ btn:GetRegions() }) do
            if region:IsObjectType("Texture") then
                local texName = region:GetDebugName() or ""
                -- 保留圖示材質，隱藏背景/邊框/發光
                if texName:find("Background") or texName:find("Flash") or texName:find("Highlight") then
                    region:SetAlpha(0)
                end
            end
        end
    end

    -- Hook Layout 防止暴雪代碼在動態事件中重新排列按鈕位置
    if _G.MicroMenu and _G.MicroMenu.Layout and not microMenuLayoutHooked then
        microMenuLayoutHooked = true
        hooksecurefunc(_G.MicroMenu, "Layout", function()
            if not LunarUI._modulesEnabled then
                return
            end
            if bars.microBar and bars.microBar._buttons and not InCombatLockdown() then
                -- 確保 MicroMenu 仍在我們的容器內
                if _G.MicroMenu:GetParent() ~= bars.microBar then
                    _G.MicroMenu:SetParent(bars.microBar)
                end
                _G.MicroMenu:ClearAllPoints()
                _G.MicroMenu:SetAllPoints(bars.microBar)
                -- 從 DB 動態讀取（避免捕獲 stale upvalue）
                local microDB = LunarUI.GetModuleDB("actionbars")
                local mbDB = microDB and microDB.microBar
                local curBtnWidth = (mbDB and mbDB.buttonWidth) or 28
                local curSpacing = 1
                for idx, mbtn in ipairs(bars.microBar._buttons) do
                    mbtn:ClearAllPoints()
                    mbtn:SetPoint("LEFT", _G.MicroMenu, "LEFT", (idx - 1) * (curBtnWidth + curSpacing), 0)
                end
            end
        end)
    end

    bars.microBar = microBar
end

-- 微型按鈕列清理
local function CleanupMicroBar()
    local bars = LunarUI._actionBars
    if bars.microBar then
        -- 還原 MicroMenu 到原始父框架（Layout hook 因 bars.microBar=nil 自動停止介入）
        if _G.MicroMenu and not InCombatLockdown() then
            local origParent = bars._microMenuOrigParent or _G.MainMenuBar or UIParent
            _G.MicroMenu:SetParent(origParent)
            _G.MicroMenu:SetAlpha(1)
            -- 讓 Blizzard Layout 重新排列按鈕
            if _G.MicroMenu.Layout then
                pcall(_G.MicroMenu.Layout, _G.MicroMenu)
            end
        end
        bars.microBar:Hide()
        bars.microBar = nil
        bars._microMenuOrigParent = nil
    end
end

--------------------------------------------------------------------------------
-- 快捷鍵模式
--------------------------------------------------------------------------------

-- 前向宣告（EnterKeybindMode 的戰鬥事件回呼需要呼叫 ExitKeybindMode）
---@type fun()
local ExitKeybindMode

local function EnterKeybindMode()
    if InCombatLockdown() then
        LunarUI:Print(L["KeybindCombatLocked"] or "Cannot change keybinds during combat")
        return
    end
    if keybindMode then
        return
    end
    keybindMode = true

    local buttons = LunarUI._actionBarButtons
    for _name, button in pairs(buttons) do
        -- 只處理有綁定格式的 bar（跳過 bar2 主動作條第二頁和無 parent 的 orphan 按鈕）
        local barId = button:GetParent() and button:GetParent().id
        if barId and BINDING_FORMATS[barId] then
            -- 高亮按鈕
            if button.LunarBorder then
                button.LunarBorder:SetBackdropBorderColor(unpack(C.highlightBlue))
            end

            -- 啟用鍵盤綁定
            button:EnableKeyboard(true)
            button:SetScript("OnKeyDown", function(self, key)
                -- P2 fix: handler 在 ExitKeybindMode 戰鬥路徑中無法被移除
                -- （EnableKeyboard/SetScript 是 protected op），因此 handler 本身
                -- 必須 guard。keybindMode=false 或戰鬥中直接忽略按鍵，避免從
                -- tainted SecureActionButton 呼叫 SetBinding/SaveBindings。
                if not keybindMode or InCombatLockdown() then
                    return
                end
                if key == "ESCAPE" then
                    LunarUI.ABExitKeybindMode()
                    return
                end

                -- 設定快捷鍵（根據 bar ID 選擇正確的綁定命令）
                local btnBarId = self:GetParent() and self:GetParent().id
                local bindFormat = btnBarId and BINDING_FORMATS[btnBarId]
                if bindFormat then
                    local action = self._state_action
                    if action then
                        local buttonIndex = ((action - 1) % 12 + 1)
                        SetBinding(key, bindFormat:format(buttonIndex))
                        SaveBindings(GetCurrentBindingSet())
                    end
                end
            end)
        end
    end

    -- 註冊戰鬥事件：進入戰鬥時自動退出 keybind mode + 脫戰後清理 handler
    -- 使用穩定的 unified OnEvent handler 同時處理 DISABLED（auto-exit）和
    -- ENABLED（延後清 EnableKeyboard/OnKeyDown），避免 re-enter keybind mode
    -- 時因 OnEvent 被覆寫而失去 combat auto-exit 能力。
    if not keybindCombatFrame then
        keybindCombatFrame = CreateFrame("Frame")
        keybindCombatFrame:SetScript("OnEvent", function(self, event)
            if event == "PLAYER_REGEN_DISABLED" then
                if keybindMode then
                    ExitKeybindMode()
                    LunarUI:Print(L["KeybindCombatExited"] or "快捷鍵模式已自動退出（進入戰鬥）")
                end
            elseif event == "PLAYER_REGEN_ENABLED" then
                -- 脫戰後真正清掉 protected ops（EnableKeyboard / SetScript）
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                local btns = LunarUI._actionBarButtons
                if btns then
                    for _, btn in pairs(btns) do
                        btn:EnableKeyboard(false)
                        btn:SetScript("OnKeyDown", nil)
                    end
                end
            end
        end)
    end
    keybindCombatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

    local msg = L["KeybindEnabled"] or "Keybind mode enabled. Hover over a button and press a key. Press ESC to exit."
    LunarUI:Print(msg)
end

ExitKeybindMode = function()
    if not keybindMode then
        return
    end
    keybindMode = false

    -- 解除 PLAYER_REGEN_DISABLED（不需要再自動退出了，已經退出了）
    if keybindCombatFrame then
        keybindCombatFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
    end

    local buttons = LunarUI._actionBarButtons
    for _name, button in pairs(buttons) do
        -- 重設邊框
        if button.LunarBorder then
            button.LunarBorder:SetBackdropBorderColor(unpack(C.border))
        end

        -- Security S-A2: EnableKeyboard / SetScript("OnKeyDown", nil) 對
        -- SecureActionButton 是 protected operation。戰鬥中延後到脫戰清理。
        if not InCombatLockdown() then
            button:EnableKeyboard(false)
            button:SetScript("OnKeyDown", nil)
        end
    end

    -- 戰鬥中無法清 handler，讓 unified handler 的 PLAYER_REGEN_ENABLED 分支處理。
    -- OnEvent handler 不會被覆寫（stable），下次 EnterKeybindMode 不受影響。
    if InCombatLockdown() and keybindCombatFrame then
        keybindCombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end

    local msg = L["KeybindDisabled"] or "快捷鍵模式已停用。"
    LunarUI:Print(msg)
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.ABStyleExtraActionButton = StyleExtraActionButton
LunarUI.ABStyleZoneAbilityButton = StyleZoneAbilityButton
LunarUI.ABCreateMicroBar = CreateMicroBar
LunarUI.ABCleanupMicroBar = CleanupMicroBar
LunarUI.ABEnterKeybindMode = EnterKeybindMode
LunarUI.ABExitKeybindMode = ExitKeybindMode
LunarUI.ABRestoreFramePoints = RestoreFramePoints
LunarUI.ABSavedExtraActionPos = function()
    return savedExtraActionPos
end
LunarUI.ABSavedZoneAbilityPos = function()
    return savedZoneAbilityPos
end

-- 內部存取點：供 CleanupActionBars 重置狀態
LunarUI._ABSpecialButtonsState = {
    resetKeybindMode = function()
        keybindMode = false
        -- 解除戰鬥自動退出事件（CleanupActionBars 在戰鬥中無法呼叫 ExitKeybindMode）
        if keybindCombatFrame then
            keybindCombatFrame:UnregisterAllEvents()
        end
    end,
    isKeybindMode = function()
        return keybindMode
    end,
    clearSavedExtraActionPos = function()
        savedExtraActionPos = nil
    end,
    clearSavedZoneAbilityPos = function()
        savedZoneAbilityPos = nil
    end,
}
