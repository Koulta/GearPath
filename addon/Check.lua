-- Check: a second look at where each item comes from.
--
-- Every source comes from QuestieDB, and WoW: Forever changes things the
-- database hasn't caught up with yet. The checker asks the database again
-- (so finished quests, quests you picked up and chains you moved along are
-- current) and compares three things for each item:
--
--   the game        the item level and required level the game reports
--                   against the database's; a difference means Forever
--                   changed the item, and its source may be out of date
--   the database    a source with no location, a quest nobody is known to
--                   start, a mob far off the item's level
--   what you saw    quest rewards, loot and vendors you've seen in game
--                   (Learn.lua): seen is confirmed
--
-- It runs when you click a slot (that slot's items), every few minutes in
-- the background (everything; Settings), and with /gp check.

local _, GP = ...

local Check = { results = {}, lastAll = nil, lastSlot = {} }
GP.Check = Check

Check.MOB_GAP = 15     -- a mob this many levels off the item's level is suspicious
Check.ILVL_GAP = 3     -- item levels this far apart mean the item changed (closer is rounding)

-- What a warning says (tooltips list these), and how /gp check counts them.
Check.TEXT = {
    changed = "Forever changed this item (%s): where it comes from may be out of date",
    notInDB = "Not in the database: only seen in game",
    noLocation = "Where it is isn't in the database yet",
    noGiver = "Who starts the quest isn't in the database yet",
    mobLevel = "Drops from a level %d mob for a level %d item: worth a second look",
    newSource = "Seen in game from %s, which the database doesn't list",
    reported = "%d GearPath players saw it from %s, which the database doesn't list",
}
Check.KIND = {
    changed = "changed in Forever (where it comes from may be out of date)",
    notInDB = "only seen in game, not in the database",
    noLocation = "no location in the database",
    noGiver = "no quest giver in the database",
    mobLevel = "a mob far off the item's level",
    newSource = "seen in game from a source the database doesn't list",
    reported = "reported by other players from a source the database doesn't list",
}

local function warn(list, key, ...)
    list[#list + 1] = { key = key, text = select("#", ...) > 0 and string.format(Check.TEXT[key], ...) or Check.TEXT[key] }
end

local function DB() return GP.Sources.Database() end
local field = GP.Sources.Field

-- The item level the database expects players to wear it at.
local function itemLevelFor(rec)
    if rec.reqLevel and rec.reqLevel > 0 then return rec.reqLevel end
    if rec.ilvl and rec.ilvl > 0 then return math.max(1, rec.ilvl - 5) end
end

local function starterKnown(src)
    return src.giver or src.startItem or (src.chainStart and src.chainStart.giver)
end

-- Checks one entry (Sources.entries[id]); returns its result and keeps it.
function Check.Item(entry)
    local id, rec = entry.id, entry.rec
    local res = { warnings = {}, at = GetTime() }
    local w = res.warnings
    local db = DB()

    -- The game against the database.
    if db and rec and entry.fromDB then
        local diffs = {}
        local dbReq = field(db.Item, "requiredLevel", id)
        if type(dbReq) == "number" and dbReq > 0 and rec.reqLevel and rec.reqLevel > 0 and rec.reqLevel ~= dbReq then
            diffs[#diffs + 1] = string.format("needs level %d, database says %d", rec.reqLevel, dbReq)
        end
        local dbIlvl = field(db.Item, "itemLevel", id)
        if type(dbIlvl) == "number" and dbIlvl > 0 and rec.ilvl and rec.ilvl > 0 and math.abs(rec.ilvl - dbIlvl) >= Check.ILVL_GAP then
            diffs[#diffs + 1] = string.format("item level %d, database says %d", rec.ilvl, dbIlvl)
        end
        if GetLocale and GetLocale() == "enUS" then
            local dbName = field(db.Item, "name", id)
            if type(dbName) == "string" and rec.name and dbName ~= rec.name then
                diffs[#diffs + 1] = string.format("now called %s", rec.name)
            end
        end
        if #diffs > 0 then warn(w, "changed", table.concat(diffs, ", ")) end
    end
    if db and rec and not entry.fromDB and not entry.bags and not entry.fromJournal then
        local exists = db.Item.Exists and field(db.Item, "Exists", id)
        if exists == false or (exists == nil and not field(db.Item, "name", id)) then warn(w, "notInDB") end
    end

    -- The easiest source's own gaps.
    local src = entry.best
    if src and src.kind ~= "bags" and not src.worldDrop then
        if not src.zone and not src.dungeon and not src.mapID then
            warn(w, "noLocation")
        end
        if src.kind == "quest" and not starterKnown(src) then
            warn(w, "noGiver")
        end
        if src.kind == "drop" and type(src.level) == "number" and src.level > 0 and rec then
            local want = itemLevelFor(rec)
            if want and math.abs(src.level - want) > Check.MOB_GAP then
                warn(w, "mobLevel", src.level, want)
            end
        end
    end

    -- What you've seen yourself.
    local L = GP.db and GP.db.learned and GP.db.learned.items and GP.db.learned.items[id]
    if type(L) == "table" and (next(L.q or {}) or next(L.d or {}) or next(L.v or {})) then
        res.confirmed = true
        if db then
            local drops = {}
            for _, npc in ipairs(field(db.Item, "npcDrops", id) or {}) do drops[npc] = true end
            for key, info in pairs(L.d or {}) do
                if type(key) == "number" and not drops[key] then
                    warn(w, "newSource", info.n or ("NPC " .. key))
                end
            end
        end
    end

    -- What other GearPath users reported.
    for _, s in ipairs(entry.sources or {}) do
        if (s.reporters or 0) > 0 then
            res.reported = math.max(res.reported or 0, s.reporters)
            if s.shared and not s.dbKnown then warn(w, "reported", s.reporters, s.name or "?") end
        end
    end

    Check.results[id] = res
    return res
end

function Check.ResultFor(id) return Check.results[id] end

-- "?" when something wants a second look, a check when seen in game.
Check.ICON_WARN = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:12:12|t"
Check.ICON_OK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"

function Check.Mark(id)
    local r = Check.results[id]
    if not r then return "" end
    if #r.warnings > 0 then return Check.ICON_WARN .. " " end
    if r.confirmed or (r.reported or 0) > 0 then return Check.ICON_OK .. " " end
    return ""
end

-- ---------------------------------------------------------------------
-- Running it
-- ---------------------------------------------------------------------

-- Counts for a set of results: total, needing a look, confirmed.
local function summary(ids)
    local s = { total = 0, warn = 0, ok = 0 }
    for _, id in ipairs(ids) do
        local r = Check.results[id]
        if r then
            s.total = s.total + 1
            if #r.warnings > 0 then s.warn = s.warn + 1 elseif r.confirmed then s.ok = s.ok + 1 end
        end
    end
    return s
end
Check.Summary = summary

-- Checks entries. fresh: ask the database again first (quest progress,
-- what you've learned). Small lists run now; big ones in the background.
function Check.Run(entries, fresh, done)
    local ids = {}
    local function one(entry)
        if fresh then GP.Sources.Resolve(entry) end
        Check.Item(entry)
        ids[#ids + 1] = entry.id
    end
    local function finish()
        if fresh then GP.Score.Request() end
        local s = summary(ids)
        GP.Fire("CheckDone", s)
        if done then done(s) end
    end
    if #entries <= 60 then
        for _, e in ipairs(entries) do one(e) end
        finish()
        return
    end
    GP.RunJob("check", function()
        for _, e in ipairs(entries) do
            one(e)
            GP.Yield()
        end
    end, finish)
end

-- Every item GearPath found.
function Check.All(fresh, done)
    local list = {}
    for _, entry in pairs(GP.Sources.entries) do
        if entry.rec then list[#list + 1] = entry end
    end
    Check.lastAll = GetTime()
    Check.Run(list, fresh, done)
end

-- The items listed for one slot (a ring is either ring).
function Check.Slot(slotKey, done)
    local group = GP.Slots.GROUP[slotKey] or slotKey
    local list = {}
    for _, ev in ipairs(GP.Score.results.all or {}) do
        if (GP.Slots.GROUP[ev.slot] or ev.slot) == group and ev.entry then list[#list + 1] = ev.entry end
    end
    Check.lastSlot[group] = GetTime()
    Check.Run(list, true, done)
end

-- "just now", "4 min ago"
function Check.Ago(t)
    if not t then return nil end
    local s = GetTime() - t
    local L = GP.L
    if s < 60 then return L["just now"] end
    if s < 3600 then return string.format(L["%d min ago"], math.floor(s / 60)) end
    return string.format(L["%d h ago"], math.floor(s / 3600))
end

-- After the scan: a first look at everything (no new questions to the
-- database; the scan just asked them).
GP.On("SourcesChanged", function()
    if GP.Sources.status == "ready" then GP.Soon("check-first", function() Check.All(false) end) end
end)

-- Every few minutes (Settings), out of combat, when nothing else is running.
C_Timer.NewTicker(30, function()
    local minutes = tonumber(GP.Setting("checkEvery")) or 0
    if minutes <= 0 or GP.Sources.status ~= "ready" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if GP.JobRunning("check") or GP.JobRunning("scan") or GP.JobRunning("items") then return end
    if Check.lastAll and GetTime() - Check.lastAll < minutes * 60 then return end
    Check.All(true)
end)

GP.RegisterCommand("check", "ask the database again about every item and say what needs a second look", function()
    if GP.Sources.status ~= "ready" then
        GP.Print("Still reading the gear database; try again in a moment.")
        return
    end
    GP.Print("Checking every item against the database and the game...")
    Check.All(true, function(s)
        local kinds = {}
        for _, r in pairs(Check.results) do
            for _, wn in ipairs(r.warnings) do kinds[wn.key] = (kinds[wn.key] or 0) + 1 end
        end
        GP.Print("Checked %d items: %d need a second look, %d confirmed in game.", s.total, s.warn, s.ok)
        for k, n in pairs(kinds) do GP.Print("  %d %s", n, Check.KIND[k] or k) end
    end)
end)
