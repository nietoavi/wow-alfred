-- Professions/Enchanting.lua — Alfred-Enchanting (Phase 2)
-- Wires Enchanting up to the Alfred.RegisterProfession contract.
-- The data tables still live in Data.lua as globals (Config.lua and Guide.lua
-- still read them), but here we forward them to the registry so Core reads
-- via A.Profession without knowing which profession it is.
local _, A = ...

Alfred.RegisterProfession({
    id   = "enchanting",
    name = "Enchanting",
    skillName = "Enchanting",                   -- match against GetSkillLineInfo
    icon = "Interface\\Icons\\Trade_Engraving", -- header icon

    -- Macro the addon keeps in sync with the current step.
    MacroName        = "AlfredEnchant",
    LegacyMacroName  = "EnchantStep",            -- pre-v4.0 macro migration
    MacroIconDefault = "INV_Misc_QuestionMark",

    -- Confirmation popup when casting an enchant on an already-enchanted item.
    PopupName = "REPLACE_ENCHANT",

    -- Colored prefix for chat prints.
    LogPrefix = "|cff00ff00[Alfred:Enchanting]|r",
    LogWarn   = "|cffff9900[Alfred:Enchanting]|r",

    -- Data (references to the tables in Data.lua).
    -- `data` is the new source of truth (structured steps with numeric
    -- skillStart/skillEnd and materials with itemId). `guide` and `fullGuide`
    -- are derived tables for back-compat with Guide.lua and legacy code that
    -- still expects the old shape.
    data          = AlfredEnchantingData,
    slots         = AlfredEnchantingSlots,
    slotDefaults  = AlfredEnchantingDefaults,
    slotMap       = AlfredEnchantingSlotMap,
    guide         = AlfredEnchantingGuide,
    fullGuide     = AlfredEnchantingFullGuide,
    shoppingList  = AlfredEnchantingShoppingList,

    -- Extracts the spell ID from an enchanting recipe link (format "enchant:NNNN").
    GetSpellIDFromRecipeLink = function(link)
        if not link then return nil end
        local id = link:match("enchant:(%d+)")
        return id and tonumber(id) or nil
    end,

    -- Are we looking at the Enchanting window?
    -- Tolerant of alternative UIs (TSM, Skillet, etc.) that may make
    -- GetTradeSkillLine return "UNKNOWN". In that case we check the selected
    -- recipe instead.
    IsTradeskillOpen = function()
        if GetTradeSkillLine then
            local line = GetTradeSkillLine()
            if line and type(line) == "string" and line ~= "UNKNOWN" and line ~= "" then
                if line == "Enchanting" or line:lower():find("encant") then
                    return true
                end
            end
        end
        if GetTradeSkillSelectionIndex and GetTradeSkillInfo then
            local idx = GetTradeSkillSelectionIndex()
            if idx and idx > 0 then
                local name = GetTradeSkillInfo(idx)
                if name then
                    if AlfredEnchantingSlotMap and AlfredEnchantingSlotMap[name] then return true end
                    if name:find("^Enchant") or name:lower():find("^encant") then return true end
                end
            end
        end
        return false
    end,
})
