import { Difficulty, SEED_ALEATORIA } from '../config/GameConfig';
import type { Input } from '../core/Input';
import { GameState } from '../core/types';

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

const KEY = 'flapo.replay.v1';
const VERSION = 3;
const MAX_EVENTOS = 100000;

/**
 * Port de `replay_recorder.gd` (T-261). Graba flancos del botón por frame de
 * física; con la física fija y el RNG sembrado basta para reproducir la
 * partida. El reproductor vive fuera del juego; aquí solo se graba.
 */
export class ReplayRecorder {
  private frame = 0;
  private activo = false;
  private ultimo = false;
  private data: ReplayData = this.vacia();

  constructor(private readonly input: Input) {}

  private vacia(): ReplayData {
    return {
      version: VERSION,
      semilla: SEED_ALEATORIA,
      modo: Difficulty.NORMAL,
      confianza: 0,
      record: 0,
      espejo: false,
      score: 0,
      frames: [],
      pulsado: [],
    };
  }

  preparar(
    semilla: number,
    modo: Difficulty,
    confianza: number,
    record: number,
    espejo: boolean,
  ): void {
    this.data = this.vacia();
    this.data.semilla = semilla;
    this.data.modo = modo;
    this.data.confianza = confianza;
    this.data.record = record;
    this.data.espejo = espejo;
    this.frame = 0;
    this.ultimo = false;
  }

  onStateChanged(to: GameState): void {
    if (to === GameState.MENU || to === GameState.READY) {
      this.activo = false;
      this.frame = 0;
      this.ultimo = false;
    } else if (to === GameState.PLAYING) {
      this.activo = true;
    } else {
      this.activo = false;
    }
  }

  update(): void {
    if (!this.activo) return;
    const ahora = this.input.isFlapPressed();
    if (ahora !== this.ultimo) {
      if (this.data.frames.length < MAX_EVENTOS) {
        this.data.frames.push(this.frame);
        this.data.pulsado.push(ahora ? 1 : 0);
      }
      this.ultimo = ahora;
    }
    this.frame++;
  }

  terminar(score: number): void {
    this.data.score = score;
    try {
      localStorage.setItem(KEY, JSON.stringify(this.data));
    } catch {
      /* nunca reventar: un replay es un extra, no un requisito */
    }
  }
}
