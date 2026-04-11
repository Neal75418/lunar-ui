---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type, need-check-nil, return-type-mismatch
--[[
    LunarUI - Skin: Housing Frames
    Reskin WoW 12.0 家園系統相關 UI with LunarUI theme
    Housing 內建於核心 UI（非 LoadOnDemand addon），使用 PLAYER_ENTERING_WORLD 觸發
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinHousingFrames()
    local skinned = false

    -- 照片分享框架
    local photoFrame = LunarUI:SkinStandardFrame("HousingPhotoSharingFrame")
    if photoFrame then
        skinned = true
    end

    -- 照片瀏覽器
    local browser = LunarUI:SkinStandardFrame("HousingPhotoSharingBrowser")
    if browser then
        skinned = true
    end

    -- 頂部橫幅（裝飾性框架，無標題列/關閉按鈕，不適用 SkinStandardFrame）
    local banner = _G["HousingTopBannerFrame"]
    if banner and LunarUI.MarkSkinned(banner) then
        LunarUI.StripTextures(banner)
        skinned = true
    end

    return skinned
end

-- Housing 內建於核心 UI，不是 LoadOnDemand addon
LunarUI.RegisterSkin("housing", "PLAYER_ENTERING_WORLD", SkinHousingFrames)
