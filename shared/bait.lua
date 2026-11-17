-- ============================================================================================================
-- Bait. The key becomes the item key with Config.ItemPrefix in front (bait_worm -> whip_fishing_bait_worm).
--
-- quality         0..1: how good the bait is (shown to players; better bait also has better rarity mods)
-- biteChanceMult  multiplies Config.Bite.baseChance
-- biteTimeMult    multiplies the wait before a bite (below 1 = faster)
-- rarityMods      per rarity key: multiplies that tier's weight (missing = 1.0)
-- bigFishBonus    0..1: bigger fish (divides Config.Weight.exponent by 1 + bigFishBonus)
-- consumeChance   0..1: the chance it is used up at Config.BaitConsumption.point (a lure survives most casts)
-- fishBonus       optional { [fishKey] = mult }: bait-specific bonuses for single species
-- universal       true: every fish will take it, even ones whose `baits` list leaves it out
-- stack, weight   the item
-- ============================================================================================================

Baits = {
    bait_worm = {
        label = 'Worm Bait',
        desc = 'A tub of fat nightcrawlers. Everything in fresh water likes a worm.',
        quality = 0.10,
        biteChanceMult = 1.0,
        biteTimeMult = 1.0,
        rarityMods = { common = 1.25, uncommon = 1.0, rare = 0.75, epic = 0.5, legendary = 0.4, mythical = 0.3 },
        bigFishBonus = 0.0,
        consumeChance = 1.0,
        maxStack = 50,
        weight = 0.02,
    },
    bait_insect = {
        label = 'Insect Bait',
        desc = 'Crickets and grubs. Trout and panfish rise for them.',
        quality = 0.20,
        biteChanceMult = 1.05,
        biteTimeMult = 0.95,
        rarityMods = { common = 1.1, uncommon = 1.25, rare = 0.9, epic = 0.6, legendary = 0.5, mythical = 0.35 },
        bigFishBonus = 0.05,
        consumeChance = 1.0,
        fishBonus = { trout = 1.6, golden_trout = 1.4, crappie = 1.3 },
        maxStack = 50,
        weight = 0.02,
    },
    bait_minnow = {
        label = 'Minnow Bait',
        desc = 'Live minnows. Predators can\'t resist a struggling fish.',
        quality = 0.40,
        biteChanceMult = 0.95,
        biteTimeMult = 1.05,
        rarityMods = { common = 0.8, uncommon = 1.1, rare = 1.35, epic = 1.25, legendary = 1.0, mythical = 0.7 },
        bigFishBonus = 0.25,
        consumeChance = 1.0,
        fishBonus = { northern_pike = 1.6, muskie = 1.6, largemouth_bass = 1.4, walleye = 1.4, giant_bass = 1.3 },
        maxStack = 30,
        weight = 0.03,
    },
    bait_shrimp = {
        label = 'Shrimp Bait',
        desc = 'Fresh shrimp. The ocean\'s favourite snack.',
        quality = 0.35,
        biteChanceMult = 1.1,
        biteTimeMult = 0.9,
        rarityMods = { common = 1.0, uncommon = 1.1, rare = 1.15, epic = 1.1, legendary = 0.9, mythical = 0.8 },
        bigFishBonus = 0.15,
        consumeChance = 1.0,
        fishBonus = { catfish = 1.5, albino_catfish = 1.4, sturgeon = 1.4, golden_marlin = 1.3 },
        maxStack = 30,
        weight = 0.03,
    },
    bait_lure = {
        label = 'Artificial Lure',
        desc = 'A painted spinner. Reusable, but snags happen.',
        quality = 0.55,
        biteChanceMult = 0.85,
        biteTimeMult = 1.15,
        rarityMods = { common = 0.75, uncommon = 1.0, rare = 1.3, epic = 1.4, legendary = 1.2, mythical = 1.0 },
        bigFishBonus = 0.30,
        consumeChance = 0.12,
        maxStack = 10,
        weight = 0.05,
    },
    bait_premium = {
        label = 'Premium Bait',
        desc = 'A secret blend in a sealed pouch. Rumoured to tempt things that should not exist.',
        quality = 0.85,
        biteChanceMult = 1.25,
        biteTimeMult = 0.75,
        rarityMods = { common = 0.6, uncommon = 0.9, rare = 1.4, epic = 1.8, legendary = 2.4, mythical = 3.0 },
        bigFishBonus = 0.45,
        consumeChance = 1.0,
        universal = true,
        maxStack = 20,
        weight = 0.02,
    },
}
