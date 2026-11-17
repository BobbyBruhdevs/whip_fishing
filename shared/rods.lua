-- ============================================================================================================
-- Fishing rods. The key becomes the item key with Config.ItemPrefix in front (rod_basic -> whip_fishing_rod_basic).
--
-- tier             1 (basic) .. 4 (best): used to pick the best rod for the F1 wheel's "Go fishing"
-- successBonus     added to the bite chance (0.0 .. 0.3)
-- rarityBonus      scales up each rarer tier: weight *= 1 + rarityBonus * tierIndex
-- reelStrength     1.0 = baseline: more time per skill check part (msPerPart * reelStrength)
-- durability       its maximum; each landed fish wears it by the fish's tier wear (config.lua)
-- difficultyModifier 0.0 .. 0.2: 0.08 or more keeps the skill check ring's last parts one piece wider
-- biteTimeMult     multiplies the wait before a bite (below 1 = faster)
-- weight           kg (the item)
-- prop             optional { model, bone, offset, rot } instead of Config.RodProp
--
-- Better rods help, but a basic rod catches every fish: the bonuses are multipliers on chances that always
-- exist, never gates.
-- ============================================================================================================

Rods = {
    rod_basic = {
        label = 'Basic Fishing Rod',
        desc = 'A cheap rod with a squeaky reel. It catches fish, mostly the small ones.',
        tier = 1,
        successBonus = 0.0,
        rarityBonus = 0.0,
        reelStrength = 1.0,
        durability = 60,
        difficultyModifier = 0.0,
        biteTimeMult = 1.0,
        weight = 1.2,
    },
    rod_fiberglass = {
        label = 'Fiberglass Fishing Rod',
        desc = 'Flexible fiberglass that forgives a heavy hand.',
        tier = 2,
        successBonus = 0.05,
        rarityBonus = 0.12,
        reelStrength = 1.12,
        durability = 100,
        difficultyModifier = 0.04,
        biteTimeMult = 0.95,
        weight = 1.1,
    },
    rod_professional = {
        label = 'Professional Fishing Rod',
        desc = 'Tournament grade with a smooth drag. Rare fish notice the difference.',
        tier = 3,
        successBonus = 0.10,
        rarityBonus = 0.25,
        reelStrength = 1.25,
        durability = 160,
        difficultyModifier = 0.08,
        biteTimeMult = 0.9,
        weight = 1.0,
    },
    rod_carbon = {
        label = 'Advanced Carbon Fishing Rod',
        desc = 'Featherlight carbon fibre and a sealed reel built for the fish of legend.',
        tier = 4,
        successBonus = 0.15,
        rarityBonus = 0.40,
        reelStrength = 1.4,
        durability = 240,
        difficultyModifier = 0.12,
        biteTimeMult = 0.85,
        weight = 0.8,
        prop = { model = 'prop_fishing_rod_02' },
    },
}
