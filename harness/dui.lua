-- A strict stand-in for DaylightUI: only the functions GearPath is known to
-- call exist (each checked against DaylightUI's source); touching anything
-- else errors, so a call to something DaylightUI doesn't have shows up.

local H = _G.H
local new = H.new

local function strict(name, t)
    return setmetatable(t, { __index = function(_, k) error("DaylightUI." .. name .. "." .. tostring(k) .. " doesn't exist", 2) end })
end

local Style = strict("Style", {
    SIZE = { tiny = 10, small = 12, body = 13, head = 15, title = 18 },
    INK = { TITLE = { 1, 1, 1 }, VALUE = { 1, 1, 1 }, TEXT = { 0.95, 0.93, 0.9 }, LABEL = { 0.76, 0.71, 0.62 },
        OFF = { 0.55, 0.51, 0.45 }, GOOD = { 0.55, 0.85, 0.55 }, WARN = { 0.95, 0.72, 0.32 }, BAD = { 0.93, 0.36, 0.3 } },
    BAND = { 0.1, 0.09, 0.065 },
    BACKGROUND = { 0.078, 0.078, 0.09 },
})
function Style.Accent() return 0.72, 0.7, 0.66 end
function Style.Text(parent, size, justify)
    assert(type(size) == "number", "Style.Text size must be a number")
    return parent:CreateFontString(nil, "OVERLAY")
end
function Style.InkText(fs, role, a)
    if role ~= "pop" then assert(Style.INK[role], "unknown ink role " .. tostring(role)) end
    fs:SetTextColor(1, 1, 1, a or 1)
end
function Style.Separator(parent) return parent:CreateTexture(nil, "ARTWORK") end
function Style.Shell(frame, opts) local s = new("Frame", frame); s.opts = opts or {}; return s end
function Style.SetShellColors(s, border, band) s._border = border end
function Style.CropIcon(tex) end
function Style.PaintAccent(tex, alpha) tex:SetVertexColor(1, 1, 1, alpha) end

local W = strict("Widgets", {})
function W.Round(parent, layer, sublevel, outline) return parent:CreateTexture(nil, layer) end
function W.Tint(tex, c, alpha) tex:SetVertexColor(c[1], c[2], c[3], alpha) end
function W.Button(parent, text, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(height or 24)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetText(text)
    return b
end
function W.Switch(parent)
    local b = CreateFrame("Button", nil, parent)
    function b.SetOn(on) b.on = on end
    b:SetScript("PostClick", function() end)
    return b
end
function W.Input(parent, opts)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetScript("OnTextChanged", function(self, user) if opts.onChange then opts.onChange(self:GetText() or "", user) end end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return e
end
function W.Scroll(sf, opts)
    local bar = new("Frame", sf:GetParent())
    function bar.Update() end
    return bar
end
function W.Close(parent, onClick) local b = CreateFrame("Button", nil, parent); b:SetScript("OnClick", onClick); return b end
function W.OpenMenu(owner, keys, values, current, onPick)
    for _, k in ipairs(keys) do assert(values[k], "menu label missing for " .. tostring(k)) end
    H.lastMenu = { keys = keys, values = values, onPick = onPick }
end

local Win = strict("Win", {})
function Win.New(spec)
    local f = CreateFrame("Frame", spec.name, UIParent)
    f.spec = spec
    f:SetSize(spec.w or 400, spec.h or 540)
    f:Hide()
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.sub = f:CreateFontString(nil, "OVERLAY")
    f.close = W.Close(f, function() Win.Close(f) end)
    f.portrait = f:CreateTexture()
    f.host = CreateFrame("Frame", nil, f)
    f.pages, f.defs = {}, {}
    return f
end
function Win.Drag(f, opts) assert(type(opts) == "table") end
function Win.Grip(f, opts)
    assert(type(opts) == "table", "Grip opts")
    assert(type(opts.min) == "table" or type(opts.min) == "function", "Grip min")
    for _, k in ipairs({ "save", "set", "reset", "size", "place", "resized" }) do
        assert(opts[k] == nil or type(opts[k]) == "function", "Grip " .. k)
    end
    local g = CreateFrame("Button", nil, f)
    f.grip, f.gripOpts = g, opts
    return g
end
function Win.PlaceTop(f, x, y) end
function Win.SetTitle(f, title, color, sub) f.title:SetText(title); if f.sub then f.sub:SetText(sub or "") end end
function Win.Tabs(f, tabs, onPick)
    f.tabs = {}
    for _, t in ipairs(tabs) do
        local b = CreateFrame("Button", nil, f)
        b.id = t.id
        b:SetScript("OnClick", function() if f.tab ~= b.id then Win.PickTab(f, b.id); onPick(b.id) end end)
        table.insert(f.tabs, b)
    end
end
function Win.PickTab(f, id) f.tab = id end
function Win.SetPortrait(f, unit) end
function Win.Open(f) f:Show() end
function Win.Close(f, done) f:Hide(); if done then done() end end
function Win.IsOpen(f) return f:IsShown() end
function Win.Scale(own) return own end

local plugins = {}
DaylightUI = strict("root", {
    Style = Style, Widgets = W, Win = Win,
    DB = strict("DB", { GENERAL_DEFAULTS = {} }),
    Plugins = strict("Plugins", { list = plugins }),
    Options = strict("Options", {}),
})
function DaylightUI.RegisterPlugin(name, spec)
    assert(type(name) == "string" and type(spec) == "table")
    plugins[name] = { name = name, section = "plugin:" .. name }
    H.plugin = spec
    return plugins[name]
end
function DaylightUI.Options.RegisterPage(page)
    assert(page.id and page.section and page.groups)
    H.pluginPage = page
end
