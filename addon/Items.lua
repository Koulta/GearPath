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

-- Forever shows hit, crit and the like as percentages. The tooltip's own
-- percentage is used when it has one (see ReadStats). Without one, a big
-- number from the stat table is taken for a rating (an older item):
-- roughly 14 rating to 1% at 60. That ratio is a guess, not Forever's.
local PERCENT_STATS = { hit = true, crit = true, haste = true, dodge = true, parry = true, expertise = true }
local function asPercent(v)
    if v > 5 then return v / 14 end
    return v
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
    { "improves your chance to get a critical strike with spells by ([%d%.]+)%%", "crit" },
    { "improves your chance to get a critical strike by ([%d%.]+)%%", "crit" },
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
        local escaped = t:lower():gsub("([%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")
        dpsPattern, dpsTemplate = escaped:gsub("%%s", "([%%d%%.,]+)"), t
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
        local escaped = s:gsub("([%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")
        classesPattern = "^" .. escaped:gsub("%%s", "(.+)") .. "$"
    end
    return classesPattern
end

-- A requirement the game shows in red ("Requires Sergeant", "Requires
-- Friendly with Darkspear Trolls", "Requires Tailoring (150)"): one you
-- don't meet. "Requires Level" is left out (the level is handled apart).
-- Built from the game's own templates, so the word "Requires" can sit
-- anywhere in the line (Korean puts it last).
local function escape(t) return (t:gsub("([%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")) end
local REQ_TEMPLATE = type(ITEM_REQ_SKILL) == "string" and ITEM_REQ_SKILL or "Requires %s"
local LEVEL_TEMPLATE = type(ITEM_MIN_LEVEL) == "string" and ITEM_MIN_LEVEL or "Requires Level %d"
local REQ_PATTERN = "^" .. escape(REQ_TEMPLATE):gsub("%%s", "(.+)") .. "$"
local LEVEL_PATTERN = "^" .. escape(LEVEL_TEMPLATE):gsub("%%d", "%%d+") .. "$"

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

-- Reads stats out of an item's tooltip. Returns found (key -> value),
-- the classes it's limited to (a set of localized names, or nil),
-- whether it's unique-equipped, and a requirement you don't meet (or nil).
function Items.ParseTooltip(data)
    local found, classes, unique, needs = {}, nil, false, nil
    local lines = tooltipLines(data)
    if not lines then return found, classes, unique, needs end
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
        end
    end
    return found, classes, unique, needs
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
                if PERCENT_STATS[key] then v = asPercent(v) end
                stats[key] = (stats[key] or 0) + v
                if BOTH_SPELL_POWER[k] and not healing then stats.heal = (stats.heal or 0) + v end
            end
        end
    end
    local found, classes, unique, needs = Items.ParseTooltip(tooltipData)
    for k, v in pairs(found) do
        if stats[k] == nil or PERCENT_STATS[k] then stats[k] = v end
    end
    return stats, classes, unique, needs
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
    local name, itemLink, quality, ilvl, reqLevel, _, _, _, equipLoc, icon, _, classID, subClassID = GetItemInfo(link or id)
    if not name then return nil end
    link = link or itemLink
    local rec = {
        id = id, name = name, link = link, quality = quality, ilvl = ilvl, reqLevel = reqLevel or 0,
        equipLoc = equipLoc, icon = icon, classID = classID, subClassID = subClassID,
    }
    rec.stats, rec.classes, rec.unique, rec.needs = Items.ReadStats(link, tooltipFor(link))
    -- The weapon speed is kept apart from the stats (it isn't a bonus).
    rec.speed, rec.stats.speed = rec.stats.speed, nil
    return rec
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
function Items.Get(id)
    local rec = Items.cache[id]
    if rec then return rec end
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

local waiting = {}        -- [itemID] = time asked
local onArrive = {}       -- [itemID] = { callbacks }
Items.WAIT = 15           -- s before an item that never answers is given up on

local function arrived(id, success)
    local list = onArrive[id]
    waiting[id], onArrive[id] = nil, nil
    if not list then return end
    local rec = success ~= false and Items.Get(id) or nil
    for i = 1, #list do GP.SafeCall(list[i], rec, id) end
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
    if not waiting[id] then
        waiting[id] = GetTime()
        if RequestLoad then pcall(RequestLoad, id) else GetItemInfo(id) end
    end
end

-- Gives up on items that never answer (removed from the game, typos in data).
C_Timer.NewTicker(5, function()
    local now = GetTime()
    for id, t in pairs(waiting) do
        if now - t > Items.WAIT then arrived(id, false) end
    end
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
    local n = 0
    for _ in pairs(waiting) do n = n + 1 end
    return n
end
