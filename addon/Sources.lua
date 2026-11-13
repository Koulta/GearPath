-- Sources: every piece of gear you could get and where it comes from.
--
-- The list is read from QuestieDB (installed with Questie), which carries
-- WoW: Forever's own items, quests, NPCs and their locations; items in your
-- bags and what you've seen in game yourself (Learn.lua) are added to it.
-- Nothing here reads combat data, so none of it is touched by Forever's
-- addon restrictions.

local _, GP = ...

local Sources = {}
GP.Sources = Sources

local Classes, Items = GP.Classes, GP.Items

Sources.entries = {}          -- [itemID] = entry (see newEntry)
Sources.status = "idle"       -- idle, nodb, scanning, loading, ready
Sources.counts = { db = 0, candidates = 0, loaded = 0 }
Sources.questItems = {}       -- [questID] = { itemID, ... } (to refresh when a quest is done)

Sources.CONTRACT = 4          -- the QuestieDB contract this was written against
Sources.LOWER = 15            -- items more than this many levels below you are skipped
Sources.WORLD_DROP = 8        -- dropped by more NPCs than this = a random world drop

-- ---------------------------------------------------------------------
-- QuestieDB
-- ---------------------------------------------------------------------

local DB          -- LibQuestieDB, when it's installed and compatible

function Sources.Database()
    if DB ~= nil then return DB or nil end
    local lib = rawget(_G, "LibQuestieDB")
    if type(lib) ~= "table" or type(lib.Item) ~= "table" or type(lib.Quest) ~= "table" then
        DB = false
        return nil
    end
    if type(lib.RequireContract) == "function" then
        local ok = lib.RequireContract(Sources.CONTRACT)
        if not ok and not lib.RequireContract(1) then
            GP.Print("Your QuestieDB is a version GearPath doesn't know. Update GearPath or QuestieDB.")
            DB = false
            return nil
        end
    end
    DB = lib
    return DB
end

local function field(entity, name, id)
    local fn = entity and entity[name]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, id)
    if ok then return v end
    return nil
end
Sources.Field = field

-- ---------------------------------------------------------------------
-- Zones and dungeons
-- ---------------------------------------------------------------------

-- (QuestieDB's zone tables are read, checked and backed up by the game's
-- own maps in ZoneData.lua.)
function Sources.MapForArea(areaId)
    return GP.ZoneData and GP.ZoneData.MapForArea(areaId) or nil
end

function Sources.Dungeon(areaId)
    return GP.ZoneData and GP.ZoneData.Dungeon(areaId) or nil
end

local zoneNames = {}
function Sources.ZoneName(areaId, mapID)
    if areaId and zoneNames[areaId] then return zoneNames[areaId] end
    local name
    if areaId and C_Map and C_Map.GetAreaInfo then
        local ok, n = pcall(C_Map.GetAreaInfo, areaId)
        if ok and type(n) == "string" and n ~= "" then name = n end
    end
    if not name and mapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        name = info and info.name
    end
    if areaId and name then zoneNames[areaId] = name end
    return name
end

-- A dungeon's entrance out in the world, by its name, as the database has
-- it: { mapID, x, y, zone }, or nil. (The Dungeon Journal knows each wing's
-- own door and the way in; Waypoint.Entrance asks it first.)
local entranceByName
function Sources.DungeonEntrance(name)
    if type(name) ~= "string" then return nil end
    if not entranceByName then
        entranceByName = {}
        for _, d in pairs(GP.ZoneData and GP.ZoneData.Dungeons() or {}) do
            local e = type(d[4]) == "table" and d[4][1]
            if type(d[1]) == "string" and type(e) == "table" and type(e[2]) == "number" and not entranceByName[d[1]] then
                local mapID = Sources.MapForArea(e[1])
                if mapID then
                    entranceByName[d[1]] = { mapID = mapID, x = e[2] / 100, y = e[3] / 100,
                        zone = Sources.ZoneName(e[1], mapID) }
                end
            end
        end
    end
    -- Not in QuestieDB's table (or the table was set aside): the game's own.
    return entranceByName[name] or (GP.ZoneData and GP.ZoneData.GameEntrance(name)) or nil
end
GP.On("RescanRequested", function() entranceByName = nil end)

function Sources.MapName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

-- The continent a map is on (its map id), or nil when the game can't say.
local CONTINENT = 2   -- Enum.UIMapType.Continent
local continentOf = {}
-- Islands the game's maps put on no continent, each a land of its own:
-- Zephras Isle, the Skyborne's starting zone, reached by airship from
-- Mulgore or Alterac (its gear showed as Best now for an Undead in Tirisfal).
local ISLANDS = { [2521] = true }

function Sources.Continent(mapID)
    if type(mapID) ~= "number" or not (C_Map and C_Map.GetMapInfo) then return nil end
    local known = continentOf[mapID]
    if known then return known end
    local id, found, steps = mapID, false, 0
    while type(id) == "number" and id > 0 and steps < 8 do
        if ISLANDS[id] then found = id break end
        local ok, info = pcall(C_Map.GetMapInfo, id)
        if not (ok and type(info) == "table") then break end
        if info.mapType == CONTINENT then found = id break end
        id, steps = info.parentMapID, steps + 1
    end
    if found then continentOf[mapID] = found end   -- only answers found are kept
    return found or nil
end

-- The zone a map is in (the map itself if it's a zone; a town's zone).
local ZONE = 3   -- Enum.UIMapType.Zone
function Sources.Zone(mapID)
    if type(mapID) ~= "number" or not (C_Map and C_Map.GetMapInfo) then return nil end
    local id, steps = mapID, 0
    while type(id) == "number" and id > 0 and steps < 8 do
        local ok, info = pcall(C_Map.GetMapInfo, id)
        if not (ok and type(info) == "table") then return nil end
        if info.mapType == ZONE then return id end
        if info.mapType and info.mapType < ZONE then return nil end   -- a continent or the world
        id, steps = info.parentMapID, steps + 1
    end
    return nil
end

-- The zone you're in, or nil.
function Sources.PlayerZone()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
    return ok and Sources.Zone(GP.Plain(map)) or nil
end

-- Orders an item's ways to get it: the easiest first; just as easy, one in
-- the zone you're in, then your continent, then across the sea (launch
-- night: a Young Wolf in Elwynn was listed before Muad in Tirisfal for an
-- Undead standing in Tirisfal); then one in your quest log; then the lowest.
function Sources.SortSources(list)
    local Score = GP.Score
    local here, hereZone = Sources.PlayerContinent(), Sources.PlayerZone()
    local function far(s)
        if hereZone and s.mapID and Sources.Zone(s.mapID) == hereZone then return 0 end
        local c = here and s.mapID and Sources.Continent(s.mapID)
        if c ~= nil and c ~= here then return 2 end
        return Sources.EnemyLand(s) and 1.5 or 1
    end
    table.sort(list, function(a, b)
        local ea, eb = Score.Effort(a), Score.Effort(b)
        if ea ~= eb then return ea < eb end
        local fa, fb = far(a), far(b)
        if fa ~= fb then return fa < fb end
        if (a.inLog == true) ~= (b.inLog == true) then return a.inLog == true end
        return (a.level or a.reqLevel or 0) < (b.level or b.reqLevel or 0)
    end)
end

-- Moving to another zone changes what's nearest: re-order every item's
-- ways to get it (no new scan) and score again.
function Sources.Resort()
    for _, entry in pairs(Sources.entries or {}) do
        local all = entry.allSources or entry.sources
        if all and #all > 1 then
            Sources.SortSources(all)
            Sources.Visible(entry)
        end
    end
end

-- Leaves out the vendors you hid (Hide.lua): entry.sources is what's left,
-- entry.allSources everything. entry.hiddenAll: every way was hidden.
function Sources.Visible(entry)
    local all = entry.allSources or entry.sources or {}
    entry.allSources = all
    local Hide = GP.Hide
    local list = all
    if Hide and Hide.Any() then
        list = {}
        for _, s in ipairs(all) do
            if not Hide.IsVendor(s) then list[#list + 1] = s end
        end
    end
    entry.sources = list
    entry.best = list[1]
    entry.effort = GP.Score.Effort(entry.best)
    entry.hiddenAll = #all > 0 and #list == 0
end

-- After hiding or showing a vendor: every item's ways again (no new scan).
function Sources.ApplyHidden()
    for _, entry in pairs(Sources.entries or {}) do
        if entry.allSources or entry.sources then Sources.Visible(entry) end
    end
end

-- The continent you're on, or nil (in an instance, or the game can't say).
function Sources.PlayerContinent()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
    return ok and Sources.Continent(GP.Plain(map)) or nil
end

-- QuestieDB rebuilds an NPC's or object's spawn list on every read, and
-- some of Forever's mobs have thousands of spawns (tens of milliseconds a
-- read). What GearPath needs from the list, the first spot in each zone and
-- how many there are, is kept for the session: one read per NPC or object.
local spawnInfo = { npc = {}, object = {} }
local function spawnSummary(kind, id)
    if id == nil then return nil end
    local cache = spawnInfo[kind]
    local s = cache[id]
    if s ~= nil then return s or nil end
    local spawns = field(kind == "npc" and DB.Npc or DB.Object, "spawns", id)
    if type(spawns) ~= "table" then
        cache[id] = false
        return nil
    end
    s = { order = {}, at = {}, count = 0 }
    for area, list in pairs(spawns) do
        s.order[#s.order + 1] = area
        if type(list) == "table" then
            s.count = s.count + #list
            local c = list[1]
            if type(c) == "table" and type(c[1]) == "number" and c[1] >= 0 then
                s.at[area] = { c[1] / 100, c[2] / 100 }
            end
        end
    end
    cache[id] = s
    return s
end
Sources.SpawnSummary = spawnSummary

-- The first spawn of an NPC or object (its summary), preferring the given
-- zone: areaId, x, y (0-1), or nil.
local function firstSpawn(s, preferArea)
    if not s or #s.order == 0 then return nil end
    local p = preferArea and s.at[preferArea]
    if p then return preferArea, p[1], p[2] end
    for _, area in ipairs(s.order) do
        local q = s.at[area]
        if q then return area, q[1], q[2] end
    end
    -- Inside a dungeon (-1, -1): the dungeon's area, no point.
    return s.order[1], nil, nil
end

-- A place: { areaId, mapID, x, y, zone, dungeon (name) }. A dungeon's
-- place points at its entrance.
local function place(areaId, x, y)
    local p = { areaId = areaId, x = x, y = y }
    local d = Sources.Dungeon(areaId)
    if d then
        p.dungeon = d[1]
        local entrance = type(d[4]) == "table" and d[4][1]
        if type(entrance) == "table" then
            p.areaId, p.x, p.y = entrance[1], entrance[2] / 100, entrance[3] / 100
        else
            p.areaId, p.x, p.y = d[3], nil, nil
        end
    end
    p.mapID = p.areaId and Sources.MapForArea(p.areaId)
    p.zone = Sources.ZoneName(p.areaId, p.mapID)
    return p
end
Sources.Place = place

local function copyPlace(dst, p)
    if not p then return dst end
    dst.areaId, dst.mapID, dst.x, dst.y, dst.zone = p.areaId, p.mapID, p.x, p.y, p.zone
    dst.dungeon = dst.dungeon or p.dungeon
    return dst
end

-- ---------------------------------------------------------------------
-- Who you are: race, class and faction, for what's available to you
-- ---------------------------------------------------------------------

local function myRaceMask()
    local p = GP.player or GP.PlayerInfo()
    return DB and DB.Enum and DB.Enum.raceMaskById and DB.Enum.raceMaskById[p.raceID]
end

local function myClassMask()
    local p = GP.player or GP.PlayerInfo()
    return DB and DB.Enum and DB.Enum.classKeys and DB.Enum.classKeys[p.class]
end

local function myFactionLetter()
    local f = (GP.player or GP.PlayerInfo()).faction
    return f == "Horde" and "H" or "A"
end

local function friendly(npcID)
    local f = field(DB.Npc, "friendlyToFaction", npcID)
    if f == nil then return false end
    return f == "AH" or f == myFactionLetter()
end

-- The other faction's letter ("A" for a Horde player).
local function otherFactionLetter()
    return myFactionLetter() == "H" and "A" or "H"
end

-- A quest only the other faction's people hand out (Owen Thadd in the
-- Undercity for an Alliance player), whatever its race list says. Only a
-- giver marked as the other faction's counts: QuestieDB marks plenty of
-- hostile beasts "AH", so that mark says nothing.
local function giversOtherFaction(q)
    local started = field(DB.Quest, "startedBy", q)
    if type(started) ~= "table" then return false end
    local npcs, objects, items = started[1], started[2], started[3]
    if (type(objects) == "table" and #objects > 0) or (type(items) == "table" and #items > 0) then return false end
    if type(npcs) ~= "table" or #npcs == 0 then return false end
    local other = otherFactionLetter()
    for _, npc in ipairs(npcs) do
        if field(DB.Npc, "friendlyToFaction", npc) ~= other then return false end
    end
    return true
end

function Sources.QuestAvailable(q)
    if not DB or not field(DB.Quest, "name", q) then return false end
    local races = field(DB.Quest, "requiredRaces", q)
    local race = myRaceMask()
    if races and races ~= 0 and race and not GP.HasBit(races, race) then return false end
    local classes = field(DB.Quest, "requiredClasses", q)
    local class = myClassMask()
    if classes and classes ~= 0 and class and not GP.HasBit(classes, class) then return false end
    if giversOtherFaction(q) then return false end
    return true
end

-- Whether QuestieDB has a quest and says it isn't for you (another
-- faction's, race's or class's). A quest it doesn't have: false.
function Sources.QuestNotForYou(q)
    q = tonumber(q)
    if not (DB and q and field(DB.Quest, "name", q)) then return false end
    return not Sources.QuestAvailable(q)
end

-- Each faction's home ground: its starting zones, the zones next to them
-- and its capitals (the game's map ids, the same in Forever). A quest out
-- there is a trip into enemy land for the other faction: never "Best now".
local HOME = {
    Horde = { [1411] = true, [1412] = true, [1413] = true, [1420] = true, [1421] = true,
        [1454] = true, [1456] = true, [1458] = true },
    Alliance = { [1426] = true, [1429] = true, [1432] = true, [1433] = true, [1436] = true,
        [1438] = true, [1439] = true, [1453] = true, [1455] = true, [1457] = true },
}
Sources.HOME = HOME
local zoneCache = {}   -- map id -> its zone (these checks run inside sorts)
local function zoneOf(mapID)
    local z = zoneCache[mapID]
    if z == nil then z = Sources.Zone(mapID) or mapID; zoneCache[mapID] = z end
    return z
end

function Sources.EnemyLand(src)
    if not src or src.dungeon or type(src.mapID) ~= "number" then return false end
    -- A neutral town or giver out there is fine (Ratchet in the Barrens,
    -- the Darkmoon Faire in Elwynn): a vendor GearPath lists is one who
    -- deals with you, and a quest giver marked for both factions is neutral.
    if src.kind == "vendor" or src.kind == "craft" then return false end
    if src.giverID and DB and field(DB.Npc, "friendlyToFaction", src.giverID) == "AH" then return false end
    local f = (GP.player or GP.PlayerInfo()).faction
    local enemy = (f == "Horde" and HOME.Alliance) or (f == "Alliance" and HOME.Horde) or nil
    if not enemy then return false end
    return enemy[zoneOf(src.mapID)] == true
end

-- The lowest level each zone is for (the game's map ids). A quest or vendor
-- in a zone 10 or more levels above you is a trip, not Best now (launch
-- night: Surfer Shoes from Jang in Booty Bay, Stranglethorn, for a level 8).
local ZONE_MIN = {
    [1413] = 10, [1421] = 10, [1436] = 10, [1432] = 10, [1439] = 10, [1433] = 15, [1442] = 15,
    [1440] = 18, [1431] = 18, [1424] = 20, [1437] = 20, [1441] = 25, [1416] = 30, [1417] = 30,
    [1443] = 30, [1434] = 30, [1445] = 35, [1418] = 35, [1435] = 35, [1444] = 40, [1425] = 40,
    [1446] = 40, [1427] = 43, [1447] = 45, [1419] = 45, [1449] = 48, [1448] = 48, [1428] = 50,
    [1422] = 51, [1423] = 53, [1452] = 55, [1430] = 55, [1451] = 55,
}
Sources.ZONE_MIN = ZONE_MIN

function Sources.ZoneTooHigh(src, level)
    if not src or src.dungeon or type(src.mapID) ~= "number" then return false end
    level = level or (GP.player or GP.PlayerInfo()).level or 1
    local min = ZONE_MIN[zoneOf(src.mapID)]
    return min ~= nil and min >= level + 10
end

local function questDone(q)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q) == true
end
Sources.QuestDone = questDone

local function questInLog(q)
    return C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(q) ~= nil
end

-- ---------------------------------------------------------------------
-- Resolving one source
-- ---------------------------------------------------------------------

-- Where a quest is picked up: the giver's name and place.
local function questStart(q)
    local started = field(DB.Quest, "startedBy", q)
    local zoneArea = field(DB.Quest, "zoneOrSort", q)
    if type(zoneArea) ~= "number" or zoneArea <= 0 then zoneArea = nil end
    local out = {}
    if type(started) == "table" then
        local npcs, objects, items = started[1], started[2], started[3]
        if type(npcs) == "table" then
            for _, npc in ipairs(npcs) do
                if friendly(npc) or #npcs == 1 then
                    out.giver = field(DB.Npc, "name", npc)
                    out.giverID = npc
                    local area, x, y = firstSpawn(spawnSummary("npc", npc), zoneArea)
                    copyPlace(out, place(area or field(DB.Npc, "zoneID", npc) or zoneArea, x, y))
                    break
                end
            end
        end
        if not out.giver and type(objects) == "table" and objects[1] then
            out.giver = field(DB.Object, "name", objects[1])
            local area, x, y = firstSpawn(spawnSummary("object", objects[1]), zoneArea)
            copyPlace(out, place(area or field(DB.Object, "zoneID", objects[1]) or zoneArea, x, y))
        end
        if not out.giver and type(items) == "table" and items[1] then
            out.startItem = field(DB.Item, "name", items[1])
            out.giver = out.startItem and ("the item " .. out.startItem) or nil
        end
    end
    if not out.zone and zoneArea then copyPlace(out, place(zoneArea)) end
    return out
end

-- The quests before this one you haven't done yet, first to last.
local function chainBefore(q)
    local chain, seen, cur = {}, { [q] = true }, q
    for _ = 1, 15 do
        local single = field(DB.Quest, "preQuestSingle", cur)
        local group = field(DB.Quest, "preQuestGroup", cur)
        local nextQ
        if type(single) == "table" and #single > 0 then
            -- Any one of these opens it: done if one is.
            local anyDone = false
            for _, p in ipairs(single) do if questDone(p) then anyDone = true break end end
            if not anyDone then
                for _, p in ipairs(single) do
                    if not seen[p] and Sources.QuestAvailable(p) then nextQ = p break end
                end
            end
        elseif type(group) == "table" and #group > 0 then
            for _, p in ipairs(group) do
                if not seen[p] and not questDone(p) and Sources.QuestAvailable(p) then nextQ = p break end
            end
        end
        if not nextQ then break end
        seen[nextQ] = true
        table.insert(chain, 1, nextQ)
        cur = nextQ
    end
    return chain
end

local function questSource(q)
    if not Sources.QuestAvailable(q) then return nil end
    local s = {
        kind = "quest", id = q,
        name = field(DB.Quest, "name", q),
        level = field(DB.Quest, "questLevel", q),
        reqLevel = field(DB.Quest, "requiredLevel", q),
        done = questDone(q),
        inLog = questInLog(q),
    }
    local start = questStart(q)
    s.giver, s.giverID, s.startItem = start.giver, start.giverID, start.startItem
    copyPlace(s, start)
    local zoneArea = field(DB.Quest, "zoneOrSort", q)
    if type(zoneArea) == "number" and zoneArea > 0 then
        local d = Sources.Dungeon(zoneArea)
        if d then s.dungeon = d[1] end
    end
    if not s.done then
        local chain = chainBefore(q)
        if #chain > 0 then
            s.chain = {}
            for i, cq in ipairs(chain) do
                s.chain[i] = { id = cq, name = field(DB.Quest, "name", cq), level = field(DB.Quest, "questLevel", cq) }
            end
            s.chainLength = #chain + 1
            -- The trip starts where the chain does.
            local first = questStart(chain[1])
            s.chainStart = copyPlace({ giver = first.giver, giverID = first.giverID, name = s.chain[1].name }, first)
        end
    end
    return s
end

local RANK = { [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }

local function dropSource(npc)
    -- Your own faction's people (a Hillsbrad Farmer for an Alliance
    -- player): you can't attack them.
    if field(DB.Npc, "friendlyToFaction", npc) == myFactionLetter() then return nil end
    local s = { kind = "drop", id = npc, name = field(DB.Npc, "name", npc) }
    s.level = field(DB.Npc, "maxLevel", npc) or field(DB.Npc, "minLevel", npc)
    s.minLevel = field(DB.Npc, "minLevel", npc)
    local rank = field(DB.Npc, "rank", npc)
    s.rank = RANK[rank or 0]
    s.elite = rank == 1 or rank == 2 or rank == 3
    local area, x, y = firstSpawn(spawnSummary("npc", npc))
    copyPlace(s, place(area or field(DB.Npc, "zoneID", npc), x, y))
    return s
end

local function vendorSource(npc)
    if not friendly(npc) then return nil end
    local s = { kind = "vendor", id = npc, name = field(DB.Npc, "name", npc) }
    local area, x, y = firstSpawn(spawnSummary("npc", npc))
    copyPlace(s, place(area or field(DB.Npc, "zoneID", npc), x, y))
    return s
end

Sources.RANDOM_CHEST = 8      -- an object with more spawns than this is a random chest
Sources.RANDOM_OBJECTS = 3    -- an item in more kinds of object than this is random chest loot

local function objectSource(obj)
    local s = { kind = "object", id = obj, name = field(DB.Object, "name", obj) }
    local spawns = spawnSummary("object", obj)
    -- "Solid Chest" and the like spawn all over and hold random loot: as
    -- hard to aim for as a world drop. So is anything with no known spot.
    local name = s.name or ""
    local generic = name:find("Solid Chest$") or name:find("Battered Chest$") or name:find("Tattered Chest$")
        or name:find("Bound Chest$") or name:find("Footlocker$")
    local n = spawns and spawns.count or 0
    if n > Sources.RANDOM_CHEST or n == 0 or generic then
        s.worldDrop = true
        s.randomChest = true
        return s
    end
    local area, x, y = firstSpawn(spawns)
    copyPlace(s, place(area or field(DB.Object, "zoneID", obj), x, y))
    return s
end

-- What you've seen in game yourself (Learn.lua).
-- Your skill in a profession ("Tailoring"), or nil when you don't have it.
function Sources.ProfessionSkill(prof)
    if not (GetNumSkillLines and GetSkillLineInfo) then return nil end
    for i = 1, GP.Plain(GetNumSkillLines()) or 0 do
        local name, header, _, rank = GetSkillLineInfo(i)
        name, rank = GP.Plain(name), GP.Plain(rank)
        if not header and name == prof then return type(rank) == "number" and rank or 0 end
    end
    return nil
end

-- The nearest of some places: in your zone, then on your continent, then
-- anywhere; nil for an empty list.
local function nearestOf(list)
    local here, hereZone = Sources.PlayerContinent(), Sources.PlayerZone()
    local best, bestRank
    for _, s in ipairs(list) do
        local rank = 3
        if s.mapID then
            if hereZone and Sources.Zone(s.mapID) == hereZone then rank = 0
            elseif here and Sources.Continent(s.mapID) == here then rank = 1
            else rank = 2 end
        end
        if not best or rank < bestRank then best, bestRank = s, rank end
    end
    return best
end

-- An NPC of your faction (or anyone's) and where it stands, from QuestieDB:
-- { id, name, mapID, x, y, zone }, or nil.
local function friendlyNpcAt(npc)
    if not (DB and type(npc) == "number" and friendly(npc)) then return nil end
    local s = { id = npc, name = field(DB.Npc, "name", npc) }
    local area, x, y = firstSpawn(spawnSummary("npc", npc))
    copyPlace(s, place(area or field(DB.Npc, "zoneID", npc), x, y))
    return s
end

local function nearestFriendly(list)
    local found = {}
    for _, n in ipairs(list or {}) do
        local s = friendlyNpcAt(type(n) == "table" and n.id or n)
        if s then found[#found + 1] = s end
    end
    return nearestOf(found)
end

-- How to learn a recipe ProfessionDB knows (r = GP.Crafts.RecipesFor's
-- entry): { via = "trainer" | "vendor" | "quest" | "drop" | "random", npc,
-- name, count }, or nil when nothing says. A recipe item's own sources in
-- QuestieDB (Forever's) come before ProfessionDB's lists, which for Forever
-- are Vanilla's.
local function recipeWay(r)
    local src = r.sources
    if src and src.trainer then
        local npc = nearestFriendly(src.trainer)
        return { via = "trainer", npc = npc }
    end
    if DB and r.item then
        local npc = nearestFriendly(field(DB.Item, "vendors", r.item))
        if npc then return { via = "vendor", npc = npc } end
        for _, q in ipairs(field(DB.Item, "questRewards", r.item) or {}) do
            local qs = questSource(q)
            if qs then return { via = "quest", name = qs.name, quest = qs } end
        end
        local drops = field(DB.Item, "npcDrops", r.item)
        if type(drops) == "table" and #drops > 0 then
            if #drops > Sources.WORLD_DROP then return { via = "random" } end
            local list = {}
            for _, n in ipairs(drops) do
                local d = dropSource(n)
                if d then list[#list + 1] = d end
            end
            local d = nearestOf(list)
            if d then return { via = "drop", npc = d, count = #drops } end
        end
        local objs = field(DB.Item, "objectDrops", r.item)
        if type(objs) == "table" and #objs > 0 then return { via = "random" } end
    end
    -- (Without QuestieDB there's no telling whose side an NPC is on: no
    -- names then, only the kind.)
    if src and src.vendor then
        local npc = nearestFriendly(src.vendor)
        if npc or not DB then return { via = "vendor", npc = npc } end
    end
    if src and src.quest then return { via = "quest" } end
    if src and src.drop and (src.drop.total or #src.drop) <= Sources.WORLD_DROP then
        local l = {}
        for _, n in ipairs(src.drop) do
            local d = DB and dropSource(n.id)
            if d then l[#l + 1] = d end
        end
        local npc = nearestOf(l)
        if npc or not DB then return { via = "drop", npc = npc, count = src.drop.total or #src.drop } end
    end
    if src and (src.drop or src.container) then return { via = "random" } end
    return nil
end
Sources.RecipeWay = recipeWay

-- A crafted item's way in, for this character, one per profession:
-- info = what you've seen yourself (Learn.lua: whether you know the recipe,
-- the skill a trainer asked for and where that trainer stands); r = what
-- ProfessionDB says (GP.Crafts). You know the recipe; or you can learn it
-- now; or it takes more skill first. nil: not one of your professions, or
-- nothing to go on.
function Sources.CraftSource(prof, info, r)
    local skill = Sources.ProfessionSkill(prof)
    if not skill then return nil end
    if type(info) ~= "table" then info = nil end
    if not info and not r then return nil end
    local known = (info and type(info.k) == "table" and info.k[GP.Learn.Me()] == true)
        or (r and (r.auto or (GP.Crafts and GP.Crafts.Known(r.spell)))) or false
    local s = { kind = "craft", id = prof, name = prof, profession = prof, known = known,
        learned = info ~= nil, spell = r and r.spell }
    if known then
        s.zone = "Craft it yourself"
        return s
    end
    -- The skill it takes: a trainer's own number; else ProfessionDB's,
    -- unconfirmed ("Tailoring (75?)": its numbers run high for Forever).
    local rank, sure = info and info.r, true
    if type(rank) ~= "number" then rank, sure = r and r.rank, false end
    if type(rank) == "number" then
        s.rank, s.rankSure = rank, sure
        if skill < rank then s.needs = string.format(sure and "%s (%d)" or "%s (%d?)", prof, rank) end
    end
    -- Where to learn it: the trainer you saw it at; else ProfessionDB.
    if info and info.t then
        s.via, s.npcName = "trainer", info.t
        if info.m then
            s.mapID, s.x, s.y = info.m, info.x, info.y
            s.zone = Sources.MapName(info.m)
        end
        return s
    end
    local way = r and recipeWay(r)
    if not way then
        -- Seen only in another character's profession window, or nothing
        -- known about it at all: nothing to send you to.
        if not r then return nil end
        return s
    end
    s.via, s.count = way.via, way.count
    local npc = way.npc
    if npc then
        s.npcName, s.npcID = npc.name, npc.id
        s.mapID, s.x, s.y, s.zone, s.dungeon = npc.mapID, npc.x, npc.y, npc.zone, npc.dungeon
    else
        s.npcName = way.name
    end
    return s
end

-- Every craft way in for an item: what you've seen in game merged with
-- ProfessionDB, one per profession (the lowest skill, when two recipes in
-- one profession make it).
function Sources.CraftSourcesFor(id)
    local out = {}
    local L = GP.db and GP.db.learned and GP.db.learned.items and GP.db.learned.items[id]
    local seen = type(L) == "table" and type(L.c) == "table" and L.c or nil
    local byProf = {}
    for _, r in ipairs(GP.Crafts and GP.Crafts.RecipesFor(id) or {}) do
        local cur = byProf[r.prof]
        if not cur or (r.rank or 9999) < (cur.rank or 9999) then byProf[r.prof] = r end
    end
    local profs = {}
    for prof in pairs(byProf) do profs[prof] = true end
    for prof in pairs(seen or {}) do profs[prof] = true end
    for prof in pairs(profs) do
        local s = Sources.CraftSource(prof, seen and seen[prof], byProf[prof])
        if s then out[#out + 1] = s end
    end
    return out
end

local function learnedSources(id)
    local out = {}
    local L = GP.db and GP.db.learned and GP.db.learned.items and GP.db.learned.items[id]
    if type(L) ~= "table" then return out end
    for q, info in pairs(L.q or {}) do
        if not questDone(q) then
            out[#out + 1] = { kind = "quest", id = q, name = info.n, giver = info.g, mapID = info.m, x = info.x, y = info.y,
                zone = Sources.MapName(info.m), learned = true, choice = info.c, inLog = questInLog(q),
                level = info.l }
        end
    end
    for key, info in pairs(L.v or {}) do
        out[#out + 1] = { kind = "vendor", id = key, name = info.n, mapID = info.m, x = info.x, y = info.y,
            zone = Sources.MapName(info.m), learned = true }
    end
    for key, info in pairs(L.d or {}) do
        out[#out + 1] = { kind = "drop", id = key, name = info.n, mapID = info.m, x = info.x, y = info.y,
            zone = Sources.MapName(info.m), learned = true, dungeon = info.dg }
    end
    return out
end

local KIND_OF = { q = "quest", d = "drop", v = "vendor" }
local LIST_OF = { q = "questRewards", d = "npcDrops", v = "vendors" }
local ENTITY_OF = { q = "Quest", d = "Npc", v = "Npc" }

-- What other GearPath users reported (Share.lua).
local function sharedSources(id)
    local out = {}
    if not GP.Share then return out end
    local function known(kind, sid)
        if not DB then return false end
        for _, x in ipairs(field(DB.Item, LIST_OF[kind], id) or {}) do
            if x == sid then return true end
        end
        return false
    end
    for _, r in ipairs(GP.Share.SourcesFor(id, known)) do
        local s, kind = r.info, KIND_OF[r.kind]
        if kind and not (kind == "quest" and questDone(r.id)) then
            local name = (DB and field(DB[ENTITY_OF[r.kind]], "name", r.id)) or s.n
            -- A reported spot counts only on a map the game itself has.
            local zone = s.m and Sources.MapName(s.m) or nil
            local mapID, x, y = nil, nil, nil
            if zone then mapID, x, y = s.m, s.x, s.y end
            out[#out + 1] = { kind = kind, id = r.id, name = name or (kind == "quest" and ("Quest " .. r.id) or ("NPC " .. r.id)),
                mapID = mapID, x = x, y = y, zone = zone, learned = true, shared = true,
                reporters = s.c, dbKnown = r.known, inLog = kind == "quest" and questInLog(r.id) or nil }
        end
    end
    return out
end

-- Every source of an item, and the easiest one.
function Sources.Resolve(entry)
    local id = entry.id
    local list = {}
    if DB then
        for _, q in ipairs(field(DB.Item, "questRewards", id) or {}) do
            local s = questSource(q)
            if s then
                list[#list + 1] = s
                Sources.questItems[q] = Sources.questItems[q] or {}
                Sources.questItems[q][id] = true
                -- Its chain too: handing in an earlier quest moves where it starts.
                for _, c in ipairs(s.chain or {}) do
                    Sources.questItems[c.id] = Sources.questItems[c.id] or {}
                    Sources.questItems[c.id][id] = true
                end
            end
        end
        for _, npc in ipairs(field(DB.Item, "vendors", id) or {}) do
            local s = vendorSource(npc)
            if s then list[#list + 1] = s end
        end
        local drops = field(DB.Item, "npcDrops", id)
        if type(drops) == "table" and #drops > 0 then
            if #drops > Sources.WORLD_DROP then
                list[#list + 1] = { kind = "drop", worldDrop = true, name = "World drop", count = #drops }
            else
                for _, npc in ipairs(drops) do list[#list + 1] = dropSource(npc) end
            end
        end
        local objs = field(DB.Item, "objectDrops", id)
        if type(objs) == "table" and #objs > Sources.RANDOM_OBJECTS then
            -- In many kinds of chest ("Solid Chest", "Alliance Chest",
            -- "Horde Chest"...): random chest loot, not a place to go.
            local like
            for _, obj in ipairs(objs) do
                local n = field(DB.Object, "name", obj)
                if n and n:find("Chest") then like = n break end
                like = like or n
            end
            list[#list + 1] = { kind = "object", worldDrop = true, randomChest = true,
                name = like or "Chest", count = #objs }
        elseif type(objs) == "table" then
            for _, obj in ipairs(objs) do list[#list + 1] = objectSource(obj) end
        end
    end
    -- DungeonJournal, when installed: fills in what the database leaves out
    -- (where a boss is, which dungeon or wing a quest belongs to, whether a
    -- quest's rewards are pick-one) and adds what the database doesn't have.
    if GP.Journal and GP.Journal.Available() then
        for _, j in ipairs(GP.Journal.SourcesFor(id)) do
            local match
            for _, have in ipairs(list) do
                if have.kind == j.kind and not have.worldDrop and (
                    (j.kind == "quest" and have.id == j.id) or
                    (j.kind == "drop" and j.bossName and type(have.name) == "string" and have.name:lower() == j.bossName:lower())) then
                    match = have
                    break
                end
            end
            if match then
                match.journal = true
                match.dungeon = j.dungeon
                if not (match.mapID and match.x) then
                    match.mapID, match.x, match.y, match.zone = j.mapID, j.x, j.y, j.zone or match.zone
                end
                if j.kind == "quest" then
                    match.choice = j.choice
                    match.giver = match.giver or j.giver
                elseif not match.rank then
                    match.rank = j.rank
                end
            elseif not j.done and not (j.kind == "quest" and Sources.QuestNotForYou(j.id)) then
                -- (The journal called Important Heirlooms "Both"; QuestieDB
                -- knows it's an Alliance quest, given in Ironforge.)
                list[#list + 1] = j
            end
        end
    end

    -- Crafting: your professions (ProfessionDB, and what you've seen).
    for _, s in ipairs(Sources.CraftSourcesFor(id)) do list[#list + 1] = s end

    local seen = learnedSources(id)
    for _, s in ipairs(sharedSources(id)) do seen[#seen + 1] = s end
    for _, s in ipairs(seen) do
        -- A quest already known from the database keeps the database's richer copy.
        local dup = false
        for _, have in ipairs(list) do
            if have.kind == s.kind and have.id == s.id then
                dup = true
                if s.choice ~= nil then have.choice = s.choice end
                -- Other players saw it too: the database's copy is confirmed.
                if s.reporters then have.reporters = (have.reporters or 0) + s.reporters end
                if s.learned and not s.shared then have.seenByYou = true end
                break
            end
        end
        if not dup and not (s.kind == "quest" and Sources.QuestNotForYou(s.id)) then list[#list + 1] = s end
    end
    if entry.bags then
        table.insert(list, 1, { kind = "bags", name = "In your bags", zone = "In your bags" })
    end

    -- Quests already handed in can't give the item again.
    local usable = {}
    for _, s in ipairs(list) do
        if not (s.kind == "quest" and s.done) then usable[#usable + 1] = s end
    end
    Sources.SortSources(usable)
    entry.allSources = usable
    Sources.Visible(entry)
    entry.allDone = #list > 0 and #usable == 0
    return entry
end

-- ---------------------------------------------------------------------
-- Building the list
-- ---------------------------------------------------------------------

local function newEntry(id)
    return { id = id, sources = {}, usable = false }
end

-- Whether the class can (or soon can) use an item with this slot and type.
local function usableFor(classID, subClassID, equipLoc, level, ahead)
    if not GP.Slots.FOR_EQUIPLOC[equipLoc] then return false end
    local ok, _, opensAt = Classes.CanUse(classID, subClassID, equipLoc, nil, level)
    if ok then return true end
    if opensAt and opensAt <= level + ahead then return true, opensAt end
    return false
end

-- After the item's record arrives: limited to other classes?
local function finishEntry(entry, rec)
    entry.rec = rec
    if rec.classes then
        local mine = UnitClass("player")
        if not rec.classes[mine] then
            entry.usable = false
            return
        end
    end
    entry.usable = true
    Sources.counts.loaded = Sources.counts.loaded + 1
end

-- Items in your bags that you could wear.
function Sources.ScanBags()
    local level = (GP.player or GP.PlayerInfo()).level
    local ahead = GP.Setting("ahead") or 5
    local found = {}
    local getSlots = C_Container and C_Container.GetContainerNumSlots
    local getLink = C_Container and C_Container.GetContainerItemLink
    if not (getSlots and getLink) then return found end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (getSlots(bag) or 0) do
            local link = getLink(bag, slot)
            local id = link and Items.IDFromLink(link)
            if id and not found[id] then
                local equipLoc, classID, subClassID = Items.Instant(id)
                if equipLoc and usableFor(classID, subClassID, equipLoc, level, ahead) then
                    found[id] = link
                end
            end
        end
    end
    return found
end

local function applyBags()
    local bags = Sources.ScanBags()
    -- Items that left your bags lose the "In your bags" source.
    for id, entry in pairs(Sources.entries) do
        if entry.bags and not bags[id] then
            entry.bags = nil
            if not (entry.fromDB or entry.fromCraft) then Sources.entries[id] = nil else Sources.Resolve(entry) end
        end
    end
    local toLoad = {}
    for id, link in pairs(bags) do
        local entry = Sources.entries[id]
        if not entry then
            entry = newEntry(id)
            Sources.entries[id] = entry
        end
        if not entry.bags then
            entry.bags = true
            entry.bagLink = link
            Sources.Resolve(entry)
        end
        if not entry.rec then toLoad[#toLoad + 1] = id end
    end
    return toLoad
end

-- Items DungeonJournal lists for dungeons near your level that the database
-- doesn't have: added to the list (their ids, to load).
local function addJournalItems(level, ahead)
    local toLoad = {}
    if not (GP.Journal and GP.Journal.Available()) then return toLoad end
    for _, id in ipairs(GP.Journal.ItemsNear(level, Sources.LOWER, ahead)) do
        if not Sources.entries[id] then
            local equipLoc, classID, subClassID = Items.Instant(id)
            local ok, opensAt = false, nil
            if equipLoc then ok, opensAt = usableFor(classID, subClassID, equipLoc, level, ahead) end
            if ok then
                local entry = newEntry(id)
                entry.fromJournal = true
                entry.opensAt = opensAt
                Sources.Resolve(entry)
                if entry.best then
                    Sources.entries[id] = entry
                    Sources.counts.candidates = Sources.counts.candidates + 1
                    toLoad[#toLoad + 1] = id
                end
            end
        end
    end
    return toLoad
end

-- Near your level, by the database's numbers (an item it doesn't know
-- passes: the scoring checks the level once the item is loaded).
local function nearLevel(id, level, ahead)
    if not (DB and DB.Item) then return true end
    if field(DB.Item, "class", id) == nil then return true end
    local req = field(DB.Item, "requiredLevel", id) or 0
    local near = req
    if near == 0 then
        local ilvl = field(DB.Item, "itemLevel", id) or 0
        near = ilvl > 0 and math.max(1, ilvl - 5) or level
    end
    local lowest = math.max(0, level - Sources.LOWER)
    return req <= level + ahead and near >= lowest and near <= level + ahead + 5
end

-- Crafted gear: what your professions make (ProfessionDB) and what you've
-- seen in your profession window or at a trainer (Learn.lua). QuestieDB has
-- no recipes, so these are added to every scan here.
local function addCrafts(level, ahead)
    local toLoad = {}
    local ids = GP.Crafts and GP.Crafts.MyItems() or {}
    local items = GP.db and GP.db.learned and GP.db.learned.items
    if type(items) == "table" then
        for id, L in pairs(items) do
            if type(L) == "table" and type(L.c) == "table" then ids[id] = true end
        end
    end
    for id in pairs(ids) do
        if not Sources.entries[id] and nearLevel(id, level, ahead) then
            local equipLoc, classID, subClassID = Items.Instant(id)
            local ok, opensAt = false, nil
            if equipLoc then ok, opensAt = usableFor(classID, subClassID, equipLoc, level, ahead) end
            if ok then
                local entry = newEntry(id)
                entry.fromCraft = true
                entry.opensAt = opensAt
                Sources.Resolve(entry)
                if entry.best then
                    Sources.entries[id] = entry
                    Sources.counts.candidates = Sources.counts.candidates + 1
                    toLoad[#toLoad + 1] = id
                end
            end
        end
    end
    return toLoad
end

-- Each scan has a number: loading left over from an earlier scan (a
-- level-up right after login starts another) must not finish the new one
-- or fill its list.
Sources.gen = 0

local function loadRecords(ids, done)
    local gen = Sources.gen
    Sources.status = "loading"
    GP.Fire("SourcesChanged")
    Items.LoadAll("items", ids, function(rec, id)
        if gen ~= Sources.gen then return end
        local entry = Sources.entries[id]
        if entry then
            -- Bagged items keep their own link (a random suffix's stats).
            if entry.bagLink then rec = Items.FromLink(entry.bagLink) or rec end
            finishEntry(entry, rec)
        end
    end, function()
        if gen == Sources.gen and done then done() end
    end)
end

local function finished()
    if Sources.timing and Sources.timing.start then Sources.timing.ready = GP.Clock() - Sources.timing.start end
    Sources.status = "ready"
    GP.Fire("SourcesChanged")
    GP.Score.Run()
end

-- The full scan: every equippable item in the database you can use and
-- get, within reach of your level. A background job (no hitching).
function Sources.Scan()
    Sources.gen = Sources.gen + 1
    GP.PlayerInfo()
    DB = nil
    local lib = Sources.Database()
    Sources.entries = {}
    Sources.questItems = {}
    Sources.counts = { db = 0, candidates = 0, loaded = 0 }
    Sources.timing = { start = GP.Clock() }   -- for /gp status and /gp report: how long until the list is ready
    local level = GP.player.level
    local ahead = GP.Setting("ahead") or 5
    local lowest = math.max(0, level - Sources.LOWER)

    if not lib then
        Sources.status = "nodb"
        GP.Fire("SourcesChanged")
        local toLoad = addJournalItems(level, ahead)
        for _, id in ipairs(addCrafts(level, ahead)) do toLoad[#toLoad + 1] = id end
        for _, id in ipairs(applyBags()) do toLoad[#toLoad + 1] = id end
        loadRecords(toLoad, finished)
        return
    end

    Sources.status = "scanning"
    GP.Fire("SourcesChanged")
    GP.RunJob("scan", function()
        local Item = lib.Item
        local ids = Item.GetAllIds and Item.GetAllIds() or {}
        Sources.counts.db = #ids
        for i = 1, #ids do
            local id = ids[i]
            local classID = field(Item, "class", id)
            if classID == Classes.WEAPON or classID == Classes.ARMOR then
                -- Plenty of quest rewards need no level: the item level
                -- (about five above the level it's meant for) stands in.
                local req = field(Item, "requiredLevel", id) or 0
                local near = req
                if near == 0 then
                    local ilvl = field(Item, "itemLevel", id) or 0
                    near = ilvl > 0 and math.max(1, ilvl - 5) or level
                end
                if req <= level + ahead and near >= lowest and near <= level + ahead + 5 then
                    local equipLoc, iClass, iSub = Items.Instant(id)
                    local ok, opensAt = usableFor(iClass or classID, iSub or field(Item, "subClass", id), equipLoc, level, ahead)
                    if ok then
                        local entry = newEntry(id)
                        entry.fromDB = true
                        entry.opensAt = opensAt
                        Sources.Resolve(entry)
                        if entry.best then
                            Sources.entries[id] = entry
                            Sources.counts.candidates = Sources.counts.candidates + 1
                        end
                    end
                end
            end
            GP.Yield()
        end
    end, function()
        local toLoad = {}
        addJournalItems(level, ahead)
        addCrafts(level, ahead)
        for id, entry in pairs(Sources.entries) do
            if not entry.rec then toLoad[#toLoad + 1] = id end
        end
        for _, id in ipairs(applyBags()) do toLoad[#toLoad + 1] = id end
        loadRecords(toLoad, finished)
    end)
end

-- Quick refreshes that don't need the full scan.
function Sources.RefreshQuest(q)
    local items = Sources.questItems[q]
    if not items then return end
    for id in pairs(items) do
        local entry = Sources.entries[id]
        if entry then Sources.Resolve(entry) end
    end
    GP.Score.Request()
end

function Sources.RefreshBags()
    if Sources.status ~= "ready" and Sources.status ~= "nodb" then return end
    local toLoad = applyBags()
    if #toLoad > 0 then
        loadRecords(toLoad, finished)
    else
        GP.Score.Request()
    end
end

-- Learned something new about an item (Learn.lua).
function Sources.Learned(id)
    local entry = Sources.entries[id]
    if entry then
        Sources.Resolve(entry)
        if entry.rec and GP.Check then GP.Check.Item(entry) end
        GP.Score.Request()
        return
    end
    if Sources.status ~= "ready" then return end
    local equipLoc, classID, subClassID = Items.Instant(id)
    local level = GP.player.level
    local ok, opensAt = usableFor(classID, subClassID, equipLoc, level, GP.Setting("ahead") or 5)
    if not ok then return end
    entry = newEntry(id)
    entry.opensAt = opensAt
    Sources.Resolve(entry)
    if not entry.best then return end
    Sources.entries[id] = entry
    Items.Want(id, function(rec)
        if rec then
            finishEntry(entry, rec)
            if GP.Check then GP.Check.Item(entry) end
            GP.Score.Request()
        end
    end)
end

-- ---------------------------------------------------------------------
-- When to scan
-- ---------------------------------------------------------------------

GP.On("Login", function()
    -- A few seconds in: the world is loaded and the login rush is over.
    C_Timer.After(4, Sources.Scan)
end)

GP.On("LevelChanged", function()
    C_Timer.After(1, Sources.Scan)
end)

GP.On("RescanRequested", function()
    GP.Print("Rebuilding the gear list...")
    Sources.Scan()
end)

GP.On("SettingChanged", function(key)
    if key == "ahead" then GP.Soon("rescan", Sources.Scan) end
end)

GP.RegisterEvent("QUEST_TURNED_IN", function(_, q)
    if type(q) == "number" then C_Timer.After(0.5, function() Sources.RefreshQuest(q) end) end
end)

GP.RegisterEvent("QUEST_ACCEPTED", function(_, a, b)
    local q = type(b) == "number" and b or a
    if type(q) == "number" then Sources.RefreshQuest(q) end
end)

GP.RegisterEvent("BAG_UPDATE_DELAYED", function()
    GP.Soon("bags", Sources.RefreshBags)
end)

GP.On("StatusRequested", function()
    local lib = Sources.Database()
    if lib then
        GP.Print("Database: QuestieDB (%s), %d items in it.", tostring(lib.readMode or "?"), Sources.counts.db)
    else
        GP.Print("Database: QuestieDB not found. Install QuestieDB for quests, drops and vendors; until then only your bags and what you've seen are used.")
    end
    local crafts = GP.Crafts and GP.Crafts.StatusLine()
    if crafts then GP.Print(crafts) end
    GP.Print("Gear for you: %d found, %d loaded. Status: %s.", Sources.counts.candidates, Sources.counts.loaded, Sources.status)
    local r = GP.Score.results
    GP.Print("Upgrades: %d to get now, %d worth chasing.", r.primary or 0, r.secondary or 0)
    if GP.Learn and GP.Learn.Count and GP.db then
        GP.Print("Saved sources: %d you saw, %d other players shared (kept at most %d and %d).",
            GP.Learn.Count(GP.db.learned and GP.db.learned.items), GP.Learn.Count(GP.db.shared and GP.db.shared.items),
            GP.Learn.LEARNED_MAX, GP.Learn.SHARED_MAX)
    end
    if GP.Skin and GP.Skin.current then GP.Print("Look: %s.", GP.Skin.current.label or GP.Skin.current.name) end
    GP.Print("Speed: %s.", Sources.SpeedText(true))
    if GP.ZoneData then
        local z = GP.ZoneData.Status()
        if z.hasDB then
            GP.Print("Zones: %s (%d dungeons, %d entrances). /gp zones for the details.",
                z.ok and "QuestieDB's, checked" or "game's own maps (QuestieDB's zone data changed)", z.counts.dungeons, z.counts.entrances)
        end
    end
end)

-- "list ready in 2.1 s (0.4 s of work), memory 3.4 MB"
function Sources.SpeedText(long)
    local t = Sources.timing or {}
    local work = (GP.jobMs.scan or 0) + (GP.jobMs.items or 0) + (GP.Score.lastMs or 0)
    local parts = {}
    if t.ready then
        parts[#parts + 1] = string.format(long and "list ready in %.1f s (%.2f s of work, spread over frames)" or "ready %.1fs work %.2fs",
            t.ready / 1000, work / 1000)
    else
        parts[#parts + 1] = long and "the list isn't ready yet" or "not ready"
    end
    local kb = GP.MemoryKB()
    if kb then parts[#parts + 1] = string.format(long and "memory %.1f MB" or "%.1fMB", kb / 1024) end
    return table.concat(parts, long and ", " or " ")
end

-- One line with what a bug report needs: version, game and language,
-- character, add-ons GearPath reads, counts, speed and errors.
function Sources.ReportLine()
    local p = GP.PlayerInfo()
    local version, build, _, toc = "?", "?", nil, "?"
    if GetBuildInfo then version, build, _, toc = GetBuildInfo() end
    local lib = Sources.Database()
    local r = GP.Score.results or {}
    local db = GP.db or {}
    local e = GP.errors or { count = 0 }
    local addons = {}
    addons[#addons + 1] = lib and ("QuestieDB " .. (Sources.counts.db or 0)) or "no QuestieDB"
    if GP.Journal and GP.Journal.Available and GP.Journal.Available() then addons[#addons + 1] = "Journal" end
    if GP.Crafts and GP.Crafts.Available() then addons[#addons + 1] = "ProfessionDB" end
    if GP.AddOnLoaded("DaylightUI") then addons[#addons + 1] = "DaylightUI" end
    if GP.AddOnLoaded("TomTom") then addons[#addons + 1] = "TomTom" end
    local parts = {
        "GearPath " .. tostring(GP.VERSION),
        string.format("WoW %s.%s (%s) %s", tostring(version), tostring(build), tostring(toc), tostring(GetLocale and GP.Plain(GetLocale()) or "?")),
        string.format("%s %d %s %s", tostring(p.class), p.level or 0, tostring(p.race), tostring(p.faction)),
        "look " .. tostring(GP.Skin and GP.Skin.current and GP.Skin.current.name or "?"),
        table.concat(addons, " "),
        GP.ZoneData and GP.ZoneData.ReportPart() or "zones ?",
        string.format("gear %d/%d %s", Sources.counts.candidates or 0, Sources.counts.loaded or 0, tostring(Sources.status)),
        string.format("now %d chase %d", r.primary or 0, r.secondary or 0),
        string.format("saved %d/%d", GP.Learn.Count(db.learned and db.learned.items), GP.Learn.Count(db.shared and db.shared.items)),
        Sources.SpeedText(false),
        e.count > 0 and string.format("errors %d (last: %s)", e.count, e.last or "?") or "errors 0",
    }
    if #(GP.blocked or {}) > 0 then parts[#parts + 1] = "blocked " .. table.concat(GP.blocked, ", ") end
    return table.concat(parts, " | ")
end

GP.RegisterCommand("report", "one line for a bug report (version, game, character, counts), ready to copy", function()
    local line = Sources.ReportLine()
    GP.Print(line)
    if GP.UI and GP.UI.TextBox then
        GP.UI.TextBox({ title = GP.L["GearPath report"], note = GP.L["Press Ctrl+C to copy it, then paste it into your bug report."], text = line })
    end
end)
