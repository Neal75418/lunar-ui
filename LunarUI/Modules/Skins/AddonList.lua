---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Addon List
    Reskin AddonList (插件列表) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinAddonList()
    local frame = LunarUI:SkinStandardFrame("AddonList")
    if not frame then
        return
    end

    -- 底部按鈕
    if _G.AddonListOkayButton then
        LunarUI.SkinButton(_G.AddonListOkayButton)
    end
    if _G.AddonListCancelButton then
        LunarUI.SkinButton(_G.AddonListCancelButton)
    end
    if _G.AddonListEnableAllButton then
        LunarUI.SkinButton(_G.AddonListEnableAllButton)
    end
    if _G.AddonListDisableAllButton then
        LunarUI.SkinButton(_G.AddonListDisableAllButton)
    end

    -- 下拉選單按鈕（角色篩選）
    if frame.Dropdown then
        LunarUI.SkinButton(frame.Dropdown)
    end

    return true
end

-- AddonList 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI.RegisterSkin("addonlist", "PLAYER_ENTERING_WORLD", SkinAddonList)
