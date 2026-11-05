-- Score: how good an item is for you, how much better than what you wear,
-- and which upgrades are "Best now" (easy to get at your level) versus
-- "Worth chasing" (a dungeon, a rare drop, a long chain, a few levels off).

local _, GP = ...

local Score = {}
GP.Score = Score

local Classes, Slots = GP.Classes, GP.Slots

Score.MIN_POINTS = 0.5    -- smaller gains are noise
Score.MIN_PCT = 1         -- and so is less than 1%

-- ---------------------------------------------------------------------
-- One item's points
-- ---------------------------------------------------------------------

local W = Classes.W

-- Which weight a weapon's damage per second takes.
local function dpsWeight(rec, weights, slotKey)
    if rec.classID ~= Classes.WEAPON then return 0 end
    local sub = rec.subClassID
    if sub == W.WAND then return weights.dpsWand or 0 end
    if sub == W.BOW or sub == W.GUN or sub == W.CROSSBOW then return weights.dpsRanged or 0 end
    if sub == W.THROWN then return (weights.dpsRanged or 0) * 0.8 end
    if rec.equipLoc == "INVTYPE_WEAPONOFFHAND" or slotKey == "SecondaryHandSlot" then
        return weights.dpsOff or ((weights.dpsMelee or 0) * 0.5)
    end
    return weights.dpsMelee or 0
end

-- Points for an item record (higher is better). slotKey matters only for
-- one-handers, which are worth less in the off hand.
function Score.Points(rec, slotKey, weights)
    if not rec or not rec.stats then return 0 end
    weights = weights or Classes.Weights()
    local total = 0
    for key, value in pairs(rec.stats) do
        if key ~= "dps" then
            local w = weights[key]
            if w then total = total + w * value end
        end
    end
    -- A spec's weapon speed (a slow main hand, a fast off hand) and weapon
    -- type (a Subtlety rogue's dagger) change what the weapon's damage is
    -- worth. Its stats are worth the same on any weapon.
    local speedF, typeF = Classes.WeaponFactor(rec, slotKey)
    if rec.stats.dps then total = total + dpsWeight(rec, weights, slotKey) * rec.stats.dps * speedF * typeF end
    local _, factor = Classes.CanUse(rec.classID, rec.subClassID, rec.equipLoc, nil, 999)
    if factor and factor > 0 and factor ~= 1 then total = total * factor end
    return total
end

-- ---------------------------------------------------------------------
-- What you wear now
-- ---------------------------------------------------------------------

Score.equipped = {}     -- [slotKey] = { rec, points, link, id, pending }
Score.gearHit = 0       -- hit (%) on the gear you wear

function Score.ReadEquipped()
    local weights = Classes.Weights()
    local hit = 0
    for _, s in ipairs(Slots.LIST) do
        local link = GetInventoryItemLink("player", s.id)
        local rec = link and GP.Items.FromLink(link) or nil
        local id = link and GP.Items.IDFromLink(link) or nil
        -- Worn but not loaded by the client yet (the first login after a
        -- patch): not an empty slot. Nothing is weighed against it until
        -- it's in, and then everything is scored again.
        local pending = link ~= nil and rec == nil
        if pending and id then
            GP.Items.Want(id, function(loaded) if loaded then Score.Request() end end)
        end
        if rec and rec.stats and rec.stats.hit then hit = hit + rec.stats.hit end
        Score.equipped[s.key] = {
            link = link, rec = rec,
            points = rec and Score.Points(rec, s.key, weights) or 0,
            id = id, pending = pending or nil,
        }
    end
    Score.gearHit = hit
end

local function eq(key) return Score.equipped[key] or { points = 0 } end

-- Whether something is worn in a slot (worth anything or not): a slot
-- whose item is worth 0 points to your spec (a starter dagger to a
-- caster) still isn't empty. For the main hand, an off hand counts too.
function Score.Worn(slotKey)
    if type(slotKey) ~= "string" then return false end
    if eq(slotKey).rec then return true end
    return slotKey == "MainHandSlot" and eq("SecondaryHandSlot").rec ~= nil
end

local function twoHanded()
    local mh = eq("MainHandSlot").rec
    return mh and mh.equipLoc == "INVTYPE_2HWEAPON"
end

-- ---------------------------------------------------------------------
-- How much better an item is than what it replaces
-- ---------------------------------------------------------------------

-- The best one-hander and off-hand you could get (for weighing a two-hander
-- against a pair, and a pair against a two-hander).
local bestPartner = { main = 0, off = 0 }

local function hitOf(r) return r and r.stats and r.stats.hit or 0 end

-- What a change of hit is really worth: hit past the cap does nothing.
-- hitIn is the hit on what goes on, hitOut on what comes off. Returns the
-- points to add to a plain weights x stats delta (0 or less for a gain past
-- the cap; more than 0 for losing hit you had past it).
function Score.HitPastCap(hitIn, hitOut, weights)
    weights = weights or Classes.Weights()
    local cap = Classes.HitCap(weights)
    if not cap or hitIn == hitOut then return 0 end
    local now = Score.gearHit or 0
    local after = now - hitOut + hitIn
    local useful = math.min(after, cap) - math.min(now, cap)
    return (weights.hit or 0) * (useful - (hitIn - hitOut))
end

-- Returns slotKey, delta (points gained), pct (nil when the slot is empty),
-- base (the points of what it replaces) and its points for the best place
-- to put rec.
function Score.Upgrade(rec)
    local places = rec and Slots.FOR_EQUIPLOC[rec.equipLoc]
    if not places then return nil end
    local weights = Classes.Weights()
    local hitIn = hitOf(rec)
    local best
    for _, slotKey in ipairs(places) do
        local okSlot = true
        if slotKey == "SecondaryHandSlot" and rec.equipLoc == "INVTYPE_WEAPON" and not Classes.CanDualWield() then
            okSlot = false
        end
        local points = okSlot and Score.Points(rec, slotKey, weights) or 0
        local base, delta, hitOut
        local s = Slots.BY_KEY[slotKey]
        if not okSlot then
            -- (no place here)
        elseif s.pair then
            -- A ring or trinket replaces the weaker of the two you wear. One
            -- you already have on: a Unique one can't go on twice, a second
            -- copy of any other goes in the other slot.
            local a, b = eq(slotKey), eq(s.pair)
            if a.pending or b.pending then return nil end
            local wornA, wornB = a.id == rec.id, b.id == rec.id
            if (wornA and wornB) or ((wornA or wornB) and rec.unique) then return nil end
            local target
            if wornA then target = s.pair
            elseif wornB then target = slotKey
            else target = (a.points <= b.points) and slotKey or s.pair end
            local e = eq(target)
            slotKey, base, hitOut = target, e.points, hitOf(e.rec)
            delta = points - base
            if not e.rec then base = 0 end
        elseif slotKey == "MainHandSlot" then
            local mh, oh = eq("MainHandSlot"), eq("SecondaryHandSlot")
            if mh.pending or oh.pending or mh.id == rec.id or (rec.unique and oh.id == rec.id) then
                okSlot = false
            elseif rec.equipLoc == "INVTYPE_2HWEAPON" then
                base = mh.points + oh.points
                delta = points - base
                hitOut = hitOf(mh.rec) + hitOf(oh.rec)
                if not mh.rec and not oh.rec then base = 0 end
            elseif twoHanded() then
                -- Off a two-hander: with the best off hand you can get.
                base = mh.points
                delta = points + bestPartner.off - base
                hitOut = hitOf(mh.rec)
            else
                base = mh.points
                delta = points - base
                hitOut = hitOf(mh.rec)
                if not mh.rec then base = 0 end
            end
        elseif slotKey == "SecondaryHandSlot" then
            local mh, oh = eq("MainHandSlot"), eq("SecondaryHandSlot")
            if mh.pending or oh.pending or oh.id == rec.id or (rec.unique and mh.id == rec.id) then
                okSlot = false
            elseif twoHanded() then
                -- Off a two-hander: with the best main hand you can get.
                base = mh.points
                delta = points + bestPartner.main - base
                hitOut = hitOf(mh.rec)
            else
                base = oh.points
                delta = points - base
                hitOut = hitOf(oh.rec)
                if not oh.rec then base = 0 end
            end
        else
            local e = eq(slotKey)
            if e.pending or e.id == rec.id then
                okSlot = false
            else
                base = e.points
                delta = points - base
                hitOut = hitOf(e.rec)
                if not e.rec then base = 0 end
            end
        end
        if okSlot and delta then
            delta = delta + Score.HitPastCap(hitIn, hitOut or 0, weights)
            if not best or delta > best.delta then
                best = { slot = slotKey, delta = delta, base = base, points = points }
            end
        end
    end
    if not best then return nil end
    local pct = best.base > 0 and (best.delta / best.base * 100) or nil
    return best.slot, best.delta, pct, best.base, best.points
end

-- What a set of items tried on ({ [slotKey] = ev }) adds to your score,
-- all together: a two-hander takes the off hand with it, an off hand
-- tried on under a two-hander takes the two-hander off.
function Score.LoadoutGain(tried)
    tried = tried or {}
    local weights = Classes.Weights()
    local after = {}
    for _, key in ipairs(Slots.ORDER) do after[key] = eq(key).rec or false end
    for key, ev in pairs(tried) do
        if after[key] ~= nil and ev.rec then after[key] = ev.rec end
    end
    local tmh = tried.MainHandSlot
    if tmh and tmh.rec and tmh.rec.equipLoc == "INVTYPE_2HWEAPON" then
        after.SecondaryHandSlot = false
    elseif tried.SecondaryHandSlot and not tmh and twoHanded() then
        after.MainHandSlot = false
    end
    local now, total, hitNow, hitAfter = 0, 0, 0, 0
    for _, key in ipairs(Slots.ORDER) do
        local e = eq(key)
        now = now + (e.points or 0)
        hitNow = hitNow + hitOf(e.rec)
        local rec = after[key]
        if rec == (e.rec or false) then
            total = total + (e.points or 0)
        elseif rec then
            total = total + Score.Points(rec, key, weights)
        end
        hitAfter = hitAfter + hitOf(rec or nil)
    end
    return total - now + Score.HitPastCap(hitAfter, hitNow, weights)
end

-- ---------------------------------------------------------------------
-- Sorting every candidate into "Best now" and "Worth chasing"
-- ---------------------------------------------------------------------

-- How hard a source is to use: 0 = in your bags, 1 = a quest or vendor
-- in the open world, 2 = a dungeon, a named rare/elite or a long chain,
-- 3 = a random drop from many mobs.
function Score.Effort(source)
    if not source then return 9 end
    if source.kind == "bags" then return 0 end
    -- Where it is isn't in the database: not easy, whatever it is.
    local unknown = not source.worldDrop and not source.dungeon and not source.zone and not source.mapID
    if source.kind == "vendor" then return (source.dungeon or unknown) and 2 or 1 end
    if source.kind == "quest" then
        -- Nobody known to start it (or its chain): you can't go and pick it up.
        local starter = source.giver or source.startItem or (source.chainStart and source.chainStart.giver)
        if source.dungeon or unknown or not starter or (source.chainLength or 0) >= 3 then return 2 end
        return 1
    end
    if source.kind == "drop" or source.kind == "object" then
        if source.worldDrop then return 3 end
        return 2
    end
    return 2
end

Score.results = { bySlot = {}, all = {}, byID = {}, primary = 0, secondary = 0, plan = { picks = {}, zones = {} } }

-- Healer gear: Healing is its biggest spell stat ("+7 Healing, +3 Spell
-- Damage") and your weights give Healing nothing, so you're not the healer.
-- It's left off your lists (unless you ask for it in Settings), and when it
-- drops in a group it's the healer's to roll on.
function Score.HealerGear(rec, weights)
    local s = rec and rec.stats
    local heal = s and s.heal or 0
    if heal <= 0 then return false end
    weights = weights or Classes.Weights()
    if (weights.heal or 0) > 0 then return false end
    return heal > (s.sp or 0)
end

-- Whether you can wear rec now (or at `level`): there's a slot for it, it's
-- your class's armor or weapon, no class limit or rank stands in the way,
-- and it isn't healer gear (unless asked for in Settings). The second
-- return is true when it's left out only for being healer gear.
function Score.CanWear(rec, level)
    if not (rec and Slots.FOR_EQUIPLOC[rec.equipLoc]) then return false end
    if Classes.CanUse(rec.classID, rec.subClassID, rec.equipLoc, nil, level) ~= true then return false end
    if rec.classes and not rec.classes[UnitClass("player")] then return false end
    if rec.needs then return false end
    if Score.HealerGear(rec) and GP.Setting("healerGear") ~= true then return false, true end
    return true
end

-- An upgrade big enough to mention: slot, delta, pct (nil pct: an empty
-- slot), or nil.
function Score.Gain(rec)
    local slot, delta, pct = Score.Upgrade(rec)
    if slot and delta and delta >= Score.MIN_POINTS and (pct == nil or pct >= Score.MIN_PCT) then
        return slot, delta, pct
    end
end

-- Loot a group rolls on: mob drops, and chests in dungeons. (A quest reward
-- or a vendor's item is nobody else's.)
function Score.GroupLoot(src)
    if not src then return false end
    if src.kind == "drop" then return true end
    return src.dungeon ~= nil and src.kind ~= "quest" and src.kind ~= "vendor" and src.kind ~= "bags"
end

local function newSlotTable()
    local t = {}
    for _, key in ipairs(Slots.ORDER) do t[key] = { primary = {}, secondary = {}, locked = {} } end
    return t
end

local function better(a, b)
    -- Across the sea goes after what's on your continent, however big.
    if (a.far == true) ~= (b.far == true) then return not a.far end
    if a.delta ~= b.delta then return a.delta > b.delta end
    return (a.rec.ilvl or 0) > (b.rec.ilvl or 0)
end

-- The level an entry waits for: the item's own, a kind that opens later
-- (Mail at 40 for a hunter), a quest you can't pick up yet.
local function reqOf(entry, src)
    local rec = entry.rec
    src = src or entry.best
    local questReq = src and src.kind == "quest" and src.reqLevel or 0
    return math.max(rec.reqLevel or 0, entry.opensAt or 0, questReq)
end

-- Whether a source is on another continent than the one you're on
-- (Score.here, set by Score.Run). Unknown either way: not far.
local function isFar(src)
    local here = Score.here
    if not (here and src and src.mapID and GP.Sources and GP.Sources.Continent) then return false end
    -- Dungeons are run from anywhere (group finder, a summon): never locked out.
    if src.dungeon then return false end
    local c = GP.Sources.Continent(src.mapID)
    return c ~= nil and c ~= here
end

Score.IsFar = isFar

-- How hard it is to get: a quest or a mob well above you isn't easy,
-- whatever the item needs, and neither is one across the sea (launch
-- night: a rare in Teldrassil in an Undead's list in Tirisfal). Returns
-- effort, the source's level, and whether it's far.
local function effortOf(entry, level, soon)
    local src = entry.best
    local effort = entry.effort or 9
    -- Easiest across the sea, but another way on your continent: that one.
    local far = isFar(src)
    if far then
        for _, s in ipairs(entry.sources or {}) do
            if not isFar(s) then src, effort, far = s, Score.Effort(s), false break end
        end
    end
    local srcLevel = src and (src.kind == "quest" or src.kind == "drop") and src.level or 0
    if srcLevel > level + soon and effort < 2 then effort = 2 end
    return effort, srcLevel, far, src
end

-- Scores every candidate the sources found (GP.Sources.entries) against
-- what you wear, then sorts them into the two tiers and builds the plan.
function Score.Run()
    GP.PlayerInfo()
    Score.ReadEquipped()
    Score.here = GP.Sources and GP.Sources.PlayerContinent and GP.Sources.PlayerContinent() or nil
    local level = GP.player.level
    local ahead, soon = GP.Setting("ahead") or 5, GP.Setting("soon") or 2
    local allowDungeons, allowWorld = GP.Setting("dungeons") ~= false, GP.Setting("worldDrops") == true
    local allowHealer = GP.Setting("healerGear") == true
    local entries = GP.Sources and GP.Sources.entries or {}

    -- First pass: the best partners for two-hander comparisons (only what
    -- would itself be "Best now").
    bestPartner.main, bestPartner.off = 0, 0
    local weights = Classes.Weights()
    for _, entry in pairs(entries) do
        local rec = entry.rec
        local pe, _, pfar, psrc = effortOf(entry, level, soon)
        if rec and entry.usable and not rec.needs and not pfar and reqOf(entry, psrc) <= level + soon
            and pe <= 1 and (allowHealer or not Score.HealerGear(rec, weights)) then
            local loc = rec.equipLoc
            if loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONMAINHAND" then
                bestPartner.main = math.max(bestPartner.main, Score.Points(rec, "MainHandSlot", weights))
            end
            if loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" or loc == "INVTYPE_WEAPONOFFHAND" or
                (loc == "INVTYPE_WEAPON" and Classes.CanDualWield()) then
                bestPartner.off = math.max(bestPartner.off, Score.Points(rec, "SecondaryHandSlot", weights))
            end
        end
    end

    local res = { bySlot = newSlotTable(), all = {}, byID = {}, primary = 0, secondary = 0, locked = 0 }
    for _, entry in pairs(entries) do
        local rec = entry.rec
        if rec and entry.usable then
            -- Mail at 40 for a hunter: the item waits for that level too, and
            -- so does a quest you can't pick up yet.
            local effort, srcLevel, far, src = effortOf(entry, level, soon)
            local req = reqOf(entry, src)
            local slot, delta, pct, base, points = Score.Upgrade(rec)
            if slot and req <= level + ahead then
                local ev = { entry = entry, rec = rec, slot = slot, delta = delta, pct = pct, base = base,
                    points = points, source = src, effort = effort, req = req, srcLevel = srcLevel, needs = rec.needs,
                    far = far }
                -- A weapon skill, Mail or Plate, or Dual Wield still to learn (Training.lua).
                if GP.Training then ev.train = GP.Training.Need(rec, slot) end
                local gain = delta >= Score.MIN_POINTS and (pct == nil or pct >= Score.MIN_PCT)
                local dungeon = src and src.dungeon
                if Score.HealerGear(rec, weights) then
                    ev.healer = true
                    -- Not for you: left out, from any source (unless you've
                    -- asked for healer gear in Settings).
                    if not allowHealer then ev.healerPass = true end
                end
                if gain and ev.healerPass then
                    ev.tier = nil
                -- "Requires Sergeant", a reputation, a profession: not yours
                -- yet, so it waits in a group of its own.
                elseif gain and ev.needs then
                    ev.tier = "locked"
                -- Its easiest source is on another continent: off your lists
                -- (Koulta's call, launch night). Tooltips and Browse still
                -- show it; sail there and GearPath looks again.
                elseif gain and ev.far then
                    ev.tier = nil
                    ev.elsewhere = true
                elseif gain then
                    if req <= level + soon and ev.effort <= 1 then
                        ev.tier = "primary"
                    elseif (ev.effort <= 2 or (allowWorld and ev.effort == 3)) and (allowDungeons or not dungeon) then
                        ev.tier = "secondary"
                    end
                end
                res.all[#res.all + 1] = ev
                res.byID[rec.id] = ev
                local group = Slots.GROUP[slot] or slot
                local bucket = res.bySlot[group]
                if bucket and ev.tier then
                    table.insert(bucket[ev.tier], ev)
                    res[ev.tier] = res[ev.tier] + 1
                end
            end
        end
    end
    for _, bucket in pairs(res.bySlot) do
        table.sort(bucket.primary, better)
        table.sort(bucket.secondary, better)
        table.sort(bucket.locked, better)
    end
    res.plan = Score.BuildPlan(res)
    Score.results = res
    GP.Fire("ScoresChanged", res)
    return res
end

-- How long the last run took (for /gp status and /gp report).
do
    local run = Score.Run
    function Score.Run(...)
        local t0 = GP.Clock()
        local res = run(...)
        Score.lastMs = GP.Clock() - t0
        return res
    end
end

-- The plan: the best "Best now" item for each slot, never two rewards from
-- the same quest (you only get to pick one), then grouped by zone.
-- keep(ev), when given, limits it to some items (one kind of content).
-- A pick is the item's evaluation, or (when the plan puts it somewhere
-- else, or it's worth something else alongside the other picks) a copy of
-- it with its own slot, delta and pct.
local function planned(ev, slot, delta, base)
    local pct = base and base > 0 and (delta / base * 100) or nil
    return setmetatable({ slot = slot, delta = delta, pct = pct, planned = true }, { __index = ev })
end

local function bigEnough(delta, base)
    return delta >= Score.MIN_POINTS and (not base or base <= 0 or delta / base * 100 >= Score.MIN_PCT)
end

function Score.BuildPlan(res, keep)
    local picks, usedQuest, usedItem = {}, {}, {}
    local function questOf(ev)
        -- A pick-one quest gives one of its rewards; one that gives them all doesn't block.
        return ev.source and ev.source.kind == "quest" and ev.source.choice ~= false and ev.source.id
    end
    local function free(ev)
        local q = questOf(ev)
        return (not keep or keep(ev)) and not usedItem[ev.rec.id] and not (q and usedQuest[q])
    end
    local function take(pick)
        picks[#picks + 1] = pick
        usedItem[pick.rec.id] = true
        local q = questOf(pick)
        if q then usedQuest[q] = pick end
    end
    local function list(key) return res.bySlot[key] and res.bySlot[key].primary or {} end

    -- The two hands are one choice: a two-hander, or a main hand and an
    -- off hand, never both. Returns the picks and their gain together.
    local function hands()
        local mh, oh = eq("MainHandSlot"), eq("SecondaryHandSlot")
        local wearing2H = twoHanded()
        local best2H, bestMain, bestOff
        for _, ev in ipairs(list("MainHandSlot")) do
            if free(ev) then
                if ev.rec.equipLoc == "INVTYPE_2HWEAPON" then
                    if not best2H or ev.delta > best2H.delta then best2H = ev end
                elseif not bestMain or ev.points > bestMain.points then
                    bestMain = ev
                end
            end
        end
        for _, ev in ipairs(list("SecondaryHandSlot")) do
            if free(ev) and (not bestOff or ev.points > bestOff.points) then bestOff = ev end
        end
        -- Two rewards of the same pick-one quest: the bigger one.
        if bestMain and bestOff and questOf(bestMain) and questOf(bestMain) == questOf(bestOff) then
            if bestMain.points >= bestOff.points then bestOff = nil else bestMain = nil end
        end
        local pair, pairGain = {}, 0
        if wearing2H then
            -- Off a two-hander takes a main hand (an off hand alone isn't a swap).
            if bestMain then
                local m, o = bestMain.points or 0, bestOff and bestOff.points or 0
                pairGain = m + o - mh.points
                if bigEnough(pairGain, mh.points) then
                    -- The two-hander's points shared between the two, by their points.
                    local share = (m + o) > 0 and m / (m + o) or 1
                    pair[1] = planned(bestMain, "MainHandSlot", m - mh.points * share, mh.points * share)
                    if bestOff then
                        pair[2] = planned(bestOff, "SecondaryHandSlot", o - mh.points * (1 - share), mh.points * (1 - share))
                    end
                else
                    pairGain = 0
                end
            end
        else
            if bestMain then pair[#pair + 1] = bestMain; pairGain = pairGain + bestMain.delta end
            if bestOff then pair[#pair + 1] = bestOff; pairGain = pairGain + bestOff.delta end
        end
        if best2H and best2H.delta >= pairGain then return { best2H }, best2H.delta end
        return pair, pairGain
    end

    -- A ring or trinket pair: the first goes over the weaker of the two you
    -- wear, the second over the other one (and only if it's still a gain).
    local function pairOf(key)
        local s = Slots.BY_KEY[key]
        local first
        for _, ev in ipairs(list(key)) do
            if free(ev) then first = ev break end
        end
        if not first then return {}, 0 end
        local other = first.slot == key and s.pair or key
        local e = eq(other)
        local second, gain2
        for _, ev in ipairs(list(key)) do
            if ev ~= first and free(ev) and ev.rec.id ~= e.id and (not questOf(ev) or questOf(ev) ~= questOf(first)) then
                local g = (ev.points or 0) - e.points + Score.HitPastCap(hitOf(ev.rec) + hitOf(first.rec),
                    hitOf(e.rec) + hitOf(eq(first.slot).rec)) - Score.HitPastCap(hitOf(first.rec), hitOf(eq(first.slot).rec))
                if not second or g > gain2 then second, gain2 = ev, g end
            end
        end
        local out = { first }
        if second and bigEnough(gain2, e.rec and e.points or nil) then
            out[2] = planned(second, other, gain2, e.rec and e.points or nil)
            return out, first.delta + gain2
        end
        return out, first.delta
    end

    -- Each slot's best (a pair of hands, two rings, two trinkets as one).
    local groups = {}
    for _, key in ipairs(Slots.ORDER) do
        if key == "MainHandSlot" then
            groups[#groups + 1] = { key = key, fn = hands }
        elseif key ~= "SecondaryHandSlot" and (Slots.GROUP[key] or key) == key then
            local s = Slots.BY_KEY[key]
            groups[#groups + 1] = { key = key, fn = s.pair and function() return pairOf(key) end or function()
                for _, ev in ipairs(list(key)) do
                    if free(ev) then return { ev }, ev.delta end
                end
                return {}, 0
            end }
        end
    end
    -- The biggest gains choose first (for a quest that rewards two slots).
    for _, g in ipairs(groups) do
        local list_, gain = g.fn()
        g.top = #list_ > 0 and gain or nil
    end
    table.sort(groups, function(a, b)
        if (a.top ~= nil) ~= (b.top ~= nil) then return a.top ~= nil end
        if a.top and a.top ~= b.top then return a.top > b.top end
        return a.key < b.key
    end)
    for _, g in ipairs(groups) do
        if g.top then
            -- Asked again: an earlier group may have taken its quest.
            for _, pick in ipairs((g.fn())) do take(pick) end
        end
    end
    -- Grouped by where you go: the zone of the quest giver, vendor or mob.
    local zones, zoneOrder = {}, {}
    for _, ev in ipairs(picks) do
        local src = ev.source or {}
        local zone = src.dungeon or GP.Waypoint.ZoneOf(src) or "Somewhere unknown"
        if src.kind == "bags" then zone = "In your bags" end
        if not zones[zone] then
            zones[zone] = { zone = zone, picks = {}, gain = 0, level = src.level or ev.req or 0 }
            zoneOrder[#zoneOrder + 1] = zones[zone]
        end
        local z = zones[zone]
        table.insert(z.picks, ev)
        z.gain = z.gain + ev.delta
    end
    table.sort(zoneOrder, function(a, b)
        if (a.zone == "In your bags") ~= (b.zone == "In your bags") then return a.zone == "In your bags" end
        if #a.picks ~= #b.picks then return #a.picks > #b.picks end
        return a.gain > b.gain
    end)
    return { picks = picks, zones = zoneOrder }
end

-- An evaluation of one item for tooltips: tier, slot, gain.
function Score.ForItem(id)
    local byID = Score.results.byID
    return byID and byID[id] or nil
end

-- Rescoring is cheap; it waits a frame so a burst of changes runs it once.
function Score.Request()
    GP.Soon("rescore", Score.Run)
end

GP.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() Score.Request() end)
GP.On("WeightsChanged", Score.Request)
GP.On("SettingChanged", function(key)
    if key == "ahead" or key == "soon" or key == "dungeons" or key == "worldDrops" or key == "healerGear" then
        Score.Request()
    end
end)

-- A new zone changes what's nearest, a new continent what's listed: the
-- ways to get each item are re-ordered and everything scored again (no
-- new scan).
local lastZone
local function continentCheck()
    local S = GP.Sources
    if not (S and S.PlayerZone and S.Resort and S.status == "ready") then return end
    local zone, cont = S.PlayerZone(), S.PlayerContinent()
    if zone == lastZone and cont == Score.here then return end
    lastZone = zone
    S.Resort()
    Score.Run()
end
for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
    GP.RegisterEvent(e, function()
        if C_Timer and C_Timer.After then C_Timer.After(2, function() GP.SafeCall(continentCheck) end) end
    end)
end
