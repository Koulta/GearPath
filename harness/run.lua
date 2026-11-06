-- lua5.1 run.lua <addon dir> <native|daylight> [nodb]
local dir, look, extra = arg[1], arg[2] or "native", arg[3]
local here = arg[0]:match("^(.*)/[^/]*$") or "."

local H = dofile(here .. "/wow.lua")
H.noDB = extra == "nodb"
dofile(here .. "/data.lua")
if look == "daylight" then dofile(here .. "/dui.lua") end
if look == "ellesmere" then assert(loadfile(here .. "/eui.lua"))(H) end

local checks, failed = 0, 0
local function check(cond, what)
    checks = checks + 1
    if not cond then
        failed = failed + 1
        print("  FAIL: " .. what)
    end
end

-- Load the addon in TOC order, as the client does.
local ns = {}
local toc = io.open(dir .. "/GearPath.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local path = dir .. "/" .. line:gsub("\\", "/")
        local chunk = assert(loadfile(path))
        local ok, err = pcall(chunk, "GearPath", ns)
        if not ok then print("  LOAD ERROR " .. line .. ": " .. tostring(err)); failed = failed + 1 end
    end
end
local GP = ns
check(_G.GearPath == GP, "GearPath global")

-- The fake world sends this Horde warlock to Westfall as a stand-in zone:
-- its home-ground rule is off until the faction checks below.
local realAllianceHome = GP.Sources.HOME.Alliance
GP.Sources.HOME.Alliance = {}
H.Fire("ADDON_LOADED", "GearPath")
H.Fire("PLAYER_LOGIN")
if look == "ellesmere" then H.loggedIn = true; H.EUILogin() end
GP.db.settings.look = (look == "daylight" or look == "ellesmere") and "auto" or "native"

-- Scan: the login timer, the background job, item loading.
for _ = 1, 400 do
    H.Tick(0.1)
    if GP.Sources.status == "ready" or GP.Sources.status == "nodb" and GP.Score.results.all[1] then
        if GP.Sources.status == "ready" or _ > 80 then break end
    end
end
for _ = 1, 20 do H.Tick(0.1) end
print(string.format("  status=%s candidates=%d loaded=%d", GP.Sources.status, GP.Sources.counts.candidates, GP.Sources.counts.loaded))

local res = GP.Score.results
local tiers = {}
for _, ev in ipairs(res.all) do
    tiers[ev.rec.id] = ev.tier or "none"
    print(string.format("    %d %-24s slot=%-17s delta=%6.2f pct=%s tier=%s effort=%s src=%s", ev.rec.id, ev.rec.name, ev.slot,
        ev.delta, ev.pct and string.format("%.0f", ev.pct) or "-", ev.tier or "-", ev.effort,
        GP.UI.Describe(ev.source)))
end

if not H.noDB then
    check(GP.Sources.status == "ready", "scan finished")
    check(tiers[200] == "primary", "200 cowl (quest, lvl 21) is Best now")
    check(tiers[201] == "primary", "201 robe (2-quest chain, lvl 24) is Best now")
    check(tiers[202] ~= nil, "202 dagger (vendor) is listed")
    check(tiers[203] == "secondary", "203 ring (elite drop) is Worth chasing")
    check(tiers[204] == "secondary", "204 cloak (Deadmines quest) is Worth chasing")
    check(tiers[205] == nil, "205 mail chest is left out for a warlock")
    check(tiers[206] == "none", "206 world drop is listed but not counted as an upgrade by default")
    check(tiers[207] == nil, "207 reward of a done quest is left out")
    check(tiers[209] ~= nil, "209 (loaded late) is listed")
    check(tiers[210] == "primary", "210 gloves in the bags are Best now")
    check(tiers[211] == "primary", "211 wand (quest) is Best now")
    check(tiers[213] == "secondary", "213 from a level 30 quest is Worth chasing at 23, not Best now (got " .. tostring(tiers[213]) .. ")")
    check(tiers[214] == "none", "214 from random chests isn't counted as an upgrade (got " .. tostring(tiers[214]) .. ")")
    check(GP.UI.Describe(GP.Score.ForItem(214).source):find("Random chests"), "random chests read as random")
    local ev215 = GP.Score.ForItem(215)
    check(ev215 and ev215.needs == "Sergeant", "215 knows it needs Sergeant (got " .. tostring(ev215 and ev215.needs) .. ")")
    check(tiers[215] == "locked", "215 (needs a PvP rank) waits under Needs something first (got " .. tostring(tiers[215]) .. ")")
    local ev201 = GP.Score.ForItem(201)
    check(ev201 and ev201.source.chainLength == 2, "201 knows its chain")
    check(ev201 and ev201.source.chainStart and ev201.source.chainStart.zone == "Duskwood", "201 chain starts in Duskwood")
    local ev204 = GP.Score.ForItem(204)
    check(ev204 and ev204.source.dungeon == "The Deadmines", "204 is a Deadmines quest")
    -- One reward per quest: 200 and 211 both come from quest 5000.
    local fromQuest = 0
    for _, ev in ipairs(res.plan.picks) do
        if ev.source and ev.source.kind == "quest" and ev.source.id == 5000 then fromQuest = fromQuest + 1 end
    end
    check(fromQuest == 1, "the route takes one reward from quest 5000 (got " .. fromQuest .. ")")
    print("  route:")
    for _, z in ipairs(res.plan.zones) do
        local names = {}
        for _, ev in ipairs(z.picks) do names[#names + 1] = ev.rec.name end
        print("    " .. z.zone .. ": " .. table.concat(names, ", "))
    end
else
    check(GP.Sources.status == "nodb" or GP.Sources.status == "ready", "runs without QuestieDB")
    check(tiers[210] == "primary", "bag gloves still found without QuestieDB")
end

-- ---------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------

GP.Toggle()
local UI = GP.UI
check(UI.frame ~= nil, "window built")
check(UI.frame and UI.frame:IsShown(), "window open")
check(GP.Skin.current.name == look, "look is " .. look .. " (got " .. tostring(GP.Skin.current and GP.Skin.current.name) .. ")")
check(UI.current == "doll", "opens on Character")
for _ = 1, 3 do H.Tick(0.1) end

local function activeRows(list)
    local n, kinds = 0, {}
    for row in pairs(list.active) do
        n = n + 1
        kinds[row.kindName] = (kinds[row.kindName] or 0) + 1
    end
    return n, kinds
end

local n = activeRows(UI.SlotPanel.list)
check(n > 0, "slot panel shows rows (" .. n .. ")")

-- Hover an item row: tooltip with GearPath lines.
local itemRow
for row in pairs(UI.SlotPanel.list.active) do if row.kindName == "item" then itemRow = row break end end
check(itemRow ~= nil, "an item row is on screen")
if itemRow then
    itemRow:_run("OnEnter")
    local text = table.concat(GameTooltip._lines or {}, "\n")
    check(text:find("GearPath:"), "item tooltip has the GearPath line")
    check(text:find("Click: try it on"), "item tooltip has the click hints")
    print("  tooltip:\n    " .. text:gsub("\n", "\n    "))
    itemRow:Click("LeftButton")
    check(UI.model._tried ~= nil, "click tries the item on the model")
    itemRow:Click("RightButton")
    if not H.noDB then check(H.waypoint ~= nil or H.printed[#H.printed]:find("Waypoint"), "right-click sets a waypoint") end
    if H.waypoint then print(string.format("  waypoint: map %d at %.3f, %.3f", H.waypoint.m, H.waypoint.x, H.waypoint.y)) end
    if not H.noDB then
        check(H.mapOpened == (H.waypoint and H.waypoint.m), "the world map opens at the pin")
        print("  chat: " .. tostring(H.printed[#H.printed]):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        -- And the pin button on a row does the same.
        H.waypoint, H.mapOpened = nil, nil
        itemRow.pin:Click()
        check(H.waypoint ~= nil and H.mapOpened ~= nil, "the row's map pin button sets a pin and opens the map")
    end
end

-- Near you: the all-slots view starts with what's in your zone, closest first.
do
    UI.SelectSlot(nil)
    UI.Show("doll")
    local function nearRows()
        local sec, rows, on = nil, {}, false
        for _, it in ipairs(UI.SlotPanel.list.items) do
            if it.kind == "section" then
                on = it.text == "Near you"
                if on then sec = it end
            elseif on and it.kind == "item" then
                rows[#rows + 1] = it
            end
        end
        return sec, rows
    end
    local sec, rows = nearRows()
    check(sec ~= nil and sec.right == "Tirisfal Glades", "Near you names the zone you're in (" .. tostring(sec and sec.right) .. ")")
    for _, it in ipairs(rows) do print("  near: " .. it.ev.rec.name .. "  |  " .. it.prefix .. "  |  " .. UI.Describe(it.ev.source)) end
    if not H.noDB then
        check(#rows > 0, "Near you lists upgrades sold or given here")
        check(rows[1] and rows[1].prefix:find("right here"), "the closest says it's right here (" .. tostring(rows[1] and rows[1].prefix) .. ")")
        check(rows[1] and rows[1].ev.source.mapID == 1420, "its line and pin go by the nearby place")
        -- Walk across the zone: the distances follow.
        H.playerX = 0.30
        UI.SlotPanel.RefreshNear(false)
        local _, far = nearRows()
        check(far[1] and far[1].prefix:find("k yd"), "walking away updates the distance (" .. tostring(far[1] and far[1].prefix) .. ")")
        H.playerX = nil
        UI.SlotPanel.RefreshNear(false)
        -- Clicking one on the Character tab still tries it on.
        UI.model._tried = nil
        UI.ItemClick(rows[1].ev, "LeftButton")
        check(UI.model._tried ~= nil, "a near item click tries it on")
    end
    -- Inside a dungeon: what drops in it.
    local inInst, instInfo = IsInInstance, GetInstanceInfo
    IsInInstance = function() return true, "party" end
    GetInstanceInfo = function() return "The Deadmines" end
    UI.SlotPanel.RefreshNear(true)
    local isec = nearRows()
    check(isec ~= nil and isec.right == "The Deadmines", "inside a dungeon, Near you is the dungeon")
    IsInInstance, GetInstanceInfo = inInst, instInfo
    -- A slot picked: no Near you.
    UI.SelectSlot("HeadSlot")
    check(nearRows() == nil, "a picked slot doesn't show Near you")
    UI.SelectSlot(nil)
end

-- Slots: the head has an upgrade arrow; clicking it lists the head.
local doll = UI.Doll
check(UI.selectedSlot == nil, "no slot picked at first")
UI.SelectSlot("HeadSlot")
check(UI.SlotPanel.title:GetText() == "Head", "slot panel shows Head")
UI.SelectSlot("Finger1Slot")
check(UI.SlotPanel.title:GetText() == "Ring", "rings group together")
UI.SelectSlot(nil)
doll.ResetModel()

-- Every page fills without errors.
for _, id in ipairs({ "plan", "browse", "settings", "doll" }) do
    local before = #H.errors
    UI.Show(id)
    check(#H.errors == before, "page " .. id .. " fills cleanly")
end

UI.Show("plan")
local pn, pk = activeRows(UI.Plan.list)
check(pn > 0 and (pk.header or 0) > 0, "route shows zones")

-- A click on a route item: the map pin, never the game's dressing room.
do
    local row
    for r in pairs(UI.Plan.list.active) do
        if r.kindName == "item" and r.item.ev.source and GP.Waypoint.CanSet(r.item.ev.source) then row = r break end
    end
    check(row ~= nil, "a route item with a place is on screen")
    if row then
        H.waypoint, H.dressedUp, H.lastModified = nil, nil, nil
        UI.model._tried = nil
        row:_run("OnEnter")
        local text = table.concat(GameTooltip._lines or {}, "\n")
        check(text:find("Click: map pin") and text:find("Ctrl%-click: dressing room"), "route tooltip says a click is the map pin")
        check(not text:find("try it on"), "route tooltip doesn't promise a try-on")
        row:Click("LeftButton")
        check(H.waypoint ~= nil, "clicking a route item sets its map pin")
        check(H.dressedUp == nil and UI.model._tried == nil, "clicking a route item opens no dressing room")
        H.modified = true
        row:Click("LeftButton")
        H.modified = false
        check(H.lastModified ~= nil, "Ctrl/Shift-click goes to the game's own handling")
    end
    -- No pin buttons on the route: the item rows hide theirs, the group bars have none
-- and a click on a bar is the pin.
do
    local shownPins, header = 0, nil
    for r in pairs(UI.Plan.list.active) do
        if r.kindName == "item" and r.pin:IsShown() then shownPins = shownPins + 1 end
        if r.kindName == "header" and not header and r.item.source and GP.Waypoint.CanSet(r.item.source) then header = r end
    end
    check(shownPins == 0, "route item rows show no pin buttons")
    check(header ~= nil, "a route group with a place is on screen")
    if header then
        check(header.pin == nil, "route group bars have no pin button")
        H.waypoint = nil
        header:Click("LeftButton")
        check(H.waypoint ~= nil, "clicking a route group's bar sets its map pin")
    end
end
-- An item with nowhere to pin: the click does nothing and the hint says why.
    local ev = { rec = { id = 1, name = "x" }, source = { kind = "drop", name = "Someone" } }
    if not GP.Waypoint.CanSet(ev.source) then
        H.waypoint, H.dressedUp = nil, nil
        UI.ItemClick(ev, "LeftButton")
        check(H.waypoint == nil and H.dressedUp == nil, "no place: the click does nothing")
        check(UI.ClickHint(ev):find("isn't in the database"), "no place: the hint says so")
    end
end

UI.Show("browse")
local before = UI.Browse.count:GetText()
UI.Browse.search:SetText("robe")
H.Tick(0.1)
check(H.noDB or UI.Browse.count:GetText() == "1 item", "search 'robe' finds 1 (got " .. tostring(UI.Browse.count:GetText()) .. ", was " .. tostring(before) .. ")")
UI.Browse.search:SetText("")
H.Tick(0.1)
UI.Browse.only:Click()
check(UI.Browse.state.upgrades == true, "Upgrades only switches on")
UI.Browse.sort:Click()
check(H.lastMenu ~= nil, "sort opens a menu")
if look == "native" and H.lastMenu and H.lastMenu.radios then
    H.lastMenu.radios[4].setSel()
    check(GP.Setting("browseSort") == "name", "menu picks name")
elseif H.lastMenu and H.lastMenu.onPick then
    H.lastMenu.onPick("name")
    check(GP.Setting("browseSort") == "name", "menu picks name")
end

-- The content filter: types, the switch list, every tab following it.
if not H.noDB then
    local C = UI.ContentOf
    check(C(GP.Score.ForItem(200)) == "quest", "200 is a quest item")
    check(C(GP.Score.ForItem(204)) == "dungeon", "204 is dungeon content")
    check(C(GP.Score.ForItem(202)) == "vendor", "202 is a vendor item")
    check(C(GP.Score.ForItem(203)) == "drop", "203 is a mob drop")
    check(C(GP.Score.ForItem(214)) == "world", "214 is world drops & chests")
    check(C(GP.Score.ForItem(210)) == "bags", "210 is in the bags")
    check(C(GP.Score.ForItem(215)) == "pvp", "215 is PvP rank")
    check(GP.Score.ForItem(215).tier == "locked", "215 sits under Needs something first")

    UI.Show("browse")
    local all = UI.Browse.count:GetText()
    UI.Browse.source:Click()                 -- opens the switches
    local popup
    for _, f in ipairs(H.frames) do if f.rows and f.catcher then popup = f end end
    check(popup ~= nil and popup:IsShown(), "Show: opens a list of switches")
    UI.SetAllContent(false)
    popup.rows[1]:Click()                    -- tick Quests
    H.Tick(0.1)
    check(UI.ContentOn("quest") and not UI.ContentOn("vendor"), "only Quests is ticked")
    check(UI.ContentSummary() == "Quests", "the button says Quests (got " .. UI.ContentSummary() .. ")")
    local onlyQuests = true
    for row in pairs(UI.Browse.list.active) do
        if row.item and row.item.ev and C(row.item.ev) ~= "quest" then onlyQuests = false end
    end
    check(onlyQuests, "Browse shows only quest items")
    print("  browse: " .. tostring(all) .. " -> " .. tostring(UI.Browse.count:GetText()) .. " with Quests only")
    popup.rows[2]:Click()                    -- and Dungeons
    H.Tick(0.1)
    check(UI.ContentSummary() == "Quests, Dungeons", "two kinds read as a list (got " .. UI.ContentSummary() .. ")")
    popup.catcher:Click()
    check(not popup:IsShown(), "a click elsewhere closes the switches")

    UI.Show("plan")
    local planOk = true
    for _, ev in ipairs(GP.Score.BuildPlan(GP.Score.results, UI.ContentMatches).picks) do
        if C(ev) ~= "quest" and C(ev) ~= "dungeon" then planOk = false end
    end
    check(planOk, "the route keeps to the ticked kinds")
    UI.Show("doll")
    UI.SelectSlot(nil)
    local panelOk = true
    for row in pairs(UI.SlotPanel.list.active) do
        if row.item and row.item.ev and not UI.ContentMatches(row.item.ev) then panelOk = false end
    end
    check(panelOk, "the slot lists keep to the ticked kinds")
    UI.SetAllContent(false)
    UI.SetContent("pvp", true)
    H.Tick(0.1)
    local sawLocked = false
    for row in pairs(UI.SlotPanel.list.active) do
        if row.kindName == "section" and row.text:GetText() == UI.TIER_TEXT.locked then sawLocked = true end
    end
    check(sawLocked, "PvP rank alone shows Needs something first")
    UI.SetAllContent(true)
    H.Tick(0.1)
    check(UI.ContentSummary() == "Everything", "All ticks everything back")
end

UI.Show("settings")
local errs = #H.errors
GP.SetSetting("ahead", 3)
for _ = 1, 30 do H.Tick(0.1) end
check(#H.errors == errs, "changing look-ahead rescans cleanly")

-- Learn: a quest window offering an item the database doesn't know.
H.Fire("QUEST_DETAIL")
for _ = 1, 5 do H.Tick(0.1) end
check(GP.db.learned.items[212] ~= nil, "a quest reward seen in game is learned")
check(GP.Score.ForItem(212) ~= nil, "the learned item is scored")
if GP.Score.ForItem(212) then print("  learned: " .. GP.UI.Describe(GP.Score.ForItem(212).source, true)) end

-- DungeonJournal as a second source.
if not H.noDB then
    local e217 = GP.Sources.entries[217]
    check(e217 and e217.fromJournal, "217, only in DungeonJournal, joins the gear list")
    local d = e217 and GP.UI.Describe(e217.best, true) or ""
    check(d:find("Lord Shade %(Boss%), Shadow Keep"), "217 reads as a boss drop in Shadow Keep (" .. d .. ")")
    check(GP.Waypoint.CanSet(e217 and e217.best), "217 has a pin at the dungeon entrance")
    local e218 = GP.Sources.entries[218]
    local q
    for _, s in ipairs(e218 and e218.sources or {}) do if s.kind == "quest" then q = s end end
    check(q and q.id == 5005 and q.choice == false, "218's quest gives every reward (not pick-one)")
    check(q and q.giver == "Captain Grey", "the journal's quest giver is used")
    local alliance = false
    for _, s in ipairs(e218 and e218.sources or {}) do if s.id == 5006 then alliance = true end end
    check(not alliance, "an Alliance-only journal quest is left out for the Horde")
    UI.Show("plan")
    local bands, gaps = {}, 0
    for row in pairs(UI.Plan.list.active) do
        if row.kindName == "header" and row.item then bands[row.item.text] = row.item.tone end
        if row.kindName == "gap" then gaps = gaps + 1 end
    end
    check(bands["Shadow Keep"] == "dungeon", "Shadow Keep gets a dungeon band on the route")
    check(gaps > 0, "groups have room between them")
end

-- The checker.
if not H.noDB then
    local C = GP.Check
    check(C.ResultFor(200) ~= nil, "the first check ran after the scan")
    local r202 = C.ResultFor(202)
    local changed = false
    for _, w in ipairs(r202 and r202.warnings or {}) do if w.key == "changed" then changed = true end end
    check(changed, "202: the game says level 22, the database 20: flagged as changed in Forever")
    check(C.Mark(202):find("ReadyCheck%-Waiting"), "202 gets the ? mark")
    check(C.ResultFor(212) and C.ResultFor(212).confirmed, "212, seen in game, is confirmed")
    UI.Show("doll")
    UI.SelectSlot("MainHandSlot")
    check(C.lastSlot.MainHandSlot ~= nil, "clicking a slot checks it")
    local sawNote = false
    for row in pairs(UI.SlotPanel.list.active) do
        if row.kindName == "note" and (row.text:GetText() or ""):find("Checked") then sawNote = true end
    end
    check(sawNote, "the slot panel says what the check found")
    UI.SelectSlot(nil)
    local before = #H.printed
    SlashCmdList.GEARPATH("check")
    for _ = 1, 10 do H.Tick(0.2) end
    local said = table.concat(H.printed, "\n", before + 1)
    check(said:find("Checked %d+ items"), "/gp check reports (" .. tostring(said:match("Checked[^\n]*")) .. ")")
end

-- Healer gear (Healing its main stat): left out from every source; a drop's tooltip says to let the healer roll.
if not H.noDB then
    local cape, mantle = GP.Score.ForItem(230), GP.Score.ForItem(231)
    check(cape and cape.healer and cape.healerPass and cape.tier == nil, "a healer cape that drops is left out")
    check(mantle and mantle.healer and mantle.healerPass and mantle.tier == nil, "a healer quest reward is left out too")
    local function tip(id)
        GameTooltip._lines = {}
        GP.Tooltip.Add(GameTooltip, id)
        return table.concat(GameTooltip._lines or {}, "\n")
    end
    check(tip(230):find("let your healer roll first"), "the dropped one's tooltip says to let the healer roll")
    check(tip(231):find("not listed for you"), "the quest one's tooltip says it's not listed")
    GP.SetSetting("healerGear", true); GP.Score.Run()
    check(GP.Score.ForItem(230).tier ~= nil and GP.Score.ForItem(231).tier ~= nil, "with healer gear asked for, both are listed")
    GP.SetSetting("healerGear", false); GP.Score.Run()
    check(GP.Score.ForItem(230).tier == nil and GP.Score.ForItem(231).tier == nil, "and left out again when it's off")
    -- A class whose weights value Healing (the default Priest) isn't steered away.
    check(GP.Score.HealerGear(cape.rec, { heal = 0.4 }) == false, "a healer's weights keep healer gear")
end

-- Sharing: what Learn saw goes out; what others report comes in.
if not H.noDB then
    for _ = 1, 20 do H.Tick(0.5) end   -- the flush ticker
    local out
    for _, m in ipairs(H.sent) do if m.msg:find("Q:212:6000") then out = m end end
    check(out ~= nil and out.prefix == "GearPath", "a quest reward seen in game is shared")
    local where = {}
    for _, m in ipairs(H.sent) do where[m.chatType] = true end
    check(GP.Setting("shareChannel") == true, "the GearPath channel is on to begin with")
    for _ = 1, 30 do H.Tick(1) end    -- past the login delay: it joins, then says so once
    check((GetChannelName("GearPathData")) > 0, "GearPath joins its channel after login")
    local said = 0
    for _, line in ipairs(H.printed) do if line:find("hidden chat channel", 1, true) then said = said + 1 end end
    check(said == 1 and GP.db.shareNoticed == true, "a chat line says once that it shares through the channel (" .. said .. ")")
    GP.Share.Notice()
    local again = 0
    for _, line in ipairs(H.printed) do if line:find("hidden chat channel", 1, true) then again = again + 1 end end
    check(again == 1, "and doesn't say it again")
    if out then print("  sent: " .. out.msg) end
    GP.Share.Send("v", 9901, 9001, 1420, 0.5, 0.5, "Test Vendor")
    for _ = 1, 10 do H.Tick(0.5) end
    local onChannel, onGuild = false, false
    for _, m in ipairs(H.sent) do
        if m.msg:find("V:9901") then
            if m.chatType == "CHANNEL" then onChannel = true end
            if m.chatType == "GUILD" then onGuild = true end
        end
    end
    check(onChannel and onGuild, "sources go to the guild and the channel")
    GP.SetSetting("shareChannel", false); GP.Share.Changed()
    check((GetChannelName("GearPathData")) == 0, "turning it off leaves the channel")
    -- The game rejoins channels from earlier sessions; with it off, GearPath leaves.
    JoinTemporaryChannel("GearPathData"); GP.Share.Changed()
    check((GetChannelName("GearPathData")) == 0, "a channel the game rejoined is left when it's off")
    GP.Share.Send("v", 9902, 9001, 1420, 0.5, 0.5, "Test Vendor")
    for _ = 1, 10 do H.Tick(0.5) end
    local leaked = false
    for _, m in ipairs(H.sent) do if m.chatType == "CHANNEL" and m.msg:find("V:9902") then leaked = true end end
    check(not leaked, "with it off, nothing goes to the channel")
    -- Saves from before 0.7.3 had it off by default: switched on once (and told);
    -- a later choice to turn it off sticks.
    local keep = GearPathDB
    GearPathDB = { schema = 2, shareNoticed = true, settings = { shareChannel = false } }
    GP.InitDB()
    check(GP.db.settings.shareChannel == true and GP.db.schema == GP.SCHEMA and not GP.db.shareNoticed,
        "an older save's channel setting is switched on once, and the chat line will say so")
    GP.db.settings.shareChannel = false
    GP.InitDB()
    check(GP.db.settings.shareChannel == false, "turning it off afterwards sticks")
    GearPathDB = keep
    GP.InitDB()
    GP.SetSetting("shareChannel", true); GP.Share.Changed()
    -- Two strangers report 216 dropping from Mob 9100, which the database doesn't know.
    local function hear(sender, channel, msg) H.Fire("CHAT_MSG_ADDON", "GearPath", msg, channel, sender, "", 0, 0, "", 0) end
    hear("Bob-Forever", "CHANNEL", "1;D:203:9100:1431:500:500:Mob 9100")
    H.Tick(0.1)
    local function hasShared(id, npc)
        local e = GP.Sources.entries[id]
        for _, s in ipairs(e and e.sources or {}) do if s.kind == "drop" and s.id == npc then return s end end
    end
    check(not hasShared(203, 9100), "one stranger's report of an unknown source isn't shown yet")
    hear("Ann-Forever", "CHANNEL", "1;D:203:9100:1431:500:500:Mob 9100")
    H.Tick(0.1)
    local s = hasShared(203, 9100)
    check(s and s.reporters == 2, "two reports and it shows, reported by 2")
    check(s and GP.UI.Describe(s):find("reported by other players", 1, true), "a source only players report says so")
    -- More than eight voices: the count stops at 8, and one player can't pump it.
    for i = 1, 7 do hear("V" .. i .. "-Forever", "CHANNEL", "1;D:203:9100:1431:500:500:Mob 9100") end
    for _ = 1, 5 do hear("V7-Forever", "CHANNEL", "1;D:203:9100:1431:500:500:Mob 9100") end
    hear("Zed-Forever", "CHANNEL", "1;D:203:9100:1431:500:500:Mob 9100")
    check(GP.db.shared.items[203].d[9100].c == 8, "the reporter count stops at 8 (" .. GP.db.shared.items[203].d[9100].c .. ")")
    -- A spot on a map the game doesn't have: the source stays, the pin doesn't.
    hear("Bob-Forever", "CHANNEL", "1;D:204:9101:99998:500:500:Far Mob")
    hear("Ann-Forever", "CHANNEL", "1;D:204:9101:99998:500:500:Far Mob")
    H.Tick(0.1)
    local far = hasShared(204, 9101)
    check(far and far.mapID == nil and far.x == nil, "a reported pin on an unknown map is dropped")
    -- Within one session, new items stop being taken past the saved cap.
    local was = GP.Share.newItems
    GP.Share.newItems = GP.Learn.SHARED_MAX
    hear("Ann-Forever", "CHANNEL", "1;V:8801:9001:1431:500:500:Test Vendor")
    check(not GP.db.shared.items[8801], "new items stop at the cap within a session")
    GP.Share.newItems = was
    -- A guild mate confirms what the database already says (203 drops from 9002).
    hear("Cal-Forever", "GUILD", "1;D:203:9002:1431:772:361:Stalvan Mistmantle")
    H.Tick(0.1)
    local dbSrc = hasShared(203, 9002)
    check(dbSrc and dbSrc.reporters == 1 and not dbSrc.shared, "a report of a known source confirms the database's copy")
    GP.Check.Item(GP.Sources.entries[203])
    check((GP.Check.ResultFor(203).reported or 0) > 0, "the checker counts it as seen by other players")
    -- Rubbish and tricks are dropped.
    local n = 0
    for _ in pairs(GP.db.shared.items) do n = n + 1 end
    hear("Eve-Forever", "CHANNEL", "1;Q:1:2:3:4:5:|Hitem:1|h[x]|h;D:abc:1:1:1:1:x;V:5:5:5:5000:5:x;" .. string.rep("Q:9:9:9:9:9:x;", 40))
    hear("Eve-Forever", "CHANNEL", "2;Q:7:7:7:7:7:new version")
    local m = 0
    for _ in pairs(GP.db.shared.items) do m = m + 1 end
    check(m <= n + 1, "bad records, other versions and floods are dropped (" .. n .. " -> " .. m .. ")")
    check(not GP.db.shared.items[1], "a record carrying a link is refused")
    hear("Koulta-Forever", "CHANNEL", "1;Q:300:300:1:1:1:me")
    check(not GP.db.shared.items[300], "your own messages are ignored")
    -- What's saved is dated and kept in bounds.
    local Learn = GP.Learn
    check(GP.db.shared.items[203].d[9100].s == H.wall, "a shared source keeps when it was last reported")
    check(GP.db.learned.items[212] and GP.db.learned.items[212].q[6000].s == H.wall, "a source you saw keeps when you saw it")
    local DAY = 86400
    local t = {
        [1] = { d = { [10] = { s = H.wall - 61 * DAY }, [11] = { s = H.wall - 5 * DAY } } },
        [2] = { v = { [12] = { s = H.wall - 90 * DAY } } },
        [3] = { q = { [13] = {} } },                 -- from before 0.6.0: no date
        [4] = "rubbish",
    }
    local kept, dropped = Learn.Prune(t, 10, 60, H.wall)
    check(not t[1].d[10] and t[1].d[11], "a shared source unseen for 60 days is dropped, a recent one kept")
    check(t[2] == nil, "an item left with no sources is dropped too")
    check(t[3].q[13].s == H.wall, "a source saved before dates were kept is dated today")
    check(t[4] == nil, "a broken entry is dropped")
    check(kept == 2 and dropped == 2, "kept 2, dropped 2 (" .. kept .. ", " .. dropped .. ")")
    -- Over the cap: the longest unseen go first, whatever their kind.
    local big = {}
    for i = 1, 30 do big[i] = { d = { [i] = { s = H.wall - i * 3600 } } } end
    kept, dropped = Learn.Prune(big, 20, nil, H.wall)
    check(kept == 20 and dropped == 10 and Learn.Count(big) == 20, "cut to the cap (" .. Learn.Count(big) .. " kept)")
    check(big[1] and big[20] and not big[21] and not big[30], "the newest are the ones kept")
    -- Your own sightings have no age limit.
    local mine = { [5] = { q = { [1] = { s = H.wall - 400 * DAY } } } }
    Learn.Prune(mine, Learn.LEARNED_MAX, nil, H.wall)
    check(mine[5] and mine[5].q[1], "a source you saw a year ago is still kept")
    -- On load, both saved lists are pruned before the first scan.
    GP.db.shared.items[777] = { d = { [1] = { s = H.wall - 100 * DAY, c = 3, by = {} } } }
    GP.Fire("Loaded")
    check(GP.db.shared.items[777] == nil, "an old shared source is gone after the next load")
    check(GP.db.shared.items[203] and GP.db.learned.items[212], "recent ones survive the load")
    -- The rate counts from a minute ago are cleared.
    GP.Share.rate["Old-Forever"] = { start = H.now - 120, n = 3 }
    for _ = 1, 8 do H.Tick(0.5) end
    check(GP.Share.rate["Old-Forever"] == nil, "old rate counts are cleared")
end

-- The mouse wheel moves a list by a useful step, and stops at the ends.
do
    GP.Toggle("plan")
    local sf = UI.Plan.list.sf
    local wheel = sf:GetScript("OnMouseWheel")
    check(type(wheel) == "function", "lists handle the mouse wheel")
    local range = sf:GetVerticalScrollRange()
    if wheel and range > 0 then
        sf:SetVerticalScroll(0)
        wheel(sf, -1)
        local one = sf:GetVerticalScroll()
        check(one >= 48 or one == range, "one notch moves at least two rows' worth (" .. one .. ")")
        for _ = 1, 200 do wheel(sf, -1) end
        check(sf:GetVerticalScroll() == range, "the wheel stops at the bottom")
        for _ = 1, 200 do wheel(sf, 1) end
        check(sf:GetVerticalScroll() == 0, "the wheel stops at the top")
    end
end

-- The window can be made bigger, not smaller, and goes back on a right-click.
do
    local f = UI.frame
    if look == "daylight" then
        local o = f.gripOpts
        check(o ~= nil, "DaylightUI's grip is on the window")
        if o then
            check(o.min[1] == UI.W and o.min[2] == UI.H, "the grip can't go under the made size")
            f:SetSize(1100, 760); o.set(1100, 760)
            check(GP.db.window.size and GP.db.window.size[2] == 760, "the dragged size is kept")
            o.reset()
            check(GP.db.window.size == nil and f:GetHeight() == UI.H, "right-click puts the made size back")
        end
    else
        local g = f.grip
        check(g ~= nil, "the window has a size grip")
        if g then
            g:GetScript("OnMouseDown")(g, "LeftButton")
            f:SetSize(1100, 760)
            g:GetScript("OnMouseUp")(g, "LeftButton")
            check(GP.db.window.size and GP.db.window.size[1] == 1100, "the dragged size is kept")
            g:GetScript("OnMouseUp")(g, "RightButton")
            check(GP.db.window.size == nil and f:GetWidth() == UI.W, "right-click puts the made size back")
        end
    end
end

-- Rare watch: in the Deadmines, an icon for each rare that drops an upgrade.
if not H.noDB then
    local RW = GP.RareWatch
    local inInst, instInfo = IsInInstance, GetInstanceInfo
    IsInInstance = function() return true, "party" end
    GetInstanceInfo = function() return "The Deadmines" end
    RW.Refresh()
    check(RW.active and RW.count == 2, "in the Deadmines, both rares with upgrades are watched (" .. tostring(RW.count) .. ")")
    check(RW.frame ~= nil and RW.frame:IsShown(), "the row shows")
    local shown = {}
    for _, b in ipairs(RW.icons or {}) do if b:IsShown() then shown[#shown + 1] = b end end
    check(#shown == 2, "one icon per rare")
    check(shown[1] and shown[1].label:GetText() == "Miner Testson", "the biggest upgrade's rare comes first, named under its icon")
    check(shown[2] and shown[2].label:GetText() == "Foreman Testly", "the other rare has its own icon")
    local r, r2 = RW.watch.id9200, RW.watch.id9201
    check(r ~= nil and RW.state[r] == nil and not shown[1].glow:IsShown(), "dim until its rare is seen")
    -- Its tooltip: what it drops and how close you need to be.
    shown[1]:_run("OnEnter")
    local tip = table.concat(GameTooltip._lines or {}, "\n")
    check(tip:find("Testson's Vestments") and tip:find("60 yards"), "the tooltip names the drop and your nameplate range")
    H.cvars.nameplateShowEnemies = "0"
    shown[1]:_run("OnEnter")
    tip = table.concat(GameTooltip._lines or {}, "\n")
    check(tip:find("Enemy nameplates are off"), "and warns when enemy nameplates are off")
    H.cvars.nameplateShowEnemies = "1"
    H.units.nameplate1 = { guid = "Creature-0-1-2-3-4-9100-0001", name = "Mob 9100" }
    H.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    check(RW.state[r] == nil and RW.state[r2] == nil, "another mob's nameplate lights nothing")
    local before = #H.printed
    H.units.nameplate2 = { guid = "Creature-0-1-2-3-4-9200-0002", name = "Miner Testson" }
    H.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    check(RW.state[r] == "up" and RW.state[r2] == nil, "the rare's nameplate lights only its own icon")
    check(shown[1].glow:IsShown() and not shown[2].glow:IsShown(), "its icon glows, the other stays dim")
    local said = table.concat(H.printed, "\n", before + 1)
    check(said:find("Miner Testson is here") and said:find("Testson's Vestments"), "and chat says it's here and what it drops")
    if r then print("  rare watch: " .. (said:match("[^\n]*is here[^\n]*") or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    -- In combat: out of sight; a rare spotted then still gets its sound and chat line.
    H.Fire("PLAYER_REGEN_DISABLED")
    check(not RW.frame:IsShown(), "the row hides when combat starts")
    before = #H.printed
    H.units.target = { name = "Foreman Testly" }
    RW.Check("target")
    check(RW.state[r2] == "up" and not RW.frame:IsShown(), "a rare seen in combat is noted, the row stays hidden")
    check(table.concat(H.printed, "\n", before + 1):find("Foreman Testly is here"), "and chat still says so")
    H.Fire("PLAYER_REGEN_ENABLED")
    check(RW.frame:IsShown() and shown[2].glow:IsShown(), "after combat the row is back, that icon lit")
    H.units.nameplate2.dead = true
    RW.Check("nameplate2")
    check(RW.state[r] == "dead" and shown[1].mark:GetText() ~= "", "seen dead, its icon gets the killed check")
    shown[1]:GetScript("OnClick")(shown[1], "RightButton")
    check(not RW.frame:IsShown(), "right-click hides the row for the run")
    SlashCmdList.GEARPATH("rare")
    check(RW.frame:IsShown(), "/gp rare brings it back")
    GP.SetSetting("rareWatch", false); RW.Refresh()
    check(not RW.frame:IsShown(), "off in Settings, no icons")
    GP.SetSetting("rareWatch", true)
    IsInInstance, GetInstanceInfo = inInst, instInfo
    H.units.nameplate1, H.units.nameplate2, H.units.target = nil, nil, nil
    RW.Refresh()
    check(not RW.frame:IsShown() and RW.world, "out of the dungeon, the row goes away")
    -- Out in Tirisfal: Gorefang drops an upgrade; watched quietly, nothing on screen.
    local g = RW.watch.id9300
    check(RW.active and g ~= nil and RW.count == 1, "out in the world, your zone's rare with an upgrade is watched (" .. RW.count .. ")")
    check(RW.watch.id9200 == nil, "a dungeon's rares aren't watched out in the world")
    check(not RW.frame:IsShown(), "nothing shows until it comes into view")
    before = #H.printed
    SlashCmdList.GEARPATH("rare")
    check(table.concat(H.printed, "\n", before + 1):find("watching for Gorefang"), "/gp rare says which rares it watches for")
    g = RW.watch.id9300
    before = #H.printed
    H.units.nameplate3 = { guid = "Creature-0-1-2-3-4-9300-0003", name = "Gorefang" }
    H.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    check(RW.state[g] == "up" and RW.frame:IsShown(), "its nameplate: the icon pops up")
    check(table.concat(H.printed, "\n", before + 1):find("Gorefang is here! It drops Gorefang's Collar"), "with the chat line")
    local vis = 0
    for _, b in ipairs(RW.icons) do if b:IsShown() then vis = vis + 1 end end
    check(vis == 1 and RW.icons[1].label:GetText() == "Gorefang", "only the rare in view has an icon")
    -- Out of sight for a while: it goes, and coming back is news again.
    H.units.nameplate3 = nil
    for _ = 1, 50 do H.Tick(2) end
    check(not RW.frame:IsShown() and RW.state[g] == nil, "out of sight a while, the icon goes")
    before = #H.printed
    H.units.target = { guid = "Creature-0-1-2-3-4-9300-0003", name = "Gorefang" }
    H.Fire("PLAYER_TARGET_CHANGED")
    check(RW.frame:IsShown() and table.concat(H.printed, "\n", before + 1):find("Gorefang is here"), "back in view: it pops up again")
    g = RW.watch.id9300
    -- Killed: the check for a few seconds, then gone.
    H.units.target.dead = true
    H.Fire("PLAYER_TARGET_CHANGED")
    check(RW.state[g] == "dead" and RW.icons[1].mark:GetText() ~= "", "killed: the icon gets its check")
    H.units.target = nil
    for _ = 1, 10 do H.Tick(2) end
    check(not RW.frame:IsShown(), "and goes after a few seconds")
    -- Off in Settings: not watched out in the world (dungeons are their own switch).
    GP.SetSetting("rareWatchWorld", false); RW.Refresh()
    check(not RW.active and RW.count == 0, "the open-world switch turns it off")
    GP.SetSetting("rareWatchWorld", true); RW.Refresh()
    H.units.nameplate1, H.units.nameplate2, H.units.nameplate3, H.units.target = nil, nil, nil, nil
end

-- Precise places: a dungeon drop pins the entrance, a dungeon quest its giver outside.
if not H.noDB then
    local W = GP.Waypoint
    -- The Deadmines rare's robe: the database's entrance (Westfall 42.5, 71.7).
    local robe = GP.Sources.entries[232]
    local p = robe and W.PlaceOf(robe.best)
    check(p and p.kind == "entrance" and p.dungeon == "The Deadmines", "a dungeon drop's place is the dungeon's entrance")
    local text = robe and GP.UI.Describe(robe.best, true) or ""
    check(text:find("Drop: Miner Testson %(Rare Elite%), The Deadmines") and text:find("Entrance: Westfall %(42%.5, 71%.7%)"),
        "its line names the dungeon and the entrance (" .. text .. ")")
    print("  place: " .. text)
    -- The dungeon quest: picked up from Scout Riell in Westfall, the Deadmines in brackets.
    local cloak = GP.Sources.entries[204]
    local qs
    for _, s in ipairs(cloak and cloak.sources or {}) do if s.kind == "quest" and s.id == 5002 then qs = s end end
    local qp = qs and W.PlaceOf(qs)
    check(qp and qp.kind ~= "entrance" and qp.mapID == 1436, "a dungeon quest's place is its giver, outside")
    local qt = qs and GP.UI.Describe(qs, true) or ""
    check(qt:find("%(The Deadmines%) from Scout Riell, Westfall %(42%.0, 71%.0%)"), "its line says the dungeon and where you get it (" .. qt .. ")")
    print("  place: " .. qt)
    -- The pin message.
    H.waypoint = nil
    local before = #H.printed
    W.Set(robe.best, "Testson's Vestments")
    local said = table.concat(H.printed, "\n", before + 1)
    check(H.waypoint and H.waypoint.m == 1436 and said:find("The Deadmines entrance, Westfall %(42%.5, 71%.7%) %(for Testson's Vestments%)"),
        "the pin message says it's the entrance, and for what (" .. said:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. ")")
    before = #H.printed
    W.Set(qs, "Defias Shadow Cloak")
    said = table.concat(H.printed, "\n", before + 1)
    check(said:find("Scout Riell, Westfall %(42%.0, 71%.0%): starts Red Silk Bandanas %(for Defias Shadow Cloak%)"),
        "a quest pin names the giver and the quest to start")
    -- The journal's wing entrance and its directions.
    if not H.noJournal then
        local e = W.Entrance("Shadow Keep")
        check(e and e.mapID == 1431 and e.detail == "Up the hill behind the inn, through the iron gate", "the journal's entrance and the way in")
        local mantle = GP.Sources.entries[217]
        local mp = mantle and W.PlaceOf(mantle.best)
        check(mp and mp.kind == "entrance" and mp.dungeon == "Shadow Keep", "a journal boss drop pins its dungeon's entrance")
        GameTooltip._lines = {}
        GP.Tooltip.Add(GameTooltip, 217)
        check(table.concat(GameTooltip._lines, "\n"):find("through the iron gate"), "the tooltip gives the way in")
        before = #H.printed
        W.Set(mantle.best, "Shade Mantle")
        check(table.concat(H.printed, "\n", before + 1):find("through the iron gate"), "and so does the pin message")
    end
    -- On the route, a dungeon's bar pins its entrance.
    UI.Show("plan")
    local bar
    for _, it in ipairs(UI.Plan.list.items) do
        if it.kind == "header" and it.tone == "dungeon" then bar = it break end
    end
    check(bar and bar.source and bar.source.kind == "entrance", "a dungeon's bar on the route pins its entrance")
end

-- Warlock weights for Forever: Spirit (Life Tap) and crit (DoTs crit) count more.
do
    local w = GP.Classes.Weights("WARLOCK")
    check(w.spi == 0.55 and w.crit == 7.5 and w.hit == 11 and w.haste == 5,
        "Warlock weights follow the Affliction order (Spell Power > Hit > Intellect > Spirit > Crit)")
    for _, c in ipairs({ "WARLOCK", "MAGE", "PRIEST", "ROGUE", "HUNTER", "WARRIOR", "PALADIN", "SHAMAN", "DRUID" }) do
        check(type(GP.Classes.DATA[c].weights.haste) == "number", c .. " scores Haste")
    end
end

-- Quest reward pick: the best upgrade among the choices, else the best seller.
if not H.noDB then
    local QP = GP.QuestPick
    local npc = CreateFrame("Frame", "DaylightUINpc", UIParent)
    npc:Show()
    -- Choices: a robe that's an upgrade, a healer cape, mail you can't wear.
    H.choices = { 230, 232, 205 }
    QP.said = nil
    local before = #H.printed
    H.Fire("QUEST_COMPLETE")
    local pick = QP.pick
    check(pick and pick.kind == "upgrade" and pick.rec.id == 232, "the upgrade is the pick (" .. tostring(pick and pick.rec.name) .. ")")
    check(QP.card and QP.card:IsShown() and QP.card.name:GetText() == "Testson's Vestments", "a pick card shows beside DaylightUI's window")
    local said = table.concat(H.printed, "\n", before + 1)
    check(said:find("Pick") and said:find("Testson's Vestments"), "chat names the pick on turn-in")
    print("  quest pick: " .. (said:match("[^\n]*Pick[^\n]*") or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]*|h", ""):gsub("|h", ""))
    -- No upgrades: the best seller (healer gear still sells).
    H.choices = { 205, 230 }
    QP.said = nil
    before = #H.printed
    H.Fire("QUEST_COMPLETE")
    check(QP.pick and QP.pick.kind == "sell" and QP.pick.rec.id == 230, "with no upgrade, the best seller is the pick")
    check(table.concat(H.printed, "\n", before + 1):find("None of these rewards are upgrades"), "and chat says none are upgrades")
    -- The game's own quest window: an arrow on the picked button.
    npc:Hide()
    local qf = CreateFrame("Frame", "QuestFrame", UIParent)
    qf:Show()
    local rf = CreateFrame("Frame", "QuestInfoRewardsFrame", qf)
    rf.RewardButtons = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, rf)
        b.type = "choice"
        b.GetID = function() return i end
        b:Show()
        rf.RewardButtons[i] = b
    end
    H.choices = { 230, 232, 205 }
    H.Fire("QUEST_DETAIL")
    local arrowOn = {}
    for i, b in ipairs(rf.RewardButtons) do arrowOn[i] = b.gpArrow ~= nil and b.gpArrow:IsShown() end
    check(arrowOn[2] and not arrowOn[1] and not arrowOn[3], "in the game's window, only the picked button gets the arrow")
    check(QP.card:IsShown(), "and the card shows beside it")
    H.Fire("QUEST_FINISHED")
    check(not QP.card:IsShown(), "the card goes when the quest window closes")
    GP.SetSetting("questPick", false)
    H.Fire("QUEST_DETAIL")
    check(not QP.card:IsShown(), "off in Settings, no pick")
    GP.SetSetting("questPick", true)
    H.Fire("QUEST_FINISHED")
    qf:Hide()
    H.choices = nil
end

-- The seven QoL notes.
local function plain(t) return (t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]*|h", ""):gsub("|h", "") end
if not H.noDB then
    local W, T = GP.Waypoint, GP.Tooltip
    -- 1. NPC and mob tooltips.
    local function unitLines(guid, name)
        H.units.mouseover = { guid = guid, name = name }
        H.ShowUnit(GameTooltip, "mouseover")
        H.units.mouseover = nil
        return table.concat(GameTooltip._lines, "\n")
    end
    local vendor = unitLines("Creature-0-1-0-1-9001-00001", "Abigail Shiel")
    check(vendor:find("GearPath: sells Ritual Dagger") or vendor:find("GearPath: sells Slow Bracers"), "a vendor's tooltip names the upgrade it sells")
    check(not vendor:find("Sergeant's Cloak"), "but not gear that needs a rank first")
    local giver = unitLines("Creature-0-1-0-1-9000-00001", "Gryan Stoutmantle")
    check(giver:find("GearPath: quest reward Shadowweave Cowl"), "a quest giver's tooltip names the reward for you")
    check(not giver:find("Healer Quest Mantle"), "healer gear isn't listed on a quest giver")
    local eva = unitLines("Creature-0-1-0-1-9003-00001", "Madame Eva")
    check(eva:find("Robe of the Lost Order"), "the giver who starts a chain names its reward")
    local mob = unitLines("Creature-0-1-0-1-9002-00001", "Stalvan Mistmantle")
    check(mob:find("GearPath: drops Ring of Dark Whispers"), "a mob's tooltip names the upgrade it drops")
    check(not mob:find("Glowing Test Cape"), "a mob's healer drop isn't listed")
    print("  unit tooltip: " .. plain(mob):gsub("\n", " / "))
    check(not unitLines("Player-1-00000001", "Somebody"):find("GearPath"), "nothing on a player")
    if not H.noJournal then
        check(unitLines("Creature-0-1-0-1-7777-00001", "Lord Shade"):find("drops Shade Mantle"), "a journal boss is matched by name")
    end
    GP.SetSetting("tooltip", false)
    check(not unitLines("Creature-0-1-0-1-9002-00001", "Stalvan Mistmantle"):find("GearPath"), "tooltips off: no unit lines")
    GP.SetSetting("tooltip", true)

    -- 4. A wand's damage against yours.
    GameTooltip._lines = {}
    T.Add(GameTooltip, 211)
    local wl = table.concat(GameTooltip._lines, "\n")
    check(wl:find("Wand: 15.0 damage per second || you wear no wand"), "a wand's tooltip gives its damage (no wand worn)")
    H.EQUIPPED[18] = 234
    GP.Score.ReadEquipped()
    GameTooltip._lines = {}
    T.Add(GameTooltip, 211)
    check(table.concat(GameTooltip._lines, "\n"):find("+5.0 over yours"), "and how much more than yours")
    GameTooltip._lines = {}
    T.Add(GameTooltip, 234)
    check(table.concat(GameTooltip._lines, "\n"):find("the wand you wear"), "and which one is yours")
    GameTooltip._lines = {}
    T.Add(GameTooltip, 200)
    check(not table.concat(GameTooltip._lines, "\n"):find("Wand:"), "no wand line on other gear")
    H.EQUIPPED[18] = nil
    GP.Score.ReadEquipped()

    -- 3. A pin that clears itself on arrival.
    local cowl = GP.Score.ForItem(200).source
    H.playerX, H.playerY = 0.61, 0.52
    W.Set(cowl, "Shadowweave Cowl")
    check(W.active and W.active.armed, "the pin watches for you to arrive")
    H.Tick(1.1)
    check(H.waypoint ~= nil, "still far away: the pin stays")
    H.playerX, H.playerY = 0.563, 0.477
    local before = #H.printed
    H.Tick(1.1)
    local said = plain(table.concat(H.printed, "\n", before + 1))
    check(H.waypoint == nil and W.active == nil, "on arrival the pin clears itself")
    check(said:find("Talk to Gryan Stoutmantle to start The Lost Cultist %(for Shadowweave Cowl%)%. Map pin cleared%."),
        "and chat says who to talk to (" .. said .. ")")
    -- Set while standing on it: it waits until you've been away.
    W.Set(cowl, "Shadowweave Cowl")
    H.Tick(1.1)
    check(H.waypoint ~= nil and W.active and not W.active.armed, "a pin set where you stand doesn't clear at once")
    H.playerX, H.playerY = 0.61, 0.52
    H.Tick(1.1)
    H.playerX, H.playerY = 0.563, 0.477
    H.Tick(1.1)
    check(H.waypoint == nil, "it clears after you've been away and come back")
    -- Someone else's pin: left alone.
    H.playerX, H.playerY = 0.61, 0.52
    W.Set(cowl, "Shadowweave Cowl")
    H.waypoint = { m = 1431, x = 0.2, y = 0.2 }
    H.Tick(1.1)
    check(W.active == nil and H.waypoint.m == 1431, "another pin put down: GearPath stops watching and leaves it")
    -- A dungeon's door.
    local vest
    for _, src in ipairs(GP.Sources.entries[232].sources) do if src.kind == "drop" then vest = src end end
    W.Set(vest, "Testson's Vestments")
    H.playerX, H.playerY = 0.425, 0.716
    before = #H.printed
    H.Tick(1.1)
    said = plain(table.concat(H.printed, "\n", before + 1))
    check(said:find("You're at the entrance to The Deadmines %(for Testson's Vestments%)"), "at a dungeon's door: you're at the entrance (" .. said .. ")")
    H.waypoint, H.playerX, H.playerY = nil, nil, nil

    -- 2. A level-up that lets you wear gear from your bags.
    H.bag = { [5] = 201 }
    before = #H.printed
    GP.Notes.LevelUp(23, 24)
    said = plain(table.concat(H.printed, "\n", before + 1))
    check(said:find("Level 24: you can wear %[Robe of the Lost Order%], %+%d+%% Chest%."), "a level-up names gear in your bags you can wear now (" .. said .. ")")
    check(not said:find("Bagged Gloves"), "but not what you could already wear")
    before = #H.printed
    GP.Notes.LevelUp(24, 25)
    check(#H.printed == before, "nothing new at the next level: no note")
    H.bag = nil

    -- 5. A vendor that sells an upgrade.
    H.merchant = { { 205, 5000 }, { 209, 1250 }, { 215, 9000 } }
    before = #H.printed
    H.Fire("MERCHANT_SHOW")
    H.Tick(0.4)
    said = plain(table.concat(H.printed, "\n", before + 1))
    check(said:find("This vendor sells an upgrade: %[Slow Bracers%], fills your empty Wrists slot"), "a vendor with an upgrade gets a note (" .. said .. ")")
    check(not said:find("Chainmail") and not said:find("Sergeant"), "only gear you can wear")
    before = #H.printed
    H.Tick(2)
    check(#H.printed == before, "once per visit")
    H.Fire("MERCHANT_CLOSED")
    H.merchant = { { 205, 5000 } }
    before = #H.printed
    H.Fire("MERCHANT_SHOW")
    H.Tick(0.4)
    check(#H.printed == before, "no upgrades: no note")
    H.Fire("MERCHANT_CLOSED")
    H.merchant = nil

    -- 6. A toast when you put on an upgrade.
    H.EQUIPPED[5] = 232
    H.Fire("PLAYER_EQUIPMENT_CHANGED", 5, false)
    local toast = GP.Notes.toast
    check(toast and toast:IsShown() and (toast.title:GetText():find("^Upgrade: %+%d+%% Chest$") or toast.title:GetText():find("^Upgrade: %dx Chest$")), "putting on an upgrade shows a toast (" .. tostring(toast and toast.title:GetText()) .. ")")
    check(toast and toast.name:GetText() == "Testson's Vestments" and toast.sub:GetText():find("GearPath score"), "with its name and the score it adds")
    H.Tick(0.1)
    toast:Hide()
    H.Fire("PLAYER_EQUIPMENT_CHANGED", 5, false)
    check(not toast:IsShown(), "no toast for what you were already wearing")
    H.EQUIPPED[5] = 101
    H.Fire("PLAYER_EQUIPMENT_CHANGED", 5, false)
    check(not toast:IsShown(), "no toast for a downgrade")
    H.Tick(0.1)
    H.EQUIPPED[5] = 232
    H.Fire("PLAYER_EQUIPMENT_CHANGED", 5, false)
    for _ = 1, 60 do H.Tick(0.1) end
    check(not toast:IsShown(), "the toast fades away")
    H.EQUIPPED[5] = 101
    GP.Score.Run()

    -- 7. Counts on the addon list button.
    GameTooltip._lines = {}
    GearPath_CompartmentEnter(nil, UIParent)
    local ct = table.concat(GameTooltip._lines, "\n")
    check(ct:find("Best now || %d+ upgrades? in %d+ places?") and ct:find("Worth chasing ||"), "the addon list button shows the route's counts (" .. ct:gsub("\n", " / ") .. ")")
    check(ct:find("Click to open GearPath"), "and what a click does")
end

-- The Character tab's background: your race's dressing room art.
do
    local D = UI.Doll
    check(D.art and D.art.race == "Scourge" and D.art.path == "Interface\\DressUpFrame\\DressUpBackground-Scourge",
        "the Character tab shows your race's art (" .. tostring(D.art and D.art.path) .. ")")
    check(D.art and D.art.pieces[4]:GetTexture() == "Interface\\DressUpFrame\\DressUpBackground-Scourge4", "in its four pieces")
    check(D.art and D.art.dim._color and D.art.dim._color[4] == 0.25, "dimmed a little behind the model")
    check(D.ArtPath("Skyborne") == nil, "a race without art keeps the plain panel")
    -- The pieces fill the panel: the sides are cut, nothing is squashed.
    local fake = { pieces = {} }
    for i = 1, 4 do
        local t = { shown = true }
        function t:Hide() self.shown = false end
        function t:Show() self.shown = true end
        function t:ClearAllPoints() end
        function t:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
        function t:SetSize(w, h) self.w, self.h = w, h end
        function t:SetTexCoord(l, r, tp, b) self.tc = { l, r, tp, b } end
        fake.pieces[i] = t
    end
    D.LayoutArt(fake, 252, 340)
    local p1, p2, p3, p4 = unpack(fake.pieces)
    local near = function(a, b) return math.abs(a - b) < 0.01 end
    check(near(p1.w + p2.w, 252) and near(p1.h + p3.h, 340), "the four pieces cover the panel exactly")
    check(near(p1.x, 0) and near(p1.y, 0) and near(p4.x, p1.w) and near(p4.y, -p1.h), "and sit edge to edge")
    check(p1.tc[1] > 0 and near(p2.tc[2], 1 - p1.tc[1] * 256 / 64) and near(p1.tc[3], 0), "the sides are cut evenly, the top isn't")
    check(near((p1.w / (p1.tc[2] - p1.tc[1])) / 256, (p1.h / (p1.tc[4] - p1.tc[3])) / 256), "the picture keeps its shape")
end

-- The stats under the model, and what an item tried on would change.
if not H.noDB then
    local St, D = UI.Stats, UI.Doll
    UI.Show("doll")
    local keys = table.concat(St.Keys(GP.Classes.Weights()), " ")
    -- (Mp5 sorts last since 0.7.7: Gear Judge 3.2.11 halved it for launch's stronger Life Tap.)
    check(keys == "sp hit int spi crit sta haste mp5", "a warlock's stats in Affliction order (" .. keys .. ")")
    local function cell(label)
        for _, c in ipairs(St.frame.cells) do
            if c.row and c.row.label == label then return c end
        end
    end
    local sp, crit, haste, int = cell("Spell Power"), cell("Crit"), cell("Haste"), cell("Intellect")
    check(sp and sp.value:GetText() == "5" and crit and crit.value:GetText() == "4.5%", "the game's own numbers: Spell Power 5, Crit 4.5%")
    check(int and int.value:GetText() == "60", "Intellect as the character sheet has it (gear, talents and buffs)")
    check(sp and sp.extra:GetText():find("^%d+%%$") and sp.row.share > 40, "each stat's share of your GearPath score (" .. tostring(sp and sp.extra:GetText()) .. ")")
    check(haste == nil or haste.row.fromGear, "a stat the game doesn't say comes from your gear")
    check(St.frame.empty:GetText():find("empty slots:") and St.frame.empty:GetText():find("Neck"), "the empty slots are named")
    print("  stats: " .. St.frame.note:GetText() .. " / " .. St.frame.empty:GetText())
    -- Try on the Robe of the Lost Order: +7 Spell Power, +5 Stamina over the Apprentice Robe.
    local robe = GP.Score.ForItem(201)
    UI.ItemClick(robe, "LeftButton")
    check(UI.tried and UI.tried.ChestSlot == robe, "a click tries the item on and keeps it in its slot")
    check(sp.value:GetText() == "12" and sp.extra:GetText() == "+7", "the stats show it: Spell Power 12 (+7) (" .. sp.value:GetText() .. " " .. sp.extra:GetText() .. ")")
    check(cell("Stamina").extra:GetText() == "+5", "and Stamina +5")
    check(St.frame.note:GetText() == "With Robe of the Lost Order", "the panel says what you're trying on")
    check(D.summary:GetText():find("GearPath score %d+ |cff40ff40%(%+%d+%)"), "the score line shows the gain (" .. plain(D.summary:GetText()) .. ")")
    -- And a head on top: they add up.
    UI.ItemClick(GP.Score.ForItem(200), "LeftButton")
    check(sp.value:GetText() == "21" and sp.extra:GetText() == "+16", "two items tried on add up: Spell Power 21 (+16)")
    check(St.frame.note:GetText() == "With the 2 items you're trying on", "and the panel says how many")
    check(not St.frame.empty:GetText():find("Head") , "a slot you're trying something on isn't empty")
    -- Take it off: back to what you wear.
    D.ResetModel()
    check(UI.tried == nil and sp.value:GetText() == "5" and sp.extra:GetText():find("%%$"), "Take it off: back to what you wear")
    check(not D.summary:GetText():find("%("), "and the score line is plain again")
    -- "Put it on" for gear tried on from your bags.
    local function label(b) return b.text and b.text:GetText() or b:GetText() end
    local put = D.putOn
    UI.ItemClick(robe, "LeftButton")
    check(put and not put:IsShown(), "no Put it on for gear that isn't in your bags")
    D.ResetModel()
    local gloves = GP.Score.ForItem(210)
    UI.ItemClick(gloves, "LeftButton")
    check(put:IsShown() and label(put) == "Put it on", "gloves tried on from your bags: Put it on (" .. tostring(label(put)) .. ")")
    put:_run("OnEnter")
    local tip = table.concat(GameTooltip._lines or {}, "\n")
    check(tip:find("Bagged Gloves") and tip:find("Hands") and not tip:find("binds to you"), "its tooltip names the item and the slot")
    D.ResetModel()
    H.bind = { [210] = 2 }
    UI.ItemClick(gloves, "LeftButton")
    check(label(put) == "Put it on (binds)", "gear that binds when worn says so on the button (" .. tostring(label(put)) .. ")")
    put:_run("OnEnter")
    tip = table.concat(GameTooltip._lines or {}, "\n")
    check(tip:find("binds to you when you put it on") and tip:find("asks you to confirm"), "and the tooltip warns before you click")
    H.bound = { [3] = true }
    D.ResetModel(); UI.ItemClick(gloves, "LeftButton")
    check(label(put) == "Put it on", "already bound to you: no warning")
    H.bound = nil
    -- In combat nothing happens but a note.
    H.equips, H.combat = {}, true
    local before = #H.printed
    put:Click("LeftButton")
    check(#H.equips == 0 and (H.printed[#H.printed] or ""):find("combat") and #H.printed > before, "in combat: not put on, and chat says why")
    check(UI.tried ~= nil, "and it's still tried on")
    H.combat = false
    put:Click("LeftButton")
    check(#H.equips == 1 and H.equips[1].slot == 10 and H.equips[1].link:find("item:210"), "out of combat: put on in the Hands slot")
    check(UI.tried == nil and not put:IsShown(), "then the model is back to what you wear")
    -- Too high a level for you, even in your bags: no button.
    H.bag = { [5] = 201 }
    D.ResetModel(); UI.ItemClick(robe, "LeftButton")
    check(not put:IsShown(), "gear above your level in your bags can't be put on yet")
    H.bag, H.bind, H.equips = nil, nil, nil
    D.ResetModel()
end

-- The minimap button: open, Settings, hide.
do
    local M = UI.MinimapButton
    local b = M.button
    check(b and b:IsShown() and b:GetParent() == Minimap, "a GearPath button sits on the minimap")
    local _, _, _, x, y = b:GetPoint(1)
    check(type(x) == "number" and math.abs(math.sqrt(x * x + y * y) - 75) < 0.5, "on the minimap's edge")
    local wasOpen = UI.frame and UI.frame:IsShown()
    b:Click("LeftButton")
    check((UI.frame and UI.frame:IsShown()) ~= wasOpen, "a click opens or closes the window")
    if not UI.frame:IsShown() then b:Click("LeftButton") end
    b:Click("RightButton")
    check(UI.frame:IsShown() and UI.current == "settings", "a right-click opens Settings")
    b:_run("OnEnter")
    local tip = table.concat(GameTooltip._lines or {}, "\n")
    check(tip:find("Right%-click: Settings") and tip:find("Best now"), "its tooltip has the route's counts and the clicks")
    GP.SetSetting("minimapButton", false)
    check(not b:IsShown(), "Settings can hide it")
    GP.SetSetting("minimapButton", true)
    check(b:IsShown(), "and bring it back")
    check(BINDING_NAME_GEARPATH_TOGGLE == "Open or close GearPath", "a key binding to open GearPath")
    UI.Show("plan")
end

-- Item levels on the game's own Character window.
do
    local cf = CreateFrame("Frame", "CharacterFrame", UIParent)
    local head = CreateFrame("Button", "CharacterHeadSlot", cf)
    local chest = CreateFrame("Button", "CharacterChestSlot", cf)
    local neck = CreateFrame("Button", "CharacterNeckSlot", cf)
    local shirt = CreateFrame("Button", "CharacterShirtSlot", cf)
    cf:Show()
    if look == "ellesmere" then
        -- EllesmereUI's Character sheet draws item levels itself: no second set.
        UI.Doll.GameSlotLevels()
        check(not head.gpLevel or head.gpLevel:GetText() == "", "with EllesmereUI's Character sheet on, GearPath draws no item levels")
        EllesmereUIDB.themedCharacterSheet = false
    end
    UI.Doll.GameSlotLevels()
    check(head.gpLevel and head.gpLevel:GetText() == "15" and chest.gpLevel:GetText() == "18", "each slot shows its item's level (Old Hood 15, Apprentice Robe 18)")
    check(not neck.gpLevel or neck.gpLevel:GetText() == "", "an empty slot shows nothing")
    check(not shirt.gpLevel, "the shirt and tabard are left alone")
    GP.SetSetting("itemLevels", false)
    UI.Doll.GameSlotLevels()
    check(head.gpLevel:GetText() == "", "Settings can turn them off")
    GP.SetSetting("itemLevels", true)
    UI.Doll.GameSlotLevels()
    cf:Hide()
end

-- Every client language: Blizzard's own Equip lines read as the right stat.
do
    local I = GP.Items
    local cases = dofile(here .. "/locales_test.lua")
    local savedPrefix = ITEM_SPELL_TRIGGER_ONEQUIP
    local total, wrong = 0, {}
    for code, case in pairs(cases) do
        I.locale = code
        ITEM_SPELL_TRIGGER_ONEQUIP = case[1]
        for _, c in ipairs(case[2]) do
            total = total + 1
            local found = I.ParseTooltip({ lines = { { leftText = "Item" }, { leftText = case[1] .. " " .. c[1] } } })
            local n = 0
            for _ in pairs(found) do n = n + 1 end
            -- Damage-and-healing spell power counts as Healing too.
            local both = c[2] == "sp" and found.heal == c[3]
            if found[c[2]] ~= c[3] or n ~= (both and 2 or 1) then
                local got = {}
                for k, v in pairs(found) do got[#got + 1] = k .. "=" .. tostring(v) end
                wrong[#wrong + 1] = code .. ": " .. c[1] .. " -> " .. table.concat(got, ",")
            end
        end
    end
    I.locale, ITEM_SPELL_TRIGGER_ONEQUIP = nil, savedPrefix
    for _, w in ipairs(wrong) do print("  locale miss: " .. w) end
    check(#wrong == 0, string.format("all %d Equip lines in 11 client languages read right (%d wrong)", total, #wrong))
    check(GP.LOCALES.READS.deDE and GP.LOCALES.READS.zhTW and GP.LOCALES.READS.itIT and not GP.LOCALES.READS.xxXX, "the languages GearPath reads")
    -- "Requires ..." wherever the language puts the word (Korean: last).
    check(select(4, I.ParseTooltip({ lines = { { leftText = "Cloak" },
        { leftText = "Requires Sergeant", leftColor = { r = 1, g = 0.1, b = 0.1 } } } })) == "Sergeant", "an unmet requirement is read")
    check(select(4, I.ParseTooltip({ lines = { { leftText = "Cloak" },
        { leftText = "Requires Level 30", leftColor = { r = 1, g = 0.1, b = 0.1 } } } })) == nil, "a level requirement isn't one of them")
    -- The damage-per-second line in the client's own words.
    DPS_TEMPLATE = "(%s Schaden pro Sekunde)"
    local f = I.ParseTooltip({ lines = { { leftText = "Stab" }, { leftText = "(17,5 Schaden pro Sekunde)" } } })
    check(f.dps == 17.5, "a German weapon's damage per second (17,5) reads as 17.5 (" .. tostring(f.dps) .. ")")
    DPS_TEMPLATE = nil
end

-- Close and reopen on another page.
GP.Toggle()
check(not UI.frame:IsShown(), "toggle closes")
GP.Toggle("plan")
check(UI.frame:IsShown() and UI.current == "plan", "opens on a named page")

-- Slash commands.
SlashCmdList.GEARPATH("status")
SlashCmdList.GEARPATH("help")

-- Weights to share: copy as a string, paste someone else's.
do
    local C = GP.Classes
    local str = C.ExportWeights()
    print("  weights: " .. str)
    check(str:find("^GP1:WARLOCK:") and str:find("hit=11") and str:find("armor=0%.008") and #str < 250, "your weights as a short string that fits a chat line")
    local w, class = C.ParseWeights(str)
    check(class == "WARLOCK" and w.sp == 1 and w.spShadow == 0.95, "the string reads back the same")
    -- Someone else's: Spirit up, Stamina down.
    local ok, msg = C.ImportWeights("  GP1:WARLOCK:sp=1,hit=11,spi=0.9,sta=0.2  ")
    check(ok and C.Weights().spi == 0.9 and C.Weights().sta == 0.2 and C.Weights().int == 0.6, "pasted weights are used; stats it leaves out keep their defaults")
    check(GP.char.weights.sp == nil and GP.char.weights.spi == 0.9, "only the differences are kept")
    local bad = {
        { "GP1:MAGE:sp=1", "for a Mage, and you're a Warlock" },
        { "GP2:WARLOCK:sp=1", "newer GearPath" },
        { "hello", "isn't a GearPath weights string" },
        { "GP1:WARLOCK:sp=1,evil=5", "isn't a stat weight" },
        { "GP1:WARLOCK:sp=1e9", "isn't a stat weight" },
        { "GP1:WARLOCK:sp=101", "isn't a stat weight" },
        { "GP1:WARLOCK:sp=-1", "isn't a GearPath weights string" },
        { "GP1:WARLOCK:sp=os.exit()", "isn't a GearPath weights string" },
        { "GP1:WARLOCK:", "no weights" },
        { "GP1:PIRATE:sp=1", "doesn't know" },
    }
    for _, b in ipairs(bad) do
        local good, why = C.ImportWeights(b[1])
        check(not good and type(why) == "string" and why:find(b[2], 1, true), "refused: " .. b[1] .. " (" .. tostring(why) .. ")")
    end
    check(C.Weights().spi == 0.9, "a refused paste leaves your weights alone")
    -- The Settings buttons and /gp weights.
    UI.Show("settings")
    local S = UI.Settings
    S.copyWeights:Click("LeftButton")
    local box = UI.TextBox({ title = "x" }) -- the same box
    SlashCmdList.GEARPATH("weights")
    check(box:IsShown() and box.input:GetText() == C.ExportWeights() and not box.action:IsShown(), "Copy my weights shows them ready to copy")
    S.pasteWeights:Click("LeftButton")
    check(box:IsShown() and box.action:IsShown() and box.input:GetText() == "", "Paste weights opens an empty paste box")
    box.input:SetText("GP1:WARLOCK:sp=1,hit=12"); box.action:Click()
    check(not box:IsShown() and C.Weights().hit == 12 and C.Weights().spi == 0.55, "Use these applies them and closes")
    SlashCmdList.GEARPATH("weights GP1:WARLOCK:sp=1,hit=13")
    check(C.Weights().hit == 13, "/gp weights <string> uses them too")
    GP.char.weights = nil
    GP.Fire("WeightsChanged")
    UI.Show("plan")
end

-- A controller: the window takes the pad's buttons while it's open.
if not H.noDB then
    local P, f = UI.Pad, UI.frame
    if f:IsShown() then GP.Toggle() end
    H.cvars.GamePadEnable = "1"
    GP.Toggle("plan")
    check(P.on and f._pad == true, "with gamepad mode on, the open window takes the controller")
    local function press(b) f:_run("OnGamePadButtonDown", b) end
    local list = UI.Plan.list
    press("PADDDOWN")
    check(list.focus ~= nil and list:CanFocus(list.focus) and list:FocusRow() ~= nil, "D-pad down focuses the first row a click works on")
    check(GameTooltip:IsShown(), "and shows its tooltip")
    local first = list.focus
    press("PADDDOWN"); press("PADDDOWN")
    check(list.focus > first, "down again moves on")
    press("PADDUP")
    check(list.focus > first or list.focus == first, "and up comes back")
    local focusedItem = list.items[list.focus]
    H.waypoint = nil
    press("PAD1")
    check(H.waypoint ~= nil, "A clicks the row: on the Route, its map pin (" .. tostring(focusedItem.kind) .. ")")
    check(GP.Pad == nil and UI.ClickHint(GP.Score.ForItem(202)):find("^A: map pin"), "tooltips name the controller's buttons")
    press("PADRSHOULDER")
    check(UI.current == "browse", "the right shoulder button: the next tab (" .. tostring(UI.current) .. ")")
    press("PADLSHOULDER"); press("PADLSHOULDER")
    check(UI.current == "doll", "the left one goes back")
    -- Character tab: left and right go through the slots.
    UI.SelectSlot(nil)
    press("PADDRIGHT")
    check(UI.selectedSlot == GP.Slots.LEFT[1], "D-pad right picks the first slot (" .. tostring(UI.selectedSlot) .. ")")
    press("PADDLEFT")
    check(UI.selectedSlot == nil, "and left goes back to Near you")
    press("PADDLEFT")
    check(UI.selectedSlot == GP.Slots.BOTTOM[#GP.Slots.BOTTOM], "left again wraps round to the last slot")
    -- Hands: try the bagged gloves on with A, put them on with Y.
    UI.SelectSlot("HandsSlot")
    local sl = UI.SlotPanel.list
    local gotGloves = false
    for _ = 1, 20 do
        press("PADDDOWN")
        local it = sl.items[sl.focus or 0]
        if it and it.ev and it.ev.rec.id == 210 then gotGloves = true break end
    end
    check(gotGloves, "the D-pad reaches the gloves in your bags")
    press("PAD1")
    check(UI.tried and UI.tried.HandsSlot and UI.Doll.putOn:IsShown(), "A tries them on")
    H.equips = {}
    press("PAD4")
    check(#H.equips == 1 and H.equips[1].slot == 10, "Y puts them on")
    H.equips = nil
    press("PAD2")
    check(not f:IsShown() and not P.on and f._pad == false, "B closes the window and gives the controller back")
    -- Gamepad mode off: the window leaves the controller alone.
    H.cvars.GamePadEnable = "0"
    GP.Toggle("plan")
    check(not P.on and not f._pad, "without gamepad mode, the window doesn't take it")
    GP.Toggle()
    -- ConsolePort: its cursor drives the window; GearPath doesn't take the pad.
    H.cvars.GamePadEnable = "1"
    ConsolePort = {}
    GP.Toggle("plan")
    check(not P.on, "with ConsolePort, GearPath leaves the controller to it")
    GP.Toggle()
    ConsolePort = nil
    H.cvars.GamePadEnable = nil
    UI.SelectSlot(nil)
    GP.Toggle("plan")
end

-- Weapon training: a dagger when you haven't learned Daggers.
if not H.noDB then
    local T = GP.Training
    local function rescore() T.reliable = nil; GP.Score.Run() end
    H.unknownSpells = { [1180] = true }
    rescore()
    local ev = GP.Score.ForItem(202)
    check(ev and ev.train and ev.train[1].spell == 1180 and ev.train[1].name == "Daggers", "a dagger needs Daggers learned first")
    check(ev and ev.train and ev.train[1].masters[1].name == "Archibald", "an Undead is sent to Archibald in Undercity first")
    check(T.Short(ev.train) == "Learn Daggers first", "its line says so (" .. T.Short(ev.train) .. ")")
    local long = T.Long(ev.train[1])
    check(long:find("Archibald, Undercity") and long:find("1000") == nil, "and the tooltip says who and where (" .. long .. ")")
    check(ev.tier ~= nil, "it's still an upgrade (training is cheap)")
    -- The Route: a row for the trainer, its click a map pin.
    if not UI.frame:IsShown() then GP.Toggle("plan") end
    UI.Show("plan")
    local row
    for _, it in ipairs(UI.Plan.list.items) do
        if it.kind == "header" and (it.text or ""):find("^Learn Daggers") then row = it end
    end
    check(row ~= nil, "the Route has a row to learn Daggers (" .. tostring(row and row.text) .. ")")
    check(row and row.right == "for 1 upgrade", "for how many upgrades (" .. tostring(row and row.right) .. ")")
    check(row and row.source and row.source.kind == "trainer" and GP.Waypoint.CanSet(row.source), "and a click on it pins the trainer")
    if row and row.source then
        check(GP.Waypoint.ArrivedText(row.source, nil, row.source) == "Talk to Archibald to learn Daggers.", "arriving says what to do")
    end
    -- The item's tooltip.
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GP.Tooltip.Add(GameTooltip, 202)
    local tip = table.concat(GameTooltip._lines or {}, "\n")
    check(tip:find("Learn Daggers first: Archibald, Undercity"), "the item's tooltip names the trainer")
    -- Put it on: not offered while the skill is missing.
    H.bag = { [5] = 202 }
    GP.Sources.RefreshBags(); H.Tick(0.1); GP.Score.Run()
    UI.Show("doll")
    UI.ItemClick(GP.Score.ForItem(202), "LeftButton")
    check(not UI.Doll.putOn:IsShown(), "no Put it on for a weapon you can't use yet")
    UI.Doll.ResetModel()
    H.bag = nil
    GP.Sources.RefreshBags(); H.Tick(0.1)
    -- Dual Wield for an off-hand, from the class trainer.
    local need = T.Need({ classID = 2, subClassID = 15, equipLoc = "INVTYPE_WEAPON" }, "SecondaryHandSlot")
    H.unknownSpells = { [674] = true }; T.reliable = nil
    need = T.Need({ classID = 2, subClassID = 15, equipLoc = "INVTYPE_WEAPON" }, "SecondaryHandSlot")
    check(need and need[1].spell == 674 and T.Long(need[1]):find("class trainer"), "an off-hand weapon needs Dual Wield from the class trainer")
    -- Plate at 40.
    H.unknownSpells = { [750] = true }; T.reliable = nil
    need = T.Need({ classID = 4, subClassID = 4, equipLoc = "INVTYPE_HEAD" }, "HeadSlot")
    check(need and need[1].name == "Plate Mail" and need[1].kind == "class", "plate armor needs Plate Mail from the class trainer")
    -- Polearms: 1 gold, from level 20.
    H.unknownSpells = { [200] = true }; T.reliable = nil
    GP.player.level = 15
    need = T.Need({ classID = 2, subClassID = 6, equipLoc = "INVTYPE_2HWEAPON" }, "MainHandSlot")
    check(need and need[1].cost == 10000 and T.Long(need[1]):find("from level 20"), "Polearms cost 1 gold and wait for level 20")
    GP.player.level = 23
    -- If the game's answer can't be trusted (the staff you hold reads as unknown), nothing is marked.
    H.unknownSpells = { [227] = true, [1180] = true }
    rescore()
    check(GP.Score.ForItem(202).train == nil, "no training marks when the game's answer can't be trusted")
    H.unknownSpells = nil
    rescore()
    check(GP.Score.ForItem(202).train == nil, "everything known: nothing to learn")
    UI.Show("plan")
end

-- Specs: switch, weights follow, your own changes stay with their spec.
do
    local C = GP.Classes
    check(C.Spec().key == "affliction", "a warlock starts as Affliction")
    GP.char.weights = { spi = 0.9 }
    local before = #H.printed
    SlashCmdList.GEARPATH("spec destruction")
    check(C.Spec().key == "destruction" and C.Weights().spFire == 0.6 and C.Weights().spi == 0.3, "/gp spec destruction: Destruction's weights")
    check(H.printed[#H.printed]:find("Spec: Destruction"), "and chat says so")
    SlashCmdList.GEARPATH("spec aff")
    check(C.Spec().key == "affliction" and C.Weights().spi == 0.9, "back to Affliction: your own Spirit weight is still there")
    SlashCmdList.GEARPATH("spec")
    check(H.printed[#H.printed]:find("%[Affliction%]"), "/gp spec lists them, the one in use in brackets")
    GP.char.weights = nil
    GP.Fire("WeightsChanged")
    UI.UpdateSub()
    -- The title line names it; Settings has the choice.
    if not UI.frame:IsShown() then GP.Toggle("settings") end
    UI.Show("settings")
    UI.UpdateSub()
    if look == "native" then
        check(UI.frame.sub:GetText():find("level 23 Affliction Warlock"), "the title line names the spec (" .. UI.frame.sub:GetText() .. ")")
    end
    -- A weapon's speed, read from its tooltip in any language.
    local f = GP.Items.ParseTooltip({ lines = { { leftText = "Sword" }, { leftText = "37 - 69 Damage", rightText = "Speed 2.90" } } })
    check(f.speed == 2.9, "a weapon's speed is read (" .. tostring(f.speed) .. ")")
    f = GP.Items.ParseTooltip({ lines = { { leftText = "Schwert" }, { leftText = "37 - 69 Schaden", rightText = "Tempo 2,90" } } })
    check(f.speed == 2.9, "in German too")
    f = GP.Items.ParseTooltip({ lines = { { leftText = "Robe" }, { leftText = "Chest", rightText = "Cloth" } } })
    check(f.speed == nil, "armor has none")
    UI.Show("plan")
end

-- Rings and trinkets: never the same item twice; one you wear only as a
-- second copy on the other finger, and never when it's Unique.
if not H.noDB then
    local n = 0
    for _, ev in ipairs(GP.Score.results.plan.picks) do if ev.rec.id == 203 then n = n + 1 end end
    check(n <= 1, "the route never picks the same ring for both ring slots")
    H.EQUIPPED[12] = 203
    GP.Score.ReadEquipped(); GP.Score.Run()
    local again = GP.Score.ForItem(203)
    check(again == nil or again.slot == "Finger0Slot", "a ring you wear: a second copy only for the other finger")
    H.ITEMS[203][9] = { "Unique" }
    GP.Items.cache[203] = nil
    for link in pairs(GP.Items.linkCache) do if GP.Items.IDFromLink(link) == 203 then GP.Items.linkCache[link] = nil end end
    for _, e in pairs(GP.Sources.entries or {}) do if e.rec and e.rec.id == 203 then e.rec = GP.Items.Get(203) end end
    GP.Score.ReadEquipped(); GP.Score.Run()
    check(GP.Score.ForItem(203) == nil, "a Unique ring you already wear isn't suggested again")
    H.ITEMS[203][9] = nil
    GP.Items.cache[203] = nil
    for link in pairs(GP.Items.linkCache) do if GP.Items.IDFromLink(link) == 203 then GP.Items.linkCache[link] = nil end end
    for _, e in pairs(GP.Sources.entries or {}) do if e.rec and e.rec.id == 203 then e.rec = GP.Items.Get(203) end end
    H.EQUIPPED[12] = nil
    GP.Score.ReadEquipped(); GP.Score.Run()
end

-- An NPC's spawn list is read from the database once a session.
if not H.noDB then
    local N = LibQuestieDB.Npc
    local real, reads = N.spawns, 0
    N.spawns = function(id) reads = reads + 1; return real(id) end
    local a = GP.Sources.SpawnSummary("npc", 9002)
    local b = GP.Sources.SpawnSummary("npc", 9002)
    check(a and a == b and reads == 0 and a.count == 1 and a.at[10], "an NPC's spawns read by the scan are kept, not read again (" .. reads .. " reads)")
    N.spawns = real
end

-- /gp report: one line for a bug report, in a box ready to copy.
do
    local before = #H.printed
    SlashCmdList.GEARPATH("report")
    local line = (H.printed[before + 1] or ""):gsub("^.-: ", "", 1)
    print("  report: " .. line)
    check(line:find("^GearPath ") and line:find("WARLOCK 23 Scourge Horde") and line:find("errors 0"), "the report names the version, the character and the errors")
    check(line:find(H.noDB and "no QuestieDB" or "QuestieDB %d+"), "and the database")
    check(line:find("now %d+ chase %d+") and line:find("saved %d+/%d+"), "and the counts")
    check(H.noDB or line:find("ready %d+%.%ds work %d+%.%d+s"), "and how long the list took")
    local box = UI.TextBox and UI.TextBox({ title = "t", text = "keep" })
    check(box and box:IsShown() and box.input:GetText() == "keep" and not box.action:IsShown(), "a copy box shows the text, with no Apply button")
    box.input:SetText("typed over"); box.input:_run("OnTextChanged", true)
    check(box.input:GetText() == "keep", "typing in a copy box puts the text back")
    box.input:_run("OnEscapePressed")
    check(not box:IsShown(), "Escape closes it")
    -- A paste box: Apply hands over the text; a bad one stays open and says why.
    local got
    box = UI.TextBox({ title = "p", note = "paste", action = { label = "Use", fn = function(t) got = t; return t == "good", "Not a GearPath string." end } })
    check(box.action:IsShown() and box.input:GetText() == "", "a paste box starts empty, with its button")
    box.input:SetText("bad"); box.action:Click()
    check(got == "bad" and box:IsShown() and box.note:GetText():find("Not a GearPath"), "a bad paste keeps it open with the reason")
    box.input:SetText("good"); box.input:_run("OnEnterPressed")
    check(got == "good" and not box:IsShown(), "Enter applies a good one and closes")
    -- Errors are counted for the report.
    GP.SafeCall(function() error("test failure") end)
    check(GP.errors.count == 1 and GP.errors.last:find("test failure"), "an error is counted, with its first line (" .. tostring(GP.errors.last) .. ")")
    check(GP.Sources.ReportLine():find("errors 1 %(last: "), "and the report says so")
    GP.errors.count, GP.errors.last = 0, nil
    table.remove(H.errors)   -- that one was on purpose
end

-- Faction filtering (0.7.6, launch night: an Undead was offered the
-- Dwarven Tome from Important Heirlooms, a quest given in Ironforge).
if not H.noDB then
    local Src = GP.Sources
    GP.Sources.HOME.Alliance = realAllianceHome
    check(Src.EnemyLand({ mapID = 1436 }), "Westfall is enemy land for a Horde player")
    check(not Src.EnemyLand({ mapID = 1420 }), "Tirisfal isn't")
    check(not Src.EnemyLand({ mapID = 1436, dungeon = "The Deadmines" }), "a dungeon's entrance is never enemy land")
    check(GP.Score.Effort({ kind = "quest", giver = "Thom", mapID = 1436, zone = "Westfall" }) == 2,
        "a quest in Westfall is a trip for a Horde player, not Best now")
    check(GP.Score.Effort({ kind = "quest", giver = "Abigail", mapID = 1420, zone = "Tirisfal Glades" }) == 1,
        "one in Tirisfal is an easy pick-up")
    local sorted = { { kind = "quest", giver = "A", mapID = 1436, zone = "Westfall", level = 10 },
        { kind = "quest", giver = "B", mapID = 1431, zone = "Duskwood", level = 12 } }
    Src.SortSources(sorted)
    check(sorted[1].mapID == 1431, "a quest in enemy land goes after one elsewhere")
    local said = GP.UI.Describe({ kind = "quest", name = "Captain Sander's Hidden Treasure", level = 16, mapID = 1436, zone = "Westfall" })
    check(said:find("(Alliance territory)", 1, true), "the line says why: " .. said)
    said = GP.UI.Describe({ kind = "quest", name = "Rear Guard Patrol", level = 13, mapID = 1420, zone = "Tirisfal Glades" })
    check(not said:find("territory", 1, true), "nothing on your own side: " .. said)
    said = GP.UI.Describe({ kind = "vendor", name = "Jang", mapID = 1436, zone = "Westfall" })
    check(not said:find("territory", 1, true), "vendors who deal with you aren't flagged: " .. said)
    check(not Src.QuestAvailable(5011), "a quest only an Alliance NPC hands out isn't a Horde player's")
    check(Src.QuestAvailable(5012), "a giver marked AH keeps the quest")
    check(not Src.QuestAvailable(5010) and Src.QuestNotForYou(5010), "an Alliance race list keeps the quest out")
    check(not Src.QuestNotForYou(5005), "a quest the database doesn't have isn't judged")
    local sash = Src.Resolve({ id = 241 })
    local names = {}
    for _, s in ipairs(sash.sources or {}) do names[#names + 1] = s.name end
    check(#names == 1 and names[1] == "Hillsbrad Tester",
        "your own faction's people drop nothing for you; the other faction's still do (" .. table.concat(names, ", ") .. ")")
    if not H.noJournal then
        local bracers = Src.Resolve({ id = 218 })
        local got5010, got5005 = false, false
        for _, s in ipairs(bracers.sources or {}) do
            if s.kind == "quest" and s.id == 5010 then got5010 = true end
            if s.kind == "quest" and s.id == 5005 then got5005 = true end
        end
        check(not got5010, "the journal's \"Both\" doesn't beat the database's Alliance race list")
        check(got5005, "a journal quest the database doesn't have is still listed")
    end
    GP.Sources.HOME.Alliance = {}
    -- The window's title carries the version (Nov 5).
    check(GP.UI.WindowTitle():find(GP.VERSION, 1, true) and GP.UI.WindowTitle():find("^GearPath"),
        "the title says which version you run (" .. GP.UI.WindowTitle() .. ")")
    -- The header counts what Show: lets through.
    local all = GP.UI.StatusText()
    GP.UI.ContentOff().quest = true
    local now = 0
    for _, ev in ipairs(GP.Score.results.all) do
        if ev.tier == "primary" and GP.UI.ContentMatches(ev) then now = now + 1 end
    end
    local shown = GP.UI.StatusText()
    check(shown:find("^" .. now .. " to get now") and shown ~= all,
        "with quests unticked, the header counts only what's shown (" .. shown .. " / " .. all .. ")")
    GP.UI.ContentOff().quest = nil
end

if look == "ellesmere" then
    local W = GP.UI.frame
    local skinned = function(f, prim) return H.euiSkinned[f] and H.euiSkinned[f][prim] end
    check(W and skinned(W, "Shell"), "the window is an EllesmereUI shell")
    local tabs, buttons, boxes = 0, 0, 0
    for _, c in ipairs(H.euiCalls) do
        if c.prim == "Tab" then tabs = tabs + 1 elseif c.prim == "Button" then buttons = buttons + 1
        elseif c.prim == "EditBox" then boxes = boxes + 1 end
    end
    check(tabs >= 3, "the tabs are painted (" .. tabs .. ")")
    check(buttons >= 3 and boxes >= 1, "buttons and inputs are painted (" .. buttons .. ", " .. boxes .. ")")
    check((H.euiErrors or 0) == 0, "no errors in GearPath's skin callback")
    local r, g, b = GP.Skin.current.Accent()
    check(math.abs(r - H.eui.accent[1]) < 1e-6 and math.abs(g - H.eui.accent[2]) < 1e-6, "the accent is EllesmereUI's")
    -- EllesmereUI's bags: an arrow on a bag upgrade, none on an empty slot.
    check(EUI_Bags.itemOverlayIcons.GearPath ~= nil, "registered an icon for EllesmereUI's bags")
    local btn = H.EUIPaintSlot(0, 3, H.Link(210))
    local a = GP.Ellesmere.arrows and GP.Ellesmere.arrows[btn]
    check(a and a:IsShown(), "Bagged Gloves get the upgrade arrow in EllesmereUI's bags")
    check(a and a:GetPoint(1) == "TOPRIGHT", "in the top right corner, off EllesmereUI's item level (top left)")
    local empty = H.EUIPaintSlot(0, 9, nil)
    check(not (GP.Ellesmere.arrows[empty] and GP.Ellesmere.arrows[empty]:IsShown()), "an empty bag slot gets none")
    -- Skinning turned off for GearPath: the next session falls back to the game's look.
    H.eui.enabled = false
    check(GP.Skin.Resolve("auto") == "native", "with its skinning off for GearPath, auto means the game's own look")
    H.eui.enabled = true
end

if look == "daylight" then
    check(H.plugin ~= nil and H.plugin.short == "Gear", "registered as a DaylightUI plugin")
    check(H.pluginPage ~= nil, "plugin page added")
end

local unknown = {}
for k in pairs(H.unknown) do unknown[#unknown + 1] = k end
table.sort(unknown)
print("  widget methods the fake didn't model: " .. table.concat(unknown, ", "))
print(string.format("  %s: %d checks, %d failed, %d errors", look .. (extra and (" " .. extra) or ""), checks, failed, #H.errors))
for _, e in ipairs(H.errors) do print("  error: " .. tostring(e):match("^[^\n]*")) end
os.exit((failed == 0 and #H.errors == 0) and 0 or 1)
