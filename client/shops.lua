-- ============================================================================================================
-- The tackle shop's selector. One prompt beside the shopkeeper with everything on it: scroll through the
-- choices, E (Enter) takes the one shown. "Sell Fish" opens its own menu (everything, or one species at a
-- time), filled from the server each time it opens; "Enter the Shop" opens WHIP's own buy screen.
-- The menus are only lists the server built: the server prices and takes the fish itself.
-- ============================================================================================================

local busy = false

local function money(n) return ('%s%d'):format(Config.Economy.currency or '$', n) end

--- The sell menu's rows, built each time it opens: everything first, then a row per species carried.
--- The server reads the player's pockets and prices every fish itself; this only shows its answer.
---@return table[] rows  (an empty list shows the prompt's own "Nothing here")
local function sellRows()
    local data = Whip.core:Callback('whip_fishing:sellList')
    if type(data) ~= 'table' or #data.groups == 0 then return {} end
    local rows = { {
        id = 'all',
        label = ('Everything  -  %s'):format(money(data.total)),
        icon = 'cash',
        onSelect = function(ctx) TriggerServerEvent('whip_fishing:sell', ctx.option) end,
    } }
    for _, g in ipairs(data.groups) do
        rows[#rows + 1] = {
            id = g.key,
            label = ('%s x%d (%s)  -  %s'):format(g.label, g.count, g.rarityLabel, money(g.total)),
            icon = 'dollar',
            onSelect = function(ctx) TriggerServerEvent('whip_fishing:sell', ctx.option) end,
        }
    end
    return rows
end

local function openSellMenu()
    if busy then return end
    busy = true
    local data, why = Whip.core:Callback('whip_fishing:sellList')
    if type(data) ~= 'table' then
        busy = false
        return Whip.core:Notify(type(why) == 'string' and why or 'The shop is closed', 'error')
    end
    if #data.groups == 0 then
        busy = false
        return Whip.core:Notify('You have no fish to sell', 'info')
    end
    local options = { { label = ('Everything  -  %s'):format(money(data.total)), value = 'all' } }
    for _, g in ipairs(data.groups) do
        options[#options + 1] = {
            label = ('%s x%d (%s)  -  %s'):format(g.label, g.count, g.rarityLabel, money(g.total)),
            value = g.key,
        }
    end
    local values = Whip.core:Input({
        title = 'Sell Fish',
        fields = { { label = 'What to sell', type = 'select', options = options, default = 'all' } },
    })
    busy = false
    if type(values) ~= 'table' then return end
    local what = values[1]
    if type(what) ~= 'string' then return end
    TriggerServerEvent('whip_fishing:sell', what)
end

local blips = {}

-- A map blip per shop, made by this player's own game, so it shows however the server-side blips behave
local function makeBlips()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    blips = {}
    for _, shop in ipairs(Config.Shops) do
        local b = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(b, shop.blipSprite or 68)
        SetBlipColour(b, shop.blipColor or 3)
        SetBlipScale(b, 0.85)
        SetBlipAsShortRange(b, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(shop.name)
        EndTextCommandSetBlipName(b)
        blips[#blips + 1] = b
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)

CreateThread(makeBlips)

local function nearShop(range)
    local c = GetEntityCoords(PlayerPedId())
    for _, shop in ipairs(Config.Shops) do
        if #(c - vector3(shop.coords.x, shop.coords.y, shop.coords.z)) <= range then return true end
    end
    return false
end

Whip.register(function()
    for _, shop in ipairs(Config.Shops) do
        -- At the shopkeeper: the counter's one prompt (the keeper is ours — the shop itself has no
        -- counter of whip's own). No heading: it turns to face whoever comes up.
        local options
        if Config.Economy.enabled then
            options = {
                {
                    id = 'sell',
                    label = 'Sell Fish',
                    icon = 'star',
                    -- After a sale the menu is filled again: sell the next stack straight away
                    stay = true,
                    options = function(ctx)
                        -- The menu fills each time it opens, so it shows what is carried right now.
                        -- An empty list shows the prompt's own "Nothing here".
                        return sellRows()
                    end,
                },
                {
                    id = 'browse',
                    label = 'Enter the Shop',
                    icon = 'dollar',
                    onSelect = function(ctx) TriggerServerEvent('whip_fishing:browse', shop.id) end,
                },
            }
        else
            options = {
                {
                    id = 'browse',
                    label = 'Enter the Shop',
                    icon = 'dollar',
                    onSelect = function(ctx) TriggerServerEvent('whip_fishing:browse', shop.id) end,
                },
            }
        end
        Whip.core:AddAction({
            id = 'shop_' .. shop.id,
            at = { coords = vector3(shop.coords.x, shop.coords.y, shop.coords.z + 1.0) },
            label = shop.name,
            icon = 'store',
            reach = 3.0,
            seeFrom = 8.0,
            focusMode = 'near',
            -- The choices, scrolled through one at a time on the prompt; E takes the one shown.
            options = options,
        })
    end

    if not Config.Economy.enabled then return end

    -- The same thing on the F1 wheel while you stand at a shop, in case the prompt is hard to see
    Whip.core:AddAction({
        id = 'sell_fish_wheel',
        at = { radial = true },
        label = 'Sell Fish',
        icon = 'star',
        description = 'Sell the fish you carry to the tackle shop',
        canInteract = function() return nearShop((Config.Economy.range or 6.0) - 1.0) end,
        onSelect = function() CreateThread(openSellMenu) end,
    })
end)
