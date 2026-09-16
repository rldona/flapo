import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  chromium,
  devices,
  firefox,
  webkit,
  type Browser,
  type BrowserType,
  type Page,
} from 'playwright';
import { iniciarServidorVite, type ServidorVite } from './harness';

/**
 * Cross-browser y móvil con Playwright.
 *
 * Repite el flujo básico —arrancar, pasar a READY, aletear y entrar en
 * PLAYING— en **Chromium, Firefox y WebKit**, comprobando que no hay errores de
 * consola y que el canvas mantiene su resolución lógica. Además prueba el
 * aleteo táctil con un perfil móvil.
 */

const MOTORES: Array<[string, BrowserType]> = [
  ['chromium', chromium],
  ['firefox', firefox],
  ['webkit', webkit],
];

interface DebugFlapo {
  getState(): number;
}

async function jugar(page: Page): Promise<number> {
  await page.goto('/', { waitUntil: 'networkidle' });
  await page.waitForFunction(() => (window as unknown as { __flapo?: DebugFlapo }).__flapo !== undefined);
  const estadoInicial = await page.evaluate(
    () => (window as unknown as { __flapo: DebugFlapo }).__flapo.getState(),
  );
  await page.click('[data-act="play"]');
  await page.waitForFunction(
    () => (window as unknown as { __flapo: DebugFlapo }).__flapo.getState() === 1,
  );
  // El input solo se habilita en el primer tick del bucle tras pasar a READY:
  // hay que dejar correr un par de frames o el aleteo se pierde.
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => {
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      }),
  );
  await page.keyboard.down('Space');
  await page.waitForTimeout(80);
  await page.keyboard.up('Space');
  await page.waitForFunction(
    () => (window as unknown as { __flapo: DebugFlapo }).__flapo.getState() === 2,
  );
  return estadoInicial;
}

describe('E2E · cross-browser y móvil', () => {
  let servidor: ServidorVite;
  const navegadores = new Map<string, Browser>();

  beforeAll(async () => {
    servidor = await iniciarServidorVite();
    for (const [nombre, tipo] of MOTORES) {
      navegadores.set(nombre, await tipo.launch());
    }
  }, 180_000);

  afterAll(async () => {
    for (const browser of navegadores.values()) await browser.close();
    await servidor?.cerrar();
  });

  for (const [nombre] of MOTORES) {
    it(`${nombre}: arranca, juega y no da errores`, async () => {
      const browser = navegadores.get(nombre)!;
      const context = await browser.newContext({ baseURL: servidor.url });
      const page = await context.newPage();
      const errores: string[] = [];
      page.on('pageerror', (e) => errores.push(String(e)));
      page.on('console', (m) => {
        if (m.type() === 'error') errores.push(m.text());
      });

      expect(await jugar(page)).toBe(0); // MENU

      const canvas = await page.evaluate(() => {
        const c = document.getElementById('playfield') as HTMLCanvasElement;
        return { w: c.width, h: c.height };
      });
      expect(canvas.w).toBe(288);
      expect(canvas.h).toBeGreaterThanOrEqual(512);
      expect(errores).toEqual([]);
      await context.close();
    });
  }

  it('móvil táctil (Chromium): un toque aletea', async () => {
    const browser = navegadores.get('chromium')!;
    const context = await browser.newContext({ ...devices['iPhone 13'], baseURL: servidor.url });
    const page = await context.newPage();
    await page.goto('/', { waitUntil: 'networkidle' });
    await page.waitForFunction(
      () => (window as unknown as { __flapo?: DebugFlapo }).__flapo !== undefined,
    );
    await page.click('[data-act="play"]');
    await page.waitForFunction(
      () => (window as unknown as { __flapo: DebugFlapo }).__flapo.getState() === 1,
    );
    await page.waitForTimeout(120);
    await page.tap('#stage');
    await page.waitForFunction(
      () => (window as unknown as { __flapo: DebugFlapo }).__flapo.getState() === 2,
    );
    await context.close();
  });
});
