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
    expect(j.alpha()).toBeCloseTo(j.flashAlpha, 9);
    expect(j.shakeX()).not.toBe(0);
  });

  it('completa el hit-stop justo cuando llega a 0', () => {
    const j = new Juice();
    const escalas: number[] = [];
    j.setTimeScale = (s) => escalas.push(s);
    j.punch();
    j.update(j.hitStopTime); // hitStopLeft = 0 exacto
    expect(escalas).toEqual([0, 0, 1]);
  });

  it('sin hitStopTime no fuerza timeScale', () => {
    const j = new Juice();
    const escalas: number[] = [];
    j.setTimeScale = (s) => escalas.push(s);
    j.hitStopTime = 0;
    j.punch();
    expect(escalas).toEqual([]);
  });

  it('durante el hit-stop no decae el flash y termina justo al agotarse', () => {
    const j = new Juice();
    const escalas: number[] = [];
    j.setTimeScale = (s) => escalas.push(s);
    j.punch();
    j.update(0.01);
    j.update(0.01);
    expect(escalas).toEqual([0, 0, 0]);
    expect(j.alpha()).toBeCloseTo(j.flashAlpha, 9);

    j.update(j.hitStopTime);
    expect(escalas.at(-1)).toBe(1);
  });

  it('sacudida y flash siguen sus fórmulas exactas', () => {
    const j = new Juice();
    j.punch();
    j.update(j.hitStopTime); // completa el hit-stop; todavía no decae nada

    const sl = j.shakeTime;
    const intensidad = j.shakeStrength * (sl / j.shakeTime);
    expect(j.shakeX()).toBeCloseTo(Math.sin(sl * j.shakeFrequency) * intensidad, 9);
    expect(j.shakeY()).toBeCloseTo(
      Math.cos(sl * j.shakeFrequency * 1.37) * intensidad * 0.6,
      9,
    );
    expect(j.alpha()).toBeCloseTo(j.flashAlpha, 9);

    j.update(0.1);
    const sl2 = j.shakeTime - 0.1;
    const i2 = j.shakeStrength * (sl2 / j.shakeTime);
    expect(j.shakeX()).toBeCloseTo(Math.sin(sl2 * j.shakeFrequency) * i2, 9);
    expect(j.shakeY()).toBeCloseTo(Math.cos(sl2 * j.shakeFrequency * 1.37) * i2 * 0.6, 9);
    expect(j.alpha()).toBeCloseTo(j.flashAlpha * ((j.flashTime - 0.1) / j.flashTime), 9);
  });

  it('cuando se agotan, sacudida y flash vuelven a cero', () => {
    const j = new Juice();
    j.punch();
    j.update(j.hitStopTime);
    j.update(j.shakeTime);
    expect(j.shakeX()).toBe(0);
    expect(j.shakeY()).toBe(0);
    j.update(j.flashTime);
    expect(j.alpha()).toBe(0);
  });

  it('reset restaura el timeScale', () => {
    const j = new Juice();
    const escalas: number[] = [];
    j.setTimeScale = (s) => escalas.push(s);
    j.punch();
    j.reset();
    expect(escalas).toContain(1);
  });

  it('READY y MENU resetean; PLAYING no', () => {
    const j = new Juice();
    j.punch();
    j.onStateChanged(GameState.PLAYING);
    expect(j.alpha()).toBeGreaterThan(0);
    j.onStateChanged(GameState.MENU);
    expect(j.alpha()).toBe(0);
    expect(j.shakeX()).toBe(0);

    j.punch();
    j.onStateChanged(GameState.READY);
    expect(j.alpha()).toBe(0);

    j.punch();
    j.reset();
    expect(j.alpha()).toBe(0);
  });
});
