import { describe, expectTypeOf, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { Rng } from '../src/core/Rng';
import { SaveManager } from '../src/meta/SaveManager';
import { Assets, type AudioName, type SpriteName } from '../src/render/Assets';

/**
 * Contratos de tipos de la API pública. `expectTypeOf` no hace nada en tiempo de
 * ejecución: la comprobación real la hace `tsc` (incluido en `npm run typecheck`
 * y en CI), así que un cambio accidental de firma rompe aquí.
 */

describe('contratos · tipos', () => {
  it('las funciones de GameConfig mantienen sus firmas', () => {
    expectTypeOf(C.sanitizePlayerName).parameter(0).toBeString();
    expectTypeOf(C.sanitizePlayerName('')).toBeString();
    expectTypeOf(C.medalFor(0)).toEqualTypeOf<C.Medal>();
    expectTypeOf(C.pantLevel(0, 0)).toEqualTypeOf<C.Pant>();
    expectTypeOf(C.sceneryFor(0)).toEqualTypeOf<C.Scenery>();
    expectTypeOf(C.journeyStage(0)).toEqualTypeOf<C.Stage>();
    expectTypeOf(C.difficultyName(C.Difficulty.NORMAL)).toBeString();
    expectTypeOf(C.codigoASeed('00000')).toBeNumber();
    expectTypeOf(C.seedACodigo(0)).toBeString();
  });

  it('la persistencia devuelve los tipos esperados', () => {
    expectTypeOf(SaveManager.getDifficulty()).toEqualTypeOf<C.Difficulty>();
    expectTypeOf(SaveManager.getDailyHistory()).toEqualTypeOf<Array<[string, number]>>();
    expectTypeOf(SaveManager.getAverageScore()).toBeNumber();
    expectTypeOf(SaveManager.getPlayerName()).toBeString();
  });

  it('el RNG y los activos mantienen sus firmas', () => {
    expectTypeOf(new Rng().randf()).toBeNumber();
    expectTypeOf(new Rng().randiRange(0, 1)).toBeNumber();
    expectTypeOf(new Rng().randfRange(0, 1)).toBeNumber();
    expectTypeOf(Assets.spriteNames()).toEqualTypeOf<readonly SpriteName[]>();
    expectTypeOf(Assets.audioNames()).toEqualTypeOf<readonly AudioName[]>();
  });
});
