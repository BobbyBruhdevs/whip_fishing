-- ============================================================================================================
-- Tackle shops and selling fish.
-- Buying is WHIP's own shop screen (EnsureShop). WHIP has no sell-to-shop call, so selling is ours: the server
-- reads every fish the player carries, prices it from the weight in the fish's own item data (never from
-- anything the client says), takes the fish and pays once. One sale at a time per player.
-- ============================================================================================================

Shops = {}

local selling = {}   -- [source] = true while a sale is running

local function money(n) return ('%s%d'):format(Config.Economy.currency or '$', n) end

--- The nearest shop's position to the player, for SecureEvent's `near` check.
local function nearestShop(source)
    local c = Security.coords(source)
    if not c then return nil end
    local best, bestD = nil, math.huge
    for _, shop in ipairs(Config.Shops) do
        local p = vector3(shop.coords.x, shop.coords.y, shop.coords.z)
        local d = #(c - p)
        if d < bestD then best, bestD = p, d end
    end
    return best
end

--- Every sellable the player carries that this sale covers: { { item, key, stack, each, count } }, and the total.
--- Fish are priced from the weight in the item's own data; treasures at their fixed price.
---@param only string|nil one fish or treasure key, or nil for all
local function gather(source, only)
    local out, total = {}, 0
    for _, item in ipairs(FishingUtil.FishItems) do
        local key = FishingUtil.FishByItem[item]
        if not only or only == key then
            local stacks = exports.whip_core:FindAllItems(source, item)
            if type(stacks) == 'table' then
                for _, s in ipairs(stacks) do
                    local weight = type(s.metadata) == 'table' and tonumber(s.metadata.weight) or nil
                    local each = FishingUtil.sellValue(key, weight)
                    out[#out + 1] = { item = item, key = key, stack = s, each = each, count = s.amount or 1 }
                    total = total + each * (s.amount or 1)
                end
            end
        end
    end
    for _, item in ipairs(FishingUtil.TreasureItems) do
        local key = FishingUtil.TreasureByItem[item]
        if not only or only == key then
            local stacks = exports.whip_core:FindAllItems(source, item)
            if type(stacks) == 'table' then
                for _, s in ipairs(stacks) do
                    local each = Treasures[key].price
                    out[#out + 1] = { item = item, key = key, stack = s, each = each, count = s.amount or 1 }
                    total = total + each * (s.amount or 1)
                end
            end
        end
    end
    return out, total
end

--- What the player could sell, grouped by species or treasure: { groups = { { key, label, rarityLabel, count, total } }, total }
local function summary(source)
    local list, total = gather(source)
    local byKey, groups = {}, {}
    for _, e in ipairs(list) do
        local g = byKey[e.key]
        if not g then
            local tr = Treasures[e.key]
            g = tr and
                { key = e.key, label = tr.label, rarityLabel = 'Treasure', count = 0, total = 0, treasure = true } or
                { key = e.key, label = Fish[e.key].label,
                  rarityLabel = FishingUtil.RarityByKey[Fish[e.key].rarity].label, count = 0, total = 0 }
            byKey[e.key] = g
            groups[#groups + 1] = g
        end
        g.count = g.count + e.count
        g.total = g.total + e.each * e.count
    end
    table.sort(groups, function(a, b)
        -- Fish by rarity, rarest first (treasures sort after every fish), then by name
        local ra = a.treasure and 0 or (FishingUtil.RarityIndex[Fish[a.key].rarity] or 0)
        local rb = b.treasure and 0 or (FishingUtil.RarityIndex[Fish[b.key].rarity] or 0)
        if ra ~= rb then return ra > rb end
        return a.label < b.label
    end)
    return { groups = groups, total = total }
end
Shops.summary = summary

--- Sells `only` (a fish key) or everything. Returns true, count, total or false, why.
local function sell(source, player, only)
    if selling[source] then return false, 'One sale at a time' end
    selling[source] = true
    local ok, a, b, c = pcall(function()
        local list, total = gather(source, only)
        if #list == 0 or total <= 0 then return false, 'You have nothing to sell' end
        if not exports.whip_core:IsSessionCurrent(source, player.session) then return false, 'Try again' end

        -- Take every stack first, remembering what was taken so a failed payment can give it back
        local taken, count, value = {}, 0, 0
        for _, e in ipairs(list) do
            local t = exports.whip_core:StoreTake(e.stack.addr, e.count, { reason = 'sold to a tackle shop' })
            if t then
                taken[#taken + 1] = { item = e.item, amount = e.count, metadata = e.stack.metadata }
                count = count + e.count
                value = value + e.each * e.count
            end
        end
        if count == 0 then return false, 'You have nothing to sell' end

        local paid, why = exports.whip_core:PayPlayer(source, value, {
            method = Config.Economy.method or 'auto', reason = 'Sold fish to a tackle shop',
        })
        if not paid then
            for _, t in ipairs(taken) do
                exports.whip_core:AddItem(source, t.item, t.amount, t.metadata, { reason = 'sale refunded' })
            end
            return false, why or 'The shop could not pay you'
        end
        return true, count, value
    end)
    selling[source] = nil
    if not ok then
        print(('^1[whip_fishing] sale for %d failed: %s^7'):format(source, tostring(a)))
        return false, 'Something went wrong selling your fish'
    end
    return a, b, c
end

AddEventHandler('playerDropped', function() selling[source] = nil end)

-- ------------------------------------------------------------------------------------------------------------
-- The shopkeepers. The shops are ensured without an npcModel, so whip_core makes no counter of its own;
-- these are ours: the same stand behind the counter, and the one prompt at the counter (client/shops.lua).
-- ------------------------------------------------------------------------------------------------------------

local keepers = {}   -- [shop id] = npcId, so a re-registration replaces its keeper instead of doubling it

local function makeKeeper(shop)
    if not shop.npcModel then return end
    local old = keepers[shop.id]
    if old then exports.whip_core:DespawnNpc(old) end
    keepers[shop.id] = nil
    local npcId, why = exports.whip_core:SpawnNpc({
        model = shop.npcModel,
        coords = { x = shop.coords.x, y = shop.coords.y, z = shop.coords.z, heading = shop.coords.w },
        behaviour = 'stand',
        conditions = { invincible = true, canMove = false, reacts = false, flees = false },
    }, { tag = 'whip_fishing_shop_' .. shop.id, fightBack = false })
    if not npcId then
        print(('^1[whip_fishing] the keeper of %s was NOT made: %s^7'):format(shop.id, tostring(why)))
        return
    end
    keepers[shop.id] = npcId
    exports.whip_core:SetNpcState(npcId, { anim = { scenario = 'WORLD_HUMAN_STAND_IMPATIENT' } })
end

Whip.register(function()
    -- The buy side: WHIP's shop screen, one shop per spot. No npcModel: the shop has no counter of
    -- WHIP's own (no keeper, no prompt) — the keeper and the one prompt at the counter are ours,
    -- so selling and buying are a single selector instead of two prompts.
    for _, shop in ipairs(Config.Shops) do
        local catalog = {}
        for key, price in pairs(shop.catalog or {}) do catalog[Config.ItemPrefix .. key] = price end
        local made, why = Whip.core:EnsureShop('whip_fishing_' .. shop.id, {
            name = shop.name, mode = 'npc',
            x = shop.coords.x, y = shop.coords.y, z = shop.coords.z, heading = shop.coords.w,
            blipSprite = shop.blipSprite, blipColor = shop.blipColor, catalog = catalog,
        })
        if not made then
            print(('^1[whip_fishing] shop %s was NOT made: %s^7'):format(shop.id, tostring(why)))
        else
            print(('^2[whip_fishing] shop %s ready at %.1f, %.1f, %.1f^7'):format(shop.id, shop.coords.x, shop.coords.y, shop.coords.z))
        end
        makeKeeper(shop)
    end

    -- Enter the shop (WHIP's buy screen) from the tackle-shop prompt. This resource made the shops,
    -- so OpenShop takes them; it checks again that the player is close enough. Registered however the
    -- economy is set: buying is not gated on selling.
    Whip.core:SecureEvent('whip_fishing:browse', {
        rateLimit = 1000,
        params = { { 'shopId', 'key', 32 } },
    }, function(source, player, shopId)
        local shop
        for _, s in ipairs(Config.Shops) do
            if s.id == shopId then shop = s break end
        end
        if not shop then return false, 'No such shop' end
        local ok, why = exports.whip_core:OpenShop(source, { key = 'whip_fishing_' .. shopId },
            { range = Config.Economy.range or 6.0 })
        if not ok then return false, why end
    end)

    if not Config.Economy.enabled then return end
    local near = { at = nearestShop, range = Config.Economy.range or 6.0, message = 'Go to a tackle shop to sell fish' }

    -- What the player holds, for the sell menu
    Whip.core:SecureCallback('whip_fishing:sellList', { rateLimit = 800, near = near }, function(source)
        return summary(source)
    end)

    -- The sale: everything, or one species or treasure (a real key, checked)
    Whip.core:SecureEvent('whip_fishing:sell', {
        rateLimit = 1000, near = near,
        params = { { 'what', 'key', 32 } },
    }, function(source, player, what)
        local only = nil
        if what ~= 'all' then
            if not Fish[what] and not Treasures[what] then return false, 'Unknown item' end
            only = what
        end
        local ok, count, total = sell(source, player, only)
        if not ok then return false, count end
        exports.whip_core:NotifyPlayer(source, ('Sold %d items for %s'):format(count, money(total)), 'success')
    end)
end)
