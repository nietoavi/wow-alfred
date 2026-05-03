-- Core/Slash.lua — Alfred-Enchanting
-- All addon commands. Four aliases: /alfred, /alfred-enchanting, /aen, /eb.
local _, A = ...

SLASH_ALFREDENCHANTING1 = "/alfred"
SLASH_ALFREDENCHANTING2 = "/alfred-enchanting"
SLASH_ALFREDENCHANTING3 = "/aen"
SLASH_ALFREDENCHANTING4 = "/eb"  -- legacy alias for existing users

SlashCmdList["ALFREDENCHANTING"] = function(msg)
    msg = msg and msg:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local cmd = msg:lower():match("^(%S+)") or msg:lower()
    -- For commands with args (set), preserve the original case of the remainder:
    local args = msg:match("^%S+%s+(.+)$")
    if cmd == "" then cmd = "help" end

    local MP = A.UI.MainPanel

    if cmd == "debug" then
        local idx = GetTradeSkillSelectionIndex()
        if idx and idx > 0 then
            local name = GetTradeSkillInfo(idx)
            local id = A.Tradeskill.GetSpellIDForRecipe(idx)
            local item = AlfredEnchanting_GetItemForRecipe(idx)
            print("[Alfred:Enchanting] Recipe: " .. tostring(name) .. " (id=" .. tostring(id) .. ")")
            print("[Alfred:Enchanting] Item: " .. tostring(item))
            print("[Alfred:Enchanting] Reagent capacity: " .. tostring(A.Tradeskill.GetReagentCapacity(idx)))
            print("[Alfred:Enchanting] Items in bag: " .. tostring(item and A.Bags.Count(item) or 0))
        else
            print("[Alfred:Enchanting] No recipe selected.")
        end
    elseif cmd == "config" then
        if AlfredEnchanting_ToggleConfig then
            AlfredEnchanting_ToggleConfig()
        else
            print("|cffff9900[Alfred:Enchanting]|r Config toggle not available.")
        end
    elseif cmd == "diag" then
        print("|cff00ff00[Alfred:Enchanting]|r Diagnostics:")
        print("  |cffaaaaaa(make sure Enchanting is OPEN when running this)|r")

        local function loaded(name)
            if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
            if IsAddOnLoaded then return IsAddOnLoaded(name) end
            return nil
        end
        print("  --- AddOns ---")
        print("  Blizzard_TradeSkillUI loaded: " .. tostring(loaded("Blizzard_TradeSkillUI")))
        print("  Blizzard_Professions loaded: " .. tostring(loaded("Blizzard_Professions")))

        print("  --- Global frames ---")
        print("  TradeSkillFrame:        " .. tostring(_G.TradeSkillFrame ~= nil))
        print("  TradeSkillCreateButton: " .. tostring(_G.TradeSkillCreateButton ~= nil))
        print("  ProfessionsFrame:       " .. tostring(_G.ProfessionsFrame ~= nil))
        if _G.ProfessionsFrame then
            print("  ProfessionsFrame.CraftingPage: " .. tostring(_G.ProfessionsFrame.CraftingPage ~= nil))
            if _G.ProfessionsFrame.CraftingPage then
                print("  ...CraftingPage.CreateButton: " .. tostring(_G.ProfessionsFrame.CraftingPage.CreateButton ~= nil))
            end
        end

        print("  --- Legacy API (GetTradeSkill*) ---")
        print("  GetTradeSkillLine exists:           " .. tostring(GetTradeSkillLine ~= nil))
        print("  GetTradeSkillInfo exists:           " .. tostring(GetTradeSkillInfo ~= nil))
        print("  GetTradeSkillSelectionIndex exists: " .. tostring(GetTradeSkillSelectionIndex ~= nil))
        print("  GetTradeSkillRecipeLink exists:     " .. tostring(GetTradeSkillRecipeLink ~= nil))

        print("  --- New API (C_TradeSkillUI) ---")
        if C_TradeSkillUI then
            print("  C_TradeSkillUI exists: true")
            if C_TradeSkillUI.GetTradeSkillLine then
                local info = C_TradeSkillUI.GetTradeSkillLine()
                print("  C_TradeSkillUI.GetTradeSkillLine(): " .. tostring(info))
            end
            if C_TradeSkillUI.GetBaseProfessionInfo then
                local info = C_TradeSkillUI.GetBaseProfessionInfo()
                if info then
                    print("  Profession: " .. tostring(info.professionName) .. " (id=" .. tostring(info.professionID) .. ")")
                end
            end
        else
            print("  C_TradeSkillUI does not exist")
        end

        print("  --- Internal state ---")
        local container = MP.GetContainer()
        print("  enchantContainer created: " .. tostring(container ~= nil))
        if container then
            print("  enchantContainer visible: " .. tostring(container:IsShown()))
            local pt, _, _, x, y = container:GetPoint(1)
            print("  enchantContainer anchor: " .. tostring(pt) .. " (" .. tostring(x) .. ", " .. tostring(y) .. ")")
        end
        if A.Profession.slots then
            for _, slotDef in ipairs(A.Profession.slots) do
                local item = A.DB.GetSlotItem(slotDef.key)
                print("    " .. slotDef.key .. ": " .. tostring(item or "(unassigned)"))
            end
        end
        local cursorType = GetCursorInfo and GetCursorInfo() or nil
        print("  GetCursorInfo type: " .. tostring(cursorType))
        local line = GetTradeSkillLine and GetTradeSkillLine() or nil
        print("  GetTradeSkillLine(): " .. tostring(line))
        local idx = GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex() or 0
        print("  Selected recipe idx: " .. tostring(idx))
        if idx and idx > 0 then
            local n, t = GetTradeSkillInfo(idx)
            local id = A.Tradeskill.GetSpellIDForRecipe(idx)
            print("  Recipe name: '" .. tostring(n) .. "' (type=" .. tostring(t) .. ", id=" .. tostring(id) .. ")")
            local map = A.Profession.slotMap
            print("  In slot map by name?: " .. tostring(map and map[n] ~= nil))
            print("  In slot map by id?:   " .. tostring(map and id and map[id] ~= nil))
        end
    elseif cmd == "stats" then
        local activeDB = A.DB.Active()
        if args == "reset" then
            if activeDB then activeDB.stats = {} end
            print("|cff00ff00[Alfred:Enchanting]|r Stats reset.")
            return
        end
        local stats = activeDB and activeDB.stats
        if not stats or not next(stats) then
            print("|cff00ff00[Alfred:Enchanting]|r No stats yet.")
            return
        end
        print("|cff00ff00[Alfred:Enchanting]|r Skill ups per recipe:")
        local rows = {}
        for name, s in pairs(stats) do
            table.insert(rows, { name = name, casts = s.casts, ups = s.skillUps })
        end
        table.sort(rows, function(a, b) return a.ups > b.ups end)
        for _, r in ipairs(rows) do
            local rate = r.casts > 0 and (r.ups / r.casts * 100) or 0
            print(string.format("  %s — %d casts, %d ups (%.0f%%)", r.name, r.casts, r.ups, rate))
        end
    elseif cmd == "resetstats" then
        local activeDB = A.DB.Active()
        if activeDB then activeDB.stats = {} end
        print("|cff00ff00[Alfred:Enchanting]|r Stats reset.")
    elseif cmd == "stop" or cmd == "cancel" then
        A.Engine.BulkCancel()
    elseif cmd == "show" then
        A.Engine.SetSticky(true)
        MP.Show()
        MP.UpdateButton()
        print("|cff00ff00[Alfred:Enchanting]|r Panel shown (sticky). /eb hide to hide it.")
    elseif cmd == "hide" then
        A.Engine.SetSticky(false)
        MP.Hide()
        print("|cff00ff00[Alfred:Enchanting]|r Panel hidden.")
    elseif cmd == "listen" then
        if args == "off" then
            A.Engine.SetListen(false)
            print("|cff00ff00[Alfred:Enchanting]|r Listen OFF.")
        else
            A.Engine.SetListen(true)
            print("|cff00ff00[Alfred:Enchanting]|r Listen ON — all events will be printed. /eb listen off to stop.")
        end
    elseif cmd == "set" then
        if not args then
            print("|cffff9900[Alfred:Enchanting]|r Usage: /eb set <slot> <item name>")
            print("  Slots: bracer, cloak, chest, gloves, boots, shield, ring")
            print("  Ex:    /eb set bracer Bands of Indwelling")
            return
        end
        local slotKey, itemName = args:match("^(%S+)%s+(.+)$")
        if not slotKey or not itemName then
            print("|cffff9900[Alfred:Enchanting]|r Usage: /eb set <slot> <item name>")
            return
        end
        slotKey = slotKey:lower()
        if AlfredEnchanting_SetSlotByName then
            local ok, info = AlfredEnchanting_SetSlotByName(slotKey, itemName)
            if ok then
                print("|cff00ff00[Alfred:Enchanting]|r |cffffd100" .. itemName .. "|r → |cffffd100" .. info .. "|r")
            else
                print("|cffff9900[Alfred:Enchanting]|r Error: " .. tostring(info))
            end
        end
    elseif cmd == "list" then
        print("|cff00ff00[Alfred:Enchanting]|r Configured items:")
        local slots = A.Profession.slots or {}
        for _, s in ipairs(slots) do
            local item = A.DB.GetSlotItem(s.key)
            if item and item ~= "" then
                print(string.format("  |cffffd100%s|r → %s", s.key, item))
            else
                print(string.format("  |cff888888%s|r → (unassigned)", s.key))
            end
        end
    elseif cmd == "step" then
        if not args then
            local n = MP.GetCurrentStep()
            local total = MP.GetTotalSteps()
            local entry = MP.GetGuideEntry(n)
            local spell = entry and entry.spell
            local kind = entry and entry.kind or "enchant"
            local slot = (kind == "enchant") and MP.GetSlotForSpell(spell) or nil
            local item = slot and MP.GetItemForSlotKey(slot)
            print(string.format("|cff00ff00[Alfred:Enchanting]|r Step |cffffd100%d/%d|r [%s · %s · %dx]: %s → %s",
                n, total, kind, entry and entry.range or "?", entry and entry.count or 0,
                tostring(spell), tostring(item or "(n/a)")))
            return
        end
        local n = tonumber(args)
        if not n then
            print("|cffff9900[Alfred:Enchanting]|r Usage: /eb step <N>")
            return
        end
        MP.SetStep(n)
    elseif cmd == "next" then
        MP.NextStep()
    elseif cmd == "prev" or cmd == "previous" then
        MP.PrevStep()
    elseif cmd == "guide" then
        local total = MP.GetTotalSteps()
        local kindColors = MP.GetKindColors()
        print(string.format("|cff00ff00[Alfred:Enchanting]|r Guide (%d steps):", total))
        local current = MP.GetCurrentStep()
        for i = 1, total do
            local entry = MP.GetGuideEntry(i)
            local marker = (i == current) and "|cff00ff00→|r " or "  "
            local kindColor = kindColors[entry.kind or "enchant"] or "ffffffff"
            print(string.format("  %s|cff888888%2d|r |c%s[%s]|r %s |cffaaaaaa(%s · %dx)|r",
                marker, i, kindColor, (entry.kind or "?"):sub(1, 4),
                entry.spell or "?",
                entry.range or "?", entry.count or 0))
        end
    elseif cmd == "pin" then
        if not args or args == "" then
            print("|cffff9900[Alfred:Enchanting]|r Usage:")
            print("  /eb pin <FrameName>   — pin the panel to the given frame")
            print("  /eb pin auto          — auto-detect TSM/Blizzard/Skillet")
            print("  /eb scan              — list visible relevant frames")
            print("  /eb unpin             — return to free-floating")
            return
        end
        if args == "auto" then
            local candidates = { "TSMCraftingFrame", "TradeSkillFrame", "SkilletFrame", "ProfessionsFrame", "ATSWFrame" }
            local found
            for _, name in ipairs(candidates) do
                local f = _G[name]
                if f and f.IsShown and f:IsShown() then
                    found = name
                    break
                end
            end
            if found then
                A.DB.Shared().pinTo = found
                MP.ApplyPin()
                print("|cff00ff00[Alfred:Enchanting]|r Pinned to |cffffd100" .. found .. "|r.")
            else
                print("|cffff9900[Alfred:Enchanting]|r No visible tradeskill frame detected. Open the tradeskill first, then /alfred pin auto. If it still fails, use /alfred scan.")
            end
            return
        end
        local target = _G[args]
        if not target then
            print("|cffff9900[Alfred:Enchanting]|r Frame '" .. args .. "' does not exist.")
            return
        end
        if not (type(target) == "table" and target.IsShown) then
            print("|cffff9900[Alfred:Enchanting]|r '" .. args .. "' exists but is not a Frame.")
            return
        end
        A.DB.Shared().pinTo = args
        MP.ApplyPin()
        print("|cff00ff00[Alfred:Enchanting]|r Pinned to |cffffd100" .. args .. "|r.")
    elseif cmd == "unpin" then
        A.DB.Shared().pinTo = nil
        MP.ApplyPin()
        print("|cff00ff00[Alfred:Enchanting]|r Unpinned. Panel free-floating.")
    elseif cmd == "minimap" then
        local shared = A.DB.Shared()
        if not shared then return end
        if args == "show" or args == "on" then
            shared.minimapHide = false
            A.UI.Minimap.Show()
            print("|cff00ff00[Alfred:Enchanting]|r Minimap button visible.")
        elseif args == "hide" or args == "off" then
            shared.minimapHide = true
            A.UI.Minimap.Hide()
            print("|cff00ff00[Alfred:Enchanting]|r Minimap button hidden.")
        else
            -- Toggle
            shared.minimapHide = not shared.minimapHide
            if shared.minimapHide then
                A.UI.Minimap.Hide()
                print("|cff00ff00[Alfred:Enchanting]|r Minimap button hidden. /alfred minimap show to bring it back.")
            else
                A.UI.Minimap.Show()
                print("|cff00ff00[Alfred:Enchanting]|r Minimap button visible.")
            end
        end
    elseif cmd == "test" then
        -- Current step requirements diagnostic
        print("|cff00ff00[Alfred:Enchanting]|r Current step test:")
        local n = MP.GetCurrentStep()
        local entry = MP.GetGuideEntry(n)
        if not entry then
            print("  No entry for step " .. n)
            return
        end
        print(string.format("  Step %d: %s (kind=%s, range=%s, count=%d)",
            n, tostring(entry.spell), tostring(entry.kind), tostring(entry.range), tostring(entry.count)))

        print("  --- Spell-learned detection ---")
        local sName = entry.spell
        local link = GetSpellLink and GetSpellLink(sName)
        print("  GetSpellLink('" .. sName .. "'): " .. tostring(link))
        if GetSpellInfo then
            local info = GetSpellInfo(sName)
            print("  GetSpellInfo('" .. sName .. "'): " .. tostring(info))
            local _, _, _, _, _, _, spellID = GetSpellInfo(sName)
            print("  extracted spellID: " .. tostring(spellID))
            if spellID then
                if IsSpellKnown then
                    print("  IsSpellKnown(" .. spellID .. "): " .. tostring(IsSpellKnown(spellID)))
                end
                if IsPlayerSpell then
                    print("  IsPlayerSpell(" .. spellID .. "): " .. tostring(IsPlayerSpell(spellID)))
                end
            end
        end
        local cache = A.Spells.GetCache()
        local cacheSize = 0
        for _ in pairs(cache) do cacheSize = cacheSize + 1 end
        print("  Spellbook cache size: " .. cacheSize)
        print("  Spellbook cache contains this spell: " .. tostring(cache[sName] == true))
        print("  Final IsSpellLearned: " .. tostring(A.Spells.IsLearned(sName)))

        print("  --- Materials (mats check) ---")
        if entry.materials and #entry.materials > 0 then
            print(string.format("  Schema: |cff66ff66structured|r (skill %d-%d, %dx casts)",
                entry.skillStart or 0, entry.skillEnd or 0, entry.quantity or 0))
            local total = entry.quantity or 1
            for _, m in ipairs(entry.materials) do
                local perCast = (total > 0) and math.ceil(m.quantity / total) or m.quantity
                local have
                if m.itemId and GetItemCount then
                    have = GetItemCount(m.itemId)
                else
                    have = A.Bags.Count(m.name)
                end
                print(string.format("    [%d] %s: have=%d, perCast=%d, total=%d",
                    m.itemId or 0, m.name, have or 0, perCast, m.quantity))
            end
        else
            -- Fallback: legacy schema (string-parsed)
            local fullEntry = A.Reagents.FindFullEntry(entry.spell, entry.range)
            print("  Schema: |cffff9900legacy|r — FullEntry: " ..
                (fullEntry and ("range=" .. fullEntry.range .. ", reagents='" .. tostring(fullEntry.reagents) .. "'") or "nil"))
            local reagents = A.Reagents.Parse(fullEntry and fullEntry.reagents, entry.count)
            for _, r in ipairs(reagents) do
                local have = A.Bags.Count(r.name)
                print(string.format("    %s: have=%d, perCast=%d, total=%d",
                    r.name, have, r.perCast, r.totalCount))
            end
        end
    elseif cmd == "scan" then
        print("|cff00ff00[Alfred:Enchanting]|r Visible frames with relevant names:")
        local searchTerms = { "trade", "craft", "profession", "tsm", "enchant", "skillet", "atsw" }
        local found = 0
        for name, frame in pairs(_G) do
            if type(name) == "string" and type(frame) == "table" and type(frame.IsShown) == "function" then
                local ok, shown = pcall(frame.IsShown, frame)
                if ok and shown then
                    local lower = name:lower()
                    for _, term in ipairs(searchTerms) do
                        if lower:find(term, 1, true) then
                            print(string.format("  |cffffd100%s|r", name))
                            found = found + 1
                            break
                        end
                    end
                end
            end
        end
        if found == 0 then
            print("|cffaaaaaa  (none — open your tradeskill UI first)|r")
        else
            print(string.format("|cffaaaaaa  Total: %d. Use /eb pin <Name> to pin.|r", found))
        end
    else
        print("|cff00ff00[Alfred:Enchanting]|r Commands (aliases: /alfred, /aen, /eb):")
        print("  /alfred show / hide          — show/hide floating panel")
        print("  /alfred minimap              — toggle minimap button")
        print("  /alfred config               — open items panel")
        print("  /alfred step [N] / next / prev   — navigate guide steps")
        print("  /alfred guide                — list steps in chat")
        print("  /alfred pin <Frame> | auto   — pin panel to tradeskill UI")
        print("  /alfred unpin                — return to free-floating")
        print("  /alfred scan                 — list visible relevant frames")
        print("  /alfred set <slot> <item>    — assign item via chat")
        print("  /alfred list                 — view configured items")
        print("  /alfred diag                 — UI diagnostics")
        print("  /alfred listen on/off        — log events to chat")
    end
end
