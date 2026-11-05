-- lua5.1 scoring_test.lua <addon dir>
-- The upgrade math, end to end: weapon DPS priced from attack power, no
-- weapon racials, the two hands as one choice, the second ring against the
-- stronger one, Healing from damage-and-healing spell power, gear the
-- client hasn't loaded yet, expertise and percentages from the tooltip,
-- the hit cap, Unique, the try-on total, and the client fixes (renamed
-- learned-spell event, the controller in combat, one bind confirmation at
-- a time).
local dir = arg[1]
local here = arg[0]:match("^(.*)/[^/]*$") or "."

local H = dofile(here .. "/wow.lua")
H.noDB = true
dofile(here .. "/data.lua")

local checks, failed = 0, 0
local function check(cond, what)
    checks = checks + 1
    if not cond then failed = failed + 1 print("  FAIL: " .. what) end
end
local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.01) end

-- Test gear: { name, quality, ilvl, req, equipLoc, classID, subClassID, stats, tooltip lines }
local I = H.ITEMS
I[400] = { "Ring A", 2, 25, 20, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_STAMINA_SHORT = 20 } }
I[401] = { "Ring B", 2, 25, 20, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_STAMINA_SHORT = 10 } }
I[402] = { "Ring X", 2, 25, 20, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_STAMINA_SHORT = 40 } }
I[403] = { "Ring Y", 2, 25, 20, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_STAMINA_SHORT = 16 } }
I[404] = { "Unique Ring", 2, 25, 20, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_STAMINA_SHORT = 30 }, { "Unique" } }
I[410] = { "Big 2H", 2, 28, 20, "INVTYPE_2HWEAPON", 2, 8, { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 25 } }
I[411] = { "Sword 1H", 2, 26, 20, "INVTYPE_WEAPON", 2, 7, { ITEM_MOD_STRENGTH_SHORT = 4, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 16 } }
I[412] = { "Shield", 2, 26, 20, "INVTYPE_SHIELD", 4, 6, { ITEM_MOD_STAMINA_SHORT = 5 } }
I[413] = { "Better Shield", 2, 26, 20, "INVTYPE_SHIELD", 4, 6, { ITEM_MOD_STAMINA_SHORT = 15 } }
I[414] = { "Weak 2H", 2, 20, 15, "INVTYPE_2HWEAPON", 2, 8, { ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 15 } }
I[420] = { "Dmg-Heal Robe", 2, 26, 20, "INVTYPE_ROBE", 4, 1, {}, { "Equip: Increases damage and healing done by magical spells and effects by up to 20." } }
I[421] = { "Heal Robe", 2, 26, 20, "INVTYPE_ROBE", 4, 1, { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 12, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 4 } }
I[422] = { "Spell Power Robe", 2, 26, 20, "INVTYPE_ROBE", 4, 1, { ITEM_MOD_SPELL_POWER_SHORT = 20 } }
I[430] = { "Expertise Gloves", 2, 26, 20, "INVTYPE_HAND", 4, 3, {}, { "Equip: Reduces chance to be Dodged or Parried by 1.0%." } }
I[431] = { "Crit Gloves", 2, 26, 20, "INVTYPE_HAND", 4, 3, { ITEM_MOD_CRIT_RATING_SHORT = 6 }, { "Equip: Improves your chance to get a critical strike by 6%." } }
I[440] = { "Hit Hood", 2, 25, 20, "INVTYPE_HEAD", 4, 1, { ITEM_MOD_HIT_RATING_SHORT = 4 } }
I[441] = { "Hit Gloves", 2, 25, 20, "INVTYPE_HAND", 4, 1, { ITEM_MOD_HIT_RATING_SHORT = 2 } }
I[442] = { "Plain Gloves", 2, 25, 20, "INVTYPE_HAND", 4, 1, {} }
I[450] = { "Worse Chest", 2, 20, 15, "INVTYPE_CHEST", 4, 1, { ITEM_MOD_STAMINA_SHORT = 5 } }

local ns = {}
for line in io.open(dir .. "/GearPath.toc"):read("*a"):gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local ok, err = pcall(assert(loadfile(dir .. "/" .. line:gsub("\\", "/"))), "GearPath", ns)
        if not ok then print("  LOAD ERROR " .. line .. ": " .. tostring(err)) failed = failed + 1 end
    end
end
local GP = ns
H.Fire("ADDON_LOADED", "GearPath")
H.Fire("PLAYER_LOGIN")
for _ = 1, 100 do H.Tick(0.1) if GP.Sources.status == "ready" then break end end
for _ = 1, 10 do H.Tick(0.1) end

local C, S, EQ = GP.Classes, GP.Score, H.EQUIPPED
local CLASSES = { WARRIOR = { "Warrior", 1 }, PALADIN = { "Paladin", 2 }, HUNTER = { "Hunter", 3 }, ROGUE = { "Rogue", 4 },
    PRIEST = { "Priest", 5 }, SHAMAN = { "Shaman", 7 }, MAGE = { "Mage", 8 }, WARLOCK = { "Warlock", 9 }, DRUID = { "Druid", 11 } }
local function as(class, race)
    function UnitClass() return CLASSES[class][1], class, CLASSES[class][2] end
    function UnitRace() return race or "Scourge", race or "Scourge", 5 end
    GP.char.spec, GP.char.weights, GP.char.specWeights = nil, nil, nil
    GP.PlayerInfo()
end
local function rec(id) return GP.Items.FromLink(H.Link(id)) end
local function wear(t)
    for k in pairs(EQ) do EQ[k] = nil end
    for k, v in pairs(t) do EQ[k] = v end
    S.ReadEquipped()
end
local function emptyRes()
    local res = { bySlot = {} }
    for _, k in ipairs(GP.Slots.ORDER) do res.bySlot[k] = { primary = {}, secondary = {}, locked = {} } end
    return res
end
local function ev(id)
    local slot, delta, pct, base, points = S.Upgrade(rec(id))
    return { rec = rec(id), slot = slot, delta = delta, pct = pct, base = base, points = points, source = { kind = "bags" } }
end
local function planOf(ids)
    local res = emptyRes()
    for _, id in ipairs(ids) do
        local e = ev(id)
        if e.slot then table.insert(res.bySlot[GP.Slots.GROUP[e.slot] or e.slot].primary, e) end
    end
    for _, b in pairs(res.bySlot) do table.sort(b.primary, function(a, b2) return a.delta > b2.delta end) end
    local plan = S.BuildPlan(res)
    local total, byName = 0, {}
    for _, p in ipairs(plan.picks) do total = total + p.delta; byName[p.rec.name] = p end
    return plan, total, byName
end

-- 1. Weapon DPS is 14 attack power (Forever, as Classic): 14 x the AP weight.
for class in pairs(CLASSES) do
    for _, spec in ipairs(C.Specs(class)) do
        local w = spec.weights or C.Data(class).weights
        local name = class .. " " .. spec.name
        if class == "HUNTER" then
            check(near(w.dpsRanged, 14 * (w.rap or 0)), name .. ": ranged DPS = 14 x ranged attack power (" .. tostring(w.dpsRanged) .. ")")
        elseif (w.ap or 0) > 0 and spec.role ~= "healer" then
            check(near(w.dpsMelee, 14 * w.ap), name .. ": weapon DPS = 14 x attack power (" .. tostring(w.dpsMelee) .. ")")
            if w.dpsOff and w.dpsOff > 0.5 then
                check(w.dpsOff >= 7 * w.ap - 0.01 and w.dpsOff <= 7 * w.ap * 1.25 + 0.05,
                    name .. ": off-hand DPS is half, up to +25% with Dual Wield Specialization (" .. tostring(w.dpsOff) .. ")")
            end
        end
    end
end

-- 1b. Survival is melee in Forever: its melee weapon is priced like a melee class's
-- (14 x attack power) and outweighs the bow; Marksmanship the other way round.
as("HUNTER", "Orc")
do
    local function pts(equipLoc, sub, slot) return S.Points({ classID = 2, subClassID = sub, equipLoc = equipLoc, stats = { dps = 20 }, speed = 3.4 }, slot) end
    C.SetSpec("survival")
    local w = C.Weights()
    check(near(w.dpsMelee, 14 * w.ap), "Survival: weapon DPS = 14 x attack power (" .. tostring(w.dpsMelee) .. ")")
    check(pts("INVTYPE_2HWEAPON", 6, "MainHandSlot") > 3 * pts("INVTYPE_RANGED", 2, "RangedSlot"), "Survival: a 20 DPS polearm is worth far more than a 20 DPS bow")
    C.SetSpec("marksmanship")
    check(pts("INVTYPE_RANGED", 2, "RangedSlot") > 3 * pts("INVTYPE_2HWEAPON", 6, "MainHandSlot"), "Marksmanship: the bow is worth far more than the polearm")
    C.SetSpec("survival")
    check(C.Spec("HUNTER").key == "survival" and C.Spec("HUNTER").name == "Survival", "Survival is a Hunter spec")
end

-- 2. No weapon racials (flat bonuses in Forever).
check(C.RACIAL_CRIT == nil, "no weapon racial table")
as("ROGUE", "Human")
C.SetSpec("subtlety")
local function wpts(sub) return S.Points({ classID = 2, subClassID = sub, equipLoc = "INVTYPE_WEAPON", stats = { dps = 20 }, speed = 1.8 }, "MainHandSlot") end
check(wpts(15) > wpts(7), "a Human Subtlety rogue: a dagger beats a sword")
-- The dagger preference is on the weapon's damage, not its stats.
local function statDagger(sub) return S.Points({ classID = 2, subClassID = sub, equipLoc = "INVTYPE_WEAPON", stats = { agi = 10 }, speed = 1.8 }, "MainHandSlot") end
check(near(statDagger(15), statDagger(7)), "Agility on a dagger is worth what it is on a sword")

-- 3. The two hands are one choice.
as("WARRIOR", "Orc")
wear({ [16] = 411, [17] = 412 })
local plan, total, by = planOf({ 410, 413 })
check(not (by["Big 2H"] and by["Better Shield"]), "never a two-hander and a shield together")
local mh, oh = S.equipped.MainHandSlot.points, S.equipped.SecondaryHandSlot.points
local twoH = S.Points(rec(410), "MainHandSlot") - mh - oh
local shield = S.Points(rec(413), "SecondaryHandSlot") - oh
check(near(total, math.max(twoH, shield)), string.format("the Route takes the bigger of the two (%.1f; 2H %.1f, shield %.1f)", total, twoH, shield))

wear({ [16] = 414 })
GP.Sources.entries = {}
for _, id in ipairs({ 411, 413 }) do
    GP.Sources.entries[id] = { rec = rec(id), usable = true, effort = 1, best = { kind = "vendor", zone = "Durotar", mapID = 1 } }
end
local res = S.Run()
total = 0
for _, p in ipairs(res.plan.picks) do total = total + p.delta end
local real = S.Points(rec(411), "MainHandSlot") + S.Points(rec(413), "SecondaryHandSlot") - S.equipped.MainHandSlot.points
check(#res.plan.picks == 2 and near(total, real), string.format("off a two-hander: a one-hander and shield add up to what they're really worth (%.1f, real %.1f)", total, real))
GP.Sources.entries = {}

-- The try-on total (Character tab): the two together, not each with its partner.
local tried = { MainHandSlot = { rec = rec(411) }, SecondaryHandSlot = { rec = rec(413) } }
check(near(S.LoadoutGain(tried), real), "trying on a one-hander and shield over a two-hander: the real gain")
wear({ [16] = 411, [17] = 412 })
check(near(S.LoadoutGain({ MainHandSlot = { rec = rec(410) } }), twoH), "trying on a two-hander takes the shield off too")

-- 4. The second ring goes over the stronger one, and only if it's still a gain.
wear({ [11] = 400, [12] = 401 })
plan, total, by = planOf({ 402, 403 })
check(by["Ring X"] and not by["Ring Y"], "a ring weaker than the one it would replace isn't the second pick")
check(near(total, 40 * 0.5 - 10 * 0.5), "the Route's ring gain is X over B only (" .. total .. ")")
I[405] = { "Ring Z", 2, 25, 20, "INVTYPE_FINGER", 4, 0, { ITEM_MOD_STAMINA_SHORT = 30 } }
plan, total, by = planOf({ 402, 405 })
check(by["Ring X"] and by["Ring Z"] and by["Ring X"].slot ~= by["Ring Z"].slot, "two ring upgrades go on different fingers")
check(near(total, (40 - 10) * 0.5 + (30 - 20) * 0.5), "X over B, Z over A (" .. total .. ")")

-- Unique: a second copy only if it isn't Unique.
wear({ [11] = 402, [12] = 401 })
check(S.Upgrade(rec(402)) == "Finger1Slot", "a second copy of a ring you wear goes on the other finger")
wear({ [11] = 404, [12] = 401 })
check(rec(404).unique == true and S.Upgrade(rec(404)) == nil, "a Unique ring you wear isn't suggested again")

-- 5. Damage-and-healing spell power is Healing too.
as("PALADIN")
C.SetSpec("holy")
wear({})
local dh, heal, sp = rec(420), rec(421), rec(422)
check(dh.stats.heal == 20 and dh.stats.sp == 20, "a damage-and-healing line counts for both")
check(sp.stats.heal == 20, "the stat table's spell power counts as Healing too")
check(heal.stats.heal == 12 and heal.stats.sp == 4, "healer gear's own Healing and bonus damage stay as they are")
check(S.Points(dh, "ChestSlot") > S.Points(heal, "ChestSlot"), "for a healer, +20 damage and healing beats +12 healing")
check(not S.HealerGear(dh, { sp = 1 }), "damage-and-healing gear isn't healer gear")
check(S.HealerGear(heal, { sp = 1 }), "healing gear still is")

-- 6. Gear the client hasn't loaded yet isn't an empty slot.
as("WARRIOR")
local realLink = GetInventoryItemLink
local loaded = false
I[451] = { "Late Chest", 2, 26, 20, "INVTYPE_CHEST", 4, 3, { ITEM_MOD_STAMINA_SHORT = 50 } }
local realInfo = C_Item.GetItemInfo
GetInventoryItemLink = function(u, slot) if slot == 5 then return H.Link(451) end return realLink(u, slot) end
local wantWas = GP.Items.Want
local calledBack
GP.Items.Want = function(id, fn) calledBack = fn end
GP.Items.linkCache[H.Link(451)] = nil
local ITEMS451 = I[451]
I[451] = nil
H.ITEMS[451] = nil
-- (no data for 451 now: the client hasn't loaded it)
GetInventoryItemLink = function(u, slot)
    if slot == 5 then return "|cff1eff00|Hitem:451::::::::23:::::|h[Late Chest]|h|r" end
    return realLink(u, slot)
end
for k in pairs(EQ) do EQ[k] = nil end
S.ReadEquipped()
check(S.equipped.ChestSlot.pending == true, "a worn item not loaded yet is pending")
check(S.Upgrade(rec(450)) == nil, "nothing is weighed against it (a worse chest isn't 'new')")
check(type(calledBack) == "function", "it's asked for")
I[451] = ITEMS451
for _ = 1, 3 do H.Tick(0.1) end         -- (anything already queued runs first)
local runs = 0
local run = S.Run
S.Run = function(...) runs = runs + 1 return run(...) end
calledBack(GP.Items.FromLink("|cff1eff00|Hitem:451::::::::23:::::|h[Late Chest]|h|r"), 451)
for _ = 1, 3 do H.Tick(0.1) end
check(runs >= 1, "and everything is scored again when it arrives")
check(S.equipped.ChestSlot.rec ~= nil and select(2, S.Upgrade(rec(450))) < 0, "then a worse chest is a loss")
S.Run, GP.Items.Want, GetInventoryItemLink = run, wantWas, realLink

-- 7. Expertise and percentages from the tooltip.
local ex = rec(430)
check(near(ex.stats.expertise, 1.0), "Forever's expertise line reads as 1% (" .. tostring(ex.stats.expertise) .. ")")
check(near(rec(431).stats.crit, 6), "the tooltip's 6% crit wins over the stat table's number (" .. tostring(rec(431).stats.crit) .. ")")

-- 8. Hit past the cap counts for nothing.
as("WARLOCK")
local cap = C.HitCap()
check(cap == C.HIT_CAP.spell, "a warlock's cap is the spell cap")
wear({ [1] = 440, [10] = 442 })          -- 4% hit on: at the cap
local _, dHit = S.Upgrade(rec(441))
check(dHit == nil or dHit < S.MIN_POINTS, "at the cap, +2% hit gloves aren't an upgrade (" .. tostring(dHit) .. ")")
wear({ [10] = 442 })
_, dHit = S.Upgrade(rec(441))
check(near(dHit, 2 * C.Weights().hit), "under the cap, hit counts in full (" .. tostring(dHit) .. ")")
wear({ [1] = 440, [10] = 441 })          -- 6% on: 2% past the cap
local _, dOff = S.Upgrade(rec(442))
check(near(dOff, 0), "past the cap, taking hit gloves off loses nothing (" .. tostring(dOff) .. ")")
as("PALADIN"); C.SetSpec("holy")
check(C.HitCap() == nil, "healers don't score hit")

-- 9. The learned-spell event of the modern client rescores.
as("WARLOCK")
for _ = 1, 3 do H.Tick(0.1) end
runs = 0
S.Run = function(...) runs = runs + 1 return run(...) end
H.Fire("LEARNED_SPELL_IN_SKILL_LINE", 201)
for _ = 1, 3 do H.Tick(0.1) end
check(runs >= 1, "LEARNED_SPELL_IN_SKILL_LINE rescores")
runs = 0
H.Fire("SPELLS_CHANGED")
for _ = 1, 3 do H.Tick(0.1) end
check(runs >= 1, "SPELLS_CHANGED rescores")
S.Run = run

-- 10. The controller isn't switched in combat (a blocked call doesn't error).
local UI = GP.UI
if UI and UI.Toggle then
    UI.Toggle()
    for _ = 1, 3 do H.Tick(0.1) end
    local f = UI.frame
    if f and f.EnableGamePadButton then
        H.combat = true
        f._pad = "untouched"
        UI.Pad = UI.Pad
        f:Hide(); f:Show()
        check(f._pad == "untouched", "in combat the window doesn't take or give back the controller")
        H.combat = false
        H.Fire("PLAYER_REGEN_ENABLED")
        if f.IsShown and f:IsShown() then f:Hide() end
    end
end

-- 11. Two items that bind when worn: one confirmation at a time.
H.bag = { [5] = 212 }
H.bind = { [210] = 2, [212] = 2 }
H.equips = {}
UI.tried = { HandsSlot = { rec = GP.Items.Get(210), slot = "HandsSlot" }, WaistSlot = { rec = GP.Items.Get(212), slot = "WaistSlot" } }
local sent, left = UI.PutOn()
check(sent == 1 and left == 1 and #H.equips == 1, "two bind-on-equip items: one sent, one left (" .. tostring(sent) .. ", " .. tostring(left) .. ")")
local rest = 0
for _ in pairs(UI.tried or {}) do rest = rest + 1 end
check(rest == 1, "the one left stays tried on for the next click")
sent, left = UI.PutOn()
check(sent == 1 and left == 0 and #H.equips == 2, "the next click sends the other")
H.bag, H.bind, H.equips, UI.tried = nil, nil, nil, nil

-- Launch night (Nov 4): a worn item worth 0 points to the spec (a caster's
-- starter dagger) isn't an empty slot.
do
    local Score, UIw = GP.Score, GP.UI
    local keepMH, keepOH = Score.equipped.MainHandSlot, Score.equipped.SecondaryHandSlot
    Score.equipped.MainHandSlot = { points = 0, rec = { id = 1, name = "Forsaken Dagger", equipLoc = "INVTYPE_WEAPON" } }
    Score.equipped.SecondaryHandSlot = nil
    check(Score.Worn("MainHandSlot"), "a worthless dagger counts as worn")
    local text = UIw.GainText({ slot = "MainHandSlot", delta = 12, pct = nil, tier = "secondary" })
    check(text ~= "new" and text:find("12"), "over it, the gain is in points, not 'new' (" .. tostring(text) .. ")")
    check(not UIw.GainLine("MainHandSlot", 12, nil):find("empty"), "and the chat line doesn't call the slot empty")
    Score.equipped.MainHandSlot = nil
    check(not Score.Worn("MainHandSlot") and UIw.GainText({ slot = "MainHandSlot", delta = 12, tier = "primary" }) == "new",
        "a truly empty main hand is still 'new'")
    Score.equipped.MainHandSlot, Score.equipped.SecondaryHandSlot = keepMH, keepOH
end

-- Launch night (Nov 4): sources just as easy to get are ordered with the
-- ones on your continent first; this is how the continent is found.
do
    local Src = GP.Sources
    local keepInfo, keepBest = C_Map.GetMapInfo, C_Map.GetBestMapForUnit
    local M = { [1420] = { mapType = 3, parentMapID = 1415 }, [1429] = { mapType = 3, parentMapID = 1415 },
        [1411] = { mapType = 3, parentMapID = 1414 }, [1415] = { mapType = 2, parentMapID = 947 },
        [1414] = { mapType = 2, parentMapID = 947 }, [947] = { mapType = 1 }, [1458] = { mapType = 3, parentMapID = 1420 }, [9465] = { mapType = 5, parentMapID = 1420 } }
    C_Map.GetMapInfo = function(id) return M[id] end
    C_Map.GetBestMapForUnit = function() return 1420 end
    check(Src.Continent(1429) == 1415 and Src.Continent(1411) == 1414, "zones find their continent")
    check(Src.Continent(1458) == 1415, "a city inside a zone too")
    check(Src.Zone(1458) == 1458 and Src.Zone(1420) == 1420 and Src.Zone(1415) == nil, "a city is a zone of its own; a continent is no zone")
    check(Src.Zone(9465) == 1420, "a small area (Deathknell's own map) climbs to its zone")
    check(Src.PlayerZone() == 1420, "the zone you're in")
    -- The Small Green Dagger on launch night: Muad in Tirisfal before a Young
    -- Wolf in Elwynn (same continent, lower level), for an Undead in Tirisfal.
    local ways = { { kind = "drop", name = "Young Wolf", zone = "Elwynn Forest", mapID = 1429, level = 1 },
        { kind = "drop", name = "Muad", zone = "Tirisfal Glades", mapID = 1420, level = 6 },
        { kind = "drop", name = "Far Mob", zone = "Durotar", mapID = 1411, level = 1 } }
    Src.SortSources(ways)
    check(ways[1].name == "Muad" and ways[2].name == "Young Wolf" and ways[3].name == "Far Mob",
        "just as easy: your zone, then your continent, then across the sea (" .. ways[1].name .. ", " .. ways[2].name .. ", " .. ways[3].name .. ")")
    check(Src.PlayerContinent() == 1415, "and so does where you stand")
    check(Src.Continent(99999) == nil and Src.Continent(nil) == nil, "an unknown map has none")
    -- Zephras Isle (Nov 5): on no continent on the game's maps; an island of its own.
    M[2521] = { mapType = 3, parentMapID = 947 }
    check(Src.Continent(2521) == 2521, "Zephras Isle is a land of its own")
    GP.Score.here = 1415
    check(GP.Score.IsFar({ kind = "vendor", mapID = 2521 }), "so its vendors are across the sea from Tirisfal")
    GP.Score.here = 2521
    check(not GP.Score.IsFar({ kind = "vendor", mapID = 2521 }), "and not when you're on it")
    GP.Score.here = nil
    -- A zone far above you (Nov 5: Surfer Shoes from Jang in Booty Bay at level 8).
    M[1434] = { mapType = 3, parentMapID = 1415 }
    check(Src.ZoneTooHigh({ kind = "vendor", mapID = 1434 }, 8), "Stranglethorn is too high for a level 8")
    check(not Src.ZoneTooHigh({ kind = "vendor", mapID = 1434 }, 25), "not for a level 25")
    check(not Src.ZoneTooHigh({ kind = "vendor", mapID = 1420 }, 8) and not Src.ZoneTooHigh({ kind = "drop", mapID = 1434, dungeon = "Zul'Gurub" }, 8),
        "Tirisfal isn't, and a dungeon is judged by its own levels")
    local lvl = GP.PlayerInfo().level or 1
    local stv = { kind = "vendor", vendor = "Jang", zone = "Stranglethorn Vale", mapID = 1434 }
    check(GP.Score.Effort(stv) == (lvl <= 20 and 2 or 1), "a vendor in a zone 10+ levels up is a trip, not Best now (level " .. lvl .. ")")
    -- Far sources: another continent than where you stand.
    local keepHere = GP.Score.here
    GP.Score.here = Src.PlayerContinent()
    check(GP.Score.IsFar({ mapID = 1411 }) and not GP.Score.IsFar({ mapID = 1429 }), "Durotar is far from Tirisfal, Elwynn isn't")
    check(not GP.Score.IsFar({ mapID = 99999 }) and not GP.Score.IsFar({ kind = "quest" }), "unknown places aren't far")
    check(not GP.Score.IsFar({ kind = "drop", mapID = 1411, dungeon = "Ragefire Chasm" }), "a dungeon is never too far (group finder)")
    GP.Score.here = nil
    check(not GP.Score.IsFar({ mapID = 1411 }), "and nothing is far when you're nowhere (an instance)")
    GP.Score.here = keepHere
    -- Locked to your continent: an upgrade only found across the sea is off
    -- the lists (tooltip says why); one with a way on your continent too stays,
    -- by that way.
    wear({ [16] = 414 })
    GP.Sources.entries = {
        [411] = { rec = rec(411), usable = true, effort = 1, best = { kind = "vendor", zone = "Durotar", mapID = 1411 },
            sources = { { kind = "vendor", zone = "Durotar", mapID = 1411 } } },
        [413] = { rec = rec(413), usable = true, effort = 1, best = { kind = "vendor", zone = "Durotar", mapID = 1411 },
            sources = { { kind = "vendor", zone = "Durotar", mapID = 1411 }, { kind = "vendor", zone = "Elwynn Forest", mapID = 1429 } } },
    }
    local r = S.Run()
    local a, b = r.byID[411], r.byID[413]
    check(a and a.elsewhere and a.tier == nil, "only across the sea: off the lists (" .. tostring(a and a.tier) .. ")")
    check(b and not b.elsewhere and b.tier == "primary" and b.source.mapID == 1429,
        "a way on your continent too: listed, by that way (" .. tostring(b and b.tier) .. ")")
    local inPlan = false
    for _, p in ipairs(r.plan.picks) do if p.rec.id == 411 then inPlan = true end end
    check(not inPlan, "and the Route doesn't send you across the sea")
    C_Map.GetBestMapForUnit = function() return nil end   -- in an instance
    r = S.Run()
    check(r.byID[411] and r.byID[411].tier == "primary", "where the game can't say where you are, nothing is locked out")
    GP.Sources.entries = {}
    C_Map.GetMapInfo, C_Map.GetBestMapForUnit = keepInfo, keepBest
    S.Run()
end

print(string.format("  scoring: %d checks, %d failed, %d errors", checks, failed, #(H.errors or {})))
for _, e in ipairs(H.errors or {}) do print("  ERROR: " .. tostring(e):match("^[^\n]*")) end
