import { describe, expect, it } from 'vitest';
import * as C from '../src/config/GameConfig';
import { GameState } from '../src/core/types';
import { Bird, type BirdCallbacks } from '../src/systems/Bird';
import { PipeSpawner } from '../src/systems/PipeSpawner';
import { Snapshot } from '../src/systems/Snapshot';

function cb(): BirdCallbacks {
  return {
    onFlapped: () => {},
    onDied: () => {},
    onSoftHit: () => {},
    onBreathRecovered: () => {},
    onGlided: () => {},
    onBreathChanged: () => {},
    onFatigueChanged: () => {},
  };
}

function crear(): { snap: Snapshot; muestras: () => number } {
  const bird = new Bird(cb());
  const pipes = new PipeSpawner({ onPipeSpawned: () => {} });
  const snap = new Snapshot(bird, pipes);
  return { snap, muestras: () => (snap as unknown as { estela: unknown[] }).estela.length };
}

/** Cada cuántos frames toma una muestra (120 / SNAPSHOT_SAMPLES). */
const CADA = Math.max(Math.floor((C.SNAPSHOT_SECONDS * 60) / C.SNAPSHOT_SAMPLES), 1);

describe('Snapshot', () => {
  it('no muestrea si no está jugando', () => {
    const { snap, muestras } = crear();
    for (let i = 0; i < 100; i++) snap.update();
    expect(muestras()).toBe(0);
  });

  it('toma muestras cada CADA frames y se queda con SNAPSHOT_SAMPLES', () => {
    const { snap, muestras } = crear();
    snap.onStateChanged(GameState.PLAYING);
    for (let i = 0; i < CADA; i++) snap.update();
    expect(muestras()).toBe(1);

    for (let i = 0; i < CADA * (C.SNAPSHOT_SAMPLES + 5); i++) snap.update();
    expect(muestras()).toBe(C.SNAPSHOT_SAMPLES);
  });

  it('READY reinicia la estela y el conteo', () => {
    const { snap, muestras } = crear();
    snap.onStateChanged(GameState.PLAYING);
    for (let i = 0; i < CADA * 2; i++) snap.update();
    expect(muestras()).toBeGreaterThan(0);
    snap.onStateChanged(GameState.READY);
    expect(muestras()).toBe(0);
    snap.update();
    expect(muestras()).toBe(0); // ya no está activo
  });

  it('capturar devuelve null sin vuelo o sin document', () => {
    const { snap } = crear();
    expect(snap.capturar()).toBeNull();

    snap.onStateChanged(GameState.PLAYING);
    for (let i = 0; i < CADA; i++) snap.update();
    // En Node no hay `document`, así que no se puede componer el canvas.
    expect(snap.capturar()).toBeNull();
  });
});
