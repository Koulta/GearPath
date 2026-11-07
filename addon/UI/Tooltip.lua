-- Tooltip: GearPath's lines on tooltips.
--   Items everywhere (bags, chat links, quest rewards, loot, vendors): Best
--   now / Worth chasing, how much better than what you wear, and where to
--   get it; on a wand, its damage against yours.
--   NPCs and mobs: the upgrades they drop, sell or give for a quest.
-- Anything secret (a unit in combat, say) is skipped.

local _, GP = ...

local Tooltip = {}
GP.Tooltip = Tooltip

local GOOD, WARN, BAD, DIM = { 0.25, 1, 0.25 }, { 1, 0.65, 0.1 }, { 1, 0.31, 0.31 }, { 0.6, 0.6, 0.6 }

Tooltip.MORE = 2      -- other ways to get an item listed under the first

-- A wand's damage per second against the one you wear (for classes that
-- use wands): "Wand: 17.5 damage per second || +7.1 over yours".
function Tooltip.WandLine(rec)
    local C = GP.Classes
    if not (rec and rec.classID == C.WEAPON and rec.subClassID == C.W.WAND) then return nil end
    if not C.Data().weapons[C.W.WAND] then return nil end
    local dps = rec.stats and rec.stats.dps
    if type(dps) ~= "number" or dps <= 0 then return nil end
    local left = string.format("Wand: %.1f damage per second", dps)
    local worn = GP.Score.equipped.RangedSlot
    local mine = worn and worn.rec
    if mine and mine.id == rec.id then return left, "the wand you wear", DIM end
    local myDps = mine and mine.subClassID == C.W.WAND and mine.stats and mine.stats.dps
    if type(myDps) ~= "number" then return left, "you wear no wand", GOOD end
    local d = dps - myDps
    if math.abs(d) < 0.05 then return left, "same as yours", DIM end
    return left, string.format("%+.1f %s yours", d, d > 0 and "over" or "under"), d > 0 and GOOD or BAD
end

-- An item GearPath hasn't scored (an auction, a recipe at a trainer
-- before its list is read, a link in chat): weighed on the spot, if you
-- could wear it. Where it comes from isn't known, so it's never Best now.
function Tooltip.QuickEval(rec)
    if not (rec and rec.equipLoc and rec.classID) then return nil end
    if rec.classes and not rec.classes[UnitClass("player")] then return nil end
    if not GP.Classes.CanUse(rec.classID, rec.subClassID, rec.equipLoc) then return nil end
    local slot, delta, pct, base = GP.Score.Upgrade(rec)
    if not slot then return nil end
    return { rec = rec, slot = slot, delta = delta, pct = pct, base = base, quick = true, req = rec.reqLevel }
end

-- Better, but not on your lists: why, in a few words.
local function offList(ev)
    local src = ev.source
    if ev.quick then
        local level = (GP.player and GP.player.level) or 0
        if (ev.req or 0) > level then return "GearPath: better, from level " .. ev.req end
        return "GearPath: better"
    end
    if src and (src.worldDrop or src.randomChest) then return "GearPath: better, but only from random loot" end
    if src and src.dungeon and GP.Setting("dungeons") == false then
        return "GearPath: better, but dungeons are off in Settings"
    end
    return "GearPath: better, not on your lists"
end

local function line(tt, left, right, lc, rc)
    rc = rc or lc
    tt:AddDoubleLine(left, right, lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
end

function Tooltip.Add(tt, id, link)
    if type(id) ~= "number" then return end
    local ev = GP.Score.ForItem(id)
    local rec = ev and ev.rec or (link and GP.Items.FromLink(link)) or GP.Items.Get(id)
    local wl, wr, wc = Tooltip.WandLine(rec)
    if not ev then
        -- The one you have on: said, so a silent tooltip never looks like
        -- GearPath missed it (Koulta's own crafted cape and bracers, Nov 6).
        local worn
        for key, e in pairs(GP.Score.equipped or {}) do
            if e.id == id then worn = key break end
        end
        if worn then
            tt:AddLine(" ")
            line(tt, "GearPath: currently equipped", GP.Slots.Label(worn), DIM)
            if wl then line(tt, wl, wr, DIM, wc) end
            return
        end
        ev = Tooltip.QuickEval(rec)
        if not ev then
            if wl then tt:AddLine(" "); line(tt, wl, wr, DIM, wc) end
            return
        end
    end
    local slot = GP.Slots.Label(ev.slot)
    local gain = GP.UI.GainText(ev)
    if gain == "new" then gain, slot = "", slot .. " (empty now)" end
    local right = (gain ~= "" and (gain .. " ") or "") .. slot
    local better = ev.delta and ev.delta > 0 and GP.Score.BigEnough(ev.delta, ev.base)
    tt:AddLine(" ")
    if ev.needs then
        line(tt, "GearPath: needs " .. ev.needs, right, BAD, DIM)
    elseif ev.healerPass then
        -- Seen in a loot roll too: say what to do before anyone asks.
        local what = GP.Score.GroupLoot(ev.source) and "GearPath: healer gear, let your healer roll first"
            or "GearPath: healer gear, not listed for you"
        line(tt, what, right, WARN, DIM)
    elseif ev.elsewhere then
        line(tt, "GearPath: better, but on another continent", right, DIM)
    elseif ev.tier then
        local c = ev.tier == "primary" and GOOD or WARN
        line(tt, "GearPath: " .. GP.UI.TIER_TEXT[ev.tier], right, c)
    elseif better then
        -- Never "not an upgrade +40%": a real gain says why it isn't listed.
        line(tt, offList(ev), right, ev.quick and WARN or DIM)
    elseif ev.delta and ev.delta > 0 then
        -- A sliver better (9 armor over 9 armor is +100% of almost
        -- nothing): no number that says otherwise.
        line(tt, "GearPath: barely better", slot, DIM)
    else
        -- Worse shows by how much; no better and no worse ("+0 pts")
        -- shows nothing.
        line(tt, "GearPath: not an upgrade", (ev.delta or 0) < 0 and right or slot, DIM)
    end
    if wl then tt:AddDoubleLine(wl, wr, DIM[1], DIM[2], DIM[3], wc[1], wc[2], wc[3]) end
    -- A skill still to learn first, and who teaches it.
    for _, n in ipairs(ev.train or {}) do
        tt:AddLine(GP.Training.Long(n), BAD[1], BAD[2], BAD[3], true)
    end
    if ev.source then
        tt:AddLine(GP.UI.Describe(ev.source, true), 0.85, 0.85, 0.85, true)
        -- The way in to a dungeon, in the Dungeon Journal's words.
        local place = GP.Waypoint.PlaceOf(ev.source)
        if place and place.detail then tt:AddLine(place.detail, DIM[1], DIM[2], DIM[3], true) end
        -- The next easiest ways too, so a doubtful first answer can be checked.
        local all = ev.entry and ev.entry.sources or {}
        local said, others = { [GP.UI.Describe(ev.source)] = true }, {}
        for i = 2, #all do
            local d = GP.UI.Describe(all[i])
            if not said[d] then said[d] = true; others[#others + 1] = d end
        end
        local shown = 0
        for _, d in ipairs(others) do
            if shown >= Tooltip.MORE then break end
            tt:AddLine("or " .. d, DIM[1], DIM[2], DIM[3], true)
            shown = shown + 1
        end
        local rest = #others - shown
        if rest > 0 then
            tt:AddLine(string.format("and %d more way%s to get it", rest, rest == 1 and "" or "s"), DIM[1], DIM[2], DIM[3])
        end
    end
    -- What the checker found.
    local r = GP.Check and GP.Check.ResultFor(id)
    if r then
        if r.confirmed then tt:AddLine(GP.Check.ICON_OK .. " Seen in game: confirmed", GOOD[1], GOOD[2], GOOD[3], true) end
        if (r.reported or 0) > 0 then
            tt:AddLine(string.format("%s Seen by %d other GearPath player%s", GP.Check.ICON_OK, r.reported,
                r.reported == 1 and "" or "s"), GOOD[1], GOOD[2], GOOD[3], true)
        end
        -- (A missing place or quest giver is already in the source line.)
        local said = ev.source and { noGiver = true, noLocation = true } or {}
        for _, wn in ipairs(r.warnings) do
            if not said[wn.key] then
                tt:AddLine(GP.Check.ICON_WARN .. " " .. wn.text, WARN[1], WARN[2], WARN[3], true)
            end
        end
    end
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
