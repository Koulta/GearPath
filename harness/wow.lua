-- A small fake of the WoW client, enough to load GearPath, run a scan and
-- build every page of its window. Unknown widget methods are no-ops that
-- get recorded (so they can be reviewed), while calling a missing field on
-- one of GearPath's own tables still errors as it would in game.

local H = { errors = {}, unknown = {}, printed = {}, timers = {}, frames = {}, events = {}, tooltipLines = {} }
_G.H = H

local function noop() end

local function colorArgs(name, r, g, b, a)
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or (a ~= nil and type(a) ~= "number") then
        error(string.format("Usage: %s(r, g, b [, a]) got %s, %s, %s, %s", name, type(r), type(g), type(b), type(a)), 3)
    end
end

-- WoW's xpcall passes extra arguments on (plain Lua 5.1's doesn't).
local xpcall51 = xpcall
function xpcall(fn, handler, ...)
    local n, args = select("#", ...), { ... }
    return xpcall51(function() return fn(unpack(args, 1, n)) end, handler)
end

-- ---------------------------------------------------------------------
-- Widgets
-- ---------------------------------------------------------------------

local Object = {}
Object.__index = function(t, k)
    local m = Object[k]
    if m ~= nil then return m end
    if type(k) == "string" and k:match("^[A-Z]") then
        H.unknown[(rawget(t, "_type") or "?") .. ":" .. k] = true
        return noop
    end
    return nil
end

local function new(kind, parent, name)
    local o = setmetatable({ _type = kind, _parent = parent, _scripts = {}, _shown = true, _points = {},
        _level = parent and (rawget(parent, "_level") or 0) + 1 or 0, _name = name, _children = {} }, Object)
    if parent and rawget(parent, "_children") then table.insert(parent._children, o) end
    if name then _G[name] = o end
    return o
end
H.new = new

function Object:GetObjectType() return self._type end
function Object:IsForbidden() return false end
function Object:GetName() return self._name end
function Object:GetParent() return self._parent end
function Object:SetParent(p) self._parent = p end
function Object:Show()
    local was = self:IsVisible()
    self._shown = true
    if not was and self:IsVisible() then self:_fireShow() end
end
function Object:_fireShow()
    if self._scripts.OnShow then self:_run("OnShow") end
    for _, c in ipairs(self._children) do if c._shown then c:_fireShow() end end
end
function Object:Hide()
    local was = self:IsVisible()
    self._shown = false
    if was and self._scripts.OnHide then self:_run("OnHide") end
end
function Object:SetShown(on) if on then self:Show() else self:Hide() end end
function Object:IsShown() return self._shown end
function Object:IsVisible()
    local o = self
    while o do
        if not o._shown then return false end
        o = o._parent
    end
    return true
end
function Object:SetSize(w, h) self._w, self._h = w, h end
function Object:SetWidth(w) self._w = w end
function Object:SetHeight(h) self._h = h end
function Object:GetWidth()
    if self._w then return self._w end
    return self._parent and self._parent:GetWidth() or 1920
end
function Object:GetHeight()
    if self._h then return self._h end
    return self._parent and self._parent:GetHeight() or 1080
end
function Object:GetSize() return self:GetWidth(), self:GetHeight() end
function Object:SetPoint(...)
    local p = select(1, ...)
    if type(p) ~= "string" then error("SetPoint: bad point " .. tostring(p), 2) end
    table.insert(self._points, { ... })
end
function Object:GetPoint(i) local p = self._points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
function Object:ClearAllPoints() self._points = {} end
function Object:SetAllPoints() end
function Object:GetLeft() return 100 end
function Object:GetTop() return 800 end
function Object:GetBottom() return 200 end
function Object:GetRight() return 1000 end
function Object:GetCenter() return 500, 500 end
function Object:GetEffectiveScale() return 1 end
function Object:GetScale() return self._scale or 1 end
function Object:SetScale(s) self._scale = s end
function Object:SetAlpha(a) self._alpha = a end
function Object:GetAlpha() return self._alpha or 1 end
function Object:GetFrameLevel() return self._level end
function Object:SetFrameLevel(l) self._level = l end
function Object:GetFrameStrata() return "MEDIUM" end
function Object:IsMouseOver() return false end
function Object:GetChildren() return unpack(self._children) end

-- Scripts
function Object:SetScript(name, fn) self._scripts[name] = fn end
function Object:GetScript(name) return self._scripts[name] end
function Object:HookScript(name, fn)
    local old = self._scripts[name]
    if old then
        self._scripts[name] = function(...) old(...); fn(...) end
    else
        self._scripts[name] = fn
    end
end
function Object:HasScript() return true end
function Object:EnableGamePadButton(on) self._pad = on and true or false end
function Object:IsGamePadButtonEnabled() return self._pad == true end
function Object:_run(name, ...)
    local fn = self._scripts[name]
    if fn then return fn(self, ...) end
end
function Object:Click(button)
    if self._type == "CheckButton" then self._checked = not self._checked end
    if self._scripts.OnClick then self:_run("OnClick", button or "LeftButton", false) end
    if self._scripts.PostClick then self:_run("PostClick", button or "LeftButton") end
end
function Object:RegisterEvent(e)
    H.events[e] = H.events[e] or {}
    H.events[e][self] = true
end
function Object:UnregisterEvent(e) if H.events[e] then H.events[e][self] = nil end end
function Object:RegisterForClicks() end
function Object:RegisterForDrag() end
function Object:EnableMouse() end
function Object:EnableMouseWheel() end
function Object:SetID(i) self._id = i end
function Object:GetID() return self._id or 0 end
function Object:SetEnabled(on) self._enabled = on end
function Object:IsEnabled() return self._enabled ~= false end

-- Regions
function Object:CreateTexture(name, layer) local t = new("Texture", self, name); t._layer = layer; return t end
function Object:CreateMaskTexture() return new("MaskTexture", self) end
function Object:CreateFontString(name, layer, template)
    local fs = new("FontString", self, name)
    fs._template = template
    return fs
end
function Object:SetText(t)
    self._text = t
    if self._type == "EditBox" and self._scripts.OnTextChanged then self:_run("OnTextChanged", false) end
end
function Object:GetText() return self._text end
function Object:SetFormattedText(f, ...) self._text = string.format(f, ...) end
function Object:GetStringWidth() return #(tostring(self._text or "")) * 6 end
function Object:GetFontString()
    self._fs = self._fs or new("FontString", self)
    return self._fs
end
function Object:SetTexture(t) self._tex = t; return true end
function Object:GetTexture() return self._tex end
function Object:SetAtlas(a) self._atlas = a end
function Object:SetColorTexture(r, g, b, a) colorArgs("SetColorTexture", r, g, b, a); self._color = { r, g, b, a } end
function Object:SetVertexColor(r, g, b, a) colorArgs("SetVertexColor", r, g, b, a); self._vc = { r, g, b, a } end
function Object:SetTextColor(r, g, b, a)
    colorArgs("SetTextColor", r, g, b, a)
    self._tc = { r, g, b, a }
end
function Object:GetTextColor() local c = self._tc or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end

-- Scroll frames
function Object:SetScrollChild(c) self._child = c; c._parent = self end
function Object:GetScrollChild() return self._child end
function Object:SetVerticalScroll(v)
    self._vscroll = v
    if self._scripts.OnVerticalScroll then self:_run("OnVerticalScroll", v) end
end
function Object:GetVerticalScroll() return self._vscroll or 0 end
function Object:GetVerticalScrollRange()
    local c = self._child
    return math.max(0, (c and c:GetHeight() or 0) - self:GetHeight())
end

-- Edit boxes, check buttons
function Object:ClearFocus() if self._scripts.OnEditFocusLost then self:_run("OnEditFocusLost") end end
function Object:SetFocus() end
function Object:SetChecked(on) self._checked = on end
function Object:GetChecked() return self._checked end
function Object:SetCursorPosition() end

-- Models
function Object:SetUnit(u) self._unit = u end
function Object:TryOn(link) self._tried = link end
function Object:GetFacing() return self._facing or 0 end
function Object:SetFacing(f) self._facing = f end

-- Tooltip
function Object:SetOwner() self._lines = {} end
function Object:AddLine(t) self._lines = self._lines or {}; table.insert(self._lines, tostring(t)) end
function Object:AddDoubleLine(a, b) self._lines = self._lines or {}; table.insert(self._lines, tostring(a) .. " || " .. tostring(b)) end

-- ---------------------------------------------------------------------
-- Templates
-- ---------------------------------------------------------------------

local TEMPLATES = {}
TEMPLATES.ButtonFrameTemplate = function(f)
    f.Inset = new("Frame", f)
    f.CloseButton = new("Button", f)
    f.SetTitle = function(self, t) self._title = t end
    f.SetPortraitToUnit = function() end
end
TEMPLATES.InsetFrameTemplate = function() end
TEMPLATES.ScrollFrameTemplate = function(f)
    f.ScrollBar = new("EventFrame", f)
    f.ScrollBar.SetHideIfUnscrollable = function() end
    f.ScrollBar.Update = function() end
end
TEMPLATES.PanelTabButtonTemplate = function(b, parent)
    rawset(parent, "Tabs", rawget(parent, "Tabs") or {})
    table.insert(parent.Tabs, b)
end
TEMPLATES.SearchBoxTemplate = function(e) e.Instructions = new("FontString", e) end
TEMPLATES.InputBoxTemplate = function() end
TEMPLATES.UIPanelButtonTemplate = function() end
TEMPLATES.UICheckButtonTemplate = function() end
TEMPLATES.TooltipBackdropTemplate = function() end

function CreateFrame(kind, name, parent, template)
    local f = new(kind, parent or UIParent, name)
    if kind ~= "Frame" or template then end
    if template then
        for t in template:gmatch("[^,%s]+") do
            local fn = TEMPLATES[t]
            if not fn then error("CreateFrame: unknown template " .. t, 2) end
            fn(f, parent)
        end
    end
    table.insert(H.frames, f)
    return f
end

UIParent = new("Frame", nil, "UIParent")
UIParent._w, UIParent._h = 1920, 1080
Minimap = new("Frame", UIParent, "Minimap")
Minimap._w, Minimap._h = 140, 140
GameTooltip = new("GameTooltip", UIParent, "GameTooltip")
ItemRefTooltip = new("GameTooltip", UIParent, "ItemRefTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(H.printed, msg); if H.echo then print("  [chat] " .. msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end end }
UISpecialFrames = {}
SlashCmdList = {}

-- ---------------------------------------------------------------------
-- Time, events, errors
-- ---------------------------------------------------------------------

H.now = 1000
H.wall = 1790000000          -- time(): seconds since 1970 (October 2026)
function GetTime() return H.now end
function time() return H.wall end
function debugprofilestop() return os.clock() * 1000 end
function debugstack() return "(stack)" end
function geterrorhandler()
    return function(err)
        table.insert(H.errors, tostring(err))
        print("  ERROR: " .. tostring(err):match("^[^\n]*"))
    end
end
function issecretvalue() return false end
-- Spells (weapon skills, armor, Dual Wield): all known unless a test lists them in H.unknownSpells.
function IsPlayerSpell(id) return not (H.unknownSpells and H.unknownSpells[id]) end
function InCombatLockdown() return H.combat == true end
function strsplit(sep, s)
    local out = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%-", "%%-")) do out[#out + 1] = piece end
    return unpack(out)
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert

C_Timer = {
    After = function(t, fn) table.insert(H.timers, { at = H.now + t, fn = fn }) end,
    NewTicker = function(t, fn) local tk = { every = t, fn = fn, at = H.now + t, ticker = true }; table.insert(H.timers, tk); return { Cancel = function() tk.dead = true end } end,
}

function H.Fire(event, ...)
    for f in pairs(H.events[event] or {}) do
        local fn = f._scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
end

-- Moves time on by dt: timers run, every visible frame's OnUpdate runs.
function H.Tick(dt)
    H.now = H.now + (dt or 0.1)
    local due = {}
    for i = #H.timers, 1, -1 do
        local t = H.timers[i]
        if t.dead then table.remove(H.timers, i)
        elseif t.at <= H.now then
            if t.ticker then t.at = H.now + t.every; due[#due + 1] = t.fn
            else table.remove(H.timers, i); due[#due + 1] = t.fn end
        end
    end
    for _, fn in ipairs(due) do
        local ok, err = pcall(fn)
        if not ok then table.insert(H.errors, err); print("  ERROR (timer): " .. tostring(err)) end
    end
    for _, f in ipairs(H.frames) do
        local fn = f._scripts.OnUpdate
        if fn and f:IsVisible() then
            local ok, err = pcall(fn, f, dt or 0.1)
            if not ok then table.insert(H.errors, err); print("  ERROR (OnUpdate): " .. tostring(err)) end
        end
    end
end

-- ---------------------------------------------------------------------
-- Misc client API
-- ---------------------------------------------------------------------

C_AddOns = { GetAddOnMetadata = function(_, field) if field == "Version" then return "0.1.0" end end }
SOUNDKIT = { IG_CHARACTER_INFO_TAB = 1, IG_CHARACTER_INFO_OPEN = 2, IG_CHARACTER_INFO_CLOSE = 3,
    IG_MAINMENU_OPTION_CHECKBOX_ON = 4, IG_MAINMENU_OPTION_CHECKBOX_OFF = 5 }
function PlaySound() end
function PanelTemplates_SetNumTabs(f, n) f.numTabs = n end
function PanelTemplates_SetTab(f, i) f.selectedTab = i end
function ButtonFrameTemplate_HideButtonBar() end
function IsModifiedClick() return H.modified == true end
function HandleModifiedItemClick(link) H.lastModified = link; return true end
function DressUpItemLink(link) H.dressedUp = link end
function GetCursorPosition() return 500, 500 end
function ReloadUI() end
function IsInInstance() return false, "none" end
function GetInstanceInfo() return "World" end
Enum = { TooltipDataType = { Item = 0, Unit = 2 } }
ITEM_CLASSES_ALLOWED = "Classes: %s"
ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:"
ITEM_UNIQUE = "Unique"
NUM_BAG_SLOTS = 4
INVTYPE_HEAD = "Head"

MenuUtil = {
    CreateContextMenu = function(owner, gen)
        local root = { radios = {} }
        function root:CreateRadio(text, isSel, setSel) table.insert(self.radios, { text = text, isSel = isSel, setSel = setSel }) end
        gen(owner, root)
        H.lastMenu = root
    end,
}

TooltipDataProcessor = {
    calls = {},
    AddTooltipPostCall = function(kind, fn)
        TooltipDataProcessor.calls[kind] = TooltipDataProcessor.calls[kind] or {}
        table.insert(TooltipDataProcessor.calls[kind], fn)
    end,
}
local function runTooltip(tt, id)
    for _, fn in ipairs(TooltipDataProcessor.calls[0] or {}) do fn(tt, { id = id }) end
end
-- A unit's tooltip (a mouseover, a target): the game's lines, then the post calls.
function H.ShowUnit(tt, unit)
    tt._lines = { "[unit " .. tostring(UnitName(unit)) .. "]" }
    tt._ttunit = unit
    for _, fn in ipairs(TooltipDataProcessor.calls[2] or {}) do fn(tt, { guid = UnitGUID(unit) }) end
end
function Object:GetUnit() return self._ttunit and UnitName(self._ttunit), self._ttunit end
function Object:SetHyperlink(link)
    self._lines = { "[item " .. link .. "]" }
    runTooltip(self, tonumber(link:match("item:(%d+)")))
end
function Object:SetTrainerService(i) self._lines = { "[recipe " .. i .. "]" } end
-- hooksecurefunc(table, name, fn) or hooksecurefunc(name, fn): fn runs after.
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then t, name, fn = _G, t, name end
    local orig = t[name]
    t[name] = function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end
end
function Object:SetItemByID(id) self._lines = { "[item " .. id .. "]" }; runTooltip(self, id) end
function Object:SetInventoryItem(_, slot) self._lines = { "[slot " .. slot .. "]" } end
function Object:GetItem() return nil, nil end

-- Addon messages: what's sent is kept; channels by name.
H.sent = {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) H.prefix = p; return true end,
    SendAddonMessage = function(prefix, msg, chatType, target)
        assert(#msg <= 255, "addon message too long: " .. #msg)
        table.insert(H.sent, { prefix = prefix, msg = msg, chatType = chatType, target = target })
        return 0
    end,
}
local channels = {}
function JoinTemporaryChannel(name) channels[name] = channels[name] or 5 end
function GetChannelName(name) return channels[name] or 0, name end
function LeaveChannelByName(name) channels[name] = nil end
function IsInGuild() return true end
function IsInGroup() return false end
function IsInRaid() return false end
function UnitFullName() return "Koulta", "Forever" end
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.16.0", "60123", "Oct 1 2026", 16001 end

C_Texture = { GetAtlasInfo = function(a) if a == "Waypoint-MapPin-Untracked" or a == "bags-greenarrow" then return {} end end }

return H
