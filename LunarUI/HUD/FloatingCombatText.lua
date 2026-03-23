---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - Floating Combat Text
    輕量級浮動戰鬥數字

    功能：
    - 傷害輸出（近戰/法術/遠程）
    - 受到傷害
    - 治療量
    - 暴擊放大 + 不同顏色
    - 向上飄動 + 淡出動畫
    - 框架池回收機制（避免 GC）
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local fctFrame = nil
local queueFrame = nil -- 佇列處理框架（在乾淨的執行環境中消化 CLEU 事件）
local textPool = {} -- 可用的 FontString 池
local activeTexts = {} -- 目前顯示中的 FontString
-- CLEU 事件佇列：平行陣列取代 table-of-tables，消除每事件 GC 壓力
local pendingAmounts = {}
local pendingCriticals = {}
local pendingTypes = {}
local pendingCount = 0
local POOL_SIZE = 20 -- 預建數量

-- 效能：快取熱路徑全域變數
local math_floor = math.floor
local math_random = math.random
local table_insert = table.insert
local table_remove = table.remove
local isEnabled = false

-- M4 效能修復：快取 HUD DB 設定值，避免 ShowText 每次呼叫（戰鬥 AoE 中高頻）都查 DB
local fctFontSize = 24
local fctCritScale = 1.5
local fctDuration = 1.5
local fctShowDmgOut = true
local fctShowDmgIn = true
local fctShowHeal = true

local function RefreshFCTSettingsCache()
    local db = LunarUI.GetModuleDB("hud")
    if not db then
        return
    end
    fctFontSize = db.fctFontSize or 24
    fctCritScale = db.fctCritScale or 1.5
    fctDuration = db.fctDuration or 1.5
    fctShowDmgOut = db.fctDamageOut ~= false
    fctShowDmgIn = db.fctDamageIn ~= false
    fctShowHeal = db.fctHealing ~= false
end

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local FLOAT_DISTANCE = 60 -- 飄動距離（像素）
local STAGGER_OFFSET = 15 -- 同時多筆時的水平分散

-- 顏色表
local FCT_COLORS = {
    damage_out = { 1.0, 0.8, 0.2 }, -- 金色（輸出傷害）
    damage_in = { 0.9, 0.2, 0.2 }, -- 紅色（受到傷害）
    heal = { 0.2, 0.9, 0.2 }, -- 綠色（治療）
    crit = { 1.0, 1.0, 1.0 }, -- 白色（暴擊閃光）
}

-- 傷害事件對照表
local DAMAGE_EVENTS = {
    SWING_DAMAGE = true,
    SPELL_DAMAGE = true,
    RANGE_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
}

local HEAL_EVENTS = {
    SPELL_HEAL = true,
    SPELL_PERIODIC_HEAL = true,
}

--------------------------------------------------------------------------------
-- 緩動函數（直接引用 Tokens.lua）
--------------------------------------------------------------------------------

local OutQuad = LunarUI.Easing.OutQuad
local InQuad = LunarUI.Easing.InQuad

--------------------------------------------------------------------------------
-- 設定讀取
--------------------------------------------------------------------------------

local function GetSettings()
    local db = LunarUI.GetModuleDB("hud")
    if not db then
        return false, 24, 1.5, 1.5, true, true, true
    end
    return db.fctEnabled == true,
        db.fctFontSize or 24,
        db.fctCritScale or 1.5,
        db.fctDuration or 1.5,
        db.fctDamageOut ~= false,
        db.fctDamageIn ~= false,
        db.fctHealing ~= false
end

--------------------------------------------------------------------------------
-- 框架池管理
--------------------------------------------------------------------------------

local function CreatePooledText(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(fs, 24, "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:Hide()

    -- 每個 FontString 自帶動畫用框架（避免閉包 GC）
    local animFrame = CreateFrame("Frame", nil, parent)
    animFrame:Hide()
    fs._animFrame = animFrame
    animFrame._fctOwner = fs -- 反向連結，供 FCTAnimOnUpdate 使用
    fs._elapsed = 0
    fs._duration = 1.5
    fs._startY = 0
    fs._isCrit = false

    return fs
end

local function InitPool(parent)
    for _ = 1, POOL_SIZE do
        local fs = CreatePooledText(parent)
        table_insert(textPool, fs)
    end
end

local poolExhaustedLogged = false

local function AcquireText()
    if #textPool > 0 then
        return table_remove(textPool)
    end
    -- 池耗盡：首次記錄警告，後續靜默丟棄（避免刷屏）
    if not poolExhaustedLogged then
        poolExhaustedLogged = true
        LunarUI:Debug("FCT: 框架池已耗盡，部分戰鬥數字將被跳過")
    end
    return nil
end

local function RecycleText(fs)
    fs:Hide()
    fs:ClearAllPoints()
    fs._elapsed = 0
    fs._animFrame:SetScript("OnUpdate", nil)
    fs._animFrame:Hide()

    -- M3 效能修復：O(1) swap-remove，避免 table.remove 在中間位置移動後續所有元素
    for i, active in ipairs(activeTexts) do
        if active == fs then
            activeTexts[i] = activeTexts[#activeTexts]
            activeTexts[#activeTexts] = nil
            break
        end
    end

    table_insert(textPool, fs)
end

--------------------------------------------------------------------------------
-- 動畫系統
--------------------------------------------------------------------------------

-- 模組層級 OnUpdate handler，透過 _fctOwner 取得 FontString，避免每次 AnimateText 建立閉包
local function FCTAnimOnUpdate(self, dt)
    local fs = self._fctOwner
    fs._elapsed = fs._elapsed + dt
    local pct = fs._elapsed / fs._duration

    if pct >= 1 then
        RecycleText(fs)
        return
    end

    -- 向上飄動（OutQuad 先快後慢）
    local y = fs._startY + OutQuad(pct, 0, FLOAT_DISTANCE, 1)
    -- 淡出（InQuad 先慢後快）
    local alpha = 1 - InQuad(pct, 0, 1, 1)

    fs:SetPoint("CENTER", fctFrame, "CENTER", fs._offsetX or 0, y)
    fs:SetAlpha(alpha)
end

local function AnimateText(fs, startY, duration)
    fs._elapsed = 0
    fs._duration = duration
    fs._startY = startY
    fs:Show()
    fs._animFrame:Show()
    fs._animFrame:SetScript("OnUpdate", FCTAnimOnUpdate)
end

--------------------------------------------------------------------------------
-- 文字顯示
--------------------------------------------------------------------------------

local function ShowText(amount, isCrit, textType)
    if not isEnabled or not fctFrame then
        return
    end

    -- M4 效能修復：使用快取的設定值，避免每次 ShowText 都查 DB
    local fontSize, critScale, duration = fctFontSize, fctCritScale, fctDuration

    -- 類別過濾
    if textType == "damage_out" and not fctShowDmgOut then
        return
    end
    if textType == "damage_in" and not fctShowDmgIn then
        return
    end
    if textType == "heal" and not fctShowHeal then
        return
    end

    local fs = AcquireText()
    if not fs then
        return
    end -- 池耗盡

    -- 設定文字
    local displayAmount = LunarUI.FormatValue(math_floor(amount))

    if isCrit then
        displayAmount = displayAmount .. "!"
    end

    fs:SetText(displayAmount)

    -- 設定大小與顏色
    local size = isCrit and math_floor(fontSize * critScale) or fontSize
    local font = LunarUI.GetSelectedFont()
    fs:SetFont(font, size, "OUTLINE")

    local color = FCT_COLORS[textType] or FCT_COLORS.damage_out
    if isCrit then
        fs:SetTextColor(1, 1, 1) -- 暴擊白色
    else
        fs:SetTextColor(color[1], color[2], color[3])
    end

    -- 水平分散（避免重疊）
    local offsetX = 0
    if #activeTexts > 0 then
        offsetX = (math_random() - 0.5) * STAGGER_OFFSET * 2
    end
    fs._offsetX = offsetX

    -- 起始位置
    local startY = 0
    if textType == "damage_in" then
        startY = -20 -- 受到傷害從稍低位置開始
    elseif textType == "heal" then
        startY = 10 -- 治療從稍高位置開始
    end

    fs:SetPoint("CENTER", fctFrame, "CENTER", offsetX, startY)
    fs:SetAlpha(1)
    fs._isCrit = isCrit

    table_insert(activeTexts, fs)
    AnimateText(fs, startY, duration)
end

--------------------------------------------------------------------------------
-- 戰鬥事件處理
--------------------------------------------------------------------------------

local playerGUID = nil

-- taint 安全工具：使用 tostring/tonumber 斷開 CombatLogGetCurrentEventInfo 的 taint 鏈
-- WoW 12.0 中 CLEU 回傳值帶有 taint，直接使用會污染後續安全操作
local function Sanitize(val)
    if val == nil then
        return nil
    end
    local t = type(val)
    if t == "number" then
        return tonumber(tostring(val))
    end
    if t == "string" then
        return tostring(val)
    end
    if t == "boolean" then
        return val == true
    end
    return val
end

-- CLEU handler：只做資料解析，不操作任何 UI
-- 所有 UI 操作延遲到 queueFrame 的 OnUpdate（乾淨的執行環境）
local function OnCombatLogEvent()
    if not isEnabled then
        return
    end

    -- 一次性解構所有需要的欄位（零分配、單次呼叫）
    -- CombatLogGetCurrentEventInfo() 回傳值索引：
    -- 1=timestamp, 2=subevent, 4=sourceGUID, 8=destGUID
    -- SWING_DAMAGE: 12=amount, 18=critical
    -- SPELL_DAMAGE/HEAL: 15=amount, 21=critical (damage) / 18=critical (heal)
    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, a12, _, _, a15, _, _, a18, _, _, a21 =
        CombatLogGetCurrentEventInfo()

    local event = Sanitize(subevent)
    if not DAMAGE_EVENTS[event] and not HEAL_EVENTS[event] then
        return
    end

    sourceGUID = Sanitize(sourceGUID)
    destGUID = Sanitize(destGUID)

    if not playerGUID then
        playerGUID = UnitGUID("player")
    end

    -- 只處理與玩家相關的事件（提早退出）
    if sourceGUID ~= playerGUID and destGUID ~= playerGUID then
        return
    end

    if DAMAGE_EVENTS[event] then
        local amount, critical
        if event == "SWING_DAMAGE" then
            amount = Sanitize(a12)
            critical = Sanitize(a18)
        else
            amount = Sanitize(a15)
            critical = Sanitize(a21)
        end

        if type(amount) ~= "number" then
            return
        end

        if sourceGUID == playerGUID then
            pendingCount = pendingCount + 1
            pendingAmounts[pendingCount] = amount
            pendingCriticals[pendingCount] = critical
            pendingTypes[pendingCount] = "damage_out"
        elseif destGUID == playerGUID then
            pendingCount = pendingCount + 1
            pendingAmounts[pendingCount] = amount
            pendingCriticals[pendingCount] = critical
            pendingTypes[pendingCount] = "damage_in"
        end
    elseif HEAL_EVENTS[event] then
        local amount = Sanitize(a15)
        local critical = Sanitize(a18) -- SPELL_HEAL: critical 在位置 18（SPELL_DAMAGE 的 critical 才在 21）

        if type(amount) ~= "number" then
            return
        end

        if sourceGUID == playerGUID then
            pendingCount = pendingCount + 1
            pendingAmounts[pendingCount] = amount
            pendingCriticals[pendingCount] = critical
            pendingTypes[pendingCount] = "heal"
        end
    end

    -- 喚醒佇列處理框架（下一幀的 OnUpdate 將在乾淨環境中執行）
    if pendingCount > 0 and queueFrame then
        queueFrame:Show()
    end
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

---@return Frame
local function CreateFCTFrame()
    if fctFrame then
        -- re-enable 時重新掛載事件（CleanupFCT 呼叫了 UnregisterAllEvents）
        fctFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        fctFrame:SetScript("OnEvent", OnCombatLogEvent)
        -- 重新掛載 queueFrame OnUpdate（CleanupFCT 呼叫了 SetScript("OnUpdate", nil)）
        if queueFrame then
            queueFrame:SetScript("OnUpdate", function(self)
                self:Hide()
                for i = 1, pendingCount do
                    ShowText(pendingAmounts[i], pendingCriticals[i], pendingTypes[i])
                end
                pendingCount = 0
            end)
        end
        return fctFrame
    end

    fctFrame = CreateFrame("Frame", "LunarUI_FCT", UIParent)
    fctFrame:SetSize(200, 100)
    fctFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    fctFrame:SetFrameStrata("HIGH")

    -- 初始化框架池
    InitPool(fctFrame)

    -- 佇列處理框架：在乾淨的 OnUpdate 環境中消化 CLEU 事件
    -- Show/Hide 控制：只在有待處理事件時才啟動 OnUpdate，避免空轉
    queueFrame = CreateFrame("Frame", nil, fctFrame)
    queueFrame:Hide()
    queueFrame:SetScript("OnUpdate", function(self)
        self:Hide() -- 處理完立即停止，下次有事件時再 Show()
        for i = 1, pendingCount do
            ShowText(pendingAmounts[i], pendingCriticals[i], pendingTypes[i])
        end
        pendingCount = 0
    end)

    -- 註冊戰鬥日誌事件
    fctFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    fctFrame:SetScript("OnEvent", OnCombatLogEvent)

    -- 納入 HUD 縮放和框架移動
    LunarUI:RegisterHUDFrame("LunarUI_FCT")
    LunarUI.RegisterMovableFrame("fct", fctFrame, L["HUDFCT"] or "Floating Combat Text")

    return fctFrame
end

--------------------------------------------------------------------------------
-- 模組清理
--------------------------------------------------------------------------------

local function CleanupFCT()
    if fctFrame then
        fctFrame:UnregisterAllEvents()
        fctFrame:SetScript("OnEvent", nil)

        -- 停止佇列處理
        if queueFrame then
            queueFrame:SetScript("OnUpdate", nil)
            queueFrame:Hide()
        end
        pendingCount = 0

        -- 回收所有活動中的文字
        for i = #activeTexts, 1, -1 do
            RecycleText(activeTexts[i])
        end

        fctFrame:Hide()
    end
    isEnabled = false
    playerGUID = nil
    poolExhaustedLogged = false
end

--------------------------------------------------------------------------------
-- 模組註冊
--------------------------------------------------------------------------------

-- 匯出初始化/清理函數供 Options 即時切換使用
LunarUI.InitFCT = function()
    if isEnabled then
        return
    end
    local enabled = GetSettings()
    if not enabled then
        return
    end
    RefreshFCTSettingsCache()
    fctFrame = CreateFCTFrame()
    fctFrame:Show()
    isEnabled = true
end

LunarUI.CleanupFCT = CleanupFCT
LunarUI.Sanitize = Sanitize
LunarUI.FCTGetSettings = GetSettings

LunarUI:RegisterModule("FloatingCombatText", {
    onEnable = function()
        local enabled = GetSettings()
        if not enabled then
            return
        end

        RefreshFCTSettingsCache()
        fctFrame = CreateFCTFrame()
        fctFrame:Show()
        isEnabled = true
    end,

    onDisable = function()
        CleanupFCT()
    end,

    delay = 0.5,
    lifecycle = "reversible",
})
