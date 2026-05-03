-- Config.lua — Alfred-Enchanting
-- Hooks layer + per-slot item helpers. The UI now lives in the MainPanel's
-- "Config" tab (Core/MainPanel.lua) — this file only:
--   * intercepts shift+click on bag items (HandleModifiedItemClick) and
--     routes them to A.UI.MainPanel.AssignSelectedSlot
--   * exposes the public AlfredEnchanting_* helpers consumed by Engine,
--     Slash and the slash commands
local ADDON_NAME, A = ...

-- ============================================================================
-- Lookup helpers (consumed by Engine.lua's ResolveCast and by slash commands)
-- ============================================================================
-- Item assigned by the user for a slot. Returns "" if nothing is assigned.
-- No silent fallback to defaults: if the user didn't assign anything, the
-- macro will not pull the recommended item on its own — explicit assignment
-- is required.
local function GetItemForSlot(slotKey)
    local item = A.DB.GetSlotItem(slotKey)
    return (item and item ~= "") and item or ""
end

function AlfredEnchanting_GetItemForSpell(spellName)
    local map = A.Profession and A.Profession.slotMap
    local slotKey = map and map[spellName]
    if not slotKey then return nil end
    return GetItemForSlot(slotKey)
end

-- Resolves the item for a recipe given by tradeskill index.
-- Tries by spell ID first (locale-independent), falls back to name.
function AlfredEnchanting_GetItemForRecipe(skillIndex)
    local map = A.Profession and A.Profession.slotMap
    if not map then return nil end
    if GetTradeSkillRecipeLink and A.Profession.GetSpellIDFromRecipeLink then
        local link = GetTradeSkillRecipeLink(skillIndex)
        if link then
            local id = A.Profession.GetSpellIDFromRecipeLink(link)
            if id and map[id] then
                return GetItemForSlot(map[id])
            end
        end
    end
    local name = GetTradeSkillInfo(skillIndex)
    if name and map[name] then
        return GetItemForSlot(map[name])
    end
    return nil
end

-- Back-compat: Engine.lua's ADDON_LOADED handler already calls A.DB.Init()
-- directly, but we expose this in case external code invokes it.
function AlfredEnchanting_InitDB()
    if A and A.DB and A.DB.Init then A.DB.Init() end
end

-- ============================================================================
-- Toggle the Config tab on the MainPanel.
-- If the panel is hidden: shows it and switches to the Config tab.
-- If it's open on another tab: switches to the Config tab.
-- If it's already on the Config tab: hides the panel.
-- ============================================================================
function AlfredEnchanting_ToggleConfig()
    if not (A.UI and A.UI.MainPanel) then return end
    local MP = A.UI.MainPanel
    if MP.IsShown() and MP.GetCurrentTab and MP.GetCurrentTab() == "config" then
        MP.Hide()
    else
        MP.Show()
        if MP.ShowTab then MP.ShowTab("config") end
    end
end

-- ============================================================================
-- Shift-click assignment: we hook HandleModifiedItemClick (universal — works
-- with TSM, Bagnon, AdiBags, equipment slots, chat, etc).
-- We also keep the old ContainerFrameItemButton_OnClick hook in case some
-- client/UI doesn't call HandleModifiedItemClick.
-- ============================================================================

local function AssignItemFromLink(itemLink)
    if not itemLink then return end
    if not (A.UI and A.UI.MainPanel and A.UI.MainPanel.AssignSelectedSlot) then return end
    -- AssignSelectedSlot internally validates that we're on the Config tab and
    -- that a slot is selected — returns true/false depending on whether it
    -- assigned anything.
    A.UI.MainPanel.AssignSelectedSlot(itemLink)
end

if hooksecurefunc and HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(itemLink)
        if not IsShiftKeyDown() then return end
        AssignItemFromLink(itemLink)
    end)
end

-- Backup: container button hook (in case HandleModifiedItemClick isn't called by some UI)
local function GetBagItemLink(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.hyperlink or nil
    elseif GetContainerItemInfo then
        local _, _, _, _, _, _, link = GetContainerItemInfo(bag, slot)
        return link
    end
    return nil
end

if hooksecurefunc and ContainerFrameItemButton_OnClick then
    hooksecurefunc("ContainerFrameItemButton_OnClick", function(self, button)
        if button ~= "LeftButton" then return end
        if not IsShiftKeyDown() then return end
        local bag = self:GetParent():GetID()
        local slot = self:GetID()
        if not bag or not slot then return end
        AssignItemFromLink(GetBagItemLink(bag, slot))
    end)
end

-- ============================================================================
-- /alfred set <slot> <item>: chat-based assignment (does not require an open tab).
-- ============================================================================
function AlfredEnchanting_SetSlotByName(slotKey, itemName)
    if not slotKey or not itemName or itemName == "" then return false, "invalid args" end
    local slots = (A.Profession and A.Profession.slots) or AlfredEnchantingSlots or {}
    local valid
    for _, s in ipairs(slots) do
        if s.key == slotKey then valid = s; break end
    end
    if not valid then return false, "invalid slot: " .. slotKey end
    A.DB.SetSlotItem(slotKey, itemName)
    if AlfredEnchanting_UpdateButton then AlfredEnchanting_UpdateButton() end
    -- Refresh the config tab if it's currently open
    if A.UI and A.UI.MainPanel and A.UI.MainPanel.GetCurrentTab
       and A.UI.MainPanel.GetCurrentTab() == "config"
       and A.UI.MainPanel.Refresh then
        A.UI.MainPanel.Refresh()
    end
    return true, valid.label
end
