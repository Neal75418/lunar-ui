---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 設定序列化與匯入匯出
    安全的設定序列化（不使用 loadstring）以及匯入/匯出 UI
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI
local C = LunarUI.Colors

--------------------------------------------------------------------------------
-- 設定匯入/匯出
--------------------------------------------------------------------------------

--[[
    簡易表格序列化（無外部依賴）
    使用遞迴深度限制防止無限遞迴
]]
local function SerializeValue(val, depth)
    depth = depth or 0
    if depth > 20 then
        -- 深度超限警告（避免無聲數據丟失）
        if LunarUI and LunarUI.Debug then
            LunarUI:Debug("Warning: Table serialization depth exceeded 20 levels")
        end
        return "nil"
    end

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
local function DeserializeStringInner(str)
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
            -- 負號後必須跟著數字，否則不是合法數字
            if pos > len or not str:sub(pos, pos):match("[%d%.]") then
                return nil, "無效數字：孤立的負號，位置 " .. startPos
            end
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
    ---@type function
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

-- Top-level pcall wrapper: 防止深層遞迴或意外錯誤導致 UI 崩潰
local function DeserializeString(str)
    local ok, result, err = pcall(DeserializeStringInner, str)
    if not ok then
        return nil, "Parse error: " .. tostring(result)
    end
    return result, err
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

    -- 輸入大小限制（100KB，防止記憶體膨脹）
    local MAX_IMPORT_SIZE = 102400
    if #importString > MAX_IMPORT_SIZE then
        return false, L["ImportTooLarge"] or "匯入字串過長（上限 100KB）"
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

    -- 合併匯入的設定檔與目前設定檔（基於 defaults 白名單，忽略未知 key）
    local defaultProfile = Engine._defaults and Engine._defaults.profile

    -- Lua table 無法儲存 nil value，因此 defaults 中 `key = nil` 的 key 在 template 裡不存在。
    -- 這裡補充這些合法的 nil-default key，確保匯入時不會被靜默丟棄。
    local nilDefaultKeys = {
        bags = { bagPosition = true, bankPosition = true },
        actionbars = {
            bar1 = { fadeEnabled = true },
            bar2 = { fadeEnabled = true },
            bar3 = { fadeEnabled = true },
            bar4 = { fadeEnabled = true },
            bar5 = { fadeEnabled = true },
            bar6 = { fadeEnabled = true },
            petbar = { fadeEnabled = true },
            stancebar = { fadeEnabled = true },
        },
    }

    local function MergeTable(target, source, template, extra)
        if not template then return end
        for k, v in pairs(source) do
            local tval = template[k]
            local extraVal = extra and extra[k]
            if tval ~= nil or extraVal then
                if type(v) == "table" and type(target[k]) == "table" and type(tval) == "table" then
                    MergeTable(target[k], v, tval, type(extraVal) == "table" and extraVal or nil)
                else
                    target[k] = v
                end
            end
        end
    end

    -- 裁剪關鍵數值至安全範圍（防止惡意或損壞的匯入字串導致 UI 異常）
    local function ClampImportedValues(profile)
        if profile.style and type(profile.style.fontSize) == "number" then
            profile.style.fontSize = math.max(8, math.min(24, profile.style.fontSize))
        end
        if profile.hud and type(profile.hud.scale) == "number" then
            profile.hud.scale = math.max(0.5, math.min(2.0, profile.hud.scale))
        end
        -- 驗證每個動作條的 buttonSize（範圍與 Options 面板一致）
        if profile.actionbars then
            for i = 1, 6 do
                local barKey = "bar" .. i
                if profile.actionbars[barKey] and type(profile.actionbars[barKey].buttonSize) == "number" then
                    profile.actionbars[barKey].buttonSize = math.max(24, math.min(48, profile.actionbars[barKey].buttonSize))
                end
            end
        end
    end

    if data.profile then
        ClampImportedValues(data.profile)
    end
    MergeTable(self.db.profile, data.profile, defaultProfile, nilDefaultKeys)

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
        LunarUI.ApplyBackdrop(frame, nil, C.bgSolid)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        -- 標題
        local title = frame:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(title, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -10)
        title:SetText("|cff8882ffLunarUI|r " .. (L["SettingsExported"] and "匯出設定" or "匯出設定"))

        -- 關閉按鈕
        local closeBtn = CreateFrame("Button", nil, frame)
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetNormalFontObject(GameFontNormal)
        closeBtn:SetText("×")
        LunarUI.SetFont(closeBtn:GetFontString(), 16, "OUTLINE")
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        -- 捲動框架
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -35)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

        -- 編輯框
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        LunarUI.SetFont(editBox, 11, "")
        editBox:SetWidth(scrollFrame:GetWidth())
        editBox:SetAutoFocus(false)
        scrollFrame:SetScrollChild(editBox)
        frame.editBox = editBox

        -- 說明
        local instructions = frame:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(instructions, 10, "")
        instructions:SetPoint("BOTTOM", 0, 10)
        instructions:SetText("Ctrl+A 全選，Ctrl+C 複製")
        instructions:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

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
        LunarUI.ApplyBackdrop(frame, nil, C.bgSolid)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        -- 標題
        local title = frame:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(title, 14, "OUTLINE")
        title:SetPoint("TOP", 0, -10)
        title:SetText("|cff8882ffLunarUI|r 匯入設定")

        -- 關閉按鈕
        local closeBtn = CreateFrame("Button", nil, frame)
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetNormalFontObject(GameFontNormal)
        closeBtn:SetText("×")
        LunarUI.SetFont(closeBtn:GetFontString(), 16, "OUTLINE")
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        -- 捲動框架
        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -35)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 70)

        -- 編輯框
        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        LunarUI.SetFont(editBox, 11, "")
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
        importBtn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])

        local btnText = importBtn:CreateFontString(nil, "OVERLAY")
        LunarUI.SetFont(btnText, 12, "OUTLINE")
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
        LunarUI.SetFont(instructions, 10, "")
        instructions:SetPoint("BOTTOM", 0, 40)
        instructions:SetText("貼上匯出字串，然後點擊匯入")
        instructions:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

        self.importFrame = frame
    end

    self.importFrame.editBox:SetText("")
    self.importFrame.editBox:SetFocus()
    self.importFrame:Show()
end
