-- ============================================================================================================
-- Sessions, cooldowns and where-and-when checks. Everything that decides whether a player may fish lives here,
-- on the server: the client only asks.
--
-- One session per player (keyed by server id, tied to the character's WHIP session), one phase at a time:
--   'casting' -> 'waiting' -> 'bite' -> 'fighting' -> gone
-- Every timer and every waiting handler checks it still holds the same session table before it acts, so a
-- cancel, a logout or a second request can never be answered twice.
-- ============================================================================================================

Security = {}

local sessions = {}    -- [source] = session
local cooldowns = {}   -- [charId] = GetGameTimer() until which they may not cast
local lastId = 0

--- The player's current session, or nil.
function Security.get(source)
    return sessions[source]
end

--- Is this still the live session? (After any wait, before acting on it.)
function Security.isLive(source, sess)
    return sess ~= nil and sessions[source] == sess and not sess.ended
end

--- Opens a session. Refused while one is open (no concurrent fishing).
---@return table|nil session
---@return string|nil why
function Security.open(source, player, fields)
    if sessions[source] then return nil, 'You are already fishing' end
    lastId = lastId + 1
    local sess = fields or {}
    sess.id = lastId
    sess.source = source
    sess.charId = player.charId
    sess.playerSession = player.session
    sess.phase = 'casting'
    sess.startedAt = GetGameTimer()
    sess.gen = 0          -- bumped by every new timer; a timer that finds another gen does nothing
    sess.waits = 0
    sess.bites = 0
    sess.ended = false
    sessions[source] = sess
    return sess
end

--- Closes a session, once. The cooldown starts here.
---@return boolean closed  false when it was already closed or replaced
function Security.close(source, sess, cooldownMs)
    if not Security.isLive(source, sess) then return false end
    sess.ended = true
    if Line then Line.remove(sess) end   -- the whip_rope line goes with the session, however it ends
    sess.gen = sess.gen + 1
    sessions[source] = nil
    if cooldownMs and cooldownMs > 0 and sess.charId then
        cooldowns[sess.charId] = GetGameTimer() + cooldownMs
    end
    return true
end

--- Milliseconds left on this character's cooldown (0 when none).
function Security.cooldownLeft(charId)
    local untilAt = charId and cooldowns[charId]
    if not untilAt then return 0 end
    local left = untilAt - GetGameTimer()
    if left <= 0 then
        cooldowns[charId] = nil
        return 0
    end
    return left
end

--- The player's position as the server sees it (the same position SecureEvent's `near` trusts).
---@return vector3|nil
function Security.coords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

function Security.inVehicle(source)
    local ped = GetPlayerPed(source)
    return ped ~= 0 and GetVehiclePedIsIn(ped, false) ~= 0
end

--- The fishing spot the player stands in (the nearest whose radius holds them), or nil.
function Security.locationAt(coords)
    if not coords then return nil end
    local best, bestDist = nil, math.huge
    for _, loc in ipairs(Locations) do
        local d = #(coords - loc.coords)
        if d <= loc.radius and d < bestDist then best, bestDist = loc, d end
    end
    return best
end

--- The server's hour (WHIP's world clock).
function Security.hour()
    local h = Whip.core:GetTime()
    return tonumber(h) or 12
end

--- May this spot be fished now? true, or false and why.
function Security.locationOpen(loc)
    if not loc.hours then return true end
    if FishingUtil.inHours(loc.hours, Security.hour()) then return true end
    return false, ('%s can only be fished between %02d:00 and %02d:00'):format(loc.label, loc.hours.from, loc.hours.to)
end

--- Where the client says the line landed, checked against where the server sees the player and the spot.
---@return boolean ok
---@return string|nil why
function Security.checkLanding(coords, water, loc)
    local landing = vector3(water.x, water.y, water.z)
    local flat = #(vector2(landing.x, landing.y) - vector2(coords.x, coords.y))
    if flat > Config.Cast.maxDistance + Config.Cast.serverSlack then return false, 'That is too far to cast' end
    if landing.z > coords.z + 3.0 or landing.z < coords.z - Config.Cast.maxWaterBelow then
        return false, 'There is no water there'
    end
    if #(landing - loc.coords) > loc.radius + Config.Cast.maxDistance + Config.Cast.serverSlack then
        return false, 'Cast into the fishing spot'
    end
    return true
end

--- A refusal recorded in WHIP's Monitor without a message on screen (a forged or out-of-order request).
function Security.reject(eventName, source, reason)
    exports.whip_core:RecordEventRejection(eventName, source, reason)
    FishingUtil.debug('refused %s from %d: %s', eventName, source, reason)
end

--- Every open session (for cleanup on stop).
function Security.all()
    return sessions
end

--- Forget a character's cooldown entry when nobody needs it any more (a long-running server stays small).
CreateThread(function()
    while true do
        Wait(300000)
        local now = GetGameTimer()
        for charId, untilAt in pairs(cooldowns) do
            if untilAt <= now then cooldowns[charId] = nil end
        end
    end
end)
