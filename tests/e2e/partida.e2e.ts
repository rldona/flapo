import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import {
  aletear,
  capturar,
  crearEntorno,
  empezarPartida,
  ESTADO,
  esperarEstado,
  esperarFrames,
  estado,
  jugarAutopilotado,
  matar,
  nuevaPagina,
  pausado,
  puntuacion,
  record,
  type EntornoE2E,
  type SesionE2E,
} from './harness';

const CLAVE_GUARDADO = 'flapo.save.v1';

/**
 * E2E de partida: arranque, pausa, puntuación real cruzando tuberías, fin de
 * partida, reinicio y persistencia del récord.
 *
 * Cada caso parte de una página nueva (`beforeEach`) para no arrastrar el
 * estado de la partida anterior.
 */
describe('E2E · partida y persistencia', () => {
  let entorno: EntornoE2E;
  let sesion: SesionE2E;

  beforeAll(async () => {
    entorno = await crearEntorno();
  }, 90_000);

  afterAll(async () => {
    await entorno?.cerrar();
  });

  beforeEach(async () => {
    sesion = await nuevaPagina(entorno, { width: 412, height: 915, deviceScaleFactor: 2 });
  });

  afterEach(async (context) => {
    if (context.task.result?.state === 'fail' && sesion?.page) {
      await capturar(sesion.page, 'partida-fallo');
    }
    await sesion?.cerrar();
  });

  it('pasa a READY al pulsar Jugar y a PLAYING con el primer aleteo', async () => {
    await sesion.page.click('[data-act="play"]');
    await esperarEstado(sesion.page, ESTADO.READY);

    await esperarFrames(sesion.page, 2);
    await sesion.page.keyboard.press('Space');
    await esperarEstado(sesion.page, ESTADO.PLAYING);
  });

  it('se pausa y reanuda sin salir de PLAYING', async () => {
    await empezarPartida(sesion.page);

    // Un aleteo extra justo antes de pausar: al reanudar el pájaro va hacia
    // arriba y no se estrella de inmediato.
    await aletear(sesion.page, 60);
    await sesion.page.keyboard.press('KeyP');
    await sesion.page.waitForSelector('[aria-label="Pausa"]');
    expect(await pausado(sesion.page)).toBe(true);
    expect(await estado(sesion.page)).toBe(ESTADO.PLAYING);

    await sesion.page.click('[data-act="resume"]');
    // Se comprueba al instante: si esperásemos a que cayera el pájaro, moriría
    // por no aletear (no es un fallo de la pausa).
    expect(await pausado(sesion.page)).toBe(false);
    expect(await estado(sesion.page)).toBe(ESTADO.PLAYING);
    await sesion.page.waitForSelector('[aria-label="Pausa"]', { hidden: true });
  });

  it('cruza tuberías de verdad y suma puntos', async () => {
    await empezarPartida(sesion.page);

    const { puntuacionMaxima } = await jugarAutopilotado(sesion.page, { pasos: 200 });
    expect(puntuacionMaxima).toBeGreaterThan(0);
  });

  it('guarda el récord al morir y muestra el fin de partida', async () => {
    await empezarPartida(sesion.page);
    await jugarAutopilotado(sesion.page, { pasos: 120 });

    const marca = await puntuacion(sesion.page);
    expect(marca).toBeGreaterThan(0);

    if ((await estado(sesion.page)) !== ESTADO.GAME_OVER) await matar(sesion.page);
    await sesion.page.waitForSelector('[aria-label="Fin de la partida"]', { timeout: 15_000 });

    expect(await record(sesion.page)).toBeGreaterThanOrEqual(marca);
    const guardado = await sesion.page.evaluate((clave) => {
      const raw = localStorage.getItem(clave);
      return raw ? (JSON.parse(raw) as { high_score?: number }) : null;
    }, CLAVE_GUARDADO);
    expect(guardado?.high_score ?? 0).toBeGreaterThanOrEqual(marca);
  });

  it('reinicia con "Otra vez" y vuelve a READY', async () => {
    await empezarPartida(sesion.page);
    await matar(sesion.page);
    await sesion.page.waitForSelector('[aria-label="Fin de la partida"]', { timeout: 15_000 });

    await sesion.page.click('[data-act="restart"]');
    await esperarEstado(sesion.page, ESTADO.READY);
  });

  it('restaura el récord guardado al abrir de nuevo', async () => {
    const segunda = await nuevaPagina(entorno, {
      width: 412,
      height: 915,
      deviceScaleFactor: 2,
      almacen: {
        [CLAVE_GUARDADO]: JSON.stringify({
          high_score: 999,
          games_played: 7,
          total_score: 1234,
          difficulty: 1,
        }),
      },
    });
    try {
      expect(await record(segunda.page)).toBe(999);
      expect(await estado(segunda.page)).toBe(ESTADO.MENU);
    } finally {
      await segunda.cerrar();
    }
  });
});
