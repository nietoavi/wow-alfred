-- Professions/Tailoring.lua — Alfred (Tailoring)
-- Adapter that wires Tailoring into the Alfred.RegisterProfession contract.
-- Mirrors Professions/Alchemy.lua. Tailoring has no per-slot target item
-- (no slots / slotMap / slotDefaults) and no confirmation popup.
local _, A = ...

Alfred.RegisterProfession({
    id   = "tailoring",
    name = "Tailoring",
    skillName = "Tailoring",                 -- match against GetSkillLineInfo
    icon = "Interface\\Icons\\Trade_Tailoring",

    -- Macro the addon keeps in sync with the current step.
    MacroName        = "AlfredTailor",
    LegacyMacroName  = nil,
    MacroIconDefault = "INV_Misc_QuestionMark",

    -- Tailoring crafts go straight to the bag, no replace-on-target popup.
    PopupName = nil,

    -- Colored prefix for chat prints.
    LogPrefix = "|cffc89e7f[Alfred:Tailoring]|r",
    LogWarn   = "|cffff9900[Alfred:Tailoring]|r",

    -- Data (forwarded to A.Profession; the tables live in TailoringData.lua).
    -- No slots/slotMap/slotDefaults: tailoring crafts don't target an
    -- external item.
    data         = AlfredTailoringData,
    guide        = AlfredTailoringGuide,
    fullGuide    = AlfredTailoringFullGuide,
    shoppingList = AlfredTailoringShoppingList,

    -- TBC tradeskill links use the "enchant:NNNN" prefix regardless of
    -- profession, so the same parser as Alchemy/Enchanting works.
    GetSpellIDFromRecipeLink = function(link)
        if not link then return nil end
        local id = link:match("enchant:(%d+)")
        return id and tonumber(id) or nil
    end,

    -- Are we looking at the Tailoring window? Tolerant of TSM/Skillet etc.
    IsTradeskillOpen = function()
        if GetTradeSkillLine then
            local line = GetTradeSkillLine()
            if line and type(line) == "string" and line ~= "UNKNOWN" and line ~= "" then
                if line == "Tailoring" then return true end
            end
        end
        if GetTradeSkillSelectionIndex and GetTradeSkillInfo then
            local idx = GetTradeSkillSelectionIndex()
            if idx and idx > 0 then
                local name = GetTradeSkillInfo(idx)
                if name and (name:find("^Bolt of") or name:find("Cloth$")
                             or name:find("Mageweave") or name:find("Runecloth")
                             or name:find("Netherweave")) then
                    return true
                end
            end
        end
        return false
    end,
})
