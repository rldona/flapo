import { describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import type { Rng } from '../src/core/Rng';
import { GameState } from '../src/core/types';
import type { Pipe } from '../src/systems/Pipe';
import { PipeSpawner } from '../src/systems/PipeSpawner';

/** `Rng` falso: `randf` fijo y `randfRange` devolviendo el mínimo o el máximo. */
class RngFalso {
  constructor(
    private readonly valor: number,
    private readonly usarMax = false,
  ) {}
  randf(): number {
    return this.valor;
  }
  randfRange(a: number, b: number): number {
    return this.usarMax ? b : a;
  }
}

function spawner(valor = 0.5, usarMax = false): { sp: PipeSpawner; eventos: Pipe[] } {
  const eventos: Pipe[] = [];
  const sp = new PipeSpawner({ onPipeSpawned: (p) => eventos.push(p) });
  sp.setRng(new RngFalso(valor, usarMax) as unknown as Rng);
  return { sp, eventos };
}

describe('PipeSpawner · pausa y reservas', () => {
  it('isPaused refleja setPaused', () => {
    const { sp } = spawner();
    expect(sp.isPaused()).toBe(false);
    sp.setPaused(true);
    expect(sp.isPaused()).toBe(true);
    sp.setPaused(false);
    expect(sp.isPaused()).toBe(false);
  });

  it('setPaused(false) reactiva el spawner', () => {
    const { sp, eventos } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    const antes = eventos.length;
    sp.setPaused(true);
    sp.setPaused(false);
    sp.update(2);
    expect(eventos.length).toBe(antes + 1);
  });

  it('reserveNormal devuelve true', () => {
    const { sp } = spawner();
    expect(sp.reserveNormal()).toBe(true);
  });
});

describe('PipeSpawner · estado y lastPipe', () => {
  it('GAME_OVER pausa y congela sin vaciar', () => {
    const { sp } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    const cuantas = sp.pipes.length;
    sp.onStateChanged(GameState.GAME_OVER);
    expect(sp.isPaused()).toBe(true);
    expect(sp.pipes).toHaveLength(cuantas);
    expect(sp.pipes.every((p) => !p.moving)).toBe(true);
  });

  it('lastPipe devuelve la de mayor x aunque no sea la última', () => {
    const { sp } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    sp.update(2);
    sp.pipes[0].x = 300;
    sp.pipes[1].x = 10;
    expect(sp.lastPipe()).toBe(sp.pipes[0]);
  });

  it('con x empatadas, lastPipe se queda con la primera', () => {
    const { sp } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    sp.update(2);
    sp.pipes[0].x = 100;
    sp.pipes[1].x = 100;
    expect(sp.lastPipe()).toBe(sp.pipes[0]);
  });
});

describe('PipeSpawner · tramo especial', () => {
  it('sin reserva pendiente, el tramo especial viste aunque specialLeft sea 0', () => {
    const { sp, eventos } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    expect(eventos[0].special).toBe(false);
    expect(sp.reserveNormal()).toBe(true); // reserva consumida por la normal
  });

  it('reservar la normal impide vestir y no gasta la reserva', () => {
    const { sp, eventos } = spawner();
    sp.specialLeft = 2;
    sp.reserveNormal();
    sp.onStateChanged(GameState.PLAYING);
    expect(eventos[0].special).toBe(false);
    expect(sp.specialLeft).toBe(2);
  });
});

describe('PipeSpawner · chances con dado controlado', () => {
  it('si el dado supera la probabilidad, no salen móviles ni giratorias', () => {
    const { sp, eventos } = spawner(0.9);
    sp.movingChance = 0.5;
    sp.spinChance = 0.5;
    sp.onStateChanged(GameState.PLAYING);
    expect(eventos[0].isOscillating()).toBe(false);
    expect(eventos[0].spin).toBe(false);
  });

  it('justo en el umbral (dado == chance) tampoco salen', () => {
    const { sp, eventos } = spawner(0.9);
    sp.movingChance = 0.9;
    sp.spinChance = 0.9;
    sp.onStateChanged(GameState.PLAYING);
    expect(eventos[0].isOscillating()).toBe(false);
    expect(eventos[0].spin).toBe(false);
  });

  it('la fase de oscilación usa 0..2π', () => {
    const { sp, eventos } = spawner(0.1, true);
    sp.movingChance = 1;
    sp.onStateChanged(GameState.PLAYING);
    expect((eventos[0] as unknown as { oscillationPhase: number }).oscillationPhase).toBeCloseTo(
      Math.PI * 2,
      9,
    );
  });
});

describe('PipeSpawner · inicialización', () => {
  it('no está activo hasta onStateChanged(PLAYING)', () => {
    const { sp, eventos } = spawner();
    sp.update(10);
    expect(eventos).toHaveLength(0);
  });

  it('con specialLeft alto, la primera tubería es especial', () => {
    const { sp, eventos } = spawner();
    sp.specialLeft = C.SPECIAL_STRETCH_PIPES;
    sp.onStateChanged(GameState.PLAYING);
    expect(eventos[0].special).toBe(true);
    expect(sp.specialLeft).toBe(C.SPECIAL_STRETCH_PIPES - 1);
  });
});
