import { describe, expect, it, vi } from 'vitest';
import { Rng } from '../src/core/Rng';
import { GameState } from '../src/core/types';
import { Effects, EffectKind } from '../src/systems/Effects';
import { Fruit, FruitSpawner } from '../src/systems/Fruit';

/** Tests de detalle para matar mutantes en `Effects` y `Fruit`. */

function spawnerConRng(seed = 1234): FruitSpawner {
  const spawner = new FruitSpawner();
  spawner.setRng(new Rng(seed));
  return spawner;
}

const MEDIO = (160 / 100) * 0.5;

describe('Effects · detalle de callbacks y caducidad', () => {
  it('sin efectos activos, update no avisa', () => {
    const fx = new Effects();
    const onChanged = vi.fn();
    fx.onChanged = onChanged;
    fx.update(1);
    expect(onChanged).not.toHaveBeenCalled();
  });

  it('update descuenta y avisa; a los 0 segundos exactos caduca', () => {
    const fx = new Effects();
    const onChanged = vi.fn();
    fx.onChanged = onChanged;
    fx.apply(EffectKind.LENTO);
    onChanged.mockClear();
    fx.update(1);
    expect(onChanged).toHaveBeenCalledTimes(1);
    expect(fx.activo(EffectKind.LENTO)).toBe(true);
    fx.update(fx.duration - 1);
    expect(fx.activo(EffectKind.LENTO)).toBe(false);
  });

  it('apply avisa por eje y por escudo', () => {
    const fx = new Effects();
    const onChanged = vi.fn();
    const onShield = vi.fn();
    fx.onChanged = onChanged;
    fx.onShieldChanged = onShield;
    fx.apply(EffectKind.LIGERO);
    expect(onChanged).toHaveBeenCalledTimes(1);
    fx.apply(EffectKind.INMUNIDAD);
    expect(onShield).toHaveBeenLastCalledWith(1);
  });

  it('clear avisa con lista vacía y escudo a 0', () => {
    const fx = new Effects();
    const onChanged = vi.fn();
    const onShield = vi.fn();
    fx.onChanged = onChanged;
    fx.onShieldChanged = onShield;
    fx.apply(EffectKind.INMUNIDAD);
    fx.apply(EffectKind.PESADO);
    onChanged.mockClear();
    onShield.mockClear();
    fx.clear();
    expect(onChanged).toHaveBeenCalledWith([]);
    expect(onShield).toHaveBeenCalledWith(0);
  });

  it('kindName cubre los 5 efectos y el vacío', () => {
    const fx = new Effects();
    expect(fx.kindName(EffectKind.PESADO)).toBe('Pesado');
    expect(fx.kindName(EffectKind.LIGERO)).toBe('Ligero');
    expect(fx.kindName(EffectKind.GRANDE)).toBe('Grande');
    expect(fx.kindName(EffectKind.LENTO)).toBe('Lento');
    expect(fx.kindName(EffectKind.INMUNIDAD)).toBe('');
    expect(fx.kindName(EffectKind.NINGUNO)).toBe('');
  });
});

describe('Fruit · física de flotación', () => {
  it('valores iniciales', () => {
    const f = new Fruit();
    expect(f.taken).toBe(false);
    expect(f.gone).toBe(false);
    expect(f.phase).toBe(0);
  });

  it('la fase crece y la y sigue la sinusoide exacta', () => {
    const f = new Fruit();
    f.place(320, 200);
    f.update(1);
    expect(f.phase).toBeCloseTo(f.floatSpeed * Math.PI * 2, 10);

    const g = new Fruit();
    g.place(320, 200);
    g.phase = Math.PI / 2;
    g.update(0);
    expect(g.y).toBeCloseTo(204, 10);

    const h = new Fruit();
    h.place(320, 200);
    h.phase = Math.PI;
    h.update(0);
    expect(h.y).toBeCloseTo(200, 10);
  });

  it('sale de pantalla al cruzar x + 8 < 0', () => {
    const f = new Fruit();
    f.place(-8, 100);
    f.scrollSpeed = 0;
    f.update(0);
    expect(f.gone).toBe(false);

    f.x = -9;
    f.update(0);
    expect(f.gone).toBe(true);
  });
});

describe('FruitSpawner · detalle', () => {
  it('setPaused(false) no cancela el temporizador', () => {
    const spawner = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.setPaused(false);
    spawner.update(MEDIO + 0.01);
    expect(spawner.fruits).toHaveLength(1);
  });

  it('PLAYING no congela ni limpia las frutas', () => {
    const spawner = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(MEDIO + 0.01);
    const f = spawner.fruits[0];
    spawner.onStateChanged(GameState.PLAYING);
    expect(spawner.fruits).toHaveLength(1);
    expect(f.scrollSpeed).toBe(spawner.scrollSpeed);
  });

  it('el temporizador se agota también cuando llega justo a 0', () => {
    const spawner = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(MEDIO);
    expect(spawner.fruits).toHaveLength(1);
  });

  it('tras crear una fruta no vuelve a crear sin nuevo onPipeSpawned', () => {
    const spawner = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(MEDIO + 0.01);
    expect(spawner.fruits).toHaveLength(1);
    spawner.update(1);
    expect(spawner.fruits).toHaveLength(1);
  });

  it('el hueco grande entra justo al llegar a bigMinGap', () => {
    const spawner = spawnerConRng();
    spawner.setDifficulty(100, spawner.bigMinGap, 160);
    expect(spawner.kindsDisponibles()).toContain(EffectKind.GRANDE);
  });

  it('la fruta nace con kind válido y fase en [0, 2pi)', () => {
    let maxPhase = 0;
    for (let seed = 1; seed <= 40; seed++) {
      const spawner = spawnerConRng(seed);
      spawner.chance = 1;
      spawner.onPipeSpawned();
      spawner.update(MEDIO + 0.01);
      const f = spawner.fruits[0];
      expect(f).toBeDefined();
      expect([1, 2, 3, 4, 5]).toContain(f.kind);
      expect(f.phase).toBeGreaterThanOrEqual(0);
      expect(f.phase).toBeLessThan(Math.PI * 2 + 1e-9);
      maxPhase = Math.max(maxPhase, f.phase);
    }
    expect(maxPhase).toBeGreaterThan(Math.PI);
  });
});
