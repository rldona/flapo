import { describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { DeathCause, GameState } from '../src/core/types';
import { Bird, type BirdCallbacks } from '../src/systems/Bird';

/** Tests de detalle para matar mutantes en `Bird`. */

const DT = 1 / 60;

interface Spy extends BirdCallbacks {
  flaps: number;
  died: Array<[DeathCause, boolean]>;
  softHits: number;
  recovered: number[];
  glides: number;
  breaths: Array<[number, number]>;
  fatigues: Array<[boolean, number]>;
}

function mockCb(): Spy {
  const spy = {
    flaps: 0,
    died: [] as Array<[DeathCause, boolean]>,
    softHits: 0,
    recovered: [] as number[],
    glides: 0,
    breaths: [] as Array<[number, number]>,
    fatigues: [] as Array<[boolean, number]>,
    onFlapped() {
      spy.flaps++;
    },
    onDied(cause: DeathCause, breathless: boolean) {
      spy.died.push([cause, breathless]);
    },
    onSoftHit() {
      spy.softHits++;
    },
    onBreathRecovered(amount: number) {
      spy.recovered.push(amount);
    },
    onGlided() {
      spy.glides++;
    },
    onBreathChanged(actual: number, max: number) {
      spy.breaths.push([actual, max]);
    },
    onFatigueChanged(fatigued: boolean, count: number) {
      spy.fatigues.push([fatigued, count]);
    },
  } as Spy;
  return spy;
}

function birdPlaying(): { bird: Bird; cb: Spy } {
  const cb = mockCb();
  const bird = new Bird(cb);
  bird.onStateChanged(GameState.READY);
  bird.onStateChanged(GameState.PLAYING);
  return { bird, cb };
}

describe('Bird · estado inicial', () => {
  it('un pájaro nuevo está vivo, fuera de escena, sin planeo ni aleteos', () => {
    const bird = new Bird(mockCb());
    expect(bird.isDead).toBe(false);
    expect(bird.inScene).toBe(false);
    expect(bird.isGliding()).toBe(false);
    expect(bird.recentFlaps()).toBe(0);
    expect(bird.inSlipstream()).toBe(false);
  });
});

describe('Bird · callbacks de reset', () => {
  it('onStateChanged(PLAYING) no resetea nada', () => {
    const { bird } = birdPlaying();
    bird.y = 123;
    bird.onStateChanged(GameState.PLAYING);
    expect(bird.y).toBe(123);
    expect(bird.isDead).toBe(false);
  });

  it('el reset avisa dos veces del aliento y una de fatiga en 0', () => {
    const { bird, cb } = birdPlaying();
    for (let i = 0; i < 5; i++) bird.update(DT, true, false);
    expect(bird.isFatigued()).toBe(true);

    const breaths = cb.breaths.length;
    cb.fatigues.length = 0;
    bird.onStateChanged(GameState.READY);
    expect(cb.breaths.length).toBeGreaterThanOrEqual(breaths + 2);
    expect(cb.fatigues.at(-1)).toEqual([false, 0]);
  });
});

describe('Bird · update en READY y GAME_OVER', () => {
  it('en READY se anula la velocidad cada tick', () => {
    const { bird } = birdPlaying();
    bird.onStateChanged(GameState.READY);
    bird.vy = 100;
    bird.update(DT, false, false);
    expect(bird.vy).toBe(0);
  });

  it('en GAME_OVER la gravedad sigue actuando', () => {
    const { bird } = birdPlaying();
    bird.onStateChanged(GameState.GAME_OVER);
    bird.vy = 0;
    bird.update(DT, false, false);
    expect(bird.vy).toBeGreaterThan(0);
  });

  it('el giro de aturdimiento avanza STUN_SPIN * dt por tick', () => {
    const { bird } = birdPlaying();
    bird.onStateChanged(GameState.GAME_OVER);
    const r0 = bird.rotation;
    bird.update(DT, false, false);
    expect(bird.rotation - r0).toBeCloseTo(C.STUN_SPIN * DT, 6);
  });
});

describe('Bird · inventario y planeo con 0/1 unidades', () => {
  it('el enfriamiento de blandita no se desploma a 0', () => {
    const { bird, cb } = birdPlaying();
    bird.softBounce(bird.y + 50);
    expect(cb.softHits).toBe(1);
    bird.update(DT, false, false);
    bird.softBounce(bird.y + 50);
    expect(cb.softHits).toBe(1);
  });

  it('la invulnerabilidad dura al menos un tick', () => {
    const { bird } = birdPlaying();
    bird.survive(0.2);
    expect(bird.collides()).toBe(false);
    bird.update(DT, false, false);
    expect(bird.collides()).toBe(false);
  });

  it('pantTintWeight sigue al aliento', () => {
    const { bird } = birdPlaying();
    expect(bird.pantTintWeight()).toBe(0);
    bird.breath = bird.maxBreath * 0.15;
    expect(bird.pantTintWeight()).toBeGreaterThan(0);
  });

  it('estela de aire: entra, marca y sale', () => {
    const { bird } = birdPlaying();
    expect(bird.inSlipstream()).toBe(false);
    bird.setInSlipstream(true);
    expect(bird.inSlipstream()).toBe(true);
    bird.setInSlipstream(false);
    expect(bird.inSlipstream()).toBe(false);
  });
});

describe('Bird · blanditas y dirección', () => {
  it('si el centro está por encima, el rebote va hacia arriba', () => {
    const { bird } = birdPlaying();
    bird.softBounce(bird.y - 50);
    expect(bird.vy).toBeLessThan(0);
    expect(Math.abs(bird.vy)).toBeCloseTo(C.SOFT_PIPE_BOUNCE_SPEED, 5);
  });

  it('mismo centro: el rebote es siempre hacia arriba', () => {
    const { bird } = birdPlaying();
    bird.softBounce(bird.y);
    expect(bird.vy).toBeCloseTo(-C.SOFT_PIPE_BOUNCE_SPEED, 5);
  });
});
