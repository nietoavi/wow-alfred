-- Professions/Alchemy.lua — Alfred (Alchemy)
-- Adapter that wires Alchemy into the Alfred.RegisterProfession contract.
-- Mirrors Professions/Enchanting.lua. Alchemy has no per-slot target item
-- (no slots / slotMap / slotDefaults) and no confirmation popup.
local _, A = ...

Alfred.RegisterProfession({
    id   = "alchemy",
    name = "Alchemy",
    skillName = "Alchemy",                  -- match against GetSkillLineInfo
    icon = "Interface\\Icons\\Trade_Alchemy",

    -- Macro the addon keeps in sync with the current step.
    MacroName        = "AlfredAlchemy",
    LegacyMacroName  = nil,                  -- no prior macro to migrate from
    MacroIconDefault = "INV_Misc_QuestionMark",

    -- Alchemy has no replace-on-target popup (potions go straight to bag).
    PopupName = nil,

    -- Colored prefix for chat prints.
    LogPrefix = "|cff7fc8a8[Alfred:Alchemy]|r",
    LogWarn   = "|cffff9900[Alfred:Alchemy]|r",

    -- Data (forwarded to A.Profession; the tables live in AlchemyData.lua).
    -- No slots/slotMap/slotDefaults: potions don't target an external item.
    data         = AlfredAlchemyData,
    guide        = AlfredAlchemyGuide,
    fullGuide    = AlfredAlchemyFullGuide,
    shoppingList = AlfredAlchemyShoppingList,

    -- Extracts the spell ID from an alchemy recipe link ("enchant:NNNN" form
    -- — TBC tradeskill links use the same prefix regardless of profession).
    GetSpellIDFromRecipeLink = function(link)
        if not link then return nil end
        local id = link:match("enchant:(%d+)")
        return id and tonumber(id) or nil
    end,

    -- Are we looking at the Alchemy window? Tolerant of TSM/Skillet etc.
    IsTradeskillOpen = function()
        if GetTradeSkillLine then
            local line = GetTradeSkillLine()
            if line and type(line) == "string" and line ~= "UNKNOWN" and line ~= "" then
                if line == "Alchemy" then return true end
            end
        end
        if GetTradeSkillSelectionIndex and GetTradeSkillInfo then
            local idx = GetTradeSkillSelectionIndex()
            if idx and idx > 0 then
                local name = GetTradeSkillInfo(idx)
                if name and (name:find("Potion") or name:find("Elixir") or name:find("Flask")
                             or name:find("Transmute")) then
                    return true
                end
            end
        end
        return false
    end,
})
