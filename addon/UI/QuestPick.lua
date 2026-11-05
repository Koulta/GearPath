-- QuestPick: when a quest offers a choice of rewards, GearPath's pick.
-- The best upgrade for you (or, when none is, the one that sells for the
-- most) gets a card beside the quest window, DaylightUI's or the game's,
-- a green arrow on its button in the game's own quest window, and a line
-- in chat as you turn the quest in. Hovering any reward shows GearPath's
-- line in its tooltip, as on every item.
--
-- Healer gear (unless asked for in Settings), gear your class can't use
-- and gear that needs something you don't have yet are never the pick.
-- Off with "Quest reward pick" in Settings.

local _, GP = ...

local QP = {}
GP.QuestPick = QP

QP.CARD_W = 230

-- The item API as this client has it (Forever: C_Item; older: the globals).
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local function on() return GP.Setting("questPick") ~= false end

-- ---------------------------------------------------------------------
-- Judging the choices
-- ---------------------------------------------------------------------

local function sellPrice(link)
    if not GetItemInfo then return 0 end
    local v = select(11, GetItemInfo(link))
    return tonumber(GP.Plain(v)) or 0
end

-- One choice: { index, link, rec, sell, slot, delta, pct, healer }, or nil
-- and true while the game is still loading it.
local function judge(i)
    local link = GetQuestItemLink and GP.Plain(GetQuestItemLink("choice", i))
    if type(link) ~= "string" then return nil, true end
    local rec = GP.Items.FromLink(link)
    if not rec then return nil, true end
    local out = { index = i, link = link, rec = rec, sell = sellPrice(link) }
    local usable = true
    if GetQuestItemInfo then
        local isUsable = select(5, GetQuestItemInfo("choice", i))
        if GP.Plain(isUsable) == false then usable = false end
    end
    if usable then usable, out.healer = GP.Score.CanWear(rec) end
    if usable then out.slot, out.delta, out.pct = GP.Score.Gain(rec) end
    return out
end

-- GearPath's pick from the quest window's choices: the biggest upgrade
-- (kind "upgrade"), else the best seller (kind "sell"), else nil. Also
-- whether any choice is still loading.
function QP.Pick()
    local n = GetNumQuestChoices and tonumber(GP.Plain(GetNumQuestChoices())) or 0
    if n < 2 then return nil, false end
    if not next(GP.Score.equipped or {}) then GP.Score.ReadEquipped() end
    local list, loading = {}, false
    for i = 1, n do
        local j, wait = judge(i)
        if j then list[#list + 1] = j elseif wait then loading = true end
    end
    local best
    for _, j in ipairs(list) do
        if j.delta and (not best or j.delta > best.delta) then best = j end
    end
    if best then
        best.kind = "upgrade"
        return best, loading
    end
    for _, j in ipairs(list) do
        if j.sell > 0 and (not best or j.sell > best.sell) then best = j end
    end
    if best then best.kind = "sell" end
    return best, loading
end

local money = GP.Money

-- The pick in a few words: "+83% Chest", or what it sells for.
function QP.Why(pick)
    if pick.kind == "upgrade" then return GP.UI.GainLine(pick.slot, pick.delta, pick.pct), "GOOD" end
    return string.format(GP.L["None are upgrades: sells for the most, %s"], money(pick.sell)), "LABEL"
end

-- ---------------------------------------------------------------------
-- Showing it
-- ---------------------------------------------------------------------

-- The quest window that's on screen: DaylightUI's own, or the game's
-- (DaylightUI parks the game's out of sight while its own is up).
local function questWindow()
    local d = rawget(_G, "DaylightUINpc")
    if d and d.IsShown and d:IsShown() then return d, "daylight" end
    local q = rawget(_G, "QuestFrame")
    if q and q.IsShown and q:IsShown() then return q, "game" end
end

-- The game's reward buttons (the quest window's QuestInfo part).
local function rewardButtons()
    local list, seen = {}, {}
    local rf = rawget(_G, "QuestInfoRewardsFrame")
    if rf and type(rf.RewardButtons) == "table" then
        for _, b in ipairs(rf.RewardButtons) do
            if not seen[b] then list[#list + 1], seen[b] = b, true end
        end
    end
    for i = 1, 10 do
        local b = rawget(_G, "QuestInfoRewardsFrameQuestInfoItem" .. i)
        if b and not seen[b] then list[#list + 1], seen[b] = b, true end
    end
    return list
end

-- The arrow (or a coin, for the best seller) on the picked button.
local function markButtons(pick)
    for _, b in ipairs(rewardButtons()) do
        local mine = pick ~= nil and b.type == "choice" and b.GetID and b:GetID() == pick.index
            and b.IsShown and b:IsShown()
        if mine and not b.gpArrow then
            b.gpArrow = GP.Skin.UpgradeArrow(b, 20)
            b.gpArrow:SetPoint("TOPLEFT", b, "TOPLEFT", -6, 6)
            b.gpCoin = b:CreateTexture(nil, "OVERLAY", nil, 7)
            b.gpCoin:SetSize(14, 14)
            b.gpCoin:SetPoint("TOPLEFT", b, "TOPLEFT", -4, 4)
            b.gpCoin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        end
        if b.gpArrow then
            b.gpArrow:SetShown(mine and pick.kind == "upgrade")
            if mine then b.gpArrow.Paint("primary") end
            b.gpCoin:SetShown(mine and pick.kind == "sell")
        end
    end
end

local function buildCard()
    if QP.card then return QP.card end
    local skin = GP.Skin.Pick()
    local f = CreateFrame("Frame", "GearPathQuestPick", UIParent)
    f:SetSize(QP.CARD_W, 64)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:Hide()
    f.panel = skin.Panel(f)
    f.panel:SetAllPoints(f)
    f.title = skin.Text(f, "small", "LABEL")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -7)
    f.title:SetText(GP.L["GearPath pick"])
    f.icon = skin.Icon(f, 34)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -22)
    f.icon:EnableMouse(false)
    f.arrow = GP.Skin.UpgradeArrow(f, 16)
    f.arrow:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -6, 6)
    f.name = skin.Text(f, "body", "VALUE")
    f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1)
    f.name:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.name:SetWordWrap(false)
    f.why = skin.Text(f, "small", "GOOD")
    f.why:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -5)
    f.why:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.why:SetWordWrap(false)
    f:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Goes when the quest window does.
    f:SetScript("OnUpdate", function(self, elapsed)
        self.wait = (self.wait or 0) + (elapsed or 0)
        if self.wait < 0.25 then return end
        self.wait = 0
        if not (self.anchor and self.anchor:IsShown()) then self:Hide() end
    end)
    QP.card = f
    return f
end

local function showCard(pick, win)
    local f = buildCard()
    local skin = GP.Skin.current or GP.Skin.Pick()
    f.link = pick.link
    f.anchor = win
    f.icon.SetItem(pick.rec.icon, pick.rec.quality)
    f.arrow:SetShown(pick.kind == "upgrade")
    if pick.kind == "upgrade" then f.arrow.Paint("primary") end
    f.name:SetText(pick.rec.name or "?")
    local r, g, b = GP.QualityColor(pick.rec.quality)
    f.name:SetTextColor(r, g, b)
    local text, role = QP.Why(pick)
    f.why:SetText(text)
    skin.Ink(f.why, role)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", win, "TOPRIGHT", 6, -8)
    if win.GetFrameLevel then f:SetFrameLevel(win:GetFrameLevel() + 20) end
    f:Show()
end

function QP.Hide()
    if QP.card then QP.card:Hide() end
    markButtons(nil)
end

-- Looks at the quest window now. On turn-in it also says the pick in chat
-- (once per quest).
function QP.Update()
    if not (on() and QP.mode) then
        QP.Hide()
        return
    end
    local pick, loading = QP.Pick()
    QP.pick = pick
    if loading then
        -- A reward still loading: look again in a moment.
        C_Timer.After(0.3, function() if QP.mode then GP.SafeCall(QP.Update) end end)
    end
    if not pick then
        QP.Hide()
        return
    end
    -- In chat as you turn it in, whatever window is showing (once a quest).
    if QP.mode == "complete" and not loading then
        local quest = GetQuestID and GP.Plain(GetQuestID()) or 0
        if QP.said ~= quest then
            QP.said = quest
            if pick.kind == "upgrade" then
                GP.Print("Pick %s: %s.", pick.link, (QP.Why(pick)))
            else
                GP.Print("None of these rewards are upgrades for you. %s sells for the most, %s.", pick.link, money(pick.sell))
            end
        end
    end
    local win, which = questWindow()
    if not win then
        QP.Hide()
        return
    end
    showCard(pick, win)
    markButtons(which == "game" and pick or nil)
end

-- ---------------------------------------------------------------------
-- When
-- ---------------------------------------------------------------------

local function opened(mode)
    QP.mode = mode
    GP.SafeCall(QP.Update)
    -- DaylightUI's window lifts in a moment after the game's event.
    C_Timer.After(0.2, function() if QP.mode == mode then GP.SafeCall(QP.Update) end end)
    C_Timer.After(0.6, function() if QP.mode == mode then GP.SafeCall(QP.Update) end end)
end

GP.RegisterEvent("QUEST_DETAIL", function() opened("detail") end)
GP.RegisterEvent("QUEST_COMPLETE", function() opened("complete") end)
GP.RegisterEvent("QUEST_ITEM_UPDATE", function() if QP.mode then GP.Soon("questpick", QP.Update) end end)
GP.RegisterEvent("QUEST_FINISHED", function()
    QP.mode = nil
    QP.Hide()
end)
GP.On("SettingChanged", function(key) if key == "questPick" or key == "healerGear" then GP.Soon("questpick", QP.Update) end end)
