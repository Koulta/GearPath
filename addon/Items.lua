-- Items: what an item is, read live from the game (so it's right even after
-- Blizzard changes an item): name, quality, level, slot, and its stats as
-- plain numbers we can score. The stats come from the game's stat table,
-- with the item's "Equip:" lines read from its tooltip for what the table
-- leaves out (spell power, hit and crit as percentages, mana per 5).

local _, GP = ...

local Items = {}
GP.Items = Items

Items.cache = {}          -- [itemID] = record
Items.linkCache = {}      -- [link] = record (equipped items keep their random suffix)

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local IsCached = C_Item and C_Item.IsItemDataCachedByID
local RequestLoad = C_Item and C_Item.RequestLoadItemDataByID

-- ---------------------------------------------------------------------
-- The game's stat table -> our keys
-- ---------------------------------------------------------------------

local STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
    RESISTANCE0_NAME = "armor",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
    ITEM_MOD_SPELL_POWER_SHORT = "sp", ITEM_MOD_SPELLPOWER_SHORT = "sp", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "sp",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_HIT_SPELL_RATING_SHORT = "hit",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit", ITEM_MOD_HIT_RANGED_RATING_SHORT = "hit",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit", ITEM_MOD_CRIT_RANGED_RATING_SHORT = "crit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste", ITEM_MOD_HASTE_SPELL_RATING_SHORT = "haste",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "ap",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense",
    ITEM_MOD_BLOCK_VALUE_SHORT = "block",
    ITEM_MOD_DODGE_RATING_SHORT = "dodge", ITEM_MOD_PARRY_RATING_SHORT = "parry",
}
Items.STAT_KEYS = STAT_KEYS

-- Forever shows hit, crit and the like as percentages on the tooltip, and
-- the tooltip's own percentage is used when it has one (see ReadStats).
-- The stat table carries the same thing as a rating, at flat rates: 10 hit
-- or expertise, 14 crit, 12 dodge and 20 parry to 1% (Sharpie's Gear Judge
-- 3.2.11's Forever rates; senseos.gg's read of the client's items, Nov 7:
-- "1% hit = 10", "1% crit = 14"). Haste has no published rate: crit's.
-- (Until 0.7.16 this was a guess: 14 for everything, and a number of 5 or
-- less taken for a percentage, so 0.5% hit read from the table was 5%.)
local PERCENT_STATS = { hit = true, crit = true, haste = true, dodge = true, parry = true, expertise = true }
local RATING_PER_PERCENT = { hit = 10, expertise = 10, crit = 14, haste = 14, dodge = 12, parry = 20 }
Items.RATING_PER_PERCENT = RATING_PER_PERCENT
local function asPercent(v, key)
    return v / (RATING_PER_PERCENT[key] or 14)
end

-- Spell power that heals as much as it damages ("Increases damage and
-- healing done by magical spells..."): it counts as Healing too.
local BOTH_SPELL_POWER = { ITEM_MOD_SPELL_POWER_SHORT = true, ITEM_MOD_SPELLPOWER_SHORT = true }

-- ---------------------------------------------------------------------
-- Tooltip lines: the client's own language (Data/Locales.lua) first, then
-- English (which Italian clients show, and Forever's new lines may too)
-- ---------------------------------------------------------------------

local SCHOOLS = { shadow = "spShadow", fire = "spFire", frost = "spFrost", arcane = "spArcane",
    nature = "spNature", holy = "spHoly" }

-- Checked in order; the first that matches a line wins. "sph" is spell
-- power that heals as much as it damages: it counts as sp and heal.
local LINE_PATTERNS = {
    { "increases damage and healing done by magical spells and effects by up to (%d+)", "sph" },
    { "increases spell power by (%d+)", "sph" },
    { "increases damage done by (%a+) spells and effects by up to (%d+)", "school" },
    { "increases healing done by spells and effects by up to (%d+)", "heal" },
    { "increases healing done by magical spells and effects by up to (%d+)", "heal" },
    { "improves your chance to hit with spells by ([%d%.]+)%%", "hit" },
    { "improves your chance to hit by ([%d%.]+)%%", "hit" },
    { "improves your chance to hit with melee attacks by ([%d%.]+)%%", "hit" },
    { "improves your chance to hit with ranged attacks by ([%d%.]+)%%", "hit" },
    { "improves your chance to hit with melee and ranged attacks by ([%d%.]+)%%", "hit" },
    { "improves your chance to hit with all attacks and spells by ([%d%.]+)%%", "hit" },
    { "improves your chance to get a critical strike with spells by ([%d%.]+)%%", "crit" },
    { "improves your chance to get a critical strike by ([%d%.]+)%%", "crit" },
    { "improves your chance to get a critical strike with melee attacks by ([%d%.]+)%%", "crit" },
    { "improves your chance to get a critical strike with ranged attacks by ([%d%.]+)%%", "crit" },
    { "improves your chance to get a critical strike with melee and ranged attacks by ([%d%.]+)%%", "crit" },
    { "improves your chance to get a critical strike with all attacks and spells by ([%d%.]+)%%", "crit" },
    { "restores (%d+) mana per 5 sec", "mp5" },
    { "(%d+) mana per 5 sec", "mp5" },
    { "%+(%d+) ranged attack power", "rap" },
    { "increases ranged attack power by (%d+)", "rap" },
    { "%+(%d+) attack power", "ap" },
    { "increases attack power by (%d+)", "ap" },
    { "increases your expertise by (%d+)", "expertise" },
    { "increases expertise rating by (%d+)", "expertise" },
    -- Forever's wording: "Reduces chance to be Dodged or Parried by 1.0%."
    { "reduces chance to be dodged or parried by ([%d%.]+)%%", "expertise" },
    { "reduces the chance for your attacks to be dodged or parried by ([%d%.]+)%%", "expertise" },
    { "increased defense %+(%d+)", "defense" },
    { "increases the block value of your shield by (%d+)", "block" },
    { "increases your chance to dodge an attack by ([%d%.]+)%%", "dodge" },
    { "increases your chance to parry an attack by ([%d%.]+)%%", "parry" },
    -- Random suffixes and enchant-style green lines ("+7 Fire Spell Damage").
    { "%+(%d+) damage and healing spells", "sph" },
    { "%+(%d+) spell damage and healing", "sph" },
    { "%+(%d+) spell power", "sph" },
    { "%+(%d+) (%a+) spell damage", "school" },
    { "%+(%d+) healing spells", "heal" },
    { "%+(%d+) healing", "heal" },
}

-- The client's language ("deDE"); Items.locale stands in for it in tests.
function Items.Locale()
    return Items.locale or (GetLocale and GP.Plain(GetLocale())) or "enUS"
end

local patternsFor = {}
local function linePatterns(code)
    local list = patternsFor[code]
    if list then return list end
    list = {}
    local own = GP.LOCALES and GP.LOCALES.LINES[code]
    for _, p in ipairs(own or {}) do list[#list + 1] = p end
    for _, p in ipairs(LINE_PATTERNS) do list[#list + 1] = p end
    patternsFor[code] = list
    return list
end

-- The stat a school's name stands for ("Feuer", "d'Ombre" -> spFire, spShadow).
local function schoolKey(word, code)
    local L = GP.LOCALES
    local w = L and L.SchoolWord(word) or (type(word) == "string" and word:lower() or "")
    local own = L and L.SCHOOLS[code]
    return (own and own[w]) or SCHOOLS[w]
end

-- "1,5" -> 1.5
local function number(s)
    return type(s) == "string" and tonumber((s:gsub(",", "."))) or nil
end

-- "(17.5 damage per second)" in the client's own words (DPS_TEMPLATE).
local dpsPattern, dpsTemplate
local function dpsLinePattern()
    local t = type(DPS_TEMPLATE) == "string" and DPS_TEMPLATE or "(%s damage per second)"
    if t ~= dpsTemplate then
        dpsPattern = GP.FormatPattern(t:lower(), "([%d%.,]+)", nil, "%(([%d%.,]+) damage per second%)")
        dpsTemplate = t
    end
    return dpsPattern
end

local function lineText(line, field)
    if not line then return nil end
    local v = line[field]
    if v == nil and line.args then
        for _, arg in ipairs(line.args) do
            if arg.field == field then v = arg.stringVal break end
        end
    end
    if type(v) ~= "string" or GP.IsSecret(v) then return nil end
    return v
end

local function tooltipLines(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    if TooltipUtil and TooltipUtil.SurfaceArgs and data.args then
        pcall(TooltipUtil.SurfaceArgs, data)
    end
    return data.lines
end

local classesPattern
local function classesLinePattern()
    if classesPattern == nil then
        local s = type(ITEM_CLASSES_ALLOWED) == "string" and ITEM_CLASSES_ALLOWED or "Classes: %s"
        classesPattern = "^" .. GP.FormatPattern(s, nil, nil, "Classes: (.+)") .. "$"
    end
    return classesPattern
end

-- A requirement the game shows in red ("Requires Sergeant", "Requires
-- Friendly with Darkspear Trolls", "Requires Tailoring (150)"): one you
-- don't meet. "Requires Level" is left out (the level is handled apart).
-- Built from the game's own templates, so the word "Requires" can sit
-- anywhere in the line (Korean puts it last).
local REQ_TEMPLATE = type(ITEM_REQ_SKILL) == "string" and ITEM_REQ_SKILL or "Requires %s"
local LEVEL_TEMPLATE = type(ITEM_MIN_LEVEL) == "string" and ITEM_MIN_LEVEL or "Requires Level %d"
local REQ_PATTERN = "^" .. GP.FormatPattern(REQ_TEMPLATE, nil, nil, "Requires (.+)") .. "$"
local LEVEL_PATTERN = "^" .. GP.FormatPattern(LEVEL_TEMPLATE, nil, nil, "Requires Level %d+") .. "$"

local function isRed(line)
    local c = line and line.leftColor
    if type(c) ~= "table" then return false end
    local r, g, b = GP.Plain(c.r), GP.Plain(c.g), GP.Plain(c.b)
    return type(r) == "number" and type(g) == "number" and type(b) == "number" and r > 0.9 and g < 0.3 and b < 0.3
end

local function unmetNeed(line, left)
    if left:match(LEVEL_PATTERN) then return nil end
    local need = left:match(REQ_PATTERN)
    if not need or not isRed(line) then return nil end
    return need
end

-- Any requirement but the level, met or not ("Sergeant", "Silverwing
-- Sentinels - Honored"): what kind of gear it is, whatever the line's colour
-- (dmann420, Nov 7: Illiyana Moonblaze's reputation gear listed as plain
-- vendor gear).
local function anyNeed(left)
    if left:match(LEVEL_PATTERN) then return nil end
    return left:match(REQ_PATTERN)
end

-- A reputation requirement: { faction, standing (1-8), text } or nil.
-- From the game's template ("Requires %s - %s") and its standing names.
local REP_TEMPLATE = type(ITEM_REQ_REPUTATION) == "string" and ITEM_REQ_REPUTATION or "Requires %s - %s"
local REP_PATTERN = "^" .. GP.FormatPattern(REP_TEMPLATE, nil, nil, "Requires (.+) %- (.+)") .. "$"
local standings
local function standingOf(word)
    if not standings then
        standings = {}
        local en = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
        for i = 1, 8 do
            standings[en[i]] = i
            for _, suffix in ipairs({ "", "_FEMALE" }) do
                local name = rawget(_G, "FACTION_STANDING_LABEL" .. i .. suffix)
                if type(name) == "string" and name ~= "" then standings[name] = i end
            end
        end
    end
    return standings[word]
end

function Items.RepNeed(left)
    if type(left) ~= "string" then return nil end
    local a, b = left:match(REP_PATTERN)
    if not a then return nil end
    -- Either order (some languages put the standing first).
    local faction, standing = a, standingOf(b)
    if not standing then faction, standing = b, standingOf(a) end
    if not standing then return nil end
    local text = left:match(REQ_PATTERN) or (faction .. " - " .. b)
    return { faction = faction, standing = standing, text = text }
end

-- Your standing with each faction the game lists: { [name] = 1-8 }.
-- Factions under a collapsed header aren't listed: unknown (nil).
local standingCache
function Items.ResetStandings() standingCache = nil end
local function myStandings()
    if standingCache then return standingCache end
    local t = {}
    if GetNumFactions and GetFactionInfo then
        for i = 1, GP.Plain(GetNumFactions()) or 0 do
            local ok, name, _, standing, _, _, _, _, _, isHeader, _, hasRep = pcall(GetFactionInfo, i)
            name, standing = ok and GP.Plain(name), ok and GP.Plain(standing)
            if type(name) == "string" and type(standing) == "number" and (not isHeader or hasRep) then
                t[name] = standing
            end
        end
    end
    standingCache = t
    return t
end

GP.RegisterEvent("UPDATE_FACTION", function()
    standingCache = nil
    if GP.Score then GP.Score.Request() end
end)

-- Whether you meet a reputation requirement: true, false, or nil (can't tell).
function Items.RepMet(rep)
    if type(rep) ~= "table" then return nil end
    local have = myStandings()[rep.faction]
    if not have then return nil end
    return have >= rep.standing
end

-- What an item needs that you don't have, now: a reputation is checked
-- against your standing (so it clears as you earn it, without a /reload),
-- anything else is the tooltip's red line.
function Items.NeedsOf(rec)
    if not rec then return nil end
    if rec.rep then
        local met = Items.RepMet(rec.rep)
        if met == true then return nil end
        if met == false then return rec.rep.text end
    end
    return rec.needs
end

-- Whether the game has finished the item's tooltip: one still loading has
-- only its name (or "Retrieving item information").
function Items.TooltipComplete(data)
    local lines = tooltipLines(data)
    if not lines or #lines < 2 then return false end
    local first = lineText(lines[1], "leftText")
    if first and type(RETRIEVING_ITEM_INFO) == "string" and first == RETRIEVING_ITEM_INFO then return false end
    return true
end

-- Reads stats out of an item's tooltip. Returns found (key -> value),
-- the classes it's limited to (a set of localized names, or nil),
-- whether it's unique-equipped, and a requirement you don't meet (or nil).
function Items.ParseTooltip(data)
    local found, classes, unique, needs, rule, rep = {}, nil, false, nil, nil, nil
    local lines = tooltipLines(data)
    if not lines then return found, classes, unique, needs, rule, rep end
    local equipPrefix = type(ITEM_SPELL_TRIGGER_ONEQUIP) == "string" and ITEM_SPELL_TRIGGER_ONEQUIP:lower() or "equip:"
    local code = Items.Locale()
    local patterns = linePatterns(code)
    for i = 2, #lines do
        local left = lineText(lines[i], "leftText")
        if left then
            local text = left:lower()
            if text:sub(1, #equipPrefix) == equipPrefix then text = text:sub(#equipPrefix + 1) end
            text = text:gsub("^%s+", "")
            local dps = text:match(dpsLinePattern())
            if dps then found.dps = number(dps) or found.dps end
            for _, p in ipairs(patterns) do
                local a, b = text:match(p[1])
                if a then
                    local key, value = p[2]
                    if key == "school" then
                        -- The school's name and the number, in either order.
                        local word, num = a, b
                        if number(a) and not number(b) then word, num = b, a end
                        key = schoolKey(word, code)
                        value = number(num)
                    else
                        value = number(a)
                    end
                    if key == "sph" and value then
                        found.sp = (found.sp or 0) + value
                        found.heal = (found.heal or 0) + value
                    elseif key and value then
                        found[key] = (found[key] or 0) + value
                    end
                    break
                end
            end
            -- A weapon's speed: the number on the right of its damage line
            -- ("37 - 69 Damage" / "Speed 2.90"), in any language.
            local right = lineText(lines[i], "rightText")
            if right and not found.speed and left:match("%d+%s*%-%s*%d+") and not right:find("%%") then
                local sp = right:match("(%d+[%.,]%d+)%s*$")
                if sp then found.speed = number(sp) end
            end
            local list = left:match(classesLinePattern())
            if list then
                classes = {}
                for name in list:gmatch("[^,]+") do classes[(name:gsub("^%s+", ""):gsub("%s+$", ""))] = true end
            end
            if left == ITEM_UNIQUE or left == "Unique" or (ITEM_UNIQUE_EQUIPPABLE and left == ITEM_UNIQUE_EQUIPPABLE) then
                unique = true
            end
            needs = needs or unmetNeed(lines[i], left)
            rule = rule or anyNeed(left)
            rep = rep or Items.RepNeed(left)
        end
    end
    return found, classes, unique, needs, rule, rep
end

-- ---------------------------------------------------------------------
-- Stats of one item
-- ---------------------------------------------------------------------

-- Plain numbers from the game's stat table plus the tooltip's lines (the
-- tooltip only fills what the table didn't have, so nothing counts twice;
-- for a percentage the tooltip's own number wins over the table's).
function Items.ReadStats(link, tooltipData)
    local stats = {}
    local ok, raw = pcall(GetItemStats, link)
    if ok and type(raw) == "table" then
        local healing = raw.ITEM_MOD_SPELL_HEALING_DONE_SHORT ~= nil
        for k, v in pairs(raw) do
            local key = STAT_KEYS[k]
            if not key then
                local school = k:match("^ITEM_MOD_SPELL_DAMAGE_(%u+)_SHORT$")
                if school then key = SCHOOLS[school:lower()] end
            end
            if key and type(v) == "number" and not GP.IsSecret(v) then
                if PERCENT_STATS[key] then v = asPercent(v, key) end
                stats[key] = (stats[key] or 0) + v
                if BOTH_SPELL_POWER[k] and not healing then stats.heal = (stats.heal or 0) + v end
            end
        end
    end
    local found, classes, unique, needs, rule, rep = Items.ParseTooltip(tooltipData)
    for k, v in pairs(found) do
        if stats[k] == nil or PERCENT_STATS[k] then stats[k] = v end
    end
    return stats, classes, unique, needs, rule, rep
end

local function tooltipFor(idOrLink)
    if not C_TooltipInfo then return nil end
    local ok, data
    if type(idOrLink) == "number" then
        ok, data = pcall(C_TooltipInfo.GetItemByID, idOrLink)
    else
        ok, data = pcall(C_TooltipInfo.GetHyperlink, idOrLink)
    end
    return ok and data or nil
end

-- Builds the record once the client has the item.
local function build(id, link)
    local name, itemLink, quality, ilvl, reqLevel, _, _, _, equipLoc, icon, sellPrice, classID, subClassID = GetItemInfo(link or id)
    if not name then return nil end
    link = link or itemLink
    local rec = {
        id = id, name = name, link = link, quality = quality, ilvl = ilvl, reqLevel = reqLevel or 0,
        equipLoc = equipLoc, icon = icon, classID = classID, subClassID = subClassID,
        sellPrice = type(sellPrice) == "number" and sellPrice or nil,
    }
    local tip = tooltipFor(link)
    rec.stats, rec.classes, rec.unique, rec.needs, rec.rule, rec.rep = Items.ReadStats(link, tip)
    -- The weapon speed is kept apart from the stats (it isn't a bonus).
    rec.speed, rec.stats.speed = rec.stats.speed, nil
    -- A tooltip the game hadn't finished: read again later (Items.Get),
    -- or a "Requires" line could be missed until /reload.
    if C_TooltipInfo and not Items.TooltipComplete(tip) then rec.partial = 0 end
    return rec
end

Items.REREAD_TRIES = 5

-- Reads a record's tooltip again, if the first read came back unfinished.
local function reread(rec)
    local now = GetTime and GetTime() or 0
    if rec.partialAt and now - rec.partialAt < 1 then return end
    rec.partialAt = now
    rec.partial = rec.partial + 1
    local tip = tooltipFor(rec.link or rec.id)
    if not Items.TooltipComplete(tip) then
        if rec.partial >= Items.REREAD_TRIES then rec.partial = nil end
        return
    end
    rec.stats, rec.classes, rec.unique, rec.needs, rec.rule, rec.rep = Items.ReadStats(rec.link, tip)
    rec.speed, rec.stats.speed = rec.stats.speed, nil
    rec.partial = nil
end

function Items.IDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- What's known without loading: slot, class, subclass, icon.
function Items.Instant(id)
    if not GetItemInfoInstant then return nil end
    local ok, itemID, _, _, equipLoc, icon, classID, subClassID = pcall(GetItemInfoInstant, id)
    if not ok or not itemID then return nil end
    return equipLoc, classID, subClassID, icon
end

-- The record if the client has the item, else nil (and it's asked for).
-- A skill or rank changed: items waiting on a requirement are read again
-- (their "Requires" line was read once and kept, so gear stayed under
-- Needs something first until a /reload). Reputations are checked live
-- (Items.NeedsOf), so only the tooltip's own red line needs this.
function Items.RefreshNeeds()
    local n = 0
    for _, cache in ipairs({ Items.cache, Items.linkCache }) do
        for _, rec in pairs(cache) do
            if rec.needs then
                local tip = tooltipFor(rec.link or rec.id)
                if Items.TooltipComplete(tip) then
                    local _, _, _, needs, rule, rep = Items.ParseTooltip(tip)
                    rec.needs, rec.rule, rec.rep = needs, rule, rep
                    n = n + 1
                end
            end
        end
    end
    if n > 0 and GP.Score then GP.Score.Request() end
    return n
end
for _, e in ipairs({ "SKILL_LINES_CHANGED", "PLAYER_PVP_RANK_CHANGED" }) do
    GP.RegisterEvent(e, function() GP.Soon("needs", Items.RefreshNeeds) end)
end

function Items.Get(id)
    local rec = Items.cache[id]
    if rec then
        if rec.partial then reread(rec) end
        return rec
    end
    if IsCached and not IsCached(id) then
        if RequestLoad then pcall(RequestLoad, id) end
        return nil
    end
    rec = build(id)
    if rec then Items.cache[id] = rec end
    return rec
end

-- An equipped or bagged item by its link (random suffixes kept).
function Items.FromLink(link)
    if type(link) ~= "string" then return nil end
    local rec = Items.linkCache[link]
    if rec then return rec end
    local id = Items.IDFromLink(link)
    if not id then return nil end
    rec = build(id, link)
    if rec then Items.linkCache[link] = rec end
    return rec
end

-- ---------------------------------------------------------------------
-- Loading many items: asked for a few at a time, picked up as they arrive
-- ---------------------------------------------------------------------

local waiting = {}        -- [itemID] = time asked (sent to the server)
local onArrive = {}       -- [itemID] = { callbacks }
local queued, queue = {}, {}  -- not asked yet: [itemID] = true, and their order
local tries = {}          -- [itemID] = times asked
local inFlight = 0
Items.WAIT = 15           -- s before an asked item that hasn't answered is asked again
Items.TRIES = 3           -- asks before an item is given up on (removed from the game, a typo)
-- At most this many asked at once. The server answers item questions a few
-- dozen a second; asking for a thousand at once left most of them waiting
-- past the time limit, so they were dropped and the lists came out nearly
-- empty (OrtusX, Nov 14: Look ahead 10 and Best now range 5 showed 2 items).
Items.IN_FLIGHT = 40

local function ask(id)
    waiting[id] = GetTime()
    inFlight = inFlight + 1
    tries[id] = (tries[id] or 0) + 1
    if RequestLoad then pcall(RequestLoad, id) else GetItemInfo(id) end
end

-- Asks for queued items while there's room.
local function pump()
    local i = 1
    while inFlight < Items.IN_FLIGHT and i <= #queue do
        local id = queue[i]
        i = i + 1
        if queued[id] then
            queued[id] = nil
            if onArrive[id] then ask(id) end
        end
    end
    if i > 1 then
        local rest = {}
        for j = i, #queue do rest[#rest + 1] = queue[j] end
        queue = rest
    end
end
Items.Pump = pump

local function arrived(id, success)
    local list = onArrive[id]
    if waiting[id] then inFlight = math.max(inFlight - 1, 0) end
    waiting[id], onArrive[id], queued[id], tries[id] = nil, nil, nil, nil
    if list then
        local rec = success ~= false and Items.Get(id) or nil
        for i = 1, #list do GP.SafeCall(list[i], rec, id) end
    end
    pump()
end

GP.RegisterEvent("ITEM_DATA_LOAD_RESULT", function(_, id, success)
    if waiting[id] then arrived(id, success) end
end)

GP.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, id, success)
    if waiting[id] then arrived(id, success) end
end)

-- Calls fn(record or nil, id) once the item is in (now, if it already is).
function Items.Want(id, fn)
    local rec = Items.cache[id] or ((not IsCached or IsCached(id)) and Items.Get(id))
    if rec then
        fn(rec, id)
        return
    end
    onArrive[id] = onArrive[id] or {}
    table.insert(onArrive[id], fn)
    if not waiting[id] and not queued[id] then
        queued[id] = true
        queue[#queue + 1] = id
        pump()
    end
end

-- An item that hasn't answered in time is asked again, and after
-- Items.TRIES asks given up on.
C_Timer.NewTicker(1, function()
    local now = GetTime()
    for id, t in pairs(waiting) do
        if now - t > Items.WAIT then
            if (tries[id] or 0) < Items.TRIES then
                inFlight = math.max(inFlight - 1, 0)
                ask(id)
            else
                arrived(id, false)
            end
        end
    end
    pump()
end)

-- Loads a list of item ids, at most `perFrame` asked for each frame, and
-- calls each(rec, id) for every one that arrives and done() at the end.
-- Runs as a background job (GP.RunJob) under the given key.
function Items.LoadAll(key, ids, each, done)
    local total, left = #ids, #ids
    if total == 0 then
        if done then done() end
        return
    end
    local function one(rec, id)
        if rec and each then each(rec, id) end
        left = left - 1
        if left == 0 and done then done() end
    end
    GP.RunJob(key, function()
        for i = 1, total do
            Items.Want(ids[i], one)
            if i % 25 == 0 then coroutine.yield() end
        end
    end)
end

function Items.Pending()
    local n = #queue
    for _ in pairs(waiting) do n = n + 1 end
    return n
end
