-- Journal: DungeonJournal (ForeverDungeonJournal by Exehn), when it's
-- installed, as a second source of where gear comes from. It knows Forever's
-- dungeons the way players run them: each boss's loot, dungeon quests with
-- their quest givers and whether you pick one reward or get them all, level
-- ranges and entrances. GearPath reads its data while the game runs, through
-- its shared table (ForeverDungeonJournal_NS); nothing of it is copied, and
-- without it this file does nothing.

local _, GP = ...

local Journal = {}
GP.Journal = Journal

local function NS()
    local ns = rawget(_G, "ForeverDungeonJournal_NS")
    if type(ns) == "table" and type(ns.DB) == "table" then return ns end
end

function Journal.Available() return NS() ~= nil end

-- "28-33" -> 28, 33; 15 -> 15, 15
local function levels(v)
    if type(v) == "number" then return v, v end
    if type(v) == "string" then
        local a, b = v:match("^(%d+)%s*%-%s*(%d+)$")
        if a then return tonumber(a), tonumber(b) end
        local n = tonumber(v:match("%d+") or "")
        if n then return n, n end
    end
end

local function playerFaction() return (GP.player or GP.PlayerInfo()).faction end

local function factionOK(f)
    return not f or f == "Both" or f == "Neutral" or f == playerFaction()
end

-- ---------------------------------------------------------------------
-- The index: item -> every place the journal lists it (built once)
-- ---------------------------------------------------------------------

local index, dungeons

local function build()
    index, dungeons = {}, {}
    local ns = NS()
    if not ns then return end
    local function add(item, place)
        local id = type(item) == "table" and tonumber(item[1]) or nil
        if not id or id <= 0 then return end
        index[id] = index[id] or {}
        table.insert(index[id], place)
    end
    for _, name in ipairs(ns.ORDER or {}) do
        local d = ns.DB[name]
        if type(d) == "table" then
            local lo, hi = levels(d.level)
            dungeons[name] = { name = name, lo = lo, hi = hi, location = d.location,
                icon = type(d.icon) == "string" and d.icon or nil,
                entrance = type(d.entrance) == "table" and d.entrance or nil }
            for _, boss in ipairs(d.bosses or {}) do
                if type(boss) == "table" and not boss.recipeTab then
                    for _, item in ipairs(boss.loot or {}) do
                        add(item, { mode = "boss", dungeon = name, boss = boss.name, trash = boss.trash and true or nil,
                            level = levels(boss.level) })
                    end
                    local shared = ns.GetBossSharedLoot and select(2, pcall(ns.GetBossSharedLoot, name, boss))
                    for _, item in ipairs(type(shared) == "table" and shared or {}) do
                        add(item, { mode = "boss", dungeon = name, boss = boss.name, shared = true })
                    end
                end
            end
            for _, q in ipairs(d.quests or {}) do
                if type(q) == "table" then
                    local place = { mode = "quest", dungeon = name, quest = q }
                    for _, item in ipairs(q.rewardItems or {}) do add(item, place) end
                    for _, item in ipairs(q.additionalRewardItems or {}) do add(item, place) end
                end
            end
        end
    end
end

local function ensure()
    if not index then
        local ok = pcall(build)
        if not ok then index, dungeons = {}, {} end
    end
end

-- The journal's facts about a dungeon (level range, entrance, location).
function Journal.Dungeon(name)
    ensure()
    return dungeons[name]
end

-- A dungeon's (or wing's) entrance out in the world, with the journal's
-- own directions for the way in: { mapID, x, y, zone, detail }, or nil.
function Journal.Entrance(name)
    local d = Journal.Dungeon(name)
    local e = d and d.entrance
    if not (e and type(e.mapID) == "number" and type(e.x) == "number" and type(e.y) == "number") then return nil end
    return { mapID = e.mapID, x = e.x, y = e.y,
        zone = GP.Sources.MapName(e.mapID) or d.location,
        detail = type(e.detail) == "string" and e.detail ~= "" and e.detail or nil }
end

-- ---------------------------------------------------------------------
-- As GearPath sources
-- ---------------------------------------------------------------------

local function entranceOf(dungeon)
    local d = Journal.Dungeon(dungeon)
    local e = d and d.entrance
    if e and type(e.mapID) == "number" and type(e.x) == "number" then
        return e.mapID, e.x, e.y, d.location
    end
    return nil, nil, nil, d and d.location
end

-- Every place the journal lists an item, as sources GearPath shows.
function Journal.SourcesFor(itemID)
    ensure()
    local out = {}
    for _, p in ipairs(index[itemID] or {}) do
        local mapID, x, y, location = entranceOf(p.dungeon)
        if p.mode == "boss" then
            local d = Journal.Dungeon(p.dungeon)
            local name = p.shared and "Any boss" or (p.trash and "Trash mobs") or p.boss or "?"
            out[#out + 1] = { kind = "drop", name = name, dungeon = p.dungeon, journal = true,
                rank = (not p.trash and not p.shared) and "Boss" or nil, elite = not p.trash or nil,
                level = p.level or (d and d.hi), mapID = mapID, x = x, y = y, zone = location,
                bossName = p.boss }
        elseif p.mode == "quest" and factionOK(p.quest.faction) then
            local q = p.quest
            local start = type(q.startMap) == "table" and q.startMap or nil
            local s = { kind = "quest", id = tonumber(q.id), name = q.name, level = tonumber(q.level),
                reqLevel = tonumber(q.requires), dungeon = p.dungeon, journal = true,
                choice = q.rewardChoice == true,
                giver = start and start.targetName or (type(q.pickup) == "string" and q.pickup:match("^[^,]+")) or nil,
                pickupText = q.pickup }
            if start and type(start.mapID) == "number" then
                s.mapID, s.x, s.y = start.mapID, start.x, start.y
                s.zone = start.label and start.label:match("[%-—]%s*(.+)$") or GP.Sources.MapName(start.mapID)
            else
                s.mapID, s.x, s.y, s.zone = mapID, x, y, location
            end
            if s.id and GP.Sources.QuestDone(s.id) then s.done = true end
            out[#out + 1] = s
        end
    end
    return out
end

-- Items the journal lists for dungeons near your level (to add the ones the
-- database doesn't have to the gear list).
function Journal.ItemsNear(level, below, above)
    ensure()
    local out = {}
    for id, places in pairs(index) do
        for _, p in ipairs(places) do
            local d = dungeons[p.dungeon]
            local lo, hi = d and d.lo, d and d.hi
            if not lo or (hi + 5 >= level - below and lo <= level + above) then
                out[#out + 1] = id
                break
            end
        end
    end
    return out
end

-- Rebuilt if the journal is updated while playing (it has a reset for that).
GP.On("RescanRequested", function() index, dungeons = nil, nil end)
