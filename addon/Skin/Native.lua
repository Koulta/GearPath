-- The native look: WoW: Forever's own templates, the same ones the
-- character sheet, the quest log and the bags are made of.

local _, GP = ...

local N = { label = "Native Forever UI" }
GP.Skin.Register("native", N)

function N.Available() return true end

N.BAR_ROOM = 18       -- room a scroll area leaves on its right for the bar
N.ROW_HL = { 1, 1, 1, 0.08 }

local FONTS = {
    tiny = "GameFontHighlightSmall",
    small = "GameFontHighlightSmall",
    body = "GameFontHighlight",
    head = "GameFontNormal",
    title = "GameFontNormalLarge",
}

local INK = {
    TITLE = { 1, 0.82, 0 },
    VALUE = { 1, 1, 1 },
    TEXT = { 0.92, 0.92, 0.92 },
    LABEL = { 0.68, 0.68, 0.68 },
    OFF = { 0.5, 0.5, 0.5 },
    GOOD = { 0.25, 1, 0.25 },
    WARN = { 1, 0.65, 0.1 },
    BAD = { 1, 0.27, 0.27 },
    pop = { 1, 0.82, 0 },
}
N.INK = INK

local function sound(kit)
    if PlaySound and SOUNDKIT and SOUNDKIT[kit] then pcall(PlaySound, SOUNDKIT[kit]) end
end

function N.Accent() return INK.pop[1], INK.pop[2], INK.pop[3] end

function N.InkColor(role)
    local c = INK[role] or INK.TEXT
    return c[1], c[2], c[3]
end

-- ---------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------

local function savePosition(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    if not point then return end
    GP.db.window.native = { point, relPoint, x, y }
end

local function restorePosition(f)
    local p = GP.db.window.native
    f:ClearAllPoints()
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

function N.Window(spec)
    local f = CreateFrame("Frame", spec.name, UIParent, "ButtonFrameTemplate")
    f:SetSize(spec.w, spec.h)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:Hide()
    if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
    if f.SetPortraitToUnit then pcall(f.SetPortraitToUnit, f, "player") end
    if f.SetTitle then f:SetTitle(spec.title or "") end

    -- The inset is the page area, as on the character sheet.
    local inset = f.Inset or CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 4)
    f.body = CreateFrame("Frame", nil, inset)
    f.body:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
    f.body:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -6, 6)

    -- The line under the title: who you are and what was found.
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 66, -36)
    f.sub:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    f.sub:SetJustifyH("LEFT")
    f.sub:SetWordWrap(false)

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        savePosition(self)
    end)
    -- A size grip in the corner (the chat frame's): drag for more rows,
    -- right-click for the made size again.
    if spec.minW and f.SetResizable then
        f:SetResizable(true)
        if f.SetResizeBounds then f:SetResizeBounds(spec.minW, spec.minH)
        elseif f.SetMinResize then f:SetMinResize(spec.minW, spec.minH) end
        local grip = CreateFrame("Button", nil, f)
        grip:SetSize(16, 16)
        grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
        grip:SetFrameLevel(f:GetFrameLevel() + 20)
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        grip:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then f.gpSizing = true f:StartSizing("BOTTOMRIGHT") end
        end)
        local function stop()
            if not f.gpSizing then return end
            f.gpSizing = nil
            f:StopMovingOrSizing()
            f:SetUserPlaced(false)
            savePosition(f)
            if spec.sized then spec.sized(f:GetWidth(), f:GetHeight()) end
        end
        grip:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                f:SetSize(spec.minW, spec.minH)
                if spec.sized then spec.sized(nil) end
                return
            end
            stop()
        end)
        f:HookScript("OnHide", stop)
        f.grip = grip
    end
    restorePosition(f)
    f:SetScale(GP.Clamp(tonumber(GP.Setting("scale")) or 1, 0.6, 1.5))
    return f
end

function N.SetTitle(f, title, sub)
    if f.SetTitle and title then f:SetTitle(title) end
    if sub then f.sub:SetText(sub) end
end

function N.Tabs(f, tabs, onPick)
    f.gpTabIDs = {}
    for i, t in ipairs(tabs) do
        -- The template puts each tab in f.Tabs (parentArray).
        local b = CreateFrame("Button", f:GetName() .. "Tab" .. i, f, "PanelTabButtonTemplate")
        b:SetID(i)
        b:SetText(t.text)
        b:SetScript("OnClick", function()
            if f.selectedTab == i then return end
            PanelTemplates_SetTab(f, i)
            sound("IG_CHARACTER_INFO_TAB")
            onPick(t.id)
        end)
        f.gpTabIDs[t.id] = i
        if i == 1 then b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2) end
    end
    PanelTemplates_SetNumTabs(f, #tabs)
    PanelTemplates_SetTab(f, 1)
end

function N.PickTab(f, id)
    local i = f.gpTabIDs and f.gpTabIDs[id]
    if i then PanelTemplates_SetTab(f, i) end
end

function N.Open(f)
    if f.SetPortraitToUnit then pcall(f.SetPortraitToUnit, f, "player") end
    f:Show()
    sound("IG_CHARACTER_INFO_OPEN")
end

function N.Close(f)
    f:Hide()
    sound("IG_CHARACTER_INFO_CLOSE")
end

function N.IsOpen(f) return f:IsShown() end

function N.SetScale(f, scale) f:SetScale(GP.Clamp(tonumber(scale) or 1, 0.6, 1.5)) end

-- ---------------------------------------------------------------------
-- Pieces
-- ---------------------------------------------------------------------

function N.Panel(parent)
    return CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
end

function N.Ink(fs, role, a)
    local c = INK[role] or INK.TEXT
    fs:SetTextColor(c[1], c[2], c[3], a or 1)
end

function N.Text(parent, size, role, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", FONTS[size] or FONTS.body)
    fs:SetJustifyH(justify or "LEFT")
    N.Ink(fs, role or (size == "head" or size == "title") and "TITLE" or "TEXT")
    return fs
end

function N.Separator(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 0.1)
    t:SetHeight(1)
    return t
end

function N.Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text or "")
    function b.SetLabel(t) b:SetText(t or "") end
    function b.FitWidth(min)
        local fs = b:GetFontString()
        local sw = fs and fs:GetStringWidth() or 60
        b:SetWidth(math.max(min or 60, sw + 24))
    end
    return b
end

-- A switch: t.SetOn(on), t.on, t.onToggle(on) when clicked.
function N.Toggle(parent)
    local t = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    t:SetSize(26, 26)
    function t.SetOn(on)
        t.on = on and true or false
        t:SetChecked(t.on)
    end
    t:SetScript("OnClick", function(self)
        self.on = self:GetChecked() and true or false
        sound(self.on and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        if self.onToggle then self.onToggle(self.on) end
    end)
    return t
end

-- opts: search (a search box), hint, onChange(text, byUser), width, height.
function N.Input(parent, opts)
    opts = opts or {}
    local e = CreateFrame("EditBox", nil, parent, opts.search and "SearchBoxTemplate" or "InputBoxTemplate")
    e:SetSize(opts.width or 160, opts.height or 20)
    e:SetAutoFocus(false)
    if opts.search and e.Instructions and opts.hint then e.Instructions:SetText(opts.hint) end
    if not opts.search then e:SetTextInsets(4, 4, 0, 0) end
    if opts.onChange then
        e:HookScript("OnTextChanged", function(self, user) opts.onChange(self:GetText() or "", user) end)
    end
    e:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return e
end

-- A scroll area: sf.child is what scrolls; the bar sits outside on the
-- right (leave N.BAR_ROOM for it).
function N.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    if sf.ScrollBar and sf.ScrollBar.SetHideIfUnscrollable then sf.ScrollBar:SetHideIfUnscrollable(true) end
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf.child = child
    sf.barRoom = N.BAR_ROOM
    function sf.UpdateBar()
        if sf.ScrollBar and sf.ScrollBar.Update then pcall(sf.ScrollBar.Update, sf.ScrollBar) end
    end
    GP.Skin.Wheel(sf)
    return sf
end

-- An item's icon in its quality border: f.SetItem(icon, quality),
-- f.SetEmpty(texture).
function N.Icon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    f.bg:SetColorTexture(0, 0, 0, 0.6)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints(f)
    f.border = f:CreateTexture(nil, "OVERLAY")
    f.border:SetAllPoints(f)
    f.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    f.border:Hide()
    function f.SetItem(icon, quality)
        f.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        f.tex:SetAlpha(1)
        f.tex:SetTexCoord(0, 1, 0, 1)
        if type(quality) == "number" and quality >= 2 then
            local r, g, b = GP.QualityColor(quality)
            f.border:SetVertexColor(r, g, b)
            f.border:Show()
        else
            f.border:Hide()
        end
    end
    function f.SetEmpty(texture)
        f.tex:SetTexture(texture or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        f.tex:SetAlpha(0.8)
        f.tex:SetTexCoord(0, 1, 0, 1)
        f.border:Hide()
    end
    return f
end

-- Hover and selected looks for a list row (a Button).
function N.Highlight(row)
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints(row)
    row.hl:SetColorTexture(N.ROW_HL[1], N.ROW_HL[2], N.ROW_HL[3], N.ROW_HL[4])
    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints(row)
    row.sel:SetColorTexture(1, 0.82, 0, 0.12)
    row.sel:Hide()
end

-- A section heading's look under its text.
function N.HeaderLine(parent)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(1, 0.82, 0, 0.08)
    return t
end

-- A ring round a picked slot.
function N.Ring(parent)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    t:SetBlendMode("ADD")
    return t
end

-- A box that pops up over the window (the content filter's switches):
-- the game's tooltip frame.
function N.Popup(parent)
    local ok, f = pcall(CreateFrame, "Frame", nil, parent, "TooltipBackdropTemplate")
    if not ok or not f then
        f = CreateFrame("Frame", nil, parent)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(f)
        bg:SetColorTexture(0.04, 0.04, 0.05, 0.95)
    end
    f:Hide()
    return f
end

-- A choice from a list: keys in order, labels[key], the current key.
function N.Menu(owner, keys, labels, current, onPick)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            for _, k in ipairs(keys) do
                root:CreateRadio(labels[k] or tostring(k),
                    function() return k == current end,
                    function() onPick(k) end)
            end
        end)
        return
    end
    -- No menu system: each click moves to the next choice.
    for i, k in ipairs(keys) do
        if k == current then
            onPick(keys[i % #keys + 1])
            return
        end
    end
    onPick(keys[1])
end
