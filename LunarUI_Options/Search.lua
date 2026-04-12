---@diagnostic disable: undefined-field, inject-field
-- diagnostic disable 原因：CreateFrame("EditBox", ...) stub 回傳 Frame 而非
-- EditBox 子型別，SetAutoFocus/SetText/ClearFocus 誤報；frame.text = ... 形式
-- 的欄位注入也會誤報 inject-field。
--[[
    LunarUI Options - Search (索引 + UI)
    Extracted from Options.lua in Phase 3 Wave 5.

    Exposes Private.search.* for Options.lua to consume:
      SafeGetField(field)                    — string|function → string
      BuildSearchIndex(args, breadcrumbs, groupPath) → flat list of entries
      FilterSearchResults(query)             → filtered list (uses module-local index)
      CreateSearchUI(dialogFrame, options, AceConfigDialog)
      SetSearchIndex(idx)                    — test hook, injects a custom index

    Module-local state:
      searchIndex — rebuilt from options.args each time the panel opens
      searchFrame — EditBox, reused across panel re-opens when parent matches
      searchTimer — C_Timer for OnTextChanged throttling
]]

local _, Private = ...
Private = Private or {}
Private.search = Private.search or {}

local min = math.min

local searchIndex = nil
local searchFrame = nil
local searchTimer = nil

--- 安全取得可能為函數的 AceConfig 欄位值
--- AceConfig 的 name/desc 回呼期望 (info) 參數，此處無法提供，以 pcall 保護
local function SafeGetField(field)
    if type(field) == "function" then
        local ok, val = pcall(field)
        return ok and type(val) == "string" and val or ""
    end
    return type(field) == "string" and field or ""
end

--- 淺拷貝 table 陣列部分
local function CopyPath(src)
    local copy = {}
    for i = 1, #src do
        copy[i] = src[i]
    end
    return copy
end

--- 遞迴走訪 options.args 表，建構搜尋索引
--- @param args table      AceConfig args 表
--- @param breadcrumbs string 當前的麵包屑路徑（"General > Debug"）
--- @param groupPath table   當前的 group key 路徑（{"general"}）
local function BuildSearchIndex(args, breadcrumbs, groupPath)
    local results = {}
    if not args then
        return results
    end

    for key, entry in pairs(args) do
        if type(entry) == "table" and entry.type then
            local name = SafeGetField(entry.name)
            local desc = SafeGetField(entry.desc)

            -- 去除 WoW 色碼（|cXXXXXXXX ... |r）
            local cleanName = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local cleanDesc = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

            if entry.type == "group" then
                local newCrumbs = breadcrumbs ~= "" and (breadcrumbs .. " > " .. cleanName) or cleanName
                local newPath = CopyPath(groupPath)
                newPath[#newPath + 1] = key

                results[#results + 1] = {
                    name = cleanName,
                    desc = cleanDesc,
                    breadcrumbs = newCrumbs,
                    path = newPath,
                    isGroup = true,
                }

                -- 遞迴進入子 args
                if type(entry.args) == "table" then
                    local subResults = BuildSearchIndex(entry.args, newCrumbs, newPath)
                    for _, r in ipairs(subResults) do
                        results[#results + 1] = r
                    end
                end
            elseif entry.type ~= "header" and entry.type ~= "description" then
                -- 葉節點設定項（toggle, range, select, execute 等）
                local crumb = breadcrumbs ~= "" and (breadcrumbs .. " > " .. cleanName) or cleanName
                results[#results + 1] = {
                    name = cleanName,
                    desc = cleanDesc,
                    breadcrumbs = crumb,
                    path = CopyPath(groupPath), -- 導航到父 group（淺拷貝防止共用參照）
                    isGroup = false,
                }
            end
        end
    end

    return results
end

--- 重建搜尋索引（從給定的 options table 讀取 args）
local function RebuildSearchIndex(options)
    searchIndex = BuildSearchIndex(options.args, "", {})
end

--- 模糊匹配過濾搜尋結果
--- @param query string 使用者輸入的搜尋文字
--- @return table 過濾後的搜尋結果
local function FilterSearchResults(query)
    if not searchIndex then
        return {}
    end

    if not query or query == "" then
        return {}
    end

    query = query:lower()
    local matches = {}

    for _, entry in ipairs(searchIndex) do
        local nameMatch = entry.name:lower():find(query, 1, true)
        local descMatch = entry.desc:lower():find(query, 1, true)
        local crumbMatch = entry.breadcrumbs:lower():find(query, 1, true)

        if nameMatch or descMatch or crumbMatch then
            -- 優先順序：名稱匹配 > 描述匹配 > 麵包屑匹配
            local priority = nameMatch and 1 or (descMatch and 2 or 3)
            matches[#matches + 1] = {
                entry = entry,
                priority = priority,
            }
        end
    end

    -- 排序：priority 升序，同 priority 按名稱字母序
    table.sort(matches, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.entry.name < b.entry.name
    end)

    -- 限制最多 20 筆結果
    local limited = {}
    for i = 1, min(#matches, 20) do
        limited[i] = matches[i].entry
    end

    return limited
end

--- 建立搜尋 UI（EditBox + 結果清單疊層）
--- @param dialogFrame Frame            AceConfigDialog 的實際框架
--- @param options table                主 options table（從中重建索引）
--- @param AceConfigDialog table        AceConfigDialog 實例（用於點擊導航）
local function CreateSearchUI(dialogFrame, options, AceConfigDialog)
    -- 每次開啟時重建索引，確保反映最新的 options 狀態
    RebuildSearchIndex(options)

    -- 若搜尋框已存在且父框架相同，直接顯示
    if searchFrame then
        if searchFrame:GetParent() == dialogFrame then
            searchFrame:Show()
            return
        end
        -- 父框架已變更（AceConfigDialog 重建），重新建立
        searchFrame = nil
    end

    -- 搜尋框
    local searchBox = CreateFrame("EditBox", "LunarUIOptionsSearchBox", dialogFrame, "InputBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("TOPRIGHT", dialogFrame, "TOPRIGHT", -40, -8)
    searchBox:SetAutoFocus(false)
    searchBox:SetFontObject(GameFontNormalSmall)

    -- 占位文字（locale 經由全域 LunarUI.L 取得，Search.lua 未捕獲 Engine）
    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
    local L = (_G.LunarUI and _G.LunarUI.L) or {}
    placeholder:SetText(L.OptionsSearchPlaceholder or "Search settings...")
    searchBox._placeholder = placeholder

    -- 結果下拉面板
    local resultsPanel = CreateFrame("Frame", nil, dialogFrame, "BackdropTemplate")
    resultsPanel:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -2)
    resultsPanel:SetSize(340, 0)
    resultsPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    resultsPanel:SetBackdropColor(0.08, 0.08, 0.10, 0.98)
    resultsPanel:SetBackdropBorderColor(0.20, 0.16, 0.30, 1)
    resultsPanel:SetFrameStrata("DIALOG")
    resultsPanel:Hide()

    local resultButtons = {}

    local function UpdateResults(query)
        local results = FilterSearchResults(query)

        -- 隱藏所有既有按鈕
        for _, btn in ipairs(resultButtons) do
            btn:Hide()
        end

        if #results == 0 then
            resultsPanel:Hide()
            return
        end

        local buttonHeight = 24
        local maxResults = min(#results, 15)

        for i = 1, maxResults do
            local result = results[i]
            local btn = resultButtons[i]

            if not btn then
                btn = CreateFrame("Button", nil, resultsPanel)
                btn:SetHeight(buttonHeight)
                btn:SetPoint("TOPLEFT", resultsPanel, "TOPLEFT", 2, -(i - 1) * buttonHeight - 2)
                btn:SetPoint("TOPRIGHT", resultsPanel, "TOPRIGHT", -2, -(i - 1) * buttonHeight - 2)

                btn.text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                btn.text:SetPoint("LEFT", 6, 0)
                btn.text:SetPoint("RIGHT", -6, 0)
                btn.text:SetJustifyH("LEFT")

                local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints()
                highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
                highlight:SetVertexColor(0.53, 0.51, 1.0, 0.15)

                resultButtons[i] = btn
            end

            -- 顯示文字：group 用紫色，leaf 用白色
            local displayText = result.breadcrumbs
            if result.isGroup then
                displayText = "|cff8882ff" .. displayText .. "|r"
            end
            btn.text:SetText(displayText)

            -- 點擊導航到對應面板
            btn:SetScript("OnClick", function()
                if AceConfigDialog and #result.path > 0 then
                    AceConfigDialog:SelectGroup("LunarUI", unpack(result.path))
                end
                searchBox:SetText("")
                searchBox:ClearFocus()
                resultsPanel:Hide()
            end)

            btn:Show()
        end

        resultsPanel:SetHeight(maxResults * buttonHeight + 4)
        resultsPanel:Show()
    end

    -- EditBox 事件（節流 0.15 秒，減少 GC 壓力）
    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text == "" then
            placeholder:Show()
            resultsPanel:Hide()
            if searchTimer then
                searchTimer:Cancel()
                searchTimer = nil
            end
        else
            placeholder:Hide()
            if searchTimer then
                searchTimer:Cancel()
            end
            searchTimer = C_Timer.NewTimer(0.15, function()
                searchTimer = nil
                UpdateResults(text)
            end)
        end
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        resultsPanel:Hide()
    end)

    searchBox:SetScript("OnEditFocusGained", function()
        placeholder:Hide()
    end)

    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            placeholder:Show()
        end
    end)

    searchFrame = searchBox
end

-- Expose to Options.lua and spec tests
Private.search.SafeGetField = SafeGetField
Private.search.BuildSearchIndex = BuildSearchIndex
Private.search.FilterSearchResults = FilterSearchResults
Private.search.CreateSearchUI = CreateSearchUI
Private.search.SetSearchIndex = function(idx)
    searchIndex = idx
end
