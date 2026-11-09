<p align="center">
  <img src="curseforge/GearPath-logo-400.png" alt="GearPath logo" width="160">
</p>

<h1 align="center">GearPath Upgrade Planner</h1>

<p align="center">
  <b>The best gear for every slot in WoW: Forever, and a map pin to go get it.</b>
</p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/gearpath-upgrade-planner"><img src="https://img.shields.io/curseforge/dt/1763570?label=CurseForge&logo=curseforge&color=f16436" alt="CurseForge downloads"></a>
  <a href="https://www.curseforge.com/wow/addons/gearpath-upgrade-planner"><img src="https://img.shields.io/curseforge/v/1763570?label=version&color=4c9a2a" alt="Latest version"></a>
  <img src="https://img.shields.io/badge/WoW-Forever%201.60.1-1f6feb" alt="WoW: Forever 1.60.1">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="GPL-3.0-or-later"></a>
</p>

---

GearPath looks at your class, spec and level, finds every upgrade you can actually get, and tells you where each one comes from: the quest giver, the vendor, the mob or the dungeon entrance. Open one window and see what's worth chasing right now.

## Features

| | |
|---|---|
| **Character tab** | Your slots around your model. A green arrow means an upgrade you can get now; gold means one worth chasing. Click an item to try it on and see how your stats would change, then **Put it on** from your bags. |
| **Route** | The best upgrade for every slot, grouped by zone and dungeon. Click one and the map pin goes there. |
| **Near you** | Upgrades in the zone you're standing in, closest first, with the distance to each. |
| **Browse** | Every piece of gear for your class near your level. Search, filter and sort it. |
| **Tooltips** | Every piece of gear shows how much better or worse it is than what you wear, by your class and spec (+12%, -8%), and where to get it. Mobs and NPCs list the upgrades they drop or sell. |
| **Quest reward pick** | Shows which reward to take, or the one that sells for the most if none is an upgrade. |
| **Dungeon loot** | Walk into a dungeon and see what drops there for you, by boss, with the +%. |
| **Rare watch** | An icon and a sound when a rare that drops an upgrade for you comes into view. |
| **Crafted gear** | The gear your professions can make: what you can craft now, which trainer or vendor has the recipe, what needs more skill. From your profession window and trainers, or every recipe at once with ProfessionDB. |
| **Weapon training** | Found a great staff but never learned Staves? GearPath says so and puts the weapon master on your route. |
| **Your call** | Untick what you don't do under Show: (PvP rank, reputation, dungeons...), or right-click an item to hide it or the vendor it's from. Settings lists what you hid. |
| **Learns and shares** | Quest rewards, loot and vendor gear you see are remembered and shared with other GearPath players, so new Forever gear shows up before the database has it. |

Plus: every class and spec (tanks, healers and Forever's melee Survival hunters included), stat weights you can change and share as a short string, item levels on the Character window, a minimap button, controller and ConsolePort support, and the DaylightUI and EllesmereUI looks.

## Install

**CurseForge (recommended):** install [GearPath Upgrade Planner](https://www.curseforge.com/wow/addons/gearpath-upgrade-planner). The app installs QuestieDB for you.

**By hand:** download the latest zip from CurseForge and unzip it into `World of Warcraft\_forever_\Interface\AddOns\`, so you end up with an `AddOns\GearPath` folder. Install QuestieDB from CurseForge the same way.

Then type `/gp` in game.

### Works with

| Addon | | What it adds |
|---|---|---|
| **QuestieDB** | required | Quests, drops, vendors and where they are |
| Questie | optional | Runs happily alongside GearPath |
| ForeverDungeonJournal | optional | Boss loot, dungeon quests, wings and entrances, including Forever's new dungeons |
| DaylightUI / EllesmereUI | optional | GearPath matches their look; EllesmereUI's bags get upgrade arrows |
| TomTom | optional | An arrow for map pins |
| ProfessionDB | optional | Every piece of gear your professions can make, and where to learn each recipe |

GearPath reads these while you play. It includes none of their code or data.

## Commands

| Command | |
|---|---|
| `/gp` | Open or close the window |
| `/gp spec` | List or switch your spec |
| `/gp weight` | List or change your stat weights |
| `/gp status` | What was found and how long it took |
| `/gp report` | One line to paste into a bug report |

The full list, how gear is sorted, how stat weights were chosen and where map pins go are all in the **[full guide](addon/README.md)**.

## Found a bug?

[Open an issue](https://github.com/Koulta/GearPath/issues) (or comment on CurseForge) with the item name, what you expected, and the line `/gp report` gives you.

## For developers

```
addon/       the addon itself (this folder is GearPath in AddOns)
  UI/        window, tabs, tooltips, rare watch
  Skin/      DaylightUI, EllesmereUI and native looks
  Data/      slots, classes and specs, client languages, translations
harness/     offline tests that run the addon outside the game
queries/     checks against a real QuestieDB install
curseforge/  CurseForge description, changelog and logo
```

The tests need Lua 5.1. From the repo root:

```sh
lua5.1 harness/run.lua addon native        # the whole addon against a fake game (also: daylight, ellesmere; add nodb or nojournal)
lua5.1 harness/classes.lua addon WARLOCK   # one class (add Alliance for the other faction)
lua5.1 harness/scoring_test.lua addon      # the upgrade math
lua5.1 harness/zone_test.lua addon         # map and zone checks
```

The `queries` scripts also need a QuestieDB install and LibDeflate (`luarocks install libdeflate`). After a QuestieDB update, `GPDIR=addon lua5.1 harness/qdb.lua <QuestieDB dir> queries/zones.lua` checks its zone data offline.

What changed in each version: [CHANGELOG](addon/CHANGELOG.md).

## Credits

- **The Questie team** for QuestieDB: code by Logonz, data by Muehe, TheCrux (BreakBB), Drejjmit, Dyaxler, Cheeq, TechnoHunter, Yttrium and everyone who contributes to Questie.
- **TheCrux (BreakBB)**, Questie's lead, for answering questions on Discord and giving the go-ahead to build on QuestieDB.
- **Exehn** for ForeverDungeonJournal.
- **Pimptasty** for LibProfessionDB (the ProfessionDB addon, MIT), the recipe database behind crafted gear.
- **Supersharpie** for Sharpie's Gear Judge (MIT), which GearPath's stat weights were checked against.

## License

Copyright (C) 2026 Koulta. GearPath is free software under the [GNU General Public License v3.0 or later](LICENSE).

World of Warcraft and its item, quest and character names are trademarks and content of Blizzard Entertainment. GearPath isn't made or endorsed by Blizzard.
