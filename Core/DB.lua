-- Core/DB.lua — Alfred-Enchanting (Phase 3)
-- New multi-profession schema + migration from the old AlfredEnchantingDB.
--
-- AlfredDB schema:
--   {
--     activeProfession = "enchanting",
--     -- UI state shared across professions:
--     framePos     = { point, relPoint, x, y },
--     minimapAngle = 165,
--     minimapHide  = false,
--     pinTo        = "TSMCraftingFrame" | nil,
--     -- Per-profession state:
--     professions = {
--       enchanting = {
--         currentStep = 1,
--         stats = { [spellName] = { casts, skillUps } },
--         slots = { bracer = "Bands of Indwelling", ... },
--       },
--       tailoring = { ... },  (future)
--     },
--   }
--
-- Migration chain (each step only runs if the destination SV doesn't exist):
--   EnchantButtonDB → AlfredEnchantingDB → AlfredDB
local _, A = ...
A.DB = {}

-- Migration stage 1: legacy EnchantButtonDB → AlfredEnchantingDB (inherited from v3.x).
local function MigrateLegacyEnchantButton()
    if AlfredEnchantingDB or not EnchantButtonDB then return false end
    AlfredEnchantingDB = {}
    for k, v in pairs(EnchantButtonDB) do
        AlfredEnchantingDB[k] = v
    end
    return true
end

-- Migration stage 2: AlfredEnchantingDB (flat) → AlfredDB (multi-prof).
-- Move shared UI state to the top level, and per-profession data to
-- AlfredDB.professions.enchanting.{currentStep, stats, slots}.
local function MigrateToAlfredDB()
    if AlfredDB then return false end
    local old = AlfredEnchantingDB or {}
    AlfredDB = {
        activeProfession = "enchanting",
        framePos     = old.framePos,
        minimapAngle = old.minimapAngle,
        minimapHide  = old.minimapHide,
        pinTo        = old.pinTo,
        professions  = {
            enchanting = {
                currentStep = old.currentStep or 1,
                stats       = old.stats or {},
                slots       = {},
            },
        },
    }
    -- Move per-slot items from the flat table to the `slots` sub-table.
    -- Slots are known via A.Profession.slots (defined in
    -- Professions/Enchanting.lua).
    if A.Profession and A.Profession.slots then
        local destSlots = AlfredDB.professions.enchanting.slots
        for _, slotDef in ipairs(A.Profession.slots) do
            local v = old[slotDef.key]
            if v ~= nil then
                destSlots[slotDef.key] = v
            end
        end
    end
    return true
end

-- Initializes AlfredDB and applies defaults for the active profession.
-- Idempotent — can be called multiple times without side effects.
function A.DB.Init()
    local migratedLegacy = MigrateLegacyEnchantButton()
    local migratedNew    = MigrateToAlfredDB()

    AlfredDB = AlfredDB or { professions = {} }
    AlfredDB.professions = AlfredDB.professions or {}
    AlfredDB.activeProfession = AlfredDB.activeProfession or "enchanting"

    -- Ensure a sub-table for each registered profession.
    -- NOTE: we do NOT auto-populate slots with defaults — the user starts
    -- with an empty list and assigns manually whatever they want to use.
    -- The defaults (A.Profession.slotDefaults) remain available as an
    -- informational hint in the Config tab but are not written to the DB.
    for _, profId in ipairs(Alfred.GetRegisteredProfessions()) do
        AlfredDB.professions[profId] = AlfredDB.professions[profId] or {}
        local p = AlfredDB.professions[profId]
        p.currentStep = p.currentStep or 1
        p.stats       = p.stats or {}
        p.slots       = p.slots or {}
        p.excluded    = p.excluded or {}  -- shopping items dropped from totals
    end

    -- Report migration to the user once.
    if migratedLegacy then
        print("|cff00ff00[Alfred:Enchanting]|r Settings migrated from EnchantButton.")
    end
    if migratedNew then
        print("|cff00ff00[Alfred]|r Schema upgraded to multi-profession (AlfredDB).")
    end
end

-- ============================================================================
-- Accessors
-- ============================================================================

-- Shared table (UI: framePos, minimap, pinTo).
function A.DB.Shared()
    return AlfredDB
end

-- Active profession's table (currentStep, stats, slots).
function A.DB.Active()
    if not AlfredDB or not AlfredDB.professions then return nil end
    return AlfredDB.professions[AlfredDB.activeProfession]
end

function A.DB.ActiveProfessionId()
    return AlfredDB and AlfredDB.activeProfession
end

-- Item configured for a slot of the active profession.
function A.DB.GetSlotItem(slotKey)
    local p = A.DB.Active()
    return p and p.slots and p.slots[slotKey]
end

function A.DB.SetSlotItem(slotKey, itemName)
    local p = A.DB.Active()
    if not p then return end
    p.slots = p.slots or {}
    p.slots[slotKey] = itemName
end

function A.DB.GetSlots()
    local p = A.DB.Active()
    return (p and p.slots) or {}
end

-- Shopping list exclusions: items the user has shift-clicked to drop from the
-- estimated totals. State is per-profession so that excluding "Strange Dust"
-- for Enchanting doesn't bleed into a future Tailoring shopping list.
function A.DB.IsExcluded(itemId)
    if not itemId then return false end
    local p = A.DB.Active()
    return p and p.excluded and p.excluded[itemId] == true
end

function A.DB.ToggleExclude(itemId)
    if not itemId then return end
    local p = A.DB.Active()
    if not p then return end
    p.excluded = p.excluded or {}
    if p.excluded[itemId] then
        p.excluded[itemId] = nil
    else
        p.excluded[itemId] = true
    end
end
