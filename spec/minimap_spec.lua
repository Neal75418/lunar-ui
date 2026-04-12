---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Unit tests for LunarUI/Modules/Minimap.lua
    Tests lifecycle, coordinate helpers, cleanup
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs（wow_mock.lua 已提供 GetTime/InCombatLockdown/IsShiftKeyDown 預設值）
_G.GetZoneText = function()
    return "Stormwind"
end
_G.GetSubZoneText = function()
    return "Trade District"
end
_G.GetGameTime = function()
    return 14, 30
end
_G.GetInstanceInfo = function()
    return "Stormwind", "none", 0
end
_G.GetDifficultyInfo = function()
    return "Normal"
end
_G.HasNewMail = function()
    return false
end
_G.hooksecurefunc = function() end
_G.C_PvP = {
    GetZonePVPInfo = function()
        return "friendly"
    end,
}
_G.C_Map = {
    GetBestMapForUnit = function()
        return 84
    end,
    GetPlayerMapPosition = function()
        return {
            GetXY = function()
                return 0.5, 0.5
            end,
        }
    end,
}
_G.C_Timer = {
    After = function() end,
    NewTimer = function()
        return { Cancel = function() end }
    end,
}
_G.C_Calendar = { OpenCalendar = function() end }
_G.Minimap_ZoomIn = function() end
_G.Minimap_ZoomOut = function() end
_G.ToggleDropDownMenu = function() end

local mock_frame = require("spec.mock_frame")
local MockFrame = mock_frame.MockFrame
_G.Minimap = setmetatable({}, { __index = MockFrame })
_G.MinimapBackdrop = setmetatable({}, { __index = MockFrame })
_G.MinimapCluster = nil -- not present in test
_G.MiniMapTracking = nil
_G.MiniMapTrackingBackground = nil
_G.GameTimeFrame = setmetatable({}, { __index = MockFrame })
_G.AddonCompartmentFrame = setmetatable({}, { __index = MockFrame })
_G.QueueStatusMinimapButton = setmetatable({}, { __index = MockFrame })
_G.ExpansionLandingPageMinimapButton = nil
_G.MiniMapMailFrame = setmetatable({}, { __index = MockFrame })
_G.MinimapZoomIn = setmetatable({}, { __index = MockFrame })
_G.MinimapZoomOut = setmetatable({}, { __index = MockFrame })
_G.HybridMinimap = nil
_G.GetMinimapShape = function()
    return "ROUND"
end
_G.GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    Show = function() end,
    Hide = function() end,
}

local LunarUI = {
    Colors = {
        bg = { 0.05, 0.05, 0.05 },
        border = { 0.3, 0.3, 0.4 },
        bgIcon = { 0, 0, 0, 0.8 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    backdropTemplate = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetSelectedFont = function()
        return "Fonts\\FRIZQT__.TTF"
    end,
    FormatCoordinates = function(x, y)
        return string.format("%.1f, %.1f", x, y)
    end,
    FormatGameTime = function(h, m)
        return string.format("%02d:%02d", h, m)
    end,
    SafeCall = function(fn)
        fn()
    end,
    RegisterHUDFrame = function() end,
    RegisterMovableFrame = function() end,
    RegisterModule = function() end,
    Print = function() end,
    db = {
        profile = {
            minimap = {
                enabled = true,
                size = 180,
                showCoords = true,
                showClock = true,
                organizeButtons = true,
                zoneTextDisplay = "SHOW",
                borderColor = { r = 0.15, g = 0.12, b = 0.08, a = 1 },
            },
        },
    },
}
LunarUI.GetModuleDB = function(key)
    if not LunarUI.db or not LunarUI.db.profile then
        return nil
    end
    return LunarUI.db.profile[key]
end

-- Load ButtonCorral sub-module before main Minimap module (mirrors TOC order)
loader.loadAddonFile("LunarUI/Modules/Minimap/ButtonCorral.lua", LunarUI)
loader.loadAddonFile("LunarUI/Modules/Minimap.lua", LunarUI)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

describe("Minimap lifecycle", function()
    -- 每個測試前先清理狀態，確保 isInitialized 重置
    before_each(function()
        LunarUI.CleanupMinimap()
    end)

    -- Minimap exports（assert.is_function）已移除，行為由下方測試隱含驗證

    it("InitializeMinimap does not error", function()
        assert.has_no_errors(function()
            LunarUI.InitializeMinimap()
        end)
    end)

    it("CleanupMinimap does not error after Init", function()
        LunarUI.InitializeMinimap()
        assert.has_no_errors(function()
            LunarUI.CleanupMinimap()
        end)
    end)

    it("CleanupMinimap does not error when not initialized", function()
        -- before_each 已呼叫 CleanupMinimap，確保此時 isInitialized = false
        assert.has_no_errors(function()
            LunarUI.CleanupMinimap()
        end)
    end)

    it("RefreshMinimap skips gracefully when not initialized", function()
        -- before_each 重置後未呼叫 Init，isInitialized = false
        assert.has_no_errors(function()
            LunarUI.RefreshMinimap()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Config Guard
--------------------------------------------------------------------------------

describe("Minimap config guard", function()
    it("does not init when db is nil", function()
        local saved = LunarUI.db
        LunarUI.db = nil
        -- Load fresh instance
        local testLunarUI = {
            Colors = LunarUI.Colors,
            ICON_TEXCOORD = LunarUI.ICON_TEXCOORD,
            backdropTemplate = LunarUI.backdropTemplate,
            ApplyBackdrop = function() end,
            SetFont = function() end,
            GetSelectedFont = LunarUI.GetSelectedFont,
            FormatCoordinates = LunarUI.FormatCoordinates,
            FormatGameTime = LunarUI.FormatGameTime,
            SafeCall = LunarUI.SafeCall,
            RegisterHUDFrame = function() end,
            RegisterMovableFrame = function() end,
            RegisterModule = function() end,
            Print = function() end,
            GetModuleDB = function()
                return nil
            end,
            db = nil,
        }
        loader.loadAddonFile("LunarUI/Modules/Minimap.lua", testLunarUI)
        assert.has_no_errors(function()
            testLunarUI.InitializeMinimap()
        end)
        LunarUI.db = saved
    end)

    it("does not init when minimap is disabled", function()
        local testLunarUI = {
            Colors = LunarUI.Colors,
            ICON_TEXCOORD = LunarUI.ICON_TEXCOORD,
            backdropTemplate = LunarUI.backdropTemplate,
            ApplyBackdrop = function() end,
            SetFont = function() end,
            GetSelectedFont = LunarUI.GetSelectedFont,
            FormatCoordinates = LunarUI.FormatCoordinates,
            FormatGameTime = LunarUI.FormatGameTime,
            SafeCall = LunarUI.SafeCall,
            RegisterHUDFrame = function() end,
            RegisterMovableFrame = function() end,
            RegisterModule = function() end,
            Print = function() end,
            db = { profile = { minimap = { enabled = false } } },
        }
        testLunarUI.GetModuleDB = function(key)
            if not testLunarUI.db or not testLunarUI.db.profile then
                return nil
            end
            return testLunarUI.db.profile[key]
        end
        loader.loadAddonFile("LunarUI/Modules/Minimap.lua", testLunarUI)
        assert.has_no_errors(function()
            testLunarUI.InitializeMinimap()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Restore 對稱性（需要完整 MinimapCluster mock）
--------------------------------------------------------------------------------

describe("Minimap restore symmetry", function()
    -- 用 stateful mock 追蹤 Init 時的 mutation 和 Cleanup 後的 restore
    local statefulMinimap, statefulCluster, statefulBackdrop, statefulZoomIn, statefulZoomOut

    -- 建立追蹤狀態的 mock
    local function StatefulFrame(name)
        local f = setmetatable({}, { __index = MockFrame })
        f._name = name
        f._alpha = 1
        f._visible = true
        f._parent = nil
        f._mouseEnabled = true
        f._maskTexture = nil
        f._mouseWheelEnabled = false
        f._children = {}
        f._regions = {}
        function f:GetName()
            return self._name
        end
        function f:SetAlpha(a)
            self._alpha = a
        end
        function f:GetAlpha()
            return self._alpha
        end
        function f:Show()
            self._visible = true
        end
        function f:Hide()
            self._visible = false
        end
        function f:IsShown()
            return self._visible
        end
        function f:SetParent(p)
            self._parent = p
        end
        function f:GetParent()
            return self._parent
        end
        function f:EnableMouse(v)
            self._mouseEnabled = v
        end
        function f:EnableMouseWheel(v)
            self._mouseWheelEnabled = v
        end
        function f:SetMaskTexture(t)
            self._maskTexture = t
        end
        function f:GetMaskTexture()
            return self._maskTexture
        end
        function f:IsMouseWheelEnabled()
            return self._mouseWheelEnabled
        end
        function f:IsMouseEnabled()
            return self._mouseEnabled
        end
        function f:GetTexture()
            return self._maskTexture -- reuse for HybridMinimap CircleMask
        end
        function f:GetChildren()
            return unpack(self._children)
        end
        function f:GetRegions()
            return unpack(self._regions)
        end
        return f
    end

    before_each(function()
        -- 建立 stateful mocks
        statefulMinimap = StatefulFrame("Minimap")
        statefulCluster = StatefulFrame("MinimapCluster")
        statefulBackdrop = StatefulFrame("MinimapBackdrop")
        statefulZoomIn = StatefulFrame("MinimapZoomIn")
        statefulZoomOut = StatefulFrame("MinimapZoomOut")

        -- 設定 Blizzard 預設狀態
        statefulMinimap._parent = statefulCluster
        statefulMinimap._maskTexture = "Textures\\MinimapMask"
        statefulCluster._alpha = 1
        statefulCluster._mouseEnabled = true
        statefulCluster._visible = true
        statefulBackdrop._alpha = 1
        statefulBackdrop._visible = true
        statefulZoomIn._alpha = 1
        statefulZoomIn._visible = true
        statefulZoomOut._alpha = 1
        statefulZoomOut._visible = true

        -- 注入全域
        _G.Minimap = statefulMinimap
        _G.MinimapCluster = statefulCluster
        _G.MinimapBackdrop = statefulBackdrop
        _G.MinimapZoomIn = statefulZoomIn
        _G.MinimapZoomOut = statefulZoomOut
    end)

    it("CleanupMinimap 還原 Minimap parent 到 MinimapCluster", function()
        -- Init 會改變 parent 到 minimapFrame
        LunarUI.InitializeMinimap()
        -- parent 應該不再是 MinimapCluster
        assert.is_not.equal(statefulCluster, statefulMinimap._parent)

        -- Cleanup 應還原
        LunarUI.CleanupMinimap()
        assert.are.equal(statefulCluster, statefulMinimap._parent)
    end)

    it("CleanupMinimap 還原 MinimapCluster 可見性", function()
        LunarUI.InitializeMinimap()
        -- Init 隱藏 MinimapCluster
        assert.are.equal(0, statefulCluster._alpha)

        LunarUI.CleanupMinimap()
        -- Cleanup 應還原
        assert.are.equal(1, statefulCluster._alpha)
        assert.is_true(statefulCluster._mouseEnabled)
        assert.is_true(statefulCluster._visible)
    end)

    it("CleanupMinimap 還原方形遮罩為圓形", function()
        LunarUI.InitializeMinimap()
        -- Init 設定方形遮罩
        assert.are.equal("Interface\\BUTTONS\\WHITE8X8", statefulMinimap._maskTexture)

        LunarUI.CleanupMinimap()
        -- Cleanup 應還原圓形遮罩
        assert.are.equal("Textures\\MinimapMask", statefulMinimap._maskTexture)
    end)

    it("CleanupMinimap 還原 Minimap.Layout", function()
        LunarUI.InitializeMinimap()
        -- Init 覆蓋 Layout 為 no-op
        assert.is_function(statefulMinimap.Layout)

        LunarUI.CleanupMinimap()
        -- Cleanup 應移除覆蓋（nil = 讓 Blizzard 接管）
        assert.is_nil(rawget(statefulMinimap, "Layout"))
    end)

    it("CleanupMinimap 還原 MinimapBackdrop 和縮放按鈕", function()
        LunarUI.InitializeMinimap()
        -- Init 隱藏裝飾
        assert.are.equal(0, statefulBackdrop._alpha)
        assert.are.equal(0, statefulZoomIn._alpha)
        assert.are.equal(0, statefulZoomOut._alpha)

        LunarUI.CleanupMinimap()
        -- Cleanup 應還原
        assert.are.equal(1, statefulBackdrop._alpha)
        assert.is_true(statefulBackdrop._visible)
        assert.are.equal(1, statefulZoomIn._alpha)
        assert.is_true(statefulZoomIn._visible)
        assert.are.equal(1, statefulZoomOut._alpha)
        assert.is_true(statefulZoomOut._visible)
    end)

    it("CleanupMinimap 還原 EnableMouseWheel", function()
        LunarUI.InitializeMinimap()
        -- Init 啟用滑鼠滾輪
        assert.is_true(statefulMinimap._mouseWheelEnabled)

        LunarUI.CleanupMinimap()
        -- Cleanup 應還原（Blizzard 預設關閉）
        assert.is_false(statefulMinimap._mouseWheelEnabled)
    end)

    it("Init → Cleanup → Init → Cleanup 多次循環不累積", function()
        for _ = 1, 3 do
            LunarUI.InitializeMinimap()
            assert.are.equal(0, statefulCluster._alpha)
            assert.are.equal("Interface\\BUTTONS\\WHITE8X8", statefulMinimap._maskTexture)

            LunarUI.CleanupMinimap()
            assert.are.equal(1, statefulCluster._alpha)
            assert.are.equal("Textures\\MinimapMask", statefulMinimap._maskTexture)
            assert.are.equal(statefulCluster, statefulMinimap._parent)
        end
    end)

    it("HookScript 不累積：多次 Init/Cleanup 後只安裝一次", function()
        local hookCount = 0
        local origHookScript = statefulMinimap.HookScript
        function statefulMinimap:HookScript(event, _fn)
            if event == "OnMouseWheel" or event == "OnMouseUp" then
                hookCount = hookCount + 1
            end
            -- 呼叫原始方法（MockFrame 的 no-op）
            if origHookScript then
                origHookScript(self, event, _fn)
            end
        end

        -- 第一次 Init 應安裝 hook
        LunarUI.InitializeMinimap()
        local firstCount = hookCount
        assert.is_true(firstCount > 0)

        LunarUI.CleanupMinimap()

        -- 第二次 Init 不應再安裝新 hook
        LunarUI.InitializeMinimap()
        assert.are.equal(firstCount, hookCount)

        LunarUI.CleanupMinimap()

        -- 第三次 Init 同樣不應累積
        LunarUI.InitializeMinimap()
        assert.are.equal(firstCount, hookCount)

        LunarUI.CleanupMinimap()
    end)

    -- 測試後還原全域（避免影響其他 describe）
    after_each(function()
        _G.Minimap = setmetatable({}, { __index = MockFrame })
        _G.MinimapCluster = nil
        _G.MinimapBackdrop = setmetatable({}, { __index = MockFrame })
        _G.MinimapZoomIn = setmetatable({}, { __index = MockFrame })
        _G.MinimapZoomOut = setmetatable({}, { __index = MockFrame })
    end)
end)
