local GPDIR, FDJDIR = os.getenv("GPDIR"), os.getenv("FDJDIR")
local DB = LibQuestieDB
local ZN = {}
for sym, id in pairs(DB.Enum.zoneIDs or {}) do
    ZN[id] = sym:lower():gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
end
local MAPS = { [1416] = "Alterac Mountains", [1420] = "Tirisfal Glades", [1421] = "Silverpine Forest", [1453] = "Stormwind City", [1454] = "Orgrimmar" }
C_Map = { GetAreaInfo = function(a) return ZN[a] end, GetMapInfo = function(m) return MAPS[m] and { name = MAPS[m] } end }
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end }
-- DungeonJournal's own files, as the game loads them.
local fns = {}
for _, f in ipairs({ "Core/Bootstrap.lua", "Data/Dungeons.lua", "Data/Bosses.lua", "Data/DungeonEntrances.lua" }) do
    local chunk = assert(loadfile(FDJDIR .. "/" .. f))
    local ok, err = pcall(chunk, "ForeverDungeonJournal", fns)
    if not ok then print("FDJ load error " .. f .. ": " .. tostring(err)) end
end
local ns = {}
for line in io.lines(GPDIR .. "/GearPath.toc") do
    if not line:match("^#") and line:match("%.lua%s*$") then
        assert(loadfile(GPDIR .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")))("GearPath", ns)
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
GP.PlayerInfo(); GP.player.level = 30; GP.player.faction = "Horde"
GP.Sources.Database()
print("journal available:", GP.Journal.Available())
local d = GP.Journal.Dungeon("City of Dalaran")
print("City of Dalaran:", d and d.lo, d and d.hi, d and d.entrance and d.entrance.mapID, d and d.icon)
local function show(name)
    for _, id in ipairs(DB.Item.IdsByName(name) or {}) do
        local e = { id = id, sources = {}, usable = true }
        GP.Sources.Resolve(e)
        print(string.format("%-26s effort %s  %s", name, tostring(e.effort), e.best and GP.UI.Describe(e.best, true) or "(none)"))
        for i = 2, math.min(3, #e.sources) do print("      or " .. GP.UI.Describe(e.sources[i])) end
    end
end
for _, n in ipairs({ "Ephemeral Grips", "Glinteye Slippers", "Ring of Power Regulation", "Necrotic Wand", "Embalmed Shroud",
    "Gravestone Scepter", "Vine Pruner's Cloak", "Catacomb Cloak" }) do show(n) end
-- Journal items the database doesn't know at all.
local near = GP.Journal.ItemsNear(30, 15, 5)
local missing = 0
for _, id in ipairs(near) do if not DB.Item.name(id) then missing = missing + 1 end end
print(string.format("journal items near level 30: %d (%d not in QuestieDB)", #near, missing))
