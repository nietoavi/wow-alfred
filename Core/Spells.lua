-- Core/Spells.lua — Alfred-Enchanting
-- Detection of learned spells. In TBC Classic, enchanting recipes don't always
-- show up in the iterated spellbook; we use multiple methods.
local _, A = ...
A.Spells = {}

-- Cache of spells iterated from the spellbook. Rebuilt on demand and on
-- LEARNED_SPELL_IN_TAB / SKILL_LINES_CHANGED (Engine.lua calls Invalidate).
local knownSpells = {}
local knownSpellsBuilt = false

local function BuildKnownSpells()
    knownSpells = {}
    if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName) then
        knownSpellsBuilt = true
        return
    end
    local numTabs = GetNumSpellTabs() or 0
    for tab = 1, numTabs do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        if offset and numSpells then
            for i = offset + 1, offset + numSpells do
                local name = GetSpellBookItemName(i, "spell")
                if name then knownSpells[name] = true end
            end
        end
    end
    knownSpellsBuilt = true
end

function A.Spells.InvalidateCache()
    knownSpellsBuilt = false
end

-- For diagnostics (/aen test).
function A.Spells.GetCache()
    if not knownSpellsBuilt then BuildKnownSpells() end
    return knownSpells
end

-- IsLearned(spellName, [step])
-- The optional `step` argument lets us apply a skill-range heuristic as the
-- last fallback: if the player's profession rank already covers
-- step.skillStart, assume they trained the recipe when they passed that rank.
-- That way the cast button works at a fresh login WITHOUT the player ever
-- having to open the profession window.
function A.Spells.IsLearned(spellName, step)
    if not spellName then return true end  -- nothing to validate, assume OK

    -- Method 0 (preferred): per-character persistent learned-list for the
    -- ACTIVE profession. Populated from prior tradeskill scans (see
    -- Core/CraftList.lua). Definitive answer when populated, "no info" when
    -- the list is empty (first session, never opened the profession).
    if A.CraftList and Alfred and Alfred.GetActiveProfessionId then
        local profId = Alfred.GetActiveProfessionId()
        local res = A.CraftList.IsLearned(profId, spellName)
        if res == true then return true end
        if res == false then return false end
        -- res == nil: no info yet, fall through to live detection methods.
    end

    -- Method 1: GetSpellLink -- returns a link only for known spells.
    if GetSpellLink then
        local link = GetSpellLink(spellName)
        if link and link ~= "" then return true end
    end

    -- Method 2: iterated spellbook (includes Trade Skills tab if it works).
    if not knownSpellsBuilt then BuildKnownSpells() end
    if knownSpells[spellName] then return true end

    -- Method 3: GetSpellInfo by name. Returns something for any spell that
    -- exists in the client (whether learned or not), so a positive here is
    -- weak evidence -- but a positive is still better than a false-negative.
    if GetSpellInfo then
        local name = GetSpellInfo(spellName)
        if name then return true end
    end

    -- Method 4: scan the currently-open tradeskill window. This catches
    -- profession recipes (Alchemy/Tailoring/etc.) that the spellbook APIs
    -- sometimes miss in TBC Classic. If the tradeskill UI is open AND a
    -- full scan does NOT find the recipe, that's strong evidence it's not
    -- learned. If the UI is closed we can't know, so we don't conclude.
    if GetNumTradeSkills and GetTradeSkillInfo then
        local n = GetNumTradeSkills() or 0
        if n > 0 then
            for i = 1, n do
                local name, skillType = GetTradeSkillInfo(i)
                if name == spellName and skillType and skillType ~= "header" then
                    return true
                end
            end
            -- Open + fully scanned + not found: definitively unlearned.
            return false
        end
    end

    -- Method 5: skill-range heuristic. If the caller passed the step entry
    -- AND the player's profession skill is at-or-past the recipe's
    -- skillStart, assume it was learned at the trainer when they hit that
    -- rank. Trainable recipes match this 95%+ of the time; vendor/quest/
    -- drop recipes are the main exceptions and they fall through.
    if step and step.skillStart and Alfred and Alfred.IsProfessionLearned then
        local profId = Alfred.GetActiveProfessionId()
        if profId then
            local _, rank = Alfred.IsProfessionLearned(profId)
            if rank and rank >= step.skillStart then
                return true
            end
        end
    end

    -- All positive checks failed and the tradeskill UI wasn't open to give
    -- us a definitive answer. Default to true (false positive) so the cast
    -- button isn't pointlessly disabled when the player COULD cast -- the
    -- in-game "you don't know that spell" error is recoverable.
    return true
end

function A.Spells.GetIcon(spellName)
    if not spellName or not GetSpellInfo then return nil end
    local _, _, icon = GetSpellInfo(spellName)
    return icon
end
