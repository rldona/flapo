import { describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { DeathCause, GameState } from '../src/core/types';
import { Bird, type BirdCallbacks } from '../src/systems/Bird';

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

function flap(bird: Bird, held = false): void {
  bird.update(DT, true, held);
}

describe('Bird: gravedad y caída', () => {
  it('sin aletear cae y acelera hasta el tope', () => {
    const { bird } = birdPlaying();
    const y0 = bird.y;
    bird.update(DT, false, false);
    expect(bird.vy).toBeGreaterThan(0);
    expect(bird.y).toBeGreaterThan(y0);
    for (let i = 0; i < 600; i++) bird.update(DT, false, false);
    expect(bird.vy).toBeLessThanOrEqual(C.MAX_FALL_SPEED + 1e-6);
    expect(bird.vy).toBeCloseTo(C.MAX_FALL_SPEED, 1);
  });

  it('en READY no hay gravedad', () => {
    const cb = mockCb();
    const bird = new Bird(cb);
    bird.onStateChanged(GameState.READY);
    const y0 = bird.y;
    for (let i = 0; i < 60; i++) bird.update(DT, false, false);
    expect(bird.vy).toBe(0);
    expect(bird.y).toBe(y0);
  });

  it('el techo frena sin atravesar', () => {
    const { bird } = birdPlaying();
    bird.y = 5;
    flap(bird);
    for (let i = 0; i < 10; i++) bird.update(DT, false, false);
    expect(bird.y).toBeGreaterThanOrEqual(C.CEILING_Y);
  });
});

describe('Bird: aleteo y aliento', () => {
  it('aletea con impulso completo y gasta 10 de aliento', () => {
    const { bird, cb } = birdPlaying();
    const aliento0 = bird.breath;
    flap(bird);
    expect(bird.vy).toBeCloseTo(C.FLAP_IMPULSE, 5);
    expect(bird.breath).toBeCloseTo(aliento0 - C.BREATH_DRAIN_FLAP, 5);
    expect(cb.flaps).toBe(1);
  });

  it('recupera aliento con tope y solo avisa si gana', () => {
    const { bird, cb } = birdPlaying();
    flap(bird);
    bird.recoverBreath(C.BREATH_RECOVER_ON_GAP);
    expect(bird.breath).toBe(bird.maxBreath);
    expect(cb.recovered.length).toBeGreaterThan(0);
    const avisos = cb.recovered.length;
    bird.recoverBreath(10);
    expect(cb.recovered.length).toBe(avisos);
  });

  it('setMaxBreath recorta y notifica', () => {
    const { bird, cb } = birdPlaying();
    bird.setMaxBreath(50);
    expect(bird.maxBreath).toBe(50);
    expect(bird.breath).toBeLessThanOrEqual(50);
    expect(cb.breaths.length).toBeGreaterThan(0);
  });

  it('el jadeo depende del aliento', () => {
    const { bird } = birdPlaying();
    expect(bird.pantLevel()).toBe(C.Pant.NINGUNO);
    bird.breath = bird.maxBreath * 0.2;
    expect(bird.pantLevel()).toBe(C.Pant.JADEO);
    bird.breath = 0;
    expect(bird.pantLevel()).toBe(C.Pant.AGOTADO);
  });
});

describe('Bird: fatiga', () => {
  it('5 aleteos rápidos fatigan y reducen el impulso', () => {
    const { bird, cb } = birdPlaying();
    for (let i = 0; i < 4; i++) flap(bird);
    expect(bird.isFatigued()).toBe(false);
    flap(bird);
    expect(bird.isFatigued()).toBe(true);
    expect(bird.recentFlaps()).toBe(5);
    // El 5º impulso lleva penalización del 30%
    expect(bird.vy).toBeCloseTo(C.FLAP_IMPULSE * (1 - C.FATIGUE_PENALTY), 4);
    expect(cb.fatigues.at(-1)?.[0]).toBe(true);
  });

  it('la ventana de 1.2s poda aleteos viejos', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < 5; i++) flap(bird);
    expect(bird.isFatigued()).toBe(true);
    for (let i = 0; i < Math.ceil((C.FATIGUE_WINDOW + 0.1) / DT); i++) {
      bird.update(DT, false, false);
    }
    expect(bird.recentFlaps()).toBe(0);
    expect(bird.isFatigued()).toBe(false);
  });

  it('planear limpia la fatiga', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < 5; i++) flap(bird);
    expect(bird.isFatigued()).toBe(true);
    // Mantener para entrar en planeo
    for (let i = 0; i < Math.ceil((C.GLIDE_HOLD_TIME + 0.05) / DT); i++) {
      bird.update(DT, false, true);
    }
    expect(bird.isGliding()).toBe(true);
    expect(bird.recentFlaps()).toBe(0);
    expect(bird.isFatigued()).toBe(false);
  });
});

describe('Bird: planeo', () => {
  it('requiere mantener 0.18s y frena la caída', () => {
    const { bird, cb } = birdPlaying();
    for (let i = 0; i < 5; i++) bird.update(DT, false, true);
    expect(bird.isGliding()).toBe(false);
    for (let i = 0; i < Math.ceil(0.2 / DT); i++) bird.update(DT, false, true);
    expect(bird.isGliding()).toBe(true);
    expect(cb.glides).toBe(1);
    for (let i = 0; i < 300; i++) bird.update(DT, false, true);
    expect(bird.vy).toBeLessThanOrEqual(C.GLIDE_MAX_FALL_SPEED + 1e-6);
  });

  it('soltar corta el planeo', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < Math.ceil(0.3 / DT); i++) bird.update(DT, false, true);
    expect(bird.isGliding()).toBe(true);
    bird.update(DT, false, false);
    expect(bird.isGliding()).toBe(false);
  });

  it('sin aliento no hay planeo, pero el aleteo sigue', () => {
    const { bird } = birdPlaying();
    bird.breath = 0;
    for (let i = 0; i < Math.ceil(0.3 / DT); i++) bird.update(DT, false, true);
    expect(bird.isGliding()).toBe(false);
    const alientoAntes = bird.breath;
    flap(bird);
    expect(cbFlaps(bird)).toBe(true);
    expect(bird.breath).toBe(alientoAntes);
    expect(bird.vy).toBeCloseTo(C.FLAP_IMPULSE, 4);
  });

  it('planea gastando 15/s, en estela no gasta', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < Math.ceil(0.3 / DT); i++) bird.update(DT, false, true);
    const b0 = bird.breath;
    for (let i = 0; i < 60; i++) bird.update(DT, false, true);
    expect(bird.breath).toBeLessThan(b0);
    const gasto = b0 - bird.breath;
    expect(gasto).toBeCloseTo(C.BREATH_DRAIN_GLIDE * 1, 0.6);

    const { bird: b2 } = birdPlaying();
    b2.setInSlipstream(true);
    for (let i = 0; i < Math.ceil(0.3 / DT); i++) b2.update(DT, false, true);
    const s0 = b2.breath;
    for (let i = 0; i < 60; i++) b2.update(DT, false, true);
    expect(b2.breath).toBeCloseTo(s0, 5);
  });
});

function cbFlaps(bird: Bird): boolean {
  return bird.vy < 0;
}

describe('Bird: térmicas', () => {
  it('en térmica y planeando sube con tope', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < Math.ceil(0.3 / DT); i++) bird.update(DT, false, true);
    expect(bird.isGliding()).toBe(true);
    bird.setInThermal(true);
    expect(bird.inThermal()).toBe(true);
    const y0 = bird.y;
    for (let i = 0; i < 60; i++) bird.update(DT, false, true);
    expect(bird.y).toBeLessThan(y0);
    bird.setInThermal(false);
    expect(bird.inThermal()).toBe(false);
  });

  it('sin planear la térmica no empuja por su rama', () => {
    const { bird } = birdPlaying();
    bird.setInThermal(true);
    bird.update(DT, false, false);
    expect(bird.vy).toBeGreaterThan(0);
  });
});

describe('Bird: blanditas', () => {
  it('rebotan siempre pero el coste tiene enfriamiento', () => {
    const { bird, cb } = birdPlaying();
    const aliento0 = bird.breath;
    bird.softBounce(bird.y + 50);
    const vy1 = bird.vy;
    expect(vy1).toBeGreaterThan(0);
    expect(bird.breath).toBeCloseTo(aliento0 - C.SOFT_PIPE_BREATH_COST, 5);
    expect(cb.softHits).toBe(1);
    // Segundo golpe inmediato: rebota pero no vuelve a cobrar ni avisar
    bird.softBounce(bird.y + 50);
    expect(cb.softHits).toBe(1);
    expect(bird.breath).toBeCloseTo(aliento0 - C.SOFT_PIPE_BREATH_COST, 5);
  });

  it('tras el enfriamiento vuelve a costar', () => {
    const { bird, cb } = birdPlaying();
    bird.softBounce(bird.y + 50);
    for (let i = 0; i < Math.ceil((C.SOFT_PIPE_COOLDOWN + 0.05) / DT); i++) {
      bird.update(DT, false, false);
    }
    bird.softBounce(bird.y + 50);
    expect(cb.softHits).toBe(2);
  });
});

describe('Bird: espejo', () => {
  it('invierte gravedad e impulso', () => {
    const { bird } = birdPlaying();
    bird.mirror = true;
    const y0 = bird.y;
    for (let i = 0; i < 30; i++) bird.update(DT, false, false);
    expect(bird.y).toBeLessThan(y0);
    expect(bird.facing).toBe(-1);
    flap(bird);
    expect(bird.vy).toBeGreaterThan(0);
    expect(bird.vy).toBeCloseTo(-C.FLAP_IMPULSE, 4);
  });
});

describe('Bird: muerte y estados', () => {
  it('die una sola vez con rebote', () => {
    const { bird, cb } = birdPlaying();
    bird.die(DeathCause.TUBERIA, false);
    expect(bird.isDead).toBe(true);
    expect(bird.vy).toBe(C.BOUNCE_IMPULSE);
    bird.die(DeathCause.SUELO, true);
    expect(cb.died).toHaveLength(1);
  });

  it('READY resetea posición, aliento y fatiga', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < 5; i++) flap(bird);
    bird.y = 400;
    bird.onStateChanged(GameState.READY);
    expect(bird.x).toBe(bird.startX);
    expect(bird.y).toBe(bird.startY);
    expect(bird.vy).toBe(0);
    expect(bird.breath).toBe(bird.maxBreath);
    expect(bird.recentFlaps()).toBe(0);
    expect(bird.isGliding()).toBe(false);
    expect(bird.isDead).toBe(false);
  });

  it('en escena no cae ni colisiona', () => {
    const { bird } = birdPlaying();
    bird.setScene(true);
    expect(bird.collides()).toBe(false);
    const y0 = bird.y;
    for (let i = 0; i < 60; i++) bird.update(DT, false, false);
    expect(bird.y).toBe(y0);
    bird.setScene(false);
    expect(bird.collides()).toBe(true);
  });

  it('survive da invulnerabilidad temporal', () => {
    const { bird } = birdPlaying();
    bird.survive(0.2);
    expect(bird.collides()).toBe(false);
    for (let i = 0; i < Math.ceil(0.25 / DT); i++) bird.update(DT, false, false);
    expect(bird.collides()).toBe(true);
  });

  it('en GAME_OVER gira sin control', () => {
    const { bird } = birdPlaying();
    bird.onStateChanged(GameState.GAME_OVER);
    const rot0 = bird.rotation;
    for (let i = 0; i < 30; i++) bird.update(DT, false, false);
    expect(bird.rotation).toBeGreaterThan(rot0);
    const flapsAntes = bird.vy;
    bird.update(DT, true, false);
    expect(bird.vy).not.toBe(C.FLAP_IMPULSE);
    expect(flapsAntes).toBeDefined();
  });

  it('la rotación mira arriba al aletear y abajo al caer', () => {
    const { bird } = birdPlaying();
    flap(bird);
    for (let i = 0; i < 10; i++) bird.update(DT, false, false);
    expect(bird.rotation).toBeLessThan(0.2);
    for (let i = 0; i < 120; i++) bird.update(DT, false, false);
    expect(bird.rotation).toBeGreaterThan(0.8);
  });

  it('el frame de animación cicla 0..2', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < 120; i++) {
      bird.update(DT, false, false);
      expect(bird.animationFrame()).toBeGreaterThanOrEqual(0);
      expect(bird.animationFrame()).toBeLessThanOrEqual(2);
    }
  });
});
