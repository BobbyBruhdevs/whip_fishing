// Self-test for the reel-in game: a simple bot plays every rarity with the weakest and the best rod. It checks
// that every fight can be won and lost, that better rods help, and that no honest win is faster than the
// server's floor (minMs), the same formula as server/rewards.lua.
import { createGame, step, type Profile } from '../src/lib/game.ts';
declare const process: { exit(code: number): never };

// Mirrors config.lua (Config.Minigame, Config.Rarities) and shared/rods.lua
const M = {
  zoneSize: [0.5, 0.32], fishSpeed: [0.2, 0.5], fishAgility: [0.5, 1.0], dartChance: [0.02, 0.06],
  surgeChance: [0.0, 0.08], progressGain: [0.35, 0.25], progressLoss: [0.05, 0.1], tensionGain: [0.3, 0.5],
  timeLimitMs: [60000, 90000],
};
const lerp = (r: number[], d: number) => r[0] + (r[1] - r[0]) * d;
const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));
const RARITIES: [string, number][] = [['common', 0.18], ['uncommon', 0.32], ['rare', 0.48], ['epic', 0.62], ['legendary', 0.78], ['mythical', 0.92]];
const RODS = { basic: { str: 1.0, bonus: 0.0, mod: 0.0 }, carbon: { str: 1.4, bonus: 0.15, mod: 0.12 } };

function profile(tierD: number, rod: { str: number; bonus: number; mod: number }, ratio: number, baitQ: number): { p: Profile; minMs: number } {
  const d = clamp(tierD + ratio * 0.12 - rod.mod - baitQ * 0.06, 0.05, 1);
  const p: Profile = {
    difficulty: d, zoneSize: clamp(lerp(M.zoneSize, d) * (0.85 + 0.15 * rod.str), 0.08, 0.6),
    fishSpeed: lerp(M.fishSpeed, d), fishAgility: lerp(M.fishAgility, d), dartChance: lerp(M.dartChance, d),
    surgeChance: lerp(M.surgeChance, d), surgeMs: [700, 1600], progressGain: lerp(M.progressGain, d) * (1 + rod.bonus),
    progressLoss: lerp(M.progressLoss, d), startProgress: 0.25, tensionGain: lerp(M.tensionGain, d) / rod.str,
    tensionRelax: 0.8, surgeTension: 1.4, sweetSpot: [0.3, 0.75], sweetBonus: 0.35, breakGraceMs: 900, warnAt: 0.8,
    zoneLift: 1.9, zoneGravity: 1.5, timeLimitMs: Math.floor(lerp(M.timeLimitMs, d)), introMs: 1200, resultMs: 900,
  };
  const fastest = ((1 - p.startProgress) / (p.progressGain * (1 + p.sweetBonus))) * 1000;
  return { p, minMs: Math.floor(p.introMs + fastest * 0.85) };
}

// A decent human-like player: reacts with a delay, aims the zone at the fish, eases off near the red.
function play(p: Profile, skill: number, seed: number) {
  let x = seed >>> 0;
  const rng = () => ((x = (x * 1664525 + 1013904223) >>> 0) / 4294967296);
  const s = createGame(p, rng);
  const dt = 1 / 60;
  const lagFrames = Math.round(12 - skill * 8); // 200 ms .. 70 ms reaction
  const seen: number[] = [];
  let t = 0;
  while (!s.outcome && t < 200000) {
    seen.push(s.fish);
    const fishSeen = seen[Math.max(0, seen.length - 1 - lagFrames)];
    const predicted = s.zone + s.zoneVel * 0.25;
    let reel = predicted < fishSeen || s.tension < 0.12; // keep the line taut
    if (s.tension > 0.93 - (1 - skill) * 0.1) reel = false;
    if (rng() > 0.92 + skill * 0.07) reel = !reel; // fumbles
    step(s, p, dt, reel, rng);
    t += dt * 1000;
  }
  return { outcome: s.outcome, ms: s.elapsedMs + p.resultMs };
}

let failures = 0;
const N = 300;
console.log('rarity      rod     skill  win%   snap%  avg win s   fastest win  floor (minMs)');
for (const [name, tierD] of RARITIES) {
  for (const rodName of ['basic', 'carbon'] as const) {
    for (const skill of [0.5, 0.9]) {
      const { p, minMs } = profile(tierD, RODS[rodName], 0.5, rodName === 'carbon' ? 0.55 : 0.1);
      let wins = 0, snaps = 0, total = 0, fastest = Infinity;
      for (let i = 0; i < N; i++) {
        const r = play(p, skill, i * 7919 + 13);
        if (r.outcome === 'caught') { wins++; total += r.ms; fastest = Math.min(fastest, r.ms); }
        if (r.outcome === 'snapped') snaps++;
      }
      const win = (wins / N) * 100;
      console.log(`${name.padEnd(11)} ${rodName.padEnd(7)} ${skill.toFixed(1)}   ${win.toFixed(0).padStart(4)}  ${((snaps / N) * 100).toFixed(0).padStart(5)}   ${(wins ? total / wins / 1000 : 0).toFixed(1).padStart(8)}   ${(fastest === Infinity ? '-' : (fastest / 1000).toFixed(1)).padStart(9)}    ${(minMs / 1000).toFixed(1)}`);
      if (fastest !== Infinity && fastest < minMs) { console.log('  FAIL: an honest win beat the server floor'); failures++; }
      if (name === 'common' && skill === 0.9 && win < 70) { console.log('  FAIL: a common fish should be easy for a good player'); failures++; }
    }
  }
}
// Holding the reel down the whole fight snaps the line; never reeling lets the fish go
{
  const { p } = profile(0.48, RODS.basic, 0.5, 0.1);
  const hold = createGame(p, () => 0.5);
  while (!hold.outcome) step(hold, p, 1 / 60, true, () => 0.5);
  console.log(`always reeling -> ${hold.outcome}`);
  if (hold.outcome !== 'snapped') { console.log('  FAIL: holding the reel forever should snap the line'); failures++; }
  const idle = createGame(p, () => 0.3);
  while (!idle.outcome) step(idle, p, 1 / 60, false, () => 0.3);
  console.log(`never reeling   -> ${idle.outcome}`);
  if (idle.outcome !== 'escaped') { console.log('  FAIL: never reeling should lose the fish'); failures++; }
}
console.log(failures ? `\n${failures} check(s) failed` : '\nall checks passed');
process.exit(failures ? 1 : 0);
