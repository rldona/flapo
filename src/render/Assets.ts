/**
 * Carga de sprites y utilidades de pintado pixel-art.
 *
 * Todo se precocina al arrancar: canvas teñidos, cuerpo de tubería repetido y
 * tiles de parallax. En el bucle de dibujo no se crea un solo canvas, para que
 * no haya basura que recoja el GC a mitad de partida.
 */

const SPRITE_NAMES = [
  'flapo_0',
  'flapo_1',
  'flapo_2',
  'pipe_body',
  'pipe_cap',
  'ground_tile',
  'city',
  'cloud_a',
  'cloud_b',
  'stage_parque',
  'stage_nubes',
  'stage_cielo',
  'fruit_azul',
  'fruit_naranja',
  'fruit_roja',
  'fruit_verde',
  'fruit_violeta',
  'medal_croqueta',
  'medal_tortilla',
  'medal_jamon',
  'logo',
  'icon_app',
  'score_digits',
] as const;

export type SpriteName = (typeof SPRITE_NAMES)[number];

const AUDIO_NAMES = [
  'flap',
  'point',
  'hit',
  'fall',
  'button',
  'fruit_good',
  'fruit_bad',
  'breath',
] as const;

export type AudioName = (typeof AUDIO_NAMES)[number];

const images = new Map<string, HTMLImageElement>();
const tintCache = new Map<string, HTMLCanvasElement>();
let pipeBodyCache = new Map<string, HTMLCanvasElement>();

function loadImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`No se ha podido cargar ${url}`));
    img.src = url;
  });
}

function canvas(w: number, h: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  return c;
}

export function tintCanvas(src: CanvasImageSource, w: number, h: number, color: string): HTMLCanvasElement {
  const c = canvas(w, h);
  const g = c.getContext('2d')!;
  g.imageSmoothingEnabled = false;
  g.drawImage(src, 0, 0, w, h);
  g.globalCompositeOperation = 'multiply';
  g.fillStyle = color;
  g.fillRect(0, 0, w, h);
  g.globalCompositeOperation = 'destination-in';
  g.drawImage(src, 0, 0, w, h);
  g.globalCompositeOperation = 'source-over';
  return c;
}

export const Assets = {
  ready: false,

  async load(): Promise<void> {
    const base = `${import.meta.env.BASE_URL}sprites`;
    await Promise.all(
      SPRITE_NAMES.map(async (name) => {
        const img = await loadImage(`${base}/${name}.png`);
        images.set(name, img);
      }),
    );
    pipeBodyCache = new Map();
    tintCache.clear();
    this.ready = true;
  },

  img(name: string): HTMLImageElement {
    const img = images.get(name);
    if (!img) throw new Error(`Sprite no cargado: ${name}`);
    return img;
  },

  tinted(name: string, color: string): HTMLCanvasElement {
    const key = `${name}|${color}`;
    let c = tintCache.get(key);
    if (!c) {
      const img = this.img(name);
      c = tintCanvas(img, img.width, img.height, color);
      tintCache.set(key, c);
    }
    return c;
  },

  /** Cuerpo de tubería repetido a lo alto, teñido si hace falta. */
  pipeBody(tint: string | null): HTMLCanvasElement {
    const key = tint ?? 'none';
    let c = pipeBodyCache.get(key);
    if (c) return c;
    const tile = tint ? this.tinted('pipe_body', tint) : this.img('pipe_body');
    const w = tile.width;
    const h = 512;
    c = canvas(w, h);
    const g = c.getContext('2d')!;
    g.imageSmoothingEnabled = false;
    for (let y = 0; y < h; y += tile.height) {
      g.drawImage(tile, 0, y);
    }
    pipeBodyCache.set(key, c);
    return c;
  },

  audioNames(): readonly AudioName[] {
    return AUDIO_NAMES;
  },

  audioUrl(name: AudioName): string {
    return `${import.meta.env.BASE_URL}audio/${name}.wav`;
  },
};

export { canvas as makeCanvas };
