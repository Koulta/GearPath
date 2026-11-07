-- Window: the GearPath window, its tabs (Character, Route, Browse,
-- Settings) and what every page shares: how a source reads, how a gain
-- reads, item tooltips and what a click on an item does.
--
-- The window is built the first time it's opened, in the look picked then
-- (Skin.lua). Pages register with UI.RegisterPage(id, def):
--   def = { text = "Tab text", order = n, Build = fn(frame), Fill = fn(frame) }

local _, GP = ...

local UI = { PAGES = {}, ORDER = {} }
GP.UI = UI
local L = GP.L

UI.W, UI.H = 900, 580

function UI.RegisterPage(id, def)
    def.id = id
    UI.PAGES[id] = def
    UI.ORDER[#UI.ORDER + 1] = def
    table.sort(UI.ORDER, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

-- ---------------------------------------------------------------------
-- Words for sources and gains
-- ---------------------------------------------------------------------

-- How to get it, in a line. long: with the giver, and where the map pin
-- goes (a dungeon's entrance, a chain's first quest giver) with its spot.
--   Quest: Rig Wars [35] (Gnomeregan), Orgrimmar
--   Quest: Horde Presence [29] (chain of 2, starts with The Runed Scroll), The Barrens
--   Drop: Electrocutioner 6000 (Elite), Gnomeregan
--   Vendor: Kelm Hargunth, The Barrens
function UI.Describe(src, long)
    if not src then return L["Where to get it isn't known yet"] end
    if src.kind == "bags" then return L["In your bags: put it on"] end
    local P = GP.Waypoint
    local place = P.PlaceOf(src)
    local where, t
    if src.kind == "entrance" then
        return string.format(L["%s entrance, %s"], src.dungeon or "?", src.zone or "?")
    elseif src.kind == "quest" then
        t = string.format(L["Quest: %s"], src.name or "?")
        if src.level and src.level > 0 then t = t .. " [" .. src.level .. "]" end
        -- A dungeon's quest is picked up outside: the dungeon in brackets,
        -- the place after it is where you get the quest.
        if src.dungeon then t = t .. " (" .. src.dungeon .. ")" end
        if src.chain and src.chain[1] then
            local inner = string.format(L["chain of %d, starts with %s"], src.chainLength or (#src.chain + 1),
                src.chain[1].name or "?")
            if long and src.chainStart and src.chainStart.giver then inner = inner .. ", " .. string.format(L["from %s"], src.chainStart.giver) end
            t = t .. " (" .. inner .. ")"
        elseif long and src.giver then
            t = t .. " " .. string.format(L["from %s"], src.giver)
        end
        if src.inLog then t = t .. ", " .. L["in your quest log"] end
        if place and place.kind ~= "entrance" then where = place.zone end
        where = where or (not src.dungeon and src.zone) or nil
        if not where and src.dungeon and place and place.kind == "entrance" then where = L["starts inside the dungeon"] end
    elseif src.kind == "vendor" then
        t = string.format(L["Vendor: %s"], src.name or "?")
        where = src.dungeon or src.zone
    elseif src.kind == "drop" then
        if src.worldDrop then
            return L["World drop: random mobs"] .. (src.count and (" (" .. string.format(L["%d kinds"], src.count) .. ")") or "")
        end
        t = string.format(L["Drop: %s"], src.name or "?")
        if src.rank then t = t .. " (" .. L[src.rank] .. ")" end
        where = src.dungeon or src.zone
    elseif src.kind == "craft" then
        -- Crafting: Tailoring (you know the recipe)
        -- Crafting: Tailoring, recipe from Victor Ward, Undercity
        t = string.format(L["Crafting: %s"], src.profession or src.name or "?")
        if src.known then return t .. " (" .. L["you know the recipe"] .. ")" end
        if src.trainer then t = t .. ", " .. string.format(L["recipe from %s"], src.trainer) end
        where = src.zone
    elseif src.kind == "object" then
        if src.randomChest then
            if src.count and src.count > 1 then
                return string.format(L["Random chest loot (%d kinds of chest, like %s)"], src.count, src.name or "?")
            end
            if not src.name then return L["Random chests (spawns all over)"] end
            return string.format(L["Random chests: %s (spawns all over)"], src.name)
        end
        t = string.format(L["Found in: %s"], src.name or "?")
        where = src.dungeon or src.zone
    else
        t = src.name or "?"
        where = src.dungeon or src.zone
    end
    if where and where ~= "" then
        t = t .. ", " .. where
    elseif not (src.kind == "quest" and src.startItem) then   -- an item that starts a quest says where itself
        t = t .. (long and (" (" .. L["location not in the database yet"] .. ")") or (", " .. L["location unknown"]))
    end
    -- Only other players say so (the database doesn't): never passed off as fact.
    if src.shared and not src.dbKnown then t = t .. " (" .. L["reported by other players"] .. ")" end
    if long and src.kind == "quest" and not src.giver and not src.startItem and not (src.chain and src.chainStart and src.chainStart.giver) then
        t = t .. ". " .. L["Who starts it isn't in the database yet"]
    end
    if long and place and place.x and place.y then
        if place.kind == "entrance" then
            t = t .. ". " .. string.format(L["Entrance: %s (%.1f, %.1f)"], place.zone or "?", place.x * 100, place.y * 100)
        else
            t = t .. string.format(" (%.1f, %.1f)", place.x * 100, place.y * 100)
        end
    end
    -- Out in the other faction's home zones (Westfall for a Horde player):
    -- why it's Worth chasing and not Best now. After the coordinates, so
    -- the zone's (x, y) never sits beside another bracket.
    if GP.Sources.EnemyLand and GP.Sources.EnemyLand(src) then
        local f = (GP.player or GP.PlayerInfo()).faction
        t = t .. ", " .. L[f == "Horde" and "Alliance territory" or "Horde territory"]
    end
    return t
end

-- The gain as a short text and a text role: "+12%" (green: best now;
-- amber: worth chasing), "4x" when it's over three times as good, "new"
-- for a slot with nothing in it, "+12 pts" over a worn item worth 0 points.
function UI.GainText(ev)
    local d = ev.delta or 0
    local text
    if ev.pct then
        if math.abs(ev.pct) < 1 then
            text = d > 0 and "+<1%" or (d < 0 and "-<1%" or L["same"])
        elseif ev.pct >= 200 then
            -- Over what's worn now that's barely worth anything, a percent
            -- runs to the thousands; "4x" says the same and reads true.
            text = string.format("%dx", GP.Round(1 + ev.pct / 100))
        else
            text = string.format("%+d%%", GP.Round(ev.pct))
        end
    elseif d > 0 and not (GP.Score and GP.Score.Worn and GP.Score.Worn(ev.slot)) then
        text = "new"   -- nothing worn there now
    else
        -- Worn but worth 0 points to you (no percent to give): the points.
        text = string.format(L["%+.0f pts"], d)
    end
    local role = "OFF"
    if ev.tier == "primary" then role = "GOOD"
    elseif ev.tier == "secondary" then role = "WARN"
    elseif d < 0 then role = "BAD" end
    return text, role
end

-- The gain in a few words, for chat lines and toasts: "+12% Chest", or
-- "fills your empty Chest slot".
function UI.GainLine(slot, delta, pct)
    local label = GP.Slots.Label(slot)
    local gain = UI.GainText({ slot = slot, delta = delta, pct = pct, tier = "primary" })
    if gain == "new" then return string.format(L["fills your empty %s slot"], label) end
    return gain .. " " .. label
end

UI.TIER_TEXT = { primary = "Best now", secondary = "Worth chasing", locked = "Needs something first" }

-- ---------------------------------------------------------------------
-- Content: what kind of play an item comes from. One filter, shared by
-- every tab (the slot lists and arrows, the route, Browse): each kind can
-- be ticked or not; everything is ticked to begin with.
-- ---------------------------------------------------------------------

UI.CONTENT_KEYS = { "quest", "dungeon", "vendor", "drop", "world", "bags", "pvp", "rep", "craft" }
UI.CONTENT_LABELS = {
    quest = "Quests", dungeon = "Dungeons", vendor = "Vendors",
    drop = "Mob drops & rares", world = "World drops & chests", bags = "In your bags",
    pvp = "PvP rank", rep = "Reputation", craft = "Professions",
}

local PVP_RANKS = {}
for _, r in ipairs({ "Private", "Corporal", "Sergeant", "Master Sergeant", "Sergeant Major", "Knight",
    "Knight-Lieutenant", "Knight-Captain", "Knight-Champion", "Lieutenant Commander", "Commander", "Marshal",
    "Field Marshal", "Grand Marshal", "Scout", "Grunt", "Senior Sergeant", "First Sergeant", "Stone Guard",
    "Blood Guard", "Legionnaire", "Centurion", "Champion", "Lieutenant General", "General", "Warlord",
    "High Warlord" }) do
    PVP_RANKS[r] = true
end
-- And the game's own names for them, in the client's language.
if GetPVPRankInfo then
    for rank = 5, 18 do
        for faction = 0, 1 do
            local ok, name = pcall(GetPVPRankInfo, rank, faction)
            name = ok and GP.Plain(name) or nil
            if type(name) == "string" and name ~= "" then PVP_RANKS[name] = true end
        end
    end
end

-- The content an item belongs to.
function UI.ContentOf(ev)
    local needs = ev.needs
    if needs then
        if PVP_RANKS[needs] then return "pvp" end
        if needs:find("%(%d+%)") then return "craft" end
        return "rep"
    end
    local src = ev.source
    if not src then return "world" end
    if src.kind == "bags" then return "bags" end
    if src.kind == "craft" then return "craft" end
    if src.worldDrop then return "world" end
    if src.dungeon then return "dungeon" end
    if src.kind == "quest" then return "quest" end
    if src.kind == "vendor" then return "vendor" end
    if src.kind == "drop" then return "drop" end
    return "world"
end

-- The kinds left out: { quest = true, ... }.
function UI.ContentOff()
    local t = GP.Setting("contentOff")
    if type(t) ~= "table" then
        t = {}
        GP.db.settings.contentOff = t
    end
    return t
end

function UI.ContentOn(key) return not UI.ContentOff()[key] end
function UI.ContentFiltered() return next(UI.ContentOff()) ~= nil end
function UI.ContentMatches(ev) return not UI.ContentOff()[UI.ContentOf(ev)] end

-- A short line for the picker: "Everything", "Quests, Dungeons",
-- "All but PvP rank", "5 kinds".
function UI.ContentSummary()
    local on, off = {}, {}
    for _, k in ipairs(UI.CONTENT_KEYS) do
        if UI.ContentOn(k) then on[#on + 1] = UI.CONTENT_LABELS[k] else off[#off + 1] = UI.CONTENT_LABELS[k] end
    end
    if #off == 0 then return L["Everything"] end
    if #on == 0 then return L["Nothing"] end
    if #on <= 2 then return table.concat(on, ", ") end
    if #off == 1 then return string.format(L["All but %s"], off[1]) end
    return string.format(L["%d of %d kinds"], #on, #UI.CONTENT_KEYS)
end

-- A text that changes whenever the filter does (lists keep their scroll
-- only while it's the same).
function UI.ContentKey()
    local t = {}
    for _, k in ipairs(UI.CONTENT_KEYS) do t[#t + 1] = UI.ContentOn(k) and "1" or "0" end
    return table.concat(t)
end

local function contentChanged()
    GP.Fire("SettingChanged", "contentOff")
    GP.Soon("content", UI.Refresh)
end

function UI.SetContent(key, on)
    UI.ContentOff()[key] = (not on) or nil
    contentChanged()
end

function UI.SetAllContent(on)
    local off = UI.ContentOff()
    for _, k in ipairs(UI.CONTENT_KEYS) do off[k] = (not on) or nil end
    contentChanged()
end

-- The "Show:" picker every tab carries: a list of switches.
function UI.ContentDropdown(parent, width)
    return GP.MultiDropdown(parent, {
        width = width or 220, height = 22, keys = UI.CONTENT_KEYS, labels = UI.CONTENT_LABELS,
        prefix = L["Show:"] .. " ", summary = UI.ContentSummary,
        isOn = UI.ContentOn, setOn = UI.SetContent, setAll = UI.SetAllContent,
    })
end

-- A list with only the ticked content.
function UI.Filter(list)
    if not UI.ContentFiltered() then return list end
    local out = {}
    for _, ev in ipairs(list) do
        if UI.ContentMatches(ev) then out[#out + 1] = ev end
    end
    return out
end

-- How lists can be sorted (the slot panel and Browse).
local function ilvl(ev) return ev.rec.ilvl or 0 end
UI.SORT_KEYS = { "ilvl", "gain", "level", "name" }
UI.SORT_LABELS = { ilvl = "item level", gain = "biggest gain", level = "required level", name = "name" }
UI.SORTS = {
    ilvl = function(a, b)
        if ilvl(a) ~= ilvl(b) then return ilvl(a) > ilvl(b) end
        return (a.delta or 0) > (b.delta or 0)
    end,
    gain = function(a, b)
        if (a.delta or 0) ~= (b.delta or 0) then return (a.delta or 0) > (b.delta or 0) end
        return ilvl(a) > ilvl(b)
    end,
    level = function(a, b)
        if (a.req or 0) ~= (b.req or 0) then return (a.req or 0) < (b.req or 0) end
        return ilvl(a) > ilvl(b)
    end,
    name = function(a, b) return (a.rec.name or "") < (b.rec.name or "") end,
}

-- A sorted copy (the scorer's own lists stay in gain order for the route).
function UI.Sorted(list, key)
    local out = {}
    for i, ev in ipairs(list) do out[i] = ev end
    table.sort(out, UI.SORTS[key] or UI.SORTS.ilvl)
    return out
end

-- ---------------------------------------------------------------------
-- Items: tooltip, clicks, trying on, map pins
-- ---------------------------------------------------------------------

local function linkOf(ev)
    return (ev.entry and ev.entry.bagLink) or ev.rec.link
end

function UI.ItemTooltip(owner, ev)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local link = linkOf(ev)
    -- The hook adds GearPath's lines and the click hints for this item,
    -- even when the game rebuilds the tooltip (comparisons, item data).
    UI.hintFor = ev.rec.id
    UI.forceTooltip = true
    if link then
        GameTooltip:SetHyperlink(link)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(ev.rec.id)
    end
    if GP.Tooltip and not GP.Tooltip.hooked then GP.Tooltip.Add(GameTooltip, ev.rec.id) end
    GameTooltip:Show()
end

function UI.HideItemTooltip()
    UI.hintFor = nil
    UI.forceTooltip = false
    GameTooltip:Hide()
end

function UI.Waypoint(src, title)
    if src then GP.SafeCall(GP.Waypoint.Set, src, title) end
end

-- Whether GearPath's own model is on screen (the Character tab).
function UI.ModelShown()
    return UI.model ~= nil and UI.model:IsVisible() and true or false
end

-- Tries an item on GearPath's model (Character tab only; the game's
-- dressing room is Ctrl-click, as on any item in the game). With its
-- evaluation, it's kept as tried on in its slot (UI.tried), so the stats
-- under the model show what it would change.
function UI.TryOn(link, ev)
    local m = UI.model
    if not (link and m and m:IsVisible()) then return false end
    if pcall(m.TryOn, m, link) then
        UI.trying = true
        if ev and ev.slot and ev.rec then
            UI.tried = UI.tried or {}
            local t = UI.tried
            t[ev.slot] = ev
            -- A two-hander and an off hand don't go on together.
            if ev.slot == "MainHandSlot" and ev.rec.equipLoc == "INVTYPE_2HWEAPON" then
                t.SecondaryHandSlot = nil
            elseif ev.slot == "SecondaryHandSlot" and t.MainHandSlot and t.MainHandSlot.rec.equipLoc == "INVTYPE_2HWEAPON" then
                t.MainHandSlot = nil
            end
        end
        if UI.OnTryOn then UI.OnTryOn(ev) end
        return true
    end
    return false
end

-- ---------------------------------------------------------------------
-- Putting on gear from your bags (the Character tab's "Put it on")
-- ---------------------------------------------------------------------

-- Where an item sits in your bags: bag, slot, link, and whether it's
-- bound to you already (nil if the game doesn't say). nil if it isn't there.
function UI.FindInBags(id)
    local C = C_Container
    if not (C and C.GetContainerNumSlots) then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (GP.Plain(C.GetContainerNumSlots(bag)) or 0) do
            local link, bound
            local info = C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
            if type(info) == "table" then
                link, bound = GP.Plain(info.hyperlink), GP.Plain(info.isBound)
            end
            if not link and C.GetContainerItemLink then link = GP.Plain(C.GetContainerItemLink(bag, slot)) end
            if type(link) == "string" and GP.Items.IDFromLink(link) == id then
                return bag, slot, link, bound
            end
        end
    end
end

-- Whether putting it on binds it to you: "Binds when equipped", not bound yet.
function UI.BindsWhenWorn(id, bound)
    if bound == true then return false end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return false end
    local ok, bind = pcall(function() return select(14, get(id)) end)
    return ok and GP.Plain(bind) == 2      -- 2: binds when equipped
end

-- Whether you can wear it right now (class, level, needs); unlike the
-- lists, healer gear you tried on yourself counts.
local function wearableNow(rec, slotKey)
    local level = (GP.player and GP.player.level) or UnitLevel("player") or 1
    if (rec.reqLevel or 0) > level or rec.needs then return false end
    -- A weapon skill, armor or Dual Wield still to learn: the game won't put it on.
    if GP.Training and GP.Training.Need(rec, slotKey) then return false end
    if rec.classes and not rec.classes[select(2, UnitClass("player"))] and not rec.classes[UnitClass("player")] then return false end
    return GP.Classes.CanUse(rec.classID, rec.subClassID, rec.equipLoc, nil, level) == true
end

-- The items tried on that are in your bags and wearable now, by slot:
-- { ev, bag, slot, link, binds, slotID }.
function UI.TriedFromBags()
    local out = {}
    for key, ev in pairs(UI.tried or {}) do
        local s = GP.Slots.BY_KEY[key]
        if s and ev.rec and wearableNow(ev.rec, key) then
            local bag, slot, link, bound = UI.FindInBags(ev.rec.id)
            if bag then
                out[#out + 1] = { ev = ev, key = key, bag = bag, slot = slot, link = link, slotID = s.id,
                    binds = UI.BindsWhenWorn(ev.rec.id, bound) }
            end
        end
    end
    table.sort(out, function(a, b) return a.slotID < b.slotID end)
    return out
end

function UI.InCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    return UnitAffectingCombat ~= nil and GP.Plain(UnitAffectingCombat("player")) == true
end

-- Puts on the items tried on from your bags, each in the slot it was tried
-- on in. Gear that binds when equipped gets the game's own "this will bind
-- it to you" question first; the game asks one at a time, so only one such
-- item is sent per click (after the others), and the button stays for the
-- rest. Returns how many were sent to the game, and how many are left.
function UI.PutOn()
    local list = UI.TriedFromBags()
    if #list == 0 then return 0, 0 end
    if UI.InCombat() then
        GP.Print("Gear can't be changed in combat: put it on when the fight is over.")
        return 0, #list
    end
    local equip = (C_Item and C_Item.EquipItemByName) or EquipItemByName
    if not equip then return 0, #list end
    if ClearCursor then ClearCursor() end
    local n, binding = 0, nil
    for _, e in ipairs(list) do
        if e.binds then
            binding = binding or e
        elseif pcall(equip, e.link, e.slotID) then
            n = n + 1
        end
    end
    local left = 0
    for _, e in ipairs(list) do if e.binds and e ~= binding then left = left + 1 end end
    if binding then
        if ClearCursor then ClearCursor() end
        if pcall(equip, binding.link, binding.slotID) then n = n + 1 else left = left + 1 end
    end
    if left > 0 then
        -- What was sent comes off the tried-on list; the rest stays for the next click.
        for _, e in ipairs(list) do
            if UI.tried and (not e.binds or e == binding) then UI.tried[e.key] = nil end
        end
        GP.Print(GP.Count(left, "%d more item binds when you put it on: click Put it on again for it.",
            "%d more items bind when you put them on: click Put it on again for each."))
    end
    return n, left
end

-- ---------------------------------------------------------------------
-- A small box for text to copy (the report, your weights) or to paste
-- (someone else's weights), in the current look.
-- opts: title, note, text (selected, to copy with Ctrl+C), and for a paste
-- box action = { label, fn(text) -> ok, message }.
-- ---------------------------------------------------------------------

local box

local function buildBox(skin)
    local f = skin.Popup(UIParent)
    f.skin = skin
    f:SetSize(460, 136)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f.title = skin.Text(f, "head", "TITLE", "LEFT")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    f.note = skin.Text(f, "small", "LABEL", "LEFT")
    f.note:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.note:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    f.note:SetWordWrap(true)
    f.input = skin.Input(f, { width = 428, height = 24 })
    f.input:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -64)
    if f.input.SetMaxLetters then f.input:SetMaxLetters(0) end
    f.close = skin.Button(f, L["Close"], 90, 22)
    f.close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.action = skin.Button(f, L["Apply"], 90, 22)
    f.action:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.action:SetScript("OnClick", function()
        local fn = f.onAction
        if not fn then return end
        local ok, msg = fn(f.input:GetText() or "")
        if ok then
            f:Hide()
        elseif msg then
            f.note:SetText("|cffff5050" .. msg .. "|r")
        end
    end)
    -- A copy box can't be typed in: whatever is typed, the text comes back.
    f.input:HookScript("OnTextChanged", function(self, user)
        if f.copy and user then
            self:SetText(f.copy)
            if self.HighlightText then self:HighlightText() end
        end
    end)
    f.input:HookScript("OnEditFocusGained", function(self)
        if f.copy and self.HighlightText then self:HighlightText() end
    end)
    f.input:HookScript("OnEscapePressed", function() f:Hide() end)
    f.input:HookScript("OnEnterPressed", function()
        if f.onAction then f.action:Click() else f:Hide() end
    end)
    f:Hide()
    return f
end

function UI.TextBox(opts)
    local skin = GP.Skin and GP.Skin.current
    if not skin then return nil end
    if not box or box.skin ~= skin then
        if box then box:Hide() end
        box = buildBox(skin)
    end
    local f = box
    f.title:SetText(opts.title or GP.TITLE)
    f.note:SetText(opts.note or "")
    f.copy = opts.text
    f.onAction = opts.action and opts.action.fn or nil
    f.input:SetText(opts.text or "")
    if opts.action then
        f.action.SetLabel(opts.action.label or L["Apply"])
        f.action:Show()
    else
        f.action:Hide()
    end
    f:Show()
    if f.input.SetFocus then f.input:SetFocus() end
    if opts.text and f.input.HighlightText then f.input:HighlightText() end
    if f.input.SetCursorPosition and not opts.text then f.input:SetCursorPosition(0) end
    return f
end

-- A click on an item row. Shift (link) and Ctrl (dressing room) do what
-- they do on any item in the game. On the Character tab a click tries it
-- on the model; on Route and Browse a click puts the map pin on where you
-- get it (as the row's pin button does), so nothing opens by surprise.
function UI.ItemClick(ev, button)
    local link = linkOf(ev)
    if link and IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
        if pcall(HandleModifiedItemClick, link) then return end
    end
    if button == "LeftButton" and UI.ModelShown() then
        UI.TryOn(link, ev)
        return
    end
    if ev.source and GP.Waypoint.CanSet(ev.source) then UI.Waypoint(ev.source, ev.rec.name) end
end

-- What the clicks on an item row do, for its tooltip (a controller's
-- buttons while one drives the window).
function UI.ClickHint(ev)
    local pin = ev and ev.source and GP.Waypoint.CanSet(ev.source)
    if UI.Pad and UI.Pad.on then
        if UI.ModelShown() then return pin and L["A: try it on.  X: map pin."] or L["A: try it on."] end
        return pin and L["A: map pin."] or L["No map pin: where it is isn't in the database yet."]
    end
    if UI.ModelShown() then
        return pin and L["Click: try it on.  Right-click: map pin.  Ctrl-click: dressing room.  Shift-click: link."]
            or L["Click: try it on.  Ctrl-click: dressing room.  Shift-click: link."]
    end
    return pin and L["Click: map pin.  Ctrl-click: dressing room.  Shift-click: link."]
        or L["No map pin: where it is isn't in the database yet.  Ctrl-click: dressing room.  Shift-click: link."]
end

-- ---------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------

function UI.StatusText()
    local S = GP.Sources
    if S.status == "scanning" then return L["Reading the gear database..."] end
    if S.status == "loading" then return string.format(L["Loading item details (%d left)..."], GP.Items.Pending()) end
    if S.status == "idle" then return L["Getting ready..."] end
    local r = GP.Score.results
    local now, chase = r.primary or 0, r.secondary or 0
    -- With some kinds unticked under Show:, count what the lists show
    -- (launch night: "7 to get now" over an empty Best now).
    if UI.ContentFiltered() then
        now, chase = 0, 0
        for _, ev in ipairs(r.all or {}) do
            if ev.tier and UI.ContentMatches(ev) then
                if ev.tier == "primary" then now = now + 1 elseif ev.tier == "secondary" then chase = chase + 1 end
            end
        end
    end
    local t = string.format(L["%d to get now, %d worth chasing"], now, chase)
    if S.status == "nodb" then t = t .. "  |  " .. L["QuestieDB not found"] end
    if GP.Check and GP.Check.lastAll then t = t .. "  |  " .. string.format(L["checked %s"], GP.Check.Ago(GP.Check.lastAll)) end
    return t
end

-- The window's title, with the version in grey after it ("GearPath v0.7.6").
function UI.WindowTitle()
    local v = GP.VERSION
    if not v or v == "" then return GP.TITLE end
    if v:match("^%d") then v = "v" .. v end
    return GP.TITLE .. "  |cff9d9d9d" .. v .. "|r"
end

function UI.UpdateSub()
    if not UI.frame then return end
    local p = GP.PlayerInfo()
    local name = GP.Plain(UnitName("player")) or ""
    local className = GP.Plain(UnitClass("player")) or ""
    -- The spec too, for classes with more than one: "level 30 Affliction Warlock".
    if GP.Classes and #GP.Classes.Specs() > 1 then className = L[GP.Classes.Spec().name or ""] .. " " .. className end
    UI.skin.SetTitle(UI.frame, UI.WindowTitle(),
        string.format(L["%s, level %d %s"], name, p.level or 1, className) .. "  |  " .. UI.StatusText())
    -- While the database is read the line counts down by itself.
    local S = GP.Sources
    if (S.status == "scanning" or S.status == "loading" or S.status == "idle") and UI.frame:IsShown() and not UI.ticking then
        UI.ticking = true
        C_Timer.After(1, function()
            UI.ticking = false
            UI.UpdateSub()
        end)
    end
end

-- Fills the page shown now (and the line under the title).
function UI.Refresh()
    if not UI.frame then return end
    UI.UpdateSub()
    local def = UI.PAGES[UI.current]
    if def and def.Fill and def.frame and def.frame:IsShown() then GP.SafeCall(def.Fill, def.frame) end
end

function UI.Show(id, noFill)
    local def = UI.PAGES[id] or UI.ORDER[1]
    if not def then return end
    for _, d in ipairs(UI.ORDER) do
        if d ~= def and d.frame then d.frame:Hide() end
    end
    UI.current = def.id
    def.frame:Show()
    UI.skin.PickTab(UI.frame, def.id)
    if not noFill and def.Fill then GP.SafeCall(def.Fill, def.frame) end
end

local function build()
    local skin = GP.Skin.Pick()
    UI.skin = skin
    -- Its size: what you last dragged it to (never under the made size).
    local s = GP.db.window.size
    local w, h = UI.W, UI.H
    if type(s) == "table" and type(s[1]) == "number" and type(s[2]) == "number" then
        w, h = math.max(UI.W, s[1]), math.max(UI.H, s[2])
    end
    local f = skin.Window({ name = "GearPathFrame", w = w, h = h, minW = UI.W, minH = UI.H, title = UI.WindowTitle(),
        sized = function(nw, nh) GP.db.window.size = nw and { math.floor(nw + 0.5), math.floor(nh + 0.5) } or nil end })
    UI.frame = f
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "GearPathFrame") end
    local tabs = {}
    for _, def in ipairs(UI.ORDER) do
        tabs[#tabs + 1] = { id = def.id, text = L[def.text] }
        local page = CreateFrame("Frame", nil, f.body)
        page:SetAllPoints(f.body)
        page:Hide()
        def.frame = page
        GP.SafeCall(def.Build, page)
    end
    skin.Tabs(f, tabs, function(id) UI.Show(id) end)
    UI.Pad.Attach(f)
end

function UI.Toggle(page)
    if not UI.frame then
        GP.SafeCall(build)
        if not UI.frame then return end
    end
    local f, skin = UI.frame, UI.skin
    if skin.IsOpen(f) then
        if not page or page == UI.current then
            skin.Close(f)
        else
            UI.Show(page)
        end
        return
    end
    UI.Show(page or UI.current or (UI.ORDER[1] and UI.ORDER[1].id), true)
    skin.Open(f)
    UI.Refresh()
end

function UI.SetScale(scale)
    if UI.frame and UI.skin.SetScale then UI.skin.SetScale(UI.frame, scale) end
end

-- Kept up to date while it's open.
local function refreshSoon()
    if UI.frame and UI.frame:IsShown() then GP.Soon("ui", UI.Refresh) end
end
GP.On("ScoresChanged", refreshSoon)
GP.On("SourcesChanged", function()
    if UI.frame and UI.frame:IsShown() then GP.Soon("uisub", UI.UpdateSub) end
end)
GP.On("LevelChanged", refreshSoon)

-- ---------------------------------------------------------------------
-- Controllers. With the game's gamepad mode on and the window open: the
-- D-pad moves through the list (on the Character tab, left and right go
-- through the slots; on Settings it scrolls), A clicks, X is the
-- right-click (the map pin on the Character tab), Y puts on what you
-- tried on (or takes it off), B closes, and the shoulder buttons change
-- tab. With ConsolePort, its own cursor drives the window instead.
-- ---------------------------------------------------------------------

local Pad = { on = false }
UI.Pad = Pad

function Pad.Enabled()
    if ConsolePort then return false end
    if C_GamePad and C_GamePad.IsEnabled then
        local ok, enabled = pcall(C_GamePad.IsEnabled)
        if ok and GP.Plain(enabled) == true then return true end
    end
    local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not getCVar then return false end
    local ok, v = pcall(getCVar, "GamePadEnable")
    v = ok and GP.Plain(v) or nil
    return v == "1" or v == 1 or v == true
end

-- The list the D-pad moves through on the tab that's open.
function Pad.List()
    local id = UI.current
    if id == "plan" then return UI.Plan and UI.Plan.list end
    if id == "browse" then return UI.Browse and UI.Browse.list end
    if id == "doll" then return UI.SlotPanel and UI.SlotPanel.list end
end

-- The focused row's tooltip, as a mouse over it would show.
local function showTip(list)
    UI.HideItemTooltip()
    local row = list and list:FocusRow()
    local enter = row and row:GetScript("OnEnter")
    if enter then enter(row) end
end

function Pad.Move(step)
    local list = Pad.List()
    if list then
        if list:MoveFocus(step) then showTip(list) end
        return
    end
    local sf = UI.current == "settings" and UI.Settings and UI.Settings.sf
    if sf then
        local range = sf:GetVerticalScrollRange() or 0
        sf:SetVerticalScroll(GP.Clamp((sf:GetVerticalScroll() or 0) + step * 60, 0, range))
    end
end

-- Left and right: through the slots on the Character tab ("Near you"
-- comes before the first), a screenful at a time elsewhere.
function Pad.Side(step)
    if UI.current == "doll" then
        local S, order = GP.Slots, {}
        for _, group in ipairs({ S.LEFT, S.RIGHT, S.BOTTOM }) do
            for _, k in ipairs(group) do order[#order + 1] = k end
        end
        local at = 0
        for i, k in ipairs(order) do if k == UI.selectedSlot then at = i end end
        at = (at + step) % (#order + 1)
        UI.HideItemTooltip()
        UI.SelectSlot(order[at])
        return
    end
    local list = Pad.List()
    if list then
        for _ = 1, 6 do list:MoveFocus(step) end
        showTip(list)
    end
end

-- A (LeftButton) and X (RightButton) on the focused row.
function Pad.Click(button)
    local list = Pad.List()
    local row = list and list:FocusRow()
    local click = row and row:GetScript("OnClick")
    if not click then return end
    click(row, button)
    if list.focus then showTip(list) end
end

function Pad.PutOnOrTakeOff()
    local D = UI.Doll
    if UI.current ~= "doll" or not D then return end
    if D.putOn and D.putOn:IsShown() then D.putOn:Click("LeftButton")
    elseif D.undo and D.undo:IsShown() then D.undo:Click("LeftButton") end
end

function Pad.Tab(step)
    local n = #UI.ORDER
    if n == 0 then return end
    local at = 1
    for i, d in ipairs(UI.ORDER) do if d.id == UI.current then at = i end end
    UI.HideItemTooltip()
    UI.Show(UI.ORDER[(at - 1 + step) % n + 1].id)
end

local function close()
    if UI.frame and UI.skin then UI.skin.Close(UI.frame) end
end

Pad.ACTIONS = {
    PADDUP = function() Pad.Move(-1) end,
    PADDDOWN = function() Pad.Move(1) end,
    PADDLEFT = function() Pad.Side(-1) end,
    PADDRIGHT = function() Pad.Side(1) end,
    PAD1 = function() Pad.Click("LeftButton") end,
    PAD3 = function() Pad.Click("RightButton") end,
    PAD4 = Pad.PutOnOrTakeOff,
    PAD2 = close,
    PADBACK = close,
    PADFORWARD = close,
    PADLSHOULDER = function() Pad.Tab(-1) end,
    PADRSHOULDER = function() Pad.Tab(1) end,
}

-- The window takes the controller's buttons only while it's open (and
-- gives them back when it closes: B, Back or Start always close it).
function Pad.Update()
    local f = UI.frame
    if not (f and f.EnableGamePadButton) then return end
    local want = f:IsShown() and Pad.Enabled() or false
    if want == Pad.on then return end
    -- Not in combat: a blocked call doesn't raise an error (pcall can't
    -- tell), it just fails. Tried again when the fight is over.
    if InCombatLockdown and InCombatLockdown() then
        Pad.pending = true
        return
    end
    if pcall(f.EnableGamePadButton, f, want) then
        Pad.on = want
    else
        Pad.pending = true
    end
end

function Pad.Attach(f)
    if ConsolePort and ConsolePort.AddInterfaceCursorFrame then
        pcall(ConsolePort.AddInterfaceCursorFrame, ConsolePort, f)
    end
    if not f.EnableGamePadButton then return end
    f:SetScript("OnGamePadButtonDown", function(_, button)
        local fn = Pad.ACTIONS[GP.Plain(button) or ""]
        if fn then GP.SafeCall(fn) end
    end)
    f:HookScript("OnShow", Pad.Update)
    f:HookScript("OnHide", function()
        Pad.Update()
        for _, list in ipairs({ UI.Plan and UI.Plan.list, UI.Browse and UI.Browse.list, UI.SlotPanel and UI.SlotPanel.list }) do
            list:ClearFocus()
        end
    end)
    Pad.Update()
end

GP.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if Pad.pending then
        Pad.pending = nil
        Pad.Update()
    end
end)
GP.RegisterEvent("CVAR_UPDATE", function(_, name)
    if GP.Plain(name) == "GamePadEnable" then Pad.Update() end
end)
GP.RegisterEvent("GAME_PAD_ACTIVE_CHANGED", function() Pad.Update() end)

GP.RegisterCommand("route", "open the route (Best now, by zone)", function() GP.Toggle("plan") end)
GP.RegisterCommand("browse", "open the gear browser", function() GP.Toggle("browse") end)
GP.RegisterCommand("settings", "open GearPath's settings", function() GP.Toggle("settings") end)

-- ---------------------------------------------------------------------
-- The minimap button: click to open, right-click for Settings, drag it
-- round the minimap's edge. Off with "Minimap button" in Settings.
-- ---------------------------------------------------------------------

local Mini = {}
UI.MinimapButton = Mini

-- Where round the minimap: an angle, on its edge (a square minimap's edge
-- for square minimaps).
function Mini.Place(angle)
    local b = Mini.button
    if not b then return end
    local map = b:GetParent()
    local r = ((map:GetWidth() or 140) / 2) + 5
    local rad = math.rad(angle or 200)
    local x, y = math.cos(rad), math.sin(rad)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        -- Out to the square's edge, not the circle's.
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
    end
    b:ClearAllPoints()
    b:SetPoint("CENTER", map, "CENTER", x * r, y * r)
end

local function angleToCursor(map)
    local cx, cy = GetCursorPosition()
    local scale = map:GetEffectiveScale()
    local mx, my = map:GetCenter()
    return math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
end

function Mini.Create()
    local map = rawget(_G, "Minimap")
    if Mini.button or not map then return Mini.button end
    local b = CreateFrame("Button", "GearPathMinimapButton", map)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((map:GetFrameLevel() or 1) + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetTexture("Interface\\AddOns\\GearPath\\Media\\icon_round")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)
    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetSize(53, 53)
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b:SetScript("OnClick", function(_, button)
        GameTooltip:Hide()
        if button == "RightButton" then GP.Toggle("settings") else GP.Toggle() end
    end)
    b:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GP.LauncherTooltip(self, "ANCHOR_LEFT", { L["Click: open GearPath.  Right-click: Settings."], L["Drag to move it round the minimap."] })
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local a = angleToCursor(map)
            GP.db.settings.minimapAngle = a
            Mini.Place(a)
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)
    Mini.button = b
    Mini.Place(GP.Setting("minimapAngle"))
    return b
end

function Mini.Update()
    local on = GP.Setting("minimapButton") ~= false
    if on then Mini.Create() end
    if Mini.button then Mini.button:SetShown(on) end
end

GP.On("Login", function() GP.SafeCall(Mini.Update) end)
GP.On("SettingChanged", function(key) if key == "minimapButton" then GP.SafeCall(Mini.Update) end end)
