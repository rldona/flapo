import { describe, expect, it } from 'vitest';
import { SHIELD_MAX, playableHeight } from '../src/config/GameConfig';
import { Rng } from '../src/core/Rng';
import { GameState } from '../src/core/types';
import { Effects, EffectKind, fruitTexture } from '../src/systems/Effects';
import { Fruit, FruitSpawner } from '../src/systems/Fruit';

function spawnerConRng(seed = 1234): { spawner: FruitSpawner; rng: Rng } {
  const spawner = new FruitSpawner();
  const rng = new Rng(seed);
  spawner.setRng(rng);
  return { spawner, rng };
}

/** Avanza lo justo para que expire el temporizador de media separación. */
function medioIntervalo(spawner: FruitSpawner): number {
  // separacion 160 / velocidad 100 * 0.5 = 0.8s por defecto
  void spawner;
  return (160 / 100) * 0.5;
}

describe('Effects: escudos', () => {
  it('empieza sin escudo y consumir falla', () => {
    const fx = new Effects();
    expect(fx.hasShield()).toBe(false);
    expect(fx.shieldCount()).toBe(0);
    expect(fx.consumeShield()).toBe(false);
  });

  it('apila inmunidad hasta SHIELD_MAX sin pasarse', () => {
    const fx = new Effects();
    for (let i = 0; i < SHIELD_MAX + 2; i++) fx.apply(EffectKind.INMUNIDAD);
    expect(fx.shieldCount()).toBe(SHIELD_MAX);
    expect(fx.hasShield()).toBe(true);
  });

  it('consume uno a uno y avisa por callback', () => {
    const fx = new Effects();
    const avisos: number[] = [];
    fx.onShieldChanged = (n) => avisos.push(n);
    fx.apply(EffectKind.INMUNIDAD);
    fx.apply(EffectKind.INMUNIDAD);
    expect(fx.consumeShield()).toBe(true);
    expect(fx.shieldCount()).toBe(1);
    expect(fx.consumeShield()).toBe(true);
    expect(fx.hasShield()).toBe(false);
    expect(fx.consumeShield()).toBe(false);
    expect(avisos).toEqual([1, 2, 1, 0]);
  });

  it('clear resetea escudos y temporales', () => {
    const fx = new Effects();
    fx.apply(EffectKind.INMUNIDAD);
    fx.apply(EffectKind.LENTO);
    fx.clear();
    expect(fx.shieldCount()).toBe(0);
    expect(fx.activo(EffectKind.LENTO)).toBe(false);
    expect(fx.activos()).toEqual([]);
  });
});

describe('Effects: un efecto por eje', () => {
  it('pesado y ligero se excluyen (eje gravedad)', () => {
    const fx = new Effects();
    fx.apply(EffectKind.PESADO);
    expect(fx.activo(EffectKind.PESADO)).toBe(true);
    fx.apply(EffectKind.LIGERO);
    expect(fx.activo(EffectKind.LIGERO)).toBe(true);
    expect(fx.activo(EffectKind.PESADO)).toBe(false);
    expect(fx.gravityMult()).toBeCloseTo(fx.lightGravityMult, 5);
  });

  it('ejes distintos conviven', () => {
    const fx = new Effects();
    fx.apply(EffectKind.PESADO);
    fx.apply(EffectKind.GRANDE);
    fx.apply(EffectKind.LENTO);
    expect(fx.activo(EffectKind.PESADO)).toBe(true);
    expect(fx.activo(EffectKind.GRANDE)).toBe(true);
    expect(fx.activo(EffectKind.LENTO)).toBe(true);
    expect(fx.gravityMult()).toBeCloseTo(fx.heavyGravityMult, 5);
    expect(fx.sizeMult()).toBeCloseTo(fx.bigSizeMult, 5);
    expect(fx.hitboxMult()).toBeCloseTo(fx.bigHitboxMult, 5);
    expect(fx.speedMult()).toBeCloseTo(fx.slowSpeedMult, 5);
  });

  it('reaplicar refresca la duración', () => {
    const fx = new Effects();
    fx.apply(EffectKind.LENTO);
    fx.update(5);
    const antes = fx.activos()[0][1];
    expect(antes).toBeLessThan(fx.duration);
    fx.apply(EffectKind.LENTO);
    expect(fx.activos()[0][1]).toBeCloseTo(fx.duration, 5);
  });

  it('activos sale ordenado por tiempo restante', () => {
    const fx = new Effects();
    fx.apply(EffectKind.PESADO);
    fx.update(2);
    fx.apply(EffectKind.LENTO);
    const lista = fx.activos();
    expect(lista[0][0]).toBe(EffectKind.LENTO);
    expect(lista[1][0]).toBe(EffectKind.PESADO);
  });
});

describe('Effects: caducidad y multiplicadores', () => {
  it('sin efectos todo vale 1', () => {
    const fx = new Effects();
    expect(fx.gravityMult()).toBe(1);
    expect(fx.speedMult()).toBe(1);
    expect(fx.sizeMult()).toBe(1);
    expect(fx.hitboxMult()).toBe(1);
  });

  it('caducan tras duration', () => {
    const fx = new Effects();
    fx.apply(EffectKind.PESADO);
    fx.apply(EffectKind.LENTO);
    fx.update(fx.duration + 0.01);
    expect(fx.activo(EffectKind.PESADO)).toBe(false);
    expect(fx.activo(EffectKind.LENTO)).toBe(false);
    expect(fx.gravityMult()).toBe(1);
    expect(fx.speedMult()).toBe(1);
  });

  it('update parcial descuenta pero no borra', () => {
    const fx = new Effects();
    fx.apply(EffectKind.GRANDE);
    fx.update(1);
    expect(fx.activo(EffectKind.GRANDE)).toBe(true);
    expect(fx.activos()[0][1]).toBeCloseTo(fx.duration - 1, 5);
  });

  it('kindName y fruitTexture cubren las 5 frutas', () => {
    expect(fxNombre(EffectKind.PESADO)).toBe('Pesado');
    expect(fruitTexture(EffectKind.INMUNIDAD)).toBe('fruit_azul');
    expect(fruitTexture(EffectKind.PESADO)).toBe('fruit_roja');
    expect(fruitTexture(EffectKind.LIGERO)).toBe('fruit_verde');
    expect(fruitTexture(EffectKind.GRANDE)).toBe('fruit_naranja');
    expect(fruitTexture(EffectKind.LENTO)).toBe('fruit_violeta');
    // NINGUNO cae al azul por defecto, no revienta
    expect(fruitTexture(EffectKind.NINGUNO)).toBe('fruit_azul');
  });
});

function fxNombre(kind: EffectKind): string {
  return new Effects().kindName(kind);
}

describe('Fruit: flotación y salida', () => {
  it('se desplaza a scrollSpeed y flota en sinusoide acotada', () => {
    const f = new Fruit();
    f.place(320, 200);
    f.scrollSpeed = 100;
    f.update(0.5);
    expect(f.x).toBeCloseTo(270, 5);
    expect(Math.abs(f.y - 200)).toBeLessThanOrEqual(f.amplitude + 1e-6);
    expect(f.radius()).toBe(8);
  });

  it('marca gone al salir por la izquierda', () => {
    const f = new Fruit();
    f.place(0, 100);
    f.scrollSpeed = 100;
    f.update(0.2);
    expect(f.gone).toBe(true);
  });

  it('place fija x, y y baseY', () => {
    const f = new Fruit();
    f.place(123, 321);
    expect(f.x).toBe(123);
    expect(f.y).toBe(321);
    expect(f.baseY).toBe(321);
  });
});

describe('FruitSpawner: catálogo según hueco', () => {
  it('sin hueco grande no ofrece GRANDE', () => {
    const { spawner } = spawnerConRng();
    spawner.setDifficulty(100, 80, 160);
    expect(spawner.kindsDisponibles()).not.toContain(EffectKind.GRANDE);
  });

  it('con hueco amplio sí ofrece las 5', () => {
    const { spawner } = spawnerConRng();
    spawner.setDifficulty(100, 118, 160);
    const kinds = spawner.kindsDisponibles();
    expect(kinds).toContain(EffectKind.GRANDE);
    expect(kinds).toHaveLength(5);
  });
});

describe('FruitSpawner: temporizador de media separación', () => {
  it('sin rng nunca crea (no revienta)', () => {
    const spawner = new FruitSpawner();
    spawner.onPipeSpawned();
    spawner.update(10);
    expect(spawner.fruits).toHaveLength(0);
  });

  it('con chance 0 nunca crea', () => {
    const { spawner } = spawnerConRng();
    spawner.chance = 0;
    spawner.onPipeSpawned();
    spawner.update(medioIntervalo(spawner) + 0.01);
    expect(spawner.fruits).toHaveLength(0);
  });

  it('con chance 1 crea una fruta a medio intervalo', () => {
    const { spawner } = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(medioIntervalo(spawner) - 0.05);
    expect(spawner.fruits).toHaveLength(0);
    spawner.update(0.06);
    expect(spawner.fruits).toHaveLength(1);
  });

  it('la fruta nace en X y en banda vertical válida', () => {
    const { spawner } = spawnerConRng(7);
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(medioIntervalo(spawner) + 0.01);
    const f = spawner.fruits[0];
    expect(f.x).toBe(spawner.spawnX);
    const minY = spawner.minRatio * playableHeight();
    const maxY = spawner.maxRatio * playableHeight();
    expect(f.y).toBeGreaterThanOrEqual(minY - 1e-6);
    expect(f.y).toBeLessThanOrEqual(maxY + 1e-6);
  });

  it('castigo paga puntos, bonus no', () => {
    const { spawner } = spawnerConRng();
    spawner.chance = 1;
    // Varias semillas para cubrir castigo y bonus
    for (let seed = 1; seed <= 20; seed++) {
      spawner.setRng(new Rng(seed));
      spawner.onPipeSpawned();
      spawner.update(medioIntervalo(spawner) + 0.01);
      const f = spawner.fruits.pop();
      if (!f) continue;
      if (f.kind === EffectKind.PESADO || f.kind === EffectKind.GRANDE) {
        expect(f.points).toBe(spawner.penaltyPoints);
      } else {
        expect(f.points).toBe(0);
      }
    }
  });

  it('misma semilla, misma fruta', () => {
    const a = spawnerConRng(4242);
    const b = spawnerConRng(4242);
    a.spawner.chance = 1;
    b.spawner.chance = 1;
    a.spawner.onPipeSpawned();
    b.spawner.onPipeSpawned();
    a.spawner.update(medioIntervalo(a.spawner) + 0.01);
    b.spawner.update(medioIntervalo(b.spawner) + 0.01);
    expect(a.spawner.fruits[0].kind).toBe(b.spawner.fruits[0].kind);
    expect(a.spawner.fruits[0].y).toBeCloseTo(b.spawner.fruits[0].y, 8);
  });
});

describe('FruitSpawner: ciclo de vida', () => {
  it('READY limpia frutas y cancela el temporizador', () => {
    const { spawner } = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(medioIntervalo(spawner) + 0.01);
    expect(spawner.fruits.length).toBeGreaterThan(0);
    spawner.onStateChanged(GameState.READY);
    expect(spawner.fruits).toHaveLength(0);
    // Tras limpiar, sin nuevo onPipeSpawned no debe crear
    spawner.update(5);
    expect(spawner.fruits).toHaveLength(0);
  });

  it('GAME_OVER congela las frutas en pantalla', () => {
    const { spawner } = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(medioIntervalo(spawner) + 0.01);
    const xAntes = spawner.fruits[0].x;
    spawner.onStateChanged(GameState.GAME_OVER);
    spawner.update(1);
    expect(spawner.fruits[0].x).toBeCloseTo(xAntes, 5);
  });

  it('setDifficulty propaga la velocidad a las frutas vivas', () => {
    const { spawner } = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.update(medioIntervalo(spawner) + 0.01);
    spawner.setDifficulty(145, 82, 172);
    expect(spawner.fruits[0].scrollSpeed).toBe(145);
  });

  it('las frutas que salen se filtran', () => {
    const { spawner } = spawnerConRng();
    const f = new Fruit();
    f.place(-20, 100);
    f.scrollSpeed = 100;
    spawner.fruits.push(f);
    spawner.update(0.05);
    expect(spawner.fruits).toHaveLength(0);
  });

  it('pausar cancela el temporizador pendiente', () => {
    const { spawner } = spawnerConRng();
    spawner.chance = 1;
    spawner.onPipeSpawned();
    spawner.setPaused(true);
    spawner.update(5);
    expect(spawner.fruits).toHaveLength(0);
  });
});
