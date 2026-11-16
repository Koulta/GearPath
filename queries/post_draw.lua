-- POST=queries/post_draw.lua with sweep.lua: on the real database, every
-- listed item's tooltip is built, every source described and given its map
-- pin text, and every row of every page drawn. Prints "draw problems N".
local GP, res, H = ...
local UI = GP.UI
-- (The sweep's stand-in game has no names for units.)
if not UnitName then function UnitName() return "Sweep" end end
local bad, shown = 0, 0
local function try(what, fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then
        bad = bad + 1
        if shown < 5 then shown = shown + 1 print("  DRAW PROBLEM " .. what .. ": " .. tostring(r[2])) end
        return nil
    end
    return unpack(r, 2)
end
local before = GP.errors.count
local tips, described, rows = 0, 0, 0
for _, ev in ipairs(res.all or {}) do
    GameTooltip._lines = {}
    try("tooltip " .. tostring(ev.rec.name), GP.Tooltip.Add, GameTooltip, ev.rec.id, ev.rec.link)
    tips = tips + 1
    try("check " .. tostring(ev.rec.name), GP.Check.Item, ev.entry)
    for _, src in ipairs(ev.entry and ev.entry.allSources or {}) do
        local text = try("describe " .. tostring(ev.rec.name), UI.Describe, src, true)
        if text ~= nil and type(text) ~= "string" then bad = bad + 1 end
        try("pin " .. tostring(ev.rec.name), GP.Waypoint.Describe, src)
        try("effort", GP.Score.Effort, src)
        described = described + 1
    end
    try("roll " .. tostring(ev.rec.name), GP.Roll.Verdict, ev.rec)
    try("sell " .. tostring(ev.rec.name), GP.Score.SafeToSell, ev.rec)
end
local function drawAll(list, what)
    if not (list and list.items) then return end
    for _, it in ipairs(list.items) do
        local kind = list.kinds[it.kind] or list.kinds.note
        local row = CreateFrame("Button", nil, UIParent)
        try(what .. " row " .. tostring(it.kind) .. (it.ev and (" " .. tostring(it.ev.rec.name)) or ""), function()
            kind.build(row, list)
            kind.fill(row, it, list)
        end)
        rows = rows + 1
    end
end
if not (UI.frame and UI.frame:IsShown()) then try("open", UI.Toggle) end
for _, group in ipairs({ false, "slot" }) do
    GP.SetSetting("routeGroup", group or nil)
    try("route", UI.Show, "plan")
    if UI.Plan and UI.Plan.list then
        for _, it in ipairs(UI.Plan.list.items) do
            if it.kind == "more" and it.pick and UI.Plan.open then UI.Plan.open[it.pick] = true end
        end
        try("route opened", UI.PAGES.plan.Fill, UI.PAGES.plan.frame)
        drawAll(UI.Plan.list, "route")
    end
end
GP.SetSetting("routeGroup", nil)
try("browse", UI.Show, "browse")
drawAll(UI.Browse and UI.Browse.list, "browse")
try("character", UI.Show, "doll")
for _, s in ipairs(GP.Slots.LIST) do
    if not s.cosmetic then
        try("slot " .. s.key, UI.SelectSlot, s.key)
        drawAll(UI.SlotPanel.list, "slot " .. s.key)
    end
end
try("no slot", UI.SelectSlot, nil)
try("settings", UI.Show, "settings")
if GP.errors.count > before then
    bad = bad + (GP.errors.count - before)
    print("  DRAW PROBLEM caught by GearPath: " .. tostring(GP.errors.last))
end
print(string.format("draw problems %d (%d tooltips, %d sources, %d rows)", bad, tips, described, rows))
