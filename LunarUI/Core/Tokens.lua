--[[
    LunarUI - 設計標記
    每個月相的視覺參數設定
]]

local ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 預設標記值
--------------------------------------------------------------------------------

local DEFAULT_TOKENS = {
    NEW = {
        alpha = 0.40,           -- 低可見度
        scale = 0.95,           -- 略微縮小
        contrast = 0.6,         -- 低對比
        glowIntensity = 0,      -- 無光暈
    },
    WAXING = {
        alpha = 0.65,           -- 逐漸增強
        scale = 0.98,           -- 接近全尺寸
        contrast = 0.8,         -- 中等對比
        glowIntensity = 0.3,    -- 微弱光暈
    },
    FULL = {
        alpha = 1.00,           -- 完全可見
        scale = 1.00,           -- 全尺寸
        contrast = 1.0,         -- 最大對比
        glowIntensity = 0.8,    -- 強烈光暈
    },
    WANING = {
        alpha = 0.75,           -- 漸弱
        scale = 0.98,           -- 略微縮小
        contrast = 0.85,        -- 維持良好對比
        glowIntensity = 0.4,    -- 減弱光暈
    },
}

--------------------------------------------------------------------------------
-- 色彩配置
--------------------------------------------------------------------------------

LunarUI.Colors = {
    -- 羊皮紙風格（手繪風）
    parchment = { 0.85, 0.78, 0.65, 0.95 },
    inkDark = { 0.15, 0.12, 0.08, 1 },
    inkFaded = { 0.4, 0.35, 0.25, 1 },

    -- 生命值/能量
    health = { 0.6, 0.1, 0.1, 1 },
    mana = { 0.2, 0.3, 0.5, 1 },
    energy = { 0.9, 0.8, 0.3, 1 },
    rage = { 0.8, 0.2, 0.2, 1 },
    focus = { 0.7, 0.5, 0.3, 1 },

    -- 月相主題
    moonSilver = { 0.75, 0.78, 0.85, 1 },
    nightPurple = { 0.25, 0.2, 0.4, 1 },
    starGold = { 0.9, 0.8, 0.5, 1 },
    lunarGlow = { 0.6, 0.7, 0.9, 0.5 },

    -- 介面元素
    border = { 0.1, 0.1, 0.1, 1 },
    backdrop = { 0.05, 0.05, 0.05, 0.9 },
}

-- 目前標記（根據月相更新）
LunarUI.tokens = {}

--------------------------------------------------------------------------------
-- 標記取得函數
--------------------------------------------------------------------------------

--[[
    取得指定月相的標記
    @param phase 月相名稱（NEW, WAXING, FULL, WANING）
    @return table 標記值
]]
function LunarUI:GetTokensForPhase(phase)
    local db = self.db and self.db.profile and self.db.profile.tokens
    if db and db[phase] then
        return db[phase]
    end
    return DEFAULT_TOKENS[phase] or DEFAULT_TOKENS.NEW
end

--[[
    取得目前月相的標記
    @return table 目前標記值
]]
function LunarUI:GetTokens()
    local phase = self:GetPhase()
    return self:GetTokensForPhase(phase)
end

--[[
    更新目前標記（月相變化時呼叫）
]]
function LunarUI:UpdateTokens()
    self.tokens = self:GetTokens()
end

--------------------------------------------------------------------------------
-- 標記應用函數
--------------------------------------------------------------------------------

--[[
    將標記套用至框架
    @param frame 要套用的框架
    @param tokens 指定的標記（可選）
]]
function LunarUI:ApplyTokensToFrame(frame, tokens)
    tokens = tokens or self:GetTokens()

    if not frame then return end
    if not tokens then return end

    -- 套用透明度（需型別檢查）
    if tokens.alpha and type(tokens.alpha) == "number" then
        frame:SetAlpha(tokens.alpha)
    end

    -- 套用縮放（需型別檢查）
    if tokens.scale and type(tokens.scale) == "number" then
        frame:SetScale(tokens.scale)
    end
end

--[[
    在兩組標記間進行插值（用於平滑過渡）
    @param from 起始標記
    @param to 目標標記
    @param progress 進度（0 至 1）
    @return table 插值後的標記
]]
function LunarUI:InterpolateTokens(from, to, progress)
    local result = {}

    -- 處理 from 為 nil 或空值的邊界情況
    from = from or {}
    to = to or {}

    for key, toValue in pairs(to) do
        -- 安全取得 from 值，若為 nil 則使用 toValue
        local fromValue = from[key]
        if fromValue == nil then
            fromValue = toValue
        end

        if type(toValue) == "number" and type(fromValue) == "number" then
            result[key] = fromValue + (toValue - fromValue) * progress
        else
            result[key] = toValue
        end
    end
    return result
end

-- 匯出預設值供資料庫使用
LunarUI.DEFAULT_TOKENS = DEFAULT_TOKENS
