-- ============================================================================================================
-- Shared lookups for both sides, built once from the config, and a check of the config that names every mistake.
-- ============================================================================================================

FishingUtil = {}

local RES = GetCurrentResourceName()

local function itemKey(key) return Config.ItemPrefix .. key end
FishingUtil.itemKey = itemKey

-- [itemKey] = configKey
FishingUtil.RodByItem, FishingUtil.BaitByItem, FishingUtil.FishByItem = {}, {}, {}
FishingUtil.RodItems, FishingUtil.BaitItems, FishingUtil.FishItems = {}, {}, {}
FishingUtil.TreasureByItem, FishingUtil.TreasureItems = {}, {}
FishingUtil.RarityIndex, FishingUtil.RarityByKey = {}, {}
FishingUtil.LocationById = {}
FishingUtil.CHEST_ITEM = itemKey('chest')

local problems = {}
local function problem(fmt, ...) problems[#problems + 1] = fmt:format(...) end

for i, r in ipairs(Config.Rarities) do
    FishingUtil.RarityIndex[r.key] = i
    FishingUtil.RarityByKey[r.key] = r
    if not tostring(r.key):match('^[a-z][a-z0-9_]*$') then problem('rarity "%s": keys are lowercase words', tostring(r.key)) end
end

for key, rod in pairs(Rods) do
    local item = itemKey(key)
    FishingUtil.RodByItem[item] = key
    FishingUtil.RodItems[#FishingUtil.RodItems + 1] = item
    if type(rod.durability) ~= 'number' or rod.durability < 1 then problem('rod %s: durability must be 1 or more', key) end
    if type(rod.reelStrength) ~= 'number' or rod.reelStrength <= 0 then problem('rod %s: reelStrength must be above 0', key) end
end
table.sort(FishingUtil.RodItems, function(a, b)
    return (Rods[FishingUtil.RodByItem[a]].tier or 0) > (Rods[FishingUtil.RodByItem[b]].tier or 0)
end)

for key, bait in pairs(Baits) do
    local item = itemKey(key)
    FishingUtil.BaitByItem[item] = key
    FishingUtil.BaitItems[#FishingUtil.BaitItems + 1] = item
    if type(bait.consumeChance) ~= 'number' or bait.consumeChance < 0 or bait.consumeChance > 1 then
        problem('bait %s: consumeChance is 0..1', key)
    end
end
table.sort(FishingUtil.BaitItems)

for key, fish in pairs(Fish) do
    local item = itemKey(key)
    FishingUtil.FishByItem[item] = key
    FishingUtil.FishItems[#FishingUtil.FishItems + 1] = item
    if not FishingUtil.RarityByKey[fish.rarity] then problem('fish %s: no rarity called "%s"', key, tostring(fish.rarity)) end
    if type(fish.minWeight) ~= 'number' or type(fish.maxWeight) ~= 'number' or fish.minWeight <= 0 or fish.maxWeight < fish.minWeight then
        problem('fish %s: minWeight and maxWeight must be above 0, max at least min', key)
    end
    for _, b in ipairs(fish.baits or {}) do if not Baits[b] then problem('fish %s: unknown bait "%s"', key, b) end end
    for _, b in ipairs(fish.preferredBait or {}) do if not Baits[b] then problem('fish %s: unknown preferred bait "%s"', key, b) end end
end
table.sort(FishingUtil.FishItems)

for key, tr in pairs(Treasures) do
    local item = itemKey(key)
    FishingUtil.TreasureByItem[item] = key
    FishingUtil.TreasureItems[#FishingUtil.TreasureItems + 1] = item
    if not tostring(key):match('^[a-z][a-z0-9_]*$') then problem('treasure "%s": keys are lowercase words', tostring(key)) end
    if Rods[key] or Baits[key] or Fish[key] then problem('treasure %s: the key is taken by a rod, a bait or a fish', key) end
    if type(tr.price) ~= 'number' or tr.price <= 0 then problem('treasure %s: price must be above 0', key) end
end
table.sort(FishingUtil.TreasureItems)

for i, shop in ipairs(Config.Shops or {}) do
    if type(shop.id) ~= 'string' or not shop.id:match('^[a-z][a-z0-9_]*$') then problem('shop #%d: id must be a lowercase word', i) end
    if type(shop.coords) ~= 'vector4' then problem('shop %s: coords must be a vector4(x, y, z, heading)', tostring(shop.id)) end
    for key, price in pairs(shop.catalog or {}) do
        local known = Rods[key] or Baits[key] or key == 'repair_kit'
        if not known then problem('shop %s: "%s" is not a rod, a bait or repair_kit', tostring(shop.id), tostring(key)) end
        if type(price) ~= 'number' or price < 0 then problem('shop %s: the price of %s must be 0 or more', tostring(shop.id), tostring(key)) end
    end
end
do
    local e = Config.Economy
    if type(e) ~= 'table' then problem('Config.Economy is missing') else
        for _, r in ipairs(Config.Rarities) do
            if type(e.base[r.key]) ~= 'number' or e.base[r.key] < 0 then problem('Config.Economy.base.%s: a price of 0 or more', r.key) end
        end
        if type(e.sizeMin) ~= 'number' or type(e.sizeMax) ~= 'number' or e.sizeMin < 0 or e.sizeMax < e.sizeMin then
            problem('Config.Economy: sizeMin and sizeMax must be 0 or more, max at least min')
        end
        if e.method ~= 'cash' and e.method ~= 'bank' and e.method ~= 'auto' then problem("Config.Economy.method must be 'cash', 'bank' or 'auto'") end
    end
end

for i, loc in ipairs(Locations) do
    if type(loc.id) ~= 'string' or not loc.id:match('^[a-z][a-z0-9_]*$') then
        problem('location #%d: id must be a lowercase word', i)
    elseif FishingUtil.LocationById[loc.id] then
        problem('location %s: the id is used twice', loc.id)
    else
        FishingUtil.LocationById[loc.id] = loc
    end
    if type(loc.radius) ~= 'number' or loc.radius <= 0 then problem('location %s: radius must be above 0', tostring(loc.id)) end
    for _, f in ipairs(loc.fish or {}) do if not Fish[f] then problem('location %s: unknown fish "%s"', loc.id, f) end end
    for _, f in ipairs(loc.extraFish or {}) do if not Fish[f] then problem('location %s: unknown fish "%s"', loc.id, f) end end
end
for key, fish in pairs(Fish) do
    for _, id in ipairs(fish.locations or {}) do
        if not FishingUtil.LocationById[id] then problem('fish %s: unknown location "%s"', key, id) end
    end
end
if not ({ cast = true, bite = true, hook = true, ['end'] = true })[Config.BaitConsumption.point] then
    problem("Config.BaitConsumption.point must be 'cast', 'bite', 'hook' or 'end'")
end

for _, r in ipairs(Config.Rarities) do
    local lvl = Config.SkillCheck and Config.SkillCheck.levels and Config.SkillCheck.levels[r.key]
    if type(lvl) ~= 'table' or not (tonumber(lvl.pieces) and tonumber(lvl.parts) and tonumber(lvl.msPerPart)) then
        problem('Config.SkillCheck.levels.%s: needs pieces, parts, widest, narrowest and msPerPart', r.key)
    end
end

do
    local c = Config.Chest
    if type(c) ~= 'table' or c.enabled ~= true then
        -- Left out or off: no chests, which is fine
        Config.Chest = { enabled = false }
    else
        if type(c.chance) ~= 'number' or c.chance < 0 or c.chance > 1 then problem('Config.Chest.chance must be 0..1') end
        if type(c.minDrops) ~= 'number' or type(c.maxDrops) ~= 'number' or c.minDrops < 1 or c.maxDrops < c.minDrops then
            problem('Config.Chest: minDrops and maxDrops must be 1 or more, max at least min')
        end
        local any = false
        for _, d in ipairs(c.drops or {}) do
            if not Treasures[d.key] then problem('Config.Chest.drops: no treasure called "%s"', tostring(d.key)) end
            if type(d.weight) ~= 'number' or d.weight <= 0 then problem('Config.Chest.drops %s: weight must be above 0', tostring(d.key)) end
            any = true
        end
        if not any then problem('Config.Chest.drops: needs at least one treasure a chest can hold') end
    end
end

for _, p in ipairs(problems) do print(('^1[%s] config: %s^7'):format(RES, p)) end
FishingUtil.configOk = #problems == 0

-- ------------------------------------------------------------------------------------------------------------
-- Small helpers
-- ------------------------------------------------------------------------------------------------------------

function FishingUtil.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- What one fish of this species and weight sells for (whole number). Weight maps onto its species' range.
---@param fishKey string
---@param weight number|nil kg, from the fish's own item data
function FishingUtil.sellValue(fishKey, weight)
    local fish, e = Fish[fishKey], Config.Economy
    if not fish then return 0 end
    local base = fish.sellValue or e.base[fish.rarity] or 0
    local span = fish.maxWeight - fish.minWeight
    local ratio = 0.5
    if type(weight) == 'number' and span > 0 then ratio = FishingUtil.clamp((weight - fish.minWeight) / span, 0.0, 1.0) end
    return math.max(0, math.floor(base * (e.sizeMin + (e.sizeMax - e.sizeMin) * ratio) + 0.5))
end

--- Is `hour` inside { from, to }? Wraps past midnight ({ from = 20, to = 4 }). nil hours: always.
function FishingUtil.inHours(hours, hour)
    if type(hours) ~= 'table' then return true end
    local from, to = tonumber(hours.from), tonumber(hours.to)
    if not from or not to then return true end
    if from == to then return true end
    if from < to then return hour >= from and hour < to end
    return hour >= from or hour < to
end

function FishingUtil.debug(fmt, ...)
    if Config.Debug then print(('[%s] ' .. fmt):format(RES, ...)) end
end
