-- GearPath's zone check (ZoneData.lua) on the real QuestieDB: run it after
-- every QuestieDB update. It says whether QuestieDB's zone and dungeon
-- tables are still in the shape GearPath knows, and how many dungeons and
-- entrances they have.
--   GPDIR=<addon> lua5.1 qdb.lua <QuestieDB dir> zones.lua
-- Offline there are no game map names, so the "names agree" part of the
-- check only runs in game: /gp zones there does the full check.
local GPDIR = os.getenv("GPDIR")
local DB = LibQuestieDB
local ZN = {}
for sym, id in pairs(DB.Enum.zoneIDs or {}) do
    ZN[id] = sym:lower():gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
end
C_Map = { GetAreaInfo = function(a) return ZN[a] end, GetMapInfo = function() return nil end }
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end }
H.echo = true
local ns = {}
for line in io.lines(GPDIR .. "/GearPath.toc") do
    if not line:match("^#") and line:match("%.lua%s*$") then
        assert(loadfile(GPDIR .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")))("GearPath", ns)
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
GP.PlayerInfo()
assert(GP.Sources.Database(), "no QuestieDB")
SlashCmdList.GEARPATH("zones")
local s = GP.ZoneData.Status()
print(s.ok and "RESULT: OK" or ("RESULT: CHANGED - " .. table.concat(s.problems, "; ")))
