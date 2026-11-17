import { FishIcon } from './FishIcon';
import type { CaughtFish } from '../lib/types';
import { useState } from 'react';

// The mini cutscene when a fish is landed: letterbox bars, the rod bending, the line, a splash and the fish leaping
// out of the water into the middle of the screen. All CSS animation, no timers, so it costs nothing while it plays.

const ROD_COLORS = ['#b08850', '#e8d080', '#5a86c0', '#2a2d33'];
const DROPS = Array.from({ length: 14 }, (_, i) => {
  const a = (i / 14) * Math.PI - Math.PI; // upward fan
  const r = 5 + (i % 4) * 2.2;
  return { dx: Math.cos(a) * r, dy: Math.sin(a) * r * 1.4, d: 0.05 * (i % 5) };
});

export function CatchCutscene({ fish, rodTier, rodLabel, ms }: { fish: CaughtFish; rodTier: number; rodLabel?: string; ms: number }) {
  const [imgOk, setImgOk] = useState(true);
  const tier = Math.min(4, Math.max(1, rodTier || 1));
  const rodColor = ROD_COLORS[tier - 1];
  return (
    <div className="cs" style={{ ['--rarity' as string]: fish.color, ['--cs-ms' as string]: `${ms}ms` }}>
      <div className="cs-dim" />
      <div className="cs-bar top" />
      <div className="cs-bar bottom" />

      <div className="cs-water">
        <span className="cs-ring r1" /><span className="cs-ring r2" /><span className="cs-ring r3" />
      </div>

      <svg className="cs-rod" viewBox="0 0 400 300" aria-label={rodLabel}>
        <g className="cs-rod-bend">
          <line x1="20" y1="290" x2="330" y2="40" stroke={rodColor} strokeWidth={12 - tier} strokeLinecap="round" />
          <line x1="20" y1="290" x2="92" y2="232" stroke="#2a2420" strokeWidth="18" strokeLinecap="round" />
          <circle cx="104" cy="226" r="17" fill="#8e949c" /><circle cx="104" cy="226" r="7" fill="#ffb547" />
          <line x1="330" y1="40" x2="384" y2="240" stroke="rgba(255,255,255,0.8)" strokeWidth="2" className="cs-line" />
        </g>
      </svg>

      <div className="cs-fish">
        {imgOk ? <img src={fish.image} alt="" onError={() => setImgOk(false)} /> : <FishIcon color={fish.color} size={220} />}
      </div>
      <div className="cs-drops">
        {DROPS.map((d, i) => (
          <span key={i} style={{ ['--dx' as string]: `${d.dx}em`, ['--dy' as string]: `${d.dy}em`, animationDelay: `${d.d}s` }} />
        ))}
      </div>

      <div className="cs-title">
        <div className="cs-kicker">Caught!</div>
        <div className="cs-name">{fish.label}</div>
      </div>
    </div>
  );
}
