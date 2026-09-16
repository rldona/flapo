import fc from 'fast-check';
import { describe, it } from 'vitest';
import { Rng } from '../src/core/Rng';

/** Property-based tests del generador determinista. */

const finito = fc.double({ min: -1e6, max: 1e6, noNaN: true });

function ordenados(a: number, b: number): [number, number] {
  return a <= b ? [a, b] : [b, a];
}

describe('property · Rng', () => {
  it('la misma semilla reproduce la misma secuencia', () => {
    fc.assert(
      fc.property(fc.integer(), fc.integer({ min: 0, max: 64 }), (semilla, n) => {
        const a = new Rng(semilla);
        const b = new Rng(semilla);
        for (let i = 0; i < n; i++) {
          if (a.randf() !== b.randf()) return false;
        }
        return true;
      }),
      { numRuns: 200 },
    );
  });

  it('randf siempre cae en [0, 1)', () => {
    fc.assert(
      fc.property(fc.integer(), fc.integer({ min: 1, max: 128 }), (semilla, n) => {
        const rng = new Rng(semilla);
        for (let i = 0; i < n; i++) {
          const v = rng.randf();
          if (!(v >= 0 && v < 1)) return false;
        }
        return true;
      }),
    );
  });

  it('randfRange respeta [from, to) cuando from <= to', () => {
    fc.assert(
      fc.property(fc.integer(), finito, finito, (semilla, x, y) => {
        const [from, to] = ordenados(x, y);
        const v = new Rng(semilla).randfRange(from, to);
        return v >= from - 1e-9 && v <= to + 1e-9;
      }),
    );
  });

  it('randiRange es inclusivo, entero y degenera a from si to <= from', () => {
    fc.assert(
      fc.property(
        fc.integer(),
        fc.integer({ min: -5000, max: 5000 }),
        fc.integer({ min: -5000, max: 5000 }),
        (semilla, x, y) => {
          const [from, to] = ordenados(x, y);
          const v = new Rng(semilla).randiRange(from, to);
          if (!Number.isInteger(v)) return false;
          if (to <= from) return v === from;
          return v >= from && v <= to;
        },
      ),
    );
  });

  it('la semilla se normaliza a uint32', () => {
    fc.assert(
      fc.property(fc.integer(), (semilla) => {
        const v = new Rng(semilla).seed;
        return Number.isInteger(v) && v >= 0 && v <= 0xffffffff;
      }),
    );
  });
});
