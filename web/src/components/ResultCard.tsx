import { useState } from 'react';
import type { ResultData } from '../lib/types';
import { FishIcon } from './FishIcon';

export function ResultCard({ result, leaving }: { result: ResultData; leaving: boolean }) {
  const [imgOk, setImgOk] = useState(true);
  const [photoOk, setPhotoOk] = useState(true);
  const f = result.fish;
  if (result.success && f) {
    return (
      <div className={`result glass win ${leaving ? 'leaving' : ''}`} style={{ ['--rarity' as string]: f.color }}>
        <div className="result-glow" />
        <div className="result-kicker">Caught!</div>
        <div className="result-pic">
          {imgOk ? <img src={f.image} alt="" onError={() => setImgOk(false)} /> : <FishIcon color={f.color} size={120} />}
        </div>
        <div className="result-name">{f.label}</div>
        <div className="result-chips">
          <span className="chip rarity">{f.rarityLabel}</span>
          <span className="chip">{f.weight.toFixed(2)} kg</span>
          <span className="chip">{f.size}</span>
        </div>
        {f.desc && <div className="result-desc">{f.desc}</div>}
        {f.real && (
          <div className="result-real">
            {f.photo && photoOk && <img src={f.photo} alt={f.real} onError={() => setPhotoOk(false)} />}
            <div><b>In real life</b><br />{f.real}{f.scientific && <i> · {f.scientific}</i>}</div>
          </div>
        )}
        {result.ground && <div className="result-note">Your pockets are full: it's at your feet.</div>}
        {result.rodBroken && <div className="result-note warn">Your rod broke. Repair it before your next cast.</div>}
      </div>
    );
  }
  const title = result.reason === 'cancelled' ? 'Released' : result.snapped ? 'Line snapped!' : 'It got away';
  return (
    <div className={`result glass lose ${leaving ? 'leaving' : ''}`} style={{ ['--rarity' as string]: '#7fd8ff' }}>
      <div className="result-kicker">{title}</div>
      <div className="result-pic dim">
        <FishIcon color="#7fd8ff" size={96} />
      </div>
      <div className="result-name small">{result.size ? `A ${result.size.toLowerCase()} fish` : 'A fish'}</div>
      <div className="result-desc">{result.snapped ? 'Too much tension. Ease off when the meter turns red.' : 'Hit every part of the ring to land it.'}</div>
    </div>
  );
}
