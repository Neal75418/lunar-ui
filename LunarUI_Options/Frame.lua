--[[
    LunarUI Options - AceConfigDialog frame styling
    Extracted from Options.lua in Phase 3 Wave 5.

    Exposes Private.frame.StyleConfigFrame(deps) where `deps` carries all the
    runtime dependencies StyleConfigFrame needs:
      deps.LunarUI           — main addon object (for GetSelectedFont)
      deps.AceConfigDialog   — for looking up OpenFrames["LunarUI"]
      deps.options           — root options table (passed to Search)
      deps.Search            — Private.search namespace (for CreateSearchUI)

    This is cosmetic only (backdrop, title font, gradient, status text, search
    anchor) — zero behavioral coupling with the AceConfig spec.
]]

local _, Private = ...
Private = Private or {}
Private.frame = Private.frame or {}

--- Apply LunarUI visual treatment to the AceConfigDialog "LunarUI" panel.
--- Idempotent — tracked via dialogFrame._lunarStyled.
local function StyleConfigFrame(deps)
    local LunarUI = deps.LunarUI
    local AceConfigDialog = deps.AceConfigDialog
    local options = deps.options
    local Search = deps.Search or {}

    -- 取得 AceConfigDialog 開啟的框架
    local openFrames = AceConfigDialog and AceConfigDialog.OpenFrames
    local aceFrame = openFrames and openFrames["LunarUI"]
    if not aceFrame then
        return
    end

    local dialogFrame = aceFrame.frame
    if not dialogFrame or dialogFrame._lunarStyled then
        return
    end
    dialogFrame._lunarStyled = true

    -- 替換 backdrop 為 LunarUI 風格
    if dialogFrame.SetBackdrop then
        dialogFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        dialogFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
        dialogFrame:SetBackdropBorderColor(0.20, 0.16, 0.30, 1)
    end

    -- 標題字體美化
    if aceFrame.titletext then
        aceFrame.titletext:SetFont(LunarUI.GetSelectedFont(), 15, "OUTLINE")
        aceFrame.titletext:SetTextColor(0.53, 0.51, 1.0)
    end

    -- 頂部漸層裝飾
    local gradient = dialogFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    gradient:SetPoint("TOPLEFT", 1, -1)
    gradient:SetPoint("TOPRIGHT", -1, -1)
    gradient:SetHeight(36)
    gradient:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradient:SetGradient("VERTICAL", CreateColor(0.53, 0.51, 1.0, 0.0), CreateColor(0.53, 0.51, 1.0, 0.06))

    -- 底部狀態文字
    if aceFrame.statustext then
        aceFrame.statustext:SetFont(LunarUI.GetSelectedFont(), 10, "")
        aceFrame.statustext:SetTextColor(0.5, 0.5, 0.5)
    end

    -- 搜尋 UI
    if Search.CreateSearchUI then
        Search.CreateSearchUI(dialogFrame, options, AceConfigDialog)
    end
end

Private.frame.StyleConfigFrame = StyleConfigFrame
