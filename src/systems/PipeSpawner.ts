import * as C from '../config/GameConfig';
import type { Rng } from '../core/Rng';
import { GameState } from '../core/types';
import { Pipe } from './Pipe';

export interface PipeSpawnerCallbacks {
  onPipeSpawned(pipe: Pipe): void;
}

/**
 * Port de `pipe_spawner.gd`. Las tuberías viven en una lista, el spawner solo
 * sabe cuándo crear y cuándo parar. El temporizador cuenta en ticks de física.
 */
export class PipeSpawner {
  pipes: Pipe[] = [];

  spawnX = 320;
  randomSeed = 0;

  scrollSpeed = C.SCROLL_SPEED;
  gap = C.PIPE_GAP;
  spacing = C.PIPE_SPACING;
  movingChance = 0;
  spinChance = 0;
  specialLeft = 0;

  private reservedNormal = false;
  private contador = 0;
  private interval = C.PIPE_SPACING / C.SCROLL_SPEED;
  private nextIn = 0;
  private active = false;
  private paused = false;
  private rng: Rng | null = null;

  constructor(private readonly cb: PipeSpawnerCallbacks) {}

  setRng(rng: Rng): void {
    this.rng = rng;
  }

  onStateChanged(to: GameState): void {
    if (to === GameState.MENU || to === GameState.READY) {
      this.contador = 0;
      this.active = false;
      this.paused = false;
      this.pipes = [];
      this.specialLeft = 0;
      this.reservedNormal = false;
    } else if (to === GameState.PLAYING) {
      this.active = true;
      this.paused = false;
      this.nextIn = this.interval;
      this.createPipe();
    } else if (to === GameState.GAME_OVER) {
      this.active = false;
      this.paused = true;
      for (const p of this.pipes) p.moving = false;
    }
  }

  setDifficulty(velocidad: number, hueco: number, separacion: number): void {
    this.scrollSpeed = velocidad;
    this.gap = hueco;
    this.spacing = separacion;
    this.interval = separacion / velocidad;
    for (const p of this.pipes) p.scrollSpeed = velocidad;
  }

  setPaused(pausado: boolean): void {
    this.paused = pausado;
    this.active = !pausado;
  }

  isPaused(): boolean {
    return this.paused;
  }

  reserveNormal(): boolean {
    this.reservedNormal = true;
    return true;
  }

  lastPipe(): Pipe | null {
    let mejor: Pipe | null = null;
    for (const p of this.pipes) {
      if (!mejor || p.x > mejor.x) mejor = p;
    }
    return mejor;
  }

  update(dt: number): void {
    if (!this.active || this.paused || !this.rng) return;
    this.nextIn -= dt;
    if (this.nextIn <= 0) {
      this.nextIn += this.interval;
      this.createPipe();
    }
  }

  private createPipe(): void {
    if (!this.rng) return;
    const pipe = new Pipe();
    pipe.scrollSpeed = this.scrollSpeed;
    pipe.gap = this.gap;
    pipe.x = this.spawnX;
    pipe.soft = C.isSoftPipe(this.contador);
    this.contador++;
    pipe.randomizeGap(this.rng);

    // Cada tubería consume siempre los mismos números: la secuencia no puede
    // depender de lo que decida ser (ADR-0030).
    const saleMovil = this.movingChance > 0 && this.rng.randf() < this.movingChance;
    const fase = this.rng.randfRange(0, Math.PI * 2);
    const saleGiro = this.spinChance > 0 && this.rng.randf() < this.spinChance;

    const reservada = this.reservedNormal;
    this.reservedNormal = false;

    if (this.specialLeft > 0 && !reservada) {
      this.vestirDeTramo(pipe);
    } else if (!reservada) {
      if (saleMovil) {
        pipe.oscillationAmplitude = C.movingPipeAmplitude(pipe.gap, pipe.gapCenter);
        pipe.oscillationPhase = fase;
      }
      pipe.spin = saleGiro;
    }

    this.pipes.push(pipe);
    this.cb.onPipeSpawned(pipe);
  }

  private vestirDeTramo(pipe: Pipe): void {
    pipe.special = true;
    pipe.soft = C.isSpecialSoft(this.specialLeft);
    pipe.oscillationAmplitude = C.movingPipeAmplitude(pipe.gap, pipe.gapCenter);
    pipe.oscillationPhase = 0;
    pipe.spin = true;
    this.specialLeft--;
  }
}
