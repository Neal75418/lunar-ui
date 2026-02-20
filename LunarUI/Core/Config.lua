---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - 設定模組（AceDB）
    資料庫初始化與設定檔管理
    預設值定義於 Defaults.lua，選項面板定義於 Options.lua
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- 資料庫初始化
--------------------------------------------------------------------------------

--[[
    初始化資料庫
    從 Init.lua 的 OnInitialize 呼叫
]]
function LunarUI:InitDB()
    self.db = LibStub("AceDB-3.0"):New("LunarUIDB", Engine._defaults, "Default")

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

    -- 驗證使用者設定（修正手動編輯 SavedVariables 導致的不合法值）
    self:ValidateDB()

    -- 儲存版本
    self.db.global.version = self.version

    -- HUD 縮放由 RegisterHUDFrame() 在每次框架註冊時即時套用，
    -- 不再依賴固定延遲（避免 magic number 與模組延遲的時序假設）

    -- 專精切換自動設定檔
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
        if not self.db or not self.db.profile or not self.db.char then return end

        local specIndex = GetSpecialization and GetSpecialization()
        if specIndex and self.db.char.specProfiles then
            local target = self.db.char.specProfiles[specIndex]
            if target and target ~= self.db:GetCurrentProfile() then
                self.db:SetProfile(target)
            end
        end
    end)
end

--[[
    設定檔變更回呼
]]
function LunarUI:OnProfileChanged()
    local L = Engine.L or {}
    -- 先套用 HUD 縮放（避免框架顯示時短暫出現舊縮放值）
    if self.ApplyHUDScale then
        self:ApplyHUDScale()
    end

    self:Print(L["ProfileChanged"] or "Profile changed, UI refreshed")
end

--------------------------------------------------------------------------------
-- 統一設定存取 API
--------------------------------------------------------------------------------

--[[
    取得模組設定
    @param moduleName string - 模組名稱（如 "unitframes", "nameplates", "hud"）
    @return table|nil - 模組設定表，若不存在則返回 nil

    使用範例：
        local db = LunarUI:GetModuleConfig("unitframes")
        if not db or not db.enabled then return end
]]
function LunarUI:GetModuleConfig(moduleName)
    if not self.db or not self.db.profile then return nil end
    return self.db.profile[moduleName]
end

--[[
    取得嵌套設定路徑
    @param ... string - 路徑層級（如 "hud", "scale"）
    @return any - 設定值，若路徑不存在則返回 nil

    使用範例：
        local scale = LunarUI:GetConfigValue("hud", "scale")
        local enabled = LunarUI:GetConfigValue("unitframes", "player", "enabled")
]]
function LunarUI:GetConfigValue(...)
    if not self.db or not self.db.profile then return nil end
    local config = self.db.profile
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if type(config) ~= "table" then return nil end
        config = config[key]
        if config == nil then return nil end
    end
    return config
end

--------------------------------------------------------------------------------
-- 設定值驗證
--------------------------------------------------------------------------------

-- 驗證規則：{ path, type, min, max, enum }
-- path 為 "." 分隔的設定路徑，type 為 "number"/"string"/"boolean"
local VALIDATION_RULES = {
    -- HUD
    { path = "hud.scale",               type = "number", min = 0.5,  max = 2.0 },
    { path = "hud.auraIconSize",        type = "number", min = 10,   max = 80 },
    { path = "hud.cdIconSize",          type = "number", min = 10,   max = 80 },
    { path = "hud.fctFontSize",         type = "number", min = 8,    max = 48 },
    { path = "hud.fctCritScale",        type = "number", min = 1.0,  max = 3.0 },
    { path = "hud.fctDuration",         type = "number", min = 0.5,  max = 5.0 },
    -- 動作條
    { path = "actionbars.alpha",        type = "number", min = 0,    max = 1 },
    { path = "actionbars.fadeAlpha",    type = "number", min = 0,    max = 1 },
    { path = "actionbars.fadeDelay",    type = "number", min = 0,    max = 30 },
    { path = "actionbars.fadeDuration", type = "number", min = 0,    max = 5 },
    { path = "actionbars.buttonSize",   type = "number", min = 16,   max = 64 },
    { path = "actionbars.buttonSpacing",type = "number", min = 0,    max = 20 },
    -- 小地圖
    { path = "minimap.size",            type = "number", min = 100,  max = 400 },
    { path = "minimap.fadeAlpha",       type = "number", min = 0,    max = 1 },
    { path = "minimap.pinScale",        type = "number", min = 0.5,  max = 2.0 },
    { path = "minimap.resetZoomTimer",  type = "number", min = 0,    max = 15 },
    { path = "minimap.zoneFontSize",    type = "number", min = 6,    max = 24 },
    { path = "minimap.coordFontSize",   type = "number", min = 6,    max = 24 },
    { path = "minimap.clockFormat",     type = "string", enum = { ["12h"] = true, ["24h"] = true } },
    { path = "minimap.zoneTextDisplay", type = "string", enum = { SHOW = true, MOUSEOVER = true, HIDE = true } },
    { path = "minimap.zoneFontOutline", type = "string", enum = { NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROMEOUTLINE = true } },
    { path = "minimap.coordFontOutline",type = "string", enum = { NONE = true, OUTLINE = true, THICKOUTLINE = true, MONOCHROMEOUTLINE = true } },
    -- 背包
    { path = "bags.slotsPerRow",        type = "number", min = 6,    max = 24 },
    { path = "bags.slotSize",           type = "number", min = 20,   max = 60 },
    { path = "bags.slotSpacing",        type = "number", min = 0,    max = 10 },
    { path = "bags.frameAlpha",         type = "number", min = 0,    max = 1 },
    { path = "bags.ilvlThreshold",      type = "number", min = 0,    max = 1000 },
    -- 聊天
    { path = "chat.width",              type = "number", min = 100,  max = 1000 },
    { path = "chat.height",             type = "number", min = 50,   max = 600 },
    { path = "chat.fadeTime",           type = "number", min = 0,    max = 600 },
    -- 視覺風格
    { path = "style.theme",             type = "string", enum = { lunar = true, parchment = true, minimal = true } },
    { path = "style.fontSize",          type = "number", min = 6,    max = 32 },
    { path = "style.borderStyle",       type = "string", enum = { ink = true, clean = true, none = true } },
    -- 名牌
    { path = "nameplates.healthTextFormat", type = "string", enum = { percent = true, current = true, both = true } },
    -- 光環過濾
    { path = "auraFilters.sortMethod",  type = "string", enum = { time = true, duration = true, name = true, player = true } },
    -- 框架移動器
    { path = "frameMover.gridSize",     type = "number", min = 1,    max = 50 },
    { path = "frameMover.moverAlpha",   type = "number", min = 0,    max = 1 },
}

-- 從 "." 分隔路徑取得設定表中的值及其父表
local function resolveDBPath(db, path)
    local parts = { strsplit(".", path) }
    local parent = db
    for i = 1, #parts - 1 do
        parent = parent[parts[i]]
        if type(parent) ~= "table" then return nil, nil, nil end
    end
    local key = parts[#parts]
    return parent, key, parent[key]
end

function LunarUI:ValidateDB()
    if not self.db or not self.db.profile then return end

    local profile = self.db.profile
    local defaults = Engine._defaults and Engine._defaults.profile
    local fixCount = 0

    for _, rule in ipairs(VALIDATION_RULES) do
        local parent, key, value = resolveDBPath(profile, rule.path)
        if parent and value ~= nil then
            local invalid = false

            if rule.type == "number" then
                if type(value) ~= "number" then
                    invalid = true
                elseif rule.min and value < rule.min then
                    invalid = true
                elseif rule.max and value > rule.max then
                    invalid = true
                end
            elseif rule.type == "string" then
                if type(value) ~= "string" then
                    invalid = true
                elseif rule.enum and not rule.enum[value] then
                    invalid = true
                end
            elseif rule.type == "boolean" then
                if type(value) ~= "boolean" then
                    invalid = true
                end
            end

            if invalid then
                -- 從 defaults 取得預設值
                local _, _, defaultValue = resolveDBPath(defaults or {}, rule.path)
                if defaultValue ~= nil then
                    parent[key] = defaultValue
                    fixCount = fixCount + 1
                    self:Print(string.format(
                        "|cffff8800[Config]|r %s: invalid value %s, reset to %s",
                        rule.path, tostring(value), tostring(defaultValue)
                    ))
                end
            end
        end
    end

    if fixCount > 0 then
        self:Print(string.format("|cffff8800[Config]|r Fixed %d invalid setting(s)", fixCount))
    end
end
