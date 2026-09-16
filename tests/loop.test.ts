import { afterEach, describe, expect, it, vi } from 'vitest';
import { Loop } from '../src/core/Loop';

/**
 * Bucle de paso fijo: acumulador de 60 Hz, recorte de frames largos, tope de
 * pasos por frame, pausa e interpolación para el render.
 */

function rafFalso(): { disparar: (ms: number) => void; veces: () => number } {
  let ultimo: FrameRequestCallback | null = null;
  let veces = 0;
  vi.stubGlobal('requestAnimationFrame', (f: FrameRequestCallback) => {
    ultimo = f;
    veces++;
    return veces;
  });
  vi.stubGlobal('cancelAnimationFrame', () => {});
  return {
    disparar: (ms: number) => ultimo?.(ms),
    veces: () => veces,
  };
}

function crear(): { loop: Loop; updates: number[]; renders: number[]; frames: number[] } {
  const updates: number[] = [];
  const renders: number[] = [];
  const frames: number[] = [];
  const loop = new Loop(
    (dt) => updates.push(dt),
    (alpha) => renders.push(alpha),
    (realDt) => frames.push(realDt),
  );
  return { loop, updates, renders, frames };
}

const PASO_MS = 1000 / 60;

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('Loop · paso fijo', () => {
  it('un frame de 1/60 da exactamente un paso', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop, updates, frames } = crear();
    loop.start();
    raf.disparar(PASO_MS);
    expect(updates).toEqual([loop.step]);
    expect(updates[0]).toBeCloseTo(1 / 60, 12);
    expect(frames[0]).toBeCloseTo(1 / 60, 12);
  });

  it('acumula para dar varios pasos en un frame', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop, updates } = crear();
    loop.start();
    raf.disparar(3 * PASO_MS);
    expect(updates).toHaveLength(3);
    expect(updates.every((dt) => Math.abs(dt - 1 / 60) < 1e-12)).toBe(true);
  });

  it('el render recibe la interpolación que sobra', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop, updates, renders } = crear();
    loop.start();
    raf.disparar(1.5 * PASO_MS);
    expect(updates).toHaveLength(1);
    expect(renders.at(-1)).toBeCloseTo(0.5, 6);
  });

  it('recorta frames largos y limita a 5 pasos, reseteando el acumulador', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop, updates, frames } = crear();
    loop.start();
    raf.disparar(1000); // 1 s
    expect(frames.at(-1)).toBeCloseTo(0.25, 12);
    expect(updates).toHaveLength(5);

    raf.disparar(1000 + 20);
    expect(updates).toHaveLength(6);
  });
});

describe('Loop · pausa y timeScale', () => {
  it('en pausa no simula y renderiza con alpha 0', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop, updates, renders } = crear();
    loop.start();
    loop.paused = true;
    raf.disparar(PASO_MS);
    expect(updates).toHaveLength(0);
    expect(renders.at(-1)).toBe(0);

    loop.paused = false;
    raf.disparar(2 * PASO_MS);
    expect(updates).toHaveLength(1);
  });

  it('timeScale 0 (hit-stop) congela la simulación', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop, updates } = crear();
    loop.start();
    loop.timeScale = 0;
    raf.disparar(PASO_MS);
    expect(updates).toHaveLength(0);

    loop.timeScale = 1;
    raf.disparar(2 * PASO_MS);
    expect(updates).toHaveLength(1);
  });

  it('timeScale 0.5 da la mitad de pasos', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop, updates } = crear();
    loop.start();
    loop.timeScale = 0.5;
    raf.disparar(2 * PASO_MS);
    expect(updates).toHaveLength(1);
  });
});

describe('Loop · start/stop', () => {
  it('start es idempotente', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop } = crear();
    loop.start();
    loop.start();
    expect(raf.veces()).toBe(1);
  });

  it('tras stop, un frame pendiente no hace nada', () => {
    const raf = rafFalso();
    vi.spyOn(performance, 'now').mockReturnValue(0);
    const { loop, updates } = crear();
    loop.start();
    loop.stop();
    raf.disparar(PASO_MS);
    expect(updates).toHaveLength(0);
  });
});
