---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 色彩與工具函數
    共用色彩定義與緩動函數
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 色彩配置
--------------------------------------------------------------------------------

LunarUI.Colors = {
    -- 背景
    bg        = { 0.05, 0.05, 0.05, 0.9 },
    bgSolid   = { 0.05, 0.05, 0.05, 0.95 },
    bgLight   = { 0.05, 0.05, 0.05, 0.85 },

    -- 邊框
    border       = { 0.15, 0.12, 0.08, 1 },
    borderSubtle = { 0.1, 0.1, 0.1, 1 },
    borderWarm   = { 0.25, 0.22, 0.18, 1 },
    borderGold   = { 0.4, 0.35, 0.2, 1 },

    -- 圖示/按鈕
    bgIcon        = { 0.1, 0.1, 0.1, 0.8 },
    bgButton      = { 0.15, 0.15, 0.15, 0.8 },
    bgButtonHover = { 0.2, 0.2, 0.2, 0.8 },
    borderIcon    = { 0.2, 0.2, 0.2, 1 },

    -- 文字
    textPrimary   = { 1, 1, 1, 1 },
    textSecondary = { 0.9, 0.9, 0.9, 1 },
    textMuted     = { 0.7, 0.7, 0.7, 1 },
    textDim       = { 0.6, 0.6, 0.6, 1 },
    textGold      = { 1, 0.82, 0, 1 },

    -- 功能色
    success = { 0.1, 1.0, 0.1, 1 },
    warning = { 1.0, 0.7, 0.0, 1 },
    danger  = { 1.0, 0.1, 0.1, 1 },
    info    = { 0.41, 0.8, 0.94, 1 },

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

    -- 覆蓋層
    bgOverlay       = { 0, 0, 0, 0.5 },

    -- HUD 元件（略帶藍紫色調）
    bgHUD           = { 0.05, 0.05, 0.08, 0.75 },
    borderHUD       = { 0.20, 0.18, 0.30, 0.9 },

    -- 互動/狀態
    highlightBlue   = { 0.4, 0.6, 0.8, 1 },
    stealableBorder = { 0.2, 0.6, 1.0, 1 },

    -- 月光主題
    moonSilver = { 0.75, 0.78, 0.85, 1 },
    nightPurple = { 0.25, 0.2, 0.4, 1 },
    starGold = { 0.9, 0.8, 0.5, 1 },
    lunarGlow = { 0.6, 0.7, 0.9, 0.5 },
}

--------------------------------------------------------------------------------
-- 緩動函數庫 (Easing Functions)
--------------------------------------------------------------------------------

--[[
    t: current time/progress (0-1)
    b: beginning value (usually 0)
    c: change in value (usually 1)
    d: duration (usually 1)
]]
LunarUI.Easing = {
    -- 線性
    Linear = function(t, b, c, d)
        return c * t / d + b
    end,
    -- 二次平滑輸入
    InQuad = function(t, b, c, d)
        t = t / d
        return c * t * t + b
    end,
    -- 二次平滑輸出
    OutQuad = function(t, b, c, d)
        t = t / d
        return -c * t * (t - 2) + b
    end,
    -- 二次平滑輸入輸出
    InOutQuad = function(t, b, c, d)
        t = t / (d / 2)
        if t < 1 then return c / 2 * t * t + b end
        t = t - 1
        return -c / 2 * (t * (t - 2) - 1) + b
    end,
}
