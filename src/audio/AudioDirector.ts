import { Assets, type AudioName } from '../render/Assets';
import { Settings } from '../meta/Settings';

const VOLUMES: Record<AudioName, number> = {
  flap: -6,
  point: -3,
  hit: 0,
  fall: -6,
  button: -8,
  fruit_good: -4,
  fruit_bad: -4,
  breath: -4,
};

function dbToLinear(db: number): number {
  return Math.pow(10, db / 20);
}

/**
 * Port de `audio_director.gd` sobre Web Audio.
 *
 * Un `AudioBufferSourceNode` por reproducción: compartir uno cortaría el
 * sonido del punto con el del aleteo, que es justo cuando más se solapan. El
 * `playbackRate` permite el pitch dinámico de la Ola 2.
 */
export class AudioDirector {
  private ctx: AudioContext | null = null;
  private sfx: GainNode | null = null;
  private buffers = new Map<AudioName, AudioBuffer>();
  muted = false;

  async load(): Promise<void> {
    try {
      const Ctor = window.AudioContext ?? (window as any).webkitAudioContext;
      if (!Ctor) return;
      const ctx = new Ctor();
      this.ctx = ctx;
      this.sfx = ctx.createGain();
      this.sfx.gain.value = 1;
      this.sfx.connect(ctx.destination);
      await Promise.all(
        Assets.audioNames().map(async (name) => {
          const res = await fetch(Assets.audioUrl(name));
          const arr = await res.arrayBuffer();
          const buf = await ctx.decodeAudioData(arr.slice(0));
          this.buffers.set(name, buf);
        }),
      );
      this.applyMuted(Settings.isMuted());
    } catch {
      // Sin audio el juego es perfectamente jugable: no se revienta.
      this.ctx = null;
    }
  }

  resume(): void {
    if (this.ctx && this.ctx.state === 'suspended') void this.ctx.resume();
  }

  isMuted(): boolean {
    return this.muted;
  }

  applyMuted(muted: boolean): void {
    this.muted = muted;
    if (this.sfx) this.sfx.gain.value = muted ? 0 : 1;
  }

  toggleMuted(): boolean {
    const nuevo = !Settings.isMuted();
    Settings.setMuted(nuevo);
    this.applyMuted(nuevo);
    return nuevo;
  }

  play(name: AudioName, rate = 1, volumeScale = 1): void {
    if (!this.ctx || !this.sfx || this.muted) return;
    const buf = this.buffers.get(name);
    if (!buf) return;
    const src = this.ctx.createBufferSource();
    src.buffer = buf;
    src.playbackRate.value = rate;
    const g = this.ctx.createGain();
    g.gain.value = dbToLinear(VOLUMES[name]) * volumeScale;
    src.connect(g);
    g.connect(this.sfx);
    src.start();
    src.onended = () => {
      src.disconnect();
      g.disconnect();
    };
  }

  playFlap(rate = 1): void {
    this.play('flap', rate);
  }
  playPoint(): void {
    this.play('point');
  }
  playHit(): void {
    this.play('hit');
    this.play('fall');
  }
  playFruitGood(): void {
    this.play('fruit_good');
  }
  playFruitBad(): void {
    this.play('fruit_bad');
  }
  playBreath(): void {
    this.play('breath');
  }
  playButton(): void {
    this.play('button');
  }

  /** Silencia el bus de golpe (ducking en el hit-stop, T-234). */
  duck(active: boolean): void {
    if (this.sfx && this.ctx) {
      const target = active || this.muted ? 0 : 1;
      this.sfx.gain.setTargetAtTime(target, this.ctx.currentTime, 0.01);
    }
  }
}
