-- Locales: how each client language words the "Equip:" lines GearPath reads
-- (spell power, hit, crit, mana per 5, attack power...). Blizzard's own
-- wording, taken from WoW Classic's tooltips in every language (October
-- 2026); the source items and full lines are in the dev kit's
-- LOCALE_RESEARCH.md. English is in Items.lua and is always tried last.
--
-- Each line: { pattern, stat }. Patterns run on the tooltip line in lower
-- case (English letters only: the game lowers nothing else), after the
-- "Equip:" word. Checked in order, the first match wins, so a longer
-- wording ("ranged attack power", "with spells") comes before the shorter
-- one it contains. "school" lines capture the school's name, looked up in
-- SCHOOLS. "sph" lines are spell power that heals as much as it damages
-- (counted as both). Italian clients show these lines in English.

local _, GP = ...

local L = {}
GP.LOCALES = L

-- A number, with a decimal point or comma ("1,5"), and a percent sign that
-- may have a space or a no-break space before it.
local N = "([%d%.,]+)"
local P = "[%s\194\160]*%%"

L.LINES = {
    deDE = {
        { "zauber und magische effekte zugefügten schaden und heilung um bis zu (%d+)", "sph" },
        { "durch (%S-)zauber und %S-effekte zugefügten schaden um bis zu (%d+)", "school" },
        { "zauber und effekte verursachte heilung um bis zu (%d+)", "heal" },
        { "chance mit zaubern zu treffen um " .. N .. P, "hit" },
        { "kritischen treffer durch zauber zu erzielen, um " .. N .. P, "crit" },
        { "kritischen treffer zu erzielen, um " .. N .. P, "crit" },
        { "trefferchance um " .. N .. P, "hit" },
        { "alle 5 sek%. (%d+) punkt", "mp5" },
        { "%+(%d+) distanzangriffskraft", "rap" },
        { "%+(%d+) angriffskraft", "ap" },
    },
    frFR = {
        { "dégâts et les soins produits par les sorts et effets magiques de (%d+)", "sph" },
        { "dégâts infligés par les sorts et effets (.-) de (%d+) au maximum", "school" },
        { "soins prodigués par les sorts et effets de (%d+)", "heal" },
        { "chances de toucher avec des sorts de " .. N .. P, "hit" },
        { "coup critique avec vos sorts de " .. N .. P, "crit" },
        { "coup critique de " .. N .. P, "crit" },
        { "chances de toucher de " .. N .. P, "hit" },
        { "rend (%d+) points de mana toutes les 5", "mp5" },
        { "%+(%d+) à la puissance des attaques à distance", "rap" },
        { "%+(%d+) à la puissance d.-attaque", "ap" },
    },
    esES = {
        { "daño y la curación de los hechizos mágicos y los efectos hasta en (%d+)", "sph" },
        { "daño causado por los hechizos de (.-) y los efectos hasta en (%d+)", "school" },
        { "curación de los hechizos y los efectos hasta en (%d+)", "heal" },
        { "alcanzar el objetivo con hechizos en un " .. N .. P, "hit" },
        { "golpe crítico en " .. N .. P .. " con los hechizos", "crit" },
        { "golpe crítico en " .. N .. P, "crit" },
        { "alcanzar el objetivo en un " .. N .. P, "hit" },
        { "restaura (%d+) p%. de maná cada 5", "mp5" },
        { "%+(%d+) p%. de poder de ataque a distancia", "rap" },
        { "%+(%d+) p%. de poder de ataque", "ap" },
    },
    esMX = {
        { "hasta (%d+) p%. el daño y la sanación de los hechizos y efectos mágicos", "sph" },
        { "hasta (%d+) p%. el daño que infligen los hechizos y efectos de (.+)", "school" },
        { "hasta (%d+) p%. la sanación de los hechizos y efectos", "heal" },
        { "mejora un " .. N .. P .. " tu probabilidad de golpear con hechizos", "hit" },
        { "golpe crítico con hechizos un " .. N .. P, "crit" },
        { "mejora un " .. N .. P .. " tu probabilidad de conseguir un golpe crítico", "crit" },
        { "probabilidad de golpear un " .. N .. P, "hit" },
        { "restaura (%d+) p%. de maná cada 5", "mp5" },
        { "aumenta (%d+) p%. el poder de ataque a distancia", "rap" },
        { "aumenta (%d+) p%. el poder de ataque", "ap" },
    },
    ptBR = {
        { "em até (%d+) o dano causado e a cura realizada por feitiços e efeitos mágicos", "sph" },
        { "em até (%d+) o dano causado por feitiços e efeitos de (.+)", "school" },
        { "em até (%d+) a cura realizada por feitiços", "heal" },
        { "em " .. N .. P .. " sua chance de acertar com feitiços", "hit" },
        { "em " .. N .. P .. " a chance de realizar acertos críticos com feitiços", "crit" },
        { "em " .. N .. P .. " a chance de realizar acertos críticos", "crit" },
        { "em " .. N .. P .. " a chance de acerto", "hit" },
        { "restaura (%d+) de mana a cada 5", "mp5" },
        { "%+(%d+) de poder de ataque de longo alcance", "rap" },
        { "%+(%d+) de poder de ataque", "ap" },
    },
    ruRU = {
        { "урона и целительного действия магических заклинаний и эффектов не более чем на (%d+)", "sph" },
        { "урона от заклинаний и эффектов (.-) не более чем на (%d+)", "school" },
        { "наносимого заклинаниями и эффектами (.-), на (%d+)", "school" },
        { "исцеление от заклинаний и эффектов максимум на (%d+)", "heal" },
        { "на " .. N .. P .. " рейтинга меткости заклинаний", "hit" },
        { "рейтинга критического эффекта заклинаний на " .. N .. P, "crit" },
        { "вероятности нанесения критического урона на " .. N .. P, "crit" },
        { "нанесения удара увеличена на " .. N .. P, "hit" },
        { "(%d+) ед%. маны раз в 5", "mp5" },
        { "силы атаки в дальнем бою на (%d+)", "rap" },
        { "силу атаки на (%d+)", "ap" },
    },
    koKR = {
        { "모든 주문 및 효과에 의한 피해와 치유량이 최대 (%d+)", "sph" },
        { "(%S+) 계열의 주문과 효과의 공격력이 최대 (%d+)", "school" },
        { "모든 주문 및 효과에 의한 치유량이 최대 (%d+)", "heal" },
        { "주문의 적중률이 " .. N .. P, "hit" },
        { "주문이 극대화 효과를 낼 확률이 " .. N .. P, "crit" },
        { "치명타를 적중시킬 확률이 " .. N .. P, "crit" },
        { "무기의 적중률이 " .. N .. P, "hit" },
        { "매 5초마다 (%d+)의 마나", "mp5" },
        { "원거리 전투력 %+(%d+)", "rap" },
        { "전투력 %+(%d+)", "ap" },
    },
    zhCN = {
        { "提高所有法术和魔法效果所造成的伤害和治疗效果，最多(%d+)", "sph" },
        { "提高(.-)法术和效果所造成的伤害，最多(%d+)", "school" },
        { "使(.-)法术所造成的伤害提高最多(%d+)", "school" },
        { "提高法术所造成的治疗效果，最多(%d+)", "heal" },
        { "使你的法术击中敌人的几率提高" .. N .. P, "hit" },
        { "使你的法术造成暴击的几率提高" .. N .. P, "crit" },
        { "使你的法术造成爆击的几率提高" .. N .. P, "crit" },
        { "使你造成爆击的几率提高" .. N .. P, "crit" },
        { "使你造成暴击的几率提高" .. N .. P, "crit" },
        { "使你击中目标的几率提高" .. N .. P, "hit" },
        { "每5秒回复(%d+)点法力值", "mp5" },
        { "%+(%d+)%s*远程攻击强度", "rap" },
        { "%+(%d+)%s*攻击强度", "ap" },
    },
    zhTW = {
        { "提高魔法法術和效果所造成的傷害和治療效果，最多(%d+)", "sph" },
        { "提高(.-)法術和效果所造成的傷害，最多(%d+)", "school" },
        { "使用(.-)法術所造成的傷害提高最多(%d+)", "school" },
        { "提高法術和魔法效果所造成的治療效果，最多(%d+)", "heal" },
        { "使你的法術擊中敵人的機率提高" .. N .. P, "hit" },
        { "使你的法術造成致命一擊的機率提高" .. N .. P, "crit" },
        { "使你造成致命一擊的機率提高" .. N .. P, "crit" },
        { "使你擊中目標的機率提高" .. N .. P, "hit" },
        { "每5秒恢復(%d+)點法力", "mp5" },
        { "%+(%d+)%s*遠程攻擊強度", "rap" },
        { "%+(%d+)%s*攻擊強度", "ap" },
    },
}

-- School names as the lines word them (Fire and Shadow checked against the
-- game's text; the others are each language's usual name for the school).
L.SCHOOLS = {
    deDE = { feuer = "spFire", schatten = "spShadow", frost = "spFrost", arkan = "spArcane",
        natur = "spNature", heilig = "spHoly" },
    frFR = { feu = "spFire", ombre = "spShadow", givre = "spFrost", arcanes = "spArcane", arcane = "spArcane",
        nature = "spNature", ["sacré"] = "spHoly" },
    esES = { fuego = "spFire", sombras = "spShadow", sombra = "spShadow", escarcha = "spFrost",
        arcano = "spArcane", arcanos = "spArcane", naturaleza = "spNature", sagrado = "spHoly" },
    esMX = { fuego = "spFire", sombras = "spShadow", sombra = "spShadow", escarcha = "spFrost",
        arcano = "spArcane", arcanos = "spArcane", naturaleza = "spNature", sagrado = "spHoly" },
    ptBR = { fogo = "spFire", sombra = "spShadow", gelo = "spFrost", arcano = "spArcane",
        natureza = "spNature", sagrado = "spHoly" },
    ruRU = { ["огня"] = "spFire", ["темной магии"] = "spShadow", ["тёмной магии"] = "spShadow",
        ["льда"] = "spFrost", ["тайной магии"] = "spArcane", ["сил природы"] = "spNature",
        ["природы"] = "spNature", ["светлой магии"] = "spHoly", ["света"] = "spHoly" },
    koKR = { ["화염"] = "spFire", ["암흑"] = "spShadow", ["냉기"] = "spFrost", ["비전"] = "spArcane",
        ["자연"] = "spNature", ["신성"] = "spHoly" },
    zhCN = { ["火焰"] = "spFire", ["暗影"] = "spShadow", ["冰霜"] = "spFrost", ["奥术"] = "spArcane",
        ["自然"] = "spNature", ["神圣"] = "spHoly" },
    zhTW = { ["火焰"] = "spFire", ["暗影"] = "spShadow", ["冰霜"] = "spFrost", ["秘法"] = "spArcane",
        ["自然"] = "spNature", ["神聖"] = "spHoly" },
}

-- Client languages GearPath reads (English and Italian use the English lines).
L.READS = { enUS = true, enGB = true, itIT = true }
for code in pairs(L.LINES) do L.READS[code] = true end

-- A school's name as captured from a line, down to its bare word: no
-- article or preposition before it ("de ", "d'", "las ") and no full stop.
function L.SchoolWord(word)
    if type(word) ~= "string" then return nil end
    local w = word:lower():gsub("[%.。]+$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    for _, prefix in ipairs({ "de ", "d'", "d\226\128\153", "las ", "los ", "la ", "el ", "le ", "l'" }) do
        if w:sub(1, #prefix) == prefix then w = w:sub(#prefix + 1) break end
    end
    return w
end
