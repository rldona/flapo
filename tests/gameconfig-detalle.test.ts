import { describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';

/**
 * Tests de detalle de `GameConfig`: constantes exactas y ramas de las funciones
 * puras. Están escritos para que cada mutación de un literal, una comparación o
 * un término aritmético cambie el valor esperado.
 */

describe('GameConfig · constantes exactas', () => {
  it('medidas y física con signo', () => {
    expect(C.VIEWPORT_WIDTH).toBe(288);
    expect(C.VIEWPORT_HEIGHT).toBe(512);
    expect(C.GROUND_HEIGHT).toBe(64);
    expect(C.BOUNCE_IMPULSE).toBe(-180);
    expect(C.BUDDY_OFFSET_X).toBe(-26);
    expect(C.BUDDY_OFFSET_Y).toBe(-20);
  });

  it('tintes y colores', () => {
    expect(C.SOFT_PIPE_TINT).toBe('#7FA37B');
    expect(C.PANT_TINT).toBe('#F2B3A0');
    expect(C.SNAPSHOT_PIPE_COLOR).toBe('#3A5468');
    expect(C.BUDDY_TINT).toBe('#9BBBA8');
    expect(C.SPECIAL_PIPE_TINT).toBe('#E6C46A');
    expect(C.GHOST_TINT).toBe('#8FB8D8');
  });

  it('textos por defecto', () => {
    expect(C.PLAYER_NAME_DEFAULT).toBe('Flapo');
    expect(C.JOURNEY_LINE).toBe('Ha llegado. Gordo, pero ha llegado.');
  });

  it('escenarios exactos', () => {
    expect(C.SCENERY_SKY).toEqual(['#7CB3D7', '#E8A06B', '#2E3F5C', '#8FA3B0']);
    expect(C.SCENERY_TINT).toEqual(['#FFFFFF', '#FFC49A', '#6E7FA6', '#B9C6CE']);
    expect(C.SCENERY_LLUEVE).toEqual([false, false, false, true]);
  });

  it('meses en español exactos', () => {
    expect(C.MESES).toEqual([
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ]);
  });
});

describe('GameConfig · utilidades', () => {
  it('mix interpola y posmod siempre es positivo', () => {
    expect(C.mix(0, 10, 0.5)).toBe(5);
    expect(C.mix(10, 0, 0.25)).toBe(7.5);
    expect(C.posmod(5, 4)).toBe(1);
    expect(C.posmod(-1, 4)).toBe(3);
  });

  it('clamp recorta por ambos lados', () => {
    expect(C.clamp(5, 0, 10)).toBe(5);
    expect(C.clamp(-1, 0, 10)).toBe(0);
    expect(C.clamp(11, 0, 10)).toBe(10);
  });
});

describe('GameConfig · progresión', () => {
  it('mirrorUnlocked se abre justo a 25', () => {
    expect(C.mirrorUnlocked(24)).toBe(false);
    expect(C.mirrorUnlocked(C.MIRROR_UNLOCK_SCORE)).toBe(true);
    expect(C.mirrorUnlocked(26)).toBe(true);
  });

  it('grazeThreshold es gap*0.5*0.8', () => {
    expect(C.grazeThreshold(100)).toBeCloseTo(40, 10);
    expect(C.grazeThreshold(0)).toBe(0);
  });

  it('journeyStage avanza cada 13 y se queda en 3', () => {
    expect(C.journeyStage(0)).toBe(C.Stage.PARQUE);
    expect(C.journeyStage(12)).toBe(C.Stage.PARQUE);
    expect(C.journeyStage(13)).toBe(C.Stage.TEJADOS);
    expect(C.journeyStage(25)).toBe(C.Stage.TEJADOS);
    expect(C.journeyStage(26)).toBe(C.Stage.NUBES);
    expect(C.journeyStage(39)).toBe(C.Stage.CIELO);
    expect(C.journeyStage(999)).toBe(C.Stage.CIELO);
  });

  it('stageName nombra los 4 tramos', () => {
    expect(C.stageName(C.Stage.PARQUE)).toBe('Parque');
    expect(C.stageName(C.Stage.TEJADOS)).toBe('Tejados');
    expect(C.stageName(C.Stage.NUBES)).toBe('Nubes');
    expect(C.stageName(C.Stage.CIELO)).toBe('Cielo');
  });

  it('isSpecialSoft coincide con la mitad del tramo', () => {
    expect(C.isSpecialSoft(C.SPECIAL_STRETCH_PIPES / 2)).toBe(true);
    expect(C.isSpecialSoft(0)).toBe(false);
    expect(C.isSpecialSoft(C.SPECIAL_STRETCH_PIPES)).toBe(false);
  });

  it('groundFillHeight nunca es negativo', () => {
    expect(C.groundFillHeight(600, 400)).toBe(136);
    expect(C.groundFillHeight(512, 448)).toBe(0);
    expect(C.groundFillHeight(400, 448)).toBe(0);
  });

  it('sceneryFor da la vuelta con posmod', () => {
    expect(C.sceneryFor(0)).toBe(C.Scenery.DIA);
    expect(C.sceneryFor(1)).toBe(C.Scenery.ATARDECER);
    expect(C.sceneryFor(2)).toBe(C.Scenery.NOCHE);
    expect(C.sceneryFor(3)).toBe(C.Scenery.LLUVIA);
    expect(C.sceneryFor(4)).toBe(C.Scenery.DIA);
    expect(C.sceneryFor(-1)).toBe(C.Scenery.LLUVIA);
  });

  it('accesores de escenario devuelven cada variante', () => {
    expect(C.scenerySky(C.Scenery.DIA)).toBe('#7CB3D7');
    expect(C.sceneryTint(C.Scenery.ATARDECER)).toBe('#FFC49A');
    expect(C.sceneryTint(C.Scenery.NOCHE)).toBe('#6E7FA6');
    expect(C.scenerySky(C.Scenery.LLUVIA)).toBe('#8FA3B0');
    expect(C.sceneryRains(C.Scenery.LLUVIA)).toBe(true);
    expect(C.sceneryRains(C.Scenery.DIA)).toBe(false);
    expect(C.sceneryRains(C.Scenery.NOCHE)).toBe(false);
    expect(C.sceneryName(C.Scenery.DIA)).toBe('Día');
    expect(C.sceneryName(C.Scenery.ATARDECER)).toBe('Atardecer');
    expect(C.sceneryName(C.Scenery.NOCHE)).toBe('Noche');
    expect(C.sceneryName(C.Scenery.LLUVIA)).toBe('Lluvia');
  });
});

describe('GameConfig · dificultad', () => {
  it('difficulty va de 0 a 1 sin pasarse', () => {
    expect(C.difficulty(0)).toBe(0);
    expect(C.difficulty(15)).toBeCloseTo(0.5, 10);
    expect(C.difficulty(30)).toBe(1);
    expect(C.difficulty(60)).toBe(1);
    expect(C.difficulty(-5)).toBe(0);
  });

  it('gapMult y speedMult cubren los 3 modos y clampan el índice', () => {
    expect(C.gapMult(C.Difficulty.FACIL)).toBe(1.18);
    expect(C.gapMult(C.Difficulty.NORMAL)).toBe(1);
    expect(C.gapMult(C.Difficulty.DIFICIL)).toBe(0.88);
    expect(C.speedMult(C.Difficulty.FACIL)).toBe(0.85);
    expect(C.speedMult(C.Difficulty.NORMAL)).toBe(1);
    expect(C.speedMult(C.Difficulty.DIFICIL)).toBe(1.15);
    expect(C.gapMult(-5 as unknown as C.Difficulty)).toBe(1.18);
    expect(C.gapMult(99 as unknown as C.Difficulty)).toBe(0.88);
    expect(C.speedMult(99 as unknown as C.Difficulty)).toBe(1.15);
  });

  it('movingPipeChance arranca en el mínimo y acaba en el máximo', () => {
    expect(C.movingPipeChance(C.MOVING_PIPE_MIN_SCORE - 1)).toBe(0);
    expect(C.movingPipeChance(C.MOVING_PIPE_MIN_SCORE)).toBeCloseTo(
      C.MOVING_PIPE_CHANCE_MIN,
      10,
    );
    expect(C.movingPipeChance(C.DIFFICULTY_CAP)).toBeCloseTo(C.MOVING_PIPE_CHANCE_MAX, 10);
    expect(C.movingPipeChance(C.DIFFICULTY_CAP + 50)).toBeCloseTo(
      C.MOVING_PIPE_CHANCE_MAX,
      10,
    );
    const t = (22 - C.MOVING_PIPE_MIN_SCORE) / (C.DIFFICULTY_CAP - C.MOVING_PIPE_MIN_SCORE);
    expect(C.movingPipeChance(22)).toBeCloseTo(
      C.MOVING_PIPE_CHANCE_MIN + (C.MOVING_PIPE_CHANCE_MAX - C.MOVING_PIPE_CHANCE_MIN) * t,
      10,
    );
  });

  it('spinPipeChance igual con sus constantes', () => {
    expect(C.spinPipeChance(C.SPIN_PIPE_MIN_SCORE - 1)).toBe(0);
    expect(C.spinPipeChance(C.SPIN_PIPE_MIN_SCORE)).toBeCloseTo(
      C.SPIN_PIPE_CHANCE_MIN,
      10,
    );
    expect(C.spinPipeChance(C.DIFFICULTY_CAP)).toBeCloseTo(C.SPIN_PIPE_CHANCE_MAX, 10);
    const t = (20 - C.SPIN_PIPE_MIN_SCORE) / (C.DIFFICULTY_CAP - C.SPIN_PIPE_MIN_SCORE);
    expect(C.spinPipeChance(20)).toBeCloseTo(
      C.SPIN_PIPE_CHANCE_MIN + (C.SPIN_PIPE_CHANCE_MAX - C.SPIN_PIPE_CHANCE_MIN) * t,
      10,
    );
  });
});

describe('GameConfig · aliento, nombre y medallas', () => {
  it('pantLevel distingue agotado, jadeo y normal', () => {
    expect(C.pantLevel(50, 0)).toBe(C.Pant.NINGUNO);
    expect(C.pantLevel(0, 100)).toBe(C.Pant.AGOTADO);
    expect(C.pantLevel(-1, 100)).toBe(C.Pant.AGOTADO);
    expect(C.pantLevel(20, 100)).toBe(C.Pant.JADEO);
    expect(C.pantLevel(C.BREATH_LOW_RATIO * 100, 100)).toBe(C.Pant.NINGUNO);
    expect(C.pantLevel(100, 100)).toBe(C.Pant.NINGUNO);
  });

  it('pantTintWeight sube al bajar el aliento', () => {
    expect(C.pantTintWeight(50, 0)).toBe(0);
    expect(C.pantTintWeight(100, 100)).toBe(0);
    expect(C.pantTintWeight(0, 100)).toBeCloseTo(C.PANT_TINT_MAX, 10);
    const hundido = 1 - (C.BREATH_LOW_RATIO / 2) / C.BREATH_LOW_RATIO;
    expect(C.pantTintWeight(C.BREATH_LOW_RATIO * 50, 100)).toBeCloseTo(
      hundido * C.PANT_TINT_MAX,
      10,
    );
  });

  it('sanitizePlayerName limpia controles y colapsa espacios', () => {
    expect(C.sanitizePlayerName('a\u0001b')).toBe('a b');
    expect(C.sanitizePlayerName('a\u007fb')).toBe('a b');
    expect(C.sanitizePlayerName('a   b')).toBe('a b');
    expect(C.sanitizePlayerName('  hola  ')).toBe('hola');
    expect(C.sanitizePlayerName('a'.repeat(30))).toHaveLength(C.PLAYER_NAME_MAX_LEN);
    expect(C.sanitizePlayerName('aaaaaaaaaaa b')).toBe('aaaaaaaaaaa');
  });

  it('displayPlayerName cae al nombre por defecto', () => {
    expect(C.displayPlayerName('')).toBe(C.PLAYER_NAME_DEFAULT);
    expect(C.displayPlayerName('   ')).toBe(C.PLAYER_NAME_DEFAULT);
    expect(C.displayPlayerName('Ana')).toBe('Ana');
  });

  it('confianza y aliento máximo', () => {
    expect(C.confidenceLevel(0)).toBe(0);
    expect(C.confidenceLevel(49)).toBe(4);
    expect(C.confidenceLevel(50)).toBe(5);
    expect(C.confidenceLevel(999)).toBe(C.CONFIDENCE_MAX_LEVEL);
    expect(C.maxBreathFor(0)).toBe(C.MAX_BREATH);
    expect(C.maxBreathFor(1)).toBe(C.MAX_BREATH + C.CONFIDENCE_BREATH_BONUS);
    expect(C.maxBreathFor(99)).toBe(
      C.MAX_BREATH + C.CONFIDENCE_MAX_LEVEL * C.CONFIDENCE_BREATH_BONUS,
    );
    expect(C.maxBreathFor(-1)).toBe(C.MAX_BREATH);
  });

  it('fatiga y medallas', () => {
    expect(C.fatigueImpulseMult(4)).toBe(1);
    expect(C.fatigueImpulseMult(5)).toBeCloseTo(1 - C.FATIGUE_PENALTY, 10);
    expect(C.isFatigued(4)).toBe(false);
    expect(C.isFatigued(5)).toBe(true);
    expect(C.medalFor(9)).toBe(C.Medal.NINGUNA);
    expect(C.medalFor(10)).toBe(C.Medal.CROQUETA);
    expect(C.medalFor(19)).toBe(C.Medal.CROQUETA);
    expect(C.medalFor(20)).toBe(C.Medal.TORTILLA);
    expect(C.medalFor(39)).toBe(C.Medal.TORTILLA);
    expect(C.medalFor(40)).toBe(C.Medal.JAMON);
    expect(C.medalName(C.Medal.JAMON)).toBe('Jamón');
    expect(C.medalName(C.Medal.TORTILLA)).toBe('Tortilla');
    expect(C.medalName(C.Medal.CROQUETA)).toBe('Croqueta');
    expect(C.medalName(C.Medal.NINGUNA)).toBe('');
    expect(C.medalTextureName(C.Medal.JAMON)).toBe('medal_jamon');
    expect(C.medalTextureName(C.Medal.TORTILLA)).toBe('medal_tortilla');
    expect(C.medalTextureName(C.Medal.CROQUETA)).toBe('medal_croqueta');
    expect(C.medalTextureName(C.Medal.NINGUNA)).toBe('');
  });

  it('nombres de dificultad y espaciado', () => {
    expect(C.difficultyName(C.Difficulty.FACIL)).toBe('Fácil');
    expect(C.difficultyName(C.Difficulty.NORMAL)).toBe('Normal');
    expect(C.difficultyName(C.Difficulty.DIFICIL)).toBe('Difícil');
    expect(C.difficultyName(99 as unknown as C.Difficulty)).toBe('Normal');
    expect(C.pipeSpawnInterval()).toBeCloseTo(C.PIPE_SPACING / C.SCROLL_SPEED, 10);
  });
});

describe('GameConfig · códigos y fechas', () => {
  it('codigoModulo y round trip de semilla', () => {
    expect(C.codigoModulo()).toBe(Math.pow(C.CODIGO_ALFABETO.length, C.CODIGO_LARGO));
    const codigo = C.seedACodigo(12345);
    expect(codigo).toHaveLength(C.CODIGO_LARGO);
    expect(C.codigoASeed(codigo)).toBe(12345);
    expect(C.codigoASeed(`  ${codigo.toUpperCase()}  `)).toBe(12345);
    expect(C.codigoASeed('abc')).toBe(-1);
    expect(C.codigoASeed('abc$e')).toBe(-1);
  });

  it('dailySeed, dailyKey y dailyName', () => {
    expect(C.dailySeed(2026, 9, 14)).toBe(20260914);
    expect(C.dailyKey(2026, 9, 14)).toBe('daily_20260914');
    expect(C.dailyName(9, 14)).toBe('14 de septiembre');
    expect(C.dailyName(12, 31)).toBe('31 de diciembre');
    expect(C.dailyName(0, 5)).toBe('5/0');
    expect(C.dailyName(13, 5)).toBe('5/13');
  });
});

describe('GameConfig · planeo y tuberías', () => {
  it('showGlidePictogram y showGlideHint', () => {
    expect(C.showGlidePictogram(false, 0)).toBe(true);
    expect(C.showGlidePictogram(false, C.GLIDE_HINT_MAX_GAMES - 1)).toBe(true);
    expect(C.showGlidePictogram(false, C.GLIDE_HINT_MAX_GAMES)).toBe(false);
    expect(C.showGlidePictogram(true, 0)).toBe(false);
    expect(C.showGlideHint(false, 0, C.GLIDE_HINT_AFTER_GAPS)).toBe(true);
    expect(C.showGlideHint(false, 0, C.GLIDE_HINT_AFTER_GAPS - 1)).toBe(false);
    expect(C.showGlideHint(true, 0, 99)).toBe(false);
    expect(C.showGlideHint(false, C.GLIDE_HINT_MAX_GAMES, 99)).toBe(false);
  });

  it('breathBandHalf y playableHeight', () => {
    expect(C.playableHeight()).toBe(C.VIEWPORT_HEIGHT - C.GROUND_HEIGHT);
    expect(C.breathBandHalf(100)).toBeCloseTo(100 * C.BREATH_BAND_RATIO * 0.5, 10);
  });

  it('movingPipeAmplitude acota a la zona jugable', () => {
    expect(C.movingPipeAmplitude(40, 30)).toBeCloseTo(10, 10);
    expect(C.movingPipeAmplitude(40, 418)).toBeCloseTo(10, 10);
    expect(C.movingPipeAmplitude(118, C.playableHeight() / 2)).toBeCloseTo(
      C.MOVING_PIPE_AMPLITUDE,
      10,
    );
    expect(C.movingPipeAmplitude(100, 10)).toBe(0);
  });

  it('movingPipePeakSpeed es la derivada de la sinusoide', () => {
    expect(C.movingPipePeakSpeed(C.MOVING_PIPE_AMPLITUDE)).toBeCloseTo(
      (C.MOVING_PIPE_AMPLITUDE * Math.PI * 2) / C.MOVING_PIPE_PERIOD,
      10,
    );
    expect(C.movingPipePeakSpeed(0)).toBe(0);
  });

  it('isSoftPipe marca cada SOFT_PIPE_INTERVAL', () => {
    expect(C.isSoftPipe(0)).toBe(false);
    expect(C.isSoftPipe(-1)).toBe(false);
    expect(C.isSoftPipe(1)).toBe(false);
    expect(C.isSoftPipe(C.SOFT_PIPE_INTERVAL)).toBe(true);
    expect(C.isSoftPipe(C.SOFT_PIPE_INTERVAL * 2)).toBe(true);
    expect(C.isSoftPipe(C.SOFT_PIPE_INTERVAL + 1)).toBe(false);
  });
});

describe('GameConfig · layout y viento', () => {
  it('windowScaleFor: fraccional, entero y topes', () => {
    expect(C.windowScaleFor(576, 1024)).toBe(2);
    expect(C.windowScaleFor(1152, 2048)).toBe(4);
    expect(C.windowScaleFor(2000, 600)).toBeCloseTo(1.171875, 10);
    expect(C.windowScaleFor(2000, 600, true)).toBeCloseTo(1.171875, 10);
    expect(C.windowScaleFor(700, 1300)).toBe(2);
    expect(C.windowScaleFor(700, 1300, true)).toBeCloseTo(700 / 288, 10);
    expect(C.windowScaleFor(5000, 5000)).toBe(C.MAX_WINDOW_SCALE);
    expect(C.windowScaleFor(0, 100)).toBe(C.MIN_WINDOW_SCALE);
    expect(C.windowScaleFor(100, 0)).toBe(C.MIN_WINDOW_SCALE);
  });

  it('playfieldRectFor y layoutMarginFor centran el campo', () => {
    expect(C.playfieldRectFor(1000, 600, 2)).toEqual({
      x: Math.floor((1000 - 576) / 2),
      y: Math.floor((600 - 1024) / 2),
      w: 576,
      h: 1024,
    });
    expect(C.layoutMarginFor(1000, 600, 2)).toEqual({ x: 212, y: 0 });
    expect(C.layoutMarginFor(2000, 2000, 1)).toEqual({ x: 856, y: 744 });
  });

  it('windFactorFor respeta el sobre y elige la dirección con margen', () => {
    expect(C.windFactorFor(0, C.Difficulty.NORMAL, false)).toBeCloseTo(1.25, 10);
    expect(C.windFactorFor(0, C.Difficulty.NORMAL, true)).toBeCloseTo(1.25, 10);
    expect(C.windFactorFor(30, C.Difficulty.NORMAL, false)).toBeCloseTo(0.8, 10);
    expect(C.windFactorFor(30, C.Difficulty.NORMAL, true)).toBeCloseTo(0.8, 10);
  });

  it('windSpeedFor acota al rango de la curva', () => {
    expect(C.windSpeedFor(0, C.Difficulty.NORMAL, 1.1)).toBeCloseTo(110, 10);
    expect(C.windSpeedFor(0, C.Difficulty.NORMAL, 2)).toBeCloseTo(
      C.scrollSpeedFor(30),
      10,
    );
    expect(C.windSpeedFor(30, C.Difficulty.NORMAL, 0.5)).toBeCloseTo(
      C.scrollSpeedFor(0),
      10,
    );
  });
});
