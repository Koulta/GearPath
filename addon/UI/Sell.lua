-- Sell: gear in your bags that isn't an upgrade for any of your specs (or
-- that you can never wear) gets a small coin, and its tooltip says so
-- (approved with Koulta, Nov 13):
--     GearPath: not an upgrade for any of your specs, safe to sell
-- The coin goes on EllesmereUI's bags and on the game's own bag windows.
-- Off with "Safe to sell mark" in Settings.

local _, GP = ...
local L = GP.L

local Sell = {}
GP.Sell = Sell

Sell.COIN = "Interface\\MoneyFrame\\UI-GoldIcon"
local DIM = { 0.6, 0.6, 0.6 }

local function on() return GP.Setting("sellMark") ~= false end

-- [link] = true/false, until the next scoring or bag change.
local cache = {}
Sell.inBags = {}     -- [itemID] = true for everything in your bags

local function clear() cache = {} end
GP.On("ScoresChanged", clear)
GP.On("WeightsChanged", clear)
GP.On("SpecChanged", clear)

-- Whether the item behind `link` is safe to sell.
function Sell.Safe(link)
    if not on() or type(link) ~= "string" then return false end
    local known = cache[link]
    if known ~= nil then return known end
    local rec = GP.Items.FromLink(link)
    if not rec then return false end     -- not loaded yet: asked again next time
    local ok, safe = pcall(GP.Score.SafeToSell, rec)
    safe = ok and safe == true
    cache[link] = safe
    return safe
end

function Sell.ScanBags()
    local found = {}
    local C = C_Container
    if C and C.GetContainerNumSlots and C.GetContainerItemLink then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, (GP.Plain(C.GetContainerNumSlots(bag)) or 0) do
                local link = GP.Plain(C.GetContainerItemLink(bag, slot))
                local id = type(link) == "string" and GP.Items.IDFromLink(link)
                if id then found[id] = true end
            end
        end
    end
    Sell.inBags = found
    return found
end

-- The tooltip line, for an item that's in your bags.
function Sell.TooltipLine(tt, id, link)
    if not (on() and Sell.inBags[id]) then return false end
    link = link or (GP.Items.Get(id) or {}).link
    if not Sell.Safe(link) then return false end
    tt:AddLine(L["GearPath: not an upgrade for any of your specs, safe to sell"], DIM[1], DIM[2], DIM[3], true)
    return true
end

-- ---------------------------------------------------------------------
-- The coin
-- ---------------------------------------------------------------------

-- bag button -> its coin (kept off the button itself, like the arrows).
local coins = setmetatable({}, { __mode = "k" })
Sell.coins = coins

-- Puts a coin on (or takes it off) a bag button. parent: where it's drawn.
function Sell.Mark(btn, parent, link)
    if not btn then return end
    local c = coins[btn]
    if not Sell.Safe(link) then
        if c then c:Hide() end
        return false
    end
    if not c then
        c = (parent or btn):CreateTexture(nil, "OVERLAY", nil, 7)
        c:SetSize(12, 12)
        c:SetTexture(Sell.COIN)
        -- Top right, where an upgrade's arrow goes (an item never gets both).
        c:SetPoint("TOPRIGHT", parent or btn, "TOPRIGHT", -1, -1)
        coins[btn] = c
    end
    c:Show()
    return true
end

-- The game's own bag windows: ContainerFrame1-13, buttons ContainerFrameNItemM.
local function paintGameBags()
    if not (C_Container and C_Container.GetContainerItemLink) then return end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = rawget(_G, "ContainerFrame" .. i)
        if frame and frame.IsShown and frame:IsShown() then
            local bag = frame.GetID and frame:GetID()
            local size = bag and GP.Plain(C_Container.GetContainerNumSlots(bag)) or 0
            for j = 1, size do
                local btn = rawget(_G, "ContainerFrame" .. i .. "Item" .. j)
                if btn then
                    local slot = btn.GetID and btn:GetID()
                    local link = slot and GP.Plain(C_Container.GetContainerItemLink(bag, slot))
                    Sell.Mark(btn, btn, type(link) == "string" and link or nil)
                end
            end
        end
    end
end
Sell.PaintGameBags = paintGameBags

local function soon() GP.Soon("sellMarks", function() GP.SafeCall(paintGameBags) end) end

GP.RegisterEvent("BAG_UPDATE_DELAYED", function()
    Sell.ScanBags()
    soon()
end)
GP.On("ScoresChanged", soon)
-- A bag window opening: painted a moment later. A post-hook on the game's
-- own function (hooksecurefunc), never a script set on its frames, so the
-- game's bag code stays its own.
local hooked = false
GP.On("Login", function()
    Sell.ScanBags()
    if hooked or type(hooksecurefunc) ~= "function" then return end
    for _, name in ipairs({ "ContainerFrame_GenerateFrame", "ContainerFrame_Update" }) do
        if type(rawget(_G, name)) == "function" then
            hooksecurefunc(name, soon)
            hooked = true
        end
    end
end)
GP.On("SettingChanged", function(key)
    if key == "sellMark" then clear(); soon() end
end)
