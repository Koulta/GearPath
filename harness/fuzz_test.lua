-- lua5.1 fuzz_test.lua <addon dir> <CLASS> [seed] [Alliance]
-- GearPath against gear nobody wrote by hand: a few hundred made-up items of
-- every slot and kind, and round after round of a random level, random gear
-- on, random bags, a random spec and random settings. Each round everything
-- is scored, every tooltip is built, every row of every page is drawn and a
-- few items are tried on. Nothing may raise an error, no number may come out
-- as not-a-number, and the route may not ask for the impossible (two items
-- in one slot, a two-hander with an off hand).
local dir, CLASS, SEED, FACTION = arg[1], arg[2], tonumber(arg[3]) or 1, arg[4] or "Horde"
local ROUNDS = tonumber(os.getenv("ROUNDS")) or 25
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

-- A small generator of its own, so a seed gives the same run everywhere.
local state = SEED * 2654435761 % 4294967296
local function rnd(n)
    state = (state * 1103515245 + 12345) % 4294967296
    local v = math.floor(state / 65536) % 32768
    if n then return v % n + 1 end
    return v / 32768
end
local function pick(t) return t[rnd(#t)] end
local function chance(p) return rnd() < p end

-- ---------------------------------------------------------------------
-- Made-up gear
-- ---------------------------------------------------------------------

-- equipLoc -> { classID, { subclasses } }
local KINDS = {
    INVTYPE_HEAD = { 4, { 1, 2, 3, 4 } }, INVTYPE_SHOULDER = { 4, { 1, 2, 3, 4 } }, INVTYPE_CHEST = { 4, { 1, 2, 3, 4, 0 } },
    INVTYPE_ROBE = { 4, { 1, 2 } }, INVTYPE_WAIST = { 4, { 1, 2, 3, 4 } }, INVTYPE_LEGS = { 4, { 1, 2, 3, 4 } },
    INVTYPE_FEET = { 4, { 1, 2, 3, 4 } }, INVTYPE_WRIST = { 4, { 1, 2, 3, 4 } }, INVTYPE_HAND = { 4, { 1, 2, 3, 4 } },
    INVTYPE_NECK = { 4, { 0 } }, INVTYPE_FINGER = { 4, { 0 } }, INVTYPE_TRINKET = { 4, { 0 } }, INVTYPE_CLOAK = { 4, { 1 } },
    INVTYPE_HOLDABLE = { 4, { 0 } }, INVTYPE_SHIELD = { 4, { 6 } }, INVTYPE_RELIC = { 4, { 7, 8, 9 } },
    INVTYPE_BODY = { 4, { 0 } }, INVTYPE_TABARD = { 4, { 0 } },
    INVTYPE_WEAPON = { 2, { 0, 4, 7, 13, 15 } }, INVTYPE_WEAPONMAINHAND = { 2, { 0, 4, 7, 15 } },
    INVTYPE_WEAPONOFFHAND = { 2, { 0, 4, 7, 13, 15 } }, INVTYPE_2HWEAPON = { 2, { 1, 5, 6, 8, 10 } },
    INVTYPE_RANGED = { 2, { 2 } }, INVTYPE_RANGEDRIGHT = { 2, { 3, 18, 19 } }, INVTYPE_THROWN = { 2, { 16 } },
}
local LOCS = {}
for loc in pairs(KINDS) do LOCS[#LOCS + 1] = loc end
table.sort(LOCS)
local STATS = { "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STRENGTH_SHORT",
    "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    "ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT", "ITEM_MOD_FIRE_DAMAGE_DONE_SHORT", "ITEM_MOD_FROST_DAMAGE_DONE_SHORT",
    "ITEM_MOD_POWER_REGEN0_SHORT", "RESISTANCE0_NAME", "ITEM_MOD_HEALTH_REGEN_SHORT", "ITEM_MOD_NOT_A_REAL_STAT_SHORT" }
local LINES = {
    "Unique", "Use: Does something for 10 sec.", "Chance on hit: Zaps the target for 30 Nature damage.",
    "Equip: Improves your chance to hit by 1%.", "Equip: Improves your chance to get a critical strike by 2%.",
    "Equip: Improves your chance to hit with spells by 1%.", "Equip: Restores 4 mana per 5 sec.",
    "Equip: Increases damage and healing done by magical spells and effects by up to 12.",
    "Equip: Increases healing done by spells and effects by up to 22.", "Speed 2.60", "Speed 1.50",
    "Equip: Something GearPath has never heard of, 50% of the time.", "+7 Shadow Spell Damage", "",
    "Classes: " .. INFO[CLASS][1], "Classes: Gnome Tinker", "Binds when equipped",
}
local RED = { "Requires Level %d", "Requires Tailoring (%d)", "Requires Sergeant", "Requires One-Handed Swords", "Classes: Gnome Tinker" }

local I = H.ITEMS
local MADE, BY_LOC = {}, {}
local FIRST = 6000
for n = 0, 259 do
    local id = FIRST + n
    local loc = LOCS[(n % #LOCS) + 1]
    local kind = KINDS[loc]
    local stats = {}
    for _ = 1, rnd(5) - 1 do stats[pick(STATS)] = chance(0.05) and 0 or rnd(40) end
    if kind[1] == 2 then stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = chance(0.9) and (rnd(600) / 10) or nil end
    local lines = {}
    for _ = 1, rnd(4) - 1 do lines[#lines + 1] = pick(LINES) end
    if chance(0.15) then
        local red = pick(RED)
        lines[#lines + 1] = { red:find("%%d") and string.format(red, rnd(70)) or red, 1, 0.125, 0.125 }
    end
    I[id] = { "Made-up " .. loc:sub(9):lower() .. " " .. n, rnd(5) - 1, rnd(80), chance(0.2) and 0 or rnd(66), loc, kind[1], pick(kind[2]), stats, lines }
    MADE[#MADE + 1] = id
    BY_LOC[loc] = BY_LOC[loc] or {}
    table.insert(BY_LOC[loc], id)
end

-- Inventory slot id -> the kinds of item that go there.
local WEAR = {
    [1] = { "INVTYPE_HEAD" }, [2] = { "INVTYPE_NECK" }, [3] = { "INVTYPE_SHOULDER" }, [4] = { "INVTYPE_BODY" },
    [5] = { "INVTYPE_CHEST", "INVTYPE_ROBE" }, [6] = { "INVTYPE_WAIST" }, [7] = { "INVTYPE_LEGS" }, [8] = { "INVTYPE_FEET" },
    [9] = { "INVTYPE_WRIST" }, [10] = { "INVTYPE_HAND" }, [11] = { "INVTYPE_FINGER" }, [12] = { "INVTYPE_FINGER" },
    [13] = { "INVTYPE_TRINKET" }, [14] = { "INVTYPE_TRINKET" }, [15] = { "INVTYPE_CLOAK" },
    [16] = { "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_2HWEAPON" },
    [17] = { "INVTYPE_WEAPON", "INVTYPE_WEAPONOFFHAND", "INVTYPE_SHIELD", "INVTYPE_HOLDABLE" },
    [18] = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC" }, [19] = { "INVTYPE_TABARD" },
}

local LEVEL = 23
function UnitLevel() return LEVEL end

-- ---------------------------------------------------------------------
-- GearPath
-- ---------------------------------------------------------------------

local problems, shown = 0, 0
local where = "loading"
local function problem(text)
    problems = problems + 1
    if shown < 12 then
        shown = shown + 1
        print(string.format("  PROBLEM [%s seed %d, %s]: %s", CLASS, SEED, where, tostring(text)))
    end
end
local function try(what, fn, ...)
    local res = { pcall(fn, ...) }
    if not res[1] then problem(what .. ": " .. tostring(res[2])) return nil end
    return unpack(res, 2)
end
local function finite(v) return v == nil or (type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge) end

local ns = {}
for line in io.open(dir .. "/GearPath.toc"):read("*a"):gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local ok, err = pcall(assert(loadfile(dir .. "/" .. line:gsub("\\", "/"))), "GearPath", ns)
        if not ok then problem("load " .. line .. ": " .. tostring(err)) end
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
H.Fire("PLAYER_LOGIN")
for _ = 1, 300 do H.Tick(0.1) if GP.Sources.status == "ready" then break end end
for _ = 1, 20 do H.Tick(0.1) end
if GP.player.class ~= CLASS then problem("not playing as " .. CLASS) end

local UI, S, Items = GP.UI, GP.Score, GP.Items

-- Where the made-up gear comes from: three in four have a source GearPath
-- "learned" (a quest, a vendor, a mob in the world or in a dungeon; some
-- with a place on the map and some without), so they're on its lists.
do
    local learned = GP.db.learned.items
    local MAPS = { 1420, 1436, 1431, 999999 }
    local DUNGEONS = { "The Deadmines", "Scarlet Monastery", "Scarlet Monastery: Library", "A Dungeon Nobody Knows" }
    for n, id in ipairs(MADE) do
        if n % 4 ~= 0 then
            local rec = { s = time() }
            for _ = 1, rnd(2) do
                local kind = pick({ "q", "q", "v", "d", "d" })
                local place = chance(0.8)
                local info = { n = "Made-up " .. kind .. " " .. n, m = place and pick(MAPS) or nil, x = place and rnd() or nil, y = place and rnd() or nil, s = time() }
                if kind == "q" then
                    info.c, info.l, info.g = chance(0.5), chance(0.7) and rnd(60) or nil, chance(0.5) and "Some Giver" or nil
                    -- Two rewards of one quest now and then (only one can be picked).
                    rec.q = rec.q or {}
                    rec.q[chance(0.3) and (7000 + rnd(12)) or (7100 + n)] = info
                elseif kind == "v" then
                    rec.v = rec.v or {}
                    rec.v[8000 + rnd(40)] = info
                else
                    if chance(0.4) then info.dg = pick(DUNGEONS) end
                    rec.d = rec.d or {}
                    rec.d[9000 + rnd(60)] = info
                end
            end
            learned[id] = rec
        end
    end
    GP.Fire("RescanRequested")
    for _ = 1, 400 do H.Tick(0.1) if GP.Sources.status == "ready" then break end end
    for _ = 1, 20 do H.Tick(0.1) end
end
try("opening the window", UI.Toggle)
H.Tick(0.2)

local function suffixed(id, n) return (H.Link(id):gsub("item:" .. id .. ":", "item:" .. id .. "::::::" .. n .. ":")) end
H.suffixStats = { [41] = { ITEM_MOD_SPELL_POWER_SHORT = 9 }, [42] = { ITEM_MOD_AGILITY_SHORT = 7, ITEM_MOD_STAMINA_SHORT = 7 },
    [43] = { ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = 11, ITEM_MOD_SPIRIT_SHORT = 5 } }

local function drawAll(list, what)
    if not (list and list.items) then return 0 end
    for _, it in ipairs(list.items) do
        local kind = list.kinds[it.kind] or list.kinds.note
        local row = CreateFrame("Button", nil, UIParent)
        try(what .. " row " .. tostring(it.kind) .. (it.ev and (" (" .. tostring(it.ev.rec.name) .. ")") or ""), function()
            kind.build(row, list)
            kind.fill(row, it, list)
        end)
    end
    return #list.items
end

local rows, tips, scored, picksSeen, listed, upgrades = 0, 0, 0, 0, 0, 0
for round = 1, ROUNDS do
    where = "round " .. round
    local errorsBefore, countBefore = #H.errors, GP.errors.count
    LEVEL = chance(0.2) and pick({ 1, 2, 10, 19, 20, 39, 40, 59, 60 }) or rnd(60)

    -- What's on: most slots filled, some empty, a suffix here and there.
    H.wornLink = {}
    for slot = 1, 19 do
        H.EQUIPPED[slot] = nil
        if chance(0.75) then
            local id = pick(BY_LOC[pick(WEAR[slot])])
            H.EQUIPPED[slot] = id
            if chance(0.15) then H.wornLink[slot] = suffixed(id, 40 + rnd(3)) end
        end
    end
    -- A two-hander leaves the off hand empty.
    if H.EQUIPPED[16] and I[H.EQUIPPED[16]][5] == "INVTYPE_2HWEAPON" then H.EQUIPPED[17], H.wornLink[17] = nil, nil end
    -- The bags: anything at all, some of it the same item as what's worn.
    H.bag = {}
    for slot = 1, 16 do
        if chance(0.7) then
            local id = chance(0.15) and H.EQUIPPED[rnd(19)] or pick(MADE)
            H.bag[slot] = chance(0.25) and suffixed(id, 40 + rnd(3)) or id
        end
    end
    -- How it's set up.
    try("settings", function()
        GP.SetSetting("ahead", rnd(11) - 1)
        GP.SetSetting("soon", rnd(6) - 1)
        GP.SetSetting("dungeons", chance(0.7))
        GP.SetSetting("worldDrops", chance(0.3))
        GP.SetSetting("healerGear", chance(0.3))
        GP.SetSetting("routeGroup", chance(0.5) and "slot" or nil)
        GP.SetSetting("browseSort", pick(UI.SORT_KEYS))
        local specs = GP.Classes.Specs()
        GP.Classes.SetSpec(pick(specs).key)
        if chance(0.2) then
            GP.char.weights = { [pick({ "sta", "int", "hit", "crit", "sp", "agi", "str", "armor" })] = pick({ 0, 0.5, 3, 25, -1 }) }
            GP.Fire("WeightsChanged")
        elseif chance(0.3) then
            GP.char.weights = nil
            GP.Fire("WeightsChanged")
        end
    end)
    try("a new level", function() GP.PlayerInfo(); GP.Fire("LevelChanged", LEVEL) end)
    try("gear and bag events", function()
        H.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
        H.Fire("BAG_UPDATE_DELAYED")
        H.Fire("SKILL_LINES_CHANGED")
    end)
    for _ = 1, 40 do H.Tick(0.1) if GP.Sources.status == "ready" then break end end
    for _ = 1, 15 do H.Tick(0.1) end
    local res = try("scoring", S.Run)
    res = res or S.results

    -- Every made-up item, asked everything.
    for _, id in ipairs(MADE) do
        local link = chance(0.2) and suffixed(id, 40 + rnd(3)) or H.Link(id)
        local rec = try("reading " .. id, Items.FromLink, link)
        if rec then
            scored = scored + 1
            local slot, delta, pct, base = try("Upgrade " .. rec.name, S.Upgrade, rec)
            if not (finite(delta) and finite(pct) and finite(base)) then problem("not a number for " .. rec.name .. ": " .. tostring(delta) .. " " .. tostring(pct) .. " " .. tostring(base)) end
            if slot and delta and delta > 0 then upgrades = upgrades + 1 end
            if slot and not GP.Slots.BY_KEY[slot] then problem("an unknown slot for " .. rec.name .. ": " .. tostring(slot)) end
            for _, spec in ipairs(GP.Classes.Specs()) do try("UpgradeAs " .. rec.name, S.UpgradeAs, rec, spec) end
            try("AnySpecGain", S.AnySpecGain, rec)
            try("SafeToSell", S.SafeToSell, rec)
            try("CanWear", S.CanWear, rec, LEVEL)
            try("Gain", S.Gain, rec)
            try("Roll.Verdict", GP.Roll.Verdict, rec)
            try("BagUpgrade", GP.Ellesmere.BagUpgrade, link)
            try("Sell.Safe", GP.Sell.Safe, link)
            GameTooltip._lines = {}
            try("tooltip " .. rec.name, GP.Tooltip.Add, GameTooltip, id, link)
            tips = tips + 1
        end
    end
    -- What's worn is never an upgrade over itself.
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        local rec = link and Items.FromLink(link)
        if rec and S.Upgrade(rec) ~= nil then
            -- (Unless a second of it could go in the other ring, trinket or weapon slot.)
            local loc = rec.equipLoc
            local pair = loc == "INVTYPE_FINGER" or loc == "INVTYPE_TRINKET" or loc == "INVTYPE_WEAPON"
            if not pair then problem("what's worn is an upgrade over itself: " .. rec.name) end
        end
    end
    -- The route asks for nothing impossible.
    do
        local taken, twoHand, offHand = {}, false, false
        listed = listed + #(res.all or {})
        for _, p in ipairs(res.plan and res.plan.picks or {}) do
            picksSeen = picksSeen + 1
            local slot = p.slot or (p.ev and p.ev.slot)
            local rec = p.ev and p.ev.rec or p.rec
            if slot then
                if taken[slot] then problem("the route fills " .. slot .. " twice") end
                taken[slot] = true
                if slot == "MainHandSlot" and rec and rec.equipLoc == "INVTYPE_2HWEAPON" then twoHand = true end
                if slot == "SecondaryHandSlot" then offHand = true end
            end
            if not finite(p.delta) then problem("a route pick with no number") end
        end
        if twoHand and offHand then problem("the route asks for a two-hander and an off hand") end
    end
    -- Every list has one order however it's asked.
    for _, key in ipairs(UI.SORT_KEYS) do
        try("sort " .. key, UI.Sorted, res.all or {}, key)
    end
    for group, bucket in pairs(res.bySlot or {}) do
        local list = bucket.secondary or {}
        for i = 1, math.min(#list, 25) do
            for j = 1, math.min(#list, 25) do
                if i ~= j and S.ChaseBefore(list[i], list[j], LEVEL) and S.ChaseBefore(list[j], list[i], LEVEL) then
                    problem("Worth chasing has no order in " .. tostring(group))
                end
            end
        end
    end
    -- Everything drawn.
    try("the route page", UI.Show, "plan")
    if UI.Plan and UI.Plan.list then
        for _, it in ipairs(UI.Plan.list.items) do
            if it.kind == "more" and it.pick and UI.Plan.open then UI.Plan.open[it.pick] = true end
        end
        try("the route, opened", UI.PAGES.plan.Fill, UI.PAGES.plan.frame)
        rows = rows + drawAll(UI.Plan.list, "route")
    end
    try("the browse page", UI.Show, "browse")
    rows = rows + drawAll(UI.Browse and UI.Browse.list, "browse")
    try("the character page", UI.Show, "doll")
    try("no slot", UI.SelectSlot, nil)
    rows = rows + drawAll(UI.SlotPanel.list, "character")
    for _ = 1, 3 do
        local s = pick(GP.Slots.LIST)
        if not s.cosmetic then
            try("slot " .. s.key, UI.SelectSlot, s.key)
            rows = rows + drawAll(UI.SlotPanel.list, "slot " .. s.key)
        end
    end
    try("no slot", UI.SelectSlot, nil)
    -- A few items tried on together.
    do
        local all = res.all or {}
        local tried = {}
        for _ = 1, math.min(3, #all) do
            local ev = pick(all)
            if ev.slot then tried[ev.slot] = ev end
        end
        if next(tried) then
            local gain = try("LoadoutGain", S.LoadoutGain, tried)
            if not finite(gain) then problem("trying on gives no number") end
            UI.tried = tried
            try("stats with gear tried on", UI.Stats.Build, tried)
            try("the summary with gear tried on", UI.Doll.UpdateSummary)
            try("the stats panel", UI.Stats.Fill)
            try("Put it on's list", UI.Doll.UpdatePutOn)
            UI.tried = nil
            try("the summary", UI.Doll.UpdateSummary)
        end
    end
    try("the settings page", UI.Show, "settings")
    -- A quest that offers three of them.
    H.choices = { pick(MADE), pick(MADE), pick(MADE) }
    try("the quest reward pick", function() H.Fire("QUEST_COMPLETE") end)
    H.choices = nil
    try("the report", GP.Sources.ReportLine)
    for _ = 1, 5 do H.Tick(0.1) end
    for i = errorsBefore + 1, #H.errors do problem("an error: " .. tostring(H.errors[i]):match("^[^\n]*")) end
    -- (GearPath shows each of its own errors once; they're all counted.)
    if GP.errors.count > countBefore and #H.errors == errorsBefore then
        problem((GP.errors.count - countBefore) .. " errors caught by GearPath, the last: " .. tostring(GP.errors.last))
    end
end

print(string.format("  fuzz %s seed %d: %d rounds, %d items scored (%d upgrades), %d listed, %d route picks, %d tooltips, %d rows drawn, %d problems",
    CLASS, SEED, ROUNDS, scored, upgrades, listed, picksSeen, tips, rows, problems))
os.exit(problems == 0 and 0 or 1)
