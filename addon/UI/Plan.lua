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
local function chaseGroups(res, tier, keep)
    keep = keep or UI.ContentMatches
    local best = {}
    for _, key in ipairs(Slots.ORDER) do
        local group = Slots.GROUP[key] or key
        local bucket = group == key and res.bySlot[key]
        if bucket then
            for _, ev in ipairs(bucket[tier] or {}) do
                if keep(ev) then best[#best + 1] = ev break end
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

-- "This zone only": the Route keeps what you can get in the zone you're in
-- (its dungeons too, by their entrance) and gear already in your bags.
function Plan.HereOnly() return GP.Setting("routeHere") == true end

function Plan.Here(ev)
    local src = ev and ev.source
    if not src then return false end
    if src.kind == "bags" then return true end
    local S = GP.Sources
    local here = S.PlayerZone and S.PlayerZone()
    if src.dungeon then
        if IsInInstance and IsInInstance() and GetInstanceInfo then
            local name = GP.Plain(GetInstanceInfo())
            if type(name) == "string" and (src.dungeon == name or src.dungeon:match("^(.-)%s*:") == name) then return true end
        end
        local e = GP.Waypoint.Entrance(src.dungeon)
        return here ~= nil and e ~= nil and S.Zone(e.mapID) == here
    end
    local p = GP.Waypoint.PlaceOf(src)
    return here ~= nil and p ~= nil and S.Zone(p.mapID) == here
end

-- What the Route lists: the Show filter, and This zone only when it's ticked.
local function routeKeeps(ev)
    if not UI.ContentMatches(ev) then return false end
    return not Plan.HereOnly() or Plan.Here(ev)
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

-- A new zone: the Route follows you while This zone only is ticked.
GP.RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
    if not Plan.HereOnly() then return end
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
        -- This zone only, between the two: "Group by: [place]  [ ] This zone only".
        Plan.hereText = skin.Text(page, "small", "LABEL")
        Plan.hereText:SetText(L["This zone only"])
        Plan.hereText:SetPoint("RIGHT", Plan.content, "LEFT", -10, 0)
        Plan.here = skin.Toggle(page)
        Plan.here:SetPoint("RIGHT", Plan.hereText, "LEFT", -3, 0)
        Plan.here.SetOn(Plan.HereOnly())
        -- The words click it too.
        if Plan.here.SetHitRectInsets and Plan.hereText.GetStringWidth then
            Plan.here:SetHitRectInsets(0, -((Plan.hereText:GetStringWidth() or 0) + 3), 0, 0)
        end
        Plan.here.onToggle = function(on)
            GP.SetSetting("routeHere", on and true or nil)
            local def = UI.PAGES.plan
            if def and def.frame and def.frame:IsShown() then GP.SafeCall(def.Fill, def.frame) end
        end
        Plan.group:SetPoint("RIGHT", Plan.here, "LEFT", -10, 0)
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
        if Plan.here then Plan.here.SetOn(hereOnly) end
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
            items[#items + 1] = { kind = "note", text = hereOnly
                and L["Nothing to get in this zone right now. Untick This zone only to see everywhere."]
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
        local key = UI.ContentKey() .. (Plan.BySlot() and ":slot" or "") .. (hereOnly and (":here" .. tostring(GP.Sources.PlayerZone and GP.Sources.PlayerZone())) or "")
        Plan.list:SetItems(items, Plan.viewKey == key)
        Plan.viewKey = key
    end,
})
