-- Core/Macro.lua — Alfred-Enchanting
-- Builds the macro body and syncs it with WoW's real (per-character) macro.
-- The macro name is provided by A.Profession.
local _, A = ...
A.Macro = {}

-- spell: spell name. item: item name (may be nil for non-enchant).
-- kind: "enchant" | "rod" | "wand" | "oil" | "potion" | "elixir".
-- count: how many to craft in one click (tradeskill kinds only). Defaults to
-- 1; the caller (RenderFooter) computes max-possible from current bag.
-- If enchant, requires item.
function A.Macro.Build(spellName, itemName, kind, count)
    if not spellName then return nil end
    kind = kind or "enchant"
    count = math.max(1, tonumber(count) or 1)
    if kind == "enchant" then
        if not itemName or itemName == "" then return nil end
        return string.format("/cast %s\n/use %s\n/click StaticPopup1Button1",
            spellName, itemName)
    end
    -- Tradeskill crafts (potion / elixir / rod / wand / oil).
    --
    -- We deliberately do NOT use /cast here. In TBC Classic, /cast on a
    -- tradeskill spell whose name COLLIDES with an item in the player's
    -- bag (e.g. spell "Minor Healing Potion" + item Minor Healing Potion)
    -- triggers the item's USE instead of the spell -- so crafting healing
    -- pots makes the toon try to drink them ("You are already at full
    -- Health"). DoTradeSkill is the safe API: it crafts directly via the
    -- server without any name-resolution ambiguity.
    --
    -- Caveat: DoTradeSkill needs the tradeskill list to be loaded
    -- (GetNumTradeSkills > 0). The client caches this PER SESSION after
    -- the first time the profession is opened. So:
    --   * Once per session: open the profession (any UI -- TSM, Skillet,
    --     Blizzard) once. The list gets cached.
    --   * After that: the cast button works from the addon panel without
    --     reopening, even if the player closes the tradeskill window.
    --
    -- If the cache isn't loaded yet (very first attempt of the session),
    -- we print a friendly hint instead of failing silently.
    -- WoW Classic macro limit is 255 chars total, so we keep this minimal.
    -- No /cast (would trigger item-use when bag has same-named potion).
    -- No prints (user feedback comes from the button label in MainPanel).
    -- DoTradeSkill(i, count) enqueues `count` crafts on the server -- they
    -- chain ~1s apart and abort on movement/damage/full-bag, exactly like
    -- holding the Create button on the Blizzard UI.
    return string.format(
        '/run for i=1,(GetNumTradeSkills()or 0) do local x,t=GetTradeSkillInfo(i) if x==%q and t~="header" then DoTradeSkill(i,%d) return end end',
        spellName, count)
end

local function GetMacroIcon(spellName)
    local icon = A.Spells.GetIcon(spellName)
    if icon then
        -- Macros accept a full path or a name. Return path if the API gave one.
        return icon
    end
    return A.Profession.MacroIconDefault
end

-- Creates or updates the macro with the given body.
-- Returns: ok (bool), idx-or-error-message.
function A.Macro.Update(spellName, itemName, kind, count)
    if not spellName then return false, "no spell" end
    kind = kind or "enchant"
    if kind == "enchant" and (not itemName or itemName == "") then
        return false, "enchant without item"
    end
    if InCombatLockdown and InCombatLockdown() then return false, "in combat" end
    if not (CreateMacro and EditMacro and GetMacroIndexByName) then
        return false, "macro API unavailable"
    end
    local body = A.Macro.Build(spellName, itemName, kind, count)
    if not body then return false, "could not build body" end
    local icon = GetMacroIcon(spellName)
    local macroName = A.Profession.MacroName
    local idx = GetMacroIndexByName(macroName)
    if not idx or idx == 0 then
        -- Migration: if the old macro (LegacyMacroName) exists, rename it
        local legacyName = A.Profession.LegacyMacroName
        if legacyName and legacyName ~= "" then
            local legacyIdx = GetMacroIndexByName(legacyName)
            if legacyIdx and legacyIdx > 0 then
                EditMacro(legacyIdx, macroName, icon, body)
                return true, legacyIdx
            end
        end
    end
    if idx and idx > 0 then
        EditMacro(idx, macroName, icon, body)
    else
        idx = CreateMacro(macroName, icon, body, 1)  -- 1 = per-character
        if not idx or idx == 0 then
            return false, "could not create macro (macro slots full?)"
        end
    end
    return true, idx
end
