import { useEffect, useRef, useState } from 'react';
import { createGame, step, type GameEvent, type Outcome } from '../lib/game';
import type { FightStart } from '../lib/types';
import { nuiCallback } from '../lib/nui';
import { sfx } from '../lib/sound';
import { FishIcon } from './FishIcon';

// The reel-in game. Runs on requestAnimationFrame and writes styles straight to the elements, so React renders
// only when the fight starts and ends. Input: Space / W / Up / left mouse to reel, Esc or Backspace to give up;
// on a controller (Whip.padScreen's messages) A or X to reel, B to give up.

// WHIP's own controller glyphs, the same ones its prompts show
const PAD = 'https://cfx-nui-whip_core/html/img/pad';
const REEL_KEYS = new Set(['Space', 'KeyW', 'ArrowUp']);
const CANCEL_KEYS = new Set(['Escape', 'Backspace']);

interface Props {
  fight: FightStart;
  onEnd: () => void;
}

export function Minigame({ fight, onEnd }: Props) {
  const { profile, fish, token } = fight;
  const [pad, setPad] = useState(fight.pad);
  const zoneRef = useRef<HTMLDivElement>(null);
  const fishRef = useRef<HTMLDivElement>(null);
  const tensionRef = useRef<HTMLDivElement>(null);
  const progressRef = useRef<HTMLDivElement>(null);
  const rootRef = useRef<HTMLDivElement>(null);
  const msgRef = useRef<HTMLDivElement>(null);
  const reelInput = useRef({ key: false, mouse: false, pad: false });
  const doneRef = useRef(false);

  useEffect(() => {
    const game = createGame(profile);
    let raf = 0;
    let last = performance.now();
    let lastClick = 0;
    let msgUntil = 0;
    let finishing = false;
    let facing = 1;
    let lastFish = game.fish;

    const say = (text: string, cls: string, ms: number) => {
      const el = msgRef.current;
      if (!el) return;
      el.textContent = text;
      el.className = `fight-msg show ${cls}`;
      msgUntil = performance.now() + ms;
    };

    const rumble = (ms: number, strength: number) => void nuiCallback('rumble', { ms, strength });

    const finish = (reason: Outcome) => {
      if (finishing) return;
      finishing = true;
      const root = rootRef.current;
      if (root) root.classList.add(`end-${reason}`);
      if (reason === 'caught') { say('Landed!', 'good', 5000); }
      else if (reason === 'snapped') { say('Snap!', 'bad', 5000); sfx.snap(); }
      else if (reason === 'escaped') { say('It got away', 'bad', 5000); sfx.lost(); }
      else { say('Released', 'bad', 5000); }
      window.setTimeout(() => {
        if (doneRef.current) return;
        doneRef.current = true;
        void nuiCallback('fightDone', { token, reason });
        onEnd();
      }, reason === 'cancelled' ? 150 : profile.resultMs);
    };

    const onEvents = (events: GameEvent[]) => {
      for (const e of events) {
        if (e === 'surge') { say('Surge! Ease off', 'bad', 900); sfx.surge(); rumble(350, 0.7); }
        else if (e === 'warn') { sfx.warn(); rumble(160, 0.45); }
        else if (e === 'dart') { say('It darts!', 'info', 650); }
        else if (e === 'snap') finish('snapped');
        else if (e === 'escape') finish('escaped');
        else if (e === 'catch') finish('caught');
      }
    };

    say('Fish on!', 'good', profile.introMs);
    sfx.fishOn();

    const frame = (now: number) => {
      const dt = (now - last) / 1000;
      last = now;
      const reel = reelInput.current.key || reelInput.current.mouse || reelInput.current.pad;
      if (!finishing) onEvents(step(game, profile, dt, reel));

      if (reel && !finishing && now - lastClick > 85) { lastClick = now; sfx.click(); }

      const half = profile.zoneSize / 2;
      if (zoneRef.current) {
        zoneRef.current.style.bottom = `${(game.zone - half) * 100}%`;
        zoneRef.current.classList.toggle('hit', game.inZone);
        zoneRef.current.classList.toggle('sweet', game.sweet);
      }
      if (fishRef.current) {
        if (Math.abs(game.fish - lastFish) > 0.0005) facing = game.fish > lastFish ? -1 : 1;
        lastFish = game.fish;
        const wobble = Math.sin(now / (game.surge ? 45 : 120)) * (game.surge ? 9 : 4);
        fishRef.current.style.bottom = `${game.fish * 100}%`;
        fishRef.current.style.transform = `translate(-50%, 50%) rotate(${wobble + facing * -8}deg)`;
        fishRef.current.classList.toggle('surging', game.surge);
      }
      if (tensionRef.current) {
        tensionRef.current.style.transform = `scaleY(${game.tension})`;
      }
      if (progressRef.current) {
        progressRef.current.style.transform = `scaleX(${game.progress})`;
      }
      const root = rootRef.current;
      if (root) {
        root.classList.toggle('warn', game.warn);
        root.classList.toggle('critical', game.overMs > 0);
        root.classList.toggle('slack', game.playing && game.slack && game.inZone);
      }
      if (msgRef.current && msgUntil && now > msgUntil && !finishing) {
        msgRef.current.className = 'fight-msg';
        msgUntil = 0;
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);

    // Input --------------------------------------------------------------------------------------------------
    const giveUp = () => {
      if (finishing) return;
      game.outcome = 'cancelled';
      finish('cancelled');
    };
    const keyDown = (e: KeyboardEvent) => {
      if (REEL_KEYS.has(e.code)) { reelInput.current.key = true; e.preventDefault(); }
      else if (CANCEL_KEYS.has(e.code)) { giveUp(); e.preventDefault(); }
    };
    const keyUp = (e: KeyboardEvent) => {
      if (REEL_KEYS.has(e.code)) reelInput.current.key = false;
    };
    const mouseDown = (e: MouseEvent) => { if (e.button === 0) reelInput.current.mouse = true; };
    const mouseUp = (e: MouseEvent) => { if (e.button === 0) reelInput.current.mouse = false; };
    const blur = () => { reelInput.current = { key: false, mouse: false, pad: false }; };
    const message = (ev: MessageEvent) => {
      const d = ev.data;
      if (!d || typeof d !== 'object') return;
      if (d.action === 'pad') {
        if (d.cmd === 'a' || d.cmd === 'x' || d.cmd === 'up') reelInput.current.pad = d.down !== false;
        else if (d.cmd === 'b' && d.down !== false) giveUp();
      } else if (d.action === 'padDevice') {
        setPad(d.pad === true);
        reelInput.current.pad = false;
      } else if (d.action === 'fight:abort') {
        // whip_core called it off: stop without answering (it already has its answer)
        doneRef.current = true;
        finishing = true;
        onEnd();
      }
    };
    window.addEventListener('keydown', keyDown);
    window.addEventListener('keyup', keyUp);
    window.addEventListener('mousedown', mouseDown);
    window.addEventListener('mouseup', mouseUp);
    window.addEventListener('blur', blur);
    window.addEventListener('message', message);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('keydown', keyDown);
      window.removeEventListener('keyup', keyUp);
      window.removeEventListener('mousedown', mouseDown);
      window.removeEventListener('mouseup', mouseUp);
      window.removeEventListener('blur', blur);
      window.removeEventListener('message', message);
    };
    // One game per fight token
  }, [token]);

  const sweetLo = profile.sweetSpot[0] * 100;
  const sweetHi = profile.sweetSpot[1] * 100;
  return (
    <div className="fight-wrap">
      <div className="fight glass" ref={rootRef} style={{ ['--rarity' as string]: fish.color }}>
        <div className="fight-head">
          <span className="chip rarity">{fish.rarityLabel}</span>
          <span className="fight-size">{fish.size} fish</span>
        </div>

        <div className="fight-body">
          <div className="track">
            <div className="track-water" />
            <div className="track-marks">
              {Array.from({ length: 9 }).map((_, i) => <span key={i} />)}
            </div>
            <div className="zone" ref={zoneRef} style={{ height: `${profile.zoneSize * 100}%` }} />
            <div className="fish" ref={fishRef}>
              <FishIcon color={fish.color} size={46} />
            </div>
          </div>

          <div className="tension">
            <div className="tension-label">Tension</div>
            <div className="tension-bar">
              <div className="tension-sweet" style={{ bottom: `${sweetLo}%`, height: `${sweetHi - sweetLo}%` }} />
              <div className="tension-warn" style={{ bottom: `${profile.warnAt * 100}%` }} />
              <div className="tension-fill" ref={tensionRef} />
            </div>
          </div>
        </div>

        <div className="progress">
          <div className="progress-fill" ref={progressRef} />
        </div>
        <div className="fight-msg" ref={msgRef} />
        <div className="fight-alerts">
          <span className="alert-strain">Line strain!</span>
          <span className="alert-slack">Slack line: keep it taut</span>
        </div>

        <div className="hints">
          {pad ? (
            <>
              <span><img className="pad-img" src={`${PAD}/a.svg`} alt="A" /> Hold to reel</span>
              <span><img className="pad-img" src={`${PAD}/b.svg`} alt="B" /> Give up</span>
            </>
          ) : (
            <>
              <span><b className="key">Space</b> / <b className="key">LMB</b> Hold to reel</span>
              <span><b className="key">Esc</b> Give up</span>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
