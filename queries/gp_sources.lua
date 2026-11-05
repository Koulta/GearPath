-- GearPath's own source logic on the real QuestieDB.
local GPDIR = os.getenv("GPDIR")
local DB = LibQuestieDB
-- Zone names from QuestieDB's symbols (STRANGLETHORN_VALE -> Stranglethorn Vale).
local ZN = {}
for sym, id in pairs(DB.Enum.zoneIDs or {}) do
    ZN[id] = sym:lower():gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
end
C_Map = { GetAreaInfo = function(a) return ZN[a] end, GetMapInfo = function() return nil end }
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end,
    GetLogIndexForQuestID = function(q) if q == 1200 or q == 6561 then return 1 end end }

local ns = {}
for line in io.lines(GPDIR .. "/GearPath.toc") do
    if not line:match("^#") and line:match("%.lua%s*$") then
        local f = assert(loadfile(GPDIR .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")))
        f("GearPath", ns)
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
GP.PlayerInfo()
GP.player.level = 30
assert(GP.Sources.Database(), "no QuestieDB")

local function resolve(id)
    local entry = { id = id, sources = {}, usable = true }
    GP.Sources.Resolve(entry)
    return entry
end
local ids = {}
for _, name in ipairs({ "Gravestone Scepter", "Necrotic Wand", "Chief Brigadier Cloak", "Wing of the Whelpling",
    "Robe of the Magi", "Tigerstrike Mantle", "Brilliant Cloak", "Jutebraid Gloves", "Illusionary Rod", "Sergeant's Cloak",
    "Battle Healer's Cloak", "Windsong Drape" }) do
    for _, id in ipairs(DB.Item.IdsByName(name) or {}) do ids[#ids + 1] = { id, name } end
end
for _, p in ipairs(ids) do
    local e = resolve(p[1])
    print(string.format("%-24s effort %s  %s", p[2], tostring(e.effort), e.best and GP.UI.Describe(e.best, true) or "(no source)"))
    for i = 2, math.min(4, #e.sources) do print("      or " .. GP.UI.Describe(e.sources[i])) end
end
