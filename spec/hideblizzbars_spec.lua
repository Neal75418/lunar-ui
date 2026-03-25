---@diagnostic disable: inject-field, need-check-nil, param-type-mismatch, assign-type-mismatch, redundant-parameter, undefined-field, undefined-global, missing-parameter, call-non-callable, unnecessary-if, unused, global-in-non-module, access-invisible, deprecated
--[[
    Unit tests for LunarUI/ActionBars/HideBlizzardBars.lua
    Tests: save/restore 對稱性 — hide 階段修改的所有狀態在 restore 後正確還原
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- 追蹤框架狀態的 mock 工廠
local function CreateMockFrame(name, opts)
    opts = opts or {}
    local frame = {
        _name = name,
        _alpha = 1,
        _mouseEnabled = true,
        _keyboardEnabled = true,
        _visible = true,
        _parent = opts.parent or "UIParent",
        _regions = opts.regions or {},
        _children = opts.children or {},
        _texturePath = opts.texturePath,
        -- 方法
        GetName = function(self)
            return self._name
        end,
        SetAlpha = function(self, a)
            self._alpha = a
        end,
        GetAlpha = function(self)
            return self._alpha
        end,
        EnableMouse = function(self, v)
            self._mouseEnabled = v
        end,
        EnableKeyboard = function(self, v)
            self._keyboardEnabled = v
        end,
        Show = function(self)
            self._visible = true
        end,
        Hide = function(self)
            self._visible = false
        end,
        IsShown = function(self)
            return self._visible
        end,
        SetParent = function(self, p)
            self._parent = p
        end,
        GetParent = function(self)
            return self._parent
        end,
        GetRegions = function(self)
            return unpack(self._regions)
        end,
        GetChildren = function(self)
            return unpack(self._children)
        end,
        SetTexture = function(self, path)
            self._texturePath = path
        end,
        GetTexture = function(self)
            return self._texturePath
        end,
        IsObjectType = function(_, t)
            return t == "Texture"
        end,
    }
    -- OnEditModeEnter/Exit 原始方法
    if opts.hasEditMode then
        frame.OnEditModeEnter = function()
            return "original_enter"
        end
        frame.OnEditModeExit = function()
            return "original_exit"
        end
    end
    return frame
end

-- 設定全域環境
_G.InCombatLockdown = function()
    return false
end
_G.hooksecurefunc = function() end
_G.C_Timer = {
    After = function() end,
    NewTimer = function()
        return { Cancel = function() end }
    end,
}
_G.geterrorhandler = function()
    return function() end
end
_G.seterrorhandler = function() end
_G.C_NamePlate = { SetNamePlateSize = function() end }

-- 隱藏用父框架 mock
local hiddenBarParent = CreateMockFrame("LunarUIHiddenBars")
hiddenBarParent._visible = false
hiddenBarParent.SetAllPoints = function() end
_G.CreateFrame = function(_, name)
    if name == "LunarUIHiddenBars" then
        return hiddenBarParent
    end
    local f = CreateMockFrame(name)
    f.SetAllPoints = function() end
    return f
end

-- UIParent mock
_G.UIParent = CreateMockFrame("UIParent")
_G.UIParent.RegisterEvent = function() end
_G.UIParent.UnregisterEvent = function() end

-- MultiBar mocks（有 EditMode）
local multiBarOriginalParent = CreateMockFrame("ActionBarContainer")
local multiBar1 = CreateMockFrame("MultiBarBottomLeft", { parent = multiBarOriginalParent, hasEditMode = true })
local multiBar2 = CreateMockFrame("MultiBarRight", { parent = multiBarOriginalParent, hasEditMode = true })

-- ArtFrame region mocks
local region1 = CreateMockFrame("region1")
region1._texturePath = "Interface\\MainMenuBar\\MainMenuBar"
local region2 = CreateMockFrame("region2")
region2._texturePath = "Interface\\MainMenuBar\\Gryphon"

-- MainActionBar mock（12.0 取代 MainMenuBarArtFrame）
local artFrame = CreateMockFrame("MainActionBar")
artFrame._regions = { region1, region2 }
artFrame.LeftEndCap = CreateMockFrame("LeftEndCap")
artFrame.LeftEndCap._texturePath = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Human"
artFrame.RightEndCap = CreateMockFrame("RightEndCap")
artFrame.RightEndCap._texturePath = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Human"

-- 註冊全域框架
_G.MultiBarBottomLeft = multiBar1
_G.MultiBarRight = multiBar2
_G.MainActionBar = artFrame
_G.MainMenuBarArtFrame = nil -- 12.0 已不存在
_G.MainMenuBar = nil -- 簡化：不測試 MainMenuBar 隱藏（減少 mock 複雜度）
_G.OverrideActionBar = nil
_G.MicroMenu = nil
_G.StanceBar = nil
_G.PetActionBar = nil
_G.StatusTrackingBarManager = nil

-- 建立 LunarUI 表並載入模組
local LunarUI = {
    Colors = { border = { 0.15, 0.12, 0.08, 1 } },
    CASTBAR_COLOR = { 0.4, 0.6, 0.8, 1 },
    BG_DARKEN = 0.3,
    backdropTemplate = {},
    db = { global = {} },
    Print = function() end,
    Debug = function() end,
}
loader.loadAddonFile("LunarUI/ActionBars/HideBlizzardBars.lua", LunarUI)

describe("HideBlizzardBars", function()
    describe("save/restore 對稱性", function()
        -- 每個測試前重置框架狀態
        before_each(function()
            -- 重置 MultiBar 狀態
            multiBar1._alpha = 1
            multiBar1._parent = multiBarOriginalParent
            multiBar1._visible = true
            multiBar1._mouseEnabled = true
            multiBar1.OnEditModeEnter = function()
                return "original_enter"
            end
            multiBar1.OnEditModeExit = function()
                return "original_exit"
            end

            multiBar2._alpha = 1
            multiBar2._parent = multiBarOriginalParent
            multiBar2._visible = true
            multiBar2._mouseEnabled = true
            multiBar2.OnEditModeEnter = function()
                return "original_enter"
            end
            multiBar2.OnEditModeExit = function()
                return "original_exit"
            end

            -- 重置 region 狀態
            region1._alpha = 1
            region1._visible = true
            region1._texturePath = "Interface\\MainMenuBar\\MainMenuBar"
            region2._alpha = 1
            region2._visible = true
            region2._texturePath = "Interface\\MainMenuBar\\Gryphon"

            -- 重置 EndCap
            artFrame.LeftEndCap._alpha = 1
            artFrame.LeftEndCap._visible = true
            artFrame.LeftEndCap._texturePath = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Human"
            artFrame.RightEndCap._alpha = 1
            artFrame.RightEndCap._visible = true
            artFrame.RightEndCap._texturePath = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Human"
        end)

        it("MultiBar parent 在 hide 後被改變，restore 後還原", function()
            -- Hide
            LunarUI.HideBlizzardBarsDelayed()

            -- 驗證 hide 效果
            assert.is_not.equal(multiBarOriginalParent, multiBar1._parent)

            -- Restore
            LunarUI.RestoreBlizzardBars()

            -- 驗證 restore
            assert.are.equal(multiBarOriginalParent, multiBar1._parent)
            assert.are.equal(multiBarOriginalParent, multiBar2._parent)
        end)

        it("OnEditModeEnter/Exit 在 hide 後被覆寫為 no-op，restore 後還原", function()
            local originalEnter = multiBar1.OnEditModeEnter
            local originalExit = multiBar1.OnEditModeExit

            LunarUI.HideBlizzardBarsDelayed()

            -- 驗證被覆寫
            assert.is_not.equal(originalEnter, multiBar1.OnEditModeEnter)
            assert.is_not.equal(originalExit, multiBar1.OnEditModeExit)

            LunarUI.RestoreBlizzardBars()

            -- 驗證還原（函數回傳值一致代表是原始函數）
            assert.are.equal("original_enter", multiBar1.OnEditModeEnter())
            assert.are.equal("original_exit", multiBar1.OnEditModeExit())
        end)

        it("hide → restore → hide → restore 多次循環不累積狀態", function()
            for _ = 1, 3 do
                LunarUI.HideBlizzardBarsDelayed()
                assert.is_not.equal(multiBarOriginalParent, multiBar1._parent)

                LunarUI.RestoreBlizzardBars()
                assert.are.equal(multiBarOriginalParent, multiBar1._parent)
                assert.are.equal("original_enter", multiBar1.OnEditModeEnter())
            end
        end)

        it("EnableKeyboard 在 hide 後被禁用，restore 後還原", function()
            -- artFrame.LeftEndCap 會走 HideFrameSafely 路徑
            assert.is_true(artFrame.LeftEndCap._keyboardEnabled)

            LunarUI.HideBlizzardBarsDelayed()

            -- HideFrameSafely 應設定 EnableKeyboard(false)
            assert.is_false(artFrame.LeftEndCap._keyboardEnabled)

            LunarUI.RestoreBlizzardBars()

            -- restore 應還原 EnableKeyboard(true)
            assert.is_true(artFrame.LeftEndCap._keyboardEnabled)
        end)

        it("延遲 timer 在 restore 後不再執行 hide", function()
            -- 捕捉所有 C_Timer.After 回呼
            local pendingCallbacks = {}
            _G.C_Timer.After = function(_, fn)
                table.insert(pendingCallbacks, fn)
            end

            LunarUI.HideBlizzardBarsDelayed()
            -- 此時有 2 個延遲回呼等待執行

            -- Restore 前先重置狀態
            LunarUI.RestoreBlizzardBars()
            assert.are.equal(multiBarOriginalParent, multiBar1._parent)

            -- 模擬延遲 timer 觸發（restore 後的 generation 應使回呼跳過）
            for _, cb in ipairs(pendingCallbacks) do
                cb()
            end

            -- parent 應仍為原始值（timer 回呼被 generation guard 跳過）
            assert.are.equal(multiBarOriginalParent, multiBar1._parent)

            -- 清理：還原 C_Timer.After
            _G.C_Timer.After = function() end
        end)

        it("restore 在戰鬥中不執行", function()
            LunarUI.HideBlizzardBarsDelayed()

            -- 模擬戰鬥中
            local savedInCombat = _G.InCombatLockdown
            _G.InCombatLockdown = function()
                return true
            end

            LunarUI.RestoreBlizzardBars()

            -- 應該沒還原（仍在隱藏狀態）
            assert.is_not.equal(multiBarOriginalParent, multiBar1._parent)

            -- 結束戰鬥
            _G.InCombatLockdown = savedInCombat

            -- 現在可以還原
            LunarUI.RestoreBlizzardBars()
            assert.are.equal(multiBarOriginalParent, multiBar1._parent)
        end)
    end)

    describe("taint filter lifecycle", function()
        it("Install/Uninstall 後 UIParent 事件正確還原", function()
            -- 保存 UIParent 事件 mock 狀態
            local blockedUnregistered = false
            local blockedRegistered = false
            _G.UIParent.UnregisterEvent = function(_, event)
                if event == "ADDON_ACTION_BLOCKED" then
                    blockedUnregistered = true
                end
            end
            _G.UIParent.RegisterEvent = function(_, event)
                if event == "ADDON_ACTION_BLOCKED" then
                    blockedRegistered = true
                end
            end

            LunarUI.HideBlizzardBarsDelayed()
            assert.is_true(blockedUnregistered, "ADDON_ACTION_BLOCKED should be unregistered")

            LunarUI.RestoreBlizzardBars()
            assert.is_true(blockedRegistered, "ADDON_ACTION_BLOCKED should be re-registered after restore")

            -- 還原 mock
            _G.UIParent.UnregisterEvent = function() end
            _G.UIParent.RegisterEvent = function() end
        end)

        it("taint filter 延遲 timer 在 Restore 後不回魂", function()
            local taintTimerCallbacks = {}
            _G.C_Timer.After = function(_delay, fn)
                taintTimerCallbacks[#taintTimerCallbacks + 1] = fn
            end

            LunarUI.HideBlizzardBarsDelayed()
            local timerCount = #taintTimerCallbacks
            assert.is_true(timerCount > 0, "Should have pending taint filter timers")

            LunarUI.RestoreBlizzardBars()

            -- 觸發所有 timer — 世代已遞增，不應報錯或重新啟用
            for _, cb in ipairs(taintTimerCallbacks) do
                assert.has_no_errors(cb)
            end

            _G.C_Timer.After = function() end
        end)

        it("5 次 off/on 循環不報錯", function()
            for _ = 1, 5 do
                assert.has_no_errors(function()
                    LunarUI.HideBlizzardBarsDelayed()
                end)
                assert.has_no_errors(function()
                    LunarUI.RestoreBlizzardBars()
                end)
            end
        end)
    end)
end)
