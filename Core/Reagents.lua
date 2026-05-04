-- Core/Reagents.lua — Alfred-Enchanting
-- Reagent string parsing and step-requirement validation.
local _, A = ...
A.Reagents = {}

-- Look up the detailed FullGuide entry by (spell, range). If no exact match,
-- fall back to the first entry matching spell only.
function A.Reagents.FindFullEntry(spell, range)
    local fullGuide = A.Profession.fullGuide
    if not fullGuide then return nil end
    for _, e in ipairs(fullGuide) do
        if e.spell == spell and e.range == range then return e end
    end
    for _, e in ipairs(fullGuide) do
        if e.spell == spell then return e end
    end
    return nil
end

-- Parses "48 Strange Dust, 2 Greater Magic Essence" → list of
-- { totalCount, perCast, name }.
function A.Reagents.Parse(reagentsStr, totalCasts)
    if not reagentsStr or reagentsStr == "" or reagentsStr == "alternative" then
        return {}
    end
    local result = {}
    for chunk in reagentsStr:gmatch("([^,]+)") do
        chunk = chunk:match("^%s*(.-)%s*$") or chunk
        local n, name = chunk:match("^(%d+)%s+(.+)$")
        if n and name then
            local total = tonumber(n) or 0
            local perCast = (totalCasts and totalCasts > 0)
                and math.ceil(total / totalCasts) or total
            table.insert(result, {
                totalCount = total, perCast = perCast, name = name,
            })
        end
    end
    return result
end

-- Counts items in bag preferentially by itemId (more reliable than by name,
-- locale-independent). Falls back to A.Bags.Count(name) if no itemId.
local function CountItem(itemId, name)
    if itemId and GetItemCount then
        local n = GetItemCount(itemId)
        if n and n > 0 then return n end
    end
    return A.Bags.Count(name)
end

-- Validates recipe + mats for a step. Returns a struct with flags.
-- Prefers structured materials (entry.materials) — the modern path.
-- Falls back to parsing the FullGuide string only if materials aren't available.
function A.Reagents.CheckStep(entry)
    local result = {
        learned = true, hasAllMats = true,
        missingMats = {},  -- list of {name, have, need}
    }
    if not entry or not entry.spell then return result end

    -- 1) Spell learned. Pass the whole entry so IsLearned can use the
    -- skill-range heuristic when no other detection method works (avoids
    -- forcing the player to open the profession window first).
    result.learned = A.Spells.IsLearned(entry.spell, entry)

    -- 2a) New path: structured materials with itemId.
    if entry.materials and #entry.materials > 0 then
        local total = entry.quantity or entry.count or 1
        for _, m in ipairs(entry.materials) do
            local needPerCast = (total > 0) and math.ceil(m.quantity / total) or m.quantity
            local have = CountItem(m.itemId, m.name)
            if have < needPerCast then
                result.hasAllMats = false
                table.insert(result.missingMats, { name = m.name, have = have, need = needPerCast })
            end
        end
        return result
    end

    -- 2b) Legacy path: parse the reagent string from FullGuide.
    local fullEntry = A.Reagents.FindFullEntry(entry.spell, entry.range)
    local reagents = A.Reagents.Parse(fullEntry and fullEntry.reagents, entry.count)
    for _, r in ipairs(reagents) do
        local have = A.Bags.Count(r.name)
        if have < r.perCast then
            result.hasAllMats = false
            table.insert(result.missingMats, { name = r.name, have = have, need = r.perCast })
        end
    end
    return result
end

-- ============================================================================
-- MaxCraftsFor(entry): how many times can the player craft this recipe RIGHT
-- NOW given what's currently in their bag/bank? Returns 0 if any reagent is
-- below the per-cast requirement, otherwise the bottleneck of all reagents.
-- Used to populate the "Craft (N)" button label and to pass an explicit
-- count to DoTradeSkill so the server enqueues the whole batch.
-- ============================================================================
function A.Reagents.MaxCraftsFor(entry)
    if not entry or not entry.materials or #entry.materials == 0 then return 1 end
    local total = entry.quantity or entry.count or 1
    local minPossible = math.huge
    for _, m in ipairs(entry.materials) do
        local perCast = (total > 0) and math.ceil(m.quantity / total) or m.quantity
        if perCast > 0 then
            local have = CountItem(m.itemId, m.name)
            local maxFromThis = math.floor((have or 0) / perCast)
            if maxFromThis < minPossible then minPossible = maxFromThis end
        end
    end
    if minPossible == math.huge then return 0 end
    return math.max(0, minPossible)
end

-- ============================================================================
-- CraftsToReachSkillEnd(entry): heuristic for "how many more crafts before
-- the player levels past this step's skillEnd?". Used to cap the bulk
-- queue so we don't waste mats once the step's purpose is fulfilled.
--
--   Effective target = min(step.skillEnd, current profession cap)
--     -- if the player hasn't visited a trainer, capping at the cap
--     prevents queueing crafts that can't possibly land a skill point.
--   Crafts per skill point (color-based, with a 20% safety margin):
--     orange = 1.0  (every craft gives a point)
--     yellow = 1.5  (~75% chance per craft)
--     green  = 4.0  (~25% chance per craft)
--     gray   = inf  (no skill ups -- skip the cap)
--
-- Returns 0 if the player has already reached the step's effective skillEnd.
-- ============================================================================
function A.Reagents.CraftsToReachSkillEnd(entry)
    if not entry or not entry.skillEnd then return math.huge end
    if not Alfred or not Alfred.IsProfessionLearned then return math.huge end
    local profId = Alfred.GetActiveProfessionId()
    if not profId then return math.huge end
    local _, currentSkill, maxRank = Alfred.IsProfessionLearned(profId)
    currentSkill = currentSkill or 0
    local target = entry.skillEnd
    if maxRank and maxRank > 0 then target = math.min(target, maxRank) end
    if currentSkill >= target then return 0 end

    local color = entry.color or "orange"
    local craftsPerPoint
    if     color == "orange" then craftsPerPoint = 1.0
    elseif color == "yellow" then craftsPerPoint = 1.5
    elseif color == "green"  then craftsPerPoint = 4.0
    else                          craftsPerPoint = math.huge  -- gray, no cap
    end

    if craftsPerPoint == math.huge then return math.huge end
    return math.ceil((target - currentSkill) * craftsPerPoint * 1.2)
end

-- ============================================================================
-- AggregateFrom(stepIdx): sums all materials from the given step onwards
-- (skipping optionals). Returns an ordered list of materials with aggregated
-- totals and bag counts. Used by the Shopping List tab.
-- ============================================================================
function A.Reagents.AggregateFrom(fromStepIdx)
    local data = A.Profession and A.Profession.data
    if not data or not data.steps then return {} end
    fromStepIdx = math.max(1, fromStepIdx or 1)

    local needed = {}
    for i = fromStepIdx, #data.steps do
        local step = data.steps[i]
        if step.materials and not step.optional then
            for _, m in ipairs(step.materials) do
                local key = m.itemId or m.name
                if needed[key] then
                    needed[key].quantity = needed[key].quantity + m.quantity
                else
                    needed[key] = {
                        name      = m.name,
                        itemId    = m.itemId,
                        quantity  = m.quantity,
                        firstStep = i,
                    }
                end
            end
        end
    end

    local list = {}
    for _, m in pairs(needed) do
        m.have = CountItem(m.itemId, m.name)
        m.stillNeed = math.max(0, m.quantity - m.have)
        table.insert(list, m)
    end
    table.sort(list, function(a, b)
        if a.firstStep ~= b.firstStep then return a.firstStep < b.firstStep end
        return a.name < b.name
    end)
    return list
end
