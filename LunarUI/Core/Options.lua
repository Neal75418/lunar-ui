---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 選項模組
    角色佈局預設、設定匯入/匯出、AceConfig 選項面板
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 角色佈局預設
--------------------------------------------------------------------------------

-- 角色佈局預設值（覆蓋 unitframes 中的部分設定）
local ROLE_PRESETS = {
    DAMAGER = {
        unitframes = {
            raid = { width = 72, height = 28, spacing = 3 },
            party = { width = 140, height = 32, spacing = 5 },
        },
    },
    TANK = {
        unitframes = {
            raid = { width = 85, height = 32, spacing = 3 },
            party = { width = 155, height = 38, spacing = 5 },
        },
        nameplates = { height = 10 },
    },
    HEALER = {
        unitframes = {
            raid = { width = 90, height = 38, spacing = 2 },
            party = { width = 165, height = 42, spacing = 4 },
        },
    },
}

--[[
    偵測目前天賦角色
    @return string "DAMAGER" / "TANK" / "HEALER"
]]
function LunarUI.GetCurrentRole()
    local specIndex = GetSpecialization()
    if specIndex then
        return GetSpecializationRole(specIndex) or "DAMAGER"
    end
    return "DAMAGER"
end

--[[
    套用角色佈局預設
    @param role string "DAMAGER" / "TANK" / "HEALER"（可選，預設自動偵測）
]]
function LunarUI:ApplyRolePreset(role)
    role = role or LunarUI.GetCurrentRole()
    local preset = ROLE_PRESETS[role]
    if not preset or not self.db or not self.db.profile then return end

    -- 套用 unitframes 預設
    if preset.unitframes then
        for unit, values in pairs(preset.unitframes) do
            if self.db.profile.unitframes[unit] then
                for k, v in pairs(values) do
                    self.db.profile.unitframes[unit][k] = v
                end
            end
        end
    end

    -- 套用 nameplates 預設
    if preset.nameplates then
        for k, v in pairs(preset.nameplates) do
            self.db.profile.nameplates[k] = v
        end
    end
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

--------------------------------------------------------------------------------
-- HUD 全域縮放
--------------------------------------------------------------------------------

local HUD_FRAME_NAMES = {
    "LunarUI_PerformanceMonitor",
    "LunarUI_ClassResources",
    "LunarUI_CooldownTracker",
    "LunarUI_BuffFrame",
    "LunarUI_DebuffFrame",
}

--[[
    套用 HUD 全域縮放至所有 HUD 框架
]]
function LunarUI:ApplyHUDScale()
    local scale = self.db and self.db.profile.hud.scale or 1.0
    for _, name in ipairs(HUD_FRAME_NAMES) do
        local frame = _G[name]
        if frame then
            frame:SetScale(scale)
        end
    end
end

--------------------------------------------------------------------------------
-- AceConfig 選項面板（ESC 介面設定）
--------------------------------------------------------------------------------

local AceConfig = LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)

-- 建立選項表
local function GetOptionsTable()
    local L = Engine.L or {}

    local options = {
        type = "group",
        name = "|cff8882ffLunar|r|cffffffffUI|r",
        args = {
            -- 標題描述
            header = {
                order = 1,
                type = "description",
                name = "|cff8882ffLunarUI|r - 現代化戰鬥 UI 系統\n版本: " .. (LunarUI.version or "0.7.0") .. "\n",
                fontSize = "medium",
            },

            -- 一般設定
            general = {
                order = 10,
                type = "group",
                name = L["General"] or "一般設定",
                inline = true,
                args = {
                    enabled = {
                        order = 1,
                        type = "toggle",
                        name = L["Enable"] or "啟用插件",
                        desc = "啟用或停用 LunarUI",
                        get = function() return LunarUI.db.profile.enabled end,
                        set = function(_, val)
                            LunarUI.db.profile.enabled = val
                            if val then
                                LunarUI:Print("LunarUI 已啟用")
                            else
                                LunarUI:Print("LunarUI 已停用（需重載 UI）")
                            end
                        end,
                        width = "full",
                    },
                    debug = {
                        order = 2,
                        type = "toggle",
                        name = L["Debug"] or "除錯模式",
                        desc = "顯示除錯資訊",
                        get = function() return LunarUI.db.profile.debug end,
                        set = function(_, val) LunarUI.db.profile.debug = val end,
                    },
                },
            },

            -- 模組開關
            modules = {
                order = 30,
                type = "group",
                name = "模組設定",
                args = {
                    unitframesHeader = {
                        order = 1,
                        type = "header",
                        name = "單位框架",
                    },
                    unitframesEnabled = {
                        order = 2,
                        type = "toggle",
                        name = "啟用單位框架",
                        desc = "使用 LunarUI 自訂單位框架（需重載）",
                        get = function() return LunarUI.db.profile.unitframes.player.enabled end,
                        set = function(_, val)
                            for unit, _ in pairs(LunarUI.db.profile.unitframes) do
                                LunarUI.db.profile.unitframes[unit].enabled = val
                            end
                        end,
                        width = "full",
                    },
                    -- 單位框架光環設定
                    unitframesAurasHeader = {
                        order = 3,
                        type = "header",
                        name = L["UnitFrameAuras"] or "Unit Frame Auras",
                    },
                    ufPlayerShowBuffs = {
                        order = 4,
                        type = "toggle",
                        name = L["PlayerBuffs"] or "Player Buffs",
                        desc = L["PlayerBuffsDesc"] or "Show buffs beside player frame (requires reload)",
                        get = function() return LunarUI.db.profile.unitframes.player.showBuffs end,
                        set = function(_, val) LunarUI.db.profile.unitframes.player.showBuffs = val end,
                    },
                    ufTargetShowDebuffs = {
                        order = 5,
                        type = "toggle",
                        name = L["TargetDebuffs"] or "Target Debuffs",
                        desc = L["TargetDebuffsDesc"] or "Show debuffs above target frame (requires reload)",
                        get = function() return LunarUI.db.profile.unitframes.target.showDebuffs end,
                        set = function(_, val) LunarUI.db.profile.unitframes.target.showDebuffs = val end,
                    },
                    ufTargetOnlyPlayer = {
                        order = 6,
                        type = "toggle",
                        name = L["OnlyPlayerDebuffs"] or "Only Player Debuffs",
                        desc = L["OnlyPlayerDebuffsDesc"] or "Only show debuffs cast by you on target (requires reload)",
                        get = function() return LunarUI.db.profile.unitframes.target.onlyPlayerDebuffs end,
                        set = function(_, val) LunarUI.db.profile.unitframes.target.onlyPlayerDebuffs = val end,
                    },
                    ufAuraSize = {
                        order = 7,
                        type = "range",
                        name = L["AuraSize"] or "Aura Icon Size",
                        desc = L["AuraSizeDesc"] or "Buff/debuff icon size (requires reload)",
                        min = 16, max = 32, step = 1,
                        get = function() return LunarUI.db.profile.unitframes.target.debuffSize end,
                        set = function(_, val)
                            -- 僅套用至支援光環的單位
                            local auraUnits = {"player", "target", "focus", "party", "raid", "boss"}
                            for _, unit in ipairs(auraUnits) do
                                if LunarUI.db.profile.unitframes[unit] then
                                    LunarUI.db.profile.unitframes[unit].buffSize = val
                                    LunarUI.db.profile.unitframes[unit].debuffSize = val
                                end
                            end
                        end,
                    },
                    ufFocusShowDebuffs = {
                        order = 8,
                        type = "toggle",
                        name = L["FocusDebuffs"] or "Focus Debuffs",
                        desc = L["FocusDebuffsDesc"] or "Show debuffs above focus frame (requires reload)",
                        get = function() return LunarUI.db.profile.unitframes.focus.showDebuffs end,
                        set = function(_, val) LunarUI.db.profile.unitframes.focus.showDebuffs = val end,
                    },
                    ufPartyShowDebuffs = {
                        order = 9,
                        type = "toggle",
                        name = L["PartyDebuffs"] or "Party Debuffs",
                        desc = L["PartyDebuffsDesc"] or "Show debuffs above party frames (requires reload)",
                        get = function() return LunarUI.db.profile.unitframes.party.showDebuffs end,
                        set = function(_, val) LunarUI.db.profile.unitframes.party.showDebuffs = val end,
                    },
                    ufClassPower = {
                        order = 9.1,
                        type = "toggle",
                        name = L["ClassPower"] or "Class Power",
                        desc = L["ClassPowerDesc"] or "Show class resource bar above player frame (combo points, holy power, runes, etc.) (requires reload)",
                        get = function() return LunarUI.db.profile.unitframes.player.showClassPower end,
                        set = function(_, val) LunarUI.db.profile.unitframes.player.showClassPower = val end,
                    },
                    ufHealPrediction = {
                        order = 9.2,
                        type = "toggle",
                        name = L["HealPrediction"] or "Heal Prediction",
                        desc = L["HealPredictionDesc"] or "Show incoming heal prediction overlay on health bars (requires reload)",
                        get = function() return LunarUI.db.profile.unitframes.player.showHealPrediction end,
                        set = function(_, val)
                            -- 同步套用至所有支援的單位
                            local healUnits = {"player", "party", "raid"}
                            for _, unit in ipairs(healUnits) do
                                if LunarUI.db.profile.unitframes[unit] then
                                    LunarUI.db.profile.unitframes[unit].showHealPrediction = val
                                end
                            end
                        end,
                    },
                    nameplatesHeader = {
                        order = 10,
                        type = "header",
                        name = "名牌",
                    },
                    nameplatesEnabled = {
                        order = 11,
                        type = "toggle",
                        name = L["Nameplates"] or "啟用名牌",
                        desc = L["NameplatesDesc"] or "使用 LunarUI 自訂名牌（需重載）",
                        get = function() return LunarUI.db.profile.nameplates.enabled end,
                        set = function(_, val) LunarUI.db.profile.nameplates.enabled = val end,
                        width = "full",
                    },
                    npShowHealthText = {
                        order = 12,
                        type = "toggle",
                        name = L["NPHealthText"] or "Health Text",
                        desc = L["NPHealthTextDesc"] or "Show health text on nameplates (requires reload)",
                        get = function() return LunarUI.db.profile.nameplates.showHealthText end,
                        set = function(_, val) LunarUI.db.profile.nameplates.showHealthText = val end,
                    },
                    npHealthTextFormat = {
                        order = 13,
                        type = "select",
                        name = L["NPHealthTextFormat"] or "Health Text Format",
                        desc = L["NPHealthTextFormatDesc"] or "Format for health text display (requires reload)",
                        values = {
                            percent = L["Percent"] or "Percent",
                            current = L["Current"] or "Current",
                            both = L["Both"] or "Both",
                        },
                        get = function() return LunarUI.db.profile.nameplates.healthTextFormat end,
                        set = function(_, val) LunarUI.db.profile.nameplates.healthTextFormat = val end,
                    },
                    npEnemyShowBuffs = {
                        order = 14,
                        type = "toggle",
                        name = L["NPEnemyBuffs"] or "Enemy Buffs",
                        desc = L["NPEnemyBuffsDesc"] or "Show stealable buffs on enemy nameplates (requires reload)",
                        get = function() return LunarUI.db.profile.nameplates.enemy.showBuffs end,
                        set = function(_, val) LunarUI.db.profile.nameplates.enemy.showBuffs = val end,
                    },
                    actionbarsHeader = {
                        order = 20,
                        type = "header",
                        name = "動作條",
                    },
                    actionbarsEnabled = {
                        order = 21,
                        type = "toggle",
                        name = "啟用動作條",
                        desc = "使用 LunarUI 自訂動作條（需重載）",
                        get = function() return LunarUI.db.profile.actionbars.enabled end,
                        set = function(_, val) LunarUI.db.profile.actionbars.enabled = val end,
                        width = "full",
                    },
                    -- 每條動作條的個別設定（bar1-bar6）
                    bar1Group = {
                        order = 22,
                        type = "group",
                        name = "動作條 1（主動作條）",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1, type = "toggle", name = "啟用", desc = "需重載",
                                get = function() return LunarUI.db.profile.actionbars.bar1.enabled end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar1.enabled = val end,
                            },
                            orientation = {
                                order = 2, type = "select", name = "排列方向", desc = "需重載",
                                values = { horizontal = "水平", vertical = "垂直" },
                                get = function() return LunarUI.db.profile.actionbars.bar1.orientation or "horizontal" end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar1.orientation = val end,
                            },
                            buttons = {
                                order = 3, type = "range", name = "按鈕數量", desc = "需重載",
                                min = 1, max = 12, step = 1,
                                get = function() return LunarUI.db.profile.actionbars.bar1.buttons or 12 end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar1.buttons = val end,
                            },
                        },
                    },
                    bar2Group = {
                        order = 23,
                        type = "group",
                        name = "動作條 2",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1, type = "toggle", name = "啟用", desc = "需重載",
                                get = function() return LunarUI.db.profile.actionbars.bar2.enabled end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar2.enabled = val end,
                            },
                            orientation = {
                                order = 2, type = "select", name = "排列方向", desc = "需重載",
                                values = { horizontal = "水平", vertical = "垂直" },
                                get = function() return LunarUI.db.profile.actionbars.bar2.orientation or "horizontal" end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar2.orientation = val end,
                            },
                            buttons = {
                                order = 3, type = "range", name = "按鈕數量", desc = "需重載",
                                min = 1, max = 12, step = 1,
                                get = function() return LunarUI.db.profile.actionbars.bar2.buttons or 12 end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar2.buttons = val end,
                            },
                        },
                    },
                    bar3Group = {
                        order = 24,
                        type = "group",
                        name = "動作條 3",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1, type = "toggle", name = "啟用", desc = "需重載",
                                get = function() return LunarUI.db.profile.actionbars.bar3.enabled end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar3.enabled = val end,
                            },
                            orientation = {
                                order = 2, type = "select", name = "排列方向", desc = "需重載",
                                values = { horizontal = "水平", vertical = "垂直" },
                                get = function() return LunarUI.db.profile.actionbars.bar3.orientation or "vertical" end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar3.orientation = val end,
                            },
                            buttons = {
                                order = 3, type = "range", name = "按鈕數量", desc = "需重載",
                                min = 1, max = 12, step = 1,
                                get = function() return LunarUI.db.profile.actionbars.bar3.buttons or 12 end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar3.buttons = val end,
                            },
                        },
                    },
                    bar4Group = {
                        order = 25,
                        type = "group",
                        name = "動作條 4",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1, type = "toggle", name = "啟用", desc = "需重載",
                                get = function() return LunarUI.db.profile.actionbars.bar4.enabled end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar4.enabled = val end,
                            },
                            orientation = {
                                order = 2, type = "select", name = "排列方向", desc = "需重載",
                                values = { horizontal = "水平", vertical = "垂直" },
                                get = function() return LunarUI.db.profile.actionbars.bar4.orientation or "vertical" end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar4.orientation = val end,
                            },
                            buttons = {
                                order = 3, type = "range", name = "按鈕數量", desc = "需重載",
                                min = 1, max = 12, step = 1,
                                get = function() return LunarUI.db.profile.actionbars.bar4.buttons or 12 end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar4.buttons = val end,
                            },
                        },
                    },
                    bar5Group = {
                        order = 26,
                        type = "group",
                        name = "動作條 5",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1, type = "toggle", name = "啟用", desc = "需重載",
                                get = function() return LunarUI.db.profile.actionbars.bar5.enabled end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar5.enabled = val end,
                            },
                            orientation = {
                                order = 2, type = "select", name = "排列方向", desc = "需重載",
                                values = { horizontal = "水平", vertical = "垂直" },
                                get = function() return LunarUI.db.profile.actionbars.bar5.orientation or "horizontal" end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar5.orientation = val end,
                            },
                            buttons = {
                                order = 3, type = "range", name = "按鈕數量", desc = "需重載",
                                min = 1, max = 12, step = 1,
                                get = function() return LunarUI.db.profile.actionbars.bar5.buttons or 12 end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar5.buttons = val end,
                            },
                        },
                    },
                    bar6Group = {
                        order = 27,
                        type = "group",
                        name = "動作條 6",
                        inline = true,
                        args = {
                            enabled = {
                                order = 1, type = "toggle", name = "啟用", desc = "需重載",
                                get = function() return LunarUI.db.profile.actionbars.bar6.enabled end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar6.enabled = val end,
                            },
                            orientation = {
                                order = 2, type = "select", name = "排列方向", desc = "需重載",
                                values = { horizontal = "水平", vertical = "垂直" },
                                get = function() return LunarUI.db.profile.actionbars.bar6.orientation or "horizontal" end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar6.orientation = val end,
                            },
                            buttons = {
                                order = 3, type = "range", name = "按鈕數量", desc = "需重載",
                                min = 1, max = 12, step = 1,
                                get = function() return LunarUI.db.profile.actionbars.bar6.buttons or 12 end,
                                set = function(_, val) LunarUI.db.profile.actionbars.bar6.buttons = val end,
                            },
                        },
                    },
                    petbarEnabled = {
                        order = 28,
                        type = "toggle",
                        name = "寵物條",
                        desc = "寵物動作條（需重載）",
                        get = function() return LunarUI.db.profile.actionbars.petbar.enabled end,
                        set = function(_, val) LunarUI.db.profile.actionbars.petbar.enabled = val end,
                    },
                    stancebarEnabled = {
                        order = 29,
                        type = "toggle",
                        name = "姿態條",
                        desc = "姿態/形態動作條（需重載）",
                        get = function() return LunarUI.db.profile.actionbars.stancebar.enabled end,
                        set = function(_, val) LunarUI.db.profile.actionbars.stancebar.enabled = val end,
                    },
                    actionbarsUnlock = {
                        order = 29,
                        type = "toggle",
                        name = "解鎖動作條",
                        desc = "解鎖後可拖曳移動動作條位置",
                        get = function() return LunarUI.db.profile.actionbars.unlocked end,
                        set = function(_, val)
                            LunarUI.db.profile.actionbars.unlocked = val
                            if LunarUI.ToggleActionBarLock then
                                LunarUI:ToggleActionBarLock(not val)
                            end
                        end,
                        width = "full",
                    },
                    actionbarsButtonSize = {
                        order = 30,
                        type = "range",
                        name = "按鈕大小",
                        desc = "動作條按鈕大小（需重載）",
                        min = 24, max = 64, step = 2,
                        get = function() return LunarUI.db.profile.actionbars.buttonSize end,
                        set = function(_, val) LunarUI.db.profile.actionbars.buttonSize = val end,
                    },
                    actionbarsButtonSpacing = {
                        order = 31,
                        type = "range",
                        name = "按鈕間距",
                        desc = "按鈕之間的間距（需重載）",
                        min = 0, max = 16, step = 1,
                        get = function() return LunarUI.db.profile.actionbars.buttonSpacing end,
                        set = function(_, val) LunarUI.db.profile.actionbars.buttonSpacing = val end,
                    },
                    actionbarsAlpha = {
                        order = 32,
                        type = "range",
                        name = "透明度",
                        desc = "動作條透明度",
                        min = 0.1, max = 1.0, step = 0.1,
                        get = function() return LunarUI.db.profile.actionbars.alpha end,
                        set = function(_, val)
                            LunarUI.db.profile.actionbars.alpha = val
                            if LunarUI.actionBars then
                                for _, bar in pairs(LunarUI.actionBars) do
                                    if bar then bar:SetAlpha(val) end
                                end
                            end
                        end,
                    },
                    actionbarsShowHotkeys = {
                        order = 33,
                        type = "toggle",
                        name = "顯示快捷鍵",
                        desc = "顯示按鈕上的快捷鍵文字（需重載）",
                        get = function() return LunarUI.db.profile.actionbars.showHotkeys end,
                        set = function(_, val) LunarUI.db.profile.actionbars.showHotkeys = val end,
                    },
                    actionbarsShowMacroNames = {
                        order = 34,
                        type = "toggle",
                        name = "顯示巨集名稱",
                        desc = "顯示巨集按鈕的名稱（需重載）",
                        get = function() return LunarUI.db.profile.actionbars.showMacroNames end,
                        set = function(_, val) LunarUI.db.profile.actionbars.showMacroNames = val end,
                    },
                    actionbarsOutOfRange = {
                        order = 35,
                        type = "toggle",
                        name = L["OutOfRange"] or "Out of Range Coloring",
                        desc = L["OutOfRangeDesc"] or "Color buttons red when the target is out of range (requires reload)",
                        get = function() return LunarUI.db.profile.actionbars.outOfRangeColoring end,
                        set = function(_, val) LunarUI.db.profile.actionbars.outOfRangeColoring = val end,
                    },
                    actionbarsExtraButton = {
                        order = 36,
                        type = "toggle",
                        name = L["ExtraActionButton"] or "Extra Action Button",
                        desc = L["ExtraActionButtonDesc"] or "Style the Extra Action Button with LunarUI theme (requires reload)",
                        get = function() return LunarUI.db.profile.actionbars.extraActionButton end,
                        set = function(_, val) LunarUI.db.profile.actionbars.extraActionButton = val end,
                    },
                    actionbarsMicroBar = {
                        order = 36.1,
                        type = "toggle",
                        name = L["MicroBar"] or "Micro Bar",
                        desc = L["MicroBarDesc"] or "Rearrange system micro buttons into a compact bar (requires reload)",
                        get = function() return LunarUI.db.profile.actionbars.microBar.enabled end,
                        set = function(_, val) LunarUI.db.profile.actionbars.microBar.enabled = val end,
                    },
                    actionbarsFadeHeader = {
                        order = 37,
                        type = "header",
                        name = "淡入淡出",
                    },
                    actionbarsFadeEnabled = {
                        order = 38,
                        type = "toggle",
                        name = "啟用非戰鬥淡出",
                        desc = "非戰鬥時自動淡出動作條，滑鼠懸停時淡入",
                        get = function() return LunarUI.db.profile.actionbars.fadeEnabled end,
                        set = function(_, val)
                            LunarUI.db.profile.actionbars.fadeEnabled = val
                            if LunarUI.UpdateActionBarFade then
                                LunarUI.UpdateActionBarFade()
                            end
                        end,
                        width = "full",
                    },
                    actionbarsFadeAlpha = {
                        order = 39,
                        type = "range",
                        name = "淡出透明度",
                        desc = "非戰鬥淡出後的最低透明度",
                        min = 0, max = 0.8, step = 0.05,
                        get = function() return LunarUI.db.profile.actionbars.fadeAlpha end,
                        set = function(_, val)
                            LunarUI.db.profile.actionbars.fadeAlpha = val
                            if LunarUI.UpdateActionBarFade then
                                LunarUI.UpdateActionBarFade()
                            end
                        end,
                    },
                    actionbarsFadeDelay = {
                        order = 40,
                        type = "range",
                        name = "淡出延遲",
                        desc = "離開戰鬥 / 滑鼠離開後的淡出等待時間（秒）",
                        min = 0, max = 10, step = 0.5,
                        get = function() return LunarUI.db.profile.actionbars.fadeDelay end,
                        set = function(_, val) LunarUI.db.profile.actionbars.fadeDelay = val end,
                    },
                    minimapHeader = {
                        order = 30,
                        type = "header",
                        name = "小地圖",
                    },
                    minimapEnabled = {
                        order = 31,
                        type = "toggle",
                        name = "啟用小地圖美化",
                        get = function() return LunarUI.db.profile.minimap.enabled end,
                        set = function(_, val) LunarUI.db.profile.minimap.enabled = val end,
                    },
                    minimapSize = {
                        order = 32,
                        type = "range",
                        name = "小地圖大小",
                        min = 120, max = 280, step = 10,
                        get = function() return LunarUI.db.profile.minimap.size end,
                        set = function(_, val) LunarUI.db.profile.minimap.size = val end,
                    },
                    bagsHeader = {
                        order = 40,
                        type = "header",
                        name = "背包",
                    },
                    bagsEnabled = {
                        order = 41,
                        type = "toggle",
                        name = "啟用背包美化",
                        get = function() return LunarUI.db.profile.bags.enabled end,
                        set = function(_, val) LunarUI.db.profile.bags.enabled = val end,
                    },
                    bagsAutoSellJunk = {
                        order = 42,
                        type = "toggle",
                        name = "自動賣垃圾",
                        get = function() return LunarUI.db.profile.bags.autoSellJunk end,
                        set = function(_, val) LunarUI.db.profile.bags.autoSellJunk = val end,
                    },
                    bagsProfessionColors = {
                        order = 43,
                        type = "toggle",
                        name = "專業容器著色",
                        desc = "根據背包類型（草藥/附魔/礦石等）為格子底色著色",
                        get = function() return LunarUI.db.profile.bags.showProfessionColors end,
                        set = function(_, val) LunarUI.db.profile.bags.showProfessionColors = val end,
                    },
                    bagsUpgradeArrow = {
                        order = 44,
                        type = "toggle",
                        name = "升級箭頭",
                        desc = "物品等級高於當前裝備時顯示綠色上箭頭",
                        get = function() return LunarUI.db.profile.bags.showUpgradeArrow end,
                        set = function(_, val) LunarUI.db.profile.bags.showUpgradeArrow = val end,
                    },
                    chatHeader = {
                        order = 50,
                        type = "header",
                        name = "聊天",
                    },
                    chatEnabled = {
                        order = 51,
                        type = "toggle",
                        name = "啟用聊天美化",
                        get = function() return LunarUI.db.profile.chat.enabled end,
                        set = function(_, val) LunarUI.db.profile.chat.enabled = val end,
                    },
                    chatShortNames = {
                        order = 52,
                        type = "toggle",
                        name = "短頻道名稱",
                        desc = "縮短頻道標頭（如 [公會]→[公]、[2.交易]→[2.交]）",
                        get = function() return LunarUI.db.profile.chat.shortChannelNames end,
                        set = function(_, val) LunarUI.db.profile.chat.shortChannelNames = val end,
                    },
                    chatEmojis = {
                        order = 53,
                        type = "toggle",
                        name = "表情符號",
                        desc = "將文字表情替換為圖示（如 :) → 笑臉）",
                        get = function() return LunarUI.db.profile.chat.enableEmojis end,
                        set = function(_, val) LunarUI.db.profile.chat.enableEmojis = val end,
                    },
                    chatRoleIcons = {
                        order = 54,
                        type = "toggle",
                        name = "角色圖示",
                        desc = "在隊伍/團隊訊息前顯示坦/治/傷圖示",
                        get = function() return LunarUI.db.profile.chat.showRoleIcons end,
                        set = function(_, val) LunarUI.db.profile.chat.showRoleIcons = val end,
                    },
                    chatKeywordAlerts = {
                        order = 55,
                        type = "toggle",
                        name = "關鍵字警報",
                        desc = "當聊天中出現你的名字或自訂關鍵字時，播放音效並高亮顯示",
                        get = function() return LunarUI.db.profile.chat.keywordAlerts end,
                        set = function(_, val) LunarUI.db.profile.chat.keywordAlerts = val end,
                    },
                    chatKeywords = {
                        order = 56,
                        type = "input",
                        name = "自訂關鍵字",
                        desc = "用逗號分隔的關鍵字列表（玩家名稱會自動包含）",
                        width = "full",
                        get = function()
                            local kw = LunarUI.db.profile.chat.keywords or {}
                            return table.concat(kw, ", ")
                        end,
                        set = function(_, val)
                            local kw = {}
                            for word in val:gmatch("[^,]+") do
                                word = word:match("^%s*(.-)%s*$")  -- trim
                                if word ~= "" then
                                    table.insert(kw, word)
                                end
                            end
                            LunarUI.db.profile.chat.keywords = kw
                        end,
                    },
                    chatSpamFilter = {
                        order = 57,
                        type = "toggle",
                        name = "垃圾訊息過濾",
                        desc = "自動過濾賣金、代練等垃圾訊息",
                        get = function() return LunarUI.db.profile.chat.spamFilter end,
                        set = function(_, val) LunarUI.db.profile.chat.spamFilter = val end,
                    },
                    chatLinkPreview = {
                        order = 58,
                        type = "toggle",
                        name = "連結懸停預覽",
                        desc = "滑鼠懸停聊天中的物品/技能連結時自動顯示 Tooltip",
                        get = function() return LunarUI.db.profile.chat.linkTooltipPreview end,
                        set = function(_, val) LunarUI.db.profile.chat.linkTooltipPreview = val end,
                    },
                    chatTimestamps = {
                        order = 59,
                        type = "toggle",
                        name = L["Timestamps"] or "Timestamps",
                        desc = L["TimestampsDesc"] or "Show timestamps before chat messages (requires reload)",
                        get = function() return LunarUI.db.profile.chat.showTimestamps end,
                        set = function(_, val) LunarUI.db.profile.chat.showTimestamps = val end,
                    },
                    chatTimestampFormat = {
                        order = 59.1,
                        type = "select",
                        name = L["TimestampFormat"] or "Timestamp Format",
                        values = {
                            ["%H:%M"] = "14:30",
                            ["%H:%M:%S"] = "14:30:00",
                            ["%I:%M %p"] = "02:30 PM",
                        },
                        get = function() return LunarUI.db.profile.chat.timestampFormat end,
                        set = function(_, val) LunarUI.db.profile.chat.timestampFormat = val end,
                        disabled = function() return not LunarUI.db.profile.chat.showTimestamps end,
                    },
                    tooltipHeader = {
                        order = 60,
                        type = "header",
                        name = "滑鼠提示",
                    },
                    tooltipEnabled = {
                        order = 61,
                        type = "toggle",
                        name = "啟用滑鼠提示美化",
                        get = function() return LunarUI.db.profile.tooltip.enabled end,
                        set = function(_, val) LunarUI.db.profile.tooltip.enabled = val end,
                    },
                    tooltipItemCount = {
                        order = 62,
                        type = "toggle",
                        name = L["ItemCount"] or "Item Count",
                        desc = L["ItemCountDesc"] or "Show item count (bags/bank) in tooltips",
                        get = function() return LunarUI.db.profile.tooltip.showItemCount end,
                        set = function(_, val) LunarUI.db.profile.tooltip.showItemCount = val end,
                    },
                    databarsHeader = {
                        order = 70,
                        type = "header",
                        name = L["DataBars"] or "Data Bars",
                    },
                    databarsEnabled = {
                        order = 71,
                        type = "toggle",
                        name = L["DataBars"] or "Data Bars",
                        desc = L["DataBarsDesc"] or "Experience, reputation, and honor progress bars",
                        get = function() return LunarUI.db.profile.databars.enabled end,
                        set = function(_, val) LunarUI.db.profile.databars.enabled = val end,
                        width = "full",
                    },
                    databarsExpEnabled = {
                        order = 72,
                        type = "toggle",
                        name = L["Experience"] or "Experience",
                        desc = L["Experience"] or "Experience bar (requires reload)",
                        get = function() return LunarUI.db.profile.databars.experience.enabled end,
                        set = function(_, val) LunarUI.db.profile.databars.experience.enabled = val end,
                    },
                    databarsExpShowText = {
                        order = 73,
                        type = "toggle",
                        name = L["ShowText"] or "Show Text",
                        get = function() return LunarUI.db.profile.databars.experience.showText end,
                        set = function(_, val) LunarUI.db.profile.databars.experience.showText = val end,
                    },
                    databarsRepEnabled = {
                        order = 74,
                        type = "toggle",
                        name = L["Reputation"] or "Reputation",
                        desc = L["Reputation"] or "Reputation bar (requires reload)",
                        get = function() return LunarUI.db.profile.databars.reputation.enabled end,
                        set = function(_, val) LunarUI.db.profile.databars.reputation.enabled = val end,
                    },
                    databarsRepShowText = {
                        order = 75,
                        type = "toggle",
                        name = L["ShowText"] or "Show Text",
                        get = function() return LunarUI.db.profile.databars.reputation.showText end,
                        set = function(_, val) LunarUI.db.profile.databars.reputation.showText = val end,
                    },
                    databarsHonorEnabled = {
                        order = 76,
                        type = "toggle",
                        name = L["Honor"] or "Honor",
                        desc = L["Honor"] or "Honor bar (requires reload)",
                        get = function() return LunarUI.db.profile.databars.honor.enabled end,
                        set = function(_, val) LunarUI.db.profile.databars.honor.enabled = val end,
                    },
                    databarsWidth = {
                        order = 77,
                        type = "range",
                        name = L["BarWidth"] or "Bar Width",
                        min = 100, max = 800, step = 10,
                        get = function() return LunarUI.db.profile.databars.experience.width end,
                        set = function(_, val)
                            LunarUI.db.profile.databars.experience.width = val
                            LunarUI.db.profile.databars.reputation.width = val
                            LunarUI.db.profile.databars.honor.width = val
                        end,
                    },
                    databarsHeight = {
                        order = 78,
                        type = "range",
                        name = L["BarHeight"] or "Bar Height",
                        min = 4, max = 20, step = 1,
                        get = function() return LunarUI.db.profile.databars.experience.height end,
                        set = function(_, val)
                            LunarUI.db.profile.databars.experience.height = val
                            LunarUI.db.profile.databars.reputation.height = val
                            LunarUI.db.profile.databars.honor.height = val
                        end,
                    },
                    datatextsHeader = {
                        order = 80,
                        type = "header",
                        name = L["DataTexts"] or "Data Texts",
                    },
                    datatextsEnabled = {
                        order = 81,
                        type = "toggle",
                        name = L["DataTexts"] or "Data Texts",
                        desc = L["DataTextsDesc"] or "Configurable info panels (FPS, latency, gold, durability, etc.)",
                        get = function() return LunarUI.db.profile.datatexts.enabled end,
                        set = function(_, val) LunarUI.db.profile.datatexts.enabled = val end,
                        width = "full",
                    },
                    datatextsBottomEnabled = {
                        order = 82,
                        type = "toggle",
                        name = L["DTBottomPanel"] or "Bottom Panel",
                        desc = L["DTBottomPanelDesc"] or "Show data text panel at bottom of screen (requires reload)",
                        get = function() return LunarUI.db.profile.datatexts.panels.bottom.enabled end,
                        set = function(_, val) LunarUI.db.profile.datatexts.panels.bottom.enabled = val end,
                    },
                    datatextsBottomSlot1 = {
                        order = 83,
                        type = "select",
                        name = (L["DTSlot"] or "Slot") .. " 1",
                        values = function()
                            return {
                                fps = "FPS",
                                latency = L["Latency"] or "Latency",
                                gold = L["Gold"] or "Gold",
                                durability = L["Durability"] or "Durability",
                                bagSlots = L["BagSlots"] or "Bag Slots",
                                friends = L["Friends"] or "Friends",
                                guild = L["Guild"] or "Guild",
                                spec = L["Spec"] or "Spec",
                                clock = L["Clock"] or "Clock",
                                coords = L["Coords"] or "Coords",
                            }
                        end,
                        get = function() return LunarUI.db.profile.datatexts.panels.bottom.slots[1] end,
                        set = function(_, val) LunarUI.db.profile.datatexts.panels.bottom.slots[1] = val end,
                    },
                    datatextsBottomSlot2 = {
                        order = 84,
                        type = "select",
                        name = (L["DTSlot"] or "Slot") .. " 2",
                        values = function()
                            return {
                                fps = "FPS",
                                latency = L["Latency"] or "Latency",
                                gold = L["Gold"] or "Gold",
                                durability = L["Durability"] or "Durability",
                                bagSlots = L["BagSlots"] or "Bag Slots",
                                friends = L["Friends"] or "Friends",
                                guild = L["Guild"] or "Guild",
                                spec = L["Spec"] or "Spec",
                                clock = L["Clock"] or "Clock",
                                coords = L["Coords"] or "Coords",
                            }
                        end,
                        get = function() return LunarUI.db.profile.datatexts.panels.bottom.slots[2] end,
                        set = function(_, val) LunarUI.db.profile.datatexts.panels.bottom.slots[2] = val end,
                    },
                    datatextsBottomSlot3 = {
                        order = 85,
                        type = "select",
                        name = (L["DTSlot"] or "Slot") .. " 3",
                        values = function()
                            return {
                                fps = "FPS",
                                latency = L["Latency"] or "Latency",
                                gold = L["Gold"] or "Gold",
                                durability = L["Durability"] or "Durability",
                                bagSlots = L["BagSlots"] or "Bag Slots",
                                friends = L["Friends"] or "Friends",
                                guild = L["Guild"] or "Guild",
                                spec = L["Spec"] or "Spec",
                                clock = L["Clock"] or "Clock",
                                coords = L["Coords"] or "Coords",
                            }
                        end,
                        get = function() return LunarUI.db.profile.datatexts.panels.bottom.slots[3] end,
                        set = function(_, val) LunarUI.db.profile.datatexts.panels.bottom.slots[3] = val end,
                    },
                },
            },

            -- HUD 設定
            hud = {
                order = 40,
                type = "group",
                name = "HUD 設定",
                args = {
                    scale = {
                        order = 0,
                        type = "range",
                        name = "HUD 縮放",
                        desc = "縮放所有 HUD 元素（參考 GW2 UI 的 HUD Scale）",
                        min = 0.5, max = 2.0, step = 0.05,
                        get = function() return LunarUI.db.profile.hud.scale or 1.0 end,
                        set = function(_, val)
                            LunarUI.db.profile.hud.scale = val
                            LunarUI:ApplyHUDScale()
                        end,
                        width = "full",
                    },
                    modulesHeader = {
                        order = 0.5,
                        type = "header",
                        name = "模組開關",
                    },
                    performanceMonitor = {
                        order = 1,
                        type = "toggle",
                        name = "效能監控",
                        desc = "顯示 FPS 與延遲",
                        get = function() return LunarUI.db.profile.hud.performanceMonitor end,
                        set = function(_, val) LunarUI.db.profile.hud.performanceMonitor = val end,
                    },
                    classResources = {
                        order = 2,
                        type = "toggle",
                        name = "職業資源條",
                        desc = "顯示職業專屬資源（如聖能、連擊點數等）",
                        get = function() return LunarUI.db.profile.hud.classResources end,
                        set = function(_, val) LunarUI.db.profile.hud.classResources = val end,
                    },
                    cooldownTracker = {
                        order = 3,
                        type = "toggle",
                        name = "冷卻追蹤器",
                        desc = "追蹤重要技能冷卻",
                        get = function() return LunarUI.db.profile.hud.cooldownTracker end,
                        set = function(_, val) LunarUI.db.profile.hud.cooldownTracker = val end,
                    },
                    auraFrames = {
                        order = 4,
                        type = "toggle",
                        name = "增益/減益框架",
                        desc = "獨立的 Buff/Debuff 顯示",
                        get = function() return LunarUI.db.profile.hud.auraFrames end,
                        set = function(_, val) LunarUI.db.profile.hud.auraFrames = val end,
                    },
                },
            },

            -- 視覺風格
            style = {
                order = 50,
                type = "group",
                name = "視覺風格",
                args = {
                    theme = {
                        order = 1,
                        type = "select",
                        name = "主題",
                        values = {
                            lunar = "月光 (Lunar)",
                            parchment = "羊皮紙 (Parchment)",
                            minimal = "極簡 (Minimal)",
                        },
                        get = function() return LunarUI.db.profile.style.theme end,
                        set = function(_, val) LunarUI.db.profile.style.theme = val end,
                    },
                    borderStyle = {
                        order = 2,
                        type = "select",
                        name = "邊框風格",
                        values = {
                            ink = "水墨 (Ink)",
                            clean = "簡潔 (Clean)",
                            none = "無 (None)",
                        },
                        get = function() return LunarUI.db.profile.style.borderStyle end,
                        set = function(_, val) LunarUI.db.profile.style.borderStyle = val end,
                    },
                    fontSize = {
                        order = 3,
                        type = "range",
                        name = "字體大小",
                        min = 8, max = 18, step = 1,
                        get = function() return LunarUI.db.profile.style.fontSize end,
                        set = function(_, val) LunarUI.db.profile.style.fontSize = val end,
                    },
                },
            },

            -- 匯入/匯出
            importExport = {
                order = 60,
                type = "group",
                name = "匯入/匯出",
                args = {
                    exportBtn = {
                        order = 1,
                        type = "execute",
                        name = "匯出設定",
                        desc = "將目前設定匯出為字串",
                        func = function() LunarUI:ShowExportFrame() end,
                    },
                    importBtn = {
                        order = 2,
                        type = "execute",
                        name = "匯入設定",
                        desc = "從字串匯入設定",
                        func = function() LunarUI:ShowImportFrame() end,
                    },
                },
            },

            -- 重載按鈕
            reload = {
                order = 100,
                type = "execute",
                name = "|cffff6600重載介面|r",
                desc = "套用需要重載的變更",
                func = function() ReloadUI() end,
            },
        },
    }

    return options
end

-- 註冊選項面板
function LunarUI:SetupOptions()
    if not AceConfig or not AceConfigDialog then
        self:Print("AceConfig 未載入，無法建立設定面板")
        return
    end

    -- 註冊主選項
    AceConfig:RegisterOptionsTable("LunarUI", GetOptionsTable)
    AceConfigDialog:AddToBlizOptions("LunarUI", "LunarUI")

    -- 註冊設定檔選項（使用 AceDBOptions）
    if AceDBOptions and self.db then
        AceConfig:RegisterOptionsTable("LunarUI-Profiles", AceDBOptions:GetOptionsTable(self.db))
        AceConfigDialog:AddToBlizOptions("LunarUI-Profiles", "設定檔", "LunarUI")
    end
end

-- 注意：OpenOptions 函數已在 Commands.lua 中定義，使用 AceConfigDialog:Open
