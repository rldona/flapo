import { describe, expect, it } from 'vitest';
import { Rng } from '../src/core/Rng';
import { DeathCause } from '../src/core/types';
import { DeathLines } from '../src/systems/DeathLines';

/**
 * Cada causa tiene su repertorio de frases. La genérica (`LINES`) queda como
 * respaldo inalcanzable, así que no se prueba.
 */
const PIPE = [
  'Esa tubería salió de la nada.',
  'De morros contra el tubo.',
  'Un poco más arriba y pasa.',
  'La tubería no se ha movido, eh.',
  'Ahí había hueco, de verdad.',
];
const GROUND = [
  'Aterrizaje mejorable.',
  'El suelo sigue ahí, sí.',
  'Se te ha ido hacia abajo.',
  'Un aleteo más y no pasa.',
  'La gravedad no perdona.',
];
const VOID = [
  'Se ha ido por abajo del todo.',
  'Ahí abajo no hay nada, Flapo.',
  'Eso ha sido un picado con ganas.',
];
const BREATHLESS = [
  'Se quedó sin fuelle.',
  'Ya no le quedaba aire.',
  'Aletear cansa, resulta.',
  'Flapo pedía un descanso.',
];

const REPERTORIO: Array<[DeathCause, string[]]> = [
  [DeathCause.TUBERIA, PIPE],
  [DeathCause.SUELO, GROUND],
  [DeathCause.VACIO, VOID],
];

describe('DeathLines', () => {
  it('cada causa usa su repertorio', () => {
    const lines = new DeathLines();
    const rng = new Rng(1234);
    for (const [causa, pool] of REPERTORIO) {
      for (let i = 0; i < 400; i++) {
        expect(pool).toContain(lines.pickFor(causa, false, rng));
      }
    }
  });

  it('el jadeo manda sobre la causa', () => {
    const lines = new DeathLines();
    const rng = new Rng(7);
    for (let i = 0; i < 400; i++) {
      expect(BREATHLESS).toContain(lines.pickFor(DeathCause.SUELO, true, rng));
    }
  });

  it('es determinista con la misma semilla', () => {
    const a = new DeathLines();
    const b = new DeathLines();
    for (let i = 1; i <= 30; i++) {
      expect(a.pickFor(DeathCause.SUELO, false, new Rng(i))).toBe(
        b.pickFor(DeathCause.SUELO, false, new Rng(i)),
      );
    }
  });

  it('no repite la misma frase dos veces seguidas', () => {
    const lines = new DeathLines();
    const rng = new Rng(99);
    let anterior = '';
    for (let i = 0; i < 80; i++) {
      const frase = lines.pickFor(DeathCause.TUBERIA, false, rng);
      expect(frase).not.toBe(anterior);
      anterior = frase;
    }
  });
});
