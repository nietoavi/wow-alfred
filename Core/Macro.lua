-- Core/Macro.lua — Alfred-Enchanting
-- Builds the macro body and syncs it with WoW's real (per-character) macro.
-- The macro name is provided by A.Profession.
local _, A = ...
A.Macro = {}

-- spell: spell name. item: item name (may be nil for non-enchant).
-- kind: "enchant" | "rod" | "wand" | "oil". If enchant, requires item.
function A.Macro.Build(spellName, itemName, kind)
    if not spellName then return nil end
    kind = kind or "enchant"
    if kind == "enchant" then
        if not itemName or itemName == "" then return nil end
        return string.format("/cast %s\n/use %s\n/click StaticPopup1Button1",
            spellName, itemName)
    end
    -- rod/wand/oil: cast only (direct crafts with no target)
    return string.format("/cast %s", spellName)
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
function A.Macro.Update(spellName, itemName, kind)
    if not spellName then return false, "no spell" end
    kind = kind or "enchant"
    if kind == "enchant" and (not itemName or itemName == "") then
        return false, "enchant without item"
    end
    if InCombatLockdown and InCombatLockdown() then return false, "in combat" end
    if not (CreateMacro and EditMacro and GetMacroIndexByName) then
        return false, "macro API unavailable"
    end
    local body = A.Macro.Build(spellName, itemName, kind)
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
