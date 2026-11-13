# GearPath

Your character sheet, a gear database and an upgrade route in one window, for WoW: Forever.

- **Character**: your slots around a model you can try items on, in front of your race's art from the game's dressing room. A green arrow marks a slot with an upgrade you can get now; a gold one means only upgrades worth chasing. Click a slot to list its upgrades, sorted by item level (or by gain or required level). Under the model, **Your stats** shows your real stats as the game has them (gear, talents and buffs), the ones your weights value most first, each with its share of your GearPath score; hover one for its weight. Click an item on the right to try it on, and the stats show what it would change (Spell Power 12 +7), along with your item level and GearPath score with it; items tried on in different slots add up, and **Take it off** goes back to what you wear. When what you tried on is in your bags, **Put it on** wears it (out of combat); if it binds when equipped, the button says so first and the game asks you to confirm. Empty slots are named underneath. With no slot picked, **Near you** comes first: upgrades you can get in the zone you're in (or the dungeon you're inside), closest first, with how many yards away each one is.
- **Route**: the best upgrade for each slot you can get now, grouped by zone, and a click on a place or an item puts the map pin there. A pick-one quest counts once; a quest that gives every reward doesn't. Below that is the gear worth chasing, grouped by dungeon (each wing on its own) or zone. Groups are colored: purple for dungeons, green for zones, gold for your bags.
- **Browse**: every piece of gear found for your class within reach of your level. Search it, filter by slot and by Show:, and sort by item level, gain, required level or name.
- **Settings**: the look and window scale, how far ahead to look, dungeon, world-drop and healer gear, the extras (tooltips, upgrade notes, learning, quest reward pick, dungeon loot, rare watch), checking and sharing, and your stat weights.
- **Tooltips**: gear gets a GearPath line everywhere: how much better or worse it is than what you have on, by your class and spec's weights ("GearPath (Affliction) +12%", or -8%, same, empty slot, equipped), then a line with where to get it. The colour is the verdict: green Best now, gold Worth chasing, red needs something first, white better but not on your lists, grey not an upgrade. Every other way to get it is in the window. NPCs and mobs list the upgrades they drop, sell or give for a quest ("GearPath: sells Ritual Dagger +12% Main Hand"), Best now first, up to three.
- **Upgrade notes**: a toast at the top of the screen when you put on an upgrade, with how much it adds to your GearPath score; a line in chat when a vendor you open sells an upgrade (with its price), and when a level-up lets you wear something from your bags. Turn them off under Settings > Extras.
- **Item levels**: the game's own Character window shows each item's level on its slot, in the item's quality colour, so you don't need a separate item-level add-on. Turn it off under Settings > Extras. With EllesmereUI's Character sheet on, it draws them itself and GearPath doesn't add a second set.
- **EllesmereUI**: pick EllesmereUI under Settings > Look (Automatic picks DaylightUI first, then EllesmereUI) and the window follows EllesmereUI's theme and accent. Its bags get a green arrow on gear that's an upgrade you can wear now. EllesmereUI can turn the look off for GearPath in its own options (Third-Party Addons).
- **Minimap button**: click it to open GearPath, right-click for Settings, drag it round the minimap's edge. Hover it for the Route's numbers. Turn it off under Settings > Extras. There's also a key binding: Key Bindings > AddOns > GearPath.
- **Addon list button**: hover GearPath's button in the addon list (by the minimap) for the Route's numbers (upgrades to get now and in how many places, how many are worth chasing) and the three biggest gains. Click it to open the window.
- **Quest reward pick**: when a quest offers a choice of rewards, a GearPath card beside the quest window (DaylightUI's or the game's) shows the best upgrade for you, with a green arrow on its button in the game's own window, and chat says it as you turn the quest in. If none of them is an upgrade, it picks the one that sells for the most. Healer gear and gear you can't use are never the pick.
- **Dungeon loot**: when you walk into a dungeon or raid, a small panel lists its drops that are upgrades for you, by boss, each with its slot and how much better it is than what you have on. Only real upgrades; nothing you need a reputation or rank for first, nothing you hid. Hover an item for its tooltip, shift-click to link it. It steps aside while you fight and comes back after, until you click Hide; drag to move, drag the corner to resize (right-click it for normal size), `/gp loot` to bring it back. Off with "Dungeon loot" in Settings > Extras.
- **Rare watch**: out in the world, when a rare of your zone that drops an upgrade for you comes into view, an icon pops up with a sound and a chat line, and goes again a while after it's out of sight or killed. In a dungeon whose rare mobs drop an upgrade for you, a row of icons sits on screen, one per rare, each showing the upgrade it drops with the rare's name underneath. An icon is dim while GearPath watches, and lights up with a glow, a sound and a chat line when its rare is close enough for the game to show it: within your nameplate range (enemy nameplates on), your target or mouseover, or a party member's target (or a rare marker on the minimap, where Forever has one). A killed rare gets a green check. The row hides while you're in combat. Hover an icon for the rare's drops and your nameplate range. Drag to move, right-click to hide it for the run, `/gp rare` to bring it back. An addon can't see mobs farther away than that, so a dim icon means "not seen yet", not "not here".
- **More rows**: drag the grip in the window's bottom-right corner to make it bigger; right-click the grip for the original size.

## Weapon training

A class can learn more weapons than it starts with. Weapon masters in the capitals teach them (10 silver each; Polearms 1 gold, from level 20), and your class trainer teaches Mail or Plate at 40 and Dual Wield. GearPath still lists gear that needs a skill you haven't learned, marked **Learn Staves first** in red, and its tooltip says who teaches it and where ("Learn Daggers first: Archibald, Undercity"). When the Route's picks need training, a row at the top of Best now names the trainer; click it for the map pin. **Put it on** waits until you've learned the skill. (Forever's weapon masters: Woo Ping, Buliwyf Stonehand, Bixi Wobblebonk and Ilyenia Moonfire for the Alliance; Sayoc, Hanashi, Ansekhwa and Archibald for the Horde. In Forever, druids can learn Polearms and rogues One-Handed Axes.)

**Best now** means easy to get at your level: a quest or vendor out in the world, at most 2 levels above you, not out in the other faction's home zones, and not in a zone 10 or more levels above you. Quests and vendors of the other faction, and loot from your own faction's people, are left out altogether.
**Worth chasing** means a dungeon, an elite or rare, a quest chain of 3 or more, a quest or mob above your level, or an item a few levels away.
**Needs something first** holds gear that needs a PvP rank, a reputation or a profession you don't have yet.

**Crafted gear** comes from the game, not QuestieDB (which has no recipes): open your profession window and the gear your recipes make is added; open a profession trainer and the gear it teaches is added too, with the skill each recipe needs and where the trainer stands. With **ProfessionDB** installed (optional), every recipe of your professions is known from the start, with how to get it: the nearest trainer or pattern vendor of your faction, a quest, a named mob, or a random drop. A trainer's own skill number always wins over ProfessionDB's, which runs high for Forever and shows with a question mark ("Needs Tailoring (75?)") until you've seen a trainer. Only your own professions count, and each character's known recipes are its own.
**Healer gear** (Healing is its biggest spell stat, like "+7 Healing, +3 Spell Damage") is left out, from drops, quests and vendors alike. Turn on **Healer gear** in Settings to list it anyway. (Classes whose weights count Healing aren't affected. Gear with "damage and healing" spell power isn't healer gear: it's everyone's.)

**Show:** on every tab is one filter for the whole window. Tick the kinds of content you want (quests, dungeons, vendors, mob drops and rares, world drops and chests, your bags, PvP rank, reputation, professions) and untick the rest. The lists, the slot arrows, the route and Browse all follow it. Reputation and PvP rank gear count as such whether or not you have the standing or rank yet.

**Hiding:** right-click an item in the window to hide the vendor it's from (**Hide items from <vendor>**) or the item itself. Settings > Hidden vendors and items lists what you hid, each with **Show again**.

## Client languages

GearPath reads items in every language WoW Classic ships in: English, German, French, Spanish (Spain and Mexico), Portuguese, Italian, Russian, Korean and Chinese (Simplified and Traditional). The bonuses on "Equip:" lines (spell power, a single school's spell damage, healing, hit, crit, mana per 5, attack power, ranged attack power) are matched against Blizzard's own wording in each language.

GearPath's own window (tabs, lists, buttons, Settings) is translated into German, French, Spanish, Portuguese, Russian, Korean and Chinese. **These are drafts made by machine**, not by native speakers; corrections are welcome. Item tooltip lines and chat messages are still English. To see the window in English, turn on **English text** under Settings > Extras and type `/reload`.

## Controllers

With the game's gamepad mode on, GearPath's window takes the controller while it's open: the D-pad moves through the list (on the Character tab, left and right go through the slots; on Settings it scrolls), **A** clicks, **X** is the right-click (the map pin and hiding), **Y** puts on what you tried on (or takes it off), the shoulder buttons change tab, and **B** (or Back, or Start) closes the window and gives the controller back. Bind a button to open GearPath under Key Bindings > AddOns > GearPath. With ConsolePort installed, its own cursor drives the window instead.

## Checking and sharing

GearPath double-checks where each item comes from. It asks the database again when you click a slot, every 10 minutes in the background (change it in Settings), and when you type `/gp check`. A green check on an item means you or another GearPath player saw it in game. A yellow **?** means something wants a second look: Forever changed the item since the database was made, the database has no location or quest giver for it, or the mob is far off the item's level. Hover the item to see why.

GearPath also shares what you see (quest rewards, loot and vendor gear) with every GearPath user online: your guild and group, and everyone else through a hidden GearPath chat channel. What's saved is kept in bounds: shared sources nobody has reported for 60 days are dropped, and both lists (yours and what's shared) are capped, the longest unseen going first. You get theirs in return. Only item, quest, NPC and map numbers and a short name are sent. A source the database doesn't know shows only once two players report it, or one player in your guild or group, and it's marked "reported by other players" so it's never mistaken for the database's word; a reported map spot is only used if the game has that map. To share with only your guild and group, turn off **Use the GearPath channel** under Settings > Checking and sharing (a chat line says this once, the first time it joins). Sharing as a whole can be turned off there as well.

## Needs

- **QuestieDB** (its own addon on CurseForge, the same data Questie uses) for quests, quest chains, drops, vendors and their locations. Without it, GearPath only lists your bags and gear you've seen in game. Where its zones and dungeons are on the game's maps is checked every time a new QuestieDB version loads: if an update changes how QuestieDB keeps them, GearPath says so once in chat and places map pins from the game's own maps and the Dungeon Journal instead (`/gp zones` shows the details).
- **DungeonJournal** (optional, ForeverDungeonJournal by Exehn): with it, GearPath also knows Forever's dungeons the way players run them. That covers which boss drops what, dungeon quests with their quest givers and whether you pick one reward or get them all, dungeon wings, level ranges, and entrances for map pins. It fills in what QuestieDB leaves out, such as new Forever dungeons like the City of Dalaran.
- **DaylightUI** (optional): with it, GearPath uses DaylightUI's look and shows up under its Plugins. Without it, GearPath uses the game's own look.
- **EllesmereUI** (optional): with it, GearPath can use EllesmereUI's look (Settings > Look) and marks upgrades in its bags.
- **TomTom** (optional): if you have it, map pins use its arrow.
- **ProfessionDB** (optional, LibProfessionDB by Pimptasty): with it, GearPath knows every piece of gear your professions can make and how each recipe is learned. It needs Ace3, VersionCheck-1.0 and LibAceGUIWidgets, which the CurseForge app installs with it.

## Commands

- `/gp`: open or close the window
- `/gp route`, `/gp browse`, `/gp settings`: open a tab
- `/gp status`: what was found, how many sources are saved, and how long the list took to build
- `/gp rescan`: rebuild the gear list
- `/gp check`: check every item now and say what needs a second look
- `/gp forget`: forget the sources learned in game and the ones other players shared
- `/gp weight`: list your stat weights; `/gp weight sp 1.1` sets one; `/gp weight reset` restores the defaults
- `/gp spec`: list your class's specs; `/gp spec holy` switches
- `/gp weights`: your stat weights as a short string to copy and share; `/gp weights GP1:...` uses someone else's (same class)
- `/gp report`: one line for a bug report (version, game and language, character, counts, speed, errors), ready to copy
- `/gp loot`: show the current dungeon's upgrades for you again
- `/gp rare`: show the rare watch again and put it back in its first spot
- `/gp zones`: check QuestieDB's zone and dungeon data (where map pins come from); `/gp zones accept` takes this QuestieDB version's as good after it dropped dungeons on purpose

## Stat weights

Pick your spec under Settings > Stat weights (or `/gp spec`): each one has its own weights, and your own changes to them are kept for each spec. The specs: Warrior Fury, Arms, Protection; Paladin Retribution, Holy, Protection; Hunter Marksmanship, Beast Mastery, Survival (melee, as Forever reworked it); Rogue Subtlety, Combat, Assassination; Priest Shadow, Holy/Discipline; Shaman Enhancement, Elemental, Restoration; Mage Fire/Frost, Arcane; Warlock Affliction, Destruction, Demonology; Druid Feral, Feral (bear tank), Balance, Restoration. Healing specs count Healing, so healer gear is listed for them. Tank specs value Stamina, Defense, Armor, Dodge and Parry.

Weapons also follow the spec: a slow main hand for Combat rogues (and a fast off hand), slow two-handers for Enhancement shamans, Retribution paladins and Arms warriors, a slow bow or gun for hunters, a dagger for Subtlety and Assassination (speed and type change what the weapon's damage is worth, not its stats). Racials aren't scored: Forever's are flat bonuses with any weapon, so they never change which item is better.

The leveling specs' weights come first: Affliction Warlock, Fire Mage, Shadow Priest, Subtlety Rogue, Marksmanship Hunter, Fury Warrior, Retribution Paladin, Enhancement Shaman and Feral Druid. The stats are in the order Forever's leveling guides give them (wow.gg's spec guides, Warcraft Tavern's class and stats guides). The gaps between them come from Forever's stat conversions: Strength is 2 attack power for warriors, paladins, shamans and druids; Agility gives 1% crit per 20 (29 for rogues, 53 for hunters); 1% of hit, crit or haste costs about what 14 points of a main stat do on an item; and every 14 attack power adds 1 damage per second to a weapon, so a point of weapon DPS is worth 14 times a point of attack power (half that in the off hand). Hit past the cap against mobs of your level (5% for attacks, 4% for spells in the beta; not official yet) counts for nothing. Spell power that heals as much as it damages counts as Healing too. Every spec was also checked against Sharpie's Gear Judge (Forever), whose numbers come from the wowsims simulator: hit, crit and main stats agreed within 2x; where both its level-60 and its leveling numbers disagreed with GearPath by more than that, GearPath took its leveling value, except where that would break the guides' order. Change any of them under Settings or with `/gp weight`.

To share weights, click **Copy my weights** under Settings (or type `/gp weights`) and copy the short string, like `GP1:WARLOCK:crit=7.5,hit=11,sp=1`. Someone playing the same class clicks **Paste weights** (or types `/gp weights` followed by the string) to use them. A pasted string is only read, never run: unknown stats, other classes and odd numbers are refused, and **Reset stat weights** goes back to the defaults.

## Where the map pin goes

- **Gear from a dungeon** (a boss, a rare, trash): the dungeon's entrance out in the world, each wing its own when the Dungeon Journal knows it, with its directions for the way in.
- **A quest:** whoever starts it. For a chain, the giver of its first quest you haven't done; for a dungeon quest, its giver outside the dungeon (the dungeon is named in brackets: "Quest: Rig Wars [35] (Gnomeregan), Orgrimmar").
- **A vendor, a mob or a chest out in the world:** where it is.

When you get there, the pin clears itself and chat says what to do: "Talk to Nogg to start Rig Wars (for Civinad Robes)", "You're at the entrance to Gnomeregan", "Talk to Kelm Hargunth to buy Scout's Medallion". A pin put down where you already stand waits until you've walked away and come back. If you put down a pin of your own, GearPath leaves it alone.

## Clicks

On the Route and Browse tabs, click an item to put the game's map pin on where you get it and open the world map there; on the Route tab, clicking a zone or dungeon bar pins that place. On the Character tab, click an item to try it on the model; right-click for the map pin or to hide it. On the other tabs, right-click to hide the item or its vendor. Anywhere: Ctrl-click opens the game's dressing room and Shift-click links the item in chat, as on any item in the game.

## License and credits

Copyright (C) 2026 Koulta. GearPath is free software, released under the GNU General Public License, version 3 or later (see `LICENSE`). It contains no code from other addons, and everything it knows about quests, drops, vendors and dungeons it reads at run time from the addons you have installed, each under its own license.

- **QuestieDB** by the Questie team (required on CurseForge, installed for you): quests, drops, vendors and where they are. Not included in GearPath. Questie itself is optional. QuestieDB's code is by Logonz, and its data by Muehe, TheCrux (BreakBB), Drejjmit, Dyaxler, Cheeq, TechnoHunter, Yttrium and everyone else who contributes to Questie. Special thanks to TheCrux (BreakBB), Questie's lead, for answering questions about QuestieDB on Discord and giving the go-ahead to build GearPath on it.
- **ForeverDungeonJournal** by Exehn: Forever's dungeons, bosses and entrances. Optional; not included.
- **DaylightUI**: GearPath matches its look when it's installed. Optional; not included.
- **EllesmereUI**: GearPath matches its look through EllesmereUI's published skinning API, puts upgrade arrows in its bags, and leaves item levels on the Character sheet to it. Optional; not included.
- **Sharpie's Gear Judge** by Supersharpie (MIT License, Copyright (c) 2025 Supersharpie): its wowsims-based Forever weights were used to check GearPath's, and some of its leveling values were taken (see Stat weights).
- **TomTom**: map arrows, when installed. Optional; not included.
- **LibProfessionDB** (the ProfessionDB addon) by Pimptasty (MIT License): every recipe, the item it makes, the skill it takes and how it's learned, read while the game runs. Optional; not included.

World of Warcraft and its item, quest and character names are trademarks and content of Blizzard Entertainment. GearPath isn't made or endorsed by Blizzard.

The test scripts (`harness`, `queries`) need Lua 5.1; the `queries` scripts also need a QuestieDB install and LibDeflate (`luarocks install libdeflate`), neither of which is part of this project. After a QuestieDB update, `GPDIR=<addon> lua5.1 harness/qdb.lua <QuestieDB dir> queries/zones.lua` checks its zone data offline; `/gp zones` in game does the full check.
