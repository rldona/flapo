import { GameState } from '../core/types';

/**
 * Port de `juice.gd`: flash, sacudida, hit-stop y rebote al morir (T-042).
 *
 * El hit-stop se cuenta con reloj real y no con ticks de simulación, porque
 * durante el hit-stop la simulación está parada: es lo que permite que el
 * contador avance sin depender de sí mismo.
 */
export class Juice {
  flashAlpha = 0.75;
  flashTime = 0.28;
  shakeStrength = 7;
  shakeTime = 0.45;
  shakeFrequency = 34;
  hitStopTime = 0.08;

  setTimeScale: (scale: number) => void = () => {};

  private shakeLeft = 0;
  private flashLeft = 0;
  private hitStopLeft = 0;

  punch(): void {
    this.shakeLeft = this.shakeTime;
    this.flashLeft = this.flashTime;
    this.hitStopLeft = this.hitStopTime;
    if (this.hitStopTime > 0) this.setTimeScale(0);
  }

  /** Se llama cada frame de dibujo con delta REAL. */
  update(realDt: number): void {
    if (this.hitStopLeft > 0) {
      this.hitStopLeft -= realDt;
      this.setTimeScale(0);
      if (this.hitStopLeft <= 0) {
        this.hitStopLeft = 0;
        this.setTimeScale(1);
      }
      return;
    }
    if (this.shakeLeft > 0) this.shakeLeft = Math.max(this.shakeLeft - realDt, 0);
    if (this.flashLeft > 0) this.flashLeft = Math.max(this.flashLeft - realDt, 0);
  }

  shakeX(): number {
    if (this.shakeLeft <= 0) return 0;
    const intensidad = this.shakeStrength * (this.shakeLeft / this.shakeTime);
    return Math.sin(this.shakeLeft * this.shakeFrequency) * intensidad;
  }

  shakeY(): number {
    if (this.shakeLeft <= 0) return 0;
    const intensidad = this.shakeStrength * (this.shakeLeft / this.shakeTime);
    return Math.cos(this.shakeLeft * this.shakeFrequency * 1.37) * intensidad * 0.6;
  }

  alpha(): number {
    if (this.flashLeft <= 0) return 0;
    return this.flashAlpha * (this.flashLeft / this.flashTime);
  }

  onStateChanged(to: GameState): void {
    if (to === GameState.READY || to === GameState.MENU) this.reset();
  }

  reset(): void {
    this.shakeLeft = 0;
    this.flashLeft = 0;
    this.hitStopLeft = 0;
    this.setTimeScale(1);
  }
}
