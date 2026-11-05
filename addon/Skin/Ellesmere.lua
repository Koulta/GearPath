-- The EllesmereUI look: GearPath built from the game's own pieces (the native
-- look), then handed to EllesmereUI's published skinning API
-- (EllesmereUI.RegisterSkin, SKINNING_API.md) to paint in the player's theme.
-- Only those public calls are used: none of EllesmereUI's code, art or fonts
-- is copied, and EllesmereUI keeps the frames in step with its own theme and
-- accent changes by itself.
--
-- If the player turned EllesmereUI's skinning off for GearPath, its callback
-- never runs and GearPath falls back to the game's own look.
--
-- Also here, for EllesmereUI players whatever look they pick:
--   * its themed Character sheet already draws item levels on the slots, so
--     GearPath doesn't draw a second set (Doll.GameSlotLevel asks
--     Ellesmere.SheetHasLevels);
--   * its bags take an icon from other addons: a green arrow on gear in
--     your bags that's an upgrade you can wear now.

local _, GP = ...

local N = GP.Skin.looks.native
local E = setmetatable({ label = "EllesmereUI" }, { __index = N })
GP.Skin.Register("ellesmere", E)
GP.Ellesmere = E

local function EUI() return rawget(_G, "EllesmereUI") end

-- The skin handle EllesmereUI gives us at login (nil: not installed, or
-- skinning is off for GearPath).
E.S = nil

local eui = EUI()
if type(eui) == "table" and type(eui.RegisterSkin) == "function" then
    pcall(eui.RegisterSkin, "GearPath", function(S)
        E.S = S
        -- A window built before this ran (opened very early) gets painted now.
        if E.window then E.PaintWindow(E.window) end
    end)
end

local function S()
    local s = E.S
    if s and (not s.IsEnabled or s.IsEnabled()) then return s end
    return nil
end

-- Each primitive is called only if this EllesmereUI has it, and never lets
-- an error in it stop GearPath.
local function paint(prim, ...)
    local s = S()
    local f = s and s[prim]
    if type(f) ~= "function" then return end
    pcall(f, ...)
end

function E.Available()
    return S() ~= nil
end

function E.Accent()
    local s = S()
    if s and s.GetAccentColor then
        local ok, r, g, b = pcall(s.GetAccentColor)
        if ok and type(r) == "number" then return r, g, b end
    end
    return N.Accent()
end

function E.InkColor(role)
    if role == "pop" then return E.Accent() end
    return N.InkColor(role)
end

-- ---------------------------------------------------------------------
-- The window and its pieces: the native ones, then painted
-- ---------------------------------------------------------------------

function E.PaintWindow(f)
    paint("Shell", f)
    if f.CloseButton then paint("CloseButton", f.CloseButton) end
    if f.Inset then paint("Inset", f.Inset) end
    if f.sub then paint("Font", f.sub) end
    for _, tab in ipairs(f.gpTabs or {}) do paint("Tab", tab) end
end

function E.Window(spec)
    local f = N.Window(spec)
    E.window = f
    E.PaintWindow(f)
    return f
end

function E.Tabs(f, tabs, onPick)
    N.Tabs(f, tabs, onPick)
    f.gpTabs = {}
    for i = 1, #tabs do
        local tab = rawget(_G, f:GetName() .. "Tab" .. i)
        if tab then
            f.gpTabs[#f.gpTabs + 1] = tab
            paint("Tab", tab)
        end
    end
end

function E.Panel(parent)
    local p = N.Panel(parent)
    paint("Panel", p, { inset = true })
    return p
end

function E.Text(parent, size, role, justify)
    local fs = N.Text(parent, size, role, justify)
    paint("Font", fs)
    return fs
end

function E.Button(parent, text, w, h)
    local b = N.Button(parent, text, w, h)
    paint("Button", b)
    paint("StateButtonLabel", b)
    return b
end

function E.Toggle(parent)
    local t = N.Toggle(parent)
    paint("Checkbox", t)
    return t
end

function E.Input(parent, opts)
    local e = N.Input(parent, opts)
    paint("EditBox", e)
    return e
end

function E.Scroll(parent)
    local sf = N.Scroll(parent)
    if sf.ScrollBar then paint("ScrollBar", sf.ScrollBar) end
    return sf
end

function E.Popup(parent)
    local p = N.Popup(parent)
    paint("Panel", p)
    return p
end

-- ---------------------------------------------------------------------
-- The game's Character sheet
-- ---------------------------------------------------------------------

-- Whether EllesmereUI's Character sheet is on and drawing item levels on the
-- slots. Read from its saved settings (the switch it shows as the Character
-- Sheet card's On/Off); anything unexpected counts as "no", so GearPath
-- keeps drawing its own rather than leaving the slots bare.
function E.SheetHasLevels()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
    if type(isLoaded) ~= "function" then return false end
    local ok, loaded = pcall(isLoaded, "EllesmereUIBlizzardSkin")
    if not (ok and GP.Plain(loaded)) then return false end
    local db = rawget(_G, "EllesmereUIDB")
    if type(db) ~= "table" then return true end      -- its defaults: the sheet is on
    return db.themedCharacterSheet ~= false
end

-- ---------------------------------------------------------------------
-- EllesmereUI's bags: a green arrow on an upgrade you can wear now
-- ---------------------------------------------------------------------

-- Whether a bag item is an upgrade you can put on right now.
function E.BagUpgrade(link)
    if type(link) ~= "string" then return false end
    if not (GP.Items and GP.Score and GP.player) then return false end
    local rec = GP.Items.FromLink(link)
    if not rec or not GP.Score.CanWear(rec, GP.player.level) then return false end
    local slot = GP.Score.Gain(rec)
    if not slot then return false end
    if GP.Training and GP.Training.Need(rec, slot) then return false end
    return true
end

local arrows = {}        -- bag button -> our arrow (kept off the button itself)
E.arrows = arrows

local function paintSlot(btn, data)
    local parent = btn and btn._textOverlay
    if not parent then return end
    local up = data and E.BagUpgrade(data.itemLink)
    local a = arrows[btn]
    if not up then
        if a then a:Hide() end
        return
    end
    if not a then
        a = GP.Skin.UpgradeArrow(parent, 14)
        -- Top right: EllesmereUI keeps the item level top left, the count
        -- bottom right and Bind on Equip bottom left (the arrow sat on the
        -- item level, Nov 5).
        a:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
        arrows[btn] = a
    end
    a.Paint("primary")
    a:Show()
end

GP.On("Login", function()
    local bags = rawget(_G, "EUI_Bags")
    if type(bags) == "table" and type(bags.RegisterItemOverlayIcon) == "function" then
        pcall(bags.RegisterItemOverlayIcon, "GearPath", paintSlot)
    end
end)
