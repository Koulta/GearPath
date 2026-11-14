-- DungeonLoot: when you walk into a dungeon or raid, a small panel with its
-- drops that are upgrades for you, by boss, with how much better each is
-- than what you have on (the tooltip's +%). Koulta's idea, Nov 8.
--
-- Only real upgrades (the tooltips' "big enough" bar); nothing you need a
-- reputation or a rank for first, nothing hidden, no healer gear unless you
-- asked for it. Bosses in the journal's order where DungeonJournal is
-- installed, else the biggest upgrade first; trash and "any boss" last.
--
-- It stays up between fights until you click Hide: it steps aside while
-- you fight and comes back after. /gp loot brings a hidden one back. Drag
-- to move, drag the corner to resize.
-- Off with "Dungeon loot" in Settings > Extras.

local _, GP = ...

local Loot = { shownFor = nil }
GP.Loot = Loot

local L = GP.L

Loot.WIDTH = 300
Loot.MAX_ROWS = 14        -- item lines at most (then "and N more")
Loot.ROW_H = 18

local function on() return GP.Setting("dungeonLoot") ~= false end

local function inCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and GP.Plain(UnitAffectingCombat("player")))
        or Loot.fighting
end

-- ---------------------------------------------------------------------
-- What drops here for you
-- ---------------------------------------------------------------------

local function lastGroup(name) return name == "Trash mobs" or name == "Any boss" end

-- A wing's part of a name ("Scarlet Monastery: Library" -> "Library"), or nil.
function Loot.Wing(instance)
    if type(instance) ~= "string" then return nil end
    local base, wing = instance:match("^(.-)%s*:%s*(.+)$")
    return base and GP.Waypoint.WINGS[base] and wing or nil
end

-- Each wing's bosses (the journal's lists when it's there): a drop the
-- database files under the whole monastery stays with its own wing.
Loot.WING_BOSSES = {
    ["Scarlet Monastery: Graveyard"] = { "Interrogator Vishas", "Bloodmage Thalnos", "Ironspine", "Azshir the Sleepless", "Fallen Champion" },
    ["Scarlet Monastery: Library"] = { "Houndmaster Loksey", "Arcanist Doan" },
    ["Scarlet Monastery: Armory"] = { "Herod" },
    ["Scarlet Monastery: Cathedral"] = { "High Inquisitor Fairbanks", "Scarlet Commander Mograine", "High Inquisitor Whitemane" },
}

-- The wing a boss of a winged dungeon is in, or nil.
function Loot.BossWing(base, boss)
    if type(boss) ~= "string" then return nil end
    local J = GP.Journal
    for name, list in pairs(Loot.WING_BOSSES) do
        if name:find(base, 1, true) == 1 then
            local order = J and J.Available() and J.BossOrder(name) or {}
            if order[boss] then return name end
            for _, b in ipairs(list) do if b == boss then return name end end
        end
    end
end

-- Whether a source belongs to the place you're in: the same dungeon, and
-- in a wing, the same wing (a drop filed under the whole monastery goes by
-- its boss; anything else filed so, a quest say, stays).
function Loot.InPlace(src, instance)
    if not (src.dungeon and GP.Waypoint.SameDungeon(src.dungeon, instance)) then return false end
    local wing = Loot.Wing(instance)
    if not wing or Loot.Wing(src.dungeon) then return true end
    local base = instance:match("^(.-)%s*:")
    local at = src.kind == "drop" and Loot.BossWing(base, src.bossName or src.name)
    return not at or at == instance
end

-- The upgrades in the dungeon named `instance`: its drops, by boss, then
-- (0.8.0) its quests whose rewards are upgrades, one group per quest.
-- { { boss = name, npc = id, quest = source, items = { ev, ... } }, ... }
-- in order, and how many items. Items you've looted this visit stay on it,
-- checked (Loot.state.got), even once they're no longer upgrades.
function Loot.Build(instance)
    local groups, byBoss, seen, n = {}, {}, {}, 0
    if type(instance) ~= "string" or instance == "" then return groups, 0 end
    local Score, Way = GP.Score, GP.Waypoint
    local dungeonName
    local function add(key, make, ev)
        local g = byBoss[key]
        if not g then
            g = make()
            g.items = {}
            byBoss[key] = g
            groups[#groups + 1] = g
        end
        g.items[#g.items + 1] = ev
        seen[ev.rec.id] = true
        n = n + 1
    end
    for _, ev in ipairs(Score.results.all or {}) do
        local rec = ev.rec
        local good = rec and not seen[rec.id] and not ev.healerPass and ev.tier ~= "locked" and not ev.needs
            and Score.BigEnough(ev.delta or 0, ev.base)
        if good then
            for _, src in ipairs(ev.entry and ev.entry.sources or { ev.source }) do
                if Loot.InPlace(src, instance) then
                    if src.kind == "drop" and not src.worldDrop then
                        local boss = src.bossName or src.name or "?"
                        add(boss, function() return { boss = boss, npc = type(src.id) == "number" and src.id or nil } end, ev)
                        dungeonName = dungeonName or src.dungeon
                        break
                    elseif src.kind == "quest" and not src.done then
                        local key = "quest:" .. tostring(src.id)
                        add(key, function()
                            return { boss = string.format(L["Quest: %s"], src.name or "?"), quest = src }
                        end, ev)
                        dungeonName = dungeonName or src.dungeon
                        break
                    end
                end
            end
        end
    end
    -- What you looted here this visit: back in its group, checked.
    local st = Loot.state
    if st and st.place == instance then
        for id, got in pairs(st.got) do
            if not seen[id] and got.ev and got.boss then
                add(got.key or got.boss, function() return { boss = got.boss, npc = got.npc, quest = got.quest } end, got.ev)
            end
        end
    end
    if Loot.Wing(instance) then dungeonName = instance end
    local order = GP.Journal and GP.Journal.BossOrder and dungeonName and GP.Journal.BossOrder(dungeonName) or {}
    for _, g in ipairs(groups) do
        table.sort(g.items, function(a, b) return (a.delta or 0) > (b.delta or 0) end)
        g.best = g.items[1].delta or 0
    end
    table.sort(groups, function(a, b)
        -- Bosses, then trash and "any boss", then quests.
        local ra = a.quest and 2 or (lastGroup(a.boss) and 1 or 0)
        local rb = b.quest and 2 or (lastGroup(b.boss) and 1 or 0)
        if ra ~= rb then return ra < rb end
        local oa, ob = order[a.boss], order[b.boss]
        if oa and ob and oa ~= ob then return oa < ob end
        if (oa ~= nil) ~= (ob ~= nil) then return oa ~= nil end
        if a.best ~= b.best then return a.best > b.best end
        return a.boss < b.boss
    end)
    return groups, n
end

-- ---------------------------------------------------------------------
-- The checklist (0.8.0): bosses you've killed and items you've looted,
-- for this dungeon. Kept through a wipe and the run back (leaving and
-- coming in again); a different dungeon, or two hours later, starts over.
-- ---------------------------------------------------------------------

Loot.KEEP = 2 * 60 * 60

local function now() return (time and time()) or 0 end

function Loot.Visit(instance)
    local st = Loot.state
    if st and now() - (st.at or 0) <= Loot.KEEP then
        -- The same place, or the same one named more exactly (a Scarlet
        -- Monastery wing, once the game says which): carried on.
        local wing = st.place ~= instance and Loot.Wing(instance) and GP.Waypoint.SameDungeon(st.place, instance)
            and not Loot.Wing(st.place)
        if st.place == instance or wing then
            st.place, st.at = instance, now()
            return st
        end
    end
    Loot.state = { place = instance, at = now(), dead = {}, deadIDs = {}, got = {} }
    return Loot.state
end

function Loot.BossDone(g)
    local st = Loot.state
    if not st or g.quest then return false end
    return st.dead[g.boss] == true or (g.npc ~= nil and st.deadIDs[g.npc] == true)
end

-- A boss died (by the combat log, or the game's encounter end).
function Loot.Killed(name, npc)
    local st = Loot.state
    if not st or not Loot.place then return end
    if type(name) == "string" and name ~= "" then st.dead[name] = true end
    if type(npc) == "number" then st.deadIDs[npc] = true end
    if Loot.frame and Loot.frame:IsShown() then GP.Soon("dungeonloot", Loot.Refresh) end
end

-- You looted an item: checked on the list, if it's on it.
function Loot.Got(id)
    local st = Loot.state
    if not (st and Loot.place and id) then return end
    for _, g in ipairs(Loot.groups or {}) do
        for _, ev in ipairs(g.items) do
            if ev.rec.id == id then
                st.got[id] = { ev = ev, boss = g.boss, npc = g.npc, quest = g.quest,
                    key = g.quest and ("quest:" .. tostring(g.quest.id)) or g.boss }
                if Loot.frame and Loot.frame:IsShown() then GP.Soon("dungeonloot", Loot.Refresh) end
                return true
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- The panel
-- ---------------------------------------------------------------------

local function savePos(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    if point then GP.db.window.loot = { point, relPoint, x, y } end
end

local function placeAt(f)
    local p = GP.db.window.loot
    f:ClearAllPoints()
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
    end
end

local function frame()
    if Loot.frame then return Loot.frame end
    local skin = GP.Skin.Pick()
    local f = skin.Popup(UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        f:SetUserPlaced(false)
        savePos(f)
    end)
    f:SetWidth(Loot.WIDTH)
    f:SetScale(Loot.Scale())
    placeAt(f)
    -- A header band across the top with an accent line under it (Koulta,
    -- Nov 8: "a border at the top"), in the look's own accent colour.
    f.band = skin.HeaderLine(f)
    f.band:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    f.band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    f.band:SetHeight(25)
    f.edge = f:CreateTexture(nil, "ARTWORK")
    f.edge:SetHeight(2)
    f.edge:SetPoint("TOPLEFT", f.band, "BOTTOMLEFT", 0, 0)
    f.edge:SetPoint("TOPRIGHT", f.band, "BOTTOMRIGHT", 0, 0)
    local r, g, b = skin.Accent()
    f.edge:SetColorTexture(r or 1, g or 0.82, b or 0, 0.9)
    f.title = skin.Text(f, "head", "TITLE")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    f.title:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.title:SetWordWrap(false)
    f.hide = skin.Button(f, L["Hide"], 64, 20)
    f.hide:SetScript("OnClick", function() Loot.Close() end)
    f.lines = {}
    -- The corner grip: drag to make the whole panel (text and all) bigger
    -- or smaller; right-click puts it back to normal size (Koulta, Nov 8).
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        Loot.StartResize(GetCursorPosition())
        grip:SetScript("OnUpdate", function() Loot.Resize(GetCursorPosition()) end)
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        grip:SetScript("OnUpdate", nil)
        if button == "RightButton" then
            Loot.SetScale(1)
        elseif Loot.sizing then
            Loot.sizing = nil
            savePos(f)
        end
    end)
    f.grip = grip
    Loot.frame = f
    return f
end

-- ---------------------------------------------------------------------
-- Size (the grip)
-- ---------------------------------------------------------------------

Loot.MIN_SCALE, Loot.MAX_SCALE = 0.7, 1.8

function Loot.Scale()
    return GP.Clamp(tonumber(GP.db.window.lootScale) or 1, Loot.MIN_SCALE, Loot.MAX_SCALE)
end

-- Pins the panel by its top-left corner (where it is now on screen), so it
-- grows down and to the right from there whatever its scale.
local function pinTopLeft(f)
    local left, top, s = f:GetLeft(), f:GetTop(), f:GetScale()
    if not (left and top) then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * s, top * s)
end

function Loot.SetScale(scale)
    local f = Loot.frame
    scale = GP.Clamp(scale, Loot.MIN_SCALE, Loot.MAX_SCALE)
    GP.db.window.lootScale = scale ~= 1 and scale or nil
    if not f then return end
    local left, top, old = f:GetLeft(), f:GetTop(), f:GetScale()
    f:SetScale(scale)
    if left and top then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * old / scale, top * old / scale)
    end
    savePos(f)
end

-- Cursor x at the start, then as it moves (screen pixels): the panel's
-- width follows the cursor, and its scale with it.
function Loot.StartResize(x)
    local f = Loot.frame
    if not f then return end
    pinTopLeft(f)
    local ui = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    Loot.sizing = { x = x / ui, scale = f:GetScale() }
end

function Loot.Resize(x)
    local z, f = Loot.sizing, Loot.frame
    if not (z and f) then return end
    local ui = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local width = Loot.WIDTH * z.scale + (x / ui - z.x)
    Loot.SetScale(width / Loot.WIDTH)
end

local function line(i)
    local f = frame()
    local r = f.lines[i]
    if r then return r end
    local skin = GP.Skin.Pick()
    r = CreateFrame("Button", nil, f)
    r:SetHeight(Loot.ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(15, 15)
    r.icon:SetPoint("LEFT", r, "LEFT", 14, 0)
    r.text = skin.Text(r, "small", "TEXT")
    r.gain = skin.Text(r, "small", "GOOD", "RIGHT")
    r.gain:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.gain:SetWidth(52)
    r.slot = skin.Text(r, "small", "LABEL", "RIGHT")
    r.slot:SetPoint("RIGHT", r.gain, "LEFT", -6, 0)
    r.slot:SetWidth(64)
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    r.text:SetPoint("RIGHT", r.slot, "LEFT", -4, 0)
    r.text:SetWordWrap(false)
    r:SetScript("OnEnter", function(self)
        if not self.ev then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local rec = self.ev.rec
        if rec.link and GameTooltip.SetHyperlink then GameTooltip:SetHyperlink(rec.link)
        elseif GameTooltip.SetItemByID then GameTooltip:SetItemByID(rec.id) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Shift-click: link it in chat (to ask your group for it).
    r:SetScript("OnClick", function(self)
        if self.ev and IsModifiedClick and IsModifiedClick("CHATLINK") and self.ev.rec.link and ChatEdit_InsertLink then
            ChatEdit_InsertLink(self.ev.rec.link)
            return
        end
        -- A quest's line: the map pin on whoever gives it.
        if self.pin and GP.Waypoint.CanSet(self.pin) then GP.UI.Waypoint(self.pin, self.pin.name) end
    end)
    f.lines[i] = r
    return r
end

local function qualityColor(q)
    local c = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 0.92, 0.92, 0.92
end

-- Fills the panel: the dungeon's name, then each boss and its items.
Loot.CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t"
Loot.DIM = 0.45

function Loot.Paint(instance, groups, n)
    Loot.groups = groups
    local f = frame()
    f.title:SetText("GearPath: " .. GP.Waypoint.PlaceName(instance))
    local y, used, shown = 34, 0, 0
    for _, g in ipairs(groups) do
        if shown >= Loot.MAX_ROWS then break end
        used = used + 1
        local h = line(used)
        h.ev = nil
        h.icon:Hide()
        h.slot:SetText("")
        h.gain:SetText("")
        h.text:ClearAllPoints()
        h.text:SetPoint("LEFT", h, "LEFT", 0, 0)
        h.text:SetPoint("RIGHT", h, "RIGHT", 0, 0)
        h.text:SetText(g.boss)
        h.text:SetTextColor(1, 0.82, 0)
        local done = Loot.BossDone(g)
        if done then
            h.gain:SetText(Loot.CHECK .. " " .. L["done"])
            h.gain:SetTextColor(0.6, 0.6, 0.6)
            h.text:ClearAllPoints()
            h.text:SetPoint("LEFT", h, "LEFT", 0, 0)
            h.text:SetPoint("RIGHT", h.gain, "LEFT", -4, 0)
        end
        h:SetAlpha(done and Loot.DIM or 1)
        -- A quest's line: a click puts the map pin on its giver.
        h.pin = g.quest
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y)
        h:SetPoint("RIGHT", f, "RIGHT", -12, 0)
        h:Show()
        y = y + Loot.ROW_H
        for _, ev in ipairs(g.items) do
            if shown >= Loot.MAX_ROWS then break end
            used = used + 1
            shown = shown + 1
            local r = line(used)
            r.ev = ev
            r.icon:SetTexture(ev.rec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.icon:Show()
            r.text:ClearAllPoints()
            r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
            r.text:SetPoint("RIGHT", r.slot, "LEFT", -4, 0)
            local got = Loot.state and Loot.state.got[ev.rec.id]
            r.text:SetText((got and (Loot.CHECK .. " ") or "") .. (ev.rec.name or "?"))
            r.text:SetTextColor(qualityColor(ev.rec.quality))
            r:SetAlpha((got or done) and Loot.DIM or 1)
            r.pin = nil
            r.slot:SetText(GP.Slots.Label(ev.slot) or "")
            r.gain:SetText(GP.UI.GainText(ev))
            local c = GP.Tooltip.Color(ev)
            if c then r.gain:SetTextColor(c[1], c[2], c[3]) end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y)
            r:SetPoint("RIGHT", f, "RIGHT", -12, 0)
            r:Show()
            y = y + Loot.ROW_H
        end
    end
    if n > shown then
        used = used + 1
        local m = line(used)
        m.ev = nil
        m.icon:Hide()
        m.slot:SetText("")
        m.gain:SetText("")
        m.text:ClearAllPoints()
        m.text:SetPoint("LEFT", m, "LEFT", 14, 0)
        m.text:SetPoint("RIGHT", m, "RIGHT", 0, 0)
        m:SetAlpha(1)
        m.pin = nil
        m.text:SetText(string.format(L["and %d more (see GearPath's window)"], n - shown))
        m.text:SetTextColor(0.6, 0.6, 0.6)
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y)
        m:SetPoint("RIGHT", f, "RIGHT", -12, 0)
        m:Show()
        y = y + Loot.ROW_H
    end
    for i = used + 1, #f.lines do
        f.lines[i].ev = nil
        f.lines[i]:Hide()
    end
    f.hide:ClearAllPoints()
    f.hide:SetPoint("TOPRIGHT", f, "TOPLEFT", Loot.WIDTH - 10, -(y + 6))
    f:SetHeight(y + 36)
    Loot.lines = used
end

function Loot.Close()
    Loot.closed = true
    if Loot.frame then Loot.frame:Hide() end
end

-- Shows the panel for the dungeon you're in (if it has anything for you).
-- quiet: no chat line when there's nothing.
function Loot.Show(force, quiet)
    local here = GP.Waypoint.Here()
    local instance = here.instance
    if not instance then
        if force then GP.Print("Dungeon loot: you're not in a dungeon or raid.") end
        return false
    end
    if not on() and not force then return false end
    if inCombat() then return false end
    local groups, n = Loot.Build(instance)
    if n == 0 then
        if not quiet then GP.Print("No upgrades for you drop in %s.", GP.Waypoint.PlaceName(instance)) end
        if Loot.frame then Loot.frame:Hide() end
        return false
    end
    local wasShown = Loot.frame and Loot.frame:IsShown()
    Loot.Paint(instance, groups, n)
    Loot.closed = nil
    -- A repaint (the gear list changed) doesn't restart its time on screen.
    if not wasShown then Loot.openedAt = GetTime and GetTime() or 0 end
    Loot.frame:Show()
    return true
end

-- ---------------------------------------------------------------------
-- When
-- ---------------------------------------------------------------------

-- In a dungeon the panel stays up between fights until you click Hide
-- (Koulta, Nov 9: it showed at the door "then never again"): it steps aside
-- while you fight and comes back when the fight ends. Hide closes it for
-- the visit; leaving and coming back is a new visit. Until the gear list
-- is ready, it waits for it.
function Loot.Refresh()
    local here = GP.Waypoint.Here()
    local instance = here.instance
    if instance ~= Loot.place then
        Loot.place, Loot.shownFor, Loot.closed = instance, nil, nil
        if not instance and Loot.frame then Loot.frame:Hide() end
        if instance then Loot.Visit(instance) end
    end
    if not instance or not on() or Loot.closed then return end
    if not GP.Score.results.all or #GP.Score.results.all == 0 then return end
    if inCombat() then
        if Loot.frame then Loot.frame:Hide() end
        return
    end
    -- The chat line for "nothing here" only the first time.
    local first = Loot.shownFor ~= instance
    Loot.shownFor = instance
    Loot.Show(false, not first)
end

local function soon() GP.Soon("dungeonloot", Loot.Refresh) end
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do GP.RegisterEvent(e, soon) end
GP.On("ScoresChanged", soon)
GP.On("HiddenChanged", soon)
GP.On("SettingChanged", function(key)
    if key == "dungeonLoot" then
        if not on() and Loot.frame then Loot.frame:Hide() end
        soon()
    end
end)

-- Deaths in the dungeon: a boss on the list is done. Forever's client
-- won't let addons listen to the combat log (registering for it is blocked:
-- the "GearPath has been blocked" box in 0.8.0's first test), so a boss
-- counts as dead when a unit you can see is (your target, focus, mouseover,
-- a boss frame), when you loot its corpse, or when its encounter ends.
local WATCHED = { target = true, focus = true, mouseover = true,
    boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true }

function Loot.CheckDead(unit)
    if not (Loot.place and unit and UnitExists and GP.Plain(UnitExists(unit))) then return false end
    if GP.Plain(UnitIsDead(unit)) ~= true then return false end
    local npc = GP.NpcID(UnitGUID(unit))
    if not npc then return false end
    Loot.Killed(GP.Plain(UnitName(unit)), npc)
    return true
end

GP.RegisterEvent("UNIT_HEALTH", function(_, unit)
    unit = GP.Plain(unit)
    if WATCHED[unit] then Loot.CheckDead(unit) end
end)
GP.RegisterEvent("PLAYER_TARGET_CHANGED", function() Loot.CheckDead("target") end)
GP.RegisterEvent("UPDATE_MOUSEOVER_UNIT", function() Loot.CheckDead("mouseover") end)

-- Looting a corpse: whoever it was is dead.
GP.RegisterEvent("LOOT_OPENED", function()
    if not (Loot.place and GetNumLootItems and GetLootSourceInfo) then return end
    for slot = 1, (GP.Plain(GetNumLootItems()) or 0) do
        local npc = GP.NpcID(GetLootSourceInfo(slot))
        if npc then Loot.Killed(nil, npc) end
    end
end)
GP.RegisterEvent("ENCOUNTER_END", function(_, _, name, _, _, success)
    if GP.Plain(success) == 1 then Loot.Killed(GP.Plain(name)) end
end)

-- Your own loot ("You receive loot: [item]."): checked on the list, and a
-- toast when it's an upgrade (UI/Toast.lua), anywhere.
local SELF_PATTERNS
local function selfPatterns()
    if SELF_PATTERNS then return SELF_PATTERNS end
    SELF_PATTERNS = {}
    for _, g in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
        "LOOT_ITEM_CREATED_SELF" }) do
        local t = rawget(_G, g)
        if type(t) == "string" then
            local p = GP.FormatPattern(t)
            if p then SELF_PATTERNS[#SELF_PATTERNS + 1] = "^" .. p .. "$" end
        end
    end
    if #SELF_PATTERNS == 0 then SELF_PATTERNS = { "^You receive loot: (.+)%.$", "^You receive item: (.+)%.$" } end
    return SELF_PATTERNS
end

function Loot.FromChat(msg)
    msg = GP.Plain(msg)
    if type(msg) ~= "string" then return nil end
    for _, p in ipairs(selfPatterns()) do
        local link = msg:match(p)
        if link then return GP.Items.IDFromLink(link), link end
    end
end

GP.RegisterEvent("CHAT_MSG_LOOT", function(_, msg)
    local id, link = Loot.FromChat(msg)
    if not id then return end
    Loot.Got(id)
    if GP.Toast then GP.Toast.Looted(id, link) end
end)

-- It steps aside for a fight and comes back after it (also when you zoned
-- in with a mob still on you, as in the cave before Wailing Caverns).
GP.RegisterEvent("PLAYER_REGEN_DISABLED", function()
    Loot.fighting = true
    if Loot.frame then Loot.frame:Hide() end
end)
GP.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    Loot.fighting = false
    soon()
end)

-- /gp loot: the panel again, back to its first spot and size.
GP.RegisterCommand("loot", "show this dungeon's upgrades for you again", function()
    GP.db.window.loot, GP.db.window.lootScale = nil, nil
    if Loot.frame then
        Loot.frame:SetScale(1)
        placeAt(Loot.frame)
    end
    Loot.Show(true, false)
end)
