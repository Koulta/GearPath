-- lua5.1 zone_test.lua <addon dir>
-- ZoneData: QuestieDB's zone and dungeon tables changing shape under
-- GearPath. Every way they can break (gone, unreadable, a new layout, the
-- wrong maps, far fewer entrances than the last version) must leave map
-- pins working from the game's own maps and the Dungeon Journal, never
-- raise a Lua error, and be said once.
local dir = arg[1]
local here = arg[0]:match("^(.*)/[^/]*$") or "."

local H = dofile(here .. "/wow.lua")
dofile(here .. "/data.lua")

local checks, failed = 0, 0
local function check(cond, what)
    checks = checks + 1
    if not cond then failed = failed + 1 print("  FAIL: " .. what) end
end

-- The game's maps and areas, with a few more zones than data.lua has (so
-- the name check has enough pairs to judge).
local AREAS = { [40] = "Westfall", [10] = "Duskwood", [85] = "Tirisfal Glades", [1581] = "The Deadmines",
    [12] = "Elwynn Forest", [44] = "Redridge Mountains", [14] = "Durotar", [215] = "Mulgore", [2000] = "Shadow Keep" }
local MAPS = { [1436] = "Westfall", [1431] = "Duskwood", [1420] = "Tirisfal Glades", [1429] = "Elwynn Forest",
    [1433] = "Redridge Mountains", [1411] = "Durotar", [1412] = "Mulgore", [1458] = "Undercity" }
-- Subzones (no map of their own) and a city that is a map inside its zone.
local AREAS_SUB = { [154] = "Deathknell", [159] = "Brill", [87] = "Goldshire", [9] = "Northshire Valley",
    [362] = "Razor Hill", [222] = "Bloodhoof Village", [108] = "Sentinel Hill", [1497] = "Undercity" }
local GOOD = { [40] = 1436, [10] = 1431, [85] = 1420, [12] = 1429, [44] = 1433, [14] = 1411, [215] = 1412 }
C_Map.GetAreaInfo = function(a) return AREAS[a] or AREAS_SUB[a] end
local PARENT = { [1458] = 1420 }   -- Undercity sits inside Tirisfal Glades
C_Map.GetMapInfo = function(m) return MAPS[m] and { name = MAPS[m], mapType = 3, parentMapID = PARENT[m] or 1415 } end
C_Map.GetMapChildrenInfo = function(root)
    if root ~= 947 then return {} end
    local out = {}
    for id, name in pairs(MAPS) do out[#out + 1] = { mapID = id, name = name, mapType = 3 } end
    return out
end
local qdbVersion = "1.0.0"
local realMeta = C_AddOns.GetAddOnMetadata
C_AddOns.GetAddOnMetadata = function(addon, field)
    if addon == "QuestieDB" and field == "Version" then return qdbVersion end
    return realMeta(addon, field)
end

local function src(t)
    local parts = {}
    for k, v in pairs(t) do parts[#parts + 1] = string.format("[%d] = %d", k, v) end
    return "return { " .. table.concat(parts, ", ") .. " }"
end
local DEADMINES = { [1581] = { "The Deadmines", { 10029 }, 40, { { 40, 42.5, 71.7 } } } }
local zoneDB
LibQuestieDB.Support.Get = function(name) if name == "ZoneDB" then return zoneDB end end
local function private(p) zoneDB = { private = p } end

local ns = {}
for line in io.open(dir .. "/GearPath.toc"):read("*a"):gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local ok, err = pcall(assert(loadfile(dir .. "/" .. line:gsub("\\", "/"))), "GearPath", ns)
        if not ok then print("  LOAD ERROR " .. line .. ": " .. tostring(err)) failed = failed + 1 end
    end
end
local GP = ns
private({ areaIdToUiMapId = src(GOOD), areaIdToUiMapIdOverride = "return { [0] = 0 }", dungeons = DEADMINES })
H.Fire("ADDON_LOADED", "GearPath")
H.Fire("PLAYER_LOGIN")
for _ = 1, 100 do H.Tick(0.1) if GP.Sources.status == "ready" then break end end
local Z = GP.ZoneData

local function again()
    Z.Reset()
    GP.Fire("RescanRequested")
    return Z.Status()
end
local function warnings()
    local n = 0
    for _, m in ipairs(H.printed) do if m:find("keeps its zone data differently") then n = n + 1 end end
    return n
end
local function pinsWork(what)
    check(Z.MapForArea(40) == 1436 and Z.MapForArea(85) == 1420, what .. ": zones still land on the right maps")
    local p = GP.Sources.Place(40, 0.5, 0.5)
    check(p.mapID == 1436 and p.zone == "Westfall", what .. ": a spawn's place has its map and zone")
    check(GP.Waypoint.Entrance("Shadow Keep") ~= nil, what .. ": the Dungeon Journal's entrances still pin")
end

-- 1. The shape GearPath knows: QuestieDB's tables, checked, no warning.
local s = again()
check(s.ok and s.mapsFrom == "questiedb" and s.dungeonsFrom == "questiedb", "today's shape: QuestieDB's tables are used")
check(s.checked == "7/7 names agree", "and its area -> map pairs agree with the game's names (" .. tostring(s.checked) .. ")")
check(Z.Dungeon(1581) and Z.Dungeon(1581)[1] == "The Deadmines" and Z.Dungeon(10029) == Z.Dungeon(1581), "dungeons by area, and their other areas")
check(GP.Sources.DungeonEntrance("The Deadmines") and GP.Sources.DungeonEntrance("The Deadmines").mapID == 1436, "the Deadmines' entrance is in Westfall")
check(warnings() == 0, "nothing said")
check(GP.db.zoneCheck.lastGood and GP.db.zoneCheck.lastGood.version == "1.0.0" and GP.db.zoneCheck.lastGood.entrances == 1, "the good check is remembered")
check(Z.ReportPart() == "zones qdb 7/1/1", "report: " .. Z.ReportPart())
pinsWork("today's shape")

-- 2. ZoneDB.private gone (a QuestieDB that moved it).
qdbVersion = "1.1.0"
zoneDB = {}
s = again()
check(not s.ok and s.mapsFrom == "game", "private gone: the game's maps are used")
check(warnings() == 1, "said once in chat")
pinsWork("private gone")
check(Z.Dungeon(2000) and Z.Dungeon(2000)[1] == "Shadow Keep", "a dungeon the journal knows is still a dungeon (by its name)")
check(Z.ReportPart():find("^zones game/journal! %("), "report says so: " .. Z.ReportPart())
again(); again()
check(warnings() == 1, "and not again for the same version")

-- 3. No ZoneDB at all.
qdbVersion = "1.2.0"
zoneDB = nil
s = again()
check(not s.ok and s.problems[1]:find("no ZoneDB"), "no ZoneDB module: said (" .. tostring(s.problems[1]) .. ")")
pinsWork("no ZoneDB")

-- 4. The table as source text that won't compile.
qdbVersion = "1.3.0"
private({ areaIdToUiMapId = "return { [40] = ", dungeons = DEADMINES })
s = again()
check(not s.ok and s.mapsFrom == "game" and s.dungeonsFrom == "questiedb", "unreadable table: set aside, dungeons still used")
pinsWork("unreadable table")

-- 5. A new layout: rows are tables, not map ids.
qdbVersion = "1.4.0"
local newRows = {}
for a, m in pairs(GOOD) do newRows[a] = { uiMapId = m } end
private({ areaIdToUiMapId = newRows, dungeons = DEADMINES })
s = again()
check(not s.ok and s.mapsFrom == "game" and s.problems[1]:find("usable rows"), "new row layout: set aside (" .. tostring(s.problems[1]) .. ")")
pinsWork("new row layout")

-- 6. The right shape, the wrong maps (renumbered or shifted).
qdbVersion = "1.5.0"
local shifted, ids = {}, {}
for _, m in pairs(GOOD) do ids[#ids + 1] = m end
table.sort(ids)
local i = 0
for a in pairs(GOOD) do i = i + 1; shifted[a] = ids[i % #ids + 1] end
private({ areaIdToUiMapId = src(shifted), dungeons = DEADMINES })
s = again()
check(not s.ok and s.mapsFrom == "game" and s.problems[1]:find("wrong maps"), "shifted maps: caught by the names (" .. tostring(s.problems[1]) .. ")")
pinsWork("shifted maps")

-- 7. Dungeons in a new layout.
qdbVersion = "1.6.0"
private({ areaIdToUiMapId = src(GOOD), dungeons = { ["The Deadmines"] = { area = 1581, entrance = { 40, 42.5, 71.7 } } } })
s = again()
check(not s.ok and s.mapsFrom == "questiedb" and s.dungeonsFrom == "journal", "new dungeon layout: maps kept, dungeons from the journal")
check(Z.Dungeon(1581) == nil and Z.Dungeon(2000) and Z.Dungeon(2000)[1] == "Shadow Keep", "only the journal's dungeons, by name")
pinsWork("new dungeon layout")

-- 8. A public function, in a later QuestieDB: used first (either call style).
qdbVersion = "2.0.0"
zoneDB = { GetUiMapIdByAreaId = function(self, area) return GOOD[area] end }
s = again()
check(s.ok == false and s.mapsFrom == "questiedb", "public function (no dungeon table): its maps are used")
check(Z.MapForArea(12) == 1429, "through ZoneDB:GetUiMapIdByAreaId")
zoneDB = setmetatable({ private = { dungeons = DEADMINES } }, { __index = { GetUiMapIdByAreaId = function(area) return GOOD[area] end } })
s = again()
check(s.ok and s.mapsFrom == "questiedb" and Z.MapForArea(44) == 1433, "a dot-style function on its metatable works too")
zoneDB = { GetUiMapIdByAreaId = function(self, area) return shifted[area] end, private = { areaIdToUiMapId = src(GOOD), dungeons = DEADMINES } }
s = again()
check(Z.MapForArea(12) == 1429 and s.problems[1] and s.problems[1]:find("GetUiMapIdByAreaId"), "a public function with the wrong maps: the checked table instead")

-- 9. Far fewer entrances than the last good version.
qdbVersion = "2.1.0"
local many = {}
for n = 1, 40 do many[3000 + n] = { "Dungeon " .. n, nil, 40, { { 40, 10 + n, 20 } } } end
private({ areaIdToUiMapId = src(GOOD), dungeons = many })
s = again()
check(s.ok and GP.db.zoneCheck.lastGood.entrances == 40, "a version with 40 entrances: good")
qdbVersion = "2.2.0"
private({ areaIdToUiMapId = src(GOOD), dungeons = DEADMINES })
local before = warnings()
s = again()
check(not s.ok and s.problems[1]:find("has 1 dungeon entrances; 2.1.0 had 40"), "an update with 1 is flagged (" .. tostring(s.problems[1]) .. ")")
check(warnings() == before + 1, "and said")
check(GP.db.zoneCheck.lastGood.version == "2.1.0", "the last good version stays what it was")

-- 10. Source text can only return data.
qdbVersion = "3.0.0"
private({ areaIdToUiMapId = "GP_TOUCHED = true; return { [40] = 1436, [10] = 1431, [85] = 1420, [12] = 1429, [44] = 1433, [14] = 1411, [215] = 1412 }",
    areaIdToUiMapIdOverride = "return os.exit(1)", dungeons = many })
s = again()
check(rawget(_G, "GP_TOUCHED") == nil, "the table's text can't set a global")
check(s.mapsFrom == "questiedb" and Z.MapForArea(40) == 1436, "and its data is still read")
check(s.problems[1] and s.problems[1]:find("areaIdToUiMapIdOverride can't be read"), "the one that tried to reach os is set aside")

-- 11. Odd values anywhere: no Lua error.
qdbVersion = "3.1.0"
for _, p in ipairs({ { areaIdToUiMapId = 42 }, { areaIdToUiMapId = true, dungeons = "x" }, { dungeons = { [1] = 5, [2] = { 7 } } },
    { areaIdToUiMapId = { ["a"] = "b", [1.5] = -2 } }, { dungeons = { [1581] = { "X", "notatable", 40, {} } } } }) do
    private(p)
    again()
    Z.MapForArea(40); Z.MapForArea(nil); Z.MapForArea("40"); Z.Dungeon(1581); Z.Dungeon(-1); Z.ReportPart()
    GP.Sources.DungeonEntrance("The Deadmines"); GP.Sources.Place(1581, 0.1, 0.1)
end
check(GP.errors.count == 0 and #H.errors == 0, "no Lua errors from any of it (" .. GP.errors.count .. ", " .. #H.errors .. ")")

-- 12. /gp zones, /gp status and /gp report say where pins come from.
private({ areaIdToUiMapId = src(GOOD), dungeons = DEADMINES })
qdbVersion = "3.2.0"
local n0 = #H.printed
SlashCmdList.GEARPATH("zones")
local said = table.concat(H.printed, "\n", n0 + 1)
check(said:find("Zones: QuestieDB 3.2.0") and said:find("Maps from questiedb"), "/gp zones: the version and the source")
check(said:find("last good check was QuestieDB"), "and the last good check")
n0 = #H.printed
SlashCmdList.GEARPATH("status")
check(table.concat(H.printed, "\n", n0 + 1):find("Zones: "), "/gp status has a zones line")
check(GP.Sources.ReportLine():find("| zones questiedb/questiedb! %(QuestieDB 3.2.0 has 1 dungeon entrances"), "/gp report says the entrances dropped")
-- Fewer dungeons on purpose: /gp zones accept makes this version the baseline.
SlashCmdList.GEARPATH("zones accept")
check(GP.db.zoneCheck.lastGood.version == "3.2.0" and Z.Status().ok, "/gp zones accept: this version is the new baseline")
check(GP.Sources.ReportLine():find("| zones qdb 7/1/1 |"), "and the report is clean again")

-- 12b. Launch night (Nov 4): QuestieDB 1.0.10 puts subzones and towns on
-- their zone's map, which is right. Subzones can't be judged by name and are
-- left out; a city that is a map inside its zone agrees. Shifted maps (6.)
-- are still caught.
qdbVersion = "1.0.10"
local launch = {}
for a, m in pairs(GOOD) do launch[a] = m end
launch[154], launch[159], launch[1497] = 1420, 1420, 1420
launch[87], launch[9], launch[108] = 1429, 1429, 1436
launch[362], launch[222] = 1411, 1412
private({ areaIdToUiMapId = src(launch), dungeons = DEADMINES })
local warnedBefore = warnings()
s = again()
check(s.ok and s.mapsFrom == "questiedb", "subzones on their zone's map: accepted (" .. tostring(s.problems[1]) .. ")")
check(s.checked == "8/8 names agree", "subzones left out, the city inside its zone agrees (" .. tostring(s.checked) .. ")")
check(warnings() == warnedBefore, "and nothing said")
local wrongCity = {}
for a, m in pairs(launch) do wrongCity[a] = m end
for a in pairs(GOOD) do wrongCity[a] = 1458 end   -- every zone put on the Undercity map
private({ areaIdToUiMapId = src(wrongCity), dungeons = DEADMINES })
qdbVersion = "1.0.11"
s = again()
check(not s.ok and s.problems[1] and s.problems[1]:find("wrong maps"), "zones put inside the wrong map: still caught (" .. tostring(s.problems[1]) .. ")")
private({ areaIdToUiMapId = src(GOOD), areaIdToUiMapIdOverride = "return { [0] = 0 }", dungeons = DEADMINES })
qdbVersion = "1.0.0"
again()

-- 13. Without QuestieDB: the game's maps, nothing said.
local lib = LibQuestieDB
LibQuestieDB = nil
local before2 = warnings()
s = again()
check(not s.hasDB and Z.ReportPart() == "zones game" and warnings() == before2, "no QuestieDB: no warning")
LibQuestieDB = lib

print(string.format("  zones: %d checks, %d failed, %d errors", checks, failed, #H.errors))
for _, e in ipairs(H.errors) do print("  ERROR: " .. tostring(e):match("^[^\n]*")) end
