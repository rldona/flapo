import * as C from '../config/GameConfig';
import { Assets } from './Assets';
import type { AirSpawner } from '../systems/AirSpawner';
import type { Background } from '../systems/Background';
import type { Bird } from '../systems/Bird';
import type { Buddy } from '../systems/Buddy';
import { fruitTexture } from '../systems/Effects';
import type { FruitSpawner } from '../systems/Fruit';
import type { Ghost } from '../systems/Ghost';
import type { Ground } from '../systems/Ground';
import type { PipeSpawner } from '../systems/PipeSpawner';

interface Drop {
  x: number;
  y: number;
  len: number;
  speed: number;
}

/**
 * Renderer Canvas 2D del playfield lógico 288×512. Sin filtro, sin suavizado:
 * el canvas se escala por CSS con `image-rendering: pixelated`.
 */
export class Renderer {
  private birdFrames: CanvasImageSource[] = [];
  private pantFrames: HTMLCanvasElement[] = [];
  private ghostFrame: HTMLCanvasElement | null = null;
  private buddyFrame: HTMLCanvasElement | null = null;
  private drops: Drop[] = [];
  /** Alto lógico visible del playfield. Puede ser mayor que 512 para llenar
   *  ventanas altas: la banda jugable queda centrada y sobra cielo/colinas
   *  arriba y suelo abajo (equivalente a ADR-0042). */
  viewH = C.VIEWPORT_HEIGHT;
  /** Desplazamiento vertical de la banda de mundo dentro del viewport. */
  offsetY = 0;

  setView(viewH: number, offsetY: number): void {
    this.viewH = viewH;
    this.offsetY = offsetY;
  }

  constructor(
    private readonly ctx: CanvasRenderingContext2D,
    private readonly bird: Bird,
    private readonly pipeSpawner: PipeSpawner,
    private readonly fruitSpawner: FruitSpawner,
    private readonly air: AirSpawner,
    private readonly buddy: Buddy,
    private readonly ghost: Ghost,
    private readonly ground: Ground,
    private readonly background: Background,
  ) {
    this.birdFrames = [Assets.img('flapo_0'), Assets.img('flapo_1'), Assets.img('flapo_2')];
    this.pantFrames = [0, 1, 2].map((i) => Assets.tinted(`flapo_${i}`, C.PANT_TINT));
    this.ghostFrame = Assets.tinted('flapo_0', C.GHOST_TINT);
    this.buddyFrame = Assets.tinted('flapo_0', C.BUDDY_TINT);
    for (let i = 0; i < 48; i++) {
      this.drops.push({
        x: Math.random() * C.VIEWPORT_WIDTH,
        y: Math.random() * C.VIEWPORT_HEIGHT,
        len: 4 + Math.random() * 6,
        speed: 160 + Math.random() * 80,
      });
    }
  }

  updateVisuals(dt: number): void {
    if (!this.background.rain()) return;
    for (const d of this.drops) {
      d.y += d.speed * dt;
      d.x -= d.speed * 0.25 * dt;
      if (d.y > C.VIEWPORT_HEIGHT) {
        d.y = -8;
        d.x = Math.random() * (C.VIEWPORT_WIDTH + 40);
      }
    }
  }

  draw(scenerySky: string, shakeX: number, shakeY: number, flashAlpha: number): void {
    const g = this.ctx;
    g.save();
    g.imageSmoothingEnabled = false;
    this.drawSky(g, scenerySky);
    g.translate(Math.round(shakeX), Math.round(this.offsetY + shakeY));

    this.drawBackground(g);
    this.drawGround(g);
    this.drawAir(g);
    this.drawPipes(g);
    this.drawFruits(g);
    this.drawGhost(g);
    this.drawBuddy(g);
    this.drawBird(g);
    if (this.background.rain()) this.drawRain(g);

    g.restore();
    if (flashAlpha > 0) {
      g.fillStyle = `rgba(255,255,255,${flashAlpha})`;
      g.fillRect(0, 0, C.VIEWPORT_WIDTH, this.viewH);
    }
  }

  /** Cielo con un degradado muy suave: el alto extra se lee como parte del
   *  mundo y no como una franja plana del color de fondo. */
  private drawSky(g: CanvasRenderingContext2D, sky: string): void {
    const grd = g.createLinearGradient(0, 0, 0, this.viewH);
    grd.addColorStop(0, lighten(sky, 0.12));
    grd.addColorStop(0.55, sky);
    grd.addColorStop(1, lighten(sky, -0.08));
    g.fillStyle = grd;
    g.fillRect(0, 0, C.VIEWPORT_WIDTH, this.viewH);
  }

  /** Las nubes lejanas también cubren el alto extra, arriba y abajo. */
  private drawBackground(g: CanvasRenderingContext2D): void {
    const farTop = -this.offsetY;
    const farBottom = this.viewH - this.offsetY;
    this.background.draw(g, farTop, farBottom);
  }

  private drawGround(g: CanvasRenderingContext2D): void {
    const tile = Assets.img('ground_tile');
    const y = this.ground.surfaceY();
    const start = -this.ground.offset;
    for (let x = start; x < C.VIEWPORT_WIDTH; x += tile.width) {
      g.drawImage(tile, Math.round(x), y, tile.width, C.GROUND_HEIGHT);
    }
    // Relleno liso desde el final del tile hasta el borde inferior visible.
    const fondo = this.viewH - this.offsetY;
    g.fillStyle = '#D0AE62';
    g.fillRect(0, y + C.GROUND_HEIGHT, C.VIEWPORT_WIDTH, Math.max(0, fondo - (y + C.GROUND_HEIGHT)));
  }

  private drawPipes(g: CanvasRenderingContext2D): void {
    for (const p of this.pipeSpawner.pipes) {
      const tint = p.soft ? C.SOFT_PIPE_TINT : p.special ? C.SPECIAL_PIPE_TINT : null;
      const body = Assets.pipeBody(tint);
      const cap = tint ? Assets.tinted('pipe_cap', tint) : Assets.img('pipe_cap');
      const x = p.x;
      const media = p.bodyLength / 2;
      const topCenter = p.gapCenter - p.gap / 2 - media;
      const botCenter = p.gapCenter + p.gap / 2 + media;

      g.drawImage(body, Math.round(x - p.width / 2), Math.round(topCenter - media), p.width, p.bodyLength);
      g.drawImage(body, Math.round(x - p.width / 2), Math.round(botCenter - media), p.width, p.bodyLength);

      const angulo = p.spin ? p.spinAngle() : 0;
      const capH = cap.height;
      this.drawCap(g, cap, x, p.gapCenter - p.gap / 2 - capH / 2, true, angulo);
      this.drawCap(g, cap, x, p.gapCenter + p.gap / 2 + capH / 2, false, angulo);
    }
  }

  private drawCap(
    g: CanvasRenderingContext2D,
    cap: CanvasImageSource,
    x: number,
    y: number,
    flip: boolean,
    angle: number,
  ): void {
    g.save();
    g.translate(x, y);
    if (angle !== 0) g.rotate(angle);
    if (flip) g.scale(1, -1);
    const w = (cap as HTMLImageElement).width || 30;
    const h = (cap as HTMLImageElement).height || 14;
    g.drawImage(cap, -w / 2, -h / 2);
    g.restore();
  }

  private drawFruits(g: CanvasRenderingContext2D): void {
    for (const f of this.fruitSpawner.fruits) {
      const img = Assets.img(fruitTexture(f.kind));
      g.drawImage(img, Math.round(f.x - 8), Math.round(f.y - 8));
    }
  }

  private drawBird(g: CanvasRenderingContext2D): void {
    const frame = this.bird.animationFrame();
    const img = this.birdFrames[frame];
    const size = this.bird.sizeMult;
    g.save();
    g.translate(this.bird.x, this.bird.y);
    g.rotate(this.bird.rotation);
    if (this.bird.mirror) g.scale(1, -1);
    g.scale(size, size);
    g.drawImage(img, -12, -12, 24, 24);
    const peso = this.bird.pantTintWeight();
    if (peso > 0) {
      g.globalAlpha = peso;
      g.drawImage(this.pantFrames[frame], -12, -12, 24, 24);
      g.globalAlpha = 1;
    }
    g.restore();
  }

  private drawBuddy(g: CanvasRenderingContext2D): void {
    if (!this.buddy.visible || !this.buddyFrame) return;
    const frame = this.buddy.animationFrame();
    const img = frame === 0 ? this.buddyFrame : Assets.tinted(`flapo_${frame}`, C.BUDDY_TINT);
    g.save();
    g.translate(this.buddy.x, this.buddy.y);
    g.scale(C.BUDDY_SCALE, C.BUDDY_SCALE);
    g.drawImage(img, -12, -12, 24, 24);
    g.restore();
  }

  private drawGhost(g: CanvasRenderingContext2D): void {
    if (!this.ghost.visible || !this.ghostFrame) return;
    g.save();
    g.globalAlpha = C.GHOST_ALPHA;
    g.translate(this.ghost.x, this.ghost.y);
    g.drawImage(this.ghostFrame, -12, -12, 24, 24);
    g.restore();
  }

  private drawAir(g: CanvasRenderingContext2D): void {
    for (const s of this.air.slips) {
      g.save();
      g.globalAlpha = s.alpha();
      g.fillStyle = '#CFE6F2';
      const r = s.rect();
      g.fillRect(Math.round(r.x), Math.round(r.y), r.w, r.h);
      g.restore();
    }
    for (const t of this.air.thermals) {
      g.save();
      const r = t.rect();
      const grd = g.createLinearGradient(0, r.y + r.h, 0, r.y);
      grd.addColorStop(0, 'rgba(207,230,242,0.05)');
      grd.addColorStop(1, 'rgba(207,230,242,0.35)');
      g.fillStyle = grd;
      g.fillRect(Math.round(r.x), Math.round(r.y), r.w, r.h);
      g.fillStyle = 'rgba(255,255,255,0.55)';
      const t2 = (t.phase % 1) * 1;
      for (let i = 0; i < 4; i++) {
        const yy = r.y + r.h - (((i / 4 + t2) % 1) * r.h);
        g.fillRect(Math.round(t.x - 4), Math.round(yy), 8, 3);
      }
      g.restore();
    }
    for (const b of this.air.brothers) {
      g.save();
      g.translate(b.x, b.y);
      g.scale(1, 0.72);
      g.drawImage(this.birdFrames[0], -12, -12, 24, 24);
      g.restore();
    }
  }

  private drawRain(g: CanvasRenderingContext2D): void {
    g.strokeStyle = 'rgba(185,198,206,0.6)';
    g.lineWidth = 1;
    g.beginPath();
    for (const d of this.drops) {
      g.moveTo(d.x, d.y);
      g.lineTo(d.x - d.len * 0.25, d.y + d.len);
    }
    g.stroke();
  }
}

function lighten(hex: string, amount: number): string {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex);
  if (!m) return hex;
  const n = parseInt(m[1], 16);
  const f = (c: number) => {
    const target = amount < 0 ? 0 : 255;
    return Math.round(c + (target - c) * Math.abs(amount));
  };
  const r = f((n >> 16) & 255);
  const g = f((n >> 8) & 255);
  const b = f(n & 255);
  return `rgb(${r},${g},${b})`;
}
