-- ============================================================================================================
-- The fish database. The key becomes the item key with Config.ItemPrefix in front (bluegill -> whip_fishing_bluegill).
--
-- label           display name
-- rarity          a key from Config.Rarities
-- minWeight/maxWeight  kg; the server rolls the weight between them (Config.Weight)
-- chance          the fish's share inside its rarity tier (1.0 = normal)
-- baits           bait keys it will take (nil = any). A `universal` bait is always taken.
-- preferredBait   bait keys it favours (Config.PreferredBaitMultiplier)
-- waters          water types it lives in: lake, river, ocean, pier, dock, remote (see shared/locations.lua)
-- locations       optional location ids it lives in, on top of `waters` (a fish found in one spot only)
-- onlyLocations   true: ONLY the `locations` listed (ignores waters)
-- hours           optional { from, to } server hours it bites (wraps past midnight: { from = 20, to = 4 })
-- announce        overrides its tier's announce
-- effect          optional animpostfx name on a catch, overriding its tier's
-- itemWeight      kg the item weighs in the inventory (WHIP weighs every item of a key the same)
-- real            the real-life fish it stands for, and `scientific` its Latin name (shown in the catch cutscene)
-- desc            the inventory card's description
-- ============================================================================================================

local FRESH = { 'lake', 'river', 'remote' }
local SALT  = { 'ocean', 'pier', 'dock' }

Fish = {
    -- Common --------------------------------------------------------------------------------------------------
    bluegill = {
        real = 'Bluegill sunfish', scientific = 'Lepomis macrochirus',
        label = 'Bluegill', rarity = 'common', minWeight = 0.10, maxWeight = 0.60, chance = 1.2,
        preferredBait = { 'bait_worm', 'bait_insect' }, waters = FRESH, itemWeight = 0.3,
        desc = 'A plucky little sunfish with a blue cheek.',
    },
    perch = {
        real = 'Yellow perch', scientific = 'Perca flavescens',
        label = 'Perch', rarity = 'common', minWeight = 0.15, maxWeight = 1.10, chance = 1.0,
        preferredBait = { 'bait_worm', 'bait_minnow' }, waters = { 'lake', 'river', 'remote', 'dock' }, itemWeight = 0.5,
        desc = 'Striped, spiny and always hungry.',
    },
    smallmouth_bass = {
        real = 'Smallmouth bass', scientific = 'Micropterus dolomieu',
        label = 'Smallmouth Bass', rarity = 'common', minWeight = 0.30, maxWeight = 2.50, chance = 0.9,
        preferredBait = { 'bait_insect', 'bait_lure' }, waters = { 'river', 'lake', 'remote' }, itemWeight = 1.0,
        desc = 'Bronze-backed and pound for pound a fighter.',
    },

    -- Uncommon ------------------------------------------------------------------------------------------------
    catfish = {
        real = 'Channel catfish', scientific = 'Ictalurus punctatus',
        label = 'Catfish', rarity = 'uncommon', minWeight = 1.0, maxWeight = 9.0, chance = 1.0,
        preferredBait = { 'bait_shrimp', 'bait_worm' }, waters = { 'lake', 'river', 'dock' }, itemWeight = 2.5,
        desc = 'Whiskered bottom-feeder. Bites best after dark.',
    },
    trout = {
        real = 'Rainbow trout', scientific = 'Oncorhynchus mykiss',
        label = 'Trout', rarity = 'uncommon', minWeight = 0.4, maxWeight = 4.5, chance = 1.0,
        preferredBait = { 'bait_insect', 'bait_lure' }, waters = { 'river', 'remote' }, itemWeight = 1.2,
        desc = 'Speckled and quick, it lives in cold running water.',
    },
    crappie = {
        real = 'Black crappie', scientific = 'Pomoxis nigromaculatus',
        label = 'Crappie', rarity = 'uncommon', minWeight = 0.2, maxWeight = 1.8, chance = 1.0,
        preferredBait = { 'bait_minnow', 'bait_insect' }, waters = { 'lake', 'remote' }, itemWeight = 0.6,
        desc = 'A papery-mouthed panfish that schools near cover.',
    },

    -- Rare ----------------------------------------------------------------------------------------------------
    largemouth_bass = {
        real = 'Largemouth bass', scientific = 'Micropterus salmoides',
        label = 'Largemouth Bass', rarity = 'rare', minWeight = 0.8, maxWeight = 6.5, chance = 1.0,
        preferredBait = { 'bait_minnow', 'bait_lure' }, waters = { 'lake', 'remote' }, itemWeight = 2.0,
        desc = 'The bucketmouth. It hits like a truck and jumps to throw the hook.',
    },
    salmon = {
        real = 'Chinook salmon', scientific = 'Oncorhynchus tshawytscha',
        label = 'Salmon', rarity = 'rare', minWeight = 2.0, maxWeight = 14.0, chance = 1.0,
        preferredBait = { 'bait_shrimp', 'bait_lure' }, waters = { 'river', 'ocean', 'pier' }, itemWeight = 4.0,
        desc = 'Silver and powerful, fresh in from the sea.',
    },
    northern_pike = {
        real = 'Northern pike', scientific = 'Esox lucius',
        label = 'Northern Pike', rarity = 'rare', minWeight = 1.5, maxWeight = 12.0, chance = 0.9,
        baits = { 'bait_minnow', 'bait_lure', 'bait_shrimp' }, preferredBait = { 'bait_minnow' },
        waters = { 'lake', 'river', 'remote' }, itemWeight = 3.5,
        desc = 'All teeth and temper. Mind your fingers.',
    },

    -- Epic ----------------------------------------------------------------------------------------------------
    sturgeon = {
        real = 'Lake sturgeon', scientific = 'Acipenser fulvescens',
        label = 'Sturgeon', rarity = 'epic', minWeight = 8.0, maxWeight = 60.0, chance = 0.8,
        baits = { 'bait_shrimp', 'bait_worm', 'bait_minnow' }, preferredBait = { 'bait_shrimp' },
        waters = { 'river', 'ocean' }, itemWeight = 12.0,
        desc = 'An armoured relic older than the dinosaurs\' last days.',
    },
    muskie = {
        real = 'Muskellunge', scientific = 'Esox masquinongy',
        label = 'Muskie', rarity = 'epic', minWeight = 4.0, maxWeight = 25.0, chance = 0.9,
        baits = { 'bait_minnow', 'bait_lure' }, preferredBait = { 'bait_lure' },
        waters = { 'lake', 'remote' }, itemWeight = 7.0,
        desc = 'The fish of ten thousand casts.',
    },
    walleye = {
        real = 'Walleye', scientific = 'Sander vitreus',
        label = 'Walleye', rarity = 'epic', minWeight = 1.0, maxWeight = 8.0, chance = 1.1,
        preferredBait = { 'bait_minnow', 'bait_worm' }, waters = { 'lake', 'river', 'remote' },
        hours = { from = 18, to = 7 }, itemWeight = 2.5,
        desc = 'Glassy eyes made for the dark. It feeds at dusk and dawn.',
    },

    -- Legendary -----------------------------------------------------------------------------------------------
    golden_trout = {
        real = 'California golden trout', scientific = 'Oncorhynchus aguabonita',
        label = 'Golden Trout', rarity = 'legendary', minWeight = 0.8, maxWeight = 5.0, chance = 1.0,
        preferredBait = { 'bait_insect', 'bait_premium' }, waters = { 'remote' }, locations = { 'river_zancudo' },
        itemWeight = 1.5,
        desc = 'A living flame from the high streams. Few have seen one.',
    },
    albino_catfish = {
        real = 'Albino channel catfish', scientific = 'Ictalurus punctatus',
        label = 'Albino Catfish', rarity = 'legendary', minWeight = 6.0, maxWeight = 35.0, chance = 0.9,
        preferredBait = { 'bait_shrimp', 'bait_premium' }, waters = { 'lake', 'river' },
        hours = { from = 21, to = 5 }, itemWeight = 9.0,
        desc = 'Ghost-white and enormous. Only rises in the dead of night.',
    },
    giant_bass = {
        real = 'Trophy largemouth bass', scientific = 'Micropterus salmoides',
        label = 'Giant Bass', rarity = 'legendary', minWeight = 6.0, maxWeight = 14.0, chance = 1.0,
        preferredBait = { 'bait_minnow', 'bait_lure', 'bait_premium' }, waters = { 'lake', 'remote' },
        itemWeight = 6.0,
        desc = 'The lunker every angler on the lake tells stories about.',
    },

    -- Mythical ------------------------------------------------------------------------------------------------
    ancient_koi = {
        real = 'Koi carp', scientific = 'Cyprinus rubrofuscus',
        label = 'Ancient Koi', rarity = 'mythical', minWeight = 4.0, maxWeight = 18.0, chance = 1.0,
        baits = { 'bait_insect', 'bait_premium' }, preferredBait = { 'bait_premium' },
        locations = { 'lake_landact', 'remote_cassidy' }, onlyLocations = true,
        itemWeight = 6.0, effect = 'SuccessTrevor',
        desc = 'Its scales are etched like old coins. It has been waiting for you.',
    },
    golden_marlin = {
        real = 'Blue marlin', scientific = 'Makaira nigricans',
        label = 'Golden Marlin', rarity = 'mythical', minWeight = 80.0, maxWeight = 320.0, chance = 1.0,
        baits = { 'bait_lure', 'bait_shrimp', 'bait_premium' }, preferredBait = { 'bait_lure', 'bait_premium' },
        waters = { 'ocean' }, locations = { 'pier_paleto' }, itemWeight = 40.0,
        desc = 'A blade of molten gold that tows boats for miles.',
    },
    river_monster = {
        real = 'Alligator gar', scientific = 'Atractosteus spatula',
        label = 'Legendary River Monster', rarity = 'mythical', minWeight = 120.0, maxWeight = 400.0, chance = 1.0,
        baits = { 'bait_minnow', 'bait_premium' }, preferredBait = { 'bait_premium' },
        locations = { 'river_zancudo', 'remote_raton' }, onlyLocations = true,
        hours = { from = 22, to = 4 }, itemWeight = 60.0,
        desc = 'Something old lives under the Zancudo. Now it lives in your pocket.',
    },
}

-- Keep SALT referenced for anyone adding saltwater fish with `waters = SALT`
FishWaters = { fresh = FRESH, salt = SALT }
