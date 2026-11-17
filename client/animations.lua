-- ============================================================================================================
-- Animations: cast, idle, bite, reel and catch, all from Config.Animations. The rod itself is a server
-- HoldProps (everyone sees it); these only move the player.
-- ============================================================================================================

Anim = {}

local current = nil   -- the looping animation playing, { dict, clip }

local function load(dict)
    local ok = Whip.core:LoadAnimDict(dict)
    return ok == true
end

--- Play one of Config.Animations by name. Loops (flag 49/1) keep playing until another or Anim.stop().
---@return boolean played
function Anim.play(name)
    local a = Config.Animations[name]
    if type(a) ~= 'table' or not a.dict then return false end
    if not load(a.dict) then return false end
    local ped = PlayerPedId()
    local loop = (a.flag or 49) & 1 == 1
    TaskPlayAnim(ped, a.dict, a.clip, 4.0, 4.0, a.durationMs or -1, a.flag or 49, 0.0, false, false, false)
    if a.rate then
        Wait(0)
        SetEntityAnimSpeed(ped, a.dict, a.clip, a.rate)
    end
    if loop then current = { dict = a.dict, clip = a.clip } end
    return true
end

--- Play a one-shot animation and wait for it (cast, catch).
function Anim.playAndWait(name)
    local a = Config.Animations[name]
    if not Anim.play(name) then return end
    Wait(a.durationMs or 1000)
end

--- Is our looping animation still playing? (The player may have been knocked out of it.)
function Anim.isPlaying()
    if not current then return false end
    return IsEntityPlayingAnim(PlayerPedId(), current.dict, current.clip, 3)
end

--- Stop what we started (never another resource's animation).
function Anim.stop()
    local ped = PlayerPedId()
    if current then
        StopAnimTask(ped, current.dict, current.clip, 2.0)
        current = nil
    end
    for _, a in pairs(Config.Animations) do
        if type(a) == 'table' and a.dict and IsEntityPlayingAnim(ped, a.dict, a.clip, 3) then
            StopAnimTask(ped, a.dict, a.clip, 2.0)
        end
    end
end
