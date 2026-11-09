# GearPath dev kit

Koulta's WoW: Forever gear addon. This folder is the durable copy: the addon's
source, the offline test harness, the CurseForge kit, and these notes. The
game loads the copy in `<flavor>\Interface\AddOns\GearPath`, not this one.

## Tracker

Koulta's GearPath Tracker (to-dos, scheduled check-ins, in-game checks, plans, done, key facts):
https://claude.ai/artifact/22SminAgDNTEXrtFiM1dbK (pinned in his claude.ai sidebar). Its rows are
the `items` collection of the page's database: fields section (you, scheduled, ingame, later,
done, facts), title, detail, owner (You, Claude, Scheduled), when, done, order. At the end of
every GearPath session, update it with the ArtifactData tool on that URL: tick what got done,
add what was decided, move finished work to `done`. Never delete Koulta's own rows.

## Permissions

- **QuestieDB data as a built-in backup: allowed.** TheCrux (BreakBB, Questie lead, a GPL-3
  signer) replied on Discord, October 30, 2026: using the data "as backup" for people who don't
  have Questie installed "sounds good, yes", as long as GearPath tries the real QuestieDB first.
  Screenshot: `permissions/questie-thecrux-2026-10-30.png`. Credit Questie and QuestieDB; no
  Questie name or logo in GearPath's branding.
- He also said QuestieDB will soon be released on CurseForge as a standalone library. When it
  is, make QuestieDB (not Questie) GearPath's Required dependency on CurseForge, and list it in
  the TOC's OptionalDeps as now (`QuestieDB`).

## Folders

- `addon/` – the newest version, released or not (CHANGELOG.md says which; copy it into `Interface\AddOns\GearPath`).
  Bindings.xml sits next to the TOC; the game loads it by itself.
- `harness/` – offline tests: a fake WoW client (`wow.lua`), fake character,
  items and QuestieDB (`data.lua`), fake DaylightUI (`dui.lua`), the tests (`run.lua`),
  every language's Equip lines (`locales_test.lua`), GearPath's own text in every
  language (`text_test.lua`), the upgrade math (`scoring_test.lua`), QuestieDB's
  zone data breaking every way (`zone_test.lua`) and the real-QuestieDB loader (`qdb.lua`).
- `queries/` – one-off scripts (`weights.lua` ranks equal-budget stats per class;
  `speed.lua` times the full scan on the real QuestieDB; `sweep.lua` checks every
  pick as one class, faction and level against the real QuestieDB; `zones.lua` checks
  QuestieDB's zone and dungeon tables after a QuestieDB update).
- `curseforge/` – release zips, description, logo. Listed as "GearPath Forever"
  (the name "GearPath" is taken there).

## Running the tests

Needs Lua 5.1. From `harness/`, nine runs; all must end with 0 failed and 0 errors:

    lua5.1 run.lua <addon folder> native
    lua5.1 run.lua <addon folder> native nodb
    lua5.1 run.lua <addon folder> native nojournal
    lua5.1 run.lua <addon folder> daylight
    lua5.1 run.lua <addon folder> daylight nodb
    lua5.1 run.lua <addon folder> daylight nojournal
    lua5.1 run.lua <addon folder> ellesmere
    lua5.1 run.lua <addon folder> ellesmere nodb
    lua5.1 run.lua <addon folder> ellesmere nojournal

(`ellesmere` loads `eui.lua`, a stand-in for EllesmereUI written from its published
SKINNING_API.md: it records which frames GearPath hands it, and fakes its bag icon hook.)

Every class (and Alliance): `lua5.1 classes.lua <addon folder> <CLASS> [Alliance]` for
WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID; each must end
with 0 failed and 0 errors (what the class can wear, dual wield, two-handers,
relics, the ranged slot, the stat order, faction rules).

Weights check: `lua5.1 queries/weights.lua <addon folder>` should say
"all orders match the guides".

Upgrade math: `lua5.1 scoring_test.lua <addon folder>` and zone data:
`lua5.1 zone_test.lua <addon folder>`; both must end with 0 failed and 0 errors.
October 23, 2026 (0.7.1 work): every suite above, 3,192 checks, 0 failed.
October 29, 2026 (0.7.2): every suite above, 0 failed.
November 7, 2026 (0.7.14): every suite above, 0 failed (native 459 checks).
November 9, 2026 (0.7.16): every suite above, 0 failed (native 499 checks).

QuestieDB zone check after a QuestieDB update: from `harness/`,
`GPDIR=<addon folder> lua5.1 qdb.lua <QuestieDB folder> ../queries/zones.lua` (shape only;
the game's map names are only there in game: `/gp zones` does the full check).

Translations: `lua5.1 text_test.lua <addon folder>` must end with 0 failed: every
string the code passes through `L[...]` has all eight translations, format codes
match the English, and the addon runs in each language. A new UI string needs a
`t(...)` line in Data/Text.lua (English, de, fr, es, pt, ru, ko, zhCN, zhTW).

Speed: `GPDIR=<addon folder> LEVEL=30 lua5.1 qdb.lua <QuestieDB folder> ../queries/speed.lua`.
October 2026 (beta data, 21,279 items): load 30-40 ms; first scan 0.14-0.47 s of work
spread over about 1.1-1.4 s; rescan about 0.1 s; memory 4.7-6 MB. In game, `/gp status`
gives the real numbers (`/gp report` too).

Class sweep (real data): from `harness/`,
`GPDIR=<addon folder> CLASS=WARRIOR FACTION=Horde LEVEL=30 [SPEC=arms] [VERBOSE=1] lua5.1 qdb.lua <QuestieDB folder> ../queries/sweep.lua`.
It checks each pick against its own table of what each class can use (Forever's
changes included), the slot rules (off-hand weapons only with Dual Wield, shields,
relics, two-handers), your faction's vendors and no item picked twice; since 0.7.6 also faction rules checked on their own (no quest only the other faction gives or whose race list leaves you out, no drop from your own faction's people, nothing Best now in the other faction's home zones by area id, neutral givers and vendors excepted). Also nothing Best now in a zone 10+ levels above you (by area id). November 5, 2026 (0.7.6), QuestieDB 1.0.10: 162 runs (both factions, levels 5/8/10/15/20/30/40/50/60), 0 problems. November 6, 2026 (0.7.7), QuestieDB 1.0.11 and ForeverDungeonJournal 1.7.0: 210 runs (108 + every non-default spec at 20/40/60, both factions), 0 problems; zones OK (129 dungeons, 129 entrances); speed 80 ms rescan, 5.1 MB. November 7, 2026 (0.7.10): 210 runs again, 0 problems. Run it for
all nine classes, both factions, levels 10/20/30/40/50/60 (108 runs) plus each
non-default spec; every run must say 0 problems. October 23, 2026: 0 problems.
October 29, 2026, on QuestieDB 1.0.9 (the live client's): 204 runs (108 + every non-default
spec at 20/40/60, both factions), 0 problems. The live QuestieDB is in
`C:\World of Warcraft\_forever_\Interface\AddOns\QuestieDB`; four stub files under
`src\corrections\Forever\legacy` sit too deep for the bridge to copy (8 folders): the
`src\corrections\Era` stubs of the same names stand in for them offline (both are
stripped stubs; the data is in the TOC).

## Deploying to the game

1. Look at the installed copy first: if a file there is newer than the last
   deploy, Koulta edited it; adopt the change, don't overwrite it.
2. Copy only changed files; check the sizes afterwards.
3. A NEW file listed in the TOC only loads after a full game restart, not /reload.
4. In game: never turn on "Allow custom scripts" or change security settings.
   Check through GearPath's own window and commands.

## Rules for the work

- Use DaylightUI's public API only; copy none of its code or art.
- Don't copy GearQuest's data (All Rights Reserved).
- QuestieDB and ForeverDungeonJournal are read live, never copied.
- Plain, consistent wording in both looks (native and DaylightUI).
- GearPath is MIT (`addon/LICENSE`, also to be copied to the repo root for GitHub). Checked
  October 23: no Questie/QuestieDB code or data anywhere (addon, harness, queries, release zips).
- QuestieDB's zone tables are internal (`ZoneDB.private`): only ZoneData.lua reads them,
  checked, with the game's own maps and the Dungeon Journal behind them.

## Stat weights (Data/Classes.lua)

October 29, 2026: every spec checked against Sharpie's Gear Judge 3.2.7 (Forever, MIT,
wowsims-based): its level-60 profile and its level-30 leveling curve. Hit, crit and main stats
agreed within 2x. Where both disagreed with GearPath by more than 2x, GearPath took Gear Judge's
leveling value (or, where Gear Judge's two disagree with each other, the one nearer ours), unless
that would break a guide order (Affliction and Feral Spirit kept). Eleven values changed; the
list is in CHANGELOG.md (0.7.2).

November 6, 2026 (0.7.7): rechecked against Gear Judge 3.2.11 (its leveling weights rebuilt on
Blizzard's launch notes, 3.2.8 to 3.2.11), by the same rule: both its leveling curve (levels
20, 30 and 40) and its level-60 profile more than 2x off. Four flags: Affliction Mp5 1.2 -> 0.6
and Demonology Intellect 0.6 -> 0.29 changed; Affliction Intellect and Feral Spirit kept for the
guides' order. Note: its leveling rows price hit and crit far lower than its level-60 profiles
(1% hit about 1.4 spell power at level 30), so hit and crit only count as off when both are.
The comparison reads its Curves and Classes files as text (Python regex), never runs them.

Dual-wield hit (0.7.8, Nov 6): Classes.DW_HIT_CAP = 24 (method.gg's Forever hit guide) and
DW_HIT_SHARE = 0.6 (Gear Judge 3.2.11's ApplyForeverHitKnees for DW Fury, rogues and melee
hunters: full to 5%, 60% to 24%, 5% past; GearPath uses 0 past 24% as it does past every cap).
Score.DualWielding(): a one-hand or off-hand weapon in the off hand right now.


Since 0.7.0 each class has specs (`Classes.SPECS`; tanks and healers too). The
table below is each class's first spec, the default; the other specs override
weights, weapon speed (`speed = { base, k }` per hand) and main-hand type
(`mainType`). A player's own edits are kept per spec (`GP.char.specWeights`).
Racials aren't scored (since 0.7.1): Forever's Oct 15 beta notes made them flat bonuses
with any weapon (Human Ruthless +2% crit, Orc Savage +1% crit, Dwarf Earth Fury +2% crit damage).
Weapon DPS = 14 x the attack power weight (Forever: 14 AP = 1 DPS), off hand half (Combat
4.4 with Dual Wield Specialization); hunters' ranged DPS = 14 x ranged AP. Hit past
`Classes.HIT_CAP` (beta: 5% attacks, 4% spells vs your level; not official) counts for nothing.
"Damage and healing" spell power also counts as Healing. Agility follows the guides' order
(Koulta's call, Oct 23): Forever hasn't published its Agility-to-crit ratios.
The ORDER of stats comes from
Forever's guides (wow.gg spec guides; Warcraft Tavern class and stats guides;
cross-checked with Icy Veins, method.gg, mobalytics). The GAPS come from
Forever's conversions: Strength = 2 AP for warriors, paladins, shamans and
druids; 1% crit per 20 Agility (29 rogues, 53 hunters); 1% hit/crit/haste
costs about 14 main-stat points on an item; spell power about 0.86.
Checked October 2026 on the beta, where guides called the numbers guesswork.

| Class (spec) | Order |
|---|---|
| Warlock (Affliction) | SP > Hit > Int > Spi > Crit > Sta > Haste |
| Mage (Fire/Frost) | Hit > SP > Spi > Int > Crit > Sta |
| Priest (Shadow) | SP > Crit > Hit > Int > Sta |
| Rogue (Subtlety) | Weapon > Hit > Agi > Crit > Str > Sta |
| Hunter (Marksmanship) | Weapon > Agi > Spi > Int > Sta > Hit > Crit |
| Warrior (Fury) | Weapon > Hit > Crit > Str > Agi > Sta |
| Paladin (Retribution) | Weapon > Hit/Exp > Crit > Str > SP > Int > Agi |
| Shaman (Enhancement) | Weapon > Hit/Exp > Crit > Str > Int > Agi > SP > Spi > Sta |
| Druid (Feral) | Weapon > Hit/Exp > Crit > Str > Agi > Sta > Spi > Int > SP |

## Launch (November 4, 2026, 6 PM Eastern)

The beta ended October 23, 1 PM Eastern; character creation opens October 27, but
that's name reservation only: you can't enter the world, so addons don't run. Every
in-game check below (and the DaylightUI layout restore, which needs the new character's
folder) waits for launch night. Installing files into the AddOns folder works any time.
The dev folder is C:\Users\koult\Documents\GearPath-dev (moved out of the WoW folder;
older notes and check-ins may still say C:\World of Warcraft\GearPath-dev).

- [x] Live client found: `C:\World of Warcraft\_forever_` (wowf 1.60.1.70532, the
      beta's build, so `## Interface: 16001` holds). Check again on October 27 and
      at launch: a patch can raise it.
- [x] GearPath 0.7.0 installed into `_forever_\Interface\AddOns\GearPath` (October 23).
      Questie (QuestieDB) must be installed there too.
- [ ] Re-read the class guides for launch numbers; retune Data/Classes.lua, rerun the weights check.
- [ ] Check QuestieDB and ForeverDungeonJournal for launch updates (new dungeons,
      entrances, renamed items); rerun the harness and the real-data queries.
- [ ] Check the game's API still has what GearPath uses (C_Item, C_TooltipInfo,
      TooltipDataProcessor, C_Map pins, C_MerchantFrame, UnitStat and the stat functions).
- [ ] In game: `/gp status` for the real scan time and memory on launch data.
- [ ] Koulta runs `/gp report` once he reaches level 50 on live: errors should be 0; note the speed and memory.
- [ ] CurseForge screenshots (Character with stats panel, Route, a tooltip, Settings).
- [ ] Rebuild the release zip and update the CurseForge description and CHANGELOG.md.
- [x] Installed: the live AddOns\GearPath is a link to this folder's addon\, so the dev copy
      IS the installed copy (0.7.2 on October 29). New files (ZoneData.lua, Skin\Ellesmere.lua,
      Media\icon*.tga) need a full game restart, not /reload.
- [x] Real-data class sweep on 0.7.1/0.7.2 with QuestieDB 1.0.9: 204 runs, 0 problems (October 29).
- [ ] In game: `/gp zones` should say QuestieDB's data is in the shape GearPath knows, with
      "names agree" counts; `/dump C_Map.GetMapChildrenInfo(947, nil, true)` should list zones
      (the game fallback's root map; if empty, find Forever's world map id for `ZoneData.ROOT_MAPS`).
- [ ] In game: `/dump C_Item.GetItemStats(link)` on a "damage and healing" item (does the client
      report Healing apart?) and on Bloodvine Vest (does "2.0% hit" come back as 2 or a rating?).
- [ ] Recheck `Classes.HIT_CAP` and the racials against launch notes.
- [x] GitHub: noreply commit email set; LICENSE (now GPL-3) at the root. Repo: github.com/Koulta/GearPath.

## Review, November 9, 2026 (0.7.16)

Koulta asked for a once-over on Fable's trial. What was checked, and what it found:

- **Databases on his PC**: QuestieDB 1.0.13 (contract 4, zones OK: 129 dungeons, 129 entrances),
  ForeverDungeonJournal 1.7.4 (every field GearPath reads still there; `queries/gp_journal.lua` OK),
  ProfessionDB 1.9.1 (unchanged since the Nov 7 fixture), EllesmereUI 9.8.3, Interface 16001.
  Real-data sweep on 1.0.13: 210 runs, 0 problems, before and after the fixes.
- **Online**: Blizzard hotfixes Nov 5 and 6 (nothing GearPath models; Tanning Rack skill 140 -> 125 is
  ProfessionDB's to pick up). Class tuning announced for Nov 10 (Kaivax, Nov 6): Enhancement to have
  Strength always its strongest stat and not prefer caster gear (GearPath: str 1.0, int 0.55, sp 0.45:
  already that way; recheck once the hotfix text is out), pet durability, Affliction's Wrack vs DoTs
  (no stat change). Hit caps: method.gg (Oct 6) still 5% attacks, 4% spells, 24% dual wield vs your
  level; no official numbers. Icy Veins' Forever pages couldn't be fetched (the site refused).
- **Forever names**: a character has a first and a last name. UnitName("player") gives the first
  ("Koulta"); addon messages arrive under the full name ("Koulta Lorn"). Seen in his SavedVariables:
  231 of 268 shared sources were his own echoes, each marked trusted. Fixed with a per-session mark
  on every message (Share.mark, the "I:" piece; older versions skip it) and GP.char.shareNames.
  Learn.Me() is the character's GUID now.
- **Ratings**: the stat table gives hit/crit/dodge/parry as ratings at flat rates (Gear Judge 3.2.11
  GetGearPower: hit 10, crit 14, dodge 12, parry 20; senseos.gg from client 1.60.1.70862: hit 10,
  crit 14, dodge 12). Items.RATING_PER_PERCENT. The tooltip's percentage still wins.
- **Dungeon panel**: PLAYER_REGEN_ENABLED now retries (zoned in in combat). Known limit: Scarlet
  Monastery's wings are one instance name ("Scarlet Monastery"), so the panel lists all four wings
  there; the same for Dire Maul, Stratholme and Blackrock Spire if the game names them as one.
- **Not explained**: his saved file has no crafting records (learned.items[*].c) after three days with
  Tailoring. Other Forever addons use the same calls (GetTradeSkillLine, GetTradeSkillItemLink,
  TRADE_SKILL_SHOW), so either the window wasn't opened since 0.7.10 or GetTrainerServiceSkillReq /
  the trade skill calls answer differently. Ask him to open the Tailoring window, /reload, and read
  SavedVariables\GearPath.lua again.
- His Show: filter has drop, craft, rep, vendor and pvp unticked (his choice; the dungeon panel
  ignores Show:, on purpose).

## Crafted gear (0.7.10)

QuestieDB has no recipes. Learn.lua reads the profession window (TRADE_SKILL_SHOW/UPDATE:
GetTradeSkillLine, GetTradeSkillItemLink) and trainers (TRAINER_SHOW/UPDATE:
GetTrainerServiceItemLink, GetTrainerServiceSkillReq, category "used" = known) into
learned.items[id].c[profession] = { k = { [Name-Realm] = true }, r = skill, t = trainer, m, x, y }.
Only professions the character has (GetSkillLineInfo); never shared. Sources.CraftSource turns
it into a "craft" source: known (effort 1, route group "Craft it yourself"), trainable now
(effort 1, pin on the trainer), or needs "Tailoring (75)" (Needs something first). Every scan
adds learned crafts (addLearnedCrafts). Trainer recipe tooltips: hooksecurefunc on
GameTooltip.SetTrainerService. Untested in game until Koulta opens a trainer.

## ProfessionDB and simpler tooltips (0.7.12)

Crafts.lua reads LibProfessionDB-1.0 (the ProfessionDB addon, OptionalDeps) through LibStub:
an item index built once (2,511 Forever recipes; never-implemented ones left out), professions
matched by name (GetSpellInfo of each profession's spell vs your skill lines). Sources.CraftSource
merges per profession: Learn.lua's trainer skill and place win; ProfessionDB's skill is marked
unconfirmed ("Tailoring (75?)"). How the recipe is learned (Sources.RecipeWay): ProfessionDB's
trainer list -> nearest friendly trainer QuestieDB can place; else the recipe item's own QuestieDB
vendors / quest / drops; else ProfessionDB's vendor / quest / drop lists; else "random drop" or
"not in the database yet". Known: Learn.lua's profession window, auto-taught (AcquireMethod 1), or
IsPlayerSpell. Effort: known 1; needs 2; trainer/vendor with a place 1; quest or named mob 2;
random or unknown 3. addCrafts adds crafted items QuestieDB doesn't hold (level window when it does).
Real-data run Nov 7: ProfessionDB's Forever files read as TEXT into a fixture
(scratchpad/pdbtools/make_fixture.py, 2,511 recipes, 1,170 source lists) behind a stand-in of the
library's lookups; 8 class/profession mixes on QuestieDB 1.0.11, 0 problems (professions, skill vs
needs, other-faction NPCs, never-implemented recipes). Speed with it: rescan 87 ms vs 67 ms.
Tooltips, settled Nov 7 after several rounds (Koulta: "location, % +/- better than equipped", from
a mockup he okayed): "GearPath (Affliction)  +12%" (or -8%, same, empty slot, equipped) and one
"where" line; the colour is the verdict. "same" when |delta| < Score.MIN_POINTS (+100% of almost
nothing). A 0-100 rating was tried first and dropped: it needed a reference the tooltip can't show.
Don't change tooltip wording again without a mockup Koulta has okayed.

## Tooltip wording (0.7.11)

Read through every tooltip shape on the real QuestieDB (a level-14 Horde warlock dump:
scratchpad tips.lua = sweep.lua's setup + Tooltip.Add on one item per shape). Unscored
items get Tooltip.QuickEval (CanUse + class limits + Score.Upgrade; never a tier). Known
data quirk: QuestieDB marks Master Sergeant Biggins (12781, Alliance PvP vendor) "AH".

## Version history (short)

- 0.4.8 – personal release after two days of real play.
- 0.5.0 – review and wording pass, precise map pins (dungeon entrances, first
  quest givers), class weights retuned, NPC/mob and wand tooltip lines, pins
  that clear on arrival, vendor and level-up chat notes, upgrade toast,
  addon list button counts, race background behind the model.
- 0.5.1 – stats panel under the model, with a preview of what a tried-on item changes.
- 0.5.2 – minimap button (click: open, right-click: Settings, drag to move) and a key binding (Bindings.xml).
- 0.5.3 – item levels on the slots of the game's own Character window.
- 0.5.5 – tested as every class and as Alliance: dual wield learned at 10 (rogues) or 20 (warriors, hunters); the stats panel ranks main stats first on a tie; "Off-hand DPS" label.
- 0.5.4 – reads items in every Classic client language (Data/Locales.lua, from LOCALE_RESEARCH.md); "Requires" and damage-per-second lines follow the game's own templates; PvP rank names from the game.
- 0.6.0 – launch release: Put it on (bag gear, Bind on Equip warning), open-world rare watch, weight sharing (GP1 strings, read only), controllers (D-pad/A/B/X/Y/shoulders; ConsolePort's cursor), draft machine translations of the window (Data/Text.lua; "English text" setting), `/gp report`, spawn summaries cached (first scan about 3x less work), saved sources capped (shared: 60 days, 2000; yours: 4000), speed and memory in `/gp status`. CHANGELOG.md in the addon.
- 0.7.0 – every class and spec: specs per class (tanks, healers; `/gp spec`), weapon training
  (Training.lua: "Learn Staves first" with the weapon master, the Route pins the trainer;
  Mail/Plate/Shield/Dual Wield send you to the class trainer), weapon speed and type per
  spec, weapon racials, Forever's weapon changes (druid polearms, rogue one-handed axes,
  no hunter thrown, polearms from 20), Relic label, scan race fixed (`Sources.gen`).
  Swept on the real QuestieDB: 108 runs plus specs, 0 problems.

- 0.7.1 (unreleased, October 23) – review fixes: weapon DPS priced from AP (was about half),
  racials removed, the two hands one choice on the Route (no 2H + shield; no double count),
  second ring/trinket against the stronger one, Unique, damage-and-healing counts as Healing,
  hit cap, expertise line, tooltip percentages win, worn gear not yet loaded isn't an empty
  slot, LEARNED_SPELL_IN_SKILL_LINE, controller not toggled in combat, one Bind on Equip
  confirmation at a time, `/gp zones` + ZoneData.lua (QuestieDB zone tables checked, game
  fallback), MIT license.
- 0.7.2 (October 29) – EllesmereUI look (Skin/Ellesmere.lua, its published skinning API;
  bag upgrade arrows via EUI_Bags.RegisterItemOverlayIcon; no second set of Character-sheet
  item levels when its sheet is on), new icon (Media/icon.tga, icon_round.tga, plugin.tga),
  11 weights from Sharpie's Gear Judge (see Stat weights), sharing hardened (label, map check,
  count cap at 8, in-session item cap), Survival hunter spec (melee in Forever; Shaman has no
  tank spec in Forever, so none was added: tanking is an Enhancement option), GPL-3. Includes 0.7.1.

## Done in 0.6.0 (the list agreed on October 20)

1. Saved shared/learned sources capped. 2. Put it on. 3. `/gp report`. 4. Speed check
(again on launch day). 5. Weight sharing. 6. Open-world rare watch. 7. Changelog (screenshots
at the November 6 check). 8. Controllers and translations.

## Done in 0.7.0 (the sweep agreed on October 23)

1. Class-by-class sweep on real data. 2. Weapon trainer marks. 3. Unique rings (already
right: nothing worn or picked twice; tests added). 4. Specs. 5. Weapon speed. 6. Racials.

## Done in 0.7.2 (October 29)

1. Class sweep on 0.7.1 with QuestieDB 1.0.9. 2. Security review (SECURITY notes below).
3. Numbers pass vs Sharpie's Gear Judge. 4. EllesmereUI. 5. Icon, GPL-3, CurseForge page.

Security review, October 29: no code from outside runs (QuestieDB's zone tables run in an
empty environment, ZoneData.readTable); weight strings and shared records are pattern-matched,
range-checked and length-capped; names can't carry `|` escape codes; Put it on refuses in
combat, only acts on a click and only on your bags' items; `/gp report` has no character name;
the public share channel is opt-in. Fixed: player-only sources labeled, reported pins checked
against the game's maps, reporter count capped at 8, in-session new-item cap.

## Not checked in game yet (needs the player)

- Controller buttons (no controller here): open GearPath with gamepad mode on, try D-pad/A/B.
- Put it on with a real Bind on Equip item: the game's own confirmation should appear.
- A translated client (only English was played).
- Open-world rare watch on a real rare.
- Weapon training marks (0.7.0, written after the beta closed): on a new character, an
  untrained weapon type should say "Learn ... first" and the Route should pin the master.
  If the game ever answers wrongly about known skills, nothing is marked (Training.Reliable).
- Weapon speed read from real tooltips (the harness parses the beta's tooltip layout).
- The Spec dropdown in Settings and `/gp spec`.
- 0.7.1: ZoneData's game fallback (only used if QuestieDB's zone data changes), the hit cap
  with real gear, Put it on with two Bind on Equip items, a weapon skill learned clearing its mark.
- 0.7.2: the EllesmereUI look (Settings > Look > EllesmereUI, reload), GearPath's tooltip lines
  under EllesmereUI's tooltip skin, the arrows in its bags, its Character sheet with no
  doubled item levels, and the new icon on the minimap button and in the addon list.

## Later ideas

- Translate item tooltip lines and chat messages; native-speaker corrections of the drafts.
- Auction House upgrade scan (after launch).
- Opt-in `/gp export` plus a merge script, toward GearPath's own crowd-sourced database (after launch).
- 0.8.0 (after launch): Alts tab (snapshots of each character's gear, bags and bank; include
  or remove), gear for alts (any tradeable item on any character, scored for every alt in
  each spec), Questie's data built in as a fallback (only with the Questie team's OK).
- Leveling curves (weights that change with level), as Gear Judge has: needs a design pass.
