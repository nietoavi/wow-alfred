-- Core/Tradeskill.lua — Alfred-Enchanting
-- Wrappers over the legacy tradeskill API (GetTradeSkill*) used by the legacy
-- direct-cast flow (DoCast/Bulk). The current macro flow doesn't depend on
-- the recipe selected in the UI, so these functions are mainly used by
-- /aen debug and /aen scan.
local _, A = ...
A.Tradeskill = {}

function A.Tradeskill.GetSpellIDForRecipe(skillIndex)
    if not GetTradeSkillRecipeLink then return nil end
    local link = GetTradeSkillRecipeLink(skillIndex)
    if not link then return nil end
    -- Delegate link parsing to the profession module (each profession has its
    -- own prefix: enchant:, item:, etc.).
    return A.Profession.GetSpellIDFromRecipeLink(link)
end

function A.Tradeskill.GetReagentCapacity(skillIndex)
    local numReagents = GetTradeSkillNumReagents(skillIndex) or 0
    if numReagents == 0 then return 999 end
    local capacity = 999
    for i = 1, numReagents do
        local _, _, reagentNeeded, playerHas = GetTradeSkillReagentInfo(skillIndex, i)
        if reagentNeeded and reagentNeeded > 0 then
            local maxCasts = math.floor((playerHas or 0) / reagentNeeded)
            if maxCasts < capacity then capacity = maxCasts end
        end
    end
    return capacity
end

function A.Tradeskill.GetCurrentRank()
    local _, rank = GetTradeSkillLine()
    return rank
end

-- Reads the player's rank/maxRank for the active profession. Unlike
-- GetCurrentRank (which needs the tradeskill window open), this reads from
-- the skills spellbook via GetSkillLineInfo and works at any time.
-- Requires A.Profession.skillName for matching (e.g. "Enchanting").
function A.Tradeskill.GetPlayerSkillRank()
    local target = A.Profession and A.Profession.skillName
    if not target or not GetNumSkillLines then return nil, nil end
    target = target:lower()
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
        if not isHeader and name and name:lower() == target then
            return rank or 0, maxRank or 0
        end
    end
    return nil, nil
end
