-- Roll: a line under the item on the game's Need/Greed window, so you know
-- whether to roll Need before the timer runs out (approved with Koulta,
-- Nov 13):
--     GearPath: +105% for you (Waist)
--     GearPath: not an upgrade for you
--     GearPath: for your other spec, Demonology: +12%
-- Off with "Loot roll help" in Settings.

local _, GP = ...
local L = GP.L

local Roll = {}
GP.Roll = Roll

local GOOD, OTHER, DIM = { 0.25, 1, 0.25 }, { 1, 0.82, 0.25 }, { 0.6, 0.6, 0.6 }

local function on() return GP.Setting("rollHelp") ~= false end

local function gain(t)
    local text = GP.UI.GainText(t)
    if text == "new" then text = L["new"] end
    return text
end

-- Whether your class could ever wear it (armor, weapon, a class limit).
local function yours(rec)
    if not (rec and rec.equipLoc and GP.Slots.FOR_EQUIPLOC[rec.equipLoc]) then return false end
    if rec.classes and not rec.classes[UnitClass("player")] then return false end
    return GP.Classes.CanUse(rec.classID, rec.subClassID, rec.equipLoc, nil, 999) == true
end

-- The line for an item, and its colour. Nil for something that isn't gear.
function Roll.Verdict(rec)
    if not (rec and rec.equipLoc and GP.Slots.FOR_EQUIPLOC[rec.equipLoc]) then return nil end
    local Score, Classes = GP.Score, GP.Classes
    if not yours(rec) then return L["GearPath: not an upgrade for you"], DIM end
    local slot, delta, pct, base = Score.Upgrade(rec)
    if slot and delta and Score.BigEnough(delta, base) then
        return string.format(L["GearPath: %s for you (%s)"], gain({ slot = slot, delta = delta, pct = pct }),
            GP.Slots.Label(slot) or "?"), GOOD
    end
    local mine = Classes.Spec()
    for _, spec in ipairs(Classes.Specs()) do
        if spec.key ~= mine.key then
            local s, d, p, b = Score.UpgradeAs(rec, spec)
            if s and d and Score.BigEnough(d, b) then
                return string.format(L["GearPath: for your other spec, %s: %s"], Classes.SpecName(spec),
                    gain({ slot = s, delta = d, pct = p })), OTHER
            end
        end
    end
    return L["GearPath: not an upgrade for you"], DIM
end

-- The game's roll windows (GroupLootFrame1-4), the one for rollID.
local function frameFor(rollID)
    for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
        local f = rawget(_G, "GroupLootFrame" .. i)
        if f and f.rollID == rollID and (not f.IsShown or f:IsShown()) then return f end
    end
end

-- Puts the line under the roll window for rollID. True when it did.
function Roll.Attach(rollID, tries)
    if not on() or type(rollID) ~= "number" then return false end
    local f = frameFor(rollID)
    local link = GetLootRollItemLink and GP.Plain(GetLootRollItemLink(rollID))
    local rec = type(link) == "string" and GP.Items.FromLink(link) or nil
    if not (f and rec) then
        -- The window or the item a moment late: a few more looks.
        tries = (tries or 0) + 1
        if tries <= 5 then
            C_Timer.After(0.2, function() GP.SafeCall(Roll.Attach, rollID, tries) end)
        end
        return false
    end
    if not next(GP.Score.equipped or {}) then GP.Score.ReadEquipped() end
    local text, color = Roll.Verdict(rec)
    local line = f.gearPathLine
    if not text then
        if line then line:Hide() end
        return false
    end
    if not line then
        line = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetPoint("TOP", f, "BOTTOM", 0, -2)
        f.gearPathLine = line
    end
    line:SetText(text)
    line:SetTextColor(color[1], color[2], color[3])
    line:Show()
    return true
end

GP.RegisterEvent("START_LOOT_ROLL", function(_, rollID)
    if not on() then return end
    -- The window opens on the same event: a moment for it.
    C_Timer.After(0.05, function() GP.SafeCall(Roll.Attach, GP.Plain(rollID)) end)
end)

-- A line left on a window that's reused for the next roll without one.
GP.RegisterEvent("CANCEL_LOOT_ROLL", function(_, rollID)
    local f = frameFor(GP.Plain(rollID))
    if f and f.gearPathLine then f.gearPathLine:Hide() end
end)
