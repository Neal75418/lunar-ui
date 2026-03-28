---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if
--[[
    LunarUI - DataBars 模組
    經驗值、聲望、榮譽進度條

    功能：
    - 經驗值條（含休息經驗顯示）
    - 聲望條（追蹤陣營）
    - 榮譽條（PvP 等級進度）
    - 月相感知透明度
    - 滑鼠懸停顯示提示
    - 可設定大小、位置、文字格式
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local statusBarTexture -- 延遲載入：DB 就緒後解析
local function GetStatusBarTexture()
    if not statusBarTexture then
        statusBarTexture = LunarUI.GetSelectedStatusBarTexture()
    end
    return statusBarTexture
end
local format = string.format
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min

-- 陣營聲望顏色（對應暴雪 FACTION_BAR_COLORS）
local STANDING_COLORS = {
    [1] = { r = 0.80, g = 0.13, b = 0.13 }, -- 仇恨
    [2] = { r = 0.80, g = 0.25, b = 0.00 }, -- 敵對
    [3] = { r = 0.75, g = 0.27, b = 0.00 }, -- 不友好
    [4] = { r = 0.85, g = 0.77, b = 0.36 }, -- 中立
    [5] = { r = 0.00, g = 0.67, b = 0.00 }, -- 友善
    [6] = { r = 0.00, g = 0.39, b = 0.88 }, -- 尊敬
    [7] = { r = 0.64, g = 0.21, b = 0.93 }, -- 崇敬
    [8] = { r = 1.00, g = 0.67, b = 0.00 }, -- 崇拜
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local bars = {} -- 所有已建立的資料條框架

-- P-perf: 快取 DB 設定，避免事件處理器每次呼叫 GetModuleDB
local cachedExpEnabled = false
local cachedExpTextFmt = "percent"
local cachedRepEnabled = false
local cachedRepTextFmt = "percent"
local cachedHonEnabled = false
local cachedHonTextFmt = "percent"

local function RefreshDataBarsCache()
    local db = LunarUI.GetModuleDB("databars")
    cachedExpEnabled = db and db.experience and db.experience.enabled ~= false
    cachedExpTextFmt = db and db.experience and db.experience.textFormat or "percent"
    cachedRepEnabled = db and db.reputation and db.reputation.enabled ~= false
    cachedRepTextFmt = db and db.reputation and db.reputation.textFormat or "percent"
    cachedHonEnabled = db and db.honor and db.honor.enabled ~= false
    cachedHonTextFmt = db and db.honor and db.honor.textFormat or "percent"
end
local eventFrame -- 共用事件處理框架

--------------------------------------------------------------------------------
-- 輔助：建立單一資料條
--------------------------------------------------------------------------------

local function CreateDataBar(name, db)
    -- 重用已存在的具名 frame（re-enable 場景），避免 duplicate frame 錯誤
    local existingBar = _G["LunarUI_DataBar_" .. name]
    local bar = existingBar or CreateFrame("StatusBar", "LunarUI_DataBar_" .. name, UIParent, "BackdropTemplate")
    bar:SetStatusBarTexture(GetStatusBarTexture())
    bar:SetSize(db.width or 400, db.height or 8)
    bar:SetPoint(db.point or "BOTTOM", UIParent, db.point or "BOTTOM", db.x or 0, db.y or 2)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(2)

    -- 背景框
    LunarUI.ApplyBackdrop(bar)

    -- 子元件只在首次建立時建立（WoW CreateTexture/CreateFontString 不可刪除，重用 frame 時不重建）
    if not existingBar then
        -- 背景
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetVertexColor(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])

        -- 文字覆蓋
        bar.text = bar:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(bar.text, 10, "OUTLINE")
        bar.text:SetPoint("CENTER")

        -- 休息經驗覆蓋（僅限經驗條）
        bar.rested = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        bar.rested:SetVertexColor(0.0, 0.4, 0.8, 0.4)
        bar.rested:Hide()
    end

    -- 每次都更新材質和大小（可能因 DB 設定改變）
    bar.bg:SetTexture(GetStatusBarTexture())
    bar.rested:SetTexture(GetStatusBarTexture())
    bar.rested:SetHeight(db.height or 8)

    if db.showText then
        bar.text:Show()
    else
        bar.text:Hide()
    end

    -- 啟用滑鼠以支援 tooltip
    bar:EnableMouse(true)

    return bar
end

--------------------------------------------------------------------------------
-- 格式化輔助
--------------------------------------------------------------------------------

local FormatValue = LunarUI.FormatValue

local function FormatBarText(textFormat, cur, max, extra)
    if not cur or not max or max == 0 then
        return ""
    end
    local pct = mathFloor(cur / max * 100)

    if textFormat == "percent" then
        return pct .. "%"
    elseif textFormat == "curmax" then
        return FormatValue(cur) .. " / " .. FormatValue(max)
    elseif textFormat == "cur" then
        return FormatValue(cur)
    elseif textFormat == "remaining" then
        return FormatValue(max - cur) .. " " .. (L["Remaining"] or "remaining")
    end

    -- 預設：百分比加額外標籤
    if extra then
        return format("%s %d%%", extra, pct)
    end
    return pct .. "%"
end

--------------------------------------------------------------------------------
-- 經驗條
--------------------------------------------------------------------------------

local function UpdateExperience()
    local bar = bars.experience
    if not bar then
        return
    end

    -- P-perf: 使用快取值，避免每次事件呼叫 GetModuleDB
    if not cachedExpEnabled then
        bar:Hide()
        return
    end

    -- 滿級時隱藏
    if UnitLevel("player") >= (_G.GetMaxPlayerLevel and _G.GetMaxPlayerLevel() or 70) then
        bar:Hide()
        return
    end

    local cur = _G.UnitXP("player")
    local max = _G.UnitXPMax("player")
    if not cur or not max or max == 0 then
        bar:Hide()
        return
    end

    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)
    bar:SetStatusBarColor(0.58, 0.0, 0.55) -- 紫色

    -- 休息經驗
    local rested = _G.GetXPExhaustion() or 0
    if rested > 0 then
        -- H-6: mathMax(0, ...) 防止 cur > max 時 (max - cur) 為負數導致 SetWidth 報錯
        local restedWidth = bar:GetWidth() * (mathMax(0, mathMin(rested, max - cur)) / max)
        if restedWidth < 2 then
            bar.rested:Hide()
        else
            bar.rested:SetWidth(restedWidth)
            bar.rested:ClearAllPoints()
            bar.rested:SetPoint("LEFT", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
            bar.rested:Show()
        end
    else
        bar.rested:Hide()
    end

    -- 文字（使用快取的 textFormat）
    local expDb = LunarUI.GetModuleDB("databars")
    local expCfg = expDb and expDb.experience
    if expCfg and expCfg.showText then
        bar.text:SetText(FormatBarText(cachedExpTextFmt, cur, max, "XP"))
        bar.text:Show()
    else
        bar.text:Hide()
    end

    bar:Show()
end

local function ExperienceTooltip(bar)
    if UnitLevel("player") >= (_G.GetMaxPlayerLevel and _G.GetMaxPlayerLevel() or 70) then
        return
    end

    local cur = _G.UnitXP("player")
    local max = _G.UnitXPMax("player")
    local rested = _G.GetXPExhaustion() or 0
    local pct = max > 0 and mathFloor(cur / max * 100) or 0

    _G.GameTooltip:SetOwner(bar, "ANCHOR_TOP", 0, 4)
    _G.GameTooltip:ClearLines()
    _G.GameTooltip:AddLine(L["Experience"] or "Experience", 0.58, 0.0, 0.55)
    GameTooltip:AddDoubleLine(
        L["Current"] or "Current",
        format("%s / %s (%d%%)", FormatValue(cur), FormatValue(max), pct),
        1,
        1,
        1,
        1,
        1,
        1
    )
    GameTooltip:AddDoubleLine(L["Remaining"] or "Remaining", FormatValue(max - cur), 1, 1, 1, 0.7, 0.7, 0.7)
    if rested > 0 then
        _G.GameTooltip:AddDoubleLine(
            L["Rested"] or "Rested",
            format("%s (%d%%)", FormatValue(rested), mathFloor(rested / max * 100)),
            0.0,
            0.4,
            0.8,
            0.0,
            0.4,
            0.8
        )
    end
    _G.GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- 聲望條
--------------------------------------------------------------------------------

local function UpdateReputation()
    local bar = bars.reputation
    if not bar then
        return
    end

    if not cachedRepEnabled then
        bar:Hide()
        return
    end

    -- 使用 C_Reputation API 取得監視中的聲望資料
    local name, standing, barMin, barMax, barValue, factionID
    if _G.C_Reputation and _G.C_Reputation.GetWatchedFactionData then
        -- pcall 保護：WoW 12.0 可能將部分聲望欄位標記為 secret values
        local ok, data = pcall(_G.C_Reputation.GetWatchedFactionData)
        if ok and data then
            name = data.name
            standing = data.reaction
            barMin = data.currentReactionThreshold or 0
            barMax = data.nextReactionThreshold or 1
            barValue = data.currentStanding or 0
            factionID = data.factionID
        end
    end

    if not name then
        bar:Hide()
        return
    end

    -- 友誼 / 名望檢查（WoW 12.0）
    local isFriendship = false
    local friendName, friendText
    if factionID and _G.C_GossipInfo and _G.C_GossipInfo.GetFriendshipReputation then
        local friendData = _G.C_GossipInfo.GetFriendshipReputation(factionID)
        if friendData and friendData.friendshipFactionID and friendData.friendshipFactionID > 0 then
            isFriendship = true
            friendName = friendData.reaction or name
            friendText = friendData.text
            if friendData.nextThreshold and friendData.nextThreshold > 0 then
                barMin = friendData.reactionThreshold or 0
                barMax = friendData.nextThreshold
                barValue = friendData.standing or 0
            end
        end
    end

    local cur = mathMax(0, barValue - barMin)
    local max = barMax - barMin
    if max <= 0 then
        max = 1
    end

    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)

    -- 依聲望等級著色
    local color = STANDING_COLORS[standing] or STANDING_COLORS[4]
    bar:SetStatusBarColor(color.r, color.g, color.b)
    bar.rested:Hide()

    -- 文字（使用快取的 textFormat）
    local repDb = LunarUI.GetModuleDB("databars")
    local repCfg = repDb and repDb.reputation
    if repCfg and repCfg.showText then
        local displayName = isFriendship and friendName or name
        bar.text:SetText(FormatBarText(cachedRepTextFmt, cur, max, displayName))
        bar.text:Show()
    else
        bar.text:Hide()
    end

    bar:Show()

    -- M7 效能修復：改用 flat fields 取代每事件建立新 table，避免 UPDATE_FACTION 頻繁觸發時的 GC 壓力
    bar._repName = name
    bar._repStanding = standing
    bar._repCur = cur
    bar._repMax = max
    bar._repIsFriendship = isFriendship
    bar._repFriendName = friendName
    bar._repFriendText = friendText
end

local function ReputationTooltip(bar)
    if not bar._repName then
        return
    end

    local pct = bar._repMax > 0 and mathFloor(bar._repCur / bar._repMax * 100) or 0
    local color = STANDING_COLORS[bar._repStanding] or STANDING_COLORS[4]

    _G.GameTooltip:SetOwner(bar, "ANCHOR_TOP", 0, 4)
    _G.GameTooltip:ClearLines()
    _G.GameTooltip:AddLine(bar._repName, color.r, color.g, color.b)

    local standingLabel
    if bar._repIsFriendship and bar._repFriendName then
        standingLabel = bar._repFriendName
    else
        standingLabel = _G["FACTION_STANDING_LABEL" .. (bar._repStanding or 4)] or ""
    end
    _G.GameTooltip:AddDoubleLine(L["Standing"] or "Standing", standingLabel, 1, 1, 1, color.r, color.g, color.b)
    _G.GameTooltip:AddDoubleLine(
        L["Current"] or "Current",
        format("%s / %s (%d%%)", FormatValue(bar._repCur), FormatValue(bar._repMax), pct),
        1,
        1,
        1,
        1,
        1,
        1
    )
    _G.GameTooltip:AddDoubleLine(
        L["Remaining"] or "Remaining",
        FormatValue(bar._repMax - bar._repCur),
        1,
        1,
        1,
        0.7,
        0.7,
        0.7
    )
    _G.GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- 榮譽條
--------------------------------------------------------------------------------

local function UpdateHonor()
    local bar = bars.honor
    if not bar then
        return
    end

    if not cachedHonEnabled then
        bar:Hide()
        return
    end

    -- 檢查榮譽是否相關
    if not _G.UnitHonor or not _G.UnitHonorMax then
        bar:Hide()
        return
    end

    local cur = _G.UnitHonor("player") or 0
    local max = _G.UnitHonorMax("player") or 0
    local level = _G.UnitHonorLevel and _G.UnitHonorLevel("player") or 0

    if max == 0 then
        bar:Hide()
        return
    end

    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)
    bar:SetStatusBarColor(1.0, 0.24, 0.0) -- 橙紅色
    bar.rested:Hide()

    -- 文字（使用快取的 textFormat）
    local honDb = LunarUI.GetModuleDB("databars")
    local honCfg = honDb and honDb.honor
    if honCfg and honCfg.showText then
        local label = format("%s %d", L["Honor"] or "Honor", level)
        bar.text:SetText(FormatBarText(cachedHonTextFmt, cur, max, label))
        bar.text:Show()
    else
        bar.text:Hide()
    end

    bar:Show()

    -- 儲存 tooltip 資料（flat fields，避免每事件建立新 table）
    bar._honorCur = cur
    bar._honorMax = max
    bar._honorLevel = level
end

local function HonorTooltip(bar)
    if not bar._honorCur then
        return
    end

    local cur, max, level = bar._honorCur, bar._honorMax, bar._honorLevel
    local pct = max > 0 and mathFloor(cur / max * 100) or 0

    _G.GameTooltip:SetOwner(bar, "ANCHOR_TOP", 0, 4)
    _G.GameTooltip:ClearLines()
    _G.GameTooltip:AddLine(format("%s %d", L["HonorLevel"] or "Honor Level", level), 1.0, 0.24, 0.0)
    _G.GameTooltip:AddDoubleLine(
        L["Current"] or "Current",
        format("%s / %s (%d%%)", FormatValue(cur), FormatValue(max), pct),
        1,
        1,
        1,
        1,
        1,
        1
    )
    _G.GameTooltip:AddDoubleLine(L["Remaining"] or "Remaining", FormatValue(max - cur), 1, 1, 1, 0.7, 0.7, 0.7)
    _G.GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeDataBars()
    if eventFrame then
        return -- 已初始化，防止重複呼叫導致事件 frame 洩漏
    end
    RefreshDataBarsCache() -- P-perf: 初始化時快取 DB 設定
    local db = LunarUI.GetModuleDB("databars")
    if not db or not db.enabled then
        return
    end

    -- 經驗條
    if db.experience and db.experience.enabled then
        bars.experience = CreateDataBar("Experience", db.experience)
        bars.experience:SetScript("OnEnter", function(self)
            ExperienceTooltip(self)
        end)
        bars.experience:SetScript("OnLeave", function()
            _G.GameTooltip:Hide()
        end)
    end

    -- 聲望條
    if db.reputation and db.reputation.enabled then
        bars.reputation = CreateDataBar("Reputation", db.reputation)
        bars.reputation:SetScript("OnEnter", function(self)
            ReputationTooltip(self)
        end)
        bars.reputation:SetScript("OnLeave", function()
            _G.GameTooltip:Hide()
        end)
    end

    -- 榮譽條
    if db.honor and db.honor.enabled then
        bars.honor = CreateDataBar("Honor", db.honor)
        bars.honor:SetScript("OnEnter", function(self)
            HonorTooltip(self)
        end)
        bars.honor:SetScript("OnLeave", function()
            _G.GameTooltip:Hide()
        end)
    end

    -- 事件框架，用於更新
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
    eventFrame:RegisterEvent("UPDATE_FACTION")
    eventFrame:RegisterEvent("HONOR_XP_UPDATE")
    eventFrame:RegisterEvent("HONOR_LEVEL_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(_self, event)
        if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "UPDATE_EXHAUSTION" then
            UpdateExperience()
        elseif event == "UPDATE_FACTION" then
            UpdateReputation()
        elseif event == "HONOR_XP_UPDATE" or event == "HONOR_LEVEL_UPDATE" then
            UpdateHonor()
        elseif event == "PLAYER_ENTERING_WORLD" then
            UpdateExperience()
            UpdateReputation()
            UpdateHonor()
        end
    end)

    -- 初始更新
    UpdateExperience()
    UpdateReputation()
    UpdateHonor()
end

-- 清理
function LunarUI.CleanupDataBars()
    -- 清除材質快取（使用者切換材質後重新初始化時會重新取得）
    statusBarTexture = nil

    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
    eventFrame = nil -- M-9: 清除參照，防止重複初始化防護邏輯失效
    for _, bar in pairs(bars) do
        if bar then
            bar:Hide()
            bar:SetScript("OnEnter", nil)
            bar:SetScript("OnLeave", nil)
        end
    end
    wipe(bars)
end

-- 匯出
LunarUI.InitializeDataBars = InitializeDataBars
LunarUI.RefreshDataBarsCache = RefreshDataBarsCache -- 供 Options callback 失效快取
LunarUI.FormatBarText = FormatBarText
LunarUI.GetStatusBarTexture = GetStatusBarTexture
LunarUI.STANDING_COLORS = STANDING_COLORS

LunarUI:RegisterModule("DataBars", {
    onEnable = InitializeDataBars,
    onDisable = function()
        LunarUI.CleanupDataBars()
    end,
    delay = 0.3,
    lifecycle = "reversible",
})
