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
