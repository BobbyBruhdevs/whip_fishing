-- ============================================================================================================
-- Treasures: the rare items a sunken chest holds. The server prices them here (never from the client), the
-- tackle shop buys them like fish. Keys are lowercase words; they must not collide with fish, bait or rod keys.
-- ============================================================================================================

Treasures = {}

Treasures.captains_coin   = { label = "Captain's Coin",   desc = 'A worn doubloon, minted long before this pier stood.', price = 240,  weight = 0.05 }
Treasures.old_ring        = { label = 'Old Ring',         desc = 'Tarnished silver, still round. Someone misses it.',   price = 350,  weight = 0.05 }
Treasures.pearl_necklace  = { label = 'Pearl Necklace',   desc = 'Saltwater pearls, a little dull from the deep.',      price = 520,  weight = 0.1  }
Treasures.ancient_vase    = { label = 'Ancient Vase',     desc = 'Cracked but whole. A museum would pay for this.',     price = 800,  weight = 1.5  }
Treasures.golden_compass  = { label = 'Golden Compass',   desc = 'Its needle still turns. Never towards north.',        price = 1200, weight = 0.4  }
Treasures.jeweled_dagger  = { label = 'Jeweled Dagger',   desc = 'More jewel than dagger now. Best sold quietly.',      price = 1500, weight = 0.6  }
Treasures.sunken_idol     = { label = 'Sunken Idol',      desc = 'Gold, ancient and heavy with meaning no one remembers.', price = 2500, weight = 3.0 }
