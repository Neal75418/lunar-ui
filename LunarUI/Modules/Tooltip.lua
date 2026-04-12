---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, undefined-global, redundant-parameter, unused-local
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
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local mathFloor = math.floor
local format = string.format
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

local CLASS_COLORS = RAID_CLASS_COLORS

-- 等級差異顏色
local function GetLevelDifficultyColor(unitLevel)
    -- if unitLevel <= 0 then return 1, 1, 0 end  -- 等級未知 (Caller ensures > 0)
    local playerLevel = UnitLevel("player") or 1
    local diff = unitLevel - playerLevel

    if diff >= 5 then
        return 0.9, 0.2, 0.2 -- 紅色（非常高）
    elseif diff >= 3 then
        return 0.9, 0.5, 0.1 -- 橙色（高）
    elseif diff >= -2 then
        return 0.9, 0.9, 0.2 -- 黃色（同級）
    elseif diff >= -8 then
        return 0.2, 0.8, 0.2 -- 綠色（低）
    else
        return 0.6, 0.6, 0.6 -- 灰色（極低）
    end
end

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local tooltipStyled = false
local tooltipPositionHooked = false -- H-5: 防止 anchorCursor 動態切換時重複安裝定位 hook
local _EMPTY = {} -- L-2: 避免 Engine.L or _EMPTY 在熱路徑上每次建立新 table

-- Inspect 快取（避免重複請求）
local inspectCache = {} -- { [guid] = { ilvl, spec, time } }
local INSPECT_CACHE_TTL = 30 -- 快取有效秒數
local INSPECT_CACHE_MAX = 50 -- 最大快取筆數
local pendingInspect = nil -- 目前等待中的 inspect GUID

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

local function GetItemLevel(itemLink)
    if not itemLink then
        return nil
    end
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
                return 0.2, 0.8, 0.2 -- 友善
            elseif reaction == 4 then
                return 1, 1, 0 -- 中立
            else
                return 0.8, 0.2, 0.2 -- 敵對
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
    if data and (GetTime() - data.time) <= INSPECT_CACHE_TTL then
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
    -- 清理：過期條目一律刪除，再檢查大小上限
    local count = 0
    local now = GetTime()
    local oldestKey, oldestTime = nil, now
    local toEvict = {}
    for k, v in pairs(inspectCache) do
        if (now - v.time) >= INSPECT_CACHE_TTL then
            toEvict[#toEvict + 1] = k
        else
            count = count + 1
            if v.time < oldestTime then
                oldestKey = k
                oldestTime = v.time
            end
        end
    end
    for i = 1, #toEvict do
        inspectCache[toEvict[i]] = nil
    end
    -- 超過上限時移除最舊的條目
    if count > INSPECT_CACHE_MAX and oldestKey then
        inspectCache[oldestKey] = nil
    end
end

local function ClearInspectCache()
    wipe(inspectCache)
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
        return mathFloor(totalIlvl / count + 0.5)
    end
    return nil
end

-- 取得專精名稱
local function GetInspectSpec(unit)
    if not unit or not UnitIsPlayer(unit) then
        return nil
    end

    local specID = GetInspectSpecialization(unit)

    if specID and specID > 0 then
        local _, specName = GetSpecializationInfoByID(specID)
        return specName
    end
    return nil
end

-- 請求 Inspect（含節流：避免滑鼠快速掃過玩家時轟炸伺服器）
local lastInspectTime = 0
local INSPECT_THROTTLE = 1.0 -- 最小請求間隔（秒）

local function RequestInspect(unit)
    if not unit or not UnitIsPlayer(unit) then
        return
    end
    if not CanInspect(unit) then
        return
    end
    if InCombatLockdown() then
        return
    end
    if GetTime() - lastInspectTime < INSPECT_THROTTLE then
        return
    end

    local guid = UnitGUID(unit)
    if not guid then
        return
    end

    -- 檢查快取
    local cached = GetCachedInspectData(guid)
    if cached then
        return
    end

    -- 發送 Inspect 請求
    lastInspectTime = GetTime()
    pendingInspect = guid
    NotifyInspect(unit)
    -- M-5: timeout 防護，避免伺服器無回應時 pendingInspect 永久 stale
    local timeoutGuid = guid
    C_Timer.After(5, function()
        if pendingInspect == timeoutGuid then
            pendingInspect = nil
        end
    end)
end

-- Inspect 回應事件（保留引用以便 Cleanup 解除註冊）
local inspectEventFrame = LunarUI.CreateEventHandler({ "INSPECT_READY" }, function(_self, _event, inspectGUID)
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
                    local L = Engine.L or _EMPTY
                    -- 新增 inspect 資訊行
                    if spec then
                        GameTooltip:AddLine("|cff888888" .. (L["TooltipSpec"] or "Spec:") .. "|r " .. spec, 1, 1, 1)
                    end
                    if ilvl then
                        GameTooltip:AddLine("|cff888888" .. (L["TooltipILvl"] or "iLvl:") .. "|r " .. ilvl, 1, 1, 1)
                    end
                    pcall(GameTooltip.Show, GameTooltip)
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
    -- 呼叫端已確保 tooltip 非 nil，此處不重複檢查

    -- 套用背景
    if tooltip.SetBackdrop then
        LunarUI.ApplyBackdrop(tooltip, nil, C.bgSolid)
    elseif tooltip.NineSlice then
        -- 正式服滑鼠提示使用 NineSlice
        tooltip.NineSlice:SetAlpha(0)

        if not tooltip.LunarBackdrop then
            local backdrop = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
            backdrop:SetAllPoints()
            backdrop:SetFrameLevel(tooltip:GetFrameLevel())
            LunarUI.ApplyBackdrop(backdrop, nil, C.bgSolid)
            tooltip.LunarBackdrop = backdrop
        else
            -- re-enable 後重新顯示（UnstyleTooltip 會 Hide）
            tooltip.LunarBackdrop:Show()
        end
    end

    -- 樣式化狀態列（血量條）
    if tooltip.StatusBar or GameTooltipStatusBar then
        local statusBar = tooltip.StatusBar or GameTooltipStatusBar
        -- 儲存原始狀態（僅首次）
        if not statusBar._lunarOrigTexture then
            local tex = statusBar:GetStatusBarTexture()
            statusBar._lunarOrigTexture = tex and tex:GetTexture()
        end
        if not statusBar._lunarOrigHeight then
            statusBar._lunarOrigHeight = statusBar:GetHeight()
        end
        if not statusBar._lunarOrigPoints then
            statusBar._lunarOrigPoints = {}
            for i = 1, statusBar:GetNumPoints() do
                statusBar._lunarOrigPoints[i] = { statusBar:GetPoint(i) }
            end
        end
        statusBar:SetStatusBarTexture(LunarUI.GetSelectedStatusBarTexture())
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
        else
            statusBar.LunarBG:Show()
        end
    end
end

local function UnstyleTooltip(tooltip)
    -- 還原 NineSlice（正式服）
    if tooltip.NineSlice then
        tooltip.NineSlice:SetAlpha(1)
    end
    -- 隱藏 LunarUI 自訂背景
    if tooltip.LunarBackdrop then
        tooltip.LunarBackdrop:Hide()
    end
    -- 還原 SetBackdrop（經典版 / 舊版）
    if tooltip.SetBackdrop then
        tooltip:SetBackdrop(nil)
    end
    -- 還原狀態列
    local statusBar = tooltip.StatusBar or _G.GameTooltipStatusBar
    if statusBar then
        -- 還原材質
        if statusBar._lunarOrigTexture then
            statusBar:SetStatusBarTexture(statusBar._lunarOrigTexture)
        end
        -- 還原高度
        statusBar:SetHeight(statusBar._lunarOrigHeight or 3)
        -- 還原定位
        statusBar:ClearAllPoints()
        if statusBar._lunarOrigPoints and #statusBar._lunarOrigPoints > 0 then
            for _, pt in ipairs(statusBar._lunarOrigPoints) do
                statusBar:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
            end
        else
            statusBar:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 0, 0)
            statusBar:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 0, 0)
        end
        if statusBar.LunarBG then
            statusBar.LunarBG:Hide()
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

local function UnstyleAllTooltips()
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
            UnstyleTooltip(tooltip)
        end
    end
end

--------------------------------------------------------------------------------
-- 單位滑鼠提示增強
--------------------------------------------------------------------------------

local function OnTooltipSetUnit(tooltip)
    if not LunarUI._modulesEnabled then
        return
    end
    local db = LunarUI.GetModuleDB("tooltip")
    if not db or not db.enabled then
        return
    end

    if not tooltip.GetUnit then
        return
    end
    local _, unit = tooltip:GetUnit()
    if not unit then
        return
    end

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

    -- === 新增：AFK / DND 狀態（使用 Blizzard 本地化全域字串）===
    if UnitIsPlayer(unit) then
        if UnitIsAFK(unit) then
            local afkFlag = _G.CHAT_FLAG_AFK or "<AFK>"
            tooltip:AppendText(" |cffff9900" .. afkFlag .. "|r")
        elseif UnitIsDND(unit) then
            local dndFlag = _G.CHAT_FLAG_DND or "<DND>"
            tooltip:AppendText(" |cffff3333" .. dndFlag .. "|r")
        end
    end

    -- === 新增：等級著色（等級行固定在 line 2）===
    local level = UnitLevel(unit)
    if level and level > 0 then
        local levelLine = _G[tooltip:GetName() .. "TextLeft2"]
        if levelLine then
            levelLine:SetTextColor(GetLevelDifficultyColor(level))
        end
    end

    -- === 新增：裝等 + 專精（玩家） ===
    local L = Engine.L or _EMPTY
    if UnitIsPlayer(unit) then
        local guid = UnitGUID(unit)
        if guid then
            local cached = GetCachedInspectData(guid)
            if cached then
                -- 顯示快取的 inspect 資料
                if cached.spec then
                    tooltip:AddLine("|cff888888" .. (L["TooltipSpec"] or "Spec:") .. "|r " .. cached.spec, 1, 1, 1)
                end
                if cached.ilvl then
                    tooltip:AddLine("|cff888888" .. (L["TooltipILvl"] or "iLvl:") .. "|r " .. cached.ilvl, 1, 1, 1)
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
            tooltip:AddLine("|cffffffff" .. (L["TooltipTarget"] or "Target:") .. "|r " .. targetName, tr, tg, tb)
        end
    end

    -- 角色資訊
    if UnitInParty(unit) or UnitInRaid(unit) then
        local role = UnitGroupRolesAssigned(unit)
        if role and role ~= "NONE" then
            local roleText = {
                TANK = "|cff5555ff" .. (L["RoleTank"] or "Tank") .. "|r",
                HEALER = "|cff55ff55" .. (L["RoleHealer"] or "Healer") .. "|r",
                DAMAGER = "|cffff5555" .. (L["RoleDPS"] or "DPS") .. "|r",
            }
            if roleText[role] then
                tooltip:AddLine((L["TooltipRole"] or "Role:") .. " " .. roleText[role])
            end
        end
    end

    -- NPC ID
    if not UnitIsPlayer(unit) then
        local guid = UnitGUID(unit)
        if guid then
            -- M-6: GUID 格式 Creature-0-RealmID-MapID-InstanceID-SpawnUID-NpcID（7 段）
            -- 第 6 段為 SpawnUID，第 7 段才是 NPC ID
            local unitType, _, _, _, _, _, npcID = strsplit("-", guid)
            if unitType == "Creature" or unitType == "Vehicle" then
                if npcID then
                    tooltip:AddLine("|cff888888NPC ID: " .. npcID .. "|r")
                end
            end
        end
    end

    -- 重新 Show 以更新 tooltip 大小（新增行後需要重新排版）
    -- pcall 保護：AddLine 等操作 taint 了 tooltip 的 width，Show() 觸發
    -- Backdrop.lua:SetupTextureCoordinates 在 secure context 中讀取 tainted width
    -- 會拋出 "secret number value tainted"。pcall 在源頭捕捉，不依賴全域 error filter
    -- 只對 GameTooltip 呼叫：其他 secure tooltip（NamePlateTooltip 等）由 Blizzard 自行管理顯示
    if not InCombatLockdown() and tooltip == GameTooltip then
        pcall(tooltip.Show, tooltip)
    end
end

--------------------------------------------------------------------------------
-- 物品滑鼠提示增強
--------------------------------------------------------------------------------

local function OnTooltipSetItem(tooltip)
    if not LunarUI._modulesEnabled then
        return
    end
    local db = LunarUI.GetModuleDB("tooltip")
    if not db or not db.enabled then
        return
    end

    if not tooltip.GetItem then
        return
    end
    local _, itemLink = tooltip:GetItem()
    if not itemLink then
        return
    end

    -- 顯示物品等級
    if db.showItemLevel then
        local itemLevel = GetItemLevel(itemLink)
        if itemLevel and itemLevel > 1 then
            local found = false
            local tooltipData = tooltip.GetTooltipData and tooltip:GetTooltipData()
            if tooltipData and tooltipData.lines then
                for i = 2, #tooltipData.lines do
                    local lineData = tooltipData.lines[i]
                    if
                        lineData
                        and lineData.leftText
                        and (lineData.leftText:find("Item Level") or lineData.leftText:find("物品等級"))
                    then
                        found = true
                        break
                    end
                end
            else
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
            end

            if not found then
                local L = Engine.L or _EMPTY
                tooltip:AddLine(" ")
                tooltip:AddLine("|cff00ff00" .. (L["TooltipItemLevel"] or "Item Level:") .. " " .. itemLevel .. "|r")
            end
        end
    end

    -- 顯示物品持有數量
    if db.showItemCount then
        local itemID = itemLink:match("item:(%d+)")
        if itemID then
            local numID = tonumber(itemID)
            if numID then
                local bagCount = C_Item.GetItemCount(numID, false) or 0 -- M-4: nil guard
                local totalCount = C_Item.GetItemCount(numID, true) -- 含銀行
                if totalCount and totalCount > 0 then
                    local bankCount = totalCount - bagCount
                    local L = Engine.L or _EMPTY
                    local countText = format("%s: %d", L["ItemCount"] or "Count", bagCount)
                    if bankCount > 0 then
                        countText = countText .. format("  (%s: %d)", L["BankTitle"] or "Bank", bankCount)
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
    -- 12.0: GetItemQualityByID 是正確 API，GetItemInfo 已 deprecated
    -- 物品未快取時兩者都回傳 nil（async），不做 fallback 避免呼叫 deprecated API
    local quality = itemID and C_Item.GetItemQualityByID(tonumber(itemID))
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

    if not InCombatLockdown() and tooltip == GameTooltip then
        pcall(tooltip.Show, tooltip)
    end
end

--------------------------------------------------------------------------------
-- 法術滑鼠提示增強
--------------------------------------------------------------------------------

local function OnTooltipSetSpell(tooltip)
    if not LunarUI._modulesEnabled then
        return
    end
    local db = LunarUI.GetModuleDB("tooltip")
    if not db or not db.enabled then
        return
    end
    if not db.showSpellID then
        return
    end

    -- 12.0 優先路徑：GetTooltipData().id（GetSpell() 在 TooltipDataProcessor 回呼中可能回傳 nil）
    local spellID
    local tooltipData = tooltip.GetTooltipData and tooltip:GetTooltipData()
    if tooltipData then
        spellID = tooltipData.id
    end
    -- 經典版 / 舊版 fallback
    if not spellID and tooltip.GetSpell then
        spellID = select(2, tooltip:GetSpell())
    end
    if spellID then
        tooltip:AddLine("|cff888888法術 ID: " .. spellID .. "|r")
        if not InCombatLockdown() and tooltip == GameTooltip then
            pcall(tooltip.Show, tooltip)
        end
    end
end

--------------------------------------------------------------------------------
-- 滑鼠提示定位
--------------------------------------------------------------------------------

local function AdjustTooltipPosition(tooltip)
    if not tooltip or not tooltip:IsShown() then
        return
    end

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local scale = tooltip:GetEffectiveScale() / UIParent:GetEffectiveScale()

    local left = tooltip:GetLeft()
    local right = tooltip:GetRight()
    local top = tooltip:GetTop()
    local bottom = tooltip:GetBottom()

    if not left or not right or not top or not bottom then
        return
    end

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
    local db = LunarUI.GetModuleDB("tooltip")
    if not db or not db.enabled then
        return
    end
    -- H-5: 無條件安裝 hook（之前以 anchorCursor 為安裝條件，導致動態切換後 hook 永不安裝）
    -- callback 內部以 db.anchorCursor 決定行為，與此處安裝時機解耦
    if tooltipPositionHooked then
        return
    end
    tooltipPositionHooked = true

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if not LunarUI._modulesEnabled then
            return
        end
        -- 動態查詢 db 以支援 profile 切換（hooksecurefunc 永久存在，不可依賴閉包捕捉的 db）
        local currentDB = LunarUI.GetModuleDB("tooltip")
        if not currentDB or not currentDB.enabled then
            return
        end
        if currentDB.anchorCursor then
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        else
            tooltip:SetOwner(parent, "ANCHOR_NONE")
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 50)
        end
    end)

    if GameTooltip then
        GameTooltip:HookScript("OnShow", function(self)
            if not LunarUI._modulesEnabled then
                return
            end
            C_Timer.After(0, function()
                if not LunarUI._modulesEnabled then
                    return
                end
                AdjustTooltipPosition(self)
            end)
        end)
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeTooltip()
    local db = LunarUI.GetModuleDB("tooltip")
    if not db or not db.enabled then
        return
    end

    -- hooks（TooltipDataProcessor / HookScript）無法移除，只註冊一次
    -- 各 callback 內部已有 db.enabled 檢查，toggle off 時自動停止工作
    if tooltipStyled then
        -- 重新啟用時恢復 inspect 事件（CleanupTooltip 會 UnregisterAllEvents）
        if inspectEventFrame then
            inspectEventFrame:RegisterEvent("INSPECT_READY")
        end
        -- 重新套用樣式（CleanupTooltip 不重設 tooltipStyled 以避免 HookScript 累積）
        StyleAllTooltips()
        return
    end
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
            if not LunarUI._modulesEnabled then
                return
            end
            StyleTooltip(self)
        end)

        -- 清除時重設邊框顏色
        GameTooltip:HookScript("OnTooltipCleared", function(self)
            if not LunarUI._modulesEnabled then
                return
            end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
            elseif self.LunarBackdrop then
                self.LunarBackdrop:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
            end
        end)
    end

    -- 設定定位
    SetTooltipPosition()
end

-- Cleanup（解除 Inspect 事件監聽 + 還原樣式）
local function CleanupTooltip()
    -- 還原所有 tooltip 的 LunarUI 樣式回 Blizzard 原生
    UnstyleAllTooltips()
    if inspectEventFrame then
        inspectEventFrame:UnregisterAllEvents()
        -- H-4: 不清除 OnEvent script — re-enable 時只需 RegisterEvent 即可恢復功能
        -- 清除 OnEvent 會導致 re-enable 後 INSPECT_READY 靜默無效
    end
    pendingInspect = nil -- H-4: 清除飛行中的 inspect，避免舊 GUID 洩漏到下次啟用週期
    ClearInspectCache()
end

-- 匯出
LunarUI.InitializeTooltip = InitializeTooltip
LunarUI.CleanupTooltip = CleanupTooltip
LunarUI.GetLevelDifficultyColor = GetLevelDifficultyColor
LunarUI.GetUnitColor = GetUnitColor
LunarUI.GetInspectItemLevel = GetInspectItemLevel
LunarUI.GetInspectSpec = GetInspectSpec
LunarUI.TooltipGetItemLevel = GetItemLevel
LunarUI.GetCachedInspectData = GetCachedInspectData
LunarUI.CacheInspectData = CacheInspectData
LunarUI.ClearInspectCache = ClearInspectCache
LunarUI.RequestInspect = RequestInspect
LunarUI.ResetInspectThrottle = function()
    lastInspectTime = 0
end

LunarUI:RegisterModule("Tooltip", {
    onEnable = InitializeTooltip,
    onDisable = CleanupTooltip,
    delay = 0.3,
    lifecycle = "reversible",
})
