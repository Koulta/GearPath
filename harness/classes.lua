-- lua5.1 classes.lua <addon dir> <CLASS> [Alliance]
-- GearPath loaded as one class (level 23; Horde Undead, or Alliance Human),
-- checked for what that class can wear, dual wield, two-handers against a
-- pair, relics, the ranged slot, the stat order and faction rules.
local dir, CLASS, FACTION = arg[1], arg[2], arg[3] or "Horde"
local here = arg[0]:match("^(.*)/[^/]*$") or "."

local H = dofile(here .. "/wow.lua")
dofile(here .. "/data.lua")

local INFO = { WARRIOR = { "Warrior", 1 }, PALADIN = { "Paladin", 2 }, HUNTER = { "Hunter", 3 }, ROGUE = { "Rogue", 4 },
    PRIEST = { "Priest", 5 }, SHAMAN = { "Shaman", 7 }, MAGE = { "Mage", 8 }, WARLOCK = { "Warlock", 9 }, DRUID = { "Druid", 11 } }
assert(INFO[CLASS], "unknown class " .. tostring(CLASS))
function UnitClass() return INFO[CLASS][1], CLASS, INFO[CLASS][2] end
if FACTION == "Alliance" then
    function UnitRace() return "Human", "Human", 1 end
    function UnitFactionGroup() return "Alliance" end
end
if LibQuestieDB then
    LibQuestieDB.Enum.classKeys[CLASS] = 2 ^ (INFO[CLASS][2] - 1)
    LibQuestieDB.Enum.raceMaskById[1] = 1
end

-- Test gear: { name, quality, ilvl, req, equipLoc, classID, subClassID, stats }
local I = H.ITEMS
I[300] = { "Test Plate Helm", 2, 30, 22, "INVTYPE_HEAD", 4, 4, { ITEM_MOD_STRENGTH_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 6 } }
I[301] = { "Test Mail Hauberk", 2, 28, 22, "INVTYPE_CHEST", 4, 3, { ITEM_MOD_STRENGTH_SHORT = 6, ITEM_MOD_AGILITY_SHORT = 6 } }
I[302] = { "Test Leather Tunic", 2, 26, 20, "INVTYPE_CHEST", 4, 2, { ITEM_MOD_AGILITY_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 4 } }
I[304] = { "Test Greatsword", 2, 28, 22, "INVTYPE_2HWEAPON", 2, 8, { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 25 } }
I[305] = { "Test Longsword", 2, 26, 22, "INVTYPE_WEAPON", 2, 7, { ITEM_MOD_STRENGTH_SHORT = 4, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 16 } }
I[306] = { "Test Shiv", 2, 25, 20, "INVTYPE_WEAPONOFFHAND", 2, 15, { ITEM_MOD_AGILITY_SHORT = 3, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 } }
I[307] = { "Test Kite Shield", 2, 26, 20, "INVTYPE_SHIELD", 4, 6, { ITEM_MOD_STAMINA_SHORT = 5 } }
I[308] = { "Test Libram", 2, 25, 20, "INVTYPE_RELIC", 4, 7, { ITEM_MOD_STAMINA_SHORT = 3 } }
I[309] = { "Test Idol", 2, 25, 20, "INVTYPE_RELIC", 4, 8, { ITEM_MOD_STAMINA_SHORT = 3 } }
I[310] = { "Test Totem", 2, 25, 20, "INVTYPE_RELIC", 4, 9, { ITEM_MOD_STAMINA_SHORT = 3 } }
I[311] = { "Test Longbow", 2, 25, 20, "INVTYPE_RANGED", 2, 2, { ITEM_MOD_AGILITY_SHORT = 4, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14 } }
I[312] = { "Test Knuckles", 2, 25, 20, "INVTYPE_WEAPON", 2, 13, { ITEM_MOD_AGILITY_SHORT = 4, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 15 } }
I[313] = { "Test Polearm", 2, 27, 22, "INVTYPE_2HWEAPON", 2, 6, { ITEM_MOD_AGILITY_SHORT = 8, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 22 } }
I[315] = { "Test Throwing Axes", 2, 24, 20, "INVTYPE_THROWN", 2, 16, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } }
I[316] = { "Test Mace", 2, 25, 20, "INVTYPE_WEAPON", 2, 4, { ITEM_MOD_INTELLECT_SHORT = 4, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 } }
I[319] = { "Test Hatchet", 2, 25, 20, "INVTYPE_WEAPON", 2, 0, { ITEM_MOD_AGILITY_SHORT = 3, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14 } }
I[320] = { "Test Greataxe", 2, 27, 22, "INVTYPE_2HWEAPON", 2, 1, { ITEM_MOD_STRENGTH_SHORT = 9, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 23 } }
I[318] = { "Test Frill", 2, 25, 20, "INVTYPE_HOLDABLE", 4, 0, { ITEM_MOD_INTELLECT_SHORT = 5 } }

local checks, failed = 0, 0
local function check(cond, what)
    checks = checks + 1
    if not cond then failed = failed + 1 print("  FAIL [" .. CLASS .. "]: " .. what) end
end

local ns = {}
local toc = io.open(dir .. "/GearPath.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local chunk = assert(loadfile(dir .. "/" .. line:gsub("\\", "/")))
        local ok, err = pcall(chunk, "GearPath", ns)
        if not ok then print("  LOAD ERROR " .. line .. ": " .. tostring(err)) failed = failed + 1 end
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
H.Fire("PLAYER_LOGIN")
for _ = 1, 300 do H.Tick(0.1) if GP.Sources.status == "ready" then break end end
for _ = 1, 20 do H.Tick(0.1) end
check(GP.player.class == CLASS, "playing as " .. CLASS)

local C = GP.Classes
-- What each class can use at 23 (true) and what not (false).
local USE = {
    [300] = {},                                                   -- plate: nobody before 40
    [301] = { WARRIOR = 1, PALADIN = 1 },                         -- mail (hunters, shamans: 40)
    [302] = { ROGUE = 1, DRUID = 1, HUNTER = 1, SHAMAN = 1, WARRIOR = 1, PALADIN = 1 },
    [304] = { WARRIOR = 1, PALADIN = 1, HUNTER = 1 },             -- two-handed sword
    [305] = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, WARLOCK = 1, MAGE = 1 },
    [306] = { ROGUE = 1, WARRIOR = 1, HUNTER = 1 },               -- off-hand dagger
    [307] = { WARRIOR = 1, PALADIN = 1, SHAMAN = 1 },             -- shield
    [308] = { PALADIN = 1 }, [309] = { DRUID = 1 }, [310] = { SHAMAN = 1 },
    [311] = { HUNTER = 1, WARRIOR = 1, ROGUE = 1 },               -- bow
    [312] = { ROGUE = 1, DRUID = 1, HUNTER = 1, SHAMAN = 1, WARRIOR = 1 },
    [313] = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, DRUID = 1 },  -- polearm (druids: new in Forever)
    [211] = { MAGE = 1, PRIEST = 1, WARLOCK = 1 },                -- wand
    [315] = { ROGUE = 1, WARRIOR = 1 },                           -- thrown (not hunters)
    [319] = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, SHAMAN = 1, ROGUE = 1 },  -- one-handed axe (rogues: new in Forever)
    [320] = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, SHAMAN = 1 },  -- two-handed axe
    [316] = { PRIEST = 1, ROGUE = 1, DRUID = 1, SHAMAN = 1, WARRIOR = 1, PALADIN = 1 },
    [102] = { MAGE = 1, WARLOCK = 1, PRIEST = 1, DRUID = 1, HUNTER = 1, SHAMAN = 1, WARRIOR = 1 },  -- staff
    [318] = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1 },
}
for id, who in pairs(USE) do
    local it = I[id]
    local ok = C.CanUse(it[6], it[7], it[5], CLASS, 23)
    check((ok == true) == (who[CLASS] == 1), string.format("%s: %s", it[1], who[CLASS] and "can use" or "can't use"))
end
-- Specs: every class has its specs, each with weights the scorer uses.
do
    local specs = C.Specs(CLASS)
    check(#specs >= 2, "has a spec to choose (" .. #specs .. ")")
    for _, sp in ipairs(specs) do
        check(C.SetSpec(sp.key) or C.Spec().key == sp.key, "switches to " .. sp.name)
        local w = C.Weights()
        local n = 0
        for _, v in pairs(w) do if type(v) == "number" and v > 0 then n = n + 1 end end
        check(n >= 5, sp.name .. ": weights for at least 5 stats")
        if sp.role == "healer" then
            check((w.heal or 0) >= 1 and not GP.Score.HealerGear({ stats = { heal = 20, sp = 5 } }), sp.name .. ": healer gear is theirs")
        end
        if sp.role == "tank" then
            check((w.sta or 0) >= 1 and (w.armor or 0) > 0, sp.name .. ": stamina and armor count")
        end
    end
    C.SetSpec(specs[1].key)
end
-- Weapon speed and type for the specs that care.
local function points(sub, loc, speed, slot)
    return GP.Score.Points({ classID = 2, subClassID = sub, equipLoc = loc, stats = { dps = 20 }, speed = speed }, slot)
end
if CLASS == "ROGUE" then
    C.SetSpec("combat")
    check(points(7, "INVTYPE_WEAPON", 2.8, "MainHandSlot") > points(7, "INVTYPE_WEAPON", 1.8, "MainHandSlot"), "Combat: a slow main hand beats a fast one")
    check(points(7, "INVTYPE_WEAPON", 1.4, "SecondaryHandSlot") > points(7, "INVTYPE_WEAPON", 2.6, "SecondaryHandSlot"), "Combat: a fast off hand beats a slow one")
    C.SetSpec("subtlety")
    check(points(15, "INVTYPE_WEAPON", 1.8, "MainHandSlot") > points(7, "INVTYPE_WEAPON", 1.8, "MainHandSlot"), "Subtlety: a dagger beats a sword in the main hand")
    C.SetSpec("subtlety")
end
if CLASS == "SHAMAN" then
    check(points(5, "INVTYPE_2HWEAPON", 3.6, "MainHandSlot") > points(5, "INVTYPE_2HWEAPON", 2.6, "MainHandSlot"), "Enhancement: a slow two-hander beats a fast one")
end
if CLASS == "HUNTER" then
    check(points(2, "INVTYPE_RANGED", 3.0, "RangedSlot") > points(2, "INVTYPE_RANGED", 2.0, "RangedSlot"), "a slow bow beats a fast one")
end
if CLASS == "PRIEST" then
    check(points(15, "INVTYPE_WEAPON", 2.8, "MainHandSlot") == points(15, "INVTYPE_WEAPON", 1.6, "MainHandSlot"), "a caster doesn't care about weapon speed")
end
-- The relic slot is called that by the classes that use one.
check((GP.Slots.Label("RangedSlot") == "Relic") == (CLASS == "PALADIN" or CLASS == "DRUID" or CLASS == "SHAMAN"),
    "the ranged slot's name: " .. GP.Slots.Label("RangedSlot"))
-- Racials: Forever's are flat bonuses with any weapon (Oct 15 beta notes),
-- so no race changes what a weapon is worth.
if CLASS == "WARRIOR" then
    local race = GP.player.race
    local scores = {}
    for _, r in ipairs({ "Orc", "Human", "Dwarf", "Scourge" }) do
        GP.player.race = r
        scores[r] = points(0, "INVTYPE_WEAPON", 2.6, "MainHandSlot") + points(7, "INVTYPE_WEAPON", 2.6, "MainHandSlot")
            + points(4, "INVTYPE_WEAPON", 2.6, "MainHandSlot")
    end
    GP.player.race = race
    check(scores.Orc == scores.Scourge and scores.Human == scores.Scourge and scores.Dwarf == scores.Scourge,
        "no race scores an axe, sword or mace higher")
end
-- Polearms only from level 20.
check(C.CanUse(2, 6, "INVTYPE_2HWEAPON", CLASS, 19) ~= true, "no polearm before level 20")
-- Plate and mail open at 40 for the classes that grow into them.
local plateAt40 = { WARRIOR = true, PALADIN = true }
check((C.CanUse(4, 4, "INVTYPE_HEAD", CLASS, 40) == true) == (plateAt40[CLASS] == true), "plate at 40")
local mailAt40 = { WARRIOR = true, PALADIN = true, HUNTER = true, SHAMAN = true }
check((C.CanUse(4, 3, "INVTYPE_CHEST", CLASS, 40) == true) == (mailAt40[CLASS] == true), "mail at 40")
-- Dual wield: rogues at 10, warriors and hunters at 20.
local dwAt = { ROGUE = 10, WARRIOR = 20, HUNTER = 20 }
check(C.CanDualWield(CLASS, 23) == (dwAt[CLASS] ~= nil), "dual wield at 23")
check(C.CanDualWield(CLASS, 15) == (dwAt[CLASS] == 10), "dual wield at 15")

-- Every weight has a label in Settings, and the stats panel starts with the guide's top stat.
local w = C.Weights(CLASS)
for k in pairs(w) do check(C.STAT_LABELS[k] ~= nil, "a label for the " .. k .. " weight") end
local keys = GP.UI.Stats.Keys(w)
local TOP = { WARLOCK = "sp", MAGE = "hit", PRIEST = "sp", ROGUE = "hit", HUNTER = "agi", WARRIOR = "hit", PALADIN = "hit", SHAMAN = "hit", DRUID = "hit" }
check(keys[1] == TOP[CLASS], "the stats panel starts with " .. TOP[CLASS] .. " (got " .. tostring(keys[1]) .. ")")
for _, k in ipairs(keys) do check(k ~= "heal", "no Healing in the stats panel") end

-- Gear on: a two-hander against a one-hander and shield, an off hand, the ranged slot.
local EQ = H.EQUIPPED
for k in pairs(EQ) do EQ[k] = nil end
local function rec(id) return GP.Items.FromLink(H.Link(id)) end
local S = GP.Score
if CLASS == "WARRIOR" or CLASS == "PALADIN" then
    EQ[16], EQ[17] = 305, 307
    S.ReadEquipped()
    local slot, delta = S.Upgrade(rec(304))
    check(slot == "MainHandSlot" and delta > 0, "a strong two-hander beats a one-hander and shield (" .. tostring(slot) .. " " .. tostring(delta) .. ")")
    local base = S.equipped.MainHandSlot.points + S.equipped.SecondaryHandSlot.points
    check(math.abs(delta - (S.Points(rec(304), "MainHandSlot") - base)) < 0.01, "measured against both hands")
end
if CLASS == "ROGUE" or CLASS == "WARRIOR" or CLASS == "HUNTER" then
    EQ[16], EQ[17] = 312, nil
    S.ReadEquipped()
    local slot, delta, pct = S.Upgrade(rec(306))
    check(slot == "SecondaryHandSlot" and delta > 0 and pct == nil, "an off-hand dagger fills the empty off hand")
    check(math.abs(S.Points(rec(306), "SecondaryHandSlot") - (3 * (w.agi or 0) + 12 * (w.dpsOff or 0))) < 0.01, "off-hand damage counts at the off-hand weight")
end
if CLASS == "PALADIN" or CLASS == "DRUID" or CLASS == "SHAMAN" then
    local relic = ({ PALADIN = 308, DRUID = 309, SHAMAN = 310 })[CLASS]
    S.ReadEquipped()
    local slot = S.Upgrade(rec(relic))
    check(slot == "RangedSlot", "a relic goes in the ranged slot")
end
if CLASS == "HUNTER" then
    S.ReadEquipped()
    local slot, delta = S.Upgrade(rec(311))
    check(slot == "RangedSlot" and delta >= 14 * 4, "a bow counts its damage at the ranged weight")
end
if CLASS == "WARLOCK" or CLASS == "MAGE" or CLASS == "PRIEST" then
    S.ReadEquipped()
    check(S.Upgrade(rec(211)) == "RangedSlot", "a wand goes in the ranged slot")
end
EQ[16], EQ[17] = nil, nil

-- From the database: what the class can use and get.
local res = S.Run()
local byID = res.byID
check(GP.Sources.status == "ready", "the gear list was built")
local wantsMail = { WARRIOR = true, PALADIN = true }
check((byID[205] ~= nil) == (wantsMail[CLASS] == true), "the mail chest from the database is listed only for mail wearers at 23")
local wand = { MAGE = true, PRIEST = true, WARLOCK = true }
check((byID[211] ~= nil) == (wand[CLASS] == true), "the wand from the database is listed only for wand users")

-- Faction: an Alliance character doesn't get the Horde-only vendor.
local dagger = GP.Sources.entries[202]
local hasVendor = false
for _, src in ipairs(dagger and dagger.sources or {}) do if src.kind == "vendor" then hasVendor = true end end
if FACTION == "Alliance" then
    check(not hasVendor, "Alliance: the Horde-only vendor isn't a source")
    check(GP.Sources.entries[200] ~= nil, "Alliance: a quest from a giver both factions can use is")
    check(GP.UI.Doll.ArtPath("Human") ~= nil, "Alliance: the Human dressing room art")
elseif byID[202] then
    check(hasVendor, "Horde: the Horde vendor is a source")
end

print(string.format("  %s %s: %d checks, %d failed, %d errors", CLASS, FACTION, checks, failed, #H.errors))
for _, e in ipairs(H.errors) do print("  error: " .. tostring(e):match("^[^\n]*")) end
os.exit((failed == 0 and #H.errors == 0) and 0 or 1)
