import fc from 'fast-check';
import { beforeAll, describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { Game } from '../src/core/Game';
import type { Input } from '../src/core/Input';
import { DeathCause, GameState } from '../src/core/types';
import { SaveManager } from '../src/meta/SaveManager';
import { Effects, EffectKind } from '../src/systems/Effects';

/**
 * Fuzz de la simulación: en lugar de partidas guionizadas, se generan
 * secuencias aleatorias de aleteos y deltas de tiempo y se comprueba que el
 * mundo nunca se rompe (NaN, estados imposibles, puntuaciones negativas).
 */

class MemStorage {
  private map = new Map<string, string>();
  getItem(k: string): string | null {
    return this.map.has(k) ? (this.map.get(k) as string) : null;
  }
  setItem(k: string, v: string): void {
    this.map.set(k, String(v));
  }
  removeItem(k: string): void {
    this.map.delete(k);
  }
  clear(): void {
    this.map.clear();
  }
}

function localStorageNueva(): void {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
  SaveManager.forgetCache();
  SaveManager.clear();
}

function fakeInput(): { input: Input; press: (v: boolean) => void } {
  let held = false;
  let just = false;
  const stub = {
    enabled: true,
    isFlapPressed: () => held,
    consumeFlapJust: () => {
      const v = just;
      just = false;
      return v;
    },
    consumeRestart: () => false,
    consumePause: () => false,
  } as unknown as Input;
  return {
    input: stub,
    press: (v: boolean) => {
      if (v && !held) just = true;
      held = v;
    },
  };
}

const ESTADOS = [GameState.MENU, GameState.READY, GameState.PLAYING, GameState.GAME_OVER];

describe('property · fuzz de la partida', () => {
  beforeAll(localStorageNueva);

  it('cualquier secuencia de aleteos deja el mundo finito y válido', () => {
    fc.assert(
      fc.property(
        fc.array(
          fc.record({
            flap: fc.boolean(),
            dt: fc.double({ min: 1 / 240, max: 1 / 30, noNaN: true }),
          }),
          { minLength: 1, maxLength: 400 },
        ),
        (frames) => {
          localStorageNueva();
          const { input, press } = fakeInput();
          const game = new Game(input);
          game.initSession();
          game.startFree();
          for (const frame of frames) {
            press(frame.flap);
            game.update(frame.dt);
            expect(ESTADOS).toContain(game.getState());
            expect(Number.isFinite(game.bird.x)).toBe(true);
            expect(Number.isFinite(game.bird.y)).toBe(true);
            expect(Number.isFinite(game.bird.vy)).toBe(true);
            expect(game.getScore()).toBeGreaterThanOrEqual(0);
            if (game.getState() === GameState.GAME_OVER) game.restart();
          }
          return true;
        },
      ),
      { numRuns: 50 },
    );
  });

  it('al morir, el pájaro siempre acaba contra el suelo y no lo atraviesa', () => {
    fc.assert(
      fc.property(fc.integer({ min: 1, max: 240 }), (pasos) => {
        localStorageNueva();
        const { input } = fakeInput();
        const game = new Game(input);
        game.initSession();
        game.startFree();
        game.changeState(GameState.PLAYING);
        game.bird.y = C.playableHeight() - game.bird.baseRadius - 1;
        game.bird.vy = C.MAX_FALL_SPEED;
        game.bird.die(DeathCause.SUELO, false);
        for (let i = 0; i < pasos; i++) game.update(1 / 60);
        const suelo = C.playableHeight() - game.bird.baseRadius * game.bird.hitboxMult;
        return game.bird.y <= suelo + 1e-6;
      }),
      { numRuns: 50 },
    );
  });
});

describe('property · Effects', () => {
  it('mantiene un efecto por eje, escudos acotados y duraciones válidas', () => {
    fc.assert(
      fc.property(fc.array(fc.integer({ min: 0, max: 5 }), { maxLength: 40 }), (kinds) => {
        const fx = new Effects();
        for (const k of kinds) fx.apply(k as EffectKind);
        expect(fx.shieldCount()).toBeGreaterThanOrEqual(0);
        expect(fx.shieldCount()).toBeLessThanOrEqual(C.SHIELD_MAX);
        expect(fx.activo(EffectKind.PESADO) && fx.activo(EffectKind.LIGERO)).toBe(false);
        for (const [, t] of fx.activos()) {
          expect(t).toBeGreaterThan(0);
          expect(t).toBeLessThanOrEqual(fx.duration);
        }
      }),
      { numRuns: 200 },
    );
  });
});
