import { afterAll, beforeAll, describe, it } from 'vitest';
import {
  capturarEscena,
  compararGolden,
  crearEntorno,
  nuevaPagina,
  type EntornoE2E,
  type PlanEscena,
} from './harness';

/**
 * Regresión visual del canvas.
 *
 * Cada escena se construye de forma determinista —bucle congelado, semilla fija
 * y `Math.random` sembrado— y se compara contra su baseline en
 * `tests/e2e/__screenshots__`. Se captura el canvas lógico (288px de ancho), así
 * que no depende del DPR ni de la escala CSS.
 *
 * Para regenerar los baselines tras un cambio intencionado de dibujo:
 *
 * ```bash
 * UPDATE_SNAPSHOTS=1 npm run test:e2e
 * ```
 *
 * Los baselines se generan en la misma plataforma que los ejecuta: si CI corre
 * en Linux, conviene regenerarlos allí (o ajustar `VISUAL_MAX_DIFF`) cuando
 * cambien de versión de Chrome.
 */
describe('E2E · regresión visual', () => {
  let entorno: EntornoE2E;

  beforeAll(async () => {
    entorno = await crearEntorno();
  }, 90_000);

  afterAll(async () => {
    await entorno?.cerrar();
  });

  async function escena(nombre: string, plan: PlanEscena): Promise<void> {
    const sesion = await nuevaPagina(entorno, {
      width: 390,
      height: 844,
      deviceScaleFactor: 1,
      congelado: true,
    });
    try {
      const png = await capturarEscena(sesion.page, plan);
      await compararGolden(nombre, png);
    } finally {
      await sesion.cerrar();
    }
  }

  it('menú principal', async () => {
    await escena('menu', { menu: true });
  });

  it('READY en los cuatro escenarios', async () => {
    await escena('ready-dia', { seed: 4 });
    await escena('ready-atardecer', { seed: 5 });
    await escena('ready-noche', { seed: 6 });
    await escena('ready-lluvia', { seed: 7 });
  });

  it('jugando con tuberías', async () => {
    await escena('playing-dia', {
      seed: 4,
      jugar: true,
      inmune: true,
      pasos: 150,
      altura: 230,
      rotacion: 0,
    });
  });

  it('game over con el pájaro apoyado en el suelo', async () => {
    await escena('gameover-dia', { seed: 4, morir: true, pasos: 60, rotacion: 0 });
  });
});
