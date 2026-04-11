--[[
    LunarUI - 色彩與工具函數
    共用色彩定義與緩動函數
]]

local _, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 色彩配置
--------------------------------------------------------------------------------

LunarUI.Colors = {
    -- 背景
    bg = { 0.05, 0.05, 0.05, 0.9 },
    bgSolid = { 0.05, 0.05, 0.05, 0.95 },
    bgLight = { 0.05, 0.05, 0.05, 0.85 },

    -- 邊框
    border = { 0.15, 0.12, 0.08, 1 },
    borderSubtle = { 0.1, 0.1, 0.1, 1 },
    borderWarm = { 0.25, 0.22, 0.18, 1 },
    borderGold = { 0.4, 0.35, 0.2, 1 },

    -- 圖示/按鈕
    bgIcon = { 0.1, 0.1, 0.1, 0.8 },
    bgButtonHover = { 0.2, 0.2, 0.2, 0.8 },
    borderIcon = { 0.2, 0.2, 0.2, 1 },

    -- 文字
    textPrimary = { 1, 1, 1, 1 },
    textSecondary = { 0.9, 0.9, 0.9, 1 },
    textDim = { 0.6, 0.6, 0.6, 1 },

    -- 羊皮紙風格（手繪風）
    inkDark = { 0.15, 0.12, 0.08, 1 },

    -- 透明（backdrop 填充用）
    transparent = { 0, 0, 0, 0 },

    -- 覆蓋層
    bgOverlay = { 0, 0, 0, 0.5 },

    -- HUD 元件（略帶藍紫色調）
    bgHUD = { 0.05, 0.05, 0.08, 0.75 },
    borderHUD = { 0.20, 0.18, 0.30, 0.9 },

    -- 互動/狀態
    highlightBlue = { 0.4, 0.6, 0.8, 1 },
    stealableBorder = { 0.2, 0.6, 1.0, 1 },

    -- 月光主題
    moonSilver = { 0.75, 0.78, 0.85, 1 },
    accentPurple = { 0.53, 0.51, 1.0, 1 },
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
}

-- 圖示紋理座標（裁切邊緣 8%，消除毛邊）
LunarUI.ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }
