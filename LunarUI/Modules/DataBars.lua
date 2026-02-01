---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - DataBars 模組
    經驗值、聲望、榮譽進度條

    Features:
    - Experience bar with rested XP display
    - Reputation bar (watched faction)
    - Honor bar (PvP level progress)
    - Phase-aware alpha
    - Tooltip on mouseover
    - Configurable size, position, text format
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors
local L = Engine.L or {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local statusBarTexture  -- lazy: resolved after DB is ready
local function GetStatusBarTexture()
    if not statusBarTexture then
        statusBarTexture = LunarUI.GetSelectedStatusBarTexture()
    end
    return statusBarTexture
end
local backdropTemplate = LunarUI.backdropTemplate

local format = string.format
local floor = math.floor

-- Faction standing colors (matches Blizzard FACTION_BAR_COLORS)
local STANDING_COLORS = {
    [1] = { r = 0.80, g = 0.13, b = 0.13 },  -- Hated
    [2] = { r = 0.80, g = 0.25, b = 0.00 },  -- Hostile
    [3] = { r = 0.75, g = 0.27, b = 0.00 },  -- Unfriendly
    [4] = { r = 0.85, g = 0.77, b = 0.36 },  -- Neutral
    [5] = { r = 0.00, g = 0.67, b = 0.00 },  -- Friendly
    [6] = { r = 0.00, g = 0.39, b = 0.88 },  -- Honored
    [7] = { r = 0.64, g = 0.21, b = 0.93 },  -- Revered
    [8] = { r = 1.00, g = 0.67, b = 0.00 },  -- Exalted
}

--------------------------------------------------------------------------------
-- Module State
--------------------------------------------------------------------------------

local bars = {}           -- All created DataBar frames
local eventFrame          -- Shared event handler frame

--------------------------------------------------------------------------------
-- Helper: Create a single DataBar
--------------------------------------------------------------------------------

local function CreateDataBar(name, db)
    local bar = CreateFrame("StatusBar", "LunarUI_DataBar_" .. name, UIParent, "BackdropTemplate")
    bar:SetStatusBarTexture(GetStatusBarTexture())
    bar:SetSize(db.width or 400, db.height or 8)
    bar:SetPoint(db.point or "BOTTOM", UIParent, db.point or "BOTTOM", db.x or 0, db.y or 2)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(2)

    -- Backdrop
    if backdropTemplate then
        bar:SetBackdrop(backdropTemplate)
        bar:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
        bar:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end

    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(GetStatusBarTexture())
    bar.bg:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    -- Text overlay
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    bar.text:SetPoint("CENTER")

    if not db.showText then
        bar.text:Hide()
    end

    -- Rested XP overlay (experience bar only)
    bar.rested = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    bar.rested:SetTexture(GetStatusBarTexture())
    bar.rested:SetVertexColor(0.0, 0.4, 0.8, 0.4)
    bar.rested:SetHeight(db.height or 8)
    bar.rested:Hide()

    -- Enable mouse for tooltip
    bar:EnableMouse(true)

    return bar
end

--------------------------------------------------------------------------------
-- Format helpers
--------------------------------------------------------------------------------

local function FormatValue(value)
    if value >= 1e6 then
        return format("%.1fM", value / 1e6)
    elseif value >= 1e3 then
        return format("%.1fK", value / 1e3)
    end
    return tostring(value)
end

local function FormatBarText(textFormat, cur, max, extra)
    if not cur or not max or max == 0 then return "" end
    local pct = floor(cur / max * 100)

    if textFormat == "percent" then
        return pct .. "%"
    elseif textFormat == "curmax" then
        return FormatValue(cur) .. " / " .. FormatValue(max)
    elseif textFormat == "cur" then
        return FormatValue(cur)
    elseif textFormat == "remaining" then
        return FormatValue(max - cur) .. " " .. (L["Remaining"] or "remaining")
    end

    -- Default: percent with extra label
    if extra then
        return format("%s %d%%", extra, pct)
    end
    return pct .. "%"
end

--------------------------------------------------------------------------------
-- Experience Bar
--------------------------------------------------------------------------------

local function UpdateExperience()
    local bar = bars.experience
    if not bar then return end

    local db = LunarUI.db.profile.databars
    if not db or not db.experience or not db.experience.enabled then
        bar:Hide()
        return
    end

    -- Hide at max level
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
    bar:SetStatusBarColor(0.58, 0.0, 0.55)  -- Purple

    -- Rested XP
    local rested = _G.GetXPExhaustion() or 0
    if rested > 0 then
        local restedWidth = bar:GetWidth() * (rested / max)
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

    -- Text
    if db.experience.showText then
        bar.text:SetText(FormatBarText(db.experience.textFormat, cur, max, "XP"))
        bar.text:Show()
    else
        bar.text:Hide()
    end

    bar:Show()
end

local function ExperienceTooltip(bar)
    if UnitLevel("player") >= (_G.GetMaxPlayerLevel and _G.GetMaxPlayerLevel() or 70) then return end

    local cur = _G.UnitXP("player")
    local max = _G.UnitXPMax("player")
    local rested = _G.GetXPExhaustion() or 0
    local pct = max > 0 and floor(cur / max * 100) or 0

    _G.GameTooltip:SetOwner(bar, "ANCHOR_TOP", 0, 4)
    _G.GameTooltip:ClearLines()
    _G.GameTooltip:AddLine(L["Experience"] or "Experience", 0.58, 0.0, 0.55)
    GameTooltip:AddDoubleLine(L["Current"] or "Current", format("%s / %s (%d%%)", FormatValue(cur), FormatValue(max), pct), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Remaining"] or "Remaining", FormatValue(max - cur), 1, 1, 1, 0.7, 0.7, 0.7)
    if rested > 0 then
        _G.GameTooltip:AddDoubleLine(L["Rested"] or "Rested", format("%s (%d%%)", FormatValue(rested), floor(rested / max * 100)), 0.0, 0.4, 0.8, 0.0, 0.4, 0.8)
    end
    _G.GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Reputation Bar
--------------------------------------------------------------------------------

local function UpdateReputation()
    local bar = bars.reputation
    if not bar then return end

    local db = LunarUI.db.profile.databars
    if not db or not db.reputation or not db.reputation.enabled then
        bar:Hide()
        return
    end

    -- GetWatchedFactionInfo is available in all WoW versions
    local name, standing, barMin, barMax, barValue, factionID
    if _G.C_Reputation and _G.C_Reputation.GetWatchedFactionData then
        local data = _G.C_Reputation.GetWatchedFactionData()
        if data then
            name = data.name
            standing = data.reaction
            barMin = data.currentReactionThreshold or 0
            barMax = data.nextReactionThreshold or 1
            barValue = data.currentStanding or 0
            factionID = data.factionID
        end
    elseif _G.GetWatchedFactionInfo then
        name, standing, barMin, barMax, barValue, factionID = _G.GetWatchedFactionInfo()
    end

    if not name then
        bar:Hide()
        return
    end

    -- Friendship / Renown check (WoW 12.0)
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

    local cur = barValue - barMin
    local max = barMax - barMin
    if max <= 0 then max = 1 end

    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)

    -- Color by standing
    local color = STANDING_COLORS[standing] or STANDING_COLORS[4]
    bar:SetStatusBarColor(color.r, color.g, color.b)
    bar.rested:Hide()

    -- Text
    if db.reputation.showText then
        local displayName = isFriendship and friendName or name
        bar.text:SetText(FormatBarText(db.reputation.textFormat, cur, max, displayName))
        bar.text:Show()
    else
        bar.text:Hide()
    end

    bar:Show()

    -- Store for tooltip
    bar._repData = {
        name = name,
        standing = standing,
        cur = cur,
        max = max,
        isFriendship = isFriendship,
        friendName = friendName,
        friendText = friendText,
    }
end

local function ReputationTooltip(bar)
    local data = bar._repData
    if not data then return end

    local pct = data.max > 0 and floor(data.cur / data.max * 100) or 0
    local color = STANDING_COLORS[data.standing] or STANDING_COLORS[4]

    _G.GameTooltip:SetOwner(bar, "ANCHOR_TOP", 0, 4)
    _G.GameTooltip:ClearLines()
    _G.GameTooltip:AddLine(data.name, color.r, color.g, color.b)

    local standingLabel
    if data.isFriendship and data.friendName then
        standingLabel = data.friendName
    else
        standingLabel = _G["FACTION_STANDING_LABEL" .. (data.standing or 4)] or ""
    end
    _G.GameTooltip:AddDoubleLine(L["Standing"] or "Standing", standingLabel, 1, 1, 1, color.r, color.g, color.b)
    _G.GameTooltip:AddDoubleLine(L["Current"] or "Current", format("%s / %s (%d%%)", FormatValue(data.cur), FormatValue(data.max), pct), 1, 1, 1, 1, 1, 1)
    _G.GameTooltip:AddDoubleLine(L["Remaining"] or "Remaining", FormatValue(data.max - data.cur), 1, 1, 1, 0.7, 0.7, 0.7)
    _G.GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Honor Bar
--------------------------------------------------------------------------------

local function UpdateHonor()
    local bar = bars.honor
    if not bar then return end

    local db = LunarUI.db.profile.databars
    if not db or not db.honor or not db.honor.enabled then
        bar:Hide()
        return
    end

    -- Check if honor is relevant
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
    bar:SetStatusBarColor(1.0, 0.24, 0.0)  -- Orange-red
    bar.rested:Hide()

    -- Text
    if db.honor.showText then
        local label = format("%s %d", L["Honor"] or "Honor", level)
        bar.text:SetText(FormatBarText(db.honor.textFormat, cur, max, label))
        bar.text:Show()
    else
        bar.text:Hide()
    end

    bar:Show()

    -- Store for tooltip
    bar._honorData = { cur = cur, max = max, level = level }
end

local function HonorTooltip(bar)
    local data = bar._honorData
    if not data then return end

    local pct = data.max > 0 and floor(data.cur / data.max * 100) or 0

    _G.GameTooltip:SetOwner(bar, "ANCHOR_TOP", 0, 4)
    _G.GameTooltip:ClearLines()
    _G.GameTooltip:AddLine(format("%s %d", L["HonorLevel"] or "Honor Level", data.level), 1.0, 0.24, 0.0)
    _G.GameTooltip:AddDoubleLine(L["Current"] or "Current", format("%s / %s (%d%%)", FormatValue(data.cur), FormatValue(data.max), pct), 1, 1, 1, 1, 1, 1)
    _G.GameTooltip:AddDoubleLine(L["Remaining"] or "Remaining", FormatValue(data.max - data.cur), 1, 1, 1, 0.7, 0.7, 0.7)
    _G.GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------

local function InitializeDataBars()
    local db = LunarUI.db.profile.databars
    if not db or not db.enabled then return end

    -- Experience bar
    if db.experience and db.experience.enabled then
        bars.experience = CreateDataBar("Experience", db.experience)
        bars.experience:SetScript("OnEnter", function(self) ExperienceTooltip(self) end)
        bars.experience:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    end

    -- Reputation bar
    if db.reputation and db.reputation.enabled then
        bars.reputation = CreateDataBar("Reputation", db.reputation)
        bars.reputation:SetScript("OnEnter", function(self) ReputationTooltip(self) end)
        bars.reputation:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    end

    -- Honor bar
    if db.honor and db.honor.enabled then
        bars.honor = CreateDataBar("Honor", db.honor)
        bars.honor:SetScript("OnEnter", function(self) HonorTooltip(self) end)
        bars.honor:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    end

    -- Event frame for updates
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

    -- Initial update
    UpdateExperience()
    UpdateReputation()
    UpdateHonor()

end

-- Cleanup
function LunarUI.CleanupDataBars()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
    for name, bar in pairs(bars) do
        if bar then
            bar:Hide()
            bar:SetScript("OnEnter", nil)
            bar:SetScript("OnLeave", nil)
        end
        bars[name] = nil
    end
end

-- Export
LunarUI.InitializeDataBars = InitializeDataBars

LunarUI:RegisterModule("DataBars", {
    onEnable = InitializeDataBars,
    onDisable = function() LunarUI.CleanupDataBars() end,
    delay = 0.3,
})
