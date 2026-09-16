import { existsSync, mkdirSync } from 'node:fs';
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
  die(cause: number, breathless: boolean): void;
}

/** Subconjunto de `Game` que `src/main.ts` expone en `window.__flapo`. */
interface DebugFlapo {
  getState(): number;
  getScore(): number;
  getHighScore(): number;
  isPaused(): boolean;
  bird: PajaroDebug;
  pipeSpawner: { pipes: TuberiaDebug[] };
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
  await page.waitForFunction(() => window.__flapo !== undefined, { timeout: 30_000 });
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
  const { width = 390, height = 844, deviceScaleFactor = 2, almacen } = opciones;

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
