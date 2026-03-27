---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch, unnecessary-if, missing-parameter
--[[
    LunarUI - 光環系統
    光環過濾、排序、圖示樣式化、增益/減益/團隊減益框架建構
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local mathHuge = math.huge

local C = LunarUI.Colors
local UNITFRAME_DEBUFF_COLORS = LunarUI.DEBUFF_TYPE_COLORS or _G.DebuffTypeColor or {}

--------------------------------------------------------------------------------
-- 光環白名單/黑名單快取
--------------------------------------------------------------------------------

local auraWhitelistCache = {}
local auraBlacklistCache = {}

--[[ AuraFilter DB 設定快取（避免高頻 DB 查詢）]]
local auraFilterDBCache = {} -- [unitKey] = { onlyPlayerDebuffs = bool }
local auraFilterGlobalCache = nil -- 全域過濾器設定快取
-- A2 效能修復：快取 unit → unitKey 的 gsub 結果（AuraFilter 每次 aura 都呼叫，結果恆定）
local unitKeyCache = {} -- [unit] = unitKey (e.g. "party1" → "party")

local function RebuildAuraFilterCache()
    wipe(auraWhitelistCache)
    wipe(auraBlacklistCache)
    wipe(auraFilterDBCache) -- 清除 DB 設定快取，強制重新讀取
    wipe(unitKeyCache) -- 清除 unit → unitKey 快取（設定變更時）
    auraFilterGlobalCache = nil
    local db = LunarUI.db and LunarUI.db.profile
    if not db then
        return
    end

    -- 將逗號分隔的 spell ID 字串轉為查找表
    if db.auraWhitelist and db.auraWhitelist ~= "" then
        for id in db.auraWhitelist:gmatch("(%d+)") do
            auraWhitelistCache[tonumber(id)] = true
        end
    end
    if db.auraBlacklist and db.auraBlacklist ~= "" then
        for id in db.auraBlacklist:gmatch("(%d+)") do
            auraBlacklistCache[tonumber(id)] = true
        end
    end
end

-- 公開方法供 Options 呼叫
LunarUI.RebuildAuraFilterCache = RebuildAuraFilterCache

-- 取得全域過濾器設定（快取）
local function GetAuraFilterSettings()
    if not auraFilterGlobalCache then
        local db = LunarUI.db and LunarUI.db.profile
        local af = db and db.auraFilters or {}
        auraFilterGlobalCache = {
            hidePassive = af.hidePassive ~= false,
            showStealable = af.showStealable ~= false,
        }
    end
    return auraFilterGlobalCache
end

--------------------------------------------------------------------------------
-- 光環過濾器
--------------------------------------------------------------------------------

--[[ 光環過濾器：根據 DB 設定過濾 ]]
local function AuraFilter(_element, unit, data)
    -- 標準化單位 key（boss1 → boss, party1 → party）
    -- A2 效能修復：結果恆定，memoize 避免每次 aura 都建立字串
    local unitKey = unitKeyCache[unit]
    if not unitKey then
        unitKey = unit:gsub("%d+$", "")
        unitKeyCache[unit] = unitKey
    end

    -- 使用快取避免高頻 DB 查詢
    local cachedSettings = auraFilterDBCache[unitKey]
    if not cachedSettings then
        local ufAll = LunarUI.GetModuleDB("unitframes")
        local ufDB = ufAll and ufAll[unitKey]
        if not ufDB then
            return true
        end
        cachedSettings = {
            onlyPlayerDebuffs = ufDB.onlyPlayerDebuffs,
        }
        auraFilterDBCache[unitKey] = cachedSettings
    end

    local filters = GetAuraFilterSettings()

    -- data 的欄位可能是 WoW secret value，用單一 pcall 保護所有存取
    -- 內部 closure 回傳 true = 過濾掉（隱藏），false = 保留（顯示）
    -- 外部再轉換為 oUF AuraFilter 慣例（true = 顯示，false = 隱藏）
    local ok, shouldFilter = pcall(function()
        local spellId = data.spellId

        -- 黑名單：永遠不顯示
        if spellId and auraBlacklistCache[spellId] then
            return true
        end

        -- 白名單：永遠顯示（跳過其他過濾規則）
        if spellId and auraWhitelistCache[spellId] then
            return false
        end

        -- 可竊取 buff 在敵方目標上永遠顯示
        if filters.showStealable and data.isStealable and UnitIsEnemy("player", unit) then
            return false
        end

        -- 僅顯示玩家施放的 debuff
        if cachedSettings.onlyPlayerDebuffs and data.isHarmfulAura and not data.isPlayerAura then
            return true
        end

        -- 隱藏被動效果（持續超過 5 分鐘的 buff 和永久 buff）
        if filters.hidePassive and not data.isHarmfulAura and data.duration then
            if data.duration == 0 or data.duration > 300 then
                return true
            end
        end

        return false
    end)

    -- pcall 失敗（secret value 異常）則預設顯示
    if ok and shouldFilter then
        return false
    end

    return true
end

LunarUI.AuraFilter = AuraFilter

--------------------------------------------------------------------------------
-- 光環排序
--------------------------------------------------------------------------------

-- taint 安全工具：用 tonumber/tostring 斷開 WoW 12.0 aura 資料的 taint 鏈
local function SanitizeNumber(val)
    if val == nil then
        return 0
    end
    return tonumber(tostring(val)) or 0
end

local function SanitizeString(val)
    if val == nil then
        return ""
    end
    return tostring(val)
end

local function GetAuraSortFunction()
    -- 驗證當前 method 是否已知，未知時返回 nil（告知 oUF 不排序）
    local db = LunarUI.db and LunarUI.db.profile
    local af = db and db.auraFilters or {}
    local method = af.sortMethod or "time"
    if method ~= "time" and method ~= "duration" and method ~= "name" and method ~= "player" then
        return nil
    end

    -- C3 效能修復：method/reverse 在 GetAuraSortFunction 呼叫時讀取一次並捕獲為 upvalue
    -- 避免每次 comparator 呼叫（每次排序 ~30 次）都重複做 3 層 DB table lookup
    -- 已知限制：排序設定變更後需重新呼叫 GetAuraSortFunction() 更新 SortBuffs/SortDebuffs
    -- 目前選項面板僅呼叫 RebuildAuraFilterCache()，不會更新已存在框架的排序函式
    -- 需要 /reload 才能生效。TODO: 未來可在選項回調中遍歷 oUF 框架更新排序函式
    local reverse = af.sortReverse or false
    return function(a, b)
        if method == "time" then
            -- 按剩餘時間排序（快到期的在前）
            local aTime = SanitizeNumber(a.expirationTime)
            local bTime = SanitizeNumber(b.expirationTime)
            if aTime == 0 then
                aTime = mathHuge
            end
            if bTime == 0 then
                bTime = mathHuge
            end
            if reverse then
                return aTime > bTime
            end
            return aTime < bTime
        elseif method == "duration" then
            -- 按總持續時間排序
            local aDur = SanitizeNumber(a.duration)
            local bDur = SanitizeNumber(b.duration)
            if reverse then
                return aDur > bDur
            end
            return aDur < bDur
        elseif method == "name" then
            -- 按名稱字母排序
            local aName = SanitizeString(a.name)
            local bName = SanitizeString(b.name)
            if reverse then
                return aName > bName
            end
            return aName < bName
        elseif method == "player" then
            -- 玩家施放的在前；同類別按剩餘時間排序（reverse 同樣影響 tie-breaking）
            local aPlayer = (a.isPlayerAura == true) and 1 or 0
            local bPlayer = (b.isPlayerAura == true) and 1 or 0
            if aPlayer ~= bPlayer then
                if reverse then
                    return aPlayer < bPlayer
                end
                return aPlayer > bPlayer
            end
            local aTime = SanitizeNumber(a.expirationTime)
            local bTime = SanitizeNumber(b.expirationTime)
            if reverse then
                return aTime > bTime
            end
            return aTime < bTime
        end
    end
end

-- 公開排序函數供 oUF 使用
LunarUI.GetAuraSortFunction = GetAuraSortFunction

--------------------------------------------------------------------------------
-- 光環圖示樣式化鉤子
--------------------------------------------------------------------------------

local function PostCreateAuraIcon(_self, button)
    LunarUI.StyleAuraButton(button)

    if button.SetBackdropColor then
        button:SetBackdropColor(C.bgOverlay[1], C.bgOverlay[2], C.bgOverlay[3], C.bgOverlay[4])
        button:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end

    button.Icon:SetDrawLayer("ARTWORK")
    button.Count:SetPoint("BOTTOMRIGHT", 2, -2)

    if button.Cooldown then
        button.Cooldown:SetDrawEdge(false)
        button.Cooldown:SetHideCountdownNumbers(true)
    end
end

--[[ 減益更新鉤子：根據類型著色邊框 ]]
local function PostUpdateDebuffIcon(_self, button, _unit, data, _position)
    -- WoW 12.0: data.isHarmfulAura 在戰鬥中可能為 secret boolean，pcall 保護
    local ok, isHarmful = pcall(function()
        return data.isHarmfulAura == true
    end)
    if ok and isHarmful then
        -- WoW DebuffTypeColor 預設 key 為 ""（非 "none"）
        local color = UNITFRAME_DEBUFF_COLORS[""] or UNITFRAME_DEBUFF_COLORS["none"]
        if color then
            button:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        else
            button:SetBackdropBorderColor(0.8, 0, 0, 1) -- fallback: 紅色減益邊框
        end
    else
        button:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end
end

--------------------------------------------------------------------------------
-- 光環框架建構
--------------------------------------------------------------------------------

--[[ 光環框架共用建構 ]]
local function CreateAuraFrame(frame, unit, isDebuff)
    local unitKey = unit and unit:gsub("%d+$", "") or (isDebuff and "unknown" or "player")
    local ufAll = LunarUI.GetModuleDB("unitframes")
    local ufDB = ufAll and ufAll[unitKey]

    -- 檢查是否啟用
    if isDebuff then
        if ufDB and not ufDB.showDebuffs then
            return
        end
    else
        if ufDB and not ufDB.showBuffs then
            return
        end
    end

    local sizeKey = isDebuff and "debuffSize" or "buffSize"
    local numKey = isDebuff and "maxDebuffs" or "maxBuffs"
    local defaultSize = isDebuff and 18 or 22
    local defaultNum = isDebuff and 4 or 16

    local auraSize = ufDB and ufDB[sizeKey] or defaultSize
    local auraNum = ufDB and ufDB[numKey] or defaultNum

    local auras = CreateFrame("Frame", nil, frame)
    auras.size = auraSize
    auras.spacing = isDebuff and 2 or 3
    auras.num = auraNum
    auras.FilterAura = AuraFilter
    auras.PostCreateButton = PostCreateAuraIcon
    auras.SortBuffs = GetAuraSortFunction()
    auras.SortDebuffs = GetAuraSortFunction()

    if isDebuff then
        auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
        auras:SetSize(frame:GetWidth(), auraSize)
        auras.initialAnchor = "BOTTOMLEFT"
        auras["growth-x"] = "RIGHT"
        auras["growth-y"] = "UP"
        auras.PostUpdateButton = PostUpdateDebuffIcon
    else
        -- 增益使用預設邊框色
        auras.PostUpdateButton = function(_self, button, _unit, _data, _position)
            button:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
        end

        -- 定位依單位類型
        if unitKey == "player" then
            auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
            auras:SetSize(frame:GetWidth() > 0 and frame:GetWidth() or 220, auraSize * 2 + 3)
            auras.initialAnchor = "BOTTOMLEFT"
            auras["growth-x"] = "RIGHT"
            auras["growth-y"] = "UP"
        elseif unitKey == "target" or unitKey == "focus" then
            auras:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
            auras:SetSize(180, auraSize * 2 + 3)
            auras.initialAnchor = "TOPLEFT"
            auras["growth-x"] = "RIGHT"
            auras["growth-y"] = "DOWN"
        else
            auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
            auras:SetSize(frame:GetWidth() > 0 and frame:GetWidth() or 160, auraSize)
            auras.initialAnchor = "BOTTOMLEFT"
            auras["growth-x"] = "RIGHT"
            auras["growth-y"] = "UP"
        end
    end

    return auras
end

--[[ 增益框架 ]]
local function CreateBuffs(frame, unit)
    local buffs = CreateAuraFrame(frame, unit, false)
    if not buffs then
        return
    end
    frame.Buffs = buffs
    return buffs
end

--[[ 僅減益（用於隊伍/團隊/目標/焦點/首領） ]]
local function CreateDebuffs(frame, unit)
    local debuffs = CreateAuraFrame(frame, unit, true)
    if not debuffs then
        return
    end
    frame.Debuffs = debuffs
    return debuffs
end

--[[ 團隊減益（特殊佈局：較小、居中） ]]
local function CreateRaidDebuffs(frame, unitKey)
    local ufAll = LunarUI.GetModuleDB("unitframes")
    -- 優先使用 per-tier config（raid1/raid2/raid3），退回到 raid 基礎設定
    local raidDB = ufAll and (ufAll[unitKey] or ufAll.raid)
    if not raidDB or raidDB.showDebuffs == false then
        return
    end

    local debuffSize = raidDB.debuffSize or 16
    local maxDebuffs = raidDB.maxDebuffs or 2

    local debuffs = CreateFrame("Frame", nil, frame)
    debuffs:SetPoint("CENTER", frame, "CENTER", 0, 0)
    debuffs:SetSize(debuffSize * maxDebuffs + 2, debuffSize)
    debuffs.size = debuffSize
    debuffs.spacing = 2
    debuffs.num = maxDebuffs
    debuffs.initialAnchor = "CENTER"
    debuffs["growth-x"] = "RIGHT"
    debuffs.FilterAura = AuraFilter
    debuffs.PostCreateButton = PostCreateAuraIcon
    debuffs.PostUpdateButton = PostUpdateDebuffIcon
    frame.Debuffs = debuffs
    return debuffs
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.UFCreateBuffs = CreateBuffs
LunarUI.UFCreateDebuffs = CreateDebuffs
LunarUI.UFCreateRaidDebuffs = CreateRaidDebuffs
