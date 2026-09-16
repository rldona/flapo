import { beforeEach, describe, expect, it } from 'vitest';
import { Difficulty } from '../src/config/GameConfig';
import { SaveManager } from '../src/meta/SaveManager';

/** Tests de detalle para matar mutantes en la persistencia. */

const KEY = 'flapo.save.v1';

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

function leerGuardado(): Record<string, unknown> | null {
  const raw = localStorage.getItem(KEY);
  return raw ? (JSON.parse(raw) as Record<string, unknown>) : null;
}

beforeEach(() => {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
  SaveManager.forgetCache();
  SaveManager.clear();
});

describe('SaveManager · lectura robusta', () => {
  it('un JSON corrupto cae a los valores por defecto', () => {
    localStorage.setItem(KEY, '{no-es-json');
    SaveManager.forgetCache();
    expect(SaveManager.getHighScore()).toBe(0);
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);
  });

  it('un número no finito cuenta como 0', () => {
    localStorage.setItem(KEY, '{"high_score":1e999}');
    SaveManager.forgetCache();
    expect(SaveManager.getHighScore()).toBe(0);
  });

  it('los negativos se recortan a 0', () => {
    localStorage.setItem(KEY, '{"high_score":-5,"games_played":-2}');
    SaveManager.forgetCache();
    expect(SaveManager.getHighScore()).toBe(0);
    expect(SaveManager.getGamesPlayed()).toBe(0);
  });

  it('getDifficulty rechaza valores fuera de rango', () => {
    localStorage.setItem(KEY, JSON.stringify({ difficulty: 99 }));
    SaveManager.forgetCache();
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);

    localStorage.setItem(KEY, JSON.stringify({ difficulty: -1 }));
    SaveManager.forgetCache();
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);

    localStorage.setItem(KEY, JSON.stringify({ difficulty: Difficulty.DIFICIL }));
    SaveManager.forgetCache();
    expect(SaveManager.getDifficulty()).toBe(Difficulty.DIFICIL);
  });

  it('getPlayerName ignora valores que no son string', () => {
    localStorage.setItem(KEY, JSON.stringify({ player_name: 123 }));
    SaveManager.forgetCache();
    expect(SaveManager.getPlayerName()).toBe('');
  });
});

describe('SaveManager · escritura persistente', () => {
  it('setDifficulty guarda en localStorage', () => {
    SaveManager.setDifficulty(Difficulty.DIFICIL);
    expect(leerGuardado()?.difficulty).toBe(Difficulty.DIFICIL);
  });

  it('setPlayerName guarda en localStorage', () => {
    SaveManager.setPlayerName('Raúl');
    expect(leerGuardado()?.player_name).toBe('Raúl');
    expect(SaveManager.getPlayerName()).toBe('Raúl');
  });

  it('setHasGlided guarda una sola vez', () => {
    SaveManager.setHasGlided();
    expect(leerGuardado()?.has_glided).toBe(1);
    expect(SaveManager.getHasGlided()).toBe(true);
    SaveManager.setHasGlided();
    expect(leerGuardado()?.has_glided).toBe(1);
  });

  it('setJourneyCompleted guarda una sola vez', () => {
    SaveManager.setJourneyCompleted();
    expect(leerGuardado()?.journey_completed).toBe(1);
    expect(SaveManager.getJourneyCompleted()).toBe(true);
    SaveManager.setJourneyCompleted();
    expect(leerGuardado()?.journey_completed).toBe(1);
  });

  it('setMirror guarda el booleano', () => {
    SaveManager.setMirror(true);
    expect(leerGuardado()?.mirror).toBe(1);
    expect(SaveManager.getMirror()).toBe(true);
    SaveManager.setMirror(false);
    expect(SaveManager.getMirror()).toBe(false);
  });
});

describe('SaveManager · partidas', () => {
  it('recordGame guarda en localStorage y actualiza la media', () => {
    expect(SaveManager.recordGame(30)).toBe(true);
    expect(leerGuardado()?.high_score).toBe(30);
    SaveManager.recordGame(20);
    expect(SaveManager.getGamesPlayed()).toBe(2);
    expect(SaveManager.getTotalScore()).toBe(50);
    expect(SaveManager.getAverageScore()).toBe(25);
  });

  it('empatar el récord no cuenta como récord nuevo', () => {
    SaveManager.recordGame(50);
    expect(SaveManager.recordGame(50)).toBe(false);
    expect(SaveManager.getHighScore()).toBe(50);
  });

  it('sin partidas la media es 0', () => {
    expect(SaveManager.getGamesPlayed()).toBe(0);
    expect(SaveManager.getAverageScore()).toBe(0);
  });

  it('cuentaParaElRecord=false nunca mejora la marca', () => {
    SaveManager.recordGame(10, true);
    expect(SaveManager.recordGame(100, false)).toBe(false);
    expect(SaveManager.getHighScore()).toBe(10);
  });

  it('getDailyHistory ordena de más reciente a más antigua', () => {
    SaveManager.recordDaily('daily_20260910', 5);
    SaveManager.recordDaily('daily_20260914', 10);
    expect(SaveManager.getDailyHistory().map(([k]) => k)).toEqual([
      'daily_20260914',
      'daily_20260910',
    ]);
  });
});
