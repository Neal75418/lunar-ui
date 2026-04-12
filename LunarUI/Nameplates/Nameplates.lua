---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, unused-local
--[[
    LunarUI - 名牌系統
    基於 oUF 的名牌系統，支援月相感知

    功能：
    - 敵方名牌：血量、施法條、減益效果
    - 友方名牌（簡化版）
    - 月相感知透明度（新月相時淡出）
    - 重要目標高亮（稀有、精英、Boss）
    - 大量拉怪效能最佳化
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors

-- 效能：快取全域變數（PostUpdate / GetNPCRoleColor / Nameplate_OnShow hot path）
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitIsTapDenied = UnitIsTapDenied
local UnitReaction = UnitReaction
local UnitClassification = UnitClassification
local UnitPowerType = UnitPowerType
local C_QuestLog = C_QuestLog
local mathFloor = math.floor
local format = string.format

-- 等待 oUF
-- oUF 透過 TOC 的 X-oUF 標頭以 LunarUF 命名空間暴露
local oUF = Engine.oUF or LunarUF or _G.oUF
if not oUF then
    return
end

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local statusBarTexture -- 延遲載入：DB 就緒後解析
local npCombatWaitFrame -- 戰鬥等待框架（singleton，避免重複呼叫建立多個 frame）
local nameplateDriverSpawned = false -- oUF:SpawnNamePlates 是 singleton，只能呼叫一次
local nameplateModuleEnabled = false -- runtime 啟用旗標（OnShow hook 用此判斷是否處理名牌）
local function GetStatusBarTexture()
    if not statusBarTexture then
        statusBarTexture = LunarUI.GetSelectedStatusBarTexture()
    end
    return statusBarTexture
end

-- 串聯 Layout.lua 的 statusBarTexture 失效函數，確保 Options 更換材質時名牌也同步清除
do
    local _prev = LunarUI.InvalidateStatusBarTextureCache
    LunarUI.InvalidateStatusBarTextureCache = function()
        statusBarTexture = nil
        if _prev then
            _prev()
        end
    end
end

-- 共用顏色常數（定義於 Core/Media.lua）
local CASTBAR_COLOR = LunarUI.CASTBAR_COLOR
local BG_DARKEN = LunarUI.BG_DARKEN

-- 分類顏色
local CLASSIFICATION_COLORS = {
    worldboss = { r = 1.0, g = 0.2, b = 0.2 },
    rareelite = { r = 1.0, g = 0.5, b = 0.0 },
    elite = { r = 1.0, g = 0.8, b = 0.0 },
    rare = { r = 0.7, g = 0.7, b = 1.0 },
    normal = { r = 0.5, g = 0.5, b = 0.5 },
    trivial = { r = 0.3, g = 0.3, b = 0.3 },
}

-- NPC 角色分類色（Caster / Miniboss）
local NPC_ROLE_COLORS = {
    caster = { r = 0.55, g = 0.35, b = 0.85 }, -- 紫色（施法者）
    miniboss = { r = 0.8, g = 0.6, b = 0.2 }, -- 金色（精英/小Boss）
}

-- classification 為可選參數，由呼叫端傳入已計算的值以避免重複呼叫 UnitClassification
local function GetNPCRoleColor(unit, db, classification)
    if not unit or UnitIsPlayer(unit) then
        return nil
    end
    local npcDb = db and db.npcColors
    if not npcDb or not npcDb.enabled then
        return nil
    end

    if not classification then
        classification = UnitClassification(unit)
    end
    if classification == "worldboss" or classification == "elite" or classification == "rareelite" then
        return npcDb.miniboss or NPC_ROLE_COLORS.miniboss
    end

    local powerType = UnitPowerType(unit)
    if powerType == 0 then -- Mana = 施法者
        return npcDb.caster or NPC_ROLE_COLORS.caster
    end

    return nil -- 近戰：保持預設反應色
end

-- P4 效能：命名函式供 pcall 呼叫，避免每次 FilterAura 建新 closure
local function CheckIsPlayerAura(data)
    return data.isPlayerAura == true
end
local function CheckIsStealable(data)
    return data.isStealable == true
end

-- cachedDebuffDefaultColor 在 DEBUFF_TYPE_COLORS 定義後初始化（見下方）
local cachedDebuffDefaultColor

local function NameplateDebuffFilterAura(_element, _unit, data)
    local ok, val = pcall(CheckIsPlayerAura, data)
    return ok and val
end

local function NameplateDebuffPostUpdate(_self, button, _unit, _data, _position)
    if button.SetBackdropBorderColor then
        if cachedDebuffDefaultColor then
            button:SetBackdropBorderColor(
                cachedDebuffDefaultColor.r,
                cachedDebuffDefaultColor.g,
                cachedDebuffDefaultColor.b,
                1
            )
        else
            button:SetBackdropBorderColor(0.8, 0, 0, 1)
        end
    end
end

local function NameplateBuffFilterAura(_element, _unit, data)
    local ok, val = pcall(CheckIsStealable, data)
    return ok and val
end

local function NameplateBuffPostUpdate(_self, button, _unit, _data, _position)
    if button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(
            C.stealableBorder[1],
            C.stealableBorder[2],
            C.stealableBorder[3],
            C.stealableBorder[4]
        )
    end
end

local DEBUFF_TYPE_COLORS = LunarUI.DEBUFF_TYPE_COLORS or _G.DebuffTypeColor or {}
cachedDebuffDefaultColor = DEBUFF_TYPE_COLORS[""] or DEBUFF_TYPE_COLORS["none"]

-- P1-perf: 快取名牌尺寸供 Nameplate_OnShow 使用（在 StartStackingDetection 中更新）
local cachedNpWidth = 120
local cachedNpHeight = 12

-- 私有事件框架（不暴露到 LunarUI 物件）
local nameplateTargetFrame
local nameplateQuestFrame

-- 前向宣告：堆疊偵測髒旗標函數
---@type function
local MarkStackingDirty

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function CreateBackdrop(frame)
    return LunarUI.CreateBackdrop(frame, { inset = 1, borderColor = C.borderSubtle })
end

local function GetUnitClassification(unit)
    local classification = UnitClassification(unit)
    return classification or "normal"
end

--------------------------------------------------------------------------------
-- 名牌元素
--------------------------------------------------------------------------------

--[[ Health Bar ]]
local function CreateHealthBar(frame)
    local db = LunarUI.GetModuleDB("nameplates")

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetStatusBarTexture(GetStatusBarTexture())
    health:SetAllPoints()

    -- 職業顏色優先，NPC 用反應顏色（與 UnitFrames 一致）
    health.colorClass = true
    health.colorReaction = true
    health.colorTapping = true
    health.colorDisconnected = true

    -- 背景
    health.bg = health:CreateTexture(nil, "BACKGROUND")
    health.bg:SetAllPoints()
    health.bg:SetTexture(GetStatusBarTexture())
    health.bg:SetVertexColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
    health.bg.multiplier = BG_DARKEN

    -- 高頻更新
    health.frequentUpdates = true

    -- 血量文字覆蓋
    local healthText
    if db and db.showHealthText then
        healthText = health:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(healthText, 7, "OUTLINE")
        healthText:SetPoint("RIGHT", health, "RIGHT", -2, 0)
        healthText:SetJustifyH("RIGHT")
        healthText:SetTextColor(0.9, 0.9, 0.9)
        frame.HealthText = healthText
    end

    -- P2 效能修復：快取 DB 設定到 upvalue，避免每次 UNIT_HEALTH 做 GetModuleDB
    -- Options 變更時由 InvalidateNameplateSettings() 重新整理快取
    local cachedNpcColorsEnabled = db and db.npcColors and db.npcColors.enabled
    local cachedHealthFmt = db and db.healthTextFormat or "percent"

    -- 提供外部重新整理快取的方法（Options callback 呼叫）
    frame._refreshHealthSettings = function()
        local freshDb = LunarUI.GetModuleDB("nameplates")
        cachedNpcColorsEnabled = freshDb and freshDb.npcColors and freshDb.npcColors.enabled
        cachedHealthFmt = freshDb and freshDb.healthTextFormat or "percent"
    end

    health.PostUpdate = function(bar, unit, cur, max)
        -- NPC 角色分類上色（覆蓋 oUF 的 reaction 顏色）
        if cachedNpcColorsEnabled and unit then
            local npcColor = frame._npcColorCache
            if npcColor then
                local reaction = UnitReaction(unit, "player")
                if (not reaction or reaction <= 4) and not UnitIsTapDenied(unit) then
                    bar:SetStatusBarColor(npcColor.r, npcColor.g, npcColor.b)
                    if bar.bg then
                        bar.bg:SetVertexColor(npcColor.r * BG_DARKEN, npcColor.g * BG_DARKEN, npcColor.b * BG_DARKEN)
                    end
                end
            end
        end

        -- 生命值文字（動態查找，showHealthText 在 layout 時建立）
        -- Perf A4: cache `(pct, fmt, cur)` 三元組，沒變就 skip SetText 避免每幀
        -- 對每個可見名牌 alloc 新字串（地城 30 plates × 60fps 原本 ~1800 strings/sec）
        local ht = frame.HealthText
        if not ht then
            return
        end
        if type(cur) ~= "number" or type(max) ~= "number" or max == 0 then
            if ht._lastText ~= "" then
                ht:SetText("")
                ht._lastText = ""
            end
            return
        end
        local pct = mathFloor(cur / max * 100)
        -- 短路：pct + fmt 沒變（percent 模式）或 pct + cur + fmt 都沒變（其他模式）
        if
            ht._lastPct == pct
            and ht._lastFmt == cachedHealthFmt
            and (cachedHealthFmt == "percent" or ht._lastCur == cur)
        then
            return
        end
        ht._lastPct = pct
        ht._lastFmt = cachedHealthFmt
        ht._lastCur = cur
        if cachedHealthFmt == "percent" then
            ht:SetText(format("%d%%", pct))
        elseif cachedHealthFmt == "current" then
            ht:SetText(LunarUI.FormatValue(cur))
        elseif cachedHealthFmt == "both" then
            ht:SetText(format("%s - %d%%", LunarUI.FormatValue(cur), pct))
        end
    end

    frame.Health = health
    return health
end

--[[ Name Text ]]
local function CreateNameText(frame)
    local name = frame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(name, 9, "OUTLINE")
    name:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
    name:SetJustifyH("LEFT")
    name:SetWidth(frame:GetWidth())
    name:SetTextColor(0.9, 0.9, 0.9)

    frame:Tag(name, "[lunar:name:abbrev]") -- 名牌空間有限，使用縮寫
    frame.Name = name
    return name
end

--[[ Level Text ]]
local function CreateLevelText(frame)
    local level = frame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(level, 8, "OUTLINE")
    level:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 2)
    level:SetJustifyH("RIGHT")
    level:SetTextColor(0.7, 0.7, 0.7)

    frame:Tag(level, "[lunar:level:smart]")
    frame.LevelText = level
    return level
end

--[[ Castbar ]]
local function CreateCastbar(frame)
    local castbar = CreateFrame("StatusBar", nil, frame)
    castbar:SetStatusBarTexture(GetStatusBarTexture())
    castbar:SetStatusBarColor(unpack(CASTBAR_COLOR))
    castbar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -3)
    castbar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -3)
    castbar:SetHeight(6)

    -- 背景
    local bg = castbar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(GetStatusBarTexture())
    bg:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    castbar.bg = bg

    -- 邊框
    local border = CreateFrame("Frame", nil, castbar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    LunarUI.ApplyBackdrop(border, nil, C.transparent, C.borderSubtle)

    -- 圖示
    local icon = castbar:CreateTexture(nil, "OVERLAY")
    icon:SetSize(6, 6)
    icon:SetPoint("RIGHT", castbar, "LEFT", -2, 0)
    icon:SetTexCoord(unpack(LunarUI.ICON_TEXCOORD))
    castbar.Icon = icon

    -- 文字
    local text = castbar:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(text, 7, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    castbar.Text = text

    -- WoW 12.0 將 notInterruptible 設為 secret value，無法可靠判斷
    -- 統一使用固定顏色（與 UnitFrames/Layout.lua PostCastStart 一致）
    castbar.PostCastStart = function(self, _unit)
        self:SetStatusBarColor(unpack(CASTBAR_COLOR))
    end
    -- 火花效果
    local spark = castbar:CreateTexture(nil, "OVERLAY")
    spark:SetSize(10, 10)
    spark:SetBlendMode("ADD")
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    castbar.Spark = spark

    frame.Castbar = castbar
    return castbar
end

-- 名牌 Aura 按鈕共用樣式（Debuffs / Buffs 共用）
local function StyleNameplateAura(_self, button)
    LunarUI.StyleAuraButton(button)
    LunarUI.SetFont(button.Count, 8, "OUTLINE")
    button.Count:SetPoint("BOTTOMRIGHT", 2, -2)
    if button.SetBackdropColor then
        button:SetBackdropColor(C.bgOverlay[1], C.bgOverlay[2], C.bgOverlay[3], C.bgOverlay[4])
    end
end

--[[ Debuffs ]]
local function CreateDebuffs(frame)
    local debuffs = CreateFrame("Frame", nil, frame)
    debuffs:SetPoint("BOTTOM", frame, "TOP", 0, 14)
    debuffs:SetSize(frame:GetWidth(), 18)

    debuffs.size = 16
    debuffs.spacing = 2
    debuffs.num = 5
    debuffs.initialAnchor = "CENTER"
    debuffs["growth-x"] = "RIGHT"
    debuffs["growth-y"] = "UP"

    -- 只顯示玩家的減益
    debuffs.onlyShowPlayer = true

    -- WoW 12.0 將 isHarmful 設為 secret value（taint-protected），無法讀取。
    -- oUF Debuffs element 已限制 aura pool 為 harmful，FilterAura 只需檢查 isPlayerAura。
    -- 不要加 "and data.isHarmful == true"——永遠不會匹配，會隱藏所有 debuffs。
    -- WoW 12.0: data.isPlayerAura 也可能是 secret boolean，pcall 保護
    -- P2-perf: 使用 module-level 命名函式，不在每個 frame 建 closure
    debuffs.FilterAura = NameplateDebuffFilterAura
    debuffs.PostCreateButton = StyleNameplateAura
    debuffs.PostUpdateButton = NameplateDebuffPostUpdate

    frame.Debuffs = debuffs
    return debuffs
end

--[[ Buffs (enemy nameplates — stealable/important buffs) ]]
local function CreateNameplateBuffs(frame)
    local db = LunarUI.GetModuleDB("nameplates")
    local enemyDb = db and db.enemy
    local buffSize = enemyDb and enemyDb.buffSize or 14
    local maxBuffs = enemyDb and enemyDb.maxBuffs or 4

    local buffs = CreateFrame("Frame", nil, frame)
    -- 有減益時定位在減益上方，否則在血條上方
    if frame.Debuffs then
        buffs:SetPoint("BOTTOM", frame.Debuffs, "TOP", 0, 2)
    else
        buffs:SetPoint("BOTTOM", frame, "TOP", 0, 14)
    end
    buffs:SetSize(frame:GetWidth(), buffSize + 2)

    buffs.size = buffSize
    buffs.spacing = 2
    buffs.num = maxBuffs
    buffs.initialAnchor = "CENTER"
    buffs["growth-x"] = "RIGHT"
    buffs["growth-y"] = "UP"

    -- 過濾：只顯示敵方可竊取/可驅散的增益
    -- WoW 12.0: data.isStealable 在戰鬥中為 secret boolean，pcall 保護比較
    -- P2-perf: 使用 module-level 命名函式
    buffs.FilterAura = NameplateBuffFilterAura
    buffs.PostCreateButton = StyleNameplateAura
    buffs.PostUpdateButton = NameplateBuffPostUpdate

    frame.Buffs = buffs
    return buffs
end

--[[ Threat Indicator — 血條頂部 1px 細線（取代粗邊框） ]]
local function CreateThreatIndicator(frame)
    local threat = frame:CreateTexture(nil, "OVERLAY")
    threat:SetHeight(1)
    threat:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 1)
    threat:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 1)
    threat:SetTexture("Interface\\Buttons\\WHITE8x8")
    threat:SetVertexColor(0, 0, 0, 0)

    threat.PostUpdate = function(self, _unit, status, r, g, b)
        if not self then
            return
        end
        if status and status > 0 and r and g and b then
            self:SetVertexColor(r, g, b, 0.9)
        else
            self:SetVertexColor(0, 0, 0, 0)
        end
    end

    frame.ThreatIndicator = threat
    return threat
end

--[[ Classification Icon ]]
local function CreateClassificationIndicator(frame)
    local class = frame:CreateTexture(nil, "OVERLAY")
    class:SetSize(14, 14)
    class:SetPoint("LEFT", frame, "RIGHT", 2, 0)
    frame.ClassificationIndicator = class
    return class
end

--[[ Classification Glow (elite/rare/boss subtle outer glow) ]]
local function CreateClassificationGlow(frame)
    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    glow:SetTexture(LunarUI.textures.glow)
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", -8, 8)
    glow:SetPoint("BOTTOMRIGHT", 8, -8)
    glow:SetAlpha(0)
    glow:Hide()
    frame.ClassificationGlow = glow
    return glow
end

--[[ Raid Target Icon ]]
local function CreateRaidTargetIndicator(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    frame.RaidTargetIndicator = icon
    return icon
end

--[[ Quest Icon Indicator ]]
local function CreateQuestIndicator(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", frame, "RIGHT", 18, 0)
    icon:SetTexture("Interface\\TARGETINGFRAME\\PortraitQuestBadge")
    icon:Hide()
    frame.QuestIndicator = icon
    return icon
end

--[[ Target Highlight ]]
local function CreateTargetIndicator(frame)
    local highlight = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    highlight:SetPoint("TOPLEFT", -3, 3)
    highlight:SetPoint("BOTTOMRIGHT", 3, -3)
    highlight:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    highlight:SetBackdropBorderColor(1, 1, 1, 0)
    highlight:SetFrameLevel(frame:GetFrameLevel() + 6)
    highlight:Hide()

    frame.TargetIndicator = highlight
    return highlight
end

-- 弱引用表：名牌框架追蹤（疊加偵測等）
-- Weak table: key 為弱引用，當 nameplate frame 被 GC 時自動清理
local nameplateFrames = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------------------
-- 佈局函數
--------------------------------------------------------------------------------

--[[ Unified Nameplate Layout ]]
-- oUF 會跨類型回收名牌框架（友方框架可能被回收給敵方使用），
-- style callback 只在首次建立時呼叫，因此必須建立所有可能需要的元素。
-- 元素可見性由 Nameplate_OnShow 根據當前單位的反應值動態控制。
local function NameplateLayout(frame, _unit)
    local db = LunarUI.GetModuleDB("nameplates")
    local width = db and db.width or 120
    local height = db and db.height or 12

    -- 覆蓋 oUF 的 SetAllPoints()（ouf.lua:900）：清除雙錨點改用固定尺寸
    -- WoW 12.0 移除 C_NamePlate.SetNamePlateSize，父框架尺寸不受控制
    -- 若不清除，SetSize 被錨點覆蓋，導致回收時名牌尺寸不一致
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetSize(width, height)

    -- 共用元素（敵方/友方皆需要）
    CreateBackdrop(frame)
    CreateHealthBar(frame)
    CreateNameText(frame)
    CreateLevelText(frame)
    CreateRaidTargetIndicator(frame)
    CreateTargetIndicator(frame)

    -- 敵方專用元素（無條件建立，可見性在 OnShow 控制）
    CreateCastbar(frame)
    CreateDebuffs(frame)
    CreateNameplateBuffs(frame)
    CreateThreatIndicator(frame)
    CreateClassificationIndicator(frame)
    CreateClassificationGlow(frame)
    CreateQuestIndicator(frame)

    return frame
end

--------------------------------------------------------------------------------
-- 名牌回呼
--------------------------------------------------------------------------------

--[[ Update quest indicator ]]
local function UpdateQuestIndicator(frame)
    if not frame or not frame.QuestIndicator or not frame.unit then
        return
    end
    local isQuest = C_QuestLog.UnitIsRelatedToActiveQuest(frame.unit)
    if isQuest then
        frame.QuestIndicator:Show()
    else
        frame.QuestIndicator:Hide()
    end
end

--[[ Update target indicator ]]
local function UpdateTargetIndicator(frame)
    if not frame or not frame.unit or not frame.TargetIndicator then
        return
    end

    if UnitIsUnit(frame.unit, "target") then
        frame.TargetIndicator:SetBackdropBorderColor(1, 1, 1, 1)
        frame.TargetIndicator:Show()
    else
        frame.TargetIndicator:Hide()
    end
end

--[[ Nameplate callback: OnShow ]]
local function Nameplate_OnShow(frame)
    if not frame then
        return
    end
    -- 模組停用時不處理名牌（oUF driver 是 singleton 無法關閉，用旗標控制）
    if not nameplateModuleEnabled then
        return
    end

    -- 重新註冊框架追蹤（隱藏時已移除）
    nameplateFrames[frame] = true

    -- P1-perf: 寬高使用 module-level 快取，其他設定仍從 db 讀取（OnShow 頻率可接受）
    local db = LunarUI.GetModuleDB("nameplates")
    local width = cachedNpWidth or (db and db.width) or 120
    local height = cachedNpHeight or (db and db.height) or 12
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetSize(width, height)

    -- Shift+V 關再開時 WoW 重用框架但 OnHide 已重設錨點，需要重新確認樣式
    if frame.Health then
        frame.Health:ClearAllPoints()
        frame.Health:SetAllPoints(frame)
    end
    if frame.Backdrop then
        frame.Backdrop:ClearAllPoints()
        frame.Backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
        frame.Backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
        -- 重設邊框為預設色（分類高亮會在下方覆蓋）
        frame.Backdrop:SetBackdropBorderColor(
            C.borderSubtle[1],
            C.borderSubtle[2],
            C.borderSubtle[3],
            C.borderSubtle[4]
        )
    end

    -- Performance: 標記堆疊偵測需要重新計算
    MarkStackingDirty()

    -- 根據當前單位類型控制元素可見性（oUF 會跨類型回收框架）
    -- reaction 1-3 = 敵對，4 = 中立（視為敵方處理），5-8 = 友善
    local isEnemy
    if not frame.unit then
        -- frame.unit 尚未設定（框架首次建立時 oUF 尚未 assign unit）
        -- 預設隱藏敵方專用元素，避免友方名牌短暫閃現敵方 UI
        if frame.Debuffs then
            frame.Debuffs:Hide()
        end
        if frame.Buffs then
            frame.Buffs:Hide()
        end
        if frame.ClassificationIndicator then
            frame.ClassificationIndicator:Hide()
        end
        if frame.ClassificationGlow then
            frame.ClassificationGlow:Hide()
        end
        if frame.QuestIndicator then
            frame.QuestIndicator:Hide()
        end
    else
        local reaction = UnitReaction(frame.unit, "player")
        isEnemy = not reaction or reaction <= 4

        -- 敵方/友方專用元素可見性（只在類型變更時切換，避免重複呼叫）
        if isEnemy ~= frame._lastIsEnemy then
            frame._lastIsEnemy = isEnemy

            local enemyDb = db and db.enemy
            local friendlyDb = db and db.friendly

            -- LevelText（FontString，show/hide 安全）
            if frame.LevelText then
                if isEnemy then
                    frame.LevelText:SetShown(not enemyDb or enemyDb.showLevel ~= false)
                else
                    frame.LevelText:SetShown(friendlyDb and friendlyDb.showLevel or false)
                end
            end

            -- Castbar（oUF 元素，用 EnableElement/DisableElement 控制更新週期）
            -- 使用 explicit if/else 取代 and/or ternary，邏輯等價但更易讀（#3 code review）
            if frame.Castbar then
                local showCastbar
                if isEnemy then
                    -- 敵方預設顯示（opt-out）：缺設定或未顯式設為 false 都顯示
                    showCastbar = not enemyDb or enemyDb.showCastbar ~= false
                else
                    -- 友方預設隱藏（opt-in）：必須顯式啟用
                    showCastbar = friendlyDb and friendlyDb.showCastbar
                end
                if showCastbar then
                    frame:EnableElement("Castbar")
                else
                    frame:DisableElement("Castbar")
                    frame.Castbar:Hide()
                end
            end

            -- Debuffs / Buffs（oUF 註冊為單一 "Auras" 元素，無法個別 enable/disable）
            -- 只用 Show/Hide 控制可見性，oUF UNIT_AURA 處理仍會執行（已知限制）
            -- Debuffs 預設顯示（opt-out），Buffs 預設隱藏（opt-in）— 與原始 EnemyNameplateLayout 一致
            if frame.Debuffs then
                local showDebuffs
                if isEnemy then
                    showDebuffs = not enemyDb or enemyDb.showAuras ~= false
                else
                    showDebuffs = false
                end
                frame.Debuffs:SetShown(showDebuffs)
            end
            if frame.Buffs then
                local showBuffs
                if isEnemy then
                    showBuffs = enemyDb and enemyDb.showBuffs
                else
                    showBuffs = false
                end
                -- SetShown 對 nil 視同 false，所以 truthy 檢查即可
                frame.Buffs:SetShown(showBuffs or false)
            end

            -- ThreatIndicator（oUF 元素）
            if frame.ThreatIndicator then
                if isEnemy then
                    frame:EnableElement("ThreatIndicator")
                else
                    frame:DisableElement("ThreatIndicator")
                    frame.ThreatIndicator:SetVertexColor(0, 0, 0, 0)
                end
            end

            -- 敵方專用手動元素
            if frame.ClassificationIndicator then
                frame.ClassificationIndicator:SetShown(isEnemy)
            end
            if frame.QuestIndicator then
                frame.QuestIndicator:SetShown(false) -- 由 UpdateQuestIndicator 控制
            end
        end
    end

    -- 更新目標指示器
    UpdateTargetIndicator(frame)

    -- 更新任務指示器（只對敵方顯示）
    if isEnemy then
        UpdateQuestIndicator(frame)
    end

    -- 更新分類高亮 + 光暈
    if frame.unit then
        local classification = GetUnitClassification(frame.unit)
        -- M6 效能修復：直接用已讀取的 classification 判斷，避免 IsImportantTarget 內第二次呼叫 UnitClassification
        local isImportant = classification == "worldboss"
            or classification == "rareelite"
            or classification == "elite"
            or classification == "rare"
        -- H2 效能修復：預計算 NPC 顏色並快取到 frame，PostUpdate 直接讀取快取
        -- M6 效能修復：傳入已計算的 classification，避免 GetNPCRoleColor 內第二次呼叫 UnitClassification
        frame._npcColorCache = GetNPCRoleColor(frame.unit, db, classification)

        if db and db.highlight then
            local color = CLASSIFICATION_COLORS[classification]
            if color and isImportant then
                if frame.Backdrop then
                    frame.Backdrop:SetBackdropBorderColor(color.r, color.g, color.b, 1)
                end
            end
        end

        -- 重要目標顯示分類光暈
        if frame.ClassificationGlow then
            if isEnemy and isImportant then
                local color = CLASSIFICATION_COLORS[classification]
                if color then
                    frame.ClassificationGlow:SetVertexColor(color.r, color.g, color.b, 0.4)
                    frame.ClassificationGlow:Show()
                end
            else
                frame.ClassificationGlow:Hide()
            end
        end
    end
end

--[[ Nameplate callback: OnHide ]]
local function Nameplate_OnHide(frame)
    -- 清理
    if frame.TargetIndicator then
        frame.TargetIndicator:Hide()
    end
    if frame.ClassificationGlow then
        frame.ClassificationGlow:Hide()
    end
    if frame.QuestIndicator then
        frame.QuestIndicator:Hide()
    end
    -- 隱藏時移除框架引用
    nameplateFrames[frame] = nil

    -- 清除快取狀態，避免框架回收後帶有前一個 NPC 的資料
    frame._npcColorCache = nil
    frame._lastIsEnemy = nil -- 強制下次 OnShow 重新判斷敵友類型

    -- 清除堆疊偏移狀態，避免框架被回收再用時帶有舊 NPC 的偏移
    if frame._lunarStackShift then
        frame._lunarStackShift = nil
        frame._lunarStackOffset = nil
        if frame.Health then
            frame.Health:ClearAllPoints()
            frame.Health:SetAllPoints(frame)
        end
        if frame.Backdrop then
            frame.Backdrop:ClearAllPoints()
            frame.Backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
            frame.Backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
        end
    else
        frame._lunarStackOffset = nil
    end

    -- Performance: 標記堆疊偵測需要重新計算
    MarkStackingDirty()
end

--------------------------------------------------------------------------------
-- 疊加偵測（偏移重疊名牌）
--------------------------------------------------------------------------------

local stackingFrame = nil
local STACKING_INTERVAL = 0.1 -- 更新間隔（秒）
local STACKING_OFFSET = 10 -- 每層偏移量（像素）
-- cachedNpWidth / cachedNpHeight 已在檔案前段定義，此處由 StartStackingDetection 更新

-- 重用平行陣列，避免每 0.1s 為每個名牌建新 table
local stackFrames = {}
local stackYs = {}
local stackOffsets = {}

-- Performance: 髒旗標驅動 - 只有名牌數量變化時才重新計算
local stackingDirty = false
---@diagnostic disable-next-line
MarkStackingDirty = function()
    stackingDirty = true
    -- P5 效能：重新顯示 stacking frame 以啟動 OnUpdate（idle 時已隱藏）
    if stackingFrame then
        stackingFrame:Show()
    end
end

-- 記錄上一個目標名牌，切換時只更新前/後兩個
local lastTargetNameplate = nil

-- 收集可見名牌到重用陣列
local function CollectVisibleNameplates()
    -- 清理重用陣列
    for k = 1, #stackFrames do
        stackFrames[k] = nil
        stackYs[k] = nil
        stackOffsets[k] = nil
    end

    local count = 0
    for np in pairs(nameplateFrames) do
        if np:IsShown() and np:GetParent() then
            local _, screenY = np:GetCenter()
            if screenY then
                local appliedOffset = np._lunarStackOffset or 0
                local baseY = screenY - appliedOffset
                count = count + 1
                stackFrames[count] = np
                stackYs[count] = baseY
                stackOffsets[count] = 0
            end
        end
    end

    return count
end

-- 按 Y 座標排序（由下到上）—— 簡單插入排序，名牌數量通常 < 30
local function SortNameplatesByY(count)
    for i = 2, count do
        local keyFrame = stackFrames[i]
        local keyY = stackYs[i]
        local j = i - 1
        while j >= 1 and stackYs[j] > keyY do
            stackFrames[j + 1] = stackFrames[j]
            stackYs[j + 1] = stackYs[j]
            stackOffsets[j + 1] = stackOffsets[j]
            j = j - 1
        end
        stackFrames[j + 1] = keyFrame
        stackYs[j + 1] = keyY
        stackOffsets[j + 1] = 0
    end
end

-- 偵測重疊並計算偏移（使用固定閾值）
-- 以未偏移的 Y 比較，避免偏移誤差累積導致不必要的堆疊
local function DetectOverlaps(count, npHeight)
    for i = 2, count do
        local dy = stackYs[i] - stackYs[i - 1]
        if dy < npHeight then
            stackOffsets[i] = stackOffsets[i - 1] + STACKING_OFFSET
        end
    end
end

-- 套用堆疊偏移到名牌元素
local function ApplyStackOffsets(count)
    for i = 1, count do
        local np = stackFrames[i]
        if not np then
            break
        end
        local offset = stackOffsets[i]
        if np._lunarStackOffset ~= offset then
            np._lunarStackOffset = offset
            local parent = np:GetParent()
            if parent and np.SetPoint then
                -- oUF 名牌由暴雪 NamePlate 框架管理位置
                -- 我們透過調整子內容的相對位置來模擬偏移
                if offset > 0 then
                    if not np._lunarStackShift then
                        np._lunarStackShift = true
                    end
                    -- 使用 Health bar 的位移來表現偏移
                    if np.Health then
                        np.Health:ClearAllPoints()
                        np.Health:SetPoint("TOPLEFT", np, "TOPLEFT", 0, offset)
                        np.Health:SetPoint("BOTTOMRIGHT", np, "BOTTOMRIGHT", 0, offset)
                    end
                    if np.Backdrop then
                        np.Backdrop:ClearAllPoints()
                        np.Backdrop:SetPoint("TOPLEFT", np.Health or np, "TOPLEFT", -1, 1)
                        np.Backdrop:SetPoint("BOTTOMRIGHT", np.Health or np, "BOTTOMRIGHT", 1, -1)
                    end
                else
                    if np._lunarStackShift then
                        np._lunarStackShift = nil
                        if np.Health then
                            np.Health:ClearAllPoints()
                            np.Health:SetAllPoints(np)
                        end
                        if np.Backdrop then
                            np.Backdrop:ClearAllPoints()
                            np.Backdrop:SetPoint("TOPLEFT", np, "TOPLEFT", -1, 1)
                            np.Backdrop:SetPoint("BOTTOMRIGHT", np, "BOTTOMRIGHT", 1, -1)
                        end
                    end
                end
            end
        end
    end
end

-- Perf C2: 快取上一次的 (count, sum(baseY)) 作為位置簽名。
-- stackingDirty 已 gate 執行頻率，但 show/hide 事件觸發的 dirty 有時候其實
-- 沒改變位置版面（例如 pet 短暫隱身）。簽名短路讓這些無變化的觸發直接 bail。
local _lastStackSig_count = -1
local _lastStackSig_sum = -1

-- 主協調器：名牌堆疊偵測與調整
-- 注意：只操作非 secure 的子框架（Health/Backdrop），不需要 InCombatLockdown 檢查
local function UpdateNameplateStacking()
    -- B4 效能修復：使用快取的 npHeight，由 StartStackingDetection 設定
    local npHeight = cachedNpHeight

    -- 執行堆疊調整流程
    local count = CollectVisibleNameplates()
    if count > 0 then
        -- 先排序，讓 stackYs 成為確定性的升序
        if count > 1 then
            SortNameplatesByY(count)
        end

        -- Perf C2（#2 correctness fix）: 簽名在 sort **之後** 計算。
        -- CollectVisibleNameplates 使用 pairs() 迭代 weak table，順序不確定。
        -- 若在 sort 前計算 weighted sum，同一批 plates 兩次呼叫會因 pairs 順序
        -- 不同而產生不同 sigSum → 無意義的 false negative（白重算）。sort 後
        -- stackYs[1..count] 是升序，index 唯一確定 → 簽名穩定且正確反映位置變化。
        local sigSum = 0
        for i = 1, count do
            sigSum = sigSum + stackYs[i] * i
        end
        if count == _lastStackSig_count and sigSum == _lastStackSig_sum then
            return
        end
        _lastStackSig_count = count
        _lastStackSig_sum = sigSum

        if count > 1 then
            DetectOverlaps(count, npHeight)
        end
        ApplyStackOffsets(count)
    else
        _lastStackSig_count = 0
        _lastStackSig_sum = 0
    end
end

local function StartStackingDetection()
    local db = LunarUI.GetModuleDB("nameplates")
    if not db or not db.stackingDetection then
        return
    end
    -- B4 效能修復：快取尺寸，UpdateNameplateStacking 和 Nameplate_OnShow 直接使用不再查 DB
    cachedNpWidth = db.width or 120
    cachedNpHeight = (db.height or 8) + 4

    if stackingFrame then
        return
    end
    stackingFrame = CreateFrame("Frame")
    local elapsed = 0
    stackingFrame:SetScript("OnUpdate", function(_self, dt)
        elapsed = elapsed + dt
        if elapsed >= STACKING_INTERVAL then
            elapsed = 0
            if stackingDirty then
                stackingDirty = false
                UpdateNameplateStacking()
            else
                -- P5 效能：無待處理工作時隱藏 frame 停止 OnUpdate（MarkStackingDirty 會重新 Show）
                stackingFrame:Hide()
            end
        end
    end)
    -- 初次標記為髒，確保立即執行第一次計算
    stackingDirty = true
end

local function StopStackingDetection()
    if stackingFrame then
        stackingFrame:SetScript("OnUpdate", nil)
        stackingFrame:Hide()
        stackingFrame = nil
    end
    -- 重設所有名牌偏移
    for np in pairs(nameplateFrames) do
        if np._lunarStackShift then
            np._lunarStackShift = nil
            np._lunarStackOffset = nil
            if np.Health then
                np.Health:ClearAllPoints()
                np.Health:SetAllPoints(np)
            end
            if np.Backdrop then
                np.Backdrop:ClearAllPoints()
                np.Backdrop:SetPoint("TOPLEFT", np, "TOPLEFT", -1, 1)
                np.Backdrop:SetPoint("BOTTOMRIGHT", np, "BOTTOMRIGHT", 1, -1)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 註冊樣式與生成
--------------------------------------------------------------------------------

oUF:RegisterStyle("LunarUI_Nameplate", NameplateLayout)

-- 戰鬥緩衝：SpawnNameplates 確認啟用後，若處於戰鬥鎖定才啟動
-- oUF:SpawnNamePlates 內部做 SetAttribute（protected），無法在戰鬥中執行，
-- 等待 REGEN_ENABLED 期間 NAME_PLATE_UNIT_ADDED 仍會觸發，需要暫存以便脫戰後回放
-- delay=0 使 SpawnNameplates 在 PLAYER_LOGIN handler 中同步執行，
-- NAME_PLATE_UNIT_ADDED 在 PLAYER_LOGIN 之後才觸發，正常路徑不需要 buffer
local EARLY_BUFFER_CAP = 40 -- 名牌最多 ~40 個，超過就不緩衝
local earlyPlateBuffer -- nil：僅在 combat wait 時建立

local function StartEarlyPlateBuffer()
    if earlyPlateBuffer then
        return
    end
    earlyPlateBuffer = CreateFrame("Frame")
    earlyPlateBuffer._units = {}
    earlyPlateBuffer:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    earlyPlateBuffer:SetScript("OnEvent", function(_self, _event, unit)
        if #earlyPlateBuffer._units < EARLY_BUFFER_CAP then
            earlyPlateBuffer._units[#earlyPlateBuffer._units + 1] = unit
        end
    end)
end

-- 停止緩衝並釋放資源（供 combat spawn 成功 / cleanup / disabled 三路徑共用）
local function StopEarlyPlateBuffer()
    if not earlyPlateBuffer then
        return
    end
    earlyPlateBuffer:UnregisterAllEvents()
    earlyPlateBuffer:SetScript("OnEvent", nil)
    earlyPlateBuffer._units = nil
    earlyPlateBuffer = nil
end

local function SpawnNameplates()
    local db = LunarUI.GetModuleDB("nameplates")
    if not db or not db.enabled then
        StopEarlyPlateBuffer()
        return
    end

    -- 使用事件驅動重試處理戰鬥鎖定（singleton 避免重複呼叫建立多個 frame）
    if InCombatLockdown() then
        -- 戰鬥中無法呼叫 oUF:SpawnNamePlates（SetAttribute 受保護），
        -- 啟動 buffer 捕捉等待期間的事件，脫戰後回放
        StartEarlyPlateBuffer()
        if not npCombatWaitFrame then
            npCombatWaitFrame = CreateFrame("Frame")
        end
        npCombatWaitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        npCombatWaitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            SpawnNameplates()
        end)
        return
    end

    -- WoW 12.0.0 移除了 C_NamePlate.SetNamePlateSize 和 C_NamePlateManager.SetNamePlateHitTestInsets
    -- vendored oUF (ouf.lua:766) 已有 existence check，不需要全域 shim

    nameplateModuleEnabled = true
    oUF:SetActiveStyle("LunarUI_Nameplate")

    -- oUF:SpawnNamePlates 是 singleton，只能呼叫一次（re-enable 時重新啟用輔助系統）
    if not nameplateDriverSpawned then
        nameplateDriverSpawned = true
        local nameplateDriver = oUF:SpawnNamePlates("LunarUI_Nameplate")
        nameplateDriver:SetAddedCallback(function(frame)
            -- SetAddedCallback 只在框架首次建立時觸發，非每次 OnShow。
            -- Hook OnShow/OnHide 使每次框架被回收給不同 NPC 時都能正確刷新狀態。
            frame:HookScript("OnShow", Nameplate_OnShow)
            frame:HookScript("OnHide", Nameplate_OnHide)
            -- 框架剛建立時可能已可見，執行首次初始化
            Nameplate_OnShow(frame)
        end)
        nameplateDriver:SetRemovedCallback(function(frame)
            Nameplate_OnHide(frame)
        end)

        -- 回放早期緩衝：將 delay 期間錯過的 NAME_PLATE_UNIT_ADDED 事件送給 oUF
        if earlyPlateBuffer then
            local bufferedUnits = earlyPlateBuffer._units
            -- 先停止捕捉（oUF driver 已註冊，後續事件由 oUF 直接處理）
            StopEarlyPlateBuffer()

            if bufferedUnits then
                local driverHandler = nameplateDriver.GetScript and nameplateDriver:GetScript("OnEvent")
                if driverHandler then
                    for _, unit in ipairs(bufferedUnits) do
                        -- 只處理 oUF 尚未建立 unitFrame 的名牌
                        local plate = C_NamePlate.GetNamePlateForUnit(unit)
                        if plate and not plate.unitFrame then
                            driverHandler(nameplateDriver, "NAME_PLATE_UNIT_ADDED", unit)
                        end
                    end
                end
            end
        end
    else
        -- re-enable：對當前已可見的名牌重新觸發 OnShow（HookScript 只在下次 Show 時觸發）
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                if plate and plate.unitFrame then
                    Nameplate_OnShow(plate.unitFrame)
                end
            end
        end
    end

    -- 堆疊偵測
    StartStackingDetection()

    -- 使用 singleton 避免重複事件處理器
    if not nameplateTargetFrame then
        nameplateTargetFrame = CreateFrame("Frame")
        nameplateTargetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        nameplateTargetFrame:SetScript("OnEvent", function()
            -- 只更新前一個和當前目標名牌，而非遍歷全部
            -- 清除舊目標
            if lastTargetNameplate and lastTargetNameplate:IsShown() then
                UpdateTargetIndicator(lastTargetNameplate)
            end
            -- 設定新目標
            local targetPlate = C_NamePlate.GetNamePlateForUnit("target")
            if targetPlate then
                -- oUF 名牌掛在 unitFrame 子框架上
                local np = targetPlate.unitFrame or targetPlate
                -- 驗證框架有效性：存在於追蹤表中且仍顯示
                if np and nameplateFrames[np] and np:IsShown() then
                    UpdateTargetIndicator(np)
                    lastTargetNameplate = np
                else
                    lastTargetNameplate = nil
                end
            else
                lastTargetNameplate = nil
            end
        end)
    end

    -- 任務狀態變更時更新任務圖示（throttle 避免連續觸發）
    if not nameplateQuestFrame then
        nameplateQuestFrame = CreateFrame("Frame")
        nameplateQuestFrame:RegisterEvent("QUEST_LOG_UPDATE")
        local questUpdatePending = false
        -- #9: 具名函數，避免 QUEST_LOG_UPDATE 每次觸發時分配新 closure
        -- Security S-B13: C_Timer.After(0.5) 沒有 generation guard，cleanup 後
        -- nameplateFrames 被 wipe 所以目前「意外安全」。加顯式 enabled guard
        -- 防止未來在 OnQuestTimerFired 加 module-level 操作時遺漏保護。
        local function OnQuestTimerFired()
            questUpdatePending = false
            if not nameplateModuleEnabled then
                return
            end
            for np in pairs(nameplateFrames) do
                if np:IsShown() then
                    UpdateQuestIndicator(np)
                end
            end
        end
        nameplateQuestFrame:SetScript("OnEvent", function()
            if questUpdatePending then
                return
            end
            questUpdatePending = true
            C_Timer.After(0.5, OnQuestTimerFired)
        end)
    end
end

-- 匯出
LunarUI.SpawnNameplates = SpawnNameplates
LunarUI.CLASSIFICATION_COLORS = CLASSIFICATION_COLORS
LunarUI.NPC_ROLE_COLORS = NPC_ROLE_COLORS
LunarUI.GetNPCRoleColor = GetNPCRoleColor

-- 清理函數：防止 disable/reload 時記憶體洩漏
function LunarUI.CleanupNameplates()
    -- Soft disable：停止 LunarUI 名牌增強，但不銷毀 oUF nameplate driver（singleton）
    -- oUF:SpawnNamePlates() 只能呼叫一次，因此：
    -- - /lunar off：設 nameplateModuleEnabled = false，OnShow hook 跳過處理
    -- - /lunar on：設 nameplateModuleEnabled = true，對現存名牌重新觸發 OnShow
    -- - 完全回到 Blizzard 原生名牌：需要 /reload
    -- 不呼叫 frame:Hide()：名牌框架由 WoW 引擎管理（secure），
    -- 強制 Hide 在戰鬥中會 taint，且框架不會自動恢復
    nameplateModuleEnabled = false

    -- P2 fix: disable 時停止早期緩衝（若 enable→disable 循環在 delay 視窗內發生）
    StopEarlyPlateBuffer()

    -- 清理戰鬥等待框架
    if npCombatWaitFrame then
        npCombatWaitFrame:UnregisterAllEvents()
        npCombatWaitFrame:SetScript("OnEvent", nil)
        npCombatWaitFrame = nil
    end
    -- 取消註冊目標切換事件處理器
    if nameplateTargetFrame then
        nameplateTargetFrame:UnregisterAllEvents()
        nameplateTargetFrame:SetScript("OnEvent", nil)
        nameplateTargetFrame = nil
    end
    -- 取消註冊任務更新事件處理器
    if nameplateQuestFrame then
        nameplateQuestFrame:UnregisterAllEvents()
        nameplateQuestFrame:SetScript("OnEvent", nil)
        nameplateQuestFrame = nil
    end
    -- 停止堆疊偵測
    StopStackingDetection()
    -- 清除弱引用表引用
    wipe(nameplateFrames)
    -- 重置過期 upvalue，防止 re-enable 後高亮錯誤框架
    lastTargetNameplate = nil
end

LunarUI:RegisterModule("Nameplates", {
    onEnable = SpawnNameplates,
    onDisable = function()
        LunarUI.CleanupNameplates()
    end,
    -- delay=0：在 PLAYER_LOGIN handler 中同步執行，早於 NAME_PLATE_UNIT_ADDED，
    -- 無需 file-load 階段的事件緩衝；戰鬥鎖定時才按需啟動 buffer
    delay = 0,
    lifecycle = "soft_disable",
})
