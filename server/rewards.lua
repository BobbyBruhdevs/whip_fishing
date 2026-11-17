-- ============================================================================================================
-- Every random roll, on the server only: how long until a bite, whether it bites, which fish, how heavy, how
-- hard it fights and how much it wears the rod. The client is told the result, never asked for it.
-- ============================================================================================================

Rewards = {}

local clamp = FishingUtil.clamp

local function randRange(a, b)
    return a + math.random() * (b - a)
end

local function listHas(list, value)
    if type(list) ~= 'table' then return false end
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

local function baitBonus(loc, baitKey)
    return (loc.baitBonus and loc.baitBonus[baitKey]) or {}
end

-- ------------------------------------------------------------------------------------------------------------
-- Bites
-- ------------------------------------------------------------------------------------------------------------

--- The next wait, in ms.
function Rewards.biteWait(sess)
    local rod, bait, loc = Rods[sess.rodKey], Baits[sess.baitKey], FishingUtil.LocationById[sess.locId]
    local ms = randRange(Config.Bite.minMs, Config.Bite.maxMs)
    ms = ms * (bait.biteTimeMult or 1.0) * (loc.biteTimeMult or 1.0) * (rod.biteTimeMult or 1.0)
    return math.floor(clamp(ms, Config.Bite.floorMs, Config.Bite.ceilMs))
end

--- Does a finished wait end in a bite?
function Rewards.rollBite(sess)
    local rod, bait, loc = Rods[sess.rodKey], Baits[sess.baitKey], FishingUtil.LocationById[sess.locId]
    local chance = Config.Bite.baseChance * (bait.biteChanceMult or 1.0) * (baitBonus(loc, sess.baitKey).bite or 1.0)
    chance = clamp(chance + (rod.successBonus or 0.0), 0.02, 0.98)
    local roll = math.random()
    FishingUtil.debug('bite roll %.3f against %.3f (session %d)', roll, chance, sess.id)
    return roll <= chance
end

-- ------------------------------------------------------------------------------------------------------------
-- Which fish
-- ------------------------------------------------------------------------------------------------------------

--- Can this fish bite at this spot at all?
local function livesAt(fish, fishKey, loc)
    if loc.fish then return listHas(loc.fish, fishKey) end
    if listHas(loc.extraFish, fishKey) then return true end
    if listHas(fish.locations, loc.id) then return true end
    if fish.onlyLocations then return false end
    return listHas(fish.waters, loc.type)
end

--- Will it take this bait?
local function takesBait(fish, baitKey)
    local bait = Baits[baitKey]
    if bait.universal then return true end
    if fish.baits == nil then return true end
    return listHas(fish.baits, baitKey)
end

--- Every fish that could take this cast right now, with its weight: { { key, weight } }, and their total.
function Rewards.candidates(sess, hour)
    local rod, bait, loc = Rods[sess.rodKey], Baits[sess.baitKey], FishingUtil.LocationById[sess.locId]
    local list, total = {}, 0
    local locBait = baitBonus(loc, sess.baitKey)
    for key, fish in pairs(Fish) do
        if livesAt(fish, key, loc) and takesBait(fish, sess.baitKey) and FishingUtil.inHours(fish.hours, hour) then
            local tierIndex = FishingUtil.RarityIndex[fish.rarity] or 1
            local tier = FishingUtil.RarityByKey[fish.rarity]
            local w = (fish.chance or 1.0) * tier.weight
            w = w * ((loc.rarityMods and loc.rarityMods[fish.rarity]) or 1.0)
            w = w * ((bait.rarityMods and bait.rarityMods[fish.rarity]) or 1.0)
            w = w * (1.0 + (rod.rarityBonus or 0.0) * (tierIndex - 1) * Config.RodRarityScale)
            if tierIndex > 1 then w = w * (locBait.rarity or 1.0) end
            if listHas(fish.preferredBait, sess.baitKey) then w = w * Config.PreferredBaitMultiplier end
            if bait.fishBonus and bait.fishBonus[key] then w = w * bait.fishBonus[key] end
            if w > 0 then
                list[#list + 1] = { key = key, weight = w }
                total = total + w
            end
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)   -- the same order every time, for a fair roll
    return list, total
end

--- Picks the species. nil when nothing at this spot takes this bait now.
function Rewards.pickFish(sess, hour)
    local list, total = Rewards.candidates(sess, hour)
    if total <= 0 then return nil end
    local roll = math.random() * total
    for _, c in ipairs(list) do
        roll = roll - c.weight
        if roll <= 0 then return c.key end
    end
    return list[#list].key
end

--- The fish's weight, and where it sits in its species' range (0 = smallest, 1 = largest).
---@return number weight, number ratio
function Rewards.rollWeight(fishKey, baitKey)
    local fish, bait = Fish[fishKey], Baits[baitKey]
    local exponent = Config.Weight.exponent / (1.0 + (bait.bigFishBonus or 0.0))
    local ratio = math.random() ^ exponent
    local weight = fish.minWeight + (fish.maxWeight - fish.minWeight) * ratio
    local mult = 10 ^ Config.Weight.decimals
    weight = math.floor(weight * mult + 0.5) / mult
    return weight, ratio
end

-- ------------------------------------------------------------------------------------------------------------
-- The fight
-- ------------------------------------------------------------------------------------------------------------

--- The ring WHIP's SkillCheck plays for this fish: its rarity's level, more time with a stronger rod, one more
--- part for a big one. A WhipSkillLevel table: { pieces, parts, widest, narrowest, msPerPart }.
function Rewards.ringLevel(fishKey, ratio, rodKey)
    local fish, rod = Fish[fishKey], Rods[rodKey]
    local base = Config.SkillCheck.levels[fish.rarity] or Config.SkillCheck.levels.common
    local lvl = { pieces = base.pieces, parts = base.parts, widest = base.widest, narrowest = base.narrowest,
        msPerPart = math.floor(base.msPerPart * (rod.reelStrength or 1.0)) }
    local big = Config.SkillCheck.bigFishExtraPart
    if big and ratio >= big then lvl.parts = lvl.parts + 1 end
    -- A better rod keeps the last parts wider (difficultyModifier 0.08+ widens the narrowest part by one)
    lvl.narrowest = math.min(lvl.widest, lvl.narrowest + math.floor((rod.difficultyModifier or 0.0) * 12 + 0.5))
    return lvl
end

--- Rod wear for landing this fish.
function Rewards.catchWear(fishKey)
    local tier = FishingUtil.RarityByKey[Fish[fishKey].rarity]
    return tier.wear or 1
end

--- On a lost fight: did the line snap (extra wear)?
function Rewards.rollSnap()
    return math.random() <= (Config.Durability.snapChance or 0.0)
end

-- ------------------------------------------------------------------------------------------------------------
-- Sunken chests
-- ------------------------------------------------------------------------------------------------------------

--- Did this landed catch come up as a chest instead of a fish?
function Rewards.rollChest(sess)
    local c = Config.Chest
    if not c.enabled or c.chance <= 0 then return false end
    local loc = FishingUtil.LocationById[sess.locId]
    local chance = (loc and loc.chestChance) or c.chance
    return chance > 0 and math.random() <= chance
end

--- What a chest gives up: the keys of Treasures, `minDrops` to `maxDrops` of them, drawn by weight.
---@return string[] keys
function Rewards.rollChestContents()
    local c = Config.Chest
    local n = math.random(math.floor(c.minDrops or 1), math.floor(c.maxDrops or c.minDrops or 1))
    local out = {}
    for _ = 1, n do
        local total = 0
        for _, d in ipairs(c.drops) do total = total + d.weight end
        local roll = math.random() * total
        for _, d in ipairs(c.drops) do
            roll = roll - d.weight
            if roll <= 0 then
                out[#out + 1] = d.key
                break
            end
        end
    end
    return out
end

--- Small, Medium or Large: all the player is told while fighting. The species, rarity and weight are a surprise
--- until the fish is landed.
function Rewards.sizeClass(ratio)
    if ratio >= 0.67 then return 'Large' end
    if ratio >= 0.34 then return 'Medium' end
    return 'Small'
end
