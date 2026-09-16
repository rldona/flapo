import { beforeEach, describe, expect, it } from 'vitest';
import { seedACodigo } from '../src/config/GameConfig';
import { Game } from '../src/core/Game';
import type { Input } from '../src/core/Input';
import { DeathCause, GameState } from '../src/core/types';
import { SaveManager } from '../src/meta/SaveManager';

/**
 * Determinismo del replay: una partida grabada por `ReplayRecorder` (semilla +
 * flancos del botón por frame) se re-simula desde cero y debe dar **el mismo
 * score y las mismas tuberías**. Es la garantía que hace útiles los replays y
 * los códigos de partida.
 */

const KEY_REPLAY = 'flapo.replay.v1';

interface ReplayData {
  version: number;
  semilla: number;
  modo: number;
  confianza: number;
  record: number;
  espejo: boolean;
  score: number;
  frames: number[];
  pulsado: number[];
}

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

/** Mismo piloto que `simulation.test.ts`: apunta al centro del hueco siguiente. */
function grabar(game: Game, press: (v: boolean) => void, frames: number): number[] {
  const gaps: number[] = [];
  const vistos = new Set<object>();
  let cooldown = 0;
  for (let i = 0; i < frames; i++) {
    const estado = game.getState();
    if (estado === GameState.GAME_OVER) break;
    if (estado === GameState.READY) {
      press(true);
    } else if (estado === GameState.PLAYING) {
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
    registrarGaps(game, gaps, vistos);
  }
  return gaps;
}

/** Re-simula aplicando los flancos grabados, sin mirar el estado del juego. */
function rejugar(game: Game, press: (v: boolean) => void, replay: ReplayData, frames: number): number[] {
  const gaps: number[] = [];
  const vistos = new Set<object>();
  let indice = 0;
  let pulsado = false;
  for (let f = 0; f < frames; f++) {
    while (indice < replay.frames.length && replay.frames[indice] === f) {
      pulsado = replay.pulsado[indice] === 1;
      indice++;
    }
    press(pulsado);
    if (game.getState() === GameState.GAME_OVER) break;
    game.update(1 / 60);
    registrarGaps(game, gaps, vistos);
  }
  return gaps;
}

function registrarGaps(game: Game, gaps: number[], vistos: Set<object>): void {
  for (const p of game.pipeSpawner.pipes) {
    if (!vistos.has(p)) {
      vistos.add(p);
      gaps.push(Math.round(p.baseGapCenter * 1000));
    }
  }
}

describe('integración · replay determinista', () => {
  beforeEach(storageNueva);

  it('una partida grabada se reproduce con el mismo score y tuberías', () => {
    const semilla = 424242;
    const code = seedACodigo(semilla);

    // --- Grabación ---
    const a = fakeInput();
    const gameA = new Game(a.input);
    gameA.initSession();
    expect(gameA.startCode(code)).toBe(true);
    const gapsA = grabar(gameA, a.press, 1800);
    if (gameA.getState() !== GameState.GAME_OVER) gameA.bird.die(DeathCause.SUELO, false);
    const scoreGrabado = gameA.getScore();

    const replay = JSON.parse(
      localStorage.getItem(KEY_REPLAY) ?? 'null',
    ) as ReplayData | null;
    expect(replay).not.toBeNull();
    expect(scoreGrabado).toBeGreaterThan(0);
    expect(replay?.semilla).toBe(semilla);
    expect(replay?.score).toBe(scoreGrabado);
    expect(replay?.frames.length ?? 0).toBeGreaterThan(0);

    // --- Reproducción desde la semilla + flancos ---
    storageNueva();
    const b = fakeInput();
    const gameB = new Game(b.input);
    gameB.initSession();
    gameB.session.setDifficulty(replay!.modo);
    gameB.session.setMirror(replay!.espejo);
    expect(gameB.startCode(seedACodigo(replay!.semilla))).toBe(true);
    const gapsB = rejugar(gameB, b.press, replay!, 1800);

    expect(gameB.getScore()).toBe(scoreGrabado);
    expect(gapsB).toEqual(gapsA);
  });

  it('dos partidas con la misma semilla y entradas son idénticas', () => {
    const code = seedACodigo(777);

    const a = fakeInput();
    const gameA = new Game(a.input);
    gameA.initSession();
    gameA.startCode(code);
    const gapsA = grabar(gameA, a.press, 900);

    storageNueva();
    const b = fakeInput();
    const gameB = new Game(b.input);
    gameB.initSession();
    gameB.startCode(code);
    const gapsB = grabar(gameB, b.press, 900);

    expect(gapsB).toEqual(gapsA);
    expect(gameB.getScore()).toBe(gameA.getScore());
  });
});
