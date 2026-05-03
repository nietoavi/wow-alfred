-- Data.lua — Alfred-Enchanting
-- Defines the available slots and maps each enchant to its corresponding slot.
-- Items assigned to each slot are persisted in SavedVariables
-- (AlfredDB.professions.enchanting.slots) and can be changed from the in-game
-- options panel. The tables here (Slots, Defaults, SlotMap, Data, ShoppingList)
-- are consumed by Professions/Enchanting.lua and passed to the registry via
-- Alfred.RegisterProfession.
--
-- AlfredEnchantingSlotMap supports two key types:
--   * Enchant name (string) — works on the English client.
--   * Spell ID (numeric)    — locale-independent (see TBC enchant IDs).
-- The runtime looks up by ID extracted from the recipe link first, then by name.

-- Available slots: internal key → label shown to the player
AlfredEnchantingSlots = {
    { key = "bracer",   label = "Bracer" },
    { key = "cloak",    label = "Cloak" },
    { key = "chest",    label = "Chest" },
    { key = "gloves",   label = "Gloves" },
    { key = "boots",    label = "Boots" },
    { key = "shield",   label = "Shield" },
    { key = "ring",     label = "Ring" },
    { key = "weapon2h", label = "2H Weapon" },
}

-- Default values for slots (used if the player hasn't configured anything)
AlfredEnchantingDefaults = {
    bracer   = "Bands of Indwelling",
    cloak    = "Avian Cloak of Feathers",
    chest    = "Masquerade Gown",
    gloves   = "",
    boots    = "Boots of the Incorrupt",
    shield   = "",
    ring     = "",
    weapon2h = "",
}

-- ============================================================================
-- AlfredEnchantingData — Artisan-style structured schema.
-- Each step is the atomic unit that the UI renders, the macro consumes and the
-- shopping list aggregates.
--
-- Per-step fields:
--   skillStart, skillEnd (int)  — numeric range (drives progress/coloring)
--   recipeName            (str) — exact spell name (used by /cast and slotMap)
--   kind                  (str) — "enchant" | "rod" | "wand" | "oil"
--                                  drives macro template: enchant = 3-line with
--                                  /use+/click, others = 1-line /cast
--   quantity              (int) — expected number of casts at this step
--   outputItemId          (int) — itemID of the crafted item (rods/wands/oils);
--                                  nil for enchants (no item produced)
--   materials             (arr) — list of { name, itemId, quantity } total per step
--   color                 (str) — "orange" | "yellow" | "green" | "gray" tint
--   optional              (bool)— true if this is an alternative to the main step
--   notes                 (str) — vendor info, alternatives, warnings
-- ============================================================================
AlfredEnchantingData = {
    professionName = "Enchanting",
    maxSkill       = 375,
    icon           = "Interface\\Icons\\Trade_Engraving",

    steps = {
        -- -- 1-100: Apprentice ------------------------------------------------
        { skillStart = 1,   skillEnd = 2,
          recipeName = "Runed Copper Rod", kind = "rod", quantity = 1,
          outputItemId = 6218, color = "orange",
          materials = {
              { name = "Copper Rod",          itemId = 6217,  quantity = 1 },
              { name = "Strange Dust",         itemId = 10940, quantity = 1 },
              { name = "Lesser Magic Essence", itemId = 10938, quantity = 1 },
          } },

        { skillStart = 2,   skillEnd = 50,
          recipeName = "Enchant Bracer - Minor Health", kind = "enchant", quantity = 48,
          color = "orange",
          materials = {
              { name = "Strange Dust", itemId = 10940, quantity = 48 },
          } },

        { skillStart = 50,  skillEnd = 90,
          recipeName = "Enchant Bracer - Minor Health", kind = "enchant", quantity = 40,
          optional = true, color = "orange",
          materials = {
              { name = "Strange Dust", itemId = 10940, quantity = 40 },
          },
          notes = "Only if Strange Dust is cheap — alternative: skip straight to Stamina." },

        { skillStart = 90,  skillEnd = 100,
          recipeName = "Enchant Bracer - Minor Stamina", kind = "enchant", quantity = 10,
          color = "orange",
          materials = {
              { name = "Strange Dust", itemId = 10940, quantity = 30 },
          } },

        -- -- 100-150: Journeyman ---------------------------------------------
        { skillStart = 100, skillEnd = 101,
          recipeName = "Runed Silver Rod", kind = "rod", quantity = 1,
          outputItemId = 6339, color = "orange",
          materials = {
              { name = "Silver Rod",            itemId = 6338,  quantity = 1 },
              { name = "Strange Dust",          itemId = 10940, quantity = 6 },
              { name = "Greater Magic Essence", itemId = 10939, quantity = 3 },
          } },

        { skillStart = 101, skillEnd = 110,
          recipeName = "Greater Magic Wand", kind = "wand", quantity = 9,
          outputItemId = 11288, color = "orange",
          materials = {
              { name = "Simple Wood",           itemId = 4470,  quantity = 9 },
              { name = "Greater Magic Essence", itemId = 10939, quantity = 9 },
          } },

        { skillStart = 110, skillEnd = 135,
          recipeName = "Enchant Cloak - Minor Agility", kind = "enchant", quantity = 25,
          color = "orange",
          materials = {
              { name = "Lesser Astral Essence", itemId = 10998, quantity = 25 },
          } },

        { skillStart = 110, skillEnd = 135,
          recipeName = "Enchant 2H Weapon - Minor Impact", kind = "enchant", quantity = 28,
          optional = true, color = "orange",
          materials = {
              { name = "Strange Dust",          itemId = 10940, quantity = 112 },
              { name = "Small Glimmering Shard", itemId = 10978, quantity = 28  },
          },
          notes = "Alternative to Minor Agility. 28 Strange Dust + 28 Small Glimmering Shard." },

        { skillStart = 135, skillEnd = 155,
          recipeName = "Enchant Bracer - Lesser Stamina", kind = "enchant", quantity = 20,
          color = "orange",
          materials = {
              { name = "Soul Dust", itemId = 11083, quantity = 40 },
          } },

        -- -- 155-225: Expert -------------------------------------------------
        { skillStart = 155, skillEnd = 156,
          recipeName = "Runed Golden Rod", kind = "rod", quantity = 1,
          outputItemId = 11130, color = "orange",
          materials = {
              { name = "Golden Rod",            itemId = 11128, quantity = 1 },
              { name = "Iridescent Pearl",      itemId = 5500,  quantity = 1 },
              { name = "Greater Astral Essence", itemId = 11082, quantity = 2 },
              { name = "Soul Dust",              itemId = 11083, quantity = 2 },
          } },

        { skillStart = 156, skillEnd = 185,
          recipeName = "Enchant Bracer - Lesser Strength", kind = "enchant", quantity = 40,
          color = "orange",
          materials = {
              { name = "Soul Dust", itemId = 11083, quantity = 80 },
          },
          notes = "Recipe vendor: Kulwia (Horde, Stonetalon) or Dalria (Alliance, Ashenvale) — limited supply." },

        { skillStart = 165, skillEnd = 185,
          recipeName = "Enchant Bracer - Spirit", kind = "enchant", quantity = 20,
          optional = true, color = "orange",
          materials = {
              { name = "Lesser Mystic Essence", itemId = 11134, quantity = 20 },
          },
          notes = "Alternative: 20 Lesser Mystic Essence if cheaper than Soul Dust." },

        { skillStart = 185, skillEnd = 200,
          recipeName = "Enchant Bracer - Strength", kind = "enchant", quantity = 15,
          color = "orange",
          materials = {
              { name = "Vision Dust", itemId = 11137, quantity = 15 },
          } },

        { skillStart = 200, skillEnd = 201,
          recipeName = "Runed Truesilver Rod", kind = "rod", quantity = 1,
          outputItemId = 11145, color = "orange",
          materials = {
              { name = "Truesilver Rod",          itemId = 11144, quantity = 1 },
              { name = "Black Pearl",             itemId = 7971,  quantity = 1 },
              { name = "Greater Mystic Essence", itemId = 11135, quantity = 2 },
              { name = "Vision Dust",             itemId = 11137, quantity = 2 },
          } },

        { skillStart = 201, skillEnd = 220,
          recipeName = "Enchant Bracer - Strength", kind = "enchant", quantity = 25,
          color = "yellow",
          materials = {
              { name = "Vision Dust", itemId = 11137, quantity = 25 },
          } },

        { skillStart = 220, skillEnd = 225,
          recipeName = "Enchant Cloak - Greater Defense", kind = "enchant", quantity = 5,
          color = "orange",
          materials = {
              { name = "Vision Dust", itemId = 11137, quantity = 15 },
          } },

        -- -- 225-300: Artisan ------------------------------------------------
        { skillStart = 225, skillEnd = 230,
          recipeName = "Enchant Gloves - Agility", kind = "enchant", quantity = 5,
          color = "orange",
          materials = {
              { name = "Lesser Nether Essence", itemId = 11174, quantity = 5 },
              { name = "Vision Dust",            itemId = 11137, quantity = 5 },
          } },

        { skillStart = 230, skillEnd = 235,
          recipeName = "Enchant Boots - Stamina", kind = "enchant", quantity = 5,
          color = "orange",
          materials = {
              { name = "Vision Dust", itemId = 11137, quantity = 25 },
          } },

        { skillStart = 235, skillEnd = 250,
          recipeName = "Enchant Chest - Superior Health", kind = "enchant", quantity = 25,
          color = "orange",
          materials = {
              { name = "Vision Dust", itemId = 11137, quantity = 150 },
          } },

        { skillStart = 250, skillEnd = 265,
          recipeName = "Lesser Mana Oil", kind = "oil", quantity = 20,
          outputItemId = 20747, color = "orange",
          materials = {
              { name = "Dream Dust",   itemId = 11176, quantity = 60 },
              { name = "Purple Lotus", itemId = 8831,  quantity = 40 },
              { name = "Crystal Vial", itemId = 8925,  quantity = 20 },
          },
          notes = "Recipe vendor: Kania (Silithus, Inn upstairs)." },

        { skillStart = 265, skillEnd = 290,
          recipeName = "Enchant Shield - Greater Stamina", kind = "enchant", quantity = 27,
          color = "orange",
          materials = {
              { name = "Dream Dust", itemId = 11176, quantity = 270 },
          },
          notes = "Recipe vendor: Daniel Bartlett (Undercity, Horde) or Mythrin'dir (Darnassus, Alliance). |cffff5555BoP|r — limited supply." },

        { skillStart = 290, skillEnd = 299,
          recipeName = "Enchant Cloak - Superior Defense", kind = "enchant", quantity = 9,
          color = "orange",
          materials = {
              { name = "Illusion Dust", itemId = 16204, quantity = 72 },
          },
          notes = "Recipe vendor: Lorelae Wintersong (Moonglade, Nighthaven) — limited supply, 15-20 min respawn." },

        { skillStart = 299, skillEnd = 300,
          recipeName = "Runed Arcanite Rod", kind = "rod", quantity = 1,
          outputItemId = 16207, color = "orange",
          materials = {
              { name = "Arcanite Rod",            itemId = 16206, quantity = 1  },
              { name = "Golden Pearl",            itemId = 13926, quantity = 1  },
              { name = "Illusion Dust",           itemId = 16204, quantity = 10 },
              { name = "Greater Eternal Essence", itemId = 16203, quantity = 4  },
              { name = "Large Brilliant Shard",   itemId = 14344, quantity = 2  },
          },
          notes = "Recipe vendor: Lorelae Wintersong (Moonglade) — grab it here while you're around." },

        -- -- 300-375: Master (TBC) -------------------------------------------
        { skillStart = 300, skillEnd = 301,
          recipeName = "Runed Fel Iron Rod", kind = "rod", quantity = 1,
          outputItemId = 22461, color = "orange",
          materials = {
              { name = "Fel Iron Rod",            itemId = 25843, quantity = 1 },
              { name = "Greater Eternal Essence", itemId = 16203, quantity = 4 },
              { name = "Large Brilliant Shard",   itemId = 14344, quantity = 6 },
          } },

        { skillStart = 301, skillEnd = 310,
          recipeName = "Enchant Bracer - Assault", kind = "enchant", quantity = 9,
          color = "orange",
          materials = {
              { name = "Arcane Dust", itemId = 22445, quantity = 54 },
          } },

        { skillStart = 300, skillEnd = 310,
          recipeName = "Enchant Cloak - Superior Defense", kind = "enchant", quantity = 12,
          optional = true, color = "orange",
          materials = {
              { name = "Illusion Dust", itemId = 16204, quantity = 96 },
          },
          notes = "Alternative for 300-310 if you have spare Illusion Dust." },

        { skillStart = 310, skillEnd = 316,
          recipeName = "Enchant Bracer - Brawn", kind = "enchant", quantity = 6,
          color = "orange",
          materials = {
              { name = "Arcane Dust", itemId = 22445, quantity = 36 },
          } },

        { skillStart = 316, skillEnd = 330,
          recipeName = "Enchant Gloves - Assault", kind = "enchant", quantity = 16,
          color = "yellow",
          materials = {
              { name = "Arcane Dust", itemId = 22445, quantity = 128 },
          } },

        { skillStart = 320, skillEnd = 330,
          recipeName = "Enchant Chest - Major Spirit", kind = "enchant", quantity = 10,
          optional = true, color = "orange",
          materials = {
              { name = "Greater Planar Essence", itemId = 22446, quantity = 20 },
          },
          notes = "Alternative: 20 Greater Planar Essence — for spirit users." },

        { skillStart = 330, skillEnd = 335,
          recipeName = "Enchant Shield - Major Stamina", kind = "enchant", quantity = 5,
          color = "orange",
          materials = {
              { name = "Arcane Dust", itemId = 22445, quantity = 75 },
          },
          notes = "Recipe vendor: Madame Ruby (Shattrath) — 5-10 min respawn. Also grab Formula: Superior Wizard Oil." },

        { skillStart = 330, skillEnd = 335,
          recipeName = "Enchant Chest - Major Spirit", kind = "enchant", quantity = 6,
          optional = true, color = "orange",
          materials = {
              { name = "Greater Planar Essence", itemId = 22446, quantity = 12 },
          },
          notes = "Alternative to Enchant Shield - Major Stamina if you're not a tank." },

        { skillStart = 335, skillEnd = 340,
          recipeName = "Enchant Shield - Resilience", kind = "enchant", quantity = 5,
          color = "orange",
          materials = {
              { name = "Large Prismatic Shard",  itemId = 22449, quantity = 5  },
              { name = "Lesser Planar Essence", itemId = 22447, quantity = 20 },
          } },

        { skillStart = 340, skillEnd = 350,
          recipeName = "Superior Wizard Oil", kind = "oil", quantity = 15,
          outputItemId = 22522, color = "yellow",
          materials = {
              { name = "Arcane Dust",   itemId = 22445, quantity = 45 },
              { name = "Nightmare Vine", itemId = 22785, quantity = 15 },
              { name = "Imbued Vial",   itemId = 18256, quantity = 15 },
          },
          notes = "Recipe vendor: Madame Ruby (Shattrath) — picked up earlier at the Major Stamina step." },

        { skillStart = 350, skillEnd = 360,
          recipeName = "Enchant Gloves - Major Strength", kind = "enchant", quantity = 15,
          color = "yellow",
          materials = {
              { name = "Arcane Dust",            itemId = 22445, quantity = 180 },
              { name = "Greater Planar Essence", itemId = 22446, quantity = 15  },
          } },

        { skillStart = 360, skillEnd = 361,
          recipeName = "Runed Adamantite Rod", kind = "rod", quantity = 1,
          outputItemId = 22462, color = "orange",
          materials = {
              { name = "Adamantite Rod",         itemId = 25844, quantity = 1 },
              { name = "Primal Might",           itemId = 23571, quantity = 1 },
              { name = "Greater Planar Essence", itemId = 22446, quantity = 8 },
              { name = "Large Prismatic Shard",  itemId = 22449, quantity = 8 },
          },
          notes = "Recipe vendor: Rungor (Stonebreaker Hold, Terokkar — Horde) or Vodesiin (Temple of Telhamat, Hellfire — Alliance)." },

        { skillStart = 361, skillEnd = 365,
          recipeName = "Enchant Gloves - Major Strength", kind = "enchant", quantity = 10,
          color = "yellow",
          materials = {
              { name = "Arcane Dust",            itemId = 22445, quantity = 120 },
              { name = "Greater Planar Essence", itemId = 22446, quantity = 10  },
          } },

        { skillStart = 365, skillEnd = 375,
          recipeName = "Enchant Ring - Spellpower", kind = "enchant", quantity = 12,
          color = "yellow",
          materials = {
              { name = "Large Prismatic Shard",  itemId = 22449, quantity = 24 },
              { name = "Greater Planar Essence", itemId = 22446, quantity = 24 },
          },
          notes = "Recipe vendor: Alurmi (Caverns of Time, Tanaris) — Honored with Keepers of Time." },

        { skillStart = 365, skillEnd = 375,
          recipeName = "Enchant Ring - Striking", kind = "enchant", quantity = 12,
          optional = true, color = "yellow",
          materials = {},
          notes = "Alternative: vendor Ythyar (Karazhan, before Chess) — Revered with Consortium." },
    },
}

-- ============================================================================
-- Per-enchant slot mapping
-- IMPORTANT: names use " - " (dash with spaces), NOT ":". The WoW client
-- returns names with dashes; using ":" causes GetSpellInfo and /cast to fail.
-- ============================================================================
AlfredEnchantingSlotMap = {
    -- Bracers
    ["Enchant Bracer - Minor Health"]      = "bracer",
    ["Enchant Bracer - Minor Stamina"]     = "bracer",
    ["Enchant Bracer - Lesser Stamina"]    = "bracer",
    ["Enchant Bracer - Lesser Strength"]   = "bracer",
    ["Enchant Bracer - Spirit"]            = "bracer",
    ["Enchant Bracer - Strength"]          = "bracer",
    ["Enchant Bracer - Assault"]           = "bracer",
    ["Enchant Bracer - Brawn"]             = "bracer",

    -- Cloak
    ["Enchant Cloak - Minor Agility"]      = "cloak",
    ["Enchant Cloak - Greater Defense"]    = "cloak",
    ["Enchant Cloak - Superior Defense"]   = "cloak",

    -- Chest
    ["Enchant Chest - Superior Health"]    = "chest",
    ["Enchant Chest - Major Spirit"]       = "chest",

    -- Gloves
    ["Enchant Gloves - Agility"]           = "gloves",
    ["Enchant Gloves - Assault"]           = "gloves",
    ["Enchant Gloves - Major Strength"]    = "gloves",

    -- Boots
    ["Enchant Boots - Stamina"]            = "boots",

    -- Shield
    ["Enchant Shield - Greater Stamina"]   = "shield",
    ["Enchant Shield - Major Stamina"]     = "shield",
    ["Enchant Shield - Resilience"]        = "shield",

    -- Ring
    ["Enchant Ring - Spellpower"]          = "ring",
    ["Enchant Ring - Striking"]            = "ring",

    -- 2H Weapon
    ["Enchant 2H Weapon - Minor Impact"]   = "weapon2h",
}

-- ============================================================================
-- Canonical shopping list (counts hand-tuned to wow-professions).
-- This is NOT derived from steps because the official guide's counts are
-- adjusted (e.g. extra dust for yellow recipes, materials from optional steps
-- omitted). The Guide.lua frame renders this directly.
--
-- Two entry types:
--   * Materials (no `kind`, or kind = "material" implicit): { id, name, count }
--   * Vendor recipes (kind = "recipe"): { kind, id, name, vendor, [req] }
--     - count is implicit 1 (you only need one copy of each formula)
--     - id may be nil if the wowhead ID isn't confirmed yet — the row will
--       render without icon/bag count, only name + vendor.
-- The render groups by kind, materials first, then a "Vendor recipes" section.
-- ============================================================================
AlfredEnchantingShoppingList = {
    -- ---- Materials ----------------------------------------------------------
    { id = 10940, name = "Strange Dust",          count = 125 },
    { id = 10938, name = "Lesser Magic Essence",  count = 1 },
    { id = 10939, name = "Greater Magic Essence", count = 12 },
    { id = 10998, name = "Lesser Astral Essence", count = 25 },
    { id = 11083, name = "Soul Dust",             count = 130 },
    { id = 11082, name = "Greater Astral Essence",count = 2 },
    { id = 11137, name = "Vision Dust",           count = 240 },
    { id = 11135, name = "Greater Mystic Essence",count = 2 },
    { id = 11174, name = "Lesser Nether Essence", count = 5 },
    { id = 11176, name = "Dream Dust",            count = 330 },
    { id = 8831,  name = "Purple Lotus",          count = 40 },
    { id = 16204, name = "Illusion Dust",         count = 82 },
    { id = 16203, name = "Greater Eternal Essence", count = 4 },
    { id = 14344, name = "Large Brilliant Shard", count = 2 },
    { id = 22445, name = "Arcane Dust",           count = 640 },
    { id = 22447, name = "Lesser Planar Essence", count = 20 },
    { id = 22446, name = "Greater Planar Essence",count = 57 },
    { id = 22785, name = "Nightmare Vine",        count = 15 },
    { id = 22449, name = "Large Prismatic Shard", count = 37 },
    { id = 23571, name = "Primal Might",          count = 1 },

    -- ---- Vendor recipes (in roughly skill-order) ----------------------------
    -- IDs verified against Wowhead. The two `id = nil` entries are vendor BoP
    -- formulas whose IDs I could not confirm — fill them in once you see them
    -- in-game.
    { kind = "recipe", id = 11039, name = "Formula: Enchant Cloak - Minor Agility",
      vendor = "Kulwia (Stonetalon, H) / Dalria (Ashenvale, A)" },
    { kind = "recipe", id = 11101, name = "Formula: Enchant Bracer - Lesser Strength",
      vendor = "Kulwia (Stonetalon, H) / Dalria (Ashenvale, A) — limited supply" },
    { kind = "recipe", id = 20754, name = "Formula: Lesser Mana Oil",
      vendor = "Kania (Silithus, Inn upstairs)" },
    { kind = "recipe", id = nil,   name = "Formula: Enchant Shield - Greater Stamina",
      vendor = "Daniel Bartlett (Undercity, H) / Mythrin'dir (Darnassus, A) — BoP, limited" },
    { kind = "recipe", id = 16224, name = "Formula: Enchant Cloak - Superior Defense",
      vendor = "Lorelae Wintersong (Moonglade) — limited, 15-20 min respawn" },
    { kind = "recipe", id = 16243, name = "Formula: Runed Arcanite Rod",
      vendor = "Lorelae Wintersong (Moonglade) — pick up while in Moonglade" },
    { kind = "recipe", id = nil,   name = "Formula: Enchant Shield - Major Stamina",
      vendor = "Madame Ruby (Shattrath) — limited, 5-10 min respawn" },
    { kind = "recipe", id = 22563, name = "Formula: Superior Wizard Oil",
      vendor = "Madame Ruby (Shattrath) — pick up at the same time" },
    { kind = "recipe", id = 25848, name = "Formula: Runed Adamantite Rod",
      vendor = "Rungor (Stonebreaker Hold, H) / Vodesiin (Telhamat, A)" },
    { kind = "recipe", id = 22536, name = "Formula: Enchant Ring - Spellpower",
      vendor = "Alurmi (Caverns of Time, Tanaris)", req = "Honored — Keepers of Time" },
    { kind = "recipe", id = 22535, name = "Formula: Enchant Ring - Striking",
      vendor = "Ythyar (Karazhan, before Chess)", req = "Revered — The Consortium" },
}

-- ============================================================================
-- Back-compat: AlfredEnchantingGuide and AlfredEnchantingFullGuide derived
-- from AlfredEnchantingData.steps. Preserve the legacy API (consumed by
-- Guide.lua) while Core has already moved to the new schema.
--
-- AlfredEnchantingGuide:    {spell, kind, range, count, optional, notes}
-- AlfredEnchantingFullGuide:{range, spell, count, reagents (string), optional, notes}
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

AlfredEnchantingGuide     = {}
AlfredEnchantingFullGuide = {}
for i, step in ipairs(AlfredEnchantingData.steps) do
    local rangeStr = FormatRange(step.skillStart, step.skillEnd)
    AlfredEnchantingGuide[i] = {
        spell    = step.recipeName,
        kind     = step.kind,
        range    = rangeStr,
        count    = step.quantity,
        optional = step.optional,
        notes    = step.notes,
    }
    AlfredEnchantingFullGuide[i] = {
        range    = rangeStr,
        spell    = step.recipeName,
        count    = step.quantity,
        reagents = MaterialsToString(step.materials),
        optional = step.optional,
        notes    = step.notes,
    }
end
