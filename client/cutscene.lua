-- ============================================================================================================
-- The catch cutscene, in the game world: the camera swings round in front of the player (WHIP's Camera API,
-- with cinema bars), the player holds the fish up to show it off, then the camera eases back and the catch card
-- shows. Everything here is local to this player's game and only for looks: the fish was already given by the
-- server before this starts.
-- ============================================================================================================

Cutscene = {}
Cutscene.active = false

local BLOCK = 'whip_fishing:cutscene'
local fishEnt = nil

local function cleanup()
    if fishEnt and DoesEntityExist(fishEnt) then
        DetachEntity(fishEnt, true, false)
        DeleteEntity(fishEnt)
    end
    fishEnt = nil
    local a = Config.Cutscene.hold
    if a and a.dict then StopAnimTask(PlayerPedId(), a.dict, a.clip, 2.0) end
    Whip.core:UnblockControls(BLOCK)
    Cutscene.active = false
end

--- A local (unnetworked) fish in the player's hands, for the camera only.
local function spawnFish(fishKey)
    local cfg = Config.Cutscene
    local fish = Fish[fishKey] or {}
    local model = fish.cutsceneModel or cfg.fishModel
    local hash = Whip.core:LoadModel(model, 3000)
    if not hash then return nil end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local ent
    if IsModelAPed(hash) then
        ent = CreatePed(28, hash, c.x, c.y, c.z - 5.0, 0.0, false, false)
        if ent ~= 0 then
            SetEntityInvincible(ent, true)
            SetBlockingOfNonTemporaryEvents(ent, true)
            SetPedCanRagdoll(ent, false)
            FreezeEntityPosition(ent, true)
        end
    else
        ent = CreateObject(hash, c.x, c.y, c.z - 5.0, false, false, false)
    end
    SetModelAsNoLongerNeeded(hash)
    if not ent or ent == 0 then return nil end
    SetEntityCollision(ent, false, false)
    local o, r = cfg.attach.offset, cfg.attach.rot
    AttachEntityToEntity(ent, ped, GetPedBoneIndex(ped, cfg.attach.bone), o[1], o[2], o[3], r[1], r[2], r[3],
        true, true, false, false, 2, true)
    return ent
end

--- The camera's timeline, round the player. yaw 180 is in front of them.
local function sequence()
    local s = Config.Cutscene.shots
    local keys = {}
    for i, shot in ipairs(s) do
        keys[i] = {
            t = shot.t,
            move = shot.move or 'glide',
            around = shot.around,
            punch = shot.punch,
            shot = { kind = 'orbit', subject = 'player', yaw = shot.yaw, pitch = shot.pitch, dist = shot.dist,
                aim = shot.aim, fov = shot.fov },
        }
    end
    return { letterbox = Config.Cutscene.letterbox ~= false, length = Config.Cutscene.lengthMs, keys = keys }
end

--- Plays the cutscene for a landed fish and waits for it to end. Call from a thread.
---@return boolean played  false when it was skipped (off, busy camera, in a car, ...)
function Cutscene.play(fishKey)
    local cfg = Config.Cutscene
    if not cfg.enabled or Cutscene.active then return false end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedSwimming(ped) then return false end
    if Whip.core:IsCameraActive() == true then return false end

    Cutscene.active = true
    Whip.core:BlockControls(BLOCK, { all = true, except = { 245, 249 } })   -- chat and push-to-talk stay
    local ok = pcall(function()
        -- Turn the player a little towards the camera's side so the fish is in frame
        if cfg.hold and Whip.core:LoadAnimDict(cfg.hold.dict) == true then
            TaskPlayAnim(ped, cfg.hold.dict, cfg.hold.clip, 3.0, 3.0, -1, cfg.hold.flag or 49, 0.0, false, false, false)
        end
        fishEnt = spawnFish(fishKey)
        local played = Whip.core:PlayCameraSequence(sequence(), {
            transitionIn = cfg.transitionInMs, transitionOut = cfg.transitionOutMs,
        })
        if played ~= true then Wait(cfg.lengthMs or 4000) end
    end)
    if not ok and Whip.core:IsCameraActive() == true then Whip.core:StopCamera() end
    cleanup()
    return true
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if fishEnt and DoesEntityExist(fishEnt) then DeleteEntity(fishEnt) end
end)
