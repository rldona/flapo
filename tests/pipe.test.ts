import { describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { Rng } from '../src/core/Rng';
import { GameState } from '../src/core/types';
import { Pipe } from '../src/systems/Pipe';
import { PipeSpawner } from '../src/systems/PipeSpawner';

/** Tubería individual. */
describe('Pipe', () => {
  it('setGapCenter fija centro y base', () => {
    const p = new Pipe();
    p.setGapCenter(200);
    expect(p.gapCenter).toBe(200);
    expect(p.baseGapCenter).toBe(200);
  });

  it('randomizeGap deja el hueco en la banda jugable', () => {
    const alto = C.playableHeight();
    for (let seed = 1; seed <= 50; seed++) {
      const p = new Pipe();
      p.randomizeGap(new Rng(seed));
      expect(p.gapCenter).toBeGreaterThanOrEqual(p.gapCenterMinRatio * alto - 1e-9);
      expect(p.gapCenter).toBeLessThanOrEqual(p.gapCenterMaxRatio * alto + 1e-9);
    }
  });

  it('update desplaza y marca gone al salir por la izquierda', () => {
    const p = new Pipe();
    p.scrollSpeed = 100;
    p.update(0.5);
    expect(p.x).toBeCloseTo(320 - 50, 6);

    p.x = -p.width / 2 - 0.1;
    p.update(0);
    expect(p.gone).toBe(true);
  });

  it('parada (moving=false) no se mueve', () => {
    const p = new Pipe();
    p.moving = false;
    const x = p.x;
    p.update(1);
    expect(p.x).toBe(x);
  });

  it('oscila alrededor de la base dentro de la amplitud', () => {
    const p = new Pipe();
    p.setGapCenter(220);
    p.oscillationAmplitude = 22;
    p.oscillationPeriod = 2.4;
    expect(p.isOscillating()).toBe(true);
    for (let i = 0; i < 240; i++) {
      p.update(1 / 60);
      expect(p.gapCenter).toBeGreaterThanOrEqual(220 - 22 - 1e-6);
      expect(p.gapCenter).toBeLessThanOrEqual(220 + 22 + 1e-6);
    }
  });

  it('la rotación avanza con el tiempo', () => {
    const p = new Pipe();
    p.spin = true;
    p.update(1);
    expect(p.spinTime).toBeCloseTo(1, 9);
    expect(p.spinAngle()).toBeCloseTo(C.SPIN_PIPE_TURNS_PER_SECOND * Math.PI * 2, 9);
  });

  it('los rects de colisión y puntuación son coherentes con el hueco', () => {
    const p = new Pipe();
    p.x = 100;
    p.width = 26;
    p.bodyLength = 512;
    p.gap = 100;
    p.setGapCenter(250);

    const top = p.topRect();
    const bottom = p.bottomRect();
    const score = p.scoreRect();
    expect(top.x).toBe(100 - 13);
    expect(top.y + top.h).toBeCloseTo(250 - 50, 9);
    expect(bottom.y).toBeCloseTo(250 + 50, 9);
    expect(score.x).toBe(100 - 13);
    expect(score.y).toBeCloseTo(200, 9);
    expect(score.h).toBe(100);
  });
});

function spawner(seed = 1234): { sp: PipeSpawner; eventos: Pipe[] } {
  const eventos: Pipe[] = [];
  const sp = new PipeSpawner({ onPipeSpawned: (p) => eventos.push(p) });
  sp.setRng(new Rng(seed));
  return { sp, eventos };
}

describe('PipeSpawner · estados y cadencia', () => {
  it('READY limpia y GAME_OVER congela', () => {
    const { sp } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    expect(sp.pipes.length).toBeGreaterThan(0);
    sp.onStateChanged(GameState.MENU);
    expect(sp.pipes).toHaveLength(0);
    expect(sp.specialLeft).toBe(0);

    sp.onStateChanged(GameState.PLAYING);
    sp.onStateChanged(GameState.GAME_OVER);
    expect(sp.pipes.every((p) => !p.moving)).toBe(true);
  });

  it('sin activar o sin rng no crea nada', () => {
    const sp = new PipeSpawner({ onPipeSpawned: () => {} });
    sp.setRng(new Rng(1));
    sp.update(10);
    expect(sp.pipes).toHaveLength(0);
  });

  it('crea una al pasar a PLAYING y luego respeta el intervalo', () => {
    const { sp, eventos } = spawner();
    sp.setDifficulty(100, 118, 160); // intervalo 1.6 s
    sp.onStateChanged(GameState.PLAYING);
    expect(eventos).toHaveLength(1);

    sp.update(1.6);
    expect(eventos).toHaveLength(2);
    sp.update(0.8);
    expect(eventos).toHaveLength(2);
    sp.update(0.8);
    expect(eventos).toHaveLength(3);
  });

  it('marca blanditas según el contador', () => {
    const { sp, eventos } = spawner();
    sp.movingChance = 0;
    sp.spinChance = 0;
    sp.onStateChanged(GameState.PLAYING);
    for (let i = 0; i < 7; i++) sp.update(2);
    expect(eventos.map((p) => p.soft)).toEqual(eventos.map((_, i) => C.isSoftPipe(i)));
  });

  it('lastPipe devuelve la más a la derecha', () => {
    const { sp } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    sp.update(2);
    expect(sp.pipes.length).toBeGreaterThanOrEqual(2);
    sp.pipes[0].x = 10;
    sp.pipes[1].x = 300;
    expect(sp.lastPipe()).toBe(sp.pipes[1]);
  });
});

describe('PipeSpawner · móviles, giratorias y tramo especial', () => {
  it('con chance 0 nunca salen móviles ni giratorias', () => {
    const { sp, eventos } = spawner();
    sp.movingChance = 0;
    sp.spinChance = 0;
    sp.onStateChanged(GameState.PLAYING);
    expect(eventos[0].isOscillating()).toBe(false);
    expect(eventos[0].spin).toBe(false);
  });

  it('con chance 1 salen móviles y giratorias', () => {
    const { sp, eventos } = spawner();
    sp.movingChance = 1;
    sp.spinChance = 1;
    sp.onStateChanged(GameState.PLAYING);
    expect(eventos[0].oscillationAmplitude).toBeGreaterThan(0);
    expect(eventos[0].spin).toBe(true);
  });

  it('el tramo especial viste y consume reservas', () => {
    const { sp, eventos } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    sp.specialLeft = C.SPECIAL_STRETCH_PIPES;
    sp.update(2);
    const especial = eventos[eventos.length - 1];
    expect(especial.special).toBe(true);
    expect(especial.spin).toBe(true);
    expect(especial.oscillationAmplitude).toBeGreaterThan(0);
    expect(sp.specialLeft).toBe(C.SPECIAL_STRETCH_PIPES - 1);
  });

  it('reserveNormal impide vestir la siguiente y no gasta la reserva', () => {
    const { sp, eventos } = spawner();
    sp.onStateChanged(GameState.PLAYING);
    sp.specialLeft = 2;
    sp.reserveNormal();
    sp.update(2);
    const normal = eventos[eventos.length - 1];
    expect(normal.special).toBe(false);
    expect(sp.specialLeft).toBe(2);
  });
});

describe('PipeSpawner · determinismo', () => {
  function firma(sp: PipeSpawner): string {
    return JSON.stringify(
      sp.pipes.map((p) => [
        Math.round(p.gapCenter * 1000),
        p.soft,
        p.spin,
        Math.round(p.oscillationAmplitude * 1000),
        Math.round(p.oscillationPhase * 1000),
      ]),
    );
  }

  it('la misma semilla da la misma secuencia', () => {
    const a = spawner(4242);
    const b = spawner(4242);
    for (const sp of [a.sp, b.sp]) {
      sp.movingChance = 0.5;
      sp.spinChance = 0.4;
      sp.onStateChanged(GameState.PLAYING);
      for (let i = 0; i < 12; i++) sp.update(2);
    }
    expect(firma(a.sp)).toBe(firma(b.sp));
  });
});
