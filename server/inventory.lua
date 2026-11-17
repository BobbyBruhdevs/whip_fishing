-- ============================================================================================================
-- Items: rods, bait, fish and the repair kit, registered with WHIP's inventory (inside Whip.register, see
-- server/main.lua), plus the helpers the session uses to find the rod, wear it and take bait.
-- No other inventory is touched: every call is whip_core's.
-- ============================================================================================================

Inventory = {}

local REPAIR_KIT = Config.ItemPrefix .. 'repair_kit'
Inventory.REPAIR_KIT = REPAIR_KIT

local function rodCondition(durability, max)
    return ('%d / %d'):format(math.max(0, math.floor(durability)), math.floor(max))
end

--- A short random id for one rod, so the session can find the same rod again after the player moves it.
local function newRodId()
    return ('%08x%04x'):format(math.random(0, 0x7fffffff), math.random(0, 0xffff))
end

--- The rod's durability and maximum from its metadata (an older rod without them counts as new).
function Inventory.rodState(rodKey, metadata)
    local rod = Rods[rodKey]
    local max = tonumber(metadata and metadata.maxDurability) or rod.durability
    local dur = tonumber(metadata and metadata.durability)
    if dur == nil then dur = max end
    return dur, max
end

-- ------------------------------------------------------------------------------------------------------------
-- Registration (called from Whip.register in server/main.lua)
-- ------------------------------------------------------------------------------------------------------------

function Inventory.registerItems()
    for key, rod in pairs(Rods) do
        local item = FishingUtil.itemKey(key)
        Whip.core:RegisterItem(item, {
            name = rod.label,
            desc = rod.desc,
            weight = rod.weight or 1.0,
            type = 'tool',
            stack = false,
            maxStack = 1,
            usable = true,
            cooldown = 2,
            grab = '2h',
            metaFields = { { key = 'condition', label = 'Condition' } },
        })
        -- Every new rod starts at full durability with its own id (given, bought, picked up).
        Whip.core:RegisterItemDefaultMetadata(item, function()
            return {
                durability = rod.durability,
                maxDurability = rod.durability,
                condition = rodCondition(rod.durability, rod.durability),
                rodId = newRodId(),
            }
        end)
    end

    for key, bait in pairs(Baits) do
        local item = FishingUtil.itemKey(key)
        Whip.core:RegisterItem(item, {
            name = bait.label,
            desc = bait.desc .. ' Use it to fish with it next.',
            weight = bait.weight or 0.02,
            type = 'bait',
            stack = true,
            maxStack = bait.maxStack or 50,
            usable = true,   -- "Use" picks it as the bait for the next cast (it is kept)
            cooldown = 1,
        })
    end

    for key, fish in pairs(Fish) do
        local item = FishingUtil.itemKey(key)
        local rarity = FishingUtil.RarityByKey[fish.rarity]
        Whip.core:RegisterItem(item, {
            name = fish.label,
            desc = ('%s %s'):format(rarity and ('[' .. rarity.label .. ']') or '', fish.desc or ''),
            weight = fish.itemWeight or 1.0,
            type = 'fish',
            -- Every fish carries its own rolled weight, so each one keeps its own slot
            stack = false,
            maxStack = 1,
            metaFields = {
                { key = 'weightLabel', label = 'Weight' },
                { key = 'rarityLabel', label = 'Rarity' },
                { key = 'spot', label = 'Caught at' },
                { key = 'angler', label = 'Angler' },
            },
        })
    end

    if Config.RepairKit.enabled then
        Whip.core:RegisterItem(REPAIR_KIT, {
            name = 'Rod Repair Kit',
            desc = ('Line, ferrules and reel grease. Restores %d durability to your most worn rod.'):format(Config.RepairKit.restore),
            weight = 0.4,
            type = 'tool',
            stack = true,
            maxStack = 5,
            usable = true,
            cooldown = 3,
        })
    end

    -- The sunken chest a lucky cast can land
    if Config.Chest.enabled then
        Whip.core:RegisterItem(FishingUtil.CHEST_ITEM, {
            name = 'Sunken Chest',
            desc = 'A barnacled chest, dripping seawater. Use it to pry it open.',
            weight = 8.0,
            type = 'treasure',
            stack = true,
            maxStack = 5,
            usable = true,
            cooldown = 3,
            metaFields = {
                { key = 'spot', label = 'Fished up at' },
                { key = 'angler', label = 'Angler' },
            },
        })
    end

    -- What a chest holds: rare items, sold at a tackle shop
    for key, tr in pairs(Treasures) do
        Whip.core:RegisterItem(FishingUtil.itemKey(key), {
            name = tr.label,
            desc = ('%s Sell it at a tackle shop.'):format(tr.desc or 'A rare find from the deep.'),
            weight = tr.weight or 0.3,
            type = 'treasure',
            stack = true,
            maxStack = 20,
        })
    end
end

-- ------------------------------------------------------------------------------------------------------------
-- Rods
-- ------------------------------------------------------------------------------------------------------------

--- Makes sure a rod has durability and an id in its metadata (rods made before this resource, or by an admin).
---@return table metadata  the rod's metadata as it is now
function Inventory.ensureRodMetadata(rodKey, addr, metadata)
    metadata = type(metadata) == 'table' and metadata or {}
    if metadata.rodId and metadata.durability and metadata.maxDurability then return metadata end
    local dur, max = Inventory.rodState(rodKey, metadata)
    local patch = {
        durability = dur, maxDurability = max, condition = rodCondition(dur, max),
        rodId = metadata.rodId or newRodId(),
    }
    exports.whip_core:SetItemMetadata(addr, patch)
    for k, v in pairs(patch) do metadata[k] = v end
    return metadata
end

--- Finds the session's rod in the player's pockets again: by its id, wherever it was moved to.
---@return table|nil found { item, amount, metadata, addr }
function Inventory.findRod(source, sess)
    local stacks = exports.whip_core:FindAllItems(source, sess.rodItem)
    if type(stacks) ~= 'table' then return nil end
    for _, s in ipairs(stacks) do
        if type(s.metadata) == 'table' and s.metadata.rodId == sess.rodId then return s end
    end
    return nil
end

--- The best usable rod the player carries (highest tier with durability left), for the F1 wheel.
---@return table|nil found, string|nil rodKey
function Inventory.bestRod(source)
    for _, item in ipairs(FishingUtil.RodItems) do   -- sorted best tier first
        local key = FishingUtil.RodByItem[item]
        local stacks = exports.whip_core:FindAllItems(source, item)
        if type(stacks) == 'table' then
            for _, s in ipairs(stacks) do
                local dur = Inventory.rodState(key, s.metadata)
                if dur > 0 then return s, key end
            end
        end
    end
    return nil, nil
end

--- Takes `amount` durability off a rod. A rod at 0 is kept or destroyed by Config.Durability.breakBehaviour.
---@return number left, boolean broken
function Inventory.wearRod(source, sess, amount)
    if not Config.Durability.enabled or amount <= 0 then return -1, false end
    local found = Inventory.findRod(source, sess)
    if not found then return -1, false end
    local dur, max = Inventory.rodState(sess.rodKey, found.metadata)
    local left = math.max(0, dur - amount)
    if left <= 0 and Config.Durability.breakBehaviour == 'remove' then
        exports.whip_core:StoreTake(found.addr, 1, { reason = 'fishing rod broke' })
        return 0, true
    end
    exports.whip_core:SetItemMetadata(found.addr, { durability = left, condition = rodCondition(left, max) })
    return left, left <= 0
end

-- ------------------------------------------------------------------------------------------------------------
-- Bait
-- ------------------------------------------------------------------------------------------------------------

--- Every bait the player carries: { [baitKey] = count }, and whether there is any.
function Inventory.baitCounts(source)
    local out, any = {}, false
    for _, item in ipairs(FishingUtil.BaitItems) do
        local n = tonumber((exports.whip_core:GetItemCount(source, item))) or 0
        if n > 0 then
            out[FishingUtil.BaitByItem[item]] = n
            any = true
        end
    end
    return out, any
end

--- Rolls and takes one bait. The player must still carry it: if not, the attempt is lost.
---@return boolean ok, boolean|string consumedOrWhy
function Inventory.consumeBait(source, sess)
    if not exports.whip_core:HasItem(source, sess.baitItem, 1) then
        return false, 'Your bait is gone'
    end
    local bait = Baits[sess.baitKey]
    if math.random() <= (bait.consumeChance or 1.0) then
        local ok, why = exports.whip_core:RemoveItem(source, sess.baitItem, 1, nil, { reason = 'used as fishing bait' })
        if not ok then return false, why or 'Your bait is gone' end
        return true, true
    end
    return true, false
end

-- ------------------------------------------------------------------------------------------------------------
-- Fish
-- ------------------------------------------------------------------------------------------------------------

--- Gives the caught fish with its server-rolled weight. AddItem drops it at their feet if the pockets are full,
--- which still counts as given.
---@return string|false where, string|nil why
function Inventory.giveFish(source, player, sess)
    local fish = Fish[sess.fishKey]
    local rarity = FishingUtil.RarityByKey[fish.rarity]
    local loc = FishingUtil.LocationById[sess.locId]
    local metadata = {
        weight = sess.weight,
        weightLabel = ('%.' .. Config.Weight.decimals .. 'f kg'):format(sess.weight),
        rarity = fish.rarity,
        rarityLabel = rarity.label,
        spot = loc and loc.label or nil,
        angler = player and player.fullName or nil,
        caughtAt = os.time(),
    }
    return exports.whip_core:AddItem(source, FishingUtil.itemKey(sess.fishKey), 1, metadata, { reason = 'caught fishing' })
end

--- Gives the sunken chest a lucky cast landed.
---@return string|false where, string|nil why
function Inventory.giveChest(source, player, sess)
    local loc = FishingUtil.LocationById[sess.locId]
    local metadata = {
        spot = loc and loc.label or nil,
        angler = player and player.fullName or nil,
        foundAt = os.time(),
    }
    return exports.whip_core:AddItem(source, FishingUtil.CHEST_ITEM, 1, metadata, { reason = 'fished up a chest' })
end

--- A chest gives up its treasures: the server's weighted roll, given one by one.
---@return number count, table|nil given  { [treasureKey] = how many }, string|nil why
function Inventory.openChest(source)
    local keys, count, given = Rewards.rollChestContents(), 0, {}
    for _, key in ipairs(keys) do
        local tr = Treasures[key]
        if tr then
            local ok = exports.whip_core:AddItem(source, FishingUtil.itemKey(key), 1, nil,
                { reason = 'opened a sunken chest' })
            if ok then
                count = count + 1
                given[key] = (given[key] or 0) + 1
            end
        end
    end
    if count == 0 then return 0, nil, 'The chest was empty' end
    return count, given
end
