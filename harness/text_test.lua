-- lua5.1 text_test.lua <addon dir> [locale]
-- GearPath's own text in every client language (Data/Text.lua):
--  * every string the code translates has all eight translations,
--  * format codes (%s, %d, %.1f...) match the English, in order,
--  * paired slot labels keep their " 1" / " 2",
--  * the addon runs in each language: every tab, Settings, the boxes.
local dir, only = arg[1], arg[2]
local here = arg[0]:match("^(.*)/[^/]*$") or "."

local checks, failed = 0, 0
local function check(cond, what)
    checks = checks + 1
    if not cond then failed = failed + 1 print("  FAIL: " .. what) end
end

local function read(path) local f = assert(io.open(path)); local s = f:read("*a"); f:close(); return s end
local function files()
    local out = {}
    for line in read(dir .. "/GearPath.toc"):gmatch("[^\r\n]+") do
        if not line:match("^##") and line:match("%.lua$") then out[#out + 1] = line:gsub("\\", "/") end
    end
    return out
end

-- Strings the code passes through L.
local used = {}
local function unescape(s) return (s:gsub('\\"', '"'):gsub("\\'", "'")) end
for _, f in ipairs(files()) do
    local s = read(dir .. "/" .. f)
    for k in s:gmatch('L%["(.-[^\\])"%]') do used[unescape(k)] = f end
    for k in s:gmatch('rawget%(L, "(.-[^\\])"%)') do used[unescape(k)] = f end
    for k in s:gmatch('GP%.Count%([^,]+, "[^"]*", "([^"]*)"%)') do used[k] = f end
    if f == "UI/Settings.lua" then
        for k, d in s:gmatch('%f[%w]row%(c, y, "(.-[^\\])",%s*"(.-[^\\])"') do used[unescape(k)] = f; used[unescape(d)] = f end
        for k in s:gmatch('section%(c, y, "(.-[^\\])"') do used[unescape(k)] = f end
        for _, d in s:gmatch('section%(c, y, "(.-[^\\])",%s*"(.-[^\\])"') do used[unescape(d)] = f end
    end
    for k in s:gmatch('RegisterPage%("%w+", {%s*text = "([^"]+)"') do used[k] = f end
end

local function specs(s)
    local t = {}
    for spec in s:gsub("%%%%", ""):gmatch("%%[-+ #0]*%d*%.?%d*[%a]") do t[#t + 1] = spec end
    return table.concat(t, " ")
end

local function load(locale)
    local H = dofile(here .. "/wow.lua")
    dofile(here .. "/data.lua")
    function GetLocale() return locale end
    GearPathDB, GearPathCharDB = nil, nil      -- a fresh install for each language
    local ns = {}
    for _, f in ipairs(files()) do
        local chunk = assert(loadfile(dir .. "/" .. f))
        local ok, err = pcall(chunk, "GearPath", ns)
        if not ok then print("  LOAD ERROR " .. f .. ": " .. tostring(err)) failed = failed + 1 end
    end
    H.Fire("ADDON_LOADED", "GearPath")
    H.Fire("PLAYER_LOGIN")
    for _ = 1, 60 do H.Tick(0.1) end
    return ns, H
end

-- English first: the tables translated in place, by their English values.
local GP = load("enUS")
local T = GP.Text.T
for _, tbl in ipairs({ GP.UI.TIER_TEXT, GP.UI.CONTENT_LABELS, GP.UI.SORT_LABELS, GP.UI.Stats.LABELS, GP.Classes.STAT_LABELS }) do
    for _, v in pairs(tbl) do used[v] = used[v] or "(table)" end
end
for _, s in ipairs(GP.Slots.LIST) do used[s.label] = "(slot)" end
for _, k in ipairs({ "Elite", "Rare Elite", "Boss", "Rare", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane", "per 1%", "each",
    "Automatic", "Open or close GearPath", "Nothing that needs a PvP rank, a reputation or a profession.", GP.Text.NOTICE }) do
    used[k] = used[k] or "(code)"
end
for _, list in pairs(GP.Classes.SPECS) do
    for _, sp in ipairs(list) do used[sp.name] = used[sp.name] or "(spec)" end
end
used["Relic"] = used["Relic"] or "(code)"
check(GP.L["Best now"] == "Best now" and not GP.Text.active, "an English client keeps the English")

local missing, n = 0, 0
for k, where in pairs(used) do
    n = n + 1
    local tr = T[k]
    if not tr then
        missing = missing + 1
        print("  missing translation: " .. k .. "  (" .. where .. ")")
    else
        for _, lang in ipairs(GP.Text.LANGS) do
            if type(tr[lang]) ~= "string" or tr[lang] == "" then
                missing = missing + 1
                print("  missing " .. lang .. ": " .. k)
            end
        end
    end
end
check(missing == 0, string.format("every one of the %d strings has all %d translations (%d missing)", n, #GP.Text.LANGS, missing))
local unused = {}
for k in pairs(T) do if not used[k] then unused[#unused + 1] = k end end
table.sort(unused)
for _, k in ipairs(unused) do print("  (not used by the code: " .. k .. ")") end

local bad = 0
for k, tr in pairs(T) do
    for _, lang in ipairs(GP.Text.LANGS) do
        local v = tr[lang]
        if type(v) == "string" and specs(v) ~= specs(k) then
            bad = bad + 1
            print(string.format("  format codes differ (%s): %q -> %q", lang, k, v))
        end
    end
end
check(bad == 0, "format codes match the English in every translation")
for _, lang in ipairs(GP.Text.LANGS) do
    for _, k in ipairs({ "Ring 1", "Ring 2", "Trinket 1", "Trinket 2" }) do
        local v = T[k] and T[k][lang] or ""
        check(v:sub(-2) == k:sub(-2), lang .. ": " .. k .. " keeps its number at the end (" .. v .. ")")
    end
end

-- Each language: the addon runs, the window and the boxes show translated text.
local codes = only and { only } or { "deDE", "frFR", "esES", "esMX", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
for _, code in ipairs(codes) do
    local G, H = load(code)
    local UI = G.UI
    check(G.Text.active, code .. ": translations on")
    local lang = G.Text.Lang(code)
    check(G.L["Best now"] == T["Best now"][lang], code .. ": Best now is " .. tostring(G.L["Best now"]))
    check(G.Slots.Label("HeadSlot") == T["Head"][lang], code .. ": slot names translated")
    check(G.Slots.Label("Finger0Slot") == T["Ring 1"][lang]:gsub(" %d$", ""), code .. ": a ring's slot name without its number")
    check(BINDING_NAME_GEARPATH_TOGGLE == T["Open or close GearPath"][lang], code .. ": the key binding's name")
    local said = table.concat(H.printed, "\n")
    check(said:find(T[G.Text.NOTICE][lang], 1, true) ~= nil, code .. ": a one-time note in chat says it's a machine draft")
    for _, page in ipairs({ "doll", "plan", "browse", "settings" }) do
        G.Toggle(page)
        if not UI.frame:IsShown() then G.Toggle(page) end
        check(UI.current == page, code .. ": the " .. page .. " tab opens")
    end
    UI.Show("doll")
    UI.SelectSlot("HandsSlot")
    UI.ItemClick(G.Score.ForItem(210), "LeftButton")
    check(UI.Doll.putOn:IsShown(), code .. ": Put it on shows")
    UI.Doll.putOn:_run("OnEnter")
    UI.Doll.ResetModel()
    UI.SelectSlot(nil)
    UI.Show("plan")
    local sec
    for _, it in ipairs(UI.Plan.list.items) do if it.kind == "section" then sec = sec or it.text end end
    check(sec == T["Best now"][lang], code .. ": the route's first section (" .. tostring(sec) .. ")")
    for _, it in ipairs(UI.Plan.list.items) do
        if it.kind == "item" then G.UI.Describe(it.ev.source, true) end
    end
    G.UI.StatusText(); G.UI.UpdateSub()
    SlashCmdList.GEARPATH("report"); SlashCmdList.GEARPATH("weights"); SlashCmdList.GEARPATH("status")
    G.Classes.ShowImport()
    G.LauncherTooltip(UIParent)
    UI.MinimapButton.button:_run("OnEnter")
    check(#H.errors == 0, code .. ": no errors (" .. tostring(H.errors[1]) .. ")")
    -- English text on: after a reload, English again.
    G.db.settings.englishText = true
    G.Text.Apply(nil)
    check(G.L["Best now"] == "Best now", code .. ": English text turns it off")
end

print(string.format("  text: %d checks, %d failed", checks, failed))
os.exit(failed == 0 and 0 or 1)
