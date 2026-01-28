--[[
    LunarUI - 滑鼠提示模組
    Lunar 主題風格的統一滑鼠提示

    功能：
    - 自訂邊框與背景（Lunar 主題）
    - 物品等級顯示
    - 法術 ID 顯示（可選）
    - 單位職業著色
    - 目標的目標顯示
    - 月相感知定位
]]

local ADDON_NAME, Engine = ...
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

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local tooltipStyled = false

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

local function FormatNumber(num)
    if num >= 1e9 then
        return string.format("%.2fB", num / 1e9)
    elseif num >= 1e6 then
        return string.format("%.2fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    end
    return tostring(num)
end

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
        statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        statusBar:SetHeight(4)
        statusBar:ClearAllPoints()
        statusBar:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 2, 2)
        statusBar:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -2, 2)

        -- 為狀態列新增背景
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

    -- 呼叫前檢查 GetUnit 是否存在
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

    -- 新增目標的目標
    if db.showTargetTarget and UnitExists(unit .. "target") then
        local targetName = UnitName(unit .. "target")
        if targetName then
            local tr, tg, tb = GetUnitColor(unit .. "target")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffffffff目標:|r " .. targetName, tr, tg, tb)
        end
    end

    -- 為玩家新增公會資訊
    if UnitIsPlayer(unit) then
        local guildName, guildRank = GetGuildInfo(unit)
        if guildName then
            -- 公會名稱通常已顯示，但我們可以進行樣式化
        end
    end

    -- 為團隊成員新增角色資訊
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

    -- 為非玩家單位顯示 NPC ID（對開發者有用）
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

    -- 呼叫前檢查 GetItem 是否存在（ShoppingTooltip 沒有此方法）
    if not tooltip.GetItem then return end
    local _, itemLink = tooltip:GetItem()
    if not itemLink then return end

    -- 顯示物品等級
    if db.showItemLevel then
        local itemLevel = GetItemLevel(itemLink)
        if itemLevel and itemLevel > 1 then
            -- 尋找顯示物品等級的第一行或新增
            local found = false
            for i = 2, tooltip:NumLines() do
                local line = _G[tooltip:GetName() .. "TextLeft" .. i]
                if line then
                    local text = line:GetText()
                    if text and text:find("Item Level") then
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

    -- 顯示物品 ID（除錯選項）
    if db.showItemID then
        local itemID = itemLink:match("item:(%d+)")
        if itemID then
            tooltip:AddLine("|cff888888物品 ID: " .. itemID .. "|r")
        end
    end

    -- 依物品品質著色滑鼠提示邊框
    local quality = select(3, C_Item.GetItemInfo(itemLink))
    if quality and quality > 1 then  -- 僅優秀及以上
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r and g and b then
            if tooltip.SetBackdropBorderColor then
                tooltip:SetBackdropBorderColor(r, g, b, 1)
            elseif tooltip.LunarBackdrop then
                tooltip.LunarBackdrop:SetBackdropBorderColor(r, g, b, 1)
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

    -- 呼叫前檢查 GetSpell 是否存在
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

-- 自適應滑鼠提示定位避免螢幕邊緣
local function AdjustTooltipPosition(tooltip)
    if not tooltip or not tooltip:IsShown() then return end

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local tooltipWidth = tooltip:GetWidth()
    local tooltipHeight = tooltip:GetHeight()
    local scale = tooltip:GetEffectiveScale() / UIParent:GetEffectiveScale()

    local left = tooltip:GetLeft()
    local right = tooltip:GetRight()
    local top = tooltip:GetTop()
    local bottom = tooltip:GetBottom()

    if not left or not right or not top or not bottom then return end

    local offsetX, offsetY = 0, 0

    -- 檢查右邊緣
    if right * scale > screenWidth then
        offsetX = screenWidth - (right * scale) - 10
    end

    -- 檢查左邊緣
    if left * scale < 0 then
        offsetX = -left * scale + 10
    end

    -- 檢查下邊緣
    if bottom * scale < 0 then
        offsetY = -bottom * scale + 10
    end

    -- 檢查上邊緣
    if top * scale > screenHeight then
        offsetY = screenHeight - (top * scale) - 10
    end

    -- 必要時套用偏移
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
            -- 錨定至右下角
            tooltip:SetOwner(parent, "ANCHOR_NONE")
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 50)
        end
    end)

    -- 掛鉤 OnShow 以在滑鼠提示顯示後調整位置
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
    -- 但如有需要可調整背景透明度
end

local function RegisterTooltipPhaseCallback()
    if phaseCallbackRegistered then return end
    phaseCallbackRegistered = true

    LunarUI:RegisterPhaseCallback(function(oldPhase, newPhase)
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
        -- 使用前檢查 Enum 和 Enum.TooltipDataType 是否存在
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
            -- 正式服 10.0+
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
                OnTooltipSetUnit(tooltip)
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
                OnTooltipSetItem(tooltip)
            end)
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
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
