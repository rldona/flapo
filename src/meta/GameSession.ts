import {
  Difficulty,
  SEED_ALEATORIA,
  codigoASeed,
  codigoModulo,
  maxBreathFor,
  sanitizePlayerName,
  seedACodigo,
} from '../config/GameConfig';
import { Rng } from '../core/Rng';
import { DailyChallenge } from './DailyChallenge';
import { SaveManager } from './SaveManager';

export interface RngSink {
  setRng(rng: Rng): void;
}

/**
 * Port de `game_session.gd`: lo que una partida sabe de sí misma antes de
 * jugarse. Sale del guardado y no tiene nada que ver con el bucle de juego.
 */
export class GameSession {
  readonly rng = new Rng();
  readonly daily = new DailyChallenge();

  private _seed = 0;
  private _playerName = '';
  private _difficulty: Difficulty = Difficulty.NORMAL;
  private _confidence = 0;
  private _hasGlided = false;
  private _mirror = false;

  cargar(): void {
    this._difficulty = SaveManager.getDifficulty();
    this._playerName = SaveManager.getPlayerName();
    this._confidence = SaveManager.getConfidence();
    this._hasGlided = SaveManager.getHasGlided();
    this._mirror = SaveManager.getMirror();
  }

  seed(): number {
    return this._seed;
  }

  setSeed(semilla: number): void {
    this._seed = semilla;
  }

  codigo(): string {
    return seedACodigo(this._seed);
  }

  prepararLibre(): void {
    this.daily.parar();
    this._seed = SEED_ALEATORIA;
  }

  prepararReto(fecha: number[] = []): void {
    this.daily.empezar(fecha);
    this._seed = this.daily.semilla();
  }

  prepararCodigo(texto: string): boolean {
    const semilla = codigoASeed(texto);
    if (semilla < 0) return false;
    this.daily.parar();
    this._seed = semilla;
    return true;
  }

  /**
   * Siembra el generador y lo reparte. Con semilla 0 se sortea una **dentro
   * del espacio del código** (T-242) y se guarda, para poder volver a jugarla.
   */
  sembrar(piezas: Array<RngSink | null>): void {
    if (this._seed === SEED_ALEATORIA) {
      this.rng.randomize();
      this._seed = ((this.rng.seed % codigoModulo()) + codigoModulo()) % codigoModulo();
    }
    this.rng.seed = this._seed;
    for (const pieza of piezas) {
      if (pieza) pieza.setRng(this.rng);
    }
  }

  playerName(): string {
    return this._playerName;
  }

  setPlayerName(nombre: string): void {
    const limpio = sanitizePlayerName(nombre);
    if (limpio === this._playerName) return;
    this._playerName = limpio;
    SaveManager.setPlayerName(limpio);
  }

  difficulty(): Difficulty {
    return this._difficulty;
  }

  setDifficulty(modo: Difficulty): void {
    this._difficulty = modo;
    SaveManager.setDifficulty(modo);
  }

  mirror(): boolean {
    return this._mirror;
  }

  setMirror(activo: boolean): void {
    this._mirror = activo;
    SaveManager.setMirror(activo);
  }

  confidence(): number {
    return this._confidence;
  }

  maxBreath(): number {
    return maxBreathFor(this._confidence);
  }

  hasGlided(): boolean {
    return this._hasGlided;
  }

  marcarPlaneo(): void {
    if (this._hasGlided) return;
    this._hasGlided = true;
    SaveManager.setHasGlided();
  }

  registrarPartida(score: number): boolean {
    let record: boolean;
    if (this.daily.activo()) {
      record = SaveManager.recordDaily(this.daily.clave(), score);
      SaveManager.recordGame(score, false);
    } else {
      record = SaveManager.recordGame(score);
    }
    this._confidence = SaveManager.getConfidence();
    return record;
  }
}
