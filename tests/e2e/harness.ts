import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';
import puppeteer, { type Browser, type Page } from 'puppeteer-core';
import { createServer, type ViteDevServer } from 'vite';

/**
 * Arranque de los tests E2E: levanta la app (Vite en un puerto libre, o la URL
 * de `E2E_URL` si se define) y un Chrome headless, y expone utilidades para
 * pilotar la máquina de estados desde fuera.
 *
 * El navegador se resuelve por `CHROME_PATH` / `PUPPETEER_EXECUTABLE_PATH` o por
 * las rutas habituales de macOS y Linux; en CI (ubuntu-latest) es
 * `/usr/bin/google-chrome`.
 *
 * Cada caso usa una **página nueva** (`nuevaPagina`) en lugar de recargar la
 * misma: recargar una página que ya jugó deja el input y el bucle en un estado
 * del que Chrome headless no siempre se recupera.
 */

/** Mismos valores que `GameState` en `src/core/types.ts` (const enum). */
export const ESTADO = {
  MENU: 0,
  READY: 1,
  PLAYING: 2,
  GAME_OVER: 3,
} as const;

interface TuberiaDebug {
  x: number;
  gapCenter: number;
}

interface PajaroDebug {
  x: number;
  y: number;
  rotation: number;
  maskDisabled: boolean;
  die(cause: number, breathless: boolean): void;
}

/** Subconjunto de `Game` que `src/main.ts` expone en `window.__flapo`. */
interface DebugFlapo {
  getState(): number;
  getScore(): number;
  getHighScore(): number;
  isPaused(): boolean;
  startCode(codigo: string): boolean;
  changeState(estado: number): void;
  update(dt: number): void;
  render(): void;
  bird: PajaroDebug;
  pipeSpawner: { pipes: TuberiaDebug[] };
  juice: { reset(): void };
}

declare global {
  interface Window {
    __flapo?: DebugFlapo;
  }
}

const RUTAS_CHROME = [
  process.env.CHROME_PATH,
  process.env.PUPPETEER_EXECUTABLE_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome',
  '/usr/bin/google-chrome-stable',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
];

/** Primera ruta de Chrome/Chromium disponible, o error explicativo. */
export function rutaChrome(): string {
  for (const ruta of RUTAS_CHROME) {
    if (ruta && existsSync(ruta)) return ruta;
  }
  throw new Error(
    'No se encontró Chrome. Define CHROME_PATH (p. ej. /usr/bin/google-chrome).',
  );
}

export interface OpcionesPagina {
  width?: number;
  height?: number;
  deviceScaleFactor?: number;
  /** Claves de `localStorage` a sembrar antes de cargar la app. */
  almacen?: Record<string, string>;
  /**
   * Congela el bucle (no dispara `requestAnimationFrame`) y siembra
   * `Math.random`, para poder construir escenas deterministas paso a paso.
   */
  congelado?: boolean;
}

/** Servidor + navegador compartidos por todos los casos de un archivo. */
export interface EntornoE2E {
  url: string;
  browser: Browser;
  cerrar(): Promise<void>;
}

/** Una pestaña lista para testear, con sus errores recogidos y `cerrar()`. */
export interface SesionE2E {
  page: Page;
  errores: string[];
  cerrar(): Promise<void>;
}

async function esperarBoot(page: Page): Promise<void> {
  // `polling` numérico a propósito: con el bucle congelado no hay rAF que
  // dispare el sondeo por defecto de Puppeteer.
  await page.waitForFunction(() => window.__flapo !== undefined, { timeout: 30_000, polling: 100 });
}

/** Levanta el servidor de Vite (si no hay `E2E_URL`) y Chrome headless. */
export async function crearEntorno(): Promise<EntornoE2E> {
  let server: ViteDevServer | undefined;
  let url = process.env.E2E_URL ?? '';
  if (url === '') {
    server = await createServer({
      configFile: 'vite.config.ts',
      logLevel: 'warn',
      server: { host: '127.0.0.1', port: 0, strictPort: false },
    });
    await server.listen();
    const address = server.httpServer?.address();
    const port = typeof address === 'object' && address !== null ? address.port : 0;
    if (port === 0) throw new Error('El servidor de Vite no expuso ningún puerto');
    url = `http://127.0.0.1:${port}/`;
  }

  const browser = await puppeteer.launch({
    executablePath: rutaChrome(),
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--use-gl=angle',
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      '--autoplay-policy=no-user-gesture-required',
    ],
  });

  return {
    url,
    browser,
    async cerrar(): Promise<void> {
      await browser.close();
      await server?.close();
    },
  };
}

/** Abre una pestaña nueva, recoge errores y espera al boot de la app. */
export async function nuevaPagina(
  entorno: EntornoE2E,
  opciones: OpcionesPagina = {},
): Promise<SesionE2E> {
  const { width = 390, height = 844, deviceScaleFactor = 2, almacen, congelado = false } = opciones;

  const page = await entorno.browser.newPage();
  const errores: string[] = [];
  page.on('pageerror', (e: unknown) =>
    errores.push(`pageerror: ${e instanceof Error ? e.message : String(e)}`),
  );
  page.on('console', (m) => {
    if (m.type() === 'error') errores.push(`console: ${m.text()}`);
  });
  page.on('requestfailed', (r) =>
    errores.push(`requestfailed: ${r.url()} ${r.failure()?.errorText ?? ''}`),
  );

  if (almacen) {
    await page.evaluateOnNewDocument((datos: Record<string, string>) => {
      for (const [clave, valor] of Object.entries(datos)) localStorage.setItem(clave, valor);
    }, almacen);
  }

  if (congelado) {
    await page.evaluateOnNewDocument(() => {
      let id = 0;
      const w = window as unknown as {
        requestAnimationFrame: (cb: FrameRequestCallback) => number;
        cancelAnimationFrame: (handle: number) => void;
      };
      w.requestAnimationFrame = () => {
        id += 1;
        return id;
      };
      w.cancelAnimationFrame = () => {};
      // mulberry32: Math.random determinista para las gotas de lluvia.
      let estado = 0x9e3779b9 >>> 0;
      Math.random = (): number => {
        estado = (estado + 0x6d2b79f5) >>> 0;
        let t = estado;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
      };
    });
  }

  await page.setViewport({ width, height, deviceScaleFactor });
  await page.goto(entorno.url, { waitUntil: 'networkidle0', timeout: 60_000 });
  await esperarBoot(page);

  return {
    page,
    errores,
    async cerrar(): Promise<void> {
      await page.close();
    },
  };
}

/** Guarda una captura en `test-results/` para diagnosticar fallos en CI. */
export async function capturar(page: Page, nombre: string): Promise<string> {
  mkdirSync('test-results', { recursive: true });
  const ruta = `test-results/${nombre}.png`;
  await page.screenshot({ path: ruta });
  return ruta;
}

export interface PlanEscena {
  /** Deja la escena en el menú, sin arrancar código. */
  menu?: boolean;
  /** Semilla del código; su resto entre 4 elige el escenario. Evita el 0. */
  seed?: number;
  /** Avanza N pasos de 1/60 s antes de dibujar. */
  pasos?: number;
  /** Pasa a PLAYING antes de los pasos. */
  jugar?: boolean;
  /** Inmuniza al pájaro para poder dejar correr la partida sin que muera. */
  inmune?: boolean;
  /** Altura a la que colocar al pájaro antes de dibujar. */
  altura?: number;
  /** Mata al pájaro antes de los pasos (cae y queda apoyado). */
  morir?: boolean;
  /** Fija la rotación antes de dibujar (0 evita el suavizado del giro). */
  rotacion?: number;
}

/**
 * Construye una escena determinista (con el bucle congelado) y devuelve el PNG
 * del canvas lógico, sin depender del DPR ni del CSS.
 */
export async function capturarEscena(page: Page, plan: PlanEscena = {}): Promise<Buffer> {
  const dataUrl = await page.evaluate((p: PlanEscena) => {
    const g = window.__flapo;
    if (!g) throw new Error('window.__flapo no está listo');
    if (!p.menu) g.startCode(String(p.seed ?? 1).padStart(5, '0'));
    if (p.jugar || p.morir) g.changeState(2);
    if (p.inmune) g.bird.maskDisabled = true;
    if (p.morir) g.bird.die(0, false);
    const pasos = p.pasos ?? 0;
    for (let i = 0; i < pasos; i++) g.update(1 / 60);
    if (p.altura !== undefined) g.bird.y = p.altura;
    if (p.rotacion !== undefined) g.bird.rotation = p.rotacion;
    // Sin el bucle, el juice (flash/sacudida) no se decae; lo limpiamos para
    // que la escena no salga velada.
    g.juice.reset();
    g.render();
    const canvas = document.getElementById('playfield') as HTMLCanvasElement;
    return canvas.toDataURL('image/png');
  }, plan);
  return Buffer.from(dataUrl.slice(dataUrl.indexOf(',') + 1), 'base64');
}

const CARPETA_GOLDEN = 'tests/e2e/__screenshots__';
const MAX_DIFERENCIA = Number(process.env.VISUAL_MAX_DIFF ?? 0.003);

/**
 * Compara el PNG de una escena con su baseline en `tests/e2e/__screenshots__`.
 * Con `UPDATE_SNAPSHOTS=1` (o si aún no existe) escribe el baseline. En caso de
 * fallo deja `actual` y `diff` en `test-results/` para inspeccionarlos.
 */
export async function compararGolden(nombre: string, actual: Buffer): Promise<void> {
  mkdirSync(CARPETA_GOLDEN, { recursive: true });
  const ruta = `${CARPETA_GOLDEN}/${nombre}.png`;
  if (process.env.UPDATE_SNAPSHOTS === '1' || !existsSync(ruta)) {
    writeFileSync(ruta, actual);
    return;
  }

  const esperado = PNG.sync.read(readFileSync(ruta));
  const recibido = PNG.sync.read(actual);
  if (esperado.width !== recibido.width || esperado.height !== recibido.height) {
    throw new Error(
      `golden ${nombre}: tamaño ${recibido.width}x${recibido.height} != ${esperado.width}x${esperado.height}`,
    );
  }

  const diff = new PNG({ width: esperado.width, height: esperado.height });
  const distintos = pixelmatch(
    esperado.data,
    recibido.data,
    diff.data,
    esperado.width,
    esperado.height,
    { threshold: 0.1 },
  );
  const ratio = distintos / (esperado.width * esperado.height);
  if (ratio > MAX_DIFERENCIA) {
    mkdirSync('test-results', { recursive: true });
    writeFileSync(`test-results/golden-${nombre}-actual.png`, actual);
    writeFileSync(`test-results/golden-${nombre}-diff.png`, PNG.sync.write(diff));
    throw new Error(
      `golden ${nombre}: ${distintos} píxeles distintos (${(ratio * 100).toFixed(2)}% > ${(
        MAX_DIFERENCIA * 100
      ).toFixed(2)}%). Mira test-results/ o regenera con UPDATE_SNAPSHOTS=1`,
    );
  }
}

/** Espera a que la app alcance un estado concreto. */
export async function esperarEstado(
  page: Page,
  estado: number,
  timeout = 15_000,
): Promise<void> {
  await page.waitForFunction(
    (esperado: number) => window.__flapo?.getState() === esperado,
    { timeout },
    estado,
  );
}

export async function estado(page: Page): Promise<number> {
  return page.evaluate(() => window.__flapo?.getState() ?? -1);
}

export async function puntuacion(page: Page): Promise<number> {
  return page.evaluate(() => window.__flapo?.getScore() ?? 0);
}

export async function record(page: Page): Promise<number> {
  return page.evaluate(() => window.__flapo?.getHighScore() ?? 0);
}

export async function pausado(page: Page): Promise<boolean> {
  return page.evaluate(() => window.__flapo?.isPaused() ?? false);
}

/** Un aleteo real: mantiene `Space` el tiempo indicado. */
export async function aletear(page: Page, ms = 90): Promise<void> {
  await page.keyboard.down('Space');
  await new Promise((r) => setTimeout(r, ms));
  await page.keyboard.up('Space');
}

/**
 * Espera N frames de la página. El input solo se habilita en el primer tick
 * del bucle tras pasar a READY, así que hay que dejar correr un frame antes de
 * mandar el aleteo o la pulsación se pierde (según el timing).
 */
export async function esperarFrames(page: Page, veces = 2): Promise<void> {
  await page.evaluate(
    (n: number) =>
      new Promise<void>((resolve) => {
        let i = 0;
        const paso = (): void => {
          i++;
          if (i >= n) resolve();
          else requestAnimationFrame(paso);
        };
        requestAnimationFrame(paso);
      }),
    veces,
  );
}

/** Desde el menú: pulsa Jugar, espera READY y arranca con el primer aleteo. */
export async function empezarPartida(page: Page): Promise<void> {
  await page.click('[data-act="play"]');
  await esperarEstado(page, ESTADO.READY);
  await esperarFrames(page, 2);
  await aletear(page, 70);
  await esperarEstado(page, ESTADO.PLAYING);
}

/** Termina la partida en curso sin depender de colisiones. */
export async function matar(page: Page): Promise<void> {
  await page.evaluate(() => window.__flapo?.bird.die(0, false));
}

export interface ResultadoAutopiloto {
  puntuacionMaxima: number;
  pasos: number;
}

/**
 * Juega solo apuntando al centro del hueco de la próxima tubería, el mismo
 * piloto que usan `tools/smoke.mjs` y `tools/capture.mjs`.
 */
export async function jugarAutopilotado(
  page: Page,
  opciones: { pasos?: number; pausaMs?: number } = {},
): Promise<ResultadoAutopiloto> {
  const { pasos = 160, pausaMs = 35 } = opciones;
  let maxima = 0;
  for (let i = 0; i < pasos; i++) {
    const info = await page.evaluate(() => {
      const g = window.__flapo;
      if (!g) return null;
      const siguiente = g.pipeSpawner.pipes
        .filter((p) => p.x + 13 > g.bird.x)
        .sort((a, b) => a.x - b.x)[0];
      return {
        y: g.bird.y,
        objetivo: siguiente ? siguiente.gapCenter : 256,
        estado: g.getState(),
        puntuacion: g.getScore(),
      };
    });
    if (info === null) break;
    if (info.estado === ESTADO.MENU || info.estado === ESTADO.GAME_OVER) break;
    maxima = Math.max(maxima, info.puntuacion);
    if (info.estado === ESTADO.READY) {
      await aletear(page, 70);
    } else if (info.y > info.objetivo + 2) {
      await aletear(page, 60);
    }
    await new Promise((r) => setTimeout(r, pausaMs));
  }
  return { puntuacionMaxima: maxima, pasos };
}
