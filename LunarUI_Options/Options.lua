---@diagnostic disable: undefined-field, inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, unused-local
--[[
    LunarUI Options
    Configuration interface using AceConfig-3.0

    Features:
    - General settings
    - UnitFrames configuration
    - ActionBars configuration
    - Nameplates configuration
    - Non-combat UI settings (Minimap, Chat, Bags, Tooltip)
    - Visual style settings
    - Profile management
]]

-- TOC varargs: (addonName, Private) — Private is shared across all files in this
-- addon. Section builders in sections/*.lua attach to Private.sections.*
-- The spec loads Options.lua via loadfile() without varargs, so Private is nil —
-- we fallback to an empty table and the resulting options.args is empty for tests
-- (tests only exercise the utility functions, not the populated AceConfig tree).
local _, Private = ...
Private = Private or {}

local LunarUI = LibStub("AceAddon-3.0"):GetAddon("LunarUI")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0", true)

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------

-- 使用主插件的本地化表（enUS.lua / zhTW.lua），統一 i18n
-- __index fallback：key 不存在時回傳 key 名稱本身，避免 nil 錯誤
local L = setmetatable({}, {
    __index = function(_, key)
        local mainL = LunarUI.L or (_G.LunarUI and _G.LunarUI.L)
        if mainL and mainL[key] then
            return mainL[key]
        end
        return key
    end,
})

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

-- Fix #26: DB 未載入時回傳 nil（AceDB 保證 Options panel 開啟時 DB 一定存在）
local getDBWarned = false
local function GetDB()
    local profile = LunarUI.GetProfileDB and LunarUI.GetProfileDB()
    if not profile then
        if not getDBWarned then
            getDBWarned = true
            local msg = (LunarUI.L and LunarUI.L.OptionsDbNotReady)
                or "[Options] DB not ready — settings may not save"
            LunarUI:Print("|cffff0000" .. msg .. "|r")
        end
        return nil
    end
    return profile
end

local function RefreshUI()
    if LunarUI.ApplyHUDScale then
        LunarUI:ApplyHUDScale()
    end
    -- 字體/字型大小變更時即時生效（批次更新所有已註冊 FontString）
    if LunarUI.ApplyFontSettings then
        LunarUI:ApplyFontSettings()
    end
end

--------------------------------------------------------------------------------
-- DB path traversal helpers
--------------------------------------------------------------------------------

-- 沿著 path（陣列）從 profile 取值；任何中間節點為 nil 即安全返回 nil。
-- path 以陣列表示，末段是 leaf key：{"bags", "enabled"} → profile.bags.enabled
local function getByPath(path)
    local node = GetDB()
    if not node then
        return nil
    end
    for i = 1, #path - 1 do
        node = node[path[i]]
        if type(node) ~= "table" then
            return nil
        end
    end
    return node[path[#path]]
end

-- 沿著 path 寫入值；中間節點不存在時不寫入（AceDB 會建立 module 子表，所以
-- 正常情況一定存在）。避免 silent write-to-nowhere。
local function setByPath(path, value)
    local node = GetDB()
    if not node then
        return
    end
    for i = 1, #path - 1 do
        node = node[path[i]]
        if type(node) ~= "table" then
            return
        end
    end
    node[path[#path]] = value
end

--------------------------------------------------------------------------------
-- Option widget factories（Fix #2: 消除 418 處 GetDB().x.y 重複 + NPE 風險）
--
-- 每個 factory 回傳符合 AceConfig-3.0 規格的 widget table。`opts` 是可選的
-- 覆寫表，會 shallow-merge 進結果（例：width, disabled, hidden, onValueSet）。
-- `onValueSet` 在 set 完成後呼叫，用途是觸發 RefreshUI/RebuildX 等副作用。
--------------------------------------------------------------------------------

-- opts 中的 meta 欄位（不屬於 AceConfig，不應 merge 到 widget）
local FACTORY_META_KEYS = {
    onValueSet = true,
    default = true,
}

local function mergeOpts(widget, opts)
    if opts then
        for k, v in pairs(opts) do
            if not FACTORY_META_KEYS[k] then
                widget[k] = v
            end
        end
    end
    return widget
end

-- 建立 get 閉包：若 opts.default 有值，用作 nil-safety 防線（給定非常舊的
-- profile 缺欄位時的 fallback；正常情況下 AceDB + Defaults.lua 會先填好）
local function makeGetter(path, defaultValue)
    if defaultValue ~= nil then
        return function()
            local v = getByPath(path)
            if v == nil then
                return defaultValue
            end
            return v
        end
    end
    return function()
        return getByPath(path)
    end
end

local function makeSetter(path, onValueSet)
    return function(_, v)
        setByPath(path, v)
        if onValueSet then
            onValueSet(v)
        end
    end
end

local function makeToggle(order, path, name, desc, opts)
    local widget = {
        order = order,
        type = "toggle",
        name = name,
        desc = desc,
        get = makeGetter(path, opts and opts.default),
        set = makeSetter(path, opts and opts.onValueSet),
    }
    return mergeOpts(widget, opts)
end

local function makeRange(order, path, name, desc, min, max, step, opts)
    local widget = {
        order = order,
        type = "range",
        name = name,
        desc = desc,
        min = min,
        max = max,
        step = step,
        get = makeGetter(path, opts and opts.default),
        set = makeSetter(path, opts and opts.onValueSet),
    }
    return mergeOpts(widget, opts)
end

local function makeSelect(order, path, name, desc, values, opts)
    local widget = {
        order = order,
        type = "select",
        name = name,
        desc = desc,
        values = values,
        get = makeGetter(path, opts and opts.default),
        set = makeSetter(path, opts and opts.onValueSet),
    }
    return mergeOpts(widget, opts)
end

local function makeHeader(order, name)
    return { order = order, type = "header", name = name }
end

local function makeExecute(order, name, desc, func, opts)
    local widget = {
        order = order,
        type = "execute",
        name = name,
        desc = desc,
        func = func,
    }
    return mergeOpts(widget, opts)
end

--------------------------------------------------------------------------------
-- Section builder context
--------------------------------------------------------------------------------

-- ctx is passed to every Private.sections.*(ctx) builder. Fields are captured
-- by value (stable references). See LunarUI_Options/sections/*.lua.
-- toggle/range/select/header/execute factories are available to reduce boilerplate;
-- sections can migrate to them incrementally.
local ctx = {
    L = L,
    GetDB = GetDB,
    RefreshUI = RefreshUI,
    LunarUI = LunarUI,
    toggle = makeToggle,
    range = makeRange,
    select = makeSelect,
    header = makeHeader,
    execute = makeExecute,
}

--------------------------------------------------------------------------------
-- Options Table
--------------------------------------------------------------------------------

-- All section groups (general, unitframes, actionbars, ...) live in
-- sections/*.lua and are wired into options.args below via ApplySection.
-- The static table literal here only contains the top-of-panel header.
local options = {
    name = "|cff8882ffLunar|r|cffffffffUI|r",
    type = "group",
    args = {
        header = {
            order = 0,
            type = "description",
            name = "|cff888888" .. (L["OptionsDesc"] or "Modern combat UI replacement with Lunar theme") .. "|r\n\n",
            fontSize = "medium",
        },
    },
}

--------------------------------------------------------------------------------
-- Apply extracted section builders
--------------------------------------------------------------------------------

-- sections/*.lua attach builders to Private.sections.*. Any section present
-- is merged into options.args (overwriting if key already exists). Missing
-- sections (e.g. when loaded via spec loadfile without varargs) are skipped.
local function ApplySection(key, builder)
    if builder then
        options.args[key] = builder(ctx)
    end
end

do
    local sections = Private.sections or {}
    ApplySection("general", sections.General)
    ApplySection("unitframes", sections.UnitFrames)
    ApplySection("actionbars", sections.ActionBars)
    ApplySection("nameplates", sections.Nameplates)
    ApplySection("hud", sections.HUD)
    ApplySection("minimap", sections.Minimap)
    ApplySection("bags", sections.Bags)
    ApplySection("chat", sections.Chat)
    ApplySection("tooltip", sections.Tooltip)
    ApplySection("frameMover", sections.FrameMover)
    ApplySection("style", sections.Style)
    ApplySection("loot", sections.Loot)
    ApplySection("databars", sections.DataBars)
    ApplySection("datatexts", sections.DataTexts)
    ApplySection("automation", sections.Automation)
    ApplySection("skins", sections.Skins)
end

--------------------------------------------------------------------------------
-- Search — extracted to LunarUI_Options/Search.lua (Private.search.*)
--------------------------------------------------------------------------------

-- In production WoW the TOC loads Search.lua before Options.lua, so
-- Private.search is populated. In the spec (loadfile path) the same varargs
-- mechanism works because spec/options_spec.lua explicitly loads Search.lua
-- first. Both modes fall back to no-op stubs if Private.search is missing.
local Search = Private.search or {}

--------------------------------------------------------------------------------
-- Profile Options
--------------------------------------------------------------------------------

local function GetProfileOptions()
    if AceDBOptions then
        return AceDBOptions:GetOptionsTable(LunarUI.db)
    end
    return nil
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local function RegisterOptions()
    -- Register main options
    AceConfig:RegisterOptionsTable("LunarUI", options)

    -- Add to Blizzard options
    AceConfigDialog:AddToBlizOptions("LunarUI", "LunarUI")

    -- Register profile options with spec auto-switch
    local profileOptions = GetProfileOptions()
    if profileOptions then
        -- 注入專精自動切換選項
        profileOptions.args.specHeader = {
            order = 100,
            type = "header",
            name = L.specAutoSwitch,
        }
        profileOptions.args.specDesc = {
            order = 101,
            type = "description",
            name = L.specAutoSwitchDesc,
        }
        local numSpecs = GetNumSpecializations and GetNumSpecializations(false) or 0
        for i = 1, numSpecs do
            local _, specName = GetSpecializationInfo(i)
            profileOptions.args["spec" .. i] = {
                order = 101 + i,
                type = "select",
                name = (specName or ("Spec " .. i)),
                desc = L.specProfile,
                values = function()
                    local t = { [""] = "(None)" }
                    for _, p in ipairs(LunarUI.db:GetProfiles()) do
                        t[p] = p
                    end
                    return t
                end,
                get = function()
                    if not LunarUI.db or not LunarUI.db.char then
                        return ""
                    end
                    return LunarUI.db.char.specProfiles and LunarUI.db.char.specProfiles[i] or ""
                end,
                set = function(_, v)
                    if not LunarUI.db or not LunarUI.db.char then
                        return
                    end
                    if not LunarUI.db.char.specProfiles then
                        LunarUI.db.char.specProfiles = {}
                    end
                    LunarUI.db.char.specProfiles[i] = (v ~= "") and v or nil
                end,
                width = "full",
            }
        end

        AceConfig:RegisterOptionsTable("LunarUI_Profiles", profileOptions)
        AceConfigDialog:AddToBlizOptions("LunarUI_Profiles", L.profiles, "LunarUI")
    end
end

--------------------------------------------------------------------------------
-- Dialog open + styling
--------------------------------------------------------------------------------

-- StyleConfigFrame 已抽到 LunarUI_Options/Frame.lua (Private.frame.*)
local Frame = Private.frame or {}
local styleDeps = {
    LunarUI = LunarUI,
    AceConfigDialog = AceConfigDialog,
    options = options,
    Search = Search,
}

local function OpenConfig()
    -- Load the options addon if not loaded
    if not C_AddOns.IsAddOnLoaded("LunarUI_Options") then
        C_AddOns.LoadAddOn("LunarUI_Options")
    end

    -- 設定更大的視窗尺寸
    if AceConfigDialog then
        AceConfigDialog:SetDefaultSize("LunarUI", 900, 650)
        AceConfigDialog:Open("LunarUI")
        -- 延遲 0.1 秒美化（確保 AceConfigDialog 完成框架建立）
        if Frame.StyleConfigFrame then
            C_Timer.After(0.1, function()
                Frame.StyleConfigFrame(styleDeps)
            end)
        end
    end
end

-- Register with main addon
LunarUI.OpenConfig = OpenConfig

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

-- Fix #27: Clean up frame after registration
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _event, addon)
    if addon == "LunarUI_Options" then
        RegisterOptions()
        self:UnregisterEvent("ADDON_LOADED")
        self:SetScript("OnEvent", nil)
        -- Frame can be garbage collected now
    end
end)

--------------------------------------------------------------------------------
-- Test Exports (pure functions exposed for unit testing)
--------------------------------------------------------------------------------

-- Delegate search-related test hooks to Private.search (see Search.lua).
-- These are nil in spec environments that don't load Search.lua; not a concern
-- for utility tests, since the spec explicitly loads Search.lua first.
LunarUI.Options_SafeGetField = Search.SafeGetField
LunarUI.Options_BuildSearchIndex = Search.BuildSearchIndex
LunarUI.Options_FilterSearchResults = Search.FilterSearchResults
LunarUI.Options_SetSearchIndex = Search.SetSearchIndex
--- Expose the assembled options table so spec tests can verify each extracted
--- section is wired into options.args via its ApplySection call.
LunarUI.Options_GetOptionsTable = function()
    return options
end
