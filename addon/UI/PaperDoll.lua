-- PaperDoll: the Character tab's left half. Your slots in the game's own
-- layout (eight down each side, the weapons along the bottom) round a model
-- of your character that items can be tried on, in front of your race's
-- art from the game's dressing room, a green arrow on each slot
-- that has an upgrade to get now (gold: only ones worth chasing). Clicking
-- a slot lists its upgrades on the right (SlotPanel.lua).

local _, GP = ...

local UI, Slots = GP.UI, GP.Slots
local L = GP.L

local Doll = {}
UI.Doll = Doll

Doll.SLOT = 40
Doll.GAP = 4
Doll.WIDTH = 360

local buttons = {}

function UI.SelectSlot(key)
    UI.selectedSlot = key
    if key and GP.Setting("checkOnClick") ~= false and GP.Sources.status == "ready" then
        GP.SafeCall(GP.Check.Slot, key)
    end
    local def = UI.PAGES.doll
    if def and def.frame and def.frame:IsShown() then GP.SafeCall(def.Fill, def.frame) end
end

-- ---------------------------------------------------------------------
-- What each slot has waiting
-- ---------------------------------------------------------------------

-- [slotKey] = { primary = n, secondary = n, best = ev } from the last scoring.
-- Only the content ticked under "Show:".
local function upgradeCounts()
    local out = {}
    for _, ev in ipairs(GP.Score.results.all or {}) do
        local tier = ev.tier
        if tier == "locked" then tier = nil end
        if tier and UI.ContentMatches(ev) then
            local c = out[ev.slot]
            if not c then
                c = { primary = 0, secondary = 0 }
                out[ev.slot] = c
            end
            c[tier] = c[tier] + 1
            if not c.best or (tier == "primary" and c.bestTier ~= "primary") or
                (tier == c.bestTier and ev.delta > c.best.delta) then
                c.best, c.bestTier = ev, tier
            end
        end
    end
    return out
end

local counts = {}

local function slotTooltip(b)
    local s = Slots.BY_KEY[b.key]
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    if GetInventoryItemLink("player", s.id) then
        GameTooltip:SetInventoryItem("player", s.id)
    else
        GameTooltip:SetText(s.label, 1, 1, 1)
        GameTooltip:AddLine(L["Empty"], 0.6, 0.6, 0.6)
    end
    if not s.cosmetic then
        local c = counts[b.key]
        GameTooltip:AddLine(" ")
        if c and c.primary > 0 then
            local text = UI.GainText(c.best)
            if text == "new" then text = L["fills the empty slot"] end
            GameTooltip:AddLine("GearPath: " .. string.format(L["%s to get now (best %s)"],
                GP.Count(c.primary, "%d upgrade", "%d upgrades"), text), 0.25, 1, 0.25)
        end
        if c and c.secondary > 0 then
            GameTooltip:AddLine(string.format(L["%d more worth chasing"], c.secondary), 1, 0.65, 0.1)
        end
        if not c then GameTooltip:AddLine("GearPath: " .. L["nothing better within reach yet"], 0.6, 0.6, 0.6) end
        GameTooltip:AddLine(L["Click to see the upgrades for this slot."], 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function makeSlot(parent, key)
    local skin = GP.Skin.current
    local b = CreateFrame("Button", nil, parent)
    b.key = key
    b:SetSize(Doll.SLOT, Doll.SLOT)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = skin.Icon(b, Doll.SLOT)
    b.icon:SetAllPoints(b)
    -- Above the icon (its own frame): the ring, the arrow, the count.
    b.top = CreateFrame("Frame", nil, b)
    b.top:SetAllPoints(b)
    b.top:SetFrameLevel(b.icon:GetFrameLevel() + 12)
    b.ring = skin.Ring(b.top)
    b.ring:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
    b.ring:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 4, -4)
    b.ring:Hide()
    b.hover = b.top:CreateTexture(nil, "OVERLAY", nil, 5)
    b.hover:SetAllPoints(b)
    b.hover:SetColorTexture(1, 1, 1, 0.12)
    b.hover:Hide()
    b.arrow = GP.Skin.UpgradeArrow(b.top, 16)
    b.arrow:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 3)
    b.arrow:Hide()
    b.count = skin.Text(b.top, "tiny", "VALUE", "RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 3)
    b:SetScript("OnEnter", function(self)
        self.hover:Show()
        slotTooltip(self)
    end)
    b:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self, button)
        local s = Slots.BY_KEY[self.key]
        local link = GetInventoryItemLink("player", s.id)
        if link and IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
            pcall(HandleModifiedItemClick, link)
            return
        end
        if button == "RightButton" or s.cosmetic then return end
        if UI.selectedSlot == self.key then UI.SelectSlot(nil) else UI.SelectSlot(self.key) end
    end)
    buttons[key] = b
    return b
end

local function fillSlot(b)
    local s = Slots.BY_KEY[b.key]
    local link = GetInventoryItemLink("player", s.id)
    if link then
        b.icon.SetItem(GetInventoryItemTexture("player", s.id), GetInventoryItemQuality("player", s.id))
    else
        b.icon.SetEmpty(s.empty)
    end
    local c = not s.cosmetic and counts[b.key]
    if c then
        b.arrow.Paint(c.primary > 0 and "primary" or "secondary")
        b.arrow:Show()
        b.count:SetText(c.primary > 0 and tostring(c.primary) or "")
    else
        b.arrow:Hide()
        b.count:SetText("")
    end
    b.ring:SetShown(UI.selectedSlot == b.key)
end

-- ---------------------------------------------------------------------
-- The model
-- ---------------------------------------------------------------------

local function makeModel(parent)
    local m = CreateFrame("DressUpModel", nil, parent)
    m:EnableMouse(true)
    m:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self.turnX = GetCursorPosition() end
    end)
    m:SetScript("OnMouseUp", function(self) self.turnX = nil end)
    m:SetScript("OnHide", function(self) self.turnX = nil end)
    m:SetScript("OnUpdate", function(self)
        if not self.turnX then return end
        local x = GetCursorPosition()
        local facing = (self.GetFacing and self:GetFacing()) or 0
        self:SetFacing(facing + (x - self.turnX) * 0.012)
        self.turnX = x
    end)
    return m
end

-- ---------------------------------------------------------------------
-- The background: your race's art from the game's dressing room
-- ---------------------------------------------------------------------

-- The game's dressing room art comes in four pieces: 256x256 top left,
-- 64x256 top right, 256x128 bottom left, 64x128 bottom right.
local ART_W, ART_H = 320, 384
local PIECES = {
    { n = 1, x = 0,   y = 0,   w = 256, h = 256 },
    { n = 2, x = 256, y = 0,   w = 64,  h = 256 },
    { n = 3, x = 0,   y = 256, w = 256, h = 128 },
    { n = 4, x = 256, y = 256, w = 64,  h = 128 },
}

-- The races that have dressing room art, and how much each is darkened so
-- the model stands out (the game's own amounts for its character sheet, a
-- little lighter). A race not listed gets the plain panel.
Doll.RACE_DIM = {
    Human = 0.5, Dwarf = 0.5, Gnome = 0.5, NightElf = 0.45, Draenei = 0.5, Worgen = 0.4,
    Orc = 0.45, Troll = 0.45, Tauren = 0.5, Scourge = 0.25, BloodElf = 0.55, Goblin = 0.45, Pandaren = 0.5,
}

-- The art's file name without its piece number, or nil.
function Doll.ArtPath(raceFile)
    if not (raceFile and Doll.RACE_DIM[raceFile]) then return nil end
    if DressUpTexturePath then
        local ok, path = pcall(DressUpTexturePath, raceFile)
        if ok and type(path) == "string" and path ~= "" then return path end
    end
    return "Interface\\DressUpFrame\\DressUpBackground-" .. raceFile
end

-- Lays the four pieces over w x h so they fill it, cutting the sides (or
-- the top and bottom) rather than squashing the picture.
function Doll.LayoutArt(art, w, h)
    if not (type(w) == "number" and type(h) == "number" and w > 0 and h > 0) then return end
    local scale = math.max(w / ART_W, h / ART_H)
    local cx, cy = (ART_W - w / scale) / 2, (ART_H - h / scale) / 2
    for i, p in ipairs(PIECES) do
        local t = art.pieces[i]
        local x0, x1 = math.max(p.x, cx), math.min(p.x + p.w, ART_W - cx)
        local y0, y1 = math.max(p.y, cy), math.min(p.y + p.h, ART_H - cy)
        if x1 <= x0 or y1 <= y0 then
            t:Hide()
        else
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", art, "TOPLEFT", (x0 - cx) * scale, -(y0 - cy) * scale)
            t:SetSize((x1 - x0) * scale, (y1 - y0) * scale)
            t:SetTexCoord((x0 - p.x) / p.w, (x1 - p.x) / p.w, (y0 - p.y) / p.h, (y1 - p.y) / p.h)
            t:Show()
        end
    end
end

local function makeArt(panel)
    local _, raceFile = UnitRace("player")
    local path = Doll.ArtPath(GP.Plain(raceFile))
    if not path then return nil end
    local art = CreateFrame("Frame", nil, panel)
    art:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    art:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    art:SetFrameLevel(panel:GetFrameLevel() + 1)
    art.race, art.path = raceFile, path
    art.pieces = {}
    for i, p in ipairs(PIECES) do
        local t = art:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(path .. p.n)
        art.pieces[i] = t
    end
    art.dim = art:CreateTexture(nil, "BORDER")
    art.dim:SetAllPoints(art)
    art.dim:SetColorTexture(0, 0, 0, Doll.RACE_DIM[raceFile])
    art:SetScript("OnSizeChanged", function(self, w, h) Doll.LayoutArt(self, w, h) end)
    Doll.LayoutArt(art, art:GetWidth(), art:GetHeight())
    return art
end

-- "Put it on": shown above "Take it off" while something tried on is in
-- your bags and wearable now. It says so when the item binds to you.
function Doll.UpdatePutOn()
    local b = Doll.putOn
    if not b then return end
    local list = UI.TriedFromBags and UI.TriedFromBags() or {}
    b.list = list
    if #list == 0 then b:Hide() return end
    local binds = false
    for _, e in ipairs(list) do if e.binds then binds = true end end
    b.SetLabel((#list > 1 and L["Put them on"] or L["Put it on"]) .. (binds and (" (" .. L["binds"] .. ")") or ""))
    b:Show()
end

local function putOnTooltip(self)
    local list = self.list or {}
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(#list > 1 and L["Put them on"] or L["Put it on"])
    for _, e in ipairs(list) do
        local r, g, b = GP.QualityColor(e.ev.rec.quality)
        GameTooltip:AddDoubleLine(e.ev.rec.name or "?", GP.Slots.Label(e.ev.slot), r, g, b, 1, 1, 1)
    end
    for _, e in ipairs(list) do
        if e.binds then
            GameTooltip:AddLine(string.format(L["%s binds to you when you put it on: you can't trade it or sell it at the Auction House after. The game asks you to confirm first."],
                e.ev.rec.name or "?"), 1, 0.65, 0.1, true)
        end
    end
    if UI.InCombat() then GameTooltip:AddLine(L["Not in combat: gear can't be changed in a fight."], 1, 0.3, 0.3, true) end
    GameTooltip:Show()
end

function Doll.ResetModel()
    local m = UI.model
    if not m then return end
    pcall(m.SetUnit, m, "player")
    UI.trying = false
    UI.tried = nil
    if Doll.undo then Doll.undo:Hide() end
    if Doll.putOn then Doll.putOn:Hide() end
    if Doll.summary then Doll.UpdateSummary() end
    if UI.Stats then GP.SafeCall(UI.Stats.Fill) end
end

UI.OnTryOn = function()
    if Doll.undo then Doll.undo:Show() end
    Doll.UpdatePutOn()
    if Doll.summary then Doll.UpdateSummary() end
    if UI.Stats then GP.SafeCall(UI.Stats.Fill) end
end

-- ---------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------

-- Your average item level, or what it would be with the items tried on
-- ({ [slotKey] = ev }). A two-hander counts for both hands.
local function averageItemLevel(tried)
    local recs = {}
    for _, key in ipairs(Slots.ORDER) do
        local e = GP.Score.equipped[key]
        recs[key] = e and e.rec or false
    end
    for slot, ev in pairs(tried or {}) do
        recs[slot] = ev.rec
        if slot == "MainHandSlot" and ev.rec.equipLoc == "INVTYPE_2HWEAPON" then recs.SecondaryHandSlot = false end
    end
    local mh = recs.MainHandSlot
    local twoHand = mh and mh.equipLoc == "INVTYPE_2HWEAPON"
    local total, slots = 0, 0
    for _, key in ipairs(Slots.ORDER) do
        local ilvl = recs[key] and recs[key].ilvl or 0
        if key == "SecondaryHandSlot" and twoHand and ilvl == 0 then ilvl = mh.ilvl or 0 end
        total = total + ilvl
        slots = slots + 1
    end
    return slots > 0 and total / slots or 0
end

local function totalPoints()
    local t = 0
    for _, key in ipairs(Slots.ORDER) do
        local e = GP.Score.equipped[key]
        t = t + (e and e.points or 0)
    end
    return t
end

-- "Item level 23.8  |  GearPath score 249", and with items tried on what
-- they'd be: "Item level 24.4 (+0.6)  |  GearPath score 264 (+15)".
function Doll.UpdateSummary()
    local tried = UI.tried and next(UI.tried) and UI.tried or nil
    local ilvl, score = averageItemLevel(), totalPoints()
    if not tried then
        Doll.summary:SetText(string.format("%s %.1f   |   %s %d", L["Item level"], ilvl, L["GearPath score"], GP.Round(score)))
        return
    end
    -- All of them together (a two-hander and an off hand aren't added up).
    local gain = GP.Score.LoadoutGain(tried)
    local newIlvl = averageItemLevel(tried)
    local function signed(d, f)
        local hex = d > 0 and "ff40ff40" or (d < 0 and "ffff5050" or "ff9a9a9a")
        return string.format("|c%s(" .. f .. ")|r", hex, d)
    end
    Doll.summary:SetText(string.format("%s %.1f %s   |   %s %d %s", L["Item level"], newIlvl,
        signed(newIlvl - ilvl, "%+.1f"), L["GearPath score"], GP.Round(score + gain), signed(GP.Round(gain), "%+d")))
end

UI.RegisterPage("doll", {
    text = "Character",
    order = 1,
    Build = function(page)
        local skin = GP.Skin.current
        local S, G = Doll.SLOT, Doll.GAP
        local left = CreateFrame("Frame", nil, page)
        left:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
        left:SetWidth(Doll.WIDTH)

        local column = 8 * (S + G) - G
        local panel = skin.Panel(left)
        panel:SetPoint("TOPLEFT", left, "TOPLEFT", S + 10, 0)
        panel:SetPoint("BOTTOMRIGHT", left, "TOPRIGHT", -(S + 10), -column)
        Doll.art = makeArt(panel)
        UI.model = makeModel(panel)
        UI.model:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
        UI.model:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
        if Doll.art then UI.model:SetFrameLevel(Doll.art:GetFrameLevel() + 1) end

        Doll.undo = skin.Button(panel, L["Take it off"], 130, 22)
        Doll.undo:SetPoint("BOTTOM", panel, "BOTTOM", 0, 8)
        Doll.undo:SetFrameLevel(UI.model:GetFrameLevel() + 5)
        Doll.undo:SetScript("OnClick", Doll.ResetModel)
        Doll.undo:Hide()
        Doll.putOn = skin.Button(panel, L["Put it on"], 180, 22)
        Doll.putOn:SetPoint("BOTTOM", Doll.undo, "TOP", 0, 4)
        Doll.putOn:SetFrameLevel(UI.model:GetFrameLevel() + 5)
        Doll.putOn:SetScript("OnClick", function(self)
            local sent, left = UI.PutOn()
            if sent > 0 and (left or 0) == 0 then
                GameTooltip:Hide()
                Doll.ResetModel()
            elseif sent > 0 then
                -- Some still to go (one bind confirmation at a time).
                GameTooltip:Hide()
                Doll.UpdatePutOn()
                Doll.UpdateSummary()
            end
        end)
        Doll.putOn:HookScript("OnEnter", putOnTooltip)
        Doll.putOn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        Doll.putOn:Hide()

        for i, key in ipairs(Slots.LEFT) do
            makeSlot(left, key):SetPoint("TOPLEFT", left, "TOPLEFT", 0, -(i - 1) * (S + G))
        end
        for i, key in ipairs(Slots.RIGHT) do
            makeSlot(left, key):SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, -(i - 1) * (S + G))
        end
        local row = 3 * S + 2 * 14
        for i, key in ipairs(Slots.BOTTOM) do
            makeSlot(left, key):SetPoint("TOPLEFT", left, "TOPLEFT",
                (Doll.WIDTH - row) / 2 + (i - 1) * (S + 14), -column - 8)
        end

        Doll.summary = skin.Text(left, "body", "VALUE", "CENTER")
        Doll.summary:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -column - S - 20)
        Doll.summary:SetPoint("RIGHT", left, "RIGHT", 0, 0)
        Doll.hint = skin.Text(left, "small", "LABEL", "CENTER")
        Doll.hint:SetPoint("TOPLEFT", Doll.summary, "BOTTOMLEFT", 0, -6)
        Doll.hint:SetPoint("RIGHT", left, "RIGHT", 0, 0)
        Doll.hint:SetWordWrap(true)
        Doll.hint:SetText(L["Click a slot for its upgrades. Click an item to try it on and see what it changes. Drag the model to turn it."])
        -- (Stats.lua is new in 0.5.1: the game only loads a new file after a restart.)
        if UI.Stats then
            UI.Stats.Create(left)
            UI.Stats.frame:SetPoint("TOPLEFT", Doll.hint, "BOTTOMLEFT", 0, -14)
            UI.Stats.frame:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)
        end

        page:HookScript("OnShow", function() Doll.modelSet = false end)
        UI.SlotPanel.Build(page, Doll.WIDTH + 14)
    end,
    Fill = function(page)
        if not next(GP.Score.equipped) then GP.Score.ReadEquipped() end
        counts = upgradeCounts()
        for _, b in pairs(buttons) do fillSlot(b) end
        if not Doll.modelSet and not UI.trying then
            Doll.ResetModel()
            Doll.modelSet = true
        end
        Doll.UpdateSummary()
        if UI.Stats then UI.Stats.Fill() end
        UI.SlotPanel.Fill(page)
    end,
})

-- New gear on: the model wears it too (unless you're trying something on).
GP.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
    if not UI.trying then Doll.modelSet = false end
end)

-- ---------------------------------------------------------------------
-- The game's own Character window: each item's level on its slot, in the
-- item's quality colour (so an item-level add-on isn't needed). Off with
-- "Item levels" in Settings.
-- ---------------------------------------------------------------------

local function itemLevel(link)
    local detailed = (C_Item and C_Item.GetDetailedItemLevelInfo) or rawget(_G, "GetDetailedItemLevelInfo")
    if detailed then
        local ok, v = pcall(detailed, link)
        v = ok and GP.Plain(v) or nil
        if type(v) == "number" and v > 0 then return v end
    end
    local rec = GP.Items.FromLink(link)
    return rec and rec.ilvl
end

-- One slot of the game's window (CharacterHeadSlot and the rest).
function Doll.GameSlotLevel(button, slot)
    if not (button and slot) or slot.cosmetic then return end
    -- EllesmereUI's Character sheet draws its own: no second set.
    local on = GP.Setting("itemLevels") ~= false and not (GP.Ellesmere and GP.Ellesmere.SheetHasLevels())
    local link = on and GP.Plain(GetInventoryItemLink("player", slot.id)) or nil
    local level = type(link) == "string" and itemLevel(link) or nil
    if not level then
        if button.gpLevel then button.gpLevel:SetText("") end
        return
    end
    if not button.gpLevel then
        button.gpLevel = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.gpLevel:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    end
    local quality = GetInventoryItemQuality and GP.Plain(GetInventoryItemQuality("player", slot.id))
    local r, g, b = GP.QualityColor(quality)
    button.gpLevel:SetText(tostring(level))
    button.gpLevel:SetTextColor(r, g, b)
end

function Doll.GameSlotLevels()
    for _, slot in ipairs(Slots.LIST) do
        Doll.GameSlotLevel(rawget(_G, "Character" .. slot.key), slot)
    end
end

local function levelsSoon()
    local cf = rawget(_G, "CharacterFrame")
    if not cf or cf:IsShown() then GP.Soon("gameslots", Doll.GameSlotLevels) end
end
GP.On("Login", function()
    local cf = rawget(_G, "CharacterFrame")
    if cf and cf.HookScript then cf:HookScript("OnShow", function() GP.Soon("gameslots", Doll.GameSlotLevels) end) end
    levelsSoon()
end)
GP.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", levelsSoon)
GP.RegisterEvent("GET_ITEM_INFO_RECEIVED", levelsSoon)
GP.On("SettingChanged", function(key) if key == "itemLevels" then GP.Soon("gameslots", Doll.GameSlotLevels) end end)
