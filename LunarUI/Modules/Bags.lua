---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 背包模組
    整合式背包系統，Lunar 主題風格

    功能：
    - 整合所有背包為單一視窗
    - 羊皮紙風格背景
    - 物品排序與分類
    - 搜尋功能
    - 裝備物品等級顯示
    - 垃圾自動販賣
    - 月相感知顯示
    - 專業容器背景著色
    - 裝等升級綠色上箭頭標記

    拆分模組：
    - Bags/BagUtils.lua: 物品分析工具（裝等、裝備判斷、升級判斷、專業容器顏色）
    - Bags/BankSystem.lua: 銀行系統（框架建立、格子管理、批次更新）
    - Bags/JunkSelling.lua: 垃圾販賣
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local mathCeil = math.ceil
local mathFloor = math.floor
local L = Engine.L or {}
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- DB 存取
--------------------------------------------------------------------------------

local function GetBagDB()
    return LunarUI.GetModuleDB("bags")
end

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 可設定常數（由 LoadBagSettings 從 DB 載入，此為 fallback 預設值）
local SLOT_SIZE = 37
local SLOT_SPACING = 4
local SLOTS_PER_ROW = 12
local PADDING = 10
local HEADER_HEIGHT = 30
local FOOTER_HEIGHT = 30
local SEARCH_DEBOUNCE = 0.2 -- 搜尋防抖延遲（秒）
local SEARCH_DIM_ALPHA = 0.3 -- 搜尋不符合時的透明度
local BORDER_COLOR_DEFAULT = C.border -- { 0.15, 0.12, 0.08, 1 }
local BORDER_COLOR_BANK = C.borderGold -- { 0.4, 0.35, 0.2, 1 }
local JUNK_SELL_DELAY = 0.3 -- 商人開啟後延遲販賣垃圾（秒）
local INIT_DELAY = 0.5 -- 插件初始化延遲（秒）
local FRAME_ALPHA = 0.95 -- 框架背景透明度
local backdropTemplate = LunarUI.backdropTemplate

-- 使用集中定義的品質顏色
local ITEM_QUALITY_COLORS = LunarUI.QUALITY_COLORS

-- 背包容器 ID 範圍（WoW 12.0: bag 0-4 = 一般背包，bag 5 = 材料袋）
local LAST_BAG = 5 -- 含材料袋（Enum.BagIndex.ReagentBag = 5）
-- 銀行容器 ID（供事件處理使用）
local FIRST_BANK_BAG = 6 -- CharacterBankTab_1
local LAST_BANK_BAG = 11 -- CharacterBankTab_6

--------------------------------------------------------------------------------
-- 從子模組匯入的函數（BagUtils.lua 已先載入）
--------------------------------------------------------------------------------

local function GetItemLevel(itemLink)
    return LunarUI.BagsGetItemLevel(itemLink)
end

local function IsEquipment(itemLink)
    return LunarUI.BagsIsEquipment(itemLink)
end

local function IsItemUpgrade(itemLink)
    return LunarUI.BagsIsItemUpgrade(itemLink)
end

local function GetBagTypeColor(bag)
    return LunarUI.BagsGetBagTypeColor(bag)
end

local function RefreshEquippedItemLevels()
    return LunarUI.BagsRefreshEquippedItemLevels()
end

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

local bagFrame
local slots = {}
local searchBox
local sortButton
local closeButton
local isOpen = false
local searchTimer -- 背包搜尋防抖計時器
local pendingBagUpdates = {} -- BAG_UPDATE 累積的背包 ID（由 BAG_UPDATE_DELAYED 處理）
local isSorting = false -- 排序進行中標記（排序期間跳過 ITEM_LOCK_CHANGED 全量更新）

-- 從 DB 載入背包設定（覆寫模組常數）
local function LoadBagSettings()
    local db = GetBagDB()
    if not db then
        return
    end
    SLOT_SIZE = db.slotSize or 37
    SLOT_SPACING = db.slotSpacing or 4
    SLOTS_PER_ROW = db.slotsPerRow or 12
    FRAME_ALPHA = db.frameAlpha or 0.95
end

--------------------------------------------------------------------------------
-- 匯出共用函數給子模組（BankSystem.lua, JunkSelling.lua 在呼叫時解析）
--------------------------------------------------------------------------------

-- 匯出常數表（動態讀取，反映 LoadBagSettings 後的值）
LunarUI.BagsConstants = setmetatable({}, {
    __index = function(_, key)
        local constants = {
            SLOT_SIZE = SLOT_SIZE,
            SLOT_SPACING = SLOT_SPACING,
            SLOTS_PER_ROW = SLOTS_PER_ROW,
            PADDING = PADDING,
            HEADER_HEIGHT = HEADER_HEIGHT,
            FOOTER_HEIGHT = FOOTER_HEIGHT,
            SEARCH_DEBOUNCE = SEARCH_DEBOUNCE,
            SEARCH_DIM_ALPHA = SEARCH_DIM_ALPHA,
            BORDER_COLOR_DEFAULT = BORDER_COLOR_DEFAULT,
            BORDER_COLOR_BANK = BORDER_COLOR_BANK,
            JUNK_SELL_DELAY = JUNK_SELL_DELAY,
            INIT_DELAY = INIT_DELAY,
            FRAME_ALPHA = FRAME_ALPHA,
        }
        return constants[key]
    end,
})

LunarUI.BagsLoadSettings = LoadBagSettings
LunarUI.BagsSetSorting = function(value)
    isSorting = value
end

--------------------------------------------------------------------------------
-- 輔助函數
--------------------------------------------------------------------------------

-- 背包 0-LAST_BAG 各欄位加總輔助，fn 為 C_Container 的槽位查詢函數
-- 使用 (fn(bag)) 限制取第一個回傳值，避免 GetContainerNumFreeSlots 回傳兩個值時的意外累加
local function SumBagSlots(fn)
    local total = 0
    for bag = 0, LAST_BAG do
        total = total + ((fn(bag)) or 0)
    end
    return total
end

local function GetTotalSlots()
    return SumBagSlots(C_Container.GetContainerNumSlots)
end

local function GetTotalFreeSlots()
    return SumBagSlots(C_Container.GetContainerNumFreeSlots)
end

--------------------------------------------------------------------------------
-- 格子建立
--------------------------------------------------------------------------------

-- 共用的 tooltip 顯示邏輯
local function ShowSlotTooltip(self)
    local itemInfo = C_Container.GetContainerItemInfo(self.bag, self.slot)
    if not itemInfo then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetBagItem, GameTooltip, self.bag, self.slot)
    if not ok then
        local link = C_Container.GetContainerItemLink(self.bag, self.slot)
        if link then
            pcall(GameTooltip.SetHyperlink, GameTooltip, link)
        end
    end
    GameTooltip:Show()
end

local function HideSlotTooltip()
    GameTooltip:Hide()
end

-- 不使用 SetScript("OnClick")：會干擾 SecureActionButtonTemplate 的 intrinsic handler。
-- 改為覆寫 mixin 方法 button.OnClick，由 XML 的 <OnClick method="OnClick"/> 呼叫，
-- 在 intrinsic SecureActionButton_OnClick 之後執行。

-- 隱藏格子上的所有指示器（重構：避免重複代碼）
local function HideAllSlotIndicators(button)
    if button.ilvlText then
        button.ilvlText:Hide()
    end
    if button.junkIcon then
        button.junkIcon:Hide()
    end
    if button.questIcon then
        button.questIcon:Hide()
    end
    if button.qualityGlow then
        button.qualityGlow:Hide()
    end
    if button.upgradeArrow then
        button.upgradeArrow:Hide()
    end
    if button.bindText then
        button.bindText:Hide()
    end
    if button.newGlow then
        if button.newGlowAnim then
            button.newGlowAnim:Stop()
        end
        button.newGlow:Hide()
    end
end

-- 設定格子按鈕的共用基礎（圖示、邊框、物品等級、tooltip）
local function SetupSlotBase(button, bag, slot)
    button.bag = bag
    button.slot = slot
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- SecureActionButtonTemplate: 右鍵使用物品（UseContainerItem）
    -- intrinsic handler SecureActionButton_OnClick 在安全環境中處理
    -- 使用 item2 屬性（"bag slot" 格式），bag/slot 屬性在 12.x 已 deprecated
    button:SetAttribute("type2", "item")
    button:SetAttribute("item2", bag .. " " .. slot)

    -- PreClick 在每次右鍵前同步 item2 屬性（按鈕重用時 bag/slot 可能變更）
    -- 戰鬥中不可呼叫 SetAttribute（protected operation），沿用上次設定的屬性即可
    button:SetScript("PreClick", function(self, clickButton)
        if clickButton == "RightButton" and not InCombatLockdown() then
            self:SetAttribute("item2", self.bag .. " " .. self.slot)
        end
    end)

    -- 移除預設材質
    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        normalTexture:SetTexture(nil)
    end

    -- 隱藏 ContainerFrameItemButtonTemplate 內建的新物品發光（避免與自訂 newGlow 衝突）
    if button.NewItemTexture then
        button.NewItemTexture:Hide()
        button.NewItemTexture:SetAlpha(0)
    end
    if button.BattlepayItemTexture then
        button.BattlepayItemTexture:Hide()
    end
    if button.flash then
        button.flash:Hide()
    end

    -- 設定圖示樣式
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexCoord(unpack(LunarUI.ICON_TEXCOORD))
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    -- 格子底色（BACKGROUND 層，位於 icon 下方，讓空格子也可見）
    if not button.slotBg then
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", -1, 1)
        bg:SetColorTexture(C.bgIcon[1], C.bgIcon[2], C.bgIcon[3], C.bgIcon[4])
        button.slotBg = bg
    end

    -- 建立邊框
    if not button.LunarBorder then
        local border = CreateFrame("Frame", nil, button, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop(backdropTemplate)
        border:SetBackdropColor(0, 0, 0, 0)
        border:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 1)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        border:EnableMouse(false) -- 讓滑鼠事件穿透到按鈕
        button.LunarBorder = border
    end

    -- 物品等級文字
    if not button.ilvlText then
        local ilvl = button:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(ilvl, 10, "OUTLINE")
        ilvl:SetPoint("BOTTOMRIGHT", -2, 2)
        ilvl:SetTextColor(1, 1, 0.6)
        button.ilvlText = ilvl
    end

    -- 綁定類型文字（BoE/BoP）
    if not button.bindText then
        local bind = button:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(bind, 9, "OUTLINE")
        bind:SetPoint("TOPLEFT", 2, -2)
        bind:SetTextColor(0.1, 1, 0.1)
        bind:Hide()
        button.bindText = bind
    end

    -- 新物品發光動畫
    if not button.newGlow then
        local glow = button:CreateTexture(nil, "OVERLAY", nil, 3)
        glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        glow:SetAllPoints()
        glow:SetVertexColor(1, 1, 1, 0.3)
        glow:SetBlendMode("ADD")
        glow:Hide()
        button.newGlow = glow

        -- 閃爍動畫組
        local ag = glow:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(0.4)
        fadeIn:SetDuration(0.6)
        fadeIn:SetOrder(1)
        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(0.4)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.6)
        fadeOut:SetOrder(2)
        button.newGlowAnim = ag
    end

    -- 設定 slot ID（mixin 的 OnClick 透過 self:GetID() 取得 slot）
    button:SetID(slot)

    -- 只在首次建立時設定 handler 和 mixin 方法（避免 re-layout 時重建 closure）
    if not button._lunarSetup then
        button._lunarSetup = true

        -- 修正模板的 GetBagID（預設從 parent chain 查找 ContainerFrame，但我們的 parent 不是）
        function button:GetBagID()
            return self.bag
        end

        -- 覆寫 tooltip
        button:SetScript("OnEnter", ShowSlotTooltip)
        button:SetScript("OnLeave", HideSlotTooltip)
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", function(self)
            C_Container.PickupContainerItem(self.bag, self.slot)
        end)
        button.OnEnter = ShowSlotTooltip
        button.OnLeave = HideSlotTooltip
        button.UpdateTooltip = ShowSlotTooltip

        -- 覆寫 mixin 的 OnClick 方法（不用 SetScript 以免干擾 intrinsic handler）
        -- XML 的 <OnClick method="OnClick"/> 會呼叫 self:OnClick(btn)，
        -- 在 SecureActionButton_OnClick（intrinsic）之後執行。
        -- 右鍵已由 intrinsic 透過 type2="item" 安全處理，此處只處理左鍵。
        function button:OnClick(btn)
            if btn == "RightButton" then
                return
            end
            if IsShiftKeyDown() then
                local link = C_Container.GetContainerItemLink(self.bag, self.slot)
                if link and ChatEdit_InsertLink then
                    ChatEdit_InsertLink(link)
                end
                return
            end
            C_Container.PickupContainerItem(self.bag, self.slot)
        end
    end
end

-- 匯出 SetupSlotBase 給 BankSystem.lua
LunarUI.BagsSetupSlotBase = SetupSlotBase

local function CreateItemSlot(parent, slotID, bag, slot)
    local button = CreateFrame(
        "ItemButton",
        "LunarUI_BagSlot" .. slotID,
        parent,
        "ContainerFrameItemButtonTemplate,SecureActionButtonTemplate"
    )
    button:SetSize(SLOT_SIZE, SLOT_SIZE)

    -- 設定共用基礎（圖示、邊框、物品等級、tooltip）
    SetupSlotBase(button, bag, slot)

    -- 垃圾指示器
    if not button.junkIcon then
        local junk = button:CreateTexture(nil, "OVERLAY")
        junk:SetSize(12, 12)
        junk:SetPoint("TOPLEFT", 2, -2)
        junk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
        junk:Hide()
        button.junkIcon = junk
    end

    -- 任務指示器
    if not button.questIcon then
        local quest = button:CreateTexture(nil, "OVERLAY")
        quest:SetSize(12, 12)
        quest:SetPoint("TOPLEFT", 2, -2)
        quest:SetTexture("Interface\\MINIMAP\\TRACKING\\QuestBlob")
        quest:Hide()
        button.questIcon = quest
    end

    -- 品質發光（史詩以上）
    if not button.qualityGlow then
        local glow = button:CreateTexture(nil, "BACKGROUND")
        glow:SetTexture(LunarUI.textures.glow)
        glow:SetBlendMode("ADD")
        glow:SetPoint("TOPLEFT", -6, 6)
        glow:SetPoint("BOTTOMRIGHT", 6, -6)
        glow:SetAlpha(0)
        glow:Hide()
        button.qualityGlow = glow
    end

    -- 升級箭頭指示器
    if not button.upgradeArrow then
        local arrow = button:CreateTexture(nil, "OVERLAY", nil, 2)
        arrow:SetSize(14, 14)
        arrow:SetPoint("TOPRIGHT", -1, -1)
        arrow:SetTexture("Interface\\BUTTONS\\UI-MicroStream-Green")
        arrow:SetTexCoord(0, 1, 1, 0) -- 翻轉為向上箭頭
        arrow:Hide()
        button.upgradeArrow = arrow
    end

    -- 專業容器背景著色
    if not button.profBg then
        local profBg = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        profBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        profBg:SetAllPoints()
        profBg:SetVertexColor(0, 0, 0, 0)
        profBg:Hide()
        button.profBg = profBg
    end

    -- 懸停高亮
    if not button.hoverHighlight then
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
        highlight:SetPoint("TOPLEFT", 1, -1)
        highlight:SetPoint("BOTTOMRIGHT", -1, 1)
        highlight:SetVertexColor(1, 1, 1, 0.15)
        highlight:SetBlendMode("ADD")
        button.hoverHighlight = highlight
    end

    return button
end

-- 更新格子視覺元素：圖示、數量、品質邊框與發光
local function UpdateSlotVisuals(button, containerInfo, quality)
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon and containerInfo.iconFileID then
        icon:SetTexture(containerInfo.iconFileID)
        icon:Show()
    end

    local count = containerInfo.stackCount or 0
    if count > 1 then
        button.Count:SetText(count)
        button.Count:Show()
    else
        button.Count:Hide()
    end

    if button.LunarBorder then
        if quality and ITEM_QUALITY_COLORS[quality] then
            local color = ITEM_QUALITY_COLORS[quality]
            button.LunarBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        else
            button.LunarBorder:SetBackdropBorderColor(
                BORDER_COLOR_DEFAULT[1],
                BORDER_COLOR_DEFAULT[2],
                BORDER_COLOR_DEFAULT[3],
                1
            )
        end
    end

    if button.qualityGlow then
        if quality and quality >= 4 and ITEM_QUALITY_COLORS[quality] then
            local color = ITEM_QUALITY_COLORS[quality]
            button.qualityGlow:SetVertexColor(color[1], color[2], color[3], 0.4)
            button.qualityGlow:SetAlpha(0.4)
            button.qualityGlow:Show()
        else
            button.qualityGlow:Hide()
        end
    end
end

-- 更新格子文字覆蓋：裝等、綁定類型
local function UpdateSlotText(button, db, itemLink)
    if button.ilvlText then
        if (not db or db.showItemLevel ~= false) and IsEquipment(itemLink) then
            local ilvl = GetItemLevel(itemLink)
            local threshold = (db and db.ilvlThreshold) or 1
            if ilvl and ilvl >= threshold then
                button.ilvlText:SetText(ilvl)
                button.ilvlText:Show()
            else
                button.ilvlText:Hide()
            end
        else
            button.ilvlText:Hide()
        end
    end

    if button.bindText then
        if db and db.showBindType and itemLink then
            local bindType = select(14, C_Item.GetItemInfo(itemLink))
            if bindType and bindType == 2 then
                button.bindText:SetText(L["BoE"] or "BoE")
                button.bindText:SetTextColor(0.1, 1, 0.1)
                button.bindText:Show()
            elseif bindType == 3 then
                button.bindText:SetText(L["BoU"] or "BoU")
                button.bindText:SetTextColor(0.9, 0.6, 0.2)
                button.bindText:Show()
            else
                button.bindText:Hide()
            end
        else
            button.bindText:Hide()
        end
    end
end

-- 更新格子效果：冷卻、新物品發光、垃圾/任務/升級指示、專業容器背景
local function UpdateSlotEffects(button, db, bag, slot, containerInfo, itemLink, quality)
    if db and db.showCooldown then
        local cooldown = button.Cooldown or button.cooldown
        if cooldown then
            local start, duration, enable = C_Container.GetContainerItemCooldown(bag, slot)
            if start and duration and enable == 1 and duration > 0 then
                CooldownFrame_Set(cooldown, start, duration, enable)
                cooldown:Show()
            else
                cooldown:Hide()
            end
        end
    end

    if button.newGlow then
        if db and db.showNewGlow and C_NewItems.IsNewItem(bag, slot) then
            button.newGlow:Show()
            if button.newGlowAnim and not button.newGlowAnim:IsPlaying() then
                button.newGlowAnim:Play()
            end
        else
            if button.newGlowAnim then
                button.newGlowAnim:Stop()
            end
            button.newGlow:Hide()
        end
    end

    if button.junkIcon then
        if quality == 0 and containerInfo.hasNoValue ~= true then
            button.junkIcon:Show()
        else
            button.junkIcon:Hide()
        end
    end

    if button.questIcon then
        if db and db.showQuestItems ~= false and containerInfo.isQuestItem then
            button.questIcon:Show()
            if button.junkIcon then
                button.junkIcon:Hide()
            end
        else
            button.questIcon:Hide()
        end
    end

    if button.upgradeArrow then
        if IsItemUpgrade(itemLink) then
            button.upgradeArrow:Show()
        else
            button.upgradeArrow:Hide()
        end
    end

    if button.profBg then
        if db and db.showProfessionColors ~= false then
            local bagColor = GetBagTypeColor(bag)
            if bagColor then
                button.profBg:SetVertexColor(bagColor[1], bagColor[2], bagColor[3], bagColor[4])
                button.profBg:Show()
            else
                button.profBg:Hide()
            end
        else
            button.profBg:Hide()
        end
    end
end

-- 清空格子顯示
local function ClearSlot(button, db, bag)
    local icon = button.icon or _G[button:GetName() .. "IconTexture"]
    if icon then
        icon:SetTexture(nil)
    end
    if button.Count then
        button.Count:Hide()
    end
    if button.LunarBorder then
        button.LunarBorder:SetBackdropBorderColor(
            BORDER_COLOR_DEFAULT[1],
            BORDER_COLOR_DEFAULT[2],
            BORDER_COLOR_DEFAULT[3],
            0.5
        )
    end
    HideAllSlotIndicators(button)
    local cooldown = button.Cooldown or button.cooldown
    if cooldown then
        cooldown:Hide()
    end

    if button.profBg then
        if db and db.showProfessionColors ~= false then
            local bagColor = GetBagTypeColor(bag)
            if bagColor then
                button.profBg:SetVertexColor(bagColor[1], bagColor[2], bagColor[3], bagColor[4] * 0.5)
                button.profBg:Show()
            else
                button.profBg:Hide()
            end
        else
            button.profBg:Hide()
        end
    end
end

-- 匯出 UpdateSlotVisuals, UpdateSlotText, ClearSlot 給 BankSystem.lua
LunarUI.BagsUpdateSlotVisuals = UpdateSlotVisuals
LunarUI.BagsUpdateSlotText = UpdateSlotText
LunarUI.BagsClearSlot = ClearSlot

local function UpdateSlot(button)
    if not button or not button.bag or not button.slot then
        return
    end

    local db = GetBagDB()
    local bag, slot = button.bag, button.slot
    local containerInfo = C_Container.GetContainerItemInfo(bag, slot)

    if containerInfo then
        local itemLink = C_Container.GetContainerItemLink(bag, slot)
        local quality = containerInfo.quality or 0
        UpdateSlotVisuals(button, containerInfo, quality)
        UpdateSlotText(button, db, itemLink)
        UpdateSlotEffects(button, db, bag, slot, containerInfo, itemLink, quality)
    else
        ClearSlot(button, db, bag)
    end
end

--------------------------------------------------------------------------------
-- 共用搜尋過濾（背包 / 銀行共用）
--------------------------------------------------------------------------------

local function SearchSlots(searchBoxRef, slotList, errorKey)
    if not searchBoxRef then
        return
    end
    local text = searchBoxRef:GetText():lower()
    for _, button in pairs(slotList) do
        if button and button:IsShown() and button.bag and button.slot then
            local success, err = pcall(function()
                local itemLink = C_Container.GetContainerItemLink(button.bag, button.slot)
                if itemLink then
                    local itemName = C_Item.GetItemInfo(itemLink)
                    if itemName then
                        if text == "" or itemName:lower():find(text, 1, true) then
                            button:SetAlpha(1)
                        else
                            button:SetAlpha(SEARCH_DIM_ALPHA)
                        end
                    else
                        button:SetAlpha(1)
                    end
                else
                    button:SetAlpha(text == "" and 1 or SEARCH_DIM_ALPHA)
                end
            end)
            if not success then
                button:SetAlpha(1)
                if LunarUI:IsDebugMode() then
                    LunarUI:Debug((L[errorKey] or "Search error: ") .. tostring(err))
                end
            end
        end
    end
end

-- 匯出 SearchSlots 給 BankSystem.lua
LunarUI.BagsSearchSlots = SearchSlots

--------------------------------------------------------------------------------
-- 背包框架建立
--------------------------------------------------------------------------------

local function CreateBagFrame()
    local db = GetBagDB()
    if not db or not db.enabled then
        return
    end

    if bagFrame then
        return bagFrame
    end

    -- 從 DB 載入設定
    LoadBagSettings()

    -- 計算框架大小
    local totalSlots = GetTotalSlots()
    local numRows
    if db.splitBags then
        -- 分離視圖：每個背包佔獨立行區塊，需預算額外行數
        local layoutIdx = 0
        local prevBag = nil
        for bag = 0, LAST_BAG do
            local numBagSlots = C_Container.GetContainerNumSlots(bag)
            if numBagSlots > 0 then
                if prevBag ~= nil then
                    local currentCol = layoutIdx % SLOTS_PER_ROW
                    if currentCol ~= 0 then
                        layoutIdx = layoutIdx + (SLOTS_PER_ROW - currentCol)
                    end
                end
                prevBag = bag
                layoutIdx = layoutIdx + numBagSlots
            end
        end
        numRows = mathCeil(layoutIdx / SLOTS_PER_ROW)
    else
        numRows = mathCeil(totalSlots / SLOTS_PER_ROW)
    end
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT

    -- 建立主框架
    bagFrame = CreateFrame("Frame", "LunarUI_Bags", UIParent, "BackdropTemplate")
    bagFrame:SetSize(width, height)

    -- 位置記憶：優先讀取已儲存位置
    if db.bagPosition then
        bagFrame:SetPoint(
            db.bagPosition.point,
            UIParent,
            db.bagPosition.relPoint or db.bagPosition.point,
            db.bagPosition.x,
            db.bagPosition.y
        )
    else
        bagFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 100)
    end

    bagFrame:SetBackdrop(backdropTemplate)
    bagFrame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], FRAME_ALPHA)
    bagFrame:SetBackdropBorderColor(BORDER_COLOR_DEFAULT[1], BORDER_COLOR_DEFAULT[2], BORDER_COLOR_DEFAULT[3], 1)
    bagFrame:SetFrameStrata("HIGH")
    bagFrame:SetMovable(true)
    bagFrame:EnableMouse(true)
    bagFrame:SetClampedToScreen(true)
    bagFrame:Hide()

    -- 可拖曳
    bagFrame:RegisterForDrag("LeftButton")
    bagFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bagFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- 儲存位置到 DB（含 relativePoint 以確保跨解析度正確）
        local point, _, relPoint, x, y = self:GetPoint()
        local bagDb = GetBagDB()
        if bagDb then
            bagDb.bagPosition = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- 標題
    local title = bagFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(title, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", PADDING, -8)
    title:SetText(L["BagTitle"] or "Bags")
    title:SetTextColor(0.9, 0.9, 0.9)
    bagFrame.title = title

    -- 關閉按鈕
    closeButton = CreateFrame("Button", nil, bagFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 2, 2)
    LunarUI.SkinCloseButton(closeButton)
    closeButton:SetScript("OnClick", function()
        CloseAllBags()
    end)

    -- 搜尋框
    searchBox = CreateFrame("EditBox", "LunarUI_BagSearch", bagFrame, "SearchBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", -8, -2)

    -- 搜尋邏輯（委託共用 SearchSlots）
    local function PerformBagSearch()
        SearchSlots(searchBox, slots, "BagSearchError")
    end

    -- 搜尋防抖動：使用 HookScript 保留 SearchBoxTemplate 內建的佔位文字隱藏行為
    searchBox:HookScript("OnTextChanged", function()
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end
        searchTimer = C_Timer.NewTimer(SEARCH_DEBOUNCE, PerformBagSearch)
    end)

    -- 排序按鈕
    sortButton = CreateFrame("Button", nil, bagFrame, "UIPanelButtonTemplate")
    sortButton:SetSize(60, 20)
    sortButton:SetPoint("TOPLEFT", title, "TOPRIGHT", 10, 2)
    sortButton:SetText(L["Sort"] or "Sort")
    LunarUI.SkinButton(sortButton)

    sortButton:SetScript("OnClick", function()
        if InCombatLockdown() then
            return
        end
        isSorting = true
        C_Container.SortBags()
    end)

    -- 格子容器
    local slotContainer = CreateFrame("Frame", nil, bagFrame)
    slotContainer:SetPoint("TOPLEFT", PADDING, -HEADER_HEIGHT)
    slotContainer:SetPoint("BOTTOMRIGHT", -PADDING, FOOTER_HEIGHT)
    slotContainer:EnableMouse(false) -- 讓滑鼠事件穿透到子按鈕
    bagFrame.slotContainer = slotContainer

    -- 收集所有格子的 bag/slot 資料（支援反轉順序）
    local slotList = {}
    for bag = 0, LAST_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotList[#slotList + 1] = { bag = bag, slot = slot }
        end
    end
    if db.reverseBagSlots then
        -- 反轉整個清單
        local n = #slotList
        for i = 1, mathFloor(n / 2) do
            slotList[i], slotList[n - i + 1] = slotList[n - i + 1], slotList[i]
        end
    end

    -- 建立格子（支援分離背包視圖）
    local slotID = 0
    local layoutIdx = 0 -- 實際佈局索引（分離視圖可能跳行）
    local prevBag = nil
    for _, slotInfo in ipairs(slotList) do
        slotID = slotID + 1
        local button = CreateItemSlot(slotContainer, slotID, slotInfo.bag, slotInfo.slot)

        -- 分離背包視圖：當 bagID 改變時，跳到下一行起始
        if db.splitBags and prevBag ~= nil and slotInfo.bag ~= prevBag then
            local currentCol = layoutIdx % SLOTS_PER_ROW
            if currentCol ~= 0 then
                layoutIdx = layoutIdx + (SLOTS_PER_ROW - currentCol)
            end
        end
        prevBag = slotInfo.bag

        local row = mathFloor(layoutIdx / SLOTS_PER_ROW)
        local col = layoutIdx % SLOTS_PER_ROW

        button:SetPoint(
            "TOPLEFT",
            slotContainer,
            "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )

        -- 設定按鈕 ID 以支援預設背包行為
        button:SetID(slotInfo.slot)
        SetItemButtonDesaturated(button, false)

        slots[slotID] = button
        layoutIdx = layoutIdx + 1
    end

    -- 金錢顯示
    local money = bagFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(money, 12, "OUTLINE")
    money:SetPoint("BOTTOMLEFT", PADDING, 8)
    money:SetTextColor(1, 0.82, 0)
    bagFrame.money = money

    -- 空格指示器
    local freeSlots = bagFrame:CreateFontString(nil, "OVERLAY")
    LunarUI.SetFont(freeSlots, 10, "OUTLINE")
    freeSlots:SetPoint("BOTTOMRIGHT", -PADDING, 8)
    freeSlots:SetTextColor(0.7, 0.7, 0.7)
    bagFrame.freeSlots = freeSlots

    return bagFrame
end

--------------------------------------------------------------------------------
-- 更新函數
--------------------------------------------------------------------------------

local function UpdateMoney()
    if not bagFrame or not bagFrame.money then
        return
    end

    local money = GetMoney()
    local gold = floor(money / 10000)
    local silver = floor((money % 10000) / 100)
    local copper = money % 100

    bagFrame.money:SetFormattedText("|cffffd700%d|r.|cffc0c0c0%02d|r.|cffeda55f%02d|r", gold, silver, copper)
end

local function UpdateFreeSlots()
    if not bagFrame or not bagFrame.freeSlots then
        return
    end

    local free = GetTotalFreeSlots()
    local total = GetTotalSlots()
    bagFrame.freeSlots:SetFormattedText("%d / %d", free, total)
end

local function UpdateAllSlots()
    -- 預計算所有背包的專業容器顏色（避免逐格重複呼叫）
    for bag = 0, LAST_BAG do
        GetBagTypeColor(bag)
    end
    for _, button in pairs(slots) do
        if button then
            UpdateSlot(button)
        end
    end
    UpdateMoney()
    UpdateFreeSlots()
end

-- 僅更新升級箭頭（用於 PLAYER_EQUIPMENT_CHANGED，避免全量重繪）
local function UpdateUpgradeArrows()
    for _, button in pairs(slots) do
        if button and button.upgradeArrow then
            local itemLink = C_Container.GetContainerItemLink(button.bag, button.slot)
            if itemLink and IsItemUpgrade(itemLink) then
                button.upgradeArrow:Show()
            else
                button.upgradeArrow:Hide()
            end
        end
    end
end

local function RefreshBagLayout()
    if not bagFrame then
        return
    end

    local db = GetBagDB()

    -- 收集所有格子的 bag/slot 資料（支援反轉順序）
    local slotList = {}
    for bag = 0, LAST_BAG do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            slotList[#slotList + 1] = { bag = bag, slot = slot }
        end
    end
    if db and db.reverseBagSlots then
        local n = #slotList
        for i = 1, mathFloor(n / 2) do
            slotList[i], slotList[n - i + 1] = slotList[n - i + 1], slotList[i]
        end
    end

    -- 計算框架大小（支援分離背包視圖）
    local numRows
    if db and db.splitBags then
        local layoutIdx = 0
        local prevBag = nil
        for bag = 0, LAST_BAG do
            local numBagSlots = C_Container.GetContainerNumSlots(bag)
            if numBagSlots > 0 then
                if prevBag ~= nil then
                    local currentCol = layoutIdx % SLOTS_PER_ROW
                    if currentCol ~= 0 then
                        layoutIdx = layoutIdx + (SLOTS_PER_ROW - currentCol)
                    end
                end
                prevBag = bag
                layoutIdx = layoutIdx + numBagSlots
            end
        end
        numRows = mathCeil(layoutIdx / SLOTS_PER_ROW)
    else
        numRows = mathCeil(#slotList / SLOTS_PER_ROW)
    end
    local width = SLOTS_PER_ROW * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2
    local height = numRows * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + PADDING * 2 + HEADER_HEIGHT + FOOTER_HEIGHT

    bagFrame:SetSize(width, height)

    -- 佈局格子（支援分離背包）
    local slotID = 0
    local layoutIdx = 0
    local prevBag = nil
    for _, slotInfo in ipairs(slotList) do
        slotID = slotID + 1

        local button = slots[slotID]
        if not button then
            button = CreateItemSlot(bagFrame.slotContainer, slotID, slotInfo.bag, slotInfo.slot)
            slots[slotID] = button
        end
        button.bag = slotInfo.bag
        button.slot = slotInfo.slot
        button:SetID(slotInfo.slot)

        -- 分離背包視圖
        if db and db.splitBags and prevBag ~= nil and slotInfo.bag ~= prevBag then
            local currentCol = layoutIdx % SLOTS_PER_ROW
            if currentCol ~= 0 then
                layoutIdx = layoutIdx + (SLOTS_PER_ROW - currentCol)
            end
        end
        prevBag = slotInfo.bag

        local row = mathFloor(layoutIdx / SLOTS_PER_ROW)
        local col = layoutIdx % SLOTS_PER_ROW

        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            bagFrame.slotContainer,
            "TOPLEFT",
            col * (SLOT_SIZE + SLOT_SPACING),
            -row * (SLOT_SIZE + SLOT_SPACING)
        )
        button:SetSize(SLOT_SIZE, SLOT_SIZE)
        button:Show()
        layoutIdx = layoutIdx + 1
    end

    -- 隱藏多餘格子
    for i = slotID + 1, #slots do
        if slots[i] then
            slots[i]:Hide()
        end
    end

    UpdateAllSlots()
end

--------------------------------------------------------------------------------
-- 開啟/關閉背包
--------------------------------------------------------------------------------

local function OpenBags()
    if InCombatLockdown() then
        return
    end

    if not bagFrame then
        CreateBagFrame()
    end

    if bagFrame then
        -- 刷新裝備等級快取（用於升級箭頭判斷）
        LunarUI.BagsResetEquippedIlvlDirty()
        RefreshEquippedItemLevels()
        -- 清除背包類型快取（背包可能已更換）
        LunarUI.BagsClearBagTypeCache()

        RefreshBagLayout()
        bagFrame:Show()
        isOpen = true
    end
end

local function CloseBags()
    if bagFrame then
        bagFrame:Hide()
        isOpen = false
        isSorting = false -- 防禦性重設：排序中關閉背包時 BAG_UPDATE_DELAYED 可能不觸發
        -- 取消搜尋計時器避免洩漏
        if searchTimer then
            searchTimer:Cancel()
            searchTimer = nil
        end
        -- 關閉時清除搜尋
        local db = GetBagDB()
        if db and db.clearSearchOnClose and searchBox then
            searchBox:SetText("")
            for _, button in pairs(slots) do
                if button then
                    button:SetAlpha(1)
                end
            end
        end
        -- 清除待處理的背包更新佇列
        wipe(pendingBagUpdates)
    end
end

local function ToggleBags()
    if isOpen then
        CloseBags()
    else
        OpenBags()
    end
end

-- 完全重建背包框架（設定變更後呼叫）
function LunarUI.RebuildBags()
    local wasOpen = isOpen
    local wasBankOpen = LunarUI.BagsIsBankOpen()

    -- 隱藏並清理舊格子（WoW 框架不可銷毀，僅隱藏+解除錨定）
    for _, button in pairs(slots) do
        if button then
            if button.newGlowAnim then
                button.newGlowAnim:Stop()
            end
            button:Hide()
            button:ClearAllPoints()
        end
    end

    -- 清理銀行（委託 BankSystem）
    LunarUI.BankSystemCleanup()

    isSorting = false

    -- 隱藏主框架（但不 SetParent(nil)，保留供子框架重新 reparent）
    if bagFrame then
        CloseBags()
        bagFrame:Hide()
        bagFrame = nil
    end

    -- 清空格子參照
    wipe(slots)
    searchBox = nil
    sortButton = nil
    closeButton = nil

    -- 重新載入設定
    LoadBagSettings()

    -- 重建
    if wasOpen then
        OpenBags()
    end
    if wasBankOpen then
        LunarUI.OpenBank()
    end
end

--------------------------------------------------------------------------------
-- 掛鉤暴雪背包函數
--------------------------------------------------------------------------------

local hooksRegistered = false

local function HookBagFunctions()
    if hooksRegistered then
        return
    end

    local db = GetBagDB()
    if not db or not db.enabled then
        return
    end

    hooksRegistered = true

    -- 掛鉤 ToggleAllBags（B 鍵入口）
    -- WoW 12.0.1 的 ToggleAllBags 直接操作 ContainerFrameCombinedBags，
    -- 不再內部呼叫 OpenAllBags/CloseAllBags，因此必須獨立掛鉤
    hooksecurefunc("ToggleAllBags", function()
        if not LunarUI._modulesEnabled then
            return
        end
        ToggleBags()
    end)

    -- 掛鉤 OpenAllBags / CloseAllBags（其他插件或遊戲系統直接呼叫的路徑）
    hooksecurefunc("OpenAllBags", function()
        if not LunarUI._modulesEnabled then
            return
        end
        OpenBags()
    end)

    -- 掛鉤 CloseAllBags
    hooksecurefunc("CloseAllBags", function()
        if not LunarUI._modulesEnabled then
            return
        end
        CloseBags()
    end)

    -- 徹底禁用暴雪背包框架（alpha 0 + 移到螢幕外 + 禁用滑鼠）
    -- 只設 alpha 0 不夠：框架仍接收滑鼠事件，會擋住我們的自訂背包
    local function KillBlizzardFrame(frame)
        if not frame then
            return
        end
        pcall(function()
            frame:SetAlpha(0)
            frame:EnableMouse(false)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
            for _, child in ipairs({ frame:GetChildren() }) do
                pcall(function()
                    child:EnableMouse(false)
                end)
            end
        end)
    end

    -- 掛鉤 Show：暴雪每次打開背包都會 Show 這些框架，需持續壓制
    local function KillAndHookShow(frame)
        -- 儲存原始定位，供 CleanupBags 還原
        if not frame._lunarSavedPoint then
            local point, relativeTo, relativePoint, x, y = frame:GetPoint()
            if point then
                frame._lunarSavedPoint = { point, relativeTo, relativePoint, x, y }
            end
        end
        KillBlizzardFrame(frame)
        pcall(function()
            hooksecurefunc(frame, "Show", function(self)
                if not LunarUI._modulesEnabled then
                    return
                end
                KillBlizzardFrame(self)
            end)
        end)
    end

    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            KillAndHookShow(frame)
        end
    end
    if ContainerFrameCombinedBags then
        KillAndHookShow(ContainerFrameCombinedBags)
    end
    if BankFrame then
        KillAndHookShow(BankFrame)
    end
    -- 戰團銀行面板（AccountBankPanel）
    if AccountBankPanel then
        KillAndHookShow(AccountBankPanel)
    end
end

--------------------------------------------------------------------------------
-- 事件處理
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlerSet = false -- 防止重複設定 handler

-- 從子模組取得銀行相關函數（呼叫時解析）
local function OpenBank()
    return LunarUI.BagsOpenBank()
end
local function CloseBank()
    return LunarUI.BagsCloseBank()
end
local function UpdateAllBankSlots()
    return LunarUI.BagsUpdateAllBankSlots()
end
local function UpdateBankSlot(button)
    return LunarUI.BagsUpdateBankSlot(button)
end
local function GetTotalBankFreeSlots()
    return LunarUI.GetTotalBankFreeSlots()
end
local function GetTotalBankSlots()
    return LunarUI.GetTotalBankSlots()
end
local function SellJunk()
    return LunarUI.BagsSellJunk()
end

-- 事件處理函數 (提取到模組層級)
local function OnBagEvent(_self, event, ...)
    -- 商人開啟時自動販賣垃圾
    if event == "MERCHANT_SHOW" then
        local db = GetBagDB()
        if db and db.autoSellJunk then
            C_Timer.After(JUNK_SELL_DELAY, SellJunk)
        end
        return
    end

    -- 銀行事件處理
    if event == "BANKFRAME_OPENED" then
        local db = GetBagDB()
        if db and db.enabled then
            OpenBank()
            -- 開啟銀行時同時開啟背包
            OpenBags()
        end
        return
    end

    if event == "BANKFRAME_CLOSED" then
        CloseBank()
        return
    end

    if event == "PLAYERBANKSLOTS_CHANGED" then
        -- SortBankBags 觸發 PLAYERBANKSLOTS_CHANGED（不觸發 BAG_UPDATE_DELAYED），需在此重設旗標
        isSorting = false
        local bankFrame = LunarUI.BagsGetBankFrame()
        if bankFrame and bankFrame:IsShown() then
            UpdateAllBankSlots()
        end
        return
    end

    -- 裝備變更時標記快取過期，僅更新升級箭頭（避免全量重繪）
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        LunarUI.BagsResetEquippedIlvlDirty()
        if bagFrame and bagFrame:IsShown() then
            UpdateUpgradeArrows()
        end
        return
    end

    -- BAG_UPDATE：僅記錄需更新的背包 ID（排序時會密集觸發，不在此處理）
    if event == "BAG_UPDATE" then
        local bag = ...
        if bag then
            pendingBagUpdates[bag] = true
        end
        return
    end

    -- BAG_UPDATE_DELAYED：WoW 原生事件，在一連串 BAG_UPDATE 結束後觸發一次
    -- 這是 Bagnon 使用的模式，比 C_Timer 節流更可靠且零開銷
    if event == "BAG_UPDATE_DELAYED" then
        local bankFrame = LunarUI.BagsGetBankFrame()
        local bankSlots = LunarUI.BagsGetBankSlots()
        -- 處理累積的背包更新
        for pendingBag in pairs(pendingBagUpdates) do
            -- 更新背包（0-LAST_BAG，含材料袋）
            if pendingBag >= 0 and pendingBag <= LAST_BAG then
                if bagFrame and bagFrame:IsShown() then
                    for _, button in pairs(slots) do
                        if button and button.bag == pendingBag then
                            UpdateSlot(button)
                        end
                    end
                end
            end
            -- 更新銀行包
            if pendingBag >= FIRST_BANK_BAG and pendingBag <= LAST_BANK_BAG then
                if bankFrame and bankFrame:IsShown() then
                    for _, button in pairs(bankSlots) do
                        if button and button.bag == pendingBag then
                            UpdateBankSlot(button)
                        end
                    end
                end
            end
        end

        -- 更新計數器
        if bagFrame and bagFrame:IsShown() then
            UpdateFreeSlots()
        end
        if bankFrame and bankFrame:IsShown() and bankFrame.freeSlots then
            local free = GetTotalBankFreeSlots()
            local total = GetTotalBankSlots()
            bankFrame.freeSlots:SetFormattedText("%d / %d", free, total)
        end

        wipe(pendingBagUpdates)
        -- 排序後清理物品快取（避免 orphan entries 累積）
        if isSorting then
            LunarUI.BagsClearAllCaches()
        end
        isSorting = false -- 排序完成，恢復正常事件處理
        return
    end

    if not bagFrame or not bagFrame:IsShown() then
        return
    end

    if event == "PLAYER_MONEY" then
        UpdateMoney()
    elseif event == "ITEM_LOCK_CHANGED" then
        -- 排序期間跳過：SortBags 會密集觸發 ITEM_LOCK_CHANGED（每次物品移動 2 次），
        -- 每次都呼叫 UpdateAllSlots 會造成嚴重卡頓。排序結束後由 BAG_UPDATE_DELAYED 統一更新。
        if not isSorting then
            UpdateAllSlots()
            local bankFrame = LunarUI.BagsGetBankFrame()
            if bankFrame and bankFrame:IsShown() then
                UpdateAllBankSlots()
            end
        end
    elseif event == "BAG_SLOT_FLAGS_UPDATED" then
        -- 背包類型可能已改變（換包），清除專業容器快取
        LunarUI.BagsClearBagTypeCache()
        RefreshBagLayout()
        local bankFrame = LunarUI.BagsGetBankFrame()
        if bankFrame and bankFrame:IsShown() then
            UpdateAllBankSlots()
        end
    end
end

--------------------------------------------------------------------------------
-- 初始化
--------------------------------------------------------------------------------

local function InitializeBags()
    local db = GetBagDB()
    if not db or not db.enabled then
        return
    end

    -- 註冊事件 (移到 InitializeBags 中，確保 disable/enable 可正常工作)
    if not eventHandlerSet then
        eventFrame:SetScript("OnEvent", OnBagEvent)
        eventHandlerSet = true
    end

    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:RegisterEvent("BAG_SLOT_FLAGS_UPDATED")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("BANKFRAME_CLOSED")
    eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

    -- 掛鉤背包函數
    HookBagFunctions()

    -- 快捷鍵開啟背包由暴雪預設按鍵系統處理
end

-- 清理函數
function LunarUI.CleanupBags()
    eventFrame:UnregisterAllEvents()
    CloseBags()
    CloseBank()
    -- 清理快取，避免 re-enable 時殘留 stale entries
    LunarUI.BagsClearAllCaches()
    -- 使飛行中的 SellJunk 販賣鏈失效
    if LunarUI.InvalidateSellJunk then
        LunarUI.InvalidateSellJunk()
    end
    -- 還原被 KillBlizzardFrame 壓制的原生背包框架
    local function RestoreBlizzardFrame(frame)
        if not frame then
            return
        end
        pcall(function()
            frame:SetAlpha(1)
            frame:EnableMouse(true)
            -- 還原原始定位（KillBlizzardFrame 移到了螢幕外）
            if frame._lunarSavedPoint then
                local p = frame._lunarSavedPoint
                frame:ClearAllPoints()
                frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
            end
            for _, child in ipairs({ frame:GetChildren() }) do
                pcall(function()
                    child:EnableMouse(true)
                end)
            end
        end)
    end
    for i = 1, 13 do
        RestoreBlizzardFrame(_G["ContainerFrame" .. i])
    end
    RestoreBlizzardFrame(_G.ContainerFrameCombinedBags)
    RestoreBlizzardFrame(_G.BankFrame)
    RestoreBlizzardFrame(_G.AccountBankPanel)
    -- 注意：hooksRegistered 不重設，因為 hooksecurefunc hook 無法取消，
    -- re-enable 時重新呼叫 HookBagFunctions() 會因 hooksRegistered=true 跳過（正確行為）
end

-- 匯出
LunarUI.InitializeBags = InitializeBags
LunarUI.GetTotalSlots = GetTotalSlots
LunarUI.GetTotalFreeSlots = GetTotalFreeSlots

LunarUI:RegisterModule("Bags", {
    onEnable = InitializeBags,
    onDisable = LunarUI.CleanupBags,
    delay = INIT_DELAY,
    lifecycle = "reversible",
})
