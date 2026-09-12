import * as C from '../config/GameConfig';
import { GameState } from '../core/types';
import { GhostRecord } from '../meta/GhostRecord';
import { Settings } from '../meta/Settings';
import type { Bird } from './Bird';

/** Port de `ghost.gd`: graba y reproduce tu mejor vuelo (T-243). */
export class Ghost {
  x = 0;
  y = 0;
  visible = false;

  private registro: GhostRecord | null = null;
  private grabando: number[] = [];
  private frame = 0;
  private semilla = 0;
  private reproduciendo = false;
  private activo = false;
  private animTime = 0;

  constructor(private readonly bird: Bird) {
    this.registro = GhostRecord.cargar();
  }

  preparar(semilla: number): void {
    this.semilla = semilla;
  }

  onStateChanged(to: GameState): void {
    if (to === GameState.MENU || to === GameState.READY) {
      this.frame = 0;
      this.grabando = [];
      this.activo = false;
      this.reproduciendo = false;
      this.visible = false;
    } else if (to === GameState.PLAYING) {
      this.frame = 0;
      this.activo = true;
      this.animTime = 0;
      this.reproduciendo =
        !Settings.isGhostHidden() && this.registro !== null && this.registro.semilla === this.semilla;
      this.visible = this.reproduciendo;
      if (this.reproduciendo && this.registro) {
        this.x = this.bird.x;
        this.y = this.registro.yEn(0);
      }
    } else {
      this.activo = false;
    }
  }

  update(dt: number): void {
    if (!this.activo) return;
    this.animTime += dt * 10;
    if (this.grabando.length < C.GHOST_MAX_FRAMES) this.grabando.push(this.bird.y);
    if (this.reproduciendo && this.registro) {
      if (this.frame >= this.registro.frames()) {
        this.reproduciendo = false;
        this.visible = false;
      } else {
        this.y = this.registro.posiciones[this.frame];
      }
    }
    this.frame++;
  }

  terminar(score: number, esRecord: boolean): void {
    if (!esRecord || this.grabando.length === 0) return;
    const rec = new GhostRecord();
    rec.semilla = this.semilla;
    rec.score = score;
    rec.posiciones = this.grabando;
    if (rec.guardar()) this.registro = rec;
  }

  animationFrame(): number {
    return Math.floor(this.animTime) % 3;
  }

  estaReproduciendo(): boolean {
    return this.reproduciendo;
  }
}
