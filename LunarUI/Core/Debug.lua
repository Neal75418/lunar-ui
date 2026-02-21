---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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

--[[
    輸出警告訊息（始終輸出，不受 debug 開關影響）
    @param msg 要輸出的警告訊息
]]
function LunarUI:Warn(msg)
    self:Print("|cffff8800[警告]|r " .. tostring(msg))
end

--[[
    輸出錯誤訊息（始終輸出，不受 debug 開關影響）
    @param msg 要輸出的錯誤訊息
]]
function LunarUI:Error(msg)
    self:Print("|cffff0000[錯誤]|r " .. tostring(msg))
end

--------------------------------------------------------------------------------
-- 除錯面板
--------------------------------------------------------------------------------

local debugFrame = nil
local UPDATE_INTERVAL = 0.1 -- 更新間隔（秒）

--[[
    建立除錯面板
    重載時會重用現有框架以防止記憶體洩漏
]]
---@return Frame
local function CreateDebugFrame()
    if debugFrame then
        return debugFrame
    end

    -- 重載時重用現有框架
    local existingFrame = _G["LunarUIDebugFrame"]
    if existingFrame then
        debugFrame = existingFrame
        debugFrame:SetScript("OnUpdate", nil)
    else
        debugFrame = CreateFrame("Frame", "LunarUIDebugFrame", UIParent, "BackdropTemplate")
    end

    debugFrame:SetSize(200, 80)
    debugFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -200)
    debugFrame:SetFrameStrata("HIGH")
    debugFrame:SetMovable(true)
    debugFrame:EnableMouse(true)
    debugFrame:RegisterForDrag("LeftButton")
    debugFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    debugFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

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

    -- FPS/記憶體顯示
    local perfText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    perfText:SetPoint("TOPLEFT", 10, -25)
    debugFrame.perfText = perfText

    -- 戰鬥狀態
    local combatText = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    combatText:SetPoint("TOPLEFT", 10, -45)
    debugFrame.combatText = combatText

    debugFrame.elapsed = 0

    -- 更新腳本
    debugFrame:SetScript("OnUpdate", function(self, delta)
        self.elapsed = (self.elapsed or 0) + delta
        if self.elapsed < UPDATE_INTERVAL then
            return
        end
        self.elapsed = 0

        if not LunarUI.db or not LunarUI.db.profile or not LunarUI.db.profile.debug then
            self:Hide()
            return
        end

        -- FPS/記憶體
        local fps = GetFramerate()
        local mem = collectgarbage("count") / 1024
        self.perfText:SetText(string.format("FPS: %.0f  記憶體: %.1f MB", fps, mem))

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
function LunarUI.UpdateDebugOverlay()
    local frame = CreateDebugFrame()

    if LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.debug then
        frame:Show()
    else
        frame:Hide()
    end
end

--[[
    顯示除錯面板
]]
function LunarUI.ShowDebugOverlay()
    local frame = CreateDebugFrame()
    frame:Show()
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
