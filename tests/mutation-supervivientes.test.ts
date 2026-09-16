import { beforeEach, describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { Rng } from '../src/core/Rng';
import { GameState } from '../src/core/types';
import { SaveManager } from '../src/meta/SaveManager';
import { FruitSpawner } from '../src/systems/Fruit';
import { Journey } from '../src/systems/Journey';
import { Wind } from '../src/systems/Wind';

/**
 * Tercera pasada de tests de detalle. Cada caso apunta a un mutante concreto
 * que sobrevivía a la suite anterior: ramas defensivas, bordes exactos de
 * comparación y escrituras redundantes.
 */

const KEY = 'flapo.save.v1';

class MemStorage {
  private map = new Map<string, string>();
  setItemCalls = 0;
  getItem(k: string): string | null {
    return this.map.has(k) ? (this.map.get(k) as string) : null;
  }
  setItem(k: string, v: string): void {
    this.setItemCalls++;
    this.map.set(k, String(v));
  }
  removeItem(k: string): void {
    this.map.delete(k);
  }
  clear(): void {
    this.map.clear();
  }
}

beforeEach(() => {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
  SaveManager.forgetCache();
  SaveManager.clear();
});

describe('GameConfig · ramas defensivas', () => {
  it('sanitizePlayerName colapsa exactamente dos espacios', () => {
    expect(C.sanitizePlayerName('a  b')).toBe('a b');
  });

  it('pantLevel con máximo no positivo es NINGUNO', () => {
    expect(C.pantLevel(0, 0)).toBe(C.Pant.NINGUNO);
    expect(C.pantLevel(100, -1)).toBe(C.Pant.NINGUNO);
  });

  it('pantTintWeight con máximo no positivo es 0', () => {
    expect(C.pantTintWeight(50, -1)).toBe(0);
  });
});

describe('SaveManager · datos corruptos y escrituras', () => {
  it('un entero guardado como string no se cuela', () => {
    localStorage.setItem(KEY, JSON.stringify({ high_score: '99999' }));
    SaveManager.forgetCache();
    expect(SaveManager.recordGame(5)).toBe(true);
    expect(SaveManager.getHighScore()).toBe(5);
  });

  it('un total guardado como string no se cuela', () => {
    localStorage.setItem(KEY, JSON.stringify({ total_score: '500' }));
    SaveManager.forgetCache();
    SaveManager.recordGame(3);
    expect(SaveManager.getTotalScore()).toBe(3);
  });

  it('solo cachea claves daily_*', () => {
    localStorage.setItem(KEY, JSON.stringify({ foo: 7, daily_20260101: 5 }));
    SaveManager.forgetCache();
    expect(SaveManager.getDailyBest('foo')).toBe(0);
    expect(SaveManager.getDailyBest('daily_20260101')).toBe(5);
  });

  it('getDifficulty rechaza un valor no numérico', () => {
    SaveManager.setDifficulty('x' as unknown as C.Difficulty);
    expect(SaveManager.getDifficulty()).toBe(C.Difficulty.NORMAL);
  });

  it('getPlayerName tolera un valor no string en la caché', () => {
    SaveManager.setPlayerName(123 as unknown as string);
    expect(SaveManager.getPlayerName()).toBe('');
  });

  it('setHasGlided no reescribe si ya estaba marcado', () => {
    const store = localStorage as unknown as MemStorage;
    SaveManager.setHasGlided();
    const escrituras = store.setItemCalls;
    SaveManager.setHasGlided();
    expect(store.setItemCalls).toBe(escrituras);
  });

  it('setJourneyCompleted no reescribe si ya estaba marcado', () => {
    const store = localStorage as unknown as MemStorage;
    SaveManager.setJourneyCompleted();
    const escrituras = store.setItemCalls;
    SaveManager.setJourneyCompleted();
    expect(store.setItemCalls).toBe(escrituras);
  });
});

function spawnerConRng(seed = 1234): FruitSpawner {
  const spawner = new FruitSpawner();
  spawner.setRng(new Rng(seed));
  return spawner;
}

const MEDIO = (160 / 100) * 0.5;

describe('FruitSpawner · bordes de estado y sorteo', () => {
  it('MENU limpia frutas y cancela el temporizador', () => {
    const spawner = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(MEDIO + 0.01);
    expect(spawner.fruits).toHaveLength(1);
    spawner.onStateChanged(GameState.MENU);
    expect(spawner.fruits).toHaveLength(0);
    spawner.update(5);
    expect(spawner.fruits).toHaveLength(0);
  });

  it('GAME_OVER cancela el temporizador pendiente', () => {
    const spawner = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.onStateChanged(GameState.GAME_OVER);
    spawner.update(MEDIO + 0.01);
    expect(spawner.fruits).toHaveLength(0);
  });

  it('una tirada igual al chance no aborta el nacimiento', () => {
    const spawner = spawnerConRng(7);
    spawner.chance = new Rng(7).randf();
    spawner.onPipeSpawned();
    spawner.update(MEDIO + 0.01);
    expect(spawner.fruits).toHaveLength(1);
  });
});

describe('Wind · borde exacto de dirección', () => {
  it('una tirada de exactamente 0.5 elige cara', () => {
    const wind = new Wind({ onWarning: () => {}, onGust: () => {}, onEnded: () => {} });
    wind.setRng({ randf: () => 0.5 } as unknown as Rng);
    wind.enabled = true;
    wind.update(1);
    expect(wind.isTailwind()).toBe(false);
  });
});

describe('Journey · estados que no cierran la escena', () => {
  it('un cambio a PLAYING no cierra la escena activa', () => {
    const eventos: string[] = [];
    const journey = new Journey({
      onStarted: () => eventos.push('inicio'),
      onEnded: () => eventos.push('fin'),
    });
    journey.quizaEmpezar(C.JOURNEY_END_SCORE);
    journey.onStateChanged(GameState.PLAYING);
    expect(journey.activaAhora()).toBe(true);
    expect(eventos).toEqual(['inicio']);
  });
});
