-- RareWatch: rare mobs that drop an upgrade for you.
--
-- In a dungeon whose rares drop an upgrade for you, a row of icons on
-- screen, one per rare, each showing the upgrade it drops. An icon is dim
-- while GearPath watches, and lights up (with a sound and a chat line) when
-- its rare is close enough for the game to show it: its nameplate, your
-- target or mouseover, a party member's target, or a rare marker on the
-- minimap where Forever has one. An addon can't see mobs farther off than
-- that, so a dim icon means "not seen yet", never "not here".
--
-- Out in the world, the rares of your zone that drop an upgrade are watched
-- the same way, but quietly: nothing shows until one comes into view, then
-- its icon pops up with the sound and the chat line, and goes again a while
-- after it's out of sight or killed.
--
-- The row hides while you're in combat. Drag any icon to move the row;
-- right-click hides it until you leave the dungeon or zone. Off with "Rare
-- watch" (and "...in the open world") in Settings.

local _, GP = ...

local RW = { watch = {}, byName = {}, state = {}, seen = {}, count = 0 }
GP.RareWatch = RW

RW.SIZE = 38
RW.WORLD_FORGET = 90      -- out in the world, a rare unseen this long (seconds) drops off the row
RW.WORLD_KEEP_DEAD = 15   -- and a killed one stays this long, with its check
local SKULL_ATLAS, SKULL_FILE = "VignetteKill", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local function on() return GP.Setting("rareWatch") ~= false end
local function worldOn() return GP.Setting("rareWatchWorld") ~= false end

local function isRare(src)
    return src and src.kind == "drop" and (src.rank == "Rare Elite" or src.rank == "Rare")
end

-- ---------------------------------------------------------------------
-- Which rares to watch for
-- ---------------------------------------------------------------------

-- Whether a rare's source is where you are: the dungeon you're in, or out
-- in the world, your zone.
local function here_(src, here)
    if here.instance then
        return src.dungeon ~= nil and GP.Waypoint.SameDungeon(src.dungeon, here.instance)
    end
    return not src.dungeon and GP.Waypoint.Near(src, here) ~= nil
end

-- The rares of the dungeon (or zone) you're in that drop an upgrade for
-- you: [key] = { id, name, items = { ev, ... } }, and how many.
function RW.Build(here)
    local out, byName, n = {}, {}, 0
    if not here or not (here.instance or here.mapID or here.zone) then return out, byName, 0 end
    if not here.instance and not worldOn() then return out, byName, 0 end
    for _, ev in ipairs(GP.Score.results.all or {}) do
        if ev.tier and ev.tier ~= "locked" then
            for _, src in ipairs(ev.entry and ev.entry.sources or { ev.source }) do
                if isRare(src) and here_(src, here) then
                    local key = src.id and ("id" .. src.id) or ("n" .. tostring(src.name):lower())
                    local r = out[key]
                    if not r then
                        r = { id = src.id, name = src.name or "?", items = {} }
                        out[key] = r
                        n = n + 1
                        if src.name then byName[src.name:lower()] = r end
                    end
                    local dup = false
                    for _, e in ipairs(r.items) do if e.rec.id == ev.rec.id then dup = true end end
                    if not dup then r.items[#r.items + 1] = ev end
                end
            end
        end
    end
    for _, r in pairs(out) do table.sort(r.items, function(a, b) return (a.delta or 0) > (b.delta or 0) end) end
    return out, byName, n
end

-- ---------------------------------------------------------------------
-- Seeing one
-- ---------------------------------------------------------------------

local npcFromGUID = GP.NpcID

local function find(id, name)
    if id and RW.watch["id" .. id] then return RW.watch["id" .. id] end
    name = GP.Plain(name)
    if type(name) == "string" then return RW.byName[name:lower()] end
end

local function itemLine(ev)
    local gain = GP.UI and GP.UI.GainText and GP.UI.GainText(ev) or ""
    return string.format("%s (%s, %s)", ev.rec.name or "?", gain, GP.Slots.Label(ev.slot))
end

-- A watched rare seen: alive (lights the skull, once) or dead.
function RW.Spot(r, dead)
    local was = RW.state[r]
    RW.seen[r] = GetTime()
    -- Out in the world a killed rare comes back in time: seen alive, it's new.
    if not dead and was == "dead" and RW.world then was = nil end
    if dead then
        if was ~= "dead" then
            RW.state[r] = "dead"
            RW.Paint()
        end
        return
    end
    if was then return end
    RW.state[r] = "up"
    if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK or 8959) end
    local best = r.items[1]
    GP.Print("%s is here! It drops %s.", r.name, best and itemLine(best) or "an upgrade for you")
    RW.Paint()
end

-- Looks at one unit (a nameplate, your target, a party member's target).
function RW.Check(unit)
    if not RW.active or not unit then return end
    if UnitExists and not GP.Plain(UnitExists(unit)) then return end
    local r = find(npcFromGUID(UnitGUID and UnitGUID(unit)), UnitName and UnitName(unit))
    if not r then return end
    local dead = UnitIsDead and GP.Plain(UnitIsDead(unit)) or false
    RW.Spot(r, dead == true)
end

-- Rare markers on the minimap (where Forever gives its rares one: these
-- show across the whole dungeon).
function RW.CheckVignettes()
    if not (RW.active and C_VignetteInfo and C_VignetteInfo.GetVignettes) then return end
    local ok, list = pcall(C_VignetteInfo.GetVignettes)
    if not ok or type(list) ~= "table" then return end
    for _, guid in ipairs(list) do
        local okI, info = pcall(C_VignetteInfo.GetVignetteInfo, guid)
        if okI and type(info) == "table" then
            local r = find(npcFromGUID(info.objectGUID), info.name)
            if r then RW.Spot(r, GP.Plain(info.isDead) == true) end
        end
    end
end

-- Everything in view now: nameplates, target, mouseover, the party's targets.
function RW.Sweep()
    if not RW.active then return end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if unit then RW.Check(unit) end
            end
        end
    end
    RW.Check("target")
    RW.Check("mouseover")
    for i = 1, 4 do RW.Check("party" .. i .. "target") end
    RW.CheckVignettes()
end

-- ---------------------------------------------------------------------
-- The icons: one per rare, showing the best upgrade it drops. Dim until
-- it's seen, lit with a pulsing glow while it's here, a green check once
-- it's killed, its name underneath. Hidden while you're in combat.
-- ---------------------------------------------------------------------

RW.MAX = 6          -- icons at most
RW.LABEL_W = 78     -- room for each rare's name
RW.GAP = 6

local function savePos(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    if point then GP.db.window.rare = { point, relPoint, x, y } end
end

local function placeAt(f)
    local p = GP.db.window.rare
    f:ClearAllPoints()
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
end

local STATUS = { up = "|cff40ff40Here now|r", dead = "|cff999999Killed|r" }

-- How far your nameplates reach (yards), and whether enemy ones are on.
function RW.NameplateReach()
    local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not getCVar then return nil, nil end
    local okD, d = pcall(getCVar, "nameplateMaxDistance")
    local okE, e = pcall(getCVar, "nameplateShowEnemies")
    local dist = okD and tonumber(GP.Plain(d) or "") or nil
    local enemies = okE and GP.Plain(e) or nil
    if enemies == nil then return dist, nil end
    return dist, enemies ~= "0" and enemies ~= 0
end

local function hideForRun()
    RW.hidden = true
    RW.Paint()
    GP.Print("Rare watch hidden until you leave this %s (/gp rare brings it back).", RW.world and "zone" or "dungeon")
end

local function iconTooltip(b)
    local r = b.rare
    if not r then return end
    GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
    GameTooltip:SetText(r.name, 1, 0.82, 0)
    GameTooltip:AddLine(STATUS[RW.state[r]] or "|cffaaaaaaNot seen yet|r")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Drops, for you:", 0.6, 0.6, 0.6)
    for i = 1, math.min(#r.items, 4) do
        GameTooltip:AddLine("   " .. itemLine(r.items[i]), 0.85, 0.85, 0.85)
    end
    GameTooltip:AddLine(" ")
    local dist, enemies = RW.NameplateReach()
    if enemies == false then
        GameTooltip:AddLine("Enemy nameplates are off (press V), so this only lights up when you or your party target it.",
            1, 0.35, 0.35, true)
    else
        GameTooltip:AddLine(string.format(
            "Lights up when it's within your nameplate range%s, or when you or your party target it.",
            dist and string.format(" (%d yards)", dist) or ""), 0.6, 0.6, 0.6, true)
    end
    GameTooltip:AddLine(RW.world and "Drag to move.  Right-click: hide until you leave this zone."
        or "Drag to move.  Right-click: hide until you leave.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function container()
    if RW.frame then return RW.frame end
    local f = CreateFrame("Frame", "GearPathRareWatch", UIParent)
    f:SetSize(RW.LABEL_W, RW.SIZE + 16)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    placeAt(f)
    f:Hide()
    RW.frame, RW.icons = f, {}
    return f
end

local function makeIcon(i)
    local f = container()
    local skin = GP.Skin.Pick()
    local b = CreateFrame("Button", nil, f)
    b:SetSize(RW.SIZE, RW.SIZE)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * (RW.LABEL_W + RW.GAP) + (RW.LABEL_W - RW.SIZE) / 2, 0)
    b:EnableMouse(true)
    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks("RightButtonUp")
    -- Any icon drags the whole row.
    b:SetScript("OnDragStart", function() f:StartMoving() end)
    b:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        f:SetUserPlaced(false)
        savePos(f)
    end)
    b:SetScript("OnClick", function(_, button) if button == "RightButton" then hideForRun() end end)
    b:SetScript("OnEnter", iconTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- A soft gold glow behind it that pulses while its rare is here.
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.glow:SetSize(RW.SIZE * 1.9, RW.SIZE * 1.9)
    b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    if b.glow.SetBlendMode then b.glow:SetBlendMode("ADD") end
    b.glow:SetVertexColor(1, 0.8, 0.2)
    b.glow:Hide()
    local ag = b.glow.CreateAnimationGroup and b.glow:CreateAnimationGroup()
    if ag and ag.CreateAnimation then
        local a = ag:CreateAnimation("Alpha")
        if a then
            a:SetFromAlpha(1)
            a:SetToAlpha(0.35)
            a:SetDuration(0.7)
            ag:SetLooping("BOUNCE")
            b.pulse = ag
        end
    end

    b.icon = skin.Icon(b, RW.SIZE)
    b.icon:SetAllPoints(b)
    b.icon:EnableMouse(false)
    -- Above the icon (its own frame): a skull badge, the killed check, the name.
    b.top = CreateFrame("Frame", nil, b)
    b.top:SetAllPoints(b)
    b.top:SetFrameLevel(b.icon:GetFrameLevel() + 12)
    b.badge = b.top:CreateTexture(nil, "OVERLAY")
    b.badge:SetSize(16, 16)
    b.badge:SetPoint("TOPLEFT", b, "TOPLEFT", -5, 5)
    GP.Skin.SetArt(b.badge, SKULL_ATLAS, SKULL_FILE)
    b.mark = b.top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
    b.label = b.top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -3)
    b.label:SetWidth(RW.LABEL_W)
    b.label:SetWordWrap(false)
    RW.icons[i] = b
    return b
end

local function paintIcon(b, r)
    local st = RW.state[r]
    local best = r.items[1]
    -- Orange border while it's here, green once it's killed.
    b.icon.SetItem(best and best.rec.icon or SKULL_FILE, st == "up" and 5 or (st == "dead" and 2 or 0))
    if b.icon.tex.SetDesaturated then b.icon.tex:SetDesaturated(st ~= "up") end
    b.icon.tex:SetAlpha(st == "up" and 1 or (st == "dead" and 0.4 or 0.55))
    if b.badge.SetDesaturated then b.badge:SetDesaturated(st ~= "up") end
    b.badge:SetAlpha(st == "up" and 1 or 0.6)
    b.glow:SetShown(st == "up")
    if b.pulse then if st == "up" then b.pulse:Play() else b.pulse:Stop() end end
    b.mark:SetText(st == "dead" and GP.Check.ICON_OK or "")
    b.label:SetText(r.name)
    if st == "up" then b.label:SetTextColor(1, 0.82, 0) else b.label:SetTextColor(0.6, 0.6, 0.6) end
end

-- The rares to show, biggest upgrade first.
local function ordered()
    local list = {}
    for _, r in pairs(RW.watch) do list[#list + 1] = r end
    table.sort(list, function(a, b)
        local da, db = a.items[1] and a.items[1].delta or 0, b.items[1] and b.items[1].delta or 0
        if da ~= db then return da > db end
        return a.name < b.name
    end)
    return list
end

local function inCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and GP.Plain(UnitAffectingCombat("player")))
        or RW.fighting
end

-- The rares on the row: in a dungeon all of them; out in the world only
-- the ones in view (seen lately), and a killed one for a few seconds. One
-- out of sight long enough is forgotten, so it's news when it's back.
local function onRow()
    local list = ordered()
    if not RW.world then return list end
    local now, out = GetTime(), {}
    for _, r in ipairs(list) do
        local st, ago = RW.state[r], now - (RW.seen[r] or 0)
        if st == "up" and ago > RW.WORLD_FORGET then
            RW.state[r] = nil
        elseif (st == "up") or (st == "dead" and ago <= RW.WORLD_KEEP_DEAD) then
            out[#out + 1] = r
        end
    end
    return out
end

-- Shows the row as things stand (hidden in combat, after a right-click,
-- with nothing to watch, or out in the world with nothing in view).
function RW.Paint()
    local list = RW.active and RW.count > 0 and onRow() or {}
    local show = #list > 0 and not RW.hidden and on() and not inCombat()
    if not show then
        if RW.frame then RW.frame:Hide() end
        return
    end
    local f = container()
    local n = math.min(#list, RW.MAX)
    for i = 1, n do
        local b = RW.icons[i] or makeIcon(i)
        b.rare = list[i]
        paintIcon(b, list[i])
        b:Show()
    end
    for i = n + 1, #RW.icons do
        RW.icons[i].rare = nil
        RW.icons[i]:Hide()
    end
    f:SetSize(n * RW.LABEL_W + math.max(0, n - 1) * RW.GAP, RW.SIZE + 16)
    f:Show()
end

-- Out of sight while you fight; back (as it stands) when the fight ends.
GP.RegisterEvent("PLAYER_REGEN_DISABLED", function()
    RW.fighting = true
    if RW.frame then RW.frame:Hide() end
end)
GP.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    RW.fighting = false
    RW.Paint()
end)

-- ---------------------------------------------------------------------
-- When
-- ---------------------------------------------------------------------

-- Into or out of a dungeon, a new zone, or the gear list changed: what to
-- watch for.
function RW.Refresh()
    local here = GP.Waypoint.Here()
    local place = here.instance or (here.mapID and ("map" .. here.mapID)) or here.zone
    if place ~= RW.place then
        -- A new dungeon or zone: a fresh watch.
        RW.place, RW.hidden = place, nil
        wipe(RW.state)
        wipe(RW.seen)
    end
    RW.world = here.instance == nil
    RW.active = place ~= nil and on() and (not RW.world or worldOn())
    local watch, byName, n = RW.Build(here)
    -- Keep what's been seen for rares still watched.
    local state, seen = {}, {}
    for key, r in pairs(watch) do
        local old = RW.watch[key]
        if old then state[r], seen[r] = RW.state[old], RW.seen[old] end
    end
    RW.watch, RW.byName, RW.count, RW.state, RW.seen = watch, byName, n, state, seen
    RW.Paint()
    if RW.active then RW.Sweep() end
end

local function soon() GP.Soon("rarewatch", RW.Refresh) end
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do GP.RegisterEvent(e, soon) end
GP.On("ScoresChanged", soon)
GP.On("SettingChanged", function(key) if key == "rareWatch" or key == "rareWatchWorld" then soon() end end)

GP.RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit) RW.Check(unit) end)
GP.RegisterEvent("PLAYER_TARGET_CHANGED", function() RW.Check("target") end)
GP.RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() RW.Check("mouseover") end)
GP.RegisterEvent("UNIT_TARGET", function(_, unit)
    if type(unit) == "string" and unit:match("^party%d$") then RW.Check(unit .. "target") end
end)
GP.RegisterEvent("VIGNETTES_UPDATED", function() RW.CheckVignettes() end)
GP.RegisterEvent("VIGNETTE_MINIMAP_UPDATED", function() RW.CheckVignettes() end)
-- And a look around every couple of seconds (a rare that dies in view, a
-- nameplate that was up before the watch began).
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(2, function()
        if not RW.active then return end
        GP.SafeCall(RW.Sweep)
        -- Out in the world the row follows what's in view.
        if RW.world then GP.SafeCall(RW.Paint) end
    end)
end

-- /gp rare: the skull back if you hid it, and back to its first spot.
GP.RegisterCommand("rare", "show the rare watch icons again and put them back in their first spot", function()
    GP.db.window.rare = nil
    RW.hidden = nil
    if RW.frame then placeAt(RW.frame) end
    RW.Refresh()
    if not RW.active then
        GP.Print("Rare watch is off in Settings > Extras.")
    elseif RW.count == 0 then
        GP.Print("Rare watch: no rare here drops an upgrade for you.")
    elseif RW.world then
        local names = {}
        for _, r in ipairs(ordered()) do names[#names + 1] = r.name end
        GP.Print("Rare watch: watching for %s. An icon shows when one comes into view.", table.concat(names, ", "))
    end
end)
