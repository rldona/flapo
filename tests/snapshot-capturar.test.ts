import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import * as C from '../src/config/GameConfig';
import { GameState } from '../src/core/types';
import { Bird, type BirdCallbacks } from '../src/systems/Bird';
import { Pipe } from '../src/systems/Pipe';
import { PipeSpawner } from '../src/systems/PipeSpawner';

const { makeCanvasMock, contexto } = vi.hoisted(() => {
  const llamadas: unknown[][] = [];
  const contexto = {
    imageSmoothingEnabled: false,
    fillStyle: '',
    globalAlpha: 1,
    llamadas,
    fillRect: (...a: unknown[]) => llamadas.push(['fillRect', ...a]),
    save: () => llamadas.push(['save']),
    restore: () => llamadas.push(['restore']),
    scale: (...a: unknown[]) => llamadas.push(['scale', ...a]),
    drawImage: (...a: unknown[]) => llamadas.push(['drawImage', contexto.globalAlpha, ...a]),
  };
  const makeCanvasMock = vi.fn((w: number, h: number) => ({
    width: w,
    height: h,
    getContext: (tipo?: string) => {
      llamadas.push(['getContext', tipo]);
      return contexto;
    },
    toDataURL: (tipo: string) => `data:${tipo};base64,AAAA`,
  }));
  return { makeCanvasMock, contexto };
});

vi.mock('../src/render/Assets', () => ({ makeCanvas: makeCanvasMock }));

// Importado después del mock para que `Snapshot` reciba el `makeCanvas` falso.
import { Snapshot } from '../src/systems/Snapshot';

function cb(): BirdCallbacks {
  return {
    onFlapped: () => {},
    onDied: () => {},
    onSoftHit: () => {},
    onBreathRecovered: () => {},
    onGlided: () => {},
    onBreathChanged: () => {},
    onFatigueChanged: () => {},
  };
}

class ImageFalsa {
  static instancias: ImageFalsa[] = [];
  complete = true;
  naturalWidth = 24;
  src = '';
  constructor() {
    ImageFalsa.instancias.push(this);
  }
}

const CADA = Math.max(Math.floor((C.SNAPSHOT_SECONDS * 60) / C.SNAPSHOT_SAMPLES), 1);

function conMuestras(): Snapshot {
  const bird = new Bird(cb());
  const pipes = new PipeSpawner({ onPipeSpawned: () => {} });
  const snap = new Snapshot(bird, pipes);
  snap.sky = '#123456';
  snap.onStateChanged(GameState.PLAYING);
  const pipe = new Pipe();
  pipe.x = 100;
  pipe.gapCenter = 200;
  pipe.gap = 100;
  pipe.width = 26;
  pipes.pipes.push(pipe);
  for (let i = 0; i < CADA * 3; i++) {
    bird.y = 150 + i;
    snap.update();
  }
  return snap;
}

beforeEach(() => {
  contexto.llamadas.length = 0;
  contexto.imageSmoothingEnabled = false;
  ImageFalsa.instancias.length = 0;
  makeCanvasMock.mockClear();
  vi.stubGlobal('Image', ImageFalsa);
  // `capturar()` exige que exista `document`; el canvas está mockeado.
  vi.stubGlobal('document', {});
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('Snapshot · capturar', () => {
  it('compone el lienzo al doble de escala y devuelve un PNG', () => {
    const url = conMuestras().capturar();
    expect(url).toBe('data:image/png;base64,AAAA');
    expect(makeCanvasMock).toHaveBeenCalledWith(
      C.VIEWPORT_WIDTH * C.SNAPSHOT_SCALE,
      C.VIEWPORT_HEIGHT * C.SNAPSHOT_SCALE,
    );

    const fill = contexto.llamadas.find(([op]) => op === 'fillRect');
    expect(fill).toEqual([
      'fillRect',
      0,
      0,
      C.VIEWPORT_WIDTH * C.SNAPSHOT_SCALE,
      C.VIEWPORT_HEIGHT * C.SNAPSHOT_SCALE,
    ]);
    expect(contexto.llamadas).toContainEqual(['getContext', '2d']);
    expect(contexto.imageSmoothingEnabled).toBe(false);
    expect(contexto.llamadas.some(([op]) => op === 'scale')).toBe(true);
    expect(contexto.llamadas.some(([op]) => op === 'save')).toBe(true);
    expect(contexto.llamadas.some(([op]) => op === 'restore')).toBe(true);
    // El sprite del pájaro se carga con su ruta real.
    expect(ImageFalsa.instancias.at(-1)?.src ?? '').toContain('sprites/flapo_0.png');
  });

  it('dibuja las tuberías con su geometría', () => {
    conMuestras().capturar();
    const rects = contexto.llamadas.filter(([op]) => op === 'fillRect').slice(1);
    // Dos rects por tubería (arriba y abajo), con x = 100 - 26/2.
    expect(rects.length).toBeGreaterThanOrEqual(2);
    expect(rects[0]).toEqual(['fillRect', 100 - 26 / 2, 0, 26, 200 - 100 / 2]);
    expect(rects[1]).toEqual(['fillRect', 100 - 26 / 2, 200 + 100 / 2, 26, 512 - (200 + 100 / 2)]);
  });

  it('dibuja cada muestra del pájaro con su alfa', () => {
    conMuestras().capturar();
    const dibujos = contexto.llamadas.filter(([op]) => op === 'drawImage');
    expect(dibujos.length).toBe(3);
    // El primero es el más desvaído y el último el más opaco.
    expect(dibujos[0][1]).toBeCloseTo(C.SNAPSHOT_FADE_MIN, 6);
    expect(dibujos[dibujos.length - 1][1]).toBeCloseTo(1, 6);
    for (const d of dibujos) {
      expect(d[3]).toBe(72 - 12); // x = round(bird.x) - 12
      expect(d[5]).toBe(24);
      expect(d[6]).toBe(24);
    }
    // Primera muestra: bird.y = 150 + 19 = 169 (muestreo en el frame 20).
    expect(dibujos[0][4]).toBe(169 - 12);
  });

  it('devuelve null sin muestras', () => {
    const bird = new Bird(cb());
    const snap = new Snapshot(bird, new PipeSpawner({ onPipeSpawned: () => {} }));
    expect(snap.capturar()).toBeNull();
  });

  it('devuelve null si no hay contexto 2D', () => {
    const snap = conMuestras();
    makeCanvasMock.mockReturnValueOnce({
      width: 1,
      height: 1,
      getContext: () => null,
      toDataURL: () => 'data:,',
    } as unknown as ReturnType<typeof makeCanvasMock>);
    expect(snap.capturar()).toBeNull();
  });

  it('omite el pájaro si la imagen no está lista', () => {
    class ImagenIncompleta {
      complete = false;
      naturalWidth = 24; // con `||` se colaría
      src = '';
    }
    vi.stubGlobal('Image', ImagenIncompleta);
    conMuestras().capturar();
    expect(contexto.llamadas.filter(([op]) => op === 'drawImage')).toHaveLength(0);

    class ImagenSinAncho {
      complete = true;
      naturalWidth = 0; // con `>0 → true/>=` se colaría
      src = '';
    }
    vi.stubGlobal('Image', ImagenSinAncho);
    contexto.llamadas.length = 0;
    conMuestras().capturar();
    expect(contexto.llamadas.filter(([op]) => op === 'drawImage')).toHaveLength(0);
  });
});
