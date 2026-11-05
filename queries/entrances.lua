-- Every dungeon in the real QuestieDB: does it have an entrance GearPath can pin?
local lib = LibQuestieDB
local zdb = lib.Support.Get("ZoneDB").private
local loader = loadstring or load
local areaToMap = {}
for _, key in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
    local src = zdb[key]
    if type(src) == "string" then
        local ok, t = pcall(loader(src))
        if ok and type(t) == "table" then for a, m in pairs(t) do areaToMap[a] = m end end
    elseif type(src) == "table" then for a, m in pairs(src) do areaToMap[a] = m end end
end
local rows, missing = {}, {}
for area, d in pairs(zdb.dungeons or {}) do
    local name = d[1]
    local e = type(d[4]) == "table" and d[4][1]
    local n = type(d[4]) == "table" and #d[4] or 0
    if type(e) == "table" and type(e[2]) == "number" then
        local map = areaToMap[e[1]]
        rows[#rows + 1] = string.format("%-34s entrance area %-5s map %-5s (%.1f, %.1f)%s", name, tostring(e[1]), tostring(map),
            e[2], e[3], n > 1 and ("  [" .. n .. " entrances]") or "")
        if not map then missing[#missing + 1] = name .. " (entrance area has no map)" end
    else
        missing[#missing + 1] = name .. " (no entrance)"
    end
end
table.sort(rows)
print("QuestieDB dungeons: " .. #rows)
for _, r in ipairs(rows) do print("  " .. r) end
table.sort(missing)
print("Missing or unpinnable: " .. #missing)
for _, m in ipairs(missing) do print("  " .. m) end
