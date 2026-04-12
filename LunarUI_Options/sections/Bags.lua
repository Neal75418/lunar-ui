--[[
    LunarUI Options - Bags section builder

    這個 section 已遷移到 ctx.toggle/range/select/header/execute factory。
    Factory 內建 nil-safe DB path traversal（見 Options.lua getByPath/setByPath），
    消除 GetDB().x.y 鏈式存取的 NPE 風險。
]]

local _, Private = ...
Private = Private or {}
Private.sections = Private.sections or {}

Private.sections.Bags = function(ctx)
    local L = ctx.L
    local LunarUI = ctx.LunarUI
    local toggle = ctx.toggle
    local range = ctx.range
    local header = ctx.header
    local execute = ctx.execute

    -- RebuildBags 副作用 helper：很多 layout 類選項改動後需要重建背包框架
    local function rebuildBags()
        if LunarUI.RebuildBags then
            LunarUI:RebuildBags()
        end
    end
    local rebuildOnSet = { onValueSet = rebuildBags }

    return {
        order = 7,
        type = "group",
        name = L.bags,
        desc = L.bagsDesc,
        args = {
            enabled = toggle(1, { "bags", "enabled" }, L.enable, nil, {
                width = "full",
                onValueSet = function()
                    LunarUI:Print(L["RequiresReload"] or "需要重新載入介面才能生效")
                end,
            }),
            layoutHeader = header(2, L.layout),
            slotsPerRow = range(3, { "bags", "slotsPerRow" }, L.slotsPerRow, nil, 6, 24, 1, rebuildOnSet),
            slotSize = range(4, { "bags", "slotSize" }, L.slotSize, nil, 28, 48, 1, rebuildOnSet),
            slotSpacing = range(5, { "bags", "slotSpacing" }, L.slotSpacing, nil, 0, 8, 1, rebuildOnSet),
            frameAlpha = range(6, { "bags", "frameAlpha" }, L.backgroundOpacity, nil, 0.3, 1.0, 0.05, {
                isPercent = true,
                onValueSet = rebuildBags,
            }),
            reverseBagSlots = toggle(
                7,
                { "bags", "reverseBagSlots" },
                L.reverseBagSlots,
                L.reverseBagSlotsDesc,
                rebuildOnSet
            ),
            splitBags = toggle(8, { "bags", "splitBags" }, L.splitBags, L.splitBagsDesc, rebuildOnSet),

            displayHeader = header(10, L.display),
            showItemLevel = toggle(11, { "bags", "showItemLevel" }, L.showItemLevel),
            ilvlThreshold = range(12, { "bags", "ilvlThreshold" }, L.ilvlThreshold, L.ilvlThresholdDesc, 1, 600, 1),
            showBindType = toggle(13, { "bags", "showBindType" }, L.showBindType, L.showBindTypeDesc),
            showCooldown = toggle(14, { "bags", "showCooldown" }, L.showCooldowns, L.showCooldownsDesc),
            showNewGlow = toggle(15, { "bags", "showNewGlow" }, L.newItemGlow, L.newItemGlowDesc),
            showQuestItems = toggle(16, { "bags", "showQuestItems" }, L.showQuestItems, L.showQuestItemsDesc),
            showProfessionColors = toggle(
                17,
                { "bags", "showProfessionColors" },
                L.professionBagColors,
                L.professionBagColorsDesc
            ),
            showUpgradeArrow = toggle(18, { "bags", "showUpgradeArrow" }, L.upgradeArrow, L.upgradeArrowDesc),

            behaviorHeader = header(20, L.behavior),
            autoSellJunk = toggle(21, { "bags", "autoSellJunk" }, L.autoSellJunk),
            clearSearchOnClose = toggle(
                22,
                { "bags", "clearSearchOnClose" },
                L.clearSearchOnClose,
                L.clearSearchOnCloseDesc
            ),

            resetPosition = execute(30, L.resetPosition, L.resetPositionDesc, function()
                local bagDb = ctx.GetDB() and ctx.GetDB().bags
                if bagDb then
                    bagDb.bagPosition = nil
                    bagDb.bankPosition = nil
                end
                rebuildBags()
            end),

            -- Bank scrollable viewport (WoW 12.0 character banks can reach
            -- 600+ slots across 6 tabs; fixed viewport + scroll is required).
            -- 傳 default 以保留原先 `or 14` / `~= false` belt-and-suspenders 行為，
            -- 對應非常舊 profile 缺欄位的 edge case（Defaults.lua 已有預設值，
            -- 這是第二層防護）
            bankHeader = header(40, L.bankHeader),
            bankViewportCols = range(
                41,
                { "bags", "bankViewportCols" },
                L.bankViewportCols,
                L.bankViewportColsDesc,
                8,
                20,
                1,
                { onValueSet = rebuildBags, default = 14 }
            ),
            bankViewportRows = range(
                42,
                { "bags", "bankViewportRows" },
                L.bankViewportRows,
                L.bankViewportRowsDesc,
                8,
                20,
                1,
                { onValueSet = rebuildBags, default = 14 }
            ),
            bankDimEmpty = toggle(
                43,
                { "bags", "bankDimEmpty" },
                L.bankDimEmpty,
                L.bankDimEmptyDesc,
                { onValueSet = rebuildBags, default = true }
            ),
        },
    }
end
