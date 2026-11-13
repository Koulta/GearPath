-- Tooltip: GearPath's lines on tooltips.
--   Items everywhere (bags, chat links, quest rewards, loot, vendors): how
--   much better or worse than what you have on, by your class and spec's
--   weights, and where to get it:
--       GearPath (Affliction)                            +12%
--       Vendor: Harold Raims, Tirisfal Glades (32.4, 66.4)
--   The % is GearPath's score (each stat times what your spec values it at)
--   against the item you wear there. Its colour is the verdict: green Best
--   now, gold Worth chasing, red needs something first, white better but not
--   on your lists, grey not an upgrade. (Settled with Koulta Nov 7 from a
--   mockup, after a 0-100 rating that didn't explain itself: "location,
--   % +/- better than equipped". Don't change it without a mockup he okays.)
--   NPCs and mobs: the upgrades they drop, sell or give for a quest.
-- Anything secret (a unit in combat, say) is skipped.

local _, GP = ...
local L = GP.L

local Tooltip = {}
GP.Tooltip = Tooltip

local GOOD, WARN, BAD, DIM = { 0.25, 1, 0.25 }, { 1, 0.65, 0.1 }, { 1, 0.31, 0.31 }, { 0.6, 0.6, 0.6 }
local UP, WHERE = { 1, 1, 1 }, { 0.85, 0.85, 0.85 }

-- An item GearPath hasn't scored (an auction, a recipe at a trainer
-- before its list is read, a link in chat): weighed on the spot, if you
-- could wear it. Where it comes from isn't known, so it's never Best now.
function Tooltip.QuickEval(rec)
    if not (rec and rec.equipLoc and rec.classID) then return nil end
    if rec.classes and not rec.classes[UnitClass("player")] then return nil end
    if not GP.Classes.CanUse(rec.classID, rec.subClassID, rec.equipLoc) then return nil end
    local slot, delta, pct, base, points = GP.Score.Upgrade(rec)
    if not slot then return nil end
    return { rec = rec, slot = slot, delta = delta, pct = pct, base = base, points = points, quick = true, req = rec.reqLevel }
end

-- "GearPath (Affliction)": whose weights the % is by.
local function title()
    if not GP.Classes.Spec().name then return "GearPath" end
    return "GearPath (" .. GP.Classes.SpecName() .. ")"
end

local function line(tt, left, right, lc, rc)
    rc = rc or lc
    tt:AddDoubleLine(left, right, lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
end

-- The verdict, as a colour: whether the item is better than what you have
-- on, and (for one that is) whether it's on your lists.
function Tooltip.Color(ev)
    local better = ev.delta and ev.delta > 0 and GP.Score.BigEnough(ev.delta, ev.base)
    if not better then return DIM, false end
    if ev.needs then return BAD, true end
    if ev.tier == "primary" and not ev.healerPass then return GOOD, true end
    if ev.tier == "secondary" and not ev.healerPass then return WARN, true end
    return UP, true
end

-- Against what you have on: "+12%", "-8%", "empty slot". A difference too
-- small to matter is "same": 9 more armor on a caster is +100% of almost
-- nothing (Heavy Weave Gloves over Netted Gloves, Nov 6).
function Tooltip.Compare(ev)
    if not GP.Score.Worn(ev.slot) then return "empty slot" end
    if math.abs(ev.delta or 0) < GP.Score.MIN_POINTS then return "same" end
    local gain = GP.UI.GainText(ev)
    if gain == "new" then return "empty slot" end
    return gain
end

function Tooltip.Add(tt, id, link)
    if type(id) ~= "number" then return end
    -- The one you have on: its rating, so a tooltip never looks like
    -- GearPath missed it (Koulta's own crafted cape and bracers, Nov 6).
    -- Checked first: just after you put something on, the last scoring
    -- still has it as a candidate.
    for key, e in pairs(GP.Score.equipped or {}) do
        if e.id == id and e.rec then
            tt:AddLine(" ")
            line(tt, title(), "equipped", DIM)
            return
        end
    end
    local ev = GP.Score.ForItem(id)
    local rec = ev and ev.rec or (link and GP.Items.FromLink(link)) or GP.Items.Get(id)
    if not ev then
        ev = Tooltip.QuickEval(rec)
        if not ev then
            -- Gear you'll never wear, in your bags: safe to sell.
            local l = link or (rec and rec.link)
            if GP.Sell and GP.Sell.inBags[id] and GP.Sell.Safe(l) then
                tt:AddLine(" ")
                GP.Sell.TooltipLine(tt, id, l)
            end
            return
        end
    end
    local color, better = Tooltip.Color(ev)
    tt:AddLine(" ")
    line(tt, title(), Tooltip.Compare(ev), color)
    -- Better, but not yet yours: what it takes first.
    if better and ev.needs then tt:AddLine("Needs " .. ev.needs, BAD[1], BAD[2], BAD[3], true) end
    if better then
        for _, n in ipairs(ev.train or {}) do
            tt:AddLine(GP.Training.Long(n), BAD[1], BAD[2], BAD[3], true)
        end
    end
    -- Where to get it (the window lists every way). In your bags already:
    -- "put it on" only when it's better.
    local src = ev.source
    if src and not (src.kind == "bags" and not better) then
        tt:AddLine(GP.UI.Describe(src, true), WHERE[1], WHERE[2], WHERE[3], true)
    end
    -- In your bags and no use to any of your specs: safe to sell.
    if not better and GP.Sell then GP.Sell.TooltipLine(tt, id, link or (rec and rec.link)) end
    -- Over a row of GearPath's window: what the clicks do.
    if GP.UI and GP.UI.hintFor == id then
        tt:AddLine(GP.UI.ClickHint(ev), DIM[1], DIM[2], DIM[3], true)
    end
end

-- ---------------------------------------------------------------------
-- NPCs and mobs
-- ---------------------------------------------------------------------

-- [npcID] (or [lowercased name], for the Dungeon Journal's bosses and quest
-- givers known only by name) = { { what, ev, quest }, ... }, rebuilt after
-- every rescore.
local byNpc, byName

local function lower(s) return type(s) == "string" and s:lower() or nil end

local function buildIndex()
    byNpc, byName = {}, {}
    local function add(npc, name, what, ev, quest)
        local list
        if type(npc) == "number" then
            byNpc[npc] = byNpc[npc] or {}
            list = byNpc[npc]
        elseif lower(name) then
            byName[lower(name)] = byName[lower(name)] or {}
            list = byName[lower(name)]
        else
            return
        end
        for _, e in ipairs(list) do
            if e.ev == ev or (e.what == what and e.ev.rec.name == ev.rec.name) then return end
        end
        list[#list + 1] = { what = what, ev = ev, quest = quest }
    end
    for _, ev in ipairs(GP.Score.results.all or {}) do
        if ev.tier == "primary" or ev.tier == "secondary" then
            for _, s in ipairs(ev.entry and ev.entry.sources or {}) do
                if s.worldDrop or s.kind == "bags" then
                    -- dropped by many mobs, or already yours: not one NPC's
                elseif s.kind == "drop" then
                    add(s.id, s.bossName or s.name, "drops", ev)
                elseif s.kind == "vendor" then
                    add(s.id, s.name, "sells", ev)
                elseif s.kind == "quest" then
                    add(s.giverID, s.giver, "quest", ev, s.name)
                    local first = s.chainStart
                    if first and (first.giverID or first.giver) then
                        add(first.giverID, first.giver, "chain", ev, first.name)
                    end
                end
            end
        end
    end
end

GP.On("ScoresChanged", function() byNpc, byName = nil, nil end)

local WHAT = {
    drops = "drops %s",
    sells = "sells %s",
    quest = "quest reward %s",
    chain = "starts the quests to %s",
}

Tooltip.UNIT_MAX = 3      -- upgrades listed on an NPC; the rest are counted

-- The upgrades an NPC or mob has for you: { { what, ev, quest }, ... },
-- Best now first, then by gain.
function Tooltip.ForNpc(npc, name)
    if not byNpc then buildIndex() end
    local list = (npc and byNpc[npc]) or (lower(name) and byName[lower(name)]) or nil
    if not list then return nil end
    table.sort(list, function(a, b)
        if (a.ev.tier == "primary") ~= (b.ev.tier == "primary") then return a.ev.tier == "primary" end
        return (a.ev.delta or 0) > (b.ev.delta or 0)
    end)
    return list
end

function Tooltip.AddUnit(tt, guid, name)
    local npc = GP.NpcID(guid)
    if not npc and not name then return end
    local list = Tooltip.ForNpc(npc, name)
    if not list or #list == 0 then return end
    for i, e in ipairs(list) do
        if i > Tooltip.UNIT_MAX then
            local rest = #list - Tooltip.UNIT_MAX
            tt:AddLine(string.format("GearPath: and %d more upgrade%s", rest, rest == 1 and "" or "s"),
                DIM[1], DIM[2], DIM[3])
            break
        end
        local c = e.ev.tier == "primary" and GOOD or WARN
        local gain = GP.UI.GainText(e.ev)
        local slot = GP.Slots.Label(e.ev.slot)
        if gain == "new" then gain, slot = "", slot .. " (empty now)" end
        tt:AddDoubleLine("GearPath: " .. string.format(WHAT[e.what], e.ev.rec.name or "?"),
            (gain ~= "" and (gain .. " ") or "") .. slot, c[1], c[2], c[3], c[1], c[2], c[3])
    end
end

-- ---------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------

local function itemOf(tt, data)
    local id = data and GP.Plain(data.id)
    local link
    if tt.GetItem then
        local ok, _, l = pcall(tt.GetItem, tt)
        link = ok and GP.Plain(l) or nil
        if type(link) ~= "string" then link = nil end
    end
    if type(id) ~= "number" and link then id = GP.Items.IDFromLink(link) end
    -- Only a link for this very item (it keeps a random suffix's stats).
    if link and GP.Items.IDFromLink(link) ~= id then link = nil end
    return id, link
end

local function on() return GP.Setting("tooltip") or (GP.UI and GP.UI.forceTooltip) end

local function onItem(tt, data)
    if not on() then return end
    if tt.IsForbidden and tt:IsForbidden() then return end
    GP.SafeCall(Tooltip.Add, tt, itemOf(tt, data))
end

local function onUnit(tt, data)
    if not GP.Setting("tooltip") then return end
    if tt.IsForbidden and tt:IsForbidden() then return end
    local guid = data and GP.Plain(data.guid)
    local unit
    if tt.GetUnit then
        local ok, _, u = pcall(tt.GetUnit, tt)
        unit = ok and GP.Plain(u) or nil
    end
    if type(guid) ~= "string" and type(unit) == "string" then guid = GP.Plain(UnitGUID(unit)) end
    if type(guid) ~= "string" then return end
    local name = type(unit) == "string" and GP.Plain(UnitName(unit)) or nil
    GP.SafeCall(Tooltip.AddUnit, tt, guid, type(name) == "string" and name or nil)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItem)
    if Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onUnit)
    end
    Tooltip.hooked = true
elseif GameTooltip and GameTooltip.HookScript then
    local ok = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(tt) onItem(tt) end)
    if ok and ItemRefTooltip then
        pcall(ItemRefTooltip.HookScript, ItemRefTooltip, "OnTooltipSetItem", function(tt) onItem(tt) end)
    end
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) onUnit(tt) end)
    Tooltip.hooked = ok
end

-- A trainer's recipe shows the spell, not the item: GearPath's line for
-- the gear it makes goes under it.
if hooksecurefunc and GameTooltip and GameTooltip.SetTrainerService and GetTrainerServiceItemLink then
    hooksecurefunc(GameTooltip, "SetTrainerService", function(tt, index)
        if not GP.Setting("tooltip") then return end
        if tt.IsForbidden and tt:IsForbidden() then return end
        local link = GP.Plain(GetTrainerServiceItemLink(index))
        if type(link) ~= "string" then return end
        local id = GP.Items.IDFromLink(link)
        if not id then return end
        GP.SafeCall(Tooltip.Add, tt, id, link)
        tt:Show()
    end)
end
