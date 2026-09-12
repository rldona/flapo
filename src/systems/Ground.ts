import * as C from '../config/GameConfig';
import { GameState } from '../core/types';

/** Port de `ground.gd`: scroll infinito, colisión fija (ADR-0010). */
export class Ground {
  scrollSpeed = C.SCROLL_SPEED;
  moving = true;
  offset = 0;

  private readonly tileWidth = C.VIEWPORT_WIDTH;

  update(dt: number): void {
    if (!this.moving) return;
    this.offset = (this.offset + this.scrollSpeed * dt) % this.tileWidth;
  }

  onStateChanged(to: GameState): void {
    this.moving = to !== GameState.GAME_OVER;
  }

  surfaceY(): number {
    return C.playableHeight();
  }
}
