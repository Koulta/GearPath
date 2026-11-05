-- Share: what GearPath users see in game, passed between them.
--
-- When Learn.lua sees a gear source the database doesn't have the way you
-- saw it (a quest reward, loot, a vendor), it's sent to other GearPath
-- users with hidden addon messages: your guild, your group, and a hidden
-- GearPath channel that reaches everyone else using it (on unless you turn
-- "Use the GearPath channel" off in Settings; a chat line says so once). What they see comes back the same way. Addons
-- can't reach the internet, so this is the whole network: players online
-- at the same time.
--
-- Only numbers and a short name go out: the item, the quest or NPC, the
-- map and the spot. Nothing is passed on again (no flooding), each sender
-- is rate-limited, every field is checked, and a source the database
-- doesn't know only shows once two players report it, or one in your
-- guild or group. Off with "Share what you see" in Settings.
--
-- Sent only out of combat and outside instances (the game locks addon
-- messages there); anything waiting goes when that ends.

local _, GP = ...

local Share = { queue = {}, rate = {}, sent = {} }
GP.Share = Share

Share.PREFIX = "GearPath"
Share.CHANNEL = "GearPathData"
Share.VERSION = 1
Share.MAX_LEN = 250          -- an addon message holds 255 bytes
Share.PER_MINUTE = 40        -- records taken from one player a minute
Share.TRUST_COUNT = 2        -- reporters needed for a source the database doesn't know

local function on() return GP.Setting("share") ~= false end
local function channelOn() return on() and GP.Setting("shareChannel") == true end

local function store()
    GP.db.shared = GP.db.shared or { items = {} }
    GP.db.shared.items = GP.db.shared.items or {}
    return GP.db.shared.items
end

-- ---------------------------------------------------------------------
-- Records: "Q:item:quest:map:x:y:name", "D:...:npc...", "V:...:npc..."
-- (x, y in thousandths; the name is the quest's or the NPC's, short)
-- ---------------------------------------------------------------------

local KINDS = { Q = "q", D = "d", V = "v" }
local LETTER = { q = "Q", d = "D", v = "V" }

local function cleanName(s)
    if type(s) ~= "string" then return "" end
    -- No escape codes, no separators, nothing long.
    s = s:gsub("|", ""):gsub("[:;]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return s:sub(1, 32)
end

function Share.Encode(kind, item, id, map, x, y, name)
    local letter = LETTER[kind]
    if not (letter and type(item) == "number" and type(id) == "number") then return nil end
    local xi = type(x) == "number" and math.floor(x * 1000 + 0.5) or 0
    local yi = type(y) == "number" and math.floor(y * 1000 + 0.5) or 0
    return string.format("%s:%d:%d:%d:%d:%d:%s", letter, item, id, map or 0, xi, yi, cleanName(name))
end

local function num(s, lo, hi)
    local n = tonumber(s)
    if not n or n ~= math.floor(n) or n < lo or n > hi then return nil end
    return n
end

-- A record, or nil for anything that isn't exactly one.
function Share.Decode(s)
    if type(s) ~= "string" or #s > 120 then return nil end
    local letter, item, id, map, x, y, name = s:match("^(%u):(%d+):(%d+):(%d+):(%d+):(%d+):([^:;|]*)$")
    local kind = KINDS[letter or ""]
    if not kind then return nil end
    item, id, map = num(item, 1, 9999999), num(id, 1, 9999999), num(map, 0, 99999)
    x, y = num(x, 0, 1000), num(y, 0, 1000)
    if not (item and id and map and x and y) then return nil end
    return { kind = kind, item = item, id = id, map = map > 0 and map or nil,
        x = x > 0 and x / 1000 or nil, y = y > 0 and y / 1000 or nil, name = name ~= "" and name or nil }
end

-- ---------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------

local channelIndex

local function joinChannel()
    if not channelOn() or not JoinTemporaryChannel or not GetChannelName then return end
    local idx = GetChannelName(Share.CHANNEL)
    if type(idx) ~= "number" or idx == 0 then
        pcall(JoinTemporaryChannel, Share.CHANNEL)
        idx = GetChannelName(Share.CHANNEL)
    end
    if type(idx) == "number" and idx > 0 then
        channelIndex = idx
        -- Hidden: never shown in a chat window.
        if ChatFrame_RemoveChannel and DEFAULT_CHAT_FRAME then
            pcall(ChatFrame_RemoveChannel, DEFAULT_CHAT_FRAME, Share.CHANNEL)
        end
    end
end

local function leaveChannel()
    if LeaveChannelByName and GetChannelName and (GetChannelName(Share.CHANNEL) or 0) > 0 then
        pcall(LeaveChannelByName, Share.CHANNEL)
    end
    channelIndex = nil
end

function Share.Changed()
    if channelOn() then joinChannel() else leaveChannel() end
end

-- Queues a source you saw yourself (Learn.lua calls this).
function Share.Send(kind, item, id, map, x, y, name)
    if not on() then return end
    local rec = Share.Encode(kind, item, id, map, x, y, name)
    if not rec then return end
    local key = kind .. item .. ":" .. id
    if Share.sent[key] then return end   -- once a session is enough
    Share.sent[key] = true
    Share.queue[#Share.queue + 1] = rec
end

local function canSend()
    if InCombatLockdown and InCombatLockdown() then return false end
    if IsInInstance and IsInInstance() then return false end
    return C_ChatInfo and C_ChatInfo.SendAddonMessage ~= nil
end

local function send(msg, chatType, target)
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, Share.PREFIX, msg, chatType, target)
    return ok and (result == nil or result == 0 or result == true)
end

-- One message every few seconds, as many records as fit.
local function flush()
    if #Share.queue == 0 or not on() or not canSend() then return end
    local parts, len = { tostring(Share.VERSION) }, 1
    while Share.queue[1] and len + #Share.queue[1] + 1 <= Share.MAX_LEN do
        local rec = table.remove(Share.queue, 1)
        parts[#parts + 1] = rec
        len = len + #rec + 1
    end
    local msg = table.concat(parts, ";")
    if IsInGuild and IsInGuild() then send(msg, "GUILD") end
    if IsInRaid and IsInRaid() then send(msg, "RAID")
    elseif IsInGroup and IsInGroup() then send(msg, "PARTY") end
    if channelOn() then
        if not channelIndex then joinChannel() end
        if channelIndex then send(msg, "CHANNEL", channelIndex) end
    end
end

-- ---------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------

local function me()
    local name, realm
    if UnitFullName then name, realm = UnitFullName("player") end
    name = GP.Plain(name) or GP.Plain(UnitName("player"))
    realm = GP.Plain(realm) or (GetNormalizedRealmName and GP.Plain(GetNormalizedRealmName())) or ""
    return name, realm
end

local function fromMe(sender)
    local name, realm = me()
    return sender == name or sender == (name .. "-" .. realm)
end

-- Rate counts older than a minute are of no use; cleared as messages go out.
local function forgetRates()
    local now = GetTime()
    for sender, r in pairs(Share.rate) do
        if now - r.start > 60 then Share.rate[sender] = nil end
    end
end

local function allowed(sender)
    local now = GetTime()
    local r = Share.rate[sender]
    if not r or now - r.start > 60 then
        r = { start = now, n = 0 }
        Share.rate[sender] = r
    end
    r.n = r.n + 1
    return r.n <= Share.PER_MINUTE
end

-- Keeps one reported source: who reported it (up to 8 names) and
-- whether one of them is in your guild or group.
local function keep(rec, sender, trusted)
    local items = store()
    local t = items[rec.item]
    if not t then
        -- Saved lists are cut to size at the next load; within one session,
        -- new items stop being taken once that many arrived (spam can't
        -- grow the saved file without bound before then).
        Share.newItems = (Share.newItems or 0) + 1
        if Share.newItems > (GP.Learn and GP.Learn.SHARED_MAX or 2000) then return false end
        t = {}
        items[rec.item] = t
    end
    t[rec.kind] = t[rec.kind] or {}
    local s = t[rec.kind][rec.id]
    if not s then
        s = { by = {}, c = 0 }
        t[rec.kind][rec.id] = s
    end
    s.s = time and time() or s.s       -- last seen (Learn.Prune drops it after a while unseen)
    if s.by[sender] then return false end
    -- Eight reporters is plenty: past that a repeat can't be told from a new
    -- voice, so the count stops there instead of letting one player pump it.
    if s.c >= 8 then return false end
    s.by[sender] = true
    s.c = s.c + 1
    s.n = s.n or rec.name
    if not s.m and rec.map then s.m, s.x, s.y = rec.map, rec.x, rec.y end
    if trusted then s.t = true end
    return true
end

local TRUSTED = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }

GP.RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    prefix, text, channel, sender = GP.Plain(prefix), GP.Plain(text), GP.Plain(channel), GP.Plain(sender)
    if prefix ~= Share.PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
    if not on() or fromMe(sender) or #text > 255 then return end
    local version, rest = text:match("^(%d+);(.*)$")
    if tonumber(version) ~= Share.VERSION or not rest then return end
    local changed = {}
    for piece in rest:gmatch("[^;]+") do
        if not allowed(sender) then break end
        local rec = Share.Decode(piece)
        if rec and keep(rec, sender, TRUSTED[channel]) then changed[rec.item] = true end
    end
    for item in pairs(changed) do GP.Sources.Learned(item) end
end)

-- What other players reported for an item, as sources (Sources.lua).
-- known(kind, id): whether the database already lists that source.
function Share.SourcesFor(item, known)
    local out = {}
    local t = GP.db and GP.db.shared and GP.db.shared.items and GP.db.shared.items[item]
    if type(t) ~= "table" then return out end
    for kind, list in pairs(t) do
        for id, s in pairs(list) do
            local isKnown = known(kind, id)
            -- A source the database doesn't know needs more than one voice.
            if isKnown or s.t or (s.c or 0) >= Share.TRUST_COUNT then
                out[#out + 1] = { kind = kind, id = id, info = s, known = isKnown }
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------
-- When
-- ---------------------------------------------------------------------

GP.On("Login", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, Share.PREFIX)
    end
    store()
    -- After the game's own channels (General, Trade...) have their numbers:
    -- join it when it's on, and leave it when it's off (the game rejoins
    -- channels from earlier sessions by itself).
    C_Timer.After(20, function()
        GP.SafeCall(Share.Changed)
        GP.SafeCall(Share.Notice)
    end)
end)

-- Once per save: say that GearPath shares through its channel, and how to
-- keep it to your guild and group.
function Share.Notice()
    if not GP.db or GP.db.shareNoticed or not channelOn() then return end
    GP.db.shareNoticed = true
    GP.Print(GP.L["GearPath shares where gear comes from with every GearPath player through a hidden chat channel (only item, quest, NPC and map numbers). To share with only your guild and group, turn off \"Use the GearPath channel\" in Settings."])
end

C_Timer.NewTicker(3, function()
    GP.SafeCall(flush)
    GP.SafeCall(forgetRates)
end)
