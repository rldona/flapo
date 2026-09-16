import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';
import {
  capturar,
  crearEntorno,
  ESTADO,
  estado,
  nuevaPagina,
  type EntornoE2E,
  type SesionE2E,
} from './harness';

/**
 * E2E de arranque: la app carga sin errores, enseña el menú, abre sus paneles
 * y se adapta a móvil y escritorio.
 */
describe('E2E · arranque, menú y layout', () => {
  let entorno: EntornoE2E;
  let sesion: SesionE2E;

  beforeAll(async () => {
    entorno = await crearEntorno();
    sesion = await nuevaPagina(entorno, { width: 390, height: 844, deviceScaleFactor: 2 });
  }, 90_000);

  afterAll(async () => {
    await sesion?.cerrar();
    await entorno?.cerrar();
  });

  afterEach(async (context) => {
    if (context.task.result?.state === 'fail' && sesion?.page) {
      await capturar(sesion.page, 'arranque-fallo');
    }
  });

  it('carga el juego sin errores de consola ni peticiones fallidas', () => {
    expect(sesion.errores).toEqual([]);
  });

  it('muestra el menú principal y el canvas a resolución lógica', async () => {
    expect(await sesion.page.$('[aria-label="Menú principal"]')).not.toBeNull();
    expect(await sesion.page.$('[data-act="play"]')).not.toBeNull();

    const canvas = await sesion.page.evaluate(() => {
      const c = document.getElementById('playfield') as HTMLCanvasElement | null;
      return c ? { width: c.width, height: c.height } : null;
    });
    expect(canvas?.width).toBe(288);
    expect(canvas?.height ?? 0).toBeGreaterThanOrEqual(512);
  });

  it('arranca en estado MENU', async () => {
    expect(await estado(sesion.page)).toBe(ESTADO.MENU);
  });

  it('abre y cierra el panel de Opciones', async () => {
    await sesion.page.click('[data-act="options"]');
    await sesion.page.waitForSelector('[aria-label="Opciones"]');
    expect(await sesion.page.$('[aria-label="Opciones"]')).not.toBeNull();

    await sesion.page.click('[data-act="close"]');
    await sesion.page.waitForSelector('[aria-label="Menú principal"]');
  });

  it('abre el panel de Estadísticas', async () => {
    await sesion.page.click('[data-act="stats"]');
    await sesion.page.waitForSelector('[aria-label="Estadísticas"]');
    expect(await sesion.page.$('[aria-label="Estadísticas"]')).not.toBeNull();

    await sesion.page.click('[data-act="close"]');
    await sesion.page.waitForSelector('[aria-label="Menú principal"]');
  });

  it('se adapta a escritorio sin errores', async () => {
    await sesion.page.setViewport({ width: 1600, height: 900, deviceScaleFactor: 1 });
    await new Promise((r) => setTimeout(r, 600));

    const layout = await sesion.page.evaluate(() => {
      const stage = document.getElementById('stage') as HTMLElement;
      const canvas = document.getElementById('playfield') as HTMLCanvasElement;
      return {
        anchoVentana: window.innerWidth,
        anchoStage: stage.clientWidth,
        altoStage: stage.clientHeight,
        altoCanvas: canvas.height,
      };
    });

    expect(layout.anchoVentana).toBe(1600);
    expect(layout.anchoStage).toBeGreaterThan(0);
    expect(layout.altoStage).toBeGreaterThan(0);
    expect(layout.altoCanvas).toBeGreaterThanOrEqual(512);
    expect(sesion.errores).toEqual([]);
  });
});
