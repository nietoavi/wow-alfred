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

function A.Spells.IsLearned(spellName)
    if not spellName then return true end  -- nothing to validate → assume OK

    -- Method 1: GetSpellLink — returns a link only for known spells.
    -- If it returns something, you definitely know the spell.
    if GetSpellLink then
        local link = GetSpellLink(spellName)
        if link and link ~= "" then return true end
    end

    -- Method 2: iterated spellbook (includes Trade Skills tab if it works).
    if not knownSpellsBuilt then BuildKnownSpells() end
    if knownSpells[spellName] then return true end

    -- Method 3: GetSpellInfo by name. In TBC Classic this typically returns
    -- nil for unlearned spells; but there are variants. If it returns
    -- something, assume yes (false positive is preferable to false negative:
    -- a false negative blocks the button when you actually could cast).
    if GetSpellInfo then
        local name = GetSpellInfo(spellName)
        if name then return true end
    end

    -- No method found the spell. Probably not learned.
    return false
end

function A.Spells.GetIcon(spellName)
    if not spellName or not GetSpellInfo then return nil end
    local _, _, icon = GetSpellInfo(spellName)
    return icon
end
