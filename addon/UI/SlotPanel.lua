-- SlotPanel: the Character tab's right half. With no slot picked it shows
-- what's near you (in your zone, or the dungeon you're in), then the best
-- upgrade for every slot; with one picked, everything for that
-- slot: "Best now" (easy to get at your level) and "Worth chasing"
-- (dungeons, rares, long chains, a few levels away), biggest gain first.

local _, GP = ...

local UI, Slots = GP.UI, GP.Slots
local L = GP.L

local SP = {}
UI.SlotPanel = SP

SP.MAX_ROWS = 40     -- per section

function SP.Build(page, x)
    local skin = GP.Skin.current
    local box = CreateFrame("Frame", nil, page)
    box:SetPoint("TOPLEFT", page, "TOPLEFT", x, 0)
    box:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    SP.box = box

    SP.back = skin.Button(box, L["All slots"], 90, 22)
    SP.back:SetPoint("TOPRIGHT", box, "TOPRIGHT", -2, -2)
    SP.back:SetScript("OnClick", function() UI.SelectSlot(nil) end)

    SP.title = skin.Text(box, "head", "TITLE")
    SP.title:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -4)
    SP.title:SetPoint("RIGHT", box, "RIGHT", -104, 0)
    SP.title:SetWordWrap(false)
    SP.sub = skin.Text(box, "small", "LABEL")
    SP.sub:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -28)
    SP.sub:SetPoint("RIGHT", box, "RIGHT", -6, 0)
    SP.sub:SetWordWrap(false)

    -- What to show and in what order.
    SP.content = UI.ContentDropdown(box, 220)
    SP.content:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -46)
    SP.sort = GP.Dropdown(box, { width = 170, height = 22, keys = { "ilvl", "gain", "level" },
        labels = UI.SORT_LABELS, prefix = L["Sort:"] .. " ",
        get = function() return GP.Setting("panelSort") or "ilvl" end,
        set = function(k)
            GP.SetSetting("panelSort", k)
            SP.Fill()
        end })
    SP.sort:SetPoint("LEFT", SP.content, "RIGHT", 8, 0)

    SP.list = GP.List.New(box, { empty = L["Nothing to show yet."] })
    SP.list:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -76)
    SP.list:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
end

-- What you wear in a slot, in a line.
local function wearing(key)
    local function one(k)
        local e = GP.Score.equipped[k]
        if not (e and e.rec) then return nil end
        local _, _, _, hex = GP.QualityColor(e.rec.quality)
        return string.format("|c%s%s|r (%s)", hex, e.rec.name, string.format(L["%d pts"], GP.Round(e.points or 0)))
    end
    local s = Slots.BY_KEY[key]
    local parts = {}
    parts[#parts + 1] = one(key)
    if s.pair then parts[#parts + 1] = one(s.pair) end
    if #parts == 0 then return L["Nothing equipped"] end
    return string.format(L["Wearing %s"], table.concat(parts, " " .. L["and"] .. " "))
end

-- Notes at the top while the list isn't final.
local function statusNotes(items)
    local S = GP.Sources
    if S.status == "scanning" or S.status == "loading" or S.status == "idle" then
        items[#items + 1] = { kind = "note", text = L["Still reading the gear database; the lists fill in as items load."] }
    elseif S.status == "nodb" then
        items[#items + 1] = { kind = "note", height = 46,
            text = L["QuestieDB isn't installed, so only your bags and gear you've seen in game are listed. Install QuestieDB for every quest, drop and vendor."] }
    end
end

local function emptyText(default)
    if not UI.ContentFiltered() then return default end
    return L["Nothing here from what's ticked under Show."]
end

local function addSection(items, title, list, role, empty, prefixSlot)
    items[#items + 1] = { kind = "section", text = title, role = role,
        right = #list > 0 and GP.Count(#list, "%d item", "%d items") or nil }
    if #list == 0 then
        items[#items + 1] = { kind = "note", text = emptyText(empty) }
        return
    end
    list = UI.Sorted(list, GP.Setting("panelSort") or "ilvl")
    for i = 1, math.min(#list, SP.MAX_ROWS) do
        local ev = list[i]
        items[#items + 1] = { kind = "item", ev = ev, key = ev.rec.id,
            prefix = prefixSlot and Slots.Label(ev.slot) or nil }
    end
end

-- The best of each slot in a tier (within the chosen content).
local function bestPerSlot(res, tier)
    local out = {}
    for _, key in ipairs(Slots.ORDER) do
        local group = Slots.GROUP[key] or key
        local bucket = group == key and res.bySlot[key]
        if bucket then
            for _, ev in ipairs(bucket[tier] or {}) do
                if UI.ContentMatches(ev) then out[#out + 1] = ev break end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Near you: upgrades you can get in the zone you're in (or the dungeon
-- you're inside), closest first, with how far each one is.
-- ---------------------------------------------------------------------

SP.NEAR_MAX = 6

-- How far, in a few letters.
local function yardsText(d)
    if d == true or d == nil then return nil end
    if d < 40 then return L["right here"] end
    if d >= 1000 then return string.format("%.1fk yd", d / 1000) end
    return string.format("%d yd", math.floor(d / 10 + 0.5) * 10)
end

-- The upgrades near you (each as its nearest way to get it), and where
-- "near" is. A view of each evaluation with that source, so its line, its
-- map pin and the Show: filter all go by the nearby place.
function SP.Near()
    local here = GP.Waypoint.Here()
    local place = here.instance or here.zone
    local out = {}
    if not place then return out, nil end
    for _, ev in ipairs(GP.Score.results.all or {}) do
        -- (Not what needs a rank, a reputation or a profession first.)
        if ev.tier and ev.tier ~= "locked" then
            local best, bestD
            for _, src in ipairs(ev.entry and ev.entry.sources or { ev.source }) do
                local d = GP.Waypoint.Near(src, here)
                if d ~= nil then
                    local dn = d == true and math.huge or d
                    if not bestD or dn < bestD then best, bestD = src, dn end
                end
            end
            if best then
                local view = setmetatable({ source = best, nearYards = bestD ~= math.huge and bestD or nil },
                    { __index = ev })
                if UI.ContentMatches(view) then out[#out + 1] = view end
            end
        end
    end
    -- Closest first; where it's not known, the biggest gain.
    table.sort(out, function(a, b)
        local da, db = a.nearYards or math.huge, b.nearYards or math.huge
        if da ~= db then return da < db end
        return (a.delta or 0) > (b.delta or 0)
    end)
    return out, place
end

-- A text that changes when the near list would look different (the
-- distances to the nearest 10 yards), so moving about only redraws it
-- when something on it changed.
local function nearKey(list, place)
    local t = { place or "" }
    for i = 1, math.min(#list, SP.NEAR_MAX) do
        local ev = list[i]
        t[#t + 1] = ev.rec.id .. ":" .. (yardsText(ev.nearYards) or "")
    end
    return table.concat(t, "|")
end

local function addNear(items, list, place)
    if not place then return end
    items[#items + 1] = { kind = "section", text = L["Near you"], role = "VALUE", right = place }
    if #list == 0 then
        items[#items + 1] = { kind = "note", text = UI.ContentFiltered()
            and L["Nothing for you here from what's ticked under Show."]
            or L["No upgrades to get here. The Route tab shows where to go."] }
        return
    end
    for i = 1, math.min(#list, SP.NEAR_MAX) do
        local ev = list[i]
        local far = yardsText(ev.nearYards)
        items[#items + 1] = { kind = "item", ev = ev, key = ev.rec.id,
            prefix = Slots.Label(ev.slot) .. (far and ("  |  " .. far) or "") }
    end
    if #list > SP.NEAR_MAX then
        local rest = #list - SP.NEAR_MAX
        items[#items + 1] = { kind = "note", height = 24,
            text = string.format(L["and %d more here, farther away"], rest) }
    end
    items[#items + 1] = { kind = "gap", height = 8 }
end

local LOCKED_TEXT = "Needs something first"
local LOCKED_EMPTY = "Nothing that needs a PvP rank, a reputation or a profession."

function SP.Fill()
    if not SP.list then return end
    local res = GP.Score.results
    local key = UI.selectedSlot
    local items = {}
    statusNotes(items)
    SP.sort.Refresh()
    SP.content.Refresh()
    local lists
    if key then
        local group = Slots.GROUP[key] or key
        local bucket = res.bySlot[group] or {}
        SP.title:SetText(Slots.Label(group))
        SP.sub:SetText(wearing(group))
        SP.back:Show()
        lists = { primary = UI.Filter(bucket.primary or {}), secondary = UI.Filter(bucket.secondary or {}),
            locked = UI.Filter(bucket.locked or {}) }
        local checked = GP.Check.lastSlot[group]
        if checked then
            local ids = {}
            for _, l in pairs(lists) do for _, ev in ipairs(l) do ids[#ids + 1] = ev.rec.id end end
            local s = GP.Check.Summary(ids)
            items[#items + 1] = { kind = "note", text = s.warn > 0
                and string.format(L["%s Checked %s: %d of %d need a second look. Hover them to see why."],
                    GP.Check.ICON_WARN, GP.Check.Ago(checked), s.warn, s.total)
                or string.format(L["%s Checked %s: the game and the database agree on all %d."],
                    GP.Check.ICON_OK, GP.Check.Ago(checked), s.total) }
        end
    else
        SP.title:SetText(L["Upgrades for every slot"])
        SP.sub:SetText(L["Best now: easy to get at your level.  Worth chasing: dungeons, rares, long chains, a few levels away."])
        SP.back:Hide()
        lists = { primary = bestPerSlot(res, "primary"), secondary = bestPerSlot(res, "secondary"),
            locked = bestPerSlot(res, "locked") }
    end
    local all = not key
    SP.nearKey = nil
    if all and GP.Sources.status ~= "scanning" and GP.Sources.status ~= "idle" then
        local near, place = SP.Near()
        addNear(items, near, place)
        SP.nearKey = nearKey(near, place)
    end
    -- Only PvP rank, reputation or professions ticked: just what needs them.
    local onlyNeeds = not (UI.ContentOn("quest") or UI.ContentOn("dungeon") or UI.ContentOn("vendor")
        or UI.ContentOn("drop") or UI.ContentOn("world") or UI.ContentOn("bags"))
    if not onlyNeeds then
        addSection(items, L["Best now"], lists.primary, "GOOD", L["Nothing better you can get at your level yet."], all)
        addSection(items, L["Worth chasing"], lists.secondary, "WARN",
            key and string.format(L["Nothing worth chasing within %d levels."], GP.Setting("ahead") or 5)
                or L["Nothing worth chasing found yet."], all)
    end
    if #lists.locked > 0 or onlyNeeds then
        addSection(items, L[LOCKED_TEXT], lists.locked, "OFF", L[LOCKED_EMPTY], all)
    end
    local viewKey = (key or "all") .. "|" .. UI.ContentKey() .. "|" .. (GP.Setting("panelSort") or "ilvl")
    SP.list:SetItems(items, SP.viewKey == viewKey)
    SP.viewKey = viewKey
end

-- Near you stays up to date as you move: a new zone fills it again, and
-- walking about redraws it when a distance on it changes (looked at every
-- few seconds, only while it's on screen).
local function nearShown()
    return SP.list ~= nil and UI.frame ~= nil and UI.frame:IsShown() and UI.current == "doll"
        and not UI.selectedSlot
end

function SP.RefreshNear(force)
    if not nearShown() then return end
    if not force then
        local near, place = SP.Near()
        if nearKey(near, place) == SP.nearKey then return end
    end
    GP.SafeCall(SP.Fill)
end

for _, e in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD" }) do
    GP.RegisterEvent(e, function() SP.RefreshNear(true) end)
end
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(3, function() GP.SafeCall(SP.RefreshNear, false) end)
end
