import { GHOST_MAX_FRAMES } from '../config/GameConfig';

/**
 * Port de `ghost_record.gd` (T-243) sobre `localStorage`.
 *
 * Guarda posiciones, no pulsaciones (ADR-0032): el fantasma **es** el vuelo que
 * se hizo, y sigue siéndolo aunque un día cambien las constantes. Solo la `y`:
 * la `x` de Flapo nunca se mueve.
 *
 * Misma regla de oro: un registro ausente o corrupto devuelve `null` y el
 * juego sigue exactamente igual, solo que sin fantasma.
 */
const KEY = 'flapo.ghost.v1';

export class GhostRecord {
  semilla = 0;
  score = 0;
  posiciones: number[] = [];

  frames(): number {
    return this.posiciones.length;
  }

  yEn(frame: number): number {
    if (this.posiciones.length === 0) return 0;
    const i = Math.min(Math.max(frame, 0), this.posiciones.length - 1);
    return this.posiciones[i];
  }

  guardar(): boolean {
    try {
      localStorage.setItem(
        KEY,
        JSON.stringify({ semilla: this.semilla, score: this.score, posiciones: this.posiciones }),
      );
      return true;
    } catch {
      return false;
    }
  }

  static cargar(): GhostRecord | null {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw) as Partial<GhostRecord>;
      if (
        typeof parsed.semilla !== 'number' ||
        typeof parsed.score !== 'number' ||
        !Array.isArray(parsed.posiciones)
      ) {
        return null;
      }
      const posiciones = parsed.posiciones.filter((n) => typeof n === 'number');
      if (posiciones.length <= 0 || posiciones.length > GHOST_MAX_FRAMES) return null;
      const rec = new GhostRecord();
      rec.semilla = parsed.semilla;
      rec.score = parsed.score;
      rec.posiciones = posiciones;
      return rec;
    } catch {
      return null;
    }
  }

  static borrar(): void {
    try {
      localStorage.removeItem(KEY);
    } catch {
      /* ignore */
    }
  }
}
