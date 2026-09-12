import { dailyKey, dailyName, dailySeed } from '../config/GameConfig';
import { SaveManager } from './SaveManager';

/** Port de `daily_challenge.gd` (T-241). Fecha local, sin servidor. */
export class DailyChallenge {
  fecha: number[] = [];

  activo(): boolean {
    return this.fecha.length === 3;
  }

  static hoy(): number[] {
    const d = new Date();
    return [d.getFullYear(), d.getMonth() + 1, d.getDate()];
  }

  empezar(nueva: number[] = []): void {
    this.fecha = nueva.length === 3 ? [...nueva] : DailyChallenge.hoy();
  }

  parar(): void {
    this.fecha = [];
  }

  semilla(): number {
    if (!this.activo()) return 0;
    return dailySeed(this.fecha[0], this.fecha[1], this.fecha[2]);
  }

  clave(): string {
    if (!this.activo()) return '';
    return dailyKey(this.fecha[0], this.fecha[1], this.fecha[2]);
  }

  nombre(): string {
    if (!this.activo()) return '';
    return `Reto del ${dailyName(this.fecha[1], this.fecha[2])}`;
  }

  mejor(): number {
    const k = this.clave();
    return k !== '' ? SaveManager.getDailyBest(k) : 0;
  }
}
