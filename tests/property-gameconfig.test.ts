import fc from 'fast-check';
import { describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';

/**
 * Property-based tests de `GameConfig`: en vez de ejemplos sueltos, fijan
 * invariantes que deben cumplirse para *cualquier* entrada razonable (rangos,
 * monotonía, idempotencia y round-trips).
 */

const finito = fc.double({ min: -1e6, max: 1e6, noNaN: true });
const positivo = fc.double({ min: 1, max: 1e5, noNaN: true });

function ordenados(a: number, b: number): [number, number] {
  return a <= b ? [a, b] : [b, a];
}

describe('property · GameConfig · rangos y cotas', () => {
  it('posmod siempre cae en [0, b)', () => {
    fc.assert(
      fc.property(finito, fc.integer({ min: 1, max: 10000 }), (a, b) => {
        const r = C.posmod(a, b);
        return r >= 0 && r < b;
      }),
    );
  });

  it('clamp nunca se sale de [lo, hi]', () => {
    fc.assert(
      fc.property(finito, finito, finito, (v, x, y) => {
        const [lo, hi] = ordenados(x, y);
        const r = C.clamp(v, lo, hi);
        return r >= lo - 1e-9 && r <= hi + 1e-9;
      }),
    );
  });

  it('difficulty vive en [0, 1]', () => {
    fc.assert(
      fc.property(finito, (score) => {
        const d = C.difficulty(score);
        return d >= 0 && d <= 1;
      }),
    );
  });

  it('sceneryFor y journeyStage caen en sus enums', () => {
    fc.assert(
      fc.property(fc.integer(), finito, (semilla, score) => {
        const s = C.sceneryFor(semilla);
        const j = C.journeyStage(score);
        return (
          Number.isInteger(s) &&
          s >= 0 &&
          s <= 3 &&
          Number.isInteger(j) &&
          j >= 0 &&
          j <= 3
        );
      }),
    );
  });

  it('windowScaleFor está acotado a [MIN_WINDOW_SCALE, MAX_WINDOW_SCALE]', () => {
    fc.assert(
      fc.property(positivo, positivo, fc.boolean(), (w, h, fractional) => {
        const s = C.windowScaleFor(w, h, fractional);
        return s >= C.MIN_WINDOW_SCALE && s <= C.MAX_WINDOW_SCALE;
      }),
    );
  });

  it('movingPipeAmplitude cae en [0, MOVING_PIPE_AMPLITUDE]', () => {
    fc.assert(
      fc.property(positivo, finito, (gap, centro) => {
        const a = C.movingPipeAmplitude(gap, centro);
        return a >= 0 && a <= C.MOVING_PIPE_AMPLITUDE;
      }),
    );
  });

  it('pantTintWeight y groundFillHeight nunca son negativos', () => {
    fc.assert(
      fc.property(finito, finito, (aliento, maximo) => {
        const w = C.pantTintWeight(aliento, maximo);
        return w >= 0 && w <= C.PANT_TINT_MAX + 1e-9;
      }),
    );
    fc.assert(
      fc.property(finito, finito, (alto, sup) => C.groundFillHeight(alto, sup) >= 0),
    );
  });

  it('maxBreathFor y confidenceLevel respetan sus topes', () => {
    fc.assert(
      fc.property(finito, (nivel) => {
        const b = C.maxBreathFor(nivel);
        return (
          b >= C.MAX_BREATH &&
          b <= C.MAX_BREATH + C.CONFIDENCE_MAX_LEVEL * C.CONFIDENCE_BREATH_BONUS
        );
      }),
    );
    fc.assert(
      fc.property(finito, (partidas) => {
        const c = C.confidenceLevel(partidas);
        return c >= 0 && c <= C.CONFIDENCE_MAX_LEVEL && Number.isInteger(c);
      }),
    );
  });
});

describe('property · GameConfig · monotonía', () => {
  it('medalFor no retrocede al subir la puntuación', () => {
    fc.assert(
      fc.property(finito, fc.double({ min: 0, max: 1e4, noNaN: true }), (a, delta) => {
        return C.medalFor(a) <= C.medalFor(a + delta);
      }),
    );
  });

  it('movingPipeChance y spinPipeChance crecen y respetan sus topes', () => {
    fc.assert(
      fc.property(finito, fc.double({ min: 0, max: 1e6, noNaN: true }), (score, delta) => {
        const c1 = C.movingPipeChance(score);
        const c2 = C.movingPipeChance(score + delta);
        const dentro =
          c1 >= -1e-9 &&
          c1 <= C.MOVING_PIPE_CHANCE_MAX + 1e-9 &&
          c2 >= -1e-9 &&
          c2 <= C.MOVING_PIPE_CHANCE_MAX + 1e-9;
        return dentro && c2 >= c1 - 1e-9;
      }),
    );
    fc.assert(
      fc.property(finito, (score) => {
        const c = C.spinPipeChance(score);
        return c >= -1e-9 && c <= C.SPIN_PIPE_CHANCE_MAX + 1e-9;
      }),
    );
  });
});

describe('property · GameConfig · texto y códigos', () => {
  it('sanitizePlayerName recorta, limpia y es idempotente', () => {
    fc.assert(
      fc.property(fc.string(), (texto) => {
        const limpio = C.sanitizePlayerName(texto);
        expect(limpio.length).toBeLessThanOrEqual(C.PLAYER_NAME_MAX_LEN);
        expect(limpio).toBe(limpio.trim());
        expect(limpio.includes('  ')).toBe(false);
        expect(/[\u0000-\u001f\u007f]/.test(limpio)).toBe(false);
        expect(C.sanitizePlayerName(limpio)).toBe(limpio);
      }),
      { numRuns: 300 },
    );
  });

  it('seedACodigo y codigoASeed hacen round-trip', () => {
    fc.assert(
      fc.property(fc.integer({ min: 0, max: C.codigoModulo() - 1 }), (semilla) => {
        const codigo = C.seedACodigo(semilla);
        expect(codigo).toHaveLength(C.CODIGO_LARGO);
        expect(C.codigoASeed(codigo)).toBe(semilla);
        expect(C.codigoASeed(` ${codigo.toUpperCase()} `)).toBe(semilla);
      }),
      { numRuns: 300 },
    );
  });

  it('isSoftPipe marca exactamente los múltiplos positivos del intervalo', () => {
    fc.assert(
      fc.property(fc.integer({ min: -5000, max: 5000 }), (indice) => {
        const esperado = indice > 0 && indice % C.SOFT_PIPE_INTERVAL === 0;
        return C.isSoftPipe(indice) === esperado;
      }),
    );
  });
});
