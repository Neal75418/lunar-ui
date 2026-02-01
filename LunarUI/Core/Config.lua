---@diagnostic disable: unbalanced-assignments, need-check-nil, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
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
    self.db = LibStub("AceDB-3.0"):New("LunarUIDB", self._defaults, "Default")

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

    -- 延遲套用 HUD 縮放（等待所有 HUD 模組完成初始化）
    C_Timer.After(2, function()
        if self.ApplyHUDScale then
            self:ApplyHUDScale()
        end
    end)

    -- 專精切換自動設定檔
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
        local specIndex = GetSpecialization and GetSpecialization()
        if specIndex and self.db and self.db.char and self.db.char.specProfiles then
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

    self:Print(L["ProfileChanged"] or "設定檔已變更，UI 已重新整理")
end
