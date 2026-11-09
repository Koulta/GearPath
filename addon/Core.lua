-- Core: the namespace, saved settings, events, callbacks between files,
-- a background job runner (big scans are spread over frames so the game
-- never hitches) and the slash command.

local ADDON_NAME, GP = ...
_G.GearPath = GP

GP.NAME = ADDON_NAME
GP.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "dev"
GP.TITLE = "GearPath"

-- GearPath's own words in the client's language (Data/Text.lua, drafts
-- made by machine): GP.L["Best now"] is the translation, or the English
-- when there's none.
GP.L = setmetatable({}, { __index = function(_, k) return k end })
local L = GP.L

-- A count with its word: English has "1 item" and "3 items"; a translation
-- gives one form, written to read right for any count.
function GP.Count(n, one, many)
    local t = rawget(L, many)
    if t then return string.format(t, n) end
    return string.format(n == 1 and one or many, n)
end

-- ---------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------

function GP.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- A plain, readable value or nil (secret values can't be compared or used).
function GP.Plain(v)
    if GP.IsSecret(v) then return nil end
    return v
end

local PREFIX = "|cff66c7ffGearPath|r: "
function GP.Print(msg, ...)
    if select("#", ...) > 0 then msg = string.format(msg, ...) end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

-- Errors go to the game's error handler (BugSack sees them) instead of
-- stopping whatever called us; the same error is only reported once.
-- GP.errors counts them for /gp report, with the last one's first line.
local reported = {}
GP.errors = { count = 0 }
function GP.SafeCall(fn, ...)
    local ok, err = xpcall(fn, function(e)
        if type(debugstack) == "function" and not GP.IsSecret(e) then
            return tostring(e) .. "\n" .. tostring(debugstack(2))
        end
        return e
    end, ...)
    if not ok then
        local key = GP.IsSecret(err) and "<secret>" or tostring(err):match("^[^\n]*")
        GP.errors.count = GP.errors.count + 1
        GP.errors.last = (key:gsub("^.-([%w_]+%.lua:%d+:)", "%1")):sub(1, 120)
        if not reported[key] then
            reported[key] = true
            geterrorhandler()(err)
        end
    end
    return ok, err
end

-- The NPC number in a creature's GUID ("Creature-0-...-<npc>-<spawn>"), or
-- nil for players, pets, objects and secret values.
function GP.NpcID(guid)
    guid = GP.Plain(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

function GP.Round(n, places)
    local m = 10 ^ (places or 0)
    return math.floor(n * m + 0.5) / m
end

function GP.Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Whether a mask has a single-bit flag set. Plain arithmetic, not the bit
-- library: Forever's race masks use bits 32 and 33 (Skyborne), which the
-- client's 32-bit bit.band would cut off.
function GP.HasBit(mask, flag)
    if type(mask) ~= "number" or type(flag) ~= "number" or flag <= 0 then return false end
    return math.floor(mask / flag) % 2 == 1
end

-- Copper as the game shows money (coin icons), or "1g 20s" without them.
function GP.Money(copper)
    copper = tonumber(copper) or 0
    if GetCoinTextureString then
        local ok, s = pcall(GetCoinTextureString, copper)
        if ok and s then return s end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return string.format("%dg %ds", g, s) end
    if s > 0 then return string.format("%ds %dc", s, c) end
    return string.format("%dc", c)
end

function GP.QualityColor(q)
    if type(q) ~= "number" then return 1, 1, 1, "ffffffff" end
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b, hex = C_Item.GetItemQualityColor(q)
        if r then return r, g, b, hex end
    end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b, c.hex and c.hex:gsub("|c", "") or "ffffffff" end
    return 1, 1, 1, "ffffffff"
end

function GP.CopyDefaults(dst, src)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = GP.CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- ---------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------

GP.DEFAULTS = {
    settings = {
        look = "auto",          -- "auto" (DaylightUI when it's loaded), "native" or "daylight"
        ahead = 5,              -- show items up to this many levels above you
        soon = 2,               -- items this close count as "Best now"
        dungeons = true,        -- dungeon quests and drops go under "Worth chasing"
        worldDrops = false,     -- random world drops (dropped by many mobs)
        healerGear = false,     -- healer gear (Healing its main stat): left out; in a group it's your healer's to roll on
        tooltip = true,         -- add GearPath lines to tooltips (items, wands, NPCs and mobs)
        minimapButton = true,   -- a button on the minimap that opens the window
        itemLevels = true,      -- item levels on the slots of the game's own Character window
        minimapAngle = 200,     -- where round the minimap it sits (degrees)
        notices = true,         -- a toast for an upgrade put on; chat lines for vendor upgrades and gear a level-up opens
        learn = true,           -- remember quest rewards, loot and vendors you see
        dungeonLoot = true,     -- into a dungeon or raid: a panel with its drops that are upgrades for you, by boss
        rareWatch = true,       -- in a dungeon, an icon per rare with an upgrade for you, lit when it's near
        rareWatchWorld = true,  -- out in the world, an icon, a sound and a chat line when such a rare comes into view
        englishText = false,    -- English instead of the (machine-made, draft) translation of GearPath's own text
        questPick = true,       -- mark the best quest reward for you (or the best seller) when there's a choice
        scale = 1,
        checkEvery = 10,        -- minutes between background checks of every item (0: off)
        checkOnClick = true,    -- check a slot's items when it's clicked
        share = true,           -- pass what you see on to other GearPath users, and take in theirs
        shareChannel = true,    -- through the hidden GearPath channel too: every GearPath user online (off: only guild and group)
        contentOff = {},        -- "Show:" kinds left out: quest, dungeon, vendor, drop, world, bags, pvp, rep, craft
        panelSort = "ilvl",     -- how the Character tab's upgrade lists are sorted
        browseSort = "ilvl",    -- and the Browse tab's
    },
    learned = { items = {} },   -- what you've seen in game: [itemID] = { q = {...}, d = {...}, v = {...} }
    shared = { items = {} },    -- what other GearPath users reported, the same shape (Share.lua)
    window = {},                -- position
}

GP.CHAR_DEFAULTS = {
    weights = nil,              -- your own stat weights (nil: the class defaults)
}

-- Saved settings from older versions, brought up to date once.
GP.SCHEMA = 3
local function upgrade(db)
    local from = tonumber(db.schema) or 1
    -- 3 (0.7.3): the GearPath channel is on for everyone, so sharing reaches
    -- every GearPath user, not only your guild and group. Saves from before
    -- copied the old "off" default in, so it's switched on once; a chat line
    -- at login says so and how to turn it off (Share.lua).
    if from < 3 then db.settings.shareChannel = true; db.shareNoticed = nil end
    db.schema = GP.SCHEMA
end

function GP.InitDB()
    GearPathDB = GP.CopyDefaults(GearPathDB, GP.DEFAULTS)
    GearPathCharDB = GP.CopyDefaults(GearPathCharDB, GP.CHAR_DEFAULTS)
    upgrade(GearPathDB)
    GP.db = GearPathDB
    GP.char = GearPathCharDB
end

function GP.Setting(key) return GP.db and GP.db.settings[key] end

function GP.SetSetting(key, value)
    GP.db.settings[key] = value
    GP.Fire("SettingChanged", key, value)
end

-- ---------------------------------------------------------------------
-- Game events: one frame, many handlers
-- ---------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do GP.SafeCall(list[i], event, ...) end
end)

local unknownEvents = {}
function GP.RegisterEvent(event, fn)
    if unknownEvents[event] then return false end
    local list = handlers[event]
    if not list then
        -- Events this client doesn't know are skipped, never an error.
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then
            unknownEvents[event] = true
            return false
        end
        list = {}
        handlers[event] = list
    end
    list[#list + 1] = fn
    return true
end

-- ---------------------------------------------------------------------
-- Callbacks between our own files
-- ---------------------------------------------------------------------

local callbacks = {}

function GP.On(name, fn)
    callbacks[name] = callbacks[name] or {}
    table.insert(callbacks[name], fn)
end

function GP.Fire(name, ...)
    local list = callbacks[name]
    if not list then return end
    for i = 1, #list do GP.SafeCall(list[i], ...) end
end

-- ---------------------------------------------------------------------
-- Background jobs. A job is a function run as a coroutine; it calls
-- GP.Yield() often and gets a few milliseconds of every frame, so a scan
-- of twenty thousand items never freezes the game.
-- ---------------------------------------------------------------------

GP.BUDGET_MS = 4
local jobs = {}
local runner = CreateFrame("Frame")
runner:Hide()

local clock = debugprofilestop or function() return (os and os.clock and os.clock() or 0) * 1000 end
GP.Clock = clock               -- milliseconds, for timings
GP.jobMs = {}                  -- [key] = milliseconds of work the last finished run of a job took
local sliceStart = 0

function GP.Yield()
    if coroutine.running() and clock() - sliceStart > GP.BUDGET_MS then
        coroutine.yield()
    end
end

runner:SetScript("OnUpdate", function()
    -- A job that finishes may start another (the scan starts item loading),
    -- so the list is copied before it's walked.
    local keys = {}
    for key in pairs(jobs) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do
        local job = jobs[key]
        if job then
            sliceStart = clock()
            local ok, err = coroutine.resume(job.co)
            job.ms = (job.ms or 0) + (clock() - sliceStart)
            if not ok then
                if jobs[key] == job then jobs[key] = nil end
                GP.SafeCall(error, err, 0)
            elseif coroutine.status(job.co) == "dead" then
                if jobs[key] == job then jobs[key] = nil end
                GP.jobMs[key] = job.ms
                if job.done then GP.SafeCall(job.done) end
            end
        end
    end
    if next(jobs) == nil then runner:Hide() end
end)

-- Starts (or restarts) the job called key.
function GP.RunJob(key, fn, done)
    jobs[key] = { co = coroutine.create(fn), done = done }
    runner:Show()
end

function GP.JobRunning(key) return jobs[key] ~= nil end

-- Runs fn once on the next frame, however often it's asked for before then.
local pending = {}
function GP.Soon(key, fn)
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(0, function()
        pending[key] = nil
        GP.SafeCall(fn)
    end)
end

-- ---------------------------------------------------------------------
-- The player
-- ---------------------------------------------------------------------

-- GearPath's memory in KB (nil if the game doesn't say). Asking the game
-- to count costs a moment, so only on request.
function GP.MemoryKB()
    local update = (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage) or UpdateAddOnMemoryUsage
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    if not (update and get) then return nil end
    pcall(update)
    local ok, kb = pcall(get, ADDON_NAME)
    return ok and tonumber(GP.Plain(kb)) or nil
end

function GP.AddOnLoaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return f ~= nil and GP.Plain(f(name)) and true or false
end

function GP.PlayerInfo()
    local p = GP.player or {}
    GP.player = p
    p.level = UnitLevel("player") or 1
    local _, class = UnitClass("player")
    p.class = class
    local _, raceFile, raceID = UnitRace("player")
    p.race, p.raceID = raceFile, raceID
    p.faction = UnitFactionGroup("player")
    return p
end

-- ---------------------------------------------------------------------
-- Slash command and the addon list button
-- ---------------------------------------------------------------------

local commands = {}
function GP.RegisterCommand(name, help, fn) commands[name] = { help = help, fn = fn } end

SLASH_GEARPATH1 = "/gearpath"
SLASH_GEARPATH2 = "/gp"
SlashCmdList.GEARPATH = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        GP.Toggle()
        return
    end
    local c = commands[cmd]
    if c then
        c.fn(rest)
        return
    end
    GP.Print("Commands:")
    GP.Print("  /gp - open or close the window")
    local names = {}
    for name in pairs(commands) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do GP.Print("  /gp %s - %s", name, commands[name].help) end
end

function GP.Toggle(page)
    if not GP.UI or not GP.UI.Toggle then return end
    GP.UI.Toggle(page)
end

function GearPath_Toggle() GP.Toggle() end

-- The key binding (Bindings.xml): Key Bindings > AddOns > GearPath.
BINDING_HEADER_GEARPATH = "GearPath"
BINDING_NAME_GEARPATH_TOGGLE = "Open or close GearPath"
-- The tooltip of GearPath's buttons (the addon list's and the minimap's):
-- the Route's numbers and its top picks, then what the clicks do.
GP.COMPARTMENT_PICKS = 3
function GP.LauncherTooltip(owner, anchor, hints)
    local tt = GameTooltip
    tt:SetOwner(owner or UIParent, anchor or "ANCHOR_LEFT")
    tt:SetText(GP.TITLE)
    local Plan = GP.UI and GP.UI.Plan
    local status = GP.Sources and GP.Sources.status
    if status ~= "ready" or not (Plan and Plan.Summary) then
        tt:AddLine(L["Reading the gear database..."], 0.6, 0.6, 0.6)
    else
        local now, places, chase, pct, picks = Plan.Summary()
        local both = rawget(L, "%d upgrades in %d places")
        local nowText = both and string.format(both, now, places) or
            (GP.Count(now, "%d upgrade", "%d upgrades") .. " in " .. GP.Count(places, "%d place", "%d places"))
        tt:AddDoubleLine(L["Best now"], now > 0 and nowText or L["none"], 0.25, 1, 0.25, 1, 1, 1)
        tt:AddDoubleLine(L["Worth chasing"], chase > 0 and GP.Count(chase, "%d upgrade", "%d upgrades") or L["none"],
            1, 0.65, 0.1, 1, 1, 1)
        for i = 1, math.min(GP.COMPARTMENT_PICKS, #picks) do
            local ev = picks[i]
            local r, g, b = GP.QualityColor(ev.rec.quality)
            local gain = GP.UI.GainText(ev)
            local slot = GP.Slots.Label(ev.slot)
            tt:AddDoubleLine("  " .. (ev.rec.name or "?"), gain == "new" and string.format(L["%s (empty now)"], slot) or (gain .. " " .. slot),
                r, g, b, 0.25, 1, 0.25)
        end
        if pct and pct >= 1 then
            tt:AddLine(string.format(L["About +%d%% to your GearPath score"], GP.Round(pct)), 0.6, 0.6, 0.6)
        end
    end
    for _, line in ipairs(hints or { L["Click to open GearPath."] }) do tt:AddLine(line, 1, 1, 1) end
    tt:Show()
end
function GearPath_CompartmentEnter(_, button) GP.LauncherTooltip(button, "ANCHOR_LEFT") end
function GearPath_CompartmentLeave() GameTooltip:Hide() end

GP.RegisterCommand("rescan", "rebuild the gear list from the database", function()
    GP.Fire("RescanRequested")
end)

GP.RegisterCommand("status", "what GearPath found (database, items, look)", function()
    GP.Fire("StatusRequested")
end)

-- ---------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------

GP.RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then return end
    GP.InitDB()
    GP.Fire("Loaded")
end)

GP.RegisterEvent("PLAYER_LOGIN", function()
    GP.PlayerInfo()
    GP.loggedIn = true
    GP.Fire("Login")
    -- A client language GearPath can't read items in: said once.
    local code = GetLocale and GP.Plain(GetLocale())
    if GP.LOCALES and code and not GP.LOCALES.READS[code] then
        GP.Print("Your game's language (%s) isn't one GearPath can read items in yet, so bonuses on \"Equip:\" lines (spell power, hit, crit) aren't counted.", code)
    end
end)

GP.RegisterEvent("PLAYER_LEVEL_UP", function(_, level)
    GP.PlayerInfo()
    if type(level) == "number" then GP.player.level = level end
    GP.Fire("LevelChanged", GP.player.level)
end)
