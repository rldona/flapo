import * as C from '../config/GameConfig';
import { THERMAL_LIFT, THERMAL_MAX_RISE } from '../config/AirConfig';
import { DeathCause, GameState } from '../core/types';

export interface BirdCallbacks {
  onFlapped(): void;
  onDied(cause: DeathCause, breathless: boolean): void;
  onSoftHit(): void;
  onBreathRecovered(amount: number): void;
  onGlided(): void;
  onBreathChanged(actual: number, max: number): void;
  onFatigueChanged(fatigued: boolean, count: number): void;
}

/**
 * Port de `bird.gd`. La física no simula, obedece (ADR-0006): gravedad,
 * impulso, planeo y fatiga, todo a 60 Hz fijos.
 */
export class Bird {
  readonly startX = 72;
  readonly startY = 256;

  x = this.startX;
  y = this.startY;
  vy = 0;
  rotation = 0;

  mirror = false;
  gravityMult = 1;
  sizeMult = 1;
  hitboxMult = 1;
  maxBreath: number = C.MAX_BREATH;

  breath: number = C.MAX_BREATH;
  dead = false;
  inScene = false;

  readonly baseRadius = 8;

  private state: GameState = GameState.READY;
  private burstLeft = 0;
  private held = 0;
  private gliding = false;
  private termicas = 0;
  private estelas = 0;
  private flapTimes: number[] = [];
  private tiempo = 0;
  private invulnerableLeft = 0;
  private softCooldown = 0;
  private animTime = 0;
  private maskDisabled = false;

  constructor(private readonly cb: BirdCallbacks) {}

  onStateChanged(to: GameState): void {
    this.state = to;
    if (to === GameState.READY || to === GameState.MENU) {
      this.dead = false;
      this.vy = 0;
      this.rotation = 0;
      this.x = this.startX;
      this.y = this.startY;
      this.burstLeft = 0;
      this.held = 0;
      this.gliding = false;
      this.termicas = 0;
      this.estelas = 0;
      this.inScene = false;
      this.breath = this.maxBreath;
      this.cb.onBreathChanged(this.breath, this.maxBreath);
      this.flapTimes = [];
      this.softCooldown = 0;
      this.cb.onFatigueChanged(false, 0);
      this.gravityMult = 1;
      this.sizeMult = 1;
      this.hitboxMult = 1;
      this.maskDisabled = false;
      this.animTime = 0;
      this.cb.onBreathChanged(this.breath, this.maxBreath);
    }
  }

  setMaxBreath(value: number): void {
    this.maxBreath = value;
    this.breath = Math.min(this.breath, value);
    this.cb.onBreathChanged(this.breath, value);
  }

  isGliding(): boolean {
    return this.gliding;
  }

  isFatigued(): boolean {
    return C.isFatigued(this.recentFlaps());
  }

  recentFlaps(): number {
    this.podarAlteos(this.tiempo);
    return this.flapTimes.length;
  }

  pantLevel(): C.Pant {
    return C.pantLevel(this.breath, this.maxBreath);
  }

  pantTintWeight(): number {
    return C.pantTintWeight(this.breath, this.maxBreath);
  }

  setInThermal(dentro: boolean): void {
    this.termicas = Math.max(this.termicas + (dentro ? 1 : -1), 0);
  }

  inThermal(): boolean {
    return this.termicas > 0;
  }

  setInSlipstream(dentro: boolean): void {
    this.estelas = Math.max(this.estelas + (dentro ? 1 : -1), 0);
  }

  inSlipstream(): boolean {
    return this.estelas > 0;
  }

  setScene(activa: boolean): void {
    this.inScene = activa;
    if (activa) {
      this.vy = 0;
      this.maskDisabled = true;
    } else {
      this.maskDisabled = false;
    }
  }

  collides(): boolean {
    return !this.maskDisabled;
  }

  survive(segundos: number): void {
    this.dead = false;
    this.maskDisabled = true;
    this.invulnerableLeft = segundos;
  }

  recoverBreath(cantidad: number): void {
    const antes = this.breath;
    this.ajustarAliento(cantidad);
    const ganado = this.breath - antes;
    if (ganado > 0) this.cb.onBreathRecovered(ganado);
  }

  /** La parte de integración y control. La colisión la resuelve el mundo. */
  update(dt: number, flapJust: boolean, flapHeld: boolean): void {
    this.tiempo += dt;

    if (this.state === GameState.MENU || this.state === GameState.READY) {
      this.vy = 0;
    } else if (this.state === GameState.PLAYING) {
      if (this.inScene) {
        this.vy = 0;
        this.gliding = false;
        this.updateAnimation(dt);
        return;
      }
      this.actualizarPlaneo(dt, flapHeld);
      this.applyGravity(dt);
      if (flapJust) {
        this.vy = C.FLAP_IMPULSE * this.registrarAleteo() * this.signo();
        this.burstLeft = C.FLAP_BURST_TIME;
        this.gastarAliento(C.BREATH_DRAIN_FLAP);
        this.cb.onFlapped();
      }
    } else if (this.state === GameState.GAME_OVER) {
      this.applyGravity(dt);
      this.rotation += C.STUN_SPIN * dt;
    }

    this.y += this.vy * dt;
    this.clampToCeiling();
    if (this.state === GameState.PLAYING) this.updateRotation(dt);

    if (this.softCooldown > 0) this.softCooldown = Math.max(this.softCooldown - dt, 0);
    if (this.invulnerableLeft > 0) {
      this.invulnerableLeft = Math.max(this.invulnerableLeft - dt, 0);
      if (this.invulnerableLeft <= 0) this.maskDisabled = false;
    }
    this.updateAnimation(dt);
  }

  die(cause: DeathCause, breathless: boolean): void {
    if (this.dead) return;
    this.dead = true;
    this.vy = C.BOUNCE_IMPULSE * this.signo();
    this.cb.onDied(cause, breathless);
  }

  softBounce(centerY: number): void {
    let direccion = centerY - this.y;
    direccion = direccion === 0 ? -1 : Math.sign(direccion);
    this.vy = direccion * C.SOFT_PIPE_BOUNCE_SPEED;
    if (this.softCooldown > 0) return;
    this.softCooldown = C.SOFT_PIPE_COOLDOWN;
    this.gastarAliento(C.SOFT_PIPE_BREATH_COST);
    this.cb.onSoftHit();
  }

  get isDead(): boolean {
    return this.dead;
  }

  get facing(): number {
    return this.signo();
  }

  private signo(): number {
    return this.mirror ? -1 : 1;
  }

  private limitar(v: number, tope: number): number {
    return this.mirror ? Math.max(v, tope * -1) : Math.min(v, tope);
  }

  private applyGravity(dt: number): void {
    const signo = this.signo();
    if (this.gliding) {
      if (this.termicas > 0) {
        this.vy = Math.max(
          this.vy - THERMAL_LIFT * dt * signo,
          -THERMAL_MAX_RISE * signo,
        );
        return;
      }
      this.vy = this.limitar(
        this.vy + C.GRAVITY * this.gravityMult * C.GLIDE_GRAVITY_MULT * dt * signo,
        C.GLIDE_MAX_FALL_SPEED,
      );
      return;
    }
    this.vy = this.limitar(this.vy + C.GRAVITY * this.gravityMult * dt * signo, C.MAX_FALL_SPEED);
  }

  private actualizarPlaneo(dt: number, held: boolean): void {
    this.held = held ? this.held + dt : 0;
    const quiere = this.held >= C.GLIDE_HOLD_TIME;
    const antes = this.gliding;
    this.gliding = quiere && this.breath > 0;
    if (this.gliding && !antes) this.cb.onGlided();
    if (this.gliding) {
      if (this.estelas <= 0) this.gastarAliento(C.BREATH_DRAIN_GLIDE * dt);
      if (!antes && this.flapTimes.length > 0) {
        this.flapTimes = [];
        this.cb.onFatigueChanged(false, 0);
      }
    }
  }

  private registrarAleteo(): number {
    this.flapTimes.push(this.tiempo);
    this.podarAlteos(this.tiempo);
    const mult = C.fatigueImpulseMult(this.flapTimes.length);
    this.cb.onFatigueChanged(C.isFatigued(this.flapTimes.length), this.flapTimes.length);
    return mult;
  }

  private podarAlteos(ahora: number): void {
    while (this.flapTimes.length > 0 && ahora - this.flapTimes[0] > C.FATIGUE_WINDOW) {
      this.flapTimes.shift();
    }
  }

  private gastarAliento(cantidad: number): void {
    this.ajustarAliento(-cantidad);
  }

  private ajustarAliento(delta: number): void {
    const antes = this.breath;
    this.breath = Math.min(Math.max(this.breath + delta, 0), this.maxBreath);
    if (antes !== this.breath) this.cb.onBreathChanged(this.breath, this.maxBreath);
  }

  private clampToCeiling(): void {
    if (this.y < C.CEILING_Y) {
      this.y = C.CEILING_Y;
      this.vy = Math.max(this.vy, 0);
    }
  }

  private updateRotation(dt: number): void {
    const vel = this.vy * this.signo();
    const fallRatio = Math.min(
      Math.max((vel - C.FLAP_IMPULSE) / (C.MAX_FALL_SPEED - C.FLAP_IMPULSE), 0),
      1,
    );
    const targetDeg = C.ROTATION_UP_DEGREES + (C.ROTATION_DOWN_DEGREES - C.ROTATION_UP_DEGREES) * fallRatio;
    const target = (targetDeg * Math.PI) / 180;
    this.rotation = lerpAngle(this.rotation, target, 1 - Math.exp(-C.ROTATION_SPEED * dt));
  }

  private updateAnimation(dt: number): void {
    if (this.state === GameState.GAME_OVER) return;
    this.burstLeft = Math.max(this.burstLeft - dt, 0);
    let fps = this.burstLeft > 0 ? C.FLAP_FPS_BURST : C.FLAP_FPS_IDLE;
    if (this.pantLevel() !== C.Pant.NINGUNO) fps *= C.PANT_FLAP_FPS_MULT;
    this.animTime += dt * fps;
  }

  /** Frame de aleteo actual (0..2). */
  animationFrame(): number {
    return Math.floor(this.animTime) % 3;
  }
}

function lerpAngle(a: number, b: number, t: number): number {
  let diff = (b - a) % (Math.PI * 2);
  if (diff < -Math.PI) diff += Math.PI * 2;
  if (diff > Math.PI) diff -= Math.PI * 2;
  return a + diff * t;
}
