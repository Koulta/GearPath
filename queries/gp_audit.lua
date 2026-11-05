local GPDIR = os.getenv("GPDIR")
local DB = LibQuestieDB
local ZN = {}
for sym, id in pairs(DB.Enum.zoneIDs or {}) do
    ZN[id] = sym:lower():gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
end
C_Map = { GetAreaInfo = function(a) return ZN[a] end, GetMapInfo = function() return nil end }
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end }
local ns = {}
for line in io.lines(GPDIR .. "/GearPath.toc") do
    if not line:match("^#") and line:match("%.lua%s*$") then
        assert(loadfile(GPDIR .. "/" .. line:gsub("\\", "/"):gsub("%s+$", "")))("GearPath", ns)
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
GP.PlayerInfo(); GP.player.level = 30
GP.Sources.Database()
-- Areas that map to a uiMap (so a pin can be placed).
local I = DB.Item
local stats = { total = 0, nosource = 0, kinds = {}, unknownZone = 0, noPin = 0, noGiver = 0 }
local examples = { unknownZone = {}, noPin = {}, noGiver = {} }
local function ex(key, s) if #examples[key] < 12 then table.insert(examples[key], s) end end
for _, id in ipairs(I.GetAllIds()) do
    local class = I.class(id)
    local req = I.requiredLevel(id) or 0
    if (class == 2 or class == 4) and req >= 20 and req <= 40 then
        stats.total = stats.total + 1
        local e = { id = id, sources = {}, usable = true }
        GP.Sources.Resolve(e)
        local b = e.best
        if not b then
            stats.nosource = stats.nosource + 1
        else
            local k = b.kind .. (b.worldDrop and "/random" or "") .. (b.dungeon and "/dungeon" or "")
            stats.kinds[k] = (stats.kinds[k] or 0) + 1
            local name = I.name(id) or ("#" .. id)
            if not b.worldDrop then
                local p = GP.Waypoint.PlaceOf(b)
                if (b.zone == nil or b.zone == "Unknown zone") and not b.dungeon then
                    stats.unknownZone = stats.unknownZone + 1
                    ex("unknownZone", name .. ": " .. GP.UI.Describe(b))
                end
                if not (p and p.mapID and p.x) then
                    stats.noPin = stats.noPin + 1
                    ex("noPin", name .. ": " .. GP.UI.Describe(b))
                end
                if b.kind == "quest" and not b.giver then
                    stats.noGiver = stats.noGiver + 1
                    ex("noGiver", name .. ": " .. GP.UI.Describe(b))
                end
            end
        end
    end
end
print(string.format("armor/weapons with req 20-40: %d; no source in the data: %d", stats.total, stats.nosource))
local keys = {}
for k in pairs(stats.kinds) do keys[#keys + 1] = k end
table.sort(keys, function(a, b) return stats.kinds[a] > stats.kinds[b] end)
for _, k in ipairs(keys) do print(string.format("   best source %-22s %d", k, stats.kinds[k])) end
print(string.format("unknown zone: %d   no map pin: %d   quest with no giver: %d", stats.unknownZone, stats.noPin, stats.noGiver))
for key, list in pairs(examples) do
    print(key .. ":")
    for _, s in ipairs(list) do print("   " .. s) end
end
