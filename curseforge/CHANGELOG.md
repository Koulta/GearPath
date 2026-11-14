# GearPath changelog

## 0.8.1

### Fixed
- **Bigger Look ahead / Best now range settings left the lists nearly empty.** With more levels to look through, GearPath asked the server about hundreds of items at once; the server answers a few dozen a second, so most waited past GearPath's time limit and were dropped, and the Route could end up with only a couple of items (thanks OrtusX). GearPath now asks for at most 40 at a time and asks again for any that don't answer, so every item gets loaded, however far ahead you look.

## 0.8.0

The biggest update yet: your own stat weights front and centre, a dungeon checklist, help at the Need/Greed window, a coin on gear that's safe to sell, Scarlet Monastery by wing, and more ways to look at your Route.

### New
- **Your own stat weights, easy to find.** Click your spec at the top of GearPath's window (the pencil), or **Change what counts for you: Stat weights** under the stats panel. Every weight shows its default beside it, and the ones you changed are marked **yours**. Make up to 8 **custom sets** of your own (a PvP set, a "my way" set...) and switch between them like specs; **Reset this spec** puts a spec back to its defaults. Tooltips and the window say whose weights they use, "(your weights)" when you've changed them.
- **Dungeon checklist.** In the dungeon loot panel, a boss you've killed is ticked off and dimmed with its items, and gear you loot gets a check mark. It's kept through a wipe and the run back, and starts over in another dungeon (or two hours later).
- **Dungeon quests in the loot panel.** Quests for the dungeon you're in whose rewards are upgrades for you are listed under the bosses. Click one for its quest giver on the map.
- **"Upgrade!"** When you pick up gear that's an upgrade, a note at the top of the screen says how much better it is. Off with **Upgrade toast** in Settings.
- **Loot roll help.** On the Need/Greed window, a line under the item: `GearPath: +105% for you (Waist)`, `GearPath: not an upgrade for you`, or `GearPath: for your other spec, Demonology: +12%`. Off with **Loot roll help** in Settings.
- **Safe to sell.** A small coin on gear in your bags that isn't an upgrade for any of your specs (custom sets included), or that you can never wear, and a tooltip line: `GearPath: not an upgrade for any of your specs, safe to sell`. Trinkets, tools, epics and gear without stats GearPath reads are never marked. On the game's bags, EllesmereUI's, DaylightUI's and Baganator. Off with **Safe to sell mark** in Settings.
- **Upgrade arrows in DaylightUI's bags and Baganator** (EllesmereUI's had them already), and their `upgrade` search finds GearPath's upgrades.
- **Route: Group by place or slot.** The Route is grouped by where you go, as always; pick **Group by: slot** to see it by Head, Chest, Weapon and so on, each item saying where it's from.
- **Route: This zone only.** Tick it to see only what you can get in the zone you're in (its dungeons too) and what's in your bags. It follows you as you travel.
- **Level-up note.** When a new level puts new upgrades on your Route, one chat line says how many: `GearPath: level 27, 3 new upgrades to get. Open the Route (/gp).`
- **Scarlet Monastery by wing.** In the Graveyard, Library, Armory or Cathedral, the loot panel is titled for that wing (`GearPath: Scarlet Monastery (Library)`) and lists only that wing's bosses.

### Changed
- **Enhancement shaman weights:** Intellect and Spell Power count for less, after Blizzard's November 10 class tuning cut Mental Dexterity (Intellect to attack power, 150% to 100%) and advised Strength and attack power gear for Enhancement.

## 0.7.17

### Changed
- **The dungeon loot panel stays with you for the whole run.** It used to close for good on your first pull (or after 20 seconds). Now it steps aside while you fight and comes back when the fight ends, until you click **Hide**. `/gp loot` brings a hidden one back.

## 0.7.16

A full review of the addon against the databases installed on November 9 (QuestieDB 1.0.13, DungeonJournal 1.7.4, ProfessionDB 1.9.1), Blizzard's hotfix notes to November 6 and the class tuning announced for November 10. No stat weights changed: Enhancement already puts Strength first, as Blizzard says it will be.

### Fixed
- **The dungeon loot panel didn't open if you zoned in while in combat** (a mob still on you in the cave before Wailing Caverns). It now opens as soon as the fight ends.
- **Your own sightings were being saved as "shared by other players".** Forever characters have a first and a last name, and GearPath didn't recognise its own messages coming back under the full name. Yours are now recognised, and the ones saved by mistake are cleared the first time you share something (`/gp status` will show a much smaller "other players shared" count).
- **Two of your characters with the same first name were treated as one** for "you know the recipe". Each character is now told apart.
- **Hit read from the game's stat table was wrong** whenever an item's tooltip line couldn't be read: 0.5% hit could count as 5%. Forever's own rates are used now (10 hit, 14 crit, 12 dodge, 20 parry to 1%). Lines such as "chance to get a critical strike with melee attacks" are read too.
- **Gear that needs a profession skill or a PvP rank stayed under Needs something first** after you got the skill or rank, until a /reload. It's checked again when your skills change.
- On a client with no menu system, a right-click on an item can no longer hide something by accident.

## 0.7.15

### New
- **Dungeon loot.** Walk into a dungeon or raid and a small panel shows its drops that are upgrades for you, by boss (in DungeonJournal's order when it's installed), each with its slot and the same +% as the tooltips. Only real upgrades: nothing you need a reputation or rank for first, nothing you've hidden. Hover an item for its tooltip, shift-click to link it to your group. It closes when you pull, or by itself after 20 seconds unless your mouse is on it, and opens again the next time you come in. Drag it where you like, and drag its corner to make it bigger or smaller (right-click the corner for normal size); `/gp loot` brings it back. Off with **Dungeon loot** in Settings > Extras.

## 0.7.14

### Fixed
- **Reputation gear listed as plain vendor gear.** A quartermaster's items (Illiyana Moonblaze's Silverwing Sentinels gear, for one) could show up on your lists as if any vendor sold them. Any item that needs a reputation ("Requires Silverwing Sentinels - Honored") now counts as Reputation under Show:, whether you have the standing yet or not, so unticking Reputation leaves out the whole list. PvP rank gear works the same way under PvP rank. (Reported by dmann420.)
- **Gear stuck under Needs something first after you earned the standing.** GearPath now checks your standing as it changes, so reputation gear moves to your lists the moment you reach it, without a /reload.
- **A "Requires" line could be missed.** If the game hadn't finished loading an item's tooltip when GearPath first read it, the requirement was lost until /reload. GearPath now reads it again.

### New
- **Hide a vendor or an item.** Right-click an item in GearPath's window: **Hide items from <vendor>** or **Hide this item** (on the Character tab the map pin is there too). A hidden vendor stops counting as a way to get anything: an item you can get some other way keeps that way, one only it sells drops off the lists. A hidden item drops off the lists from any source. Settings > **Hidden vendors and items** lists them, each with **Show again**. Tooltips don't change. (Requested by dmann420.)
- The hint on GearPath's window rows mentions the right-click.

## 0.7.13

- **Tooltips, settled.** Gear you could wear shows how much better or worse it is than what you have on, by your class and spec's weights, and under it, where to get it:
  ```
  GearPath (Affliction)                             +12%
  Vendor: Harold Raims, Tirisfal Glades (32.4, 66.4)
  ```
  - The right side reads **+12%**, **-8%**, **same** (a difference too small to matter), **empty slot** or **equipped**.
  - The colour is the verdict: green Best now, gold Worth chasing, red needs something first (with a line saying what), white better but not on your lists, grey not an upgrade.
  - This replaces the tooltip in the 0.7.12 file on CurseForge, which was an in-between version. Nothing else changed.

## 0.7.12

- **Crafted gear from ProfessionDB.** With the ProfessionDB addon installed (optional), GearPath knows every piece of gear your professions can make, from Forever's own game files and including Forever's new recipes, without opening a profession window first. Each one says how to get the recipe: the nearest trainer or pattern vendor of your faction (with a map pin), a quest, a named mob, or "random drop".
  - A trainer's own skill number wins. Once you've opened a trainer, GearPath uses what it asked for; until then the number is ProfessionDB's and has a question mark ("Needs Tailoring (75?)"), because its numbers run high for Forever.
  - Recipes that come with the profession count as known, and so do recipes the game says you've learned.
  - Without ProfessionDB, crafted gear still comes from your profession window and trainers, as in 0.7.10.
- **Tooltips: plus or minus, and where.** Gear you could wear gets one line: how much better or worse it is than what you have on, by your class and spec's weights (**+12%**, **-8%**, **same**, **empty slot**, **equipped**), and under it, where to get it:
  ```
  GearPath (Affliction)                             +12%
  Vendor: Harold Raims, Tirisfal Glades (32.4, 66.4)
  ```
  - The colour is the verdict: green Best now, gold Worth chasing, red needs something first (with a line saying what), white better but not on your lists, grey not an upgrade.
  - A difference too small to matter says **same**, not "+100%" (9 more armor on a caster).
  - Gone from tooltips, still in the window: the other ways to get an item, the wand damage line, the checker's notes, and the dungeon's way-in sentence (the map pin's message has it).
- Crafted gear's source line reads like the others: "Tailoring: you know the recipe", "Tailoring recipe: Victor Ward, Undercity (40.2, 30.1)", "Tailoring recipe: random drop".
- `/gp status` and `/gp report` mention ProfessionDB when it's there.

## 0.7.11

Tooltips, read through line by line:
- **Every piece of gear you could wear gets a line.** An item GearPath hasn't scored (a trainer's recipe the first time you hover it, an auction, a link in chat) is weighed on the spot: "better", "better, from level 20", "barely better" or "not an upgrade". It never says Best now, since where it comes from isn't known.
- **Better but not listed says why:** "better, but only from random loot", "better, but dungeons are off in Settings", "better, but on another continent".
- **"Barely better"** replaces "about the same as yours", which read wrong when the slot was empty.
- **No more "+0 pts".** "Not an upgrade" shows a number only when the item is worse.
- **"Alliance territory" goes after the map spot** ("Darkshore (34.8, 87.3), Alliance territory"), so two brackets never sit side by side.
- **No repeats.** The same chest or NPC isn't listed twice under "or", and a vendor selling two items with the same name lists it once.
- **One line fewer.** "Checked just now: the game and the database agree" is gone from every tooltip; warnings and "Seen in game: confirmed" stay.
- Smaller wording: "chain of 2, starts with X, from Y" (a comma before who gives it), "location not in the database yet", and "Random chests (spawns all over)" when the chest's name isn't known.

## 0.7.10

- **Crafted gear.** QuestieDB has no recipes, so gear you can make never showed up. Open your profession window or a profession trainer and GearPath now reads what gear those recipes make (from the game itself, for the professions you have). A recipe you know is **Best now** ("Crafting: Tailoring (you know the recipe)"); one you can train now points the map pin at the trainer; one above your skill waits under Needs something first ("Needs Tailoring (75)"). Each character's recipes are its own, and crafted gear sits under Professions in Show.
- **"Currently equipped".** An item you have on now says so in its tooltip, instead of GearPath saying nothing.
- **Trainer tooltips.** Hovering a recipe at a profession trainer now shows GearPath's line for the item it makes.
- **Fixed: "not an upgrade +100%".** A piece a sliver better than yours (9 armor over 9 armor, +100% of almost nothing) said "not an upgrade" next to a big percent. It now reads "about the same as yours" with no number, and a real gain that's off your lists (a world drop, a dungeon you've turned off) says "better, not on your lists".

## 0.7.9

- **Fixed: hit on a lighter armor type.** A piece of an armor type below yours (cloth for a rogue) counts for part of its worth, but the hit cap's correction to it counted in full, so hit gear of that kind could score too low or too high. The correction is now scaled the same way (a cloth piece a rogue values at 60% gets 60% of what its hit is really worth).

## 0.7.8

- **Hit for dual-wielders.** With a weapon in each hand, your auto-attacks still miss past the 5% hit cap (up to 24% against mobs of your level), so hit there isn't wasted: it now counts for 60% of its weight from 5% to 24%, and nothing past that, as Sharpie's Gear Judge 3.2.11 counts it for dual-wield Fury, rogues and melee hunters. It was counted as nothing past 5%, so a dual-wielder at the cap saw hit gear rank below worse items. One weapon, a shield or casting: the cap is as before.
- **"Alliance territory" / "Horde territory".** A quest out in the other faction's home zones now says so on its line and in its tooltip (it's why it's under Worth chasing and not Best now).

## 0.7.7

- **Version in the title.** The GearPath window's title says which version you run ("GearPath  v0.7.7", the version in grey), in every look.
- **Two warlock weights follow launch.** Checked against Sharpie's Gear Judge 3.2.11, rebuilt on Blizzard's launch notes (Life Tap now converts twice as much): Mp5 for Affliction 1.2 to 0.6 (Gear Judge's leveling value), and Intellect for Demonology 0.6 to 0.29 (its level-60 value, the nearer of its two). As before, a weight changes only where both of Gear Judge's tables (leveling and level 60) put it more than 2x from GearPath's, and never against the guides' stat order: Affliction's Intellect and Feral's Spirit keep the guides' order. Every other spec agreed within 2x.
- Checked on QuestieDB 1.0.11 and ForeverDungeonJournal 1.7.0 (both updated after launch): zone data in the shape GearPath knows (129 dungeons, all with an entrance), and a sweep as every class and spec, both factions, levels 10 to 60 (210 runs) found no problems. Hit caps unchanged (5% attacks, 4% spells against mobs of your level).

## 0.7.6

- **Your faction's gear only.** An Undead in Tirisfal was offered the Dwarven Tome from Important Heirlooms, a quest handed out in Ironforge: the Dungeon Journal lists it for both factions, but QuestieDB knows it's an Alliance quest. Where QuestieDB has a quest, its race list now decides, whatever the journal (or another player's report) says. A quest only the other faction's people hand out is left out too, even when its race list is empty (Owen Thadd in the Undercity, for an Alliance player).
- **No loot from your own side.** Gear that drops from your own faction's people (a Hillsbrad Farmer, for an Alliance player) isn't listed from them: you can't attack them. The other faction's people still count.
- **Enemy ground is a trip.** A quest out in the other faction's starting zones, the zones next to them or its capitals (Westfall or Elwynn Forest for a Horde player, the Barrens or Tirisfal for an Alliance one) is never Best now; it moves to Worth chasing, and goes after the other ways to get the same item. Neutral towns and givers out there are fine (Ratchet, the Darkmoon Faire).
- **Zephras Isle is an island.** The Skyborne's starting zone sits on no continent on the game's maps, so its vendors counted as next door: an Undead in Tirisfal had five Al'Aketh pieces under Best now, a trip by airship from Mulgore away. It now counts as a land of its own, like another continent: its gear shows once you're there.
- **Zones above your level are a trip.** A vendor or quest in a zone at least 10 levels above you isn't Best now; it's Worth chasing (Surfer Shoes from Jang in Booty Bay was Best now for a level 8).
- **EllesmereUI's bags: the arrow moved to the top right.** It sat on EllesmereUI's item level in the top left corner (an "11" with an arrow on top of it).
- **The header follows Show:.** With some kinds unticked under Show:, "7 to get now, 44 worth chasing" counts what the lists show (it counted everything, so it could say 7 over an empty Best now).

## 0.7.5

- **A worn item worth nothing to you isn't an empty slot.** A starter weapon with no stats your spec uses (a caster's Forsaken Dagger) made GearPath say "Main Hand (empty now)" in tooltips and "fills your empty slot" in upgrade notes. Over a worn item worth 0 points it now shows the gain in points ("+12 pts"); "empty now" is only for slots with nothing in them.
- **Nearer sources first.** When an item drops from several mobs that are just as easy to get, the one in the zone you're in comes first, then the rest of your continent, then across the sea (an Undead in Tirisfal was told to go to a Young Wolf in Elwynn Forest before Muad, right there in Tirisfal). The order follows you as you change zones.
- **Your lists stay on your continent.** Gear you could only get on another continent (a rare in Teldrassil, for an Undead in Tirisfal) is no longer in Best now, Worth chasing, the Route or Near you; its tooltip says "on another continent", and Browse still has it. When an item has a way to get it on your continent too, that way is used. Dungeons are never locked out (group finder). Sail across and GearPath looks again.

## 0.7.4

- **Map pins: QuestieDB's zone data is used again.** On launch night the check GearPath runs on each new QuestieDB version wrongly set QuestieDB 1.0.10's zone table aside ("puts zones on the wrong maps, 7 of 16 names agree"), so map pins fell back to the game's own maps and the Dungeon Journal. QuestieDB rightly puts subzones and towns (Deathknell, Brill, Goldshire...) on their zone's map; the check now leaves subzones out, lets a town or city count when it sits inside the map it's given, and ignores "The" and letter case. Tables that really put zones on the wrong maps are still caught.

## 0.7.3

- **Sharing reaches every GearPath player**: the hidden GearPath channel is now on for everyone, so what you see (and what others see) is shared with every GearPath user online, not only your guild and group. The first time it joins, a chat line says so and how to keep sharing to your guild and group (turn off "Use the GearPath channel" in Settings). Saves from earlier versions are switched on once. Strangers' reports of a source the database doesn't know still need two players before they show, and stay labeled "reported by other players".
- **QuestieDB is now its own addon** on CurseForge, and GearPath's required dependency there (Questie is optional). Checked on QuestieDB 1.0.10: same contract (4) as 1.0.9, and its changes since are quest and NPC corrections only, so GearPath reads it as before. The "QuestieDB isn't installed" note and `/gp status` now say to install QuestieDB rather than Questie.

## 0.7.2

- **EllesmereUI**: a new look under Settings > Look. GearPath's window follows EllesmereUI's theme and accent through its published skinning API (Automatic picks DaylightUI first, then EllesmereUI; EllesmereUI can turn it off for GearPath in its own options). Its bags get a green arrow on gear that's an upgrade you can wear now, and with its Character sheet on, GearPath leaves the item levels on the slots to it.
- **Survival hunters**: Forever reworked Survival into a melee spec, so it's now a spec of its own (Settings > Stat weights, or `/gp spec survival`). Agility first, then Hit (wow.gg); the melee weapon is what counts, a two-hander or two one-handers, whichever items are better; the bow only for its stats. The gaps come from Sharpie's Gear Judge's melee Survival leveling build.
- **New icon**: GearPath's shield-and-arrow logo in the addon list, the addon compartment and on the minimap button (and as DaylightUI's plugin icon).
- **Stat weights checked against Sharpie's Gear Judge** (wowsims-based): hit, crit and main stats agreed for every spec. Eleven values that both its raid and its leveling numbers put more than 2x off now use its leveling value: Spirit for Holy Paladins (0.74) and Restoration Shamans (0.81); Mp5 for Fire/Frost (0.48) and Arcane Mages (0.51), Demonology Warlocks (0.33) and Restoration Druids (0.61); Stamina for Destruction (0.21) and Demonology Warlocks (0.14) and Balance Druids (0.19); Spirit for Demonology Warlocks (0.2); Dodge for bear Druids (5 per 1%). Affliction and Feral Spirit keep the guides' order.
- **Safer sharing**: a source only other players report (the database doesn't know it) says "reported by other players"; a reported map spot is only used on a map the game has; a source's reporter count stops at 8, so one player can't pump it; and within one session, new shared items stop at the saved cap, so spam can't grow your saved file before the next load trims it.
- **License**: GPL-3.0-or-later (was MIT).
- Checked on QuestieDB 1.0.9 (the live game's): its zone data is in the shape GearPath knows, and a sweep as every class and spec, both factions, levels 10 to 60 (204 runs) found no problems.

## 0.7.1


- **Weapon damage is worth what it does**: every 14 attack power adds 1 damage per second in Forever, so a point of weapon DPS now counts 14 times a point of attack power (half that in the off hand, a little more for Combat rogues). Weapons were worth about half before.
- **No weapon racials**: since the October 15 beta notes, Forever's Human, Orc and Dwarf racials are flat bonuses with any weapon, so they no longer favor swords, axes or maces.
- **Weapon type** (a Subtlety rogue's dagger) changes what the weapon's damage is worth, not its stats.
- **The two hands are one choice** on the Route: a two-hander, or a main hand and off hand, never both, and their gain is counted once. Off a two-hander, a one-hander and off hand add up to what they're really worth. The same for what you try on.
- **Two rings or trinkets**: the second one is weighed against the stronger one you wear, and left out if it isn't a gain there.
- **Unique**: a second copy of a ring or trinket you wear can go on the other slot, unless it's Unique.
- **Healing**: "damage and healing" spell power counts as Healing too, so healers value it right, and it isn't treated as healer gear. Shadow priests count Healing a lot less.
- **Hit cap**: hit past the cap against mobs of your level (5% attacks, 4% spells, from the beta) counts for nothing.
- **Expertise**: Forever's "Reduces chance to be Dodged or Parried by 1.0%" line is read.
- **Percentages**: the tooltip's own percentage of hit, crit and the like is used over the stat table's number.
- **Fixed**: gear you wear that the game hadn't loaded yet (the first login after a patch) counted as an empty slot until the next rescan; now it waits for it and rescores.
- **Fixed**: learning a weapon skill or Dual Wield rescored only after something else changed (the modern client renamed the event).
- **Fixed**: with a controller, opening or closing the window in combat could leave its buttons stuck; it now waits for the fight to end.
- **Fixed**: putting on two items that bind when worn could lose the second one; they go on one confirmation at a time.
- **Map pins survive QuestieDB updates**: where QuestieDB's zones and dungeons are on the game's maps (its internal zone tables, which it doesn't promise to keep the same) is now checked when each new QuestieDB version loads: the shape of every row, and a sample of zones against the game's own map names. If a table is gone, unreadable, in a new layout or puts zones on the wrong maps, it's set aside and pins come from the game's own maps and the Dungeon Journal. An update with far fewer dungeon entrances than the last good version is flagged too. It's said once in chat; `/gp zones` has the details, and `/gp status` and `/gp report` say where pins come from. A public QuestieDB function for it is used first if a version adds one.

## 0.7.0

- **Specs**: pick yours under Settings > Stat weights (or `/gp spec`). Every class has its usual specs, tanks and healers included: Warrior Fury, Arms, Protection; Paladin Retribution, Holy, Protection; Hunter Marksmanship, Beast Mastery; Rogue Subtlety, Combat, Assassination; Priest Shadow, Holy/Discipline; Shaman Enhancement, Elemental, Restoration; Mage Fire/Frost, Arcane; Warlock Affliction, Destruction, Demonology; Druid Feral, Feral (bear tank), Balance, Restoration. Healing specs list healer gear. Your own weight changes are kept for each spec.
- **Weapon training**: gear that needs a weapon skill you haven't learned (or Mail, Plate, Dual Wield) is marked "Learn Staves first", with the weapon master who teaches it and where. The Route puts the trainer at the top, with a map pin.
- **Weapon speed and type**: slow main hands for Combat rogues (fast off hands), slow two-handers for Enhancement, Retribution and Arms, slow bows and guns for hunters, daggers for Subtlety and Assassination.
- **Weapon racials**: a Human's sword, an Orc's axe and a Dwarf's mace count for the crit they give in Forever.
- **Forever's weapons**: druids can use Polearms and rogues One-Handed Axes; hunters can't use thrown weapons; Polearms only from level 20.
- **Relic slot**: called Relic for paladins, druids and shamans.
- **Fixed**: when a second scan started while the first was still loading items (a level-up right after logging in), the list could show up half-built until the next rescore.
- Swept on Forever's full database as every class and spec, both factions, levels 10 to 60: no wrong armor or weapon types, no off-hand weapons before Dual Wield, no shields or relics for the wrong class, no other faction's vendors, no item picked twice.

## 0.6.0 (launch release)

- **Put it on**: try on gear from your bags on the Character tab, then put it on with one click (out of combat). Gear that binds when equipped says so on the button first, and the game asks you to confirm.
- **Rare watch in the open world**: when a rare of your zone that drops an upgrade for you comes into view (its nameplate, a target, a minimap marker), an icon pops up with a sound and a chat line. Its own switch under Settings > Extras.
- **Share stat weights**: Settings > Copy my weights gives a short string (`GP1:WARLOCK:...`) another player of your class can paste (Settings > Paste weights, or `/gp weights <string>`). Pasted strings are only read, never run.
- **Controllers**: with the game's gamepad mode on, the D-pad, A, X, Y, B and the shoulder buttons drive the window. ConsolePort's cursor works too.
- **Translations (drafts made by machine)**: the window, its lists and Settings in German, French, Spanish, Portuguese, Russian, Korean and Chinese. Item tooltip lines and chat stay English. Settings > Extras > English text turns them off.
- **`/gp report`**: one line with what a bug report needs, in a box ready to copy.
- **Faster first scan**: Forever's mobs can have thousands of spawns, and the database rebuilt the list on every read. GearPath now reads each NPC's spawns once a session: the first scan at low levels does about a third of the work it did, and a rescan a fraction of that.
- **Saved data kept in bounds**: shared sources nobody has reported for 60 days are dropped, and both saved lists are capped.
- `/gp status` also says how many sources are saved, how long the list took to build and GearPath's memory.

## 0.5.5

- Tested as every class and as Alliance. Dual wield is learned at 10 (rogues) or 20 (warriors, hunters). The stats panel ranks main stats first on a tie. "Off-hand DPS" label.

## 0.5.4

- Reads items in every Classic client language (German, French, Spanish, Portuguese, Italian, Russian, Korean, Chinese), matched against Blizzard's own wording. "Requires" and damage-per-second lines follow the game's own templates. PvP rank names come from the game.

## 0.5.3

- Item levels on the slots of the game's own Character window, in each item's quality colour.

## 0.5.2

- Minimap button (click: open, right-click: Settings, drag to move) and a key binding.

## 0.5.1

- Your stats under the model, with a preview of what a tried-on item would change.

## 0.5.0

- Wording pass, precise map pins (dungeon entrances, first quest givers), class weights retuned, NPC and wand tooltip lines, map pins that clear on arrival, vendor and level-up chat notes, an upgrade toast, counts on the addon list button, your race's art behind the model.

## 0.4.8

- First release after two days of real play.
