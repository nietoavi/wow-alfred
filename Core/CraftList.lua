-- Core/CraftList.lua — Alfred
-- Per-character persistent set of recipes the player has actually learned,
-- per profession. Solves the "is this spell learned?" problem when the
-- profession's tradeskill UI isn't open: the spellbook APIs in TBC Classic
-- aren't reliable for tradeskill spells, so we cache scan results from the
-- last time the UI WAS open and use them everywhere afterwards.
--
-- Storage:
--   AlfredDB.learnedCrafts[charname-realm][profId][spellName] = true
--
-- Per-character keying so a Mage with Alchemy 200 doesn't pollute a Warrior
-- with Alchemy 50 on the same account (AlfredDB is shared across alts).
--
-- Used by A.Spells.IsLearned as the FIRST check; the previous detection
-- methods (GetSpellLink / spellbook iter / GetSpellInfo / open tradeskill
-- scan) become fallbacks for the case where the list hasn't been populated
-- yet (brand-new install, never opened the profession this session).
local _, A = ...
A.CraftList = {}

-- ============================================================================
-- Storage
-- ============================================================================
local function CharKey()
    local name  = (UnitName  and UnitName("player"))  or "Unknown"
    local realm = (GetRealmName and GetRealmName())   or "Unknown"
    return name .. "-" .. realm
end

local function ListTable(profId, createIfMissing)
    if not AlfredDB then return nil end
    if createIfMissing then
        AlfredDB.learnedCrafts = AlfredDB.learnedCrafts or {}
    end
    if not AlfredDB.learnedCrafts then return nil end
    local key = CharKey()
    if createIfMissing then
        AlfredDB.learnedCrafts[key] = AlfredDB.learnedCrafts[key] or {}
    end
    if not AlfredDB.learnedCrafts[key] then return nil end
    if createIfMissing then
        AlfredDB.learnedCrafts[key][profId] = AlfredDB.learnedCrafts[key][profId] or {}
    end
    return AlfredDB.learnedCrafts[key][profId]
end

-- ============================================================================
-- Public API
-- ============================================================================

-- Returns true if the spell is in the cached learned set, otherwise nil
-- (no info -- caller should fall back to other detection methods, including
-- the skill-range heuristic in A.Spells.IsLearned).
--
-- We deliberately do NOT return false when the cache exists but doesn't
-- list the spell: the cache could be stale (the player learned a recipe
-- after the last scan and never re-opened the profession). Treating
-- "missing from cache" as a hard "no" would block the skill-range
-- heuristic from rescuing those cases.
function A.CraftList.IsLearned(profId, spellName)
    if not profId or not spellName then return nil end
    local t = ListTable(profId, false)
    if not t then return nil end
    if t[spellName] == true then return true end
    return nil
end

function A.CraftList.MarkLearned(profId, spellName)
    if not profId or not spellName then return end
    local t = ListTable(profId, true)
    if t then t[spellName] = true end
end

function A.CraftList.Clear(profId)
    local t = ListTable(profId, false)
    if not t then return end
    for k in pairs(t) do t[k] = nil end
end

function A.CraftList.ClearAll()
    if not AlfredDB then return end
    local key = CharKey()
    if AlfredDB.learnedCrafts then
        AlfredDB.learnedCrafts[key] = nil
    end
end

-- Counts of (learned, total-listed-in-data). Total counts non-header steps
-- with a recipeName; learned counts those whose name is in the cached set.
-- Used by /alfred recipes for status output.
function A.CraftList.GetStats(profId)
    local def = profId and Alfred and Alfred.GetProfession(profId)
    if not def or not def.data or not def.data.steps then return 0, 0 end
    local t = ListTable(profId, false)
    local learned, total, seen = 0, 0, {}
    for _, step in ipairs(def.data.steps) do
        local n = step.recipeName
        if n and step.kind ~= "header" and not seen[n] then
            seen[n] = true
            total = total + 1
            if t and t[n] then learned = learned + 1 end
        end
    end
    return learned, total
end

-- ============================================================================
-- Scan: walks the currently-open tradeskill window and adds every non-header
-- recipe to the cache for the matching Alfred profession (matched by
-- skillName -> profession.skillName). Idempotent and cheap (a few dozen
-- table writes). Called by Engine on TRADE_SKILL_SHOW / TRADE_SKILL_UPDATE
-- and on demand by `/alfred recipes rescan`.
-- ============================================================================
function A.CraftList.ScanOpenTradeskill()
    if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillInfo then
        return 0
    end
    local lineName = GetTradeSkillLine()
    if not lineName or lineName == "" or lineName == "UNKNOWN" then return 0 end

    -- Match the open tradeskill against a registered profession by skillName.
    local matchedProfId
    if Alfred and Alfred.GetRegisteredProfessions then
        for _, id in ipairs(Alfred.GetRegisteredProfessions()) do
            local def = Alfred.GetProfession(id)
            if def and def.skillName == lineName then
                matchedProfId = id
                break
            end
        end
    end
    if not matchedProfId then return 0 end

    local n = GetNumTradeSkills() or 0
    if n == 0 then return 0 end

    local t = ListTable(matchedProfId, true)
    if not t then return 0 end

    local added = 0
    for i = 1, n do
        local name, skillType = GetTradeSkillInfo(i)
        if name and skillType and skillType ~= "header" and not t[name] then
            t[name] = true
            added = added + 1
        end
    end

    -- Refresh the panel so the cast button enables immediately if the user
    -- was looking at a step whose recipe just got promoted to "learned".
    if added > 0 and A.UI and A.UI.MainPanel and A.UI.MainPanel.UpdateButton then
        A.UI.MainPanel.UpdateButton()
    end
    return added
end
