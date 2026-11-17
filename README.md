# whip_fishing

An advanced, server-authoritative fishing system for FiveM on the WHIP framework.

- **4 rods**: Basic, Fiberglass, Professional and Advanced Carbon. Each has a success bonus, a rarity bonus, reel strength, durability and a difficulty modifier. Rods are never consumed. They wear out and can be repaired.
- **6 baits**: Worm, Insect, Minnow, Shrimp, Lure and Premium. You pick one per cast, the last choice is remembered, and bait is taken at a configurable point. Bait that has been taken is never given back.
- **18 fish across 6 rarities** (Common to Mythical), each with a randomised weight. Bigger fish fight harder.
- **9 fishing spots**: piers, ocean, docks, lakes, a river and remote spots. Each spot has its own fish, bait bonuses, blips, info points and optional opening hours.
- **Reeling in is WHIP's own skill check** (the ring its lockpicks use), run by the server: push the dot onto the lit part and hold it until it fills, part after narrower part. Mouse or right stick. Rarer fish get more, narrower parts; better rods give more time and wider last parts.

## Requirements

- `whip_core` (WHIP 1.0 or newer). `whip_rope` is optional (it draws the line). That is all: there is no ox_inventory, QBCore or ESX dependency.
- oxmysql, which WHIP already needs.

## Install

1. Put the `whip_fishing` folder in your resources (already done if this came from Claude).
2. In `server.cfg`, add this **below** WHIP's own lines:
   ```
   ensure whip_fishing
   ```
3. Restart the server, or run `refresh` then `ensure whip_fishing` in the console. The console should print the resource's start line. If the config has a mistake, every problem is printed in red and the resource refuses to start.
4. In game, open `/whip → Economy → Items`, give yourself `whip_fishing_rod_basic` and some `whip_fishing_bait_worm`, then go to a spot (the blips are on the map).

The built UI is already in `html/`. You only need Node if you change the UI (see *Changing the UI* below).

## How to fish

1. Stand inside a fishing spot. You get a "Fishing spot" notice, and the spot has a blip.
2. Either **use a rod** from your inventory, or choose **Go Fishing** on the F1 wheel, which picks your best rod that isn't broken.
3. Choose your bait. You are only asked when you carry more than one kind, and your last choice is remembered. Using a bait item sets it as your bait for the next cast.
4. Face the water. The line is cast and you wait. Your Interact key / controller button strikes, and your Cancel key reels in.
5. When a fish bites (splash, rumble, "Strike!"), strike within the window. Striking too early spooks the fish.
6. **The fight:** the bar at the bottom of the screen only says **Small**, **Medium** or **Large**. What it is stays a surprise. Then WHIP's ring appears: push the dot onto the lit part and hold it until it fills, part after part. Missing lets the fish go (and a failure can snap the line).
7. A short **in-game catch cutscene** plays: WHIP's camera swings round in front of your character, who holds the fish up to show it off, with cinema bars, then the catch card **reveals** the fish, its rarity, its weight and the real-life fish it stands for. Tune or turn it off in `Config.Cutscene`.
8. Landed fish go into your pockets, or onto the ground next to you if your pockets are full, carrying their weight, rarity, spot, angler and time in their metadata. Legendary and Mythical catches are announced to the server.

At an info point (Del Perro Pier by default), the **Fishing Spot** prompt shows the spot's hours, the fish known there and the baits that work well.

## Configuration

Everything is in `config.lua` and `shared/`. Every value is commented where it is defined.

| File | What it holds |
|---|---|
| `config.lua` | Rarities (weights, colours, announcements, wear, screen effects), casting distances, bite timing and chances, **when bait is taken** (`Config.BaitConsumption.point`: `cast`, `bite`, `hook` or `end`), cooldowns, durability and the repair kit, weight rolls, the skill check ring for each rarity (`Config.SkillCheck`), animations, the rod prop, the fishing line, effects, sounds, UI and blips |
| `shared/rods.lua` | The 4 rods and their stats |
| `shared/bait.lua` | The 6 baits: quality, bite speed and chance, rarity modifiers, big-fish bonus, consume chance |
| `shared/fish.lua` | The 18 fish: rarity, weight range, where they live, which baits they take, preferred bait, hours, extra difficulty |
| `shared/locations.lua` | The spots |

**The coordinates in `shared/locations.lua` are a starting set and approximate.** Walk to each spot in game and check that its sphere covers the shore or pier you want. For your own spot, stand there, open `/w → Coords`, press G, and paste the position.

Reeling in is WHIP's ring skill check. Each rarity has its own ring in `Config.SkillCheck.levels`, in WHIP's own numbers (`pieces`, `parts`, `widest`, `narrowest`, `msPerPart`). A rod's `reelStrength` multiplies the time per part, a rod with `difficultyModifier` 0.08 or more keeps the last parts one piece wider, and a fish in the top 15% of its species' weight adds one part. The shipped rings are easy: 3 wide parts for a common fish up to 8 for a mythical one. Holding the mouse, the right stick and the ring's hold time follow WHIP's own settings (`Config.SkillCheckHoldMs`, `Config.SkillCheckMouseSpeed` in whip_core).

## Look and the fishing line

- **The UI uses WHIP's own styles.** The page loads whip_core's `base.css` and fonts and reads only WHIP's tokens (`--ui-surface`, `--ui-accent`, `--ui-font` and the rest), so it looks like every other WHIP screen. If your server runs a WHIP theme (`Config.Theme` or `SetActiveTheme`), the fishing UI wears it too. Controller hints use WHIP's own button glyphs.
- **The fishing line is a whip_rope rope** when whip_rope is started: a real, physical line from the rod's tip to where it landed, locked so nobody can grab, tie or hang off it, and taken in when the attempt ends. Without whip_rope (or with `Config.Line.whipRope = false`) a plain drawn line is used instead. Tune its thickness and sag in `Config.Line`.

## Real fish photos

Each fish in `shared/fish.lua` names the real species it stands for (`real`, `scientific`), shown on the catch card. If a photo exists at `html/img/photos/whip_fishing_<fish key>.webp` (for example `whip_fishing_bluegill.webp`), the card shows it as a small polaroid. No photos are bundled: the card falls back to the species name alone. Use only photos you have the right to ship (your own, public domain, or Creative Commons with the credit kept in a `CREDITS.md`), and add the photo files to the manifest's `files` list if you use another extension.

## Treasure chests

Now and then a strike turns out to be a **Sunken Chest** instead of a fish (`Config.Treasure.chance`, 3.5% by default). It plays a tougher ring and shows up as "Large" like any heavy catch. **Use** the chest from your pockets to pry it open: a progress bar, then one to three finds (rusty coin up to ancient relic, `shared/treasure.lua`). Sell the finds at any tackle shop with **Sell Fish & Treasure**. Prices are per find in `shared/treasure.lua`.

## Tackle shops and selling fish

Three shops are set up in `Config.Shops` (Del Perro, Paleto Bay and the Alamo Sea). Each is a WHIP shop: an NPC with WHIP's own buy screen (basket, pay by card or cash) selling rods, bait and the repair kit. The shop keys are `whip_fishing_<id>`, so you can also edit them in the Director.

- **Buying:** talk to the NPC. Add, remove or reprice goods in `Config.Shops[n].catalog` (config keys such as `rod_basic`, `bait_worm`, `repair_kit`).
- **Selling:** use **Sell Fish** at the same NPC. A menu lists everything you carry, grouped by species, with what it pays. Pick everything or one species. Prices come from `Config.Economy`: a base per rarity, scaled by how heavy that fish is within its species (`sizeMin` to `sizeMax`). A fish can set its own `sellValue` in `shared/fish.lua`.
- WHIP has no sell-to-shop call, so the selling is this resource's own. The server finds your fish, reads each weight from the fish's own item data, takes them and pays once through WHIP. If the payment fails the fish are given back. The client never sends a price.

The shop coordinates are approximate. Stand where you want the NPC, open `/w -> Coords`, press G and paste.

## Security

- The server decides everything that matters: whether you are in a spot and whether it is open, where the line can land, the bite timing, the species, the weight, the difficulty, the bait use, the rod wear and the reward. The client only asks, animates and draws.
- Every request from a player goes through `SecureEvent` or `SecureCallback`, with typed parameters (the rod is a checked inventory slot, the bait an enum of real bait items) and rate limits. Nothing is a bare `RegisterNetEvent`.
- One session per player, cooldowns per character, and a maximum session length. A strike faster than a human can react is refused, and refusals are recorded with `RecordEventRejection`.
- The fight is a WHIP `SkillCheck` with a per-rarity floor (`minMs`): a "win" sent faster than the fish can honestly be landed is refused by whip_core.
- After every wait (timers, metadata writes, the fight), the server checks that the session is still the live one and that `IsSessionCurrent` still holds for the character, so swapping characters or logging out mid-fight gives nothing.
- Bait is taken once and never refunded. The rod is found again by its own id before it is worn, so moving it mid-fight loses the fish instead of wearing a different rod.

## Changing the UI

The UI's source is in `web/`. To rebuild it:

```
cd web
npm install
npm run build      # type-checks, then writes ../html
npm run dev        # the UI in a browser, with a demo panel
```

The build targets Chromium 103, FiveM's browser. Restart the resource after a build.

## Verification that was done

- Every `.lua` file parses under Lua 5.4.
- An offline Lua self-test loads the config, the shared data and the server's roll logic. It checks the config validator, the 4/6/18/6 counts, that every fish can bite somewhere, the rarity spread with the weakest and best rod, that weights stay in range, and that every fight profile stays inside whip_core's skill-check limits.
- Every `Whip.core:` and `exports.whip_core:` call in the resource was checked against whip_core's own type stubs (`types/server.lua` and `types/client.lua`). All of them exist.
- `tsc` and the production build pass.

**Not done yet:** this has not run on a live server. The WHIP scanner from the `fivem-whip` skill was not available, so the API check above stood in for it. Run the scanner yourself if you have it, and test each spot's coordinates in game.

## Files

```
fxmanifest.lua   config.lua   README.md
shared/   rods, bait, fish, treasure, locations, utils (lookups and the config validator)
server/   security (sessions, cooldowns, checks), inventory (items, rods, bait, fish), line (the whip_rope line),
          rewards (every roll), shops (tackle shops and selling fish), fishing (the state machine), main (registration, events)
client/   ui, animations, props (water, line, effects), cutscene (the catch camera), shops (Sell Fish prompt),
          fishing (bait, casting, the mode loop), main (zones, wheel entry, info points)
html/     the built UI and item icons (html/img/items/*.webp)
web/      the UI source
```
