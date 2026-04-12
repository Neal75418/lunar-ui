---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, redundant-parameter, unused-local
--[[
    LunarUI - 聊天過濾器
    頻道顏色、職業著色、網址偵測、時間戳記、短頻道名稱、表情符號、角色圖示、關鍵字警報、垃圾過濾、連結預覽
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local mathFloor = math.floor
local format = string.format
local tableInsert = table.insert

--------------------------------------------------------------------------------
-- DB 存取
--------------------------------------------------------------------------------

local function GetChatDB()
    if not LunarUI._modulesEnabled then
        return nil
    end
    return LunarUI.GetModuleDB("chat")
end

--------------------------------------------------------------------------------
-- 常數
--------------------------------------------------------------------------------

-- 改良頻道顏色
local CHANNEL_COLORS = {
    SAY = { 1.0, 1.0, 1.0 },
    YELL = { 1.0, 0.25, 0.25 },
    EMOTE = { 1.0, 0.5, 0.25 },
    WHISPER = { 1.0, 0.5, 1.0 },
    WHISPER_INFORM = { 1.0, 0.5, 1.0 },
    BN_WHISPER = { 0.0, 0.7, 1.0 },
    BN_WHISPER_INFORM = { 0.0, 0.7, 1.0 },
    PARTY = { 0.67, 0.67, 1.0 },
    PARTY_LEADER = { 0.47, 0.78, 1.0 },
    RAID = { 1.0, 0.5, 0.0 },
    RAID_LEADER = { 1.0, 0.28, 0.04 },
    RAID_WARNING = { 1.0, 0.28, 0.0 },
    INSTANCE_CHAT = { 1.0, 0.5, 0.0 },
    INSTANCE_CHAT_LEADER = { 1.0, 0.28, 0.04 },
    GUILD = { 0.25, 1.0, 0.25 },
    OFFICER = { 0.25, 0.75, 0.25 },
    CHANNEL = { 1.0, 0.75, 0.75 },
    LOOT = { 0.0, 0.67, 0.0 },
    MONEY = { 1.0, 1.0, 0.0 },
    COMBAT_XP_GAIN = { 0.43, 0.43, 1.0 },
    COMBAT_HONOR_GAIN = { 0.88, 0.67, 0.22 },
    SYSTEM = { 1.0, 1.0, 0.0 },
}

-- 短頻道名稱映射
local SHORT_CHANNEL_NAMES = {
    -- 英文
    ["General"] = "G",
    ["Trade"] = "T",
    ["LocalDefense"] = "LD",
    ["LookingForGroup"] = "LFG",
    ["WorldDefense"] = "WD",
    ["Newcomers"] = "New",
    -- 繁中
    ["綜合"] = "綜",
    ["交易"] = "交",
    ["本地防務"] = "防",
    ["尋求組隊"] = "組",
    ["世界防務"] = "世",
    ["新手"] = "新",
}

-- 頻道類型短名稱（聊天類型標頭）
local SHORT_CHANNEL_TYPES = {
    -- 英文
    ["Guild"] = "G",
    ["Party"] = "P",
    ["Party Leader"] = "PL",
    ["Raid"] = "R",
    ["Raid Leader"] = "RL",
    ["Raid Warning"] = "RW",
    ["Instance"] = "I",
    ["Instance Leader"] = "IL",
    ["Officer"] = "O",
    ["Whisper From"] = "W",
    ["Whisper To"] = "W",
    -- 繁中
    ["公會"] = "公",
    ["隊伍"] = "隊",
    ["隊伍領袖"] = "隊長",
    ["團隊"] = "團",
    ["團隊領袖"] = "團長",
    ["團隊警告"] = "團警",
    ["副本"] = "副",
    ["副本領袖"] = "副長",
    ["幹部"] = "幹",
    ["悄悄話 來自"] = "密",
    ["悄悄話 給"] = "密",
}

-- 表情符號替換表（文字 → 遊戲內建圖示）
local EMOJI_MAP = {
    [":)"] = "|TInterface\\Icons\\INV_Misc_Food_11:14:14|t",
    [":D"] = "|TInterface\\Icons\\Spell_Holy_HolyGuidance:14:14|t",
    [":("] = "|TInterface\\Icons\\Ability_Hunter_MasterMarksman:14:14|t",
    [";)"] = "|TInterface\\Icons\\INV_ValentinesCandy:14:14|t",
    [":P"] = "|TInterface\\Icons\\INV_Misc_Food_19:14:14|t",
    ["<3"] = "|TInterface\\Icons\\INV_ValentinesCandy:14:14|t",
    [":O"] = "|TInterface\\Icons\\Spell_Shadow_Skull:14:14|t",
    ["B)"] = "|TInterface\\Icons\\INV_Helm_Goggles_01:14:14|t",
}

-- Emoji 觸發字元字元類別（匹配所有可能的 2-char emoji 序列）
local EMOJI_PATTERN = "[%:%;<B][%)%(DPO3]"

-- 角色圖示材質（坦/治/傷）
local ROLE_ICONS = {
    TANK = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}

-- 垃圾訊息過濾關鍵字（不區分大小寫）
local SPAM_PATTERNS = {
    "w+w+w%.%S+%.%S+", -- www.xxx.xxx 網站
    "bit%.ly", -- 短網址
    "gold.*cheap", -- 賣金
    "cheap.*gold",
    "buy.*gold",
    "sell.*gold",
    "power%s*level", -- 代練
    "boost.*%$",
    "%$.*boost",
    "discord%.gg/", -- Discord 邀請（垃圾廣告常用）
}

-- 關鍵字警報音效
local KEYWORD_ALERT_SOUND = "Interface\\AddOns\\LunarUI\\Media\\Sounds\\keyword_alert.ogg"
local KEYWORD_ALERT_FALLBACK_SOUND = SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081

-- 可點擊網址
local URL_PATTERNS = {
    -- 完整網址（含協定）
    "(https?://[%w%.%-_~:/?#%[%]@!$&'()*+,;=%%]+)",
    -- www 網址
    "(www%.[%w%.%-_~:/?#%[%]@!$&'()*+,;=%%]+)",
    -- 電子郵件
    "([%w%.%-_]+@[%w%.%-_]+%.%w+)",
}

--------------------------------------------------------------------------------
-- 模組狀態
--------------------------------------------------------------------------------

-- C1 效能修復：角色圖示 name→unit 快取，GROUP_ROSTER_UPDATE 時標記為 dirty 重建
local roleIconNameCache = {}
local roleIconCacheDirty = true

-- H6 效能修復：時間戳記快取（同一分鐘內不重複呼叫 date()）
local _cachedTimestamp = ""
local _cachedTimestampMinute = -1

-- M8 效能修復：關鍵字列表快取（模組層，避免每則訊息建立新 table）
local keywordCheckList = {}

-- Perf A6: 預先 lower-cased keyword 陣列 + 記憶 db.keywords 的 identity 與 count。
-- 每則訊息重建 keywordCheckList + 對每個 keyword 呼叫 :lower() 是熱路徑的大浪費
-- （10+ 訊息/秒 × 5-50 keywords × 每則重建）。改成只在 db.keywords 表指針變更
-- 或長度變更時 rebuild，平時 O(1) 比對 + 零 alloc。
local keywordsLowerCache = {} -- 陣列 [1..n]，已 lower-cased
local keywordsLowerCacheRef = nil -- 記憶 db.keywords 的 table identity
local keywordsLowerCacheCount = 0
local keywordsLowerCachePlayerName = nil -- 記憶當時的 playerName（用於 cache invalidation）

-- Fix 3b: 預快取 keyword escaped pattern
local escapedKeywordCache = {}
local escapedKeywordCacheSize = 0
local KEYWORD_CACHE_MAX = 100

-- B7 效能修復：玩家名稱在 session 中不會改變，避免每則訊息呼叫 UnitName("player")
local cachedPlayerName = nil

-- 快速檢查：訊息是否包含可能的 emoji 起始字元
local EMOJI_QUICK_CHECK = "[%:%;<B]"

-- 關鍵字警報節流
local lastKeywordAlert = 0

--------------------------------------------------------------------------------
-- 頻道顏色
--------------------------------------------------------------------------------

local function ApplyChannelColors()
    local db = GetChatDB()
    if not db or not db.improvedColors then
        return
    end

    for channel, color in pairs(CHANNEL_COLORS) do
        ChangeChatColor(channel, color[1], color[2], color[3])
    end
end

--------------------------------------------------------------------------------
-- 職業著色名稱
--------------------------------------------------------------------------------

local function EnableClassColoredNames()
    local db = GetChatDB()
    if not db or not db.classColors then
        return
    end

    -- 由暴雪選項處理，我們只需啟用它
    for _, chatType in ipairs({
        "SAY",
        "EMOTE",
        "YELL",
        "WHISPER",
        "WHISPER_INFORM",
        "PARTY",
        "PARTY_LEADER",
        "RAID",
        "RAID_LEADER",
        "RAID_WARNING",
        "GUILD",
        "OFFICER",
        "INSTANCE_CHAT",
        "INSTANCE_CHAT_LEADER",
        "CHANNEL1",
        "CHANNEL2",
        "CHANNEL3",
        "CHANNEL4",
        "CHANNEL5",
    }) do
        SetChatColorNameByClass(chatType, true)
    end
end

--------------------------------------------------------------------------------
-- 網址偵測
--------------------------------------------------------------------------------

-- 格式化網址為可點擊的超連結
local function FormatURL(url)
    -- 安全性：過濾 | 字元防止 WoW 超連結控制序列注入
    -- 惡意 URL 如 "https://x.com|Hitem:1234|h[假物品]|h" 會被淨化
    local safeUrl = url:gsub("|", "")
    return format("|cff3399ff|HLunarURL:%s|h[%s]|h|r", safeUrl, safeUrl)
end

-- 過濾函數：偵測網址並轉換為可點擊連結
local function AddURLsToMessage(_self, _event, msg, ...)
    if not msg then
        return false, msg, ...
    end

    local db = GetChatDB()
    if not db or not db.detectURLs then
        return false, msg, ...
    end

    -- Perf C6: 快速 gate——95% 聊天訊息不含 URL/email，在進入 3 個 gsub loop
    -- 之前用 plain-text find 篩掉。URL_PATTERNS 目前包含 https?://、www.、
    -- 以及 email（`user@host.tld`），所以 gate 要同時涵蓋 `://` / `www.` / `@`
    -- 三種標記——漏掉 @ 會讓 non-.com 域名的 email 不再被包成超連結。
    if not (msg:find("://", 1, true) or msg:find("www.", 1, true) or msg:find("@", 1, true)) then
        return false, msg, ...
    end

    local newMsg = msg
    for _, pattern in ipairs(URL_PATTERNS) do
        newMsg = newMsg:gsub(pattern, function(url)
            -- 檢查此 URL 是否已在超連結內（避免 https://www.* 被雙重替換）
            local pos = newMsg:find(url, 1, true)
            if pos and pos > 10 then
                local before = newMsg:sub(pos - 10, pos - 1)
                if before:find("|HLunarURL:", 1, true) then
                    return url -- 已在超連結內，原樣返回
                end
            end
            return FormatURL(url)
        end)
    end

    if newMsg ~= msg then
        return false, newMsg, ...
    end

    return false, msg, ...
end

-- 處理網址超連結點擊
local function HandleURLClick(_self, link, _text, _button)
    if not link then
        return
    end

    local linkType, url = strsplit(":", link, 2)
    if linkType == "LunarURL" and url then
        -- 彈窗已在 InitializeChat 預先註冊，此處直接呼叫
        StaticPopup_Show("LUNARUI_URL_COPY", nil, nil, url)
        return true
    end
end

-- 為所有聊天事件註冊網址過濾器
local function RegisterURLFilter()
    local db = GetChatDB()
    if not db or not db.detectURLs then
        return
    end

    local chatEvents = {
        "CHAT_MSG_SAY",
        "CHAT_MSG_YELL",
        "CHAT_MSG_EMOTE",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_BN_WHISPER_INFORM",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_GUILD",
        "CHAT_MSG_OFFICER",
        "CHAT_MSG_CHANNEL",
    }

    for _, event in ipairs(chatEvents) do
        ChatFrame_AddMessageEventFilter(event, AddURLsToMessage)
    end

    -- 逐框架掛鉤超連結處理器（避免覆寫全域 ChatFrame_OnHyperlinkShow 導致 taint）
    for _, frameName in ipairs(LunarUI._chatFrames) do
        local frame = _G[frameName]
        if frame and not frame._lunarHyperlinkHooked then
            frame._lunarHyperlinkHooked = true
            frame:HookScript("OnHyperlinkClick", function(self, link, text, button)
                HandleURLClick(self, link, text, button)
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- 時間戳記
--------------------------------------------------------------------------------

local function SetupTimestamps()
    local db = GetChatDB()
    if not db or not db.showTimestamps then
        return
    end

    local fmt = db.timestampFormat or "%H:%M"

    for _, frameName in ipairs(LunarUI._chatFrames) do
        local frame = _G[frameName]
        if frame and not frame._lunarTimestampHooked then
            -- 保存原始函數用於 Cleanup 還原（只存首次值）
            if not LunarUI._chatSavedAddMessageFuncs[frameName] then
                LunarUI._chatSavedAddMessageFuncs[frameName] = frame.AddMessage
            end

            frame._lunarTimestampHooked = true
            -- 必須用直接覆寫（非 hooksecurefunc）：需在 AddMessage 前修改 msg 參數
            -- hooksecurefunc 是 post-hook，無法修改傳入參數
            -- ChatFrame 非 secure frame，不會觸發 "action blocked"
            -- 取當前值（可能已被 ShortenChannelNames 覆寫），形成 wrapper chain
            local currentAddMessage = frame.AddMessage
            frame.AddMessage = function(self, msg, ...)
                if msg and type(msg) == "string" then
                    -- H6 效能修復：同一分鐘內快取 date() 結果，避免每則訊息重複呼叫
                    local minute = mathFloor(GetTime() / 60)
                    if minute ~= _cachedTimestampMinute then
                        _cachedTimestamp = date(fmt)
                        _cachedTimestampMinute = minute
                    end
                    msg = "|cffb3b3b3[" .. _cachedTimestamp .. "]|r " .. msg
                end
                return currentAddMessage(self, msg, ...)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 短頻道名稱
--------------------------------------------------------------------------------

local function ShortenChannelNames()
    local db = GetChatDB()
    if not db or not db.shortChannelNames then
        return
    end

    -- 覆寫頻道標頭格式
    -- 數字頻道：[2. 交易] → [交]
    local origGetChannelName = _G.ChatFrame_MessageEventHandler
    if not origGetChannelName then
        return
    end

    -- 替換 CHAT_*_GET 格式字串中的頻道名稱
    -- 這些全域字串控制頻道訊息的前綴格式
    local channelTypes = {
        "CHAT_SAY_GET",
        "CHAT_YELL_GET",
        "CHAT_WHISPER_GET",
        "CHAT_WHISPER_INFORM_GET",
        "CHAT_BN_WHISPER_GET",
        "CHAT_BN_WHISPER_INFORM_GET",
        "CHAT_PARTY_GET",
        "CHAT_PARTY_LEADER_GET",
        "CHAT_RAID_GET",
        "CHAT_RAID_LEADER_GET",
        "CHAT_RAID_WARNING_GET",
        "CHAT_INSTANCE_CHAT_GET",
        "CHAT_INSTANCE_CHAT_LEADER_GET",
        "CHAT_GUILD_GET",
        "CHAT_OFFICER_GET",
        "CHAT_EMOTE_GET",
    }

    -- 替換格式字串中的括號標頭（保留原始值以便 Cleanup 還原）
    for _, chatType in ipairs(channelTypes) do
        local original = _G[chatType]
        if original and not LunarUI._chatSavedChannelFormats[chatType] then
            LunarUI._chatSavedChannelFormats[chatType] = original -- 只存首次原始值，防止 toggle off/on 時覆蓋
            -- 從格式字串中提取方括號內的頻道名稱
            for longName, shortName in pairs(SHORT_CHANNEL_TYPES) do
                if original:find(longName, 1, true) then
                    _G[chatType] =
                        original:gsub("%[" .. LunarUI.EscapePattern(longName) .. "%]", "[" .. shortName .. "]")
                    break
                end
            end
        end
    end

    -- 數字頻道（綜合、交易等）：需在 AddMessage 層面替換
    -- ChatFrame_AddMessageEventFilter 在格式化之前執行，此時 msg 尚無 [N. 頻道] 前綴
    for _, frameName in ipairs(LunarUI._chatFrames) do
        local frame = _G[frameName]
        if frame and not frame._lunarShortChannelHooked then
            -- 保存原始函數用於 Cleanup 還原（只存首次值）
            if not LunarUI._chatSavedAddMessageFuncs[frameName] then
                LunarUI._chatSavedAddMessageFuncs[frameName] = frame.AddMessage
            end

            frame._lunarShortChannelHooked = true
            -- 必須用直接覆寫（非 hooksecurefunc）：需在 AddMessage 前修改 msg 參數
            -- ChatFrame 非 secure frame，不會觸發 "action blocked"
            -- 取當前值（保持 wrapper chain），savedAddMessageFuncs 只用於 Cleanup 還原
            local currentAddMessage = frame.AddMessage
            frame.AddMessage = function(self, msg, ...)
                if msg and type(msg) == "string" then
                    -- 替換數字頻道名稱：[2. 交易] → [2.交]
                    msg = msg:gsub("%[(%d+)%.%s*(.-)%]", function(num, name)
                        local short = SHORT_CHANNEL_NAMES[name]
                        if short then
                            return "[" .. num .. "." .. short .. "]"
                        end
                        return "[" .. num .. "." .. name .. "]"
                    end)
                end
                return currentAddMessage(self, msg, ...)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 表情符號替換
--------------------------------------------------------------------------------

local function AddEmojisToMessage(_self, _event, msg, ...)
    if not msg then
        return false, msg, ...
    end

    local db = GetChatDB()
    if not db or not db.enableEmojis then
        return false, msg, ...
    end

    -- 效能優化：先快速檢查是否包含 emoji 起始字元
    if not msg:find(EMOJI_QUICK_CHECK) then
        return false, msg, ...
    end

    -- 單一 gsub + table lookup 取代逐一迴圈
    local newMsg = msg:gsub(EMOJI_PATTERN, function(m)
        return EMOJI_MAP[m] or m
    end)

    if newMsg ~= msg then
        return false, newMsg, ...
    end
    return false, msg, ...
end

--------------------------------------------------------------------------------
-- 角色圖示（坦/治/傷）
--------------------------------------------------------------------------------

local function AddRoleIconToMessage(_self, _event, msg, author, ...)
    if not msg or not author then
        return false, msg, author, ...
    end

    local db = GetChatDB()
    if not db or not db.showRoleIcons then
        return false, msg, author, ...
    end

    -- 只在隊伍/團隊頻道中顯示角色圖示
    -- 嘗試從隊伍成員中找到對應角色
    local role = nil
    local shortAuthor = Ambiguate(author, "short")

    -- C1 效能修復：使用 name→unit 快取做 O(1) 查詢，避免每則訊息最多 40 次 UnitName() API call
    -- 快取在 GROUP_ROSTER_UPDATE 時標記 dirty，於此處懶重建
    if roleIconCacheDirty then
        roleIconCacheDirty = false
        wipe(roleIconNameCache)
        local numGroupMembers = GetNumGroupMembers()
        if numGroupMembers > 0 then
            local prefix = IsInRaid() and "raid" or "party"
            local limit = IsInRaid() and numGroupMembers or (numGroupMembers - 1)
            for i = 1, limit do
                local unit = prefix .. i
                local name = UnitName(unit)
                if name then
                    roleIconNameCache[name] = unit
                end
            end
            local playerName = UnitName("player")
            if playerName then
                roleIconNameCache[playerName] = "player"
            end
        end
    end

    local unit = roleIconNameCache[shortAuthor]
    if unit then
        role = UnitGroupRolesAssigned(unit)
    end

    if role and role ~= "NONE" and ROLE_ICONS[role] then
        -- 在作者名稱前加上角色圖示
        local iconedAuthor = ROLE_ICONS[role] .. " " .. author
        return false, msg, iconedAuthor, ...
    end

    return false, msg, author, ...
end

--------------------------------------------------------------------------------
-- 關鍵字警報
--------------------------------------------------------------------------------

local function CheckKeywordAlert(_self, _event, msg, author, ...)
    if not msg then
        return false, msg, author, ...
    end

    local db = GetChatDB()
    if not db or not db.keywordAlerts then
        return false, msg, author, ...
    end

    -- 不對自己的訊息觸發（B7: 使用快取的玩家名稱，避免每則訊息呼叫 UnitName）
    if not cachedPlayerName then
        cachedPlayerName = UnitName("player")
    end
    local playerName = cachedPlayerName
    -- Security S-A9: loading screen 中 UnitName("player") 可能回 nil；不 guard
    -- 的話 playerName:lower() 在後面的 keyword cache 會 raise error 進 chat pipeline
    if not playerName then
        return false, msg, author, ...
    end
    if author then
        local shortAuthor = Ambiguate(author, "short")
        if shortAuthor == playerName then
            return false, msg, author, ...
        end
    end

    -- Perf A6: 維護兩個同步的陣列：
    --   keywordCheckList — 原始 keyword（用於後續高亮 gsub）
    --   keywordsLowerCache — 預 lower 過的 keyword（用於比對，避免每則訊息 :lower()）
    -- 只在 db.keywords table identity / 長度 / playerName 變更時 rebuild，
    -- 平時穩態下是 O(1) 比對 + 零 alloc。
    local keywords = db.keywords or {}
    local keywordsCount = #keywords
    if
        keywordsLowerCacheRef ~= keywords
        or keywordsLowerCacheCount ~= keywordsCount
        or keywordsLowerCachePlayerName ~= playerName
    then
        wipe(keywordCheckList)
        wipe(keywordsLowerCache)
        tableInsert(keywordCheckList, playerName)
        tableInsert(keywordsLowerCache, playerName:lower())
        for i = 1, keywordsCount do
            local kw = keywords[i]
            if kw and kw ~= "" then
                tableInsert(keywordCheckList, kw)
                tableInsert(keywordsLowerCache, kw:lower())
            end
        end
        keywordsLowerCacheRef = keywords
        keywordsLowerCacheCount = keywordsCount
        keywordsLowerCachePlayerName = playerName
    end

    -- Early return：沒任何可比對的 keyword（連 playerName 都空字串）就直接跳過
    -- 這些 case 在 `:lower()` 之前就應該 bail out 以避免 msg:lower() 的字串 copy。
    local lowerCount = #keywordsLowerCache
    if lowerCount == 0 then
        return false, msg, author, ...
    end

    local msgLower = msg:lower()
    local matched = false

    for i = 1, lowerCount do
        local keywordLower = keywordsLowerCache[i]
        if keywordLower ~= "" and msgLower:find(keywordLower, 1, true) then
            matched = true
            break
        end
    end

    if matched then
        local now = GetTime()
        -- 節流：至少間隔 2 秒
        if now - lastKeywordAlert >= 2 then
            lastKeywordAlert = now

            -- 播放音效
            local soundPlayed = false
            if KEYWORD_ALERT_SOUND then
                soundPlayed = PlaySoundFile(KEYWORD_ALERT_SOUND, "Master")
            end
            if not soundPlayed and KEYWORD_ALERT_FALLBACK_SOUND then
                PlaySound(KEYWORD_ALERT_FALLBACK_SOUND, "Master")
            end

            -- 閃爍聊天標籤
            local chatFrame = _G["ChatFrame1"]
            if chatFrame then
                local tab = _G[chatFrame:GetName() .. "Tab"]
                if tab and tab.glow then
                    UIFrameFlash(tab.glow, 0.25, 0.25, 2, false, 0, 0)
                end
            end

            -- 在訊息中高亮關鍵字（加底色）
            -- Fix 3b: 使用預快取的 escaped pattern
            for _, keyword in ipairs(keywordCheckList) do
                if keyword and keyword ~= "" then
                    local escaped = escapedKeywordCache[keyword]
                    if not escaped then
                        escaped = LunarUI.EscapePattern(keyword)
                        escapedKeywordCacheSize = escapedKeywordCacheSize + 1
                        if escapedKeywordCacheSize > KEYWORD_CACHE_MAX then
                            wipe(escapedKeywordCache)
                            escapedKeywordCacheSize = 1
                        end
                        escapedKeywordCache[keyword] = escaped
                    end
                    msg = msg:gsub("(" .. escaped .. ")", "|cffff8800%1|r")
                end
            end
        end
    end

    return false, msg, author, ...
end

--------------------------------------------------------------------------------
-- 垃圾訊息過濾
--------------------------------------------------------------------------------

local function FilterSpamMessage(_self, _event, msg, author, ...)
    if not msg then
        return false, msg, author, ...
    end

    local db = GetChatDB()
    if not db or not db.spamFilter then
        return false, msg, author, ...
    end

    local msgLower = msg:lower()

    for _, pattern in ipairs(SPAM_PATTERNS) do
        if msgLower:find(pattern) then
            -- 靜默丟棄垃圾訊息
            return true
        end
    end

    return false, msg, author, ...
end

--------------------------------------------------------------------------------
-- 連結懸停 Tooltip 預覽
--------------------------------------------------------------------------------

local function SetupLinkTooltipPreview()
    local db = GetChatDB()
    if not db or not db.linkTooltipPreview then
        return
    end

    for _, frameName in ipairs(LunarUI._chatFrames) do
        local frame = _G[frameName]
        if frame and not frame._lunarLinkPreviewHooked then
            frame._lunarLinkPreviewHooked = true

            frame:HookScript("OnHyperlinkEnter", function(_self, link)
                if not link then
                    return
                end

                local linkType, linkData = strsplit(":", link, 2)
                if not linkType then
                    return
                end

                GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")

                if linkType == "item" then
                    local itemID = linkData and linkData:match("^(%d+)")
                    if itemID then
                        pcall(GameTooltip.SetItemByID, GameTooltip, tonumber(itemID))
                    end
                elseif linkType == "spell" then
                    local spellID = linkData and linkData:match("^(%d+)")
                    if spellID then
                        pcall(GameTooltip.SetSpellByID, GameTooltip, tonumber(spellID))
                    end
                else
                    pcall(GameTooltip.SetHyperlink, GameTooltip, link)
                end

                GameTooltip:Show()
            end)

            frame:HookScript("OnHyperlinkLeave", function()
                GameTooltip:Hide()
            end)
        end
    end
end

--------------------------------------------------------------------------------
-- 註冊聊天增強過濾器
--------------------------------------------------------------------------------

local function RegisterChatEnhancementFilters()
    -- WoW 不提供 RemoveMessageEventFilter API，重複呼叫會累積 filter
    -- 用 flag 防止 toggle off/on 時重複註冊（filter 內部已有各自的 DB 開關判斷）
    if LunarUI._chatFiltersRegistered then
        return
    end
    LunarUI._chatFiltersRegistered = true

    local chatEvents = {
        "CHAT_MSG_SAY",
        "CHAT_MSG_YELL",
        "CHAT_MSG_EMOTE",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_BN_WHISPER_INFORM",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_GUILD",
        "CHAT_MSG_OFFICER",
        "CHAT_MSG_CHANNEL",
    }

    local db = GetChatDB()
    if not db then
        return
    end

    -- 表情符號替換
    if db.enableEmojis then
        for _, event in ipairs(chatEvents) do
            ChatFrame_AddMessageEventFilter(event, AddEmojisToMessage)
        end
    end

    -- 角色圖示（僅隊伍/團隊頻道）
    if db.showRoleIcons then
        local roleEvents = {
            "CHAT_MSG_PARTY",
            "CHAT_MSG_PARTY_LEADER",
            "CHAT_MSG_RAID",
            "CHAT_MSG_RAID_LEADER",
            "CHAT_MSG_RAID_WARNING",
            "CHAT_MSG_INSTANCE_CHAT",
            "CHAT_MSG_INSTANCE_CHAT_LEADER",
        }
        for _, event in ipairs(roleEvents) do
            ChatFrame_AddMessageEventFilter(event, AddRoleIconToMessage)
        end
    end

    -- 關鍵字警報
    if db.keywordAlerts then
        for _, event in ipairs(chatEvents) do
            ChatFrame_AddMessageEventFilter(event, CheckKeywordAlert)
        end
    end

    -- 垃圾訊息過濾（僅公開頻道）
    if db.spamFilter then
        local spamEvents = {
            "CHAT_MSG_SAY",
            "CHAT_MSG_YELL",
            "CHAT_MSG_CHANNEL",
            "CHAT_MSG_WHISPER",
        }
        for _, event in ipairs(spamEvents) do
            ChatFrame_AddMessageEventFilter(event, FilterSpamMessage)
        end
    end
end

--------------------------------------------------------------------------------
-- 清理輔助：重置此檔案擁有的快取狀態
--------------------------------------------------------------------------------

local function CleanupFilterState()
    wipe(escapedKeywordCache)
    escapedKeywordCacheSize = 0
    wipe(roleIconNameCache)
    roleIconCacheDirty = true
    wipe(keywordCheckList)
    _cachedTimestampMinute = -1
    cachedPlayerName = nil
end

--------------------------------------------------------------------------------
-- C1: 角色圖示事件處理
--------------------------------------------------------------------------------

local function OnRoleIconEvent()
    roleIconCacheDirty = true
    cachedPlayerName = UnitName("player") -- B7: 進入世界時重新取得
end

--------------------------------------------------------------------------------
-- 匯出
--------------------------------------------------------------------------------

LunarUI.ChatApplyChannelColors = ApplyChannelColors
LunarUI.ChatEnableClassColoredNames = EnableClassColoredNames
LunarUI.ChatRegisterURLFilter = RegisterURLFilter
LunarUI.ChatSetupTimestamps = SetupTimestamps
LunarUI.ChatShortenChannelNames = ShortenChannelNames
LunarUI.ChatRegisterEnhancementFilters = RegisterChatEnhancementFilters
LunarUI.ChatSetupLinkTooltipPreview = SetupLinkTooltipPreview
LunarUI.ChatCleanupFilterState = CleanupFilterState
LunarUI.ChatOnRoleIconEvent = OnRoleIconEvent
LunarUI.ChatEmojiFilter = AddEmojisToMessage
LunarUI.ChatSpamFilter = FilterSpamMessage
