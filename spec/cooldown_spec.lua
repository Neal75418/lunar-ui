--[[
    Unit tests for LunarUI/HUD/CooldownTracker.lua
    Tests FormatCooldown, GetSpellTexture cache, GetSpellCooldownInfo,
    IsSpellKnownByPlayer, AddTrackedSpell, RemoveTrackedSpell,
    Show/Hide/Cleanup functions
]]

require("spec.wow_mock")
local loader = require("spec.loader")

-- Mock WoW APIs needed by CooldownTracker
_G.GetTime = function()
    return 1000
end
_G.UnitClass = function()
    return "Warrior", "WARRIOR", 1
end
_G.IsPlayerSpell = function()
    return false
end
_G.InCombatLockdown = function()
    return false
end
_G.IsShiftKeyDown = function()
    return false
end
_G.C_Timer = { After = function() end }

-- Mock C_Spell
_G.C_Spell = {
    GetSpellCooldown = function(spellID)
        if spellID == 100 then
            return { startTime = 990, duration = 15 }
        end
        return { startTime = 0, duration = 0 }
    end,
    GetSpellInfo = function(spellID)
        if spellID == 100 then
            return { iconID = 132337 }
        elseif spellID == 999999 then
            return nil
        end
        return { iconID = 100000 + spellID }
    end,
    IsSpellUsable = function(spellID)
        return spellID == 100
    end,
}

-- Mock CreateFrame for cooldown tracker frames
local MockFrame = {}
MockFrame.__index = MockFrame
function MockFrame:SetSize() end
function MockFrame:SetPoint() end
function MockFrame:SetFrameStrata() end
function MockFrame:SetMovable() end
function MockFrame:EnableMouse() end
function MockFrame:RegisterForDrag() end
function MockFrame:SetClampedToScreen() end
function MockFrame:SetScript() end
function MockFrame:SetAllPoints() end
function MockFrame:SetDrawEdge() end
function MockFrame:SetSwipeColor() end
function MockFrame:SetAlpha() end
function MockFrame:SetTexture() end
function MockFrame:SetTexCoord() end
function MockFrame:SetBlendMode() end
function MockFrame:SetTextColor() end
function MockFrame:SetText() end
function MockFrame:SetFromAlpha() end
function MockFrame:SetToAlpha() end
function MockFrame:SetDuration() end
function MockFrame:SetOrder() end
function MockFrame:Play() end
function MockFrame:ClearAllPoints() end
function MockFrame:SetWidth() end
function MockFrame:StartMoving() end
function MockFrame:StopMovingOrSizing() end
function MockFrame:Hide() end
function MockFrame:Show() end
function MockFrame:IsShown()
    return true
end
function MockFrame:SetCooldown() end
function MockFrame:CreateTexture()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:CreateFontString()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:CreateAnimationGroup()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:CreateAnimation()
    return setmetatable({}, { __index = MockFrame })
end
function MockFrame:SetBackdrop() end
function MockFrame:SetBackdropColor() end
function MockFrame:SetBackdropBorderColor() end

_G.CreateFrame = function()
    return setmetatable({}, { __index = MockFrame })
end
_G.UIParent = setmetatable({}, { __index = MockFrame })

local LunarUI = {
    Colors = {
        bgIcon = { 0, 0, 0, 0.8 },
        borderIcon = { 0.3, 0.3, 0.4, 1 },
    },
    ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 },
    textures = { glow = "Interface\\glow" },
    ApplyBackdrop = function() end,
    SetFont = function() end,
    GetHUDSetting = function(_key, default)
        return default
    end,
    RegisterHUDFrame = function() end,
    RegisterMovableFrame = function() end,
    iconBackdropTemplate = {},
    GetSelectedStatusBarTexture = function()
        return "Interface\\StatusBar"
    end,
    RegisterModule = function() end,
    CreateEventHandler = function(_events, _callback)
        return setmetatable({
            _events = {},
            _scripts = {},
            RegisterEvent = function(self, e)
                self._events[e] = true
            end,
            SetScript = function(self, name, fn)
                self._scripts[name] = fn
            end,
            UnregisterAllEvents = function() end,
        }, {})
    end,
}

loader.loadAddonFile("LunarUI/HUD/CooldownTracker.lua", LunarUI)

--------------------------------------------------------------------------------
-- FormatCooldown
--------------------------------------------------------------------------------

describe("FormatCooldown", function()
    it("formats >= 60 seconds as minutes", function()
        assert.equals("2m", LunarUI.FormatCooldown(120))
        assert.equals("1m", LunarUI.FormatCooldown(60))
        assert.equals("2m", LunarUI.FormatCooldown(61))
    end)

    it("formats 10-59 seconds as integer", function()
        assert.equals("30", LunarUI.FormatCooldown(30))
        assert.equals("10", LunarUI.FormatCooldown(10))
        assert.equals("59", LunarUI.FormatCooldown(59.9))
    end)

    it("formats < 10 seconds with one decimal", function()
        assert.equals("5.0", LunarUI.FormatCooldown(5.0))
        assert.equals("0.5", LunarUI.FormatCooldown(0.5))
        assert.equals("9.9", LunarUI.FormatCooldown(9.9))
    end)
end)

--------------------------------------------------------------------------------
-- GetSpellCooldownInfo
--------------------------------------------------------------------------------

describe("GetSpellCooldownInfo", function()
    it("returns start and duration for known spell", function()
        local start, duration = LunarUI.GetSpellCooldownInfo(100)
        assert.equals(990, start)
        assert.equals(15, duration)
    end)

    it("returns 0,0 for unknown spell", function()
        local start, duration = LunarUI.GetSpellCooldownInfo(99999)
        assert.equals(0, start)
        assert.equals(0, duration)
    end)

    it("handles C_Spell.GetSpellCooldown error gracefully", function()
        local origFn = _G.C_Spell.GetSpellCooldown
        _G.C_Spell.GetSpellCooldown = function()
            error("API unavailable")
        end
        local start, duration = LunarUI.GetSpellCooldownInfo(100)
        assert.equals(0, start)
        assert.equals(0, duration)
        _G.C_Spell.GetSpellCooldown = origFn
    end)
end)

--------------------------------------------------------------------------------
-- CDGetSpellTexture (cache)
--------------------------------------------------------------------------------

describe("CDGetSpellTexture", function()
    before_each(function()
        LunarUI.ClearSpellTextureCache()
    end)

    it("returns texture for valid spell", function()
        local texture = LunarUI.CDGetSpellTexture(100)
        assert.equals(132337, texture)
    end)

    it("returns nil for invalid spell", function()
        local texture = LunarUI.CDGetSpellTexture(999999)
        assert.is_nil(texture)
    end)

    it("caches results (second call returns from cache)", function()
        local texture1 = LunarUI.CDGetSpellTexture(100)
        -- Modify the API to return different value
        local origFn = _G.C_Spell.GetSpellInfo
        _G.C_Spell.GetSpellInfo = function()
            return { iconID = 999 }
        end
        local texture2 = LunarUI.CDGetSpellTexture(100)
        -- Should still return cached value
        assert.equals(texture1, texture2)
        _G.C_Spell.GetSpellInfo = origFn
    end)

    it("negative caches invalid spells", function()
        LunarUI.CDGetSpellTexture(999999) -- nil result, cached as INVALID
        -- Second call should also return nil without hitting API
        local callCount = 0
        local origFn = _G.C_Spell.GetSpellInfo
        _G.C_Spell.GetSpellInfo = function(id)
            callCount = callCount + 1
            return origFn(id)
        end
        local texture = LunarUI.CDGetSpellTexture(999999)
        assert.is_nil(texture)
        assert.equals(0, callCount) -- should not call API again
        _G.C_Spell.GetSpellInfo = origFn
    end)

    it("returns nil for non-number input", function()
        assert.is_nil(LunarUI.CDGetSpellTexture("not a number"))
        assert.is_nil(LunarUI.CDGetSpellTexture(nil))
    end)

    it("clears cache when max size exceeded", function()
        -- Fill cache beyond limit (CACHE_MAX_SIZE = 2000)
        for i = 1, 2001 do
            LunarUI.CDGetSpellTexture(i)
        end
        -- Cache should have been wiped and repopulated with last entry
        -- Verify it still works
        local texture = LunarUI.CDGetSpellTexture(100)
        assert.equals(132337, texture)
    end)
end)

--------------------------------------------------------------------------------
-- ClearSpellTextureCache
--------------------------------------------------------------------------------

describe("ClearSpellTextureCache", function()
    it("clears the cache", function()
        LunarUI.CDGetSpellTexture(100) -- populate cache
        LunarUI.ClearSpellTextureCache()
        -- After clear, API should be called again
        local callCount = 0
        local origFn = _G.C_Spell.GetSpellInfo
        _G.C_Spell.GetSpellInfo = function(id)
            callCount = callCount + 1
            return origFn(id)
        end
        LunarUI.CDGetSpellTexture(100)
        assert.equals(1, callCount)
        _G.C_Spell.GetSpellInfo = origFn
    end)
end)

--------------------------------------------------------------------------------
-- IsSpellKnownByPlayer
--------------------------------------------------------------------------------

describe("IsSpellKnownByPlayer", function()
    it("returns true when C_Spell.IsSpellUsable returns true", function()
        assert.is_truthy(LunarUI.IsSpellKnownByPlayer(100))
    end)

    it("returns true when IsPlayerSpell returns true", function()
        -- CooldownTracker.lua captures IsPlayerSpell as local upvalue at load time
        -- Need to load a new instance with the mock pre-set
        local origFn = _G.IsPlayerSpell
        _G.IsPlayerSpell = function()
            return true
        end
        local testLunarUI = {
            Colors = LunarUI.Colors,
            ICON_TEXCOORD = LunarUI.ICON_TEXCOORD,
            textures = LunarUI.textures,
            ApplyBackdrop = function() end,
            SetFont = function() end,
            GetHUDSetting = function(_key, default)
                return default
            end,
            RegisterHUDFrame = function() end,
            RegisterMovableFrame = function() end,
            iconBackdropTemplate = {},
            RegisterModule = function() end,
            CreateEventHandler = LunarUI.CreateEventHandler,
        }
        loader.loadAddonFile("LunarUI/HUD/CooldownTracker.lua", testLunarUI)
        assert.is_truthy(testLunarUI.IsSpellKnownByPlayer(99999))
        _G.IsPlayerSpell = origFn
    end)

    it("returns false when neither API returns true", function()
        assert.is_falsy(LunarUI.IsSpellKnownByPlayer(99999))
    end)
end)

--------------------------------------------------------------------------------
-- AddTrackedSpell / RemoveTrackedSpell
--------------------------------------------------------------------------------

describe("AddTrackedSpell", function()
    it("adds a spell ID to tracked list", function()
        -- RefreshCooldownTracker will call SetupTrackedSpells + UpdateCooldownIcons
        -- but we can test AddTrackedSpell directly
        assert.has_no_errors(function()
            LunarUI.AddTrackedSpell(12345)
        end)
    end)

    it("ignores non-number input", function()
        assert.has_no_errors(function()
            LunarUI.AddTrackedSpell("not a number")
            LunarUI.AddTrackedSpell(nil)
        end)
    end)
end)

describe("RemoveTrackedSpell", function()
    it("removes a tracked spell ID", function()
        LunarUI.AddTrackedSpell(54321)
        assert.has_no_errors(function()
            LunarUI.RemoveTrackedSpell(54321)
        end)
    end)

    it("does nothing for non-existent spell", function()
        assert.has_no_errors(function()
            LunarUI.RemoveTrackedSpell(0)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- ShowCooldownTracker / HideCooldownTracker
--------------------------------------------------------------------------------

describe("ShowCooldownTracker", function()
    it("does not error when cooldownFrame is nil", function()
        assert.has_no_errors(function()
            LunarUI.ShowCooldownTracker()
        end)
    end)
end)

describe("HideCooldownTracker", function()
    it("does not error when cooldownFrame is nil", function()
        assert.has_no_errors(function()
            LunarUI.HideCooldownTracker()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- CleanupCooldownTracker
--------------------------------------------------------------------------------

describe("CleanupCooldownTracker", function()
    it("does not error when not initialized", function()
        assert.has_no_errors(function()
            LunarUI.CleanupCooldownTracker()
        end)
    end)
end)

--------------------------------------------------------------------------------
-- RebuildCooldownTracker
--------------------------------------------------------------------------------

describe("RebuildCooldownTracker", function()
    it("does nothing when not initialized", function()
        assert.has_no_errors(function()
            LunarUI.RebuildCooldownTracker()
        end)
    end)

    it("does nothing when in combat lockdown", function()
        local origFn = _G.InCombatLockdown
        _G.InCombatLockdown = function()
            return true
        end
        assert.has_no_errors(function()
            LunarUI.RebuildCooldownTracker()
        end)
        _G.InCombatLockdown = origFn
    end)
end)
