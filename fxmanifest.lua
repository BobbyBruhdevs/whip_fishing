-- whip_fishing: an advanced, server-authoritative fishing system for WHIP.
-- Rods, bait, a fish database with six rarities and fishing spots. Reeling in is WHIP's own skill check
-- (the ring), run by the server, so whip_core keeps the token, the timings and the answer.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'whip_fishing'
description 'Advanced fishing: rods, bait, 18 fish in six rarities, fishing spots and WHIP skill check reeling'
version '1.0.0'

dependency 'whip_core'
whip_requires '1.0'

shared_scripts {
    '@whip_core/lib/satellite.lua',   -- first: Whip.register, Whip.core, Whip.skillCheckGame, Whip.padScreen
    'config.lua',
    'shared/rods.lua',
    'shared/bait.lua',
    'shared/fish.lua',
    'shared/treasures.lua',
    'shared/locations.lua',
    'shared/utils.lua',               -- lookups and the config check, read by both sides
}

server_scripts {
    'server/security.lua',   -- sessions, cooldowns, location and time checks
    'server/inventory.lua',  -- item registration, rod metadata, bait helpers
    'server/rewards.lua',    -- every roll: bite time, species, weight, wear, the skill check ring
    'server/line.lua',       -- the fishing line as a whip_rope rope (optional)
    'server/shops.lua',      -- tackle shops (WHIP's EnsureShop) and selling fish
    'server/fishing.lua',    -- the fishing session, start to catch
    'server/main.lua',       -- Whip.register: items, use handlers, SecureEvents, the skill check game, cleanup
}

client_scripts {
    'client/ui.lua',          -- NUI messages
    'client/animations.lua',  -- cast, idle and fight animations
    'client/props.lua',       -- the water probe, splash effects, the line's end point
    'client/cutscene.lua',    -- the in-game catch cutscene: WHIP camera, the player holding up the fish
    'client/fishing.lua',     -- the fishing mode: bait choice, cast, waiting, the bite, cancel
    'client/shops.lua',       -- the "Sell Fish" prompt at each shop
    'client/main.lua',        -- prompts, the F1 wheel entry, lifecycle and cleanup
}

ui_page 'html/index.html'
nui_callback_strict_mode 'true'

files {
    'html/index.html',
    'html/assets/*.js',
    'html/assets/*.css',
    'html/img/items/*.webp',
    'html/img/photos/*.webp',
}
