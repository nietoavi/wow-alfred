-- Core/Trainer.lua — Alfred
-- Trainer scanner. When the player opens a profession trainer, walk the
-- visible service list, match each entry against the active profession's
-- guide steps, and print a chat summary of which guide recipes can be
-- learned here + total cost. Read-only -- never spends gold for the player.
--
-- Why not auto-buy: trainers stay open after you click "Train", and
-- silent purchases would surprise the user. Listing keeps the user in
-- control while removing the cognitive load of "which of these 40
-- services do I actually care about?".
--
-- Usage:
--   * automatic on TRAINER_SHOW (Alchemy/Tailoring/Enchanting trainer, etc.)
--   * /alfred train -- re-prints the listing for the currently open trainer
local _, A = ...
A.Trainer = {}

-- ============================================================================
-- Helpers
-- ============================================================================

-- Build a set of recipe names from the active profession's data.steps.
-- Cheap (~30 entries). Includes optional and alt steps so the listing is
-- complete (the user can decide which path to take).
local function GuideRecipeSet()
    local set = {}
    local def = A.Profession
    if not def or not def.data or not def.data.steps then return set end
    for _, step in ipairs(def.data.steps) do
        if step.recipeName and step.kind ~= "header" then
            set[step.recipeName] = step
        end
    end
    return set
end

-- Coin formatter (mirrors MainPanel's). Returns "1g 25s 50c" or similar.
local function FormatCoin(copper)
    if not copper or copper <= 0 then return "free" end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, c) end
    if s > 0 then return string.format("%ds %dc", s, c) end
    return string.format("%dc", c)
end

-- ============================================================================
-- Scan + report
-- ============================================================================

-- Walks the open trainer. Returns: count of matches, total cost (copper),
-- list of {name, cost, type, step} entries.
function A.Trainer.ScanOpen()
    if not GetNumTrainerServices or not GetTrainerServiceInfo then
        return 0, 0, {}
    end
    local n = GetNumTrainerServices() or 0
    if n == 0 then return 0, 0, {} end

    local guide = GuideRecipeSet()
    if not next(guide) then return 0, 0, {} end

    local matches, total = {}, 0
    for i = 1, n do
        local name, _, kind = GetTrainerServiceInfo(i)
        -- kind is "header" / "available" / "unavailable" / "used"
        if name and kind ~= "header" and guide[name] then
            local cost = (GetTrainerServiceCost and GetTrainerServiceCost(i)) or 0
            table.insert(matches, {
                index = i, name = name, cost = cost, kind = kind, step = guide[name],
            })
            if kind == "available" then total = total + cost end
        end
    end
    return #matches, total, matches
end

-- Print a formatted chat summary. `silent` makes the function a no-op when
-- there's nothing to learn (used by the auto-fire on TRAINER_SHOW so we
-- don't spam the chat at non-profession trainers).
function A.Trainer.Report(silent)
    local count, total, matches = A.Trainer.ScanOpen()
    if count == 0 then
        if not silent then
            print("|cffff9900[Alfred]|r No guide recipes match this trainer's offering.")
        end
        return
    end

    local def = A.Profession
    print(string.format("|cff00ff00[Alfred]|r %s recipes from your guide available here:",
        (def and def.name) or "Profession"))

    -- Available first (clickable to learn), then unavailable (greyed).
    table.sort(matches, function(a, b)
        if a.kind ~= b.kind then
            return a.kind == "available"
        end
        return (a.step.skillStart or 0) < (b.step.skillStart or 0)
    end)

    local availableCount, lockedCount = 0, 0
    for _, m in ipairs(matches) do
        local rangeStr = (m.step.skillStart and m.step.skillEnd)
            and string.format("%d-%d", m.step.skillStart, m.step.skillEnd) or "?"
        if m.kind == "available" then
            availableCount = availableCount + 1
            print(string.format("  |cff7fb87f[ok]|r |cffeaeaee%s|r |cff5a5e68(%s)|r  %s",
                m.name, rangeStr, FormatCoin(m.cost)))
        elseif m.kind == "unavailable" then
            lockedCount = lockedCount + 1
            print(string.format("  |cff5a5e68[--]|r |cff5a5e68%s (%s) -- skill too low|r",
                m.name, rangeStr))
        elseif m.kind == "used" then
            -- Already learned; skip the row (user already knows it).
        end
    end

    if availableCount > 0 then
        print(string.format("|cff00ff00[Alfred]|r Total to learn the %d available: %s",
            availableCount, FormatCoin(total)))
    end
    if lockedCount > 0 then
        print(string.format("|cff5a5e68[Alfred]|r %d more locked behind higher skill -- come back later.|r",
            lockedCount))
    end
end

-- ============================================================================
-- Auto-buy a single matching service by name. Returns true on success.
-- ============================================================================
function A.Trainer.LearnByName(spellName)
    if not spellName or not BuyTrainerService then return false end
    local _, _, matches = A.Trainer.ScanOpen()
    for _, m in ipairs(matches) do
        if m.name == spellName and m.kind == "available" then
            BuyTrainerService(m.index)
            return true, m.cost
        end
    end
    return false
end

-- Auto-buy every "available" match in one pass. Trainer indices remain
-- stable after a buy (the entry just changes kind from "available" to
-- "used"), so a forward iteration over the captured list is safe.
-- Returns: count learned, total copper spent.
function A.Trainer.LearnAll()
    if not BuyTrainerService then return 0, 0 end
    local _, _, matches = A.Trainer.ScanOpen()
    local learned, spent = 0, 0
    for _, m in ipairs(matches) do
        if m.kind == "available" then
            BuyTrainerService(m.index)
            learned = learned + 1
            spent   = spent   + (m.cost or 0)
        end
    end
    return learned, spent
end

-- ============================================================================
-- State (so MainPanel can show/hide the Trainer tab)
-- ============================================================================
local trainerOpen = false
function A.Trainer.IsOpen() return trainerOpen end

-- ============================================================================
-- Events
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("TRAINER_SHOW")
eventFrame:RegisterEvent("TRAINER_CLOSED")
eventFrame:RegisterEvent("TRAINER_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "TRAINER_SHOW" then
        trainerOpen = true
        -- Defer one frame: the trainer service list is populated AFTER
        -- TRAINER_SHOW fires, so a sync scan returns 0.
        if A.Timer and A.Timer.After then
            A.Timer.After(0.1, function()
                if A.UI and A.UI.MainPanel and A.UI.MainPanel.OpenTrainerTab then
                    A.UI.MainPanel.OpenTrainerTab()
                end
            end)
        end
    elseif event == "TRAINER_CLOSED" then
        trainerOpen = false
        if A.UI and A.UI.MainPanel and A.UI.MainPanel.CloseTrainerTab then
            A.UI.MainPanel.CloseTrainerTab()
        end
    elseif event == "TRAINER_UPDATE" then
        -- Fired when the trainer's offering changes (e.g. after a buy).
        if A.UI and A.UI.MainPanel and A.UI.MainPanel.GetCurrentTab
           and A.UI.MainPanel.GetCurrentTab() == "trainer"
           and A.UI.MainPanel.Refresh then
            A.UI.MainPanel.Refresh()
        end
    end
end)
