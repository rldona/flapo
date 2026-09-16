import { readdirSync, readFileSync } from 'node:fs';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import puppeteer, { type Browser, type Page } from 'puppeteer-core';
import { build, preview, type PreviewServer } from 'vite';
import { rutaChrome } from './harness';

/**
 * PWA y offline.
 *
 * El service worker solo se registra en producción (`import.meta.env.PROD`), así
 * que este archivo compila el bundle real, lo sirve con `vite preview` y prueba
 * registro/activación, el manifest y que el juego abra **sin red** gracias a la
 * caché del SW.
 */

const ESPERA_BOOT = { timeout: 30_000, polling: 100 } as const;

async function abrir(browser: Browser, url: string): Promise<Page> {
  const page = await browser.newPage();
  await page.goto(url, { waitUntil: 'networkidle0', timeout: 60_000 });
  await page.waitForFunction(() => window.__flapo !== undefined, ESPERA_BOOT);
  return page;
}

describe('E2E · PWA y offline', () => {
  let browser: Browser;
  let server: PreviewServer;
  let base = '';

  beforeAll(async () => {
    // Vitest fija `NODE_ENV=test`, y Vite deriva `import.meta.env.PROD` de ahí:
    // sin forzarlo, el bloque de registro del SW se elimina del bundle.
    const anterior = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    try {
      await build({ configFile: 'vite.config.ts', mode: 'production', logLevel: 'warn' });
    } finally {
      if (anterior === undefined) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = anterior;
    }

    const bundle = readdirSync('dist/assets').find((f) => f.endsWith('.js')) ?? '';
    expect(readFileSync(`dist/assets/${bundle}`, 'utf8')).toContain('serviceWorker');

    server = await preview({
      configFile: 'vite.config.ts',
      logLevel: 'warn',
      preview: { host: '127.0.0.1', port: 0, strictPort: false },
    });
    const address = server.httpServer.address();
    const port = typeof address === 'object' && address !== null ? address.port : 0;
    if (port === 0) throw new Error('El preview de Vite no expuso ningún puerto');
    base = `http://127.0.0.1:${port}/`;

    browser = await puppeteer.launch({
      executablePath: rutaChrome(),
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--use-gl=angle',
        '--use-angle=swiftshader',
        '--enable-unsafe-swiftshader',
      ],
    });
  }, 180_000);

  afterAll(async () => {
    await browser?.close();
    await new Promise<void>((resolve) => server?.httpServer.close(() => resolve()));
  });

  it('el manifest es válido y su icono existe', async () => {
    const page = await browser.newPage();
    const res = await page.goto(new URL('manifest.webmanifest', base).href, {
      timeout: 30_000,
    });
    expect(res?.status()).toBe(200);
    const manifest = (await res?.json()) as {
      name?: string;
      start_url?: string;
      display?: string;
      icons?: Array<{ src: string; sizes: string; type: string }>;
    };
    expect(manifest.name).toBe('Flapo');
    expect(manifest.start_url).toBeTruthy();
    expect(manifest.display).toBeTruthy();
    expect(manifest.icons?.[0]?.sizes).toContain('512');

    const icon = await page.goto(new URL('sprites/icon_app.png', base).href, {
      timeout: 30_000,
    });
    expect(icon?.status()).toBe(200);
    expect(icon?.headers()['content-type']).toContain('image/png');
    await page.close();
  });

  it('registra y activa el service worker', async () => {
    const page = await abrir(browser, base);
    await page.evaluate(() => navigator.serviceWorker.ready);
    // Con el SW ya controlando, una recarga deja el shell en la caché.
    await page.reload({ waitUntil: 'networkidle0', timeout: 60_000 });
    await page.waitForFunction(() => navigator.serviceWorker.controller !== null, ESPERA_BOOT);

    const estado = await page.evaluate(async () => {
      const reg = await navigator.serviceWorker.ready;
      return { activo: Boolean(reg.active), caches: await caches.keys() };
    });
    expect(estado.activo).toBe(true);
    expect(estado.caches).toContain('flapo-v1');
    await page.close();
  });

  it('abre sin red gracias a la caché', async () => {
    const page = await abrir(browser, base);
    // Segunda carga ya con el SW controlando: así cachea el shell y los assets.
    await page.evaluate(() => navigator.serviceWorker.ready);
    await page.reload({ waitUntil: 'networkidle0', timeout: 60_000 });
    await page.waitForFunction(() => navigator.serviceWorker.controller !== null, ESPERA_BOOT);

    const cacheados = await page.evaluate(async () => {
      const cache = await caches.open('flapo-v1');
      return (await cache.keys()).length;
    });
    expect(cacheados).toBeGreaterThan(0);

    await page.setOfflineMode(true);
    await page.reload({ waitUntil: 'domcontentloaded', timeout: 60_000 });
    await page.waitForFunction(() => window.__flapo !== undefined, ESPERA_BOOT);

    expect(await page.evaluate(() => window.__flapo?.getState() ?? -1)).toBe(0); // MENU
    await page.close();
  });
});
