-- ============================================================================================================
-- NUI messages. The page never takes the focus: the status panel, the bite alert and the catch card are drawn
-- without capturing input. Reeling in is WHIP's own skill check, on WHIP's own screen.
-- ============================================================================================================

UI = {}

local ready = false
local queued = {}

--- Send a message to the page (queued until the page says it has loaded).
function UI.send(action, data)
    local msg = { action = action, data = data }
    if not ready then
        queued[#queued + 1] = msg
        return
    end
    SendNUIMessage(msg)
end

RegisterNUICallback('ready', function(_, cb)
    cb({})
    if ready then return end
    ready = true
    CreateThread(function()
        local theme = Whip.core:Callback('whip_fishing:theme')
        if type(theme) == 'string' then SendNUIMessage({ action = 'theme', data = { resource = theme } }) end
    end)
    SendNUIMessage({ action = 'config', data = {
        scale = Config.UI.scale,
        volume = Config.Sounds.volume,
        resultMs = Config.UI.resultMs,
    } })
    for _, msg in ipairs(queued) do SendNUIMessage(msg) end
    queued = {}
end)

--- The status panel: { visible, status, phase, size, rod, bait, durability, max }
function UI.hud(state)
    UI.send('hud', state)
end

function UI.hideHud()
    UI.send('hud', { visible = false })
end

--- A GTA frontend sound from Config.Sounds (false/nil: none)
function UI.sound(name)
    local s = Config.Sounds[name]
    if type(s) == 'table' and s.name then
        PlaySoundFrontend(-1, s.name, s.set, true)
    end
end
