-- Core/Registry.lua — Alfred (Phase 4)
-- Profession registry. Each Professions/<X>.lua calls
-- Alfred.RegisterProfession({...}) and that gets attached both to the global
-- _G.Alfred (public API for future addons) and to A.Profession (so Core can
-- read the active profession's data without knowing which one it is).
--
-- Def contract (camelCase for callbacks, PascalCase for constants):
--   id                 — unique string ("enchanting")
--   name               — display string ("Enchanting")
--   skillName          — name of the skill in the player's skill list
--                        (matched against GetSkillLineInfo for "is learned")
--   icon               — texture path for the header icon
--   MacroName          — name of the WoW macro we keep in sync
--   LegacyMacroName    — old name to rename on first run (optional)
--   MacroIconDefault   — fallback icon if GetSpellInfo doesn't return one
--   PopupName          — name of the StaticPopup to auto-confirm
--                        (e.g. "REPLACE_ENCHANT"); nil if the profession has no popup
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
local order = {}      -- registration order (so list/default is deterministic)
local activeId

function Alfred.RegisterProfession(def)
    assert(def and def.id, "Alfred.RegisterProfession: def.id is required")
    if not registered[def.id] then
        table.insert(order, def.id)
    end
    registered[def.id] = def
    -- The first registered profession becomes the active default.
    -- DB.Init() may later overwrite this with the player's saved preference
    -- (or with "first learned" if no preference exists).
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
-- Returns true on success, false+message on unknown id.
function Alfred.SetActiveProfession(id)
    local def = registered[id]
    if not def then return false, "profession not registered: " .. tostring(id) end
    activeId = id
    A.Profession = def
    return true
end

-- All registered profession ids in registration order (matches the load order
-- in the .toc, which keeps lists/defaults predictable).
function Alfred.GetRegisteredProfessions()
    local list = {}
    for _, id in ipairs(order) do table.insert(list, id) end
    return list
end

-- ============================================================================
-- "Is this profession learned by the active character?"
-- TBC Classic exposes this via the legacy GetNumSkillLines / GetSkillLineInfo
-- APIs (the Skills tab in the character pane). We iterate once, cache by
-- skillName, and let Engine.lua invalidate on SKILL_LINES_CHANGED.
-- ============================================================================
local skillCache       -- table[skillName] = { rank = N, max = N } when learned
local skillCacheValid  -- boolean: true if skillCache reflects current state

local function RebuildSkillCache()
    skillCache = {}
    if not GetNumSkillLines or not GetSkillLineInfo then
        skillCacheValid = true
        return
    end
    for i = 1, (GetNumSkillLines() or 0) do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if name and not isHeader then
            skillCache[name] = { rank = rank or 0, max = maxRank or 0 }
        end
    end
    skillCacheValid = true
end

function Alfred.InvalidateLearnedCache()
    skillCacheValid = false
end

-- Returns: learned (bool), currentRank (int|nil), maxRank (int|nil)
function Alfred.IsProfessionLearned(id)
    local def = registered[id]
    if not def or not def.skillName then return false end
    if not skillCacheValid then RebuildSkillCache() end
    local entry = skillCache and skillCache[def.skillName]
    if not entry then return false end
    return true, entry.rank, entry.max
end
