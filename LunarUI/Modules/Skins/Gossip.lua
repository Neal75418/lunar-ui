---@diagnostic disable: unbalanced-assignments, undefined-field, inject-field, param-type-mismatch, assign-type-mismatch, redundant-parameter, cast-local-type
--[[
    LunarUI - Skin: Gossip Frame
    Reskin GossipFrame (NPC 對話介面) with LunarUI theme
]]

local _ADDON_NAME, Engine = ...
local LunarUI = Engine.LunarUI

local function SkinGossip()
    local frame = LunarUI:SkinStandardFrame("GossipFrame", {
        textDepth = 4,
        noStrip = true,  -- 保留羊皮紙內容背景，避免黑底蓋住對話文字
    })
    if not frame then return end

    -- 標題文字 fallback
    if not frame.TitleText and _G.GossipFrameTitleText then
        LunarUI.SetFontLight(_G.GossipFrameTitleText)
    end

    -- 關閉按鈕 fallback
    if not frame.CloseButton and _G.GossipFrameCloseButton then
        LunarUI.SkinCloseButton(_G.GossipFrameCloseButton)
    end

    -- Greeting 面板 / 再見按鈕 / NPC 模型區域
    -- noStrip 模式：保留原始外觀，不對子元件做 SkinButton / StripTextures

    -- 對話文字（重要！NPC 說的話）
    if _G.GossipGreetingText then
        LunarUI.SetFontLight(_G.GossipGreetingText)
    end

    -- 對話選項按鈕（WoW 12.0 使用 ScrollFrame）
    if frame.GreetingPanel and frame.GreetingPanel.ScrollBox then
        -- 防止重複 hook
        if frame.GreetingPanel.ScrollBox._lunarHooked then return end
        frame.GreetingPanel.ScrollBox._lunarHooked = true

        -- 對於每個對話選項，需要 hook 來處理動態內容
        hooksecurefunc(frame.GreetingPanel.ScrollBox, "Update", function(self)
            local n = select("#", self:GetChildren())
            if n > 0 then
                local children = { self:GetChildren() }
                for i = 1, n do
                    local child = children[i]
                    if child then
                        -- 確保選項文字可讀
                        LunarUI:SkinFrameText(child, 1)
                    end
                end
            end
        end)
    end
    return true
end

-- GossipFrame 在 PLAYER_ENTERING_WORLD 時已存在
LunarUI.RegisterSkin("gossip", "PLAYER_ENTERING_WORLD", SkinGossip)
