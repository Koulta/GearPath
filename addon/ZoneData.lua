-- ZoneData: where QuestieDB's zones and dungeons are on the game's maps.
--
-- Every map pin goes through here: an NPC's or object's spawn (an area id
-- and a spot in it) becomes a place on a game map, and an area inside a
-- dungeon becomes that dungeon and its entrance. QuestieDB keeps what that
-- takes in its ZoneDB support module, but in tables it doesn't promise to
-- keep the same (ZoneDB.private: areaIdToUiMapId, areaIdToUiMapIdOverride,
-- dungeons). So nothing here trusts them blindly:
--
--  1. A public ZoneDB function is used before the private tables, if a
--     QuestieDB version offers one (GetUiMapIdByAreaId).
--  2. Whatever is read is checked: the shape of every row, and a sample of
--     area -> map pairs against the game's own names (an area and the map
--     it's put on should be called the same; a shifted or renumbered table
--     isn't). A table that fails is set aside, not used.
--  3. What's missing or set aside comes from the game itself: zones by
--     name (C_Map's own map list), dungeons from the Dungeon Journal, and
--     entrances from the Dungeon Journal or the game's encounter journal.
--  4. Each QuestieDB version is checked once and remembered. A problem, or
--     an update that suddenly has far fewer dungeon entrances than the
--     last good version, is said once in chat (and shows in /gp zones,
--     /gp status and /gp report).
--
-- Nothing of QuestieDB's is copied or saved: only counts, for the check.

local _, GP = ...

local Z = {}
GP.ZoneData = Z

Z.SAMPLE = 60              -- area -> map pairs checked against the game's names
Z.MIN_COMPARABLE = 5       -- pairs with both names known before the check counts
Z.MIN_NAME_MATCH = 0.5     -- share of those whose names must agree
Z.MIN_VALID_ROWS = 0.8     -- share of rows (area -> map, dungeons) that must have the shape we know
Z.ENTRANCE_DROP = 0.25     -- a new version with this much fewer entrances is flagged

-- The game's world maps to walk for its own map list (Azeroth, Kalimdor,
-- the Eastern Kingdoms); whichever this client has.
Z.ROOT_MAPS = { 947, 1414, 1415 }
local ZONE_TYPES = { [3] = 1, [4] = 2, [5] = 3, [6] = 4 }   -- Zone, Dungeon, Micro, Orphan: preference

local state

local function isId(v) return type(v) == "number" and v > 0 and v == math.floor(v) end
local function isCoord(v) return type(v) == "number" and v >= 0 and v <= 100 end

local function problem(s, text) s.problems[#s.problems + 1] = text end

local function areaName(area)
    if not (area and C_Map and C_Map.GetAreaInfo) then return nil end
    local ok, n = pcall(C_Map.GetAreaInfo, area)
    n = ok and GP.Plain(n) or nil
    return type(n) == "string" and n ~= "" and n or nil
end

local function mapName(mapID)
    if not (mapID and C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    local n = ok and type(info) == "table" and GP.Plain(info.name) or nil
    return type(n) == "string" and n ~= "" and n or nil
end

-- A table QuestieDB keeps as Lua source text: run with nothing to reach
-- (no globals), so it can only return data.
local function readTable(src)
    if type(src) == "table" then return src end
    if type(src) ~= "string" then return nil end
    local loader = loadstring or load
    if type(loader) ~= "function" then return nil end
    local ok, fn = pcall(loader, src)
    if not ok or type(fn) ~= "function" then return nil end
    if setfenv then pcall(setfenv, fn, {}) end
    local ok2, t = pcall(fn)
    if ok2 and type(t) == "table" then return t end
    return nil
end

local function questieVersion()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    if type(get) ~= "function" then return nil end
    local ok, v = pcall(get, "QuestieDB", "Version")
    v = ok and GP.Plain(v) or nil
    return type(v) == "string" and v ~= "" and v or nil
end

-- ---------------------------------------------------------------------
-- The game's own map list: map name -> map id
-- ---------------------------------------------------------------------

local function gameMaps(s)
    if s.gameMaps then return s.gameMaps end
    local byName, rank = {}, {}
    local children = C_Map and C_Map.GetMapChildrenInfo
    if type(children) == "function" then
        for _, root in ipairs(Z.ROOT_MAPS) do
            local ok, list = pcall(children, root, nil, true)
            if ok and type(list) == "table" then
                for _, info in ipairs(list) do
                    local name, id = type(info) == "table" and GP.Plain(info.name), type(info) == "table" and info.mapID
                    local pref = type(info) == "table" and ZONE_TYPES[info.mapType]
                    if type(name) == "string" and isId(id) and pref and (not rank[name] or pref < rank[name]) then
                        byName[name], rank[name] = id, pref
                    end
                end
            end
        end
    end
    s.gameMaps = byName
    return byName
end

local function mapByName(s, area)
    local n = areaName(area)
    return n and gameMaps(s)[n] or nil
end

-- ---------------------------------------------------------------------
-- QuestieDB, read defensively
-- ---------------------------------------------------------------------

local function zoneModule()
    local DB = GP.Sources and GP.Sources.Database and GP.Sources.Database()
    if not DB then return nil, nil end
    local support = type(DB.Support) == "table" and DB.Support
    if not (support and type(support.Get) == "function") then return DB, nil end
    local ok, zoneDB = pcall(support.Get, "ZoneDB")
    return DB, ok and type(zoneDB) == "table" and zoneDB or nil
end

-- A public "area -> map" function, called either way (module:Fn(area) or Fn(area)).
local function publicLookup(zoneDB)
    if not zoneDB then return nil end
    local okFn, fn = pcall(function() return zoneDB.GetUiMapIdByAreaId end)
    if not okFn or type(fn) ~= "function" then return nil end
    return function(area)
        local ok, m = pcall(fn, zoneDB, area)
        if ok and isId(m) then return m end
        ok, m = pcall(fn, area)
        if ok and isId(m) then return m end
        return nil
    end
end

-- The area ids to check pairs with: the database's own list of zones, or
-- the table's keys.
local function sampleAreas(DB, t)
    local out = {}
    local ids = DB and type(DB.Enum) == "table" and type(DB.Enum.zoneIDs) == "table" and DB.Enum.zoneIDs
    if ids then
        for _, id in pairs(ids) do if isId(id) then out[#out + 1] = id end end
    end
    if #out == 0 and t then
        for area in pairs(t) do if isId(area) then out[#out + 1] = area end end
    end
    table.sort(out)
    -- Spread over the whole list, at most SAMPLE of them.
    if #out > Z.SAMPLE then
        local spread, step = {}, #out / Z.SAMPLE
        for i = 1, Z.SAMPLE do spread[i] = out[math.floor((i - 1) * step) + 1] end
        out = spread
    end
    return out
end

-- Names compared loosely: case, "The ..." and punctuation don't count.
local function sameName(a, b)
    local function norm(n) return (n:lower():gsub("^the%s+", ""):gsub("[^%w]", "")) end
    return norm(a) == norm(b)
end

-- Whether map m is mapID or one of the maps it sits inside (its zone,
-- continent...): a town or city area is rightly put on its zone's map.
local function onOrInside(mapID, m)
    local id, seen = mapID, 0
    while isId(id) and seen < 8 do
        if id == m then return true end
        local ok, info = pcall(C_Map.GetMapInfo, id)
        id = ok and type(info) == "table" and info.parentMapID or nil
        seen = seen + 1
    end
    return false
end

-- How many sampled pairs can be judged, and how many of them agree.
-- A pair agrees when the area and its map share a name, or the area is a
-- map of its own (by name, in the game's map list) that sits on or inside
-- the map it was given. An area that is no map of its own (a subzone like
-- Deathknell, put on its zone's map) can't be judged by name, so it's left
-- out rather than counted as wrong (launch night, Nov 4: QuestieDB 1.0.10
-- put most such subzones on their zones, which the plain name test called
-- wrong: 7 of 16).
local function nameCheck(s, areas, lookup)
    local comparable, agree = 0, 0
    local maps = gameMaps(s)
    for _, area in ipairs(areas) do
        local m = lookup(area)
        local a, b = areaName(area), m and mapName(m)
        if a and b then
            if sameName(a, b) then
                comparable, agree = comparable + 1, agree + 1
            else
                local own = maps[a]
                if own then
                    comparable = comparable + 1
                    if onOrInside(own, m) then agree = agree + 1 end
                end
            end
        end
    end
    return comparable, agree
end

-- The private area -> map tables, read and shape-checked: the table and
-- its usable row count, or nil and what's wrong with them.
local function privateMaps(private)
    if not private then return nil, 0, { "ZoneDB has no area -> map table" } end
    local t, bad, issues = {}, 0, {}
    for _, key in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
        local src = private[key]
        if src ~= nil then
            local tbl = readTable(src)
            if not tbl then
                issues[#issues + 1] = "ZoneDB." .. key .. " can't be read (it's a " .. type(src) .. ")"
            else
                for area, map in pairs(tbl) do
                    if isId(area) and isId(map) then t[area] = map
                    elseif map ~= 0 then bad = bad + 1 end      -- (0: "no map", a placeholder)
                end
            end
        elseif key == "areaIdToUiMapId" then
            issues[#issues + 1] = "ZoneDB.areaIdToUiMapId is gone"
        end
    end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n == 0 or n / (n + bad) < Z.MIN_VALID_ROWS then
        issues[#issues + 1] = string.format("ZoneDB's area -> map table has %d usable rows (%d not in the shape GearPath knows)", n, bad)
        return nil, n, issues
    end
    return t, n, issues
end

local function checkedText(comparable, agree)
    return comparable >= Z.MIN_COMPARABLE and string.format("%d/%d names agree", agree, comparable) or "names not checked"
end

local function readMaps(s, DB, zoneDB, private)
    local t, n, issues = privateMaps(private)
    local areas = sampleAreas(DB, t)
    -- 1. A public function, when there is one (checked on the same areas).
    local public = publicLookup(zoneDB)
    if public then
        local comparable, agree = nameCheck(s, areas, public)
        if comparable < Z.MIN_COMPARABLE or agree / comparable >= Z.MIN_NAME_MATCH then
            s.lookup, s.mapsFrom, s.checked = public, "questiedb", checkedText(comparable, agree)
            return
        end
        problem(s, string.format("ZoneDB.GetUiMapIdByAreaId puts zones on the wrong maps (%d of %d names agree)", agree, comparable))
    end
    -- 2. The private tables.
    for _, text in ipairs(issues) do problem(s, text) end
    if not t then return end
    local lookup = function(area) return t[area] end
    local comparable, agree = nameCheck(s, areas, lookup)
    if comparable >= Z.MIN_COMPARABLE and agree / comparable < Z.MIN_NAME_MATCH then
        problem(s, string.format("ZoneDB's area -> map table puts zones on the wrong maps (%d of %d names agree)", agree, comparable))
        return
    end
    s.lookup, s.mapsFrom, s.counts.maps, s.checked = lookup, "questiedb", n, checkedText(comparable, agree)
end

-- A dungeon row: { name, { other area ids }, area outside, { { area, x, y }, ... } }.
local function validRow(d)
    if type(d) ~= "table" or type(d[1]) ~= "string" or d[1] == "" then return false end
    if d[2] ~= nil and type(d[2]) ~= "table" then return false end
    if d[3] ~= nil and not isId(d[3]) then return false end
    if d[4] ~= nil then
        if type(d[4]) ~= "table" then return false end
        for _, e in ipairs(d[4]) do
            if type(e) ~= "table" or not isId(e[1]) or not isCoord(e[2]) or not isCoord(e[3]) then return false end
        end
    end
    return true
end

local function readDungeons(s, private)
    local src = private and private.dungeons
    if src == nil then
        problem(s, "ZoneDB has no dungeon table")
        return
    end
    if type(src) ~= "table" then
        problem(s, "ZoneDB.dungeons isn't a table (it's a " .. type(src) .. ")")
        return
    end
    local rows, good = 0, {}
    for area, d in pairs(src) do
        rows = rows + 1
        if isId(area) and validRow(d) then good[area] = d end
    end
    local n = 0
    for _ in pairs(good) do n = n + 1 end
    if rows == 0 or n / rows < Z.MIN_VALID_ROWS then
        problem(s, string.format("ZoneDB.dungeons: %d of %d rows in the shape GearPath knows", n, rows))
        return
    end
    for area, d in pairs(good) do
        s.dungeonByArea[area] = d
        if type(d[2]) == "table" then
            for _, alt in ipairs(d[2]) do if isId(alt) then s.dungeonByArea[alt] = d end end
        end
        if type(d[4]) == "table" and d[4][1] then s.counts.entrances = s.counts.entrances + 1 end
    end
    s.counts.dungeons = n
    s.dungeonsFrom = "questiedb"
end

-- ---------------------------------------------------------------------
-- Building it, checking it, saying so
-- ---------------------------------------------------------------------

local function build()
    local s = { dungeonByArea = {}, problems = {}, counts = { maps = 0, dungeons = 0, entrances = 0 },
        mapsFrom = "game", dungeonsFrom = "journal" }
    local DB, zoneDB = zoneModule()
    s.hasDB = DB ~= nil
    s.version = questieVersion()
    if DB then
        if not zoneDB then problem(s, "QuestieDB has no ZoneDB support module") end
        local private = zoneDB and type(zoneDB.private) == "table" and zoneDB.private or nil
        if zoneDB and not private and not publicLookup(zoneDB) then problem(s, "ZoneDB.private is gone") end
        GP.SafeCall(readMaps, s, DB, zoneDB, private)
        GP.SafeCall(readDungeons, s, private)
    end
    return s
end

-- Remembers the check per QuestieDB version; says once when something's off.
local function remember(s)
    if not (s.hasDB and GP.db) then return end
    GP.db.zoneCheck = type(GP.db.zoneCheck) == "table" and GP.db.zoneCheck or {}
    local saved = GP.db.zoneCheck
    local version = s.version or "?"
    local last = saved.lastGood
    if last and last.version ~= version and (last.entrances or 0) > 0
        and s.counts.entrances < last.entrances * (1 - Z.ENTRANCE_DROP) then
        problem(s, string.format("QuestieDB %s has %d dungeon entrances; %s had %d", version, s.counts.entrances,
            tostring(last.version), last.entrances))
    end
    local ok = #s.problems == 0
    if ok then
        saved.lastGood = { version = version, maps = s.counts.maps, dungeons = s.counts.dungeons, entrances = s.counts.entrances }
    end
    if not ok and saved.warned ~= version then
        saved.warned = version
        GP.Print("QuestieDB %s keeps its zone data differently from what GearPath knows (%s). Map pins use the game's own maps "
            .. "and the Dungeon Journal for now, so a few may be missing. /gp zones has the details; a /gp report helps get it fixed.",
            version, s.problems[1])
    end
    s.ok = ok
end

local function ensure()
    if state then return state end
    state = build()
    GP.SafeCall(remember, state)
    return state
end

function Z.Reset()
    state = nil
end

-- The game map an area is on (QuestieDB's, checked; else the game's own by name).
function Z.MapForArea(area)
    if not isId(area) then return nil end
    local s = ensure()
    local m = s.lookup and s.lookup(area)
    if isId(m) then return m end
    m = mapByName(s, area)
    if m then s.fromGame = (s.fromGame or 0) + 1 end
    return m
end

-- The dungeon an area is inside, as a row { name, alts, area outside,
-- entrances }, or nil. Without QuestieDB's table: the Dungeon Journal's
-- dungeon of that name (no entrance in the row; Waypoint asks the journal).
function Z.Dungeon(area)
    if not isId(area) then return nil end
    local s = ensure()
    local d = s.dungeonByArea[area]
    if d then return d end
    if s.dungeonsFrom ~= "questiedb" and GP.Journal and GP.Journal.Available and GP.Journal.Available() then
        local name = areaName(area)
        if name and GP.Journal.Dungeon(name) then
            d = { name }
            s.dungeonByArea[area] = d
            return d
        end
    end
    return nil
end

-- Every dungeon row (for entrances by name).
function Z.Dungeons()
    return ensure().dungeonByArea
end

-- An entrance from the game's own encounter journal, where this client has
-- one: { mapID, x, y, zone } by the dungeon's name, or nil.
local gameEntrances
function Z.GameEntrance(name)
    if type(name) ~= "string" then return nil end
    if not gameEntrances then
        gameEntrances = {}
        local get = C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap
        if type(get) == "function" then
            for mapName_, mapID in pairs(gameMaps(ensure())) do
                local ok, list = pcall(get, mapID)
                if ok and type(list) == "table" then
                    for _, e in ipairs(list) do
                        local n = type(e) == "table" and GP.Plain(e.name)
                        local pos = type(e) == "table" and e.position
                        local x, y
                        if type(pos) == "table" and type(pos.GetXY) == "function" then
                            local okXY, px, py = pcall(pos.GetXY, pos)
                            if okXY then x, y = px, py end
                        elseif type(pos) == "table" then
                            x, y = pos.x, pos.y
                        end
                        if type(n) == "string" and type(x) == "number" and type(y) == "number" and not gameEntrances[n] then
                            gameEntrances[n] = { mapID = mapID, x = x, y = y, zone = mapName_ }
                        end
                    end
                end
            end
        end
    end
    return gameEntrances[name]
end

-- What was found: { ok, mapsFrom, dungeonsFrom, counts, problems, version, checked }.
function Z.Status()
    return ensure()
end

-- One short part for /gp report: "zones qdb 412/58/57" or "zones GAME! (...)".
function Z.ReportPart()
    local s = ensure()
    if not s.hasDB then return "zones game" end
    if s.ok then
        return string.format("zones qdb %d/%d/%d", s.counts.maps, s.counts.dungeons, s.counts.entrances)
    end
    return string.format("zones %s/%s! (%s)", s.mapsFrom, s.dungeonsFrom, tostring(s.problems[1]):sub(1, 60))
end

GP.On("RescanRequested", Z.Reset)

-- /gp zones: the check, in full.
GP.RegisterCommand("zones", "check QuestieDB's zone and dungeon data (map pins); /gp zones accept takes this version's as good", function(rest)
    rest = (rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if rest == "accept" then
        -- Fewer dungeons on purpose (QuestieDB dropped some): this version is the new baseline.
        local s = ensure()
        if s.hasDB and GP.db then
            GP.db.zoneCheck = type(GP.db.zoneCheck) == "table" and GP.db.zoneCheck or {}
            GP.db.zoneCheck.lastGood = { version = s.version or "?", maps = s.counts.maps, dungeons = s.counts.dungeons,
                entrances = s.counts.entrances }
            GP.Print("Zones: QuestieDB %s's zone data is now the one GearPath compares updates with.", tostring(s.version or "?"))
        end
    end
    Z.Reset()
    local s = ensure()
    if not s.hasDB then
        GP.Print("Zones: QuestieDB isn't installed; map pins use the game's own maps and the Dungeon Journal.")
        return
    end
    GP.Print("Zones: QuestieDB %s. Maps from %s (%d rows, %s), dungeons from %s (%d, %d with an entrance).",
        tostring(s.version or "?"), s.mapsFrom, s.counts.maps, tostring(s.checked or "not checked"),
        s.dungeonsFrom, s.counts.dungeons, s.counts.entrances)
    if s.ok then
        GP.Print("Zones: everything is in the shape GearPath knows.")
    else
        for _, p in ipairs(s.problems) do GP.Print("  Problem: %s.", p) end
    end
    local last = GP.db and GP.db.zoneCheck and GP.db.zoneCheck.lastGood
    if last then
        GP.Print("Zones: last good check was QuestieDB %s (%d dungeons, %d entrances).", tostring(last.version), last.dungeons or 0, last.entrances or 0)
    end
end)
