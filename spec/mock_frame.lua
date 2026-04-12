---@diagnostic disable: inject-field, undefined-field, undefined-global, need-check-nil, param-type-mismatch, assign-type-mismatch, missing-parameter, unused, global-in-non-module, access-invisible, duplicate-set-field, redundant-parameter, return-type-mismatch
--[[
    Shared MockFrame for busted tests
    Provides a complete WoW Frame mock with all methods used across spec files.
    Specs that need custom behavior should override methods on their local instances.

    Usage:
        local mock_frame = require("spec.mock_frame")
        -- _G.CreateFrame and _G.UIParent are set automatically on require

        -- Override for custom behavior in specific tests:
        local myFrame = CreateFrame()
        function myFrame:IsShown() return false end
]]

local MockFrame = {}
MockFrame.__index = MockFrame

--------------------------------------------------------------------------------
-- Geometry & Layout
--------------------------------------------------------------------------------

function MockFrame:SetSize() end
function MockFrame:SetWidth() end
function MockFrame:SetHeight() end
function MockFrame:SetPoint() end
function MockFrame:ClearAllPoints() end
function MockFrame:SetAllPoints() end
function MockFrame:SetScale() end
function MockFrame:GetScale()
    return 1.0
end

function MockFrame:GetWidth()
    return 200
end
function MockFrame:GetHeight()
    return 100
end
function MockFrame:GetNumPoints()
    return 0
end
function MockFrame:GetPoint()
    return "CENTER", nil, "CENTER", 0, 0
end
function MockFrame:GetEffectiveScale()
    return 1
end

--------------------------------------------------------------------------------
-- Frame hierarchy & strata
--------------------------------------------------------------------------------

function MockFrame:SetFrameStrata() end
function MockFrame:SetFrameLevel() end
function MockFrame:SetParent() end

function MockFrame:GetFrameLevel()
    return 1
end
function MockFrame:GetName()
    return "MockFrame"
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

function MockFrame:Show() end
function MockFrame:Hide() end

function MockFrame:IsShown()
    return true
end

--------------------------------------------------------------------------------
-- Interactivity
--------------------------------------------------------------------------------

function MockFrame:SetMovable() end
function MockFrame:SetResizable() end
function MockFrame:EnableMouse() end
function MockFrame:EnableMouseWheel() end
function MockFrame:EnableKeyboard() end
function MockFrame:RegisterForDrag() end
function MockFrame:RegisterForClicks() end
function MockFrame:SetClampedToScreen() end
function MockFrame:SetPropagateKeyboardInput() end
function MockFrame:SetHitRectInsets() end
function MockFrame:StartMoving() end
function MockFrame:StartSizing() end
function MockFrame:StopMovingOrSizing() end

function MockFrame:IsMouseOver()
    return false
end
function MockFrame:IsObjectType()
    return false
end

--------------------------------------------------------------------------------
-- Scripting & Events
--------------------------------------------------------------------------------

function MockFrame:SetScript(name, fn)
    if not rawget(self, "_scripts") then
        rawset(self, "_scripts", {})
    end
    self._scripts[name] = fn
end

function MockFrame:HookScript(name, fn)
    if not rawget(self, "_scripts") then
        rawset(self, "_scripts", {})
    end
    local old = self._scripts[name]
    if old then
        self._scripts[name] = function(...)
            old(...)
            fn(...)
        end
    else
        self._scripts[name] = fn
    end
end

function MockFrame:GetScript(name)
    local s = rawget(self, "_scripts")
    return s and s[name]
end

function MockFrame:RegisterEvent() end
function MockFrame:UnregisterEvent() end
function MockFrame:UnregisterAllEvents() end
function MockFrame:SetAttribute() end
function MockFrame:GetAttribute() end

--------------------------------------------------------------------------------
-- Appearance - Texture & Color
--------------------------------------------------------------------------------

function MockFrame:SetTexture() end
function MockFrame:SetTexCoord() end
function MockFrame:SetBlendMode() end
function MockFrame:SetVertexColor() end
function MockFrame:SetColorTexture() end
function MockFrame:SetGradient() end
function MockFrame:SetDrawLayer() end
function MockFrame:SetSnapToPixelGrid() end
function MockFrame:SetTexelSnappingBias() end
function MockFrame:SetMaskTexture() end
function MockFrame:SetNormalTexture() end
function MockFrame:SetPushedTexture() end
function MockFrame:SetHighlightTexture() end
function MockFrame:SetPinScale() end

function MockFrame:SetAlpha() end

function MockFrame:GetAlpha()
    return 1
end

--------------------------------------------------------------------------------
-- Backdrop
--------------------------------------------------------------------------------

function MockFrame:SetBackdrop() end
function MockFrame:SetBackdropColor() end
function MockFrame:SetBackdropBorderColor() end

--------------------------------------------------------------------------------
-- Text
--------------------------------------------------------------------------------

function MockFrame:SetText() end
function MockFrame:SetFormattedText() end
function MockFrame:SetTextColor() end
function MockFrame:SetFont() end
function MockFrame:SetShadowOffset() end
function MockFrame:SetJustifyH() end
function MockFrame:SetWordWrap() end
function MockFrame:SetMultiLine() end
function MockFrame:SetMaxLetters() end
function MockFrame:SetAutoFocus() end
function MockFrame:SetFocus() end
function MockFrame:HighlightText() end

function MockFrame:GetFont()
    return "Fonts\\FRIZQT__.TTF", 12, ""
end

--------------------------------------------------------------------------------
-- StatusBar
--------------------------------------------------------------------------------

function MockFrame:SetMinMaxValues() end
function MockFrame:SetValue() end
function MockFrame:SetStatusBarTexture() end
function MockFrame:SetStatusBarColor() end
function MockFrame:GetStatusBarTexture()
    return self
end
function MockFrame:SetOrientation() end

--------------------------------------------------------------------------------
-- Cooldown
--------------------------------------------------------------------------------

function MockFrame:SetCooldown() end
function MockFrame:SetDrawEdge() end
function MockFrame:SetSwipeColor() end
function MockFrame:SetHideCountdownNumbers() end

--------------------------------------------------------------------------------
-- Animation
--------------------------------------------------------------------------------

function MockFrame:SetFromAlpha() end
function MockFrame:SetToAlpha() end
function MockFrame:SetDuration() end
function MockFrame:SetOrder() end
function MockFrame:Play() end

--------------------------------------------------------------------------------
-- Chat Frame specific
--------------------------------------------------------------------------------

function MockFrame:GetNumMessages()
    return 0
end
function MockFrame:GetMessageInfo()
    return nil
end
function MockFrame:SetScrollChild() end

--------------------------------------------------------------------------------
-- Minimap specific
--------------------------------------------------------------------------------

function MockFrame:SetArchBlobRingScalar() end
function MockFrame:SetArchBlobRingAlpha() end
function MockFrame:SetQuestBlobRingScalar() end
function MockFrame:SetQuestBlobRingAlpha() end
function MockFrame:SetArchBlobInsideTexture() end
function MockFrame:SetArchBlobOutsideTexture() end
function MockFrame:SetQuestBlobInsideTexture() end
function MockFrame:SetQuestBlobOutsideTexture() end

function MockFrame:GetChildren()
    return -- 零 varargs，與 WoW API 一致（非 return nil）
end
function MockFrame:GetRegions()
    return
end

--------------------------------------------------------------------------------
-- Child creation（return new MockFrame instances）
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- Module exports
--------------------------------------------------------------------------------

local M = {}

M.MockFrame = MockFrame

-- Create a new MockFrame instance
function M.newFrame()
    return setmetatable({}, { __index = MockFrame })
end

-- Set globals（safe to call multiple times）
_G.CreateFrame = function()
    return M.newFrame()
end
_G.UIParent = M.newFrame()

return M
