import { useEffect, useState } from 'react';

// The bite: a big pulse in the middle of the screen with the strike window draining away.
export function BiteAlert({ id, windowMs, hint }: { id: number; windowMs: number; hint: string }) {
  const [shown, setShown] = useState(false);
  useEffect(() => {
    if (!id || windowMs <= 0) {
      setShown(false);
      return;
    }
    setShown(true);
    const t = window.setTimeout(() => setShown(false), windowMs);
    return () => window.clearTimeout(t);
  }, [id, windowMs]);
  if (!shown) return null;
  return (
    <div className="bite" key={id}>
      <div className="bite-ring" />
      <div className="bite-core">!</div>
      <div className="bite-text">Fish on the line</div>
      <div className="bite-hint">{hint}</div>
      <div className="bite-bar">
        <div className="bite-bar-fill" style={{ animationDuration: `${windowMs}ms` }} />
      </div>
    </div>
  );
}
