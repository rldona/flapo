import { describe, expect, it } from 'vitest';
import { THERMAL_LIFT, THERMAL_MAX_RISE } from '../src/config/AirConfig';
import * as C from '../src/config/GameConfig';
import { DeathCause, GameState } from '../src/core/types';
import { Bird, type BirdCallbacks } from '../src/systems/Bird';

/** Segunda pasada de tests de detalle para matar mutantes de `Bird`. */

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

function entrarEnPlaneo(bird: Bird): void {
  for (let i = 0; i < Math.ceil((C.GLIDE_HOLD_TIME + 0.05) / DT); i++) {
    bird.update(DT, false, true);
  }
}

describe('Bird · callbacks exactos', () => {
  it('setMaxBreath avisa una vez más', () => {
    const { bird, cb } = birdPlaying();
    const n = cb.breaths.length;
    bird.setMaxBreath(60);
    expect(cb.breaths.length).toBe(n + 1);
  });

  it('ajustarAliento avisa sólo si cambia', () => {
    const { bird, cb } = birdPlaying();
    const lleno = cb.breaths.length;
    bird.recoverBreath(10);
    expect(cb.breaths.length).toBe(lleno);

    bird.breath = 0;
    const vacio = cb.breaths.length;
    bird.recoverBreath(10);
    expect(cb.breaths.length).toBe(vacio + 1);
  });
});

describe('Bird · gravedad con multiplicador', () => {
  it('la caída normal escala con gravityMult', () => {
    const { bird } = birdPlaying();
    bird.gravityMult = 2;
    bird.vy = 0;
    bird.update(DT, false, false);
    expect(bird.vy).toBeCloseTo(C.GRAVITY * 2 * DT, 8);
  });

  it('el planeo sin térmica escala con gravityMult', () => {
    const { bird } = birdPlaying();
    entrarEnPlaneo(bird);
    expect(bird.isGliding()).toBe(true);
    bird.gravityMult = 2;
    bird.vy = 0;
    bird.update(DT, false, true);
    expect(bird.vy).toBeCloseTo(C.GRAVITY * 2 * C.GLIDE_GRAVITY_MULT * DT, 8);
  });

  it('sin térmica, el planeo acaba frenando en GLIDE_MAX_FALL_SPEED', () => {
    const { bird } = birdPlaying();
    entrarEnPlaneo(bird);
    bird.vy = 0;
    for (let i = 0; i < 300; i++) bird.update(DT, false, true);
    expect(bird.vy).toBeCloseTo(C.GLIDE_MAX_FALL_SPEED, 0);
  });
});

describe('Bird · térmicas exactas', () => {
  it('un tick en térmica resta THERMAL_LIFT * dt', () => {
    const { bird } = birdPlaying();
    entrarEnPlaneo(bird);
    bird.setInThermal(true);
    bird.vy = 0;
    bird.update(DT, false, true);
    expect(bird.vy).toBeCloseTo(-THERMAL_LIFT * DT, 8);
  });

  it('la térmica acaba topada en THERMAL_MAX_RISE', () => {
    const { bird } = birdPlaying();
    entrarEnPlaneo(bird);
    bird.y = 400;
    bird.setInThermal(true);
    bird.vy = 0;
    for (let i = 0; i < 40; i++) bird.update(DT, false, true);
    expect(bird.vy).toBeCloseTo(-THERMAL_MAX_RISE, 6);
  });
});

describe('Bird · planeo y fatiga', () => {
  it('el planeo arranca también cuando held llega justo al umbral', () => {
    const { bird } = birdPlaying();
    (bird as unknown as { held: number }).held = C.GLIDE_HOLD_TIME;
    bird.update(0, false, true);
    expect(bird.isGliding()).toBe(true);
  });

  it('al entrar en planeo limpia la fatiga una sola vez', () => {
    const { bird, cb } = birdPlaying();
    for (let i = 0; i < 3; i++) bird.update(DT, true, false);

    const avisos: Array<[boolean, number]> = [];
    cb.onFatigueChanged = (f, c) => {
      avisos.push([f, c]);
    };
    const limpiezas = (): number => avisos.filter(([f, c]) => f === false && c === 0).length;

    entrarEnPlaneo(bird);
    expect(bird.isGliding()).toBe(true);
    expect(limpiezas()).toBe(1);
    expect(bird.recentFlaps()).toBe(0);

    for (let i = 0; i < 10; i++) bird.update(DT, false, true);
    expect(limpiezas()).toBe(1);
  });

  it('la poda de aleteos respeta el borde exacto de la ventana', () => {
    const { bird } = birdPlaying();
    bird.update(DT, true, false);
    (bird as unknown as { tiempo: number }).tiempo = DT + C.FATIGUE_WINDOW;
    expect(bird.recentFlaps()).toBe(1);
  });
});

describe('Bird · techo', () => {
  it('no recorta si está justo en el techo y cae', () => {
    const { bird } = birdPlaying();
    bird.y = C.CEILING_Y;
    bird.vy = 100;
    bird.update(DT, false, false);
    expect(bird.y).toBeGreaterThan(C.CEILING_Y);
  });

  it('al chocar contra el techo la velocidad no queda negativa', () => {
    const { bird } = birdPlaying();
    bird.y = 1;
    bird.vy = -100;
    bird.update(DT, false, false);
    expect(bird.vy).toBeGreaterThanOrEqual(0);
  });

  it('si el borde del techo cae exacto, no recorta el aleteo', () => {
    const { bird } = birdPlaying();
    bird.y = -C.FLAP_IMPULSE * DT;
    bird.vy = 0;
    bird.update(DT, true, false);
    expect(bird.vy).toBeCloseTo(C.FLAP_IMPULSE, 6);
  });
});

describe('Bird · rotación', () => {
  it('gira hacia el objetivo de forma parcial, no de golpe', () => {
    const { bird } = birdPlaying();
    bird.rotation = 0;
    bird.vy = C.MAX_FALL_SPEED;
    bird.update(DT, false, false);
    const objetivo = (C.ROTATION_DOWN_DEGREES * Math.PI) / 180;
    expect(bird.rotation).toBeGreaterThan(0);
    expect(bird.rotation).toBeLessThan(objetivo);
  });

  it('normaliza el ángulo por encima de +PI', () => {
    const { bird } = birdPlaying();
    const objetivo = (C.ROTATION_DOWN_DEGREES * Math.PI) / 180;
    bird.vy = C.MAX_FALL_SPEED;
    bird.rotation = objetivo + 3.5;
    for (let i = 0; i < 600; i++) bird.update(DT, false, false);
    expect(bird.rotation).toBeCloseTo(objetivo + Math.PI * 2, 6);
  });

  it('normaliza el ángulo por debajo de -PI', () => {
    const { bird } = birdPlaying();
    const objetivo = (C.ROTATION_DOWN_DEGREES * Math.PI) / 180;
    bird.vy = C.MAX_FALL_SPEED;
    bird.rotation = objetivo - 3.5;
    for (let i = 0; i < 600; i++) bird.update(DT, false, false);
    expect(bird.rotation).toBeCloseTo(objetivo - Math.PI * 2, 6);
  });

  it('justo en -PI gira hacia el objetivo, no al otro lado', () => {
    const { bird } = birdPlaying();
    const objetivo = (C.ROTATION_DOWN_DEGREES * Math.PI) / 180;
    bird.vy = C.MAX_FALL_SPEED;
    bird.rotation = objetivo + Math.PI;
    const inicial = bird.rotation;
    bird.update(DT, false, false);
    expect(bird.rotation).toBeLessThan(inicial);
  });

  it('justo en +PI gira hacia el objetivo, no al otro lado', () => {
    const { bird } = birdPlaying();
    const objetivo = (C.ROTATION_DOWN_DEGREES * Math.PI) / 180;
    bird.vy = C.MAX_FALL_SPEED;
    bird.rotation = objetivo - Math.PI;
    const inicial = bird.rotation;
    bird.update(DT, false, false);
    expect(bird.rotation).toBeGreaterThan(inicial);
  });
});

describe('Bird · animación', () => {
  it('la animación avanza en READY', () => {
    const bird = new Bird(mockCb());
    bird.onStateChanged(GameState.READY);
    for (let i = 0; i < 13; i++) bird.update(DT, false, false);
    expect(bird.animationFrame()).toBe(1);
  });

  it('el burst de aleteo acelera la animación y luego decae', () => {
    const { bird } = birdPlaying();
    bird.update(DT, true, false);
    for (let i = 0; i < 11; i++) bird.update(DT, false, false);
    expect(bird.animationFrame()).toBe(0);
  });

  it('en GAME_OVER la animación se congela', () => {
    const { bird } = birdPlaying();
    bird.onStateChanged(GameState.GAME_OVER);
    const frame0 = bird.animationFrame();
    for (let i = 0; i < 20; i++) bird.update(DT, false, false);
    expect(bird.animationFrame()).toBe(frame0);
  });

  it('el jadeo acelera la animación', () => {
    const bird = new Bird(mockCb());
    bird.onStateChanged(GameState.READY);
    bird.breath = 10;
    for (let i = 0; i < 13; i++) bird.update(DT, false, false);
    expect(bird.animationFrame()).toBe(2);
  });
});

describe('Bird · ramas de estado y escena', () => {
  it('survive revive al pájaro', () => {
    const { bird } = birdPlaying();
    bird.die(DeathCause.SUELO, false);
    expect(bird.isDead).toBe(true);
    bird.survive(0.2);
    expect(bird.isDead).toBe(false);
  });

  it('un pájaro nuevo colisiona', () => {
    expect(new Bird(mockCb()).collides()).toBe(true);
  });

  it('el reset vuelve a habilitar la colisión', () => {
    const { bird } = birdPlaying();
    bird.survive(0.2);
    expect(bird.collides()).toBe(false);
    bird.onStateChanged(GameState.READY);
    expect(bird.collides()).toBe(true);
  });

  it('MENU también resetea, no sólo READY', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < 3; i++) bird.update(DT, true, false);
    bird.y = 400;
    bird.onStateChanged(GameState.MENU);
    expect(bird.y).toBe(bird.startY);
    expect(bird.recentFlaps()).toBe(0);
  });

  it('en MENU la velocidad se anula cada tick', () => {
    const bird = new Bird(mockCb());
    bird.onStateChanged(GameState.MENU);
    bird.vy = 100;
    bird.update(DT, false, false);
    expect(bird.vy).toBe(0);
  });

  it('survive(0) mantiene la máscara activa hasta el update', () => {
    const { bird } = birdPlaying();
    bird.survive(0);
    bird.update(DT, false, false);
    expect(bird.collides()).toBe(false);
  });

  it('en PLAYING un aleteo usa el impulso, no la rama de muerte', () => {
    const { bird } = birdPlaying();
    bird.update(DT, true, false);
    expect(bird.vy).toBeCloseTo(C.FLAP_IMPULSE, 6);
  });

  it('en espejo la gravedad también va hacia arriba con su tope', () => {
    const { bird } = birdPlaying();
    bird.mirror = true;
    bird.vy = 0;
    bird.update(DT, false, false);
    expect(bird.vy).toBeCloseTo(-C.GRAVITY * DT, 8);
  });

  it('en escena el planeo se corta', () => {
    const { bird } = birdPlaying();
    entrarEnPlaneo(bird);
    expect(bird.isGliding()).toBe(true);
    bird.setScene(true);
    bird.update(DT, false, false);
    expect(bird.isGliding()).toBe(false);
  });

  it('en escena la animación sigue avanzando', () => {
    const { bird } = birdPlaying();
    bird.setScene(true);
    for (let i = 0; i < 13; i++) bird.update(DT, false, false);
    expect(bird.animationFrame()).toBe(1);
  });

  it('aletear mientras planea no re-limpia la fatiga', () => {
    const { bird, cb } = birdPlaying();
    for (let i = 0; i < 3; i++) bird.update(DT, true, false);
    const avisos: Array<[boolean, number]> = [];
    cb.onFatigueChanged = (f, c) => {
      avisos.push([f, c]);
    };
    const limpiezas = (): number => avisos.filter(([f, c]) => f === false && c === 0).length;

    entrarEnPlaneo(bird);
    const base = limpiezas();
    expect(base).toBe(1);

    bird.update(DT, true, true);
    bird.update(DT, false, true);
    expect(limpiezas()).toBe(base);
  });

  it('al entrar en planeo sin aleteos previos no limpia nada', () => {
    const { bird, cb } = birdPlaying();
    const avisos: Array<[boolean, number]> = [];
    cb.onFatigueChanged = (f, c) => {
      avisos.push([f, c]);
    };
    entrarEnPlaneo(bird);
    expect(bird.isGliding()).toBe(true);
    expect(avisos.filter(([f, c]) => f === false && c === 0)).toHaveLength(0);
  });

  it('registrarAleteo poda antes de calcular la fatiga', () => {
    const { bird } = birdPlaying();
    for (let i = 0; i < 4; i++) bird.update(DT, true, false);
    for (let i = 0; i < Math.ceil((C.FATIGUE_WINDOW + 0.1) / DT); i++) {
      bird.update(DT, false, false);
    }
    bird.update(DT, true, false);
    expect(bird.vy).toBeCloseTo(C.FLAP_IMPULSE, 5);
  });

  it('sin envolver el ángulo, converge al objetivo directo', () => {
    const { bird } = birdPlaying();
    const objetivo = (C.ROTATION_DOWN_DEGREES * Math.PI) / 180;
    bird.vy = C.MAX_FALL_SPEED;
    bird.rotation = objetivo + 0.5;
    for (let i = 0; i < 600; i++) bird.update(DT, false, false);
    expect(bird.rotation).toBeCloseTo(objetivo, 6);
  });
});
