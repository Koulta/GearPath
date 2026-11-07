-- List: one scrolling list for every page. Only the rows on screen exist
-- (a few dozen frames, reused), so a list of two thousand items scrolls as
-- smoothly as one of ten. Rows come in kinds; the shared ones are:
--
--   header   a group (a zone, a dungeon): the whole bar is its map pin
--   item     an item: icon, name, gain, where to get it, level, and a map
--            pin button (not on lists made with pins = false, where a click
--            on the row is the map pin)
--   note     a dim line ("Nothing better within reach yet.")
--
-- list:SetItems({ { kind = "header", text = ..., right = ... },
--                 { kind = "item", ev = <Score evaluation>, prefix = ... }, ... })

local _, GP = ...

local List = {}
List.__index = List
GP.List = List

List.KINDS = {}

-- ---------------------------------------------------------------------
-- The shared kinds
-- ---------------------------------------------------------------------

-- A section: "Best now", "Worth chasing".
List.KINDS.section = {
    height = 34,
    highlight = false,
    build = function(row)
        local skin = GP.Skin.current
        row.bg = skin.HeaderLine(row)
        row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4)
        row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 4)
        row.right = skin.Text(row, "small", "LABEL", "RIGHT")
        row.right:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.text = skin.Text(row, "head", "TITLE")
        row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.text:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
        row.text:SetWordWrap(false)
    end,
    fill = function(row, item)
        row.text:SetText(item.text or "")
        row.right:SetText(item.right or "")
        if item.role then GP.Skin.current.Ink(row.text, item.role) else GP.Skin.current.Ink(row.text, "TITLE") end
    end,
}

-- A group inside a section: a zone or a dungeon on the route. A shaded
-- band with a colored edge (purple: a dungeon, green: a zone, gold: your
-- bags, gray: unknown), its icon and what's in it. Clicking the bar puts
-- the map pin on the place.
List.TONES = {
    dungeon = { 0.64, 0.42, 0.95 }, zone = { 0.35, 0.80, 0.45 },
    bags = { 1, 0.78, 0.25 }, unknown = { 0.55, 0.55, 0.55 }, random = { 0.85, 0.55, 0.30 },
}
List.ICONS = {
    dungeon = "Interface\\Icons\\INV_Misc_Key_03", zone = "Interface\\Icons\\INV_Misc_Map_01",
    bags = "Interface\\Icons\\INV_Misc_Bag_08", unknown = "Interface\\Icons\\INV_Misc_QuestionMark",
    random = "Interface\\Icons\\INV_Box_02",
}

local function headerPinnable(item)
    return item.source ~= nil and GP.Waypoint.CanSet(item.source)
end

List.KINDS.header = {
    height = 34,
    build = function(row)
        local skin = GP.Skin.current
        row.band = row:CreateTexture(nil, "BACKGROUND")
        row.band:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -3)
        row.band:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 3)
        row.band:SetColorTexture(1, 1, 1, 0.05)
        row.edge = row:CreateTexture(nil, "ARTWORK")
        row.edge:SetPoint("TOPLEFT", row.band, "TOPLEFT", 0, 0)
        row.edge:SetPoint("BOTTOMLEFT", row.band, "BOTTOMLEFT", 0, 0)
        row.edge:SetWidth(3)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row, "LEFT", 12, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.right = skin.Text(row, "small", "LABEL", "RIGHT")
        row.right:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.text = skin.Text(row, "body", "VALUE")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
        row.text:SetWordWrap(false)
    end,
    fill = function(row, item)
        local tone = item.tone or "zone"
        local c = List.TONES[tone] or List.TONES.zone
        row.edge:SetColorTexture(c[1], c[2], c[3], 0.9)
        row.band:SetColorTexture(c[1], c[2], c[3], 0.07)
        row.icon:SetTexture(item.icon or List.ICONS[tone] or List.ICONS.zone)
        row.text:SetText(item.text or "")
        row.right:SetText(item.right or "")
        -- Lights up under the mouse only when a click does something.
        if row.hl then row.hl:SetShown(headerPinnable(item)) end
    end,
    enter = function(row)
        if not headerPinnable(row.item) then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.item.text or "", 1, 1, 1)
        GameTooltip:AddLine("Click: map pin.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end,
    click = function(row)
        if headerPinnable(row.item) then GP.UI.Waypoint(row.item.source, row.item.text) end
    end,
}

-- Room between groups.
List.KINDS.gap = {
    height = 10,
    highlight = false,
    build = function() end,
    fill = function() end,
}

List.KINDS.note = {
    height = 34,
    highlight = false,
    build = function(row)
        row.text = GP.Skin.current.Text(row, "small", "LABEL")
        row.text:SetPoint("LEFT", row, "LEFT", 12, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        row.text:SetWordWrap(true)
    end,
    fill = function(row, item) row.text:SetText(item.text or "") end,
}

List.KINDS.item = {
    height = 46,
    build = function(row)
        local skin = GP.Skin.current
        row.icon = skin.Icon(row, 34)
        row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.guide = row:CreateTexture(nil, "BACKGROUND")
        row.guide:SetPoint("TOPLEFT", row, "TOPLEFT", 12, 0)
        row.guide:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 12, 0)
        row.guide:SetWidth(2)
        row.guide:Hide()
        row.pin = GP.Skin.PinButton(row, 18)
        row.pin:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.pin:SetScript("OnClick", function()
            local ev = row.item and row.item.ev
            if ev then GP.UI.Waypoint(ev.source, ev.rec.name) end
        end)
        row.gain = skin.Text(row, "body", "GOOD", "RIGHT")
        row.gain:SetPoint("TOPRIGHT", row, "TOPRIGHT", -30, -7)
        row.gain:SetWidth(84)
        row.req = skin.Text(row, "small", "LABEL", "RIGHT")
        row.req:SetPoint("TOPRIGHT", row.gain, "BOTTOMRIGHT", 0, -5)
        row.req:SetWidth(84)
        row.name = skin.Text(row, "body", "VALUE")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 9, -1)
        row.name:SetPoint("RIGHT", row.gain, "LEFT", -6, 0)
        row.name:SetWordWrap(false)
        row.where = skin.Text(row, "small", "LABEL")
        row.where:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -5)
        row.where:SetPoint("RIGHT", row.req, "LEFT", -6, 0)
        row.where:SetWordWrap(false)
    end,
    fill = function(row, item, list)
        local ev = item.ev
        local rec = ev.rec
        local skin = GP.Skin.current
        local pins = not (list and list.opts.pins == false)
        row.gain:SetPoint("TOPRIGHT", row, "TOPRIGHT", pins and -30 or -10, -7)
        local indent = item.indent or 0
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", row, "LEFT", 6 + indent, 0)
        if indent > 0 then
            local c = List.TONES[item.tone or "zone"] or List.TONES.zone
            row.guide:SetColorTexture(c[1], c[2], c[3], 0.35)
            row.guide:Show()
        else
            row.guide:Hide()
        end
        row.icon.SetItem(rec.icon, rec.quality)
        row.name:SetText(rec.name or ("Item " .. tostring(rec.id)))
        local r, g, b = GP.QualityColor(rec.quality)
        row.name:SetTextColor(r, g, b)
        local text, role = GP.UI.GainText(ev)
        row.gain:SetText(text == "new" and GP.L["new"] or text)
        skin.Ink(row.gain, role)
        local where = GP.UI.Describe(ev.source)
        if ev.needs then where = "|cffff5050Needs " .. ev.needs .. "|r  |  " .. where end
        if ev.train and GP.Training then where = "|cffff5050" .. GP.Training.Short(ev.train) .. "|r  |  " .. where end
        if item.prefix then where = item.prefix .. "  |  " .. where end
        row.where:SetText(GP.Check.Mark(rec.id) .. where)
        local level = GP.player and GP.player.level or 1
        -- Required level (not item level). Red when it's above your level.
        row.req:SetText(ev.req and ev.req > 0 and ("Req. " .. ev.req) or "")
        skin.Ink(row.req, (ev.req or 0) > level and "WARN" or "LABEL")
        row.pin:SetShown(pins and GP.Waypoint.CanSet(ev.source))
    end,
    enter = function(row) GP.UI.ItemTooltip(row, row.item.ev) end,
    click = function(row, button) GP.UI.ItemClick(row.item.ev, button, row) end,
}

-- ---------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------

-- opts: kinds = { name = kind } (added to the shared ones), onClick(item,
-- button, row) for any row, empty = text when there's nothing.
function List.New(parent, opts)
    opts = opts or {}
    local skin = GP.Skin.current
    local self = setmetatable({
        opts = opts, items = {}, tops = {}, heights = {}, total = 0,
        pools = {}, active = {}, kinds = setmetatable(opts.kinds or {}, { __index = List.KINDS }),
    }, List)
    self.frame = CreateFrame("Frame", nil, parent)
    local sf = skin.Scroll(self.frame)
    sf:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -(sf.barRoom or 16), 0)
    self.sf, self.child = sf, sf.child
    sf:HookScript("OnVerticalScroll", function() self:Draw() end)
    sf:HookScript("OnSizeChanged", function(_, w)
        if type(w) == "number" and w > 0 then self.child:SetWidth(w) end
        self:Draw()
    end)
    self.empty = skin.Text(self.frame, "body", "LABEL", "CENTER")
    self.empty:SetPoint("LEFT", self.frame, "LEFT", 24, 0)
    self.empty:SetPoint("RIGHT", self.frame, "RIGHT", -24, 0)
    self.empty:SetWordWrap(true)
    self.empty:SetText(opts.empty or "")
    self.empty:Hide()
    return self
end

function List:SetPoint(...) self.frame:SetPoint(...) end
function List:SetEmptyText(text) self.empty:SetText(text or "") end

local function binaryFirst(tops, y)
    local lo, hi = 1, #tops
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if tops[mid] <= y then lo = mid else hi = mid - 1 end
    end
    return lo
end

function List:SetItems(items, keepScroll)
    self.items = items or {}
    local y = 0
    for i, item in ipairs(self.items) do
        local kind = self.kinds[item.kind] or self.kinds.note
        local h = item.height or kind.height or 30
        self.tops[i], self.heights[i] = y, h
        y = y + h
    end
    for i = #self.items + 1, #self.tops do self.tops[i], self.heights[i] = nil, nil end
    self.total = y
    self.child:SetHeight(math.max(1, y))
    if not keepScroll then self.sf:SetVerticalScroll(0) end
    -- A controller's focus stays on its row only through a refresh in place.
    if not keepScroll or (self.focus and not self:CanFocus(self.focus)) then self.focus = nil end
    self.empty:SetShown(#self.items == 0)
    self:Draw()
    if self.sf.UpdateBar then self.sf.UpdateBar() end
end

function List:Release()
    for row in pairs(self.active) do
        row:Hide()
        row:ClearAllPoints()
        row.item = nil
        local pool = self.pools[row.kindName]
        pool[#pool + 1] = row
    end
    wipe(self.active)
end

function List:Acquire(kindName)
    self.pools[kindName] = self.pools[kindName] or {}
    local pool = self.pools[kindName]
    local row = table.remove(pool)
    if row then return row end
    local kind = self.kinds[kindName]
    row = CreateFrame("Button", nil, self.child)
    row:Hide()
    row.kindName = kindName
    row:SetHeight(kind.height or 30)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if kind.highlight ~= false then GP.Skin.current.Highlight(row) end
    kind.build(row, self)
    local list = self
    row:SetScript("OnClick", function(r, button)
        if not r.item then return end
        if r.item.onClick then r.item.onClick(r.item, button, r)
        elseif list.opts.onClick then list.opts.onClick(r.item, button, r)
        elseif kind.click then kind.click(r, button) end
    end)
    row:SetScript("OnEnter", function(r)
        if not r.item then return end
        if r.item.tip then
            GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
            GameTooltip:SetText(r.item.tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        elseif kind.enter then
            kind.enter(r)
        end
    end)
    row:SetScript("OnLeave", function() GP.UI.HideItemTooltip() end)
    return row
end

function List:Draw()
    self:Release()
    local n = #self.items
    if n == 0 then return end
    local top = self.sf:GetVerticalScroll() or 0
    local view = self.sf:GetHeight() or 0
    if view <= 0 then return end
    for i = binaryFirst(self.tops, top), n do
        local y = self.tops[i]
        if y > top + view then break end
        local item = self.items[i]
        local kindName = self.kinds[item.kind] and item.kind or "note"
        local row = self:Acquire(kindName)
        -- Counted as on screen before it's filled, so a row whose fill
        -- fails is still put away on the next draw instead of left behind.
        self.active[row] = true
        row:SetHeight(self.heights[i])
        row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", self.child, "RIGHT", 0, 0)
        row.item = item
        local ok = GP.SafeCall(self.kinds[kindName].fill, row, item, self)
        if row.sel then row.sel:SetShown(ok and item.key ~= nil and item.key == self.selected) end
        local focused = ok and self.focus == i
        if focused and not row.focusMark then
            local r, g, b = GP.Skin.current.Accent()
            row.focusMark = row:CreateTexture(nil, "OVERLAY")
            row.focusMark:SetAllPoints(row)
            row.focusMark:SetColorTexture(r, g, b, 0.14)
            row.focusEdge = row:CreateTexture(nil, "OVERLAY")
            row.focusEdge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.focusEdge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            row.focusEdge:SetWidth(3)
            row.focusEdge:SetColorTexture(r, g, b, 0.9)
        end
        if row.focusMark then
            row.focusMark:SetShown(focused)
            row.focusEdge:SetShown(focused)
        end
        row:SetShown(ok)
    end
end

function List:Select(key)
    self.selected = key
    self:Draw()
end

-- ---------------------------------------------------------------------
-- A controller's focus: one row at a time, moved with the D-pad (the
-- window's controller handling, Window.lua). Only rows a click does
-- something on can have it.
-- ---------------------------------------------------------------------

function List:CanFocus(i)
    local item = self.items[i]
    local kind = item and self.kinds[item.kind]
    if not kind or kind.highlight == false then return false end
    if item.kind == "header" and not item.onClick then return headerPinnable(item) end
    return true
end

-- Keeps row i in view.
function List:ScrollTo(i)
    local top, h = self.tops[i], self.heights[i]
    if not top then return end
    local sf = self.sf
    local view = sf:GetHeight() or 0
    local cur = sf:GetVerticalScroll() or 0
    local want = cur
    if top < cur then want = top elseif top + h > cur + view then want = top + h - view end
    want = GP.Clamp(want, 0, math.max(0, self.total - view))
    if want ~= cur then sf:SetVerticalScroll(want) end
end

-- Moves the focus to the next row a click works on (step 1: down, -1: up).
-- Returns whether it moved.
function List:MoveFocus(step)
    local n = #self.items
    if n == 0 then return false end
    local i = self.focus
    if not (i and self:CanFocus(i)) then i = step > 0 and 0 or n + 1 end
    repeat i = i + step until i < 1 or i > n or self:CanFocus(i)
    if i < 1 or i > n then return false end
    self.focus = i
    self:ScrollTo(i)
    self:Draw()
    return true
end

-- The row on screen for the focused item, if it's drawn.
function List:FocusRow()
    local item = self.focus and self.items[self.focus]
    if not item then return nil end
    for row in pairs(self.active) do
        if row.item == item then return row end
    end
end

function List:ClearFocus()
    if self.focus == nil then return end
    self.focus = nil
    self:Draw()
end
