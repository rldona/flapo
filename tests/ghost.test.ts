import { beforeEach, describe, expect, it } from 'vitest';
import { Bird, type BirdCallbacks } from '../src/systems/Bird';
import { Ghost } from '../src/systems/Ghost';
import { GhostRecord } from '../src/meta/GhostRecord';
import { Settings } from '../src/meta/Settings';
import { GameState } from '../src/core/types';

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

/** Graba un vuelo de 5 frames con la semilla dada. */
function grabarVuelo(semilla: number, score = 10): void {
  const emisor = new Ghost(new Bird(cb()));
  emisor.preparar(semilla);
  emisor.onStateChanged(GameState.PLAYING);
  for (let i = 0; i < 5; i++) emisor.update(1 / 60);
  emisor.terminar(score, true);
}

beforeEach(() => {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
  Settings.clear();
  GhostRecord.borrar();
});

describe('Ghost', () => {
  it('graba el vuelo y lo reproduce después', () => {
    const bird = new Bird(cb());
    const emisor = new Ghost(bird);
    emisor.preparar(123);
    emisor.onStateChanged(GameState.PLAYING);
    for (let i = 0; i < 5; i++) {
      bird.y = 100 + i * 10;
      emisor.update(1 / 60);
    }
    emisor.terminar(10, true);

    const receptor = new Ghost(new Bird(cb()));
    receptor.preparar(123);
    receptor.onStateChanged(GameState.PLAYING);
    expect(receptor.visible).toBe(true);
    expect(receptor.estaReproduciendo()).toBe(true);

    const ys: number[] = [];
    for (let i = 0; i < 5; i++) {
      receptor.update(1 / 60);
      ys.push(receptor.y);
    }
    expect(ys).toEqual([100, 110, 120, 130, 140]);

    receptor.update(1 / 60); // se acaban los frames grabados
    expect(receptor.estaReproduciendo()).toBe(false);
    expect(receptor.visible).toBe(false);
  });

  it('no guarda si no hay récord ni posiciones', () => {
    const g = new Ghost(new Bird(cb()));
    g.preparar(1);
    g.onStateChanged(GameState.PLAYING);
    g.update(1 / 60);
    g.terminar(0, false); // no es récord
    expect(GhostRecord.cargar()).toBeNull();

    const vacio = new Ghost(new Bird(cb()));
    vacio.preparar(1);
    vacio.terminar(5, true); // nunca grabó
    expect(GhostRecord.cargar()).toBeNull();
  });

  it('no reproduce si la semilla no coincide', () => {
    grabarVuelo(123);
    const g = new Ghost(new Bird(cb()));
    g.preparar(999);
    g.onStateChanged(GameState.PLAYING);
    expect(g.estaReproduciendo()).toBe(false);
    expect(g.visible).toBe(false);
  });

  it('no reproduce si el fantasma está oculto en ajustes', () => {
    grabarVuelo(123);
    Settings.setGhostHidden(true);
    const g = new Ghost(new Bird(cb()));
    g.preparar(123);
    g.onStateChanged(GameState.PLAYING);
    expect(g.estaReproduciendo()).toBe(false);
  });

  it('READY resetea y deja de ser visible', () => {
    grabarVuelo(123);
    const g = new Ghost(new Bird(cb()));
    g.preparar(123);
    g.onStateChanged(GameState.PLAYING);
    g.onStateChanged(GameState.READY);
    expect(g.visible).toBe(false);
    expect(g.estaReproduciendo()).toBe(false);
  });
});
