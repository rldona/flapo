import * as C from '../config/GameConfig';
import type { Rng } from '../core/Rng';
import { GameState } from '../core/types';
import { type EffectKind } from './Effects';

/** Port de `fruit.gd`: fruta flotante, `Area2D` que solo detecta el toque. */
export class Fruit {
  x = 320;
  y = 256;
  baseY = 256;
  phase = 0;
  scrollSpeed = C.SCROLL_SPEED;
  kind: EffectKind = 1;
  points = 0;
  taken = false;
  gone = false;

  readonly amplitude = 4;
  readonly floatSpeed = 1.6;

  update(dt: number): void {
    this.x -= this.scrollSpeed * dt;
    this.phase += dt * this.floatSpeed * Math.PI * 2;
    this.y = this.baseY + Math.sin(this.phase) * this.amplitude;
    if (this.x + 8 < 0) this.gone = true;
  }

  place(x: number, y: number): void {
    this.x = x;
    this.y = y;
    this.baseY = y;
  }

  /** Radio de colisión aproximado, dibujo 16x16. */
  radius(): number {
    return 8;
  }
}

/** Port de `fruit_spawner.gd`: nacen a mitad de camino entre dos tuberías. */
export class FruitSpawner {
  fruits: Fruit[] = [];

  chance = 0.6;
  spawnX = 320;
  minRatio = 0.25;
  maxRatio = 0.75;
  penaltyPoints = 3;
  bigMinGap = 90;
  randomSeed = 0;

  scrollSpeed = C.SCROLL_SPEED;

  private gapActual = C.PIPE_GAP;
  private separacion = C.PIPE_SPACING;
  private rng: Rng | null = null;
  private timerActive = false;
  private timerLeft = 0;

  setRng(rng: Rng): void {
    this.rng = rng;
  }

  onStateChanged(to: GameState): void {
    if (to === GameState.MENU || to === GameState.READY) {
      this.timerActive = false;
      this.fruits = [];
    } else if (to === GameState.GAME_OVER) {
      this.timerActive = false;
      for (const f of this.fruits) f.scrollSpeed = 0;
    }
  }

  setPaused(pausado: boolean): void {
    if (pausado) this.timerActive = false;
  }

  onPipeSpawned(): void {
    this.timerActive = true;
    this.timerLeft = this.medioIntervalo();
  }

  setDifficulty(velocidad: number, hueco: number, separacion: number): void {
    this.scrollSpeed = velocidad;
    this.gapActual = hueco;
    this.separacion = separacion;
    for (const f of this.fruits) f.scrollSpeed = velocidad;
  }

  update(dt: number): void {
    for (const f of this.fruits) f.update(dt);
    this.fruits = this.fruits.filter((f) => !f.gone);
    if (!this.timerActive || !this.rng) return;
    this.timerLeft -= dt;
    if (this.timerLeft > 0) return;
    this.timerActive = false;
    if (this.rng.randf() > this.chance) return;
    this.crear();
  }

  kindsDisponibles(): EffectKind[] {
    const kinds: EffectKind[] = [1, 2, 3, 5];
    if (this.gapActual >= this.bigMinGap) kinds.push(4);
    return kinds;
  }

  private medioIntervalo(): number {
    return (this.separacion / this.scrollSpeed) * 0.5;
  }

  private crear(): void {
    if (!this.rng) return;
    const kinds = this.kindsDisponibles();
    const kind = kinds[this.rng.randiRange(0, kinds.length - 1)];
    const fruit = new Fruit();
    fruit.kind = kind;
    fruit.points = kind === 2 || kind === 4 ? this.penaltyPoints : 0;
    fruit.scrollSpeed = this.scrollSpeed;
    fruit.phase = this.rng.randf() * Math.PI * 2;
    const ratio = this.rng.randfRange(this.minRatio, this.maxRatio);
    fruit.place(this.spawnX, ratio * C.playableHeight());
    this.fruits.push(fruit);
  }
}
