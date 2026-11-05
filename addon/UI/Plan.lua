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
local function chaseGroups(res, tier)
    local best = {}
    for _, key in ipairs(Slots.ORDER) do
        local group = Slots.GROUP[key] or key
        local bucket = group == key and res.bySlot[key]
        if bucket then
            for _, ev in ipairs(bucket[tier] or {}) do
                if UI.ContentMatches(ev) then best[#best + 1] = ev break end
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
local function addGroup(items, g, first)
    if not first then items[#items + 1] = { kind = "gap" } end
    -- A dungeon's bar pins its entrance; a zone's, its first place to go.
    local pin = g.tone == "dungeon" and GP.Waypoint.Entrance(g.name) or pinSource(g.picks)
    items[#items + 1] = { kind = "header", text = g.name, right = groupRight(g.picks, g.level, g.range),
        source = pin, tone = g.tone, icon = g.icon }
    for _, ev in ipairs(g.picks) do
        items[#items + 1] = { kind = "item", ev = ev, key = ev.rec.id, prefix = Slots.Label(ev.slot),
            indent = 14, tone = g.tone }
    end
end

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
        local filtered = UI.ContentFiltered()
        Plan.content.Refresh()
        local plan = res.plan or { picks = {}, zones = {} }
        if filtered then plan = GP.Score.BuildPlan(res, UI.ContentMatches) end
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
            items[#items + 1] = { kind = "note", text = not filtered
                and L["No upgrades to get at your level right now. Check Worth chasing below, or come back after a level or two."]
                or L["Nothing to get at your level right now from what's ticked under Show."] }
        end
        for i, z in ipairs(plan.zones) do
            local first = z.picks[1] and z.picks[1].source
            local name, tone, icon, range = groupInfo(first, z.zone)
            addGroup(items, { name = name, picks = z.picks, level = z.level, tone = tone, icon = icon, range = range }, i == 1)
        end

        local function groups(tier, title, role, empty, always)
            local list = chaseGroups(res, tier)
            local n = 0
            for _, g in ipairs(list) do n = n + #g.picks end
            if n == 0 and not always then return end
            items[#items + 1] = { kind = "gap", height = 16 }
            items[#items + 1] = { kind = "section", text = title, role = role,
                right = n > 0 and plural(n, "upgrade") or nil }
            if n == 0 then items[#items + 1] = { kind = "note", text = empty } end
            for i, g in ipairs(list) do addGroup(items, g, i == 1) end
        end
        groups("secondary", L["Worth chasing"], "WARN", L["Nothing worth chasing found yet."], true)
        groups("locked", UI.TIER_TEXT.locked, "OFF", "", false)
        local key = UI.ContentKey()
        Plan.list:SetItems(items, Plan.viewKey == key)
        Plan.viewKey = key
    end,
})
