-- Core/Registry.lua — Alfred-Enchanting (Phase 2)
-- Profession registry. Each Professions/<X>.lua calls
-- Alfred.RegisterProfession({...}) and that gets attached both to the global
-- _G.Alfred (public API for future addons) and to A.Profession (so Core can
-- read the active profession's data without knowing which one it is).
--
-- Def contract (camelCase for callbacks, PascalCase for constants):
--   id                 — unique string ("enchanting")
--   name               — display string ("Enchanting")
--   MacroName          — name of the WoW macro we keep in sync
--   LegacyMacroName    — old name to rename on first run (optional)
--   MacroIconDefault   — fallback icon if GetSpellInfo doesn't return one
--   PopupName          — name of the StaticPopup to auto-confirm (e.g. "REPLACE_ENCHANT")
--   LogPrefix          — colored prefix for chat prints
--   slots              — array {key, label} (may be nil if the prof has no target items)
--   slotDefaults       — table[slotKey] = itemName
--   slotMap            — table[spellName|spellID] = slotKey
--   guide              — array of steps {spell, kind, range, count, optional, notes}
--   fullGuide          — detailed array {range, spell, count, reagents, optional, notes}
--   shoppingList       — array {id, name, count}
--   GetSpellIDFromRecipeLink(link) — extracts spell ID from the recipe link
--   IsTradeskillOpen()             — heuristic to detect the prof's UI
local _, A = ...

_G.Alfred = _G.Alfred or {}

local registered = {}
local activeId

function Alfred.RegisterProfession(def)
    assert(def and def.id, "Alfred.RegisterProfession: def.id is required")
    registered[def.id] = def
    -- The first registered profession becomes the active default.
    if not activeId then
        activeId = def.id
        A.Profession = def
    end
end

function Alfred.GetProfession(id)
    return registered[id]
end

function Alfred.GetActiveProfession()
    return registered[activeId]
end

function Alfred.GetActiveProfessionId()
    return activeId
end

-- Switches the active profession. Re-binds A.Profession so Core sees it.
-- In Phase 2 only one profession is registered, so this setter is here to
-- prepare for Phase 4 (multi-profession).
function Alfred.SetActiveProfession(id)
    local def = registered[id]
    if not def then return false, "profession not registered: " .. tostring(id) end
    activeId = id
    A.Profession = def
    return true
end

function Alfred.GetRegisteredProfessions()
    local list = {}
    for id in pairs(registered) do table.insert(list, id) end
    table.sort(list)
    return list
end
