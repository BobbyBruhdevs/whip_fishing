-- ============================================================================================================
-- Fishing spots. A player can only fish while standing inside one (the server checks), facing water (the client
-- finds the surface, the server bounds where it says the line landed).
--
-- id            unique, lowercase
-- label         display name
-- type          lake, river, ocean, pier, dock or remote: fish whose `waters` list it can bite here
-- coords        the spot's centre (vector3)
-- radius        metres from the centre a player may fish
-- fish          optional list of fish keys: if set, ONLY these bite here (replaces the `waters` match)
-- extraFish     optional list of fish keys added on top of the `waters` match
-- rarityMods    per rarity key: multiplies that tier's weight here
-- baitBonus     per bait key: { bite = mult on the bite chance, rarity = mult on every non-common tier }
-- biteTimeMult  multiplies every wait here
-- hours         optional { from, to } server hours the spot can be fished (wraps past midnight)
-- blip          true (Config.Blip) or { sprite, color, scale }; nil/false for none
-- infoPoint     optional vector3: a prompt there shows what bites here
--
-- Coordinates are a starting set. Stand where you want a spot in game, /w -> Coords, press G, paste here.
-- ============================================================================================================

Locations = {
    {
        id = 'pier_delperro', label = 'Del Perro Pier', type = 'pier',
        coords = vector3(-1850.0, -1250.0, 8.6), radius = 70.0,
        rarityMods = { common = 1.0, rare = 1.1 },
        baitBonus = { bait_shrimp = { bite = 1.2, rarity = 1.1 } },
        biteTimeMult = 1.0,
        blip = true,
        infoPoint = vector3(-1835.5, -1232.0, 13.0),
    },
    {
        id = 'pier_paleto', label = 'Paleto Bay Pier', type = 'pier',
        coords = vector3(-275.0, 6635.0, 7.4), radius = 70.0,
        extraFish = { 'salmon' },
        rarityMods = { rare = 1.15, epic = 1.15, mythical = 1.2 },
        baitBonus = { bait_lure = { bite = 1.15, rarity = 1.15 } },
        biteTimeMult = 1.05,
        blip = true,
    },
    {
        id = 'ocean_chumash', label = 'Chumash Coast', type = 'ocean',
        coords = vector3(-3200.0, 1150.0, 2.0), radius = 280.0,
        rarityMods = { uncommon = 1.1, epic = 1.1 },
        baitBonus = { bait_shrimp = { bite = 1.15 } },
        biteTimeMult = 1.1,
        blip = true,
    },
    {
        id = 'dock_puerta', label = 'Puerto Del Sol Marina', type = 'dock',
        coords = vector3(-830.0, -1440.0, 1.6), radius = 120.0,
        rarityMods = { common = 1.2, rare = 0.85, legendary = 0.6 },
        baitBonus = { bait_worm = { bite = 1.1 } },
        biteTimeMult = 0.9,
        blip = true,
    },
    {
        id = 'lake_alamo', label = 'Alamo Sea Pier', type = 'lake',
        coords = vector3(1299.0, 4216.0, 33.9), radius = 120.0,
        extraFish = { 'catfish' },
        rarityMods = { uncommon = 1.15, legendary = 1.1 },
        baitBonus = { bait_worm = { bite = 1.15 }, bait_minnow = { rarity = 1.1 } },
        biteTimeMult = 1.0,
        blip = true,
        infoPoint = vector3(1301.5, 4228.0, 33.9),
    },
    {
        id = 'lake_landact', label = 'Land Act Reservoir', type = 'lake',
        coords = vector3(1800.0, 80.0, 170.0), radius = 260.0,
        rarityMods = { rare = 1.1, epic = 1.15 },
        baitBonus = { bait_lure = { bite = 1.1, rarity = 1.1 } },
        biteTimeMult = 1.05,
        blip = true,
    },
    {
        id = 'river_zancudo', label = 'Zancudo River', type = 'river',
        coords = vector3(-1950.0, 2600.0, 2.0), radius = 300.0,
        rarityMods = { uncommon = 1.1, rare = 1.15, legendary = 1.2 },
        baitBonus = { bait_insect = { bite = 1.15 } },
        biteTimeMult = 1.0,
        blip = true,
    },
    {
        id = 'remote_cassidy', label = 'Cassidy Creek', type = 'remote',
        coords = vector3(-500.0, 4400.0, 30.0), radius = 260.0,
        rarityMods = { common = 0.85, rare = 1.2, epic = 1.25, legendary = 1.3, mythical = 1.2 },
        baitBonus = { bait_insect = { bite = 1.2, rarity = 1.1 } },
        biteTimeMult = 1.15,
        hours = { from = 5, to = 22 },
        blip = false,   -- remote spots are found, not shown
    },
    {
        id = 'remote_raton', label = 'Raton Canyon', type = 'remote',
        coords = vector3(-1500.0, 4400.0, 15.0), radius = 300.0,
        rarityMods = { common = 0.8, rare = 1.2, epic = 1.3, legendary = 1.35, mythical = 1.3 },
        baitBonus = { bait_minnow = { bite = 1.1, rarity = 1.15 } },
        biteTimeMult = 1.2,
        blip = false,
    },
}
