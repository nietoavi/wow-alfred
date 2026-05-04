-- Core/Engine.lua — Alfred-Enchanting
-- Bootstrap: registers event handlers, hooks the REPLACE_ENCHANT StaticPopup,
-- maintains the legacy direct-cast flow (DoCast/Bulk) and the skill tracking.
-- This file is the "owner" of the addon's eventFrame.
-- WoW passes the real addon name (= folder/.toc name) as the first vararg.
-- Capturing it here ensures the ADDON_LOADED handler matches.
-- Previously it was hardcoded as "AlfredEnchanting" (no dash) and never matched
-- "Alfred-Enchanting" → A.DB.Init() never ran → AlfredDB was nil.
local ADDON_NAME, A = ...
A.Engine = {}

-- ============================================================================
-- State (legacy direct-cast flow, predates the real macro)
-- ============================================================================
local pendingPopupClick      -- Waiting to confirm REPLACE_ENCHANT popup
local pendingCastToken = 0   -- Incremental token per cast
local bulkRemaining = 0      -- Casts remaining in bulk mode
local bulkLastSpell          -- Spell of the most recent cast (for skill-up tracking)
local bulkLockSpell          -- Spell name the bulk is "locked" to
local lastKnownRank          -- Enchanting rank before the last cast
local sawEnchantingOnce = false

local listenMode = false  -- /eb listen on/off — log every event
local stickyShow = false  -- /eb show forces panel visibility

-- Setters exposed to Slash.lua / Minimap.lua
function A.Engine.SetSticky(b) stickyShow = b end
function A.Engine.IsSticky()   return stickyShow end
function A.Engine.SetListen(b) listenMode = b end
function A.Engine.IsListening() return listenMode end

-- ============================================================================
-- Profession switching (shared by slash command + UI dropdown)
-- ============================================================================
-- Picks the best profession to land on at boot when the user has no saved
-- preference: first learned in registration order, falling back to the first
-- registered if none are learned (the player can still consult its guide).
function A.Engine.PickDefaultProfession()
    local list = Alfred.GetRegisteredProfessions()
    for _, id in ipairs(list) do
        if Alfred.IsProfessionLearned(id) then return id end
    end
    return list[1]
end

-- Switches active profession, persists it, and refreshes the panel.
-- Returns true on success, false+message on failure.
function A.Engine.SwitchProfession(id)
    local ok, err = Alfred.SetActiveProfession(id)
    if not ok then return false, err end
    if AlfredDB then AlfredDB.activeProfession = id end
    if A.UI and A.UI.MainPanel and A.UI.MainPanel.OnProfessionChanged then
        A.UI.MainPanel.OnProfessionChanged()
    end
    return true
end

-- ============================================================================
-- Skill tracking
-- ============================================================================
local function StatsKey(spellName) return spellName end

function A.Engine.RecordCast(spellName)
    if not spellName then return end
    local p = A.DB.Active()
    if not p then return end
    p.stats = p.stats or {}
    local k = StatsKey(spellName)
    p.stats[k] = p.stats[k] or { casts = 0, skillUps = 0 }
    p.stats[k].casts = p.stats[k].casts + 1
end

function A.Engine.RecordSkillUp(spellName, points)
    if not spellName then return end
    local p = A.DB.Active()
    if not p then return end
    p.stats = p.stats or {}
    local k = StatsKey(spellName)
    p.stats[k] = p.stats[k] or { casts = 0, skillUps = 0 }
    p.stats[k].skillUps = p.stats[k].skillUps + (points or 1)
end

-- ============================================================================
-- Direct cast (legacy — no longer the primary flow; the current flow uses the
-- real macro fired by the MainPanel's SecureActionButton). Kept around in case
-- we re-integrate bulk mode later.
-- ============================================================================
local function ResolveCast(skillIndex)
    local skillName, skillType = GetTradeSkillInfo(skillIndex)
    if not skillName or skillType == "header" then
        return false, "No recipe selected"
    end
    local itemName = AlfredEnchanting_GetItemForRecipe(skillIndex)
    if not itemName or itemName == "" then
        return false, "No item configured for: " .. skillName
    end
    local bag, slot = A.Bags.Find(itemName)
    if not bag then
        return false, "Item not found in bags: " .. itemName
    end
    if A.Tradeskill.GetReagentCapacity(skillIndex) <= 0 then
        return false, "Missing reagents for: " .. skillName
    end
    return true, nil, skillName, itemName, bag, slot
end

local function DoCast(skillIndex)
    local ok, err, skillName, _, bag, slot = ResolveCast(skillIndex)
    if not ok then
        print("|cffff9900[Alfred:Enchanting]|r " .. err)
        return false
    end

    bulkLastSpell = skillName
    lastKnownRank = A.Tradeskill.GetCurrentRank()
    pendingCastToken = pendingCastToken + 1
    local myToken = pendingCastToken
    pendingPopupClick = true

    CastSpellByName(skillName)
    A.Bags.UseBagItem(bag, slot)

    A.Engine.RecordCast(skillName)

    -- Fallback: if the popup never arrives, don't get stuck.
    A.Timer.After(2.0, function()
        if pendingCastToken == myToken then
            pendingPopupClick = false
        end
    end)

    return true
end

A.Engine.DoCast = DoCast

-- Hook the enchant-replace popup (more robust than a fixed timer)
local function OnPopupShow(which)
    if which ~= A.Profession.PopupName or not pendingPopupClick then return end
    pendingPopupClick = false
    A.Timer.After(0.05, function()
        for i = 1, 4 do
            local p = _G["StaticPopup" .. i]
            if p and p:IsShown() and p.which == A.Profession.PopupName then
                local btn = _G["StaticPopup" .. i .. "Button1"]
                if btn then btn:Click() end
                return
            end
        end
    end)
end

-- ============================================================================
-- Bulk mode (legacy — not integrated into the current macro flow; kept as
-- useful dead code in case we revisit it later).
-- ============================================================================
function A.Engine.BulkCancel()
    if bulkRemaining > 0 then
        bulkRemaining = 0
        print("|cffff9900[Alfred:Enchanting]|r Bulk cancelled.")
    end
end

local function ScheduleNextBulk()
    if bulkRemaining <= 0 then return end
    local idx = GetTradeSkillSelectionIndex()
    if not idx or idx == 0 then
        bulkRemaining = 0
        return
    end
    local currentName = GetTradeSkillInfo(idx)
    if bulkLockSpell and currentName ~= bulkLockSpell then
        print("|cffff9900[Alfred:Enchanting]|r Recipe changed. Bulk cancelled.")
        bulkRemaining = 0
        bulkLockSpell = nil
        return
    end
    if not DoCast(idx) then
        bulkRemaining = 0
        bulkLockSpell = nil
        return
    end
    bulkRemaining = bulkRemaining - 1
    if bulkRemaining > 0 then
        A.Timer.After(0.6, ScheduleNextBulk)
    else
        bulkLockSpell = nil
    end
end

function A.Engine.StartBulk(count)
    if count <= 1 then
        local idx = GetTradeSkillSelectionIndex()
        if idx and idx > 0 then DoCast(idx) end
        return
    end
    local idx = GetTradeSkillSelectionIndex()
    if not idx or idx == 0 then return end
    bulkLockSpell = GetTradeSkillInfo(idx)
    bulkRemaining = count
    print("|cff00ff00[Alfred:Enchanting]|r Enchanting x" .. count .. " — click the button again to cancel.")
    ScheduleNextBulk()
end

-- ============================================================================
-- Auto-pick (legacy): find the best available recipe for a skill up.
-- Exposed as a global for back-compat (not used in the current flow).
-- ============================================================================
local function HasMapping(skillIndex)
    local map = A.Profession.slotMap
    if not map then return false end
    local id = A.Tradeskill.GetSpellIDForRecipe(skillIndex)
    if id and map[id] then return true end
    local name = GetTradeSkillInfo(skillIndex)
    return name and map[name] ~= nil
end

function AlfredEnchanting_FindBestRecipe()
    local n = GetNumTradeSkills() or 0
    local order = { optimal = 1, medium = 2, easy = 3, trivial = 4 }
    local best, bestScore = nil, 99

    for i = 1, n do
        local name, skillType = GetTradeSkillInfo(i)
        if name and skillType and skillType ~= "header" and HasMapping(i) then
            local itemName = AlfredEnchanting_GetItemForRecipe(i)
            if itemName and itemName ~= "" and A.Bags.Find(itemName) then
                if A.Tradeskill.GetReagentCapacity(i) > 0 then
                    local score = order[skillType] or 99
                    if skillType ~= "trivial" and score < bestScore then
                        best, bestScore = i, score
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================================
-- Events
-- ============================================================================
local eventFrame = CreateFrame("Frame", ADDON_NAME .. "EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_CLOSE")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
pcall(eventFrame.RegisterEvent, eventFrame, "LEARNED_SPELL_IN_TAB")
pcall(eventFrame.RegisterEvent, eventFrame, "SKILL_LINES_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "GET_ITEM_INFO_RECEIVED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if listenMode then
        print("|cffaaaaaa[eb event]|r " .. tostring(event) .. " " .. tostring(arg1))
    end

    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            A.DB.Init()
            print("|cff00ff00[Alfred]|r loaded. /alfred prof list to see professions, /alfred show to display the panel.")
        end
    elseif event == "PLAYER_LOGIN" then
        -- First-time activation: if the user has no saved preference, pick the
        -- first profession the character actually has learned. Falls back to
        -- the first registered (still consultable) when none are learned.
        if AlfredDB and not AlfredDB.activeProfession then
            local pick = A.Engine.PickDefaultProfession()
            if pick then
                Alfred.SetActiveProfession(pick)
                AlfredDB.activeProfession = pick
            end
        end
        A.UI.MainPanel.Create()
        local shared = A.DB.Shared()
        if not (shared and shared.minimapHide) then
            A.UI.Minimap.Create()
        end
    elseif event == "TRADE_SKILL_SHOW" then
        if not A.UI.MainPanel.GetContainer() then A.UI.MainPanel.Create() end
        lastKnownRank = A.Tradeskill.GetCurrentRank()
        -- Populate the per-char learned-recipes cache so future "is this
        -- spell learned?" lookups don't depend on the panel being open.
        if A.CraftList and A.CraftList.ScanOpenTradeskill then
            A.CraftList.ScanOpenTradeskill()
        end
        if A.Profession.IsTradeskillOpen() then
            if not sawEnchantingOnce then
                print("|cff00ff00[Alfred:Enchanting]|r active on Enchanting. /aen show if you don't see the panel.")
                sawEnchantingOnce = true
            end
            A.UI.MainPanel.Show()
            A.UI.MainPanel.ApplyPin()
        end
        A.UI.MainPanel.UpdateButton()
    elseif event == "TRADE_SKILL_CLOSE" then
        -- We don't auto-hide: the panel is useful even outside the tradeskill.
        A.UI.MainPanel.UpdateButton()
    elseif event == "TRADE_SKILL_UPDATE" then
        local newRank = A.Tradeskill.GetCurrentRank()
        if lastKnownRank and newRank and newRank > lastKnownRank and bulkLastSpell then
            A.Engine.RecordSkillUp(bulkLastSpell, newRank - lastKnownRank)
        end
        lastKnownRank = newRank
        -- TRADE_SKILL_UPDATE also fires when the player learns a new recipe
        -- with the panel open -- catch the new entries.
        if A.CraftList and A.CraftList.ScanOpenTradeskill then
            A.CraftList.ScanOpenTradeskill()
        end
        A.UI.MainPanel.UpdateButton()
    elseif event == "BAG_UPDATE_DELAYED" then
        A.UI.MainPanel.UpdateButton()
    elseif event == "LEARNED_SPELL_IN_TAB" or event == "SKILL_LINES_CHANGED" then
        A.Spells.InvalidateCache()
        if Alfred and Alfred.InvalidateLearnedCache then
            Alfred.InvalidateLearnedCache()
        end
        A.UI.MainPanel.UpdateButton()
        -- Skill-goal notification: when a craft queue pushes the player's
        -- skill past the active step's skillEnd, print a one-shot reminder
        -- so they can move to interrupt the remaining crafts. Keyed by
        -- profId+stepIdx so navigating to a different step re-arms it.
        if Alfred and A.UI and A.UI.MainPanel and A.UI.MainPanel.GetGuideEntry then
            local profId = Alfred.GetActiveProfessionId()
            local cur    = A.UI.MainPanel.GetCurrentStep()
            local entry  = A.UI.MainPanel.GetGuideEntry(cur)
            if profId and entry and entry.skillEnd then
                local _, rank = Alfred.IsProfessionLearned(profId)
                if rank and rank >= entry.skillEnd then
                    A.Engine._lastSkillNotice = A.Engine._lastSkillNotice or {}
                    local key = profId .. ":" .. tostring(cur)
                    if A.Engine._lastSkillNotice[profId] ~= key then
                        print(string.format("|cffe6b870[Alfred]|r Skill %d reached -- step done. Move/walk to interrupt remaining crafts in the queue, then advance to the next step.",
                            entry.skillEnd))
                        A.Engine._lastSkillNotice[profId] = key
                    end
                end
            end
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- The first time the client encounters an item id (vendor recipe,
        -- alt-path herb the player has never seen), GetItemInfo returns nil
        -- and the icon falls back to the question-mark texture. When the
        -- info finally arrives, we re-render once. Throttle so a flood of
        -- events (login boot) doesn't trigger N back-to-back renders.
        if A.UI and A.UI.MainPanel and A.UI.MainPanel.QueueIconRefresh then
            A.UI.MainPanel.QueueIconRefresh()
        end
    end
end)

-- Hook the enchant-replace popup
hooksecurefunc("StaticPopup_Show", OnPopupShow)
