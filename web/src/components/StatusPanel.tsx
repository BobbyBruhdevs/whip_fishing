import type { HudState } from '../lib/types';

/** A small pill at the bottom middle: what is happening, how big the fish is, and the rod and bait in hand. */
export function StatusPanel({ hud }: { hud: HudState }) {
  const dur = hud.durability ?? 0;
  const max = hud.maxDurability ?? 0;
  const pct = max > 0 ? dur / max : 1;
  const wear = pct > 0.5 ? 'ok' : pct > 0.2 ? 'low' : 'crit';
  const alert = hud.phase === 'bite' || hud.phase === 'striking';
  return (
    <div className={`status glass ${hud.visible ? 'shown' : ''}`}>
      <div className={`status-line ${alert ? 'tone-alert' : ''}`}>
        <span className="pulse-dot" />
        <span>{hud.status}</span>
      </div>
      {hud.size && <span className="status-size">{hud.size}</span>}
      <span className="status-sep" />
      {hud.rod && (
        <span className={`status-chip ${wear}`}>
          {hud.rod}
          {max > 0 && <em> {dur}/{max}</em>}
        </span>
      )}
      {hud.bait && (
        <span className="status-chip">
          {hud.bait}
          {typeof hud.baitLeft === 'number' && <em> ×{hud.baitLeft}</em>}
        </span>
      )}
    </div>
  );
}
