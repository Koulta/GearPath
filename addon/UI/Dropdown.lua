-- Dropdown: a button that shows a choice and opens the look's menu.
--
--   GP.Dropdown(parent, { width = 150, keys = { ... } or fn, labels = { key = text },
--                         get = fn() -> key, set = fn(key), prefix = "Sort: " })

local _, GP = ...

function GP.Dropdown(parent, spec)
    local skin = GP.Skin.current
    local b = skin.Button(parent, "", spec.width or 150, spec.height or 24)
    local arrow = GP.Skin.DownArrow(b, 14)
    arrow:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    local function keys() return type(spec.keys) == "function" and spec.keys() or spec.keys end
    function b.Refresh()
        local k = spec.get()
        local label = spec.labels[k] or tostring(k or "")
        b.SetLabel((spec.prefix or "") .. label)
    end
    b:SetScript("OnClick", function()
        skin.Menu(b, keys(), spec.labels, spec.get(), function(k)
            spec.set(k)
            b.Refresh()
        end)
    end)
    b.Refresh()
    return b
end

-- MultiDropdown: a button that opens a list of switches, for picking any
-- number of things (the content filter). Stays open while you switch;
-- a click anywhere else, or on the button again, closes it.
--
--   GP.MultiDropdown(parent, { width, keys, labels, prefix, summary = fn() -> text,
--                              isOn = fn(key), setOn = fn(key, on), setAll = fn(on) })

local openPopup

function GP.MultiDropdown(parent, spec)
    local skin = GP.Skin.current
    local b = skin.Button(parent, "", spec.width or 220, spec.height or 24)
    local arrow = GP.Skin.DownArrow(b, 14)
    arrow:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    local popup, refresh

    function b.Refresh()
        b.SetLabel((spec.prefix or "") .. spec.summary())
        if popup and popup:IsShown() then refresh() end
    end

    local function close()
        if popup then popup:Hide() end
    end

    local ROW = 26
    local function build()
        popup = skin.Popup(UIParent)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        popup:SetSize(240, 46 + #spec.keys * ROW)
        local all = skin.Button(popup, GP.L["All"], 64, 22)
        all:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -12)
        all:SetScript("OnClick", function() spec.setAll(true); refresh() end)
        local none = skin.Button(popup, GP.L["None"], 64, 22)
        none:SetPoint("LEFT", all, "RIGHT", 8, 0)
        none:SetScript("OnClick", function() spec.setAll(false); refresh() end)
        popup.rows = {}
        for i, k in ipairs(spec.keys) do
            local row = CreateFrame("Button", nil, popup)
            row:SetHeight(ROW)
            row:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -(42 + (i - 1) * ROW))
            row:SetPoint("RIGHT", popup, "RIGHT", -8, 0)
            skin.Highlight(row)
            row.toggle = skin.Toggle(row)
            row.toggle:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.toggle.onToggle = function(on) spec.setOn(k, on); refresh() end
            row.label = skin.Text(row, "body", "TEXT")
            row.label:SetPoint("LEFT", row.toggle, "RIGHT", 8, 0)
            row.label:SetText(spec.labels[k] or k)
            row:SetScript("OnClick", function() spec.setOn(k, not spec.isOn(k)); refresh() end)
            popup.rows[i] = row
        end
        -- A click anywhere else closes it.
        popup.catcher = CreateFrame("Button", nil, UIParent)
        popup.catcher:SetAllPoints(UIParent)
        popup.catcher:SetFrameStrata("FULLSCREEN")
        popup.catcher:RegisterForClicks("AnyUp")
        popup.catcher:SetScript("OnClick", close)
        popup.catcher:Hide()
        popup:SetScript("OnHide", function()
            popup.catcher:Hide()
            if openPopup == popup then openPopup = nil end
        end)
    end

    refresh = function()
        for i, k in ipairs(spec.keys) do
            local on = spec.isOn(k)
            popup.rows[i].toggle.SetOn(on)
            GP.Skin.current.Ink(popup.rows[i].label, on and "TEXT" or "OFF")
        end
        b.SetLabel((spec.prefix or "") .. spec.summary())
    end

    b:SetScript("OnClick", function()
        if popup and popup:IsShown() then close() return end
        if not popup then build() end
        if openPopup and openPopup ~= popup then openPopup:Hide() end
        local k = (b:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        popup:SetScale(k > 0 and k or 1)
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -4)
        refresh()
        popup:Show()
        popup.catcher:Show()
        openPopup = popup
    end)
    b:HookScript("OnHide", close)
    b.Refresh()
    return b
end
