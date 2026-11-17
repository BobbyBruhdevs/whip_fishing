// A fish silhouette, tinted by rarity. Used on the track and as a fallback for a missing item picture.
export function FishIcon({ color = '#7fd8ff', size = 48, flip = false }: { color?: string; size?: number; flip?: boolean }) {
  return (
    <svg width={size} height={size * 0.6} viewBox="0 0 100 60" style={{ transform: flip ? 'scaleX(-1)' : undefined }} aria-hidden>
      <defs>
        <linearGradient id={`fg-${color.replace('#', '')}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={color} stopOpacity="1" />
          <stop offset="1" stopColor={color} stopOpacity="0.55" />
        </linearGradient>
      </defs>
      <path
        d="M8 30 C 22 8, 58 4, 74 26 L 94 10 L 88 30 L 94 50 L 74 34 C 58 56, 22 52, 8 30 Z"
        fill={`url(#fg-${color.replace('#', '')})`}
        stroke="rgba(255,255,255,0.65)"
        strokeWidth="2"
      />
      <circle cx="24" cy="26" r="3.4" fill="#0b1118" />
      <path d="M40 18 C 46 26, 46 34, 40 42" stroke="rgba(255,255,255,0.35)" strokeWidth="2" fill="none" />
    </svg>
  );
}
