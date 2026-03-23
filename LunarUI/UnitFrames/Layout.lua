---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, unnecessary-if, redundant-value, need-check-nil, return-type-mismatch
--[[
    LunarUI - oUF 佈局
    定義所有單位框架的視覺風格

    月相感知單位框架：根據月相變化調整外觀
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

-- 等待 oUF 可用（TOC 中設定 X-oUF: LunarUF）
local oUF = Engine.oUF or _G.LunarUF or _G.oUF
if not oUF then
    local L = Engine.L or {}
    print("|cffff0000LunarUI:|r " .. (L["ErrorOUFNotFound"] or "找不到 oUF 框架"))
    return
end

--------------------------------------------------------------------------------
-- 常數與共用資源
--------------------------------------------------------------------------------

-- 前向宣告（供後續函數使用）
local spawnedFrames = {}
local savedStateDrivers = {} -- { [frame] = conditionString } — re-enable 時重新註冊
local combatWaitFrame -- 戰鬥等待框架（重用避免洩漏）
local ufGeneration = 0 -- 世代計數器：防止 disable 後延遲 timer 仍觸發 spawn/update

local CreateBackdrop = LunarUI.CreateBackdrop

-- 框架尺寸
-- ElvUI-inspired compact sizes（fallback，正常由 Defaults.lua 的 DB 值覆蓋）
local SIZES = {
    player = { width = 220, height = 26 },
    target = { width = 220, height = 26 },
    focus = { width = 180, height = 22 },
    pet = { width = 120, height = 16 },
    targettarget = { width = 120, height = 16 },
    boss = { width = 180, height = 24 },
    party = { width = 150, height = 22 },
    raid = { width = 80, height = 20 },
}

--------------------------------------------------------------------------------
-- 佈局函數
--------------------------------------------------------------------------------

--[[ 所有單位的共用佈局 ]]
local function Shared(frame, unit)
    frame:RegisterForClicks("AnyUp")
    frame:SetScript("OnEnter", UnitFrame_OnEnter)
    frame:SetScript("OnLeave", UnitFrame_OnLeave)

    CreateBackdrop(frame)
    LunarUI.UFCreateHealthBar(frame, unit)
    LunarUI.UFCreateNameText(frame, unit)

    return frame
end

--[[ 玩家佈局 ]]
local function PlayerLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.player
    local size = db and { width = db.width, height = db.height } or SIZES.player
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    LunarUI.UFCreatePortrait(frame, unit)
    LunarUI.UFCreatePowerBar(frame)
    LunarUI.UFCreateHealthText(frame, unit)
    LunarUI.UFCreateCastbar(frame, unit)
    LunarUI.UFCreateBuffs(frame, unit)
    -- player 不顯示等級（滿等場景無意義）
    LunarUI.UFCreateRestingIndicator(frame)
    LunarUI.UFCreateCombatIndicator(frame)
    LunarUI.UFCreateThreatIndicator(frame)
    LunarUI.UFCreateClassPower(frame)
    LunarUI.UFCreateAlternativePower(frame)
    LunarUI.UFCreateHealPrediction(frame, unit)

    return frame
end

--[[ 目標佈局 ]]
local function TargetLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.target
    local size = db and { width = db.width, height = db.height } or SIZES.target
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    LunarUI.UFCreatePortrait(frame, unit)
    LunarUI.UFCreatePowerBar(frame)
    LunarUI.UFCreateHealthText(frame, unit)
    LunarUI.UFCreateCastbar(frame, unit)

    -- 減益：定位在框架上方（顯示所有人的 debuff）
    LunarUI.UFCreateDebuffs(frame, unit)
    if frame.Debuffs then
        frame.Debuffs:ClearAllPoints()
        frame.Debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
        local debuffSize = db and db.debuffSize or 22
        frame.Debuffs:SetSize(frame:GetWidth(), debuffSize * 2 + 3)
        frame.Debuffs.initialAnchor = "BOTTOMLEFT" -- 與 SetPoint 一致
        frame.Debuffs["growth-x"] = "RIGHT"
        frame.Debuffs["growth-y"] = "UP"
    end

    LunarUI.UFCreateClassification(frame)
    LunarUI.UFCreateLevelText(frame, unit)
    LunarUI.UFCreateThreatIndicator(frame)
    LunarUI.UFCreateDeathIndicator(frame, unit)

    return frame
end

--[[ 焦點佈局 ]]
local function FocusLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.focus
    local size = db and { width = db.width, height = db.height } or SIZES.focus
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    LunarUI.UFCreatePortrait(frame, unit)
    LunarUI.UFCreatePowerBar(frame)
    LunarUI.UFCreateHealthText(frame, unit)
    LunarUI.UFCreateCastbar(frame, unit)
    LunarUI.UFCreateDebuffs(frame, unit)
    LunarUI.UFCreateLevelText(frame, unit)

    return frame
end

--[[ 寵物佈局 ]]
local function PetLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.pet
    local size = db and { width = db.width, height = db.height } or SIZES.pet
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    -- pet 不顯示能量條（框架太小，資訊價值低）
    LunarUI.UFCreateThreatIndicator(frame)

    return frame
end

--[[ 目標的目標佈局 ]]
local function TargetTargetLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.targettarget
    local size = db and { width = db.width, height = db.height } or SIZES.targettarget
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)

    return frame
end

--[[ 首領佈局 ]]
local function BossLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.boss
    local size = db and { width = db.width, height = db.height } or SIZES.boss
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    LunarUI.UFCreatePowerBar(frame)
    LunarUI.UFCreateHealthText(frame, unit)
    LunarUI.UFCreateCastbar(frame, unit)
    LunarUI.UFCreateDebuffs(frame, unit)
    LunarUI.UFCreateLevelText(frame, unit)

    return frame
end

--[[ 隊伍佈局 ]]
local function PartyLayout(frame, unit)
    local db = LunarUI.db.profile.unitframes.party
    local size = db and { width = db.width, height = db.height } or SIZES.party
    frame:SetSize(size.width, size.height)

    Shared(frame, unit)
    LunarUI.UFCreatePowerBar(frame)
    LunarUI.UFCreateHealthText(frame, unit)
    LunarUI.UFCreateDebuffs(frame, unit)
    LunarUI.UFCreateThreatIndicator(frame)
    LunarUI.UFCreateRangeIndicator(frame)
    LunarUI.UFCreateHealPrediction(frame, unit)
    LunarUI.UFCreateLeaderIndicator(frame)
    LunarUI.UFCreateGroupRoleIndicator(frame)
    LunarUI.UFCreateReadyCheckIndicator(frame)
    LunarUI.UFCreateSummonIndicator(frame)
    LunarUI.UFCreateResurrectIndicator(frame)
    LunarUI.UFCreateDeathIndicator(frame, unit)

    return frame
end

--[[ 團隊佈局工廠（支援多重 raid 尺寸） ]]
local function CreateRaidLayout(dbKey)
    return function(frame, unit)
        local db = LunarUI.db.profile.unitframes[dbKey]
        local size = db and { width = db.width, height = db.height } or SIZES.raid
        frame:SetSize(size.width, size.height)

        Shared(frame, unit)
        LunarUI.UFCreateThreatIndicator(frame)
        LunarUI.UFCreateRangeIndicator(frame)
        LunarUI.UFCreateHealPrediction(frame, unit)
        LunarUI.UFCreateLeaderIndicator(frame)
        LunarUI.UFCreateAssistantIndicator(frame)
        LunarUI.UFCreateRaidRoleIndicator(frame)
        LunarUI.UFCreateGroupRoleIndicator(frame)
        LunarUI.UFCreateReadyCheckIndicator(frame)
        LunarUI.UFCreateSummonIndicator(frame)
        LunarUI.UFCreateResurrectIndicator(frame)
        LunarUI.UFCreateRaidDebuffs(frame)
        LunarUI.UFCreateDeathIndicator(frame, unit)

        return frame
    end
end

local RaidLayout = CreateRaidLayout("raid")
local Raid1Layout = CreateRaidLayout("raid1")
local Raid2Layout = CreateRaidLayout("raid2")
local Raid3Layout = CreateRaidLayout("raid3")

--------------------------------------------------------------------------------
-- 註冊風格
--------------------------------------------------------------------------------

oUF:RegisterStyle("LunarUI", Shared)
oUF:RegisterStyle("LunarUI_Player", PlayerLayout)
oUF:RegisterStyle("LunarUI_Target", TargetLayout)
oUF:RegisterStyle("LunarUI_Focus", FocusLayout)
oUF:RegisterStyle("LunarUI_Pet", PetLayout)
oUF:RegisterStyle("LunarUI_TargetTarget", TargetTargetLayout)
oUF:RegisterStyle("LunarUI_Boss", BossLayout)
oUF:RegisterStyle("LunarUI_Party", PartyLayout)
oUF:RegisterStyle("LunarUI_Raid", RaidLayout)
oUF:RegisterStyle("LunarUI_Raid1", Raid1Layout)
oUF:RegisterStyle("LunarUI_Raid2", Raid2Layout)
oUF:RegisterStyle("LunarUI_Raid3", Raid3Layout)

oUF:SetActiveStyle("LunarUI")

--------------------------------------------------------------------------------
-- 生成函數
--------------------------------------------------------------------------------

local spawnRetries = 0
local MAX_SPAWN_RETRIES = 15 -- 最多重試 15 次（3 秒）

-- 生成個人單位框架：player, target, focus, pet, targettarget
-- 輔助函數：生成並錨定框架（減少重複）
local function SpawnAndAnchorFrame(unit, style, anchorFunc)
    oUF:SetActiveStyle(style)
    local frame = oUF:Spawn(unit, style)
    spawnedFrames[unit] = frame
    anchorFunc(frame)
    return frame
end

local function SpawnPlayerFrames(uf)
    if uf.player.enabled then
        local frame = SpawnAndAnchorFrame("player", "LunarUI_Player", function(f)
            f:SetPoint(uf.player.point, UIParent, "CENTER", uf.player.x, uf.player.y)
        end)
        -- 特殊處理：玩家框架需要延遲顯示 + 強制更新
        local gen = ufGeneration
        C_Timer.After(0.2, function()
            if ufGeneration ~= gen then
                return
            end
            if frame then
                frame:Show()
                if frame.UpdateAllElements then
                    frame:UpdateAllElements("ForceUpdate")
                end
            end
        end)
    end

    if uf.target.enabled then
        SpawnAndAnchorFrame("target", "LunarUI_Target", function(f)
            f:SetPoint(uf.target.point, UIParent, "CENTER", uf.target.x, uf.target.y)
        end)
    end

    if uf.focus and uf.focus.enabled then
        SpawnAndAnchorFrame("focus", "LunarUI_Focus", function(f)
            f:SetPoint(uf.focus.point or "CENTER", UIParent, "CENTER", uf.focus.x or -350, uf.focus.y or 200)
        end)
    end

    if uf.pet and uf.pet.enabled then
        SpawnAndAnchorFrame("pet", "LunarUI_Pet", function(f)
            -- 特殊處理：錨定到玩家框架（如可用）
            if spawnedFrames.player then
                f:SetPoint("TOPLEFT", spawnedFrames.player, "BOTTOMLEFT", 0, -8)
            else
                f:SetPoint("CENTER", UIParent, "CENTER", uf.pet.x or -200, uf.pet.y or -180)
            end
        end)
    end

    if uf.targettarget and uf.targettarget.enabled then
        SpawnAndAnchorFrame("targettarget", "LunarUI_TargetTarget", function(f)
            -- 特殊處理：錨定到目標框架（如可用）
            if spawnedFrames.target then
                f:SetPoint("TOPRIGHT", spawnedFrames.target, "BOTTOMRIGHT", 0, -28)
            else
                f:SetPoint("CENTER", UIParent, "CENTER", uf.targettarget.x or 280, uf.targettarget.y or -180)
            end
        end)
    end
end

-- 生成首領框架
local function SpawnBossFrames(uf)
    if not (uf.boss and uf.boss.enabled) then
        return
    end

    for i = 1, 8 do
        oUF:SetActiveStyle("LunarUI_Boss") -- 每次 Spawn 前設定，防止其他程式碼插入時的 active style 競態
        local boss = oUF:Spawn("boss" .. i, "LunarUI_Boss" .. i)
        boss:SetPoint("RIGHT", UIParent, "RIGHT", uf.boss.x or -50, uf.boss.y or (200 - (i - 1) * 55))
        spawnedFrames["boss" .. i] = boss
    end
end

-- 生成隊伍/團隊標頭框架
local function SpawnGroupFrames(uf)
    if uf.party and uf.party.enabled then
        oUF:SetActiveStyle("LunarUI_Party")
        local partyHeader = oUF:SpawnHeader(
            "LunarUI_Party",
            nil,
            "showParty",
            true,
            "showPlayer",
            false,
            "showSolo",
            false,
            "yOffset",
            -8,
            "oUF-initialConfigFunction",
            ([[
                self:SetHeight(%d)
                self:SetWidth(%d)
            ]]):format(uf.party.height or 35, uf.party.width or 160)
        )
        partyHeader:SetPoint(
            uf.party.point or "LEFT",
            UIParent,
            uf.party.point or "LEFT",
            uf.party.x or -500,
            uf.party.y or 0
        )
        local partyVis = "[@raid6,exists] hide; [group:party,nogroup:raid] show; hide"
        _G.RegisterStateDriver(partyHeader, "visibility", partyVis)
        savedStateDrivers[partyHeader] = partyVis
        spawnedFrames.party = partyHeader
    end

    if uf.raid and uf.raid.enabled then
        if uf.raid.autoSwitchSize then
            -- 多重 Raid 尺寸：根據團隊人數自動切換 3 個 header
            local raidPoint = uf.raid.point or "TOPLEFT"
            local raidX = uf.raid.x or 20
            local raidY = uf.raid.y or -20

            -- 各 header 的 maxColumns/unitsPerColumn 根據實際最大人數限制
            -- 避免 3 個 header 各建 40 個框架（共 120）浪費記憶體
            local raidConfigs = {
                {
                    key = "raid1",
                    style = "LunarUI_Raid1",
                    name = "LunarUI_Raid1",
                    maxCol = 2,
                    perCol = 5, -- 最多 10 人
                    vis = "[@raid11,exists] hide; [group:raid] show; hide",
                },
                {
                    key = "raid2",
                    style = "LunarUI_Raid2",
                    name = "LunarUI_Raid2",
                    maxCol = 5,
                    perCol = 5, -- 最多 25 人
                    vis = "[@raid26,exists] hide; [@raid11,exists,group:raid] show; hide",
                },
                {
                    key = "raid3",
                    style = "LunarUI_Raid3",
                    name = "LunarUI_Raid3",
                    maxCol = 8,
                    perCol = 5, -- 最多 40 人
                    vis = "[@raid26,exists,group:raid] show; hide",
                },
            }

            for _, cfg in ipairs(raidConfigs) do
                local raidDB = uf[cfg.key] or {}
                local w = raidDB.width or uf.raid.width or 80
                local h = raidDB.height or uf.raid.height or 30
                local sp = raidDB.spacing or uf.raid.spacing or 3

                oUF:SetActiveStyle(cfg.style)
                local header = oUF:SpawnHeader(
                    cfg.name,
                    nil,
                    "showRaid",
                    true,
                    "showParty",
                    false,
                    "showPlayer",
                    true,
                    "showSolo",
                    false,
                    "xOffset",
                    sp,
                    "yOffset",
                    -sp,
                    "groupFilter",
                    "1,2,3,4,5,6,7,8",
                    "groupBy",
                    "GROUP",
                    "groupingOrder",
                    "1,2,3,4,5,6,7,8",
                    "maxColumns",
                    cfg.maxCol,
                    "unitsPerColumn",
                    cfg.perCol,
                    "columnSpacing",
                    sp,
                    "columnAnchorPoint",
                    "TOP",
                    "oUF-initialConfigFunction",
                    ([[
                        self:SetHeight(%d)
                        self:SetWidth(%d)
                    ]]):format(h, w)
                )
                header:SetPoint(raidPoint, UIParent, raidPoint, raidX, raidY)
                _G.RegisterStateDriver(header, "visibility", cfg.vis)
                savedStateDrivers[header] = cfg.vis
                spawnedFrames[cfg.key] = header
            end
        else
            -- 單一 Raid header（傳統模式）
            oUF:SetActiveStyle("LunarUI_Raid")
            local raidHeader = oUF:SpawnHeader(
                "LunarUI_Raid",
                nil,
                "showRaid",
                true,
                "showParty",
                false,
                "showPlayer",
                true,
                "showSolo",
                false,
                "xOffset",
                4,
                "yOffset",
                -4,
                "groupFilter",
                "1,2,3,4,5,6,7,8",
                "groupBy",
                "GROUP",
                "groupingOrder",
                "1,2,3,4,5,6,7,8",
                "maxColumns",
                8,
                "unitsPerColumn",
                5,
                "columnSpacing",
                4,
                "columnAnchorPoint",
                "TOP",
                "oUF-initialConfigFunction",
                ([[
                    self:SetHeight(%d)
                    self:SetWidth(%d)
                ]]):format(uf.raid.height or 30, uf.raid.width or 80)
            )
            raidHeader:SetPoint(
                uf.raid.point or "TOPLEFT",
                UIParent,
                uf.raid.point or "TOPLEFT",
                uf.raid.x or 20,
                uf.raid.y or -20
            )
            local raidVis = "[group:raid] show; hide"
            _G.RegisterStateDriver(raidHeader, "visibility", raidVis)
            savedStateDrivers[raidHeader] = raidVis
            spawnedFrames.raid = raidHeader
        end
    end
end

local unitFramesSpawned = false -- oUF:Spawn 是 singleton，同一個 unit 不能 spawn 兩次
local playerEnterWorldFrame -- 前向宣告（SpawnUnitFrames re-enable 路徑需要存取）

local function SpawnUnitFrames()
    -- 已 spawn 過 → 只需重新啟用（Enable + Show + 重新註冊 StateDriver）
    if unitFramesSpawned then
        for _, frame in pairs(spawnedFrames) do
            if frame then
                -- Group headers 需重新註冊 StateDriver（CleanupUnitFrames 會 Unregister）
                local vis = savedStateDrivers[frame]
                if vis then
                    pcall(_G.RegisterStateDriver, frame, "visibility", vis)
                end
                if frame.Enable then
                    frame:Enable() -- oUF API: RegisterUnitWatch + conditional Show
                else
                    frame:Show()
                end
            end
        end
        -- 重新註冊 PLAYER_ENTERING_WORLD 強制更新路徑（CleanupUnitFrames 會清除）
        if playerEnterWorldFrame then
            playerEnterWorldFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        end
        return
    end

    -- 戰鬥中不能創建框架，等待脫離戰鬥（使用單一框架避免洩漏）
    if _G.InCombatLockdown() then
        if not combatWaitFrame then
            combatWaitFrame = CreateFrame("Frame")
        end
        combatWaitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        combatWaitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            local ok, err = pcall(SpawnUnitFrames)
            if not ok and LunarUI.Debug then
                LunarUI:Debug("SpawnUnitFrames error: " .. tostring(err))
            end
        end)
        return
    end

    if not LunarUI.db or not LunarUI.db.profile then
        spawnRetries = spawnRetries + 1
        if spawnRetries < MAX_SPAWN_RETRIES then
            local gen = ufGeneration
            C_Timer.After(0.2, function()
                if ufGeneration == gen then
                    SpawnUnitFrames()
                end
            end)
        end
        return
    end
    local uf = LunarUI.db.profile.unitframes

    LunarUI.RebuildAuraFilterCache()
    SpawnPlayerFrames(uf)
    SpawnBossFrames(uf)
    SpawnGroupFrames(uf)
end

-- 編輯模式退出時清除 focus（暴雪編輯模式會將玩家設為 focus 用於預覽，退出時不清除）
if _G.EditModeManagerFrame and _G.EditModeManagerFrame.ExitEditMode then
    hooksecurefunc(_G.EditModeManagerFrame, "ExitEditMode", function()
        if _G.UnitIsUnit("focus", "player") then
            _G.ClearFocus()
        end
    end)
end

-- 清理函數
local function CleanupUnitFrames()
    -- Soft disable：隱藏 LunarUI 框架 + 停止事件，但不銷毀 oUF singleton
    -- oUF:Spawn() 是一次性的（相同 unit 不可二次 spawn），因此：
    -- - /lunar off：frame:Disable()（UnregisterUnitWatch + Hide）
    -- - /lunar on：frame:Enable()（RegisterUnitWatch + conditional Show）
    -- - 完全回到 Blizzard 原生框架：需要 /reload
    for _, frame in pairs(spawnedFrames) do
        if frame then
            -- Group headers（party/raid）需先取消 StateDriver（否則 state driver 會覆蓋 Hide）
            if frame.GetAttribute then
                local isGroupHeader = frame:GetAttribute("showRaid") or frame:GetAttribute("showParty")
                if isGroupHeader then
                    pcall(_G.UnregisterStateDriver, frame, "visibility")
                end
            end
            if frame.Disable then
                frame:Disable() -- oUF API: UnregisterUnitWatch + Hide
            else
                frame:Hide()
            end
        end
    end

    -- 清除 PLAYER_ENTERING_WORLD 事件（不清 OnEvent script — re-enable 時只需 RegisterEvent 即可恢復）
    -- generation counter 已保護 stale callback
    if playerEnterWorldFrame then
        playerEnterWorldFrame:UnregisterAllEvents()
    end
    -- 清除戰鬥等待框架（防止 disable 後 PLAYER_REGEN_ENABLED 重新觸發 SpawnUnitFrames）
    if combatWaitFrame then
        combatWaitFrame:UnregisterAllEvents()
        combatWaitFrame:SetScript("OnEvent", nil)
    end
    spawnRetries = 0
    -- 遞增世代計數器，使所有飛行中的延遲 timer 失效
    ufGeneration = ufGeneration + 1
    -- 注意：unitFramesSpawned 保持 true（oUF:Spawn 是 singleton，re-enable 走 Enable 路徑）
end

-- 匯出
LunarUI.SpawnUnitFrames = SpawnUnitFrames
LunarUI.spawnedFrames = spawnedFrames
LunarUI.CleanupUnitFrames = CleanupUnitFrames

-- 在 PLAYER_ENTERING_WORLD 時強制更新玩家框架
-- 確保玩家資料在更新元素前可用
playerEnterWorldFrame = LunarUI.CreateEventHandler({ "PLAYER_ENTERING_WORLD" }, function(_self, _event)
    local gen = ufGeneration
    C_Timer.After(0.3, function()
        if ufGeneration ~= gen then
            return
        end
        if spawnedFrames.player then
            spawnedFrames.player:Show()
            if spawnedFrames.player.UpdateAllElements then
                spawnedFrames.player:UpdateAllElements("ForceUpdate")
            end
        end
    end)
end)

LunarUI:RegisterModule("UnitFrames", {
    onEnable = SpawnUnitFrames,
    onDisable = LunarUI.CleanupUnitFrames,
    delay = 0.1,
})
