import * as C from '../config/GameConfig';
import type { Rng } from '../core/Rng';
import type { Rect } from '../core/types';

/**
 * Port de `pipe.gd`: par de tubos con un hueco. Se mueve solo y se libera al
 * salir por la izquierda (ADR-0008).
 */
export class Pipe {
  x = 320;
  y = 0;
  width = 26;
  bodyLength = 512;
  scrollSpeed = C.SCROLL_SPEED;
  moving = true;

  gap = C.PIPE_GAP;
  gapCenter = 256;
  baseGapCenter = 256;

  soft = false;
  special = false;
  spin = false;
  spinTime = 0;

  oscillationAmplitude = 0;
  oscillationPeriod = C.MOVING_PIPE_PERIOD;
  oscillationPhase = 0;
  private oscTime = 0;

  scored = false;
  gone = false;

  readonly gapCenterMinRatio = 0.2;
  readonly gapCenterMaxRatio = 0.8;

  update(dt: number): void {
    if (!this.moving) return;
    this.x -= this.scrollSpeed * dt;
    if (this.oscillationAmplitude > 0 && this.oscillationPeriod > 0) {
      this.oscTime += dt;
      const angulo = this.oscillationPhase + (this.oscTime * Math.PI * 2) / this.oscillationPeriod;
      this.gapCenter = this.baseGapCenter + Math.sin(angulo) * this.oscillationAmplitude;
    }
    if (this.spin) this.spinTime += dt;
    if (this.x + this.width * 0.5 < 0) this.gone = true;
  }

  setGapCenter(y: number): void {
    this.gapCenter = y;
    this.baseGapCenter = y;
  }

  randomizeGap(rng: Rng): void {
    const ratio = rng.randfRange(this.gapCenterMinRatio, this.gapCenterMaxRatio);
    this.setGapCenter(ratio * C.playableHeight());
  }

  topRect(): Rect {
    const bottom = this.gapCenter - this.gap * 0.5;
    return { x: this.x - this.width / 2, y: bottom - this.bodyLength, w: this.width, h: this.bodyLength };
  }

  bottomRect(): Rect {
    const top = this.gapCenter + this.gap * 0.5;
    return { x: this.x - this.width / 2, y: top, w: this.width, h: this.bodyLength };
  }

  scoreRect(): Rect {
    return {
      x: this.x - this.width / 2,
      y: this.gapCenter - this.gap * 0.5,
      w: this.width,
      h: this.gap,
    };
  }

  spinAngle(): number {
    return this.spinTime * C.SPIN_PIPE_TURNS_PER_SECOND * Math.PI * 2;
  }

  isOscillating(): boolean {
    return this.oscillationAmplitude > 0;
  }
}
