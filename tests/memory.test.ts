import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { seedACodigo } from '../src/config/GameConfig';
import { Game } from '../src/core/Game';
import { Input } from '../src/core/Input';
import { GameState } from '../src/core/types';
import { SaveManager } from '../src/meta/SaveManager';

/**
 * Memoria y fugas: tras muchos ciclos de partida las colecciones deben quedar
 * acotadas, y `Input` debe retirar exactamente los listeners que registró.
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

/** Juega y reinicia en bucle para provocar muchos ciclos de vida. */
function ciclar(game: Game, press: (v: boolean) => void, frames: number): number {
  let muertes = 0;
  let cooldown = 0;
  for (let i = 0; i < frames; i++) {
    if (game.getState() === GameState.GAME_OVER) {
      muertes++;
      game.restart();
    }
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
  return muertes;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('memoria · ciclos de partida', () => {
  beforeAll(storageNueva);

  it('tras muchos ciclos, las colecciones siguen acotadas', () => {
    storageNueva();
    const { input, press } = fakeInput();
    const game = new Game(input);
    game.initSession();
    game.startCode(seedACodigo(20260101));

    const muertes = ciclar(game, press, 12000);
    expect(muertes).toBeGreaterThan(3); // de verdad han pasado varios ciclos

    expect(game.pipeSpawner.pipes.length).toBeLessThan(20);
    expect(game.fruitSpawner.fruits.length).toBeLessThan(20);
    expect(game.air.thermals.length).toBeLessThan(20);
    expect(game.air.slips.length).toBeLessThan(20);
    expect(game.air.brothers.length).toBeLessThan(20);
    expect(game.effects.activos().length).toBeLessThanOrEqual(3);
  });

  it('al volver a READY se vacían aire y fantasma', () => {
    storageNueva();
    const { input, press } = fakeInput();
    const game = new Game(input);
    game.initSession();
    game.startCode(seedACodigo(555));
    ciclar(game, press, 1200);

    if (game.getState() !== GameState.GAME_OVER) game.bird.die(0, false);
    game.restart(); // GAME_OVER -> READY
    expect(game.air.thermals).toHaveLength(0);
    expect(game.air.slips).toHaveLength(0);
    expect(game.air.brothers).toHaveLength(0);
    expect(game.ghost.visible).toBe(false);
    expect(game.pipeSpawner.pipes).toHaveLength(0);
  });
});

describe('memoria · listeners de Input', () => {
  it('dispose retira exactamente los listeners registrados', () => {
    const registro = new Map<string, number>();
    const apunta = (signo: number) => (tipo: string) => {
      registro.set(tipo, (registro.get(tipo) ?? 0) + signo);
    };
    const surface = {
      addEventListener: apunta(1),
      removeEventListener: apunta(-1),
    };
    const win = {
      addEventListener: apunta(1),
      removeEventListener: apunta(-1),
    };
    vi.stubGlobal('window', win);

    const input = new Input(surface as unknown as HTMLElement);
    expect([...registro.values()].some((n) => n > 0)).toBe(true);
    input.dispose();
    expect([...registro.values()].every((n) => n === 0)).toBe(true);
  });

  it('crear y destruir muchos Input no acumula listeners', () => {
    const registro = new Map<string, number>();
    const apunta = (signo: number) => (tipo: string) => {
      registro.set(tipo, (registro.get(tipo) ?? 0) + signo);
    };
    vi.stubGlobal('window', {
      addEventListener: apunta(1),
      removeEventListener: apunta(-1),
    });
    const surface = {
      addEventListener: apunta(1),
      removeEventListener: apunta(-1),
    } as unknown as HTMLElement;

    for (let i = 0; i < 100; i++) new Input(surface).dispose();
    expect([...registro.values()].every((n) => n === 0)).toBe(true);
  });
});
