-- Rank one-stat items of equal item budget for each class.
local GP = { RegisterCommand = function() end, On = function() end, RegisterEvent = function() end }
local chunk = assert(loadfile(arg[1] .. "/Data/Classes.lua"))
chunk("GearPath", GP)
local C = GP.Classes
-- budget: 1 point of a main stat; percent stats cost 14 points per 1%
local COST = { hit = 14, crit = 14, haste = 14, expertise = 14 }
local ORDER = {
  WARLOCK = { "sp", "hit", "int", "spi", "crit", "sta", "haste" },
  MAGE    = { "hit", "sp", "spi", "int", "crit", "sta" },
  PRIEST  = { "sp", "crit", "hit", "int", "sta" },
  ROGUE   = { "hit", "agi", "crit", "str", "sta" },
  HUNTER  = { "agi", "spi", "int", "sta", "hit", "crit" },
  WARRIOR = { "hit", "crit", "str", "agi", "sta" },
  PALADIN = { "hit", "crit", "str", "sp", "int", "agi" },
  SHAMAN  = { "hit", "crit", "str", "agi", "int", "spi", "sta", "sp" },  -- Nov 13: after the Nov 10 tuning
  DRUID   = { "hit", "crit", "str", "agi", "sta", "spi", "int", "sp" },
}
-- Spell power on an item costs less budget than a main stat in Classic
-- itemization (about 0.86 point each), so compare per budget point.
COST.sp = 1 / 0.86
local bad = 0
for _, class in ipairs({ "WARLOCK","MAGE","PRIEST","ROGUE","HUNTER","WARRIOR","PALADIN","SHAMAN","DRUID" }) do
  local w = C.DATA[class].weights
  local list = {}
  for _, s in ipairs(ORDER[class]) do list[#list+1] = { s = s, v = (w[s] or 0) / (COST[s] or 1) } end
  local got = {}
  for i, e in ipairs(list) do got[i] = e end
  table.sort(got, function(a, b) return a.v > b.v end)
  local ok = true
  for i = 1, #list do if got[i].s ~= list[i].s then ok = false end end
  local parts = {}
  for _, e in ipairs(got) do parts[#parts+1] = string.format("%s %.2f", e.s, e.v) end
  print(string.format("%-8s %s  %s", class, ok and "OK  " or "DIFF", table.concat(parts, " > ")))
  if not ok then bad = bad + 1 end
end
print(bad == 0 and "all orders match the guides" or (bad .. " differ"))
