-- Professions/AlchemyData.lua — Alfred (Alchemy)
-- Static data for the Alchemy profession (1-375, TBC Anniversary).
-- Mirrors the schema used by Enchanting in Data.lua so that Core can render it
-- with no special cases. Globals (AlfredAlchemy*) are picked up by the adapter
-- in Professions/Alchemy.lua and forwarded to Alfred.RegisterProfession.
--
-- Source: https://www.wow-professions.com/tbc/alchemy-leveling-guide-burning-crusade-classic
-- Item IDs verified against Wowhead.

-- ============================================================================
-- AlfredAlchemyData — Artisan-style structured schema (same shape as Enchanting)
-- ============================================================================
AlfredAlchemyData = {
    professionName = "Alchemy",
    maxSkill       = 375,
    icon           = "Interface\\Icons\\Trade_Alchemy",

    steps = {
        -- -- 1-110: Apprentice / Journeyman ---------------------------------
        { skillStart = 1,   skillEnd = 60,
          recipeName = "Minor Healing Potion", kind = "potion", quantity = 65,
          outputItemId = 118, color = "orange",
          materials = {
              { name = "Peacebloom",  itemId = 2447, quantity = 65 },
              { name = "Silverleaf",  itemId = 765,  quantity = 65 },
              { name = "Empty Vial",  itemId = 3371, quantity = 65 },
          },
          notes = "Keep all 65 — they're consumed as a reagent in the next step." },

        { skillStart = 60,  skillEnd = 110,
          recipeName = "Lesser Healing Potion", kind = "potion", quantity = 65,
          outputItemId = 858, color = "orange",
          materials = {
              { name = "Minor Healing Potion", itemId = 118,  quantity = 65 },
              { name = "Briarthorn",           itemId = 2450, quantity = 65 },
          } },

        -- -- 110-155: Journeyman / Expert -----------------------------------
        { skillStart = 110, skillEnd = 140,
          recipeName = "Healing Potion", kind = "potion", quantity = 35,
          outputItemId = 929, color = "orange",
          materials = {
              { name = "Bruiseweed",  itemId = 2453, quantity = 35 },
              { name = "Briarthorn",  itemId = 2450, quantity = 35 },
              { name = "Leaded Vial", itemId = 3372, quantity = 35 },
          } },

        { skillStart = 140, skillEnd = 155,
          recipeName = "Lesser Mana Potion", kind = "potion", quantity = 20,
          outputItemId = 3385, color = "orange",
          materials = {
              { name = "Mageroyal",    itemId = 785,  quantity = 20 },
              { name = "Stranglekelp", itemId = 3820, quantity = 20 },
              { name = "Empty Vial",   itemId = 3371, quantity = 20 },
          },
          notes = "Yellow recipe for the last 10 points — plan a few extras." },

        -- -- 155-225: Expert ------------------------------------------------
        { skillStart = 155, skillEnd = 185,
          recipeName = "Greater Healing Potion", kind = "potion", quantity = 35,
          outputItemId = 3928, color = "orange",
          materials = {
              { name = "Liferoot",    itemId = 3357, quantity = 35 },
              { name = "Kingsblood",  itemId = 3356, quantity = 35 },
              { name = "Leaded Vial", itemId = 3372, quantity = 35 },
          } },

        { skillStart = 185, skillEnd = 210,
          recipeName = "Elixir of Agility", kind = "potion", quantity = 30,
          outputItemId = 8949, color = "orange",
          materials = {
              { name = "Stranglekelp", itemId = 3820, quantity = 30 },
              { name = "Goldthorn",    itemId = 3821, quantity = 30 },
              { name = "Leaded Vial",  itemId = 3372, quantity = 30 },
          } },

        { skillStart = 210, skillEnd = 215,
          recipeName = "Elixir of Greater Defense", kind = "potion", quantity = 5,
          outputItemId = 8951, color = "orange",
          materials = {
              { name = "Wild Steelbloom", itemId = 3355, quantity = 5 },
              { name = "Goldthorn",       itemId = 3821, quantity = 5 },
              { name = "Leaded Vial",     itemId = 3372, quantity = 5 },
          } },

        -- -- 215-300: Artisan -----------------------------------------------
        { skillStart = 215, skillEnd = 230,
          recipeName = "Superior Healing Potion", kind = "potion", quantity = 15,
          outputItemId = 3928, color = "orange",
          materials = {
              { name = "Sungrass",          itemId = 8838, quantity = 15 },
              { name = "Khadgar's Whisker", itemId = 3358, quantity = 15 },
              { name = "Crystal Vial",      itemId = 8925, quantity = 15 },
          } },

        { skillStart = 230, skillEnd = 265,
          recipeName = "Elixir of Detect Undead", kind = "potion", quantity = 45,
          outputItemId = 9088, color = "orange",
          materials = {
              { name = "Arthas' Tears", itemId = 8836, quantity = 45 },
              { name = "Crystal Vial",  itemId = 8925, quantity = 45 },
          } },

        { skillStart = 265, skillEnd = 285,
          recipeName = "Superior Mana Potion", kind = "potion", quantity = 30,
          outputItemId = 13443, color = "orange",
          materials = {
              { name = "Sungrass",     itemId = 8838,  quantity = 60 },
              { name = "Blindweed",    itemId = 8839,  quantity = 60 },
              { name = "Crystal Vial", itemId = 8925,  quantity = 30 },
          } },

        { skillStart = 285, skillEnd = 300,
          recipeName = "Major Healing Potion", kind = "potion", quantity = 20,
          outputItemId = 13446, color = "orange",
          materials = {
              { name = "Golden Sansam",      itemId = 13464, quantity = 40 },
              { name = "Mountain Silversage", itemId = 13465, quantity = 20 },
              { name = "Crystal Vial",       itemId = 8925,  quantity = 20 },
          } },

        -- -- 300-315: PICK ONE of seven paths --------------------------------
        -- Three TBC potions/elixirs first (cheapest TBC herbs win), then four
        -- Classic alternatives -- only worth it if you already have stockpiled
        -- Dreamfoil/Icecap/etc. After 315 always switch to the TBC path
        -- (Elixir of Healing Power) -- Classic potions become useless.
        -- The "header" kind rows render as visual dividers in the Guide tab
        -- (no icon, no cast button) and are skipped by next/prev navigation.
        { kind = "header", recipeName = "===  300-315: TBC paths (preferred)  ===" },

        { skillStart = 300, skillEnd = 315,
          recipeName = "Volatile Healing Potion", kind = "potion", quantity = 15,
          outputItemId = 22829, color = "orange",
          materials = {
              { name = "Golden Sansam", itemId = 13464, quantity = 15 },
              { name = "Felweed",       itemId = 22785, quantity = 15 },
              { name = "Imbued Vial",   itemId = 22866, quantity = 15 },
          },
          notes = "Pick ONE of the seven 300-315 paths -- whichever herbs are cheapest on your realm." },

        { skillStart = 300, skillEnd = 315,
          recipeName = "Adept's Elixir", kind = "potion", quantity = 15,
          outputItemId = 22831, optional = true, color = "orange",
          materials = {
              { name = "Dreamfoil",   itemId = 13463, quantity = 15 },
              { name = "Felweed",     itemId = 22785, quantity = 15 },
              { name = "Imbued Vial", itemId = 22866, quantity = 15 },
          },
          notes = "Alt 300-315 (TBC) -- pick if Dreamfoil is cheaper than Golden Sansam." },

        { skillStart = 300, skillEnd = 315,
          recipeName = "Onslaught Elixir", kind = "potion", quantity = 15,
          outputItemId = 22835, optional = true, color = "orange",
          materials = {
              { name = "Mountain Silversage", itemId = 13465, quantity = 15 },
              { name = "Felweed",             itemId = 22785, quantity = 15 },
              { name = "Imbued Vial",         itemId = 22866, quantity = 15 },
          },
          notes = "Alt 300-315 (TBC) -- strength elixir, pick if Mountain Silversage is cheapest." },

        -- ---- Classic alternatives for 300-315 (only if classic herbs cheap)
        { kind = "header", recipeName = "===  300-315: Classic alternatives (only if cheap)  ===" },

        { skillStart = 300, skillEnd = 315,
          recipeName = "Major Mana Potion", kind = "potion", quantity = 17,
          outputItemId = 13444, optional = true, color = "orange",
          materials = {
              { name = "Dreamfoil",    itemId = 13463, quantity = 51 },
              { name = "Icecap",       itemId = 13467, quantity = 34 },
              { name = "Crystal Vial", itemId = 8925,  quantity = 17 },
          },
          notes = "Alt 300-315 (Classic) -- viable if Dreamfoil + Icecap are cheap." },

        { skillStart = 300, skillEnd = 315,
          recipeName = "Greater Arcane Elixir", kind = "potion", quantity = 20,
          outputItemId = 13454, optional = true, color = "orange",
          materials = {
              { name = "Dreamfoil",           itemId = 13463, quantity = 60 },
              { name = "Mountain Silversage", itemId = 13465, quantity = 20 },
              { name = "Crystal Vial",        itemId = 8925,  quantity = 20 },
          },
          notes = "Alt 300-315 (Classic) -- viable if Dreamfoil + Silversage stack is cheap." },

        { skillStart = 300, skillEnd = 315,
          recipeName = "Greater Fire Protection Potion", kind = "potion", quantity = 17,
          outputItemId = 13457, optional = true, color = "orange",
          materials = {
              { name = "Elemental Fire", itemId = 7068,  quantity = 17 },
              { name = "Dreamfoil",      itemId = 13463, quantity = 17 },
              { name = "Crystal Vial",   itemId = 8925,  quantity = 17 },
          },
          notes = "Alt 300-315 (Classic) -- viable if Elemental Fire is cheap (often is)." },

        { skillStart = 300, skillEnd = 315,
          recipeName = "Greater Arcane Protection Potion", kind = "potion", quantity = 17,
          outputItemId = 13461, optional = true, color = "orange",
          materials = {
              { name = "Dream Dust",   itemId = 11176, quantity = 17 },
              { name = "Dreamfoil",    itemId = 13463, quantity = 17 },
              { name = "Crystal Vial", itemId = 8925,  quantity = 17 },
          },
          notes = "Alt 300-315 (Classic) -- viable if Dream Dust + Dreamfoil are cheap." },

        -- -- 315-375: Master (TBC) ------------------------------------------
        { skillStart = 315, skillEnd = 330,
          recipeName = "Elixir of Healing Power", kind = "potion", quantity = 25,
          outputItemId = 22730, color = "orange",
          materials = {
              { name = "Golden Sansam", itemId = 13464, quantity = 25 },
              { name = "Dreaming Glory", itemId = 22790, quantity = 25 },
              { name = "Imbued Vial",   itemId = 22866, quantity = 25 },
          } },

        { skillStart = 330, skillEnd = 335,
          recipeName = "Elixir of Draenic Wisdom", kind = "potion", quantity = 5,
          outputItemId = 32067, color = "orange",
          materials = {
              { name = "Terocone",    itemId = 22789, quantity = 5 },
              { name = "Felweed",     itemId = 22785, quantity = 5 },
              { name = "Imbued Vial", itemId = 22866, quantity = 5 },
          } },

        { skillStart = 335, skillEnd = 340,
          recipeName = "Super Healing Potion", kind = "potion", quantity = 5,
          outputItemId = 22829, color = "orange",
          materials = {
              { name = "Netherbloom", itemId = 22791, quantity = 10 },
              { name = "Felweed",     itemId = 22785, quantity = 5 },
              { name = "Imbued Vial", itemId = 22866, quantity = 5 },
          } },

        { skillStart = 340, skillEnd = 355,
          recipeName = "Super Mana Potion", kind = "potion", quantity = 15,
          outputItemId = 22832, color = "orange",
          materials = {
              { name = "Dreaming Glory", itemId = 22790, quantity = 30 },
              { name = "Felweed",        itemId = 22785, quantity = 15 },
              { name = "Imbued Vial",    itemId = 22866, quantity = 15 },
          } },

        { skillStart = 355, skillEnd = 375,
          recipeName = "Major Dreamless Sleep Potion", kind = "potion", quantity = 40,
          outputItemId = 22841, color = "orange",
          materials = {
              { name = "Dreaming Glory", itemId = 22790, quantity = 40 },
              { name = "Nightmare Vine", itemId = 22792, quantity = 40 },
              { name = "Imbued Vial",    itemId = 22866, quantity = 40 },
          },
          notes = "Green recipe for the last 3 points — plan a few extras." },
    },
}

-- ============================================================================
-- Canonical shopping list (counts hand-tuned to wow-professions).
-- Mirrors Enchanting's structure: materials first, then a "Vendor recipes"
-- section. Alchemy is mostly self-trainable, so the recipe list is short.
-- ============================================================================
AlfredAlchemyShoppingList = {
    -- ---- Vials --------------------------------------------------------------
    -- vendorPrice = base list price in copper (no rep discount). The actual
    -- price the player sees is auto-captured the first time they open a
    -- vendor that sells the vial (Core/VendorPrices.lua), which overrides
    -- this default. 1g = 10000c, 1s = 100c.
    { id = 3371,  name = "Empty Vial",   count = 85,  vendorPrice = 3    }, -- 3c
    { id = 3372,  name = "Leaded Vial",  count = 105, vendorPrice = 25   }, -- 25c
    { id = 8925,  name = "Crystal Vial", count = 110, vendorPrice = 125  }, -- 1s 25c
    { id = 22866, name = "Imbued Vial",  count = 105, vendorPrice = 5000 }, -- 50s

    -- ---- Classic herbs ------------------------------------------------------
    { id = 2447,  name = "Peacebloom",          count = 65 },
    { id = 765,   name = "Silverleaf",          count = 65 },
    { id = 2450,  name = "Briarthorn",          count = 100 },
    { id = 2453,  name = "Bruiseweed",          count = 35 },
    { id = 785,   name = "Mageroyal",           count = 20 },
    { id = 3820,  name = "Stranglekelp",        count = 50 },
    { id = 3357,  name = "Liferoot",            count = 35 },
    { id = 3356,  name = "Kingsblood",          count = 35 },
    { id = 3821,  name = "Goldthorn",           count = 35 },
    { id = 3355,  name = "Wild Steelbloom",     count = 5 },
    { id = 8838,  name = "Sungrass",            count = 75 },
    { id = 3358,  name = "Khadgar's Whisker",   count = 15 },
    { id = 8836,  name = "Arthas' Tears",       count = 45 },
    { id = 8839,  name = "Blindweed",           count = 60 },
    { id = 13464, name = "Golden Sansam",       count = 80 },
    { id = 13465, name = "Mountain Silversage", count = 20 },

    -- ---- TBC herbs ----------------------------------------------------------
    { id = 22785, name = "Felweed",        count = 40 },
    { id = 22789, name = "Terocone",       count = 5 },
    { id = 22790, name = "Dreaming Glory", count = 95 },
    { id = 22791, name = "Netherbloom",    count = 10 },
    { id = 22792, name = "Nightmare Vine", count = 40 },

    -- ---- Alternatives for the 300-315 path (kind="alt" excludes from total) ---
    -- The seven 300-315 paths share Felweed/Imbued Vial (already counted above
    -- for the primary Volatile Healing route). Listed here so you can compare
    -- AH prices and pick the cheapest path WITHOUT inflating the running total.
    -- The render groups them under a dim "Alternatives" header.
    { kind = "alt", id = 13463, name = "Dreamfoil (Adept's Elixir, 15x)",                 count = 15 },
    { kind = "alt", id = 13465, name = "Mountain Silversage (Onslaught Elixir, 15x)",     count = 15 },
    { kind = "alt", id = 13463, name = "Dreamfoil (Major Mana Potion, 17x)",              count = 51 },
    { kind = "alt", id = 13467, name = "Icecap (Major Mana Potion, 17x)",                 count = 34 },
    { kind = "alt", id = 13463, name = "Dreamfoil (Greater Arcane Elixir, 20x)",          count = 60 },
    { kind = "alt", id = 13465, name = "Mountain Silversage (Gr. Arcane Elixir, 20x)",    count = 20 },
    { kind = "alt", id = 7068,  name = "Elemental Fire (Gr. Fire Prot Potion, 17x)",      count = 17 },
    { kind = "alt", id = 13463, name = "Dreamfoil (Gr. Fire Prot Potion, 17x)",           count = 17 },
    { kind = "alt", id = 11176, name = "Dream Dust (Gr. Arcane Prot Potion, 17x)",        count = 17 },
    { kind = "alt", id = 13463, name = "Dreamfoil (Gr. Arcane Prot Potion, 17x)",         count = 17 },

    -- ---- Vendor recipes (NOT learned from the trainer) ---------------------
    -- Per the wow-professions guide. IDs verified to my best knowledge against
    -- Wowhead -- if any icon shows wrong, replace the id once you see it
    -- in-game. Recipes are limited supply (15-30 min respawn typical).
    { kind = "recipe", id = 22907, name = "Recipe: Super Mana Potion",
      vendor = "Daga Ramba (Hellfire Pen., H) / Haalrun (Nagrand, A)",
      req    = "Required for 340-355 (main path)" },
    { kind = "recipe", id = 22910, name = "Recipe: Major Dreamless Sleep Potion",
      vendor = "Daga Ramba (Hellfire Pen., H) / Leeli Longhaggle (Nagrand, A)",
      req    = "Required for 355-375 (main path)" },
    { kind = "recipe", id = 13483, name = "Recipe: Nature Protection Potion",
      vendor = "Limited supply, multiple vendors",
      req    = "Optional alt for 190-215 (Classic path)" },
    { kind = "recipe", id = 32070, name = "Recipe: Elixir of Major Shadow Power",
      vendor = "Nakodu (Shattrath -- Lower City)",
      req    = "Revered with The Lower City -- alt for 355-375" },
}

-- ============================================================================
-- Back-compat: derived AlfredAlchemyGuide / AlfredAlchemyFullGuide.
-- Same convention as Data.lua — keeps the legacy {spell, kind, range, count}
-- shape available in case any consumer still expects it.
-- ============================================================================
local function FormatRange(s, e)
    return tostring(s) .. "-" .. tostring(e)
end

local function MaterialsToString(mats)
    if not mats or #mats == 0 then return "" end
    local parts = {}
    for _, m in ipairs(mats) do
        table.insert(parts, tostring(m.quantity) .. " " .. m.name)
    end
    return table.concat(parts, ", ")
end

AlfredAlchemyGuide     = {}
AlfredAlchemyFullGuide = {}
for i, step in ipairs(AlfredAlchemyData.steps) do
    local rangeStr = FormatRange(step.skillStart, step.skillEnd)
    AlfredAlchemyGuide[i] = {
        spell    = step.recipeName,
        kind     = step.kind,
        range    = rangeStr,
        count    = step.quantity,
        optional = step.optional,
        notes    = step.notes,
    }
    AlfredAlchemyFullGuide[i] = {
        range    = rangeStr,
        spell    = step.recipeName,
        count    = step.quantity,
        reagents = MaterialsToString(step.materials),
        optional = step.optional,
        notes    = step.notes,
    }
end
