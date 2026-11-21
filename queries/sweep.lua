-- The class sweep: GearPath on the real QuestieDB as one class, faction and
-- level, every pick checked against an independent table of what each
-- class can use (Classic + Forever's changes) and the rules of the slots.
--   GPDIR=<addon> CLASS=WARRIOR FACTION=Horde LEVEL=30 lua5.1 qdb.lua <QuestieDB> sweep.lua
-- QuestieDB has no equip slots or stats: slots come from the weapon type or
-- the item's name, stats are made up from the armor type. The point is the
-- rules (who can use what, where it goes, sources for your faction and class).
local GPDIR = os.getenv("GPDIR")
-- SNAPSHOT=<GearPath's saved file>: real items from the game (/gp snapshot
-- in game, then /reload), used instead of guessing slots and stats. Since
-- 0.8.12 it also has the character's gear and setup; CLASS, FACTION, LEVEL
-- and SPEC default to it, so SNAPSHOT=... alone rebuilds their lists.
local SNAP, SNAPSHOT = {}, nil
if (os.getenv("SNAPSHOT") or "") ~= "" then
    local env = {}
    local chunk = assert(loadfile(os.getenv("SNAPSHOT")))
    setfenv(chunk, env)
    chunk()
    SNAPSHOT = env.GearPathDB and env.GearPathDB.snapshot or {}
    SNAP = SNAPSHOT.items or {}
    local n, w = 0, 0
    for _ in pairs(SNAP) do n = n + 1 end
    for _ in pairs(SNAPSHOT.worn or {}) do w = w + 1 end
    io.stderr:write("snapshot: " .. n .. " real items, " .. w .. " worn" .. (SNAPSHOT.class and
        (", " .. tostring(SNAPSHOT.class) .. " " .. tostring(SNAPSHOT.level) .. " " .. tostring(SNAPSHOT.spec)) or "") .. "\n")
end
local function env(name, fromSnap) local v = os.getenv(name); if v and v ~= "" then return v end; return fromSnap end
local CLASS = env("CLASS", SNAPSHOT and SNAPSHOT.class) or "WARLOCK"
local FACTION = env("FACTION", SNAPSHOT and SNAPSHOT.faction) or "Horde"
local LEVEL = tonumber(env("LEVEL", SNAPSHOT and SNAPSHOT.level) or "30")
local VERBOSE = os.getenv("VERBOSE")
local DB = LibQuestieDB
local I = DB.Item

local CLASSES = { WARRIOR = { "Warrior", 1 }, PALADIN = { "Paladin", 2 }, HUNTER = { "Hunter", 3 }, ROGUE = { "Rogue", 4 },
    PRIEST = { "Priest", 5 }, SHAMAN = { "Shaman", 7 }, MAGE = { "Mage", 8 }, WARLOCK = { "Warlock", 9 }, DRUID = { "Druid", 11 } }
-- A race that can be the class, per faction (as the sweep ran it in October 2026).
local RACE = {
    Horde = { WARRIOR = { "Orc", 2 }, PALADIN = { "Tauren", 6 }, HUNTER = { "Troll", 8 }, ROGUE = { "Scourge", 5 }, PRIEST = { "Scourge", 5 },
        SHAMAN = { "Tauren", 6 }, MAGE = { "Troll", 8 }, WARLOCK = { "Scourge", 5 }, DRUID = { "Tauren", 6 } },
    Alliance = { WARRIOR = { "Human", 1 }, PALADIN = { "Human", 1 }, HUNTER = { "NightElf", 4 }, ROGUE = { "Human", 1 }, PRIEST = { "Human", 1 },
        SHAMAN = { "Dwarf", 3 }, MAGE = { "Gnome", 7 }, WARLOCK = { "Human", 1 }, DRUID = { "NightElf", 4 } },
}
local race = RACE[FACTION][CLASS]
function UnitClass() return CLASSES[CLASS][1], CLASS, CLASSES[CLASS][2] end
function UnitClassBase() return CLASS, CLASSES[CLASS][2] end
function UnitRace() return race[1], race[1], race[2] end
function UnitRaceBase() return race[1], race[2] end
function UnitFactionGroup() return FACTION end
function UnitLevel() return LEVEL end

-- Independent reference: Classic proficiencies + Forever (druid polearms, rogue one-handed axes, shaman two-handers for all).
local W = { AXE1H = 0, AXE2H = 1, BOW = 2, GUN = 3, MACE1H = 4, MACE2H = 5, POLEARM = 6, SWORD1H = 7, SWORD2H = 8,
    STAFF = 10, FIST = 13, MISC = 14, DAGGER = 15, THROWN = 16, CROSSBOW = 18, WAND = 19, FISHING = 20 }
local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local REF = {
    WARRIOR = { w = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18), a = set(1, 2, 3, 4, 6), plateAt = 40 },
    PALADIN = { w = set(0, 1, 4, 5, 6, 7, 8), a = set(1, 2, 3, 4, 6, 7), plateAt = 40 },
    HUNTER = { w = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18), a = set(1, 2, 3), mailAt = 40 },
    ROGUE = { w = set(0, 2, 3, 4, 7, 13, 15, 16, 18), a = set(1, 2) },
    PRIEST = { w = set(4, 10, 15, 19), a = set(1) },
    SHAMAN = { w = set(0, 1, 4, 5, 10, 13, 15), a = set(1, 2, 3, 6, 9), mailAt = 40 },
    MAGE = { w = set(7, 10, 15, 19), a = set(1) },
    WARLOCK = { w = set(7, 10, 15, 19), a = set(1) },
    DRUID = { w = set(4, 5, 6, 10, 13, 15), a = set(1, 2, 8) },
}
local DW = { ROGUE = 10, WARRIOR = 20, HUNTER = 20 }
local ref = REF[CLASS]

-- Slots from the weapon type or the name.
local TWO = set(1, 5, 6, 8, 10)
local function byName(name, list)
    name = (name or ""):lower()
    for _, p in ipairs(list) do
        for _, word in ipairs(p[2]) do if name:find(word, 1, true) then return p[1] end end
    end
end
local ARMOR_WORDS = {
    { "INVTYPE_CLOAK", { "cloak", "cape", "drape", "shroud" } },
    { "INVTYPE_HEAD", { "helm", "hood", "cap", "crown", "circlet", "cowl", "mask", "headband", "visor", "skullcap", "hat" } },
    { "INVTYPE_SHOULDER", { "shoulder", "mantle", "pauldron", "spaulder", "amice", "epaulet" } },
    { "INVTYPE_CHEST", { "robe", "vest", "tunic", "chest", "breastplate", "jerkin", "hauberk", "harness", "armor", "raiment", "garb", "shirt" } },
    { "INVTYPE_WRIST", { "bracer", "wrist", "bindings", "cuffs", "armguard", "bracelet" } },
    { "INVTYPE_HAND", { "glove", "gauntlet", "handwrap", "mitt", "grip", "hand" } },
    { "INVTYPE_WAIST", { "belt", "girdle", "sash", "cord", "waist", "cinch" } },
    { "INVTYPE_LEGS", { "pant", "legging", "legguard", "trouser", "kilt", "breeches", "legplate", "skirt", "britches" } },
    { "INVTYPE_FEET", { "boot", "sandal", "tread", "shoe", "slipper", "sabaton", "footwrap", "stomper", "greaves" } },
}
local MISC_WORDS = {
    { "INVTYPE_FINGER", { "ring", "band", "loop", "signet", "seal" } },
    { "INVTYPE_NECK", { "necklace", "amulet", "pendant", "choker", "talisman", "medallion", "collar", "chain", "locket" } },
    { "INVTYPE_HOLDABLE", { "orb", "tome", "lamp", "candle", "scroll", "lantern", "branch", "torch", "skull", "book" } },
}
-- What they wear, from the snapshot: by slot id, and stats by link.
local WORN, WORN_BY_LINK = {}, {}
for sid, w in pairs(SNAPSHOT and SNAPSHOT.worn or {}) do
    if type(w) == "table" and w.link then
        WORN[tonumber(sid) or sid] = w
        WORN_BY_LINK[w.link] = w
    end
end
local function wornFor(l)
    local key = type(l) == "string" and l:match("item:[%-%d:]+")
    return key and WORN_BY_LINK[key]
end

local function loc(id)
    if SNAP[id] then return SNAP[id].loc end
    local c, s = I.class(id), I.subClass(id) or 0
    local name = I.name(id)
    if c == 2 then
        if s == W.BOW or s == W.GUN or s == W.CROSSBOW then return "INVTYPE_RANGED" end
        if s == W.WAND then return "INVTYPE_RANGEDRIGHT" end
        if s == W.THROWN then return "INVTYPE_THROWN" end
        if s == W.FISHING or s == W.MISC then return "INVTYPE_WEAPONMAINHAND" end
        return TWO[s] and "INVTYPE_2HWEAPON" or "INVTYPE_WEAPON"
    end
    if c == 4 then
        if s == 6 then return "INVTYPE_SHIELD" end
        if s >= 7 and s <= 9 then return "INVTYPE_RELIC" end
        -- Misc armour is shirts, tabards and cosmetics as often as trinkets.
        -- With a snapshot, one it doesn't know isn't guessed as a trinket
        -- (it took a wedding outfit for one); without, the old guess stays.
        if s == 0 then return byName(name, MISC_WORDS) or (next(SNAP) and "" or "INVTYPE_TRINKET") end
        return byName(name, ARMOR_WORDS) or "INVTYPE_CHEST"
    end
end
local function stats(id)
    if SNAP[id] then return SNAP[id].stats or {} end
    local c, s = I.class(id), I.subClass(id) or 0
    local il = math.max(1, I.itemLevel(id) or 1)
    local v = math.floor(il / 4) + 1
    if c == 2 then
        local t = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = il * 0.6 + 2 }
        if s == W.STAFF or s == W.WAND or (s == W.DAGGER and id % 2 == 0) then t.ITEM_MOD_SPELL_POWER_SHORT = v end
        if s == W.SWORD1H or s == W.SWORD2H or s == W.AXE1H or s == W.AXE2H or s == W.MACE2H or s == W.POLEARM then t.ITEM_MOD_STRENGTH_SHORT = v end
        if s == W.FIST or s == W.DAGGER or s == W.BOW or s == W.GUN or s == W.CROSSBOW or s == W.THROWN then t.ITEM_MOD_AGILITY_SHORT = v end
        if s == W.MACE1H then t.ITEM_MOD_STRENGTH_SHORT = v; t.ITEM_MOD_INTELLECT_SHORT = math.floor(v / 2) end
        return t
    end
    if s == 1 then return { ITEM_MOD_INTELLECT_SHORT = v, ITEM_MOD_SPELL_POWER_SHORT = math.floor(v / 2), ITEM_MOD_SPIRIT_SHORT = math.floor(v / 2) } end
    if s == 2 then return { ITEM_MOD_AGILITY_SHORT = v, ITEM_MOD_STAMINA_SHORT = math.floor(v / 2) } end
    if s == 3 then return { ITEM_MOD_STRENGTH_SHORT = math.floor(v / 2), ITEM_MOD_AGILITY_SHORT = math.floor(v / 2), ITEM_MOD_INTELLECT_SHORT = math.floor(v / 2) } end
    if s == 4 then return { ITEM_MOD_STRENGTH_SHORT = v, ITEM_MOD_STAMINA_SHORT = v } end
    if s == 6 then return { ITEM_MOD_STAMINA_SHORT = v } end
    return { ITEM_MOD_STAMINA_SHORT = math.floor(v / 2) + 1, ITEM_MOD_INTELLECT_SHORT = id % 3 == 0 and v or nil,
        ITEM_MOD_AGILITY_SHORT = id % 3 == 1 and v or nil, ITEM_MOD_STRENGTH_SHORT = id % 3 == 2 and v or nil }
end
function GetItemInfoInstant(x)
    local id = type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)"))
    if id and SNAP[id] then return id, "", "", SNAP[id].loc or "", 134000, SNAP[id].c, SNAP[id].s end
    if not id or not I.class(id) then return nil end
    return id, "", "", loc(id) or "", 134000, I.class(id), I.subClass(id) or 0
end
local function link(id) return string.format("|cff1eff00|Hitem:%d::::::::%d:::::|h[%s]|h|r", id, LEVEL, I.name(id) or "?") end
C_Item = {
    GetItemInfoInstant = GetItemInfoInstant,
    GetItemInfo = function(x)
        local id = type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)"))
        local r = id and SNAP[id]
        if r then
            return r.name, link(id), r.q, r.il, r.req, "", "", 1, r.loc or "", 134000, r.sell or 100, r.c, r.s, 2
        end
        if not id or not I.class(id) then return nil end
        return I.name(id), link(id), id % 3 + 2, I.itemLevel(id) or 1, I.requiredLevel(id) or 0, "", "", 1, loc(id) or "",
            134000, 100, I.class(id), I.subClass(id) or 0, 2
    end,
    GetItemStats = function(l)
        local w = wornFor(l)
        if w and w.stats then return w.stats end
        return stats(tonumber(l:match("item:(%d+)")))
    end,
    IsItemDataCachedByID = function() return true end,
    RequestLoadItemDataByID = function() end,
    GetItemQualityColor = function() return 1, 1, 1, "ffffffff" end,
}
-- ASYNC=1: items arrive like in the game, a while after they're asked for
-- (and only once asked for), so overlapping scans meet half-loaded lists.
if os.getenv("ASYNC") then
    local cached, asked = {}, {}
    local seed = 7
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
    C_Item.IsItemDataCachedByID = function(id) return cached[id] == true end
    -- RATE=n: the server answers n items a second, in order (it queues them).
    local rate, queue, nextAt = tonumber(os.getenv("RATE") or "0"), {}, 0
    C_Item.RequestLoadItemDataByID = function(id)
        if cached[id] or asked[id] then return end
        asked[id] = true
        local delay = (1 + rnd(90)) / 60
        if rate > 0 then
            local now = GetTime()
            nextAt = math.max(nextAt, now) + 1 / rate
            delay = nextAt - now
        end
        C_Timer.After(delay, function()
            cached[id], asked[id] = true, nil
            H.Fire("GET_ITEM_INFO_RECEIVED", id, true)
        end)
    end
end
local function tipFor(id, fallback)
    local r = id and SNAP[id]
    if r and r.lines and #r.lines > 0 then
        local lines = {}
        for i, t in ipairs(r.lines) do lines[i] = { leftText = t } end
        return { lines = lines }
    end
    return { lines = { { leftText = fallback or "?" } } }
end
C_TooltipInfo = {
    GetHyperlink = function(l)
        local w = wornFor(l)
        if w and w.lines and #w.lines > 0 then
            local lines = {}
            for i, t in ipairs(w.lines) do lines[i] = { leftText = t } end
            return { lines = lines }
        end
        return tipFor(tonumber(l:match("item:(%d+)")), l:match("%[(.-)%]"))
    end,
    GetItemByID = function(id) return tipFor(id, I.name(id)) end,
}
C_TooltipInfo.GetItemByID = function(id) return C_TooltipInfo.GetHyperlink(link(id)) end
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemLink = function() return nil end }
-- Slots by name, the game's ids; worn gear from the snapshot.
local SLOT_ID = { HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7,
    FeetSlot = 8, WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14,
    BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18, TabardSlot = 19 }
function GetInventorySlotInfo(name) return SLOT_ID[name] or 1, "" end
function GetInventoryItemLink(_, sid)
    local w = WORN[sid]
    if not w then return nil end
    local id = tonumber(w.link:match("item:(%d+)"))
    return "|cff1eff00|H" .. w.link .. "|h[" .. tostring(SNAP[id] and SNAP[id].name or I.name(id) or "?") .. "]|h|r"
end
function GetInventoryItemID(_, sid) local w = WORN[sid]; return w and tonumber(w.link:match("item:(%d+)")) end
function GetInventoryItemTexture(_, sid) return WORN[sid] and 134000 or nil end
function GetInventoryItemQuality(_, sid) return WORN[sid] and 2 or nil end
function GetInventoryItemDurability() return nil end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end }
local ZN = {}
for sym, id in pairs(DB.Enum.zoneIDs or {}) do
    ZN[id] = sym:lower():gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
end
C_Map = { GetAreaInfo = function(a) return ZN[a] end, GetMapInfo = function() return nil end,
    GetBestMapForUnit = function() return nil end }
-- A fresh character's skills: a few weapons known (so training shows), the rest to learn.
local KNOWN = { [1180] = true, [227] = true, [201] = true, [198] = true, [196] = true, [5009] = true, [264] = true, [266] = true,
    [8737] = (CLASS == "WARRIOR" or CLASS == "PALADIN"), [9116] = true }
function IsPlayerSpell(id) return KNOWN[id] == true end

local ns = {}
for line in io.lines(GPDIR .. "/GearPath.toc") do
    if not line:match("^#") and line:match("%.lua%s*$") then
        assert(loadfile(GPDIR .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")))("GearPath", ns)
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
H.Fire("PLAYER_LOGIN")
GP.player.level = LEVEL
local SPEC = env("SPEC", SNAPSHOT and SNAPSHOT.spec)
if SNAPSHOT then
    GP.char.weaponStyle = SNAPSHOT.weaponStyle
    GP.char.weaponTypesOff = SNAPSHOT.weaponTypesOff
end
if SPEC then GP.Classes.SetSpec(SPEC) end
if next(WORN) then GP.Score.ReadEquipped() end
if os.getenv("HOOK") then assert(loadfile(os.getenv("HOOK")))(GP) end
-- Settings > Look ahead / Best now range (OrtusX, Nov 14: 10 and 5 showed 2 items).
if os.getenv("AHEAD") then GP.SetSetting("ahead", tonumber(os.getenv("AHEAD"))) end
if os.getenv("SOON") then GP.SetSetting("soon", tonumber(os.getenv("SOON"))) end
-- A scan now and the one login starts 4 seconds in, overlapping (as a
-- level-up right after login would): the result must be the full list.
GP.Sources.Scan()
local frames = 0
repeat
    H.Tick(1 / 60); frames = frames + 1
until (frames > 300 and GP.Sources.status == "ready" and not GP.JobRunning("scan") and not GP.JobRunning("items")) or frames > 100000

-- CLICKS=1: after the list is ready, click Look ahead up to AHEAD2 and Best
-- now range up to SOON2 one step at a time, a few frames apart, as a player
-- does in Settings (OrtusX's report, Nov 14).
if os.getenv("CLICKS") then
    local function step(key, to, def)
        local v = GP.Setting(key) or def
        while v < to do
            v = v + 1
            GP.SetSetting(key, v)
            for _ = 1, tonumber(os.getenv("GAP") or "12") do H.Tick(1 / 60) end
        end
    end
    step("ahead", tonumber(os.getenv("AHEAD2") or "10"), 5)
    step("soon", tonumber(os.getenv("SOON2") or "5"), 2)
    frames = 0
    repeat
        H.Tick(1 / 60); frames = frames + 1
    until (frames > 300 and GP.Sources.status == "ready" and not GP.JobRunning("scan") and not GP.JobRunning("items")) or frames > 100000
end

-- ---------------------------------------------------------------------
-- The checks
-- ---------------------------------------------------------------------
local problems = {}
local function bad(ev, why)
    problems[#problems + 1] = string.format("%s [%d] %s (%s): %s", ev.rec.name or "?", ev.rec.id, GP.Slots.Label(ev.slot), ev.tier or "-", why)
end
local res = GP.Score.results
if _G.SNreport then print(string.format("same-name lookups %d, starts found %d, %.3fs", _G.SNreport())) end
-- ITEM=id: everything GearPath decided about one item (a player's "why
-- isn't X suggested?").
if os.getenv("ITEM") then
    local id = tonumber(os.getenv("ITEM"))
    local entry = GP.Sources.entries and GP.Sources.entries[id]
    print("ITEM " .. id .. ": in the scan " .. tostring(entry ~= nil))
    if entry then
        print("  usable " .. tostring(entry.usable) .. ", opensAt " .. tostring(entry.opensAt) .. ", effort " .. tostring(entry.effort))
        for _, s in ipairs(entry.sources or {}) do print("  source " .. GP.UI.Describe(s, true) .. " level " .. tostring(s.level) .. " req " .. tostring(s.reqLevel)) end
    end
    local rec = GP.Items.Get(id)
    if rec then print("  item: req " .. tostring(rec.reqLevel) .. " " .. tostring(rec.equipLoc) .. " class " .. tostring(rec.classID) .. "/" .. tostring(rec.subClassID)) end
    local ev = res.byID and res.byID[id]
    if ev then
        print("  scored: tier " .. tostring(ev.tier) .. " delta " .. tostring(ev.delta) .. " pct " .. tostring(ev.pct) .. " slot " .. tostring(ev.slot) .. " req " .. tostring(ev.req))
    else
        print("  not scored (no ev)")
        if rec then print("  Upgrade: ", GP.Score.Upgrade(rec)); print("  CanWear: ", GP.Score.CanWear(rec, LEVEL)) end
    end
    -- What it's up against in its slot.
    local slot = ev and ev.slot
    local bucket = slot and res.bySlot[GP.Slots.GROUP[slot] or slot]
    if bucket then
        for i = 1, math.min(3, #bucket.secondary) do
            local e = bucket.secondary[i]
            print(string.format("  Worth chasing #%d: %s +%.0f req %s", i, e.rec.name, e.delta, tostring(e.req)))
        end
    end
    if slot then
        local list = {}
        for _, e in pairs(res.byID) do if e.slot == slot and e.delta then list[#list + 1] = e end end
        table.sort(list, function(a, b) return a.delta > b.delta end)
        for i = 1, math.min(8, #list) do
            local e = list[i]
            print(string.format("  #%d %s [%s] %s +%.0f req %s %s", i, e.rec.name, tostring(e.tier), slot, e.delta, tostring(e.req or e.rec.reqLevel), e.source and GP.UI.Describe(e.source, true) or "?"))
        end
    end
end
local function canUse(rec)
    if rec.classID == 2 then return ref.w[rec.subClassID] == true end
    if rec.classID == 4 then
        local s = rec.subClassID
        if rec.equipLoc == "INVTYPE_CLOAK" or rec.equipLoc == "INVTYPE_NECK" or rec.equipLoc == "INVTYPE_FINGER"
            or rec.equipLoc == "INVTYPE_TRINKET" or rec.equipLoc == "INVTYPE_HOLDABLE" then return true end
        if s == 0 then return true end
        if s == 4 then return ref.plateAt ~= nil and LEVEL + (GP.Setting("ahead") or 5) >= ref.plateAt end
        if s == 3 and ref.mailAt then return LEVEL + (GP.Setting("ahead") or 5) >= ref.mailAt end
        return ref.a[s] == true
    end
    return false
end
local tiers = { primary = 0, secondary = 0, locked = 0 }
local train = {}
for _, ev in ipairs(res.all or {}) do
    if ev.tier then
        tiers[ev.tier] = tiers[ev.tier] + 1
        local rec = ev.rec
        if not canUse(rec) then bad(ev, "class can't use this type (" .. rec.classID .. "/" .. rec.subClassID .. ")") end
        if (rec.reqLevel or 0) > LEVEL + (GP.Setting("ahead") or 5) then bad(ev, "too high a level " .. rec.reqLevel) end
        if ev.tier == "primary" and (ev.req or 0) > LEVEL + (GP.Setting("soon") or 2) then bad(ev, "Best now but needs level " .. ev.req) end
        if ev.slot == "SecondaryHandSlot" and rec.equipLoc == "INVTYPE_WEAPON" and not (DW[CLASS] and LEVEL >= DW[CLASS]) then
            bad(ev, "a one-hander in the off hand without Dual Wield")
        end
        if rec.equipLoc == "INVTYPE_SHIELD" and not ref.a[6] then bad(ev, "a shield") end
        if rec.equipLoc == "INVTYPE_RELIC" and not ref.a[rec.subClassID] then bad(ev, "another class's relic") end
        local src = ev.source
        if src and src.kind == "vendor" and src.id then
            local f = DB.Npc.friendlyToFaction(src.id)
            if f and f ~= "AH" and f ~= (FACTION == "Horde" and "H" or "A") then bad(ev, "vendor of the other faction: " .. tostring(src.name)) end
        end
        -- Faction rules (0.7.6), checked on their own: no quest only the other
        -- faction's people give or its race list leaves you out of, no drop
        -- from your own faction's people, nothing in the other faction's home
        -- zones as Best now (zone area ids, not GearPath's map ids).
        local mine, other = FACTION == "Horde" and "H" or "A", FACTION == "Horde" and "A" or "H"
        if src and src.kind == "quest" and src.id and DB.Quest.name(src.id) then
            local races = DB.Quest.requiredRaces(src.id)
            local mask = DB.Enum.raceMaskById[race[2]]
            if races and races ~= 0 and mask and math.floor(races / mask) % 2 == 0 then bad(ev, "a quest for other races: " .. tostring(src.name)) end
            local sb = DB.Quest.startedBy(src.id)
            local npcs = type(sb) == "table" and sb[1]
            local onlyOther = type(npcs) == "table" and #npcs > 0 and not (type(sb[2]) == "table" and #sb[2] > 0) and not (type(sb[3]) == "table" and #sb[3] > 0)
            if onlyOther then
                for _, n in ipairs(npcs) do if DB.Npc.friendlyToFaction(n) ~= other then onlyOther = false end end
            end
            if onlyOther then bad(ev, "a quest only the other faction gives: " .. tostring(src.name)) end
        end
        if src and src.kind == "drop" and src.id and not src.journal and DB.Npc.friendlyToFaction(src.id) == mine then
            bad(ev, "a drop from your own faction's people: " .. tostring(src.name))
        end
        local HOME_AREAS = FACTION == "Horde" and { [1] = 1, [12] = 1, [38] = 1, [40] = 1, [44] = 1, [141] = 1, [148] = 1, [1519] = 1, [1537] = 1, [1657] = 1 }
            or { [14] = 1, [17] = 1, [85] = 1, [130] = 1, [215] = 1, [1497] = 1, [1637] = 1, [1638] = 1 }
        local neutral = src and (src.kind == "vendor" or (src.giverID and DB.Npc.friendlyToFaction(src.giverID) == "AH"))
        if ev.tier == "primary" and src and not src.dungeon and not neutral and src.areaId and HOME_AREAS[src.areaId] then
            bad(ev, "Best now in the other faction's home zone: " .. tostring(src.zone))
        end
        -- Best now in a zone 10+ levels above you (area ids, not GearPath's table).
        local AREA_MIN = { [33] = 30, [36] = 30, [45] = 30, [405] = 30, [400] = 25, [267] = 20, [11] = 20, [10] = 18,
            [331] = 18, [406] = 15, [44] = 15, [15] = 35, [3] = 35, [8] = 35, [357] = 40, [47] = 40, [440] = 40, [51] = 43,
            [16] = 45, [4] = 45, [490] = 48, [361] = 48, [46] = 50, [28] = 51, [139] = 53, [618] = 55, [41] = 55, [1377] = 55 }
        if ev.tier == "primary" and src and not src.dungeon and src.areaId and AREA_MIN[src.areaId] and AREA_MIN[src.areaId] >= LEVEL + 10 then
            bad(ev, "Best now in a zone far above you: " .. tostring(src.zone))
        end
        for _, n in ipairs(ev.train or {}) do train[n.name] = (train[n.name] or 0) + 1 end
    end
end
-- The route: one pick per slot (two for rings and trinkets), no item twice.
local seen, perGroup = {}, {}
for _, ev in ipairs(res.plan.picks) do
    if seen[ev.rec.id] then bad(ev, "picked twice on the route") end
    seen[ev.rec.id] = true
    local g = GP.Slots.GROUP[ev.slot] or ev.slot
    perGroup[g] = (perGroup[g] or 0) + 1
    local max = GP.Slots.BY_KEY[g].pair and 2 or 1
    if perGroup[g] > max then bad(ev, "too many picks for " .. g) end
end
-- POST=file: a script run once the list is scored, given GP and the results
-- (for one-off questions about the real data).
if (os.getenv("POST") or "") ~= "" then assert(loadfile(os.getenv("POST")))(GP, res, H) end
local trained = {}
for name, n in pairs(train) do trained[#trained + 1] = name .. " " .. n end
table.sort(trained)
print(string.format("%-14s %-8s %2d | gear %4d | now %3d chase %3d needs %2d | route %2d picks in %2d places | train: %s | problems %d",
    CLASS:sub(1, 3) .. ":" .. (GP.Classes.Spec().key or "?"), FACTION, LEVEL, GP.Sources.counts.candidates, tiers.primary, tiers.secondary, tiers.locked,
    #res.plan.picks, #res.plan.zones, #trained > 0 and table.concat(trained, ", ") or "-", #problems))
for i = 1, math.min(#problems, VERBOSE and 40 or 6) do print("    ! " .. problems[i]) end
if VERBOSE then
    for _, ev in ipairs(res.plan.picks) do
        print(string.format("    %-12s %-34s %s", GP.Slots.Label(ev.slot), ev.rec.name, GP.UI.Describe(ev.source)))
    end
end
for i = 1, math.min(3, #H.errors) do print("    error: " .. tostring(H.errors[i]):match("^[^\n]*")) end
