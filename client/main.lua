-- ============================================================================================================
-- WHIP interactions: a zone per fishing spot (no polling: WHIP tells us on enter and exit), "Go Fishing" on the
-- F1 wheel while standing in a spot with a rod, and an info prompt at spots that set an infoPoint.
-- ============================================================================================================

local function hasUsableRod()
    for _, item in ipairs(FishingUtil.RodItems) do
        local key = FishingUtil.RodByItem[item]
        local n = Whip.core:GetItemCount(item, function(meta)
            local dur = type(meta) == 'table' and tonumber(meta.durability)
            return dur == nil or dur > 0
        end)
        if (tonumber(n) or 0) > 0 then return true, key end
    end
    return false
end

local function hoursText(h)
    if type(h) ~= 'table' then return 'Open all day' end
    return ('Open %02d:00 to %02d:00'):format(h.from, h.to)
end

local function showSpotInfo(loc)
    local info, why = Whip.core:Callback('whip_fishing:spotInfo', loc.id)
    if type(info) ~= 'table' then
        return Whip.core:Notify(type(why) == 'string' and why or 'Nothing to see here', 'error')
    end
    local lines = {}
    lines[#lines + 1] = ('%s  ·  %s'):format(hoursText(info.hours), info.open and 'biting now' or 'closed now')
    if #info.known > 0 then
        local names = {}
        for _, f in ipairs(info.known) do names[#names + 1] = ('%s (%s)'):format(f.label, f.rarity) end
        lines[#lines + 1] = 'Known here: ' .. table.concat(names, ', ')
    end
    if info.rumours > 0 then
        lines[#lines + 1] = ('Anglers whisper of %d rarer fish here...'):format(info.rumours)
    end
    if #info.bonusBaits > 0 then
        lines[#lines + 1] = 'Works well here: ' .. table.concat(info.bonusBaits, ', ')
    end
    Whip.core:Alert({ title = info.label, message = table.concat(lines, '\n'), button = 'Tight lines' })
end

Whip.register(function()
    -- One sphere zone per spot: the current spot follows the player for the wheel entry and the hint
    for _, loc in ipairs(Locations) do
        Whip.core:RegisterZone({
            id = 'whip_fishing_' .. loc.id,
            type = 'sphere',
            pos = loc.coords,
            radius = loc.radius,
            label = loc.label,
            group = 'whip_fishing',
            onEnter = function()
                Fishing.currentSpot = loc
                if Config.UI.showSpotHint then
                    Whip.core:Notify(('Fishing spot: %s'):format(loc.label), 'info', 3500)
                end
            end,
            onExit = function()
                if Fishing.currentSpot == loc then Fishing.currentSpot = nil end
                -- Walking out of the spot with a line in the water reels it in
                if Fishing.state and Fishing.state.phase ~= 'fighting' then Fishing.stop(true) end
            end,
        })

        if loc.infoPoint then
            Whip.core:AddAction({
                id = 'info_' .. loc.id,
                at = { coords = loc.infoPoint },
                label = 'Fishing Spot',
                icon = 'star',
                focusMode = 'near',
                onSelect = function()
                    CreateThread(function() showSpotInfo(loc) end)
                end,
            })
        end
    end

    -- "Go Fishing" on the F1 wheel: the server picks the best rod that isn't broken
    if Config.UI.radialEntry then
        Whip.core:AddAction({
            id = 'go_fishing',
            at = { radial = true },
            label = 'Go Fishing',
            icon = 'target',
            description = 'Cast a line here with your best rod',
            require = { vehicle = 'out' },
            canInteract = function()
                return Fishing.currentSpot ~= nil and Fishing.state == nil and not (Cutscene and Cutscene.active) and hasUsableRod()
            end,
            onSelect = function()
                TriggerServerEvent('whip_fishing:start')
            end,
        })
    end
end)
