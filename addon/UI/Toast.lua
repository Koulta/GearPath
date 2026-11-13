-- Toast: when you pick up gear that's an upgrade for you, a small note at
-- the top of the screen for a few seconds (0.8.0, the idea from GearQuest's
-- "got it" toast; written for GearPath):
--   Upgrade!
--   Leftover Abomination: +57% (Chest)
-- Anywhere, not only in dungeons. A click closes it. Off with "Upgrade
-- toast" in Settings > Extras.

local _, GP = ...

local Toast = {}
GP.Toast = Toast

local L = GP.L

Toast.SHOW_FOR = 5   -- seconds

local function on() return GP.Setting("upgradeToast") ~= false end

local function frame()
    if Toast.frame then return Toast.frame end
    local skin = GP.Skin.Pick()
    local f = skin.Popup(UIParent)
    f:SetFrameStrata("HIGH")
    f:SetSize(320, 52)
    f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function() f:Hide() end)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(32, 32)
    f.icon:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.title = skin.Text(f, "head", "GOOD")
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, 0)
    f.title:SetText(L["Upgrade!"])
    f.text = skin.Text(f, "body", "VALUE")
    f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.text:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.text:SetWordWrap(false)
    f:Hide()
    Toast.frame = f
    return f
end

-- The line for an upgrade: "Leftover Abomination: +57% (Chest)".
function Toast.Text(ev)
    local gain = GP.UI.GainText(ev)
    if gain == "new" then gain = L["new"] end
    return string.format("%s: %s (%s)", ev.rec.name or "?", gain, GP.Slots.Label(ev.slot) or "?")
end

-- You looted item `id`: a toast if GearPath counted it as an upgrade.
function Toast.Looted(id)
    if not on() then return false end
    local ev = GP.Score.ForItem(id)
    if not ev or ev.healerPass or not GP.Score.BigEnough(ev.delta or 0, ev.base) then return false end
    local f = frame()
    f.icon:SetTexture(ev.rec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.text:SetText(Toast.Text(ev))
    f:Show()
    Toast.shownAt = GetTime and GetTime() or 0
    local at = Toast.shownAt
    if C_Timer and C_Timer.After then
        C_Timer.After(Toast.SHOW_FOR, function()
            if Toast.shownAt == at and Toast.frame then Toast.frame:Hide() end
        end)
    end
    if PlaySound and SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST then pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST) end
    return true
end
