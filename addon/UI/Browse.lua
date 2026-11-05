-- Browse: the Browse tab, every piece of gear found for you (your class,
-- within reach of your level) to search, filter and sort, as a gear
-- database addon would show it, each with how much better it is than what
-- you wear and where to get it.

local _, GP = ...

local UI, Slots = GP.UI, GP.Slots
local L = GP.L

local Browse = {}
UI.Browse = Browse

Browse.state = { text = "", slot = "all", upgrades = false }

local SLOT_KEYS, SLOT_LABELS = { "all" }, { all = "All slots" }
for _, key in ipairs(Slots.ORDER) do
    if not Slots.GROUP[key] then
        SLOT_KEYS[#SLOT_KEYS + 1] = key
        SLOT_LABELS[key] = Slots.Label(key)
    end
end

function Browse.Filtered()
    local st = Browse.state
    local text = st.text:lower()
    local out = {}
    for _, ev in ipairs(GP.Score.results.all or {}) do
        local rec = ev.rec
        local ok = true
        if text ~= "" and not (rec.name or ""):lower():find(text, 1, true) then ok = false end
        if ok and st.slot ~= "all" and (Slots.GROUP[ev.slot] or ev.slot) ~= st.slot then ok = false end
        if ok and not UI.ContentMatches(ev) then ok = false end
        if ok and st.upgrades and not ev.tier then ok = false end
        if ok then out[#out + 1] = ev end
    end
    table.sort(out, UI.SORTS[GP.Setting("browseSort") or "ilvl"] or UI.SORTS.ilvl)
    return out
end

local function changed()
    local def = UI.PAGES.browse
    Browse.reset = true
    if def and def.frame and def.frame:IsShown() then GP.SafeCall(def.Fill, def.frame) end
end

UI.RegisterPage("browse", {
    text = "Browse",
    order = 3,
    Build = function(page)
        local skin = GP.Skin.current
        local st = Browse.state
        local bar = CreateFrame("Frame", nil, page)
        bar:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
        bar:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
        bar:SetHeight(30)

        -- Labels in the client's language (Data/Text.lua is applied by now).
        for k in pairs(SLOT_LABELS) do SLOT_LABELS[k] = k == "all" and L["All slots"] or Slots.Label(k) end
        Browse.search = skin.Input(bar, { search = true, hint = L["Search gear"], width = 190, height = 24,
            onChange = function(text)
                if text == st.text then return end
                st.text = text
                GP.Soon("browse-search", changed)
            end })
        Browse.search:SetPoint("LEFT", bar, "LEFT", 6, 0)

        Browse.slot = GP.Dropdown(bar, { width = 130, keys = SLOT_KEYS, labels = SLOT_LABELS,
            get = function() return st.slot end, set = function(k) st.slot = k; changed() end })
        Browse.slot:SetPoint("LEFT", Browse.search, "RIGHT", 10, 0)

        Browse.source = UI.ContentDropdown(bar, 190)
        Browse.source:SetHeight(24)
        Browse.source:SetPoint("LEFT", Browse.slot, "RIGHT", 8, 0)

        Browse.sort = GP.Dropdown(bar, { width = 170, keys = UI.SORT_KEYS, labels = UI.SORT_LABELS, prefix = L["Sort:"] .. " ",
            get = function() return GP.Setting("browseSort") or "ilvl" end,
            set = function(k) GP.SetSetting("browseSort", k); changed() end })
        Browse.sort:SetPoint("LEFT", Browse.source, "RIGHT", 8, 0)

        Browse.only = skin.Toggle(bar)
        Browse.only:SetPoint("LEFT", Browse.sort, "RIGHT", 12, 0)
        Browse.only.SetOn(st.upgrades)
        Browse.only.onToggle = function(on) st.upgrades = on; changed() end
        Browse.onlyLabel = skin.Text(bar, "small", "TEXT")
        Browse.onlyLabel:SetPoint("LEFT", Browse.only, "RIGHT", 4, 0)
        Browse.onlyLabel:SetText(L["Upgrades only"])

        Browse.count = skin.Text(bar, "small", "LABEL", "RIGHT")
        Browse.count:SetPoint("RIGHT", bar, "RIGHT", -6, 0)

        Browse.list = GP.List.New(page, { empty = L["No gear matches."], pins = false })
        Browse.list:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -38)
        Browse.list:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    end,
    Fill = function()
        Browse.source.Refresh()
        local key = UI.ContentKey()
        if Browse.contentKey ~= key then Browse.reset = true end
        Browse.contentKey = key
        local list = Browse.Filtered()
        local items = {}
        local S = GP.Sources
        if S.status == "scanning" or S.status == "loading" or S.status == "idle" then
            items[#items + 1] = { kind = "note", text = L["Still reading the gear database; more gear appears as items load."] }
        end
        for _, ev in ipairs(list) do
            items[#items + 1] = { kind = "item", ev = ev, key = ev.rec.id, prefix = Slots.Label(ev.slot) }
        end
        Browse.count:SetText(GP.Count(#list, "%d item", "%d items"))
        local keep = not Browse.reset
        Browse.reset = false
        Browse.list:SetItems(items, keep)
    end,
})
