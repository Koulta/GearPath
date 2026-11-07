-- Settings: the Settings tab. The look and the window's scale, what to
-- look for, the extras (tooltips, upgrade notes, learning, quest reward
-- pick, rare watch), checking and sharing, and your stat weights.

local _, GP = ...

local UI = GP.UI
local L = GP.L

local Settings = { refreshers = {} }
UI.Settings = Settings

local LOOK_KEYS = { "auto", "native", "daylight", "ellesmere" }
local LOOK_LABELS = { auto = "Automatic", native = "Native Forever UI", daylight = "DaylightUI", ellesmere = "EllesmereUI" }

local function onRefresh(fn) Settings.refreshers[#Settings.refreshers + 1] = fn end

-- A row: a label, a dim line under it, a control on the right.
local function row(parent, y, label, desc, control)
    local skin = GP.Skin.current
    local l = skin.Text(parent, "body", "VALUE")
    l:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -y)
    l:SetPoint("RIGHT", parent, "RIGHT", -280, 0)
    l:SetText(L[label])
    local d = skin.Text(parent, "small", "LABEL")
    d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -4)
    d:SetPoint("RIGHT", parent, "RIGHT", -280, 0)
    d:SetWordWrap(true)
    d:SetText(desc and L[desc] or "")
    if control then control:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -y + 2) end
    return y + 62, d
end

local function section(parent, y, title, desc)
    local skin = GP.Skin.current
    local bg = skin.HeaderLine(parent)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    bg:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    bg:SetHeight(28)
    local t = skin.Text(parent, "head", "TITLE")
    t:SetPoint("LEFT", bg, "LEFT", 10, 0)
    t:SetText(L[title])
    y = y + 36
    if desc then
        local d = skin.Text(parent, "small", "LABEL")
        d:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -y)
        d:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
        d:SetWordWrap(true)
        d:SetText(L[desc])
        y = y + 30
    end
    return y
end

local function toggle(parent, key, onChange)
    local t = GP.Skin.current.Toggle(parent)
    t.onToggle = function(on)
        GP.SetSetting(key, on)
        if onChange then onChange(on) end
    end
    onRefresh(function() t.SetOn(GP.Setting(key) == true) end)
    return t
end

-- A number with - and + either side.
local function stepper(parent, get, set, lo, hi, step, fmt)
    local skin = GP.Skin.current
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(130, 24)
    local minus = skin.Button(f, "-", 28, 22)
    minus:SetPoint("LEFT", f, "LEFT", 0, 0)
    local plus = skin.Button(f, "+", 28, 22)
    plus:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    local v = skin.Text(f, "body", "VALUE", "CENTER")
    v:SetPoint("LEFT", minus, "RIGHT", 2, 0)
    v:SetPoint("RIGHT", plus, "LEFT", -2, 0)
    local function show() v:SetText(fmt(get())) end
    local function move(dir)
        local n = GP.Clamp(GP.Round((tonumber(get()) or lo) + dir * step, 2), lo, hi)
        set(n)
        show()
    end
    minus:SetScript("OnClick", function() move(-1) end)
    plus:SetScript("OnClick", function() move(1) end)
    onRefresh(show)
    return f
end

local function levels(n) return GP.Count(n, "%d level", "%d levels") end

-- ---------------------------------------------------------------------
-- Stat weights
-- ---------------------------------------------------------------------

-- Every stat any of your class's specs weighs (the spec in use sets the
-- numbers; a stat it doesn't use shows 0).
local function weightRows(parent, y)
    local skin = GP.Skin.current
    local Classes = GP.Classes
    local keys = Classes.WeightKeys()
    local colW = 0.5
    for i, k in ipairs(keys) do
        local col = (i - 1) % 2
        local r = math.floor((i - 1) / 2)
        local cell = CreateFrame("Frame", nil, parent)
        cell:SetHeight(26)
        cell:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -(y + r * 30))
        cell:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
        local label = skin.Text(cell, "body", "TEXT")
        local input = skin.Input(cell, { width = 64, height = 22 })
        cell:SetScript("OnSizeChanged", function(self, w)
            if type(w) ~= "number" then return end
            local half = w * colW
            label:ClearAllPoints()
            label:SetPoint("LEFT", self, "LEFT", col * half, 0)
            input:ClearAllPoints()
            input:SetPoint("LEFT", self, "LEFT", col * half + 170, 0)
        end)
        label:SetPoint("LEFT", cell, "LEFT", 0, 0)
        input:SetPoint("LEFT", cell, "LEFT", 170, 0)
        label:SetText(Classes.STAT_LABELS[k] or k)
        local function show()
            local w = Classes.Weights()[k]
            input:SetText(w and tostring(GP.Round(w, 3)) or "0")
            input:SetCursorPosition(0)
        end
        local function apply()
            local v = tonumber(input:GetText())
            if not v then show() return end
            local current = Classes.Weights()[k] or 0
            if v == current then return end
            local base = Classes.BaseWeights()
            GP.char.weights = GP.char.weights or {}
            if v == (base[k] or 0) then GP.char.weights[k] = nil else GP.char.weights[k] = v end
            if next(GP.char.weights) == nil then GP.char.weights = nil end
            GP.Fire("WeightsChanged")
        end
        input:HookScript("OnEditFocusLost", apply)
        onRefresh(show)
    end
    return y + math.ceil(#keys / 2) * 30 + 6
end

-- ---------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------

UI.RegisterPage("settings", {
    text = "Settings",
    order = 4,
    Build = function(page)
        local skin = GP.Skin.current
        local sf = skin.Scroll(page)
        sf:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
        sf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -(sf.barRoom or 16), 0)
        local c = sf.child
        sf:HookScript("OnSizeChanged", function(_, w) if type(w) == "number" and w > 0 then c:SetWidth(w) end end)
        Settings.sf = sf

        local y = 6
        for k, v in pairs(LOOK_LABELS) do LOOK_LABELS[k] = L[v] end
        y = section(c, y, "Look")
        local look = GP.Dropdown(c, { width = 200, keys = LOOK_KEYS, labels = LOOK_LABELS,
            get = function() return GP.Setting("look") or "auto" end,
            set = function(k)
                GP.SetSetting("look", k)
                for _, fn in ipairs(Settings.refreshers) do fn() end
            end })
        local lookDesc
        y, lookDesc = row(c, y, "Window look",
            "Automatic uses DaylightUI's look when DaylightUI is on, the game's own look when it isn't.", look)
        onRefresh(function()
            look.Refresh()
            local now = GP.Skin.current and GP.Skin.current.label or "?"
            local after = GP.Skin.PendingLabel()
            if now == after then
                lookDesc:SetText(L["Automatic uses DaylightUI's look when DaylightUI is on, the game's own look when it isn't."]
                    .. " " .. string.format(L["Showing: %s."], now))
            else
                lookDesc:SetText(string.format(L["Showing %s now; %s after a reload (type /reload)."], now, after))
            end
        end)
        local scale = stepper(c, function() return GP.Setting("scale") or 1 end, function(v)
            GP.SetSetting("scale", v)
            UI.SetScale(v)
        end, 0.7, 1.3, 0.05, function(v) return string.format("%d%%", GP.Round((v or 1) * 100)) end)
        y = row(c, y, "Window scale", "Makes everything in the window bigger or smaller. Drag the window's corner for more room.", scale)

        y = section(c, y, "What to look for")
        y = row(c, y, "Look ahead",
            "Show gear you can't wear yet, up to this many levels above you (under Worth chasing).",
            stepper(c, function() return GP.Setting("ahead") or 5 end, function(v) GP.SetSetting("ahead", v) end,
                0, 10, 1, levels))
        y = row(c, y, "Best now range",
            "Gear this many levels above you still counts as Best now, if it's easy to get (a quest or vendor out in the world).",
            stepper(c, function() return GP.Setting("soon") or 2 end, function(v) GP.SetSetting("soon", v) end,
                0, 5, 1, levels))
        y = row(c, y, "Dungeon gear", "List dungeon quests and drops under Worth chasing.", toggle(c, "dungeons"))
        y = row(c, y, "Random world drops",
            "Also list gear that drops at random from many kinds of mobs (rarely worth farming).", toggle(c, "worldDrops"))
        y = row(c, y, "Healer gear",
            "Gear made for healers (Healing is its main stat) is left out, and its loot roll tooltip says to let your healer roll. Turn this on to list it anyway.",
            toggle(c, "healerGear"))

        y = section(c, y, "Extras")
        y = row(c, y, "Tooltips",
            "Adds GearPath's lines to tooltips: on gear, how much better it is and where to get it; on NPCs and mobs, the upgrades they drop, sell or give for a quest.",
            toggle(c, "tooltip"))
        y = row(c, y, "Minimap button",
            "A GearPath button on the minimap: click to open the window, right-click for Settings, drag to move it. GearPath also has a key binding (Key Bindings > AddOns).",
            toggle(c, "minimapButton"))
        y = row(c, y, "Item levels",
            "Shows each item's level on its slot in the game's own Character window, in the item's quality colour.",
            toggle(c, "itemLevels"))
        y = row(c, y, "Upgrade notes",
            "A toast when you put on an upgrade, and a line in chat when a vendor sells one or a level-up lets you wear one from your bags.",
            toggle(c, "notices"))
        y = row(c, y, "Learn as you play",
            "Remember quest rewards, loot and vendor gear you see, so new items the database doesn't know yet still get a source.",
            toggle(c, "learn"))
        y = row(c, y, "Quest reward pick",
            "When a quest offers a choice, shows the best upgrade for you (or the best seller) beside the quest window, and in chat as you turn it in.",
            toggle(c, "questPick"))
        y = row(c, y, "Rare watch",
            "In a dungeon, an icon for each rare that drops an upgrade for you, lit with a sound when it's near. Hidden in combat; /gp rare brings it back.",
            toggle(c, "rareWatch"))
        y = row(c, y, "Rare watch in the open world",
            "Out in the world, an icon, a sound and a chat line when a rare of your zone that drops an upgrade for you comes into view (its nameplate, a target, a minimap marker).",
            toggle(c, "rareWatchWorld"))
        -- Only in a client GearPath has (draft) translations for.
        if GP.Text and GP.Text.available then
            y = row(c, y, "English text",
                "GearPath's window is translated by machine (a draft). Turn this on to see it in English. Takes effect after a reload (type /reload).",
                toggle(c, "englishText"))
        end

        y = section(c, y, "Checking and sharing",
            "GearPath double-checks where items come from, and can trade what players see in game with other GearPath users.")
        y = row(c, y, "Check a slot when you click it",
            "Asks the database again about that slot's items (finished quests, quests you picked up) and compares them with the game.",
            toggle(c, "checkOnClick"))
        y = row(c, y, "Check everything every",
            "Also checks every item in the background this often, out of combat.",
            stepper(c, function() return GP.Setting("checkEvery") or 10 end, function(v) GP.SetSetting("checkEvery", v) end,
                0, 60, 5, function(v) return (v or 0) <= 0 and L["Off"] or string.format(L["%d min"], v) end))
        y = row(c, y, "Share what you see",
            "Trades the quest rewards, loot and vendor gear you see with other GearPath users. Only item, quest, NPC and map numbers are sent.",
            toggle(c, "share", function() if GP.Share then GP.Share.Changed() end end))
        y = row(c, y, "Use the GearPath channel",
            "Also trades with every other GearPath user online, through a hidden chat channel. Turn it off to share with only your guild and group.",
            toggle(c, "shareChannel", function() if GP.Share then GP.Share.Changed() end end))

        y = section(c, y, "Stat weights",
            "How many points 1 of each stat is worth to you (hit, crit and haste: per 1%). Type a number; it's used as soon as you click away.")
        -- The spec: its own weights (and weapon speed), healer gear for healing specs.
        local specs = GP.Classes.Specs()
        if #specs > 1 then
            local specKeys, specLabels = {}, {}
            for _, s in ipairs(specs) do
                specKeys[#specKeys + 1] = s.key
                specLabels[s.key] = L[s.name]
            end
            local specPick = GP.Dropdown(c, { width = 200, keys = specKeys, labels = specLabels,
                get = function() return GP.Classes.Spec().key end,
                set = function(k)
                    GP.Classes.SetSpec(k)
                    for _, fn in ipairs(Settings.refreshers) do fn() end
                end })
            onRefresh(function() specPick.Refresh() end)
            y = row(c, y, "Spec",
                "Which stats count, and for melee and hunters which weapon speed. Healing specs list healer gear. Your own changes to the weights are kept for each spec.",
                specPick)
        end
        y = weightRows(c, y)
        local copyW = skin.Button(c, L["Copy my weights"], 150, 24)
        copyW:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -y)
        copyW:SetScript("OnClick", function() GP.Classes.ShowExport() end)
        local pasteW = skin.Button(c, L["Paste weights"], 150, 24)
        pasteW:SetPoint("LEFT", copyW, "RIGHT", 10, 0)
        pasteW:SetScript("OnClick", function()
            GP.Classes.ShowImport(function() for _, fn in ipairs(Settings.refreshers) do fn() end end)
        end)
        Settings.copyWeights, Settings.pasteWeights = copyW, pasteW
        y = y + 34

        local rescan = skin.Button(c, L["Rescan database"], 150, 24)
        rescan:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -y)
        rescan:SetScript("OnClick", function() GP.Fire("RescanRequested") end)
        local reset = skin.Button(c, L["Reset stat weights"], 150, 24)
        reset:SetPoint("LEFT", rescan, "RIGHT", 10, 0)
        reset:SetScript("OnClick", function()
            GP.char.weights = nil
            GP.Fire("WeightsChanged")
            for _, fn in ipairs(Settings.refreshers) do fn() end
        end)
        local forget = skin.Button(c, L["Forget learned gear"], 160, 24)
        forget:SetPoint("LEFT", reset, "RIGHT", 10, 0)
        forget:SetScript("OnClick", function() SlashCmdList.GEARPATH("forget") end)
        local check = skin.Button(c, L["Check everything now"], 170, 24)
        check:SetPoint("TOPLEFT", rescan, "BOTTOMLEFT", 0, -10)
        check:SetScript("OnClick", function() SlashCmdList.GEARPATH("check") end)
        y = y + 74

        -- What you hid with a right-click (Hide.lua), each with Show again.
        y = section(c, y, "Hidden vendors and items",
            "Right-click an item in the window to hide its vendor or the item. Hidden ones are left off the lists; tooltips still show them.")
        local top, rows = y, {}
        local function layout()
            local list = GP.Hide.List()
            local yy = top
            for i = 1, math.max(#list, 1) do
                local r = rows[i]
                if not r then
                    r = CreateFrame("Frame", nil, c)
                    r:SetHeight(26)
                    r.text = skin.Text(r, "body", "VALUE")
                    r.text:SetPoint("LEFT", r, "LEFT", 0, 0)
                    r.text:SetPoint("RIGHT", r, "RIGHT", -130, 0)
                    r.show = skin.Button(r, L["Show again"], 110, 22)
                    r.show:SetPoint("RIGHT", r, "RIGHT", 0, 0)
                    r.show:SetScript("OnClick", function()
                        if r.entry then GP.Hide.Show(r.entry.kind, r.entry.key) end
                    end)
                    rows[i] = r
                end
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -yy)
                r:SetPoint("RIGHT", c, "RIGHT", -16, 0)
                local e = list[i]
                r.entry = e
                if e then
                    r.text:SetText(string.format(e.kind == "v" and L["%s (vendor)"] or L["%s (item)"], e.name))
                    r.show:Show()
                else
                    r.text:SetText(L["Nothing hidden."])
                    r.show:Hide()
                end
                r:Show()
                yy = yy + 30
            end
            for i = math.max(#list, 1) + 1, #rows do rows[i]:Hide() end
            c:SetHeight(yy + 20)
            if Settings.sf and Settings.sf.UpdateBar then Settings.sf.UpdateBar() end
        end
        Settings.hiddenRows = rows
        onRefresh(layout)
        GP.On("HiddenChanged", function() GP.SafeCall(layout) end)
        layout()
    end,
    Fill = function()
        for _, fn in ipairs(Settings.refreshers) do fn() end
        if Settings.sf and Settings.sf.UpdateBar then Settings.sf.UpdateBar() end
    end,
})
