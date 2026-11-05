-- Waypoint: "Show on the map". Puts the game's own map pin where a source
-- is (and TomTom's arrow, when TomTom is installed), then opens the world
-- map at it. When you get there, the pin clears itself and chat says what
-- to do ("Talk to Nogg to start Rig Wars").
--
-- WoW: Forever has the game's map pins (C_Map.SetUserWaypoint and the
-- world map's pin), but not the retail helper that builds the point
-- (UiMapPoint is only loaded in retail), so the point is built here.

local _, GP = ...

local Waypoint = {}
GP.Waypoint = Waypoint

-- Where you walk in to a dungeon (or one of its wings): a place to pin,
-- { kind = "entrance", dungeon, mapID, x, y, zone, detail }, or nil. The
-- Dungeon Journal knows each wing's own door and the way in; the database
-- has one entrance per dungeon.
local entrances = {}
function Waypoint.Entrance(dungeon)
    if type(dungeon) ~= "string" then return nil end
    if entrances[dungeon] then return entrances[dungeon] end
    local e = GP.Journal and GP.Journal.Available() and GP.Journal.Entrance(dungeon)
    e = e or GP.Sources.DungeonEntrance(dungeon)
    if not e then
        -- "Scarlet Monastery: Graveyard" -> the monastery's door at least.
        local base = dungeon:match("^(.-)%s*:")
        if base and base ~= "" and base ~= dungeon then
            local b = Waypoint.Entrance(base)
            if b then e = { mapID = b.mapID, x = b.x, y = b.y, zone = b.zone, detail = b.detail } end
        end
    end
    if not e then return nil end
    local out = { kind = "entrance", dungeon = dungeon, mapID = e.mapID, x = e.x, y = e.y, zone = e.zone,
        detail = e.detail }
    entrances[dungeon] = out
    return out
end
GP.On("RescanRequested", function() wipe(entrances) end)

-- The place to go for a source:
--   a quest      where its chain starts (the first quest's giver), else its
--                own giver; a dungeon quest nobody outside starts: the door
--   gear from inside a dungeon (a boss, a rare, trash, a chest): the
--                dungeon's entrance, the wing's own when it's known
--   anything else  where it is
function Waypoint.PlaceOf(source)
    if not source then return nil end
    if source.kind == "entrance" then return source end
    if source.kind == "quest" then
        if source.chainStart and source.chainStart.mapID then return source.chainStart end
        if source.mapID then return source end
        return source.dungeon and Waypoint.Entrance(source.dungeon) or source
    end
    if source.dungeon and source.kind ~= "bags" then return Waypoint.Entrance(source.dungeon) or source end
    return source
end

-- The zone you go to for a source (where the route groups it).
function Waypoint.ZoneOf(source)
    local p = Waypoint.PlaceOf(source)
    return (p and p.zone) or (source and source.zone)
end

function Waypoint.CanSet(source)
    local p = Waypoint.PlaceOf(source)
    return p and p.mapID and p.x and p.y and true or false
end

local function point(mapID, x, y)
    if UiMapPoint and UiMapPoint.CreateFromCoordinates then
        return UiMapPoint.CreateFromCoordinates(mapID, x, y)
    end
    local pos = CreateVector2D and CreateVector2D(x, y) or { x = x, y = y }
    return { uiMapID = mapID, position = pos }
end

-- The game's own pin. True when it took.
local function setGamePin(mapID, x, y)
    if not (C_Map and C_Map.SetUserWaypoint) then return false end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then return false end
    local ok = pcall(C_Map.SetUserWaypoint, point(mapID, x, y))
    if not ok then return false end
    if C_Map.HasUserWaypoint and not C_Map.HasUserWaypoint() then return false end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return true
end

local function setTomTom(mapID, x, y, title)
    local tomtom = rawget(_G, "TomTom")
    if type(tomtom) ~= "table" or type(tomtom.AddWaypoint) ~= "function" then return false end
    return pcall(tomtom.AddWaypoint, tomtom, mapID, x, y, { title = title, from = "GearPath" }) == true
end

-- Opens the world map on the place (and pings the game's pin when it's set).
local function openMap(mapID, pinned)
    if InCombatLockdown and InCombatLockdown() then return false end
    if pinned and OpenMapToUserWaypoint then
        return pcall(OpenMapToUserWaypoint) == true
    end
    if OpenWorldMap then return pcall(OpenWorldMap, mapID) == true end
    if WorldMapFrame and WorldMapFrame.SetMapID then
        if not WorldMapFrame:IsShown() and ToggleWorldMap then pcall(ToggleWorldMap) end
        return pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID) == true
    end
    return false
end

-- ---------------------------------------------------------------------
-- Where you are, and how far a place is
-- ---------------------------------------------------------------------

local function xy(v)
    if type(v) ~= "table" then return nil end
    local x, y
    if v.GetXY then x, y = v:GetXY() else x, y = v.x, v.y end
    x, y = GP.Plain(x), GP.Plain(y)
    if type(x) == "number" and type(y) == "number" then return x, y end
end

local ZONE_TYPE = 3   -- Enum.UIMapType.Zone

-- { mapID, zone, x, y } for the zone you're in (a cave or a town's own map
-- counts as its zone); in a dungeon { instance = name } as well. x, y are
-- nil where the game won't say (in dungeons).
function Waypoint.Here()
    local here = {}
    if IsInInstance then
        local inside, kind = IsInInstance()
        if GP.Plain(inside) and (kind == "party" or kind == "raid") then
            here.instance = GP.Plain((GetInstanceInfo()))
        end
    end
    if not (C_Map and C_Map.GetBestMapForUnit) then return here end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    id = ok and GP.Plain(id) or nil
    -- Up from a cave or a town map to its zone (not past it).
    for _ = 1, 4 do
        if type(id) ~= "number" or here.instance then break end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        local t = info and GP.Plain(info.mapType)
        local parent = info and GP.Plain(info.parentMapID)
        if not t or t <= ZONE_TYPE or not parent or parent == 0 then break end
        id = parent
    end
    if type(id) ~= "number" then return here end
    here.mapID = id
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    here.zone = info and GP.Plain(info.name) or GP.Sources.MapName(id)
    if C_Map.GetPlayerMapPosition then
        local okp, pos = pcall(C_Map.GetPlayerMapPosition, id, "player")
        if okp then here.x, here.y = xy(pos) end
    end
    return here
end

-- Yards between two spots on one map, or nil when the game won't say.
function Waypoint.Yards(mapID, x1, y1, x2, y2)
    if not (mapID and x1 and y1 and x2 and y2 and C_Map) then return nil end
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local ok1, c1, w1 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x1, y1))
        local ok2, c2, w2 = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x2, y2))
        local ax, ay = xy(ok1 and w1)
        local bx, by = xy(ok2 and w2)
        if ax and bx and GP.Plain(c1) == GP.Plain(c2) then
            return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
        end
    end
    if C_Map.GetMapWorldSize then
        local ok, w, h = pcall(C_Map.GetMapWorldSize, mapID)
        w, h = ok and GP.Plain(w), ok and GP.Plain(h)
        if type(w) == "number" and type(h) == "number" and w > 0 then
            return math.sqrt(((x1 - x2) * w) ^ 2 + ((y1 - y2) * h) ^ 2)
        end
    end
    return nil
end

-- A dungeon name as the journal or database has it, against the one the
-- game gives inside ("Scarlet Monastery: Graveyard" is in "Scarlet Monastery").
local function squash(s) return type(s) == "string" and s:lower():gsub("[^%w]", "") or "" end
function Waypoint.SameDungeon(a, b)
    a, b = squash(a), squash(b)
    if a == "" or b == "" then return false end
    return a == b or a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

-- How close a source is to you: yards (or 0 inside its dungeon), true when
-- it's in your zone but where exactly isn't known, nil when it's elsewhere.
-- Random world drops and chests are everywhere, so never "near".
function Waypoint.Near(source, here)
    if not (source and here) or source.worldDrop or source.kind == "bags" then return nil end
    if here.instance then
        if source.dungeon and Waypoint.SameDungeon(source.dungeon, here.instance) then return 0 end
        return nil
    end
    local p = Waypoint.PlaceOf(source)
    if p and p.mapID and p.mapID == here.mapID then
        return Waypoint.Yards(here.mapID, here.x, here.y, p.x, p.y) or true
    end
    if not (p and p.mapID) and here.zone and (p and p.zone or source.zone) == here.zone then return true end
    return nil
end

-- What a pin is for, in a line, and a short name for TomTom's arrow:
-- "Gnomeregan entrance, Dun Morogh (24.3, 39.8) (for Spidertank Oilrag)"
-- "Nogg, Orgrimmar (76.0, 25.4): starts Rig Wars (for Civinad Robes)"
-- "Kelm Hargunth, The Barrens (46.6, 8.4) (for Scout's Medallion)"
function Waypoint.Describe(source, title)
    local p = Waypoint.PlaceOf(source)
    if not (p and p.mapID and p.x and p.y) then return nil end
    local where = string.format("%s (%.1f, %.1f)", p.zone or GP.Sources.MapName(p.mapID) or "?", p.x * 100, p.y * 100)
    local line, short
    if p.kind == "entrance" then
        short = p.dungeon .. " entrance"
        line = short .. ", " .. where
        if title and title ~= p.dungeon then line = line .. " (for " .. title .. ")" end
    elseif source.kind == "quest" then
        local first = source.chainStart and source.chainStart.mapID and source.chainStart or nil
        local giver = first and first.giver or source.giver
        local quest = first and first.name or source.name
        short = giver or quest or "Quest"
        line = string.format("%s, %s: starts %s", short, where, quest or "the quest")
        if title then line = line .. " (for " .. title .. ")" end
    else
        short = source.name or title or "GearPath"
        line = short .. ", " .. where
        if title and title ~= source.name then line = line .. " (for " .. title .. ")" end
    end
    return line, short, p
end

-- ---------------------------------------------------------------------
-- Getting there: the pin clears itself, and chat says what to do
-- ---------------------------------------------------------------------

Waypoint.REACH_NPC = 15     -- yards from a quest giver or vendor that count as there
Waypoint.REACH_AREA = 30    -- from a mob's spot, a chest or a dungeon door
Waypoint.EVERY = 1          -- seconds between looks

-- What to do once you're there, in a line.
function Waypoint.ArrivedText(source, title, p)
    local forItem = title and (" (for " .. title .. ")") or ""
    if p.kind == "entrance" then
        return string.format("You're at the entrance to %s%s.", p.dungeon, forItem)
    end
    if source.kind == "quest" then
        local first = source.chainStart and source.chainStart.mapID and source.chainStart or nil
        local giver = first and first.giver or source.giver
        local quest = (first and first.name) or source.name or "the quest"
        if giver and not giver:find("^the item ") then
            return string.format("Talk to %s to start %s%s.", giver, quest, forItem)
        end
        return string.format("%s starts around here%s.", quest, forItem)
    end
    if source.kind == "vendor" then
        return string.format("Talk to %s to buy %s.", source.name or "the vendor", title or "it")
    end
    if source.kind == "drop" then
        return string.format("%s should be around here%s.", source.name or "The mob", forItem)
    end
    if source.kind == "trainer" then
        return string.format("Talk to %s to learn %s%s.", source.name or "the trainer", source.skill or "the skill", forItem)
    end
    if source.kind == "object" then
        return string.format("Look for the %s around here%s.", source.name or "chest", forItem)
    end
    return string.format("You're there%s.", forItem)
end

local function stopWatch()
    local a = Waypoint.active
    if a and a.ticker then a.ticker:Cancel() end
    Waypoint.active = nil
end

-- Whether the game's pin is still the one GearPath put down.
local function stillOurs(a)
    if not (C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return false end
    local w = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if type(w) ~= "table" or GP.Plain(w.uiMapID) ~= a.mapID then return false end
    local x, y = xy(w.position)
    if x and (math.abs(x - a.x) > 0.001 or math.abs(y - a.y) > 0.001) then return false end
    return true
end

-- How far you are from the pin, or nil when the game won't say.
local function distance(a)
    if not C_Map.GetPlayerMapPosition then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, a.mapID, "player")
    local px, py = xy(ok and pos)
    if not px then return nil end
    return Waypoint.Yards(a.mapID, px, py, a.x, a.y)
end

local function arrive(a, inside)
    stopWatch()
    if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    local text = inside and string.format("You're in %s%s.", a.place.dungeon,
        a.title and (" (for " .. a.title .. ")") or "") or Waypoint.ArrivedText(a.source, a.title, a.place)
    GP.Print("%s Map pin cleared.", text)
    if a.place.detail and not inside then GP.Print("  %s", a.place.detail) end
end

-- One look: there yet?
function Waypoint.Check()
    local a = Waypoint.active
    if not a then return end
    -- Cleared, or another pin took its place: nothing more to do.
    if not stillOurs(a) then stopWatch() return end
    if a.place.kind == "entrance" and IsInInstance then
        local inside = GP.Plain((IsInInstance()))
        if inside then
            local name = GP.Plain((GetInstanceInfo()))
            if Waypoint.SameDungeon(name, a.place.dungeon) then arrive(a, true) end
            return
        end
    end
    local yards = distance(a)
    if not yards then return end
    -- Set while standing on it: wait until you've been away first.
    if not a.armed then
        if yards > a.reach * 1.5 then a.armed = true end
        return
    end
    if yards <= a.reach then arrive(a) end
end

function Waypoint.Watch(source, title, p)
    stopWatch()
    local reach = (p.kind ~= "entrance" and (source.kind == "quest" or source.kind == "vendor"))
        and Waypoint.REACH_NPC or Waypoint.REACH_AREA
    local a = { mapID = p.mapID, x = p.x, y = p.y, source = source, title = title, place = p, reach = reach }
    local yards = distance(a)
    a.armed = yards == nil or yards > reach
    Waypoint.active = a
    if C_Timer and C_Timer.NewTicker then
        a.ticker = C_Timer.NewTicker(Waypoint.EVERY, function() GP.SafeCall(Waypoint.Check) end)
    end
end

function Waypoint.Set(source, title)
    local line, short, p = Waypoint.Describe(source, title)
    if not line then
        GP.Print("No map location is known for %s.", title or (source and source.name) or "that")
        return false
    end
    local pinned = setGamePin(p.mapID, p.x, p.y)
    local arrow = setTomTom(p.mapID, p.x, p.y, short)
    openMap(p.mapID, pinned)
    if pinned or arrow then
        GP.Print("Map pin: %s.", line)
    else
        GP.Print("%s. (The game won't put a pin on that map.)", line)
    end
    -- The journal's directions for the way in, when it has them.
    if p.detail then GP.Print("  %s", p.detail) end
    if pinned then Waypoint.Watch(source, title, p) else stopWatch() end
    return pinned or arrow
end
