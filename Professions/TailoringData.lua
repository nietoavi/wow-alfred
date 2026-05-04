-- Professions/TailoringData.lua — Alfred (Tailoring)
-- Static data for the Tailoring profession (1-375, TBC Anniversary).
-- Mirrors the schema used by Alchemy/Enchanting so Core renders it without
-- special-casing. Globals (AlfredTailoring*) are picked up by the adapter
-- in Professions/Tailoring.lua and forwarded to Alfred.RegisterProfession.
--
-- Source: https://www.wow-professions.com/tbc/tailoring-leveling-guide-burning-crusade-classic
-- Item IDs verified against Wowhead where confident; uncertain ones may
-- show wrong icons until corrected (shift+click the row to confirm).

-- ============================================================================
-- AlfredTailoringData -- Artisan-style structured schema (same shape as Alchemy)
-- ============================================================================
AlfredTailoringData = {
    professionName = "Tailoring",
    maxSkill       = 375,
    icon           = "Interface\\Icons\\Trade_Tailoring",

    steps = {
        -- -- 1-75: Apprentice ------------------------------------------------
        { skillStart = 1,   skillEnd = 45,
          recipeName = "Bolt of Linen Cloth", kind = "tailor", quantity = 102,
          outputItemId = 2996, color = "orange",
          materials = {
              { name = "Linen Cloth", itemId = 2589, quantity = 204 },
          },
          notes = "Stop at 45; the bolts are reagents for the next two steps." },

        { skillStart = 40,  skillEnd = 67,
          recipeName = "Linen Belt", kind = "tailor", quantity = 35,
          outputItemId = 2568, color = "orange",
          materials = {
              { name = "Bolt of Linen Cloth", itemId = 2996, quantity = 35 },
              { name = "Coarse Thread",       itemId = 2605, quantity = 35 },
          },
          notes = "Overlaps with Bolt of Linen if you didn't make all 102." },

        { skillStart = 67,  skillEnd = 75,
          recipeName = "Reinforced Linen Cape", kind = "tailor", quantity = 8,
          outputItemId = 2569, color = "orange",
          materials = {
              { name = "Bolt of Linen Cloth", itemId = 2996, quantity = 16 },
              { name = "Coarse Thread",       itemId = 2605, quantity = 24 },
          } },

        -- -- 75-125: Journeyman ---------------------------------------------
        { skillStart = 75,  skillEnd = 100,
          recipeName = "Bolt of Woolen Cloth", kind = "tailor", quantity = 45,
          outputItemId = 2997, color = "orange",
          materials = {
              { name = "Wool Cloth", itemId = 2592, quantity = 135 },
          } },

        { skillStart = 100, skillEnd = 110,
          recipeName = "Simple Kilt", kind = "tailor", quantity = 13,
          outputItemId = 2572, color = "orange",
          materials = {
              { name = "Bolt of Linen Cloth", itemId = 2996, quantity = 52 },
              { name = "Fine Thread",         itemId = 2604, quantity = 13 },
          },
          notes = "May need a few extras if skill gains lag." },

        { skillStart = 110, skillEnd = 125,
          recipeName = "Double-Stitched Woolen Shoulders", kind = "tailor", quantity = 15,
          outputItemId = 4242, color = "orange",
          materials = {
              { name = "Bolt of Woolen Cloth", itemId = 2997, quantity = 45 },
              { name = "Fine Thread",          itemId = 2604, quantity = 30 },
          } },

        -- -- 125-205: Expert ------------------------------------------------
        { skillStart = 125, skillEnd = 145,
          recipeName = "Bolt of Silk Cloth", kind = "tailor", quantity = 201,
          outputItemId = 4305, color = "orange",
          materials = {
              { name = "Silk Cloth", itemId = 4306, quantity = 804 },
          },
          notes = "Bulk of the bolts are reagents for the next steps." },

        { skillStart = 145, skillEnd = 160,
          recipeName = "Azure Silk Hood", kind = "tailor", quantity = 18,
          outputItemId = 7048, color = "orange",
          materials = {
              { name = "Bolt of Silk Cloth", itemId = 4305, quantity = 36 },
              { name = "Blue Dye",           itemId = 6260, quantity = 36 },
              { name = "Fine Thread",        itemId = 2604, quantity = 18 },
          } },

        { skillStart = 160, skillEnd = 170,
          recipeName = "Silk Headband", kind = "tailor", quantity = 10,
          outputItemId = 7026, color = "orange",
          materials = {
              { name = "Bolt of Silk Cloth", itemId = 4305, quantity = 30 },
              { name = "Fine Thread",        itemId = 2604, quantity = 20 },
          } },

        { skillStart = 170, skillEnd = 175,
          recipeName = "Formal White Shirt", kind = "tailor", quantity = 5,
          outputItemId = 10054, color = "orange",
          materials = {
              { name = "Bolt of Silk Cloth", itemId = 4305, quantity = 15 },
              { name = "Bleach",             itemId = 2880, quantity = 10 },
              { name = "Fine Thread",        itemId = 2604, quantity = 5 },
          } },

        { skillStart = 175, skillEnd = 185,
          recipeName = "Bolt of Mageweave", kind = "tailor", quantity = 94,
          outputItemId = 4339, color = "orange",
          materials = {
              { name = "Mageweave Cloth", itemId = 4338, quantity = 470 },
          } },

        { skillStart = 185, skillEnd = 205,
          recipeName = "Crimson Silk Vest", kind = "tailor", quantity = 20,
          outputItemId = 7649, color = "orange",
          materials = {
              { name = "Bolt of Silk Cloth", itemId = 4305, quantity = 80 },
              { name = "Fine Thread",        itemId = 2604, quantity = 40 },
              { name = "Red Dye",            itemId = 2604, quantity = 40 },
          },
          notes = "TODO: verify Red Dye itemId (placeholder shares Fine Thread id)." },

        -- -- 205-300: Artisan -----------------------------------------------
        { skillStart = 205, skillEnd = 215,
          recipeName = "Crimson Silk Pantaloons", kind = "tailor", quantity = 10,
          outputItemId = 7639, color = "orange",
          materials = {
              { name = "Bolt of Silk Cloth", itemId = 4305, quantity = 40 },
              { name = "Red Dye",            itemId = 2604, quantity = 20 },
              { name = "Silken Thread",      itemId = 4291, quantity = 20 },
          } },

        { skillStart = 215, skillEnd = 220,
          recipeName = "Orange Mageweave Shirt", kind = "tailor", quantity = 5,
          outputItemId = 10046, color = "orange",
          materials = {
              { name = "Bolt of Mageweave",     itemId = 4339, quantity = 5 },
              { name = "Orange Dye",            itemId = 6261, quantity = 5 },
              { name = "Heavy Silken Thread",   itemId = 8343, quantity = 5 },
          } },

        { skillStart = 220, skillEnd = 230,
          recipeName = "Black Mageweave Gloves", kind = "tailor", quantity = 10,
          outputItemId = 10006, color = "orange",
          materials = {
              { name = "Bolt of Mageweave",   itemId = 4339, quantity = 20 },
              { name = "Heavy Silken Thread", itemId = 8343, quantity = 20 },
          } },

        { skillStart = 230, skillEnd = 250,
          recipeName = "Black Mageweave Headband", kind = "tailor", quantity = 23,
          outputItemId = 10009, color = "orange",
          materials = {
              { name = "Bolt of Mageweave",   itemId = 4339, quantity = 69 },
              { name = "Heavy Silken Thread", itemId = 8343, quantity = 46 },
          } },

        { skillStart = 250, skillEnd = 260,
          recipeName = "Bolt of Runecloth", kind = "tailor", quantity = 188,
          outputItemId = 14048, color = "orange",
          materials = {
              { name = "Runecloth", itemId = 14047, quantity = 940 },
          },
          notes = "Massive bolt batch -- reagent for the rest of the Classic range." },

        { skillStart = 260, skillEnd = 280,
          recipeName = "Runecloth Belt", kind = "tailor", quantity = 25,
          outputItemId = 13854, color = "orange",
          materials = {
              { name = "Bolt of Runecloth", itemId = 14048, quantity = 75 },
              { name = "Rune Thread",       itemId = 14341, quantity = 25 },
          },
          notes = "Yellow at 270 -- plan a few extras." },

        -- -- 280-300: PICK ONE of three Classic alts ------------------------
        -- Cost differs per realm: gold-bar route is steadier; runecloth+leather
        -- variant scales with cheap leather; wizardweave needs Dream Dust.
        { kind = "header", recipeName = "===  280-300: Pick ONE Classic path  ===" },

        { skillStart = 280, skillEnd = 300,
          recipeName = "Brightcloth Cloak", kind = "tailor", quantity = 25,
          outputItemId = 13868, color = "orange",
          materials = {
              { name = "Bolt of Runecloth", itemId = 14048, quantity = 100 },
              { name = "Gold Bar",          itemId = 3577,  quantity = 50 },
              { name = "Rune Thread",       itemId = 14341, quantity = 25 },
          },
          notes = "Default 280-300 path -- viable when Gold Bars are cheap." },

        { skillStart = 280, skillEnd = 300,
          recipeName = "Runecloth Gloves", kind = "tailor", quantity = 25,
          outputItemId = 13856, optional = true, color = "orange",
          materials = {
              { name = "Bolt of Runecloth", itemId = 14048, quantity = 100 },
              { name = "Rugged Leather",    itemId = 8170,  quantity = 100 },
              { name = "Rune Thread",       itemId = 14341, quantity = 25 },
          },
          notes = "Alt 280-300 -- pick if Rugged Leather is cheap." },

        { skillStart = 280, skillEnd = 300,
          recipeName = "Wizardweave Leggings", kind = "tailor", quantity = 25,
          outputItemId = 13864, optional = true, color = "orange",
          materials = {
              { name = "Bolt of Runecloth", itemId = 14048, quantity = 150 },
              { name = "Dream Dust",        itemId = 11176, quantity = 25 },
              { name = "Rune Thread",       itemId = 14341, quantity = 25 },
          },
          notes = "Alt 280-300 -- needs +250 extra Runecloth, viable if Dream Dust is cheap." },

        -- -- 300-375: Master (TBC) ------------------------------------------
        { skillStart = 300, skillEnd = 325,
          recipeName = "Bolt of Netherweave", kind = "tailor", quantity = 496,
          outputItemId = 21840, color = "orange",
          materials = {
              { name = "Netherweave Cloth", itemId = 21877, quantity = 2976 },
          },
          notes = "All bolts are reagents for everything 325+. Make them all now for free skill points." },

        { skillStart = 325, skillEnd = 340,
          recipeName = "Bolt of Imbued Netherweave", kind = "tailor", quantity = 102,
          outputItemId = 21842, color = "orange",
          materials = {
              { name = "Bolt of Netherweave", itemId = 21840, quantity = 306 },
              { name = "Arcane Dust",         itemId = 22445, quantity = 204 },
          },
          notes = "Vendor recipe (Eiin, Shattrath). Requires Mana Loom (next to Eiin)." },

        { skillStart = 340, skillEnd = 345,
          recipeName = "Netherweave Boots", kind = "tailor", quantity = 5,
          outputItemId = 21874, color = "orange",
          materials = {
              { name = "Bolt of Netherweave", itemId = 21840, quantity = 30 },
              { name = "Knothide Leather",    itemId = 21887, quantity = 10 },
              { name = "Rune Thread",         itemId = 14341, quantity = 5 },
          },
          notes = "Recipe taught by the Hellfire Peninsula trainer." },

        { skillStart = 345, skillEnd = 360,
          recipeName = "Netherweave Tunic", kind = "tailor", quantity = 20,
          outputItemId = 21875, color = "orange",
          materials = {
              { name = "Bolt of Netherweave", itemId = 21840, quantity = 160 },
              { name = "Rune Thread",         itemId = 14341, quantity = 40 },
          },
          notes = "Vendor recipe (Eiin, Shattrath). Yellow for last 5 points." },

        -- -- 360-375: PICK ONE main path + alternatives --------------------
        { kind = "header", recipeName = "===  360-375: Pick ONE path  ===" },

        { skillStart = 360, skillEnd = 375,
          recipeName = "Imbued Netherweave Tunic", kind = "tailor", quantity = 17,
          outputItemId = 21876, color = "orange",
          materials = {
              { name = "Bolt of Imbued Netherweave", itemId = 21842, quantity = 102 },
              { name = "Netherweb Spider Silk",      itemId = 21881, quantity = 34 },
              { name = "Rune Thread",                itemId = 14341, quantity = 17 },
          },
          notes = "Vendor recipe: Arrond (Shadowmoon), Neutral with Scryers. Yellow for last 5 points." },

        { skillStart = 360, skillEnd = 375,
          recipeName = "Imbued Netherweave Robe", kind = "tailor", quantity = 17,
          optional = true, color = "orange",
          materials = {
              { name = "Bolt of Imbued Netherweave", itemId = 21842, quantity = 102 },
              { name = "Netherweb Spider Silk",      itemId = 21881, quantity = 34 },
              { name = "Rune Thread",                itemId = 14341, quantity = 17 },
          },
          notes = "Alt 360-375 -- same vendor + reagents as Tunic; identical cost." },

        { skillStart = 360, skillEnd = 375,
          recipeName = "Arcanoweave Boots", kind = "tailor", quantity = 18,
          optional = true, color = "orange",
          materials = {
              { name = "Bolt of Netherweave", itemId = 21840, quantity = 144 },
              { name = "Arcane Dust",         itemId = 22445, quantity = 288 },
              { name = "Rune Thread",         itemId = 14341, quantity = 36 },
          },
          notes = "Alt 360-375 -- recipe drops from Sunseeker Astromages (Mechanar). Yellow at 370." },

        { skillStart = 370, skillEnd = 375,
          recipeName = "Arcanoweave Robe", kind = "tailor", quantity = 4,
          optional = true, color = "orange",
          materials = {
              { name = "Bolt of Netherweave", itemId = 21840, quantity = 48 },
              { name = "Arcane Dust",         itemId = 22445, quantity = 80 },
              { name = "Rune Thread",         itemId = 14341, quantity = 8 },
          },
          notes = "Alt 370-375 -- recipe drops from Pathaleon (Mechanar). Pairs well with Arcanoweave Boots." },
    },
}

-- ============================================================================
-- Canonical shopping list (counts hand-tuned to wow-professions)
-- ============================================================================
AlfredTailoringShoppingList = {
    -- ---- Cloth (Classic) ----------------------------------------------------
    { id = 2589,  name = "Linen Cloth",     count = 204 },
    { id = 2592,  name = "Wool Cloth",      count = 135 },
    { id = 4306,  name = "Silk Cloth",      count = 804 },
    { id = 4338,  name = "Mageweave Cloth", count = 470 },
    { id = 14047, name = "Runecloth",       count = 940 },

    -- ---- Cloth (TBC) --------------------------------------------------------
    { id = 21877, name = "Netherweave Cloth", count = 2976 },

    -- ---- Threads ------------------------------------------------------------
    { id = 2605,  name = "Coarse Thread",       count = 59  },
    { id = 2604,  name = "Fine Thread",         count = 126 }, -- 43 Journeyman + 83 Expert
    { id = 4291,  name = "Silken Thread",       count = 20  },
    { id = 8343,  name = "Heavy Silken Thread", count = 71  },
    { id = 14341, name = "Rune Thread",         count = 121 }, -- 25 belt + 25 280-300 + 5 boots + 40 tunic + 17 imbued + 9 buffer

    -- ---- Dyes ---------------------------------------------------------------
    { id = 6260, name = "Blue Dye",   count = 36 },
    { id = 2604, name = "Red Dye",    count = 60 }, -- TODO verify itemId (currently shares Fine Thread id)
    { id = 2880, name = "Bleach",     count = 10 },
    { id = 6261, name = "Orange Dye", count = 5  },

    -- ---- TBC components -----------------------------------------------------
    { id = 22445, name = "Arcane Dust",         count = 204 },
    { id = 21887, name = "Knothide Leather",    count = 10  },
    { id = 21881, name = "Netherweb Spider Silk", count = 34 },

    -- ---- Alternatives for the 280-300 path (kind="alt" excludes from total) -
    -- Brightcloth Cloak (default) uses Gold Bar 50x. Listed below are the
    -- mats unique to the OTHER two alt paths (Runecloth Gloves / Wizardweave
    -- Leggings). Pick whichever is cheapest on your realm.
    { kind = "alt", id = 3577,  name = "Gold Bar (Brightcloth Cloak, 25x)",         count = 50 },
    { kind = "alt", id = 8170,  name = "Rugged Leather (Runecloth Gloves, 25x)",    count = 100 },
    { kind = "alt", id = 11176, name = "Dream Dust (Wizardweave Leggings, 25x)",    count = 25 },
    { kind = "alt", id = 14048, name = "Bolt of Runecloth (Wizardweave +250 extra Runecloth)", count = 50 },

    -- ---- Vendor / drop recipes (NOT learned from the trainer) ---------------
    { kind = "recipe", id = 22307, name = "Pattern: Bolt of Imbued Netherweave",
      vendor = "Eiin (Shattrath, Lower City)",
      req    = "Required for 325-340 (main path)" },
    { kind = "recipe", id = 22310, name = "Pattern: Netherweave Tunic",
      vendor = "Eiin (Shattrath, Lower City)",
      req    = "Required for 345-360 (main path)" },
    { kind = "recipe", id = 22311, name = "Pattern: Imbued Netherweave Tunic",
      vendor = "Arrond (Shadowmoon Valley, Sanctum of the Stars)",
      req    = "Neutral Scryers reputation -- 360-375 main" },
    { kind = "recipe", id = 22312, name = "Pattern: Imbued Netherweave Robe",
      vendor = "Arrond (Shadowmoon Valley, Sanctum of the Stars)",
      req    = "Neutral Scryers -- alt for 360-375" },
    { kind = "recipe", id = 24292, name = "Pattern: Arcanoweave Boots",
      vendor = "World drop -- Sunseeker Astromages (The Mechanar)",
      req    = "Optional alt for 360-375" },
    { kind = "recipe", id = 24293, name = "Pattern: Arcanoweave Robe",
      vendor = "World drop -- Pathaleon the Calculator (The Mechanar)",
      req    = "Optional alt for 370-375" },
}

-- ============================================================================
-- Back-compat: derived AlfredTailoringGuide / AlfredTailoringFullGuide
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

AlfredTailoringGuide     = {}
AlfredTailoringFullGuide = {}
for i, step in ipairs(AlfredTailoringData.steps) do
    local rangeStr = FormatRange(step.skillStart, step.skillEnd)
    AlfredTailoringGuide[i] = {
        spell    = step.recipeName,
        kind     = step.kind,
        range    = rangeStr,
        count    = step.quantity,
        optional = step.optional,
        notes    = step.notes,
    }
    AlfredTailoringFullGuide[i] = {
        range    = rangeStr,
        spell    = step.recipeName,
        count    = step.quantity,
        reagents = MaterialsToString(step.materials),
        optional = step.optional,
        notes    = step.notes,
    }
end
