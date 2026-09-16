import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AudioDirector } from '../src/audio/AudioDirector';
import { Settings } from '../src/meta/Settings';

/**
 * Audio con un `AudioContext` falso: comprueba el cableado (fuente → gain → bus),
 * el respeto al mute, el ducking, el pitch y la tolerancia a que no haya audio.
 */

class MemStorage {
  private map = new Map<string, string>();
  getItem(k: string): string | null {
    return this.map.has(k) ? (this.map.get(k) as string) : null;
  }
  setItem(k: string, v: string): void {
    this.map.set(k, String(v));
  }
  removeItem(k: string): void {
    this.map.delete(k);
  }
  clear(): void {
    this.map.clear();
  }
}

class FakeGainNode {
  readonly duck: Array<[number, number, number]> = [];
  readonly conectadoA: unknown[] = [];
  desconectado = false;
  gain = {
    value: 1,
    setTargetAtTime: (v: number, t: number, c: number): void => {
      this.duck.push([v, t, c]);
    },
  };
  connect(dest: unknown): void {
    this.conectadoA.push(dest);
  }
  disconnect(): void {
    this.desconectado = true;
  }
}

class FakeSource {
  buffer: unknown = null;
  playbackRate = { value: 1 };
  readonly conectadoA: unknown[] = [];
  started = false;
  onended: (() => void) | null = null;
  connect(dest: unknown): void {
    this.conectadoA.push(dest);
  }
  disconnect(): void {}
  start(): void {
    this.started = true;
  }
  terminar(): void {
    this.onended?.();
  }
}

class FakeAudioContext {
  static instancias: FakeAudioContext[] = [];
  state: AudioContextState = 'running';
  currentTime = 0;
  readonly destination = { nombre: 'destination' };
  readonly ganancias: FakeGainNode[] = [];
  readonly fuentes: FakeSource[] = [];
  reanudado = 0;
  constructor() {
    FakeAudioContext.instancias.push(this);
  }
  createGain(): FakeGainNode {
    const g = new FakeGainNode();
    this.ganancias.push(g);
    return g;
  }
  createBufferSource(): FakeSource {
    const s = new FakeSource();
    this.fuentes.push(s);
    return s;
  }
  decodeAudioData(): Promise<AudioBuffer> {
    return Promise.resolve({ nombre: 'buffer' } as unknown as AudioBuffer);
  }
  resume(): Promise<void> {
    this.reanudado++;
    this.state = 'running';
    return Promise.resolve();
  }
}

class FakeAudioContextFallo extends FakeAudioContext {
  override decodeAudioData(): Promise<AudioBuffer> {
    return Promise.reject(new Error('sin decodificador'));
  }
}

function instalarAudio(Ctor: typeof FakeAudioContext = FakeAudioContext): void {
  vi.stubGlobal('window', globalThis);
  vi.stubGlobal('AudioContext', Ctor);
  vi.stubGlobal('fetch', async () => ({ arrayBuffer: async () => new ArrayBuffer(8) }));
}

function ultimoCtx(): FakeAudioContext {
  return FakeAudioContext.instancias[FakeAudioContext.instancias.length - 1];
}

beforeEach(() => {
  FakeAudioContext.instancias = [];
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
  Settings.clear();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('AudioDirector · carga', () => {
  it('crea el contexto, el bus y decodifica todos los sonidos', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();

    const ctx = ultimoCtx();
    expect(ctx.ganancias).toHaveLength(1); // el bus sfx
    expect(ctx.ganancias[0].conectadoA).toContain(ctx.destination);
    expect(ctx.ganancias[0].gain.value).toBe(1);

    // Con los buffers cargados, cualquier sonido crea una fuente.
    audio.play('point');
    expect(ctx.fuentes).toHaveLength(1);
  });

  it('respeta el mute guardado en los ajustes', async () => {
    Settings.setMuted(true);
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    expect(audio.isMuted()).toBe(true);
    expect(ultimoCtx().ganancias[0].gain.value).toBe(0);
  });

  it('sin AudioContext no revienta y no reproduce', async () => {
    vi.stubGlobal('window', {});
    const audio = new AudioDirector();
    await expect(audio.load()).resolves.toBeUndefined();
    expect(() => audio.play('flap')).not.toThrow();
  });

  it('si falla la decodificación, cae a modo silencioso', async () => {
    instalarAudio(FakeAudioContextFallo);
    const audio = new AudioDirector();
    await expect(audio.load()).resolves.toBeUndefined();
    expect(() => audio.play('flap')).not.toThrow();
  });
});

describe('AudioDirector · reproducción', () => {
  it('cablea fuente -> gain -> bus, aplica volumen y arranca', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    const ctx = ultimoCtx();

    audio.play('flap', 1.5, 0.5);

    const src = ctx.fuentes[0];
    expect(src.started).toBe(true);
    expect(src.playbackRate.value).toBe(1.5);
    const gain = ctx.ganancias[1];
    expect(gain.gain.value).toBeCloseTo(Math.pow(10, -6 / 20) * 0.5, 6);
    expect(src.conectadoA).toContain(gain);
    expect(gain.conectadoA).toContain(ctx.ganancias[0]);
  });

  it('al terminar desconecta la fuente', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    const ctx = ultimoCtx();
    audio.play('point');
    const gain = ctx.ganancias[1];
    ctx.fuentes[0].terminar();
    expect(gain.desconectado).toBe(true);
  });

  it('muteado no reproduce nada', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    const ctx = ultimoCtx();
    audio.applyMuted(true);
    audio.play('flap');
    audio.playHit();
    expect(ctx.fuentes).toHaveLength(0);
  });

  it('playHit lanza golpe y caída', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    const ctx = ultimoCtx();
    audio.playHit();
    expect(ctx.fuentes).toHaveLength(2);
  });

  it('sin cargar, reproducir no hace nada', () => {
    instalarAudio();
    const audio = new AudioDirector();
    expect(() => audio.play('flap')).not.toThrow();
    expect(FakeAudioContext.instancias).toHaveLength(0);
  });
});

describe('AudioDirector · mute y ducking', () => {
  it('toggleMuted persiste y aplica la ganancia', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    const bus = ultimoCtx().ganancias[0];

    expect(audio.toggleMuted()).toBe(true);
    expect(audio.isMuted()).toBe(true);
    expect(Settings.isMuted()).toBe(true);
    expect(bus.gain.value).toBe(0);

    expect(audio.toggleMuted()).toBe(false);
    expect(audio.isMuted()).toBe(false);
    expect(Settings.isMuted()).toBe(false);
    expect(bus.gain.value).toBe(1);
  });

  it('duck silencia el bus y lo restaura', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    const bus = ultimoCtx().ganancias[0];

    audio.duck(true);
    audio.duck(false);
    expect(bus.duck.map(([v]) => v)).toEqual([0, 1]);
  });

  it('duck respeta el mute aunque se desactiva', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    audio.applyMuted(true);
    const bus = ultimoCtx().ganancias[0];
    audio.duck(false);
    expect(bus.duck.at(-1)?.[0]).toBe(0);
  });

  it('resume solo actúa si el contexto está suspendido', async () => {
    instalarAudio();
    const audio = new AudioDirector();
    await audio.load();
    const ctx = ultimoCtx();

    ctx.state = 'running';
    audio.resume();
    expect(ctx.reanudado).toBe(0);

    ctx.state = 'suspended';
    audio.resume();
    expect(ctx.reanudado).toBe(1);
  });
});
