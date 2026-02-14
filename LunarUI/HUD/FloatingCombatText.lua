---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local fctFrame = nil
local queueFrame = nil       -- 佇列處理框架（在乾淨的執行環境中消化 CLEU 事件）
local textPool = {}          -- 可用的 FontString 池
local activeTexts = {}       -- 目前顯示中的 FontString
local pendingTexts = {}      -- CLEU 事件佇列（避免在 tainted 環境中操作 UI）
local POOL_SIZE = 20         -- 預建數量
local isEnabled = false

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local FLOAT_DISTANCE = 60    -- 飄動距離（像素）
local STAGGER_OFFSET = 15    -- 同時多筆時的水平分散

-- 顏色表
local FCT_COLORS = {
    damage_out = { 1.0, 0.8, 0.2 },    -- 金色（輸出傷害）
    damage_in  = { 0.9, 0.2, 0.2 },    -- 紅色（受到傷害）
    heal       = { 0.2, 0.9, 0.2 },    -- 綠色（治療）
    crit       = { 1.0, 1.0, 1.0 },    -- 白色（暴擊閃光）
}

-- 傷害事件對照表
local DAMAGE_EVENTS = {
    SWING_DAMAGE        = true,
    SPELL_DAMAGE        = true,
    RANGE_DAMAGE        = true,
    SPELL_PERIODIC_DAMAGE = true,
}

local HEAL_EVENTS = {
    SPELL_HEAL          = true,
    SPELL_PERIODIC_HEAL = true,
}

--------------------------------------------------------------------------------
-- 緩動函數（直接引用 Tokens.lua）
--------------------------------------------------------------------------------

local OutQuad = LunarUI.Easing.OutQuad
local InQuad  = LunarUI.Easing.InQuad

--------------------------------------------------------------------------------
-- 設定讀取
--------------------------------------------------------------------------------

local function GetSettings()
    local db = LunarUI.db and LunarUI.db.profile and LunarUI.db.profile.hud
    if not db then
        return true, 24, 1.5, 1.5, true, true, true
    end
    return
        db.fctEnabled ~= false,
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
    fs._elapsed = 0
    fs._duration = 1.5
    fs._startY = 0
    fs._isCrit = false

    return fs
end

local function InitPool(parent)
    for _ = 1, POOL_SIZE do
        local fs = CreatePooledText(parent)
        table.insert(textPool, fs)
    end
end

local poolExhaustedLogged = false

local function AcquireText()
    if #textPool > 0 then
        return table.remove(textPool)
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

    -- 從活動列表移除
    for i, active in ipairs(activeTexts) do
        if active == fs then
            table.remove(activeTexts, i)
            break
        end
    end

    table.insert(textPool, fs)
end

--------------------------------------------------------------------------------
-- 動畫系統
--------------------------------------------------------------------------------

local function AnimateText(fs, startY, duration)
    fs._elapsed = 0
    fs._duration = duration
    fs._startY = startY
    fs:Show()
    fs._animFrame:Show()

    fs._animFrame:SetScript("OnUpdate", function(_self, dt)
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
    end)
end

--------------------------------------------------------------------------------
-- 文字顯示
--------------------------------------------------------------------------------

local function ShowText(amount, isCrit, textType)
    if not isEnabled or not fctFrame then return end

    local _, fontSize, critScale, duration, showDmgOut, showDmgIn, showHeal = GetSettings()

    -- 類別過濾
    if textType == "damage_out" and not showDmgOut then return end
    if textType == "damage_in" and not showDmgIn then return end
    if textType == "heal" and not showHeal then return end

    local fs = AcquireText()
    if not fs then return end  -- 池耗盡

    -- 設定文字
    local displayAmount
    if amount >= 1e6 then
        displayAmount = string.format("%.1fM", amount / 1e6)
    elseif amount >= 1e3 then
        displayAmount = string.format("%.1fK", amount / 1e3)
    else
        displayAmount = tostring(math.floor(amount))
    end

    if isCrit then
        displayAmount = displayAmount .. "!"
    end

    fs:SetText(displayAmount)

    -- 設定大小與顏色
    local size = isCrit and math.floor(fontSize * critScale) or fontSize
    local font = LunarUI.GetSelectedFont()
    fs:SetFont(font, size, "OUTLINE")

    local color = FCT_COLORS[textType] or FCT_COLORS.damage_out
    if isCrit then
        fs:SetTextColor(1, 1, 1)  -- 暴擊白色
    else
        fs:SetTextColor(color[1], color[2], color[3])
    end

    -- 水平分散（避免重疊）
    local offsetX = 0
    if #activeTexts > 0 then
        offsetX = (math.random() - 0.5) * STAGGER_OFFSET * 2
    end
    fs._offsetX = offsetX

    -- 起始位置
    local startY = 0
    if textType == "damage_in" then
        startY = -20  -- 受到傷害從稍低位置開始
    elseif textType == "heal" then
        startY = 10   -- 治療從稍高位置開始
    end

    fs:SetPoint("CENTER", fctFrame, "CENTER", offsetX, startY)
    fs:SetAlpha(1)
    fs._isCrit = isCrit

    table.insert(activeTexts, fs)
    AnimateText(fs, startY, duration)
end

--------------------------------------------------------------------------------
-- 戰鬥事件處理
--------------------------------------------------------------------------------

local playerGUID = nil

-- taint 安全工具：使用 tostring/tonumber 斷開 CombatLogGetCurrentEventInfo 的 taint 鏈
-- WoW 12.0 中 CLEU 回傳值帶有 taint，直接使用會污染後續安全操作
local function Sanitize(val)
    if val == nil then return nil end
    local t = type(val)
    if t == "number" then return tonumber(tostring(val)) end
    if t == "string" then return tostring(val) end
    if t == "boolean" then return val == true end
    return val
end

-- CLEU handler：只做資料解析，不操作任何 UI
-- 所有 UI 操作延遲到 queueFrame 的 OnUpdate（乾淨的執行環境）
local function OnCombatLogEvent()
    if not isEnabled then return end

    -- 一次擷取所有值，透過 Sanitize 斷開 taint
    local info = { CombatLogGetCurrentEventInfo() }
    local event = Sanitize(info[2])
    local sourceGUID = Sanitize(info[4])
    local destGUID = Sanitize(info[8])

    if not playerGUID then
        playerGUID = UnitGUID("player")
    end

    -- 只處理與玩家相關的事件（提早退出）
    if sourceGUID ~= playerGUID and destGUID ~= playerGUID then return end

    if DAMAGE_EVENTS[event] then
        local amount, critical
        if event == "SWING_DAMAGE" then
            amount = Sanitize(info[12])
            critical = Sanitize(info[18])
        else
            amount = Sanitize(info[15])
            critical = Sanitize(info[21])
        end

        if type(amount) ~= "number" then return end

        if sourceGUID == playerGUID then
            pendingTexts[#pendingTexts + 1] = { amount, critical, "damage_out" }
        elseif destGUID == playerGUID then
            pendingTexts[#pendingTexts + 1] = { amount, critical, "damage_in" }
        end

    elseif HEAL_EVENTS[event] then
        local amount = Sanitize(info[15])
        local critical = Sanitize(info[18])

        if type(amount) ~= "number" then return end

        if sourceGUID == playerGUID then
            pendingTexts[#pendingTexts + 1] = { amount, critical, "heal" }
        end
    end

    -- 喚醒佇列處理框架（下一幀的 OnUpdate 將在乾淨環境中執行）
    if #pendingTexts > 0 and queueFrame then
        queueFrame:Show()
    end
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

---@return Frame
local function CreateFCTFrame()
    if fctFrame then return fctFrame end

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
        self:Hide()  -- 處理完立即停止，下次有事件時再 Show()
        for i = 1, #pendingTexts do
            local entry = pendingTexts[i]
            ShowText(entry[1], entry[2], entry[3])
        end
        wipe(pendingTexts)
    end)

    -- 註冊戰鬥日誌事件
    fctFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    fctFrame:SetScript("OnEvent", OnCombatLogEvent)

    -- 納入 HUD 縮放和框架移動
    LunarUI:RegisterHUDFrame("LunarUI_FCT")
    LunarUI:RegisterMovableFrame("fct", fctFrame, "Floating Combat Text")

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
        wipe(pendingTexts)

        -- 回收所有活動中的文字
        for i = #activeTexts, 1, -1 do
            RecycleText(activeTexts[i])
        end

        fctFrame:Hide()
    end
    isEnabled = false
    playerGUID = nil
end

--------------------------------------------------------------------------------
-- 模組註冊
--------------------------------------------------------------------------------

LunarUI:RegisterModule("FloatingCombatText", {
    onEnable = function()
        local enabled = GetSettings()
        if not enabled then return end

        fctFrame = CreateFCTFrame()
        fctFrame:Show()
        isEnabled = true
    end,

    onDisable = function()
        CleanupFCT()
    end,

    delay = 0.5,
})
