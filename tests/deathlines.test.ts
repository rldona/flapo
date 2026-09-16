import { describe, expect, it } from 'vitest';
import { Rng } from '../src/core/Rng';
import { DeathCause } from '../src/core/types';
import { DeathLines } from '../src/systems/DeathLines';

const CAUSAS = [DeathCause.TUBERIA, DeathCause.SUELO, DeathCause.VACIO];

describe('DeathLines', () => {
  it('siempre devuelve una frase para cada causa y estado', () => {
    const lines = new DeathLines();
    let i = 0;
    for (const causa of CAUSAS) {
      for (const breathless of [false, true]) {
        const frase = lines.pickFor(causa, breathless, new Rng(++i));
        expect(typeof frase).toBe('string');
        expect(frase.length).toBeGreaterThan(0);
      }
    }
  });

  it('es determinista con la misma semilla', () => {
    const a = new DeathLines();
    const b = new DeathLines();
    for (let i = 1; i <= 20; i++) {
      expect(a.pickFor(DeathCause.SUELO, false, new Rng(i))).toBe(
        b.pickFor(DeathCause.SUELO, false, new Rng(i)),
      );
    }
  });

  it('no repite la misma frase dos veces seguidas', () => {
    const lines = new DeathLines();
    const rng = new Rng(99);
    let anterior = '';
    for (let i = 0; i < 60; i++) {
      const frase = lines.pickFor(DeathCause.TUBERIA, false, rng);
      expect(frase).not.toBe(anterior);
      anterior = frase;
    }
  });
});
