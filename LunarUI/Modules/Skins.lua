---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skins Engine
    Unified Blizzard UI frame restyling system

    Features:
    - Core skin utilities (SkinFrame, SkinButton, SkinCloseButton, SkinTab)
    - Registry for per-frame skins with lazy loading
    - StripTextures helper to remove default decorations
    - Integrates with LunarUI backdropTemplate + colors
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local _L = Engine.L or {}
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local skins = {}       -- 已註冊的 skin 函數 { name = { event, func } }
local skinned = {}     -- 已套用的框架名稱（避免重複）
local skinsEventFrame  -- 私有事件框架（不暴露到 LunarUI 物件）

--------------------------------------------------------------------------------
-- Strip Textures Helper
--------------------------------------------------------------------------------

-- Fix 4: 用 select 安全遍歷，避免 ipairs 在 nil gap 中斷
local function StripTextures(frame)
    if not frame or not frame.GetRegions then return end
    local n = select("#", frame:GetRegions())
    if n == 0 then return end
    local regions = { frame:GetRegions() }
    for i = 1, n do
        local region = regions[i]
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local drawLayer = region:GetDrawLayer()
            if drawLayer == "BACKGROUND" or drawLayer == "BORDER" or drawLayer == "ARTWORK" then
                region:SetAlpha(0)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Core Skin Utilities
--------------------------------------------------------------------------------

--- 替換框架背景為 LunarUI 風格
function LunarUI:SkinFrame(frame, options)
    if not frame or not frame.GetObjectType then return end
    options = options or {}

    -- 隱藏暴雪 NineSlice 邊框
    if frame.NineSlice then frame.NineSlice:SetAlpha(0) end

    -- 移除原始裝飾材質（noStrip = true 時跳過，保留羊皮紙等內容背景）
    if not options.noStrip then
        StripTextures(frame)
    end

    -- 建立 LunarUI 風格背景
    if not frame._lunarSkinBG then
        frame._lunarSkinBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame._lunarSkinBG:SetAllPoints()
        frame._lunarSkinBG:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    end

    LunarUI.ApplyBackdrop(frame._lunarSkinBG)

    -- 修復文字顏色（暗黑風格：白色文字）
    if options.fixText ~= false then
        self:SkinFrameText(frame, options.textDepth or 2)
    end
end

--- 修復框架內的文字顏色（解決黑底黑字問題）
-- @param frame 目標框架
-- @param depth 遞迴深度限制（預設 2，避免過度遍歷影響效能）
-- @param currentDepth 當前深度（內部使用）
function LunarUI:SkinFrameText(frame, depth, currentDepth)
    if not frame or not frame.GetRegions then return end
    depth = depth or 2
    currentDepth = currentDepth or 0

    -- 遍歷框架的所有 region（包含 FontString）
    local n = select("#", frame:GetRegions())
    if n > 0 then
        local regions = { frame:GetRegions() }
        for i = 1, n do
            local region = regions[i]
            if region and region.IsObjectType and region:IsObjectType("FontString") then
                -- 只修復近黑色文字（閾值 0.3），避免誤改暴雪故意使用的中灰色/陰影文字
                local r, g, b = region:GetTextColor()
                if r and r < 0.3 and g < 0.3 and b < 0.3 then
                    region:SetTextColor(1, 1, 1, 1)
                end
            end
        end
    end

    -- 遞迴處理子框架（有深度限制）
    -- 使用 select("#", ...) 安全遍歷，避免 ipairs 在 nil gap 時停止
    if currentDepth < depth then
        local childCount = select("#", frame:GetChildren())
        if childCount > 0 then
            local children = { frame:GetChildren() }
            for i = 1, childCount do
                local child = children[i]
                -- 跳過已有 LunarUI 處理過的框架
                if child and not child._lunarSkinBG then
                    self:SkinFrameText(child, depth, currentDepth + 1)
                end
            end
        end
    end
end

--- 設定 FontString 為亮色（用於單獨處理特定文字）
function LunarUI.SetFontLight(fontString)
    if fontString and fontString.SetTextColor then
        fontString:SetTextColor(1, 1, 1, 1)
    end
end

--- 設定 FontString 為次要顏色（灰白色）
function LunarUI.SetFontSecondary(fontString)
    if fontString and fontString.SetTextColor then
        fontString:SetTextColor(0.9, 0.9, 0.9, 1)
    end
end

--- 設定 FontString 為柔和顏色（用於次要資訊）
function LunarUI.SetFontMuted(fontString)
    if fontString and fontString.SetTextColor then
        fontString:SetTextColor(0.7, 0.7, 0.7, 1)
    end
end

--- 替換按鈕樣式
function LunarUI.SkinButton(btn)
    if not btn then return end

    StripTextures(btn)

    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end

    -- 建立按鈕背景
    if not btn._lunarSkinBG then
        btn._lunarSkinBG = btn:CreateTexture(nil, "BACKGROUND")
        btn._lunarSkinBG:SetAllPoints()
        btn._lunarSkinBG:SetColorTexture(C.bgButton[1], C.bgButton[2], C.bgButton[3], C.bgButton[4])
    end

    -- 懸停高亮
    if not btn._lunarHighlight then
        btn._lunarHighlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn._lunarHighlight:SetAllPoints()
        btn._lunarHighlight:SetColorTexture(1, 1, 1, 0.1)
    end
end

--- 替換關閉按鈕
function LunarUI.SkinCloseButton(btn)
    if not btn then return end

    StripTextures(btn)
    btn:SetSize(18, 18)

    -- 自訂關閉按鈕外觀
    if not btn._lunarCloseBG then
        btn._lunarCloseBG = btn:CreateTexture(nil, "BACKGROUND")
        btn._lunarCloseBG:SetAllPoints()
        btn._lunarCloseBG:SetColorTexture(0.5, 0.1, 0.1, 0.8)
    end

    -- 「X」文字
    if not btn._lunarCloseText then
        btn._lunarCloseText = btn:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(btn._lunarCloseText, 12, "OUTLINE")
        btn._lunarCloseText:SetPoint("CENTER", 0, 0)
        btn._lunarCloseText:SetText("×")
        btn._lunarCloseText:SetTextColor(1, 1, 1, 1)
    end

    -- 懸停高亮
    if not btn._lunarHighlight then
        btn._lunarHighlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn._lunarHighlight:SetAllPoints()
        btn._lunarHighlight:SetColorTexture(0.8, 0.2, 0.2, 0.3)
    end

    -- 清除原始材質
    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end
    if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
end

--- 替換分頁按鈕（底線指示器風格）
function LunarUI.SkinTab(tab)
    if not tab then return end

    StripTextures(tab)

    -- 底線指示器取代凸出分頁
    if not tab._lunarIndicator then
        tab._lunarIndicator = tab:CreateTexture(nil, "OVERLAY")
        tab._lunarIndicator:SetHeight(2)
        tab._lunarIndicator:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 0)
        tab._lunarIndicator:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
        tab._lunarIndicator:SetColorTexture(C.borderGold[1], C.borderGold[2], C.borderGold[3], C.borderGold[4])
    end
end

--- 標準框架 Skin 工廠：處理共用的 SkinFrame + TitleText + CloseButton + Tabs 流程
---@param frameName string|Frame 全域框架名稱或框架引用
---@param options? table 可選設定
---@return string|Frame|nil frame 框架引用；找不到框架時回傳 nil
function LunarUI:SkinStandardFrame(frameName, options)
    local frame = type(frameName) == "string" and _G[frameName] or frameName
    if not frame or not frame.GetObjectType then return nil end
    options = options or {}

    self:SkinFrame(frame, { textDepth = options.textDepth or 3, noStrip = options.noStrip })

    if frame.TitleText then
        LunarUI.SetFontLight(frame.TitleText)
    end

    if frame.CloseButton then
        LunarUI.SkinCloseButton(frame.CloseButton)
    end

    if options.tabPrefix then
        for i = 1, (options.tabCount or 10) do
            local tab = _G[options.tabPrefix .. i]
            if tab then
                LunarUI.SkinTab(tab)
                if tab.Text then LunarUI.SetFontLight(tab.Text) end
            end
        end
    elseif options.tabProperty then
        local tabs = frame[options.tabProperty]
        if tabs then
            for _, tab in pairs(tabs) do
                LunarUI.SkinTab(tab)
                if tab.Text then LunarUI.SetFontLight(tab.Text) end
            end
        end
    elseif options.useTabSystem then
        if frame.TabSystem and frame.TabSystem.tabs then
            for _, tab in ipairs(frame.TabSystem.tabs) do
                LunarUI.SkinTab(tab)
                if tab.Text then LunarUI.SetFontLight(tab.Text) end
            end
        end
    end

    return frame
end

--- 替換捲軸條
function LunarUI.SkinScrollBar(scrollBar)
    if not scrollBar then return end
    StripTextures(scrollBar)
end

--- 替換編輯框樣式
function LunarUI.SkinEditBox(editBox)
    if not editBox then return end

    StripTextures(editBox)

    -- 建立背景
    if not editBox._lunarSkinBG then
        editBox._lunarSkinBG = editBox:CreateTexture(nil, "BACKGROUND")
        editBox._lunarSkinBG:SetAllPoints()
        editBox._lunarSkinBG:SetColorTexture(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    end

    -- 修復文字顏色
    if editBox.SetTextColor then
        editBox:SetTextColor(1, 1, 1, 1)
    end
end

--------------------------------------------------------------------------------
-- Skin Registry
--------------------------------------------------------------------------------

--- 註冊 skin（延遲載入）
function LunarUI.RegisterSkin(name, loadEvent, skinFunc)
    skins[name] = { event = loadEvent, func = skinFunc }
end

--- 套用指定 skin
local function ApplySkin(name)
    if skinned[name] then return end
    local skin = skins[name]
    if not skin or not skin.func then return end

    local ok, result = pcall(skin.func)
    if not ok then
        if LunarUI.Debug then
            LunarUI:Debug("Skin error [" .. name .. "]: " .. tostring(result))
        end
    elseif result then
        skinned[name] = true
    end
end

--- 檢查指定 skin 是否啟用
local function IsSkinEnabled(db, name)
    return db and db.enabled and db.blizzard and db.blizzard[name] ~= false
end

--- 載入所有已註冊的 skin
local function LoadAllSkins()
    local db = LunarUI.db and LunarUI.db.profile.skins
    local retryList = {}
    for name, skin in pairs(skins) do
        if IsSkinEnabled(db, name) and skin.event == "PLAYER_ENTERING_WORLD" then
            ApplySkin(name)
            if not skinned[name] then
                retryList[#retryList + 1] = name
            end
        end
    end
    -- 延遲重試失敗的 skins（等待 frame 建立完成）
    if #retryList > 0 then
        C_Timer.After(3.0, function()
            local retryDb = LunarUI.db and LunarUI.db.profile.skins
            for _, name in ipairs(retryList) do
                if not skinned[name] and IsSkinEnabled(retryDb, name) then
                    ApplySkin(name)
                end
            end
        end)
    end
end

--- 處理延遲載入的 skin（透過 ADDON_LOADED）
local function OnAddonLoaded(_event, addonName)
    local db = LunarUI.db and LunarUI.db.profile.skins
    for name, skin in pairs(skins) do
        if not skinned[name] and skin.event == addonName and IsSkinEnabled(db, name) then
            ApplySkin(name)
        end
    end
end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------

local function InitializeSkins()
    local db = LunarUI.db and LunarUI.db.profile.skins
    if not db or not db.enabled then return end

    -- 載入立即可用的 skins
    LoadAllSkins()

    -- 監聽延遲載入的 addon
    if not skinsEventFrame then
        skinsEventFrame = CreateFrame("Frame")
        skinsEventFrame:RegisterEvent("ADDON_LOADED")
        skinsEventFrame:SetScript("OnEvent", function(_self, event, ...)
            OnAddonLoaded(event, ...)
        end)
    end
end

-- 匯出
LunarUI.StripTextures = StripTextures
LunarUI.InitializeSkins = InitializeSkins

--- 標記框架已 skin 過，回傳 true 代表首次標記（應套用 skin）
function LunarUI.MarkSkinned(frame)
    if not frame or frame._lunarSkinned then return false end
    frame._lunarSkinned = true
    return true
end

-- 清理
function LunarUI.CleanupSkins()
    if skinsEventFrame then
        skinsEventFrame:UnregisterAllEvents()
        skinsEventFrame:SetScript("OnEvent", nil)
    end
end

LunarUI:RegisterModule("Skins", {
    onEnable = InitializeSkins,
    onDisable = function() LunarUI.CleanupSkins() end,
    delay = 1.5,
})
