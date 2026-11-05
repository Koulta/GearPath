-- A stand-in for the client's C_EncodingUtil (base64, CBOR, zlib), enough
-- for QuestieDB's baked data to load offline.

local LibDeflate = require("LibDeflate")

local E = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64V = {}
for i = 1, 64 do B64V[B64:sub(i, i)] = i - 1 end

function E.DecodeBase64(s)
    s = s:gsub("[^%w%+/=]", "")
    local out, n = {}, 0
    for i = 1, #s, 4 do
        local a, b, c, d = B64V[s:sub(i, i)], B64V[s:sub(i + 1, i + 1)], s:sub(i + 2, i + 2), s:sub(i + 3, i + 3)
        local cv, dv = B64V[c], B64V[d]
        local v = a * 262144 + b * 4096 + (cv or 0) * 64 + (dv or 0)
        local b1 = math.floor(v / 65536) % 256
        local b2 = math.floor(v / 256) % 256
        local b3 = v % 256
        n = n + 1; out[n] = string.char(b1)
        if c ~= "=" and c ~= "" then n = n + 1; out[n] = string.char(b2) end
        if d ~= "=" and d ~= "" then n = n + 1; out[n] = string.char(b3) end
    end
    return table.concat(out)
end

function E.DecompressString(data, method)
    local out = LibDeflate:DecompressZlib(data)
    if not out then out = LibDeflate:DecompressDeflate(data) end
    return out
end

local function float(bytes, expBits, mantBits)
    local v = 0
    for i = 1, #bytes do v = v * 256 + bytes:byte(i) end
    local total = 1 + expBits + mantBits
    local sign = math.floor(v / 2 ^ (total - 1)) % 2
    local exp = math.floor(v / 2 ^ mantBits) % 2 ^ expBits
    local mant = v % 2 ^ mantBits
    local bias = 2 ^ (expBits - 1) - 1
    local r
    if exp == 0 then
        r = mant / 2 ^ mantBits * 2 ^ (1 - bias)
    elseif exp == 2 ^ expBits - 1 then
        r = mant == 0 and math.huge or 0 / 0
    else
        r = (1 + mant / 2 ^ mantBits) * 2 ^ (exp - bias)
    end
    return sign == 1 and -r or r
end

local decode
decode = function(s, pos)
    local ib = s:byte(pos)
    pos = pos + 1
    local major, info = math.floor(ib / 32), ib % 32
    local function uint(n)
        local v = 0
        for i = 0, n - 1 do v = v * 256 + s:byte(pos + i) end
        pos = pos + n
        return v
    end
    local function arg()
        if info < 24 then return info end
        if info == 24 then return uint(1) end
        if info == 25 then return uint(2) end
        if info == 26 then return uint(4) end
        if info == 27 then return uint(8) end
        return nil   -- indefinite length
    end
    if major == 0 then return arg(), pos end
    if major == 1 then return -1 - arg(), pos end
    if major == 2 or major == 3 then
        local n = arg()
        if n == nil then
            local parts = {}
            while s:byte(pos) ~= 0xFF do
                local part
                part, pos = decode(s, pos)
                parts[#parts + 1] = part
            end
            return table.concat(parts), pos + 1
        end
        return s:sub(pos, pos + n - 1), pos + n
    end
    if major == 4 then
        local n, t = arg(), {}
        if n == nil then
            local i = 1
            while s:byte(pos) ~= 0xFF do t[i], pos = decode(s, pos); i = i + 1 end
            return t, pos + 1
        end
        for i = 1, n do t[i], pos = decode(s, pos) end
        return t, pos
    end
    if major == 5 then
        local n, t = arg(), {}
        local count = 0
        while (n == nil and s:byte(pos) ~= 0xFF) or (n ~= nil and count < n) do
            local k, v
            k, pos = decode(s, pos)
            v, pos = decode(s, pos)
            if k ~= nil then t[k] = v end
            count = count + 1
        end
        if n == nil then pos = pos + 1 end
        return t, pos
    end
    if major == 6 then
        arg()
        return decode(s, pos)
    end
    -- major 7
    if info == 20 then return false, pos end
    if info == 21 then return true, pos end
    if info == 22 or info == 23 then return nil, pos end
    if info == 25 then local b = s:sub(pos, pos + 1); return float(b, 5, 10), pos + 2 end
    if info == 26 then local b = s:sub(pos, pos + 3); return float(b, 8, 23), pos + 4 end
    if info == 27 then local b = s:sub(pos, pos + 7); return float(b, 11, 52), pos + 8 end
    return nil, pos
end

function E.DeserializeCBOR(bytes)
    if type(bytes) ~= "string" or bytes == "" then return nil end
    local v = decode(bytes, 1)
    return v
end

return E
