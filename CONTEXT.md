# Alfred — Project Context

> Read this file at the start of a new Claude Code session to pick up context.

## What it is

WoW addon for **Burning Crusade Classic Anniversary** (interface 20504) with a **multi-profession** architecture: a single profession-agnostic `Core` + independent `Professions/<X>.lua` modules registered via `Alfred.RegisterProfession({...})`.

Today only Enchanting is implemented (levels 1-375). Tailoring, Alchemy, etc. are added as new files in `Professions/` without touching Core.

**Core idea**: the addon maintains a real WoW macro (`AlfredEnchant`) that updates dynamically to the current step of the guide. The macro does `/cast <enchant> + /use <item> + /click StaticPopup1Button1`. Clicking a floating button on the addon's panel runs the macro through a `SecureActionButton`.

## User environment

- Client: **TBC Classic Anniversary**, interface `20504`.
- Tradeskill UI: **TSM4** (TradeSkillMaster 4) replaces Blizzard's standard `TradeSkillFrame`. **Critical**: TSM does not update `GetTradeSkillSelectionIndex` when the user selects something in its UI; the global API returns cached data from the last native tradeskill that was opened. That's why the addon does NOT depend on the "currently selected recipe" — it uses its own guide step.
- Locale: English client (spell names are hardcoded in English).

## Project structure

```
Alfred-Enchanting/
├── Alfred-Enchanting.toc        ← manifest (interface 20504, version 4.1.0)
├── Data.lua                     ← guide data + slots + slot map + shopping list (no logic)
├── Core/
│   ├── Registry.lua             ← _G.Alfred + Alfred.RegisterProfession + Get/SetActive
│   ├── DB.lua                   ← multi-prof AlfredDB schema + migration + accessors
│   ├── Timer.lua                ← After() multiplexer (C_Timer doesn't exist in TBC)
│   ├── Bags.lua                 ← C_Container compat + Find/Count items in bags
│   ├── Spells.lua               ← IsLearned + cache + GetIcon
│   ├── Reagents.lua             ← Parse + CheckStep
│   ├── Tradeskill.lua           ← legacy tradeskill API (old bulk flow)
│   ├── Macro.lua                ← Build + Update real macro (parameterized by A.Profession)
│   ├── MainPanel.lua            ← panel + RefreshGuide + nav + pin + close button
│   ├── Minimap.lua              ← circular minimap button
│   ├── Engine.lua               ← events + popup hook + legacy cast/bulk + skill tracking
│   └── Slash.lua                ← /alfred, /aen, /eb, /alfred-enchanting
├── Professions/
│   └── Enchanting.lua           ← Alfred.RegisterProfession({...}) with all the data
├── Config.lua                   ← items panel, shift+click hook, public helpers
└── Guide.lua                    ← standalone frame with detailed guide and shopping list
```

Load order (in .toc):
```
Data → Core/Registry → Professions/Enchanting → Core/DB → Core/Timer → Bags →
Spells → Reagents → Tradeskill → Macro → MainPanel → Minimap → Engine → Slash →
Config → Guide
```

## Architecture: Core + Profession Registry

**Each `.lua` receives the addon's private namespace via `local _, A = ...`.** It's the same shared table across every file in the addon (the second return of the WoW vararg).

**Core never knows "Enchanting" directly.** Core modules read from the active profession:
- `A.Profession.slots`, `.slotMap`, `.slotDefaults` — slot data
- `A.Profession.guide`, `.fullGuide`, `.shoppingList` — guide data
- `A.Profession.MacroName`, `.LegacyMacroName`, `.PopupName` — constants
- `A.Profession.GetSpellIDFromRecipeLink(link)` — parse a recipe link
- `A.Profession.IsTradeskillOpen()` — heuristic for "is this profession open?"

**`Professions/Enchanting.lua`** calls `Alfred.RegisterProfession({...})` with all of that on load. The first registered profession becomes active (`A.Profession = def`).

## Exposed globals

**`Alfred` global** (from Registry.lua):
- `Alfred.RegisterProfession(def)` — register a profession
- `Alfred.GetActiveProfession()`, `.GetActiveProfessionId()`, `.GetProfession(id)`
- `Alfred.SetActiveProfession(id)`, `.GetRegisteredProfessions()`

**SavedVariables** (in .toc):
- `AlfredDB` — current multi-profession schema:
  ```
  AlfredDB = {
      activeProfession = "enchanting",
      framePos = {...}, minimapAngle, minimapHide, pinTo,  -- shared UI
      professions = {
          enchanting = { currentStep, stats, slots = {bracer="..."} },
      },
  }
  ```
- `AlfredEnchantingDB` — legacy (pre v4.1), still listed so the migration can read it.
- `EnchantButtonDB` — legacy (pre v4.0), same.

Migration chain (one-shot, idempotent): `EnchantButtonDB → AlfredEnchantingDB → AlfredDB`.

**Globals from Data.lua** (consumed by `Professions/Enchanting.lua` and `Config.lua`/`Guide.lua` for back-compat):
- `AlfredEnchantingSlots`, `AlfredEnchantingDefaults`, `AlfredEnchantingShoppingList`, `AlfredEnchantingFullGuide`, `AlfredEnchantingGuide`, `AlfredEnchantingSlotMap`.

**Public functions** (in Config.lua, used by Engine.lua and future consumers):
- `AlfredEnchanting_InitDB()` — alias for `A.DB.Init()`.
- `AlfredEnchanting_GetItemForSpell(spellName)` / `_GetItemForRecipe(idx)` — resolves the configured item.
- `AlfredEnchanting_SetSlotByName(slotKey, itemName)` — used by `/alfred set`.
- `AlfredEnchanting_UpdateButton()` — refreshes the main panel (alias for `A.UI.MainPanel.UpdateButton`).
- `AlfredEnchanting_RefreshGuide()` — refreshes the current step (alias for `A.UI.MainPanel.Refresh`).
- `AlfredEnchanting_RefreshGuideHighlights()` — repaints highlights in the guide window.
- `AlfredEnchanting_ToggleConfig()` / `_ToggleGuide()` — opens/closes frames.
- `AlfredEnchanting_FindBestRecipe()` — auto-pick (legacy, currently unused).

**Named frames** (for external hooks/anchors):
- `AlfredEnchantingContainer` — main floating panel.
- `AlfredEnchantingClose` — panel's X button.
- `AlfredEnchantingConfigFrame` — items panel.
- `AlfredEnchantingGuideFrame` — detailed guide.
- `AlfredEnchantingMinimapButton` — minimap button.
- `AlfredEnchantingPrev`, `AlfredEnchantingNext`, `AlfredEnchantingCast` — panel buttons.

**Macro**: `AlfredEnchant`. Automatic migration of the old name (`EnchantStep`, pre-v4.0) in `Macro.Update` the first time. The macro has 3 lines for enchants (`/cast + /use + /click StaticPopup1Button1`) or 1 line for rods/wands/oils (`/cast`).

## Slash commands

Four aliases: `/alfred` (canonical), `/alfred-enchanting`, `/aen`, `/eb` (legacy).

| Command | Action |
|---|---|
| `/alfred show` / `/alfred hide` | toggle main panel |
| `/alfred minimap` | toggle minimap button |
| `/alfred config` | open items panel |
| `/alfred step [N]` / `next` / `prev` | navigate steps |
| `/alfred guide` | list steps in chat |
| `/alfred guide window` | open detailed guide |
| `/alfred pin <Frame>` / `auto` | pin panel to tradeskill UI |
| `/alfred unpin` | free-floating |
| `/alfred scan` | list visible relevant frames |
| `/alfred set <slot> <item>` | assign item via chat |
| `/alfred list` | view configured items |
| `/alfred diag` | UI diagnostics |
| `/alfred test` | current step requirements diagnostic |
| `/alfred listen on/off` | log events to chat |

## How to add a new profession

```lua
-- Professions/Tailoring.lua  (future)
local _, A = ...
Alfred.RegisterProfession({
    id   = "tailoring",
    name = "Tailoring",
    MacroName = "AlfredTailor",
    PopupName = nil,                         -- tailoring has no confirmation popup
    LogPrefix = "|cff00ff00[Alfred:Tailoring]|r",
    guide        = MyTailoringGuide,
    fullGuide    = MyTailoringFullGuide,
    shoppingList = MyTailoringShoppingList,
    -- no slots/slotMap/slotDefaults: tailoring doesn't need target items
    GetSpellIDFromRecipeLink = function(link) return link and tonumber(link:match("item:(%d+)")) end,
    IsTradeskillOpen = function()
        local line = GetTradeSkillLine and GetTradeSkillLine()
        return line == "Tailoring"
    end,
})
```

Add it to the .toc right after `Professions\Enchanting.lua`. Core treats it identically (same UI, same macro management, same skill tracking) — it just needs its own data + a small adapter.

## Key components

### Main panel (Core/MainPanel.lua, `A.UI.MainPanel.Create`)
Floating container 380×195, draggable, persistent position (`AlfredDB.framePos` in shared), X button (`UIPanelCloseButton`) top right. Contents:
- Title with version (read via `GetAddOnMetadata`)
- Nav row: `[<]  Step N/M · range  [>]`
- Spell with `[KIND]` badge and `[OPT]` if optional
- Slot item (`→ Bands of Indwelling (Bracer)`)
- Notes (vendor info, alternatives)
- Requirements line: `✓ Recipe learned · ✓ Mats OK` or errors
- Cast button (SecureActionButton) + Macros + Guide
- Status line: macro state

### Cast button (SecureActionButtonTemplate)
Multi-template `"UIPanelButtonTemplate,SecureActionButtonTemplate"` (order matters: UIPanel first to get a visible appearance). On click runs the `macrotext` updated on every `RefreshGuide`. Disabled when: in combat, no item, no learned recipe, no mats.

### Learned-spell detection (Core/Spells.lua, `A.Spells.IsLearned`)
**Iterating `GetSpellBookItemName` alone doesn't work** — enchanting recipes don't show up in the standard TBC Classic spellbook tab. Strategy: try multiple methods, default to `true` unless evidence says otherwise.
1. `GetSpellLink(name)` — returns a link only if known.
2. Iterated spellbook cache (backup, invalidated on `LEARNED_SPELL_IN_TAB` / `SKILL_LINES_CHANGED`).
3. `GetSpellInfo(name)` — returns nil if it doesn't exist.
Only returns `false` if all three fail.

### Mats detection (Core/Reagents.lua)
`A.Reagents.Parse` extracts `{name, perCast, totalCount}` from the string in `A.Profession.fullGuide[i].reagents`. Counts items in bag with `A.Bags.Count(name)` (uses `C_Container.GetContainerItemInfo` with a fallback to the global `GetContainerItemInfo`).

### Minimap button (Core/Minimap.lua)
Circular, parented to `Minimap`, draggable rotationally (math.atan2). Left click: toggle panel. Right-click: open guide window. Position in `AlfredDB.minimapAngle`.

### Detailed guide (Guide.lua)
Standalone scrollable frame with shopping list (2 columns, clickable items: click=AH search, shift+click=chat link, right-click=Wowhead URL popup) + 40 detailed steps. The current step is highlighted green.

## Known bugs / pending items

- **TRADE_SKILL_SHOW may not fire with TSM4** — the panel is shown via `/alfred show` manually.
- **`/alfred scan` may not find the TSM frame** if TSM uses anonymous frames. Workaround: `/alfred pin TSMCraftingFrame` (or whatever).
- **Skill tracking** (`AlfredDB.professions.enchanting.stats`) — the code is present but isn't updated from the macro flow (only from the old direct-cast flow, now disused).
- **Bulk mode** (`A.Engine.StartBulk`, `A.Engine.BulkCancel`) — legacy code still present, not integrated into the current macro flow. Could be revisited.
- **SDD.md is out of date** (still says "EnchantButton — Software Design Document"). Update when it becomes relevant again.

## Version history

- **1.0** (original): single button on TradeSkillFrame that casts the selected enchant + uses the item + confirms the popup.
- **2.0**: per-slot buttons (because TSM doesn't update `GetTradeSkillSelectionIndex`).
- **3.0**: step panels with auto-updated real macro. Full guide in a separate frame.
- **3.1-3.7**: interactive shopping list (AH/chat/Wowhead), pin to tradeskill UI, kinds in steps, optionals with notes/vendors, recipe and mats validation.
- **3.8**: minimap button.
- **4.0**: full rebrand `EnchantButton` → `Alfred - Enchanting`. Automatic SavedVariables and macro migration.
- **4.1.0** (Phases 1+2+3 of the multi-profession refactor):
  - **Phase 1**: physical split of `Main.lua` (62KB) into `Core/` (10 modules) + `Professions/Enchanting.lua`. Each file receives the private namespace via `local _, A = ...`. No functional changes. Close button (X) added to the panel. Version visible in the header.
  - **Phase 2**: `Core/Registry.lua` introduces `_G.Alfred` + `Alfred.RegisterProfession`. `Professions/Enchanting.lua` becomes a single call to `RegisterProfession({...})`. Core stops reading globals `AlfredEnchanting*` directly — everything goes through `A.Profession.X`.
  - **Phase 3**: `Core/DB.lua` introduces the multi-profession `AlfredDB` schema, with one-shot migration from `AlfredEnchantingDB`. Unified slash command `/alfred` added (with `/aen`, `/eb`, `/alfred-enchanting` as aliases). Folder and macro NOT renamed (preserve user's SavedVariables and muscle memory).

## Conventions for future addons / modules

- File at `Professions/<Profession>.lua`.
- Profession `id` lowercase ("tailoring", "alchemy").
- `MacroName`: `Alfred<Profession>` (e.g. `AlfredTailor`).
- Slash stays `/alfred` (single alias for all professions).
- SavedVariables always in `AlfredDB.professions[profId]`.

## Project files that are NOT part of the addon

- `SDD.md` — Software Design Doc (documentation, out of date).
- `guide.md` — original user guide with the macro list (historical).
- `CONTEXT.md` — this file.

## How to test in-game

1. Folder at `World of Warcraft\_classic_\Interface\AddOns\Alfred-Enchanting\` with all addon files (including the `Core\` and `Professions\` subfolders).
2. Delete/disable the old `EnchantButton/` if it exists.
3. Log in. You should see:
   - `[Alfred:Enchanting] loaded.`
   - (first time) `[Alfred] Schema upgraded to multi-profession (AlfredDB).`
   - (if migrating from EnchantButton) `[Alfred:Enchanting] Settings migrated from EnchantButton.`
4. `/alfred show` — the panel appears.
5. `/alfred step 1` — start clean.
6. Verify:
   - The panel shows step 1 with kind, range, count.
   - The `req` line says `✓ Recipe learned · ✓ Mats OK` (if you have both).
   - Click Enchant → runs the macro.
   - The `AlfredEnchant` macro exists in the game's macro list (Esc → Macros).
   - `/alfred diag` runs without errors and reports state.
   - `/alfred test` shows the current step's requirements.
