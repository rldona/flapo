import { describe, expect, it } from 'vitest';
import { GameState } from '../src/core/types';
import { Juice } from '../src/systems/Juice';

describe('Juice', () => {
  it('punch arranca flash, sacudida y hit-stop (timeScale 0)', () => {
    const j = new Juice();
    const escalas: number[] = [];
    j.setTimeScale = (s) => escalas.push(s);
    j.punch();
    expect(escalas).toEqual([0]);
    expect(j.alpha()).toBeGreaterThan(0);
  });

  it('update termina el hit-stop devolviendo timeScale y apaga el flash', () => {
    const j = new Juice();
    const escalas: number[] = [];
    j.setTimeScale = (s) => escalas.push(s);
    j.punch();
    j.update(j.hitStopTime + 0.01);
    expect(escalas.at(-1)).toBe(1);
    j.update(j.flashTime);
    expect(j.alpha()).toBe(0);
  });

  it('sin punch no hay flash ni sacudida', () => {
    const j = new Juice();
    expect(j.alpha()).toBe(0);
    expect(j.shakeX()).toBe(0);
    expect(j.shakeY()).toBe(0);
  });

  it('la sacudida está acotada por su fuerza', () => {
    const j = new Juice();
    j.punch();
    j.update(j.hitStopTime + 0.001); // consume el hit-stop
    expect(Math.abs(j.shakeX())).toBeLessThanOrEqual(j.shakeStrength + 1e-9);
    expect(Math.abs(j.shakeY())).toBeLessThanOrEqual(j.shakeStrength * 0.6 + 1e-9);
  });

  it('READY/MENU resetean y reset limpia', () => {
    const j = new Juice();
    j.punch();
    j.onStateChanged(GameState.READY);
    expect(j.alpha()).toBe(0);
    expect(j.shakeX()).toBe(0);

    j.punch();
    j.reset();
    expect(j.alpha()).toBe(0);
  });
});
