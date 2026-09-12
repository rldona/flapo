import * as C from '../config/GameConfig';
import type { Rng } from '../core/Rng';
import { GameState } from '../core/types';

export const enum WindPhase {
  CALMA,
  AVISO,
  SOPLANDO,
}

export interface WindCallbacks {
  onWarning(aFavor: boolean): void;
  onGust(aFavor: boolean): void;
  onEnded(): void;
}

/** Port de `wind.gd`: ráfagas globales anunciadas 2 s antes (ADR-0026). */
export class Wind {
  enabled = false;
  randomSeed = 0;

  private fase: WindPhase = WindPhase.CALMA;
  private restante = 0;
  private aFavor = true;
  private rng: Rng | null = null;

  constructor(private readonly cb: WindCallbacks) {}

  setRng(rng: Rng): void {
    this.rng = rng;
    if (this.randomSeed !== 0) this.rng.seed = this.randomSeed;
  }

  onStateChanged(to: GameState): void {
    if (to !== GameState.PLAYING) {
      this.enabled = false;
      this.reset();
    }
  }

  reset(): void {
    this.fase = WindPhase.CALMA;
    this.restante = this.calma();
    if (this.randomSeed !== 0 && this.rng) this.rng.seed = this.randomSeed;
  }

  update(dt: number): void {
    if (!this.enabled || !this.rng) return;
    this.restante -= dt;
    if (this.restante > 0) return;
    if (this.fase === WindPhase.CALMA) {
      this.aFavor = this.rng.randf() < 0.5;
      this.entrar(WindPhase.AVISO, C.WIND_WARNING_TIME);
      this.cb.onWarning(this.aFavor);
    } else if (this.fase === WindPhase.AVISO) {
      this.entrar(WindPhase.SOPLANDO, C.WIND_DURATION);
      this.cb.onGust(this.aFavor);
    } else {
      this.entrar(WindPhase.CALMA, this.calma());
      this.cb.onEnded();
    }
  }

  isBlowing(): boolean {
    return this.fase === WindPhase.SOPLANDO;
  }

  isWarning(): boolean {
    return this.fase === WindPhase.AVISO;
  }

  isTailwind(): boolean {
    return this.aFavor;
  }

  timeLeft(): number {
    return Math.max(this.restante, 0);
  }

  private entrar(fase: WindPhase, duracion: number): void {
    this.fase = fase;
    this.restante = duracion;
  }

  private calma(): number {
    if (!this.rng) return C.WIND_CALM_MIN;
    return this.rng.randfRange(C.WIND_CALM_MIN, C.WIND_CALM_MAX);
  }
}
