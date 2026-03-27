---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 動作條淡入淡出與懸停偵測
    非戰鬥淡出動畫、滑鼠懸停偵測、戰鬥狀態追蹤
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local mathMax = math.max
local mathMin = math.min

-- M6: 不參與淡出的 bar key（Blizzard secure bars + 永遠可見的 microBar）
local FADE_EXCLUDED_KEYS = { extraActionButton = true, zoneAbilityButton = true, microBar = true }

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local isInCombat = false
local isBarsUnlocked = false -- 解鎖時完全停用淡出
local fadeInitialized = false
local fadeState = {} -- { [barKey] = { alpha, targetAlpha, hovered, timer } }

-- 懸停偵測系統（合併後的全域狀態）
local hoverCheckElapsed = 0
local barHoverStates = {} -- { [barKey] = { wasHovering = bool } }

-- A1/B5 效能修復：快取 fade 設定值，避免 UpdateFadeAndHover（每幀）和 IsBarFadeEnabled（每 bar）重複查 DB
local cachedFadeEnabled = true
local cachedFadeAlpha = 0.3
local cachedFadeDelay = 2.0
local cachedFadeDuration = 0.4
local cachedBaseAlpha = 1.0 -- #3: 快取 bar 基礎透明度，避免 SetBarAlpha 每幀查 DB

local function RefreshFadeSettingsCache()
    local db = LunarUI.GetModuleDB("actionbars") or {}
    cachedFadeEnabled = db.fadeEnabled ~= false
    cachedFadeAlpha = db.fadeAlpha or 0.3
    cachedFadeDelay = db.fadeDelay or 2.0
    cachedFadeDuration = db.fadeDuration or 0.4
    cachedBaseAlpha = db.alpha or 1.0 -- #3
end

local function IsBarFadeEnabled(barKey)
    if isBarsUnlocked then
        return false
    end
    if not cachedFadeEnabled then -- A1/B5: 使用快取值，避免每條動作列呼叫 GetFadeSettings()
        return false
    end

    -- 每條 bar 可獨立覆蓋
    local db = LunarUI.GetModuleDB("actionbars")
    if db and type(db[barKey]) == "table" and db[barKey].fadeEnabled ~= nil then
        return db[barKey].fadeEnabled
    end
    return true -- 預設跟隨全域設定
end

---@param bar Frame?
---@param alpha number
local function SetBarAlpha(bar, alpha)
    if not bar then
        return
    end
    bar:SetAlpha(alpha * cachedBaseAlpha) -- #3: 使用快取，避免動畫每幀查 DB
end

-- 平滑動畫框架
local fadeAnimFrame = CreateFrame("Frame")
local fadeAnimActive = false

-- 前向宣告（UpdateFadeAndHover 需要這些函數）
---@type fun(barKey: string, targetAlpha: number)
local FadeBarTo
---@type fun()
local StartFadeAnimation

-- 淡出動畫處理器（線性插值）
local function UpdateFadeAnimation(fadeEnabled, elapsed)
    if not (fadeAnimActive and fadeEnabled) then
        return false
    end

    local bars = LunarUI._actionBars
    local fadeDuration = cachedFadeDuration
    local anyActive = false

    for barKey, state in pairs(fadeState) do
        if state.alpha ~= state.targetAlpha then
            anyActive = true
            local bar = bars[barKey]
            if bar then
                local speed = (1.0 / mathMax(fadeDuration, 0.05)) * elapsed
                if state.alpha < state.targetAlpha then
                    state.alpha = mathMin(state.alpha + speed, state.targetAlpha)
                else
                    state.alpha = mathMax(state.alpha - speed, state.targetAlpha)
                end
                SetBarAlpha(bar, state.alpha)
            end
        end
    end

    if not anyActive then
        fadeAnimActive = false
    end

    return anyActive
end

-- 懸停偵測處理器（節流 0.05 秒）
local function UpdateHoverDetection(fadeEnabled, fadeAlpha, fadeDelay, elapsed)
    if isInCombat or not fadeEnabled or isBarsUnlocked then
        return
    end

    hoverCheckElapsed = hoverCheckElapsed + elapsed
    if hoverCheckElapsed < 0.05 then
        return
    end

    hoverCheckElapsed = 0

    local bars = LunarUI._actionBars
    for barKey, bar in pairs(bars) do
        if IsBarFadeEnabled(barKey) then
            -- 初始化懸停狀態
            if not barHoverStates[barKey] then
                barHoverStates[barKey] = { wasHovering = false }
            end
            local hoverState = barHoverStates[barKey]

            local isHovering = bar:IsMouseOver(8, -8, -8, 8)

            -- 滑鼠進入
            if isHovering and not hoverState.wasHovering then
                hoverState.wasHovering = true
                if not fadeState[barKey] then
                    fadeState[barKey] = {
                        alpha = 1.0,
                        targetAlpha = 1.0,
                        hovered = false,
                        timer = nil,
                    }
                end
                fadeState[barKey].hovered = true
                if fadeState[barKey].timer then
                    fadeState[barKey].timer:Cancel()
                    fadeState[barKey].timer = nil
                end
                FadeBarTo(barKey, 1.0)

            -- 滑鼠離開（fadeState[barKey] 已在進入時初始化，此處必然存在）
            elseif not isHovering and hoverState.wasHovering then
                hoverState.wasHovering = false
                local state = fadeState[barKey]
                if state then
                    state.hovered = false
                    if state.timer then
                        state.timer:Cancel()
                    end
                    state.timer = C_Timer.NewTimer(fadeDelay, function()
                        if not isInCombat and fadeState[barKey] and not fadeState[barKey].hovered then
                            FadeBarTo(barKey, fadeAlpha)
                        end
                        if fadeState[barKey] then
                            fadeState[barKey].timer = nil
                        end
                    end)
                end
            end
        end
    end
end

-- 合併的 OnUpdate 處理器（協調淡出動畫與懸停偵測）
local function UpdateFadeAndHover(_self, elapsed)
    -- A1/B5 效能修復：使用快取設定值，避免每幀查 DB
    local fadeEnabled, fadeAlpha, fadeDelay = cachedFadeEnabled, cachedFadeAlpha, cachedFadeDelay

    -- 執行淡出動畫
    local anyAnimActive = UpdateFadeAnimation(fadeEnabled, elapsed)

    -- 執行懸停偵測
    UpdateHoverDetection(fadeEnabled, fadeAlpha, fadeDelay, elapsed)

    -- 自動停止：無動畫且不需要懸停輪詢時
    -- 懸停輪詢需繼續的條件：有 bar 處於淡出狀態（alpha < 1.0 或 targetAlpha < 1.0）
    -- 或有 bar 目前被懸停中（需偵測滑鼠離開以觸發淡出計時器）
    -- 以上皆無時停止 OnUpdate，FadeBarTo 或滑鼠進入會在下次需要時重新啟動
    if not anyAnimActive then
        local needsHoverPoll = false
        if fadeEnabled and not isInCombat and not isBarsUnlocked then
            for _, state in pairs(fadeState) do
                if state.alpha < 1.0 or state.targetAlpha < 1.0 or state.hovered then
                    needsHoverPoll = true
                    break
                end
            end
        end
        if not needsHoverPoll then
            fadeAnimFrame:SetScript("OnUpdate", nil)
        end
    end
end

function FadeBarTo(barKey, targetAlpha)
    if not fadeState[barKey] then
        fadeState[barKey] = { alpha = 1.0, targetAlpha = 1.0, hovered = false, timer = nil }
    end
    fadeState[barKey].targetAlpha = targetAlpha
    StartFadeAnimation()
end

function StartFadeAnimation()
    if fadeAnimActive then
        return
    end
    fadeAnimActive = true
    RefreshFadeSettingsCache() -- A1/B5: 更新所有快取設定值（包含 duration）
    fadeAnimFrame:SetScript("OnUpdate", UpdateFadeAndHover)
end

local function FadeAllBarsOut()
    if not cachedFadeEnabled then -- A1/B5: 使用快取值
        return
    end

    local bars = LunarUI._actionBars
    for barKey in pairs(bars) do
        if not FADE_EXCLUDED_KEYS[barKey] and IsBarFadeEnabled(barKey) then -- M6: 跳過 Blizzard 安全框架
            if not fadeState[barKey] or not fadeState[barKey].hovered then
                FadeBarTo(barKey, cachedFadeAlpha)
            end
        end
    end
end

local function FadeAllBarsIn()
    local bars = LunarUI._actionBars
    for barKey in pairs(bars) do
        if not FADE_EXCLUDED_KEYS[barKey] then -- M6: 跳過 Blizzard 安全框架
            FadeBarTo(barKey, 1.0)
        end
    end
end

-- 懸停偵測：使用透明遮罩框架覆蓋整條 bar
-- barKey 不再需要傳入，懸停偵測已整合至全域 UpdateFadeAndHover
---@param bar Frame?
local function SetupBarHoverDetection(bar)
    if not bar or bar._lunarFadeHooked then
        return
    end
    bar._lunarFadeHooked = true

    -- 建立懸停偵測框架（覆蓋整條 bar + 邊距）
    local hoverFrame = CreateFrame("Frame", nil, bar)
    hoverFrame:SetPoint("TOPLEFT", -8, 8)
    hoverFrame:SetPoint("BOTTOMRIGHT", 8, -8)
    hoverFrame:SetFrameStrata(bar:GetFrameStrata())
    hoverFrame:SetFrameLevel(bar:GetFrameLevel() + 50)
    hoverFrame:EnableMouse(false) -- 不攔截點擊

    -- 懸停偵測已整合至 UpdateFadeAndHover 的統一 OnUpdate 中
    -- 不再需要每個 bar 獨立的 OnUpdate 腳本

    bar._lunarHoverFrame = hoverFrame
end

-- 戰鬥事件（檔案載入時建立，RefreshFadeSettingsCache 內有 or {} 防護）
local combatFrame = LunarUI.CreateEventHandler(
    { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" },
    function(_self, event)
        RefreshFadeSettingsCache() -- A1/B5: 更新快取（戰鬥狀態切換時設定可能已變更）
        if not cachedFadeEnabled then
            return
        end

        if event == "PLAYER_REGEN_DISABLED" then
            -- 進入戰鬥：全部淡入
            isInCombat = true
            FadeAllBarsIn()
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- 離開戰鬥：延遲淡出
            isInCombat = false
            C_Timer.After(cachedFadeDelay, function()
                if not fadeInitialized then
                    return
                end
                if not isInCombat then
                    FadeAllBarsOut()
                end
            end)
        end
    end
)

-- 初始化淡出狀態（非戰鬥時啟動淡出）
local function InitializeFade()
    if not combatFrame then
        return
    end
    -- 重新註冊戰鬥事件（Cleanup 後重新啟用時需要）
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    RefreshFadeSettingsCache() -- #2: 確保快取最新，避免兩次 GetFadeSettings() 查 DB
    if not cachedFadeEnabled then
        return
    end
    fadeInitialized = true

    -- 為每條 bar 設定懸停偵測
    local bars = LunarUI._actionBars
    for _, bar in pairs(bars) do
        SetupBarHoverDetection(bar)
    end

    -- 非戰鬥中立即啟動淡出
    if not InCombatLockdown() then
        isInCombat = false
        C_Timer.After(cachedFadeDelay, function() -- #2: 使用快取值
            if not fadeInitialized then
                return
            end
            if not isInCombat then
                FadeAllBarsOut()
            end
        end)
    else
        isInCombat = true
    end
end

-- 清理淡出系統
local function CleanupFade()
    fadeInitialized = false
    isInCombat = false -- 重設戰鬥狀態，避免 re-enable 後 hover 偵測誤判為戰鬥中
    fadeAnimFrame:SetScript("OnUpdate", nil)
    fadeAnimActive = false

    -- 清理淡出計時器
    for _, state in pairs(fadeState) do
        if state.timer then
            state.timer:Cancel()
            state.timer = nil
        end
    end
    wipe(fadeState)
    wipe(barHoverStates) -- 清理懸停狀態

    -- 解除戰鬥事件監聽（保留 frame 參照，重新啟用時可重新註冊）
    if combatFrame then
        combatFrame:UnregisterAllEvents()
    end
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.ABInitializeFade = InitializeFade
LunarUI.ABCleanupFade = CleanupFade
