import * as C from '../config/GameConfig';
import { BuddyReaction, GameState } from '../core/types';
import type { Bird } from './Bird';

/** Port de `buddy.gd`: compañero silencioso, no colisiona ni puntúa (T-058). */
export class Buddy {
  x = 0;
  y = 0;
  reaction: BuddyReaction = BuddyReaction.NADA;
  visible = false;

  private restante = 0;
  private tiempo = 0;
  private activo = false;
  private animTime = 0;

  constructor(private readonly bird: Bird) {}

  onStateChanged(to: GameState): void {
    this.reaction = BuddyReaction.NADA;
    this.restante = 0;
    this.tiempo = 0;
    if (to === GameState.MENU) {
      this.activo = false;
      this.visible = false;
    } else if (to === GameState.READY || to === GameState.PLAYING) {
      this.activo = true;
      this.visible = true;
      this.x = this.bird.x + C.BUDDY_OFFSET_X;
      this.y = this.bird.y + C.BUDDY_OFFSET_Y;
    } else {
      this.activo = false;
    }
  }

  update(dt: number): void {
    if (!this.activo) return;
    this.tiempo += dt;
    this.animTime += dt * 10;
    if (this.restante > 0) {
      this.restante = Math.max(this.restante - dt, 0);
      if (this.restante <= 0) this.reaction = BuddyReaction.NADA;
    }
    const dest = this.destino();
    const peso = 1 - Math.exp(-dt / C.BUDDY_LAG);
    this.x += (dest.x - this.x) * peso;
    this.y += (dest.y - this.y) * peso;
  }

  private destino(): { x: number; y: number } {
    let x = this.bird.x + C.BUDDY_OFFSET_X;
    let y = this.bird.y + C.BUDDY_OFFSET_Y;
    y += Math.sin((this.tiempo * Math.PI * 2) / C.BUDDY_BOB_PERIOD) * C.BUDDY_BOB;
    if (this.reaction === BuddyReaction.SUSTO) {
      x -= C.BUDDY_SCARE_JUMP;
      y -= C.BUDDY_SCARE_JUMP;
    } else if (this.reaction === BuddyReaction.APLAUSO) {
      y -= Math.abs(Math.sin(this.tiempo * Math.PI * 2 * 3)) * C.BUDDY_CLAP_BOUNCE;
    }
    return { x, y };
  }

  animationFrame(): number {
    return Math.floor(this.animTime) % 3;
  }

  scare(): void {
    if (!this.activo) return;
    this.reaction = BuddyReaction.SUSTO;
    this.restante = C.BUDDY_SCARE_TIME;
  }

  clap(): void {
    if (!this.activo) return;
    this.reaction = BuddyReaction.APLAUSO;
    this.restante = C.BUDDY_CLAP_TIME;
  }
}
