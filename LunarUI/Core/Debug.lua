---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if
--[[
    LunarUI - 除錯模組
    提供除錯日誌與視覺化除錯面板
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 除錯輔助函數
--------------------------------------------------------------------------------

--[[
    輸出除錯訊息（僅在除錯模式下）
    @param msg 要輸出的訊息
]]
function LunarUI:Debug(msg)
    if self.db and self.db.profile and self.db.profile.debug then
        self:Print("|cff888888[除錯]|r " .. tostring(msg))
    end
end

--[[
    檢查是否處於除錯模式
    @return boolean
]]
function LunarUI:IsDebugMode()
    return self.db and self.db.profile and self.db.profile.debug
end

--------------------------------------------------------------------------------
-- 除錯面板
--------------------------------------------------------------------------------

local debugFrame = nil
local updateInterval = 0.1  -- 更新間隔（秒）
local elapsed = 0

-- 月相圖示（ASCII 表示）
local PHASE_ICONS = {
    NEW = "|cff333333●|r",      -- 新月（暗色）
    WAXING = "|cff888888◐|r",   -- 上弦月
    FULL = "|cffffff00●|r",     -- 滿月（亮色）
    WANING = "|cff666666◑|r",   -- 下弦月
}

--[[
    建立除錯面板
    重載時會重用現有框架以防止記憶體洩漏
]]
local function CreateDebugFrame()
    if debugFrame then return debugFrame end

    -- 重載時重用現有框架
    local existingFrame = _G["LunarUIDebugFrame"]
    if existingFrame then
        debugFrame = existingFrame
        debugFrame:SetScript("OnUpdate", nil)
    else
        debugFrame = CreateFrame("Frame", "LunarUIDebugFrame", UIParent, "BackdropTemplate")
    end

    debugFrame:SetSize(200, 120)
    debugFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -200)
    debugFrame:SetFrameStrata("HIGH")
    debugFrame:SetMovable(true)
    debugFrame:EnableMouse(true)
    debugFrame:RegisterForDrag("LeftButton")
    debugFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    debugFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- 背景樣式
    debugFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    debugFrame:SetBackdropColor(0, 0, 0, 0.8)
    debugFrame:SetBackdropBorderColor(0.5, 0.4, 0.8, 1)

    -- 標題
    local title = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
    title:SetText("|cff8882ffLunarUI 除錯|r")
    debugFrame.title = title

    -- 月相顯示
    local phaseText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    phaseText:SetPoint("TOPLEFT", 10, -25)
    debugFrame.phaseText = phaseText

    -- Token 顯示
    local tokensText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tokensText:SetPoint("TOPLEFT", 10, -45)
    debugFrame.tokensText = tokensText

    -- 計時器顯示
    local timerText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("TOPLEFT", 10, -75)
    debugFrame.timerText = timerText

    -- 戰鬥狀態
    local combatText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    combatText:SetPoint("TOPLEFT", 10, -95)
    debugFrame.combatText = combatText

    -- 更新腳本
    debugFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < updateInterval then return end
        elapsed = 0

        if not LunarUI.db or not LunarUI.db.profile.debug then
            self:Hide()
            return
        end

        local phase = LunarUI:GetPhase()
        local tokens = LunarUI:GetTokens()
        local icon = PHASE_ICONS[phase] or "?"

        -- 更新月相
        self.phaseText:SetText("月相: " .. icon .. " |cff8882ff" .. phase .. "|r")

        -- 更新 Token
        self.tokensText:SetText(string.format(
            "透明度: %.2f  縮放: %.2f",
            tokens.alpha or 0,
            tokens.scale or 0
        ))

        -- 更新計時器
        if phase == LunarUI.PHASES.WANING then
            local remaining = LunarUI:GetWaningTimeRemaining()
            self.timerText:SetText(string.format("下弦: %.1f 秒後結束", remaining))
            self.timerText:SetTextColor(1, 0.8, 0.3)
        else
            self.timerText:SetText("計時器: 閒置")
            self.timerText:SetTextColor(0.5, 0.5, 0.5)
        end

        -- 更新戰鬥狀態
        if InCombatLockdown() then
            self.combatText:SetText("戰鬥: |cffff0000戰鬥中|r")
        else
            self.combatText:SetText("戰鬥: |cff00ff00安全|r")
        end
    end)

    return debugFrame
end

--[[
    更新除錯面板可見性
]]
function LunarUI:UpdateDebugOverlay()
    if not debugFrame then
        debugFrame = CreateDebugFrame()
    end

    if self.db and self.db.profile.debug then
        debugFrame:Show()
    else
        debugFrame:Hide()
    end
end

--[[
    顯示除錯面板
]]
function LunarUI.ShowDebugOverlay()
    if not debugFrame then
        debugFrame = CreateDebugFrame()
    end
    debugFrame:Show()
end

--[[
    隱藏除錯面板
    清理 OnUpdate 腳本以節省資源
]]
function LunarUI.HideDebugOverlay()
    if debugFrame then
        debugFrame:SetScript("OnUpdate", nil)
        debugFrame:Hide()
    end
end
