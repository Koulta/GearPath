-- Crafts: LibProfessionDB (the ProfessionDB addon, by Pimptasty, MIT), when
-- it's installed, as the list of gear your professions can make. It's built
-- from Forever's own game files: every recipe, the item it makes, the skill
-- it takes and how it's learned (a trainer, a vendor, a drop). GearPath
-- reads it while the game runs, through LibStub; nothing of it is copied,
-- and without it this file does nothing (crafted gear then comes only from
-- your profession window and trainers, Learn.lua).
--
-- Its skill numbers run high for Forever (Simple Dress: 40 by ProfessionDB,
-- 25 at Kil'hala; checked Nov 7), so a trainer's own number, once GearPath
-- has seen it, always wins, and ProfessionDB's is marked unconfirmed.

local _, GP = ...

local Crafts = {}
GP.Crafts = Crafts

-- ProfessionDB's profession ids (the skill lines) and a spell of each, whose
-- name is the profession's name in the game's language ("Tailoring").
Crafts.SPELL = {
    [171] = 2259,   -- Alchemy
    [164] = 2018,   -- Blacksmithing
    [333] = 7411,   -- Enchanting
    [202] = 4036,   -- Engineering
    [165] = 2108,   -- Leatherworking
    [197] = 3908,   -- Tailoring
    [185] = 2550,   -- Cooking
    [129] = 3273,   -- First Aid
    [356] = 7620,   -- Fishing
    [186] = 2575,   -- Mining
}
Crafts.ENGLISH = {
    [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
    [165] = "Leatherworking", [197] = "Tailoring", [185] = "Cooking", [129] = "First Aid",
    [356] = "Fishing", [186] = "Mining",
}

-- The library, once it has data for this game; else nil (kept once found).
local found
function Crafts.Lib()
    if found then return found end
    local LS = rawget(_G, "LibStub")
    if type(LS) ~= "table" and type(LS) ~= "function" then return nil end
    local ok, lib = pcall(LS, "LibProfessionDB-1.0", true)
    if not ok or type(lib) ~= "table" then return nil end
    if not (lib.IsReady and lib.Iterate) then return nil end
    local ok2, ready = pcall(lib.IsReady, lib)
    if not (ok2 and ready) then return nil end
    found = lib
    return lib
end

function Crafts.Available() return Crafts.Lib() ~= nil end

-- A profession's name in the game's language, by ProfessionDB's id.
local names = {}
function Crafts.ProfName(profId)
    if names[profId] then return names[profId] end
    local spell, name = Crafts.SPELL[profId], nil
    if spell then
        if C_Spell and C_Spell.GetSpellName then
            local ok, n = pcall(C_Spell.GetSpellName, spell)
            if ok then name = GP.Plain(n) end
        elseif GetSpellInfo then
            local ok, n = pcall(GetSpellInfo, spell)
            if ok then name = GP.Plain(n) end
        end
    end
    if type(name) ~= "string" or name == "" then name = Crafts.ENGLISH[profId] end
    names[profId] = name
    return name
end

-- The item index: [crafted itemID] = { { prof = profId, spell = recipeId }, ... },
-- built once from the library (2,511 recipes for Forever: a moment's work).
-- Recipes the game never let anyone learn are left out.
local index
function Crafts.Index()
    if index then return index end
    local lib = Crafts.Lib()
    if not lib then return nil end
    index = {}
    local count = 0
    for profId, spell, e in lib:Iterate() do
        local item = type(e) == "table" and e.craftedItemId
        local hidden = lib.IsHiddenRecipe and lib:IsHiddenRecipe(spell)
        if type(item) == "number" and not hidden then
            local list = index[item]
            if not list then
                list = {}
                index[item] = list
            end
            list[#list + 1] = { prof = profId, spell = spell }
            count = count + 1
        end
    end
    Crafts.count = count
    return index
end

-- For the tests, and if the library turns up late.
function Crafts.Reset() index, names, found = nil, {}, nil end

-- The professions you have, from your skills: { [profId] = name }.
function Crafts.Mine()
    local mine = {}
    if not (GetNumSkillLines and GetSkillLineInfo) then return mine end
    local have = {}
    for i = 1, GP.Plain(GetNumSkillLines()) or 0 do
        local name, header = GetSkillLineInfo(i)
        name = GP.Plain(name)
        if type(name) == "string" and not header then have[name] = true end
    end
    for profId in pairs(Crafts.SPELL) do
        local name = Crafts.ProfName(profId)
        if name and have[name] then mine[profId] = name end
    end
    return mine
end

-- What ProfessionDB says about making an item, one entry per recipe:
--   { prof = name, profId, spell, rank (skill it takes, or nil),
--     auto (learned with the profession), item (the recipe item, if any),
--     sources (the library's own lists: trainer/vendor/quest/drop/container) }
function Crafts.RecipesFor(itemID)
    local idx = Crafts.Index()
    local list = idx and idx[itemID]
    if not list then return nil end
    local lib = Crafts.Lib()
    local out = {}
    for _, r in ipairs(list) do
        local e = lib:GetRecipe(r.prof, r.spell) or {}
        local item = lib.GetRecipeItem and lib:GetRecipeItem(r.spell) or e.itemId
        out[#out + 1] = {
            prof = Crafts.ProfName(r.prof), profId = r.prof, spell = r.spell,
            rank = type(e.requiredSkill) == "number" and e.requiredSkill or nil,
            auto = lib.IsAutoTaughtRecipe and lib:IsAutoTaughtRecipe(r.spell) or false,
            item = type(item) == "number" and item or nil,
            sources = lib.GetRecipeSources and lib:GetRecipeSources(r.spell) or nil,
        }
    end
    return out
end

-- Every crafted item your professions make: { [itemID] = true }.
function Crafts.MyItems()
    local out = {}
    local idx = Crafts.Index()
    if not idx then return out end
    local mine = Crafts.Mine()
    if not next(mine) then return out end
    for item, list in pairs(idx) do
        for _, r in ipairs(list) do
            if mine[r.prof] then
                out[item] = true
                break
            end
        end
    end
    return out
end

-- Do you know a recipe? true, or nil when the game can't say (the profession
-- window, read by Learn.lua, is the other way to know).
function Crafts.Known(spell)
    if not (spell and IsPlayerSpell) then return nil end
    local ok, v = pcall(IsPlayerSpell, spell)
    if not ok then return nil end
    v = GP.Plain(v)
    if v == true or v == 1 then return true end
    return nil
end

-- For /gp status: "ProfessionDB: 2,511 recipes (Forever), 412 make gear for you".
function Crafts.StatusLine()
    local lib = Crafts.Lib()
    if not lib then return nil end
    local total = lib.Count and lib:Count() or 0
    local game = lib.GetGameVersion and lib:GetGameVersion() or "?"
    local mine = 0
    for _ in pairs(Crafts.MyItems()) do mine = mine + 1 end
    return string.format("ProfessionDB: %d recipes (%s), %d items your professions make.", total, tostring(game), mine)
end
