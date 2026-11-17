-- ============================================================================================================
-- The fishing line, as a whip_rope rope: from the rod's tip in the player's hand to where the line landed in
-- the water. Locked (nobody can grab, tie, hang off or coil it), thin, and only for as long as the line is out.
-- whip_rope is optional: without it (or with Config.Line.whipRope = false) the client draws a plain line.
-- ============================================================================================================

Line = {}

local owned = {}   -- [ropeId] = session, so whip_rope's notices can be matched to ours

function Line.available()
    return Config.Line.enabled and Config.Line.whipRope ~= false and GetResourceState('whip_rope') == 'started'
end

local function rodModel(rodKey)
    local rod = Rods[rodKey] or {}
    return (rod.prop and rod.prop.model) or Config.RodProp.model
end

--- Puts the line out for a session (after the rod is in the player's hand). true when a rope was made.
---@param water vector3 where the line landed
function Line.attach(source, sess, water)
    if not Line.available() or sess.ropeId then return false end
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end
    local from = GetEntityCoords(ped)
    local cfg = Config.Line
    local length = #(vector3(from.x, from.y, from.z + 1.5) - water) * (cfg.slack or 1.04)
    length = math.max(0.5, math.min(100.0, length))
    local tip = cfg.tipOffset

    local id, why = exports.whip_rope:CreateRope({
        origin = { type = 'held', heldBy = source },
        tail   = { type = 'fixed', pos = water },
        length = length,
        player = source,
        kind   = 'whip_fishing_line',
        locked = true,
        heldAt = { model = rodModel(sess.rodKey), offset = { x = tip.x, y = tip.y, z = tip.z } },
        look   = {
            model = GetHashKey(cfg.ropeModel or 'whip_rope_seg'),
            modelNoShadow = GetHashKey(cfg.ropeModelNoShadow or 'whip_rope_seg_ns'),
            thickness = cfg.thickness or 0.08,
        },
        collide = { vehicles = false, props = false },
    })
    if not id then
        FishingUtil.debug('no whip_rope line for %d: %s', source, tostring(why))
        return false
    end
    sess.ropeId = id
    owned[id] = sess
    return true
end

--- Takes the line in (session ended, dropped or replaced). Safe to call twice.
function Line.remove(sess)
    local id = sess and sess.ropeId
    if not id then return end
    sess.ropeId = nil
    owned[id] = nil
    if GetResourceState('whip_rope') == 'started' then exports.whip_rope:RemoveRope(id) end
end

-- whip_rope took it in itself (/clearropes): forget it; the session carries on with no visible line
AddEventHandler('whip_rope:ropeRemoved', function(id, resource)
    if resource ~= GetCurrentResourceName() then return end
    local sess = owned[id]
    owned[id] = nil
    if sess then sess.ropeId = nil end
end)

-- whip_rope restarted: every rope it had is gone
AddEventHandler('onResourceStop', function(res)
    if res ~= 'whip_rope' then return end
    for id, sess in pairs(owned) do sess.ropeId = nil; owned[id] = nil end
end)
