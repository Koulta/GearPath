-- DungeonLoot: when you walk into a dungeon or raid, a small panel with its
-- drops that are upgrades for you, by boss, with how much better each is
-- than what you have on (the tooltip's +%). Koulta's idea, Nov 8.
--
-- Only real upgrades (the tooltips' "big enough" bar); nothing you need a
-- reputation or a rank for first, nothing hidden, no healer gear unless you
-- asked for it. Bosses in the journal's order where DungeonJournal is
-- installed, else the biggest upgrade first; trash and "any boss" last.
--
-- It never opens in combat: a pull closes it, and it closes itself after a
-- while unless your mouse is on it. /gp loot brings it back. Drag to move,
-- drag the corner to resize.
-- Off with "Dungeon loot" in Settings > Extras.

local _, GP = ...

local Loot = { shownFor = nil }
GP.Loot = Loot

local L = GP.L

Loot.WIDTH = 300
Loot.MAX_ROWS = 14        -- item lines at most (then "and N more")
Loot.CLOSE_AFTER = 20     -- seconds on screen before it closes itself
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

-- The upgrades that drop in the dungeon named `instance`:
-- { { boss = name, items = { ev, ... } }, ... } in order, and how many items.
function Loot.Build(instance)
    local groups, byBoss, seen, n = {}, {}, {}, 0
    if type(instance) ~= "string" or instance == "" then return groups, 0 end
    local Score, Way = GP.Score, GP.Waypoint
    local dungeonName
    for _, ev in ipairs(Score.results.all or {}) do
        local rec = ev.rec
        local good = rec and not seen[rec.id] and not ev.healerPass and ev.tier ~= "locked" and not ev.needs
            and Score.BigEnough(ev.delta or 0, ev.base)
        if good then
            for _, src in ipairs(ev.entry and ev.entry.sources or { ev.source }) do
                if src.kind == "drop" and not src.worldDrop and src.dungeon and Way.SameDungeon(src.dungeon, instance) then
                    local boss = src.bossName or src.name or "?"
                    local g = byBoss[boss]
                    if not g then
                        g = { boss = boss, items = {} }
                        byBoss[boss] = g
                        groups[#groups + 1] = g
                    end
                    g.items[#g.items + 1] = ev
                    seen[rec.id] = true
                    n = n + 1
                    dungeonName = dungeonName or src.dungeon
                    break
                end
            end
        end
    end
    local order = GP.Journal and GP.Journal.BossOrder and dungeonName and GP.Journal.BossOrder(dungeonName) or {}
    for _, g in ipairs(groups) do
        table.sort(g.items, function(a, b) return (a.delta or 0) > (b.delta or 0) end)
        g.best = g.items[1].delta or 0
    end
    table.sort(groups, function(a, b)
        local la, lb = lastGroup(a.boss), lastGroup(b.boss)
        if la ~= lb then return lb end
        local oa, ob = order[a.boss], order[b.boss]
        if oa and ob and oa ~= ob then return oa < ob end
        if (oa ~= nil) ~= (ob ~= nil) then return oa ~= nil end
        if a.best ~= b.best then return a.best > b.best end
        return a.boss < b.boss
    end)
    return groups, n
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
        end
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
function Loot.Paint(instance, groups, n)
    local f = frame()
    f.title:SetText("GearPath: " .. instance)
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
            r.text:SetText(ev.rec.name or "?")
            r.text:SetTextColor(qualityColor(ev.rec.quality))
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
        if not quiet then GP.Print("No upgrades for you drop in %s.", instance) end
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

-- Into a dungeon: once per visit (leaving and coming back is a new one).
-- Until the gear list is ready, it waits for it.
function Loot.Refresh()
    local here = GP.Waypoint.Here()
    local instance = here.instance
    if instance ~= Loot.place then
        Loot.place, Loot.shownFor, Loot.closed = instance, nil, nil
        if not instance and Loot.frame then Loot.frame:Hide() end
    end
    if not instance or not on() then return end
    if Loot.shownFor == instance or Loot.closed then
        -- Already shown this visit: keep it current if it's up.
        if Loot.frame and Loot.frame:IsShown() then Loot.Show(false, true) end
        return
    end
    if not GP.Score.results.all or #GP.Score.results.all == 0 then return end
    if inCombat() then return end
    Loot.shownFor = instance
    Loot.Show(false, false)
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

-- A pull closes it for the visit.
GP.RegisterEvent("PLAYER_REGEN_DISABLED", function()
    Loot.fighting = true
    if Loot.frame and Loot.frame:IsShown() then Loot.Close() end
end)
GP.RegisterEvent("PLAYER_REGEN_ENABLED", function() Loot.fighting = false end)

-- And by itself after a while, unless your mouse is on it.
function Loot.Tick()
    local f = Loot.frame
    if not (f and f:IsShown() and Loot.openedAt) then return end
    if f.IsMouseOver and f:IsMouseOver() then
        Loot.openedAt = GetTime()
        return
    end
    if GetTime() - Loot.openedAt >= Loot.CLOSE_AFTER then Loot.Close() end
end
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(1, function() GP.SafeCall(Loot.Tick) end)
end

-- /gp loot: the panel again, back to its first spot and size.
GP.RegisterCommand("loot", "show this dungeon's upgrades for you again", function()
    GP.db.window.loot, GP.db.window.lootScale = nil, nil
    if Loot.frame then
        Loot.frame:SetScale(1)
        placeAt(Loot.frame)
    end
    Loot.Show(true, false)
end)
