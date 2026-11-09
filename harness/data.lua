-- The fake character (a level 23 Undead Warlock), the items, quests, NPCs
-- and a stub of QuestieDB's public API holding them.

local H = _G.H

-- [id] = { name, quality, ilvl, req, equipLoc, classID, subClassID, stats (game keys), tip (Equip: lines) }
local ITEMS = {
    [100] = { "Old Hood", 2, 15, 12, "INVTYPE_HEAD", 4, 1, { ITEM_MOD_INTELLECT_SHORT = 3, ITEM_MOD_STAMINA_SHORT = 2 } },
    [101] = { "Apprentice Robe", 2, 18, 15, "INVTYPE_ROBE", 4, 1, {}, { "Equip: Increases damage and healing done by magical spells and effects by up to 5." } },
    [102] = { "Gnarled Staff", 2, 18, 15, "INVTYPE_2HWEAPON", 2, 10, { ITEM_MOD_INTELLECT_SHORT = 5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } },
    [103] = { "Copper Band", 2, 14, 10, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_STAMINA_SHORT = 2 } },
    [200] = { "Shadowweave Cowl", 3, 25, 21, "INVTYPE_HEAD", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 9, ITEM_MOD_INTELLECT_SHORT = 4 } },
    [201] = { "Robe of the Lost Order", 3, 28, 24, "INVTYPE_ROBE", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 12, ITEM_MOD_STAMINA_SHORT = 5 } },
    [202] = { "Ritual Dagger", 2, 24, 22, "INVTYPE_WEAPON", 2, 15, { ITEM_MOD_SPELL_POWER_SHORT = 7, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 9 } },
    [203] = { "Ring of Dark Whispers", 3, 25, 20, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_INTELLECT_SHORT = 3 } },
    [204] = { "Defias Shadow Cloak", 3, 27, 25, "INVTYPE_CLOAK", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 6 } },
    [205] = { "Chainmail Hauberk", 2, 25, 22, "INVTYPE_CHEST", 4, 3, { ITEM_MOD_STRENGTH_SHORT = 6 } },
    [206] = { "Embroidered Leggings", 2, 24, 22, "INVTYPE_LEGS", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 5 } },
    [207] = { "Done Quest Boots", 2, 22, 20, "INVTYPE_FEET", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 4 } },
    [209] = { "Slow Bracers", 2, 23, 21, "INVTYPE_WRIST", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 3 } },
    -- Healer gear: a cape that drops in a group, a mantle from a quest.
    [230] = { "Glowing Test Cape", 3, 26, 22, "INVTYPE_CLOAK", 4, 1, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 7, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 3, ITEM_MOD_SPIRIT_SHORT = 8 } },
    [233] = { "Testly's Gloves", 2, 25, 20, "INVTYPE_HAND", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 5 } },
    -- A world rare's drop, out in Tirisfal.
    [236] = { "Gorefang's Collar", 3, 26, 21, "INVTYPE_NECK", 4, 0, { ITEM_MOD_SPELL_POWER_SHORT = 6, ITEM_MOD_STAMINA_SHORT = 3 } },
    [232] = { "Testson's Vestments", 3, 27, 20, "INVTYPE_ROBE", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 16, ITEM_MOD_STAMINA_SHORT = 6 } },
    [231] = { "Healer Quest Mantle", 2, 24, 21, "INVTYPE_SHOULDER", 4, 1, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 10, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 3, ITEM_MOD_STAMINA_SHORT = 3 } },
    [210] = { "Bagged Gloves", 2, 22, 20, "INVTYPE_HAND", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 3 } },
    [211] = { "Ebon Wand", 3, 26, 23, "INVTYPE_RANGEDRIGHT", 2, 19, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 15 } },
    [212] = { "Seen Belt", 2, 22, 21, "INVTYPE_WAIST", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 4 } },
    [213] = { "High Quest Mantle", 3, 30, 0, "INVTYPE_SHOULDER", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 8 } },
    [214] = { "Chest Loot Leggings", 3, 26, 22, "INVTYPE_LEGS", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 9 } },
    [217] = { "Shade Mantle", 3, 27, 24, "INVTYPE_SHOULDER", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 10 } },
    [218] = { "Keep Bracers", 2, 26, 23, "INVTYPE_WRIST", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 6 } },
    [219] = { "Keep Gloves", 2, 26, 23, "INVTYPE_HAND", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 6 } },
    [234] = { "Lesser Test Wand", 2, 18, 15, "INVTYPE_RANGEDRIGHT", 2, 19, { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } },
    -- Crafted (Learn.lua's crafting test): known, trainable, more skill needed, another profession's.
    [244] = { "Test Tailored Belt", 2, 26, 22, "INVTYPE_WAIST", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 9 } },
    [245] = { "Test Tailored Boots", 2, 26, 22, "INVTYPE_FEET", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 9 } },
    [246] = { "Test Tailored Gloves", 2, 27, 23, "INVTYPE_HAND", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 10 } },
    [247] = { "Test Leather Cap", 2, 26, 22, "INVTYPE_HEAD", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 9 } },
    -- Made by the fake ProfessionDB's recipes (run.lua's ProfessionDB test).
    [248] = { "PDB Trainer Mantle", 2, 26, 20, "INVTYPE_SHOULDER", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 20 } },
    [249] = { "PDB High Leggings", 2, 27, 21, "INVTYPE_LEGS", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 25 } },
    [250] = { "PDB Known Cuffs", 2, 26, 20, "INVTYPE_WRIST", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 20 } },
    [251] = { "PDB Pattern Cloak", 2, 26, 20, "INVTYPE_CLOAK", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 20 } },
    [252] = { "PDB Rare Pendant", 2, 26, 20, "INVTYPE_NECK", 4, 0, { ITEM_MOD_SPELL_POWER_SHORT = 20 } },
    [253] = { "PDB Never Hat", 2, 26, 20, "INVTYPE_HEAD", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 30 } },
    [254] = { "PDB Leather Cap", 2, 26, 20, "INVTYPE_HEAD", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 30 } },
    [256] = { "PDB Starter Band", 2, 26, 20, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_SPELL_POWER_SHORT = 20 } },
    [215] = { "Sergeant's Cloak", 3, 30, 23, "INVTYPE_CLOAK", 4, 1, { ITEM_MOD_STAMINA_SHORT = 9 }, { { "Requires Sergeant", 1, 0.125, 0.125 }, { "Requires Level 23", 1, 0.125, 0.125 } } },
}
H.ITEMS = ITEMS
local uncached = { [209] = true }      -- answers after a request

local function idOf(x)
    if type(x) == "number" then return x end
    if type(x) == "string" then return tonumber(x:match("item:(%d+)")) end
end

function H.Link(id) return string.format("|cff1eff00|Hitem:%d::::::::23:::::|h[%s]|h|r", id, ITEMS[id][1]) end

local function info(x)
    local id = idOf(x)
    local it = id and ITEMS[id]
    if not it or uncached[id] then return nil end
    return it[1], H.Link(id), it[2], it[3], it[4], "Armor", "Cloth", 1, it[5], 134000 + id, 100 + id, it[6], it[7],
        (H.bind and H.bind[id]) or 1
end

C_Item = {
    GetItemInfo = info,
    GetItemInfoInstant = function(x)
        local id = idOf(x)
        local it = id and ITEMS[id]
        if not it then return nil end
        return id, "Armor", "Cloth", it[5], 134000 + id, it[6], it[7]
    end,
    GetItemStats = function(link)
        local it = ITEMS[idOf(link)]
        local out = {}
        for k, v in pairs(it and it[8] or {}) do out[k] = v end
        return out
    end,
    IsItemDataCachedByID = function(id) return ITEMS[id] ~= nil and not uncached[id] end,
    RequestLoadItemDataByID = function(id)
        if uncached[id] then
            C_Timer.After(0.3, function()
                uncached[id] = nil
                H.Fire("ITEM_DATA_LOAD_RESULT", id, true)
            end)
        end
    end,
    -- Putting gear on: kept for the tests to look at.
    EquipItemByName = function(link, slot)
        H.equips = H.equips or {}
        H.equips[#H.equips + 1] = { link = link, slot = slot }
    end,
    GetItemQualityColor = function(q)
        local c = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee" }
        return 1, 1, 1, c[q] or "ffffffff"
    end,
}

C_TooltipInfo = {
    GetHyperlink = function(link)
        local it = ITEMS[idOf(link)]
        local lines = { { leftText = it and it[1] or "?" } }
        for _, l in ipairs(it and it[9] or {}) do
            if type(l) == "table" then
                lines[#lines + 1] = { leftText = l[1], leftColor = { r = l[2], g = l[3], b = l[4] } }
            else
                lines[#lines + 1] = { leftText = l, leftColor = { r = 0, g = 1, b = 0 } }
            end
        end
        return { lines = lines }
    end,
    GetItemByID = function(id) return C_TooltipInfo.GetHyperlink(H.Link(id)) end,
}

-- The character
local EQUIPPED = { [1] = 100, [5] = 101, [16] = 102, [11] = 103 }
H.EQUIPPED = EQUIPPED
local SLOT_IDS = { HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6,
    LegsSlot = 7, FeetSlot = 8, WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12,
    Trinket0Slot = 13, Trinket1Slot = 14, BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17,
    RangedSlot = 18, TabardSlot = 19 }
function GetInventorySlotInfo(name) return SLOT_IDS[name], "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. name end
function GetInventoryItemLink(_, slot) return EQUIPPED[slot] and H.Link(EQUIPPED[slot]) end
function GetInventoryItemTexture(_, slot) return EQUIPPED[slot] and 134000 + EQUIPPED[slot] end
function GetInventoryItemQuality(_, slot) return EQUIPPED[slot] and ITEMS[EQUIPPED[slot]][2] end
function UnitLevel() return 23 end
function UnitClass() return "Warlock", "WARLOCK", 9 end
function UnitRace() return "Undead", "Scourge", 5 end
function UnitFactionGroup() return "Horde" end
-- The character sheet's numbers (no haste in this client: it falls back to gear).
local STATS = { 20, 22, 40, 60, 55 }
function UnitStat(_, i) return STATS[i] - 5, STATS[i], 0, 0 end
function GetSpellBonusDamage(school) return school == 6 and 5 or 3 end
function GetSpellHitModifier() return 0 end
function GetSpellCritChance() return 4.5 end
function GetManaRegen() return 1.5, 0 end
function UnitArmor() return 40, 45 end
-- Units the tests put in view (nameplates, targets): { guid, name, dead }.
H.units = {}
function UnitName(u) if H.units[u] then return H.units[u].name end if u == "player" then return "Koulta Summonpls" end return "Gryan" end
function UnitGUID(u) if H.units[u] then return H.units[u].guid end if u == "player" then return "Player-1-0000CAFE" end return "Creature-0-0-0-0-9000-0000" end
function UnitExists(u) return u == "player" or H.units[u] ~= nil end
function UnitIsDead(u) return H.units[u] ~= nil and H.units[u].dead == true end
H.cvars = { nameplateMaxDistance = "60", nameplateShowEnemies = "1" }
function GetCVar(k) return H.cvars[k] end

-- The backpack: Bagged Gloves in slot 3, and whatever a test puts in H.bag ({ [slot] = itemID }).
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 16 or 0 end,
    GetContainerItemLink = function(bag, slot)
        if bag ~= 0 then return nil end
        if H.bag and H.bag[slot] then return H.Link(H.bag[slot]) end
        if slot == 3 then return H.Link(210) end
    end,
    -- isBound from H.bound ({ [slot] = true }).
    GetContainerItemInfo = function(bag, slot)
        local link = C_Container.GetContainerItemLink(bag, slot)
        if not link then return nil end
        return { hyperlink = link, itemID = tonumber(link:match("item:(%d+)")), isBound = (H.bound and H.bound[slot]) or false }
    end,
}

local DONE = { [5003] = true }
C_QuestLog = {
    IsQuestFlaggedCompleted = function(q) return DONE[q] == true end,
    GetLogIndexForQuestID = function(q) if q == 5000 then return 4 end end,
}

local AREAS = { [40] = "Westfall", [10] = "Duskwood", [85] = "Tirisfal Glades", [1581] = "The Deadmines" }
local MAPS = { [1436] = "Westfall", [1431] = "Duskwood", [1420] = "Tirisfal Glades" }
C_Map = {
    GetAreaInfo = function(a) return AREAS[a] end,
    GetMapInfo = function(m) return MAPS[m] and { name = MAPS[m], mapType = 3, parentMapID = 1415 } end,
    GetBestMapForUnit = function() return 1420 end,
    GetPlayerMapPosition = function() local x, y = H.playerX or 0.61, H.playerY or 0.52; return { GetXY = function() return x, y end } end,
    -- A zone 5000 yards across.
    GetWorldPosFromMapPos = function(m, v) return 0, { GetXY = function() return v.x * 5000, v.y * 5000 end } end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(p)
        assert(type(p) == "table" and type(p.uiMapID) == "number" and type(p.position) == "table", "SetUserWaypoint: bad point")
        H.waypoint = { m = p.uiMapID, x = p.position.x, y = p.position.y }
    end,
    HasUserWaypoint = function() return H.waypoint ~= nil end,
    GetUserWaypoint = function() return H.waypoint and { uiMapID = H.waypoint.m, position = { x = H.waypoint.x, y = H.waypoint.y } } end,
    ClearUserWaypoint = function() H.waypoint = nil end,
}
-- Forever: no UiMapPoint (retail only), but the vector helper and the map's own functions.
function CreateVector2D(x, y) return { x = x, y = y } end
function OpenMapToUserWaypoint() H.mapOpened = C_Map.GetUserWaypoint().uiMapID end
function OpenWorldMap(id) H.mapOpened = id end
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) H.superTracked = on end }

-- ---------------------------------------------------------------------
-- QuestieDB
-- ---------------------------------------------------------------------

local function entity(rows, ids)
    local e = {}
    local fields = {}
    for _, row in pairs(rows) do for k in pairs(row) do fields[k] = true end end
    for k in pairs(fields) do e[k] = function(id) local r = rows[id]; return r and r[k] end end
    -- Fields nothing set still answer nil.
    setmetatable(e, { __index = function(_, k) return function() return nil end end })
    e.GetAllIds = function() return ids end
    return e
end

local DB_ITEMS = {
    [200] = { class = 4, subClass = 1, requiredLevel = 21, name = "Shadowweave Cowl", questRewards = { 5000 } },
    [201] = { class = 4, subClass = 1, requiredLevel = 24, name = "Robe of the Lost Order", questRewards = { 5001 } },
    [202] = { class = 2, subClass = 15, requiredLevel = 20, name = "Ritual Dagger", vendors = { 9001 } },
    [203] = { class = 4, subClass = 0, requiredLevel = 20, name = "Ring of Dark Whispers", npcDrops = { 9002 } },
    [230] = { class = 4, subClass = 1, requiredLevel = 22, name = "Glowing Test Cape", npcDrops = { 9002 } },
    [231] = { class = 4, subClass = 1, requiredLevel = 21, name = "Healer Quest Mantle", questRewards = { 5000 } },
    [232] = { class = 4, subClass = 1, requiredLevel = 20, name = "Testson's Vestments", npcDrops = { 9200 } },
    [233] = { class = 4, subClass = 1, requiredLevel = 20, name = "Testly's Gloves", npcDrops = { 9201 } },
    [236] = { class = 4, subClass = 0, requiredLevel = 21, name = "Gorefang's Collar", npcDrops = { 9300 } },
    [204] = { class = 4, subClass = 1, requiredLevel = 25, name = "Defias Shadow Cloak", questRewards = { 5002 } },
    [205] = { class = 4, subClass = 3, requiredLevel = 22, name = "Chainmail Hauberk", questRewards = { 5000 } },
    [206] = { class = 4, subClass = 1, requiredLevel = 22, name = "Embroidered Leggings",
        npcDrops = { 9100, 9101, 9102, 9103, 9104, 9105, 9106, 9107, 9108, 9109, 9110, 9111 } },
    [207] = { class = 4, subClass = 1, requiredLevel = 20, name = "Done Quest Boots", questRewards = { 5003 } },
    [209] = { class = 4, subClass = 1, requiredLevel = 21, name = "Slow Bracers", vendors = { 9001 } },
    [211] = { class = 2, subClass = 19, requiredLevel = 23, name = "Ebon Wand", questRewards = { 5000 } },
    [213] = { class = 4, subClass = 1, requiredLevel = 0, itemLevel = 30, name = "High Quest Mantle", questRewards = { 5004 } },
    [214] = { class = 4, subClass = 1, requiredLevel = 22, name = "Chest Loot Leggings", objectDrops = { 2 } },
    [215] = { class = 4, subClass = 1, requiredLevel = 23, name = "Sergeant's Cloak", vendors = { 9001 } },
    [500] = { class = 0, requiredLevel = 1, name = "Potion" },
    -- A recipe item, sold by a Horde vendor (ProfessionDB test).
    [255] = { class = 9, subClass = 2, requiredLevel = 0, name = "Pattern: PDB Pattern Cloak", vendors = { 9012 } },
    -- Level 60: never a candidate, only resolved by the faction checks.
    [241] = { class = 4, subClass = 1, requiredLevel = 60, name = "Guard's Sash", npcDrops = { 9009, 9010 } },
}
local QUESTS = {
    [5000] = { name = "The Lost Cultist", questLevel = 22, requiredLevel = 18, startedBy = { { 9000 } }, zoneOrSort = 40 },
    [4999] = { name = "A Whisper in the Dark", questLevel = 21, requiredLevel = 17, startedBy = { { 9003 } }, zoneOrSort = 10 },
    [5001] = { name = "The Lost Order", questLevel = 24, requiredLevel = 20, startedBy = { { 9003 } }, zoneOrSort = 10, preQuestSingle = { 4999 } },
    [5002] = { name = "Red Silk Bandanas", questLevel = 24, requiredLevel = 18, startedBy = { { 9004 } }, zoneOrSort = 1581 },
    [5004] = { name = "Strahnbrad Mystery", questLevel = 30, requiredLevel = 22, startedBy = { { 9000 } }, zoneOrSort = 40 },
    [5003] = { name = "Old News", questLevel = 20, requiredLevel = 15, startedBy = { { 9000 } }, zoneOrSort = 40 },
    -- Faction filtering: the journal calls 5010 "Both", the database knows it's Alliance (races 77);
    -- 5011 is handed out only by an Alliance NPC; 5012's giver is marked "AH" (says nothing).
    [5010] = { name = "Heirlooms Elsewhere", questLevel = 15, requiredLevel = 10, requiredRaces = 77, startedBy = { { 9008 } }, zoneOrSort = 40 },
    [5011] = { name = "Ironforge Errand", questLevel = 15, requiredLevel = 10, startedBy = { { 9007 } }, zoneOrSort = 40 },
    [5012] = { name = "Anyone's Errand", questLevel = 15, requiredLevel = 10, startedBy = { { 9008 } }, zoneOrSort = 40 },
}
local NPCS = {
    [9000] = { name = "Gryan Stoutmantle", friendlyToFaction = "AH", spawns = { [40] = { { 56.3, 47.5 } } }, zoneID = 40 },
    [9001] = { name = "Abigail Shiel", friendlyToFaction = "H", spawns = { [85] = { { 61.0, 52.0 } } }, zoneID = 85 },
    [9007] = { name = "Thom Alliance", friendlyToFaction = "A", spawns = { [40] = { { 50, 50 } } }, zoneID = 40 },
    [9008] = { name = "Anyone", friendlyToFaction = "AH", spawns = { [40] = { { 51, 51 } } }, zoneID = 40 },
    [9009] = { name = "Deathguard Tester", friendlyToFaction = "H", minLevel = 20, maxLevel = 20, spawns = { [85] = { { 60, 50 } } }, zoneID = 85 },
    [9010] = { name = "Hillsbrad Tester", friendlyToFaction = "A", minLevel = 20, maxLevel = 20, spawns = { [40] = { { 60, 50 } } }, zoneID = 40 },
    [9201] = { name = "Foreman Testly", rank = 4, minLevel = 20, maxLevel = 20, spawns = { [1581] = { { 40, 60 } } }, zoneID = 1581 },
    [9200] = { name = "Miner Testson", rank = 2, minLevel = 20, maxLevel = 20, spawns = { [1581] = { { 50, 50 } } }, zoneID = 1581 },
    -- A weapon master (the harness's map: put in Tirisfal).
    [11870] = { name = "Archibald", subName = "Weapon Master", friendlyToFaction = "H", spawns = { [85] = { { 57.3, 32.8 } } }, zoneID = 85 },
    [9300] = { name = "Gorefang", rank = 4, minLevel = 24, maxLevel = 24, spawns = { [85] = { { 90.0, 90.0 } } }, zoneID = 85 },
    [9002] = { name = "Stalvan Mistmantle", rank = 1, minLevel = 25, maxLevel = 25, spawns = { [10] = { { 77.2, 36.1 } } }, zoneID = 10 },
    [9003] = { name = "Madame Eva", friendlyToFaction = "AH", spawns = { [10] = { { 75.8, 45.3 } } }, zoneID = 10 },
    [9004] = { name = "Scout Riell", friendlyToFaction = "AH", spawns = { [40] = { { 42.0, 71.0 } } }, zoneID = 40 },
    -- A tailoring trainer and a pattern vendor in Tirisfal; an Alliance trainer (ProfessionDB test).
    [9011] = { name = "Test Tailor", friendlyToFaction = "H", spawns = { [85] = { { 52.0, 55.0 } } }, zoneID = 85 },
    [9012] = { name = "Pattern Seller", friendlyToFaction = "H", spawns = { [85] = { { 60.0, 51.0 } } }, zoneID = 85 },
    [9013] = { name = "Alliance Tailor", friendlyToFaction = "A", spawns = { [40] = { { 30.0, 30.0 } } }, zoneID = 40 },
}
for i = 9100, 9111 do NPCS[i] = { name = "Mob " .. i, spawns = { [10] = { { 10, 10 } } } } end

local itemIds = {}
for id in pairs(DB_ITEMS) do itemIds[#itemIds + 1] = id end
table.sort(itemIds)

H.DB_ITEMS, H.NPCS, H.itemIds = DB_ITEMS, NPCS, itemIds
if not H.noDB then
    LibQuestieDB = {
        readMode = "baked",
        RequireContract = function(n) return n >= 1 and n <= 4 end,
        Item = entity(DB_ITEMS, itemIds),
        Quest = entity(QUESTS, {}),
        Npc = entity(NPCS, {}),
        Object = entity({ [1] = { name = "Chest" }, [2] = { name = "Solid Chest", spawns = { [10] = { {1,1},{2,2},{3,3},{4,4},{5,5} }, [40] = { {6,6},{7,7},{8,8},{9,9},{10,10} } } } }, {}),
        Enum = { raceMaskById = { [5] = 16 }, classKeys = { WARLOCK = 256 } },
        Support = { Get = function(name)
            if name ~= "ZoneDB" then return nil end
            return { private = {
                areaIdToUiMapId = "return { [40] = 1436, [10] = 1431, [85] = 1420 }",
                areaIdToUiMapIdOverride = "return { [0] = 0 }",
                dungeons = { [1581] = { "The Deadmines", { 10029 }, 40, { { 40, 42.5, 71.7 } } } },
            } }
        end },
    }
end

-- Quest window, loot and vendor APIs for Learn.lua
function GetQuestID() return 6000 end
function GetTitleText() return "Seen Belt Quest" end
-- A quest window's choices: H.choices = { itemID, ... } (else the one Learn.lua's test uses).
function GetNumQuestChoices() return H.choices and #H.choices or 1 end
function GetNumQuestRewards() return 0 end
function GetQuestItemLink(kind, i)
    if kind ~= "choice" then return nil end
    if H.choices then return H.choices[i] and H.Link(H.choices[i]) end
    if i == 1 then return H.Link(212) end
end
function GetQuestItemInfo(kind, i)
    local id = H.choices and H.choices[i]
    if not id then return nil end
    return ITEMS[id][1], 134000 + id, 1, ITEMS[id][2], true, id
end
function GetNumLootItems() return 0 end
function GetLootSlotLink() end
-- Professions (Learn.lua's crafting): H.skills = { { name, rank } };
-- the profession window H.trade = { line = "Tailoring", items = { ids } };
-- a trainer H.trainer = { { itemID, profession, rank, category } }.
function GetRealmName() return "Forever" end
function GetNumSkillLines() return 1 + #(H.skills or {}) end
function GetSkillLineInfo(i)
    if i == 1 then return "Professions", 1, 1, 0 end
    local s = H.skills and H.skills[i - 1]
    if s then return s[1], nil, nil, s[2] end
end
function GetTradeSkillLine() return H.trade and H.trade.line or "UNKNOWN", 40, 75 end
function GetNumTradeSkills() return H.trade and (#H.trade.items + 1) or 0 end
function GetTradeSkillInfo(i)
    if i == 1 then return "Cloth", "header" end
    return "Recipe " .. i, "easy"
end
function GetTradeSkillItemLink(i) local id = H.trade and H.trade.items[i - 1]; return id and H.Link(id) end
function GetNumTrainerServices() return H.trainer and #H.trainer or 0 end
function GetTrainerServiceInfo(i) local r = H.trainer and H.trainer[i]; if r then return "Recipe", "", r[4] end end
function GetTrainerServiceItemLink(i) local r = H.trainer and H.trainer[i]; return r and H.Link(r[1]) end
function GetTrainerServiceSkillReq(i) local r = H.trainer and H.trainer[i]; if r then return r[2], r[3], true end end
-- A vendor's list: H.merchant = { { id, price }, ... }.
function GetMerchantNumItems() return H.merchant and #H.merchant or 0 end
function GetMerchantItemLink(i) local m = H.merchant and H.merchant[i]; return m and H.Link(m[1]) end
function GetMerchantItemInfo(i) local m = H.merchant and H.merchant[i]; if m then return ITEMS[m[1]][1], 134000 + m[1], m[2], 1, -1, true, true end end

-- A stand-in for DungeonJournal's shared table (its real shape).
if not H.noJournal then
    ForeverDungeonJournal_NS = {
        ORDER = { "Shadow Keep" },
        DB = {
            ["Shadow Keep"] = {
                level = "20-26", location = "Duskwood", icon = "Interface\\Icons\\Spell_Shadow_Shadowform",
                entrance = { mapID = 1431, x = 0.5, y = 0.5, label = "Shadow Keep Entrance",
                    detail = "Up the hill behind the inn, through the iron gate" },
                bosses = { { name = "Lord Shade", level = 26, loot = { { 217, "Shade Mantle", "Shoulder, Cloth", 3 } } },
                           { name = "Trash", trash = true, loot = {} } },
                quests = { { id = 5005, name = "Keep Clearing", level = 25, requires = 20, faction = "Both", rewardChoice = false,
                    rewardItems = { { 218, "Keep Bracers", 2 }, { 219, "Keep Gloves", 2 } },
                    startMap = { mapID = 1436, x = 0.4, y = 0.4, label = "Captain Grey - Westfall", targetName = "Captain Grey" } },
                    { id = 5006, name = "Alliance Only", faction = "Alliance", rewardItems = { { 218, "Keep Bracers", 2 } } },
                    { id = 5010, name = "Heirlooms Elsewhere", faction = "Both", rewardItems = { { 218, "Keep Bracers", 2 } },
                        startMap = { mapID = 1436, x = 0.3, y = 0.3, label = "Thom - Westfall", targetName = "Thom" } } },
            },
        },
    }
end
