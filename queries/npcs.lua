local N = LibQuestieDB.Npc
local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local t = {}
    for k, x in pairs(v) do t[#t + 1] = tostring(k) .. "=" .. show(x) end
    return "{" .. table.concat(t, ", ") .. "}"
end
local Z = LibQuestieDB.Support.Get("ZoneDB").private
local d = Z.dungeons or {}
for _, name in ipairs({ "Arugal's Voidwalker", "Lordaeron Captain", "Thicket Lurker", "Saltspine", "Shadetooth", "Relic Guardian" }) do
    for _, id in ipairs(N.IdsByName(name) or {}) do
        local sp = N.spawns(id)
        print(id, name, "zoneID", N.zoneID(id), "lvl", N.maxLevel(id), "rank", N.rank(id), "spawns", show(sp))
        for area in pairs(sp or {}) do print("    area", area, "dungeon?", d[area] and d[area][1] or "no") end
    end
end
