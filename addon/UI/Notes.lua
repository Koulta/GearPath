-- Notes: small heads-ups as you play.
--   A level-up that lets you wear gear from your bags: a line in chat.
--   A vendor you open that sells an upgrade: a line in chat.
--   An upgrade you put on: a toast at the top of the screen, with how much
--   it adds to your GearPath score.
-- Off with "Upgrade notes" in Settings.

local _, GP = ...

local Notes = {}
GP.Notes = Notes

Notes.TOAST_SECONDS = 4     -- how long the toast stays before it fades
Notes.TOAST_FADE = 0.8
Notes.QUIET_AFTER_LOAD = 8  -- seconds after a loading screen with no toast (gear is still being read)
Notes.MAX_LINES = 3         -- items listed in one chat note; the rest are counted

local function on() return GP.Setting("notices") ~= false end

-- "[Item], +12% Chest" (with "at level 24" when it isn't wearable yet).
local function itemLine(c, level)
    local text = string.format("%s, %s", c.link, GP.UI.GainLine(c.slot, c.delta, c.pct))
    if level and (c.rec.reqLevel or 0) > level then text = text .. " at level " .. c.rec.reqLevel end
    if c.price and c.price > 0 then text = text .. ", " .. GP.Money(c.price) end
    return text
end

-- The best of each slot, biggest gain first.
local function bestPerSlot(list)
    local bySlot = {}
    for _, c in ipairs(list) do
        if not bySlot[c.slot] or c.delta > bySlot[c.slot].delta then bySlot[c.slot] = c end
    end
    local out = {}
    for _, c in pairs(bySlot) do out[#out + 1] = c end
    table.sort(out, function(a, b) return a.delta > b.delta end)
    return out
end

local function printList(intro, several, list, level)
    if #list == 1 then
        GP.Print("%s %s.", intro, itemLine(list[1], level))
        return
    end
    GP.Print(several, #list)
    for i, c in ipairs(list) do
        if i > Notes.MAX_LINES then
            GP.Print("  and %d more.", #list - Notes.MAX_LINES)
            break
        end
        GP.Print("  %s", itemLine(c, level))
    end
end

-- ---------------------------------------------------------------------
-- A level-up: gear in your bags you can wear now
-- ---------------------------------------------------------------------

-- Gear in your bags you couldn't wear at level `from` and can at `to`
-- that beats what you wear: { { link, rec, slot, delta, pct }, ... }.
function Notes.WearableNow(from, to)
    local out, seen = {}, {}
    local getSlots = C_Container and C_Container.GetContainerNumSlots
    local getLink = C_Container and C_Container.GetContainerItemLink
    if not (getSlots and getLink) then return out end
    local Classes, Score = GP.Classes, GP.Score
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, (getSlots(bag) or 0) do
            local link = GP.Plain(getLink(bag, slot))
            local rec = type(link) == "string" and GP.Items.FromLink(link) or nil
            if rec and not seen[rec.id] then
                seen[rec.id] = true
                local req = rec.reqLevel or 0
                local before = req <= from and Classes.CanUse(rec.classID, rec.subClassID, rec.equipLoc, nil, from) == true
                if not before and req <= to and Score.CanWear(rec, to) then
                    local s, delta, pct = Score.Gain(rec)
                    -- Not if a weapon skill or armor still has to be learned first.
                    if s and GP.Training and GP.Training.Need(rec, s) then s = nil end
                    if s then out[#out + 1] = { link = link, rec = rec, slot = s, delta = delta, pct = pct } end
                end
            end
        end
    end
    return bestPerSlot(out)
end

function Notes.LevelUp(from, to)
    if not on() or type(from) ~= "number" or type(to) ~= "number" or to <= from then return end
    GP.Score.ReadEquipped()
    local list = Notes.WearableNow(from, to)
    if #list == 0 then return end
    printList(string.format("Level %d: you can wear", to),
        "Level " .. to .. ": you can wear %d upgrades from your bags now:", list)
end

local lastLevel
GP.On("Login", function() lastLevel = GP.player and GP.player.level end)
GP.On("LevelChanged", function(level)
    local from = lastLevel
    lastLevel = level
    -- A moment for the game to settle the new level.
    C_Timer.After(1.5, function() GP.SafeCall(Notes.LevelUp, from, level) end)
end)

-- ---------------------------------------------------------------------
-- A vendor that sells an upgrade
-- ---------------------------------------------------------------------

local function merchantPrice(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
        if ok and type(info) == "table" then return tonumber(GP.Plain(info.price)) or 0 end
    end
    if GetMerchantItemInfo then
        local ok, _, _, price = pcall(GetMerchantItemInfo, i)
        if ok then return tonumber(GP.Plain(price)) or 0 end
    end
    return 0
end

-- The vendor's upgrades for you (wearable now or within the Best now
-- range), and whether any of its items are still loading.
function Notes.VendorUpgrades()
    local n = GetMerchantNumItems and tonumber(GP.Plain(GetMerchantNumItems())) or 0
    local level = (GP.player or GP.PlayerInfo()).level
    local soon = GP.Setting("soon") or 2
    local entries = GP.Sources and GP.Sources.entries or {}
    local out, loading = {}, false
    for i = 1, n do
        local link = GetMerchantItemLink and GP.Plain(GetMerchantItemLink(i))
        local rec = type(link) == "string" and GP.Items.FromLink(link) or nil
        if type(link) == "string" and not rec then loading = true end
        local owned = rec and entries[rec.id] and entries[rec.id].bags
        if rec and not owned and (rec.reqLevel or 0) <= level + soon and GP.Score.CanWear(rec) then
            local s, delta, pct = GP.Score.Gain(rec)
            if s then
                out[#out + 1] = { link = link, rec = rec, slot = s, delta = delta, pct = pct, price = merchantPrice(i) }
            end
        end
    end
    return bestPerSlot(out), loading
end

local vendorSaid
local function lookAtVendor(tries)
    if not on() or vendorSaid then return end
    if not next(GP.Score.equipped or {}) then GP.Score.ReadEquipped() end
    local list, loading = Notes.VendorUpgrades()
    if loading and tries < 3 then
        C_Timer.After(0.5, function() GP.SafeCall(lookAtVendor, tries + 1) end)
        return
    end
    vendorSaid = true
    if #list == 0 then return end
    printList("This vendor sells an upgrade:", "This vendor sells %d upgrades for you:", list,
        (GP.player or GP.PlayerInfo()).level)
end

GP.RegisterEvent("MERCHANT_SHOW", function()
    vendorSaid = nil
    -- The vendor's list fills in a moment after the window opens.
    C_Timer.After(0.3, function() GP.SafeCall(lookAtVendor, 1) end)
end)
GP.RegisterEvent("MERCHANT_CLOSED", function() vendorSaid = true end)

-- ---------------------------------------------------------------------
-- The toast: an upgrade you put on
-- ---------------------------------------------------------------------

local function buildToast()
    if Notes.toast then return Notes.toast end
    local skin = GP.Skin.current or GP.Skin.Pick()
    local f = CreateFrame("Frame", "GearPathToast", UIParent)
    f:SetSize(280, 60)
    f:SetPoint("TOP", UIParent, "TOP", 0, -165)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)
    f:Hide()
    f.panel = skin.Panel(f)
    f.panel:SetAllPoints(f)
    f.icon = skin.Icon(f, 36)
    f.icon:SetPoint("LEFT", f, "LEFT", 11, 0)
    f.icon:EnableMouse(false)
    f.arrow = GP.Skin.UpgradeArrow(f, 18)
    f.arrow:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -7, 7)
    f.title = skin.Text(f, "small", "GOOD")
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 9, 1)
    f.title:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.title:SetWordWrap(false)
    f.name = skin.Text(f, "body", "VALUE")
    f.name:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.name:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.name:SetWordWrap(false)
    f.sub = skin.Text(f, "small", "LABEL")
    f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
    f.sub:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.sub:SetWordWrap(false)
    f:SetScript("OnUpdate", function(self, elapsed)
        self.age = (self.age or 0) + (elapsed or 0)
        local fadeFrom = Notes.TOAST_SECONDS
        if self.age >= fadeFrom + Notes.TOAST_FADE then
            self:Hide()
        elseif self.age > fadeFrom then
            self:SetAlpha(1 - (self.age - fadeFrom) / Notes.TOAST_FADE)
        end
    end)
    Notes.toast = f
    return f
end

-- Shows the toast for an item put on: { rec, slot, delta, pct, scorePct }.
function Notes.Toast(t)
    local f = buildToast()
    f.icon.SetItem(t.rec.icon, t.rec.quality)
    f.arrow.Paint("primary")
    f.title:SetText(string.format(GP.L["Upgrade: %s"], GP.UI.GainLine(t.slot, t.delta, t.pct)))
    f.name:SetText(t.rec.name or "?")
    local r, g, b = GP.QualityColor(t.rec.quality)
    f.name:SetTextColor(r, g, b)
    f.sub:SetText(t.scorePct and t.scorePct >= 1
        and string.format(GP.L["About +%d%% to your GearPath score"], GP.Round(t.scorePct))
        or GP.L["A little more to your GearPath score"])
    f.age = 0
    f:SetAlpha(1)
    f:Show()
end

-- What putting this item in this slot did, from what you wore a moment ago
-- (GearPath reads your gear again a frame later): a toast's details, or nil
-- when it isn't an upgrade.
function Notes.Equipped(slotID)
    local s = GP.Slots.BY_ID and GP.Slots.BY_ID[slotID]
    if not s then
        for _, x in ipairs(GP.Slots.LIST) do if x.id == slotID then s = x break end end
    end
    if not s or s.cosmetic then return nil end
    local before = GP.Score.equipped
    if not next(before or {}) then return nil end
    local link = GP.Plain(GetInventoryItemLink("player", slotID))
    local rec = type(link) == "string" and GP.Items.FromLink(link) or nil
    if not rec then return nil end
    -- Moved from another slot (a ring or trinket swapped over): not new.
    for _, e in pairs(before) do
        if e.id == rec.id then return nil end
    end
    local old = before[s.key] or { points = 0 }
    local base = old.points or 0
    local mh = (before.MainHandSlot or {}).rec
    if s.key == "MainHandSlot" and rec.equipLoc == "INVTYPE_2HWEAPON" then
        base = base + ((before.SecondaryHandSlot or {}).points or 0)
    elseif s.key == "SecondaryHandSlot" and mh and mh.equipLoc == "INVTYPE_2HWEAPON" then
        -- An off hand in place of a two-hander: it's the pair that counts.
        return nil
    end
    local points = GP.Score.Points(rec, s.key)
    local delta = points - base
    local pct = old.rec and base > 0 and (delta / base * 100) or nil
    if delta < GP.Score.MIN_POINTS or (pct and pct < GP.Score.MIN_PCT) then return nil end
    local total = 0
    for _, e in pairs(before) do total = total + (e.points or 0) end
    return { rec = rec, slot = s.key, delta = delta, pct = pct, scorePct = total > 0 and (delta / total * 100) or nil }
end

local loadedAt = 0
GP.RegisterEvent("PLAYER_ENTERING_WORLD", function() loadedAt = GetTime() end)

GP.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slotID, empty)
    if not on() or not GP.loggedIn or empty == true or type(slotID) ~= "number" then return end
    if GetTime() - loadedAt < Notes.QUIET_AFTER_LOAD then return end
    local t = Notes.Equipped(slotID)
    if t then Notes.Toast(t) end
end)
