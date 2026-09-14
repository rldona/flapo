import { beforeEach, describe, expect, it } from 'vitest';
import { Difficulty } from '../src/config/GameConfig';
import { SaveManager } from '../src/meta/SaveManager';

const KEY = 'flapo.save.v1';

class MemStorage {
  map = new Map<string, string>();
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
  raw(): string | null {
    return this.getItem(KEY);
  }
}

let storage: MemStorage;

function reset(): void {
  storage = new MemStorage();
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = storage;
  SaveManager.forgetCache();
  SaveManager.clear();
}

function escribirCrudo(valor: unknown): void {
  storage.setItem(KEY, typeof valor === 'string' ? valor : JSON.stringify(valor));
  SaveManager.forgetCache();
}

beforeEach(() => {
  reset();
});

describe('SaveManager: valores por defecto', () => {
  it('sin guardado todo vale cero / vacío', () => {
    expect(SaveManager.getHighScore()).toBe(0);
    expect(SaveManager.getGamesPlayed()).toBe(0);
    expect(SaveManager.getTotalScore()).toBe(0);
    expect(SaveManager.getAverageScore()).toBe(0);
    expect(SaveManager.getConfidence()).toBe(0);
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);
    expect(SaveManager.getMirror()).toBe(false);
    expect(SaveManager.getPlayerName()).toBe('');
    expect(SaveManager.getHasGlided()).toBe(false);
    expect(SaveManager.getJourneyCompleted()).toBe(false);
    expect(SaveManager.getDailyHistory()).toEqual([]);
  });
});

describe('SaveManager: nunca revienta', () => {
  it('JSON corrupto devuelve defaults', () => {
    escribirCrudo('{no es json');
    expect(SaveManager.getHighScore()).toBe(0);
    expect(SaveManager.getGamesPlayed()).toBe(0);
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);
    expect(SaveManager.getPlayerName()).toBe('');
  });

  it('tipos equivocados se ignoran', () => {
    escribirCrudo({
      high_score: 'cien',
      games_played: 'muchas',
      total_score: null,
      difficulty: 'difícil',
      mirror: 'sí',
      player_name: 123,
      has_glided: 'sí',
    });
    expect(SaveManager.getHighScore()).toBe(0);
    expect(SaveManager.getGamesPlayed()).toBe(0);
    expect(SaveManager.getTotalScore()).toBe(0);
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);
    expect(SaveManager.getMirror()).toBe(false);
    expect(SaveManager.getPlayerName()).toBe('');
    expect(SaveManager.getHasGlided()).toBe(false);
  });

  it('dificultad fuera de rango cae a NORMAL', () => {
    escribirCrudo({ difficulty: 99 });
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);
    escribirCrudo({ difficulty: -1 });
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);
  });

  it('si localStorage.getItem revienta, usa defaults', () => {
    (globalThis as unknown as { localStorage: unknown }).localStorage = {
      getItem: () => {
        throw new Error('modo privado');
      },
      setItem: () => {},
      removeItem: () => {},
    };
    SaveManager.forgetCache();
    expect(SaveManager.getHighScore()).toBe(0);
    expect(SaveManager.getDifficulty()).toBe(Difficulty.NORMAL);
    reset();
  });

  it('si setItem revienta, sigue jugando en memoria', () => {
    (globalThis as unknown as { localStorage: unknown }).localStorage = {
      getItem: () => null,
      setItem: () => {
        throw new Error('disco lleno');
      },
      removeItem: () => {},
    };
    SaveManager.forgetCache();
    expect(() => SaveManager.recordGame(10)).not.toThrow();
    expect(SaveManager.getHighScore()).toBe(10);
    expect(SaveManager.getGamesPlayed()).toBe(1);
    reset();
  });

  it('leerInt sanea: trunca, pinza negativos y NaN', () => {
    escribirCrudo({ high_score: 12.9, games_played: -5, total_score: NaN });
    // 12.9 se trunca a 12; -5 e Infinity/NaN caen a 0
    expect(SaveManager.getHighScore()).toBe(12);
    expect(SaveManager.getGamesPlayed()).toBe(0);
    expect(SaveManager.getTotalScore()).toBe(0);
    escribirCrudo({ high_score: Infinity });
    expect(SaveManager.getHighScore()).toBe(0);
  });
});

describe('SaveManager: ajustes', () => {
  it('dificultad ida y vuelta', () => {
    SaveManager.setDifficulty(Difficulty.FACIL);
    expect(SaveManager.getDifficulty()).toBe(Difficulty.FACIL);
    SaveManager.setDifficulty(Difficulty.DIFICIL);
    expect(SaveManager.getDifficulty()).toBe(Difficulty.DIFICIL);
  });

  it('espejo ida y vuelta', () => {
    SaveManager.setMirror(true);
    expect(SaveManager.getMirror()).toBe(true);
    SaveManager.setMirror(false);
    expect(SaveManager.getMirror()).toBe(false);
  });

  it('nombre ida y vuelta', () => {
    SaveManager.setPlayerName('Flapo');
    expect(SaveManager.getPlayerName()).toBe('Flapo');
  });

  it('has_glided y journey solo se marcan una vez', () => {
    expect(SaveManager.getHasGlided()).toBe(false);
    SaveManager.setHasGlided();
    expect(SaveManager.getHasGlided()).toBe(true);
    SaveManager.setHasGlided();
    expect(SaveManager.getHasGlided()).toBe(true);
    expect(SaveManager.getJourneyCompleted()).toBe(false);
    SaveManager.setJourneyCompleted();
    expect(SaveManager.getJourneyCompleted()).toBe(true);
    SaveManager.setJourneyCompleted();
    expect(SaveManager.getJourneyCompleted()).toBe(true);
  });

  it('persiste tras olvidar la caché (recarga)', () => {
    SaveManager.setDifficulty(Difficulty.DIFICIL);
    SaveManager.setPlayerName('Gordo');
    SaveManager.setMirror(true);
    SaveManager.forgetCache();
    expect(SaveManager.getDifficulty()).toBe(Difficulty.DIFICIL);
    expect(SaveManager.getPlayerName()).toBe('Gordo');
    expect(SaveManager.getMirror()).toBe(true);
  });
});

describe('SaveManager: partidas y récord', () => {
  it('la primera partida con puntos es récord', () => {
    expect(SaveManager.recordGame(10)).toBe(true);
    expect(SaveManager.getHighScore()).toBe(10);
    expect(SaveManager.getGamesPlayed()).toBe(1);
    expect(SaveManager.getTotalScore()).toBe(10);
    expect(SaveManager.getAverageScore()).toBe(10);
  });

  it('superar el récord lo sube, no superarlo lo mantiene', () => {
    SaveManager.recordGame(10);
    expect(SaveManager.recordGame(5)).toBe(false);
    expect(SaveManager.getHighScore()).toBe(10);
    expect(SaveManager.recordGame(15)).toBe(true);
    expect(SaveManager.getHighScore()).toBe(15);
    expect(SaveManager.getGamesPlayed()).toBe(3);
    expect(SaveManager.getTotalScore()).toBe(30);
    expect(SaveManager.getAverageScore()).toBeCloseTo(10, 8);
  });

  it('cuentaParaElRecord=false suma pero no corona', () => {
    SaveManager.recordGame(10);
    expect(SaveManager.recordGame(50, false)).toBe(false);
    expect(SaveManager.getHighScore()).toBe(10);
    expect(SaveManager.getGamesPlayed()).toBe(2);
    expect(SaveManager.getTotalScore()).toBe(60);
  });

  it('la puntuación negativa no resta ni corona', () => {
    expect(SaveManager.recordGame(-5)).toBe(false);
    expect(SaveManager.getHighScore()).toBe(0);
    expect(SaveManager.getGamesPlayed()).toBe(1);
    expect(SaveManager.getTotalScore()).toBe(0);
  });

  it('la confianza sube con las partidas', () => {
    for (let i = 0; i < 10; i++) SaveManager.recordGame(1);
    expect(SaveManager.getConfidence()).toBeGreaterThanOrEqual(1);
    expect(SaveManager.getAverageScore()).toBeCloseTo(1, 8);
  });

  it('clear borra disco y caché', () => {
    SaveManager.recordGame(30);
    SaveManager.setPlayerName('X');
    SaveManager.clear();
    expect(storage.raw()).toBeNull();
    expect(SaveManager.getHighScore()).toBe(0);
    expect(SaveManager.getPlayerName()).toBe('');
  });
});

describe('SaveManager: reto diario', () => {
  it('sin marca devuelve 0 y graba si mejora', () => {
    expect(SaveManager.getDailyBest('daily_20260914')).toBe(0);
    expect(SaveManager.recordDaily('daily_20260914', 12)).toBe(true);
    expect(SaveManager.getDailyBest('daily_20260914')).toBe(12);
  });

  it('empatar no cuenta como mejora', () => {
    SaveManager.recordDaily('daily_20260914', 12);
    expect(SaveManager.recordDaily('daily_20260914', 12)).toBe(false);
    expect(SaveManager.recordDaily('daily_20260914', 5)).toBe(false);
    expect(SaveManager.recordDaily('daily_20260914', 13)).toBe(true);
  });

  it('el historial ordena de más reciente a más viejo', () => {
    SaveManager.recordDaily('daily_20260914', 5);
    SaveManager.recordDaily('daily_20260915', 7);
    SaveManager.recordDaily('daily_20260913', 9);
    expect(SaveManager.getDailyHistory()).toEqual([
      ['daily_20260915', 7],
      ['daily_20260914', 5],
      ['daily_20260913', 9],
    ]);
  });

  it('las claves no-daily no entran al historial', () => {
    escribirCrudo({ high_score: 50, daily_20260914: 8, otra: 99 });
    expect(SaveManager.getDailyHistory()).toEqual([['daily_20260914', 8]]);
  });

  it('daily no numérico se ignora al cargar', () => {
    escribirCrudo({ daily_20260914: 'doce' });
    expect(SaveManager.getDailyBest('daily_20260914')).toBe(0);
    expect(SaveManager.getDailyHistory()).toEqual([]);
  });

  it('el diario sobrevive a la recarga', () => {
    SaveManager.recordDaily('daily_20260914', 21);
    SaveManager.forgetCache();
    expect(SaveManager.getDailyBest('daily_20260914')).toBe(21);
  });
});
