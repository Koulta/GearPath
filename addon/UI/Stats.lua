-- Stats: the Character tab's stats, under the model. Your real stats as the
-- game has them (gear, talents and buffs), the ones your weights value most
-- first, each with its share of your GearPath score. Click an item on the
-- right to try it on and the stats show what it would change: the
-- difference beside each stat, until "Take it off". Items tried on in
-- different slots add up.

local _, GP = ...

local UI = GP.UI
local L = GP.L

local Stats = {}
UI.Stats = Stats

Stats.MAX = 8          -- stats shown (two columns)
Stats.ROW = 20         -- height of a row

-- What a stat costs on an item, in points of a main stat, so the order
-- follows what a stat is worth for the room it takes (1% hit is about 14
-- Intellect's worth of an item). Stats not listed cost 1.
local COST = {
    hit = 14, crit = 14, haste = 14, expertise = 14, dodge = 14, parry = 14, block = 14,
    sp = 1 / 0.86, mp5 = 2.5, ap = 0.5, rap = 0.5, armor = 0.1, defense = 1.5,
}
-- On a tie, the main stats come first (a hunter's Agility before Ranged
-- Attack Power, which Agility also gives).
local MAIN = { str = true, agi = true, sta = true, int = true, spi = true }

-- Never in the panel: healing (left to healers), one school's spell power
-- (it's folded into Spell Power) and weapon damage (it's the weapon's).
local SKIP = { heal = true, dps = true, dpsMelee = true, dpsOff = true, dpsRanged = true, dpsWand = true }
local SCHOOLS = { spHoly = 2, spFire = 3, spNature = 4, spFrost = 5, spShadow = 6, spArcane = 7 }
local SCHOOL_NAMES = { [2] = "Holy", [3] = "Fire", [4] = "Nature", [5] = "Frost", [6] = "Shadow", [7] = "Arcane" }
local PERCENT = { hit = true, crit = true, haste = true, dodge = true, parry = true, block = true }
local UNIT_STAT = { str = 1, agi = 2, sta = 3, int = 4, spi = 5 }

Stats.LABELS = {
    sp = "Spell Power", hit = "Hit", crit = "Crit", haste = "Haste", int = "Intellect", spi = "Spirit",
    sta = "Stamina", str = "Strength", agi = "Agility", ap = "Attack Power", rap = "Ranged Attack Power",
    armor = "Armor", mp5 = "Mana per 5", expertise = "Expertise", defense = "Defense", block = "Block",
    dodge = "Dodge", parry = "Parry",
}

local function num(v)
    v = GP.Plain(v)
    return type(v) == "number" and v or nil
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

-- ---------------------------------------------------------------------
-- Which stats, and their real values
-- ---------------------------------------------------------------------

-- The stats to show for these weights, most valuable first.
function Stats.Keys(w)
    local list = {}
    for key, value in pairs(w) do
        if not SKIP[key] and not SCHOOLS[key] and Stats.LABELS[key] and value > 0 then
            list[#list + 1] = { key = key, v = value / (COST[key] or 1) }
        end
    end
    table.sort(list, function(a, b)
        if math.abs(a.v - b.v) > 1e-6 then return a.v > b.v end
        if (MAIN[a.key] == true) ~= (MAIN[b.key] == true) then return MAIN[a.key] == true end
        return a.key < b.key
    end)
    local out = {}
    for i = 1, math.min(Stats.MAX, #list) do out[i] = list[i].key end
    return out
end

-- Your main spell school: the one your weights value most (Shadow for a
-- warlock), or nil when none is.
function Stats.School(w)
    local best, bw
    for key, school in pairs(SCHOOLS) do
        local v = w[key] or 0
        if v > 0 and (not bw or v > bw or (v == bw and school < best)) then best, bw = school, v end
    end
    return best, bw and ("sp" .. SCHOOL_NAMES[best])
end

local function caster(w) return (w.sp or 0) >= 0.5 end

-- The game's own number for a stat (gear, talents and buffs), or nil.
function Stats.Actual(key, w, class)
    if UNIT_STAT[key] then
        local _, effective = call(UnitStat, "player", UNIT_STAT[key])
        return num(effective)
    end
    if key == "sp" then
        local school = Stats.School(w)
        if school then return num(call(GetSpellBonusDamage, school)) end
        local best
        for s = 2, 7 do
            local v = num(call(GetSpellBonusDamage, s))
            if v and (not best or v > best) then best = v end
        end
        return best
    end
    if key == "hit" then return num(call(caster(w) and GetSpellHitModifier or GetHitModifier)) end
    if key == "crit" then
        if caster(w) then return num(call(GetSpellCritChance, Stats.School(w) or 2)) end
        if class == "HUNTER" then return num(call(GetRangedCritChance)) end
        return num(call(GetCritChance))
    end
    if key == "haste" then
        if caster(w) then
            local v = num(call(UnitSpellHaste, "player"))
            if v then return v end
        end
        if class == "HUNTER" then
            local v = num(call(GetRangedHaste))
            if v then return v end
        end
        return num(call(GetHaste))
    end
    if key == "ap" or key == "rap" then
        local base, plus, minus = call(key == "ap" and UnitAttackPower or UnitRangedAttackPower, "player")
        base = num(base)
        return base and (base + (num(plus) or 0) + (num(minus) or 0))
    end
    if key == "armor" then
        local _, effective = call(UnitArmor, "player")
        return num(effective)
    end
    if key == "mp5" then
        local _, casting = call(GetManaRegen)
        casting = num(casting)
        return casting and casting * 5
    end
    if key == "expertise" then return num(call(GetExpertise)) end
    if key == "block" then return num(call(GetBlockChance)) end
    if key == "dodge" then return num(call(GetDodgeChance)) end
    if key == "parry" then return num(call(GetParryChance)) end
    if key == "defense" then
        local base, mod = call(UnitDefense, "player")
        base = num(base)
        return base and (base + (num(mod) or 0))
    end
end

-- How much of a stat a record carries (Spell Power counts your school's too).
local function carried(rec, key, schoolKey)
    local s = rec and rec.stats
    if not s then return 0 end
    local v = s[key] or 0
    if key == "sp" and schoolKey then v = v + (s[schoolKey] or 0) end
    return v
end

-- The items an item tried on would take the place of.
local function replaced(ev)
    local eq = GP.Score.equipped
    local out = { eq[ev.slot] and eq[ev.slot].rec }
    if ev.slot == "MainHandSlot" and ev.rec.equipLoc == "INVTYPE_2HWEAPON" then
        out[#out + 1] = eq.SecondaryHandSlot and eq.SecondaryHandSlot.rec
    end
    return out
end

-- Everything the panel shows: { rows = { { key, label, value, gear, share, delta } }, empty = { labels } }.
-- tried: { [slotKey] = ev } of items tried on (or nil).
function Stats.Build(tried)
    local w = GP.Classes.Weights()
    local class = GP.player and GP.player.class
    local _, schoolKey = Stats.School(w)
    local eq = GP.Score.equipped
    local total = 0
    for _, e in pairs(eq) do total = total + (e.points or 0) end
    local rows = {}
    for _, key in ipairs(Stats.Keys(w)) do
        -- What your gear carries, and the points it gives (your share).
        local gear, points = 0, 0
        for _, e in pairs(eq) do
            local v = carried(e.rec, key, schoolKey)
            if v ~= 0 then
                gear = gear + v
                local _, factor = GP.Classes.CanUse(e.rec.classID, e.rec.subClassID, e.rec.equipLoc, nil, 999)
                local sw = key == "sp" and schoolKey and (w[schoolKey] or 0) or 0
                points = points + (e.rec.stats[key] or 0) * (w[key] or 0) * (factor or 1)
                    + (key == "sp" and schoolKey and (e.rec.stats[schoolKey] or 0) * sw * (factor or 1) or 0)
            end
        end
        local delta
        for _, ev in pairs(tried or {}) do
            local d = carried(ev.rec, key, schoolKey)
            for _, old in ipairs(replaced(ev)) do d = d - carried(old, key, schoolKey) end
            delta = (delta or 0) + d
        end
        local actual = Stats.Actual(key, w, class)
        rows[#rows + 1] = {
            key = key, label = Stats.LABELS[key], percent = PERCENT[key],
            value = actual or gear, fromGear = actual == nil,
            share = total > 0 and points / total * 100 or nil, points = points,
            delta = delta, weight = w[key],
        }
    end
    -- Empty slots (an off hand with a two-hander on isn't empty).
    local empty = {}
    local mh = eq.MainHandSlot and eq.MainHandSlot.rec
    for _, s in ipairs(GP.Slots.LIST) do
        local e = eq[s.key]
        if not s.cosmetic and not (e and e.rec) and not (tried and tried[s.key]) then
            local covered = s.key == "SecondaryHandSlot" and mh and mh.equipLoc == "INVTYPE_2HWEAPON"
            if not covered then empty[#empty + 1] = s.label end
        end
    end
    return { rows = rows, empty = empty, school = schoolKey and schoolKey:sub(3) }
end

local function fmt(row, v)
    if row.percent then return string.format("%.1f%%", v) end
    if math.abs(v - math.floor(v + 0.5)) < 0.05 then return tostring(math.floor(v + 0.5)) end
    return string.format("%.1f", v)
end

function Stats.DeltaText(row)
    local d = row.delta
    if not d or math.abs(d) < 0.05 then return "", "OFF" end
    local s = row.percent and string.format("%+.1f%%", d) or (math.abs(d - math.floor(d + 0.5)) < 0.05
        and string.format("%+d", math.floor(d + 0.5)) or string.format("%+.1f", d))
    return s, d > 0 and "GOOD" or "BAD"
end

-- ---------------------------------------------------------------------
-- The panel
-- ---------------------------------------------------------------------

local function cellTooltip(cell)
    local row = cell.row
    if not row then return end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    local title = row.label
    if row.key == "sp" and Stats.data and Stats.data.school then title = title .. " (" .. L[Stats.data.school] .. ")" end
    GameTooltip:SetText(title, 1, 1, 1)
    local unit = row.percent and "per 1%" or "each"
    local weight = GP.Round(row.weight or 0, 3)
    local translated = rawget(L, "Weight: %s points %s")
    GameTooltip:AddLine(translated and string.format(translated, weight, L[unit])
        or string.format("Weight: %s point%s %s", weight, (row.weight == 1) and "" or "s", unit), 0.85, 0.85, 0.85)
    if row.share then
        GameTooltip:AddLine(string.format(L["Your gear's %s gives %d%% of your GearPath score."], row.label,
            GP.Round(row.share)), 0.85, 0.85, 0.85, true)
    end
    if row.fromGear then GameTooltip:AddLine(L["The game doesn't say this one; it's what your gear adds."], 0.6, 0.6, 0.6, true) end
    if row.delta and math.abs(row.delta) >= 0.05 then
        local text, role = Stats.DeltaText(row)
        local c = role == "GOOD" and { 0.25, 1, 0.25 } or { 1, 0.31, 0.31 }
        GameTooltip:AddLine(string.format(L["With what you're trying on: %s"], text), c[1], c[2], c[3])
    end
    GameTooltip:Show()
end

function Stats.Create(parent)
    local skin = GP.Skin.current
    local f = CreateFrame("Frame", nil, parent)
    f.head = skin.Text(f, "small", "TITLE")
    f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 4, 0)
    f.head:SetText(L["Your stats"])
    f.note = skin.Text(f, "small", "LABEL", "RIGHT")
    f.note:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, 0)
    f.note:SetPoint("LEFT", f.head, "RIGHT", 8, 0)
    f.note:SetWordWrap(false)
    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetHeight(1)
    f.line:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -16)
    f.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -16)
    f.line:SetColorTexture(1, 1, 1, 0.12)
    f.cells = {}
    for i = 1, Stats.MAX do
        local c = CreateFrame("Frame", nil, f)
        c:SetHeight(Stats.ROW)
        local col, r = (i - 1) % 2, math.floor((i - 1) / 2)
        c.col, c.r = col, r
        c.label = skin.Text(c, "small", "TEXT")
        c.label:SetPoint("LEFT", c, "LEFT", 0, 0)
        c.extra = skin.Text(c, "small", "LABEL", "RIGHT")
        c.extra:SetPoint("RIGHT", c, "RIGHT", 0, 0)
        c.extra:SetWidth(46)
        c.value = skin.Text(c, "body", "VALUE", "RIGHT")
        c.value:SetPoint("RIGHT", c.extra, "LEFT", -4, 0)
        c:EnableMouse(true)
        c:SetScript("OnEnter", cellTooltip)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.cells[i] = c
    end
    f.empty = skin.Text(f, "small", "WARN")
    f.empty:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.empty:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    f.empty:SetWordWrap(true)
    -- Two columns across whatever width the panel gets, and as many rows as
    -- fit its height (all of them unless the window is at its smallest).
    f:SetScript("OnSizeChanged", function(self, w, h)
        if type(w) ~= "number" or w <= 0 then return end
        local colW = (w - 8 - 18) / 2
        for _, c in ipairs(self.cells) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", self, "TOPLEFT", 4 + c.col * (colW + 18), -22 - c.r * Stats.ROW)
            c:SetWidth(colW)
        end
        if type(h) == "number" and h > 0 then
            local fit = math.max(1, math.floor((h - 22 - 18) / Stats.ROW))
            if fit ~= self.fitRows then
                self.fitRows = fit
                GP.Soon("stats", Stats.Fill)
            end
        end
    end)
    Stats.frame = f
    return f
end

function Stats.Fill()
    local f = Stats.frame
    if not f then return end
    local tried = UI.tried and next(UI.tried) and UI.tried or nil
    local data = Stats.Build(tried)
    Stats.data = data
    if tried then
        local n, name = 0, nil
        for _, ev in pairs(tried) do n, name = n + 1, ev.rec.name end
        f.note:SetText(n == 1 and string.format(L["With %s"], name or "?") or string.format(L["With the %d items you're trying on"], n))
        GP.Skin.current.Ink(f.note, "WARN")
    else
        f.note:SetText(L["Share of your score"])
        GP.Skin.current.Ink(f.note, "LABEL")
    end
    local cap = math.min(Stats.MAX, (f.fitRows or math.ceil(Stats.MAX / 2)) * 2)
    for i, c in ipairs(f.cells) do
        local row = i <= cap and data.rows[i] or nil
        c.row = row
        if row then
            c.label:SetText(row.label)
            c.value:SetText(fmt(row, row.value + (row.delta or 0)))
            if tried then
                local text, role = Stats.DeltaText(row)
                c.extra:SetText(text)
                GP.Skin.current.Ink(c.extra, role)
                GP.Skin.current.Ink(c.value, (row.delta and math.abs(row.delta) >= 0.05) and role or "VALUE")
            else
                c.extra:SetText(row.share and string.format("%d%%", GP.Round(row.share)) or "")
                GP.Skin.current.Ink(c.extra, "LABEL")
                GP.Skin.current.Ink(c.value, "VALUE")
            end
            c:Show()
        else
            c:Hide()
        end
    end
    local rows = math.ceil(math.min(#data.rows, cap) / 2)
    f.empty:ClearAllPoints()
    f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -22 - rows * Stats.ROW - 6)
    f.empty:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    if #data.empty > 0 then
        f.empty:SetText(GP.Count(#data.empty, "%d empty slot", "%d empty slots") .. ": " .. table.concat(data.empty, ", "))
    else
        f.empty:SetText("")
    end
end

-- Buffs and talents change your stats: kept up to date while shown (new
-- gear refills the whole tab once it's scored).
local function changed(_, unit)
    if unit and unit ~= "player" then return end
    if Stats.frame and Stats.frame:IsVisible() then GP.Soon("stats", Stats.Fill) end
end
for _, e in ipairs({ "UNIT_STATS", "UNIT_AURA", "UNIT_RESISTANCES", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER",
    "PLAYER_DAMAGE_DONE_MODS", "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED" }) do
    GP.RegisterEvent(e, changed)
end
