-- ============================================================================================================
-- Declarations (Whip.register, so they come back after a whip_core restart) and cleanup when a player dies, logs
-- out or leaves. Reeling in is WHIP's own skill check (server/fishing.lua), so there is no game to register.
-- ============================================================================================================

local function mostWornRod(source)
    local best, bestKey, bestMissing = nil, nil, 0
    for _, item in ipairs(FishingUtil.RodItems) do
        local key = FishingUtil.RodByItem[item]
        local stacks = exports.whip_core:FindAllItems(source, item)
        if type(stacks) == 'table' then
            for _, s in ipairs(stacks) do
                local dur, max = Inventory.rodState(key, s.metadata)
                local missing = max - dur
                if missing > bestMissing then best, bestKey, bestMissing = s, key, missing end
            end
        end
    end
    return best, bestKey
end

Whip.register(function()
    if not FishingUtil.configOk then
        Whip.startProblem('the config has problems (listed above): fix them and restart')
    end

    -- Items ---------------------------------------------------------------------------------------------------
    Inventory.registerItems()

    -- Use on a rod: start fishing. The rod is kept (return false); a refusal tells them why.
    for _, item in ipairs(FishingUtil.RodItems) do
        Whip.core:RegisterUseHandler(item, function(source, player, slotData, addr)
            local ok, why = Fishing.prepare(source, player, item, slotData, addr)
            if not ok then return false, why end
            return false
        end)
    end

    -- Use on a bait: it becomes the bait for the next cast. Kept.
    for _, item in ipairs(FishingUtil.BaitItems) do
        local baitKey = FishingUtil.BaitByItem[item]
        Whip.core:RegisterUseHandler(item, function(source)
            TriggerClientEvent('whip_fishing:client:setBait', source, baitKey)
            exports.whip_core:NotifyPlayer(source, ('%s is on your hook for the next cast'):format(Baits[baitKey].label), 'success')
            return false
        end)
    end

    -- The repair kit: a server-timed bar, then durability back on the most worn rod
    if Config.RepairKit.enabled then
        Whip.core:RegisterUseHandler(Inventory.REPAIR_KIT, {
            label = 'Repairing your rod...',
            duration = Config.RepairKit.duration,
            anim = Config.RepairKit.anim,
            icon = 'devtools',
            canUse = function(source)
                if Security.get(source) then return false, 'Reel in first' end
                if not mostWornRod(source) then return false, 'None of your rods need repairing' end
                return true
            end,
            onComplete = function(source)
                local rod, key = mostWornRod(source)
                if not rod then return false, 'None of your rods need repairing' end
                local dur, max = Inventory.rodState(key, rod.metadata)
                local now = math.min(max, dur + Config.RepairKit.restore)
                local ok, why = exports.whip_core:SetItemMetadata(rod.addr, {
                    durability = now, maxDurability = max, condition = ('%d / %d'):format(now, max),
                })
                if not ok then return false, why end
                exports.whip_core:NotifyPlayer(source, ('%s repaired (%d / %d)'):format(Rods[key].label, now, max), 'success')
                return true
            end,
        })
    end

    -- A sunken chest: a server-timed bar, then the treasures inside (whip takes the chest itself,
    -- and a `false, why` here gives it back)
    if Config.Chest.enabled then
        Whip.core:RegisterUseHandler(FishingUtil.CHEST_ITEM, {
            label = 'Prying the chest open...',
            duration = Config.Chest.openMs or 3500,
            anim = Config.Chest.anim,
            icon = 'pickup',
            onComplete = function(source)
                local count, given, why = Inventory.openChest(source)
                if count <= 0 then
                    return false, why or 'The chest was empty'
                end
                local names = {}
                for key, n in pairs(given) do
                    names[#names + 1] = ('%s x%d'):format(Treasures[key].label, n)
                end
                table.sort(names)
                exports.whip_core:NotifyPlayer(source,
                    ('Inside: %s. Sell it at a tackle shop.'):format(table.concat(names, ', ')), 'success', 9000)
                FishingUtil.debug('chest opened by %d: %d treasures', source, count)
                return true
            end,
        })
    end

    -- Client requests -----------------------------------------------------------------------------------------
    -- Every one is a SecureEvent or SecureCallback: loaded, alive (unless said), rate limited, values checked.

    -- "Go fishing" on the F1 wheel: the best usable rod they carry
    Whip.core:SecureEvent('whip_fishing:start', { rateLimit = 2000 }, function(source, player)
        local rod = Inventory.bestRod(source)
        if not rod then return false, 'You need a fishing rod that isn\'t broken' end
        local ok, why = Fishing.prepare(source, player, rod.item, rod, rod.addr)
        if not ok then return false, why end
    end)

    -- The cast: which rod (a slot they own, holding a rod), which bait, where the line landed
    Whip.core:SecureCallback('whip_fishing:cast', {
        rateLimit = Config.Cooldown.castRateMs,
        params = {
            { 'rod', 'slot', { item = FishingUtil.RodItems } },
            { 'bait', 'enum', FishingUtil.BaitItems },
            { 'water', 'record', {
                { 'x', 'number', -20000, 20000 },
                { 'y', 'number', -20000, 20000 },
                { 'z', 'number', -1000, 3000 },
            } },
        },
    }, function(source, player, rod, bait, water)
        return Fishing.cast(source, player, rod, bait, water)
    end)

    -- The strike. The whole fight runs in this handler (SkillCheck waits), so one at a time: burst 1.
    Whip.core:SecureEvent('whip_fishing:hook', { rateLimit = 400, burst = 1 }, function(source, player)
        return Fishing.hook(source, player)
    end)

    -- Reeling in by choice. Allowed while down, so a death never leaves a line in the water.
    Whip.core:SecureEvent('whip_fishing:cancel', { rateLimit = 500, burst = 3, whileDead = true }, function(source)
        Fishing.cancel(source)
    end)

    -- What bites at a spot (the info prompt)
    Whip.core:SecureCallback('whip_fishing:spotInfo', {
        rateLimit = 1000,
        params = { { 'id', 'key', 32 } },
    }, function(source, player, id)
        return Fishing.spotInfo(source, id)
    end)

    -- The server's active WHIP theme, so the fishing page wears the same skin as WHIP's own screens
    Whip.core:SecureCallback('whip_fishing:theme', { rateLimit = 2000 }, function()
        local theme = exports.whip_core:GetActiveTheme()
        if type(theme) == 'string' and theme:match('^[%w_%-]+$') and GetResourceState(theme) == 'started' then return theme end
        return false
    end)

    -- Blips --------------------------------------------------------------------------------------------------
    if Config.UI.blips then
        for _, loc in ipairs(Locations) do
            if loc.blip then
                local b = type(loc.blip) == 'table' and loc.blip or Config.Blip
                Whip.core:ShowBlip('everyone', 'whip_fishing_' .. loc.id, {
                    coords = loc.coords, label = 'Fishing: ' .. loc.label,
                    sprite = b.sprite or Config.Blip.sprite, color = b.color or Config.Blip.color,
                    scale = b.scale or Config.Blip.scale, shortRange = true,
                })
            end
        end
    end
end)

-- Cleanup ----------------------------------------------------------------------------------------------------
-- Any resource can fire whip_core's events on the server, so only whip_core's own are believed.

AddEventHandler('whip_core:player:logout', function(e)
    if GetInvokingResource() ~= 'whip_core' or type(e) ~= 'table' then return end
    Fishing.drop(e.source, 'logout')
end)

AddEventHandler('whip_core:player:died', function(e)
    if GetInvokingResource() ~= 'whip_core' or type(e) ~= 'table' then return end
    Fishing.drop(e.source, 'died')
end)

AddEventHandler('playerDropped', function()
    Fishing.drop(source, 'left')
end)

-- Our props and blips go with the resource (whip_core sweeps them); nothing else is held.

Whip.sayStarted()
