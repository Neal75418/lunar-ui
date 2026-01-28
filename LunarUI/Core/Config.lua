---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field
--[[
    LunarUI - 設定模組（AceDB）
    資料庫預設值與設定檔管理
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 資料庫預設值
--------------------------------------------------------------------------------

local defaults = {
    profile = {
        -- 一般設定
        enabled = true,
        debug = false,

        -- 月相管理器設定
        waningDuration = 10,  -- 戰鬥結束後進入新月的秒數

        -- 標記覆蓋（每個月相）
        tokens = {
            NEW = {
                alpha = 0.40,
                scale = 0.95,
            },
            WAXING = {
                alpha = 0.65,
                scale = 0.98,
            },
            FULL = {
                alpha = 1.00,
                scale = 1.00,
            },
            WANING = {
                alpha = 0.75,
                scale = 0.98,
            },
        },

        -- 單位框架設定
        unitframes = {
            player = {
                enabled = true,
                width = 220,
                height = 45,
                x = -300,
                y = -200,
                point = "CENTER",
            },
            target = {
                enabled = true,
                width = 220,
                height = 45,
                x = 300,
                y = -200,
                point = "CENTER",
            },
            focus = {
                enabled = true,
                width = 180,
                height = 35,
                x = -450,
                y = -100,
                point = "CENTER",
            },
            pet = {
                enabled = true,
                width = 120,
                height = 25,
                x = -300,
                y = -260,
                point = "CENTER",
            },
            targettarget = {
                enabled = true,
                width = 120,
                height = 25,
                x = 450,
                y = -200,
                point = "CENTER",
            },
            party = {
                enabled = true,
                width = 150,
                height = 35,
                x = -500,
                y = 0,
                point = "LEFT",
                spacing = 5,
            },
            raid = {
                enabled = true,
                width = 80,
                height = 30,
                x = 20,
                y = -20,
                point = "TOPLEFT",
                spacing = 3,
            },
            boss = {
                enabled = true,
                width = 180,
                height = 40,
                x = -100,
                y = 300,
                point = "RIGHT",
                spacing = 50,
            },
        },

        -- 名牌設定
        nameplates = {
            enabled = false,  -- 使用暴雪預設名牌
            width = 120,
            height = 8,
            -- 敵方名牌
            enemy = {
                enabled = true,
                showHealth = true,
                showCastbar = true,
                showAuras = true,
                auraSize = 18,
                maxAuras = 5,
            },
            -- 友方名牌
            friendly = {
                enabled = true,
                showHealth = true,
                showCastbar = false,
                showAuras = false,
            },
            -- 仇恨顏色
            threat = {
                enabled = true,
            },
            -- 重要目標高亮
            highlight = {
                rare = true,
                elite = true,
                boss = true,
            },
            -- 分類圖示
            classification = {
                enabled = true,
            },
        },

        -- 動作條設定（未來擴展）
        actionbars = {
            enabled = false,  -- 使用暴雪預設動作條
            bar1 = { enabled = true, buttons = 12, buttonSize = 36 },
            bar2 = { enabled = true, buttons = 12, buttonSize = 36 },
            bar3 = { enabled = false, buttons = 12, buttonSize = 36 },
            bar4 = { enabled = false, buttons = 12, buttonSize = 36 },
            bar5 = { enabled = false, buttons = 12, buttonSize = 36 },
            petbar = { enabled = true },
            stancebar = { enabled = true },
        },

        -- 小地圖設定
        minimap = {
            enabled = true,
            size = 180,
            showCoords = true,
            showClock = true,
            organizeButtons = true,
        },

        -- 背包設定
        bags = {
            enabled = true,
            slotsPerRow = 12,
            slotSize = 37,
            autoSellJunk = true,
            showItemLevel = true,
            showQuestItems = true,
        },

        -- 聊天設定
        chat = {
            enabled = true,
            width = 400,
            height = 180,
            improvedColors = true,
            classColors = true,
            fadeTime = 120,
            detectURLs = true,  -- 啟用可點擊網址
        },

        -- 滑鼠提示設定
        tooltip = {
            enabled = true,
            anchorCursor = false,
            showItemLevel = true,
            showItemID = false,
            showSpellID = false,
            showTargetTarget = true,
        },

        -- 視覺風格
        style = {
            theme = "lunar",  -- lunar, parchment, minimal
            font = "Fonts\\FRIZQT__.TTF",
            fontSize = 12,
            borderStyle = "ink",  -- ink, clean, none
            moonlightOverlay = false,  -- 滿月時的微妙螢幕覆蓋
            phaseGlow = true,  -- 戰鬥中框架的光暈效果
            animations = true,  -- 啟用月相過渡動畫
        },
    },

    global = {
        version = nil,
    },

    char = {
        -- 角色專屬設定
    },
}

--------------------------------------------------------------------------------
-- 資料庫初始化
--------------------------------------------------------------------------------

--[[
    初始化資料庫
    從 Init.lua 的 OnInitialize 呼叫
]]
function LunarUI:InitDB()
    self.db = LibStub("AceDB-3.0"):New("LunarUIDB", defaults, "Default")

    -- 註冊設定檔變更回呼（使用正確的 Ace3 回呼語法）
    self.db:RegisterCallback("OnProfileChanged", function()
        self:OnProfileChanged()
    end)
    self.db:RegisterCallback("OnProfileCopied", function()
        self:OnProfileChanged()
    end)
    self.db:RegisterCallback("OnProfileReset", function()
        self:OnProfileChanged()
    end)

    -- 儲存版本
    self.db.global.version = self.version
end

--[[
    設定檔變更回呼
]]
function LunarUI:OnProfileChanged()
    local L = Engine.L or {}
    -- 重新整理所有 UI 元素
    self:UpdateTokens()

    -- 通知模組重新整理
    self:NotifyPhaseChange(self:GetPhase(), self:GetPhase())

    self:Print(L["ProfileChanged"] or "設定檔已變更，UI 已重新整理")
end

--------------------------------------------------------------------------------
-- 設定匯入/匯出
--------------------------------------------------------------------------------

--[[
    簡易表格序列化（無外部依賴）
    使用遞迴深度限制防止無限遞迴
]]
local function SerializeValue(val, depth)
    depth = depth or 0
    if depth > 20 then return "nil" end  -- 防止無限遞迴

    local valType = type(val)
    if valType == "nil" then
        return "nil"
    elseif valType == "boolean" then
        return val and "true" or "false"
    elseif valType == "number" then
        return tostring(val)
    elseif valType == "string" then
        -- 跳脫特殊字元
        return string.format("%q", val)
    elseif valType == "table" then
        local parts = {}
        local _isArray = #val > 0  -- 保留供未來 JSON 相容
        for k, v in pairs(val) do
            local keyStr
            if type(k) == "string" then
                keyStr = string.format("[%q]=", k)
            else
                keyStr = string.format("[%s]=", tostring(k))
            end
            table.insert(parts, keyStr .. SerializeValue(v, depth + 1))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return "nil"
    end
end

--[[
    安全的表格反序列化器（不使用 loadstring，防止程式碼注入）
    這是一個簡單的遞迴下降解析器，用於解析 Lua 表格字面值
]]
local function DeserializeString(str)
    if not str or str == "" then
        return nil, "空字串"
    end

    local pos = 1
    local len = #str

    -- 輔助函數：跳過空白
    local function skipWhitespace()
        while pos <= len and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end

    -- 輔助函數：解析字串字面值
    local function parseString()
        local quote = str:sub(pos, pos)
        if quote ~= '"' and quote ~= "'" then
            return nil, "預期字串"
        end
        pos = pos + 1
        local _startPos = pos  -- 用於除錯
        local result = ""

        while pos <= len do
            local c = str:sub(pos, pos)
            if c == "\\" and pos < len then
                -- 處理跳脫序列
                local next = str:sub(pos + 1, pos + 1)
                if next == "n" then result = result .. "\n"
                elseif next == "t" then result = result .. "\t"
                elseif next == "r" then result = result .. "\r"
                elseif next == "\\" then result = result .. "\\"
                elseif next == '"' then result = result .. '"'
                elseif next == "'" then result = result .. "'"
                else result = result .. next
                end
                pos = pos + 2
            elseif c == quote then
                pos = pos + 1
                return result
            else
                result = result .. c
                pos = pos + 1
            end
        end
        return nil, "未終結的字串"
    end

    -- 輔助函數：解析數字
    local function parseNumber()
        local startPos = pos
        if str:sub(pos, pos) == "-" then
            pos = pos + 1
        end
        while pos <= len and str:sub(pos, pos):match("[%d%.eE%+%-]") do
            pos = pos + 1
        end
        local numStr = str:sub(startPos, pos - 1)
        local num = tonumber(numStr)
        if num then
            return num
        end
        return nil, "無效數字：" .. numStr
    end

    -- 前向宣告（用於相互遞迴）
    local parseValue

    -- 輔助函數：解析表格
    local function parseTable()
        if str:sub(pos, pos) ~= "{" then
            return nil, "預期表格"
        end
        pos = pos + 1
        skipWhitespace()

        local result = {}

        while pos <= len do
            skipWhitespace()
            local c = str:sub(pos, pos)

            if c == "}" then
                pos = pos + 1
                return result
            end

            -- 解析鍵
            local key
            if c == "[" then
                pos = pos + 1
                skipWhitespace()
                local keyVal, err = parseValue()
                if err then return nil, err end
                key = keyVal
                skipWhitespace()
                if str:sub(pos, pos) ~= "]" then
                    return nil, "預期 ']'"
                end
                pos = pos + 1
                skipWhitespace()
                if str:sub(pos, pos) ~= "=" then
                    return nil, "預期 '='"
                end
                pos = pos + 1
            elseif c:match("[%a_]") then
                -- 裸識別符鍵
                local startPos = pos
                while pos <= len and str:sub(pos, pos):match("[%w_]") do
                    pos = pos + 1
                end
                key = str:sub(startPos, pos - 1)
                skipWhitespace()
                if str:sub(pos, pos) ~= "=" then
                    return nil, "預期 '='"
                end
                pos = pos + 1
            else
                return nil, "無效的表格鍵，位置：" .. pos
            end

            -- 解析值
            skipWhitespace()
            local value, err = parseValue()
            if err then return nil, err end
            result[key] = value

            skipWhitespace()
            c = str:sub(pos, pos)
            if c == "," then
                pos = pos + 1
            elseif c ~= "}" then
                return nil, "預期 ',' 或 '}'"
            end
        end

        return nil, "未終結的表格"
    end

    -- 主要值解析器
    parseValue = function()
        skipWhitespace()
        if pos > len then
            return nil, "輸入意外結束"
        end

        local c = str:sub(pos, pos)

        -- 字串
        if c == '"' or c == "'" then
            return parseString()
        end

        -- 表格
        if c == "{" then
            return parseTable()
        end

        -- 數字（包含負數）
        if c:match("[%d%-]") then
            return parseNumber()
        end

        -- 布林值/nil 關鍵字
        if str:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        end
        if str:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        end
        if str:sub(pos, pos + 2) == "nil" then
            pos = pos + 3
            return nil
        end

        return nil, "未預期的字元：" .. c
    end

    -- 解析輸入
    local result, err = parseValue()
    if err then
        return nil, err
    end

    skipWhitespace()
    if pos <= len then
        return nil, "值之後有未預期的資料"
    end

    return result
end

--------------------------------------------------------------------------------
-- 匯出/匯入函數
--------------------------------------------------------------------------------

--[[
    匯出目前設定檔為字串
    @return string 序列化的設定檔字串
]]
function LunarUI:ExportSettings()
    if not self.db or not self.db.profile then
        return nil, "資料庫未初始化"
    end

    -- 建立設定檔副本（排除函數和 userdata）
    local exportData = {
        version = self.version,
        profile = {}
    }

    -- 複製所有設定檔設定
    for k, v in pairs(self.db.profile) do
        if type(v) ~= "function" and type(v) ~= "userdata" then
            exportData.profile[k] = v
        end
    end

    -- 序列化為字串
    local serialized = SerializeValue(exportData)

    -- 加入識別標頭
    local header = "LUNARUI"
    local exportString = header .. serialized

    return exportString
end

--[[
    從字串匯入設定
    @param importString 匯出的設定字串
    @return boolean, string 成功狀態與訊息
]]
function LunarUI:ImportSettings(importString)
    local L = Engine.L or {}

    if not importString or importString == "" then
        return false, L["InvalidSettings"] or "未提供匯入字串"
    end

    -- 檢查標頭
    local header = "LUNARUI"
    if not importString:find("^" .. header) then
        return false, L["InvalidSettings"] or "無效的匯入字串（缺少標頭）"
    end

    -- 移除標頭
    local dataString = importString:sub(#header + 1)

    -- 反序列化
    local data, err = DeserializeString(dataString)
    if not data then
        return false, "解析失敗：" .. (err or "未知錯誤")
    end

    -- 驗證結構
    if type(data) ~= "table" or not data.profile then
        return false, L["InvalidSettings"] or "無效的資料結構"
    end

    -- 套用匯入的設定
    if not self.db or not self.db.profile then
        return false, "資料庫未初始化"
    end

    -- 合併匯入的設定檔與目前設定檔
    local function MergeTable(target, source)
        for k, v in pairs(source) do
            if type(v) == "table" and type(target[k]) == "table" then
                MergeTable(target[k], v)
            else
                target[k] = v
            end
        end
    end

    MergeTable(self.db.profile, data.profile)

    -- 觸發設定檔變更以重新整理 UI
    self:OnProfileChanged()

    return true, (L["SettingsImported"] or "設定匯入成功") .. "（版本：" .. (data.version or "未知") .. "）"
end

--------------------------------------------------------------------------------
-- 匯出/匯入介面
--------------------------------------------------------------------------------

--[[
    顯示匯出視窗（透過 EditBox 複製到剪貼簿）
]]
function LunarUI:ShowExportFrame()
    local L = Engine.L or {}
    local exportString, err = self:ExportSettings()
    if not exportString then
        self:Print("匯出失敗：" .. (err or "未知"))
        return
    end

    -- 建立或顯示匯出視窗
    if not self.exportFrame then
        local frame = CreateFrame("Frame", "LunarUI_ExportFrame", UIParent, "BackdropTemplate")
        frame:SetSize(500, 200)
        frame:SetPoint("CENTER")
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        frame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        -- 標題
        local title = frame:CreateFontString(nil, "OVERLAY")
        title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -10)
        title:SetText("|cff8882ffLunarUI|r " .. (L["SettingsExported"] and "匯出設定" or "匯出設定"))

        -- 關閉按鈕
        local closeBtn = CreateFrame("Button", nil, frame)
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetNormalFontObject(GameFontNormal)
        closeBtn:SetText("×")
        closeBtn:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        -- 捲動框架
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -35)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

        -- 編輯框
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFont(STANDARD_TEXT_FONT, 11, "")
        editBox:SetWidth(scrollFrame:GetWidth())
        editBox:SetAutoFocus(false)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox

        -- 說明
        local instructions = frame:CreateFontString(nil, "OVERLAY")
        instructions:SetFont(STANDARD_TEXT_FONT, 10, "")
        instructions:SetPoint("BOTTOM", 0, 10)
        instructions:SetText("Ctrl+A 全選，Ctrl+C 複製")
        instructions:SetTextColor(0.6, 0.6, 0.6)

        self.exportFrame = frame
    end

    self.exportFrame.editBox:SetText(exportString)
    self.exportFrame.editBox:HighlightText()
    self.exportFrame.editBox:SetFocus()
    self.exportFrame:Show()
end

--[[
    顯示匯入視窗
]]
function LunarUI:ShowImportFrame()
    -- 建立或顯示匯入視窗
    if not self.importFrame then
        local frame = CreateFrame("Frame", "LunarUI_ImportFrame", UIParent, "BackdropTemplate")
        frame:SetSize(500, 200)
        frame:SetPoint("CENTER")
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        frame:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        -- 標題
        local title = frame:CreateFontString(nil, "OVERLAY")
        title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -10)
        title:SetText("|cff8882ffLunarUI|r 匯入設定")

        -- 關閉按鈕
        local closeBtn = CreateFrame("Button", nil, frame)
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetNormalFontObject(GameFontNormal)
        closeBtn:SetText("×")
        closeBtn:GetFontString():SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        -- 捲動框架
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -35)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 70)

        -- 編輯框
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFont(STANDARD_TEXT_FONT, 11, "")
        editBox:SetWidth(scrollFrame:GetWidth())
        editBox:SetAutoFocus(false)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox

        -- 匯入按鈕
        local importBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        importBtn:SetSize(100, 25)
        importBtn:SetPoint("BOTTOM", 0, 10)
        importBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        importBtn:SetBackdropColor(0.2, 0.4, 0.2, 1)
        importBtn:SetBackdropBorderColor(0.15, 0.12, 0.08, 1)

        local btnText = importBtn:CreateFontString(nil, "OVERLAY")
        btnText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        btnText:SetPoint("CENTER")
        btnText:SetText("匯入")

        importBtn:SetScript("OnClick", function()
            local importString = frame.editBox:GetText()
            local success, msg = LunarUI:ImportSettings(importString)
            if success then
                LunarUI:Print("|cff00ff00" .. msg .. "|r")
                frame:Hide()
            else
                LunarUI:Print("|cffff0000" .. msg .. "|r")
            end
        end)

        importBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.5, 0.3, 1)
        end)
        importBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.4, 0.2, 1)
        end)

        -- 說明
        local instructions = frame:CreateFontString(nil, "OVERLAY")
        instructions:SetFont(STANDARD_TEXT_FONT, 10, "")
        instructions:SetPoint("BOTTOM", 0, 40)
        instructions:SetText("貼上匯出字串，然後點擊匯入")
        instructions:SetTextColor(0.6, 0.6, 0.6)

        self.importFrame = frame
    end

    self.importFrame.editBox:SetText("")
    self.importFrame.editBox:SetFocus()
    self.importFrame:Show()
end
