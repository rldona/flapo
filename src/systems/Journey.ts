import * as C from '../config/GameConfig';
import { GameState } from '../core/types';

export interface JourneyCallbacks {
  onStarted(): void;
  onEnded(): void;
}

/**
 * Port de `journey.gd`: el nido a 50 puntos (T-209). No es un estado de la
 * máquina, es una pausa del generador con un cartel encima (ADR-0027).
 */
export class Journey {
  private restante = 0;
  private activa = false;
  private usada = false;

  constructor(private readonly cb: JourneyCallbacks) {}

  onStateChanged(to: GameState): void {
    if (to === GameState.MENU || to === GameState.READY) {
      this.restante = 0;
      this.activa = false;
      this.usada = false;
    } else if (to === GameState.GAME_OVER && this.activa) {
      this.activa = false;
      this.restante = 0;
      this.cb.onEnded();
    }
  }

  quizaEmpezar(score: number): boolean {
    if (this.usada || this.activa || score !== C.JOURNEY_END_SCORE) return false;
    this.usada = true;
    this.activa = true;
    this.restante = C.JOURNEY_SCENE_TIME;
    this.cb.onStarted();
    return true;
  }

  update(dt: number): void {
    if (!this.activa) return;
    this.restante -= dt;
    if (this.restante <= 0) {
      this.activa = false;
      this.restante = 0;
      this.cb.onEnded();
    }
  }

  activaAhora(): boolean {
    return this.activa;
  }

  usadaYa(): boolean {
    return this.usada;
  }

  get restanteSeg(): number {
    return this.restante;
  }
}
