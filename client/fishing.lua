-- ============================================================================================================
-- The fishing mode on the player's game: choosing bait, casting, waiting with the line out, the bite and the
-- strike. The server decides everything that matters; this side asks, animates and draws.
--
-- While a line is out the player is in a WHIP "mode": BlockControls with mode = true, so E prompts and the
-- hotbar stand down and Interact / Cancel are ours (IsAcceptPressed / IsCancelPressed, keyboard or pad).
-- ============================================================================================================

Fishing = {}

Fishing.state = nil          -- the attempt on this game, or nil
Fishing.currentSpot = nil    -- the spot the player stands in (client/main.lua's zones)

local KVP_BAIT = 'whip_fishing:bait'
local preferredBait = GetResourceKvpString(KVP_BAIT)
if preferredBait == '' then preferredBait = nil end

local MODE_BLOCK = 'whip_fishing:mode'

local function notify(text, kind)
    if text then Whip.core:Notify(text, kind or 'info') end
end

--- Can the player fish right now? false and why when not.
local function canFishNow()
    local ped = PlayerPedId()
    if Whip.core:IsPlayerDead() == true or IsEntityDead(ped) then return false, 'You can\'t fish right now' end
    if IsPedInAnyVehicle(ped, false) then return false, 'You can\'t fish from a vehicle' end
    local body, words = Whip.core:GetBodyState()
    if body then return false, type(words) == 'string' and words or 'You can\'t fish right now' end
    if IsPedRagdoll(ped) or IsPedFalling(ped) then return false, 'Steady yourself first' end
    return true
end

local function hud(status, extra)
    local s = Fishing.state
    if not s then return end
    s.status = status or s.status
    local data = {
        visible = true,
        status = s.status,
        phase = s.phase,
        rod = s.rodLabel,
        bait = s.baitLabel,
        baitLeft = s.baitLeft,
        durability = s.durability,
        maxDurability = s.maxDurability,
    }
    if extra then for k, v in pairs(extra) do data[k] = v end end
    UI.hud(data)
end

local function hints()
    local s = Fishing.state
    if not s then return end
    local accept, cancel = Whip.core:AcceptHint(), Whip.core:CancelHint()
    if s.phase == 'bite' then
        Whip.core:ShowText(('%s Strike!  |  %s Reel in'):format(accept, cancel), { icon = 'target', tone = 'warn' })
    else
        Whip.core:ShowText(('%s Strike  |  %s Reel in'):format(accept, cancel), { icon = 'target' })
    end
end

--- Leaves the mode on this game (the server has its own session; it is told separately when needed).
local function leaveMode(keepAnim)
    Whip.core:UnblockControls(MODE_BLOCK)
    Whip.core:HideText()
    if not keepAnim then Anim.stop() end
end

--- Ends the attempt here. `tell`: also ask the server to reel in.
function Fishing.stop(tell, keepHud)
    local s = Fishing.state
    if not s then return end
    Fishing.state = nil
    if tell then TriggerServerEvent('whip_fishing:cancel') end
    leaveMode(false)
    if not keepHud then UI.hideHud() end
end

-- ------------------------------------------------------------------------------------------------------------
-- Choosing bait
-- ------------------------------------------------------------------------------------------------------------

--- Picks the bait for this cast from what the server says they carry: the preferred one while it is carried
--- (unless Config.UI.askBaitEachCast), the only one, or the player's choice in WHIP's Input dialog.
---@param baits table { [baitKey] = count }
---@return string|nil baitKey
local function chooseBait(baits)
    local keys = {}
    for key in pairs(baits) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return Baits[a].label < Baits[b].label end)
    if #keys == 0 then return nil end
    if not Config.UI.askBaitEachCast and preferredBait and baits[preferredBait] then return preferredBait end
    if #keys == 1 then return keys[1] end

    local options, default = {}, nil
    for _, key in ipairs(keys) do
        options[#options + 1] = { value = key, label = ('%s  (x%d)'):format(Baits[key].label, baits[key]) }
        if key == preferredBait then default = key end
    end
    local answer = Whip.core:Input('Choose your bait', {
        { label = 'Bait', type = 'select', options = options, default = default or keys[1] },
    })
    if type(answer) ~= 'table' or not answer[1] or not baits[answer[1]] then return nil end
    return answer[1]
end

function Fishing.setPreferredBait(key)
    if not Baits[key] then return end
    preferredBait = key
    SetResourceKvp(KVP_BAIT, key)
end

-- ------------------------------------------------------------------------------------------------------------
-- The mode loop: only while a line is out. Draws the line, reads Strike and Reel in, and stops the attempt the
-- moment the player can no longer fish (down, in a car, in the water, knocked over).
-- ------------------------------------------------------------------------------------------------------------

local function modeLoop()
    local s = Fishing.state
    if not s then return end
    Whip.core:BlockControls(MODE_BLOCK, { groups = { 'move', 'combat' }, controls = { 26, 45, 140 }, mode = true })
    hints()

    local rodEnt, nextLook, nextCheck, lastStrike = nil, 0, 0, 0
    while Fishing.state == s and (s.phase == 'waiting' or s.phase == 'bite' or s.phase == 'striking') do
        local now = GetGameTimer()
        if now >= nextLook then
            rodEnt = Props.rodEntity(s.rodKey)
            nextLook = now + 500
        end
        if rodEnt and not s.rope then Props.drawLine(Props.tipOf(rodEnt), s.water, s.phase == 'bite') end

        if now >= nextCheck then
            nextCheck = now + 250
            local ok, why = canFishNow()
            if not ok or IsPedRagdoll(PlayerPedId()) then
                notify(why or 'You dropped the line', 'error')
                Fishing.stop(true)
                return
            end
            -- Knocked out of the pose by something else: back into it
            if not Anim.isPlaying() and s.phase ~= 'striking' then Anim.play(s.phase == 'bite' and 'bite' or 'idle') end
        end

        if Whip.core:IsCancelPressed() then
            Fishing.stop(true)
            return
        end
        if Whip.core:IsAcceptPressed() and now - lastStrike > 450 then
            lastStrike = now
            if s.phase == 'bite' then
                s.phase = 'striking'
                hud('Striking...')
            end
            TriggerServerEvent('whip_fishing:hook')
        end
        Wait(0)
    end

    -- The fight is WHIP's skill check now (the server runs it), or the attempt ended
    Whip.core:UnblockControls(MODE_BLOCK)
    Whip.core:HideText()
end

-- ------------------------------------------------------------------------------------------------------------
-- From the server
-- ------------------------------------------------------------------------------------------------------------

local function mine(data)
    return Fishing.state and type(data) == 'table' and data.session == Fishing.state.session
end

-- The server says they may fish here: choose bait, find the water, cast
RegisterNetEvent('whip_fishing:client:begin', function(data)
    if Fishing.state or type(data) ~= 'table' or (Cutscene and Cutscene.active) then return end
    local ok, why = canFishNow()
    if not ok then return notify(why, 'error') end

    local baitKey = chooseBait(type(data.baits) == 'table' and data.baits or {})
    if not baitKey then return end
    if Fishing.state then return end   -- (a second begin while the dialog was up)

    local water = Props.findWater()
    if not water then return notify('Face the water to cast your line', 'error') end
    ok, why = canFishNow()
    if not ok then return notify(why, 'error') end

    local rod = Rods[data.rod]
    local s = {
        phase = 'casting', session = nil, rodKey = data.rod, rodLabel = rod and rod.label or 'Rod',
        baitKey = baitKey, baitLabel = Baits[baitKey].label, water = water,
    }
    Fishing.state = s
    Fishing.setPreferredBait(baitKey)
    hud('Casting...')

    -- The cast animation plays while the server checks the cast
    CreateThread(function() Anim.play('cast') end)
    local started = GetGameTimer()
    local res, castWhy = Whip.core:Callback('whip_fishing:cast', data.slot, FishingUtil.itemKey(baitKey),
        { x = water.x, y = water.y, z = water.z })
    if Fishing.state ~= s then return end
    if type(res) ~= 'table' then
        Fishing.state = nil
        leaveMode(false)
        UI.hideHud()
        return notify(type(castWhy) == 'string' and castWhy or 'You can\'t cast here', 'error')
    end

    s.session = res.session
    s.rope = res.rope == true
    s.durability, s.maxDurability = res.rod and res.rod.durability, res.rod and res.rod.max
    s.baitLeft = res.bait and res.bait.left
    local castMs = Config.Animations.cast.durationMs or 1000
    local left = castMs - (GetGameTimer() - started)
    if left > 0 then Wait(left) end
    if Fishing.state ~= s then return end

    s.phase = 'waiting'
    UI.sound('cast')
    Props.effect('castSplash', water)
    Anim.play('idle')
    hud('Waiting for a bite...')
    UI.send('cast', { water = true })
    CreateThread(modeLoop)
end)

RegisterNetEvent('whip_fishing:client:nibble', function(data)
    if not mine(data) then return end
    UI.send('nibble')
    hud('Something is nibbling...')
end)

RegisterNetEvent('whip_fishing:client:spooked', function(data)
    if not mine(data) then return end
    hud('Spooked them. Wait for a real bite')
end)

RegisterNetEvent('whip_fishing:client:bite', function(data)
    if not mine(data) then return end
    local s = Fishing.state
    s.phase = 'bite'
    UI.send('bite', { windowMs = data.windowMs })
    UI.sound('bite')
    Props.effect('biteSplash', s.water)
    Props.biteShake()
    if Whip.core:IsControllerActive() == true then SetPadShake(0, Config.Effects.rumbleMs or 200, 200) end
    Anim.play('bite')
    hud('Fish on the line! Strike!')
    hints()
end)

RegisterNetEvent('whip_fishing:client:biteMissed', function(data)
    if not mine(data) then return end
    local s = Fishing.state
    s.phase = 'waiting'
    UI.send('biteMissed')
    Anim.play('idle')
    hud('It let go. Waiting for another bite...')
    hints()   -- (the mode loop is still running: it covers waiting, bite and striking)
end)

-- The strike landed: the fight is next (the server starts WHIP's skill check right after this)
RegisterNetEvent('whip_fishing:client:fight', function(data)
    if not mine(data) then return end
    local s = Fishing.state
    s.phase = 'fighting'
    hud('Fish on!', { size = type(data.size) == 'string' and data.size or nil })
end)

RegisterNetEvent('whip_fishing:client:result', function(data)
    if not mine(data) then return end
    if data.success then
        UI.sound('catch')
        CreateThread(function()
            -- The in-game cutscene first (when on and possible), then the card and the celebration.
            -- A chest is not a fish: no cutscene, it has no pose.
            local fishKey = type(data.fish) == 'table' and data.fish.key or nil
            local played = fishKey and Fish[fishKey] and Cutscene and Cutscene.play(fishKey)
            UI.send('result', data)
            if type(data.effect) == 'string' and data.effect ~= '' then AnimpostfxPlay(data.effect, 2500, false) end
            if not played then Anim.playAndWait('catch') end
        end)
    else
        UI.send('result', data)
        UI.sound('lost')
    end
end)

RegisterNetEvent('whip_fishing:client:ended', function(data)
    if not mine(data) then
        -- Our own attempt before the server numbered it, or an old one: only clean up if nothing is live here
        return
    end
    local s = Fishing.state
    Fishing.state = nil
    leaveMode(data.outcome == 'caught')
    UI.hideHud()
    if data.message then notify(data.message, data.kind) end
    if s and data.outcome ~= 'caught' then Anim.stop() end
end)

RegisterNetEvent('whip_fishing:client:setBait', function(baitKey)
    Fishing.setPreferredBait(baitKey)
end)

-- Down, or logged out: whatever was out is put away (the server drops its session on its own events too)
AddEventHandler('whip_core:player:died', function()
    if Fishing.state then Fishing.stop(true) end
end)
AddEventHandler('whip_core:player:logout', function()
    if Fishing.state then Fishing.stop(false) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Fishing.state then
        Fishing.state = nil
        Anim.stop()
    end
end)
