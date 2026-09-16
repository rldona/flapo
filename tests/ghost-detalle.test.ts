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

/** Guarda un vuelo de 3 frames con la semilla dada. */
function grabar(semilla: number): void {
  const bird = new Bird(cb());
  const emisor = new Ghost(bird);
  emisor.preparar(semilla);
  emisor.onStateChanged(GameState.PLAYING);
  for (let i = 0; i < 3; i++) {
    bird.y = 100 + i * 10;
    emisor.update(1 / 60);
  }
  emisor.terminar(9, true);
}

beforeEach(() => {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
  Settings.clear();
  GhostRecord.borrar();
});

describe('Ghost · estado inicial y animación', () => {
  it('no es visible ni graba hasta empezar a jugar', () => {
    const g = new Ghost(new Bird(cb()));
    expect(g.visible).toBe(false);
    expect(g.estaReproduciendo()).toBe(false);
    g.update(1);
    g.terminar(3, true);
    expect(GhostRecord.cargar()).toBeNull();
  });

  it('la animación cicla 0..2 a 10 fps', () => {
    const g = new Ghost(new Bird(cb()));
    g.preparar(1);
    g.onStateChanged(GameState.PLAYING);
    g.update(1);
    expect(g.animationFrame()).toBe(1);
  });
});

describe('Ghost · reset y estados que no graban', () => {
  it('READY vacía lo grabado', () => {
    const g = new Ghost(new Bird(cb()));
    g.preparar(1);
    g.onStateChanged(GameState.PLAYING);
    g.update(1 / 60);
    g.onStateChanged(GameState.READY);
    g.terminar(3, true);
    expect(GhostRecord.cargar()).toBeNull();
  });

  it('GAME_OVER no arranca la grabación', () => {
    const g = new Ghost(new Bird(cb()));
    g.preparar(1);
    g.onStateChanged(GameState.GAME_OVER);
    g.update(1 / 60);
    g.terminar(3, true);
    expect(GhostRecord.cargar()).toBeNull();
  });
});

describe('Ghost · transición a GAME_OVER y tope de frames', () => {
  it('pasar a GAME_OVER corta la grabación', () => {
    const g = new Ghost(new Bird(cb()));
    g.preparar(1);
    g.onStateChanged(GameState.PLAYING);
    g.onStateChanged(GameState.GAME_OVER);
    g.update(1 / 60);
    g.terminar(3, true);
    expect(GhostRecord.cargar()).toBeNull();
  });

  it('no graba más allá del máximo de frames', () => {
    const g = new Ghost(new Bird(cb()));
    g.preparar(1);
    g.onStateChanged(GameState.PLAYING);
    const internos = g as unknown as { grabando: number[] };
    internos.grabando = new Array(36000).fill(5); // GHOST_MAX_FRAMES
    g.update(1 / 60);
    expect(internos.grabando.length).toBe(36000);
  });

  it('MENU también resetea y deja de reproducir', () => {
    grabar(1);
    const g = new Ghost(new Bird(cb()));
    g.preparar(1);
    g.onStateChanged(GameState.PLAYING);
    expect(g.visible).toBe(true);
    g.onStateChanged(GameState.MENU);
    expect(g.visible).toBe(false);
    expect(g.estaReproduciendo()).toBe(false);
    g.update(1 / 60); // con activo=true volvería a grabar
    g.terminar(3, true);
    expect(GhostRecord.cargar()?.posiciones.length).toBe(3); // el registro viejo intacto
  });
});

describe('Ghost · reproducción', () => {
  it('copia la posición inicial al empezar a jugar', () => {
    grabar(1);
    const g = new Ghost(new Bird(cb()));
    g.preparar(1);
    g.onStateChanged(GameState.PLAYING);
    expect(g.visible).toBe(true);
    expect(g.y).toBe(100);
  });

  it('con semilla distinta no usa el registro ajeno', () => {
    grabar(1);
    const g = new Ghost(new Bird(cb()));
    g.preparar(2);
    g.onStateChanged(GameState.PLAYING);
    expect(g.estaReproduciendo()).toBe(false);
    expect(g.y).toBe(0);
    g.update(1 / 60);
    expect(g.y).toBe(0);
  });

  it('un terminar sin frames guardados no deja registro', () => {
    const g = new Ghost(new Bird(cb()));
    g.preparar(5);
    g.onStateChanged(GameState.PLAYING);
    g.terminar(9, true); // sin update, no hay posiciones
    g.onStateChanged(GameState.READY);
    g.preparar(5);
    g.onStateChanged(GameState.PLAYING);
    expect(g.estaReproduciendo()).toBe(false);
  });
});
