# EnchantButton — Software Design Document

> **Current version: 2.0.0 — REDESIGN** (compatible with TSM4 / alternative UIs).
>
> Fundamental change: the single "Enchant" button did not work with TSM4 because TSM does not update `GetTradeSkillSelectionIndex` when the user selects something in its UI. The global API returned cached data from the last native tradeskill the client opened.
>
> **New model: 7 buttons per slot** (Bracer, Cloak, Chest, Gloves, Boots, Shield, Ring). The user:
> 1. Casts the enchant via their preferred method (TSM "Enchant" button, action bar, drag from spellbook…)
> 2. Clicks the button for the corresponding slot in our floating panel
> 3. The addon uses the configured item for that slot and confirms the `REPLACE_ENCHANT` popup
>
> Works with TSM, Skillet, the standard Blizzard UI, or with no tradeskill UI open.
>
> Previous versions:
> - 1.4.x — C_Container wrapper with fallback to old APIs, floating panel (no longer anchored to `TradeSkillFrame`).
> - 1.3.0 — standalone configuration panel, buttons always visible in Enchanting with explanatory text.
> - 1.2.0 — bulk mode, reagent validation, counter, skill tracking, auto-pick, spellID lookup, lazy creation, robust popup hook.

## 1. Purpose

Addon for **WoW Classic Anniversary (TBC, Interface 20504)** that speeds up leveling the **Enchanting** profession. Replaces the manual flow (select recipe → drag to hotbar → equip practice item → confirm popup) with **a single button** inside the Tradeskill window, with bulk casting support and automatic best-recipe picking.

Honors the guide's idea of emulating a macro
```
/cast <enchant>
/use <item>
/click StaticPopup1Button1
```
but generated dynamically from the selected enchant in the UI, without consuming macro slots or action bar slots.

## 2. Scope

**In scope:** contextual button on `TradeSkillFrame`, enchant→slot map, configurable item per slot, options panel, shift-click assignment from the bag, bulk mode (1/10/max), auto-pick of the best recipe, per-recipe skill-up tracking.

**Out of scope:** automatic reagent purchase, "next optimal step of the guide" suggestion, auto-vendoring of enchanted items, TSM/AH integration.

## 3. Architecture

### 3.1 File structure

| File | Role |
|---|---|
| [EnchantButton.toc](EnchantButton.toc) | Manifest. Declares `Interface: 20504`, `SavedVariables: EnchantButtonDB`, load order. |
| [EnchantData.lua](EnchantData.lua) | Static data: list of slots, default items, enchant→slot map (accepts name or spellID as key). |
| [EnchantConfig.lua](EnchantConfig.lua) | Options panel, persistence, shift-click hook, public API (`EnchantButton_GetItemForSpell`, `EnchantButton_GetItemForRecipe`, `EnchantButton_InitDB`). |
| [EnchantButton.lua](EnchantButton.lua) | TradeSkillFrame button, cast logic, bulk mode, skill tracking, auto-pick, events. |

Mandatory load order: **Data → Config → Button** (Button calls global functions defined in Config; Config consumes Data's tables).

### 3.2 Flow diagram (click on "Enchant")

```
TradeSkillFrame (recipe selected)
        │
        ▼
EnchantButton:OnClick — modifiers: shift=x10, ctrl=max, none=x1
        │
        ▼
StartBulk(N) → ScheduleNextBulk()
        │
        ▼
DoCast(idx)
        ├─ ResolveCast(idx)
        │     ├─ GetTradeSkillInfo(idx)             → skillName, skillType
        │     ├─ EnchantButton_GetItemForRecipe(idx) → itemName
        │     │     ├─ Try by spellID (from GetTradeSkillRecipeLink)
        │     │     └─ Fall back to name
        │     ├─ FindItemInBags(itemName)            → bag, slot
        │     └─ GetReagentCapacity(idx) > 0
        │
        ├─ pendingCastToken++; pendingPopupClick=true
        ├─ CastSpellByName(skillName) ; UseContainerItem(bag, slot)
        ├─ RecordCast(skillName)
        └─ After(2.0) fallback (token-checked)
                │
                ▼
StaticPopup_Show("REPLACE_ENCHANT")  ← hook
        │
        ▼
After(0.05) → StaticPopupNButton1:Click()
        │
        ▼
After(0.6) → ScheduleNextBulk() if bulkRemaining > 0
```

## 4. Data model

### 4.1 Static tables (in code, [EnchantData.lua](EnchantData.lua))

- `EnchantButtonSlots` — ordered array `{ key, label }` of the 7 supported slots (bracer, cloak, chest, gloves, boots, shield, ring).
- `EnchantButtonDefaults` — `{ slotKey = itemName }`. "Starter" items.
- `EnchantButtonSlotMap` — **single source of truth** about which enchants the addon recognizes. Accepts two key types:
  - `["Enchant Bracer: Spirit"] = "bracer"` (string, locale-dependent)
  - `[7418] = "bracer"` (numeric, spellID — locale-independent)
  The runtime tries by spellID extracted from the recipe link first, then falls back to name.

### 4.2 SavedVariables (`EnchantButtonDB`)

```
EnchantButtonDB = {
    bracer  = "Bands of Indwelling",
    cloak   = "Avian Cloak of Feathers",
    ...
    stats = {
        ["Enchant Bracer: Spirit"] = { casts = 12, skillUps = 8 },
        ...
    }
}
```

`EnchantButton_InitDB` fills gaps with defaults — never overwrites existing values except for "Restore defaults" (now with confirmation).

## 5. Components and responsibilities

### 5.1 Lazy button creation ([EnchantButton.lua:265](EnchantButton.lua:265))

`Blizzard_TradeSkillUI` is **LoadOnDemand** in TBC Classic, so `TradeSkillFrame` may not exist when our addon loads. `CreateButtons()` is called at three points:
1. If `IsAddOnLoaded("Blizzard_TradeSkillUI")` when we receive our `ADDON_LOADED` (case: another addon already forced it to load).
2. When we receive `ADDON_LOADED` with `arg1 == "Blizzard_TradeSkillUI"` (normal case: the user opens tradeskill for the first time).
3. As a fallback in `TRADE_SKILL_SHOW` if for some reason the previous didn't fire.

### 5.2 Contextual buttons

- **`enchantBtn`** ("Enchant (N)") — runs the cast for the selected recipe. Modifiers: shift=10, ctrl=max. Text reflects capacity: `Enchant (5)`, `No item in bag`, `No reagents`, `Cancel (3)` during bulk.
- **`autoBtn`** ("Skill up auto") — calls `EnchantButton_FindBestRecipe`, selects the recipe and casts. Prioritizes orange > yellow > green, skips grays.
- **`statusText`** — beneath the button, shows `Casts: N  Skillups: M (X%)` for the current recipe.

Visibility: only when the selected recipe is in `EnchantButtonSlotMap` and isn't a header.

### 5.3 Cast logic ([EnchantButton.lua:152](EnchantButton.lua:152))

`DoCast(idx)`:
1. `ResolveCast` validates recipe + assigned item + item in bag + reagents. Returns a clear message if it fails.
2. Increments `pendingCastToken`, sets `pendingPopupClick = true`.
3. `CastSpellByName(skillName)` arms the cursor with the enchant, `UseContainerItem(bag, slot)` applies it.
4. `RecordCast` increments the counter in `EnchantButtonDB.stats`.
5. `After(2.0)` schedules a token-checked fallback: only clears the flag if a more recent cast hasn't started (essential for bulk mode).

### 5.4 Popup hook ([EnchantButton.lua:175](EnchantButton.lua:175))

Replaces the v1.1 `After(0.15)`. `hooksecurefunc("StaticPopup_Show", ...)` detects when a `REPLACE_ENCHANT` popup appears. Verifies that `pendingPopupClick` is active (avoids confusing it with an unrelated popup), and after 0.05s looks for the popup in `StaticPopup1..4` and clicks its Button1.

### 5.5 Bulk mode ([EnchantButton.lua:194](EnchantButton.lua:194))

`StartBulk(count)` → recursive `ScheduleNextBulk()` with `After(0.6)` between casts. Aborts if: the cast fails in `ResolveCast`, no recipe is selected, the user clicks the button again (`BulkCancel`), or the TradeSkillFrame is closed.

Why 0.6s between casts: leaves enough time for the popup to close and the client to refresh bag/reagent state. Empirically lower (≤0.3s) causes overlaps.

### 5.6 Skill tracking ([EnchantButton.lua:106](EnchantButton.lua:106))

- `RecordCast(spellName)` on every `DoCast`.
- In `TRADE_SKILL_UPDATE`, we compare `lastKnownRank` with the current Enchanting rank (from `GetTradeSkillLine`). If it went up, we attribute the points to `bulkLastSpell` (the last recipe we cast).
- Persisted in `EnchantButtonDB.stats[spellName] = { casts, skillUps }`.

Limitation: if you skill up from an external cause (trainer, other interaction) on the same frame, the points get attributed to the most recent cast. Acceptable.

### 5.7 Auto-pick ([EnchantButton.lua:239](EnchantButton.lua:239))

`EnchantButton_FindBestRecipe` iterates `1..GetNumTradeSkills()`, filters out headers, and from the recipes that:
- Are in `EnchantButtonSlotMap`
- Have an assigned item that's available in the bag
- Have reagents for ≥1 cast
- Are not `trivial` (gray)

…returns the one with the lowest `score` per `{ optimal=1, medium=2, easy=3 }`. Orange beats yellow, yellow beats green.

### 5.8 Options panel ([EnchantConfig.lua](EnchantConfig.lua))

**v1.3.0 — standalone frame**: the panel is no longer registered in Blizzard's Interface Options. It's a Frame with `BasicFrameTemplate` (title, close button, drag from the top bar). Registered in `UISpecialFrames` so ESC closes it. `/eb config` opens/closes it. Reason: the `Settings.*` API changed several times across Classic versions, which caused the "open config" button to not work or the panel to remain invisible.

Earlier changes (v1.2.0):
- "Clear" button (text) replaces the confusing red "X".
- "Restore defaults" prompts via `StaticPopupDialogs["ENCHANTBUTTON_RESET_DEFAULTS"]`.
- "View stats" button that invokes `/eb stats`.
- Any change (assign/clear/reset) calls `EnchantButton_UpdateButton` to refresh the button live.

### 5.9 In-game button visibility (v1.3.0)

Before: buttons only appeared when the selected recipe was in `EnchantButtonSlotMap`. If the user selected something unsupported, they saw nothing and couldn't tell if the addon was loaded.

Now: **as long as `IsEnchantingOpen()` is true**, the buttons are always shown. The "Enchant" button's state changes with explanatory text:
- `Select a recipe` (no selection)
- `Recipe not mapped` (selection isn't in the map)
- `No item configured` (config slot empty)
- `No item in bag` (item not found)
- `No reagents` (missing materials)
- `Enchant (N)` (everything ready, N = max possible casts)
- `Cancel (N)` (during bulk)

Plus a welcome message the first time Enchanting is opened in the session: `[EnchantButton] active in Enchanting. /eb config to configure items.`

## 6. Slash commands

- `/eb` — help.
- `/eb config` — open the panel.
- `/eb debug` — print the selected recipe, spellID, resolved item, reagent capacity, items in bag.
- `/eb stats` — list skill ups per recipe, ordered by points descending.
- `/eb stats reset` — clears stats.
- `/eb stop` (alias `/eb cancel`) — cancel an in-progress bulk.

## 7. Design decisions

| Decision | Reason |
|---|---|
| enchant→slot map accepts name **or** spellID | Compatibility with the English client (the most common) without giving up on future multi-locale. The user can add `[spellID] = "slot"` entries by checking `/eb debug`. |
| Item per slot **is** editable, enchant→slot mapping is **not** | The item changes with character progress; the mapping is a stable game property. |
| Items matched by **name**, not itemID | The user assigns by shift-clicking what they have in their bag and reasons by name. Loses stacks with ambiguous names (rare). |
| `TRADE_SKILL_UPDATE` to refresh selection | In TBC, the selection handler is XML, doesn't allow safe `hooksecurefunc`. |
| Hook to `StaticPopup_Show` instead of fixed timer | Avoids getting stuck when there's lag or the popup is delayed; avoids confusion with other popups (`which == "REPLACE_ENCHANT"`). |
| Incremental token in `pendingCastToken` | In bulk mode, prevents the fallback of an old cast from clearing the state of a new cast. |
| Lazy creation of buttons (on `ADDON_LOADED` of `Blizzard_TradeSkillUI`) | The TradeSkill UI is LoD; creating the button earlier with nil parent crashes. |
| `BAG_UPDATE_DELAYED` instead of `BAG_UPDATE` | The latter fires many times in a row; the former groups them. |

## 8. Known limitations

- **Items with the same name:** the first one found is used.
- **Locale:** the default map is English names. For other clients, `spellID` entries must be added (the infrastructure already exists; it just needs to be populated).
- **Bags 0..4 only:** the reagent bag isn't scanned (doesn't apply to TBC).
- **Ambiguous skill-up tracking:** if the rank goes up from an external cause during a cast, it's attributed to the cast.
- **Bulk doesn't detect server failures:** if the server rejects a cast due to movement or damage, the addon doesn't know and proceeds to the next. The 2s `pendingPopupClick` timeout avoids getting stuck, but the bulk counter consumes "attempts" even if the enchant didn't execute.

## 9. Future extension points

1. **Populate `EnchantButtonSlotMap` with TBC spellIDs** to support non-English locales out of the box.
2. **Detect cast failure in bulk** — listen to `UI_ERROR_MESSAGE` or `UNIT_SPELLCAST_FAILED` to know if the cast actually executed.
3. **Suggest a cheaper practice item** automatically by scanning bags.
4. **Stats per slot/skill goal** — "you need 25 more points to 300, recommend continuing with recipe X".
5. **"Enchant and sell" button** — enchant and then auto-sell at the nearest vendor if open.

## 10. References

- Leveling guide: https://www.wow-professions.com/tbc/enchanting-leveling-guide-burning-crusade-classic
- WoW UI source (Classic Anniversary): https://github.com/Ketho/wow-ui-source-bcc/tree/classic_anniversary
- List of target enchants and item mapping: [guide.md](guide.md)
