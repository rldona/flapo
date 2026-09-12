import { describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { Rng } from '../src/core/Rng';

describe('curva de dificultad', () => {
  it('arranca con los valores del GDD', () => {
    expect(C.scrollSpeedFor(0)).toBeCloseTo(100, 5);
    expect(C.pipeGapFor(0)).toBeCloseTo(118, 5);
    expect(C.pipeSpacingFor(0)).toBeCloseTo(160, 5);
  });

  it('llega al tope y no lo pasa', () => {
    expect(C.scrollSpeedFor(30)).toBeCloseTo(145, 5);
    expect(C.scrollSpeedFor(999)).toBeCloseTo(145, 5);
    expect(C.pipeGapFor(30)).toBeCloseTo(82, 5);
    expect(C.pipeSpacingFor(30)).toBeCloseTo(172, 5);
  });

  it('mantiene entre 3 y 5 aleteos por hueco en normal', () => {
    const inicio = C.flapsBetweenPipes(0);
    const tope = C.flapsBetweenPipes(30);
    expect(inicio).toBeGreaterThan(3);
    expect(tope).toBeGreaterThan(3);
    expect(inicio).toBeLessThan(5);
  });

  it('escala los modos sin cambiar el ritmo de aleteos', () => {
    const normal = C.flapsBetweenPipes(15, C.Difficulty.NORMAL);
    const facil = C.flapsBetweenPipes(15, C.Difficulty.FACIL);
    const dificil = C.flapsBetweenPipes(15, C.Difficulty.DIFICIL);
    expect(facil).toBeCloseTo(normal, 6);
    expect(dificil).toBeCloseTo(normal, 6);
    expect(C.pipeGapFor(15, C.Difficulty.FACIL)).toBeGreaterThan(C.pipeGapFor(15, C.Difficulty.DIFICIL));
  });
});

describe('aliento y fatiga', () => {
  it('marca fatiga a partir de 4 aleteos', () => {
    expect(C.fatigueImpulseMult(4)).toBe(1);
    expect(C.fatigueImpulseMult(5)).toBeCloseTo(0.7, 5);
    expect(C.isFatigued(5)).toBe(true);
  });

  it('el jadeo es función pura del aliento', () => {
    expect(C.pantLevel(100, 100)).toBe(C.Pant.NINGUNO);
    expect(C.pantLevel(20, 100)).toBe(C.Pant.JADEO);
    expect(C.pantLevel(0, 100)).toBe(C.Pant.AGOTADO);
  });

  it('la confianza alarga el aliento con tope', () => {
    expect(C.maxBreathFor(0)).toBe(100);
    expect(C.maxBreathFor(5)).toBe(140);
    expect(C.maxBreathFor(99)).toBe(140);
    expect(C.confidenceLevel(50)).toBe(5);
  });
});

describe('semilla compartible', () => {
  it('el código es ida y vuelta', () => {
    for (const semilla of [0, 1, 12345, 999999, C.codigoModulo() - 1]) {
      const codigo = C.seedACodigo(semilla);
      expect(codigo).toHaveLength(C.CODIGO_LARGO);
      expect(C.codigoASeed(codigo)).toBe(semilla);
    }
  });

  it('rechaza códigos inválidos', () => {
    expect(C.codigoASeed('abc')).toBe(-1);
    expect(C.codigoASeed('abc$e')).toBe(-1);
  });
});

describe('layout adaptativo', () => {
  it('usa escala entera en escritorio y fraccional en móvil', () => {
    expect(C.windowScaleFor(576, 1024)).toBe(2);
    expect(C.windowScaleFor(1152, 2048)).toBe(4);
    expect(C.windowScaleFor(300, 2000)).toBeCloseTo(1.0417, 2);
    expect(C.windowScaleFor(390, 844)).toBeCloseTo(1.354, 2);
  });
});

describe('viento', () => {
  it('respeta el sobre de la curva y siempre sopla hacia donde hay margen', () => {
    const aFavor = C.windFactorFor(0, C.Difficulty.NORMAL, false);
    expect(aFavor).toBeGreaterThan(1);
    const enContra = C.windFactorFor(30, C.Difficulty.NORMAL, true);
    expect(enContra).toBeLessThan(1);
    for (let score = 0; score <= 30; score++) {
      const f = C.windFactorFor(score, C.Difficulty.NORMAL, Math.random() > 0.5);
      const v = C.windSpeedFor(score, C.Difficulty.NORMAL, f);
      expect(v).toBeGreaterThanOrEqual(C.scrollSpeedFor(0) - 1e-6);
      expect(v).toBeLessThanOrEqual(C.scrollSpeedFor(30) + 1e-6);
    }
  });
});

describe('tuberías móviles', () => {
  it('nunca saca el hueco completo de la zona jugable', () => {
    const gap = C.pipeGapFor(20);
    const centro = C.playableHeight() * 0.5;
    const amp = C.movingPipeAmplitude(gap, centro);
    expect(centro - gap / 2 - amp).toBeGreaterThanOrEqual(0);
    expect(centro + gap / 2 + amp).toBeLessThanOrEqual(C.playableHeight());
  });

  it('la velocidad de punta queda por debajo del aleteo', () => {
    expect(C.movingPipePeakSpeed(C.MOVING_PIPE_AMPLITUDE)).toBeLessThan(380);
  });
});

describe('determinismo', () => {
  it('la misma semilla da la misma secuencia', () => {
    const a = new Rng(42);
    const b = new Rng(42);
    for (let i = 0; i < 100; i++) {
      expect(a.randf()).toBeCloseTo(b.randf(), 12);
    }
  });

  it('semillas distintas dan secuencias distintas', () => {
    const a = new Rng(1);
    const b = new Rng(2);
    let iguales = 0;
    for (let i = 0; i < 50; i++) if (a.randf() === b.randf()) iguales++;
    expect(iguales).toBeLessThan(5);
  });
});

describe('utilidades', () => {
  it('sanea el nombre de jugador', () => {
    expect(C.sanitizePlayerName('  Raúl   López  ')).toBe('Raúl López');
    expect(C.sanitizePlayerName('a'.repeat(30))).toHaveLength(C.PLAYER_NAME_MAX_LEN);
  });

  it('las medallas son regla, no decoración', () => {
    expect(C.medalFor(9)).toBe(C.Medal.NINGUNA);
    expect(C.medalFor(10)).toBe(C.Medal.CROQUETA);
    expect(C.medalFor(20)).toBe(C.Medal.TORTILLA);
    expect(C.medalFor(40)).toBe(C.Medal.JAMON);
  });
});
