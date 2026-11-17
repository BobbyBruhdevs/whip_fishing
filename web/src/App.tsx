import { useCallback, useEffect, useRef, useState } from 'react';
import { StatusPanel } from './components/StatusPanel';
import { BiteAlert } from './components/BiteAlert';
import { ResultCard } from './components/ResultCard';
import { nuiCallback, inGame } from './lib/nui';
import { setVolume, sfx } from './lib/sound';
import type { HudState, ResultData, UiConfig } from './lib/types';
import { demo } from './demo';

const DEFAULT_CONFIG: UiConfig = { scale: 1, volume: 0.6, resultMs: 9000 };

export function App() {
  const [config, setConfig] = useState<UiConfig>(DEFAULT_CONFIG);
  const [hud, setHud] = useState<HudState>({ visible: false });
  const [bite, setBite] = useState({ id: 0, windowMs: 1600 });
  const [nibble, setNibble] = useState(0);
  const [result, setResult] = useState<ResultData | null>(null);
  const [leaving, setLeaving] = useState(false);
  const resultTimer = useRef<number[]>([]);

  const showResult = useCallback((r: ResultData, ms: number) => {
    resultTimer.current.forEach((t) => window.clearTimeout(t));
    setLeaving(false);
    setResult(r);
    resultTimer.current = [
      window.setTimeout(() => setLeaving(true), Math.max(500, ms - 400)),
      window.setTimeout(() => setResult(null), ms),
    ];
  }, []);

  useEffect(() => {
    const onMessage = (ev: MessageEvent) => {
      const msg = ev.data;
      if (!msg || typeof msg !== 'object' || typeof msg.action !== 'string') return;
      const data = msg.data;
      switch (msg.action) {
        case 'config':
          setConfig({ ...DEFAULT_CONFIG, ...data });
          setVolume(data?.volume ?? 0.6);
          break;
        case 'theme': {
          // The server's WHIP skin: its theme.css overrides the same tokens this page reads
          const res = typeof data?.resource === 'string' && /^[\w-]+$/.test(data.resource) ? data.resource : null;
          document.getElementById('whip-theme')?.remove();
          if (res) {
            const link = document.createElement('link');
            link.id = 'whip-theme';
            link.rel = 'stylesheet';
            link.href = `https://cfx-nui-${res}/theme.css`;
            document.head.appendChild(link);
          }
          break;
        }
        case 'hud':
          setHud((prev) => (data?.visible === false ? { ...prev, visible: false } : { ...prev, ...data, visible: true }));
          break;
        case 'cast':
          sfx.cast();
          break;
        case 'nibble':
          setNibble((n) => n + 1);
          sfx.nibble();
          break;
        case 'bite':
          setBite((b) => ({ id: b.id + 1, windowMs: data?.windowMs ?? 1600 }));
          sfx.bite();
          break;
        case 'biteMissed':
          setBite((b) => ({ id: b.id + 1, windowMs: 0 }));
          sfx.missed();
          break;
        case 'result':
          showResult(data as ResultData, (data as ResultData).success ? config.resultMs : Math.min(config.resultMs, 3500));
          if ((data as ResultData).success) sfx.catch();
          else sfx.lost();
          break;
      }
    };
    window.addEventListener('message', onMessage);
    void nuiCallback('ready');
    if (!inGame) demo();
    return () => window.removeEventListener('message', onMessage);
  }, [config.resultMs, showResult]);

  const scale = config.scale || 1;
  return (
    <div className="root" style={{ ['--ui-scale' as string]: String(scale) }}>
      <StatusPanel hud={hud} />
      {nibble > 0 && hud.visible && hud.phase === 'waiting' && <div className="nibble" key={nibble}>Something's nibbling…</div>}
      <BiteAlert id={bite.windowMs > 0 ? bite.id : 0} windowMs={bite.windowMs} hint="Strike now" />
      {result && <ResultCard result={result} leaving={leaving} />}
    </div>
  );
}
