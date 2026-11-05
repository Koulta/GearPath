-- Speed check: GearPath's full scan on the real QuestieDB (21k items).
--   GPDIR=<addon> LEVEL=30 lua5.1 qdb.lua <QuestieDB dir> speed.lua
-- Item details the client would give (slot, stats) are made up from the
-- database's class and level: enough for timing, not for scoring.
local GPDIR = os.getenv("GPDIR")
local LEVEL = tonumber(os.getenv("LEVEL") or "30")
local DB = LibQuestieDB
local I = DB.Item

C_Map = { GetAreaInfo = function() return "Zone" end, GetMapInfo = function() return nil end,
    GetBestMapForUnit = function() return 1420 end }
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end }
local ARMOR = { "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET",
    "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_CLOAK" }
local MISC = { "INVTYPE_FINGER", "INVTYPE_NECK", "INVTYPE_TRINKET" }
local WEAPON = { [0] = "INVTYPE_WEAPON", [1] = "INVTYPE_2HWEAPON", [4] = "INVTYPE_WEAPON", [5] = "INVTYPE_2HWEAPON",
    [7] = "INVTYPE_WEAPON", [8] = "INVTYPE_2HWEAPON", [10] = "INVTYPE_2HWEAPON", [15] = "INVTYPE_WEAPON",
    [19] = "INVTYPE_RANGEDRIGHT", [2] = "INVTYPE_RANGED", [3] = "INVTYPE_RANGED", [18] = "INVTYPE_RANGED", [6] = "INVTYPE_2HWEAPON" }
local function loc(id)
    local c, s = I.class(id), I.subClass(id) or 0
    if c == 2 then return WEAPON[s] or "INVTYPE_WEAPON" end
    if c == 4 then
        if s == 0 then return MISC[id % #MISC + 1] end
        if s == 6 then return "INVTYPE_SHIELD" end
        return ARMOR[id % #ARMOR + 1]
    end
end
function GetItemInfoInstant(id)
    if type(id) == "string" then id = tonumber(id:match("item:(%d+)")) end
    if not id or not I.class(id) then return nil end
    return id, "", "", loc(id) or "", 134000, I.class(id), I.subClass(id) or 0
end
local function link(id) return string.format("|cff1eff00|Hitem:%d::::::::%d:::::|h[%s]|h|r", id, LEVEL, I.name(id) or "?") end
C_Item = {
    GetItemInfoInstant = GetItemInfoInstant,
    GetItemInfo = function(x)
        local id = type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)"))
        if not id or not I.class(id) then return nil end
        return I.name(id), link(id), id % 3 + 2, I.itemLevel(id) or 1, I.requiredLevel(id) or 0, "", "", 1, loc(id) or "",
            134000, 100, I.class(id), I.subClass(id) or 0, 2
    end,
    GetItemStats = function(l)
        local id = tonumber(l:match("item:(%d+)"))
        local il = I.itemLevel(id) or 1
        return { ITEM_MOD_STAMINA_SHORT = math.floor(il / 4), ITEM_MOD_INTELLECT_SHORT = math.floor(il / 5),
            ITEM_MOD_SPELL_POWER_SHORT = id % 2 == 0 and math.floor(il / 3) or nil }
    end,
    IsItemDataCachedByID = function() return true end,
    RequestLoadItemDataByID = function() end,
    GetItemQualityColor = function() return 1, 1, 1, "ffffffff" end,
}
C_TooltipInfo = { GetHyperlink = function(l) return { lines = { { leftText = l:match("%[(.-)%]") or "?" } } } end }
C_TooltipInfo.GetItemByID = function(id) return C_TooltipInfo.GetHyperlink(link(id)) end
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemLink = function() return nil end }
function GetInventorySlotInfo(name) return 1, "" end
function GetInventoryItemLink() return nil end
function UnitLevel() return LEVEL end

-- Warm the database's own caches with what a scan reads, so the memory
-- difference below is GearPath's.
for _, id in ipairs(I.GetAllIds()) do
    local c = I.class(id)
    if c == 2 or c == 4 then
        local _ = I.requiredLevel(id), I.itemLevel(id), I.subClass(id), I.questRewards(id), I.npcDrops(id), I.vendors(id), I.objectDrops(id)
    end
end
collectgarbage("collect"); collectgarbage("collect")
local mem0 = collectgarbage("count")

local t0 = os.clock()
local ns = {}
for line in io.lines(GPDIR .. "/GearPath.toc") do
    if not line:match("^#") and line:match("%.lua%s*$") then
        assert(loadfile(GPDIR .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")))("GearPath", ns)
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
local loadMs = (os.clock() - t0) * 1000
H.Fire("PLAYER_LOGIN")
GP.player.level = LEVEL
local frames, start = 0, os.clock()
GP.Sources.Scan()
while GP.Sources.status ~= "ready" and frames < 100000 do
    H.Tick(1 / 60)
    frames = frames + 1
end
local cpu = (os.clock() - start) * 1000
collectgarbage("collect"); collectgarbage("collect")
local mem1 = collectgarbage("count")
local c = GP.Sources.counts
print(string.format("level %d: %d items in the database, %d gear for you, %d loaded", LEVEL, c.db, c.candidates, c.loaded))
print(string.format("  load: files %.0f ms", loadMs))
print(string.format("  scan: %.0f ms of work (scan job %.0f, items %.0f, score %.0f), over %d frames = %.1f s at 60 fps",
    cpu, GP.jobMs.scan or 0, GP.jobMs.items or 0, GP.Score.lastMs or 0, frames, frames / 60))
print(string.format("  memory: %.2f MB for GearPath after the scan", (mem1 - mem0) / 1024))
print(string.format("  upgrades: %d now, %d chase; errors %d", GP.Score.results.primary or 0, GP.Score.results.secondary or 0, #H.errors))
-- Again (a rescan: the database's spawn lists are already summarised),
-- and the background check of every item.
local function timeIt(start)
    local f, t = 0, os.clock()
    start()
    while (GP.Sources.status ~= "ready" or next(GP.jobMs) == nil or GP.JobRunning("check") or GP.JobRunning("scan") or GP.JobRunning("items")) and f < 100000 do
        H.Tick(1 / 60); f = f + 1
    end
    return (os.clock() - t) * 1000, f
end
local ms, f = timeIt(function() GP.Sources.Scan() end)
print(string.format("  rescan: %.0f ms of work over %d frames", ms, f))
if GP.Check and GP.Check.All then
    ms, f = timeIt(function() GP.Check.All(true) end)
    print(string.format("  check every item: %.0f ms of work over %d frames", ms, f))
end
for i = 1, math.min(3, #H.errors) do print("  error: " .. tostring(H.errors[i]):match("^[^\n]*")) end
