import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import * as C from '../src/config/GameConfig';
import { Game } from '../src/core/Game';
import type { Input } from '../src/core/Input';
import { DeathCause, GameState } from '../src/core/types';
import { SaveManager } from '../src/meta/SaveManager';
import { EffectKind } from '../src/systems/Effects';
import { Fruit } from '../src/systems/Fruit';

/**
 * Integración de la máquina de estados: transiciones legales e ilegales,
 * efectos colaterales (reset, espejo, dificultad), pausa, escudo, frutas y
 * tolerancia a fallos del entorno (localStorage/crypto).
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

class FalloStorage extends MemStorage {
  override getItem(): string | null {
    throw new Error('localStorage no disponible');
  }
  override setItem(): void {
    throw new Error('disco lleno');
  }
}

function almacen(storage: MemStorage): void {
  (globalThis as unknown as { localStorage: MemStorage }).localStorage = storage;
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

function nuevaPartida(): Game {
  const { input } = fakeInput();
  const game = new Game(input);
  game.initSession();
  game.startFree();
  return game;
}

beforeEach(() => {
  almacen(new MemStorage());
  SaveManager.forgetCache();
  SaveManager.clear();
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('integración · transiciones de estado', () => {
  it('arranca en MENU y startFree lo lleva a READY', () => {
    const { input } = fakeInput();
    const game = new Game(input);
    expect(game.getState()).toBe(GameState.MENU);
    game.initSession();
    game.startFree();
    expect(game.getState()).toBe(GameState.READY);
  });

  it('READY -> PLAYING crea la primera tubería', () => {
    const game = nuevaPartida();
    expect(game.pipeSpawner.pipes).toHaveLength(0);
    game.changeState(GameState.PLAYING);
    expect(game.getState()).toBe(GameState.PLAYING);
    expect(game.pipeSpawner.pipes.length).toBeGreaterThan(0);
  });

  it('al morir pasa a GAME_OVER y registra la partida', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.bird.die(DeathCause.TUBERIA, false);
    expect(game.getState()).toBe(GameState.GAME_OVER);
    expect(SaveManager.getGamesPlayed()).toBe(1);
  });

  it('rechaza una transición ilegal con un aviso y sin cambiar de estado', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.bird.die(DeathCause.SUELO, false);
    game.changeState(GameState.PLAYING);
    expect(game.getState()).toBe(GameState.GAME_OVER);
    expect(warn).toHaveBeenCalled();
  });

  it('MENU no salta directamente a PLAYING', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const { input } = fakeInput();
    const game = new Game(input);
    game.initSession();
    game.changeState(GameState.PLAYING);
    expect(game.getState()).toBe(GameState.MENU);
    expect(warn).toHaveBeenCalled();
  });

  it('restart vuelve a READY y toMenu vuelve a MENU', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.bird.die(DeathCause.SUELO, false);
    game.restart();
    expect(game.getState()).toBe(GameState.READY);
    game.toMenu();
    expect(game.getState()).toBe(GameState.MENU);
  });
});

describe('integración · efectos colaterales del estado', () => {
  it('volver a MENU limpia efectos, escudos y puntuación', () => {
    const game = nuevaPartida();
    game.effects.apply(EffectKind.INMUNIDAD);
    game.effects.apply(EffectKind.LENTO);
    game.toMenu();
    expect(game.getState()).toBe(GameState.MENU);
    expect(game.effects.activos()).toEqual([]);
    expect(game.effects.shieldCount()).toBe(0);
    expect(game.getScore()).toBe(0);
  });

  it('READY reinicia el pájaro a su posición de partida', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.bird.y = 400;
    game.bird.die(DeathCause.SUELO, false);
    game.restart();
    expect(game.getState()).toBe(GameState.READY);
    expect(game.bird.y).toBe(game.bird.startY);
    expect(game.bird.vy).toBe(0);
    expect(game.bird.isDead).toBe(false);
  });

  it('READY aplica el modo espejo de la sesión', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.session.setMirror(true);
    game.bird.die(DeathCause.SUELO, false);
    game.restart();
    expect(game.bird.mirror).toBe(true);
  });

  it('aplica la dificultad elegida al mundo', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.session.setDifficulty(C.Difficulty.FACIL);
    game.bird.die(DeathCause.SUELO, false);
    game.restart();
    expect(game.pipeSpawner.scrollSpeed).toBeCloseTo(
      C.scrollSpeedFor(0, C.Difficulty.FACIL),
      5,
    );
    game.changeState(GameState.PLAYING);
    game.session.setDifficulty(C.Difficulty.DIFICIL);
    game.bird.die(DeathCause.SUELO, false);
    game.restart();
    expect(game.pipeSpawner.scrollSpeed).toBeCloseTo(
      C.scrollSpeedFor(0, C.Difficulty.DIFICIL),
      5,
    );
  });
});

describe('integración · pausa', () => {
  it('setPaused solo tiene efecto en PLAYING', () => {
    const game = nuevaPartida();
    game.setPaused(true);
    expect(game.isPaused()).toBe(false);
    game.changeState(GameState.PLAYING);
    game.setPaused(true);
    expect(game.isPaused()).toBe(true);
    game.setPaused(false);
    expect(game.isPaused()).toBe(false);
  });

  it('pausado, la simulación se congela', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.setPaused(true);
    const y = game.bird.y;
    for (let i = 0; i < 60; i++) game.update(1 / 60);
    expect(game.bird.y).toBe(y);
    game.setPaused(false);
    game.update(1 / 60);
    expect(game.bird.y).toBeGreaterThan(y);
  });
});

describe('integración · escudo y frutas', () => {
  it('un escudo absorbe el golpe contra el suelo y el pájaro sigue vivo', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.effects.apply(EffectKind.INMUNIDAD);
    expect(game.effects.shieldCount()).toBe(1);

    game.bird.y = C.playableHeight() - 1;
    game.bird.vy = C.MAX_FALL_SPEED;
    game.update(1 / 60);

    expect(game.effects.shieldCount()).toBe(0);
    expect(game.bird.isDead).toBe(false);
    expect(game.getState()).toBe(GameState.PLAYING);
  });

  it('sin escudo, el mismo golpe mata', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    game.bird.y = C.playableHeight() - 1;
    game.bird.vy = C.MAX_FALL_SPEED;
    game.update(1 / 60);
    expect(game.getState()).toBe(GameState.GAME_OVER);
  });

  it('recoger una fruta aplica su efecto y ajusta el pájaro', () => {
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    const fruta = new Fruit();
    fruta.kind = EffectKind.GRANDE;
    fruta.scrollSpeed = 0;
    fruta.place(game.bird.x, game.bird.y);
    game.fruitSpawner.fruits.push(fruta);

    game.update(1 / 60);

    expect(game.effects.activo(EffectKind.GRANDE)).toBe(true);
    expect(game.bird.sizeMult).toBeCloseTo(game.effects.bigSizeMult, 5);
    expect(game.bird.hitboxMult).toBeCloseTo(game.effects.bigHitboxMult, 5);
  });
});

describe('integración · tolerancia a fallos del entorno', () => {
  it('un localStorage que lanza no impide arrancar', () => {
    almacen(new FalloStorage());
    SaveManager.forgetCache();
    const { input } = fakeInput();
    const game = new Game(input);
    expect(() => game.initSession()).not.toThrow();
    expect(game.getHighScore()).toBe(0);
  });

  it('un setItem que lanza no impide morir ni reiniciar', () => {
    almacen(new FalloStorage());
    SaveManager.forgetCache();
    const game = nuevaPartida();
    game.changeState(GameState.PLAYING);
    expect(() => game.bird.die(DeathCause.TUBERIA, false)).not.toThrow();
    expect(() => game.restart()).not.toThrow();
    expect(game.getState()).toBe(GameState.READY);
  });

  it('arranca sin crypto (cae a Math.random)', () => {
    vi.stubGlobal('crypto', undefined);
    const game = nuevaPartida();
    expect(game.getState()).toBe(GameState.READY);
    expect(Number.isInteger(game.session.seed())).toBe(true);
  });

  it('arranca sin localStorage (usa los valores por defecto)', () => {
    delete (globalThis as unknown as { localStorage?: MemStorage }).localStorage;
    SaveManager.forgetCache();
    const game = nuevaPartida();
    expect(game.getState()).toBe(GameState.READY);
    expect(SaveManager.getHighScore()).toBe(0);
  });
});
