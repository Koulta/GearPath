local DB = LibQuestieDB
local I, Q, N, O = DB.Item, DB.Quest, DB.Npc, DB.Object
local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local t = {}
    for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. show(x) end
    return "{" .. table.concat(t, ", ") .. "}"
end
local function spawnsSummary(sp)
    if type(sp) ~= "table" then return "none" end
    local t = {}
    for zone, list in pairs(sp) do t[#t + 1] = zone .. ":" .. (type(list) == "table" and #list or 0) end
    return table.concat(t, " ")
end
local names = { "Gravestone Scepter", "Necrotic Wand", "Chief Brigadier Cloak", "Wing of the Whelpling", "Robe of the Magi",
    "Tigerstrike Mantle", "Brilliant Cloak", "Souvenir Sea Shell", "Jutebraid Gloves", "Illusionary Rod" }
for _, name in ipairs(names) do
    local ids = I.IdsByName and I.IdsByName(name) or {}
    for _, id in ipairs(ids or {}) do
        print(string.format("ITEM %d %s  req %s ilvl %s", id, name, tostring(I.requiredLevel(id)), tostring(I.itemLevel(id))))
        for _, q in ipairs(I.questRewards(id) or {}) do
            local starters = Q.startedBy(q)
            print(string.format("   quest %d %s [lvl %s, req %s] zone %s  startedBy %s  pre %s", q, tostring(Q.name(q)), tostring(Q.questLevel(q)),
                tostring(Q.requiredLevel(q)), tostring(Q.zoneOrSort(q)), show(starters), show(Q.preQuestSingle(q) or Q.preQuestGroup(q))))
        end
        for _, npc in ipairs(I.npcDrops(id) or {}) do
            print(string.format("   drop  %d %s lvl %s rank %s zone %s spawns %s", npc, tostring(N.name(npc)), tostring(N.maxLevel(npc)),
                tostring(N.rank(npc)), tostring(N.zoneID(npc)), spawnsSummary(N.spawns(npc))))
        end
        for _, npc in ipairs(I.vendors(id) or {}) do
            print(string.format("   vendor %d %s zone %s friendly %s", npc, tostring(N.name(npc)), tostring(N.zoneID(npc)), tostring(N.friendlyToFaction(npc))))
        end
        for _, obj in ipairs(I.objectDrops(id) or {}) do
            print(string.format("   object %d %s zone %s spawns %s", obj, tostring(O.name(obj)), tostring(O.zoneID(obj)), spawnsSummary(O.spawns(obj))))
        end
    end
end
