-- BagMarks: GearPath's marks on bags that take Baganator plugins: the green
-- upgrade arrow and the safe-to-sell coin. That's Baganator itself and
-- DaylightUI's bags, which answer Baganator's published plugin calls
-- (Baganator.API) while Baganator is off. Only that API is used; nothing of
-- either addon is copied or changed.
--   top right: the arrow on an upgrade, or else the coin on gear to sell
-- The "upgrade" search in those bags finds GearPath's upgrades too.

local _, GP = ...

local BagMarks = {}
GP.BagMarks = BagMarks

BagMarks.ARROW_ID = "gearpath_upgrade"
BagMarks.COIN_ID = "gearpath_sell"

local function api()
    local b = rawget(_G, "Baganator")
    return type(b) == "table" and type(b.API) == "table" and b.API or nil
end

-- Upgrade: true/false, or nil while the item isn't loaded (asked again).
function BagMarks.IsUpgrade(link)
    if type(link) ~= "string" then return false end
    if not GP.Items.FromLink(link) then return nil end
    return GP.Ellesmere.BagUpgrade(link) and true or false
end

function BagMarks.IsSafe(link)
    if type(link) ~= "string" then return false end
    if not GP.Items.FromLink(link) then return nil end
    if GP.Ellesmere.BagUpgrade(link) then return false end
    return GP.Sell.Safe(link)
end

local function arrowInit(btn)
    local f = CreateFrame("Frame", nil, btn)
    f:SetSize(14, 14)
    local a = GP.Skin.UpgradeArrow(f, 14)
    a:SetPoint("CENTER", f, "CENTER")
    a.Paint("primary")
    return f
end

local function coinInit(btn)
    local f = CreateFrame("Frame", nil, btn)
    f:SetSize(12, 12)
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(f)
    t:SetTexture(GP.Sell.COIN)
    return f
end

local function arrowUpdate(_, details) return BagMarks.IsUpgrade(details and details.itemLink) end
local function coinUpdate(_, details) return BagMarks.IsSafe(details and details.itemLink) end

BagMarks.registered = false
function BagMarks.Register()
    local A = api()
    if BagMarks.registered or not A then return false end
    if type(A.RegisterCornerWidget) == "function" then
        -- The same corner: whichever comes first and says yes shows.
        pcall(A.RegisterCornerWidget, "GearPath: upgrade", BagMarks.ARROW_ID, arrowUpdate, arrowInit,
            { corner = "top_right", priority = 1 })
        pcall(A.RegisterCornerWidget, "GearPath: safe to sell", BagMarks.COIN_ID, coinUpdate, coinInit,
            { corner = "top_right", priority = 2 })
    end
    if type(A.RegisterUpgradePlugin) == "function" then
        pcall(A.RegisterUpgradePlugin, "GearPath", "gearpath", function(link) return BagMarks.IsUpgrade(link) == true end)
    end
    BagMarks.registered = true
    return true
end

local function refresh()
    local A = api()
    if BagMarks.registered and A and type(A.RequestItemButtonsRefresh) == "function" then
        GP.Soon("bagMarks", function() pcall(A.RequestItemButtonsRefresh) end)
    end
end

GP.On("Login", BagMarks.Register)
GP.On("ScoresChanged", refresh)
GP.On("SettingChanged", function(key) if key == "sellMark" then refresh() end end)
