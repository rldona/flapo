import * as C from '../config/GameConfig';
import { type Scenery } from '../config/GameConfig';
import type { AudioDirector } from '../audio/AudioDirector';
import type { Input } from '../core/Input';
import type { Loop } from '../core/Loop';
import { Rng } from '../core/Rng';
import { DeathCause, GameState, circleRectOverlap } from '../core/types';
import type { Renderer } from '../render/Renderer';
import { AirSpawner } from '../systems/AirSpawner';
import { Background } from '../systems/Background';
import { Bird } from '../systems/Bird';
import { Buddy } from '../systems/Buddy';
import { DeathLines } from '../systems/DeathLines';
import { Effects, type EffectKind } from '../systems/Effects';
import { FruitSpawner } from '../systems/Fruit';
import { Ghost } from '../systems/Ghost';
import { Ground } from '../systems/Ground';
import { Journey } from '../systems/Journey';
import { Juice } from '../systems/Juice';
import { PipeSpawner } from '../systems/PipeSpawner';
import { ReplayRecorder } from '../systems/ReplayRecorder';
import { Snapshot } from '../systems/Snapshot';
import { Wind } from '../systems/Wind';
import { GameSession } from '../meta/GameSession';
import { SaveManager } from '../meta/SaveManager';
import type { UI } from '../ui/UI';

const TRANSITIONS: Record<GameState, GameState[]> = {
  [GameState.MENU]: [GameState.READY],
  [GameState.READY]: [GameState.PLAYING, GameState.MENU],
  [GameState.PLAYING]: [GameState.GAME_OVER],
  [GameState.GAME_OVER]: [GameState.READY, GameState.MENU],
};

const SHIELD_GRACE = 1.0;
const FADE_TIME = 0.25;

/**
 * Port de `main.gd`: raíz de la partida y dueña de la máquina de estados.
 * "Call down, signal up": el padre cablea, los hijos no se buscan entre sí.
 */
export class Game {
  readonly session = new GameSession();
  readonly bird: Bird;
  readonly pipeSpawner: PipeSpawner;
  readonly fruitSpawner: FruitSpawner;
  readonly effects = new Effects();
  readonly wind: Wind;
  readonly air = new AirSpawner();
  readonly journey: Journey;
  readonly ghost: Ghost;
  readonly buddy: Buddy;
  readonly snapshot: Snapshot;
  readonly replay: ReplayRecorder;
  readonly ground = new Ground();
  readonly background = new Background();
  readonly juice = new Juice();
  readonly deathLines = new DeathLines();

  private state: GameState = GameState.MENU;
  private score = 0;
  private highScore = 0;
  private isNewHighScore = false;
  private huecosSinPlanear = 0;
  private tramoUsado = false;
  private tramoScore = -1;
  private deathCause: DeathCause = DeathCause.SUELO;
  private deathBreathless = false;
  private readonly rngCosmetico = new Rng();
  private skyColor = C.SCENERY_SKY[0];
  private fadeLeft = 0;
  private lastEffectLine = '';
  private lastShield = -1;
  private lastFatigue = false;
  private paused = false;
  private pendingStartFlap = false;
  private gameOverDelay = 0;
  private gameOverShown = false;

  private loop: Loop | null = null;
  private renderer: Renderer | null = null;
  private ui: UI | null = null;
  private audio: AudioDirector | null = null;

  constructor(private readonly input: Input) {
    this.bird = new Bird({
      onFlapped: () => this.audio?.playFlap(),
      onDied: (cause, breathless) => this.onBirdDied(cause, breathless),
      onSoftHit: () => this.onSoftHit(),
      onBreathRecovered: () => this.audio?.playBreath(),
      onGlided: () => this.onGlided(),
      onBreathChanged: (actual, max) => this.ui?.setBreath(actual, max, this.lastFatigue),
      onFatigueChanged: (fatigued) => {
        this.lastFatigue = fatigued;
        this.ui?.setBreath(this.bird.breath, this.bird.maxBreath, fatigued);
      },
    });
    this.pipeSpawner = new PipeSpawner({
      onPipeSpawned: () => {
        this.fruitSpawner.onPipeSpawned();
        this.air.onPipeSpawned();
      },
    });
    this.fruitSpawner = new FruitSpawner();
    this.wind = new Wind({
      onWarning: (aFavor) => this.ui?.setWind('aviso', aFavor),
      onGust: (aFavor) => {
        this.ui?.setWind('sopla', aFavor);
        this.applyDifficulty();
      },
      onEnded: () => {
        this.ui?.setWind('', true);
        this.applyDifficulty();
      },
    });
    this.journey = new Journey({
      onStarted: () => this.onJourneyStarted(),
      onEnded: () => this.onJourneyEnded(),
    });
    this.ghost = new Ghost(this.bird);
    this.buddy = new Buddy(this.bird);
    this.snapshot = new Snapshot(this.bird, this.pipeSpawner);
    this.replay = new ReplayRecorder(this.input);
    this.air.setPipeSpawner(this.pipeSpawner);
  }

  attach(ui: UI, audio: AudioDirector, loop: Loop, renderer: Renderer): void {
    this.ui = ui;
    this.audio = audio;
    this.loop = loop;
    this.renderer = renderer;
    this.juice.setTimeScale = (scale) => {
      if (this.loop) this.loop.timeScale = scale;
    };
  }

  /** Alto lógico visible: si supera 512, el mundo se centra y sobra cielo y
   *  suelo. Lo llama el layout en cada redimensionado. */
  setViewport(viewH: number): void {
    const offsetY = Math.max(0, Math.round((viewH - C.VIEWPORT_HEIGHT) / 2));
    this.renderer?.setView(viewH, offsetY);
  }

  viewOffsetY(viewH: number): number {
    return Math.max(0, Math.round((viewH - C.VIEWPORT_HEIGHT) / 2));
  }

  initSession(): void {
    this.rngCosmetico.randomize();
    this.highScore = SaveManager.getHighScore();
    this.session.cargar();
    this.bird.setMaxBreath(this.session.maxBreath());
    this.applyScenery();
    this.refreshSidePanels();
  }

  getState(): GameState {
    return this.state;
  }

  getScore(): number {
    return this.score;
  }

  getHighScore(): number {
    return this.highScore;
  }

  isPaused(): boolean {
    return this.paused;
  }

  /** Llamado en cada frame de dibujo con delta real (hit-stop, flash, shake). */
  updateJuice(dt: number): void {
    this.juice.update(dt);
  }

  // ----------------------------------------------------------------- ciclo
  update(dt: number): void {
    this.input.enabled =
      (this.state === GameState.READY || this.state === GameState.PLAYING) &&
      (this.ui?.currentPanel() ?? null) === null;
    if (this.paused) return;

    if (this.state === GameState.MENU) {
      this.ground.update(dt);
      this.background.update(dt);
      this.buddy.update(dt);
      return;
    }

    if (this.state === GameState.READY) {
      const held = this.input.isFlapPressed();
      if (this.input.consumeFlapJust()) {
        // El primer aleteo arranca la partida Y da el impulso, igual que en el
        // original: no se pierde en la transición.
        this.pendingStartFlap = true;
        this.changeState(GameState.PLAYING);
      } else {
        this.bird.update(dt, false, held);
        this.ground.update(dt);
        this.background.update(dt);
        this.buddy.update(dt);
        this.updateGlideHint();
        return;
      }
    }

    if (this.state === GameState.GAME_OVER) {
      this.bird.update(dt, false, false);
      this.ground.update(dt);
      if (!this.gameOverShown) {
        this.gameOverDelay -= dt;
        if (this.gameOverDelay <= 0) {
          this.gameOverShown = true;
          this.showGameOver();
        }
      } else if (this.input.consumeRestart()) {
        this.restart();
      }
      this.updateGlideHint();
      this.updateHud();
      return;
    }

    // PLAYING
    const flapJust = this.pendingStartFlap || this.input.consumeFlapJust();
    this.pendingStartFlap = false;
    this.bird.update(dt, flapJust, this.input.isFlapPressed());
    if (this.state !== GameState.PLAYING) return;

    this.pipeSpawner.update(dt);
    for (const p of this.pipeSpawner.pipes) p.update(dt);
    this.pipeSpawner.pipes = this.pipeSpawner.pipes.filter((p) => !p.gone);

    this.resolveScoring();
    this.fruitSpawner.update(dt);
    this.resolveFruitPickups();
    this.air.update(dt);
    this.resolveAirOverlaps();
    this.wind.update(dt);
    this.effects.update(dt);
    this.journey.update(dt);
    this.ghost.update(dt);
    this.buddy.update(dt);
    this.snapshot.update();
    this.replay.update();
    this.resolveCollisions();

    this.ground.update(dt);
    this.background.update(dt);
    this.renderer?.updateVisuals(dt);
    this.updateFade(dt);
    this.updateGlideHint();
    this.updateHud();
  }

  render(): void {
    if (!this.renderer || !this.ui) return;
    const shakeX = this.paused ? 0 : this.juice.shakeX();
    const shakeY = this.paused ? 0 : this.juice.shakeY();
    const flash = this.paused ? 0 : this.juice.alpha();
    this.renderer.draw(this.skyColor, shakeX, shakeY, flash);
    this.ui.flash(flash);
  }

  // ---------------------------------------------------------------- estado
  changeState(to: GameState): void {
    if (to === this.state) return;
    if (!TRANSITIONS[this.state].includes(to)) {
      console.warn(`Transición ilegal: ${this.state} -> ${to}`);
      return;
    }
    this.state = to;

    if (to === GameState.MENU || to === GameState.READY) {
      this.score = 0;
      this.effects.clear();
      this.highScore = SaveManager.getHighScore();
      this.isNewHighScore = false;
      this.bird.setMaxBreath(this.session.maxBreath());
    }
    if (to === GameState.READY) {
      this.session.sembrar([this.pipeSpawner, this.fruitSpawner, this.wind]);
      this.ghost.preparar(this.session.seed());
      this.applyScenery();
      this.bird.mirror = this.session.mirror();
      this.replay.preparar(
        this.session.seed(),
        this.session.difficulty(),
        this.session.confidence(),
        this.highScore,
        this.session.mirror(),
      );
      this.huecosSinPlanear = 0;
      this.tramoUsado = false;
      this.tramoScore = -1;
      this.bird.gravityMult = 1;
      this.bird.sizeMult = 1;
      this.bird.hitboxMult = 1;
      this.applyDifficulty();
      this.ui?.setScore(0);
      this.ui?.setEffects([]);
      this.ui?.setShield(0);
      this.lastEffectLine = '';
      this.lastShield = -1;
      this.fadeLeft = 0;
    }
    if (to === GameState.PLAYING) this.fadeLeft = FADE_TIME;

    this.bird.onStateChanged(to);
    this.pipeSpawner.onStateChanged(to);
    this.fruitSpawner.onStateChanged(to);
    this.wind.onStateChanged(to);
    this.air.onStateChanged(to);
    this.journey.onStateChanged(to);
    this.ghost.onStateChanged(to);
    this.buddy.onStateChanged(to);
    this.snapshot.onStateChanged(to);
    this.replay.onStateChanged(to);
    this.ground.onStateChanged(to);
    this.background.onStateChanged(to);
    this.juice.onStateChanged(to);

    if (to === GameState.GAME_OVER) {
      this.gameOverDelay = 0.5;
      this.gameOverShown = false;
    }
    this.ui?.setHudVisible(to === GameState.PLAYING);
    this.updateGlideHint();
    this.refreshSidePanels();
  }

  restart(): void {
    this.setPaused(false);
    this.changeState(GameState.READY);
  }

  toMenu(): void {
    this.setPaused(false);
    this.changeState(GameState.MENU);
  }

  startFree(): void {
    this.session.prepararLibre();
    this.changeState(GameState.READY);
  }

  startDaily(fecha: number[] = []): void {
    this.session.prepararReto(fecha);
    this.changeState(GameState.READY);
  }

  startCode(codigo: string): boolean {
    if (!this.session.prepararCodigo(codigo)) return false;
    this.changeState(GameState.READY);
    return true;
  }

  setPaused(paused: boolean): void {
    if (paused && this.state !== GameState.PLAYING) return;
    this.paused = paused;
    if (this.loop) this.loop.paused = paused;
    this.input.enabled = !paused;
    if (paused) this.ui?.showPause(this.audio?.isMuted() ?? false);
    else if (this.ui?.currentPanel() === 'pause') this.ui?.close();
  }

  /** Estadísticas que enseña el panel (T-084). */
  statsRows(): Array<[string, string]> {
    const medalla = C.medalFor(SaveManager.getHighScore());
    return [
      ['Partidas', String(SaveManager.getGamesPlayed())],
      ['Mejor marca', String(SaveManager.getHighScore())],
      ['Mejor medalla', C.medalName(medalla) || '—'],
      ['Tuberías cruzadas', String(SaveManager.getTotalScore())],
      ['Media por partida', SaveManager.getAverageScore().toFixed(1)],
    ];
  }

  setInputEnabled(enabled: boolean): void {
    this.input.enabled = enabled;
  }

  // --------------------------------------------------------------- acciones
  private onSoftHit(): void {
    this.audio?.playFruitBad();
    this.juice.punch();
    const antes = this.score;
    this.score = Math.max(this.score - C.SOFT_PIPE_SCORE_COST, 0);
    if (this.score === antes) return;
    this.applyDifficulty();
    this.ui?.setScore(this.score);
  }

  private onGlided(): void {
    this.session.marcarPlaneo();
    this.updateGlideHint();
  }

  private onScored(): void {
    if (this.journey.activaAhora()) return;
    const antes = this.score;
    this.score += 1;
    this.quizaTramoEspecial();
    this.journey.quizaEmpezar(this.score);
    if (!this.session.hasGlided()) this.huecosSinPlanear += 1;
    this.wind.enabled = this.score >= C.WIND_MIN_SCORE;
    this.audio?.playPoint();
    this.quizaMedalla(antes);
    this.background.setStage(C.journeyStage(this.score));
    this.applyDifficulty();
    this.ui?.setScore(this.score);
    this.refreshSidePanels();
  }

  private quizaMedalla(antes: number): void {
    if (C.medalFor(this.score) !== C.medalFor(antes)) this.buddy.clap();
  }

  private quizaTramoEspecial(): void {
    if (this.tramoUsado || this.highScore < C.SPECIAL_MIN_RECORD) return;
    if (this.score <= this.highScore) return;
    this.tramoUsado = true;
    this.tramoScore = this.score;
    this.pipeSpawner.specialLeft = C.SPECIAL_STRETCH_PIPES;
  }

  private scoreParaDificultad(): number {
    if (this.tramoScore >= 0 && this.pipeSpawner.specialLeft > 0) return this.tramoScore;
    return this.score;
  }

  private windFactor(): number {
    if (!this.wind.isBlowing()) return 1;
    return C.windFactorFor(
      this.scoreParaDificultad(),
      this.session.difficulty(),
      this.wind.isTailwind(),
    );
  }

  private applyDifficulty(): void {
    const puntos = this.scoreParaDificultad();
    let velocidad = C.windSpeedFor(puntos, this.session.difficulty(), this.windFactor());
    velocidad *= this.effects.speedMult();
    const hueco = C.pipeGapFor(puntos, this.session.difficulty());
    const separacion = C.pipeSpacingFor(puntos, this.session.difficulty());
    this.pipeSpawner.setDifficulty(velocidad, hueco, separacion);
    this.pipeSpawner.movingChance = C.movingPipeChance(puntos);
    this.pipeSpawner.spinChance = C.spinPipeChance(puntos);
    this.ground.scrollSpeed = velocidad;
    this.background.scrollSpeed = velocidad;
    this.fruitSpawner.setDifficulty(velocidad, hueco, separacion);
    this.air.setDifficulty(velocidad, separacion, puntos);
  }

  private applyScenery(): void {
    const variante: Scenery = C.sceneryFor(this.session.seed());
    this.skyColor = C.scenerySky(variante);
    this.background.setVariant(variante);
    this.background.setStage(C.journeyStage(this.score));
    this.snapshot.sky = this.skyColor;
    this.ui?.setSky(this.skyColor);
  }

  private onFruitTaken(kind: EffectKind, puntos: number): void {
    this.effects.apply(kind);
    this.bird.gravityMult = this.effects.gravityMult();
    this.bird.sizeMult = this.effects.sizeMult();
    this.bird.hitboxMult = this.effects.hitboxMult();
    this.applyDifficulty();
    if (puntos > 0) this.audio?.playFruitBad();
    else this.audio?.playFruitGood();
    for (let i = 0; i < puntos; i++) this.onScored();
  }

  private onJourneyStarted(): void {
    this.pipeSpawner.setPaused(true);
    this.fruitSpawner.setPaused(true);
    this.bird.setScene(true);
    this.ui?.setJourney(C.JOURNEY_LINE);
    SaveManager.setJourneyCompleted();
  }

  private onJourneyEnded(): void {
    if (this.state !== GameState.PLAYING) return;
    this.pipeSpawner.setPaused(false);
    this.fruitSpawner.setPaused(false);
    this.bird.setScene(false);
    this.ui?.setJourney('');
  }

  private onBirdDied(cause: DeathCause, breathless: boolean): void {
    this.deathCause = cause;
    this.deathBreathless = breathless;
    this.juice.punch();
    this.audio?.playHit();
    this.isNewHighScore = this.session.registrarPartida(this.score);
    this.highScore = SaveManager.getHighScore();
    this.ghost.terminar(this.score, this.isNewHighScore);
    this.replay.terminar(this.score);
    if (this.isNewHighScore) this.snapshot.capturar();
    this.changeState(GameState.GAME_OVER);
  }

  // -------------------------------------------------------------- colisiones
  private circle(): { x: number; y: number; r: number } {
    return { x: this.bird.x + 1, y: this.bird.y, r: this.bird.baseRadius * this.bird.hitboxMult };
  }

  private resolveScoring(): void {
    const c = this.circle();
    for (const p of this.pipeSpawner.pipes) {
      if (p.scored) continue;
      const zr = p.scoreRect();
      if (circleRectOverlap(c.x, c.y, c.r, zr.x, zr.y, zr.w, zr.h)) {
        p.scored = true;
        this.onScored();
        const desvio = Math.abs(this.bird.y - p.gapCenter);
        if (desvio <= C.breathBandHalf(p.gap)) this.bird.recoverBreath(C.BREATH_RECOVER_ON_GAP);
        else if (desvio >= C.grazeThreshold(p.gap)) this.buddy.scare();
      }
    }
  }

  private resolveFruitPickups(): void {
    if (!this.bird.collides()) return;
    const c = this.circle();
    for (const f of this.fruitSpawner.fruits) {
      if (f.taken) continue;
      if (circleRectOverlap(c.x, c.y, c.r, f.x - 8, f.y - 8, 16, 16)) {
        f.taken = true;
        f.gone = true;
        this.onFruitTaken(f.kind, f.points);
      }
    }
    this.fruitSpawner.fruits = this.fruitSpawner.fruits.filter((f) => !f.gone);
  }

  private resolveAirOverlaps(): void {
    const c = this.circle();
    for (const t of this.air.thermals) {
      const r = t.rect();
      const inside = circleRectOverlap(c.x, c.y, c.r, r.x, r.y, r.w, r.h);
      if (inside !== t.inside) {
        t.inside = inside;
        this.bird.setInThermal(inside);
      }
    }
    for (const s of this.air.slips) {
      const r = s.rect();
      const inside = circleRectOverlap(c.x, c.y, c.r, r.x, r.y, r.w, r.h);
      if (inside !== s.inside) {
        s.inside = inside;
        this.bird.setInSlipstream(inside);
      }
    }
  }

  private resolveCollisions(): void {
    if (this.bird.isDead || !this.bird.collides()) return;
    const c = this.circle();
    const hits = [];
    for (const p of this.pipeSpawner.pipes) {
      const top = p.topRect();
      const bottom = p.bottomRect();
      if (
        circleRectOverlap(c.x, c.y, c.r, top.x, top.y, top.w, top.h) ||
        circleRectOverlap(c.x, c.y, c.r, bottom.x, bottom.y, bottom.w, bottom.h)
      ) {
        hits.push(p);
      }
    }
    const groundHit = c.y + c.r >= C.playableHeight();
    const ceilingDeath = this.bird.mirror && this.bird.y <= C.CEILING_Y;
    const voidDeath = this.bird.y >= C.FALL_DEATH_Y;
    const choque = hits.length > 0 || groundHit;
    if (!choque && !ceilingDeath && !voidDeath) return;

    const allSoft = hits.length > 0 && !groundHit && hits.every((h) => h.soft);
    if (allSoft) {
      this.bird.softBounce(hits[0].gapCenter);
      return;
    }

    if (this.effects.consumeShield()) {
      this.bird.survive(SHIELD_GRACE);
      this.bird.vy = C.BOUNCE_IMPULSE * this.bird.facing;
      this.audio?.playFruitGood();
      return;
    }

    let cause: DeathCause = DeathCause.VACIO;
    if (hits.length > 0) cause = DeathCause.TUBERIA;
    else if (groundHit || ceilingDeath) cause = DeathCause.SUELO;
    this.bird.die(cause, this.bird.breath <= 0);
  }

  // --------------------------------------------------------------------- UI
  private updateGlideHint(): void {
    if (!this.ui) return;
    const partidas = SaveManager.getGamesPlayed();
    if (this.state === GameState.READY) {
      this.ui.setGlideHint(C.showGlidePictogram(this.session.hasGlided(), partidas) ? 'pictograma' : '');
    } else if (this.state === GameState.PLAYING) {
      this.ui.setGlideHint(
        C.showGlideHint(this.session.hasGlided(), partidas, this.huecosSinPlanear) ? 'aviso' : '',
      );
    } else {
      this.ui.setGlideHint('');
    }
  }

  private updateHud(): void {
    if (!this.ui) return;
    const lineas = this.effects
      .activos()
      .map(([k, t]) => `${this.effects.kindName(k)} ${Math.ceil(t)}`);
    const line = lineas.join('|');
    if (line !== this.lastEffectLine) {
      this.lastEffectLine = line;
      this.ui.setEffects(lineas);
    }
    if (this.effects.shieldCount() !== this.lastShield) {
      this.lastShield = this.effects.shieldCount();
      this.ui.setShield(this.lastShield);
    }
    this.ui.setBreath(this.bird.breath, this.bird.maxBreath, this.lastFatigue);
  }

  private updateFade(dt: number): void {
    if (this.fadeLeft > 0) {
      this.fadeLeft = Math.max(this.fadeLeft - dt, 0);
      this.ui?.fade(0.6 * (this.fadeLeft / FADE_TIME));
    } else {
      this.ui?.fade(0);
    }
  }

  private showGameOver(): void {
    if (!this.ui) return;
    const frase = this.deathLines.pickFor(this.deathCause, this.deathBreathless, this.rngCosmetico);
    this.ui.showGameOver({
      score: this.score,
      highScore: this.highScore,
      isRecord: this.isNewHighScore,
      medal: C.medalFor(this.score),
      line: frase,
      playerName: this.session.playerName(),
      challenge: this.session.daily.nombre(),
      code: this.session.daily.activo() ? '' : this.session.codigo(),
      canShare: typeof navigator !== 'undefined' && 'share' in navigator,
      muted: this.audio?.isMuted() ?? false,
    });
  }

  showMenu(codeError = false): void {
    if (!this.ui) return;
    this.ui.showMenu({
      highScore: this.highScore,
      journeyCompleted: SaveManager.getJourneyCompleted(),
      dailyName: this.session.daily.nombre(),
      dailyBest: this.session.daily.mejor(),
      hasCodeError: codeError,
    });
  }

  refreshSidePanels(): void {
    if (!this.ui) return;
    this.ui.updateSides(
      [
        ['Récord', String(this.highScore)],
        ['Partidas', String(SaveManager.getGamesPlayed())],
        ['Medalla', C.medalName(C.medalFor(this.highScore)) || '—'],
      ],
      C.stageName(C.journeyStage(this.score)),
      C.sceneryName(C.sceneryFor(this.session.seed())),
    );
  }
}
