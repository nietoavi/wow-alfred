-- Core/Items.lua — Alfred-Enchanting
-- Shared helpers for item actions: chat link, AH search, Wowhead URL popup.
-- Used by the shopping list (in MainPanel) and by the legacy detailed guide
-- (Guide.lua).
local _, A = ...
A.Items = {}

local WOWHEAD_URL_PREFIX = "https://www.wowhead.com/tbc/item="

-- Shared popup for displaying URLs (Ctrl+C to copy, ESC/Enter closes).
StaticPopupDialogs["ALFRED_WOWHEAD_URL"] = {
    text = "Wowhead URL — Ctrl+C to copy",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(self, data)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        if eb and data and data.url then
            eb:SetText(data.url)
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed  = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function A.Items.ShowWowheadURL(itemId)
    if not itemId then return end
    StaticPopup_Show("ALFRED_WOWHEAD_URL", "", "", { url = WOWHEAD_URL_PREFIX .. tostring(itemId) })
end

-- If the AH is open, search for the item. Otherwise, print a hint.
-- itemId is optional; if provided, we ask AHPrices to capture the lowest
-- buyout/unit from the search results so the shopping list can show prices.
--
-- Two search paths:
--   * Blizzard UI active → fill BrowseName + click BrowseSearchButton (visual
--     feedback in the standard Browse tab, and triggers the query).
--   * TSM / Auctionator active → BrowseName is hidden, so we issue
--     QueryAuctionItems directly. Silent but the AUCTION_ITEM_LIST_UPDATE
--     event still fires and AHPrices captures normally.
function A.Items.SearchAH(itemName, itemId)
    if not AuctionFrame or not AuctionFrame:IsShown() then
        print("|cffff9900[Alfred:Enchanting]|r AH not open. Item: |cffffd100" .. tostring(itemName) ..
              "|r (shift+click to link).")
        return
    end
    -- Arm capture BEFORE any query call — both paths can fire AUCTION_ITEM_LIST_UPDATE.
    if itemId and A.AHPrices and A.AHPrices.RequestCapture then
        A.AHPrices.RequestCapture(itemId, itemName)
    end
    -- Respect AH rate limit (TSM/Auctionator scans count too).
    if CanSendAuctionQuery and not CanSendAuctionQuery() then
        print("|cffc8a070[Alfred]|r AH busy (another addon scanning?). Try again in a moment.")
        return
    end
    -- Path A: Blizzard browse UI is visible → use it for visual feedback.
    if BrowseName and BrowseSearchButton and BrowseName:IsVisible() then
        if AuctionFrameTab_OnClick and AuctionFrameTab1 then
            pcall(AuctionFrameTab_OnClick, AuctionFrameTab1)
        end
        BrowseName:SetText(itemName)
        BrowseSearchButton:Click()
        return
    end
    -- Path B: alternative AH UI (TSM, Auctionator, etc.) → silent direct query.
    if QueryAuctionItems then
        QueryAuctionItems(itemName, nil, nil, 0, false, 0, false, false)
    end
end

-- Links the item to chat (via HandleModifiedItemClick if available).
function A.Items.LinkToChat(itemId)
    if not itemId then return end
    local _, link = GetItemInfo(itemId)
    link = link or ("item:" .. tostring(itemId))
    if HandleModifiedItemClick then
        HandleModifiedItemClick(link)
    elseif ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
    end
end

-- Dispatches an action based on mouse button + modifier. Encapsulates the
-- convention:
--   left            → AH search
--   shift + left    → chat link
--   right           → Wowhead URL popup
function A.Items.HandleClick(itemId, itemName, mouseButton)
    if mouseButton == "RightButton" then
        A.Items.ShowWowheadURL(itemId)
    elseif IsShiftKeyDown and IsShiftKeyDown() then
        A.Items.LinkToChat(itemId)
    else
        A.Items.SearchAH(itemName, itemId)
    end
end
