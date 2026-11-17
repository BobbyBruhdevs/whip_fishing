// The reel-in game's rules, with no DOM: the page drives it frame by frame, and test/game.test.ts plays it
// with a bot to check every rarity can be won and lost. Positions run 0 (the bottom) to 1 (the surface).

export interface Profile {
  difficulty: number;
  zoneSize: number;
  fishSpeed: number;
  fishAgility: number;
  dartChance: number;
  surgeChance: number;
  surgeMs: [number, number];
  progressGain: number;
  progressLoss: number;
  startProgress: number;
  tensionGain: number;
  tensionRelax: number;
  surgeTension: number;
  sweetSpot: [number, number];
  sweetBonus: number;
  breakGraceMs: number;
  warnAt: number;
  zoneLift: number;
  zoneGravity: number;
  timeLimitMs: number;
  introMs: number;
  resultMs: number;
}

export type Outcome = 'caught' | 'snapped' | 'escaped' | 'cancelled';

export interface GameState {
  elapsedMs: number; // since the start, intro included
  playing: boolean; // past the intro
  fish: number;
  fishTarget: number;
  fishDart: boolean;
  nextTurnMs: number;
  zone: number;
  zoneVel: number;
  tension: number;
  overMs: number; // time spent at full tension
  progress: number;
  surgeUntilMs: number;
  inZone: boolean;
  sweet: boolean;
  slack: boolean; // tension too low to reel anything in
  surge: boolean;
  warn: boolean;
  outcome: Outcome | null;
}

export type GameEvent = 'surge' | 'dart' | 'warn' | 'enter' | 'leave' | 'snap' | 'escape' | 'catch';

export type Rng = () => number;

/** Below this tension the line is slack and the fish gains ground. */
export const SLACK_AT = 0.05;

const clamp = (v: number, lo: number, hi: number) => (v < lo ? lo : v > hi ? hi : v);
const between = (rng: Rng, a: number, b: number) => a + rng() * (b - a);

export function createGame(p: Profile, rng: Rng = Math.random): GameState {
  const fish = between(rng, 0.35, 0.65);
  return {
    elapsedMs: 0,
    playing: false,
    fish,
    fishTarget: fish,
    fishDart: false,
    nextTurnMs: 0,
    zone: 0.5,
    zoneVel: 0,
    tension: 0.15,
    overMs: 0,
    progress: clamp(p.startProgress, 0.05, 0.95),
    surgeUntilMs: 0,
    inZone: Math.abs(fish - 0.5) <= p.zoneSize / 2,
    sweet: false,
    slack: false,
    surge: false,
    warn: false,
    outcome: null,
  };
}

/** Advance the game by dt seconds. `reel`: the reel button is held. Returns what happened this step. */
export function step(s: GameState, p: Profile, dt: number, reel: boolean, rng: Rng = Math.random): GameEvent[] {
  const events: GameEvent[] = [];
  if (s.outcome) return events;
  dt = clamp(dt, 0, 0.1); // a long frame (alt-tab) never jumps the fish across the track
  s.elapsedMs += dt * 1000;

  if (!s.playing) {
    // The intro: the fish wobbles in place while "Fish on!" shows
    s.fish = clamp(s.fish + Math.sin(s.elapsedMs / 90) * 0.002, 0.05, 0.95);
    if (s.elapsedMs >= p.introMs) {
      s.playing = true;
      s.nextTurnMs = s.elapsedMs;
    }
    return events;
  }

  const half = p.zoneSize / 2;

  // --- The fish ------------------------------------------------------------------------------------------
  const surging = s.elapsedMs < s.surgeUntilMs;
  if (!surging && rng() < p.surgeChance * dt) {
    s.surgeUntilMs = s.elapsedMs + between(rng, p.surgeMs[0], p.surgeMs[1]);
    s.fishTarget = clamp(s.fish - between(rng, 0.2, 0.45), 0.04, 0.96);
    s.fishDart = false;
    events.push('surge');
  }
  s.surge = s.elapsedMs < s.surgeUntilMs;

  if (!s.surge && s.elapsedMs >= s.nextTurnMs) {
    // A new heading: sometimes a dart across the track
    const dart = rng() < p.dartChance;
    s.fishDart = dart;
    if (dart) {
      s.fishTarget = s.fish > 0.5 ? between(rng, 0.04, 0.3) : between(rng, 0.7, 0.96);
      events.push('dart');
    } else {
      s.fishTarget = clamp(s.fish + between(rng, -0.35, 0.35), 0.04, 0.96);
    }
    s.nextTurnMs = s.elapsedMs + (1000 / Math.max(0.2, p.fishAgility)) * between(rng, 0.5, 1.5);
  }
  const speed = p.fishSpeed * (s.fishDart ? 2.6 : 1) * (s.surge ? 1.5 : 1);
  const diff = s.fishTarget - s.fish;
  const move = Math.min(Math.abs(diff), speed * dt * (0.55 + 0.45 * Math.min(1, Math.abs(diff) * 6)));
  s.fish = clamp(s.fish + Math.sign(diff) * move, 0.02, 0.98);
  if (Math.abs(diff) < 0.01) s.fishDart = false;

  // --- The zone (the player) -----------------------------------------------------------------------------
  s.zoneVel += (reel ? p.zoneLift : -p.zoneGravity) * dt;
  s.zoneVel = clamp(s.zoneVel, -1.1, 1.1);
  s.zone += s.zoneVel * dt * 0.62;
  if (s.zone < half) {
    s.zone = half;
    s.zoneVel = Math.abs(s.zoneVel) * 0.25;
  } else if (s.zone > 1 - half) {
    s.zone = 1 - half;
    s.zoneVel = -Math.abs(s.zoneVel) * 0.25;
  }

  const wasIn = s.inZone;
  s.inZone = Math.abs(s.fish - s.zone) <= half;
  if (s.inZone && !wasIn) events.push('enter');
  if (!s.inZone && wasIn) events.push('leave');

  // --- Tension -------------------------------------------------------------------------------------------
  if (reel) {
    s.tension += p.tensionGain * dt * (s.surge ? p.surgeTension : 1) * (s.inZone ? 1 : 1.15);
  } else {
    // Eases off fast from the red, slowly near slack: a light touch keeps the line taut
    s.tension -= p.tensionRelax * dt * (s.surge ? 0.6 : 1) * (0.3 + s.tension);
  }
  s.tension = clamp(s.tension, 0, 1);
  const wasWarn = s.warn;
  s.warn = s.tension >= p.warnAt;
  if (s.warn && !wasWarn) events.push('warn');
  if (s.tension >= 1) {
    s.overMs += dt * 1000;
    if (s.overMs >= p.breakGraceMs) {
      s.outcome = 'snapped';
      events.push('snap');
      return events;
    }
  } else {
    s.overMs = 0;
  }

  // --- Progress ------------------------------------------------------------------------------------------
  // A slack line reels nothing in: the fish has to be fought, not waited out at the bottom of the track
  s.slack = s.tension < SLACK_AT;
  s.sweet = s.inZone && s.tension >= p.sweetSpot[0] && s.tension <= p.sweetSpot[1];
  if (s.inZone && !s.slack) {
    s.progress += p.progressGain * dt * (s.sweet ? 1 + p.sweetBonus : 1);
  } else if (s.inZone) {
    s.progress -= p.progressLoss * 0.35 * dt;
  } else {
    s.progress -= p.progressLoss * dt;
  }
  s.progress = clamp(s.progress, 0, 1);

  if (s.progress >= 1) {
    s.outcome = 'caught';
    events.push('catch');
  } else if (s.progress <= 0 || s.elapsedMs - p.introMs >= p.timeLimitMs) {
    s.outcome = 'escaped';
    events.push('escape');
  }
  return events;
}
