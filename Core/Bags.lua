-- Core/Bags.lua — Alfred-Enchanting
-- C_Container compatibility (Anniversary) vs old globals (Classic), plus
-- helpers to find/count items in bags by name.
local _, A = ...
A.Bags = {}

local function ContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

-- Normalizes the C_Container.GetContainerItemInfo (table) return to the old
-- style. Returns only what we need: stackCount, itemLink.
local function ContainerItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.stackCount, info.hyperlink end
        return nil, nil
    elseif GetContainerItemInfo then
        local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
        return count, link
    end
    return nil, nil
end

function A.Bags.UseBagItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        return C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then
        return UseContainerItem(bag, slot)
    end
end

function A.Bags.GetItemNameFromLink(itemLink)
    if not itemLink then return nil end
    return GetItemInfo(itemLink) or itemLink:match("%[(.-)%]")
end

function A.Bags.Find(itemName)
    if not itemName or itemName == "" then return nil, nil end
    for bag = 0, 4 do
        local numSlots = ContainerNumSlots(bag)
        for slot = 1, numSlots do
            local _, itemLink = ContainerItemInfo(bag, slot)
            if itemLink and A.Bags.GetItemNameFromLink(itemLink) == itemName then
                return bag, slot
            end
        end
    end
    return nil, nil
end

function A.Bags.Count(itemName)
    if not itemName or itemName == "" then return 0 end
    local count = 0
    for bag = 0, 4 do
        local numSlots = ContainerNumSlots(bag)
        for slot = 1, numSlots do
            local stackCount, itemLink = ContainerItemInfo(bag, slot)
            if itemLink and A.Bags.GetItemNameFromLink(itemLink) == itemName then
                count = count + (stackCount or 1)
            end
        end
    end
    return count
end
