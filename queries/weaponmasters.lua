local N = LibQuestieDB.Npc
local ids = N.GetAllIds and N.GetAllIds() or {}
print("npcs", #ids)
local id0 = ids[100]
for _, k in ipairs({"name","subName","npcFlags","friendlyToFaction","zoneID"}) do
  local ok, v = pcall(N[k] or function() return "(no field)" end, id0); print(k, ok, v)
end
local n = 0
for _, id in ipairs(ids) do
  local ok, sub = pcall(N.subName, id)
  if ok and type(sub) == "string" and sub:lower():find("weapon") then
    n = n + 1
    print(id, N.name(id), sub, N.friendlyToFaction(id), N.zoneID(id))
  end
end
print("weapon trainers:", n)
