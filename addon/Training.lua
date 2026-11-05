-- Training: the weapon skills, armor and Dual Wield you still have to
-- learn. A class can learn more weapons than it starts with: weapon
-- masters in the capitals teach them (10 silver each; Polearms 1 gold from
-- level 20), and the class trainer teaches Mail or Plate at 40 and Dual
-- Wield. GearPath still lists gear that needs one of these, marked "Learn
-- Staves first", with who teaches it, and the Route puts the trainer on
-- the way.
--
-- What you know comes from the game (each skill is a spell you have or
-- don't). If the game's answer can't be trusted (you hold a weapon whose
-- skill reads as unknown), nothing is marked rather than everything.
--
-- The weapon masters and what each teaches: Forever's guides (Warcraft
-- Tavern, via foreverwisp.com, October 2026); their spots come from
-- QuestieDB.

local _, GP = ...

local Training = {}
GP.Training = Training

local Classes = GP.Classes
local W, A = Classes.W, Classes.A

-- The skill (a spell id) each weapon or armor type needs.
Training.WEAPON_SPELL = {
    [W.AXE1H] = 196, [W.AXE2H] = 197, [W.MACE1H] = 198, [W.MACE2H] = 199, [W.POLEARM] = 200,
    [W.SWORD1H] = 201, [W.SWORD2H] = 202, [W.STAFF] = 227, [W.BOW] = 264, [W.GUN] = 266,
    [W.DAGGER] = 1180, [W.THROWN] = 2567, [W.WAND] = 5009, [W.CROSSBOW] = 5011, [W.FIST] = 15590,
}
Training.ARMOR_SPELL = { [A.MAIL] = 8737, [A.PLATE] = 750, [A.SHIELD] = 9116 }
Training.DUAL_WIELD = 674

-- English names (the game's own, in the client's language, are used when it gives them).
Training.NAMES = {
    [196] = "One-Handed Axes", [197] = "Two-Handed Axes", [198] = "One-Handed Maces", [199] = "Two-Handed Maces",
    [200] = "Polearms", [201] = "One-Handed Swords", [202] = "Two-Handed Swords", [227] = "Staves", [264] = "Bows",
    [266] = "Guns", [1180] = "Daggers", [2567] = "Thrown", [5009] = "Wands", [5011] = "Crossbows",
    [15590] = "Fist Weapons", [8737] = "Mail", [750] = "Plate Mail", [9116] = "Shield", [674] = "Dual Wield",
}

Training.COST = 1000                 -- copper: 10 silver
Training.COSTS = { [200] = 10000 }   -- Polearms: 1 gold
Training.MIN_LEVEL = { [200] = 20 }  -- Polearms from level 20

local S = Training.WEAPON_SPELL
Training.MASTERS = {
    { id = 11867, name = "Woo Ping", city = "Stormwind", faction = "Alliance",
        teaches = { S[W.CROSSBOW], S[W.DAGGER], S[W.SWORD1H], S[W.SWORD2H], S[W.POLEARM], S[W.STAFF] } },
    { id = 11865, name = "Buliwyf Stonehand", city = "Ironforge", faction = "Alliance",
        teaches = { S[W.FIST], S[W.GUN], S[W.AXE1H], S[W.AXE2H], S[W.MACE1H], S[W.MACE2H] } },
    { id = 13084, name = "Bixi Wobblebonk", city = "Ironforge", faction = "Alliance",
        teaches = { S[W.CROSSBOW], S[W.DAGGER], S[W.THROWN] } },
    { id = 11866, name = "Ilyenia Moonfire", city = "Darnassus", faction = "Alliance",
        teaches = { S[W.BOW], S[W.DAGGER], S[W.FIST], S[W.STAFF], S[W.THROWN] } },
    { id = 11868, name = "Sayoc", city = "Orgrimmar", faction = "Horde",
        teaches = { S[W.BOW], S[W.DAGGER], S[W.FIST], S[W.AXE1H], S[W.AXE2H], S[W.STAFF], S[W.THROWN] } },
    { id = 2704, name = "Hanashi", city = "Orgrimmar", faction = "Horde",
        teaches = { S[W.BOW], S[W.AXE1H], S[W.AXE2H], S[W.STAFF], S[W.THROWN] } },
    { id = 11869, name = "Ansekhwa", city = "Thunder Bluff", faction = "Horde",
        teaches = { S[W.GUN], S[W.MACE1H], S[W.MACE2H], S[W.STAFF] } },
    { id = 11870, name = "Archibald", city = "Undercity", faction = "Horde",
        teaches = { S[W.CROSSBOW], S[W.DAGGER], S[W.SWORD1H], S[W.SWORD2H], S[W.POLEARM] } },
}

-- Which capital to send you to first: your race's own, then the nearest others.
Training.CITY_ORDER = {
    Scourge = { "Undercity", "Orgrimmar", "Thunder Bluff" },
    Orc = { "Orgrimmar", "Thunder Bluff", "Undercity" },
    Troll = { "Orgrimmar", "Thunder Bluff", "Undercity" },
    Tauren = { "Thunder Bluff", "Orgrimmar", "Undercity" },
    Human = { "Stormwind", "Ironforge", "Darnassus" },
    Dwarf = { "Ironforge", "Stormwind", "Darnassus" },
    Gnome = { "Ironforge", "Stormwind", "Darnassus" },
    NightElf = { "Darnassus", "Stormwind", "Ironforge" },
    Horde = { "Orgrimmar", "Undercity", "Thunder Bluff" },
    Alliance = { "Stormwind", "Ironforge", "Darnassus" },
}

-- ---------------------------------------------------------------------
-- What you know
-- ---------------------------------------------------------------------

-- true / false, or nil when the game can't say.
function Training.Known(spell)
    if not spell then return true end
    local f = IsPlayerSpell or IsSpellKnown
    if not f then return nil end
    local ok, v = pcall(f, spell)
    if not ok then return nil end
    v = GP.Plain(v)
    if v == nil then return nil end
    return v == true or v == 1
end

-- Whether the game's answers can be trusted: the weapons you hold read as
-- known. With none held, at least one weapon your class uses must.
function Training.Reliable()
    if Training.reliable ~= nil then return Training.reliable end
    local checked, ok = false, true
    for _, slot in ipairs({ 16, 17, 18 }) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        local id = link and GP.Items.IDFromLink(link)
        if id then
            local _, classID, subClassID = GP.Items.Instant(id)
            local spell = classID == Classes.WEAPON and Training.WEAPON_SPELL[subClassID]
            if spell then
                checked = true
                if Training.Known(spell) ~= true then ok = false end
            end
        end
    end
    if not checked then
        ok = false
        for sub in pairs(Classes.Data().weapons or {}) do
            if Training.Known(Training.WEAPON_SPELL[sub]) == true then ok = true break end
        end
    end
    Training.reliable = ok
    return ok
end

-- Asked again when your skills or gear change, and everything rescored
-- (a weapon skill or Dual Wield just learned clears its "Learn ... first").
-- The modern client calls the learned-spell event LEARNED_SPELL_IN_SKILL_LINE
-- (LEARNED_SPELL_IN_TAB before 11.0); whichever exists is used.
local function forget() Training.reliable = nil end
local function learned()
    forget()
    if GP.loggedIn then GP.Score.Request() end
end
GP.RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", learned)
GP.RegisterEvent("LEARNED_SPELL_IN_TAB", learned)
GP.RegisterEvent("SKILL_LINES_CHANGED", learned)
GP.RegisterEvent("SPELLS_CHANGED", learned)
GP.RegisterEvent("PLAYER_EQUIPMENT_CHANGED", forget)

function Training.SkillName(spell)
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, spell)
        if ok then name = GP.Plain(n) end
    elseif GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, spell)
        if ok then name = GP.Plain(n) end
    end
    return (type(name) == "string" and name ~= "") and name or Training.NAMES[spell] or ("Skill " .. tostring(spell))
end

-- ---------------------------------------------------------------------
-- Who teaches it
-- ---------------------------------------------------------------------

local function teaches(m, spell)
    for _, s in ipairs(m.teaches) do if s == spell then return true end end
    return false
end

-- The weapon masters of your faction who teach a skill, your race's
-- capital first. Each: { id, name, city, source } (source: a map pin).
function Training.Masters(spell)
    local p = GP.player or {}
    local faction = p.faction
    local order = Training.CITY_ORDER[p.race or ""] or Training.CITY_ORDER[faction or ""] or {}
    local rank = {}
    for i, c in ipairs(order) do rank[c] = i end
    local out = {}
    for _, m in ipairs(Training.MASTERS) do
        if (not faction or m.faction == faction) and teaches(m, spell) then out[#out + 1] = m end
    end
    table.sort(out, function(a, b) return (rank[a.city] or 9) < (rank[b.city] or 9) end)
    return out
end

-- A map pin for a weapon master (from QuestieDB's spawn), or nil.
function Training.Place(m, spell)
    m.places = m.places or {}
    if m.places[spell] ~= nil then return m.places[spell] or nil end
    local src
    local S2 = GP.Sources
    local s = S2.SpawnSummary and S2.Database() and S2.SpawnSummary("npc", m.id)
    if s and s.order[1] then
        local area = s.order[1]
        local at = s.at[area]
        local place = S2.Place(area, at and at[1], at and at[2])
        src = { kind = "trainer", id = m.id, name = m.name, skill = Training.SkillName(spell),
            areaId = place.areaId, mapID = place.mapID, x = place.x, y = place.y, zone = place.zone or m.city }
    end
    m.places[spell] = src or false
    return src
end

-- ---------------------------------------------------------------------
-- What an item needs
-- ---------------------------------------------------------------------

-- The skills you'd have to learn to use rec in slot (nil: none), each
-- { spell, name, kind = "weapon" (a weapon master) or "class" (your class
-- trainer), masters, cost, minLevel }.
function Training.Need(rec, slot)
    if not rec or not Training.Reliable() then return nil end
    local need = {}
    local function add(spell, kind)
        if Training.Known(spell) ~= false then return end
        local n = { spell = spell, kind = kind, name = Training.SkillName(spell) }
        if kind == "weapon" then
            n.masters = Training.Masters(spell)
            n.cost = Training.COSTS[spell] or Training.COST
            n.minLevel = Training.MIN_LEVEL[spell]
            -- No weapon master of yours teaches it (Wands): your class trainer.
            if #n.masters == 0 then n.kind = "class" end
        end
        need[#need + 1] = n
    end
    if rec.classID == Classes.WEAPON then
        add(Training.WEAPON_SPELL[rec.subClassID], "weapon")
        if slot == "SecondaryHandSlot" and (rec.equipLoc == "INVTYPE_WEAPON" or rec.equipLoc == "INVTYPE_WEAPONOFFHAND") then
            add(Training.DUAL_WIELD, "class")
        end
    elseif rec.classID == Classes.ARMOR then
        add(Training.ARMOR_SPELL[rec.subClassID], "class")
    end
    return #need > 0 and need or nil
end

-- "Learn Staves first" (a row's line), and the long one for tooltips:
-- "Learn Staves first: Archibald, Undercity (10 silver)".
function Training.Short(need)
    local names = {}
    for _, n in ipairs(need or {}) do names[#names + 1] = n.name end
    return string.format(GP.L["Learn %s first"], table.concat(names, " " .. GP.L["and"] .. " "))
end

function Training.Long(n)
    if n.kind == "class" then
        return string.format(GP.L["Learn %s first: your class trainer"], n.name)
    end
    local m = n.masters[1]
    local text = string.format(GP.L["Learn %s first: %s, %s (%s)"], n.name, m.name, m.city, GP.Money(n.cost))
    if n.minLevel and (GP.player.level or 0) < n.minLevel then
        text = text .. " " .. string.format(GP.L["from level %d"], n.minLevel)
    end
    return text
end

-- The skills the given picks still need, once each: { need, picks }.
function Training.ForPicks(picks)
    local bySpell, order = {}, {}
    for _, ev in ipairs(picks or {}) do
        for _, n in ipairs(ev.train or {}) do
            local t = bySpell[n.spell]
            if not t then
                t = { need = n, picks = {} }
                bySpell[n.spell] = t
                order[#order + 1] = t
            end
            t.picks[#t.picks + 1] = ev
        end
    end
    table.sort(order, function(a, b) return #a.picks > #b.picks end)
    return order
end
