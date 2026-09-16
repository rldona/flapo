import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { GHOST_MAX_FRAMES } from '../src/config/GameConfig';
import { GhostRecord } from '../src/meta/GhostRecord';

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

class FalloStorage extends MemStorage {
  override setItem(): void {
    throw new Error('disco lleno');
  }
}

function almacen(s: MemStorage): void {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = s;
}

beforeEach(() => almacen(new MemStorage()));
afterEach(() => vi.unstubAllGlobals());

describe('GhostRecord', () => {
  it('guarda y recupera el vuelo', () => {
    const rec = new GhostRecord();
    rec.semilla = 42;
    rec.score = 7;
    rec.posiciones = [10, 20, 30];
    expect(rec.guardar()).toBe(true);

    const leido = GhostRecord.cargar();
    expect(leido).not.toBeNull();
    expect(leido?.semilla).toBe(42);
    expect(leido?.score).toBe(7);
    expect(leido?.posiciones).toEqual([10, 20, 30]);
    expect(leido?.frames()).toBe(3);
  });

  it('cargar sin guardado devuelve null', () => {
    expect(GhostRecord.cargar()).toBeNull();
  });

  it('un JSON corrupto devuelve null', () => {
    almacen(new MemStorage());
    localStorage.setItem('flapo.ghost.v1', '{no-es-json');
    expect(GhostRecord.cargar()).toBeNull();
  });

  it('rechaza registros incompletos, vacíos o demasiado largos', () => {
    localStorage.setItem('flapo.ghost.v1', JSON.stringify({ semilla: 1, score: 2 }));
    expect(GhostRecord.cargar()).toBeNull();

    localStorage.setItem(
      'flapo.ghost.v1',
      JSON.stringify({ semilla: 1, score: 2, posiciones: [] }),
    );
    expect(GhostRecord.cargar()).toBeNull();

    localStorage.setItem(
      'flapo.ghost.v1',
      JSON.stringify({
        semilla: 1,
        score: 2,
        posiciones: new Array(GHOST_MAX_FRAMES + 1).fill(1),
      }),
    );
    expect(GhostRecord.cargar()).toBeNull();
  });

  it('descarta posiciones que no son números', () => {
    localStorage.setItem(
      'flapo.ghost.v1',
      JSON.stringify({ semilla: 1, score: 2, posiciones: [1, 'x', 2, null, 3] }),
    );
    expect(GhostRecord.cargar()?.posiciones).toEqual([1, 2, 3]);
  });

  it('yEn recorta el índice y frames es la longitud', () => {
    const rec = new GhostRecord();
    rec.posiciones = [5, 6, 7];
    expect(rec.frames()).toBe(3);
    expect(rec.yEn(-5)).toBe(5);
    expect(rec.yEn(99)).toBe(7);
    expect(rec.yEn(1)).toBe(6);
    expect(new GhostRecord().yEn(0)).toBe(0);
  });

  it('guardar devuelve false si localStorage lanza y borrar limpia', () => {
    const rec = new GhostRecord();
    rec.posiciones = [1];
    almacen(new FalloStorage());
    expect(rec.guardar()).toBe(false);

    almacen(new MemStorage());
    rec.guardar();
    GhostRecord.borrar();
    expect(GhostRecord.cargar()).toBeNull();
  });
});
