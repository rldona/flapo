import * as C from '../config/GameConfig';
import * as A from '../config/AirConfig';
import { GameState, type Rect } from '../core/types';
import type { PipeSpawner } from './PipeSpawner';

export class Thermal {
  x = 0;
  y = 0;
  scrollSpeed = C.SCROLL_SPEED;
  moving = true;
  gone = false;
  readonly w = A.THERMAL_SIZE_W;
  readonly h = A.THERMAL_SIZE_H;
  phase = 0;
  inside = false;

  update(dt: number): void {
    if (!this.moving) return;
    this.x -= this.scrollSpeed * dt;
    this.phase += dt;
    if (this.x < -this.w) this.gone = true;
  }

  rect(): Rect {
    return { x: this.x - this.w / 2, y: this.y - this.h / 2, w: this.w, h: this.h };
  }
}

export class Slipstream {
  x = 0;
  y = 0;
  scrollSpeed = C.SCROLL_SPEED;
  moving = true;
  gone = false;
  ancho = C.VIEWPORT_WIDTH;
  restante = A.SLIPSTREAM_TIME;
  inside = false;

  update(dt: number): void {
    if (!this.moving) return;
    this.x -= this.scrollSpeed * dt;
    this.restante -= dt;
    if (this.restante <= 0 || this.x < -this.ancho) this.gone = true;
  }

  alpha(): number {
    return Math.max(0, Math.min(this.restante / A.SLIPSTREAM_TIME, 1)) * 0.5;
  }

  rect(): Rect {
    return {
      x: this.x - this.ancho / 2,
      y: this.y - A.SLIPSTREAM_HEIGHT / 2,
      w: this.ancho,
      h: A.SLIPSTREAM_HEIGHT,
    };
  }
}

export class Brother {
  x = 0;
  y = 0;
  scrollSpeed = C.SCROLL_SPEED;
  moving = true;
  gone = false;

  update(dt: number): void {
    if (!this.moving) return;
    this.x -= this.scrollSpeed * A.BROTHER_SPEED_MULT * dt;
    if (this.x < -32) this.gone = true;
  }
}

/**
 * Port de `air_spawner.gd`: térmicas (T-203) y el rebufo del hermano (T-204).
 * Se engancha a `pipe_spawned` y cuenta tuberías; no pide un solo número al
 * generador, así que no altera la secuencia determinista.
 */
export class AirSpawner {
  thermals: Thermal[] = [];
  slips: Slipstream[] = [];
  brothers: Brother[] = [];

  scrollSpeed = C.SCROLL_SPEED;
  spacing = C.PIPE_SPACING;
  spawnX = 320;

  private contador = 0;
  private score = 0;
  private pipeSpawner: PipeSpawner | null = null;

  onStateChanged(to: GameState): void {
    if (to === GameState.MENU || to === GameState.READY) {
      this.contador = 0;
      this.score = 0;
      this.thermals = [];
      this.slips = [];
      this.brothers = [];
    } else if (to === GameState.GAME_OVER) {
      for (const t of this.thermals) t.moving = false;
      for (const s of this.slips) s.moving = false;
      for (const b of this.brothers) b.moving = false;
    }
  }

  setPipeSpawner(spawner: PipeSpawner): void {
    this.pipeSpawner = spawner;
  }

  setDifficulty(velocidad: number, separacion: number, score: number): void {
    this.scrollSpeed = velocidad;
    this.spacing = separacion;
    this.score = score;
    for (const t of this.thermals) t.scrollSpeed = velocidad;
    for (const s of this.slips) s.scrollSpeed = velocidad;
    for (const b of this.brothers) b.scrollSpeed = velocidad;
  }

  onPipeSpawned(): void {
    this.contador += 1;
    this.quizaHermano();
    if (!this.tocaTermica() || !this.pipeSpawner) return;
    const anterior = this.pipeSpawner.lastPipe();
    if (anterior && (anterior.oscillationAmplitude > 0 || anterior.special)) return;
    if (!this.pipeSpawner.reserveNormal()) return;
    this.crearTermica();
  }

  update(dt: number): void {
    for (const t of this.thermals) t.update(dt);
    for (const s of this.slips) s.update(dt);
    for (const b of this.brothers) b.update(dt);
    this.thermals = this.thermals.filter((t) => !t.gone);
    this.slips = this.slips.filter((s) => !s.gone);
    this.brothers = this.brothers.filter((b) => !b.gone);
  }

  private quizaHermano(): void {
    if (this.score < A.BROTHER_MIN_SCORE) return;
    if (A.BROTHER_INTERVAL <= 0 || this.contador % A.BROTHER_INTERVAL !== 0) return;
    const y = this.alturaLibre();
    const hermano = new Brother();
    hermano.scrollSpeed = this.scrollSpeed;
    hermano.x = C.VIEWPORT_WIDTH + 24;
    hermano.y = y;
    this.brothers.push(hermano);

    const estela = new Slipstream();
    estela.scrollSpeed = this.scrollSpeed;
    estela.ancho = C.VIEWPORT_WIDTH;
    estela.x = C.VIEWPORT_WIDTH * 0.5;
    estela.y = y;
    this.slips.push(estela);
  }

  private alturaLibre(): number {
    const alto = C.playableHeight();
    let centro = alto * 0.5;
    const ultima = this.pipeSpawner?.lastPipe();
    if (ultima) centro = ultima.gapCenter;
    if (centro < alto * 0.5) return alto - A.BROTHER_EDGE_MARGIN;
    return A.BROTHER_EDGE_MARGIN;
  }

  private tocaTermica(): boolean {
    if (this.score < A.THERMAL_MIN_SCORE) return false;
    if (A.THERMAL_INTERVAL <= 0) return false;
    return this.contador % A.THERMAL_INTERVAL === 0;
  }

  private crearTermica(): void {
    const t = new Thermal();
    t.scrollSpeed = this.scrollSpeed;
    const referencia = this.pipeSpawner?.spawnX ?? this.spawnX;
    t.x = referencia + this.spacing * 0.5;
    t.y = C.playableHeight() * 0.5;
    this.thermals.push(t);
  }
}
