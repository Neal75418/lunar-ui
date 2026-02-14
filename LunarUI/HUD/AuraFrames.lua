---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unused-local, undefined-global
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
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 效能：快取全域變數
--------------------------------------------------------------------------------

local math_floor = math.floor
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
local BAR_OFFSET = 1  -- 圖示與計時條間距

local function LoadSettings()
    ICON_SIZE = LunarUI.GetHUDSetting("auraIconSize", 30)
    ICON_SPACING = LunarUI.GetHUDSetting("auraIconSpacing", 4)
    ICONS_PER_ROW = LunarUI.GetHUDSetting("auraIconsPerRow", 8)
    MAX_BUFFS = LunarUI.GetHUDSetting("maxBuffs", 16)
    MAX_DEBUFFS = LunarUI.GetHUDSetting("maxDebuffs", 8)
    BAR_HEIGHT = LunarUI.GetHUDSetting("auraBarHeight", 4)
end

-- 過濾的 Buff 名稱（瑣碎增益）
local FILTERED_BUFF_NAMES = {
    -- 食物 / 休息
    ["充分休息"] = true,
    ["Well Rested"] = true,
    -- 死亡後虛弱
    ["復活虛弱"] = true,
    ["Resurrection Sickness"] = true,
}

local DEBUFF_TYPE_COLORS = LunarUI.DEBUFF_TYPE_COLORS

-- 計時條顏色（依剩餘時間）
local function GetTimerBarColor(remaining, duration)
    if not remaining or not duration or duration <= 0 then return 0.5, 0.5, 0.5 end
    local pct = remaining / duration
    if pct > 0.5 then
        return 0.2, 0.7, 0.2  -- 綠色
    elseif pct > 0.2 then
        return 0.9, 0.7, 0.1  -- 黃色
    else
        return 0.9, 0.2, 0.2  -- 紅色
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

-- /reload 時舊框架已在正確位置，不隱藏它（避免閃爍和位置跳動）

local AURA_THROTTLE = 0.1

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function ShouldShowBuff(name, _duration)
    -- WoW secret value 不能當 table index，用 pcall 保護
    local ok, isFiltered = pcall(function() return FILTERED_BUFF_NAMES[name] end)
    if not ok or isFiltered then
        return false
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
            pcall(GameTooltip.SetUnitBuffByAuraInstanceID, GameTooltip, "player", self.auraData.auraInstanceID, self.auraData.filter)
            GameTooltip:Show()
        end
    end)
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- 右鍵取消 Buff
    -- WoW 12.0: CancelSpellByName 可能已移除，優先使用 auraInstanceID
    icon:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.auraData and self.auraData.filter == "HELPFUL" then
            if InCombatLockdown() then return end  -- 戰鬥中不可取消

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

local function CreateAuraFrame(name, label, anchorPoint, offsetX, offsetY)
    local existingFrame = _G[name]
    local frame
    local isReused = false
    if existingFrame then
        frame = existingFrame
        isReused = true
        -- 清除舊的子物件（避免重載時重複）
        for _, child in ipairs({frame:GetRegions()}) do
            if child.lunarLabel then child:Show() end
        end
    else
        frame = CreateFrame("Frame", name, UIParent)
    end
    LunarUI:RegisterHUDFrame(name)

    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT
    frame:SetSize(
        ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING,
        totalIconHeight * 2 + ICON_SPACING + 16  -- 16 = 標籤高度
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
    buffFrame = CreateAuraFrame("LunarUI_BuffFrame", "增益", "TOPRIGHT", -215, -10)

    -- 減益框架 - 增益下方
    local buffHeight = buffFrame:GetHeight()
    debuffFrame = CreateAuraFrame("LunarUI_DebuffFrame", "減益", "TOPRIGHT", -215, -10 - buffHeight - 6)

    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT

    -- 建立 Buff 圖示（從右到左排列）
    for i = 1, MAX_BUFFS do
        buffIcons[i] = CreateAuraIcon(buffFrame, i)
        local row = math_floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        buffIcons[i]:SetPoint(
            "TOPRIGHT", buffFrame, "TOPRIGHT",
            -col * (ICON_SIZE + ICON_SPACING),
            -(row * (totalIconHeight + ICON_SPACING)) - 16  -- 16 = 標籤下方偏移
        )
    end

    -- 建立 Debuff 圖示
    for i = 1, MAX_DEBUFFS do
        debuffIcons[i] = CreateAuraIcon(debuffFrame, i)
        local row = math_floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        debuffIcons[i]:SetPoint(
            "TOPRIGHT", debuffFrame, "TOPRIGHT",
            -col * (ICON_SIZE + ICON_SPACING),
            -(row * (totalIconHeight + ICON_SPACING)) - 16
        )
    end
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateAuraIcon(iconFrame, auraData, index, filter, isDebuff)
    local name = tostring(auraData.name or "")
    local iconTexture = auraData.icon
    local count = tonumber(tostring(auraData.applications or 0)) or 0
    local duration = tonumber(tostring(auraData.duration or 0)) or 0
    local expirationTime = tonumber(tostring(auraData.expirationTime or 0)) or 0

    -- 圖示紋理
    iconFrame.texture:SetTexture(iconTexture)

    -- 邊框顏色
    if isDebuff then
        local debuffType = tostring(auraData.dispelName or "")
        local color = DEBUFF_TYPE_COLORS[debuffType] or DEBUFF_TYPE_COLORS[""]
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

    -- 計時條
    if duration > 0 and expirationTime > 0 then
        local remaining = expirationTime - GetTime()
        if remaining > 0 then
            -- 計時條寬度
            local pct = remaining / duration
            local barWidth = (ICON_SIZE - 2) * pct
            if barWidth < 1 then barWidth = 1 end
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

    -- 淡入動畫
    if iconFrame.currentAuraName ~= name then
        iconFrame.currentAuraName = name
        if iconFrame.fadeIn and not iconFrame:IsShown() then
            iconFrame.fadeIn:Play()
        end
    end

    iconFrame:Show()
end

local function UpdateAuraGroup(icons, maxIcons, isDebuff)
    local getDataFn = isDebuff and C_UnitAuras.GetDebuffDataByIndex or C_UnitAuras.GetBuffDataByIndex
    local filter = isDebuff and "HARMFUL" or "HELPFUL"
    local visibleIndex = 0

    for i = 1, 40 do
        local auraOk, auraData = pcall(getDataFn, "player", i)
        if not auraOk or not auraData then break end

        -- Fix 10: 合併 pcall — 同時取 name 和 duration，減少每個 aura 開銷
        local ok, nameStr, durNum = pcall(function()
            return tostring(auraData.name or ""), tonumber(auraData.duration or 0) or 0
        end)
        local name = ok and nameStr or ""
        local duration = ok and durNum or 0

        local shouldShow
        if isDebuff then
            shouldShow = true  -- 減益都顯示
        else
            shouldShow = ShouldShowBuff(name, duration)
        end

        if shouldShow then
            visibleIndex = visibleIndex + 1
            if visibleIndex <= maxIcons then
                UpdateAuraIcon(icons[visibleIndex], auraData, i, filter, isDebuff)
            end
        end
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
    if not buffFrame or not debuffFrame then return end
    if not buffFrame:IsShown() and not debuffFrame:IsShown() then return end

    UpdateAuraGroup(buffIcons, MAX_BUFFS, false)
    UpdateAuraGroup(debuffIcons, MAX_DEBUFFS, true)
end

-- 計時條即時更新（每幀更新計時條寬度和顏色）
local function UpdateTimerBars()
    local now = GetTime()

    local function UpdateIconTimers(icons, maxIcons)
        for i = 1, maxIcons do
            local iconFrame = icons[i]
            if not iconFrame or not iconFrame:IsShown() then break end
            if not iconFrame.auraData then break end

            -- 從冷卻框架反推持續時間
            local start, dur = iconFrame.cooldown:GetCooldownTimes()
            if start and dur and start > 0 and dur > 0 then
                start = start / 1000  -- GetCooldownTimes 回傳毫秒
                dur = dur / 1000
                local remaining = (start + dur) - now
                if remaining > 0 then
                    local pct = remaining / dur
                    local barWidth = (ICON_SIZE - 2) * pct
                    if barWidth < 1 then barWidth = 1 end
                    iconFrame.bar:SetWidth(barWidth)
                    local r, g, b = GetTimerBarColor(remaining, dur)
                    iconFrame.bar:SetVertexColor(r, g, b)
                else
                    iconFrame.bar:Hide()
                end
            end
        end
    end

    UpdateIconTimers(buffIcons, MAX_BUFFS)
    UpdateIconTimers(debuffIcons, MAX_DEBUFFS)
end

--------------------------------------------------------------------------------
-- 暴雪框架隱藏
--------------------------------------------------------------------------------

local blizzShowHooks = {}  -- 追蹤已 hook Show 的暴雪框架（避免重複 hook）

local function HideBlizzardBuffFrames()
    -- 不使用 SetParent（會造成 taint 汙染）
    -- 不使用 UnregisterAllEvents（無法還原，阻止即時 toggle 恢復）
    -- 改用 Hide + SetAlpha(0) + Hook Show 防止重新顯示
    local frames = { _G.BuffFrame, _G.DebuffFrame }
    for _, frame in ipairs(frames) do
        if frame then
            pcall(function() frame:Hide() end)
            pcall(function() frame:SetAlpha(0) end)
            -- Hook Show 防止暴雪代碼重新顯示（hooksecurefunc 不造成 taint）
            if not blizzShowHooks[frame] then
                blizzShowHooks[frame] = true
                pcall(function()
                    hooksecurefunc(frame, "Show", function(self)
                        if self._lunarUIAllowShow then return end
                        pcall(function() self:Hide() end)
                    end)
                end)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

-- Forward declarations（實際定義在下方事件處理區段）
local eventFrame
local timerElapsed = 0
local TIMER_UPDATE_INTERVAL = 0.05  -- 計時條 20 FPS

local function AuraOnUpdate(_self, elapsed)
    timerElapsed = timerElapsed + elapsed
    if timerElapsed >= TIMER_UPDATE_INTERVAL then
        timerElapsed = 0
        UpdateTimerBars()
    end
end

local function Initialize()
    if isInitialized then return end
    if LunarUI.GetHUDSetting("auraFrames", true) == false then return end

    LoadSettings()
    HideBlizzardBuffFrames()
    SetupFrames()

    -- 註冊至框架移動器（支援拖曳定位）
    if buffFrame then
        LunarUI:RegisterMovableFrame("BuffFrame", buffFrame, "增益框架")
    end
    if debuffFrame then
        LunarUI:RegisterMovableFrame("DebuffFrame", debuffFrame, "減益框架")
    end

    isInitialized = true

    -- 啟動計時條 OnUpdate
    eventFrame:SetScript("OnUpdate", AuraOnUpdate)

    -- 位置已同步套用，可以立即顯示
    if buffFrame then buffFrame:Show() end
    if debuffFrame then debuffFrame:Show() end
    UpdateAuras()
end

-- 暴露 Initialize 供 Options toggle 即時切換
LunarUI.InitAuraFrames = Initialize

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

-- 光環資料節流更新（用 C_Timer 取代 OnUpdate 輪詢）
local auraUpdateScheduled = false
local function ScheduleAuraUpdate()
    if auraUpdateScheduled then return end
    auraUpdateScheduled = true
    C_Timer.After(AURA_THROTTLE, function()
        auraUpdateScheduled = false
        if isInitialized then
            UpdateAuras()
        end
    end)
end

eventFrame = LunarUI.CreateEventHandler(
    {"PLAYER_ENTERING_WORLD", "UNIT_AURA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"},
    function(_self, event, arg1)
        if event == "PLAYER_ENTERING_WORLD" then
            if LunarUI.GetHUDSetting("auraFrames", true) == false then return end
            C_Timer.After(1.0, Initialize)
        elseif event == "UNIT_AURA" then
            if arg1 == "player" and isInitialized then
                ScheduleAuraUpdate()
            end
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- 戰鬥狀態切換時，確保框架可見並強制更新
            if isInitialized then
                if buffFrame and not buffFrame:IsShown() then buffFrame:Show() end
                if debuffFrame and not debuffFrame:IsShown() then debuffFrame:Show() end
                ScheduleAuraUpdate()
            end
        end
    end
)

--------------------------------------------------------------------------------
-- 匯出函數
--------------------------------------------------------------------------------

function LunarUI.ShowAuraFrames()
    if buffFrame then buffFrame:Show() end
    if debuffFrame then debuffFrame:Show() end
end

function LunarUI.HideAuraFrames()
    if buffFrame then buffFrame:Hide() end
    if debuffFrame then debuffFrame:Hide() end
end

function LunarUI.RefreshAuraFrames()
    UpdateAuras()
end

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
            local row = math_floor((i - 1) / ICONS_PER_ROW)
            local col = (i - 1) % ICONS_PER_ROW
            icons[i]:SetPoint(
                "TOPRIGHT", parentFrame, "TOPRIGHT",
                -col * (ICON_SIZE + ICON_SPACING),
                -(row * (totalIconHeight + ICON_SPACING)) - 16
            )
        end
    end
end

function LunarUI.RebuildAuraFrames()
    if not isInitialized then return end
    if InCombatLockdown() then return end

    local oldMaxBuffs = #buffIcons
    local oldMaxDebuffs = #debuffIcons
    LoadSettings()

    local totalIconHeight = ICON_SIZE + BAR_OFFSET + BAR_HEIGHT

    -- 重設框架大小
    if buffFrame then
        buffFrame:SetSize(
            ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING,
            totalIconHeight * 2 + ICON_SPACING + 16
        )
    end
    if debuffFrame then
        debuffFrame:SetSize(
            ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING,
            totalIconHeight * 2 + ICON_SPACING + 16
        )
    end

    -- 調整 Buff 圖示：重用現有、新增不足、隱藏多餘
    for i = 1, math.min(oldMaxBuffs, MAX_BUFFS) do
        ResizeAuraIcon(buffIcons[i])
    end
    for i = MAX_BUFFS + 1, oldMaxBuffs do
        if buffIcons[i] then buffIcons[i]:Hide() end
    end
    for i = oldMaxBuffs + 1, MAX_BUFFS do
        buffIcons[i] = CreateAuraIcon(buffFrame, i)
    end
    RelayoutIcons(buffIcons, buffFrame, MAX_BUFFS)

    -- 調整 Debuff 圖示
    for i = 1, math.min(oldMaxDebuffs, MAX_DEBUFFS) do
        ResizeAuraIcon(debuffIcons[i])
    end
    for i = MAX_DEBUFFS + 1, oldMaxDebuffs do
        if debuffIcons[i] then debuffIcons[i]:Hide() end
    end
    for i = oldMaxDebuffs + 1, MAX_DEBUFFS do
        debuffIcons[i] = CreateAuraIcon(debuffFrame, i)
    end
    RelayoutIcons(debuffIcons, debuffFrame, MAX_DEBUFFS)

    UpdateAuras()
end

function LunarUI.CleanupAuraFrames()
    if buffFrame then buffFrame:Hide() end
    if debuffFrame then debuffFrame:Hide() end

    -- 還原暴雪框架（標記 _lunarUIAllowShow 繞過 Show hook）
    for _, frame in ipairs({ _G.BuffFrame, _G.DebuffFrame }) do
        if frame then
            frame._lunarUIAllowShow = true
            pcall(function() frame:SetAlpha(1) end)
            pcall(function() frame:Show() end)
            frame._lunarUIAllowShow = nil
        end
    end

    -- 停止 OnUpdate 避免空轉（Initialize 會重新設定）
    if eventFrame then eventFrame:SetScript("OnUpdate", nil) end
    timerElapsed = 0

    isInitialized = false
    -- 不取消事件註冊：OnEvent 已有 isInitialized guard，
    -- 保留事件以便 toggle 重新啟用時 Initialize 能被正確呼叫
end

LunarUI:RegisterModule("AuraFrames", {
    onEnable = Initialize,
    onDisable = LunarUI.CleanupAuraFrames,
    delay = 1.5,
})
