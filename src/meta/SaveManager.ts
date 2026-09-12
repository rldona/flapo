import { Difficulty, confidenceLevel } from '../config/GameConfig';

/**
 * Port de `save_manager.gd` sobre `localStorage`.
 *
 * Regla de oro del original, que se mantiene: **nunca reventar**. Un guardado
 * ausente, corrupto o de otra versión devuelve valores por defecto. Perder el
 * récord es molesto; no poder abrir el juego es un desastre.
 */
const KEY = 'flapo.save.v1';

interface SaveData {
  high_score: number;
  games_played: number;
  total_score: number;
  confidence: number;
  difficulty: number;
  mirror: number;
  player_name: string;
  has_glided: number;
  journey_completed: number;
  [daily: string]: number | string;
}

const DEFAULTS: SaveData = {
  high_score: 0,
  games_played: 0,
  total_score: 0,
  confidence: 0,
  difficulty: Difficulty.NORMAL,
  mirror: 0,
  player_name: '',
  has_glided: 0,
  journey_completed: 0,
};

let cache: SaveData | null = null;

function datos(): SaveData {
  if (cache) return cache;
  cache = { ...DEFAULTS };
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      for (const k of Object.keys(DEFAULTS)) {
        const v = parsed[k];
        if (typeof v === typeof DEFAULTS[k]) {
          (cache as Record<string, unknown>)[k] = v;
        }
      }
      // Claves de reto del día: daily_YYYYMMDD.
      for (const k of Object.keys(parsed)) {
        if (k.startsWith('daily_')) {
          const v = parsed[k];
          if (typeof v === 'number') cache[k] = v;
        }
      }
    }
  } catch {
    cache = { ...DEFAULTS };
  }
  return cache;
}

function guardar(): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(datos()));
  } catch {
    /* disco lleno o modo privado: se sigue jugando con los datos en memoria */
  }
}

function leerInt(clave: string): number {
  const v = datos()[clave];
  if (typeof v !== 'number' || !Number.isFinite(v)) return 0;
  return Math.max(Math.trunc(v), 0);
}

export const SaveManager = {
  getHighScore(): number {
    return leerInt('high_score');
  },
  getGamesPlayed(): number {
    return leerInt('games_played');
  },
  getTotalScore(): number {
    return leerInt('total_score');
  },
  getAverageScore(): number {
    const partidas = this.getGamesPlayed();
    if (partidas <= 0) return 0;
    return this.getTotalScore() / partidas;
  },
  getConfidence(): number {
    return leerInt('confidence');
  },
  getDifficulty(): Difficulty {
    const v = datos().difficulty;
    if (typeof v !== 'number' || v < 0 || v > Difficulty.DIFICIL) return Difficulty.NORMAL;
    return v as Difficulty;
  },
  setDifficulty(modo: Difficulty): void {
    datos().difficulty = modo;
    guardar();
  },
  getMirror(): boolean {
    return leerInt('mirror') > 0;
  },
  setMirror(activo: boolean): void {
    datos().mirror = activo ? 1 : 0;
    guardar();
  },
  getPlayerName(): string {
    const v = datos().player_name;
    return typeof v === 'string' ? v : '';
  },
  setPlayerName(nombre: string): void {
    datos().player_name = nombre;
    guardar();
  },
  getHasGlided(): boolean {
    return leerInt('has_glided') > 0;
  },
  setHasGlided(): void {
    if (this.getHasGlided()) return;
    datos().has_glided = 1;
    guardar();
  },
  getJourneyCompleted(): boolean {
    return leerInt('journey_completed') > 0;
  },
  setJourneyCompleted(): void {
    if (this.getJourneyCompleted()) return;
    datos().journey_completed = 1;
    guardar();
  },
  getDailyBest(clave: string): number {
    return leerInt(clave);
  },
  recordDaily(clave: string, score: number): boolean {
    if (score <= this.getDailyBest(clave)) return false;
    datos()[clave] = score;
    guardar();
    return true;
  },
  getDailyHistory(): Array<[string, number]> {
    const salida: Array<[string, number]> = [];
    for (const k of Object.keys(datos())) {
      if (k.startsWith('daily_')) salida.push([k, leerInt(k)]);
    }
    salida.sort((a, b) => (a[0] < b[0] ? 1 : -1));
    return salida;
  },
  recordGame(score: number, cuentaParaElRecord = true): boolean {
    const d = datos();
    const record = cuentaParaElRecord && score > d.high_score;
    if (record) d.high_score = score;
    const partidas = d.games_played + 1;
    d.games_played = partidas;
    d.total_score = d.total_score + Math.max(score, 0);
    d.confidence = Math.max(d.confidence, confidenceLevel(partidas));
    guardar();
    return record;
  },
  clear(): void {
    cache = { ...DEFAULTS };
    try {
      localStorage.removeItem(KEY);
    } catch {
      /* ignore */
    }
  },
  forgetCache(): void {
    cache = null;
  },
};
