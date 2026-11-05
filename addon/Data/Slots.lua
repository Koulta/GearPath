-- Slots: the character sheet's slots, where each kind of item can go, and
-- the layout of the paper doll (the same columns as the game's own sheet).

local _, GP = ...

local Slots = {}
GP.Slots = Slots

-- key = the game's slot name; id = inventory slot; scored = we look for
-- upgrades there (the shirt and tabard are only shown).
Slots.LIST = {
    { key = "HeadSlot",          id = 1,  label = "Head" },
    { key = "NeckSlot",          id = 2,  label = "Neck" },
    { key = "ShoulderSlot",      id = 3,  label = "Shoulders" },
    { key = "ShirtSlot",         id = 4,  label = "Shirt",     cosmetic = true },
    { key = "ChestSlot",         id = 5,  label = "Chest" },
    { key = "WaistSlot",         id = 6,  label = "Waist" },
    { key = "LegsSlot",          id = 7,  label = "Legs" },
    { key = "FeetSlot",          id = 8,  label = "Feet" },
    { key = "WristSlot",         id = 9,  label = "Wrists" },
    { key = "HandsSlot",         id = 10, label = "Hands" },
    { key = "Finger0Slot",       id = 11, label = "Ring 1",    pair = "Finger1Slot" },
    { key = "Finger1Slot",       id = 12, label = "Ring 2",    pair = "Finger0Slot" },
    { key = "Trinket0Slot",      id = 13, label = "Trinket 1", pair = "Trinket1Slot" },
    { key = "Trinket1Slot",      id = 14, label = "Trinket 2", pair = "Trinket0Slot" },
    { key = "BackSlot",          id = 15, label = "Back" },
    { key = "MainHandSlot",      id = 16, label = "Main Hand" },
    { key = "SecondaryHandSlot", id = 17, label = "Off Hand" },
    { key = "RangedSlot",        id = 18, label = "Ranged" },
    { key = "TabardSlot",        id = 19, label = "Tabard",    cosmetic = true },
}

Slots.BY_KEY, Slots.BY_ID = {}, {}
for _, s in ipairs(Slots.LIST) do
    Slots.BY_KEY[s.key] = s
    Slots.BY_ID[s.id] = s
end

-- The game's own sheet: eight down the left, eight down the right, the
-- weapons along the bottom.
Slots.LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
Slots.RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
Slots.BOTTOM = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }

-- The order upgrades are listed in (the plan, the browser's slot filter).
Slots.ORDER = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot", "HandsSlot",
    "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }

-- Where an item can go, by its equip location. A ring or trinket fits
-- either of its two slots; a one-hander the off hand too for classes that
-- dual wield (Classes.CanDualWield decides).
Slots.FOR_EQUIPLOC = {
    INVTYPE_HEAD = { "HeadSlot" },
    INVTYPE_NECK = { "NeckSlot" },
    INVTYPE_SHOULDER = { "ShoulderSlot" },
    INVTYPE_CHEST = { "ChestSlot" },
    INVTYPE_ROBE = { "ChestSlot" },
    INVTYPE_WAIST = { "WaistSlot" },
    INVTYPE_LEGS = { "LegsSlot" },
    INVTYPE_FEET = { "FeetSlot" },
    INVTYPE_WRIST = { "WristSlot" },
    INVTYPE_HAND = { "HandsSlot" },
    INVTYPE_FINGER = { "Finger0Slot", "Finger1Slot" },
    INVTYPE_TRINKET = { "Trinket0Slot", "Trinket1Slot" },
    INVTYPE_CLOAK = { "BackSlot" },
    INVTYPE_WEAPON = { "MainHandSlot", "SecondaryHandSlot" },
    INVTYPE_2HWEAPON = { "MainHandSlot" },
    INVTYPE_WEAPONMAINHAND = { "MainHandSlot" },
    INVTYPE_WEAPONOFFHAND = { "SecondaryHandSlot" },
    INVTYPE_SHIELD = { "SecondaryHandSlot" },
    INVTYPE_HOLDABLE = { "SecondaryHandSlot" },
    INVTYPE_RANGED = { "RangedSlot" },
    INVTYPE_RANGEDRIGHT = { "RangedSlot" },
    INVTYPE_THROWN = { "RangedSlot" },
    INVTYPE_RELIC = { "RangedSlot" },
}

-- The "slot" a list groups by: a ring is a ring whichever finger it's on.
Slots.GROUP = {
    Finger1Slot = "Finger0Slot",
    Trinket1Slot = "Trinket0Slot",
}

-- Fills in the client's own slot ids and empty-slot pictures.
function Slots.Init()
    for _, s in ipairs(Slots.LIST) do
        if GetInventorySlotInfo then
            local ok, id, texture = pcall(GetInventorySlotInfo, s.key)
            if ok and type(id) == "number" then
                Slots.BY_ID[s.id] = nil
                s.id = id
                Slots.BY_ID[id] = s
                s.empty = texture
            end
        end
    end
end

function Slots.Label(key)
    local s = Slots.BY_KEY[key]
    if not s then return key end
    -- Paladins, druids and shamans put a relic there.
    if key == "RangedSlot" and GP.Classes and GP.player and GP.Classes.Data().relic then return GP.L["Relic"] end
    if s.pair then return s.label:gsub(" %d$", "") end
    return s.label
end

GP.On("Loaded", Slots.Init)
