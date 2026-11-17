
-- ============================================================================================================
-- whip_fishing: configuration
-- ============================================================================================================
-- Easy Fishing Configuration
-- Faster bites, increased rare fish chances, easier skill checks and reduced durability loss.
-- Restart whip_fishing after making changes.
-- ============================================================================================================

Config = {}

-- Debug
Config.Debug = false

-- Item prefix
Config.ItemPrefix = 'whip_fishing_'

-- ------------------------------------------------------------------------------------------------------------
-- Rarities
-- Increased weights for uncommon, rare, epic, legendary and mythical fish.
-- ------------------------------------------------------------------------------------------------------------

Config.Rarities = {
    { key = 'common',    label = 'Common',    weight = 100, color = '#9aa7b4', announce = false, wear = 1, screenEffect = false },
    { key = 'uncommon',  label = 'Uncommon',  weight = 65,  color = '#4fd18b', announce = false, wear = 1, screenEffect = false },
    { key = 'rare',      label = 'Rare',      weight = 35,  color = '#3fa9ff', announce = false, wear = 1, screenEffect = false },
    { key = 'epic',      label = 'Epic',      weight = 18,  color = '#b26bff', announce = false, wear = 2, screenEffect = 'SuccessNeutral' },
    { key = 'legendary', label = 'Legendary', weight = 8,   color = '#ffb547', announce = true,  wear = 2, screenEffect = 'SuccessFranklin' },
    { key = 'mythical',  label = 'Mythical',  weight = 3,   color = '#ff4f7b', announce = true,  wear = 3, screenEffect = 'SuccessMichael' },
}

-- ------------------------------------------------------------------------------------------------------------
-- Casting
-- ------------------------------------------------------------------------------------------------------------

Config.Cast = {
    minDistance   = 4.0,
    maxDistance   = 18.0,
    probeStep     = 2.0,
    probeDown     = 40.0,
    serverSlack   = 6.0,
    maxWaterBelow = 60.0,
}

-- ------------------------------------------------------------------------------------------------------------
-- Bites
-- Much faster bites and a substantially higher chance of getting a bite.
-- ------------------------------------------------------------------------------------------------------------

Config.Bite = {
    minMs            = 2500,
    maxMs            = 8000,
    floorMs          = 1500,
    ceilMs           = 12000,
    baseChance       = 0.95,
    maxWaits         = 6,
    hookWindowMs     = 3000,
    minReactionMs    = 100,
    maxBites         = 5,
    rebiteMs         = { 1500, 3500 },
    earlyStrikeDelay = { 1000, 2000 },
}

-- ------------------------------------------------------------------------------------------------------------
-- Bait consumption
-- Bait is consumed when casting instead of hooking.
-- ------------------------------------------------------------------------------------------------------------

Config.BaitConsumption = {
    point    = 'cast',
    onEscape = false,
}

-- ------------------------------------------------------------------------------------------------------------
-- Cooldowns
-- ------------------------------------------------------------------------------------------------------------

Config.Cooldown = {
    afterCatchMs  = 1000,
    afterLossMs   = 2000,
    afterCancelMs = 1000,
    castRateMs    = 1000,
    sessionMaxMs  = 180000,
}

-- ------------------------------------------------------------------------------------------------------------
-- Rod durability
-- Rods last longer and are less likely to snap.
-- ------------------------------------------------------------------------------------------------------------

Config.Durability = {
    enabled        = true,
    snapChance     = 0.10,
    snapWear       = 1,
    breakBehaviour = 'keep',
}

-- ------------------------------------------------------------------------------------------------------------
-- Repair kit
-- ------------------------------------------------------------------------------------------------------------

Config.RepairKit = {
    enabled  = true,
    restore  = 40,
    duration = 6000,
    anim     = { dict = 'mini@repair', clip = 'fixing_a_ped' },
}

-- ------------------------------------------------------------------------------------------------------------
-- Sunken chests
-- A share of landed catches is a chest instead of a fish. It goes in the pockets; using it pries it open and
-- rolls the rare treasures inside (shared/treasures.lua), sold at the tackle shop with the fish.
-- ------------------------------------------------------------------------------------------------------------

Config.Chest = {
    enabled  = true,
    chance   = 0.04,    -- share of landed catches (0.04 = one in twenty-five)
    wear     = 2,       -- rod wear for landing one
    weight   = 8.0,     -- what the catch card shows
    announce = true,    -- everyone hears about a chest coming up
    openMs   = 3500,    -- prying it open
    anim     = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    minDrops = 1,       -- how many treasures a chest holds
    maxDrops = 2,
    drops = {           -- what it holds, by the weight of the draw (keys of Treasures)
        { key = 'captains_coin',  weight = 30 },
        { key = 'old_ring',       weight = 25 },
        { key = 'pearl_necklace', weight = 20 },
        { key = 'ancient_vase',   weight = 12 },
        { key = 'golden_compass', weight = 8  },
        { key = 'jeweled_dagger', weight = 4  },
        { key = 'sunken_idol',    weight = 1  },
    },
}

-- ------------------------------------------------------------------------------------------------------------
-- Fish weights
-- Increased average fish sizes.
-- ------------------------------------------------------------------------------------------------------------

Config.Weight = {
    exponent = 1.15,
    decimals = 2,
}

-- ------------------------------------------------------------------------------------------------------------
-- Preferred bait and rod rarity bonuses
-- ------------------------------------------------------------------------------------------------------------

Config.PreferredBaitMultiplier = 3.0
Config.RodRarityScale = 1.5

-- ------------------------------------------------------------------------------------------------------------
-- Skill check
-- Easier reeling for every rarity, including mythical fish.
-- Wider target areas, fewer parts and more time per part.
-- ------------------------------------------------------------------------------------------------------------

Config.SkillCheck = {
    levels = {
        common    = { pieces = 4,  parts = 2, widest = 4, narrowest = 3, msPerPart = 1400 },
        uncommon  = { pieces = 4,  parts = 2, widest = 4, narrowest = 3, msPerPart = 1300 },
        rare      = { pieces = 8,  parts = 3, widest = 7, narrowest = 5, msPerPart = 1200 },
        epic      = { pieces = 8,  parts = 3, widest = 7, narrowest = 5, msPerPart = 1100 },
        legendary = { pieces = 8,  parts = 4, widest = 7, narrowest = 5, msPerPart = 1100 },
        mythical  = { pieces = 16, parts = 4, widest = 14, narrowest = 10, msPerPart = 1000 },
    },

    bigFishExtraPart = false,
}

-- ============================================================================================================
-- END OF CONFIGURATION
-- ============================================================================================================

-- ------------------------------------------------------------------------------------------------------------
-- Animations (client). Each is { dict, clip, flag? }.
-- ------------------------------------------------------------------------------------------------------------
Config.Animations = {
    cast  = { dict = 'mini@tennis',                         clip = 'forehand_ts_md_far', flag = 48, durationMs = 1100 },
    idle  = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_c',             flag = 49 },
    bite  = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_b',             flag = 49 },
    reel  = { dict = 'amb@world_human_stand_fishing@idle_a', clip = 'idle_a',             flag = 49, rate = 1.6 },
    catch = { dict = 'mp_player_intcelebrationmale',          clip = 'thumbs_up',          flag = 48, durationMs = 1800 },
}

-- The rod in hand (server HoldProps, so everyone sees it). Each rod may override `prop`.
Config.RodProp = {
    model  = 'prop_fishing_rod_01',
    bone   = 60309,
    offset = { 0.0, 0.0, 0.0 },
    rot    = { 0.0, 0.0, 0.0 },
}

-- The fishing line drawn from the rod's tip to where it landed (client, only while a line is out).
-- tipOffset is in the rod prop's own frame; adjust it if a custom rod model is longer or turned.
Config.Line = {
    enabled   = true,
    whipRope  = true,      -- use whip_rope for the line when it is started (a real, physical line); else drawn
    thickness = 0.08,      -- whip_rope only: scale of its 3.5 cm rope piece (0.08 = about 3 mm)
    slack     = 1.04,      -- whip_rope only: the line's length as a share of the distance (a little sag)
    tipOffset = vector3(0.0, 0.0, 1.95),
    color     = { 225, 235, 240, 150 },
    biteColor = { 120, 220, 255, 230 },
}

-- Particle effects at the line's end (client). enabled = false to turn one off.
Config.Effects = {
    castSplash = { enabled = true, asset = 'core', name = 'ent_anim_bm_water_mist', scale = 0.6 },
    biteSplash = { enabled = true, asset = 'core', name = 'ent_anim_bm_water_mist', scale = 1.2 },
    biteShake  = { enabled = true, type = 'SMALL_EXPLOSION_SHAKE', amplitude = 0.05 },
    rumbleMs   = 220,   -- controller rumble on a bite
}

-- Sounds. The NUI plays its own (synthesised, no files); GTA frontend sounds play on top where set.
Config.Sounds = {
    volume = 0.6,              -- the NUI's volume, 0..1
    bite   = { name = 'CHECKPOINT_NORMAL',  set = 'HUD_MINI_GAME_SOUNDSET' },
    catch  = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },
    lost   = { name = 'CHECKPOINT_MISSED',  set = 'HUD_MINI_GAME_SOUNDSET' },
    cast   = false,
}

-- ------------------------------------------------------------------------------------------------------------
-- Tackle shops and selling fish
-- Each shop is a WHIP shop (an NPC with WHIP's own buy screen: basket, pay by card or cash) for rods, bait and the
-- repair kit. The same NPC buys your fish: use "Sell Fish" at the shop. `catalog` keys are config keys (a rod key
-- from shared/rods.lua, a bait key from shared/bait.lua, or 'repair_kit'); the item prefix is added for you.
-- The coordinates are approximate: stand where you want the NPC, open /w -> Coords, press G, and paste.
-- ------------------------------------------------------------------------------------------------------------
Config.Shops = {
    {
        id = 'del_perro', name = 'Del Perro Bait & Tackle', npcModel = 'a_m_m_hillbilly_01',
        coords = vector4(-1862.6865, -1203.1532, 13.0171, 71.8531), blipSprite = 68, blipColor = 3,
        catalog = {
            rod_basic = 150, rod_fiberglass = 600, rod_professional = 1800, rod_carbon = 5000,
            bait_worm = 5, bait_insect = 8, bait_minnow = 15, bait_shrimp = 20, bait_lure = 250, bait_premium = 120,
            repair_kit = 300,
        },
    },
    {
        id = 'paleto', name = 'Paleto Bay Bait & Tackle', npcModel = 'a_m_m_farmer_01',
        coords = vector4(-275.6, 6635.9, 7.4, 135.0), blipSprite = 68, blipColor = 3,
        catalog = {
            rod_basic = 150, rod_fiberglass = 600, rod_professional = 1800,
            bait_worm = 5, bait_insect = 8, bait_minnow = 15, bait_shrimp = 20, bait_lure = 250,
            repair_kit = 300,
        },
    },
    {
        id = 'sandy', name = 'Alamo Sea Tackle', npcModel = 'a_m_m_hillbilly_02',
        coords = vector4(1708.4, 3596.9, 35.3, 210.0), blipSprite = 68, blipColor = 3,
        catalog = {
            rod_basic = 150, rod_fiberglass = 600, rod_professional = 1800, rod_carbon = 5000,
            bait_worm = 5, bait_insect = 8, bait_minnow = 15, bait_shrimp = 20, bait_lure = 250, bait_premium = 120,
            repair_kit = 300,
        },
    },
}

-- What a fish sells for. Price = the rarity's base (or the fish's own `sellValue` in shared/fish.lua) times a
-- size factor from its weight: the lightest fish of a species pays `sizeMin` of the base, the heaviest `sizeMax`.
-- The server reads the weight from the fish's own item data, so nothing the client sends can change a price.
Config.Economy = {
    enabled   = true,
    currency  = '$',                 -- shown in messages and menus
    method    = 'auto',              -- how you are paid: 'cash', 'bank' or 'auto' (cash while online)
    base = { common = 20, uncommon = 45, rare = 110, epic = 260, legendary = 700, mythical = 1800 },
    sizeMin   = 0.7,
    sizeMax   = 1.3,
    range     = 6.0,                 -- how close to a shop NPC you must be to sell (metres, server checked)
}

-- ------------------------------------------------------------------------------------------------------------
-- UI
-- ------------------------------------------------------------------------------------------------------------
Config.UI = {
    scale          = 1.0,      -- the whole UI's scale on top of the automatic resolution scaling
    askBaitEachCast = false,   -- false: reuse the last bait while it is carried (change it from the bait's menu)
    showSpotHint   = true,     -- a short line when entering a fishing spot
    resultMs       = 9000,     -- how long the whole catch screen stays (cutscene included)
    blips          = true,     -- blips for every spot that sets one (shared/locations.lua)
    radialEntry    = true,     -- "Go fishing" on the F1 wheel while standing in a spot with a rod
}

-- ------------------------------------------------------------------------------------------------------------
-- The in-game catch cutscene (client, looks only): WHIP's camera swings round in front of the player, who holds
-- the fish up, then the catch card shows. Shots orbit the player: yaw 180 is in front, pitch is degrees above,
-- dist is metres, aim is a point on the player's box (-1..1; +y front, +z top).
-- The fish is a local ped or prop in the hand: a fish can set its own `cutsceneModel` in shared/fish.lua.
-- The hold is one-handed (a Contract hold idle): the fish rides the LEFT hand (bone 18905 is SKEL_L_Hand).
-- The offset and rot are taken from whip's own left-hand prop emotes (a raised palm like this one uses
-- x around +0.10 to +0.15 — a negative x is what throws the prop out onto the forearm). Nudge offset
-- in steps of 0.02 if a fish sits oddly; every fish can also set its own cutsceneModel in shared/fish.lua.
-- ------------------------------------------------------------------------------------------------------------
Config.Cutscene = {
    enabled         = true,
    letterbox       = true,
    fishModel       = 'a_c_fish',
    hold            = { dict = 'anim@scripted@player@fix_astu_ig10_shots@male@', clip = 'male_b_ped_b_hold_idle', flag = 49 },
    attach          = { bone = 18905, offset = { 0.1, -0.03, 0.03 }, rot = { 80.0, 0.0, -10.0 } },
    lengthMs        = 4600,
    transitionInMs  = 700,
    transitionOutMs = 800,
    shots = {
        { t = 0,    yaw = 140, pitch = 12, dist = 3.4, fov = 46, aim = { x = 0, y = 0, z = 0.3 } },
        { t = 1800, yaw = 178, pitch = 4,  dist = 1.8, fov = 38, aim = { x = 0, y = 0.3, z = 0.35 }, move = 'orbit', around = 'short',
          punch = { fov = 5, decay = 4 } },
        { t = 4600, yaw = 205, pitch = 7,  dist = 1.6, fov = 36, aim = { x = 0, y = 0.3, z = 0.4 } },
    },
}

-- Default blip look for spots that ask for one
Config.Blip = { sprite = 68, color = 3, scale = 0.75 }
