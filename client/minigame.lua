-- ============================================================================================================
-- The reel-in minigame: the client half of the WHIP skill check game FishingUtil.GAME.
--
-- The server starts it with SkillCheck(source, rarity, { game = 'whip_fishing.reel', minMs, timeoutMs }), so
-- whip_core holds the one-shot token, refuses an answer faster than the fish could honestly be landed, and gives
-- up at the timeout. This side only plays it: the page runs the game, this file owns the screen while it does.
--
-- Input: keyboard and mouse through the page (NUI focus, only for the length of the fight), a controller through
-- Whip.padScreen (WHIP's pad reader for NUI screens). Every other control is held off with BlockControls.
-- Anything else that starts this game (the Director's Skill Check card) gets a profile built from the level.
-- ============================================================================================================

Minigame = {}

local screen = Whip.padScreen({
    buttons  = { 'a', 'b', 'x', 'up', 'down' },
    releases = { a = true, x = true },   -- A (and X) held = reeling: the page needs the release too
    stick    = false,
})

local pending = nil   -- the server's profile for the next fight: { session, profile, fish, at }
local active = nil    -- the fight on screen: { token, p }

--- The server's profile for this fight (sent just before whip_core starts the game).
function Minigame.setPending(data)
    pending = data
    pending.at = GetGameTimer()
end

function Minigame.clearPending()
    pending = nil
end

function Minigame.isActive()
    return active ~= nil
end

--- A profile from a level name alone (the Director, or another resource's SkillCheck), a basic rod and no bait.
local function profileFor(level)
    local tier = FishingUtil.RarityByKey[level] or Config.Rarities[1]
    local m = Config.Minigame
    local d = FishingUtil.clamp(tier.difficulty + m.globalDifficulty, m.minDifficulty, m.maxDifficulty)
    local lerp = FishingUtil.lerp
    return {
        difficulty = d,
        zoneSize = lerp(m.zoneSize, d), fishSpeed = lerp(m.fishSpeed, d), fishAgility = lerp(m.fishAgility, d),
        dartChance = lerp(m.dartChance, d), surgeChance = lerp(m.surgeChance, d), surgeMs = m.surgeMs,
        progressGain = lerp(m.progressGain, d), progressLoss = lerp(m.progressLoss, d), startProgress = m.startProgress,
        tensionGain = lerp(m.tensionGain, d), tensionRelax = m.tensionRelax, surgeTension = m.surgeTension,
        sweetSpot = m.sweetSpot, sweetBonus = m.sweetBonus, breakGraceMs = m.breakGraceMs, warnAt = m.warnAt,
        zoneLift = m.zoneLift, zoneGravity = m.zoneGravity, timeLimitMs = math.floor(lerp(m.timeLimitMs, d)),
        introMs = m.introMs, resultMs = m.resultMs,
    }, { rarity = tier.key, rarityLabel = tier.label, color = tier.color, size = 'Unknown' }
end

local function close()
    screen:close()
    Whip.core:SetScreenOpen(false, 'reel')
    Whip.core:UnblockControls('whip_fishing:fight')
    UI.send('fight:stop')
end

--- whip_core's call: play the game, answer passed or false and why ('failed' | 'cancelled' | 'busy').
local function run(difficulty, token)
    if active then return false, 'busy' end
    if Whip.core:IsPlayerDead() == true then return false, 'cancelled' end

    -- The profile is sent just before whip_core's start; allow it a moment to arrive
    local deadline = GetGameTimer() + 1500
    while not pending and GetGameTimer() < deadline do Wait(0) end
    local data = pending
    pending = nil
    if data and GetGameTimer() - data.at > 10000 then data = nil end   -- a stale one from an old fight

    local profile, fish
    if data and data.profile then
        profile, fish = data.profile, data.fish
    else
        profile, fish = profileFor(difficulty)
    end

    local p = promise.new()
    active = { token = token, p = p }

    -- Everything held off while the fish fights (the pad reader still reads its buttons through the block)
    Whip.core:BlockControls('whip_fishing:fight', { all = true })
    Whip.core:SetScreenOpen(true, 'reel', { keepHud = false })
    local pad = screen:open()
    UI.send('fight:start', { token = token, profile = profile, fish = fish, pad = pad })
    Anim.play('reel')

    local result = Citizen.Await(p)
    close()
    active = nil
    if type(result) == 'table' and result.passed == true then return true end
    return false, (type(result) == 'table' and result.why) or 'failed'
end

--- whip_core called it off (the server gave up, the player died, the resource that asked stopped).
local function cancel(token)
    if active and active.token == token then
        UI.send('fight:abort')
        active.p:resolve({ passed = false, why = 'cancelled' })
    end
end

Whip.skillCheckGame(FishingUtil.GAME, { run = run, cancel = cancel })

-- The page's answer. Its words are mapped to whip_core's: caught -> passed; snapped/escaped -> 'failed'.
RegisterNUICallback('fightDone', function(data, cb)
    cb({})
    if not active or type(data) ~= 'table' or data.token ~= active.token then return end
    local reason = data.reason
    if reason == 'caught' then
        active.p:resolve({ passed = true })
    elseif reason == 'cancelled' then
        active.p:resolve({ passed = false, why = 'cancelled' })
    else
        active.p:resolve({ passed = false, why = 'failed' })
    end
end)

-- A shake on the controller (a surge, the line about to snap). Keyboards feel nothing.
RegisterNUICallback('rumble', function(data, cb)
    cb({})
    if not (active and screen:isPad()) then return end
    local ms = math.max(30, math.min(800, math.floor(tonumber(type(data) == 'table' and data.ms) or 150)))
    local strength = math.max(0, math.min(1, tonumber(type(data) == 'table' and data.strength) or 0.5))
    SetPadShake(0, ms, math.floor(strength * 255))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if active then
        active.p:resolve({ passed = false, why = 'cancelled' })
        screen:close()
    end
end)
