export interface UiConfig {
  scale: number;
  volume: number;
  resultMs: number;
}

export interface HudState {
  visible: boolean;
  status?: string;
  phase?: string;
  rod?: string;
  bait?: string;
  baitLeft?: number;
  durability?: number;
  maxDurability?: number;
  size?: string;
}

export interface CaughtFish {
  key: string;
  label: string;
  rarity: string;
  rarityLabel: string;
  color: string;
  weight: number;
  size: string;
  desc?: string;
  real?: string;
  scientific?: string;
  photo?: string;
  image: string;
}

export interface ResultData {
  success: boolean;
  fish?: CaughtFish;
  snapped?: boolean;
  reason?: string;
  rarityLabel?: string;
  color?: string;
  size?: string;
  ground?: boolean;
  rodLeft?: number;
  rodBroken?: boolean;
}
