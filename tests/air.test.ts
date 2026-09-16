import { describe, expect, it } from 'vitest';
import * as A from '../src/config/AirConfig';
import * as C from '../src/config/GameConfig';
import { GameState } from '../src/core/types';
import { AirSpawner, Brother, Slipstream, Thermal } from '../src/systems/AirSpawner';
import type { PipeSpawner } from '../src/systems/PipeSpawner';

function pipeSpawnerFalso(over: Record<string, unknown> = {}): PipeSpawner {
  return {
    lastPipe: () => null,
    reserveNormal: () => true,
    spawnX: 320,
    ...over,
  } as unknown as PipeSpawner;
}

function air(score: number, ps: PipeSpawner = pipeSpawnerFalso()): AirSpawner {
  const a = new AirSpawner();
  a.setPipeSpawner(ps);
  a.setDifficulty(100, 160, score);
  return a;
}

describe('AirSpawner · elementos', () => {
  it('la térmica se mueve, avanza su fase y desaparece por la izquierda', () => {
    const t = new Thermal();
    t.scrollSpeed = 100;
    t.update(0.5);
    expect(t.x).toBeCloseTo(-50, 6);
    expect(t.phase).toBeCloseTo(0.5, 6);
    t.x = -t.w - 1;
    t.update(0);
    expect(t.gone).toBe(true);

    t.moving = false;
    const x = t.x;
    t.update(1);
    expect(t.x).toBe(x);
  });

  it('el rect de la térmica usa su tamaño', () => {
    const t = new Thermal();
    t.x = 100;
    t.y = 200;
    expect(t.rect()).toEqual({
      x: 100 - A.THERMAL_SIZE_W / 2,
      y: 200 - A.THERMAL_SIZE_H / 2,
      w: A.THERMAL_SIZE_W,
      h: A.THERMAL_SIZE_H,
    });
  });

  it('la estela caduca por tiempo o al salir, con alpha acotado', () => {
    const s = new Slipstream();
    s.scrollSpeed = 0;
    s.restante = A.SLIPSTREAM_TIME / 2;
    expect(s.alpha()).toBeCloseTo(0.25, 6);
    s.update(A.SLIPSTREAM_TIME);
    expect(s.gone).toBe(true);

    const s2 = new Slipstream();
    s2.scrollSpeed = 0;
    s2.x = -s2.ancho - 1;
    s2.update(0);
    expect(s2.gone).toBe(true);
    expect(new Slipstream().alpha()).toBeLessThanOrEqual(0.5);
  });

  it('el hermano vuela más rápido que el scroll normal y desaparece', () => {
    const b = new Brother();
    b.scrollSpeed = 100;
    b.update(1);
    expect(b.x).toBeCloseTo(-100 * A.BROTHER_SPEED_MULT, 6);
    b.x = -33;
    b.update(0);
    expect(b.gone).toBe(true);
  });
});

describe('AirSpawner · reglas de aparición', () => {
  it('READY vacía todo', () => {
    const a = air(A.BROTHER_MIN_SCORE);
    for (let i = 0; i < A.BROTHER_INTERVAL; i++) a.onPipeSpawned();
    expect(a.thermals.length + a.slips.length + a.brothers.length).toBeGreaterThan(0);
    a.onStateChanged(GameState.READY);
    expect(a.thermals).toHaveLength(0);
    expect(a.slips).toHaveLength(0);
    expect(a.brothers).toHaveLength(0);
  });

  it('con poco score no aparece nada', () => {
    const a = air(0);
    for (let i = 0; i < A.BROTHER_INTERVAL; i++) a.onPipeSpawned();
    expect(a.thermals).toHaveLength(0);
    expect(a.slips).toHaveLength(0);
    expect(a.brothers).toHaveLength(0);
  });

  it('el hermano (y su estela) aparece en su intervalo con score suficiente', () => {
    const a = air(A.BROTHER_MIN_SCORE);
    for (let i = 0; i < A.BROTHER_INTERVAL; i++) a.onPipeSpawned();
    expect(a.brothers).toHaveLength(1);
    expect(a.slips).toHaveLength(1);
    expect(a.brothers[0].x).toBe(C.VIEWPORT_WIDTH + 24);
    expect(a.slips[0].x).toBeCloseTo(C.VIEWPORT_WIDTH * 0.5, 6);
  });

  it('la térmica aparece en su intervalo si la última tubería es normal', () => {
    const a = air(A.THERMAL_MIN_SCORE);
    for (let i = 0; i < A.THERMAL_INTERVAL; i++) a.onPipeSpawned();
    expect(a.thermals).toHaveLength(1);
    expect(a.thermals[0].y).toBeCloseTo(C.playableHeight() * 0.5, 6);
  });

  it('no aparece térmica si la última tubería oscila o es especial', () => {
    const oscilando = pipeSpawnerFalso({ lastPipe: () => ({ oscillationAmplitude: 10 }) });
    const a = air(A.THERMAL_MIN_SCORE, oscilando);
    for (let i = 0; i < A.THERMAL_INTERVAL; i++) a.onPipeSpawned();
    expect(a.thermals).toHaveLength(0);
  });

  it('no aparece térmica si la tubería normal está reservada', () => {
    const reservado = pipeSpawnerFalso({ reserveNormal: () => false });
    const a = air(A.THERMAL_MIN_SCORE, reservado);
    for (let i = 0; i < A.THERMAL_INTERVAL; i++) a.onPipeSpawned();
    expect(a.thermals).toHaveLength(0);
  });
});

describe('AirSpawner · update y dificultad', () => {
  it('update descarta los elementos que salen de pantalla', () => {
    const a = air(0);
    const t = new Thermal();
    t.x = -t.w - 1;
    a.thermals.push(t);
    const s = new Slipstream();
    s.restante = 0;
    a.slips.push(s);
    const b = new Brother();
    b.x = -33;
    a.brothers.push(b);
    a.update(0);
    expect(a.thermals).toHaveLength(0);
    expect(a.slips).toHaveLength(0);
    expect(a.brothers).toHaveLength(0);
  });

  it('setDifficulty propaga la velocidad a los elementos vivos', () => {
    const a = air(0);
    const t = new Thermal();
    a.thermals.push(t);
    a.setDifficulty(200, 160, 5);
    expect(t.scrollSpeed).toBe(200);
  });
});
