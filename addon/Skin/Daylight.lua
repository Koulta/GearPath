-- The DaylightUI look: GearPath as a DaylightUI window. Everything here
-- calls DaylightUI's own functions (its window kit, styles and widgets,
-- through the DaylightUI global); none of its code or art is copied, so
-- this look needs DaylightUI installed and follows its theme, accent,
-- font and text settings by itself.
--
-- GearPath also registers as a DaylightUI plugin, so it's listed under
-- General > Plugins and gets its own entry in DaylightUI's options.

local _, GP = ...

local D = { label = "DaylightUI" }
GP.Skin.Register("daylight", D)

local function DUI() return rawget(_G, "DaylightUI") end

function D.Available()
    local d = DUI()
    return type(d) == "table" and type(d.Win) == "table" and type(d.Win.New) == "function"
        and type(d.Style) == "table" and type(d.Style.Text) == "function"
        and type(d.Widgets) == "table" and type(d.Widgets.Button) == "function"
end

D.BAR_ROOM = 12

local SIZE_FALLBACK = { tiny = 10, small = 12, body = 13, head = 15, title = 18 }

local function size(key)
    local S = DUI().Style.SIZE
    return (S and S[key]) or SIZE_FALLBACK[key] or 13
end

function D.Accent() return DUI().Style.Accent() end

function D.InkColor(role)
    local Style = DUI().Style
    if role == "pop" then return Style.Accent() end
    local c = Style.INK[role] or Style.INK.TEXT
    return c[1], c[2], c[3]
end

-- ---------------------------------------------------------------------
-- The window: DaylightUI's window kit (its shell, header, portrait, X,
-- header tabs and its open/close glide)
-- ---------------------------------------------------------------------

local function restorePosition(f)
    local Win = DUI().Win
    local p = GP.db.window.daylight
    if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then
        Win.PlaceTop(f, p[1], p[2])
    else
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

function D.Window(spec)
    local Win = DUI().Win
    local f = Win.New({ name = spec.name, w = spec.w, h = spec.h, portrait = true })
    -- DaylightUI's shell is see-through; with long lists of text in it,
    -- names over people's heads behind the window read as part of the
    -- list. A darker fill inside the border (the shell's own color) keeps
    -- the look and stops them showing through.
    local W, Style = DUI().Widgets, DUI().Style
    f.gpFill = W.Round(f, "BACKGROUND", -8)
    f.gpFill:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
    f.gpFill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)
    W.Tint(f.gpFill, Style.BACKGROUND or { 0.078, 0.078, 0.09 }, 0.75)
    f.body = CreateFrame("Frame", nil, f.host)
    f.body:SetPoint("TOPLEFT", f.host, "TOPLEFT", 14, -6)
    f.body:SetPoint("BOTTOMRIGHT", f.host, "BOTTOMRIGHT", -14, 14)
    Win.Drag(f, {
        save = function(x, y) GP.db.window.daylight = { x, y } end,
        reset = function()
            GP.db.window.daylight = nil
            restorePosition(f)
        end,
    })
    -- DaylightUI's own grip in the corner: drag for more rows, right-click
    -- for the made size again.
    if type(Win.Grip) == "function" and spec.minW then
        local made = { spec.minW, spec.minH }
        pcall(Win.Grip, f, {
            min = made,
            save = function(x, y) GP.db.window.daylight = { x, y } end,
            set = function(w, h) if spec.sized then spec.sized(w, h) end end,
            reset = function()
                f:SetSize(made[1], made[2])
                if spec.sized then spec.sized(nil) end
            end,
        })
    end
    restorePosition(f)
    D.SetScale(f, GP.Setting("scale"))
    Win.SetTitle(f, spec.title or "", nil, "")
    return f
end

function D.SetTitle(f, title, sub)
    DUI().Win.SetTitle(f, title or f.title:GetText() or "", nil, sub or "")
end

function D.Tabs(f, tabs, onPick)
    local Win = DUI().Win
    Win.Tabs(f, tabs, onPick)
    if tabs[1] then Win.PickTab(f, tabs[1].id) end
end

function D.PickTab(f, id) DUI().Win.PickTab(f, id) end

function D.Open(f)
    local Win = DUI().Win
    Win.SetPortrait(f, "player")
    Win.Open(f)
end

function D.Close(f) DUI().Win.Close(f) end

function D.IsOpen(f) return DUI().Win.IsOpen(f) end

function D.SetScale(f, scale)
    local Win = DUI().Win
    scale = GP.Clamp(tonumber(scale) or 1, 0.6, 1.5)
    local ok, s = pcall(Win.Scale, scale)
    f:SetScale(ok and type(s) == "number" and s or scale)
end

-- ---------------------------------------------------------------------
-- Pieces
-- ---------------------------------------------------------------------

-- A soft rounded card behind a group (the model, a list).
function D.Panel(parent)
    local W = DUI().Widgets
    local p = CreateFrame("Frame", nil, parent)
    p.bg = W.Round(p, "BACKGROUND")
    p.bg:SetAllPoints(p)
    W.Tint(p.bg, { 1, 1, 1 }, 0.035)
    return p
end

function D.Ink(fs, role, a) DUI().Style.InkText(fs, role or "TEXT", a) end

function D.Text(parent, sizeKey, role, justify)
    local Style = DUI().Style
    local fs = Style.Text(parent, size(sizeKey or "body"), justify or "LEFT")
    Style.InkText(fs, role or ((sizeKey == "head" or sizeKey == "title") and "TITLE" or "TEXT"))
    return fs
end

function D.Separator(parent)
    local t = DUI().Style.Separator(parent)
    t:SetHeight(1)
    return t
end

function D.Button(parent, text, w, h)
    local b = DUI().Widgets.Button(parent, text or "", h or 24)
    b:SetWidth(w or 100)
    function b.SetLabel(t) b.text:SetText(t or "") end
    return b
end

-- A switch: t.SetOn(on), t.on, t.onToggle(on) when clicked.
function D.Toggle(parent)
    local t = DUI().Widgets.Switch(parent)
    t:SetScript("OnClick", function(self)
        self.SetOn(not self.on)
        if self.onToggle then self.onToggle(self.on) end
    end)
    return t
end

function D.Input(parent, opts)
    opts = opts or {}
    local e = DUI().Widgets.Input(parent, {
        search = opts.search, hint = opts.hint, onChange = opts.onChange, height = opts.height,
    })
    e:SetWidth(opts.width or 160)
    return e
end

function D.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf.child = child
    sf.barRoom = D.BAR_ROOM
    sf:EnableMouseWheel(true)
    local bar = DUI().Widgets.Scroll(sf, {})
    sf.bar = bar
    function sf.UpdateBar()
        if bar and bar.Update then bar.Update() end
    end
    GP.Skin.Wheel(sf)
    return sf
end

-- An item's icon in a quality outline drawn with DaylightUI's shell.
function D.Icon(parent, px)
    local Style = DUI().Style
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(px, px)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    f.shell = Style.Shell(f, { borderPx = 3, noBevel = true })
    local function edge(r, g, b)
        if not f.shell or not Style.SetShellColors then return end
        if r then
            Style.SetShellColors(f.shell, { r, g, b }, { r * 0.45, g * 0.45, b * 0.45 })
        else
            Style.SetShellColors(f.shell, nil, nil)
        end
    end
    function f.SetItem(icon, quality)
        f.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        Style.CropIcon(f.tex)
        f.tex:SetAlpha(1)
        f.tex:SetDesaturated(false)
        if type(quality) == "number" and quality >= 2 then
            edge(GP.QualityColor(quality))
        else
            edge(nil)
        end
    end
    function f.SetEmpty(texture)
        f.tex:SetTexture(texture or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        f.tex:SetTexCoord(0, 1, 0, 1)
        f.tex:SetAlpha(0.45)
        f.tex:SetDesaturated(true)
        edge(nil)
    end
    return f
end

function D.Highlight(row)
    local W, Style = DUI().Widgets, DUI().Style
    row.hl = W.Round(row, "HIGHLIGHT")
    row.hl:SetAllPoints(row)
    W.Tint(row.hl, { 1, 1, 1 }, 0.06)
    row.sel = W.Round(row, "BACKGROUND", 1)
    row.sel:SetAllPoints(row)
    Style.PaintAccent(row.sel, 0.16)
    row.sel:Hide()
end

function D.HeaderLine(parent)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(1, 1, 1, 1)
    DUI().Style.PaintAccent(t, 0.12)
    return t
end

function D.Ring(parent)
    local W, Style = DUI().Widgets, DUI().Style
    local t = W.Round(parent, "OVERLAY", 6, true)
    Style.PaintAccent(t, 1)
    return t
end

-- A box that pops up over the window: DaylightUI's shell, filled in so
-- the list under it doesn't show through.
function D.Popup(parent)
    local W, Style = DUI().Widgets, DUI().Style
    local f = CreateFrame("Frame", nil, parent)
    Style.Shell(f, {})
    f.fill = W.Round(f, "BACKGROUND", -8)
    f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    W.Tint(f.fill, Style.BACKGROUND or { 0.078, 0.078, 0.09 }, 0.9)
    f:Hide()
    return f
end

function D.Menu(owner, keys, labels, current, onPick)
    DUI().Widgets.OpenMenu(owner, keys, labels, current, onPick)
end

-- ---------------------------------------------------------------------
-- DaylightUI plugin: listed under General > Plugins, with a page of its own
-- ---------------------------------------------------------------------

local PLUGIN = "GearPath"

local function registerPlugin()
    local d = DUI()
    if type(d) ~= "table" or type(d.RegisterPlugin) ~= "function" then return end
    local ok, err = pcall(d.RegisterPlugin, PLUGIN, {
        needs = { 1, 0 },
        color = "66c7ff",
        icon = "Interface\\AddOns\\GearPath\\Media\\plugin.tga",
        short = "Gear",
        blurb = "Upgrades for every slot and where to get them.",
    })
    if not ok then GP.SafeCall(error, err, 0) end
end

-- The plugin's page: what GearPath found, and a button to open it. Built
-- the way DaylightUI builds its own Plugins page (a page of groups with
-- buttons and text lines); left out quietly if that ever changes.
local function registerPage()
    local d = DUI()
    local O = d and d.Options
    if type(O) ~= "table" or type(O.RegisterPage) ~= "function" or not (d.DB and d.DB.GENERAL_DEFAULTS) then return end
    local plugin = d.Plugins and d.Plugins.list and d.Plugins.list[PLUGIN]
    if not plugin or plugin.off then return end
    pcall(O.RegisterPage, {
        id = "gearpath", section = plugin.section, label = "GearPath", scope = "general",
        defaults = d.DB.GENERAL_DEFAULTS, order = 0,
        desc = "Your character sheet, a gear database and an upgrade route in one window. Type /gp to open it.",
        groups = {
            {
                label = "GearPath",
                desc = "Its own settings are in its window, on the Settings tab.",
                items = {
                    { type = "button", label = "Open GearPath", text = "Open",
                      desc = "Opens the GearPath window.",
                      func = function() GP.Toggle("doll") end },
                    { type = "text", label = function()
                          local r = GP.Score and GP.Score.results or {}
                          return string.format("%d upgrades to get now, %d worth chasing.", r.primary or 0, r.secondary or 0)
                      end },
                },
            },
        },
    })
end

registerPlugin()
GP.On("Login", function() GP.SafeCall(registerPage) end)
