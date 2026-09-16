import { describe, expect, it } from 'vitest';
import * as A from '../src/config/AirConfig';
import * as C from '../src/config/GameConfig';
import { GameState } from '../src/core/types';
import { AirSpawner, Brother, Slipstream, Thermal } from '../src/systems/AirSpawner';
import type { PipeSpawner } from '../src/systems/PipeSpawner';

function ps(opciones: { last?: unknown; spawnX?: number; reservar?: boolean } = {}): PipeSpawner {
  return {
    lastPipe: () => opciones.last ?? null,
    reserveNormal: () => opciones.reservar ?? true,
    spawnX: opciones.spawnX ?? 320,
  } as unknown as PipeSpawner;
}

function air(score: number, spawner: PipeSpawner): AirSpawner {
  const a = new AirSpawner();
  a.setPipeSpawner(spawner);
  a.setDifficulty(100, 160, score);
  return a;
}

describe('AirSpawner · elementos, valores por defecto y bordes', () => {
  it('los elementos nacen vivos y no idos', () => {
    for (const e of [new Thermal(), new Slipstream(), new Brother()]) {
      expect(e.gone).toBe(false);
      expect(e.moving).toBe(true);
      expect(e.x).toBe(0);
    }
    expect(new Thermal().inside).toBe(false);
    expect(new Slipstream().inside).toBe(false);
  });

  it('el rect de la estela usa su ancho y alto', () => {
    const s = new Slipstream();
    s.x = 100;
    s.y = 200;
    expect(s.rect()).toEqual({
      x: 100 - s.ancho / 2,
      y: 200 - A.SLIPSTREAM_HEIGHT / 2,
      w: s.ancho,
      h: A.SLIPSTREAM_HEIGHT,
    });
  });

  it('la térmica no se marca ida justo en el borde', () => {
    const t = new Thermal();
    t.scrollSpeed = 0;
    t.x = -t.w;
    t.update(0);
    expect(t.gone).toBe(false);
    t.x = -t.w - 1e-6;
    t.update(0);
    expect(t.gone).toBe(true);

    const t2 = new Thermal();
    t2.scrollSpeed = 0;
    t2.x = 0;
    t2.update(0);
    expect(t2.gone).toBe(false);
  });

  it('la estela se mueve, no caduca en el borde y respeta moving=false', () => {
    const s = new Slipstream();
    s.scrollSpeed = 100;
    s.update(0.5);
    expect(s.x).toBeCloseTo(-50, 6);
    expect(s.restante).toBeCloseTo(A.SLIPSTREAM_TIME - 0.5, 6);

    const borde = new Slipstream();
    borde.scrollSpeed = 0;
    borde.restante = A.SLIPSTREAM_TIME;
    borde.x = -borde.ancho;
    borde.update(0);
    expect(borde.gone).toBe(false);
    borde.x = -borde.ancho - 1e-6;
    borde.update(0);
    expect(borde.gone).toBe(true);

    const parada = new Slipstream();
    parada.moving = false;
    const x = parada.x;
    parada.update(1);
    expect(parada.x).toBe(x);
    expect(parada.restante).toBe(A.SLIPSTREAM_TIME);
  });

  it('el hermano vuela con su multiplicador y no caduca en el borde', () => {
    const b = new Brother();
    b.scrollSpeed = 100;
    b.update(0.5);
    expect(b.x).toBeCloseTo(-100 * A.BROTHER_SPEED_MULT * 0.5, 6);

    const borde = new Brother();
    borde.scrollSpeed = 0;
    borde.x = -32;
    borde.update(0);
    expect(borde.gone).toBe(false);
    borde.x = -32 - 1e-6;
    borde.update(0);
    expect(borde.gone).toBe(true);

    const parado = new Brother();
    parado.moving = false;
    parado.update(1);
    expect(parado.x).toBe(0);
  });
});

describe('AirSpawner · altura libre del hermano', () => {
  it('sin tubería previa nada al borde', () => {
    const a = air(A.BROTHER_MIN_SCORE, ps());
    for (let i = 0; i < A.BROTHER_INTERVAL; i++) a.onPipeSpawned();
    expect(a.brothers[0].y).toBe(A.BROTHER_EDGE_MARGIN);
  });

  it('si la última tubería está abajo, se va arriba', () => {
    const a = air(A.BROTHER_MIN_SCORE, ps({ last: { oscillationAmplitude: 0, special: false, gapCenter: 50 } }));
    for (let i = 0; i < A.BROTHER_INTERVAL; i++) a.onPipeSpawned();
    expect(a.brothers[0].y).toBe(C.playableHeight() - A.BROTHER_EDGE_MARGIN);
  });

  it('si la última está arriba, se va abajo', () => {
    const a = air(A.BROTHER_MIN_SCORE, ps({ last: { oscillationAmplitude: 0, special: false, gapCenter: 400 } }));
    for (let i = 0; i < A.BROTHER_INTERVAL; i++) a.onPipeSpawned();
    expect(a.brothers[0].y).toBe(A.BROTHER_EDGE_MARGIN);
  });

  it('justo en la mitad elige el borde', () => {
    const a = air(
      A.BROTHER_MIN_SCORE,
      ps({ last: { oscillationAmplitude: 0, special: false, gapCenter: C.playableHeight() / 2 } }),
    );
    for (let i = 0; i < A.BROTHER_INTERVAL; i++) a.onPipeSpawned();
    expect(a.brothers[0].y).toBe(A.BROTHER_EDGE_MARGIN);
  });
});

describe('AirSpawner · térmicas y limpieza', () => {
  it('una tubería normal previa no bloquea la térmica', () => {
    const a = air(
      A.THERMAL_MIN_SCORE,
      ps({ last: { oscillationAmplitude: 0, special: false } }),
    );
    for (let i = 0; i < A.THERMAL_INTERVAL; i++) a.onPipeSpawned();
    expect(a.thermals).toHaveLength(1);
  });

  it('la térmica nace a media separación del spawn', () => {
    const a = air(A.THERMAL_MIN_SCORE, ps({ spawnX: 999 }));
    for (let i = 0; i < A.THERMAL_INTERVAL; i++) a.onPipeSpawned();
    expect(a.thermals[0].x).toBeCloseTo(999 + 160 * 0.5, 6);
  });

  it('PLAYING mantiene los elementos; MENU los vacía; GAME_OVER los congela', () => {
    const a = air(A.BROTHER_MIN_SCORE, ps());
    for (let i = 0; i < A.BROTHER_INTERVAL; i++) a.onPipeSpawned();
    const termica = new Thermal();
    const estela = new Slipstream();
    a.thermals.push(termica);
    a.slips.push(estela);
    const cuantos = a.brothers.length + a.slips.length;

    a.onStateChanged(GameState.PLAYING);
    expect(a.brothers.length + a.slips.length).toBe(cuantos);
    expect(a.brothers.every((b) => b.moving)).toBe(true);

    a.onStateChanged(GameState.GAME_OVER);
    expect(a.brothers.every((b) => !b.moving)).toBe(true);
    expect(termica.moving).toBe(false);
    expect(estela.moving).toBe(false);

    a.onStateChanged(GameState.MENU);
    expect(a.thermals).toHaveLength(0);
    expect(a.slips).toHaveLength(0);
    expect(a.brothers).toHaveLength(0);
  });

  it('update descarta lo ido pero conserva lo vivo', () => {
    const a = air(0, ps());
    const vivo = new Thermal();
    const ido = new Thermal();
    ido.gone = true;
    const estelaViva = new Slipstream();
    const estelaIda = new Slipstream();
    estelaIda.gone = true;
    const hermanoVivo = new Brother();
    const hermanoIdo = new Brother();
    hermanoIdo.gone = true;
    a.thermals.push(vivo, ido);
    a.slips.push(estelaViva, estelaIda);
    a.brothers.push(hermanoVivo, hermanoIdo);
    a.update(0);
    expect(a.thermals).toEqual([vivo]);
    expect(a.slips).toEqual([estelaViva]);
    expect(a.brothers).toEqual([hermanoVivo]);
  });
});
