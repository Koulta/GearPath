-- Hide: vendors and items you don't want GearPath to list (dmann420 on
-- CurseForge, Nov 7: "an option to blacklist a vendor"). Right-click an
-- item's row in the window; Settings lists what's hidden, to show it again.
--
-- A hidden vendor is left out as a way to get anything: an item it sells
-- that you can get some other way keeps that way; one only it sells drops
-- off the lists. A hidden item drops off the lists from any source.
-- Tooltips stay as they are. Kept account-wide in GearPathDB.hidden:
--   v = { [npc id or name] = name },  i = { [itemID] = name }

local _, GP = ...

local Hide = {}
GP.Hide = Hide

local function db()
    local d = GP.db
    if not d then return nil end
    if type(d.hidden) ~= "table" then d.hidden = {} end
    d.hidden.v = type(d.hidden.v) == "table" and d.hidden.v or {}
    d.hidden.i = type(d.hidden.i) == "table" and d.hidden.i or {}
    return d.hidden
end

GP.On("Loaded", db)

function Hide.Any()
    local h = db()
    return h ~= nil and (next(h.v) ~= nil or next(h.i) ~= nil)
end

-- A vendor source's key (its NPC id, or its name for one learned by name).
function Hide.VendorKey(src)
    if type(src) ~= "table" or src.kind ~= "vendor" then return nil end
    return src.id or src.name
end

function Hide.IsVendor(src)
    local key = Hide.VendorKey(src)
    local h = key ~= nil and db()
    return h and h.v[key] ~= nil or false
end

function Hide.IsItem(id)
    local h = id and db()
    return h and h.i[id] ~= nil or false
end

local function changed()
    if GP.Sources and GP.Sources.ApplyHidden then GP.Sources.ApplyHidden() end
    if GP.Score then GP.Score.Request() end
    GP.Fire("HiddenChanged")
end

function Hide.Vendor(src)
    local key, h = Hide.VendorKey(src), db()
    if key == nil or not h then return end
    h.v[key] = src.name or tostring(key)
    changed()
end

function Hide.Item(rec)
    local h = db()
    if not (rec and rec.id and h) then return end
    h.i[rec.id] = rec.name or ("item " .. rec.id)
    changed()
end

-- Shows a vendor ("v") or an item ("i") again.
function Hide.Show(kind, key)
    local h = db()
    if not (h and h[kind]) then return end
    h[kind][key] = nil
    changed()
end

-- What's hidden, vendors first, then items, each by name:
-- { { kind = "v" or "i", key, name }, ... }
function Hide.List()
    local h, out = db(), {}
    if not h then return out end
    for _, kind in ipairs({ "v", "i" }) do
        local part = {}
        for key, name in pairs(h[kind]) do
            part[#part + 1] = { kind = kind, key = key, name = type(name) == "string" and name or tostring(key) }
        end
        table.sort(part, function(a, b) return a.name < b.name end)
        for _, e in ipairs(part) do out[#out + 1] = e end
    end
    return out
end
