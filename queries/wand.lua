local DB = LibQuestieDB
local I, Q, N, O = DB.Item, DB.Quest, DB.Npc, DB.Object
local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local t = {}
    for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. show(x) end
    return "{" .. table.concat(t, ", ") .. "}"
end
for _, id in ipairs({ 7708 }) do
    print("ITEM", id, I.name(id), "req", I.requiredLevel(id), "ilvl", I.itemLevel(id), "class", I.class(id), I.subClass(id))
    print("  questRewards", show(I.questRewards(id)))
    print("  npcDrops", show(I.npcDrops(id)))
    print("  vendors", show(I.vendors(id)))
    print("  objectDrops", show(I.objectDrops(id)))
    print("  itemDrops", show(I.itemDrops(id)))
    print("  relatedQuests", show(I.relatedQuests(id)))
    for _, npc in ipairs(I.npcDrops(id) or {}) do
        print("   npc", npc, N.name(npc), "lvl", N.minLevel(npc), N.maxLevel(npc), "rank", N.rank(npc), "zone", N.zoneID(npc), "spawns", show(N.spawns(npc)))
    end
    for _, q in ipairs(I.questRewards(id) or {}) do
        print("   quest", q, Q.name(q), "lvl", Q.questLevel(q), "zone", Q.zoneOrSort(q))
    end
end
