import * as C from '../config/GameConfig';
import { GameState } from '../core/types';
import { Assets, makeCanvas } from '../render/Assets';

/**
 * Port de `background.gd`: parallax de dos capas, variantes de escenario
 * (T-057) y tramos del viaje con fundido (T-222, ADR-0040).
 */
interface FarTile {
  canvas: HTMLCanvasElement;
  w: number;
  h: number;
}

export class Background {
  scrollSpeed = C.SCROLL_SPEED;
  moving = true;
  offset = 0;
  stage: C.Stage = C.Stage.PARQUE;
  variant: C.Scenery = C.Scenery.DIA;

  readonly farFactor = 0.15;
  readonly nearFactor = 0.4;

  private blend = 1;
  private farTiles = new Map<string, FarTile>();
  private nearTiles = new Map<string, HTMLCanvasElement>();

  private readonly nearY = 328;

  update(dt: number): void {
    if (this.blend < 1) {
      this.blend = Math.min(this.blend + dt / C.JOURNEY_FADE_TIME, 1);
    }
    if (!this.moving) return;
    this.offset += this.scrollSpeed * dt;
  }

  onStateChanged(to: GameState): void {
    this.moving = to !== GameState.GAME_OVER;
    if (to === GameState.MENU || to === GameState.READY) {
      this.offset = 0;
      this.stage = C.Stage.PARQUE;
      this.blend = 1;
    }
  }

  setVariant(variante: C.Scenery): void {
    this.variant = variante;
    this.farTiles.clear();
    this.nearTiles.clear();
  }

  setStage(tramo: C.Stage): void {
    if (tramo === this.stage) return;
    this.stage = tramo;
    this.blend = 0;
  }

  mezcla(): number {
    return this.blend;
  }

  rain(): boolean {
    return C.sceneryRains(this.variant);
  }

  private buildFar(tint: string): FarTile {
    const w = 144;
    const h = 170;
    const c = makeCanvas(w, h);
    const g = c.getContext('2d')!;
    g.imageSmoothingEnabled = false;
    const a = Assets.tinted('cloud_a', tint);
    const b = Assets.tinted('cloud_b', tint);
    g.drawImage(a, Math.round(32 - a.width / 2), Math.round(68 - a.height / 2));
    g.drawImage(b, Math.round(104 - b.width / 2), Math.round(116 - b.height / 2));
    return { canvas: c, w, h };
  }

  private nearTile(stage: C.Stage, tint: string): HTMLCanvasElement {
    const key = `${stage}|${tint}`;
    let c = this.nearTiles.get(key);
    if (c) return c;
    const name = ['stage_parque', 'city', 'stage_nubes', 'stage_cielo'][stage];
    c = Assets.tinted(name, tint);
    this.nearTiles.set(key, c);
    return c;
  }

  private tileHorizontal(
    g: CanvasRenderingContext2D,
    img: CanvasImageSource,
    tileW: number,
    tileH: number,
    y: number,
    offset: number,
    alpha: number,
  ): void {
    if (alpha <= 0) return;
    g.globalAlpha = alpha;
    const start = -(((offset % tileW) + tileW) % tileW);
    for (let x = start; x < C.VIEWPORT_WIDTH; x += tileW) {
      g.drawImage(img, Math.round(x), y, tileW, tileH);
    }
    g.globalAlpha = 1;
  }

  draw(g: CanvasRenderingContext2D, farTop = 0, farBottom = C.VIEWPORT_HEIGHT): void {
    const tint = C.sceneryTint(this.variant);
    let far = this.farTiles.get(tint);
    if (!far) {
      far = this.buildFar(tint);
      this.farTiles.set(tint, far);
    }
    // Las nubes se repiten también en vertical para que el cielo extra (arriba
    // y abajo) no quede liso.
    const offsetFar = this.offset * this.farFactor;
    for (let y = farTop - far.h; y < farBottom; y += far.h) {
      this.tileHorizontal(g, far.canvas, far.w, far.h, Math.round(y), offsetFar, 1);
    }

    const previo = Math.max(this.stage - 1, 0);
    if (this.stage > 0 && this.blend < 1) {
      const sell = this.nearTile(previo, tint);
      this.tileHorizontal(g, sell, sell.width, sell.height, this.nearY, this.offset * this.nearFactor, 1 - this.blend);
    }
    const actual = this.nearTile(this.stage, tint);
    const alfa = this.stage === 0 ? 1 : this.blend;
    this.tileHorizontal(g, actual, actual.width, actual.height, this.nearY, this.offset * this.nearFactor, alfa);
  }
}
