-- ============================================================================================================
-- The world side: finding the water in front of the player, splashes at the line's end, and the line itself.
-- The rod prop is the server's HoldProps; this only reads it (GetOwnHeldProp) to draw the line from its tip.
-- ============================================================================================================

Props = {}

--- The water surface in front of the player, nearest first, between Config.Cast.minDistance and maxDistance.
---@return vector3|nil
function Props.findWater()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local c = Config.Cast
    local d = c.minDistance
    while d <= c.maxDistance do
        local x, y = pos.x + fwd.x * d, pos.y + fwd.y * d
        local top, bottom = pos.z + 3.0, pos.z - c.probeDown
        local hit, at = TestProbeAgainstWater(x, y, top, x, y, bottom)
        if hit and at then
            return vector3(at.x, at.y, at.z)
        end
        -- Fallback for water the probe misses (some lakes): the water height at that point
        local found, height = GetWaterHeight(x, y, top)
        if found and height and height > bottom and height < top then
            return vector3(x, y, height)
        end
        d = d + c.probeStep
    end
    return nil
end

local loadedAssets = {}

--- A one-shot particle effect from Config.Effects at a point.
function Props.effect(name, coords)
    local e = Config.Effects[name]
    if type(e) ~= 'table' or not e.enabled or not coords then return end
    if not loadedAssets[e.asset] then
        if Whip.core:LoadPtfxAsset(e.asset) ~= true then return end
        loadedAssets[e.asset] = true
    end
    UseParticleFxAsset(e.asset)
    StartParticleFxNonLoopedAtCoord(e.name, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, e.scale or 1.0, false, false, false)
end

--- A small camera shake for the bite.
function Props.biteShake()
    local s = Config.Effects.biteShake
    if type(s) == 'table' and s.enabled then ShakeGameplayCam(s.type, s.amplitude or 0.05) end
end

--- The held rod prop's entity (nil while it is not in hand yet). An export call: ask it now and then, not
--- every frame (the fishing loop refreshes it twice a second).
function Props.rodEntity(rodKey)
    local rod = Rods[rodKey]
    local model = (rod and rod.prop and rod.prop.model) or Config.RodProp.model
    local ent = Whip.core:GetOwnHeldProp(model, 'rod')
    if type(ent) ~= 'number' or ent == 0 or not DoesEntityExist(ent) then return nil end
    return ent
end

--- The rod's tip in the world (natives only: safe every frame).
function Props.tipOf(ent)
    if not ent or not DoesEntityExist(ent) then return nil end
    local o = Config.Line.tipOffset
    return GetOffsetFromEntityInWorldCoords(ent, o.x, o.y, o.z)
end

--- Draws the line for one frame.
function Props.drawLine(tip, water, biting)
    if not Config.Line.enabled or not tip or not water then return end
    local c = biting and Config.Line.biteColor or Config.Line.color
    DrawLine(tip.x, tip.y, tip.z, water.x, water.y, water.z, c[1], c[2], c[3], c[4])
end
