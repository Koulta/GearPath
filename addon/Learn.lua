-- Learn: remembers gear you see in game (quest reward windows, loot and
-- vendors), with where you were, so new Forever items the database
-- doesn't know yet still get a source. Kept account-wide in GearPathDB.
--
-- Everything read here is checked for secret values first (in instances
-- some unit details can be secret); anything secret is simply skipped.
--
-- Each source keeps when it was last seen (s, from time()), so the saved
-- file can't grow forever: at load, what other players shared is dropped
-- after SHARED_DAYS unseen, and both lists are cut to their limit, the
-- longest unseen first. Your own sightings have no age limit, only the cap.

local _, GP = ...

local Learn = {}
GP.Learn = Learn

local Items = GP.Items

local function on() return GP.Setting("learn") ~= false end

Learn.LEARNED_MAX = 4000    -- sources you saw yourself, kept at most
Learn.SHARED_MAX = 2000     -- sources other players shared, kept at most
Learn.SHARED_DAYS = 60      -- a shared source unseen this long is dropped

local DAY = 24 * 60 * 60
local function now() return (time and time()) or 0 end

-- Walks items[item][kind][key] = source (the shape both lists share):
-- drops sources unseen for maxDays (nil: no age limit), stamps old ones
-- that have no date yet (they age from today), then cuts the rest to max,
-- the longest unseen first. Empty kinds and items go too. Returns how many
-- are kept and how many were dropped.
function Learn.Prune(items, max, maxDays, at)
    if type(items) ~= "table" then return 0, 0 end
    at = at or now()
    local oldest = maxDays and (at - maxDays * DAY) or nil
    local list, dropped = {}, 0
    for item, kinds in pairs(items) do
        if type(kinds) ~= "table" then
            items[item] = nil
        else
            for kind, sources in pairs(kinds) do
                if type(sources) ~= "table" then
                    kinds[kind] = nil
                else
                    for key, src in pairs(sources) do
                        if type(src) ~= "table" then
                            sources[key] = nil
                        else
                            if type(src.s) ~= "number" then src.s = at end
                            if oldest and src.s < oldest then
                                sources[key] = nil
                                dropped = dropped + 1
                            else
                                list[#list + 1] = { src.s, item, kind, key }
                            end
                        end
                    end
                end
            end
        end
    end
    if #list > max then
        table.sort(list, function(a, b) return a[1] > b[1] end)   -- newest first
        for i = max + 1, #list do
            local e = list[i]
            items[e[2]][e[3]][e[4]] = nil
            dropped = dropped + 1
        end
    end
    -- Nothing empty left behind.
    for item, kinds in pairs(items) do
        for kind, sources in pairs(kinds) do
            if next(sources) == nil then kinds[kind] = nil end
        end
        if next(kinds) == nil then items[item] = nil end
    end
    return math.min(#list, max), dropped
end

-- How many sources a list holds (for /gp status and /gp report).
function Learn.Count(items)
    local n = 0
    if type(items) ~= "table" then return 0 end
    for _, kinds in pairs(items) do
        if type(kinds) == "table" then
            for _, sources in pairs(kinds) do
                if type(sources) == "table" then
                    for _ in pairs(sources) do n = n + 1 end
                end
            end
        end
    end
    return n
end

-- At load, before the first scan reads them.
GP.On("Loaded", function()
    local db = GP.db
    db.learned = type(db.learned) == "table" and db.learned or { items = {} }
    db.learned.items = type(db.learned.items) == "table" and db.learned.items or {}
    db.shared = type(db.shared) == "table" and db.shared or { items = {} }
    db.shared.items = type(db.shared.items) == "table" and db.shared.items or {}
    Learn.Prune(db.learned.items, Learn.LEARNED_MAX, nil)
    Learn.Prune(db.shared.items, Learn.SHARED_MAX, Learn.SHARED_DAYS)
end)

local function store(id)
    local t = GP.db.learned.items
    t[id] = t[id] or {}
    return t[id]
end

-- Where you are now: uiMapID, x, y (0-1).
local function here()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = GP.Plain(C_Map.GetBestMapForUnit("player"))
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return map end
    local x, y = pos:GetXY()
    x, y = GP.Plain(x), GP.Plain(y)
    if not x then return map end
    return map, GP.Round(x, 4), GP.Round(y, 4)
end

local npcIDFromGUID = GP.NpcID

local function isGear(link)
    local id = Items.IDFromLink(link)
    if not id then return nil end
    local equipLoc = Items.Instant(id)
    if equipLoc and GP.Slots.FOR_EQUIPLOC[equipLoc] then return id end
    return nil
end

-- ---------------------------------------------------------------------
-- Quest rewards
-- ---------------------------------------------------------------------

local function readQuestRewards()
    if not on() then return end
    local q = GP.Plain(GetQuestID and GetQuestID())
    if type(q) ~= "number" or q == 0 then return end
    local title = GP.Plain(GetTitleText and GetTitleText())
    local giver = GP.Plain(UnitName("npc"))
    local map, x, y = here()
    local changed = {}
    local function note(kind, count)
        for i = 1, count or 0 do
            local link = GetQuestItemLink and GP.Plain(GetQuestItemLink(kind, i))
            local id = link and isGear(link)
            if id then
                local rec = store(id)
                rec.q = rec.q or {}
                rec.q[q] = { n = title, g = giver, m = map, x = x, y = y, c = kind == "choice", s = now() }
                changed[#changed + 1] = id
                if GP.Share then GP.Share.Send("q", id, q, map, x, y, title) end
            end
        end
    end
    note("choice", GetNumQuestChoices and GetNumQuestChoices())
    note("reward", GetNumQuestRewards and GetNumQuestRewards())
    for _, id in ipairs(changed) do GP.Sources.Learned(id) end
end

GP.RegisterEvent("QUEST_DETAIL", readQuestRewards)
GP.RegisterEvent("QUEST_COMPLETE", readQuestRewards)

-- ---------------------------------------------------------------------
-- Loot
-- ---------------------------------------------------------------------

GP.RegisterEvent("LOOT_OPENED", function()
    if not on() or not GetNumLootItems then return end
    local map, x, y = here()
    local inInstance, kind = IsInInstance()
    local dungeon = inInstance and (kind == "party" or kind == "raid") and GP.Plain((GetInstanceInfo())) or nil
    for i = 1, GetNumLootItems() do
        local link = GP.Plain(GetLootSlotLink(i))
        local id = link and isGear(link)
        if id then
            local guid = GetLootSourceInfo and GetLootSourceInfo(i)
            local npc = npcIDFromGUID(guid)
            local name = GP.Plain(UnitName("target"))
            if npc or name then
                local rec = store(id)
                rec.d = rec.d or {}
                rec.d[npc or name] = { n = name or ("NPC " .. tostring(npc)), m = map, x = x, y = y, dg = dungeon, s = now() }
                GP.Sources.Learned(id)
                -- Not from inside dungeons: their spots mean nothing on the world map.
                if npc and not dungeon and GP.Share then GP.Share.Send("d", id, npc, map, x, y, name) end
            end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Vendors
-- ---------------------------------------------------------------------

GP.RegisterEvent("MERCHANT_SHOW", function()
    if not on() or not GetMerchantNumItems then return end
    local npc = npcIDFromGUID(UnitGUID("npc"))
    local name = GP.Plain(UnitName("npc"))
    if not (npc or name) then return end
    local map, x, y = here()
    for i = 1, GetMerchantNumItems() do
        local link = GP.Plain(GetMerchantItemLink(i))
        local id = link and isGear(link)
        if id then
            local rec = store(id)
            rec.v = rec.v or {}
            rec.v[npc or name] = { n = name, m = map, x = x, y = y, s = now() }
            GP.Sources.Learned(id)
            if npc and GP.Share then GP.Share.Send("v", id, npc, map, x, y, name) end
        end
    end
end)

GP.RegisterCommand("forget", "forget the gear sources you saw in game and the ones other players shared", function()
    GP.db.learned.items = {}
    GP.db.shared = { items = {} }
    GP.Print("Forgot the gear sources you saw in game and the ones other players shared.")
    GP.Fire("RescanRequested")
end)
