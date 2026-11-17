// Every sound is synthesised with WebAudio: no audio files to ship or stream.

let ctx: AudioContext | null = null;
let master: GainNode | null = null;
let volume = 0.6;

function audio(): { ctx: AudioContext; out: GainNode } | null {
  try {
    if (!ctx) {
      ctx = new AudioContext();
      master = ctx.createGain();
      master.gain.value = volume;
      master.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') void ctx.resume();
    return { ctx, out: master! };
  } catch {
    return null;
  }
}

export function setVolume(v: number) {
  volume = Math.max(0, Math.min(1, v));
  if (master) master.gain.value = volume;
}

function tone(freq: number, start: number, dur: number, type: OscillatorType = 'sine', gain = 0.3, slideTo?: number) {
  const a = audio();
  if (!a || volume <= 0) return;
  const t0 = a.ctx.currentTime + start;
  const osc = a.ctx.createOscillator();
  const g = a.ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, t0 + dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(gain, t0 + 0.012);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g).connect(a.out);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

function splash(start = 0, dur = 0.35, gain = 0.25) {
  const a = audio();
  if (!a || volume <= 0) return;
  const t0 = a.ctx.currentTime + start;
  const len = Math.floor(a.ctx.sampleRate * dur);
  const buf = a.ctx.createBuffer(1, len, a.ctx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.2);
  const src = a.ctx.createBufferSource();
  src.buffer = buf;
  const filter = a.ctx.createBiquadFilter();
  filter.type = 'bandpass';
  filter.frequency.value = 900;
  filter.Q.value = 0.7;
  const g = a.ctx.createGain();
  g.gain.value = gain;
  src.connect(filter).connect(g).connect(a.out);
  src.start(t0);
}

export const sfx = {
  cast() { splash(0.05, 0.4, 0.18); },
  nibble() { tone(520, 0, 0.08, 'triangle', 0.12); },
  bite() {
    splash(0, 0.3, 0.3);
    tone(880, 0, 0.12, 'triangle', 0.35);
    tone(1320, 0.11, 0.18, 'triangle', 0.35);
  },
  missed() { tone(440, 0, 0.25, 'sine', 0.18, 300); },
  catch() {
    [523, 659, 784, 1047].forEach((f, i) => tone(f, i * 0.09, 0.28, 'triangle', 0.28));
    splash(0, 0.45, 0.2);
  },
  lost() { tone(392, 0, 0.22, 'triangle', 0.22, 330); tone(262, 0.18, 0.4, 'triangle', 0.22, 196); },
};
