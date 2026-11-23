-- Plan: the Route tab. The best upgrade you can get now for each slot (one
-- reward per quest: you only get to pick one), grouped by where you go,
-- the zone with the most upgrades first; then what's worth chasing, by
-- dungeon or zone. A click on a place or an item puts the map pin there.

local _, GP = ...

local UI, Slots = GP.UI, GP.Slots
local L = GP.L

local Plan = {}
UI.Plan = Plan

local PLURALS = { upgrade = { "%d upgrade", "%d upgrades" }, place = { "%d place", "%d places" } }
local function plural(n, word) return GP.Count(n, PLURALS[word][1], PLURALS[word][2]) end

-- How much the picks add to your whole GearPath score, in percent.
local function scoreGain(list)
    local now, gain = 0, 0
    for _, e in pairs(GP.Score.equipped) do now = now + (e.points or 0) end
    for _, ev in ipairs(list) do gain = gain + math.max(0, ev.delta or 0) end
    if now <= 0 then return nil end
    return gain / now * 100
end

-- What a group is: its name, tone (List.TONES), icon and level text.
local function groupInfo(src, fallbackName)
    src = src or {}
    if src.kind == "bags" then return L["In your bags"], "bags" end
    if src.kind == "craft" and src.known then return L["Craft it yourself"], "zone" end
    if src.worldDrop then return src.randomChest and L["Random chest loot"] or L["Random world drops"], "random" end
    if src.dungeon then
        local d = GP.Journal and GP.Journal.Dungeon(src.dungeon)
        local range = d and d.lo and (d.lo == d.hi and string.format(L["level %d"], d.lo) or string.format(L["levels %d-%d"], d.lo, d.hi))
        return src.dungeon, "dungeon", d and d.icon, range
    end
    local zone = fallbackName or GP.Waypoint.ZoneOf(src)
    if zone and zone ~= "Somewhere unknown" then return zone, "zone" end
    return L["Somewhere unknown"], "unknown"
end

local function groupRight(list, level, range)
    local parts = { plural(#list, "upgrade") }
    if range then parts[#parts + 1] = range
    elseif level and level > 0 then parts[#parts + 1] = string.format(L["level %d"], level) end
    return table.concat(parts, ", ")
end

-- The first pick in a group that has a place to put a pin on.
local function pinSource(list)
    for _, ev in ipairs(list) do
        if ev.source and GP.Waypoint.CanSet(ev.source) then return ev.source end
    end
end

-- What's worth chasing (or needs something first): the best of each slot
-- in the chosen content, grouped by dungeon or zone.
Plan.MORE = 2          -- options shown under a Worth chasing pick
Plan.open = {}         -- [slot group] = true while its options are shown

local function chaseGroups(res, tier, keep)
    keep = keep or UI.ContentMatches
    local best = {}
    Plan.alts = Plan.alts or {}
    for _, key in ipairs(Slots.ORDER) do
        local group = Slots.GROUP[key] or key
        local bucket = group == key and res.bySlot[key]
        if bucket then
            -- The pick, and (Worth chasing) the next ones for the slot, shown
            -- under it on request.
            local pick, more = nil, {}
            for _, ev in ipairs(bucket[tier] or {}) do
                if keep(ev) then
                    if not pick then pick = ev
                    elseif ev.rec.id ~= pick.rec.id then more[#more + 1] = ev end
                    if #more >= Plan.MORE then break end
                end
            end
            if pick then
                best[#best + 1] = pick
                if tier == "secondary" then Plan.alts[pick] = more end
            end
        end
    end
    local groups, order = {}, {}
    for _, ev in ipairs(best) do
        local src = ev.source or {}
        local name, tone, icon, range = groupInfo(src)
        if not groups[name] then
            groups[name] = { name = name, picks = {}, level = src.level or 0, tone = tone, icon = icon, range = range }
            order[#order + 1] = groups[name]
        end
        table.insert(groups[name].picks, ev)
    end
    table.sort(order, function(a, b)
        if #a.picks ~= #b.picks then return #a.picks > #b.picks end
        return (a.level or 0) < (b.level or 0)
    end)
    return order
end

-- The Route's numbers, for the addon list button: upgrades to get now, the
-- places they're in, how many are worth chasing, the score gain, and the
-- picks themselves (biggest gain first). Follows the Show filter, as the
-- Route does.
function Plan.Summary()
    local res = GP.Score.results
    local plan = res.plan or { picks = {}, zones = {} }
    if UI.ContentFiltered() then plan = GP.Score.BuildPlan(res, UI.ContentMatches) end
    local chase = 0
    for _, g in ipairs(chaseGroups(res, "secondary")) do chase = chase + #g.picks end
    local picks = {}
    for i, ev in ipairs(plan.picks) do picks[i] = ev end
    table.sort(picks, function(a, b) return (a.delta or 0) > (b.delta or 0) end)
    return #plan.picks, #plan.zones, chase, scoreGain(plan.picks), picks
end

-- One group: room above it (but not under a section title), its band,
-- then its items, indented with a guide line in the group's color.
-- The Route grouped by slot instead of by place (Koulta, Nov 13: "Route
-- to remain as it is but just add the ability to sort by chest, helm,
-- weapon"): the same picks, a group per slot in the paper doll's order,
-- each item showing where it's from. Off by default.
Plan.GROUP_KEYS = { "place", "slot" }
function Plan.BySlot() return GP.Setting("routeGroup") == "slot" end

-- Zone (0.8.14, r173ym0n28711 on CurseForge: "an option for current zone
-- select which zone"; it was a This zone only tick): the Route keeps what
-- you can get in one zone (its dungeons too, by their entrance) and gear
-- already in your bags. routeZone: nil (all), "here" (the zone you're in,
-- following you) or a zone's map id. The old tick (routeHere) means "here".
function Plan.ZoneSetting()
    local z = GP.Setting("routeZone")
    if z == "here" or type(z) == "number" then return z end
    if GP.Setting("routeHere") == true then return "here" end
    return nil
end

-- The zone the Route is narrowed to now (a map id), or nil for all.
function Plan.ZoneFilter()
    local z = Plan.ZoneSetting()
    if z == "here" then
        local S = GP.Sources
        return S.PlayerZone and S.PlayerZone() or nil, true
    end
    return z, false
end
function Plan.HereOnly() return Plan.ZoneSetting() ~= nil end

-- The zone an item comes from (a map id), "bags", or nil.
function Plan.ZoneOf(ev)
    local src = ev and ev.source
    if not src then return nil end
    if src.kind == "bags" then return "bags" end
    local S = GP.Sources
    if src.dungeon then
        local e = GP.Waypoint.Entrance(src.dungeon)
        return e and S.Zone(e.mapID) or nil
    end
    local p = GP.Waypoint.PlaceOf(src)
    return p and S.Zone(p.mapID) or nil
end

function Plan.InZone(ev, zone)
    local src = ev and ev.source
    if not src then return false end
    if src.kind == "bags" then return true end
    -- Inside a dungeon, its own gear counts as here.
    if src.dungeon and zone == (GP.Sources.PlayerZone and GP.Sources.PlayerZone()) and IsInInstance and IsInInstance()
        and GetInstanceInfo then
        local name = GP.Plain(GetInstanceInfo())
        if type(name) == "string" and (src.dungeon == name or src.dungeon:match("^(.-)%s*:") == name) then return true end
    end
    return zone ~= nil and Plan.ZoneOf(ev) == zone
end

function Plan.Here(ev)
    if ev and ev.source and ev.source.kind == "bags" then return true end
    local S = GP.Sources
    local here = S.PlayerZone and S.PlayerZone()
    if ev and ev.source and ev.source.dungeon and IsInInstance and IsInInstance() then
        return Plan.InZone(ev, here)
    end
    return here ~= nil and Plan.InZone(ev, here)
end

-- The zones with something on the Route, for the Zone menu, by name.
function Plan.ZoneName(id)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    return info and GP.Plain(info.name) or (GP.Sources.MapName and GP.Sources.MapName(id)) or tostring(id)
end
function Plan.ZoneKeys()
    local seen, ids = {}, {}
    for _, ev in ipairs(GP.Score.results.all or {}) do
        if (ev.delta or 0) > 0 and UI.ContentMatches(ev) then
            local z = Plan.ZoneOf(ev)
            if type(z) == "number" and not seen[z] then seen[z] = true; ids[#ids + 1] = z end
        end
    end
    local cur = Plan.ZoneSetting()
    if type(cur) == "number" and not seen[cur] then ids[#ids + 1] = cur end
    table.sort(ids, function(a, b) return Plan.ZoneName(a) < Plan.ZoneName(b) end)
    local keys = { "all", "here" }
    for _, id in ipairs(ids) do keys[#keys + 1] = id end
    return keys
end

-- What the Route lists: the Show filter, and the Zone pick.
local function routeKeeps(ev)
    if not UI.ContentMatches(ev) then return false end
    if not Plan.HereOnly() then return true end
    local zone, here = Plan.ZoneFilter()
    if here then return Plan.Here(ev) end
    return Plan.InZone(ev, zone)
end
Plan.Keeps = routeKeeps

local function slotGroups(picks)
    local groups, byKey = {}, {}
    for _, ev in ipairs(picks) do
        local key = Slots.GROUP[ev.slot] or ev.slot or "?"
        local g = byKey[key]
        if not g then
            g = { key = key, name = Slots.Label(key) or key, picks = {}, tone = "zone" }
            byKey[key] = g
            groups[#groups + 1] = g
        end
        g.picks[#g.picks + 1] = ev
    end
    local rank = {}
    for i, k in ipairs(Slots.ORDER) do rank[Slots.GROUP[k] or k] = rank[Slots.GROUP[k] or k] or i end
    table.sort(groups, function(a, b) return (rank[a.key] or 99) < (rank[b.key] or 99) end)
    for _, g in ipairs(groups) do
        table.sort(g.picks, function(a, b) return (a.delta or 0) > (b.delta or 0) end)
    end
    return groups
end
Plan.SlotGroups = slotGroups

local function addGroup(items, g, first)
    if not first then items[#items + 1] = { kind = "gap" } end
    -- A dungeon's bar pins its entrance; a zone's, its first place to go.
    local pin = g.tone == "dungeon" and GP.Waypoint.Entrance(g.name) or pinSource(g.picks)
    items[#items + 1] = { kind = "header", text = g.name, right = groupRight(g.picks, g.level, g.range),
        source = pin, tone = g.tone, icon = g.icon }
    for _, ev in ipairs(g.picks) do
        -- By place, each line names its slot; by slot, the group already does.
        items[#items + 1] = { kind = "item", ev = ev, key = ev.rec.id, prefix = not g.bySlot and Slots.Label(ev.slot) or nil,
            indent = 14, tone = g.tone }
        -- The slot's next-best items, only when grouped by slot: by place
        -- they'd sit under a dungeon they don't come from (Koulta, Nov 16).
        local more = g.bySlot and Plan.alts and Plan.alts[ev]
        if more and #more > 0 then
            local slotKey = Slots.GROUP[ev.slot] or ev.slot or "?"
            local open = Plan.open[slotKey] == true
            items[#items + 1] = { kind = "more", indent = 14, open = open,
                text = #more == 1 and L["1 more option"] or string.format(L["%d more options"], #more),
                onToggle = function()
                    Plan.open[slotKey] = not open or nil
                    local def = UI.PAGES.plan
                    if def and def.frame then GP.SafeCall(def.Fill, def.frame) end
                end }
            if open then
                for _, alt in ipairs(more) do
                    items[#items + 1] = { kind = "alt", ev = alt, key = "alt:" .. alt.rec.id, indent = 14 }
                end
            end
        end
    end
end

-- A section's groups, by place (as built) or by slot.
local function addGroups(items, list)
    if Plan.BySlot() then
        local picks = {}
        for _, g in ipairs(list) do
            for _, ev in ipairs(g.picks) do picks[#picks + 1] = ev end
        end
        for i, g in ipairs(slotGroups(picks)) do
            addGroup(items, { name = g.name, picks = g.picks, tone = g.tone, bySlot = true }, i == 1)
        end
        return
    end
    for i, g in ipairs(list) do addGroup(items, g, i == 1) end
end

-- A new zone: the Route follows you while Zone is This zone.
GP.RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
    if Plan.ZoneSetting() ~= "here" then return end
    C_Timer.After(1, function()
        local def = UI.PAGES.plan
        if def and def.frame and def.frame:IsShown() then GP.SafeCall(def.Fill, def.frame) end
    end)
end)

UI.RegisterPage("plan", {
    text = "Route",
    order = 2,
    Build = function(page)
        local skin = GP.Skin.current
        Plan.title = skin.Text(page, "head", "TITLE")
        Plan.title:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -4)
        Plan.title:SetText(L["Your gear route"])
        Plan.content = UI.ContentDropdown(page, 220)
        Plan.content:SetPoint("TOPRIGHT", page, "TOPRIGHT", -2, -2)
        Plan.group = GP.Dropdown(page, { width = 150, keys = Plan.GROUP_KEYS,
            labels = { place = L["place"], slot = L["slot"] }, prefix = L["Group by:"] .. " ",
            get = function() return Plan.BySlot() and "slot" or "place" end,
            set = function(k)
                GP.SetSetting("routeGroup", k ~= "place" and k or nil)
                local def = UI.PAGES.plan
                if def and def.frame and def.frame:IsShown() then GP.SafeCall(def.Fill, def.frame) end
            end })
        -- Zone, between the two: "Group by: [place]  Zone: [All zones]".
        local zoneLabels = setmetatable({}, { __index = function(_, k)
            if k == "all" then return L["All zones"] end
            if k == "here" then
                local here = GP.Sources.PlayerZone and GP.Sources.PlayerZone()
                return string.format(L["This zone (%s)"], here and Plan.ZoneName(here) or "?")
            end
            return Plan.ZoneName(k)
        end })
        Plan.zone = GP.Dropdown(page, { width = 190, keys = Plan.ZoneKeys, labels = zoneLabels,
            prefix = L["Zone:"] .. " ",
            get = function() return Plan.ZoneSetting() or "all" end,
            set = function(k)
                GP.SetSetting("routeHere", nil)
                GP.SetSetting("routeZone", k ~= "all" and k or nil)
                local def = UI.PAGES.plan
                if def and def.frame and def.frame:IsShown() then GP.SafeCall(def.Fill, def.frame) end
            end })
        Plan.zone:SetPoint("RIGHT", Plan.content, "LEFT", -10, 0)
        Plan.group:SetPoint("RIGHT", Plan.zone, "LEFT", -10, 0)
        Plan.sub = skin.Text(page, "small", "LABEL")
        Plan.sub:SetPoint("TOPLEFT", Plan.title, "BOTTOMLEFT", 0, -5)
        Plan.sub:SetPoint("RIGHT", page, "RIGHT", -6, 0)
        Plan.sub:SetWordWrap(false)
        -- No pin buttons: a click on an item or a group's bar is the pin.
        Plan.list = GP.List.New(page, { empty = L["Nothing to show yet."], pins = false })
        Plan.list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -46)
        Plan.list:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    end,
    Fill = function()
        local res = GP.Score.results
        local hereOnly = Plan.HereOnly()
        local filtered = UI.ContentFiltered() or hereOnly
        Plan.content.Refresh()
        if Plan.zone then Plan.zone.Refresh() end
        local plan = res.plan or { picks = {}, zones = {} }
        if filtered then plan = GP.Score.BuildPlan(res, routeKeeps) end
        local items = {}
        local S = GP.Sources
        if S.status == "scanning" or S.status == "loading" or S.status == "idle" then
            items[#items + 1] = { kind = "note", text = L["Still reading the gear database; the route fills in as items load."] }
        end

        local pct = scoreGain(plan.picks)
        Plan.sub:SetText(#plan.picks > 0
            and string.format(L["%s in %s%s. Click a place or an item for its map pin."],
                plural(#plan.picks, "upgrade"), plural(#plan.zones, "place"),
                pct and (", " .. string.format(L["about +%d%% to your GearPath score"], GP.Round(pct))) or "")
            or L["The best upgrade for each slot you can get now, grouped by where you go."])

        items[#items + 1] = { kind = "section", text = L["Best now"], role = "GOOD",
            right = #plan.picks > 0 and plural(#plan.picks, "upgrade") or nil }
        -- Skills to learn first for these picks: who teaches each (a click pins them).
        if GP.Training then
            for _, t in ipairs(GP.Training.ForPicks(plan.picks)) do
                local n = t.need
                local m = n.masters and n.masters[1]
                local text = m and string.format(L["Learn %s: %s, %s (%s)"], n.name, m.name, m.city, GP.Money(n.cost))
                    or string.format(L["Learn %s at your class trainer"], n.name)
                items[#items + 1] = { kind = "header", tone = "bags", icon = "Interface\\Icons\\INV_Sword_04", text = text,
                    right = GP.Count(#t.picks, "for %d upgrade", "for %d upgrades"),
                    source = m and GP.Training.Place(m, n.spell) or nil }
            end
        end
        if #plan.zones == 0 then
            local zid = Plan.ZoneFilter()
            items[#items + 1] = { kind = "note", text = hereOnly
                and string.format(L["Nothing to get in %s right now. Set Zone to All zones to see everywhere."],
                    zid and Plan.ZoneName(zid) or "?")
                or not filtered
                and L["No upgrades to get at your level right now. Check Worth chasing below, or come back after a level or two."]
                or L["Nothing to get at your level right now from what's ticked under Show."] }
        end
        local now = {}
        for _, z in ipairs(plan.zones) do
            local first = z.picks[1] and z.picks[1].source
            local name, tone, icon, range = groupInfo(first, z.zone)
            now[#now + 1] = { name = name, picks = z.picks, level = z.level, tone = tone, icon = icon, range = range }
        end
        addGroups(items, now)

        Plan.alts = {}
        local function groups(tier, title, role, empty, always)
            local list = chaseGroups(res, tier, routeKeeps)
            local n = 0
            for _, g in ipairs(list) do n = n + #g.picks end
            if n == 0 and not always then return end
            items[#items + 1] = { kind = "gap", height = 16 }
            items[#items + 1] = { kind = "section", text = title, role = role,
                right = n > 0 and plural(n, "upgrade") or nil }
            if n == 0 then items[#items + 1] = { kind = "note", text = empty } end
            addGroups(items, list)
        end
        groups("secondary", L["Worth chasing"], "WARN", hereOnly and L["Nothing worth chasing in this zone."]
            or L["Nothing worth chasing found yet."], true)
        groups("locked", UI.TIER_TEXT.locked, "OFF", "", false)
        local key = UI.ContentKey() .. (Plan.BySlot() and ":slot" or "") .. (hereOnly and (":zone" .. tostring((Plan.ZoneFilter()))) or "")
        Plan.list:SetItems(items, Plan.viewKey == key)
        Plan.viewKey = key
    end,
})
