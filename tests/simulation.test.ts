import { beforeAll, describe, expect, it } from 'vitest';
import { Game } from '../src/core/Game';
import type { Input } from '../src/core/Input';
import { GameState } from '../src/core/types';
import { seedACodigo } from '../src/config/GameConfig';
import { SaveManager } from '../src/meta/SaveManager';

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

/** Autopiloto simple: mantiene a Flapo por encima del hueco siguiente. */
function jugar(
  game: Game,
  press: (v: boolean) => void,
  frames: number,
  guiado = false,
): number[] {
  const gaps: number[] = [];
  const vistos = new Set<object>();
  let cooldown = 0;
  for (let i = 0; i < frames; i++) {
    if (game.getState() === GameState.READY) {
      press(true);
    } else if (game.getState() === GameState.PLAYING) {
      cooldown -= 1 / 60;
      let objetivo = 280;
      if (guiado) {
        const siguiente = game.pipeSpawner.pipes
          .filter((p) => p.x + p.width / 2 > game.bird.x)
          .sort((a, b) => a.x - b.x)[0];
        objetivo = siguiente ? siguiente.gapCenter : 256;
      }
      if (game.bird.y > objetivo && cooldown <= 0) {
        press(true);
        cooldown = guiado ? 0.12 : 0.22;
      } else {
        press(false);
      }
    } else {
      press(false);
    }
    game.update(1 / 60);
    for (const p of game.pipeSpawner.pipes) {
      if (!vistos.has(p)) {
        vistos.add(p);
        gaps.push(Math.round(p.baseGapCenter * 1000));
      }
    }
  }
  return gaps;
}

describe('simulación headless', () => {
  beforeAll(() => {
    (globalThis as unknown as { localStorage: MemStorage }).localStorage = new MemStorage();
  });

  it('juega 30 segundos sin reventar', () => {
    const { input, press } = fakeInput();
    const game = new Game(input);
    game.initSession();
    game.startFree();
    jugar(game, press, 1800);
    expect([GameState.READY, GameState.PLAYING, GameState.GAME_OVER]).toContain(game.getState());
    expect(game.getScore()).toBeGreaterThanOrEqual(0);
  });

  it('con buen pilotaje cruza tuberías y puntúa', () => {
    const { input, press } = fakeInput();
    const game = new Game(input);
    game.initSession();
    game.startFree();
    jugar(game, press, 1800, true);
    expect(game.getScore()).toBeGreaterThan(0);
  });

  it('la misma semilla produce las mismas tuberías', () => {
    const code = seedACodigo(424242);
    localStorage.clear();
    SaveManager.forgetCache();
    const a = fakeInput();
    const gameA = new Game(a.input);
    gameA.initSession();
    expect(gameA.startCode(code)).toBe(true);
    const gapsA = jugar(gameA, a.press, 900);

    localStorage.clear();
    SaveManager.forgetCache();
    const b = fakeInput();
    const gameB = new Game(b.input);
    gameB.initSession();
    expect(gameB.startCode(code)).toBe(true);
    const gapsB = jugar(gameB, b.press, 900);

    expect(gapsA.length).toBeGreaterThanOrEqual(2);
    expect(gapsA).toEqual(gapsB);
  });

  it('el modo espejo invierte la gravedad', () => {
    const { input } = fakeInput();
    const game = new Game(input);
    game.initSession();
    game.session.setMirror(true);
    game.startFree();
    expect(game.bird.mirror).toBe(true);
    // Sin aletear: en espejo la gravedad empuja hacia arriba, así que la y baja.
    game.bird.onStateChanged(GameState.PLAYING);
    for (let i = 0; i < 30; i++) game.update(1 / 60);
    expect(game.bird.y).toBeLessThan(256);
    game.session.setMirror(false);
  });
});
