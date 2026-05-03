-- Core/AHPrices.lua — Alfred-Enchanting
-- Auction House price tracking. Listens to AUCTION_ITEM_LIST_UPDATE and
-- passively scans the result page for any item that appears in the active
-- profession's shopping list, recording the lowest buyout per unit.
--
-- Why passive: works regardless of which UI initiated the search. Whether the
-- user clicks one of our shopping rows, types in the Blizzard browse box,
-- runs an Auctionator "Shopping" list, or watches a TSM scan — every result
-- page fires AUCTION_ITEM_LIST_UPDATE, and we read the standard "list" buffer
-- via GetAuctionItemInfo.
--
-- Storage: AlfredDB.prices[realm-faction][itemId] = { copper, ts }.
local _, A = ...
A.AHPrices = {}

-- ============================================================================
-- Storage
-- ============================================================================
local function RealmKey()
    local realm   = (GetRealmName and GetRealmName()) or "Unknown"
    local faction = (UnitFactionGroup and UnitFactionGroup("player")) or "Neutral"
    return realm .. "-" .. faction
end

local function PricesTable()
    if not AlfredDB then return nil end
    AlfredDB.prices = AlfredDB.prices or {}
    local key = RealmKey()
    AlfredDB.prices[key] = AlfredDB.prices[key] or {}
    return AlfredDB.prices[key]
end

-- Returns copper, timestamp (seconds since epoch) for an item id, or nil.
function A.AHPrices.Get(itemId)
    if not itemId then return nil end
    local t = PricesTable()
    if not t then return nil end
    local entry = t[itemId]
    if not entry then return nil end
    return entry.copper, entry.ts
end

function A.AHPrices.Set(itemId, copper)
    if not itemId or not copper or copper <= 0 then return end
    local t = PricesTable()
    if not t then return end
    t[itemId] = { copper = copper, ts = time() }
end

function A.AHPrices.Clear(itemId)
    local t = PricesTable()
    if not t then return end
    if itemId then t[itemId] = nil
    else
        for k in pairs(t) do t[k] = nil end
    end
end

-- Kept as a no-op for back-compat with Items.lua. Capture is now passive.
function A.AHPrices.RequestCapture(itemId, itemName)
    -- intentionally empty
end

-- ============================================================================
-- Passive scan
-- ============================================================================

-- Build a set of item IDs we care about (from the active profession's
-- shopping list). Cheap: ~30 entries, called per AH event.
local function ShoppingListIdSet()
    local set = {}
    local list = A.Profession and A.Profession.shoppingList
    if not list then return set end
    for _, item in ipairs(list) do
        if item.id then set[item.id] = true end
    end
    return set
end

-- Scan the current AH "list" page. For every result whose itemId is in our
-- shopping list, take the lowest buyout per unit and store it.
local function ScanAndUpdate()
    if not GetNumAuctionItems or not GetAuctionItemInfo then return end
    local interesting = ShoppingListIdSet()
    if not next(interesting) then return end

    local numBatch = GetNumAuctionItems("list")
    if not numBatch or numBatch == 0 then return end

    local lowest = {}
    for i = 1, numBatch do
        -- TBC Classic API: the 17th return is itemId, the 10th is buyoutPrice.
        local _, _, count, _, _, _, _, _, _, buyoutPrice,
              _, _, _, _, _, _, itemId = GetAuctionItemInfo("list", i)
        if itemId and interesting[itemId]
           and buyoutPrice and buyoutPrice > 0
           and count and count > 0 then
            local per = math.floor(buyoutPrice / count)
            if not lowest[itemId] or per < lowest[itemId] then
                lowest[itemId] = per
            end
        end
    end

    -- Persist anything we captured. Refresh the shopping tab so prices show
    -- immediately without the user having to click around.
    local changed
    for id, copper in pairs(lowest) do
        local existing = A.AHPrices.Get(id)
        if existing ~= copper then
            A.AHPrices.Set(id, copper)
            changed = true
        end
    end
    if changed and A.UI and A.UI.MainPanel and A.UI.MainPanel.UpdateButton then
        A.UI.MainPanel.UpdateButton()
    end
end

-- ============================================================================
-- Events
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_ITEM_LIST_UPDATE" then
        ScanAndUpdate()
    end
end)
