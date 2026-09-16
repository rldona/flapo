import { afterEach, describe, expect, it, vi } from 'vitest';
import { Rng } from '../src/core/Rng';

/**
 * `randomize()` tiene dos caminos (crypto y Math.random) que normalmente no se
 * distinguen porque ambos son aleatorios. Aquí se controlan los globales para
 * forzar cada rama y comprobar el estado resultante.
 */

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('Rng · randomize', () => {
  it('usa crypto.getRandomValues cuando está disponible', () => {
    const stub = vi.fn((buf: Uint32Array) => {
      buf[0] = 0x11111111;
      return buf;
    });
    vi.stubGlobal('crypto', { getRandomValues: stub });
    const r = new Rng(1);
    r.randomize();
    expect(stub).toHaveBeenCalledTimes(1);
    expect(r.seed).toBe(0x11111111);
  });

  it('si crypto no existe, cae a Math.random', () => {
    vi.stubGlobal('crypto', undefined);
    const spy = vi.spyOn(Math, 'random').mockReturnValue(0.5);
    const r = new Rng(1);
    r.randomize();
    expect(spy).toHaveBeenCalled();
    expect(r.seed).toBe((0.5 * 0xffffffff) >>> 0);
  });

  it('si crypto existe pero no tiene getRandomValues, cae a Math.random', () => {
    vi.stubGlobal('crypto', {});
    const spy = vi.spyOn(Math, 'random').mockReturnValue(0.5);
    const r = new Rng(1);
    r.randomize();
    expect(spy).toHaveBeenCalled();
    expect(r.seed).toBe((0.5 * 0xffffffff) >>> 0);
  });
});
