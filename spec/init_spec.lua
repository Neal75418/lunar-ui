---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unused, global-in-non-module, access-invisible, deprecated
--[[
    Init.lua 測試
    RegisterModule lifecycle 欄位、EnableModules、DisableModules
]]

require("spec.wow_mock")

-- Mock Ace3 addon object（Init.lua 在頂層呼叫 LibStub）
local aceAddonObj = {
    _isEnabled = true,
    _printLog = {},
    _errorLog = {},
    _commands = {},
    _messages = {},
    RegisterChatCommand = function() end,
    IsEnabled = function(self)
        return self._isEnabled
    end,
    Print = function(self, msg)
        self._printLog[#self._printLog + 1] = msg
    end,
    Error = function(self, msg)
        self._errorLog[#self._errorLog + 1] = msg
    end,
    SendMessage = function(self, msg)
        self._messages[#self._messages + 1] = msg
    end,
    RegisterCommands = function() end,
    SetupGameMenuButton = function() end,
}
-- NewAddon 回傳 aceAddonObj，並將 mixin 方法加上去（模擬 Ace3 行為）
local aceAddon = {
    NewAddon = function(_self, _name)
        return aceAddonObj
    end,
}

_G.LibStub = function(_name, _silent)
    return aceAddon
end

-- Mock C_AddOns
_G.C_AddOns = _G.C_AddOns or {}
_G.C_AddOns.GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata or function()
    return "test"
end
_G.C_AddOns.IsAddOnLoaded = _G.C_AddOns.IsAddOnLoaded or function()
    return false
end
_G.C_AddOns.LoadAddOn = _G.C_AddOns.LoadAddOn or function() end

-- Mock C_Timer
_G.C_Timer = _G.C_Timer or {}
local timerCallbacks = {}
_G.C_Timer.After = function(_delay, fn)
    timerCallbacks[#timerCallbacks + 1] = fn
end

-- Mock debugstack
_G.debugstack = _G.debugstack or function()
    return ""
end

-- Load Init.lua
local chunk, err = loadfile("LunarUI/Core/Init.lua")
if not chunk then
    error("Failed to load Init.lua: " .. tostring(err))
end
local Engine = { L = {} }
chunk("LunarUI", Engine)

local LunarUI = Engine.LunarUI

--------------------------------------------------------------------------------
-- RegisterModule lifecycle
--------------------------------------------------------------------------------

describe("RegisterModule lifecycle", function()
    before_each(function()
        LunarUI._modulesEnabled = false
        LunarUI._resetModuleRegistry()
        wipe(aceAddonObj._errorLog)
        wipe(aceAddonObj._printLog)
        wipe(timerCallbacks)
    end)

    it("defaults lifecycle to 'reversible'", function()
        -- 註冊一個 reversible（預設）模組，再透過 DisableModules 的訊息驗證
        LunarUI:RegisterModule("TestDefault", {
            onEnable = function() end,
            onDisable = function() end,
        })
        LunarUI.EnableModules()
        wipe(aceAddonObj._printLog)
        LunarUI.DisableModules()

        -- 全部 reversible → 應印出乾淨訊息（無 reload）
        local hasReloadMsg = false
        for _, msg in ipairs(aceAddonObj._printLog) do
            if msg:find("requires UI reload") then
                hasReloadMsg = true
            end
        end
        assert.is_false(hasReloadMsg)
    end)

    it("accepts explicit lifecycle = 'reversible'", function()
        LunarUI:RegisterModule("TestReversible", {
            onEnable = function() end,
            onDisable = function() end,
            lifecycle = "reversible",
        })
        -- 沒有 Error 呼叫
        local hasLifecycleError = false
        for _, msg in ipairs(aceAddonObj._errorLog) do
            if msg:find("lifecycle") then
                hasLifecycleError = true
            end
        end
        assert.is_false(hasLifecycleError)
    end)

    it("accepts explicit lifecycle = 'soft_disable'", function()
        LunarUI:RegisterModule("TestSoftDisable", {
            onEnable = function() end,
            lifecycle = "soft_disable",
        })
        local hasLifecycleError = false
        for _, msg in ipairs(aceAddonObj._errorLog) do
            if msg:find("lifecycle") then
                hasLifecycleError = true
            end
        end
        assert.is_false(hasLifecycleError)
    end)

    it("accepts explicit lifecycle = 'reload_required'", function()
        LunarUI:RegisterModule("TestReloadRequired", {
            onEnable = function() end,
            lifecycle = "reload_required",
        })
        local hasLifecycleError = false
        for _, msg in ipairs(aceAddonObj._errorLog) do
            if msg:find("lifecycle") then
                hasLifecycleError = true
            end
        end
        assert.is_false(hasLifecycleError)
    end)

    it("falls back to 'reversible' and calls Error on invalid lifecycle", function()
        LunarUI:RegisterModule("TestInvalid", {
            onEnable = function() end,
            onDisable = function() end,
            lifecycle = "bogus",
        })
        local hasInvalidError = false
        for _, msg in ipairs(aceAddonObj._errorLog) do
            if msg:find("invalid lifecycle") then
                hasInvalidError = true
            end
        end
        assert.is_true(hasInvalidError)
    end)

    it("calls Error when reversible module has no onDisable", function()
        LunarUI:RegisterModule("TestReversibleNoDisable", {
            onEnable = function() end,
            lifecycle = "reversible",
        })
        local hasRequiresError = false
        for _, msg in ipairs(aceAddonObj._errorLog) do
            if msg:find("requires onDisable") then
                hasRequiresError = true
            end
        end
        assert.is_true(hasRequiresError)
    end)
end)

--------------------------------------------------------------------------------
-- EnableModules / DisableModules
--------------------------------------------------------------------------------

describe("EnableModules", function()
    before_each(function()
        LunarUI._modulesEnabled = false
        LunarUI._resetModuleRegistry()
        wipe(timerCallbacks)
        wipe(aceAddonObj._errorLog)
        wipe(aceAddonObj._printLog)
    end)

    it("is idempotent", function()
        LunarUI.EnableModules()
        assert.is_true(LunarUI._modulesEnabled)
        -- 第二次呼叫不應拋錯
        assert.has_no_errors(function()
            LunarUI.EnableModules()
        end)
    end)
end)

describe("DisableModules", function()
    before_each(function()
        LunarUI._modulesEnabled = false
        LunarUI._resetModuleRegistry()
        wipe(timerCallbacks)
        wipe(aceAddonObj._errorLog)
        wipe(aceAddonObj._printLog)
    end)

    it("is idempotent when not enabled", function()
        assert.has_no_errors(function()
            LunarUI.DisableModules()
        end)
    end)

    it("calls onDisable in reverse order", function()
        local order = {}
        LunarUI:RegisterModule("DisableOrderA", {
            onEnable = function() end,
            onDisable = function()
                order[#order + 1] = "A"
            end,
        })
        LunarUI:RegisterModule("DisableOrderB", {
            onEnable = function() end,
            onDisable = function()
                order[#order + 1] = "B"
            end,
        })

        LunarUI.EnableModules()
        LunarUI.DisableModules()

        -- 反向順序：B 先於 A（registry 已重置，只有這兩個模組）
        assert.are.same({ "B", "A" }, order)
    end)

    it("prints reload message when soft_disable modules exist", function()
        LunarUI:RegisterModule("SoftDisableMsg", {
            onEnable = function() end,
            lifecycle = "soft_disable",
        })

        LunarUI.EnableModules()
        wipe(aceAddonObj._printLog)
        LunarUI.DisableModules()

        local hasReloadMsg = false
        for _, msg in ipairs(aceAddonObj._printLog) do
            if msg:find("requires UI reload") or msg:find("需重載") then
                hasReloadMsg = true
            end
        end
        assert.is_true(hasReloadMsg)
    end)

    it("prints reload message when reload_required modules exist", function()
        LunarUI:RegisterModule("ReloadRequiredMsg", {
            onEnable = function() end,
            lifecycle = "reload_required",
        })

        LunarUI.EnableModules()
        wipe(aceAddonObj._printLog)
        LunarUI.DisableModules()

        local hasReloadMsg = false
        for _, msg in ipairs(aceAddonObj._printLog) do
            if msg:find("requires UI reload") or msg:find("需重載") then
                hasReloadMsg = true
            end
        end
        assert.is_true(hasReloadMsg)
    end)

    it("prints reload message when mixed reversible + soft_disable modules", function()
        LunarUI:RegisterModule("MixedReversible", {
            onEnable = function() end,
            onDisable = function() end,
            lifecycle = "reversible",
        })
        LunarUI:RegisterModule("MixedSoftDisable", {
            onEnable = function() end,
            lifecycle = "soft_disable",
        })

        LunarUI.EnableModules()
        wipe(aceAddonObj._printLog)
        LunarUI.DisableModules()

        local hasReloadMsg = false
        for _, msg in ipairs(aceAddonObj._printLog) do
            if msg:find("requires UI reload") or msg:find("需重載") then
                hasReloadMsg = true
            end
        end
        assert.is_true(hasReloadMsg)
    end)

    it("prints clean message when only reversible modules exist", function()
        LunarUI:RegisterModule("ReversibleOnly", {
            onEnable = function() end,
            onDisable = function() end,
            lifecycle = "reversible",
        })

        LunarUI.EnableModules()
        wipe(aceAddonObj._printLog)
        LunarUI.DisableModules()

        local hasReloadMsg = false
        local hasCleanMsg = false
        for _, msg in ipairs(aceAddonObj._printLog) do
            if msg:find("requires UI reload") then
                hasReloadMsg = true
            end
            if msg:find("LunarUI disabled") and not msg:find("reload") then
                hasCleanMsg = true
            end
        end
        assert.is_false(hasReloadMsg)
        assert.is_true(hasCleanMsg)
    end)
end)
