import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';
import {
  crearEntorno,
  empezarPartida,
  ESTADO,
  esperarEstado,
  matar,
  nuevaPagina,
  type EntornoE2E,
  type OpcionesPagina,
  type SesionE2E,
} from './harness';

/**
 * Accesibilidad y teclado sobre el DOM real de `UI.ts`.
 *
 * - **axe-core** inyectado en la página: sin violaciones WCAG 2 A/AA en cada
 *   panel (menú, opciones, estadísticas, pausa y fin de partida).
 * - **Teclado**: el foco entra en el panel, Tab recorre los controles, Enter
 *   activa el botón enfocado y P pausa/reanuda.
 */

const require = createRequire(import.meta.url);
const AXE_SOURCE = readFileSync(require.resolve('axe-core/axe.min.js'), 'utf8');

interface NodoAxe {
  html: string;
  target: string[];
  failureSummary?: string;
}

interface Violacion {
  id: string;
  impact: string | null;
  help: string;
  nodes: NodoAxe[];
}

function resumen(violaciones: Violacion[]): string {
  return violaciones
    .map(
      (v) =>
        `- ${v.id} [${v.impact}] ${v.help}\n    ${v.nodes
          .map((n) => n.target.join(' '))
          .join(' | ')}\n    ${v.nodes[0]?.failureSummary ?? ''}`,
    )
    .join('\n');
}

async function analizar(sesion: SesionE2E, selector?: string): Promise<Violacion[]> {
  await sesion.page.addScriptTag({ content: AXE_SOURCE });
  return sesion.page.evaluate(async (sel?: string) => {
    const axe = (
      window as unknown as {
        axe: { run(ctx: unknown, opts: unknown): Promise<{ violations: Violacion[] }> };
      }
    ).axe;
    const ctx = sel ? (document.querySelector(sel) ?? document) : document;
    const resultado = await axe.run(ctx, {
      runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] },
    });
    return resultado.violations;
  }, selector);
}

/** Espera a que el panel termine su animación de entrada antes de medir colores. */
async function esperarPanel(sesion: SesionE2E, selector: string): Promise<void> {
  await sesion.page.waitForSelector(selector);
  await new Promise((r) => setTimeout(r, 300));
}

describe('E2E · accesibilidad y teclado', () => {
  let entorno: EntornoE2E;
  const abiertas: SesionE2E[] = [];

  beforeAll(async () => {
    entorno = await crearEntorno();
  }, 90_000);

  afterEach(async () => {
    while (abiertas.length > 0) await abiertas.pop()?.cerrar();
  });

  afterAll(async () => {
    await entorno?.cerrar();
  });

  async function pagina(opciones: OpcionesPagina = {}): Promise<SesionE2E> {
    const sesion = await nuevaPagina(entorno, opciones);
    abiertas.push(sesion);
    return sesion;
  }

  it('el menú principal no tiene violaciones WCAG A/AA', async () => {
    const sesion = await pagina();
    const violaciones = await analizar(sesion);
    expect(violaciones, resumen(violaciones)).toEqual([]);
  });

  it('el panel de Opciones no tiene violaciones', async () => {
    const sesion = await pagina();
    await sesion.page.click('[data-act="options"]');
    await esperarPanel(sesion, '[role="dialog"][aria-label="Opciones"]');
    const violaciones = await analizar(sesion, '[role="dialog"][aria-label="Opciones"]');
    expect(violaciones, resumen(violaciones)).toEqual([]);
  });

  it('el panel de Estadísticas no tiene violaciones', async () => {
    const sesion = await pagina();
    await sesion.page.click('[data-act="stats"]');
    await esperarPanel(sesion, '[role="dialog"][aria-label="Estadísticas"]');
    const violaciones = await analizar(sesion, '[role="dialog"][aria-label="Estadísticas"]');
    expect(violaciones, resumen(violaciones)).toEqual([]);
  });

  it('el panel de Pausa no tiene violaciones', async () => {
    const sesion = await pagina();
    await empezarPartida(sesion.page);
    await sesion.page.keyboard.press('KeyP');
    await esperarPanel(sesion, '[role="dialog"][aria-label="Pausa"]');
    const violaciones = await analizar(sesion, '[role="dialog"][aria-label="Pausa"]');
    expect(violaciones, resumen(violaciones)).toEqual([]);
  });

  it('el fin de partida no tiene violaciones', async () => {
    const sesion = await pagina();
    await empezarPartida(sesion.page);
    await matar(sesion.page);
    await esperarPanel(sesion, '[role="dialog"][aria-label="Fin de la partida"]');
    const violaciones = await analizar(sesion, '[role="dialog"][aria-label="Fin de la partida"]');
    expect(violaciones, resumen(violaciones)).toEqual([]);
  });

  it('al abrir el menú el foco entra en el panel', async () => {
    const sesion = await pagina();
    const foco = await sesion.page.evaluate(() => {
      const el = document.activeElement as HTMLElement | null;
      return {
        tag: el?.tagName ?? '',
        act: el?.getAttribute('data-act') ?? '',
        dentroDelPanel: Boolean(el?.closest('[role="dialog"]')),
      };
    });
    expect(foco.tag).toBe('BUTTON');
    expect(foco.act).toBe('play');
    expect(foco.dentroDelPanel).toBe(true);
  });

  it('Tab recorre los controles del menú', async () => {
    const sesion = await pagina();
    const activo = (): Promise<string> =>
      sesion.page.evaluate(() => {
        const el = document.activeElement as HTMLElement | null;
        return el?.getAttribute('data-act') ?? el?.id ?? el?.tagName ?? '';
      });

    expect(await activo()).toBe('play');
    await sesion.page.keyboard.press('Tab');
    expect(await activo()).toBe('daily');
    await sesion.page.keyboard.press('Tab');
    expect(await activo()).toBe('code-input');
    await sesion.page.keyboard.press('Tab');
    expect(await activo()).toBe('code');
    await sesion.page.keyboard.press('Tab');
    expect(await activo()).toBe('options');
  });

  it('Enter activa el botón enfocado y arranca la partida', async () => {
    const sesion = await pagina();
    await sesion.page.keyboard.press('Enter');
    await esperarEstado(sesion.page, ESTADO.READY);
  });

  it('P pausa y reanuda la partida', async () => {
    const sesion = await pagina();
    await empezarPartida(sesion.page);

    await sesion.page.keyboard.press('KeyP');
    await esperarPanel(sesion, '[role="dialog"][aria-label="Pausa"]');
    expect(await sesion.page.$('[role="dialog"][aria-label="Pausa"]')).not.toBeNull();

    await sesion.page.keyboard.press('KeyP');
    await sesion.page.waitForSelector('[role="dialog"][aria-label="Pausa"]', { hidden: true });
  });
});
