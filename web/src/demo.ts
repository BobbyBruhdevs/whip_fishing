// Browser preview only (npm run dev): plays the screens with sample data, since there is no game to talk to.
function post(action: string, data?: unknown) {
  window.postMessage({ action, data }, '*');
}

export function demo() {
  post('config', { scale: 1, volume: 0.4, resultMs: 9000 });
  post('hud', { visible: true, status: 'Waiting for a bite...', phase: 'waiting', rod: 'Professional Fishing Rod', bait: 'Minnow Bait', baitLeft: 12, durability: 118, maxDurability: 160 });
  setTimeout(() => post('nibble'), 1200);
  setTimeout(() => { post('bite', { windowMs: 1600 }); post('hud', { status: 'Fish on the line! Strike!', phase: 'bite' }); }, 2600);
  setTimeout(() => {
    post('hud', { status: 'Fish on!', phase: 'fighting', size: 'Large' });
  }, 4000);
  setTimeout(() => post('result', {
    success: true,
    fish: {
      key: 'golden_trout', label: 'Golden Trout', rarity: 'legendary', rarityLabel: 'Legendary', color: '#ffb547', weight: 2.35, size: 'Large',
      desc: 'Painted in sunset colours.', real: 'California golden trout', scientific: 'Oncorhynchus aguabonita',
      photo: 'img/photos/whip_fishing_golden_trout.webp', image: 'img/items/whip_fishing_golden_trout.webp',
    },
  }), 8000);
}
