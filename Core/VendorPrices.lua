-- Core/VendorPrices.lua — Alfred
-- Vendor price tracking. Listens to MERCHANT_SHOW and passively scans the
-- merchant's inventory for any item that appears in the active profession's
-- shopping list, recording the unit price the player would actually pay
-- (so reputation discounts are baked in).
--
-- Storage: AlfredDB.vendorPrices[realm-faction][itemId] = { copper, ts }.
-- Realm-faction key matches AHPrices so users on the same toon share state.
--
-- Lookup order in the shopping renderer (see Core/MainPanel.lua):
--   1. VendorPrices.Get(id)              (captured live, includes rep discount)
--   2. shoppingList entry's vendorPrice  (hardcoded default in profession data)
--   3. AHPrices.Get(id)                  (Auction House)
local _, A = ...
A.VendorPrices = {}

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
    AlfredDB.vendorPrices = AlfredDB.vendorPrices or {}
    local key = RealmKey()
    AlfredDB.vendorPrices[key] = AlfredDB.vendorPrices[key] or {}
    return AlfredDB.vendorPrices[key]
end

function A.VendorPrices.Get(itemId)
    if not itemId then return nil end
    local t = PricesTable()
    if not t then return nil end
    local entry = t[itemId]
    if not entry then return nil end
    return entry.copper, entry.ts
end

function A.VendorPrices.Set(itemId, copper)
    if not itemId or not copper or copper <= 0 then return end
    local t = PricesTable()
    if not t then return end
    t[itemId] = { copper = copper, ts = time() }
end

function A.VendorPrices.Clear(itemId)
    local t = PricesTable()
    if not t then return end
    if itemId then t[itemId] = nil
    else
        for k in pairs(t) do t[k] = nil end
    end
end

-- ============================================================================
-- Passive scan on MERCHANT_SHOW
-- ============================================================================
local function ShoppingListIdSet()
    local set = {}
    local list = A.Profession and A.Profession.shoppingList
    if not list then return set end
    for _, item in ipairs(list) do
        if item.id then set[item.id] = true end
    end
    return set
end

-- Walk the merchant's inventory. For every slot whose itemLink matches an id
-- in our shopping list, record the per-unit price (price / stackSize), which
-- accounts for vendors that sell items in stacks of N.
local function ScanMerchant()
    if not GetMerchantNumItems or not GetMerchantItemInfo then return end
    local interesting = ShoppingListIdSet()
    if not next(interesting) then return end

    local n = GetMerchantNumItems() or 0
    if n == 0 then return end

    local changed
    for i = 1, n do
        -- name, texture, price, stackSize, numAvailable, isPurchasable, isUsable, extendedCost
        local _, _, price, stackSize = GetMerchantItemInfo(i)
        local link = GetMerchantItemLink and GetMerchantItemLink(i)
        local itemId = link and tonumber(link:match("item:(%d+)"))
        if itemId and interesting[itemId] and price and price > 0
           and stackSize and stackSize > 0 then
            local per = math.floor(price / stackSize)
            local existing = A.VendorPrices.Get(itemId)
            if existing ~= per then
                A.VendorPrices.Set(itemId, per)
                changed = true
            end
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
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        ScanMerchant()
    end
end)
