---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local skins = {}       -- 已註冊的 skin 函數 { name = { event, func } }
local skinned = {}     -- 已套用的框架名稱（避免重複）

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
function LunarUI:SkinFrame(frame)
    if not frame then return end

    -- 隱藏暴雪 NineSlice 邊框
    if frame.NineSlice then frame.NineSlice:SetAlpha(0) end

    -- 移除原始裝飾材質
    StripTextures(frame)

    -- 建立 LunarUI 風格背景
    if not frame._lunarSkinBG then
        frame._lunarSkinBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame._lunarSkinBG:SetAllPoints()
        frame._lunarSkinBG:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    end

    local bg = self.backdropColors.background
    local border = self.backdropColors.border
    frame._lunarSkinBG:SetBackdrop(self.backdropTemplate)
    frame._lunarSkinBG:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame._lunarSkinBG:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

--- 替換按鈕樣式
function LunarUI.SkinButton(_self, btn)
    if not btn then return end

    StripTextures(btn)

    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end

    -- 建立按鈕背景
    if not btn._lunarSkinBG then
        btn._lunarSkinBG = btn:CreateTexture(nil, "BACKGROUND")
        btn._lunarSkinBG:SetAllPoints()
        btn._lunarSkinBG:SetColorTexture(0.15, 0.15, 0.15, 0.8)
    end

    -- 懸停高亮
    if not btn._lunarHighlight then
        btn._lunarHighlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn._lunarHighlight:SetAllPoints()
        btn._lunarHighlight:SetColorTexture(1, 1, 1, 0.1)
    end
end

--- 替換關閉按鈕
function LunarUI.SkinCloseButton(_self, btn)
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
        btn._lunarCloseText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
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
function LunarUI:SkinTab(tab)
    if not tab then return end

    StripTextures(tab)

    -- 底線指示器取代凸出分頁
    if not tab._lunarIndicator then
        tab._lunarIndicator = tab:CreateTexture(nil, "OVERLAY")
        tab._lunarIndicator:SetHeight(2)
        tab._lunarIndicator:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 0)
        tab._lunarIndicator:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
        local gold = self.backdropColors.borderGold
        tab._lunarIndicator:SetColorTexture(gold[1], gold[2], gold[3], gold[4] or 1)
    end
end

--- 替換捲軸條
function LunarUI.SkinScrollBar(_self, scrollBar)
    if not scrollBar then return end
    StripTextures(scrollBar)
end

--------------------------------------------------------------------------------
-- Skin Registry
--------------------------------------------------------------------------------

--- 註冊 skin（延遲載入）
function LunarUI.RegisterSkin(_self, name, loadEvent, skinFunc)
    skins[name] = { event = loadEvent, func = skinFunc }
end

--- 套用指定 skin
local function ApplySkin(name)
    if skinned[name] then return end
    local skin = skins[name]
    if not skin or not skin.func then return end

    local ok, _err = pcall(skin.func)
    if ok then
        skinned[name] = true
    else
        -- if LunarUI.DebugPrint then
        --     LunarUI:DebugPrint("Skin error [" .. name .. "]: " .. tostring(err))
        -- end
    end
end

--- 檢查指定 skin 是否啟用
local function IsSkinEnabled(db, name)
    return db and db.enabled and db.blizzard and db.blizzard[name] ~= false
end

--- 載入所有已註冊的 skin
local function LoadAllSkins()
    local db = LunarUI.db and LunarUI.db.profile.skins
    for name, skin in pairs(skins) do
        if IsSkinEnabled(db, name) and skin.event == "PLAYER_ENTERING_WORLD" then
            ApplySkin(name)
        end
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
    if not LunarUI._skinsEventFrame then
        LunarUI._skinsEventFrame = CreateFrame("Frame")
        LunarUI._skinsEventFrame:RegisterEvent("ADDON_LOADED")
        LunarUI._skinsEventFrame:SetScript("OnEvent", function(_self, event, ...)
            OnAddonLoaded(event, ...)
        end)
    end
end

-- 匯出
LunarUI.StripTextures = StripTextures
LunarUI.InitializeSkins = InitializeSkins

--- 標記框架已 skin 過，回傳 true 代表首次標記（應套用 skin）
function LunarUI.MarkSkinned(_self, frame)
    if not frame or frame._lunarSkinned then return false end
    frame._lunarSkinned = true
    return true
end

-- 清理
function LunarUI:CleanupSkins()
    if self._skinsEventFrame then
        self._skinsEventFrame:UnregisterAllEvents()
        self._skinsEventFrame:SetScript("OnEvent", nil)
    end
end

LunarUI:RegisterModule("Skins", {
    onEnable = InitializeSkins,
    onDisable = function() LunarUI:CleanupSkins() end,
    delay = 1.5,
})
