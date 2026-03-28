---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, unused-local, undefined-global
--[[
    LunarUI - Buff/Debuff 框架（重新設計）
    在螢幕上顯示玩家的增益和減益效果

    功能：
    - 大圖示（40px）+ 倒數計時條
    - 分類標籤（增益 / 減益）
    - 智慧過濾（隱藏食物等瑣碎 Buff）
    - 減益類型著色（魔法/詛咒/疾病/毒）
    - 淡入動畫
    - 框架移動器整合
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local format = string.format
local L = Engine.L or {}
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 效能：快取全域變數
--------------------------------------------------------------------------------

local mathFloor = math.floor
local mathCeil = math.ceil
local mathMax = math.max
local mathMin = math.min
local GetTime = GetTime
local C_UnitAuras = C_UnitAuras
local ipairs = ipairs

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 預設值（初始化時從 DB 讀取）
local ICON_SIZE = 30
local ICON_SPACING = 4
local ICONS_PER_ROW = 8
local MAX_BUFFS = 16
local MAX_DEBUFFS = 8

-- 倒數計時條
local BAR_HEIGHT = 4
local BAR_OFFSET = 1 -- 圖示與計時條間距
local LABEL_HEIGHT = 16 -- 分類標籤（Buffs / Debuffs）高度

-- 暴雪 Buff/Debuff 框架名稱（延遲查詢，避免 WoW 12.0 EditMode 延遲建立時固化 nil 參照）
local BLIZZARD_BUFF_FRAME_NAMES = { "BuffFrame", "DebuffFrame" }

local function LoadSettings()
    ICON_SIZE = LunarUI.GetHUDSetting("auraIconSize", 30)
    ICON_SPACING = LunarUI.GetHUDSetting("auraIconSpacing", 4)
    ICONS_PER_ROW = LunarUI.GetHUDSetting("auraIconsPerRow", 8)
    MAX_BUFFS = LunarUI.GetHUDSetting("maxBuffs", 16)
    MAX_DEBUFFS = LunarUI.GetHUDSetting("maxDebuffs", 8)
    BAR_HEIGHT = LunarUI.GetHUDSetting("auraBarHeight", 4)
end

-- 過濾的 Buff spell ID（語系無關）
-- Well Rested 是 XP modifier，不是可見 aura，不需要過濾
local FILTERED_BUFF_IDS = {
    [15007] = true, -- Resurrection Sickness（復活虛弱）
}

local DEBUFF_TYPE_COLORS = LunarUI.DEBUFF_TYPE_COLORS

-- 計時條顏色（依剩餘時間）
local function GetTimerBarColor(remaining, duration)
    if not remaining or not duration or duration <= 0 then
        return 0.5, 0.5, 0.5
    end
    local pct = remaining / duration
    if pct > 0.5 then
        return 0.2, 0.7, 0.2 -- 綠色
    elseif pct > 0.2 then
        return 0.9, 0.7, 0.1 -- 黃色
    else
        return 0.9, 0.2, 0.2 -- 紅色
    end
end

local backdropTemplate = LunarUI.iconBackdropTemplate

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local buffFrame = nil
local debuffFrame = nil
local buffIcons = {}
local debuffIcons = {}
local isInitialized = false
local auraInitGeneration = 0
local auraCombatDeferFrame = nil -- singleton：戰鬥中 cleanup 時延遲還原 Blizzard 框架

-- /reload 時舊框架已在正確位置，不隱藏它（避免閃爍和位置跳動）

local AURA_THROTTLE = 0.1

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function ShouldShowBuff(_name, _duration, spellId)
    -- WoW 12.0: spellId 在戰鬥中為 secret value，
    -- pcall+rawget 保護 table 查詢避免 "table index is secret"
    if spellId then
        local ok, filtered = pcall(rawget, FILTERED_BUFF_IDS, spellId)
        if ok and filtered then
            return false
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- 圖示建立
--------------------------------------------------------------------------------

-- 建立圖示的視覺元素（紋理、冷卻、計時條、文字）
local function CreateAuraIconVisuals(icon)
    -- 圖示紋理
    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", 1, -1)
    texture:SetPoint("TOPRIGHT", -1, -1)
    texture:SetHeight(ICON_SIZE - 2)
    texture:SetTexCoord(unpack(LunarUI.ICON_TEXCOORD))
    icon.texture = texture

    -- 冷卻旋轉覆蓋
    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetPoint("TOPLEFT", 1, -1)
    cooldown:SetPoint("TOPRIGHT", -1, -1)
    cooldown:SetHeight(ICON_SIZE - 2)
    cooldown:SetDrawEdge(false)
    cooldown:SetSwipeColor(0, 0, 0, 0.6)
    cooldown:SetHideCountdownNumbers(true)
    icon.cooldown = cooldown

    -- 倒數計時條背景
    local barBg = icon:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("BOTTOMLEFT", 1, 1)
    barBg:SetPoint("BOTTOMRIGHT", -1, 1)
    barBg:SetHeight(BAR_HEIGHT)
    barBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    barBg:SetVertexColor(0, 0, 0, 0.6)
    icon.barBg = barBg

    -- 倒數計時條前景
    local bar = icon:CreateTexture(nil, "ARTWORK", nil, 1)
    bar:SetPoint("BOTTOMLEFT", 1, 1)
    bar:SetHeight(BAR_HEIGHT)
    bar:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetVertexColor(0.2, 0.7, 0.2)
    bar:SetWidth(ICON_SIZE - 2)
    icon.bar = bar

    -- 持續時間文字（隱藏，只靠計時條和冷卻旋轉顯示）
    local durationText = icon:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(durationText, 11, "OUTLINE")
    durationText:SetPoint("BOTTOM", icon, "BOTTOM", 0, BAR_HEIGHT + BAR_OFFSET + 1)
    durationText:SetTextColor(1, 1, 1)
    durationText:SetShadowOffset(1, -1)
    durationText:Hide()
    icon.duration = durationText

    -- 堆疊數量
    local count = icon:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(count, 13, "OUTLINE")
    count:SetPoint("TOPRIGHT", -1, -1)
    count:SetTextColor(1, 0.9, 0.5)
    icon.count = count
end

-- 設定淡入動畫
local function SetupAuraIconAnimation(icon)
    local fadeIn = icon:CreateAnimationGroup()
    local fadeAnim = fadeIn:CreateAnimation("Alpha")
    fadeAnim:SetFromAlpha(0)
    fadeAnim:SetToAlpha(1)
    fadeAnim:SetDuration(0.25)
    fadeAnim:SetOrder(1)
    icon.fadeIn = fadeIn
end

-- 設定 Tooltip 與點擊互動
local function SetupAuraIconInteraction(icon)
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(self)
        if self.auraData and self.auraData.auraInstanceID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- 使用 auraInstanceID 而非 index（WoW 12.0+ 支援）
            -- 根據 aura 類型使用對應的 Buff/Debuff tooltip method
            local tooltipMethod = self.auraData.isHarmful and GameTooltip.SetUnitDebuffByAuraInstanceID
                or GameTooltip.SetUnitBuffByAuraInstanceID
            pcall(tooltipMethod, GameTooltip, "player", self.auraData.auraInstanceID, self.auraData.filter)
            GameTooltip:Show()
        end
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 右鍵取消 Buff（使用普通 frame 的 OnMouseUp，非 SecureActionButtonTemplate）
    -- 限制：僅在非戰鬥、非 protected execution context 下有效。
    -- 若需戰鬥中取消，需改用 SecureActionButtonTemplate + type="cancelaura"，
    -- 但會大幅增加複雜度（每個 icon 需 secure button + 動態 attribute 更新）。
    -- 目前方案：戰鬥中靜默跳過（符合 WoW UI 慣例）。
    icon:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.auraData and self.auraData.filter == "HELPFUL" then
            if InCombatLockdown() then
                return
            end -- 戰鬥中不可取消

            local auraData = self.auraData
            -- 優先使用 auraInstanceID（12.0 推薦方式）
            if auraData.auraInstanceID and C_UnitAuras and C_UnitAuras.CancelAuraByAuraInstanceID then
                pcall(C_UnitAuras.CancelAuraByAuraInstanceID, "player", auraData.auraInstanceID)
            elseif CancelSpellByName and auraData.spellName and auraData.spellName ~= "" then
                pcall(CancelSpellByName, auraData.spellName)
            end
        end
    end)
end

local function CreateAuraIcon(parent)
    local totalHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT

    local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetSize(ICON_SIZE, totalHeight)
    icon:SetBackdrop(backdropTemplate)
    icon:SetBackdropColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], 0.85)
    icon:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.8)

    CreateAuraIconVisuals(icon)
    SetupAuraIconAnimation(icon)
    SetupAuraIconInteraction(icon)

    icon.currentAuraName = nil
    icon.auraData = nil
    icon:Hide()
    return icon
end

--------------------------------------------------------------------------------
-- 框架建立
--------------------------------------------------------------------------------

local function CreateAuraFrame(name, label, anchorPoint, offsetX, offsetY, maxIcons)
    local existingFrame = _G[name]
    local frame
    local isReused = false
    if existingFrame then
        frame = existingFrame
        isReused = true
    else
        frame = CreateFrame("Frame", name, UIParent)
    end
    LunarUI:RegisterHUDFrame(name)

    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT
    local rows = mathCeil((maxIcons or MAX_BUFFS) / ICONS_PER_ROW)
    frame:SetSize(
        ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING,
        totalIconHeight * rows + mathMax(0, rows - 1) * ICON_SPACING + LABEL_HEIGHT
    )
    -- 重用舊框架時保留其位置（/reload 時舊框架已在正確位置）
    if not isReused then
        frame:ClearAllPoints()
        frame:SetPoint(anchorPoint, UIParent, anchorPoint, offsetX, offsetY)
    end
    frame:SetFrameStrata("HIGH")
    -- 重用框架時保持可見（避免 /reload 閃爍）；新框架則隱藏等初始化
    if not isReused then
        frame:Hide()
    end

    -- 分類標籤（隱藏，只顯示圖示）
    if not frame.label then
        local labelText = frame:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(labelText, 11, "OUTLINE")
        labelText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        labelText:SetTextColor(0.7, 0.7, 0.7, 0.8)
        labelText:SetText(label)
        labelText.lunarLabel = true
        labelText:Hide()
        frame.label = labelText
    end

    return frame
end

local function SetupFrames()
    -- 增益框架 - 螢幕右上
    buffFrame = CreateAuraFrame("LunarUI_BuffFrame", L["Buffs"] or "Buffs", "TOPRIGHT", -215, -10, MAX_BUFFS)

    -- 減益框架 - 增益下方
    local buffHeight = buffFrame:GetHeight()
    debuffFrame = CreateAuraFrame(
        "LunarUI_DebuffFrame",
        L["Debuffs"] or "Debuffs",
        "TOPRIGHT",
        -215,
        -10 - buffHeight - 6,
        MAX_DEBUFFS
    )

    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT

    -- 建立 Buff 圖示（從右到左排列，重用已存在的框架）
    for i = 1, MAX_BUFFS do
        if not buffIcons[i] then
            buffIcons[i] = CreateAuraIcon(buffFrame)
        end
        local row = mathFloor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        buffIcons[i]:SetPoint(
            "TOPRIGHT",
            buffFrame,
            "TOPRIGHT",
            -col * (ICON_SIZE + ICON_SPACING),
            -(row * (totalIconHeight + ICON_SPACING)) - LABEL_HEIGHT -- 16 = 標籤下方偏移
        )
    end

    -- 建立 Debuff 圖示（重用已存在的框架）
    for i = 1, MAX_DEBUFFS do
        if not debuffIcons[i] then
            debuffIcons[i] = CreateAuraIcon(debuffFrame)
        end
        local row = mathFloor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        debuffIcons[i]:SetPoint(
            "TOPRIGHT",
            debuffFrame,
            "TOPRIGHT",
            -col * (ICON_SIZE + ICON_SPACING),
            -(row * (totalIconHeight + ICON_SPACING)) - LABEL_HEIGHT
        )
    end
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

-- #8: 接受預先淨化的參數，避免與 UpdateAuraGroup 重複做 tostring/tonumber（每個 aura 多 4 次轉換）
-- WoW 12.0: 即使經過 tonumber(tostring()) / "" .. tostring() 淨化，
-- aura 數據在戰鬥中仍可能攜帶 taint，整個函式用 pcall 保護
local function UpdateAuraIconInner(iconFrame, auraData, name, count, duration, expirationTime, filter, isDebuff)
    -- H-3: 斷開 taint 鏈（aura API 回傳的 icon fileID 可能攜帶 taint）
    local iconTexture = tonumber(auraData.icon) or tostring(auraData.icon or "")

    -- 圖示紋理
    iconFrame.texture:SetTexture(iconTexture)

    -- 邊框顏色
    if isDebuff then
        local debuffType = "" .. tostring(auraData.dispelName or "")
        local ok, color = pcall(rawget, DEBUFF_TYPE_COLORS, debuffType)
        if not ok or not color then
            color = DEBUFF_TYPE_COLORS[""] -- 退回預設 debuff 顏色
        end
        iconFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
    else
        iconFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.8)
    end

    -- 堆疊數量
    if count > 1 then
        iconFrame.count:SetText(count)
        iconFrame.count:Show()
    else
        iconFrame.count:Hide()
    end

    -- 快取持續時間（供 UpdateIconTimers 使用，避免每 0.1s 呼叫 GetCooldownTimes）
    iconFrame._cachedDuration = duration
    iconFrame._cachedExpiration = expirationTime

    -- 計時條
    if duration > 0 and expirationTime > 0 then
        local remaining = expirationTime - GetTime()
        if remaining > 0 then
            -- 計時條寬度
            local pct = remaining / duration
            local barWidth = (ICON_SIZE - 2) * pct
            if barWidth < 1 then
                barWidth = 1
            end
            iconFrame.bar:SetWidth(barWidth)

            -- 計時條顏色
            local r, g, b = GetTimerBarColor(remaining, duration)
            iconFrame.bar:SetVertexColor(r, g, b)
            iconFrame.bar:Show()
            iconFrame.barBg:Show()

            -- 冷卻旋轉
            iconFrame.cooldown:SetCooldown(expirationTime - duration, duration)
        else
            iconFrame.duration:SetText("")
            iconFrame.bar:Hide()
            iconFrame.barBg:Hide()
            iconFrame.cooldown:Clear()
        end
    else
        -- 永久 Buff（無持續時間）
        iconFrame.duration:SetText("")
        iconFrame.bar:Hide()
        iconFrame.barBg:Hide()
        iconFrame.cooldown:Clear()
    end

    -- Tooltip 資料 (使用 auraInstanceID 而非 index，避免 index 過期)
    -- 重用現有 table 避免 GC 壓力
    if not iconFrame.auraData then
        iconFrame.auraData = {}
    end
    iconFrame.auraData.auraInstanceID = auraData.auraInstanceID
    iconFrame.auraData.spellName = name
    iconFrame.auraData.filter = filter
    iconFrame.auraData.isHarmful = (filter == "HARMFUL")

    -- 淡入動畫：aura 替換時也需重播（不限於首次顯示）
    -- WoW 12.0: name 可能仍帶 taint（"" .. tostring() 不一定斷鏈），pcall 保護比較
    local nameChanged = true
    pcall(function()
        nameChanged = (iconFrame.currentAuraName ~= name)
    end)
    if nameChanged then
        iconFrame.currentAuraName = name
        if iconFrame.fadeIn then
            iconFrame.fadeIn:Stop()
            iconFrame.fadeIn:Play()
        end
    end

    iconFrame:Show()
end

local function UpdateAuraIcon(iconFrame, auraData, name, count, duration, expirationTime, filter, isDebuff)
    local ok, _err =
        pcall(UpdateAuraIconInner, iconFrame, auraData, name, count, duration, expirationTime, filter, isDebuff)
    if not ok and iconFrame then
        -- taint 錯誤時靜默忽略，保留圖示現有狀態（戰鬥結束後下次更新會修正）
        iconFrame:Show()
    end
end

local function UpdateAuraGroup(icons, maxIcons, isDebuff)
    local getDataFn = isDebuff and C_UnitAuras.GetDebuffDataByIndex or C_UnitAuras.GetBuffDataByIndex
    local filter = isDebuff and "HARMFUL" or "HELPFUL"
    local visibleIndex = 0

    for i = 1, 40 do
        -- H3 效能修復：taint 下 WoW API 回傳 nil 而非拋出例外，不需 pcall 包裹每個 index
        -- tostring/tonumber 在下方已做 taint 斷鏈，直接呼叫更有效率
        local auraData = getDataFn("player", i)
        if not auraData then
            break
        end

        -- P6 效能：type guard 避免非戰鬥時不必要的 tostring/tonumber 轉換
        -- 戰鬥中 aura data 欄位可能是 secret value，需要 tostring 斷鏈
        local rawName = auraData.name
        local name = type(rawName) == "string" and rawName or ("" .. tostring(rawName or ""))
        local rawDur = auraData.duration
        local duration = type(rawDur) == "number" and rawDur or (tonumber(tostring(rawDur or 0)) or 0)

        local shouldShow
        if isDebuff then
            shouldShow = true -- 減益都顯示
        else
            shouldShow = ShouldShowBuff(name, duration, auraData.spellId)
        end

        if shouldShow then
            visibleIndex = visibleIndex + 1
            if visibleIndex <= maxIcons then
                local rawCount = auraData.applications
                local count = type(rawCount) == "number" and rawCount or (tonumber(tostring(rawCount or 0)) or 0)
                local rawExp = auraData.expirationTime
                local expirationTime = type(rawExp) == "number" and rawExp or (tonumber(tostring(rawExp or 0)) or 0)
                UpdateAuraIcon(icons[visibleIndex], auraData, name, count, duration, expirationTime, filter, isDebuff)
            end
        end
    end

    -- 戰鬥中若 API 回傳空資料（taint 限制導致），保留現有圖示不清除
    -- 避免 "介面功能因插件而失效" 後所有 buff 圖示消失
    -- 取捨：若所有 aura 在戰鬥中真的同時過期，圖示會短暫保留直到下次成功查詢
    if visibleIndex == 0 and InCombatLockdown() then
        return
    end

    -- 隱藏多餘圖示
    for i = visibleIndex + 1, maxIcons do
        if icons[i] then
            icons[i]:Hide()
            icons[i].currentAuraName = nil
        end
    end
end

local function UpdateAuras()
    if not buffFrame or not debuffFrame then
        return
    end
    if not buffFrame:IsShown() and not debuffFrame:IsShown() then
        return
    end

    UpdateAuraGroup(buffIcons, MAX_BUFFS, false)
    UpdateAuraGroup(debuffIcons, MAX_DEBUFFS, true)
end

-- 計時條即時更新（每幀更新計時條寬度和顏色）
-- C4 效能修復：UpdateIconTimers 提升為模組層 function，now 以參數傳入，避免每 0.1s 建立 closure
-- P3 效能修復：使用快取的 duration/expirationTime（UpdateAuraIcon 設定），省去 GetCooldownTimes C call
local function UpdateIconTimers(icons, maxIcons, now)
    for i = 1, maxIcons do
        local iconFrame = icons[i]
        if iconFrame and iconFrame:IsShown() and iconFrame.auraData then
            local dur = iconFrame._cachedDuration
            local expiration = iconFrame._cachedExpiration
            if dur and dur > 0 and expiration and expiration > 0 then
                local remaining = expiration - now
                if remaining > 0 then
                    local pct = remaining / dur
                    local barWidth = (ICON_SIZE - 2) * pct
                    if barWidth < 1 then
                        barWidth = 1
                    end
                    iconFrame.bar:SetWidth(barWidth)
                    local r, g, b = GetTimerBarColor(remaining, dur)
                    iconFrame.bar:SetVertexColor(r, g, b)
                else
                    iconFrame.bar:Hide()
                    iconFrame.barBg:Hide()
                end
            end
        end
    end
end

local function UpdateTimerBars()
    local now = GetTime()
    UpdateIconTimers(buffIcons, MAX_BUFFS, now)
    UpdateIconTimers(debuffIcons, MAX_DEBUFFS, now)
end

--------------------------------------------------------------------------------
-- 暴雪框架隱藏
--------------------------------------------------------------------------------

local function HideBlizzardBuffFrames()
    -- 策略：SetScale(0.001) + SetAlpha(0) 使框架不可見
    -- 即使戰鬥中 Blizzard 再次 Show() 或 SetAlpha(1)，
    -- scale 0.001 使框架僅有次像素大小，肉眼不可見且無法點擊
    -- 不呼叫 Hide() — WoW 12.0 的 BuffFrame 是 EditMode 管理框架，
    -- Hide 會導致 Blizzard aura 管理系統停止更新，影響 C_UnitAuras 事件
    -- 不使用 hooksecurefunc — hook 在戰鬥中觸發會造成 taint 傳播
    -- 不使用 SetParent（造成 taint）
    -- 不使用 UnregisterAllEvents（無法還原，阻止 toggle 恢復）
    if InCombatLockdown() then
        return
    end
    for _, frameName in ipairs(BLIZZARD_BUFF_FRAME_NAMES) do
        local frame = _G[frameName]
        if frame then
            pcall(function()
                frame:SetScale(0.001)
                frame:SetAlpha(0)
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

-- 前向宣告（實際定義在下方事件處理區段）
local eventFrame
local timerElapsed = 0
local TIMER_UPDATE_INTERVAL = 0.1 -- 計時條 10 FPS（視覺無差異，減少 50% CPU）

local function AuraOnUpdate(_self, elapsed)
    timerElapsed = timerElapsed + elapsed
    if timerElapsed >= TIMER_UPDATE_INTERVAL then
        timerElapsed = 0
        UpdateTimerBars()
    end
end

local function Initialize()
    if isInitialized then
        return
    end
    if LunarUI.GetHUDSetting("auraFrames", true) == false then
        return
    end

    LoadSettings()
    HideBlizzardBuffFrames()
    SetupFrames()

    -- 註冊至框架移動器（支援拖曳定位）
    if buffFrame then
        LunarUI.RegisterMovableFrame("BuffFrame", buffFrame, L["HUDBuffFrame"] or "Buff Frame")
    end
    if debuffFrame then
        LunarUI.RegisterMovableFrame("DebuffFrame", debuffFrame, L["HUDDebuffFrame"] or "Debuff Frame")
    end

    isInitialized = true

    -- 啟動計時條 OnUpdate
    eventFrame:SetScript("OnUpdate", AuraOnUpdate)

    -- 位置已同步套用，可以立即顯示
    if buffFrame then
        buffFrame:Show()
    end
    if debuffFrame then
        debuffFrame:Show()
    end
    UpdateAuras()
end

-- 暴露函數供 Options toggle 即時切換與測試使用
LunarUI.InitAuraFrames = Initialize
LunarUI.GetTimerBarColor = GetTimerBarColor
LunarUI.ShouldShowBuff = ShouldShowBuff

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

-- 光環資料節流更新（用 C_Timer 取代 OnUpdate 輪詢）
local auraUpdateScheduled = false
-- B2 效能修復：提升為具名模組函數，避免 ScheduleAuraUpdate 每次觸發都建立新 closure
local function OnAuraTimerFired()
    auraUpdateScheduled = false
    if isInitialized then
        UpdateAuras()
    end
end
local function ScheduleAuraUpdate()
    if auraUpdateScheduled then
        return
    end
    auraUpdateScheduled = true
    C_Timer.After(AURA_THROTTLE, OnAuraTimerFired)
end

eventFrame = LunarUI.CreateEventHandler(
    { "PLAYER_ENTERING_WORLD", "UNIT_AURA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" },
    function(_self, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            -- 初始化由 RegisterModule delay=0.3 統一處理，PEW 只負責已初始化後的強制更新
            if isInitialized then
                UpdateAuras()
            end
        elseif event == "UNIT_AURA" then
            if arg1 == "player" and isInitialized then
                ScheduleAuraUpdate()
            end
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- 戰鬥狀態切換時，確保 LunarUI 框架可見並強制更新
            if isInitialized then
                if buffFrame and not buffFrame:IsShown() then
                    buffFrame:Show()
                end
                if debuffFrame and not debuffFrame:IsShown() then
                    debuffFrame:Show()
                end
                ScheduleAuraUpdate()
                -- 離開戰鬥時，重新確保暴雪框架被隱藏
                -- （戰鬥中 Blizzard 可能改變了框架狀態）
                if event == "PLAYER_REGEN_ENABLED" then
                    HideBlizzardBuffFrames()
                end
            end
        end
    end
)

--------------------------------------------------------------------------------
-- 匯出函數
--------------------------------------------------------------------------------

-- 調整單個圖示的大小與內部元素
local function ResizeAuraIcon(icon)
    local totalHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT
    icon:SetSize(ICON_SIZE, totalHeight)
    if icon.texture then
        icon.texture:ClearAllPoints()
        icon.texture:SetPoint("TOPLEFT", 1, -1)
        icon.texture:SetPoint("TOPRIGHT", -1, -1)
        icon.texture:SetHeight(ICON_SIZE - 2)
    end
    if icon.cooldown then
        icon.cooldown:ClearAllPoints()
        icon.cooldown:SetPoint("TOPLEFT", 1, -1)
        icon.cooldown:SetPoint("TOPRIGHT", -1, -1)
        icon.cooldown:SetHeight(ICON_SIZE - 2)
    end
    if icon.barBg then
        icon.barBg:SetHeight(BAR_HEIGHT)
    end
    if icon.bar then
        icon.bar:SetHeight(BAR_HEIGHT)
        icon.bar:SetWidth(ICON_SIZE - 2)
    end
    if icon.duration then
        icon.duration:ClearAllPoints()
        icon.duration:SetPoint("BOTTOM", icon, "BOTTOM", 0, BAR_HEIGHT + BAR_OFFSET + 1)
    end
end

-- 重新定位圖示列表
local function RelayoutIcons(icons, parentFrame, maxCount)
    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT
    for i = 1, maxCount do
        if icons[i] then
            icons[i]:ClearAllPoints()
            local row = mathFloor((i - 1) / ICONS_PER_ROW)
            local col = (i - 1) % ICONS_PER_ROW
            icons[i]:SetPoint(
                "TOPRIGHT",
                parentFrame,
                "TOPRIGHT",
                -col * (ICON_SIZE + ICON_SPACING),
                -(row * (totalIconHeight + ICON_SPACING)) - LABEL_HEIGHT
            )
        end
    end
end

function LunarUI.RebuildAuraFrames()
    if not isInitialized then
        return
    end
    if InCombatLockdown() then
        return
    end

    local oldMaxBuffs = #buffIcons
    local oldMaxDebuffs = #debuffIcons
    LoadSettings()

    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT

    -- 重設框架大小（依實際列數計算，避免 ICONS_PER_ROW 調小時圖示超出框架邊界）
    if buffFrame then
        local buffRows = mathCeil(MAX_BUFFS / ICONS_PER_ROW)
        buffFrame:SetSize(
            ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING,
            totalIconHeight * buffRows + mathMax(0, buffRows - 1) * ICON_SPACING + LABEL_HEIGHT
        )
    end
    if debuffFrame then
        local debuffRows = mathCeil(MAX_DEBUFFS / ICONS_PER_ROW)
        debuffFrame:SetSize(
            ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING,
            totalIconHeight * debuffRows + mathMax(0, debuffRows - 1) * ICON_SPACING + LABEL_HEIGHT
        )
    end

    -- 調整 Buff 圖示：重用現有、新增不足、隱藏多餘
    for i = 1, mathMin(oldMaxBuffs, MAX_BUFFS) do
        ResizeAuraIcon(buffIcons[i])
    end
    for i = MAX_BUFFS + 1, oldMaxBuffs do
        if buffIcons[i] then
            buffIcons[i]:Hide()
        end
    end
    for i = oldMaxBuffs + 1, MAX_BUFFS do
        buffIcons[i] = CreateAuraIcon(buffFrame)
    end
    RelayoutIcons(buffIcons, buffFrame, MAX_BUFFS)

    -- 調整 Debuff 圖示
    for i = 1, mathMin(oldMaxDebuffs, MAX_DEBUFFS) do
        ResizeAuraIcon(debuffIcons[i])
    end
    for i = MAX_DEBUFFS + 1, oldMaxDebuffs do
        if debuffIcons[i] then
            debuffIcons[i]:Hide()
        end
    end
    for i = oldMaxDebuffs + 1, MAX_DEBUFFS do
        debuffIcons[i] = CreateAuraIcon(debuffFrame)
    end
    RelayoutIcons(debuffIcons, debuffFrame, MAX_DEBUFFS)

    UpdateAuras()
end

function LunarUI.CleanupAuraFrames()
    if buffFrame then
        buffFrame:Hide()
    end
    if debuffFrame then
        debuffFrame:Hide()
    end

    -- C-1: 清空圖示陣列（避免重新初始化時覆蓋參照但孤兒 Frame 仍掛在 parent）
    for i = 1, #buffIcons do
        if buffIcons[i] then
            buffIcons[i]:Hide()
        end
    end
    for i = 1, #debuffIcons do
        if debuffIcons[i] then
            debuffIcons[i]:Hide()
        end
    end
    wipe(buffIcons)
    wipe(debuffIcons)
    -- 清除框架 upvalue（WoW 框架不可銷毀，但 upvalue 必須重置讓 SetupFrames 能重新發現全域框架）
    buffFrame = nil
    debuffFrame = nil

    -- 還原暴雪框架（恢復 scale / alpha — HideBlizzardBuffFrames 不使用 Hide，故不需 Show）
    if not InCombatLockdown() then
        for _, frameName in ipairs(BLIZZARD_BUFF_FRAME_NAMES) do
            local frame = _G[frameName]
            if frame then
                pcall(function()
                    frame:SetScale(1)
                    frame:SetAlpha(1)
                end)
            end
        end
    else
        -- 戰鬥中無法操作框架屬性，延遲至脫戰後還原
        if not auraCombatDeferFrame then
            auraCombatDeferFrame = CreateFrame("Frame")
            auraCombatDeferFrame:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                if LunarUI._modulesEnabled then
                    return
                end -- 脫戰前又重新啟用了，不需還原
                for _, frameName in ipairs(BLIZZARD_BUFF_FRAME_NAMES) do
                    local frame = _G[frameName]
                    if frame then
                        pcall(function()
                            frame:SetScale(1)
                            frame:SetAlpha(1)
                        end)
                    end
                end
            end)
        end
        auraCombatDeferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end

    -- 停止 OnUpdate 避免空轉（Initialize 會重新設定）
    if eventFrame then
        eventFrame:SetScript("OnUpdate", nil)
    end
    timerElapsed = 0

    -- H-1: 重置排程旗標，避免 re-enable 後首次 UNIT_AURA 靜默失敗
    auraUpdateScheduled = false
    auraInitGeneration = auraInitGeneration + 1

    isInitialized = false
    -- 不取消事件註冊：OnEvent 已有 isInitialized guard，
    -- 保留事件以便 toggle 重新啟用時 Initialize 能被正確呼叫
end

--------------------------------------------------------------------------------
-- 診斷工具
--------------------------------------------------------------------------------

function LunarUI.DebugAuraFrames()
    local lines = {}
    local function add(text)
        lines[#lines + 1] = text
    end
    local function safeNum(val)
        return tonumber(tostring(val or 0)) or 0
    end

    add("=== AuraFrames Debug ===")
    add("isInitialized=" .. tostring(isInitialized))
    add("InCombatLockdown=" .. tostring(InCombatLockdown()))

    -- 框架狀態
    for _, info in ipairs({
        { name = "LunarUI_BuffFrame", frame = buffFrame },
        { name = "LunarUI_DebuffFrame", frame = debuffFrame },
    }) do
        local f = info.frame
        if f then
            local shown, visible, alpha, effAlpha, scale, effScale = "?", "?", 0, 0, 0, 0
            pcall(function()
                shown = f:IsShown() and "shown" or "HIDDEN"
            end)
            pcall(function()
                visible = f:IsVisible() and "visible" or "INVISIBLE"
            end)
            pcall(function()
                alpha = safeNum(f:GetAlpha())
            end)
            pcall(function()
                effAlpha = safeNum(f:GetEffectiveAlpha())
            end)
            pcall(function()
                scale = safeNum(f:GetScale())
            end)
            pcall(function()
                effScale = safeNum(f:GetEffectiveScale())
            end)
            local pos = "?"
            pcall(function()
                local p, rel, _rp, px, py = f:GetPoint(1)
                local relName = rel and (rel.GetName and rel:GetName() or "unnamed") or "nil"
                pos = format("%s@%s(%+.0f,%+.0f)", tostring(p), relName, safeNum(px), safeNum(py))
            end)
            local parent = "?"
            pcall(function()
                local pp = f:GetParent()
                parent = pp and (pp.GetName and pp:GetName() or "unnamed") or "nil"
            end)
            add(
                format(
                    "%s: %s/%s a=%.2f effA=%.2f sc=%.3f effSc=%.4f pos=%s parent=%s",
                    info.name,
                    shown,
                    visible,
                    alpha,
                    effAlpha,
                    scale,
                    effScale,
                    pos,
                    parent
                )
            )
        else
            add(info.name .. ": NIL (frame not created)")
        end
    end

    -- 圖示可見數量
    local buffCount, debuffCount = 0, 0
    for i = 1, MAX_BUFFS do
        if buffIcons[i] and buffIcons[i]:IsShown() then
            buffCount = buffCount + 1
        end
    end
    for i = 1, MAX_DEBUFFS do
        if debuffIcons[i] and debuffIcons[i]:IsShown() then
            debuffCount = debuffCount + 1
        end
    end
    add(format("Visible icons: buff=%d/%d debuff=%d/%d", buffCount, MAX_BUFFS, debuffCount, MAX_DEBUFFS))

    -- 光環資料測試
    add("--- C_UnitAuras Test ---")
    for i = 1, 5 do
        local ok, data = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
        if not ok then
            add(format("  Buff[%d]: ERROR: %s", i, tostring(data)))
            break
        elseif not data then
            add(format("  Buff[%d]: nil (no more buffs)", i))
            break
        else
            local name = "?"
            pcall(function()
                name = tostring(data.name or "?")
            end)
            add(format("  Buff[%d]: %s", i, name))
        end
    end

    -- 暴雪框架狀態
    add("--- Blizzard Frames ---")
    for _, name in ipairs({ "BuffFrame", "DebuffFrame" }) do
        local f = _G[name]
        if f then
            local shown, alpha, scale = "?", 0, 0
            pcall(function()
                shown = f:IsShown() and "shown" or "hidden"
            end)
            pcall(function()
                alpha = safeNum(f:GetAlpha())
            end)
            pcall(function()
                scale = safeNum(f:GetScale())
            end)
            add(format("  %s: %s a=%.2f sc=%.4f", name, shown, alpha, scale))
        end
    end

    -- 輸出
    add("=== End AuraFrames Debug ===")
    for _, line in ipairs(lines) do
        LunarUI:Print("|cff88bbff[AuraDebug]|r " .. tostring(line))
    end
end

LunarUI:RegisterModule("AuraFrames", {
    onEnable = Initialize,
    onDisable = LunarUI.CleanupAuraFrames,
    delay = 0.3,
    lifecycle = "reversible",
})
