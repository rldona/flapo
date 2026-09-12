import * as C from '../config/GameConfig';
import { GameState } from '../core/types';
import { makeCanvas } from '../render/Assets';
import type { Bird } from './Bird';
import type { PipeSpawner } from './PipeSpawner';

interface Muestra {
  x: number;
  y: number;
  tuberias: Array<[number, number, number, number]>;
}

/**
 * Port de `snapshot.gd` (T-077, ADR-0039): compone a mano una cronofotografía
 * del mejor salto. No usa el framebuffer, así que funciona igual en cualquier
 * navegador y de forma síncrona.
 */
export class Snapshot {
  sky = C.SCENERY_SKY[0];

  private estela: Muestra[] = [];
  private frames = 0;
  private activo = false;

  constructor(
    private readonly bird: Bird,
    private readonly pipeSpawner: PipeSpawner,
  ) {}

  onStateChanged(to: GameState): void {
    if (to === GameState.MENU || to === GameState.READY) {
      this.estela = [];
      this.frames = 0;
      this.activo = false;
    } else if (to === GameState.PLAYING) {
      this.activo = true;
    } else {
      this.activo = false;
    }
  }

  update(): void {
    if (!this.activo) return;
    this.frames++;
    const cada = this.cadaCuantos();
    if (this.frames % cada !== 0) return;
    this.estela.push({ x: this.bird.x, y: this.bird.y, tuberias: this.tuberias() });
    while (this.estela.length > C.SNAPSHOT_SAMPLES) this.estela.shift();
  }

  private cadaCuantos(): number {
    const total = Math.floor(C.SNAPSHOT_SECONDS * 60);
    return Math.max(Math.floor(total / C.SNAPSHOT_SAMPLES), 1);
  }

  private tuberias(): Array<[number, number, number, number]> {
    return this.pipeSpawner.pipes.map((p) => [p.x, p.gapCenter, p.gap, p.width]);
  }

  /** Compone y devuelve un data URL, o null si no había vuelo que contar. */
  capturar(): string | null {
    if (this.estela.length === 0 || typeof document === 'undefined') return null;
    const ancho = C.VIEWPORT_WIDTH;
    const alto = C.VIEWPORT_HEIGHT;
    const c = makeCanvas(ancho * C.SNAPSHOT_SCALE, alto * C.SNAPSHOT_SCALE);
    const g = c.getContext('2d');
    if (!g) return null;
    g.imageSmoothingEnabled = false;
    g.fillStyle = this.sky;
    g.fillRect(0, 0, c.width, c.height);
    const s = C.SNAPSHOT_SCALE;
    g.save();
    g.scale(s, s);
    for (const [x, centro, hueco, grosor] of this.estela[this.estela.length - 1].tuberias) {
      g.fillStyle = C.SNAPSHOT_PIPE_COLOR;
      const arriba = centro - hueco / 2;
      const abajo = centro + hueco / 2;
      g.fillRect(x - grosor / 2, 0, grosor, arriba);
      g.fillRect(x - grosor / 2, abajo, grosor, alto - abajo);
    }
    const flapo = new Image();
    flapo.src = `${import.meta.env.BASE_URL}sprites/flapo_0.png`;
    if (flapo.complete && flapo.naturalWidth > 0) {
      for (let i = 0; i < this.estela.length; i++) {
        const peso = i / Math.max(this.estela.length - 1, 1);
        const alfa = C.SNAPSHOT_FADE_MIN + (1 - C.SNAPSHOT_FADE_MIN) * peso;
        const m = this.estela[i];
        g.globalAlpha = alfa;
        g.drawImage(flapo, Math.round(m.x) - 12, Math.round(m.y) - 12, 24, 24);
      }
      g.globalAlpha = 1;
    }
    g.restore();
    return c.toDataURL('image/png');
  }
}
