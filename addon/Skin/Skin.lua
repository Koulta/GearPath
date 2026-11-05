-- Skin: the window is written once against a small set of pieces (a window,
-- tabs, text, buttons, switches, inputs, a scroll area, item icons, row
-- highlights, a menu) and each look builds those pieces its own way:
--
--   native    the game's own templates (ButtonFrameTemplate, the tabs, the
--             search box, the minimal scroll bar), so it looks like the
--             character sheet next to it
--   daylight  DaylightUI's window kit, styles and widgets, called through
--             its public functions (DaylightUI must be installed; nothing
--             of it is copied here)
--   ellesmere the native pieces, painted by EllesmereUI's published
--             skinning API (EllesmereUI must be installed, with its skinning
--             on for GearPath)
--
-- "auto" picks DaylightUI when it's loaded, else EllesmereUI. The look is chosen when the
-- window is first opened; switching takes a /reload.

local _, GP = ...

local Skin = { looks = {}, order = {} }
GP.Skin = Skin

-- Text sizes every look knows: tiny, small, body, head, title.
-- Text roles (colors by meaning): TITLE, VALUE, TEXT, LABEL, OFF, GOOD,
-- WARN, BAD, pop (the look's accent).
Skin.SIZES = { "tiny", "small", "body", "head", "title" }

function Skin.Register(name, look)
    look.name = name
    Skin.looks[name] = look
    Skin.order[#Skin.order + 1] = name
end

function Skin.Available(name)
    local look = Skin.looks[name]
    if not look then return false end
    if look.Available then return look.Available() == true end
    return true
end

-- Which look a setting means right now.
function Skin.Resolve(setting)
    if setting == "native" then return "native" end
    if setting == "daylight" or setting == "ellesmere" then
        return Skin.Available(setting) and setting or "native"
    end
    if Skin.Available("daylight") then return "daylight" end
    if Skin.Available("ellesmere") then return "ellesmere" end
    return "native"
end

-- The look the window is built with (once per session).
function Skin.Pick()
    if Skin.current then return Skin.current end
    local setting = GP.Setting("look") or "auto"
    local name = Skin.Resolve(setting)
    if setting == "daylight" and name ~= "daylight" then
        GP.Print("DaylightUI isn't loaded, so GearPath uses the game's own look.")
    elseif setting == "ellesmere" and name ~= "ellesmere" then
        GP.Print("EllesmereUI isn't loaded (or its skinning is off for GearPath), so GearPath uses the game's own look.")
    end
    Skin.current = Skin.looks[name] or Skin.looks.native
    return Skin.current
end

-- What the look setting will be after a reload, for the settings page.
function Skin.PendingLabel()
    local name = Skin.Resolve(GP.Setting("look") or "auto")
    local look = Skin.looks[name]
    return look and look.label or name
end

-- ---------------------------------------------------------------------
-- Pieces both looks share (game art only, never DaylightUI's)
-- ---------------------------------------------------------------------

-- Whether the client has an atlas (SetAtlas itself says nothing).
function Skin.HasAtlas(atlas)
    if not (atlas and C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
    return ok and info ~= nil
end

-- A texture that takes an atlas when the client has it, else a file.
function Skin.SetArt(tex, atlas, file, coords)
    if atlas and tex.SetAtlas and Skin.HasAtlas(atlas) then
        tex:SetAtlas(atlas)
        return true
    end
    tex:SetTexture(file)
    if coords then tex:SetTexCoord(unpack(coords)) end
    return false
end

-- The mouse wheel for a scroll area, the same in every look: each notch
-- moves a fifth of what's in view (at least two rows' worth), so long lists
-- don't take dozens of notches to get through.
function Skin.Wheel(sf, step)
    if not (sf and sf.SetScript) then return end
    if sf.EnableMouseWheel then sf:EnableMouseWheel(true) end
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
        if not max or max <= 0 then return end
        local view = self:GetHeight() or 0
        local s = step or math.max(48, math.floor(view * 0.2))
        local y = (self:GetVerticalScroll() or 0) - (delta or 0) * s
        self:SetVerticalScroll(math.max(0, math.min(max, y)))
        if self.UpdateBar then self.UpdateBar() end
    end)
end

-- A small square button with a picture: the waypoint pin, the try-on reset.
function Skin.IconButton(parent, size, atlas, file, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    Skin.SetArt(b.icon, atlas, file)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    Skin.SetArt(b.hl, atlas, file)
    b.hl:SetBlendMode("ADD")
    b.hl:SetAlpha(0.5)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return b
end

-- The map pin used for "show me where".
function Skin.PinButton(parent, size)
    return Skin.IconButton(parent, size or 18, "Waypoint-MapPin-Untracked",
        "Interface\\Minimap\\Tracking\\None", "Show on the map")
end

-- The upgrade arrow on a slot (green: best now; gold: worth chasing).
function Skin.UpgradeArrow(parent, size)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetSize(size or 14, size or 14)
    if not Skin.SetArt(t, "bags-greenarrow", "Interface\\Buttons\\UI-MicroStream-Green") then
        t:SetTexCoord(0, 1, 1, 0)   -- the old art points down
    end
    function t.Paint(tier)
        if tier == "primary" then
            t:SetDesaturated(false)
            t:SetVertexColor(1, 1, 1)
        else
            t:SetDesaturated(true)
            t:SetVertexColor(1, 0.78, 0.25)
        end
    end
    return t
end

-- A small down arrow for pickers.
function Skin.DownArrow(parent, size)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(size or 14, size or 14)
    Skin.SetArt(t, nil, "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up", { 0.25, 0.75, 0.25, 0.75 })
    return t
end
