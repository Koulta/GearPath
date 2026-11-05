-- Fake EllesmereUI for the offline tests, written from its public docs
-- (SKINNING_API.md, apiVersion 3, and the bag overlay hook in EUI_Bags_Slots.lua's
-- comments). None of EllesmereUI's code is copied: this only records what
-- GearPath asks of it, so the tests can check every frame got skinned.
--   H.eui = { enabled = true, style = "eui", accent = {r,g,b}, charSheetText = true }
-- Load after wow.lua and before GearPath when a run is "ellesmere".

local H = ... or {}
H.eui = H.eui or { enabled = true, style = "eui", accent = { 0.05, 0.82, 0.62 }, charSheetText = true }
H.euiCalls = {}      -- { {prim, frame, opts}, ... } in call order
H.euiSkinned = {}    -- frame -> { prim = true, ... }
H.euiLooks = {}      -- OnLooksChanged callbacks

local function record(prim)
    return function(frame, opts, ...)
        assert(frame ~= nil, "EUI fake: S." .. prim .. " called with nil frame")
        local seen = H.euiSkinned[frame] or {}
        if seen[prim] then return end          -- primitives are idempotent
        seen[prim] = true
        H.euiSkinned[frame] = seen
        H.euiCalls[#H.euiCalls + 1] = { prim = prim, frame = frame, opts = opts }
    end
end

local S = { apiVersion = 3 }
for _, prim in ipairs({ "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
    "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "CloseButton", "PageButton",
    "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill" }) do
    S[prim] = record(prim)
end
function S.SetTabSelection(tab, selected)
    H.euiTabSel = H.euiTabSel or {}
    H.euiTabSel[tab] = selected
end
function S.IsEnabled() return H.eui.enabled end
function S.GetStyle() return H.eui.style end
function S.GetAccentColor() return H.eui.accent[1], H.eui.accent[2], H.eui.accent[3] end
function S.GetPanelColor() return 0.05, 0.05, 0.05, 0.92 end
function S.GetFont() return "Fonts\\FRIZQT__.TTF", "" end
function S.OnLooksChanged(fn) H.euiLooks[#H.euiLooks + 1] = fn end

EllesmereUI = { skins = {} }
H.euiS = S

-- Runs at PLAYER_LOGIN, or at once when registered later (as the docs say),
-- only while skinning is on for that addon; errors are caught and reported.
function EllesmereUI.RegisterSkin(name, fn)
    if EllesmereUI.skins[name] then return end           -- first registration wins
    EllesmereUI.skins[name] = fn
    if H.loggedIn and H.eui.enabled then
        local ok, err = pcall(fn, S)
        if not ok then H.euiErrors = (H.euiErrors or 0) + 1; H.euiLastError = err end
    end
end

-- Called by the harness's login step.
function H.EUILogin()
    if not H.eui.enabled then return end
    for _, fn in pairs(EllesmereUI.skins) do
        local ok, err = pcall(fn, S)
        if not ok then H.euiErrors = (H.euiErrors or 0) + 1; H.euiLastError = err end
    end
end

-- Live recolor: the tests change H.eui.accent and call this.
function H.EUILooksChanged()
    for _, fn in ipairs(H.euiLooks) do pcall(fn) end
end

-- Bags: third-party item overlays. updateFn(btn, data), data = { bag, slot, info, itemLink }.
EUI_Bags = { itemOverlayIcons = {} }
function EUI_Bags.RegisterItemOverlayIcon(name, fn) EUI_Bags.itemOverlayIcons[name] = fn end
function EUI_Bags.UnregisterItemOverlayIcon(name) EUI_Bags.itemOverlayIcons[name] = nil end
-- The harness paints a fake bag slot: returns the button so tests can look at what was drawn.
function H.EUIPaintSlot(bag, slot, itemLink)
    local btn = CreateFrame("Button")
    btn._textOverlay = CreateFrame("Frame", nil, btn)
    local data = { bag = bag, slot = slot, info = itemLink and { hyperlink = itemLink } or nil, itemLink = itemLink }
    for _, fn in pairs(EUI_Bags.itemOverlayIcons) do pcall(fn, btn, data) end
    return btn
end

-- Whether EllesmereUI is drawing item levels on the Character sheet (GearPath hides its own then).
-- The real check goes through EllesmereUI's saved settings; the exact key is confirmed in game.
H.EUICharSheetText = function() return H.eui.charSheetText end
-- EllesmereUI's saved settings and its Blizzard-skin module being loaded.
EllesmereUIDB = { themedCharacterSheet = true }
C_AddOns = C_AddOns or {}
local wasLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name)
    if name == "EllesmereUIBlizzardSkin" or name == "EllesmereUI" or name == "EllesmereUIBags" then return true end
    return wasLoaded and wasLoaded(name) or false
end

return H
