-- ============================================================================================================
-- The fishing session, start to finish, on the server.
--
--   prepare  (Use on a rod, or "Go fishing" on the F1 wheel): may they fish here, now, with this rod?
--            The client is told to choose a bait and cast.
--   cast     (SecureCallback): the rod slot, the bait and where the line landed, all checked. The session
--            opens, the rod goes in their hand for everyone (HoldProps), and the first wait is rolled.
--   bite     (timer): the bite chance is rolled; a bite gives them Config.Bite.hookWindowMs to strike.
--   hook     (SecureEvent): the strike. The species, weight and fight are rolled here, then the reel-in game
--            plays through whip_core's SkillCheck (token, floor and timeout kept by whip_core).
--   finish   the fish is given, the rod worn, the cooldown started. Exactly once per session.
--
-- The client never names a fish, a weight or an amount. Bait is taken only at Config.BaitConsumption.point.
-- ============================================================================================================

Fishing = {}

local Cfg = Config

local function notify(source, text, kind)
    exports.whip_core:NotifyPlayer(source, text, kind or 'info')
end

local function slotRef(addr)
    if type(addr) ~= 'table' then return nil end
    if addr.sub == nil or addr.sub == 'player' then return addr.slot end
    return { sub = addr.sub, slot = addr.slot }
end

local function rodProps(rodKey)
    local rod = Rods[rodKey]
    local p = rod.prop or {}
    local base = Cfg.RodProp
    return { {
        model = p.model or base.model,
        bone = p.bone or base.bone,
        offset = p.offset or base.offset,
        rot = p.rot or base.rot,
    } }
end

--- Ends a session once: props down, cooldown on, the client told.
---@param outcome string 'caught'|'lost'|'cancelled'|'nothing'|'error'
local function finish(source, sess, outcome, message, kind)
    local cooldown = Cfg.Cooldown.afterLossMs
    if outcome == 'caught' then cooldown = Cfg.Cooldown.afterCatchMs
    elseif outcome == 'cancelled' then cooldown = Cfg.Cooldown.afterCancelMs end
    if not Security.close(source, sess, cooldown) then return false end
    exports.whip_core:DropHeldProps(source, 'rod')
    TriggerClientEvent('whip_fishing:client:ended', source, { session = sess.id, outcome = outcome, message = message, kind = kind })
    FishingUtil.debug('session %d for %d ended: %s', sess.id, source, outcome)
    return true
end
Fishing.finish = finish

--- Takes the bait if the attempt has reached Config.BaitConsumption.point. false: the attempt is lost.
local function consumeAt(source, sess, point)
    if sess.baitTaken or Cfg.BaitConsumption.point ~= point then return true end
    sess.baitTaken = true
    local ok, consumed = Inventory.consumeBait(source, sess)
    if not ok then
        finish(source, sess, 'lost', consumed, 'error')
        return false
    end
    sess.baitConsumed = consumed == true
    return true
end

-- ------------------------------------------------------------------------------------------------------------
-- prepare: from Use on a rod, or from the F1 wheel
-- ------------------------------------------------------------------------------------------------------------

--- May this player start fishing with this rod here and now? Tells the client to choose bait and cast.
---@return boolean ok, string|nil why
function Fishing.prepare(source, player, rodItem, slotData, addr)
    local rodKey = FishingUtil.RodByItem[rodItem]
    if not rodKey then return false, 'That is not a fishing rod' end
    if Security.get(source) then return false, 'You are already fishing' end
    if player.isDead then return false, 'You can\'t fish right now' end

    local left = Security.cooldownLeft(player.charId)
    if left > 0 then return false, ('Rest your arms for %d more seconds'):format(math.ceil(left / 1000)) end

    local dur = Inventory.rodState(rodKey, slotData.metadata)
    if dur <= 0 then return false, 'This rod is broken. Repair it first' end

    if Security.inVehicle(source) then return false, 'You can\'t fish from a vehicle' end
    local coords = Security.coords(source)
    local loc = Security.locationAt(coords)
    if not loc then return false, 'This is not a fishing spot' end
    local open, why = Security.locationOpen(loc)
    if not open then return false, why end

    local baits, any = Inventory.baitCounts(source)
    if not any then return false, 'You need bait to fish' end

    TriggerClientEvent('whip_fishing:client:begin', source, {
        rod = rodKey,
        slot = slotRef(addr),
        location = { id = loc.id, label = loc.label },
        baits = baits,
    })
    return true
end

-- ------------------------------------------------------------------------------------------------------------
-- cast
-- ------------------------------------------------------------------------------------------------------------

local scheduleWait

---@param rod table   the SecureCallback's checked slot: { addr, item, amount, metadata }
---@param baitItem string  a bait item key (checked against the list)
---@param water table  { x, y, z } where the client found the surface
function Fishing.cast(source, player, rod, baitItem, water)
    if Security.get(source) then return false, 'You are already fishing' end
    local rodKey = FishingUtil.RodByItem[rod.item]
    local baitKey = FishingUtil.BaitByItem[baitItem]
    if not rodKey or not baitKey then return false, 'You need a rod and bait' end

    local left = Security.cooldownLeft(player.charId)
    if left > 0 then return false, ('Rest your arms for %d more seconds'):format(math.ceil(left / 1000)) end
    if Security.inVehicle(source) then return false, 'You can\'t fish from a vehicle' end

    local coords = Security.coords(source)
    local loc = Security.locationAt(coords)
    if not loc then return false, 'This is not a fishing spot' end
    local open, closedWhy = Security.locationOpen(loc)
    if not open then return false, closedWhy end
    local landed, landWhy = Security.checkLanding(coords, water, loc)
    if not landed then return false, landWhy end

    if not exports.whip_core:HasItem(source, baitItem, 1) then return false, 'You have none of that bait' end

    -- Held now, before anything waits: a second cast is refused while this one is set up
    local sess, why = Security.open(source, player, {
        rodItem = rod.item, rodKey = rodKey, baitItem = baitItem, baitKey = baitKey,
        locId = loc.id, water = vector3(water.x, water.y, water.z), whipSession = player.session,
    })
    if not sess then return false, why end

    local metadata = Inventory.ensureRodMetadata(rodKey, rod.addr, rod.metadata)
    local dur, max = Inventory.rodState(rodKey, metadata)
    if dur <= 0 then
        Security.close(source, sess, 0)
        return false, 'This rod is broken. Repair it first'
    end
    sess.rodId = metadata.rodId

    -- Still the same character after the metadata write?
    if not Security.isLive(source, sess) or not exports.whip_core:IsSessionCurrent(source, player.session) then
        Security.close(source, sess, 0)
        return false
    end

    if not consumeAt(source, sess, 'cast') then return false, 'Your bait is gone' end

    exports.whip_core:HoldProps(source, rodProps(rodKey), 'rod')
    local rope = Line and Line.attach(source, sess, sess.water) or false
    sess.phase = 'waiting'
    scheduleWait(source, sess, Rewards.biteWait(sess))

    return {
        session = sess.id,
        rod = { key = rodKey, label = Rods[rodKey].label, durability = dur, max = max },
        bait = { key = baitKey, label = Baits[baitKey].label, left = (tonumber((exports.whip_core:GetItemCount(source, baitItem))) or 0) },
        location = { id = loc.id, label = loc.label },
        hookWindowMs = Cfg.Bite.hookWindowMs,
        rope = rope,   -- whip_rope draws the line: the client doesn't
    }
end

-- ------------------------------------------------------------------------------------------------------------
-- waiting and bites (server timers)
-- ------------------------------------------------------------------------------------------------------------

local onWaitDone

--- After any wait: still this attempt, and still the same WHIP character session?
local function stillCurrent(source, sess)
    return Security.isLive(source, sess) and exports.whip_core:IsSessionCurrent(source, sess.whipSession) == true
end

scheduleWait = function(source, sess, ms)
    sess.gen = sess.gen + 1
    local gen = sess.gen
    sess.phase = 'waiting'
    SetTimeout(ms, function() onWaitDone(source, sess, gen) end)
end

local function sessionTooLong(sess)
    return GetGameTimer() - sess.startedAt > Cfg.Cooldown.sessionMaxMs
end

onWaitDone = function(source, sess, gen)
    if not stillCurrent(source, sess) or sess.gen ~= gen or sess.phase ~= 'waiting' then return end
    if sessionTooLong(sess) then
        return finish(source, sess, 'nothing', 'The fish have stopped biting here for now', 'info')
    end

    sess.waits = sess.waits + 1
    if not Rewards.rollBite(sess) then
        if sess.waits >= Cfg.Bite.maxWaits then
            return finish(source, sess, 'nothing', 'Nothing is biting. Try another bait or spot', 'info')
        end
        TriggerClientEvent('whip_fishing:client:nibble', source, { session = sess.id })
        return scheduleWait(source, sess, Rewards.biteWait(sess))
    end

    -- A bite. The species is rolled at the strike, so a missed bite costs nothing but time.
    sess.bites = sess.bites + 1
    if not consumeAt(source, sess, 'bite') then return end
    sess.phase = 'bite'
    sess.biteAt = GetGameTimer()
    sess.gen = sess.gen + 1
    local biteGen = sess.gen
    TriggerClientEvent('whip_fishing:client:bite', source, { session = sess.id, windowMs = Cfg.Bite.hookWindowMs })

    SetTimeout(Cfg.Bite.hookWindowMs + 250, function()
        if not stillCurrent(source, sess) or sess.gen ~= biteGen or sess.phase ~= 'bite' then return end
        if sess.bites >= Cfg.Bite.maxBites then
            return finish(source, sess, 'lost', 'The fish lost interest', 'info')
        end
        TriggerClientEvent('whip_fishing:client:biteMissed', source, { session = sess.id })
        scheduleWait(source, sess, math.random(Cfg.Bite.rebiteMs[1], Cfg.Bite.rebiteMs[2]))
    end)
end

-- ------------------------------------------------------------------------------------------------------------
-- hook: the strike, and the fight
-- ------------------------------------------------------------------------------------------------------------

--- The strike. Runs the whole fight inside the SecureEvent handler, as WHIP asks for a SkillCheck.
function Fishing.hook(source, player)
    local sess = Security.get(source)
    if not sess then return Security.reject('whip_fishing:hook', source, 'no fishing session') end

    if sess.phase == 'waiting' then
        -- Struck with nothing on the line: the fish are spooked, the wait starts again a little longer
        local extra = math.random(Cfg.Bite.earlyStrikeDelay[1], Cfg.Bite.earlyStrikeDelay[2])
        scheduleWait(source, sess, Rewards.biteWait(sess) + extra)
        TriggerClientEvent('whip_fishing:client:spooked', source, { session = sess.id })
        return false, 'Nothing on the line yet. You spooked the fish'
    end
    if sess.phase ~= 'bite' then
        return Security.reject('whip_fishing:hook', source, 'strike out of phase: ' .. tostring(sess.phase))
    end

    local reaction = GetGameTimer() - (sess.biteAt or 0)
    if reaction < Cfg.Bite.minReactionMs then
        Security.reject('whip_fishing:hook', source, ('strike %d ms after the bite'):format(reaction))
        return finish(source, sess, 'lost', 'You struck too early and the fish got away', 'error')
    end
    if reaction > Cfg.Bite.hookWindowMs + 400 then
        return false, 'Too late, it let go'
    end

    -- The fight begins: this handler holds the session until the end
    sess.phase = 'fighting'
    sess.gen = sess.gen + 1
    local release = function()
        if Security.isLive(source, sess) then finish(source, sess, 'error', 'The line went slack', 'error') end
    end
    exports.whip_core:TrackInvocationLock(release, 'whip_fishing:hook', source)

    if not consumeAt(source, sess, 'hook') then return end
    if not Inventory.findRod(source, sess) then
        return finish(source, sess, 'lost', 'You no longer have your rod', 'error')
    end

    local hour = Security.hour()
    local fishKey = Rewards.pickFish(sess, hour)
    if not fishKey then
        return finish(source, sess, 'nothing', 'Whatever it was spat out the hook', 'info')
    end
    local weight, ratio = Rewards.rollWeight(fishKey, sess.baitKey)
    sess.fishKey, sess.weight, sess.ratio = fishKey, weight, ratio
    local level = Rewards.ringLevel(fishKey, ratio, sess.rodKey)
    local fish = Fish[fishKey]
    local tier = FishingUtil.RarityByKey[fish.rarity]
    FishingUtil.debug('session %d: %s %.2f kg (ratio %.2f, ring %d parts)', sess.id, fishKey, weight, ratio, level.parts)

    -- What the fight shows: only Small, Medium or Large. The species, rarity and weight are revealed on landing.
    TriggerClientEvent('whip_fishing:client:fight', source, {
        session = sess.id,
        size = Rewards.sizeClass(ratio),
    })

    -- WHIP's ring, with its own token, minimum time and timeout
    local passed, why = exports.whip_core:SkillCheck(source, { level = level })

    -- The fight took time: still this session, still this character?
    if not Security.isLive(source, sess) then return end
    if not exports.whip_core:IsSessionCurrent(source, player.session) then
        Security.close(source, sess, Cfg.Cooldown.afterLossMs)
        return
    end

    if not passed then
        if why == 'too fast' then
            Security.reject('whip_fishing:hook', source, 'skill check answered faster than possible')
        end
        if Cfg.BaitConsumption.point == 'end' and Cfg.BaitConsumption.onEscape then
            if not consumeAt(source, sess, 'end') then return end
        end
        local snapped = why == 'failed' and Rewards.rollSnap()
        if snapped then Inventory.wearRod(source, sess, Cfg.Durability.snapWear) end
        local message = (why == 'cancelled' and 'You let the fish go')
            or (why == 'busy' and 'Finish what you are doing first')
            or (why == 'dead' and 'The fish got away')
            or (snapped and 'Your line snapped!')
            or 'The fish got away'
        TriggerClientEvent('whip_fishing:client:result', source, {
            session = sess.id, success = false, snapped = snapped == true, reason = why,
            size = Rewards.sizeClass(ratio),   -- what got away stays a mystery: no species, no rarity
        })
        finish(source, sess, why == 'cancelled' and 'cancelled' or 'lost', message, 'error')
        return
    end

    -- Landed. The rod must still be theirs (no handing it to a friend mid-fight), then the bait, then the catch.
    if not Inventory.findRod(source, sess) then
        return finish(source, sess, 'lost', 'You no longer have your rod', 'error')
    end
    if not consumeAt(source, sess, 'end') then return end

    -- A lucky cast can bring up a sunken chest instead of a fish: same fight, a different prize
    if Config.Chest.enabled and Rewards.rollChest(sess) then
        local where, giveWhy = Inventory.giveChest(source, player, sess)
        if not where then
            print(('^1[whip_fishing] could not give a chest to %d: %s^7'):format(source, tostring(giveWhy)))
            return finish(source, sess, 'error', 'Something went wrong landing the catch', 'error')
        end
        local left, broken = Inventory.wearRod(source, sess, Config.Chest.wear or 2)

        TriggerClientEvent('whip_fishing:client:result', source, {
            session = sess.id, success = true,
            fish = {
                key = 'chest', label = 'Sunken Chest', rarity = 'rare', rarityLabel = 'Treasure', color = '#c9a24b',
                weight = Config.Chest.weight or 8.0, size = 'Heavy',
                desc = 'A barnacled chest, dripping seawater. Open it in your pockets.',
                image = ('img/items/%s.webp'):format('whip_fishing_chest'),
            },
            ground = where == 'ground',
            rodLeft = left, rodBroken = broken,
            effect = false,
        })

        if Config.Chest.announce then
            local who = player.firstName or 'Someone'
            local loc = FishingUtil.LocationById[sess.locId]
            exports.whip_core:NotifyPlayer(-1, ('%s fished up a sunken chest at %s!'):format(
                who, loc and loc.label or 'a fishing spot'), 'success', 8000)
        end

        local msg = 'You fished up a sunken chest. Open it!'
        if broken then msg = msg .. ' Your rod broke!' end
        finish(source, sess, 'caught', msg, 'success')
        return
    end

    local where, giveWhy = Inventory.giveFish(source, player, sess)
    if not where then
        print(('^1[whip_fishing] could not give %s to %d: %s^7'):format(fishKey, source, tostring(giveWhy)))
        return finish(source, sess, 'error', 'Something went wrong landing the fish', 'error')
    end
    local left, broken = Inventory.wearRod(source, sess, Rewards.catchWear(fishKey))

    TriggerClientEvent('whip_fishing:client:result', source, {
        session = sess.id, success = true,
        fish = {
            key = fishKey, label = fish.label, rarity = fish.rarity, rarityLabel = tier.label, color = tier.color,
            weight = weight, size = Rewards.sizeClass(ratio), desc = fish.desc,
            real = fish.real, scientific = fish.scientific,
            photo = ('img/photos/%s.webp'):format(FishingUtil.itemKey(fishKey)),
            image = ('img/items/%s.webp'):format(FishingUtil.itemKey(fishKey)),   -- relative to html/index.html
        },
        ground = where == 'ground',
        rodLeft = left, rodBroken = broken,
        effect = fish.effect or tier.screenEffect or false,
    })

    local announce = fish.announce
    if announce == nil then announce = tier.announce end
    if announce then
        local who = player.firstName or 'Someone'
        local loc = FishingUtil.LocationById[sess.locId]
        exports.whip_core:NotifyPlayer(-1, ('%s landed a %s %s (%.2f kg) at %s!'):format(
            who, tier.label, fish.label, weight, loc and loc.label or 'a fishing spot'), 'success', 8000)
    end

    local msg = ('You caught a %s (%.2f kg)'):format(fish.label, weight)
    if broken then msg = msg .. '. Your rod broke!' end
    finish(source, sess, 'caught', msg, 'success')
end

-- ------------------------------------------------------------------------------------------------------------
-- cancel and cleanup
-- ------------------------------------------------------------------------------------------------------------

--- Reeling in by choice. A fight is given up from WHIP's skill check itself (it answers 'cancelled').
function Fishing.cancel(source)
    local sess = Security.get(source)
    if not sess then return end
    if sess.phase == 'fighting' then return end
    finish(source, sess, 'cancelled', nil)
end

--- Death, logout, leaving: the session goes with no reward. The bait already taken stays taken.
function Fishing.drop(source, why)
    local sess = Security.get(source)
    if not sess then return end
    FishingUtil.debug('dropping session %d for %d: %s', sess.id, source, why)
    Security.close(source, sess, Cfg.Cooldown.afterLossMs)
    exports.whip_core:DropHeldProps(source, 'rod')
    TriggerClientEvent('whip_fishing:client:ended', source, { session = sess.id, outcome = 'cancelled' })
end

-- ------------------------------------------------------------------------------------------------------------
-- the spot's information (a prompt at a spot's info point)
-- ------------------------------------------------------------------------------------------------------------

function Fishing.spotInfo(source, locId)
    local loc = FishingUtil.LocationById[locId]
    if not loc then return false, 'No such fishing spot' end
    local coords = Security.coords(source)
    if not coords or #(coords - loc.coords) > loc.radius + 10.0 then return false, 'Walk up to the fishing spot' end

    local hour = Security.hour()
    local seen, known, rumours = {}, {}, 0
    for _, baitKey in ipairs((function()
        local keys = {}
        for k in pairs(Baits) do keys[#keys + 1] = k end
        table.sort(keys)
        return keys
    end)()) do
        local probe = { rodKey = next(Rods), baitKey = baitKey, locId = loc.id }
        local list = Rewards.candidates(probe, hour)
        for _, c in ipairs(list) do
            if not seen[c.key] then
                seen[c.key] = true
                local fish = Fish[c.key]
                local idx = FishingUtil.RarityIndex[fish.rarity] or 1
                if idx <= 3 then
                    known[#known + 1] = { label = fish.label, rarity = FishingUtil.RarityByKey[fish.rarity].label, idx = idx }
                else
                    rumours = rumours + 1
                end
            end
        end
    end
    table.sort(known, function(a, b) if a.idx ~= b.idx then return a.idx < b.idx end return a.label < b.label end)

    local open = Security.locationOpen(loc)
    local bonuses = {}
    for baitKey, b in pairs(loc.baitBonus or {}) do
        if Baits[baitKey] then bonuses[#bonuses + 1] = Baits[baitKey].label end
    end
    table.sort(bonuses)
    return {
        label = loc.label,
        type = loc.type,
        open = open == true,
        hours = loc.hours,
        known = known,
        rumours = rumours,
        bonusBaits = bonuses,
    }
end
