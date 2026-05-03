# Alfred — Enchanting

Your personal butler for leveling professions in **WoW Classic Anniversary (TBC, Interface 20504)**.

Today it implements **Enchanting (1–375)** with a step-by-step guide, recipe and mats validation, and a real macro (`AlfredEnchant`) that updates itself to the current step. The architecture is **multi-profession**: the `Core` is profession-agnostic and new professions are added as a single file in `Professions/`.

## What it does

- **Step-by-step guide** from 1 to 375 with skill range, enchant kind, and notes (vendor, alternatives, optionals).
- **Auto-generated macro** (`AlfredEnchant`) that, at each step, casts the enchant + uses the practice item + confirms the `REPLACE_ENCHANT` popup.
- **Secure button** (`SecureActionButton`) on the panel — one click runs the macro for the current step.
- **Live validation**: ✓ Recipe learned · ✓ Mats OK, or a clear error message.
- **Configurable per-slot items**: shift+click an item from your bag onto the items panel to assign it as the practice item for that slot.
- **Interactive shopping list**: click = AH search, shift+click = chat link, right-click = Wowhead URL.
- **Minimap button** + panel pinnable to the tradeskill UI (TSM4, Skillet, Blizzard standard).
- **Automatic migration** of SavedVariables from previous versions (`EnchantButtonDB` → `AlfredEnchantingDB` → `AlfredDB`).

## Installation

1. Copy the addon folder to:
   ```
   World of Warcraft\_classic_\Interface\AddOns\Alfred-Enchanting\
   ```
   The folder must contain the `.toc`, `Data.lua`, `Config.lua` and the `Core/` and `Professions/` subdirectories.
2. If you had `EnchantButton/` (versions < 4.0), you can delete it — settings are migrated automatically.
3. Restart the client or `/reload`.

On load you should see:
```
[Alfred:Enchanting] loaded.
```

## Quick start

```
/alfred show         show/hide the main panel
/alfred step 1       jump to step 1
/alfred next | prev  navigate steps
/alfred guide window detailed guide + shopping list
/alfred config       items panel (assign by shift+click)
/alfred minimap      toggle the minimap button
```

Typical flow: `/alfred show` → place the panel wherever you want → click **Enchant** at each step. The `AlfredEnchant` macro updates itself; you can also drop it on a hotbar if you prefer.

### All slash commands

Four equivalent aliases: `/alfred` (canonical), `/alfred-enchanting`, `/aen`, `/eb` (legacy).

| Command | Action |
|---|---|
| `/alfred show` / `hide` | toggle main panel |
| `/alfred step [N]` / `next` / `prev` | navigate steps |
| `/alfred guide` | list steps in chat |
| `/alfred guide window` | open detailed guide |
| `/alfred config` | open items panel |
| `/alfred minimap` | toggle minimap button |
| `/alfred pin <Frame>` / `auto` | pin panel to tradeskill UI |
| `/alfred unpin` | free-floating |
| `/alfred set <slot> <item>` | assign item via chat |
| `/alfred list` | view configured items |
| `/alfred scan` | list visible relevant frames |
| `/alfred diag` | UI diagnostics |
| `/alfred test` | current step requirements |
| `/alfred listen on/off` | log events to chat |

## Architecture

```
Alfred-Enchanting/
├── Alfred-Enchanting.toc        manifest
├── Data.lua                     guide + slots + shopping list (no logic)
├── Config.lua                   items panel + shift+click + public helpers
├── Core/                        profession-agnostic modules
│   ├── Registry.lua             _G.Alfred + RegisterProfession
│   ├── DB.lua                   multi-prof schema + migrations
│   ├── Timer.lua                After() multiplexer (no C_Timer in TBC)
│   ├── Bags.lua                 C_Container compat
│   ├── Spells.lua               IsLearned + cache
│   ├── Reagents.lua             parse + mats check
│   ├── Tradeskill.lua           legacy bulk flow
│   ├── Macro.lua                build/update of the real macro
│   ├── Items.lua                item helpers
│   ├── MainPanel.lua            floating panel + nav + cast button
│   ├── Minimap.lua              minimap button
│   ├── Engine.lua               events + popup hook + skill tracking
│   └── Slash.lua                /alfred and aliases
└── Professions/
    └── Enchanting.lua           Alfred.RegisterProfession({...})
```

**Key idea**: each `.lua` receives the addon's private namespace via `local _, A = ...`. Core never knows about "Enchanting" directly — it reads from `A.Profession.*`, which is what each profession registers.

Full architecture, event, and design-decision details in [CONTEXT.md](CONTEXT.md).

## Adding a new profession

Create `Professions/<Yours>.lua` and add it to the `.toc` after `Professions\Enchanting.lua`:

```lua
local _, A = ...
Alfred.RegisterProfession({
    id   = "tailoring",
    name = "Tailoring",
    MacroName = "AlfredTailor",
    PopupName = nil,                         -- tailoring has no popup
    LogPrefix = "|cff00ff00[Alfred:Tailoring]|r",
    guide        = MyTailoringGuide,
    fullGuide    = MyTailoringFullGuide,
    shoppingList = MyTailoringShoppingList,
    GetSpellIDFromRecipeLink = function(link)
        return link and tonumber(link:match("item:(%d+)"))
    end,
    IsTradeskillOpen = function()
        return GetTradeSkillLine and GetTradeSkillLine() == "Tailoring"
    end,
})
```

Core treats it identically (same UI, same macro management, same skill tracking) — it just needs its own data + a small adapter. Conventions: `id` in lowercase, `MacroName` with the `Alfred` prefix, SavedVariables always inside `AlfredDB.professions[id]`.

## Compatibility

- **Client**: WoW Classic Anniversary (TBC), Interface `20504`.
- **Locale**: English client (spell names are hardcoded).
- **Tradeskill UI**: TSM4, Skillet, or the standard Blizzard one. The addon **does not depend** on `GetTradeSkillSelectionIndex` — it uses its own guide step, so TSM4 (which doesn't update that API) works fine.

## Known limitations

- `TRADE_SKILL_SHOW` may not fire with TSM4 — open the panel manually with `/alfred show`.
- `/alfred scan` may not find the TSM frame if it uses anonymous ones. Workaround: `/alfred pin TSMCraftingFrame`.
- Skill tracking (`AlfredDB.professions.enchanting.stats`) is wired up but not updated from the current macro flow.

## License

[MIT](Alfred/LICENSE) © 2026 Jose G Nieto A
