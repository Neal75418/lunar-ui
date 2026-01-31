---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if, missing-parameter, undefined-global, unused-local
--[[
    LunarUI - 滑鼠提示模組（增強版）
    Lunar 主題風格的統一滑鼠提示

    功能：
    - 自訂邊框與背景（Lunar 主題）
    - 物品等級顯示
    - 法術 ID 顯示（可選）
    - 單位職業著色
    - 目標的目標顯示
    - AFK / DND 狀態標記
    - 等級差異著色（灰/綠/黃/橙/紅）
    - 裝備等級 + 專精顯示（Shift 懸停 / NotifyInspect）
    - 月相感知定位
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local backdropTemplate = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local CLASS_COLORS = RAID_CLASS_COLORS

-- 等級差異顏色
local function GetLevelDifficultyColor(unitLevel)
    if unitLevel <= 0 then return 1, 1, 0 end  -- 等級未知
    local playerLevel = UnitLevel("player") or 1
    local diff = unitLevel - playerLevel

    if diff >= 5 then
        return 0.9, 0.2, 0.2    -- 紅色（非常高）
    elseif diff >= 3 then
        return 0.9, 0.5, 0.1    -- 橙色（高）
    elseif diff >= -2 then
        return 0.9, 0.9, 0.2    -- 黃色（同級）
    elseif diff >= -8 then
        return 0.2, 0.8, 0.2    -- 綠色（低）
    else
        return 0.6, 0.6, 0.6    -- 灰色（極低）
    end
end

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local tooltipStyled = false

-- Inspect 快取（避免重複請求）
local inspectCache = {}  -- { [guid] = { ilvl, spec, time } }
local INSPECT_CACHE_TTL = 30  -- 快取有效秒數
local INSPECT_CACHE_MAX = 50  -- 最大快取筆數
local pendingInspect = nil    -- 目前等待中的 inspect GUID

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function GetItemLevel(itemLink)
    if not itemLink then return nil end
    local itemLevel = select(1, C_Item.GetDetailedItemLevelInfo(itemLink))
    return itemLevel
end

local function GetUnitColor(unit)
    if not unit or not UnitExists(unit) then
        return 1, 1, 1
    end

    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if class and CLASS_COLORS[class] then
            return CLASS_COLORS[class].r, CLASS_COLORS[class].g, CLASS_COLORS[class].b
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction then
            if reaction >= 5 then
                return 0.2, 0.8, 0.2  -- 友善
            elseif reaction == 4 then
                return 1, 1, 0        -- 中立
            else
                return 0.8, 0.2, 0.2  -- 敵對
            end
        end
    end

    return 1, 1, 1
end

--------------------------------------------------------------------------------
-- Inspect 系統（裝等 + 專精）
--------------------------------------------------------------------------------

local function GetCachedInspectData(guid)
    local data = inspectCache[guid]
    if data and (GetTime() - data.time) < INSPECT_CACHE_TTL then
        return data
    end
    return nil
end

local function CacheInspectData(guid, ilvl, spec)
    inspectCache[guid] = {
        ilvl = ilvl,
        spec = spec,
        time = GetTime(),
    }
    -- 過多快取時清除過期條目
    local count = 0
    for _ in pairs(inspectCache) do count = count + 1 end
    if count > INSPECT_CACHE_MAX then
        local now = GetTime()
        for k, v in pairs(inspectCache) do
            if (now - v.time) >= INSPECT_CACHE_TTL then
                inspectCache[k] = nil
            end
        end
    end
end

-- 計算裝備等級（從 inspect 資料）
local function GetInspectItemLevel(unit)
    local totalIlvl = 0
    local count = 0
    -- 裝備欄位：1-17（不含 4=襯衣、19=戰袍）
    local slots = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local ilvl = GetItemLevel(link)
            if ilvl and ilvl > 0 then
                totalIlvl = totalIlvl + ilvl
                count = count + 1
            end
        end
    end
    if count > 0 then
        return math.floor(totalIlvl / count + 0.5)
    end
    return nil
end

-- 取得專精名稱
local function GetInspectSpec(unit)
    if not unit or not UnitIsPlayer(unit) then return nil end

    local specID
    if GetInspectSpecialization then
        specID = GetInspectSpecialization(unit)
    end

    if specID and specID > 0 then
        local _, specName = GetSpecializationInfoByID(specID)
        return specName
    end
    return nil
end

-- 請求 Inspect
local function RequestInspect(unit)
    if not unit or not UnitIsPlayer(unit) then return end
    if not CanInspect(unit) then return end
    if InCombatLockdown() then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    -- 檢查快取
    local cached = GetCachedInspectData(guid)
    if cached then return end

    -- 發送 Inspect 請求
    pendingInspect = guid
    NotifyInspect(unit)
end

-- Inspect 回應事件
local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:SetScript("OnEvent", function(_self, event, inspectGUID)
    if event ~= "INSPECT_READY" then return end

    -- 確認是我們請求的
    if pendingInspect and pendingInspect == inspectGUID then
        -- 從 inspect 結果取得資料
        local unit = "mouseover"
        if UnitExists(unit) and UnitGUID(unit) == inspectGUID then
            local ilvl = GetInspectItemLevel(unit)
            local spec = GetInspectSpec(unit)
            CacheInspectData(inspectGUID, ilvl, spec)

            -- 如果 tooltip 仍在顯示，更新它
            if GameTooltip:IsShown() and GameTooltip.GetUnit then
                local _, tooltipUnit = GameTooltip:GetUnit()
                if tooltipUnit and UnitGUID(tooltipUnit) == inspectGUID then
                    -- 新增 inspect 資訊行
                    if spec then
                        GameTooltip:AddLine("|cff888888專精:|r " .. spec, 1, 1, 1)
                    end
                    if ilvl then
                        GameTooltip:AddLine("|cff888888裝等:|r " .. ilvl, 1, 1, 1)
                    end
                    GameTooltip:Show()
                end
            end
        end
        pendingInspect = nil
    end
end)

--------------------------------------------------------------------------------
-- 滑鼠提示樣式
--------------------------------------------------------------------------------

local function StyleTooltip(tooltip)
    if not tooltip then return end

    -- 套用背景
    if tooltip.SetBackdrop then
        tooltip:SetBackdrop(backdropTemplate)
        tooltip:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        tooltip:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
    elseif tooltip.NineSlice then
        -- 正式服滑鼠提示使用 NineSlice
        tooltip.NineSlice:SetAlpha(0)

        if not tooltip.LunarBackdrop then
            local backdrop = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
            backdrop:SetAllPoints()
            backdrop:SetFrameLevel(tooltip:GetFrameLevel())
            backdrop:SetBackdrop(backdropTemplate)
            backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
            backdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            tooltip.LunarBackdrop = backdrop
        end
    end

    -- 樣式化狀態列（血量條）
    if tooltip.StatusBar or GameTooltipStatusBar then
        local statusBar = tooltip.StatusBar or GameTooltipStatusBar
        statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        statusBar:SetHeight(4)
        statusBar:ClearAllPoints()
        statusBar:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 2, 2)
        statusBar:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -2, 2)

        if not statusBar.LunarBG then
            local bg = statusBar:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(0, 0, 0, 0.5)
            statusBar.LunarBG = bg
        end
    end
end

local function StyleAllTooltips()
    local tooltips = {
        GameTooltip,
        ShoppingTooltip1,
        ShoppingTooltip2,
        ItemRefTooltip,
        ItemRefShoppingTooltip1,
        ItemRefShoppingTooltip2,
        WorldMapTooltip,
        WorldMapCompareTooltip1,
        WorldMapCompareTooltip2,
        SmallTextTooltip,
        EmbeddedItemTooltip,
        NamePlateTooltip,
        QuestScrollFrame and QuestScrollFrame.StoryTooltip,
        BattlePetTooltip,
        FloatingBattlePetTooltip,
        FloatingPetBattleAbilityTooltip,
        PetBattlePrimaryUnitTooltip,
        PetBattlePrimaryAbilityTooltip,
    }

    for _, tooltip in ipairs(tooltips) do
        if tooltip then
            StyleTooltip(tooltip)
        end
    end
end

--------------------------------------------------------------------------------
-- 單位滑鼠提示增強
--------------------------------------------------------------------------------

local function OnTooltipSetUnit(tooltip)
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end

    if not tooltip.GetUnit then return end
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    -- 依單位著色滑鼠提示邊框
    local r, g, b = GetUnitColor(unit)
    if tooltip.SetBackdropBorderColor then
        tooltip:SetBackdropBorderColor(r, g, b, 1)
    elseif tooltip.LunarBackdrop then
        tooltip.LunarBackdrop:SetBackdropBorderColor(r, g, b, 1)
    end

    -- 著色狀態列
    local statusBar = tooltip.StatusBar or GameTooltipStatusBar
    if statusBar then
        statusBar:SetStatusBarColor(r, g, b)
    end

    -- === 新增：AFK / DND 狀態 ===
    if UnitIsPlayer(unit) then
        if UnitIsAFK(unit) then
            tooltip:AppendText(" |cffff9900<AFK>|r")
        elseif UnitIsDND(unit) then
            tooltip:AppendText(" |cffff3333<DND>|r")
        end
    end

    -- === 新增：等級著色 ===
    local level = UnitLevel(unit)
    if level and level > 0 then
        -- 尋找等級行並著色
        for i = 2, tooltip:NumLines() do
            local line = _G[tooltip:GetName() .. "TextLeft" .. i]
            if line then
                local text = line:GetText()
                if text and (text:find("Level") or text:find("等級")) then
                    local lr, lg, lb = GetLevelDifficultyColor(level)
                    line:SetTextColor(lr, lg, lb)
                    break
                end
            end
        end
    end

    -- === 新增：裝等 + 專精（玩家） ===
    if UnitIsPlayer(unit) then
        local guid = UnitGUID(unit)
        if guid then
            local cached = GetCachedInspectData(guid)
            if cached then
                -- 顯示快取的 inspect 資料
                if cached.spec then
                    tooltip:AddLine("|cff888888專精:|r " .. cached.spec, 1, 1, 1)
                end
                if cached.ilvl then
                    tooltip:AddLine("|cff888888裝等:|r " .. cached.ilvl, 1, 1, 1)
                end
            else
                -- 自動請求 Inspect（不需要 Shift）
                RequestInspect(unit)
            end
        end
    end

    -- 目標的目標
    if db.showTargetTarget and UnitExists(unit .. "target") then
        local targetName = UnitName(unit .. "target")
        if targetName then
            local tr, tg, tb = GetUnitColor(unit .. "target")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffffff目標:|r " .. targetName, tr, tg, tb)
        end
    end

    -- 角色資訊
    if UnitInParty(unit) or UnitInRaid(unit) then
        local role = UnitGroupRolesAssigned(unit)
        if role and role ~= "NONE" then
            local roleText = {
                TANK = "|cff5555ff坦克|r",
                HEALER = "|cff55ff55治療|r",
                DAMAGER = "|cffff5555傷害|r",
            }
            if roleText[role] then
                tooltip:AddLine("角色: " .. roleText[role])
            end
        end
    end

    -- NPC ID
    if not UnitIsPlayer(unit) then
        local guid = UnitGUID(unit)
        if guid then
            local unitType, _, _, _, _, npcID = strsplit("-", guid)
            if unitType == "Creature" or unitType == "Vehicle" then
                if npcID then
                    tooltip:AddLine("|cff888888NPC ID: " .. npcID .. "|r")
                end
            end
        end
    end

    tooltip:Show()
end

--------------------------------------------------------------------------------
-- 物品滑鼠提示增強
--------------------------------------------------------------------------------

local function OnTooltipSetItem(tooltip)
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end

    if not tooltip.GetItem then return end
    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    -- 顯示物品等級
    if db.showItemLevel then
        local itemLevel = GetItemLevel(itemLink)
        if itemLevel and itemLevel > 1 then
            local found = false
            for i = 2, tooltip:NumLines() do
                local line = _G[tooltip:GetName() .. "TextLeft" .. i]
                if line then
                    local text = line:GetText()
                    if text and (text:find("Item Level") or text:find("物品等級")) then
                        found = true
                        break
                    end
                end
            end

            if not found then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff00ff00物品等級: " .. itemLevel .. "|r")
            end
        end
    end

    -- 顯示物品持有數量
    if db.showItemCount then
        local itemID = itemLink:match("item:(%d+)")
        if itemID then
            local numID = tonumber(itemID)
            if numID then
                local bagCount = C_Item.GetItemCount(numID, false)
                local totalCount = C_Item.GetItemCount(numID, true)  -- 含銀行
                if totalCount and totalCount > 0 then
                    local bankCount = totalCount - bagCount
                    local L = Engine.L or {}
                    local countText = string.format(
                        "%s: %d",
                        L["ItemCount"] or "Count",
                        bagCount
                    )
                    if bankCount > 0 then
                        countText = countText .. string.format(
                            "  (%s: %d)",
                            L["BankTitle"] or "Bank",
                            bankCount
                        )
                    end
                    tooltip:AddLine("|cff888888" .. countText .. "|r")
                end
            end
        end
    end

    -- 顯示物品 ID
    if db.showItemID then
        local itemID = itemLink:match("item:(%d+)")
        if itemID then
            tooltip:AddLine("|cff888888物品 ID: " .. itemID .. "|r")
        end
    end

    -- 依物品品質著色邊框
    local itemID = itemLink:match("item:(%d+)")
    local quality = itemID and C_Item.GetItemQualityByID(tonumber(itemID))
    if not quality then
        quality = select(3, C_Item.GetItemInfo(itemLink))
    end
    if quality and quality > 1 then
        local qr, qg, qb = C_Item.GetItemQualityColor(quality)
        if qr and qg and qb then
            if tooltip.SetBackdropBorderColor then
                tooltip:SetBackdropBorderColor(qr, qg, qb, 1)
            elseif tooltip.LunarBackdrop then
                tooltip.LunarBackdrop:SetBackdropBorderColor(qr, qg, qb, 1)
            end
        end
    end

    tooltip:Show()
end

--------------------------------------------------------------------------------
-- 法術滑鼠提示增強
--------------------------------------------------------------------------------

local function OnTooltipSetSpell(tooltip)
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end
    if not db.showSpellID then return end

    if not tooltip.GetSpell then return end
    local spellID = select(2, tooltip:GetSpell())
    if spellID then
        tooltip:AddLine("|cff888888法術 ID: " .. spellID .. "|r")
        tooltip:Show()
    end
end

--------------------------------------------------------------------------------
-- 滑鼠提示定位
--------------------------------------------------------------------------------

local function AdjustTooltipPosition(tooltip)
    if not tooltip or not tooltip:IsShown() then return end

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local scale = tooltip:GetEffectiveScale() / UIParent:GetEffectiveScale()

    local left = tooltip:GetLeft()
    local right = tooltip:GetRight()
    local top = tooltip:GetTop()
    local bottom = tooltip:GetBottom()

    if not left or not right or not top or not bottom then return end

    local offsetX, offsetY = 0, 0

    if right * scale > screenWidth then
        offsetX = screenWidth - (right * scale) - 10
    end
    if left * scale < 0 then
        offsetX = -left * scale + 10
    end
    if bottom * scale < 0 then
        offsetY = -bottom * scale + 10
    end
    if top * scale > screenHeight then
        offsetY = screenHeight - (top * scale) - 10
    end

    if offsetX ~= 0 or offsetY ~= 0 then
        local point, relativeTo, relativePoint, x, y = tooltip:GetPoint()
        if point and relativeTo then
            tooltip:ClearAllPoints()
            tooltip:SetPoint(point, relativeTo, relativePoint, (x or 0) + offsetX, (y or 0) + offsetY)
        end
    end
end

local function SetTooltipPosition()
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end
    if not db.anchorCursor then return end

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if db.anchorCursor then
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        else
            tooltip:SetOwner(parent, "ANCHOR_NONE")
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 50)
        end
    end)

    if GameTooltip then
        GameTooltip:HookScript("OnShow", function(self)
            C_Timer.After(0, function()
                AdjustTooltipPosition(self)
            end)
        end)
    end
end

--------------------------------------------------------------------------------
-- 月相感知
--------------------------------------------------------------------------------

local phaseCallbackRegistered = false

local function UpdateTooltipForPhase()
    -- 滑鼠提示為瞬態不需月相感知
end

local function RegisterTooltipPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(_oldPhase, _newPhase)
        UpdateTooltipForPhase()
    end)
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeTooltip()
    local db = LunarUI.db and LunarUI.db.profile.tooltip
    if not db or not db.enabled then return end

    if tooltipStyled then return end
    tooltipStyled = true

    -- 樣式化所有滑鼠提示
    StyleAllTooltips()

    -- 掛鉤 GameTooltip
    if GameTooltip then
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
            -- 正式服 10.0+
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
                OnTooltipSetUnit(tooltip)
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
                OnTooltipSetItem(tooltip)
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip)
                OnTooltipSetSpell(tooltip)
            end)
        else
            -- 經典版 / 舊版 API
            GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
            GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
            GameTooltip:HookScript("OnTooltipSetSpell", OnTooltipSetSpell)
        end

        -- 顯示時重新樣式化
        GameTooltip:HookScript("OnShow", function(self)
            StyleTooltip(self)
        end)

        -- 清除時重設邊框顏色
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            elseif self.LunarBackdrop then
                self.LunarBackdrop:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
            end
        end)
    end

    -- 設定定位
    SetTooltipPosition()

    -- 註冊月相更新
    RegisterTooltipPhaseCallback()
end

-- 匯出
LunarUI.InitializeTooltip = InitializeTooltip

-- 掛鉤至插件啟用
hooksecurefunc(LunarUI, "OnEnable", function()
    C_Timer.After(0.3, InitializeTooltip)
end)
