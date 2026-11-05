-- Loads the real QuestieDB (baked Forever data) offline, then runs a query
-- script with LibQuestieDB in hand.
--   lua5.1 qdb.lua <QuestieDB dir> <query.lua>

local dir, query = arg[1], arg[2]
local here = arg[0]:match("^(.*)/[^/]*$") or "."
package.path = package.path .. ";/usr/local/share/lua/5.1/?.lua"

dofile(here .. "/wow.lua")
C_EncodingUtil = dofile(here .. "/encoding.lua")

local meta = {}
local files = {}
for line in io.lines(dir .. "/QuestieDB_Forever.toc") do
    local k, v = line:match("^## ([^:]+): ?(.*)$")
    if k then
        meta[k] = v
    elseif not line:match("^#") and line:match("%.lua%s*$") then
        files[#files + 1] = (line:gsub("\\", "/"):gsub("%s+$", ""))
    end
end
C_AddOns = { GetAddOnMetadata = function(addon, field) if addon == "QuestieDB" then return meta[field] end end }
GetAddOnMetadata = C_AddOns.GetAddOnMetadata
function GetLocale() return "enUS" end
function UnitFactionGroup() return "Horde" end
function UnitRace() return "Undead", "Scourge", 5 end
function UnitClass() return "Warlock", "WARLOCK", 9 end
function UnitLevel() return 30 end
function UnitClassBase() return "WARLOCK", 9 end
function UnitRaceBase() return "Scourge", 5 end
function GetBuildInfo() return "1.60.1", "70450", "Oct 1 2026", 16001 end
WOW_PROJECT_ID = 2
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_MAINLINE = 1

local ns = {}
local t0 = os.clock()
for _, f in ipairs(files) do
    local chunk, err = loadfile(dir .. "/" .. f)
    if not chunk then
        io.stderr:write("skip " .. f .. ": " .. tostring(err) .. "\n")
    else
        local ok, e = pcall(chunk, "QuestieDB", ns)
        if not ok then io.stderr:write("error in " .. f .. ": " .. tostring(e) .. "\n") end
    end
end
H.Fire("ADDON_LOADED", "QuestieDB")
H.Fire("PLAYER_LOGIN")
for _ = 1, 5 do H.Tick(0.1) end
io.stderr:write(string.format("QuestieDB loaded in %.1fs, mode %s\n", os.clock() - t0, tostring(LibQuestieDB and LibQuestieDB.readMode)))
dofile(query)
