---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 資料庫預設值
    AceDB defaults 表定義
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 資料庫預設值
--------------------------------------------------------------------------------

local defaults = {
    profile = {
        -- 一般設定
        enabled = true,
        debug = false,

        -- 單位框架設定
        unitframes = {
            player = {
                enabled = true,
                width = 220,
                height = 45,
                x = -300,
                y = -200,
                point = "CENTER",
                showBuffs = false,
                buffSize = 22,
                maxBuffs = 16,
                showDebuffs = false,
                debuffSize = 22,
                maxDebuffs = 8,
                onlyPlayerDebuffs = false,
                showClassPower = true,       -- 職業資源（連擊點/聖能/符文等）
                showHealPrediction = true,   -- 治療預測條
            },
            target = {
                enabled = true,
                width = 220,
                height = 45,
                x = 300,
                y = -200,
                point = "CENTER",
                showBuffs = false,
                buffSize = 22,
                maxBuffs = 8,
                showDebuffs = true,
                debuffSize = 22,
                maxDebuffs = 16,
                onlyPlayerDebuffs = false,
            },
            focus = {
                enabled = true,
                width = 180,
                height = 35,
                x = -450,
                y = -100,
                point = "CENTER",
                showBuffs = false,
                buffSize = 20,
                maxBuffs = 8,
                showDebuffs = true,
                debuffSize = 20,
                maxDebuffs = 8,
                onlyPlayerDebuffs = false,
            },
            pet = {
                enabled = true,
                width = 120,
                height = 25,
                x = -300,
                y = -260,
                point = "CENTER",
            },
            targettarget = {
                enabled = true,
                width = 120,
                height = 25,
                x = 450,
                y = -200,
                point = "CENTER",
            },
            party = {
                enabled = true,
                width = 150,
                height = 35,
                x = -500,
                y = 0,
                point = "LEFT",
                spacing = 5,
                showBuffs = false,
                buffSize = 18,
                maxBuffs = 4,
                showDebuffs = true,
                debuffSize = 18,
                maxDebuffs = 4,
                onlyPlayerDebuffs = true,
                showHealPrediction = true,   -- 治療預測條
            },
            raid = {
                enabled = true,
                width = 80,
                height = 30,
                x = 20,
                y = -20,
                point = "TOPLEFT",
                spacing = 3,
                showBuffs = false,
                buffSize = 16,
                maxBuffs = 0,
                showDebuffs = true,
                debuffSize = 16,
                maxDebuffs = 2,
                onlyPlayerDebuffs = true,
                showHealPrediction = true,   -- 治療預測條
            },
            boss = {
                enabled = true,
                width = 180,
                height = 40,
                x = -100,
                y = 300,
                point = "RIGHT",
                spacing = 50,
                showBuffs = false,
                buffSize = 20,
                maxBuffs = 4,
                showDebuffs = true,
                debuffSize = 20,
                maxDebuffs = 8,
                onlyPlayerDebuffs = false,
            },
        },

        -- 名牌設定
        nameplates = {
            enabled = true,  -- LunarUI 名牌（設為 false 使用暴雪預設）
            width = 120,
            height = 8,
            showHealthText = true,             -- ★ 顯示生命值文字
            healthTextFormat = "percent",      -- ★ "percent" / "current" / "both"
            stackingDetection = false,         -- ★ 堆疊偵測（偏移重疊名牌）
            -- 敵方名牌
            enemy = {
                enabled = true,
                showHealth = true,
                showCastbar = true,
                showAuras = true,
                auraSize = 18,
                maxAuras = 5,
                showBuffs = false,             -- ★ 顯示敵方可竊取 Buff
                buffSize = 14,                 -- ★ Buff 圖示大小
                maxBuffs = 4,                  -- ★ 最大 Buff 顯示數量
                showLevel = true,              -- ★ 顯示等級文字
                showQuestIcon = true,          -- ★ 任務目標高亮圖示
            },
            -- 友方名牌
            friendly = {
                enabled = true,
                showHealth = true,
                showCastbar = false,
                showAuras = false,
                showLevel = false,             -- ★ 顯示等級文字（友方預設關閉）
            },
            -- 仇恨顏色
            threat = {
                enabled = true,
            },
            -- 重要目標高亮
            highlight = {
                rare = true,
                elite = true,
                boss = true,
            },
            -- 分類圖示
            classification = {
                enabled = true,
            },
        },

        -- 動作條設定
        actionbars = {
            enabled = true,  -- LunarUI 動作條（設為 false 使用暴雪預設）
            unlocked = false,  -- 解鎖拖曳
            buttonSize = 36,  -- 全域按鈕大小
            buttonSpacing = 4,  -- 按鈕間距
            showHotkeys = true,  -- 顯示快捷鍵
            showMacroNames = false,  -- 顯示巨集名稱
            alpha = 1.0,  -- 透明度
            outOfRangeColoring = true,  -- 技能超出距離時按鈕變紅
            extraActionButton = true,  -- 樣式化 ExtraActionButton
            fadeEnabled = true,   -- 非戰鬥淡出
            fadeAlpha = 0.3,      -- 淡出後透明度
            fadeDelay = 2.0,      -- 離開戰鬥後淡出延遲（秒）
            fadeDuration = 0.4,   -- 淡入淡出動畫時間（秒）
            bar1 = { enabled = true, buttons = 12, x = 0, y = 100, orientation = "horizontal", fadeEnabled = nil },
            bar2 = { enabled = true, buttons = 12, x = 0, y = 144, orientation = "horizontal", fadeEnabled = nil },
            bar3 = { enabled = true, buttons = 12, x = 250, y = 300, orientation = "vertical", fadeEnabled = nil },
            bar4 = { enabled = true, buttons = 12, x = -250, y = 300, orientation = "vertical", fadeEnabled = nil },
            bar5 = { enabled = true, buttons = 12, x = 0, y = 276, orientation = "horizontal", fadeEnabled = nil },
            bar6 = { enabled = true, buttons = 12, x = 0, y = 320, orientation = "horizontal", fadeEnabled = nil },
            petbar = { enabled = true, x = 0, y = 60, fadeEnabled = nil },
            stancebar = { enabled = true, x = -400, y = 200, fadeEnabled = nil },
            microBar = {
                enabled = true,
                buttonWidth = 28,
                buttonHeight = 36,
                point = "BOTTOMRIGHT",
                x = -2,
                y = 2,
            },
        },

        -- 光環過濾
        auraWhitelist = "",   -- 逗號分隔的 spell ID，這些 aura 永遠顯示
        auraBlacklist = "",   -- 逗號分隔的 spell ID，這些 aura 永遠隱藏

        -- 自動化 QoL
        automation = {
            autoRepair = true,
            useGuildRepair = true,
            autoRelease = false,     -- 戰場自動釋放（預設關閉，避免意外）
            autoScreenshot = false,  -- 成就截圖（預設關閉）
        },

        -- 小地圖設定
        minimap = {
            enabled = true,
            size = 180,
            showCoords = true,
            showClock = true,
            clockFormat = "24h",            -- "12h" / "24h"
            organizeButtons = true,

            -- 區域文字
            zoneTextDisplay = "SHOW",       -- "SHOW" / "MOUSEOVER" / "HIDE"
            zoneFontSize = 12,
            zoneFontOutline = "OUTLINE",    -- "NONE" / "OUTLINE" / "THICKOUTLINE" / "MONOCHROMEOUTLINE"
            coordFontSize = 10,
            coordFontOutline = "OUTLINE",

            -- 外觀
            borderColor = { r = 0.15, g = 0.12, b = 0.08, a = 1 },

            -- 行為
            resetZoomTimer = 0,             -- 0=停用, 1-15 秒
            fadeOnMouseLeave = false,
            fadeAlpha = 0.5,
            fadeDuration = 0.3,
            pinScale = 1.0,                 -- 0.5-2.0

            -- 每個圖示獨立設定
            icons = {
                calendar    = { hide = false, position = "TOPRIGHT",    scale = 1.0, xOffset = -22, yOffset = -2 },
                tracking    = { hide = false, position = "TOPRIGHT",    scale = 1.0, xOffset = -2,  yOffset = -2 },
                mail        = { hide = false, position = "BOTTOMLEFT",  scale = 1.0, xOffset = 4,   yOffset = 4 },
                difficulty  = { hide = false, position = "TOPLEFT",     scale = 1.0, xOffset = 4,   yOffset = -4 },
                lfg         = { hide = false, position = "BOTTOMRIGHT", scale = 1.0, xOffset = -2,  yOffset = 2 },
                expansion   = { hide = false, position = "TOPLEFT",     scale = 1.0, xOffset = -4,  yOffset = 4 },
                compartment = { hide = false, position = "TOPRIGHT",    scale = 1.0, xOffset = -2,  yOffset = -20 },
            },
        },

        -- 背包設定
        bags = {
            enabled = true,
            slotsPerRow = 12,
            slotSize = 37,
            slotSpacing = 4,
            autoSellJunk = true,
            showItemLevel = true,
            showQuestItems = true,
            showProfessionColors = true,  -- 專業容器背景著色
            showUpgradeArrow = true,      -- 裝等升級綠色箭頭
            showBindType = true,          -- 顯示 BoE/BoP 綁定文字
            showCooldown = true,          -- 顯示物品冷卻
            showNewGlow = false,          -- 新物品發光提示（預設關閉，需手動啟用）
            ilvlThreshold = 1,            -- 物品等級最低顯示門檻
            reverseBagSlots = false,      -- 反轉格子順序
            clearSearchOnClose = true,    -- 關閉時清除搜尋
            frameAlpha = 0.95,            -- 框架背景透明度
            splitBags = false,            -- 分離背包視圖
            bagPosition = nil,            -- 背包框架位置 { point, x, y }
            bankPosition = nil,           -- 銀行框架位置 { point, x, y }
        },

        -- 聊天設定
        chat = {
            enabled = true,
            width = 400,
            height = 180,
            improvedColors = true,
            classColors = true,
            fadeTime = 120,
            detectURLs = true,          -- 啟用可點擊網址
            shortChannelNames = true,   -- 短頻道名稱
            enableEmojis = true,        -- 表情符號替換
            showRoleIcons = true,       -- 角色圖示（坦/治/傷）
            keywordAlerts = true,       -- 關鍵字警報
            keywords = {},              -- 自訂關鍵字列表
            spamFilter = true,          -- 垃圾訊息過濾
            linkTooltipPreview = true,  -- 連結懸停 Tooltip 預覽
            showTimestamps = false,     -- 時間戳記
            timestampFormat = "%H:%M",  -- 時間戳記格式
        },

        -- 滑鼠提示設定
        tooltip = {
            enabled = true,
            anchorCursor = false,
            showItemLevel = true,
            showItemID = false,
            showSpellID = false,
            showTargetTarget = true,
            showItemCount = false,      -- 物品持有數量
        },

        -- 資料條設定
        databars = {
            enabled = true,
            experience = {
                enabled = true,
                width = 476,
                height = 8,
                showText = true,
                textFormat = "percent",  -- "percent" / "curmax" / "cur" / "remaining"
                point = "BOTTOM",
                x = 0, y = 24,
            },
            reputation = {
                enabled = true,
                width = 476,
                height = 8,
                showText = true,
                textFormat = "percent",
                point = "BOTTOM",
                x = 0, y = 34,
            },
            honor = {
                enabled = false,
                width = 476,
                height = 8,
                showText = true,
                textFormat = "percent",
                point = "BOTTOM",
                x = 0, y = 44,
            },
        },

        -- 資料文字設定
        datatexts = {
            enabled = true,
            panels = {
                bottom = {
                    enabled = true,
                    width = 476,
                    height = 22,
                    numSlots = 3,
                    point = "BOTTOM",
                    x = 0, y = 0,
                    slots = { "durability", "gold", "bagSlots" },
                },
                minimapBottom = {
                    enabled = false,
                    width = 180,
                    height = 20,
                    numSlots = 2,
                    point = "BOTTOM",
                    x = 0, y = 0,
                    slots = { "fps", "latency" },
                },
            },
        },

        -- HUD 設定
        hud = {
            scale = 1.0,                -- 全域 HUD 縮放（0.5-2.0，參考 GW2 UI）
            performanceMonitor = true,  -- FPS/延遲顯示
            classResources = true,      -- 職業資源條
            cooldownTracker = true,     -- 冷卻追蹤器
            auraFrames = true,          -- 獨立 Buff/Debuff 框架

            -- AuraFrames 設定
            auraIconSize = 30,
            auraIconSpacing = 4,
            auraIconsPerRow = 8,
            maxBuffs = 16,
            maxDebuffs = 8,
            auraBarHeight = 4,

            -- CooldownTracker 設定
            cdIconSize = 36,
            cdIconSpacing = 4,
            cdMaxIcons = 8,

            -- ClassResources 設定
            crIconSize = 26,
            crIconSpacing = 4,
            crBarHeight = 10,
        },

        -- 框架移動器
        frameMover = {
            gridSize = 10,
            moverAlpha = 0.6,
        },

        -- 拾取視窗
        loot = {
            enabled = true,
        },

        -- Skins 設定（暴雪框架重新造型）
        skins = {
            enabled = false,  -- v0.8 再啟用，目前 SkinFrame 對 Blizzard 框架的換膚尚不完整
            blizzard = {
                character = true,
                spellbook = true,
                talents = true,
                quest = true,
                merchant = true,
                gossip = true,
                worldmap = true,
                achievements = true,
                mail = true,
                collections = true,
                lfg = true,
                encounterjournal = true,
                auctionhouse = true,
                communities = true,
            },
        },

        -- 視覺風格
        style = {
            theme = "lunar",  -- lunar, parchment, minimal
            font = "Friz Quadrata TT",  -- LSM font name
            fontSize = 12,
            statusBarTexture = "Blizzard",  -- LSM statusbar name
            borderStyle = "ink",  -- ink, clean, none
        },
    },

    global = {
        version = nil,
        installComplete = false,
        installVersion = nil,
    },

    char = {
        -- 角色專屬設定
        specProfiles = {},  -- 專精自動切換設定檔 [specIndex] = "profileName"
    },
}

-- 掛載到 LunarUI 供 Config.lua 使用
LunarUI._defaults = defaults
