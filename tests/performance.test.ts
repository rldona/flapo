import { beforeAll, describe, expect, it } from 'vitest';
import { seedACodigo } from '../src/config/GameConfig';
import { Game } from '../src/core/Game';
import type { Input } from '../src/core/Input';
import { GameState } from '../src/core/types';
import { SaveManager } from '../src/meta/SaveManager';

/**
 * Presupuesto de rendimiento del bucle: el coste medio de un tick debe quedar
 * muy por debajo de los 16,7 ms de un frame a 60 Hz, y el mundo debe podar las
 * tuberías y frutas que salen de pantalla (sin crecimiento sin límite).
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

function storageNueva(): void {
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

/** Avanza `frames` ticks manteniendo la partida viva (reinicia si muere). */
function avanzar(game: Game, press: (v: boolean) => void, frames: number): void {
  let cooldown = 0;
  for (let i = 0; i < frames; i++) {
    if (game.getState() === GameState.GAME_OVER) game.restart();
    if (game.getState() === GameState.READY) {
      press(true);
    } else if (game.getState() === GameState.PLAYING) {
      cooldown -= 1 / 60;
      const siguiente = game.pipeSpawner.pipes
        .filter((p) => p.x + p.width / 2 > game.bird.x)
        .sort((a, b) => a.x - b.x)[0];
      const objetivo = siguiente ? siguiente.gapCenter : 256;
      if (game.bird.y > objetivo && cooldown <= 0) {
        press(true);
        cooldown = 0.12;
      } else {
        press(false);
      }
    } else {
      press(false);
    }
    game.update(1 / 60);
  }
}

function nueva(semilla: number): { game: Game; press: (v: boolean) => void } {
  const { input, press } = fakeInput();
  const game = new Game(input);
  game.initSession();
  game.startCode(seedACodigo(semilla));
  return { game, press };
}

describe('rendimiento', () => {
  beforeAll(storageNueva);

  it('el coste medio de un tick queda muy por debajo de un frame', () => {
    storageNueva();
    const { game, press } = nueva(424242);
    avanzar(game, press, 120); // calentar JIT

    const N = 1500;
    const t0 = performance.now();
    avanzar(game, press, N);
    const porTick = (performance.now() - t0) / N;
    expect(porTick).toBeLessThan(4);
  });

  it('las tuberías y frutas se podan y no crecen sin límite', () => {
    storageNueva();
    const { game, press } = nueva(999);
    avanzar(game, press, 4000);
    expect(game.pipeSpawner.pipes.length).toBeLessThan(20);
    expect(game.fruitSpawner.fruits.length).toBeLessThan(20);
  });
});
