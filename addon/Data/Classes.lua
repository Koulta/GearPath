-- Classes: what each class can use and how much it values each stat.
--
-- The weights are leveling weights: points per 1 of a stat (per 1% for
-- hit, crit and haste, which WoW: Forever puts on gear as percentages, and
-- per 1 damage per second for weapons). Each one can be changed with
-- /gp weight <stat> <value>.
--
-- Where they come from (checked October 2026, Forever beta): the order of
-- the stats is each class's usual leveling spec's priority in the Forever
-- guides (wow.gg's spec guides: Affliction, Fire, Shadow, Subtlety,
-- Marksmanship, Fury, Retribution, Enhancement, Feral; Warcraft Tavern's
-- class guides for Forever's stat changes). The guides give an order, not
-- numbers, so the gaps come from Forever's own conversions (Warcraft
-- Tavern's stats guide): 2 attack power per Strength for warriors,
-- paladins, shamans and druids; crit from Agility at 1% per 20 (29 for
-- rogues, 53 for hunters); and a percent of hit or crit costing about what
-- 14 points of a main stat do on an item. Forever's own changes: crit and
-- hit count for every attack and spell, DoTs can crit, Life Tap scales
-- with Spirit, and Haste is new (scored a little, as it's rare on gear).
--
-- Weapon damage per second is priced from attack power: in Forever, as in
-- Classic, every 14 attack power adds 1 damage per second to the weapon,
-- so 1 weapon DPS is worth 14 times the attack power weight (7 at the 0.5
-- most specs give attack power), half that in the off hand (it hits for
-- half), and the same for ranged attack power and a bow or gun. Druid forms
-- scale with the weapon in Forever too. (Agility follows the guides' order,
-- not the 1% per 20 above: Forever hasn't published its own ratios.)

local _, GP = ...

local Classes = {}
GP.Classes = Classes

-- Item class and subclass ids (the client's Enum.ItemClass / subclass enums).
Classes.WEAPON, Classes.ARMOR = 2, 4
local W = {
    AXE1H = 0, AXE2H = 1, BOW = 2, GUN = 3, MACE1H = 4, MACE2H = 5, POLEARM = 6,
    SWORD1H = 7, SWORD2H = 8, STAFF = 10, FIST = 13, MISC = 14, DAGGER = 15,
    THROWN = 16, CROSSBOW = 18, WAND = 19, FISHING = 20,
}
local A = { MISC = 0, CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4, SHIELD = 6, LIBRAM = 7, IDOL = 8, TOTEM = 9 }
Classes.W, Classes.A = W, A

-- The stats we score, and how they read on screen.
Classes.STAT_LABELS = {
    str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit",
    armor = "Armor", sp = "Spell Power", spShadow = "Shadow Damage", spFire = "Fire Damage",
    spFrost = "Frost Damage", spArcane = "Arcane Damage", spNature = "Nature Damage", spHoly = "Holy Damage",
    heal = "Healing", hit = "Hit %", crit = "Crit %", ap = "Attack Power", rap = "Ranged Attack Power",
    mp5 = "Mana per 5 sec", expertise = "Expertise", defense = "Defense", block = "Block Value",
    dodge = "Dodge %", parry = "Parry %", haste = "Haste %",
    dpsMelee = "Weapon DPS", dpsOff = "Off-hand DPS", dpsRanged = "Ranged DPS", dpsWand = "Wand DPS",
}

-- ---------------------------------------------------------------------
-- What each class can wear and wield. Weapons are the ones it can learn
-- (a trainer teaches the rest); armor beyond its own is allowed but scored
-- down (ARMOR_PREF). `at` = the level a kind opens up (mail/plate at 40).
-- ---------------------------------------------------------------------

Classes.DATA = {
    -- Affliction: Spell Power > Hit > Intellect > Spirit > Crit > Stamina > Haste.
    WARLOCK = {
        armor = { [A.CLOTH] = 1 },
        weapons = { [W.DAGGER] = true, [W.SWORD1H] = true, [W.STAFF] = true, [W.WAND] = true },
        dualWield = false,
        weights = { sp = 1.0, spShadow = 0.95, spFire = 0.3, hit = 11, int = 0.6, spi = 0.55, crit = 7.5,
            sta = 0.45, haste = 5, mp5 = 1.2, armor = 0.008, dpsWand = 2.2 },
    },
    -- Fire/Frost: Hit > Spell Power > Spirit > Intellect > Crit > Stamina.
    MAGE = {
        armor = { [A.CLOTH] = 1 },
        weapons = { [W.DAGGER] = true, [W.SWORD1H] = true, [W.STAFF] = true, [W.WAND] = true },
        dualWield = false,
        weights = { sp = 1.0, spFire = 0.9, spFrost = 0.9, spArcane = 0.5, hit = 13, spi = 0.55, int = 0.5,
            crit = 6.5, sta = 0.35, haste = 5.5, mp5 = 0.48, armor = 0.008, dpsWand = 1.8 },
    },
    -- Shadow: Spell Power > Crit > Hit > Intellect > Stamina (Spirit for Spirit Tap).
    PRIEST = {
        armor = { [A.CLOTH] = 1 },
        weapons = { [W.DAGGER] = true, [W.MACE1H] = true, [W.STAFF] = true, [W.WAND] = true },
        dualWield = false,
        weights = { sp = 1.0, spShadow = 0.95, spHoly = 0.2, heal = 0.1, crit = 9, hit = 8.5, int = 0.5,
            sta = 0.4, spi = 0.4, haste = 5, mp5 = 1.5, armor = 0.008, dpsWand = 2.0 },
    },
    -- Weapon > Hit > Agility > Crit > Strength > Stamina.
    ROGUE = {
        armor = { [A.LEATHER] = 1, [A.CLOTH] = 0.6 },
        -- (One-handed axes: new in Forever.)
        weapons = { [W.DAGGER] = true, [W.SWORD1H] = true, [W.MACE1H] = true, [W.FIST] = true, [W.AXE1H] = true,
            [W.BOW] = true, [W.CROSSBOW] = true, [W.GUN] = true, [W.THROWN] = true },
        dualWield = 10,       -- the level it's learned at
        weights = { agi = 1.0, hit = 15, crit = 11, str = 0.5, ap = 0.5, sta = 0.35, expertise = 6, haste = 8,
            armor = 0.01, dpsMelee = 7.0, dpsOff = 3.5, dpsRanged = 0.4 },
    },
    -- Feral: Weapon > Hit/Expertise > Crit > Strength > Agility > Stamina > Spirit > Intellect > Spell Power.
    DRUID = {
        armor = { [A.LEATHER] = 1, [A.CLOTH] = 0.65 },
        -- (Polearms: new in Forever.)
        weapons = { [W.DAGGER] = true, [W.FIST] = true, [W.MACE1H] = true, [W.MACE2H] = true, [W.STAFF] = true,
            [W.POLEARM] = true },
        dualWield = false,
        relic = A.IDOL,
        weights = { str = 1.0, agi = 0.85, hit = 15, expertise = 8, crit = 14.5, ap = 0.5, sta = 0.45, spi = 0.3,
            int = 0.25, sp = 0.2, haste = 10, mp5 = 0.5, armor = 0.03, dpsMelee = 7.0 },
    },
    -- Marksmanship: Weapon > Agility > Spirit > Intellect > Stamina > Hit > Crit
    -- (Spirit and Intellect: mana runs short early, and Careful Aim turns Intellect into attack power).
    HUNTER = {
        armor = { [A.LEATHER] = 1, [A.MAIL] = { 1.1, at = 40 }, [A.CLOTH] = 0.6 },
        -- (No thrown weapons: those are warriors' and rogues'.)
        weapons = { [W.AXE1H] = true, [W.AXE2H] = true, [W.BOW] = true, [W.CROSSBOW] = true, [W.GUN] = true,
            [W.DAGGER] = true, [W.FIST] = true, [W.POLEARM] = true, [W.STAFF] = true, [W.SWORD1H] = true,
            [W.SWORD2H] = true },
        dualWield = 20,       -- the level it's learned at
        weights = { agi = 1.0, spi = 0.5, int = 0.45, sta = 0.4, hit = 5.2, crit = 4.8, ap = 0.45, rap = 0.5,
            haste = 6, mp5 = 0.8, armor = 0.01, dpsRanged = 7.0, dpsMelee = 0.4, dpsOff = 0.2 },
    },
    -- Enhancement: Weapon > Hit/Expertise > Crit > Strength > Intellect > Agility > Spell Power > Spirit > Stamina
    -- (Intellect: Mental Dexterity turns it into attack power).
    SHAMAN = {
        armor = { [A.LEATHER] = 1, [A.MAIL] = { 1.1, at = 40 }, [A.CLOTH] = 0.6, [A.SHIELD] = 1 },
        weapons = { [W.AXE1H] = true, [W.AXE2H] = true, [W.DAGGER] = true, [W.FIST] = true,
            [W.MACE1H] = true, [W.MACE2H] = true, [W.STAFF] = true },
        dualWield = false,
        relic = A.TOTEM,
        weights = { str = 1.0, hit = 15, expertise = 8, crit = 14.5, int = 0.55, agi = 0.5, sp = 0.45, spi = 0.32,
            sta = 0.3, ap = 0.5, haste = 10, mp5 = 1.0, armor = 0.015, block = 0.1, dpsMelee = 7.0 },
    },
    -- Fury/Arms: Weapon > Hit > Crit > Strength > Agility > Stamina.
    WARRIOR = {
        armor = { [A.MAIL] = 1, [A.PLATE] = { 1.1, at = 40 }, [A.LEATHER] = 0.8, [A.CLOTH] = 0.5, [A.SHIELD] = 1 },
        weapons = { [W.AXE1H] = true, [W.AXE2H] = true, [W.BOW] = true, [W.CROSSBOW] = true, [W.GUN] = true,
            [W.DAGGER] = true, [W.FIST] = true, [W.MACE1H] = true, [W.MACE2H] = true, [W.POLEARM] = true,
            [W.STAFF] = true, [W.SWORD1H] = true, [W.SWORD2H] = true, [W.THROWN] = true },
        dualWield = 20,       -- the level it's learned at
        weights = { str = 1.0, hit = 16, crit = 15, agi = 0.75, sta = 0.5, ap = 0.5, expertise = 6, haste = 11,
            armor = 0.02, defense = 0.3, block = 0.1, dpsMelee = 7.0, dpsOff = 3.5, dpsRanged = 0.3 },
    },
    -- Retribution: Weapon > Hit/Expertise > Crit > Strength > Spell Power > Intellect > Agility.
    PALADIN = {
        armor = { [A.MAIL] = 1, [A.PLATE] = { 1.1, at = 40 }, [A.LEATHER] = 0.8, [A.CLOTH] = 0.5, [A.SHIELD] = 1 },
        weapons = { [W.AXE1H] = true, [W.AXE2H] = true, [W.MACE1H] = true, [W.MACE2H] = true,
            [W.POLEARM] = true, [W.SWORD1H] = true, [W.SWORD2H] = true },
        dualWield = false,
        relic = A.LIBRAM,
        weights = { str = 1.0, hit = 15, expertise = 8, crit = 14.5, sp = 0.6, int = 0.45, agi = 0.4, sta = 0.5,
            ap = 0.5, haste = 10, mp5 = 0.8, armor = 0.015, block = 0.1, dpsMelee = 7.0 },
    },
}

Classes.POLEARM_AT = 20

-- Racials aren't scored: since the October 15 beta notes Forever's old
-- weapon specializations are flat bonuses with any weapon (Human Ruthless
-- +2% crit, Orc Savage +1% crit, Dwarf Earth Fury +2% crit damage), the
-- same whatever you hold, so they never change which item is better.

-- Hit beyond the cap does nothing. Against mobs of your own level (what you
-- fight while leveling) the beta's numbers are 5% for attacks and 4% for
-- spells. Not official yet: check them again after the November 4 launch.
-- Only hit from gear is counted (talents and auras aren't known here).
Classes.HIT_CAP = { melee = 5, spell = 4 }

-- The cap for the spec in use: spells for casters (spell power their main
-- stat), attacks for everyone else. nil: hit isn't scored (healers).
function Classes.HitCap(weights)
    weights = weights or Classes.Weights()
    if (weights.hit or 0) <= 0 then return nil end
    local caster = (weights.sp or 0) >= 1
    return caster and Classes.HIT_CAP.spell or Classes.HIT_CAP.melee
end

-- Gear every class can use, whatever its armor: cloaks are "cloth" but worn
-- by all, and jewelry, trinkets and held-in-off-hand items are "misc".
local ANY_CLASS_LOC = {
    INVTYPE_CLOAK = true, INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
}

function Classes.Data(class)
    return Classes.DATA[class or (GP.player and GP.player.class)] or Classes.DATA.WARRIOR
end

-- ---------------------------------------------------------------------
-- Specs. Each class's usual specs; the first is its leveling spec (the
-- weights above). A spec has its own weights (same scale: main stat 1,
-- hit and crit per 1%, healing and spell power per point), and can prefer
-- a weapon speed (speed: { slot kind = { base, per second } }: points times
-- 1 + per second x (speed - base)) or a weapon type in the main hand
-- (mainType: { [subclass] = factor }). Healing specs count Healing, so
-- healer gear is theirs. Your own weight changes are kept per spec.
-- ---------------------------------------------------------------------

-- October 29, 2026 numbers pass: every spec checked against Sharpie's Gear Judge
-- 3.2.7 (Forever; MIT, (c) 2025 Supersharpie; wowsims-based), its level-60 profile
-- and its level-30 leveling curve. Hit, crit and main stats agreed within 2x. Where
-- both disagreed with GearPath by more than 2x, the leveling value was taken (or,
-- where Gear Judge's own two numbers disagree, the one nearer ours), unless it
-- would break a guide order above (Affliction and Feral Spirit stay).
Classes.SPECS = {
    WARRIOR = {
        { key = "fury", name = "Fury", speed = { main = { 2.6, 0.08 } } },
        { key = "arms", name = "Arms", speed = { main = { 3.3, 0.12 } },
            weights = { str = 1.0, hit = 16, crit = 15, agi = 0.75, sta = 0.5, ap = 0.5, expertise = 6, haste = 9,
                armor = 0.02, defense = 0.3, block = 0.1, dpsMelee = 7.0, dpsOff = 0.5, dpsRanged = 0.3 } },
        { key = "protection", name = "Protection", role = "tank",
            weights = { sta = 1.0, defense = 1.2, armor = 0.05, str = 0.6, agi = 0.6, dodge = 12, parry = 12, block = 0.35,
                hit = 8, crit = 4, expertise = 6, haste = 4, ap = 0.3, dpsMelee = 4.2, dpsOff = 0, dpsRanged = 0.2 } },
    },
    PALADIN = {
        { key = "retribution", name = "Retribution", speed = { main = { 3.3, 0.15 } } },
        { key = "holy", name = "Holy", role = "healer",
            weights = { heal = 1.0, int = 0.8, mp5 = 2.0, crit = 9, spi = 0.74, sta = 0.35, sp = 0.25, spHoly = 0.3,
                haste = 6, armor = 0.005, dpsMelee = 0.1 } },
        { key = "protection", name = "Protection", role = "tank",
            weights = { sta = 1.0, defense = 1.2, sp = 0.7, spHoly = 0.7, armor = 0.04, block = 0.45, int = 0.45,
                dodge = 10, parry = 10, hit = 7, str = 0.4, agi = 0.4, crit = 3, mp5 = 0.8, dpsMelee = 0.6 } },
    },
    HUNTER = {
        { key = "marksmanship", name = "Marksmanship", speed = { ranged = { 2.8, 0.08 } } },
        { key = "beastmastery", name = "Beast Mastery", speed = { ranged = { 2.8, 0.06 } },
            weights = { agi = 1.0, sta = 0.55, int = 0.4, spi = 0.4, hit = 5.5, crit = 4.2, ap = 0.45, rap = 0.5,
                haste = 6, mp5 = 0.8, armor = 0.012, dpsRanged = 7.0, dpsMelee = 0.4, dpsOff = 0.2 } },
        -- Survival is melee in Forever (a reworked tree: Warcraft Tavern, wowtbc.gg, wow.gg).
        -- Agility first, then Hit (wow.gg); a two-hander or two one-handers, whichever
        -- items are better; the ranged weapon is a stat stick (no ranged-weapon talents).
        -- Gaps: Sharpie's Gear Judge "Survival: Solo Leveling (melee)" at level 30, scaled to
        -- Agility = 1; Spirit and Mp5, which it puts above Agility, keep Marksmanship's values;
        -- no source weighs Haste. Weapon DPS = 14 x attack power, off hand half.
        { key = "survival", name = "Survival",
            weights = { agi = 1.0, hit = 3.3, crit = 3.2, ap = 0.5, str = 0.5, sta = 0.37, int = 0.25, spi = 0.5,
                mp5 = 0.8, dodge = 1.9, rap = 0.08, armor = 0.02, dpsMelee = 7.0, dpsOff = 3.5, dpsRanged = 1.12 } },
    },
    ROGUE = {
        { key = "subtlety", name = "Subtlety", mainType = { [W.DAGGER] = 1.15 } },
        { key = "combat", name = "Combat", speed = { main = { 2.6, 0.15 }, off = { 1.6, -0.08 } },
            mainType = { [W.SWORD1H] = 1.08, [W.MACE1H] = 1.08, [W.FIST] = 1.04, [W.AXE1H] = 1.04 },
            weights = { agi = 1.0, hit = 16, crit = 10, str = 0.5, ap = 0.5, sta = 0.35, expertise = 7, haste = 9,
                armor = 0.01, dpsMelee = 7.0, dpsOff = 4.4, dpsRanged = 0.4 } },
        { key = "assassination", name = "Assassination", mainType = { [W.DAGGER] = 1.2 },
            weights = { agi = 1.0, hit = 15, crit = 12, str = 0.5, ap = 0.5, sta = 0.35, expertise = 6, haste = 8,
                armor = 0.01, dpsMelee = 7.0, dpsOff = 3.5, dpsRanged = 0.4 } },
    },
    PRIEST = {
        { key = "shadow", name = "Shadow" },
        { key = "holy", name = "Holy/Discipline", role = "healer",
            weights = { heal = 1.0, int = 0.7, spi = 0.55, mp5 = 2.0, crit = 7, sta = 0.35, sp = 0.2, spHoly = 0.2,
                haste = 6, armor = 0.005, dpsWand = 0.6 } },
    },
    SHAMAN = {
        { key = "enhancement", name = "Enhancement", speed = { main = { 3.4, 0.2 } } },
        { key = "elemental", name = "Elemental",
            weights = { sp = 1.0, spNature = 0.9, spFire = 0.6, spFrost = 0.3, crit = 11, hit = 12, int = 0.6, mp5 = 1.5,
                spi = 0.3, sta = 0.4, haste = 6, armor = 0.008, dpsMelee = 0.2 } },
        { key = "restoration", name = "Restoration", role = "healer",
            weights = { heal = 1.0, mp5 = 2.2, int = 0.75, crit = 7, spi = 0.81, sta = 0.35, sp = 0.2, haste = 6,
                armor = 0.005, block = 0.05, dpsMelee = 0.1 } },
    },
    MAGE = {
        { key = "firefrost", name = "Fire/Frost" },
        { key = "arcane", name = "Arcane",
            weights = { sp = 1.0, spArcane = 0.95, spFire = 0.4, spFrost = 0.4, hit = 13, int = 0.7, spi = 0.6, crit = 6,
                mp5 = 0.51, sta = 0.35, haste = 6, armor = 0.008, dpsWand = 1.8 } },
    },
    WARLOCK = {
        { key = "affliction", name = "Affliction" },
        { key = "destruction", name = "Destruction",
            weights = { sp = 1.0, spShadow = 0.8, spFire = 0.6, crit = 10, hit = 11, int = 0.55, spi = 0.3, sta = 0.21,
                haste = 5, mp5 = 1.0, armor = 0.008, dpsWand = 2.0 } },
        { key = "demonology", name = "Demonology",
            weights = { sp = 1.0, spShadow = 0.85, spFire = 0.4, sta = 0.14, int = 0.6, spi = 0.2, hit = 10, crit = 6,
                haste = 4, mp5 = 0.33, armor = 0.01, dpsWand = 2.0 } },
    },
    DRUID = {
        { key = "feral", name = "Feral" },
        { key = "bear", name = "Feral (bear tank)", role = "tank",
            weights = { sta = 1.0, agi = 0.8, armor = 0.06, defense = 1.0, dodge = 5.0, str = 0.6, hit = 8, crit = 6,
                expertise = 6, ap = 0.3, haste = 4, dpsMelee = 4.2 } },
        { key = "balance", name = "Balance",
            weights = { sp = 1.0, spArcane = 0.8, spNature = 0.8, crit = 10, hit = 12, int = 0.6, spi = 0.45, mp5 = 1.4,
                sta = 0.19, haste = 6, armor = 0.005 } },
        { key = "restoration", name = "Restoration", role = "healer",
            weights = { heal = 1.0, spi = 0.6, int = 0.7, mp5 = 0.61, crit = 6, sta = 0.35, sp = 0.15, haste = 6,
                armor = 0.005 } },
    },
}

-- Your class's specs, and the one in use (your choice, or its first).
function Classes.Specs(class)
    return Classes.SPECS[class or (GP.player and GP.player.class)] or {}
end

function Classes.Spec(class)
    local specs = Classes.Specs(class)
    local mine = not class or class == (GP.player and GP.player.class)
    local key = mine and GP.char and GP.char.spec
    for _, s in ipairs(specs) do
        if s.key == key then return s end
    end
    return specs[1] or {}
end

-- Switches spec. Your own weight changes stay with the spec they were made for.
function Classes.SetSpec(key)
    local old = Classes.Spec()
    local new
    for _, s in ipairs(Classes.Specs()) do if s.key == key then new = s end end
    if not new or new == old then return false end
    GP.char.specWeights = GP.char.specWeights or {}
    if old.key then GP.char.specWeights[old.key] = GP.char.weights end
    GP.char.weights = GP.char.specWeights[new.key]
    GP.char.specWeights[new.key] = nil
    GP.char.spec = new.key
    GP.Fire("WeightsChanged")
    GP.Fire("SpecChanged", new.key)
    return true
end

-- The base weights of the spec in use (before your own changes).
function Classes.BaseWeights(class)
    return Classes.Spec(class).weights or Classes.Data(class).weights
end

-- Every weight key a class's specs use, the leveling spec's biggest first.
function Classes.WeightKeys(class)
    local first = Classes.Data(class).weights
    local keys, seen = {}, {}
    local function add(k)
        if not seen[k] then seen[k] = true; keys[#keys + 1] = k end
    end
    local sorted = {}
    for k in pairs(first) do sorted[#sorted + 1] = k end
    table.sort(sorted, function(a, b)
        if first[a] ~= first[b] then return first[a] > first[b] end
        return a < b
    end)
    for _, k in ipairs(sorted) do add(k) end
    local rest = {}
    for _, s in ipairs(Classes.Specs(class)) do
        for k in pairs(s.weights or {}) do if not seen[k] then rest[#rest + 1] = k; seen[k] = true end end
    end
    table.sort(rest)
    for _, k in ipairs(rest) do keys[#keys + 1] = k end
    return keys
end

-- How much a weapon's speed and type change its points for the spec in
-- use, in a slot: a factor for its damage (speed) and one for the whole
-- weapon (type); 1 = no change.
function Classes.WeaponFactor(rec, slotKey)
    if not rec or rec.classID ~= Classes.WEAPON then return 1, 1 end
    local spec = Classes.Spec()
    local f, t = 1, 1
    local kind
    if slotKey == "RangedSlot" then kind = "ranged"
    elseif slotKey == "SecondaryHandSlot" then kind = "off"
    else kind = "main" end
    local pref = spec.speed and spec.speed[kind]
    if pref and type(rec.speed) == "number" and rec.speed > 0 then
        f = f * GP.Clamp(1 + pref[2] * (rec.speed - pref[1]), 0.7, 1.3)
    end
    if kind == "main" and spec.mainType and spec.mainType[rec.subClassID] then
        t = spec.mainType[rec.subClassID]
    end
    return f, t
end

-- The weights in use: the spec's, with any the player set over them.
function Classes.Weights(class)
    local base = Classes.BaseWeights(class)
    local own = GP.char and GP.char.weights
    if type(own) ~= "table" or next(own) == nil then return base end
    local merged = {}
    for k, v in pairs(base) do merged[k] = v end
    for k, v in pairs(own) do merged[k] = v end
    return merged
end

-- Whether this class can (or will, by `level`) use the item, and how much
-- its armor type is worth to it (1 = its own armor). Returns usable,
-- armorFactor, opensAt (a level, when it isn't usable yet).
function Classes.CanUse(classID, subClassID, equipLoc, class, level)
    local data = Classes.Data(class)
    level = level or (GP.player and GP.player.level) or 1
    if ANY_CLASS_LOC[equipLoc] then return true, 1 end
    if classID == Classes.ARMOR then
        if subClassID == A.MISC then
            return equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" or
                equipLoc == "INVTYPE_HEAD" or equipLoc == "INVTYPE_WRIST" or equipLoc == "INVTYPE_WAIST" or
                equipLoc == "INVTYPE_FEET" or equipLoc == "INVTYPE_HAND", 1
        end
        if subClassID == A.LIBRAM or subClassID == A.IDOL or subClassID == A.TOTEM then
            return data.relic == subClassID, 1
        end
        local pref = data.armor[subClassID]
        if not pref then return false, 0 end
        if type(pref) == "table" then
            if level < (pref.at or 0) then return false, pref[1], pref.at end
            return true, pref[1]
        end
        return true, pref
    end
    if classID == Classes.WEAPON then
        if subClassID == W.FISHING or subClassID == W.MISC then return false, 0 end
        -- Polearms can only be learned from level 20.
        if subClassID == W.POLEARM and data.weapons[W.POLEARM] and level < Classes.POLEARM_AT then
            return false, 1, Classes.POLEARM_AT
        end
        if equipLoc == "INVTYPE_WEAPONOFFHAND" and type(data.dualWield) ~= "number" then return false, 0 end
        return data.weapons[subClassID] == true, 1
    end
    return false, 0
end

-- Dual wield: rogues learn it at 10, warriors and hunters at 20.
function Classes.CanDualWield(class, level)
    local at = Classes.Data(class).dualWield
    if type(at) ~= "number" then return false end
    return (level or (GP.player and GP.player.level) or 1) >= at
end

-- ---------------------------------------------------------------------
-- Sharing weights: a short string to copy and paste, "GP1:WARLOCK:crit=7.5,
-- hit=11,sp=1". Pasted strings are only read, field by field (never run):
-- known stats, numbers from 0 to WEIGHT_MAX, your own class.
-- ---------------------------------------------------------------------

Classes.WEIGHTS_VERSION = 1
Classes.WEIGHT_MAX = 100

local function shortNumber(v)
    local s = string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")
    return s
end

function Classes.ClassName(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    local n = type(names) == "table" and names[class]
    if type(n) == "string" then return n end
    return tostring(class or "?"):lower():gsub("^%l", string.upper)
end

-- The weights you use now (the class's with yours over them), as a string.
function Classes.ExportWeights()
    local class = GP.player and GP.player.class
    local w = Classes.Weights(class)
    local keys = {}
    for k, v in pairs(w) do
        if Classes.STAT_LABELS[k] and type(v) == "number" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. shortNumber(w[k]) end
    return string.format("GP%d:%s:%s", Classes.WEIGHTS_VERSION, tostring(class), table.concat(parts, ","))
end

-- A pasted string: weights and their class, or nil and why not.
function Classes.ParseWeights(text)
    if type(text) ~= "string" then return nil, "Paste a GearPath weights string." end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil, "Paste a GearPath weights string first." end
    if #text > 600 then return nil, "That's too long to be a GearPath weights string." end
    local version, class, body = text:match("^GP(%d+):(%u+):([%w%.=,]*)$")
    if not version then return nil, "That isn't a GearPath weights string (they start with GP1:)." end
    if tonumber(version) ~= Classes.WEIGHTS_VERSION then
        return nil, "That string is from a newer GearPath: update GearPath to read it."
    end
    if not Classes.DATA[class] then return nil, "That string names a class GearPath doesn't know." end
    local out, n = {}, 0
    for pair in body:gmatch("[^,]+") do
        local k, v = pair:match("^(%w+)=(%d*%.?%d+)$")
        v = tonumber(v)
        if not (k and Classes.STAT_LABELS[k] and v and v >= 0 and v <= Classes.WEIGHT_MAX) then
            return nil, "Something in that string isn't a stat weight: " .. pair:sub(1, 24)
        end
        if out[k] == nil then n = n + 1 end
        out[k] = v
    end
    if n == 0 then return nil, "There are no weights in that string." end
    return out, class, n
end

-- Uses a pasted string in place of your weights. Returns ok, message.
function Classes.ImportWeights(text)
    local w, class, n = Classes.ParseWeights(text)
    if not w then return false, class end
    local mine = GP.player and GP.player.class
    if class ~= mine then
        return false, string.format("Those weights are for a %s, and you're a %s.", Classes.ClassName(class), Classes.ClassName(mine))
    end
    -- Stored as differences from the spec's own; stats the string leaves out keep their defaults.
    local base = Classes.BaseWeights(class)
    local own = {}
    for k, v in pairs(w) do
        if v ~= base[k] then own[k] = v end
    end
    GP.char.weights = next(own) and own or nil
    GP.Fire("WeightsChanged")
    return true, string.format("Using the pasted stat weights (%d stats). Settings > Reset stat weights goes back to the defaults.", n)
end

-- The copy box with your weights, or the paste box for someone else's.
function Classes.ShowExport()
    if not (GP.UI and GP.UI.TextBox) then return false end
    GP.UI.TextBox({ title = GP.L["Your stat weights"],
        note = string.format(GP.L["Press Ctrl+C to copy, then give it to another %s: Settings > Paste weights, or /gp weights followed by the string."],
            Classes.ClassName(GP.player and GP.player.class)),
        text = Classes.ExportWeights() })
    return true
end

function Classes.ShowImport(onDone)
    if not (GP.UI and GP.UI.TextBox) then return false end
    GP.UI.TextBox({ title = GP.L["Paste stat weights"],
        note = GP.L["Paste weights another GearPath user copied (Ctrl+V). They replace yours; Reset stat weights brings the defaults back."],
        action = { label = GP.L["Use these"], fn = function(text)
            local ok, msg = Classes.ImportWeights(text)
            if ok then
                GP.Print(msg)
                if onDone then onDone() end
            end
            return ok, msg
        end } })
    return true
end

-- /gp weights: the copy box; /gp weights <string>: use someone's.
GP.RegisterCommand("weights", "copy your stat weights to share; /gp weights <string> uses someone else's", function(rest)
    rest = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if rest == "" then
        if not Classes.ShowExport() then GP.Print(Classes.ExportWeights()) end
        return
    end
    local _, msg = Classes.ImportWeights(rest)
    GP.Print(msg)
end)

-- /gp spec: your class's specs; /gp spec <name>: switch.
GP.RegisterCommand("spec", "list your class's specs, or switch: /gp spec holy", function(rest)
    rest = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local specs = Classes.Specs()
    if rest == "" then
        local names = {}
        for _, s in ipairs(specs) do
            names[#names + 1] = (s == Classes.Spec() and ("[" .. s.name .. "]") or s.name)
        end
        GP.Print("Specs: %s. Switch with /gp spec <name>.", table.concat(names, ", "))
        return
    end
    for _, s in ipairs(specs) do
        if s.key == rest or s.name:lower() == rest or s.name:lower():find(rest, 1, true) == 1 then
            if Classes.SetSpec(s.key) then GP.Print("Spec: %s.", s.name) else GP.Print("Already %s.", s.name) end
            return
        end
    end
    GP.Print("No spec called '%s'. Type /gp spec to see the list.", rest)
end)

-- /gp weight <stat> <value>: your own weight for a stat (no value: back to default).
GP.RegisterCommand("weight", "set a stat weight (/gp weight sta 0.6; /gp weight reset)", function(rest)
    local stat, value = (rest or ""):match("^(%S+)%s*(%S*)$")
    if not stat then
        local w = Classes.Weights()
        local keys = {}
        for k in pairs(w) do keys[#keys + 1] = k end
        table.sort(keys)
        GP.Print("Stat weights for your class:")
        for _, k in ipairs(keys) do GP.Print("  %s (%s) = %s", k, Classes.STAT_LABELS[k] or k, tostring(w[k])) end
        return
    end
    if stat == "reset" then
        GP.char.weights = nil
        GP.Print("Stat weights are back to the class defaults.")
        GP.Fire("WeightsChanged")
        return
    end
    if not Classes.STAT_LABELS[stat] and stat ~= "dpsOff" then
        GP.Print("Unknown stat '%s'. Type /gp weight to see the list.", stat)
        return
    end
    GP.char.weights = GP.char.weights or {}
    GP.char.weights[stat] = tonumber(value)
    GP.Print("%s is now worth %s.", Classes.STAT_LABELS[stat] or stat, tostring(GP.char.weights[stat] or "the default"))
    GP.Fire("WeightsChanged")
end)
