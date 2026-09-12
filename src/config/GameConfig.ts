/**
 * Port 1:1 de `scripts/game_config.gd` del original.
 *
 * Regla del proyecto original que se mantiene: lo compartido vive aquí; lo que
 * se tunea a ojo en un sistema concreto se queda en ese sistema. Aquí no hay
 * estado, solo constantes y funciones puras.
 */

export const enum Difficulty {
  FACIL = 0,
  NORMAL = 1,
  DIFICIL = 2,
}

export const enum Medal {
  NINGUNA = 0,
  CROQUETA = 1,
  TORTILLA = 2,
  JAMON = 3,
}

export const enum Scenery {
  DIA = 0,
  ATARDECER = 1,
  NOCHE = 2,
  LLUVIA = 3,
}

export const enum Stage {
  PARQUE = 0,
  TEJADOS = 1,
  NUBES = 2,
  CIELO = 3,
}

export const enum Pant {
  NINGUNO = 0,
  JADEO = 1,
  AGOTADO = 2,
}

// --- Pantalla ------------------------------------------------------------
export const VIEWPORT_WIDTH = 288;
export const VIEWPORT_HEIGHT = 512;
export const GROUND_HEIGHT = 64;

// --- Física de Flapo ------------------------------------------------------
// En el original viven como @export en bird.gd; aquí se centralizan para que
// los tests y el modo espejo compartan una única fuente.
export const GRAVITY = 1200;
export const FLAP_IMPULSE = -380;
export const MAX_FALL_SPEED = 500;
export const CEILING_Y = 0;
export const FALL_DEATH_Y = 512;
export const BOUNCE_IMPULSE = -180;
export const STUN_SPIN = 9;
export const GLIDE_HOLD_TIME = 0.18;
export const GLIDE_GRAVITY_MULT = 0.25;
export const GLIDE_MAX_FALL_SPEED = 90;
export const FLAP_FPS_IDLE = 6;
export const FLAP_FPS_BURST = 20;
export const FLAP_BURST_TIME = 0.18;
export const ROTATION_UP_DEGREES = -25;
export const ROTATION_DOWN_DEGREES = 90;
export const ROTATION_SPEED = 9;

// --- Mundo ----------------------------------------------------------------
export const SCROLL_SPEED = 100;
export const PIPE_SPACING = 160;

// --- Curva de dificultad --------------------------------------------------
export const DIFFICULTY_CAP = 30;
export const SCROLL_SPEED_MAX = 145;
export const PIPE_GAP_MIN = 82;
export const PIPE_SPACING_MAX = 172;
export const FLAP_CYCLE = 0.35;
export const PIPE_GAP = 118;

// --- Aliento --------------------------------------------------------------
export const MAX_BREATH = 100;
export const BREATH_DRAIN_FLAP = 10;
export const BREATH_DRAIN_GLIDE = 15;
export const BREATH_RECOVER_ON_GAP = 25;
export const BREATH_BAND_RATIO = 0.5;

// --- Modos de dificultad --------------------------------------------------
export const DIFFICULTY_GAP_MULT = [1.18, 1.0, 0.88];
export const DIFFICULTY_SPEED_MULT = [0.85, 1.0, 1.15];

// --- Tuberías móviles -----------------------------------------------------
export const MOVING_PIPE_MIN_SCORE = 15;
export const MOVING_PIPE_CHANCE_MIN = 0.15;
export const MOVING_PIPE_CHANCE_MAX = 0.45;
export const MOVING_PIPE_AMPLITUDE = 22;
export const MOVING_PIPE_PERIOD = 2.4;

// --- Ráfagas de viento ----------------------------------------------------
export const WIND_WARNING_TIME = 2;
export const WIND_DURATION = 5;
export const WIND_CALM_MIN = 12;
export const WIND_CALM_MAX = 22;
export const WIND_FACTOR_TAIL = 1.25;
export const WIND_FACTOR_HEAD = 0.8;
export const WIND_MIN_SCORE = 10;

// --- Layout adaptativo ----------------------------------------------------
export const MIN_WINDOW_SCALE = 1;
export const MAX_WINDOW_SCALE = 6;

// --- Tubería giratoria ----------------------------------------------------
export const SPIN_PIPE_MIN_SCORE = 12;
export const SPIN_PIPE_CHANCE_MIN = 0.12;
export const SPIN_PIPE_CHANCE_MAX = 0.35;
export const SPIN_PIPE_TURNS_PER_SECOND = 0.35;

// --- Tubería blandita -----------------------------------------------------
export const SOFT_PIPE_INTERVAL = 7;
export const SOFT_PIPE_BREATH_COST = 35;
export const SOFT_PIPE_SCORE_COST = 1;
export const SOFT_PIPE_COOLDOWN = 0.8;
export const SOFT_PIPE_BOUNCE_SPEED = 260;
export const SOFT_PIPE_TINT = '#7FA37B';

// --- Nombre de jugador ----------------------------------------------------
export const PLAYER_NAME_MAX_LEN = 12;
export const PLAYER_NAME_DEFAULT = 'Flapo';

// --- Confianza ------------------------------------------------------------
export const CONFIDENCE_STEP = 10;
export const CONFIDENCE_MAX_LEVEL = 5;
export const CONFIDENCE_BREATH_BONUS = 8;

// --- Semilla --------------------------------------------------------------
export const SEED_ALEATORIA = 0;
export const CODIGO_ALFABETO = '0123456789abcdefghijklmnopqrstuvwxyz';
export const CODIGO_LARGO = 5;

// --- Reto del día ---------------------------------------------------------
export const MESES = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

// --- Descubrir el planeo --------------------------------------------------
export const GLIDE_HINT_MAX_GAMES = 5;
export const GLIDE_HINT_AFTER_GAPS = 3;

// --- Jadeo visible --------------------------------------------------------
export const BREATH_LOW_RATIO = 0.3;
export const PANT_FLAP_FPS_MULT = 1.6;
export const PANT_TINT = '#F2B3A0';
export const PANT_TINT_MAX = 0.55;

// --- Fatiga ---------------------------------------------------------------
export const FATIGUE_FLAP_COUNT = 4;
export const FATIGUE_WINDOW = 1.2;
export const FATIGUE_PENALTY = 0.3;

// --- Puntuación -----------------------------------------------------------
export const MEDAL_BRONZE = 10;
export const MEDAL_SILVER = 20;
export const MEDAL_GOLD = 40;

// --- Escenarios -----------------------------------------------------------
export const SCENERY_SKY = ['#7CB3D7', '#E8A06B', '#2E3F5C', '#8FA3B0'];
export const SCENERY_TINT = ['#FFFFFF', '#FFC49A', '#6E7FA6', '#B9C6CE'];
export const SCENERY_LLUEVE = [false, false, false, true];

// --- Tramos del viaje -----------------------------------------------------
export const JOURNEY_STAGE_SCORE = 13;
export const JOURNEY_FADE_TIME = 2;
export const JOURNEY_END_SCORE = 50;
export const JOURNEY_SCENE_TIME = 3;
export const JOURNEY_LINE = 'Ha llegado. Gordo, pero ha llegado.';

// --- Escudo ---------------------------------------------------------------
export const SHIELD_MAX = 3;

// --- Captura del mejor salto ----------------------------------------------
export const SNAPSHOT_SECONDS = 2;
export const SNAPSHOT_SAMPLES = 6;
export const SNAPSHOT_SCALE = 3;
export const SNAPSHOT_FADE_MIN = 0.22;
export const SNAPSHOT_PIPE_COLOR = '#3A5468';

// --- Modo espejo ----------------------------------------------------------
export const MIRROR_UNLOCK_SCORE = 25;

// --- Compañero ------------------------------------------------------------
export const GRAZE_RATIO = 0.8;
export const BUDDY_OFFSET_X = -26;
export const BUDDY_OFFSET_Y = -20;
export const BUDDY_LAG = 0.22;
export const BUDDY_BOB = 3;
export const BUDDY_BOB_PERIOD = 0.9;
export const BUDDY_TINT = '#9BBBA8';
export const BUDDY_SCALE = 0.7;
export const BUDDY_SCARE_TIME = 0.6;
export const BUDDY_CLAP_TIME = 1;
export const BUDDY_SCARE_JUMP = 14;
export const BUDDY_CLAP_BOUNCE = 7;

// --- Tramo especial -------------------------------------------------------
export const SPECIAL_STRETCH_PIPES = 4;
export const SPECIAL_MIN_RECORD = 1;
export const SPECIAL_PIPE_TINT = '#E6C46A';

// --- Fantasma -------------------------------------------------------------
export const GHOST_ALPHA = 0.45;
export const GHOST_TINT = '#8FB8D8';
export const GHOST_MAX_FRAMES = 36000;

// --- Utilidades -----------------------------------------------------------
export function mix(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}

export function posmod(a: number, b: number): number {
  return ((a % b) + b) % b;
}

export function mirrorUnlocked(record: number): boolean {
  return record >= MIRROR_UNLOCK_SCORE;
}

export function grazeThreshold(gap: number): number {
  return gap * 0.5 * GRAZE_RATIO;
}

export function journeyStage(score: number): Stage {
  const idx = Math.trunc(Math.max(score, 0) / JOURNEY_STAGE_SCORE);
  return clamp(idx, 0, 3) as Stage;
}

export function stageName(tramo: Stage): string {
  return ['Parque', 'Tejados', 'Nubes', 'Cielo'][tramo];
}

export function isSpecialSoft(restantes: number): boolean {
  return restantes === SPECIAL_STRETCH_PIPES / 2;
}

export function groundFillHeight(altoViewport: number, superficie: number): number {
  return Math.max(0, altoViewport - superficie - GROUND_HEIGHT);
}

export function sceneryFor(semilla: number): Scenery {
  return posmod(semilla, SCENERY_SKY.length) as Scenery;
}

export function scenerySky(variante: Scenery): string {
  return SCENERY_SKY[variante];
}

export function sceneryTint(variante: Scenery): string {
  return SCENERY_TINT[variante];
}

export function sceneryRains(variante: Scenery): boolean {
  return SCENERY_LLUEVE[variante];
}

export function sceneryName(variante: Scenery): string {
  return ['Día', 'Atardecer', 'Noche', 'Lluvia'][variante];
}

export function difficulty(score: number): number {
  return clamp(score / DIFFICULTY_CAP, 0, 1);
}

export function gapMult(modo: Difficulty): number {
  return DIFFICULTY_GAP_MULT[clamp(modo, 0, DIFFICULTY_GAP_MULT.length - 1)];
}

export function speedMult(modo: Difficulty): number {
  return DIFFICULTY_SPEED_MULT[clamp(modo, 0, DIFFICULTY_SPEED_MULT.length - 1)];
}

export function scrollSpeedFor(score: number, modo: Difficulty = Difficulty.NORMAL): number {
  return mix(SCROLL_SPEED, SCROLL_SPEED_MAX, difficulty(score)) * speedMult(modo);
}

export function pipeGapFor(score: number, modo: Difficulty = Difficulty.NORMAL): number {
  return mix(PIPE_GAP, PIPE_GAP_MIN, difficulty(score)) * gapMult(modo);
}

export function pipeSpacingFor(score: number, modo: Difficulty = Difficulty.NORMAL): number {
  return mix(PIPE_SPACING, PIPE_SPACING_MAX, difficulty(score)) * speedMult(modo);
}

export function pipeSpawnIntervalFor(score: number, modo: Difficulty = Difficulty.NORMAL): number {
  return pipeSpacingFor(score, modo) / scrollSpeedFor(score, modo);
}

export function flapsBetweenPipes(score: number, modo: Difficulty = Difficulty.NORMAL): number {
  return pipeSpawnIntervalFor(score, modo) / FLAP_CYCLE;
}

export function sanitizePlayerName(texto: string): string {
  let limpio = '';
  for (const ch of texto) {
    const code = ch.codePointAt(0) ?? 0;
    if (code < 32 || code === 127) limpio += ' ';
    else limpio += ch;
  }
  while (limpio.includes('  ')) limpio = limpio.replace(/ {2}/g, ' ');
  limpio = limpio.trim();
  if (limpio.length > PLAYER_NAME_MAX_LEN) limpio = limpio.slice(0, PLAYER_NAME_MAX_LEN).trim();
  return limpio;
}

export function displayPlayerName(texto: string): string {
  const limpio = sanitizePlayerName(texto);
  return limpio !== '' ? limpio : PLAYER_NAME_DEFAULT;
}

export function movingPipeChance(score: number): number {
  if (score < MOVING_PIPE_MIN_SCORE) return 0;
  const recorrido = Math.max(DIFFICULTY_CAP - MOVING_PIPE_MIN_SCORE, 1);
  const t = clamp((score - MOVING_PIPE_MIN_SCORE) / recorrido, 0, 1);
  return mix(MOVING_PIPE_CHANCE_MIN, MOVING_PIPE_CHANCE_MAX, t);
}

export function codigoModulo(): number {
  return Math.pow(CODIGO_ALFABETO.length, CODIGO_LARGO);
}

export function seedACodigo(semilla: number): string {
  let n = posmod(Math.trunc(semilla), codigoModulo());
  const base = CODIGO_ALFABETO.length;
  let texto = '';
  for (let i = 0; i < CODIGO_LARGO; i++) {
    texto = CODIGO_ALFABETO[n % base] + texto;
    n = Math.floor(n / base);
  }
  return texto;
}

export function codigoASeed(codigo: string): number {
  const limpio = codigo.trim().toLowerCase();
  if (limpio.length !== CODIGO_LARGO) return -1;
  const base = CODIGO_ALFABETO.length;
  let n = 0;
  for (const c of limpio) {
    const d = CODIGO_ALFABETO.indexOf(c);
    if (d < 0) return -1;
    n = n * base + d;
  }
  return n;
}

export function dailySeed(anio: number, mes: number, dia: number): number {
  return anio * 10000 + mes * 100 + dia;
}

export function dailyKey(anio: number, mes: number, dia: number): string {
  return `daily_${dailySeed(anio, mes, dia)}`;
}

export function dailyName(mes: number, dia: number): string {
  if (mes < 1 || mes > MESES.length) return `${dia}/${mes}`;
  return `${dia} de ${MESES[mes - 1]}`;
}

export function showGlidePictogram(haPlaneado: boolean, partidas: number): boolean {
  if (haPlaneado) return false;
  return partidas < GLIDE_HINT_MAX_GAMES;
}

export function showGlideHint(haPlaneado: boolean, partidas: number, huecos: number): boolean {
  if (!showGlidePictogram(haPlaneado, partidas)) return false;
  return huecos >= GLIDE_HINT_AFTER_GAPS;
}

export function breathBandHalf(gap: number): number {
  return gap * BREATH_BAND_RATIO * 0.5;
}

export function playableHeight(): number {
  return VIEWPORT_HEIGHT - GROUND_HEIGHT;
}

export function movingPipeAmplitude(gap: number, centro: number): number {
  const mediaLuz = gap * 0.5;
  const margenArriba = centro - mediaLuz;
  const margenAbajo = playableHeight() - centro - mediaLuz;
  const margen = Math.min(margenArriba, margenAbajo);
  return clamp(Math.min(MOVING_PIPE_AMPLITUDE, margen), 0, MOVING_PIPE_AMPLITUDE);
}

export function movingPipePeakSpeed(amplitud: number): number {
  return (amplitud * Math.PI * 2) / MOVING_PIPE_PERIOD;
}

export function isSoftPipe(indice: number): boolean {
  if (indice <= 0 || SOFT_PIPE_INTERVAL <= 0) return false;
  return indice % SOFT_PIPE_INTERVAL === 0;
}

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export function windowScaleFor(ventanaW: number, ventanaH: number, fractional = false): number {
  if (ventanaW <= 0 || ventanaH <= 0) return MIN_WINDOW_SCALE;
  const fit = Math.min(ventanaW / VIEWPORT_WIDTH, ventanaH / VIEWPORT_HEIGHT);
  if (fit >= 2 && !fractional) {
    return clamp(Math.floor(fit), MIN_WINDOW_SCALE, MAX_WINDOW_SCALE);
  }
  return clamp(fit, MIN_WINDOW_SCALE, MAX_WINDOW_SCALE);
}

export function playfieldRectFor(ventanaW: number, ventanaH: number, escala: number): Rect {
  const w = VIEWPORT_WIDTH * escala;
  const h = VIEWPORT_HEIGHT * escala;
  return {
    x: Math.floor((ventanaW - w) / 2),
    y: Math.floor((ventanaH - h) / 2),
    w,
    h,
  };
}

export function layoutMarginFor(
  ventanaW: number,
  ventanaH: number,
  escala: number,
): { x: number; y: number } {
  const caja = playfieldRectFor(ventanaW, ventanaH, escala);
  return { x: Math.max(caja.x, 0), y: Math.max(caja.y, 0) };
}

export function windFactorFor(score: number, modo: Difficulty, aFavor: boolean): number {
  const base = scrollSpeedFor(score, modo);
  if (base <= 0) return 1;
  const suelo = scrollSpeedFor(0, modo);
  const techo = scrollSpeedFor(DIFFICULTY_CAP, modo);
  const cola = clamp(base * WIND_FACTOR_TAIL, suelo, techo) / base;
  const contra = clamp(base * WIND_FACTOR_HEAD, suelo, techo) / base;
  const preferido = aFavor ? cola : contra;
  const alternativo = aFavor ? contra : cola;
  if (Math.abs(preferido - 1) > 1e-6) return preferido;
  return alternativo;
}

export function windSpeedFor(score: number, modo: Difficulty, factor: number): number {
  const base = scrollSpeedFor(score, modo);
  return clamp(base * factor, scrollSpeedFor(0, modo), scrollSpeedFor(DIFFICULTY_CAP, modo));
}

export function spinPipeChance(score: number): number {
  if (score < SPIN_PIPE_MIN_SCORE) return 0;
  const recorrido = Math.max(DIFFICULTY_CAP - SPIN_PIPE_MIN_SCORE, 1);
  const t = clamp((score - SPIN_PIPE_MIN_SCORE) / recorrido, 0, 1);
  return mix(SPIN_PIPE_CHANCE_MIN, SPIN_PIPE_CHANCE_MAX, t);
}

export function pantLevel(aliento: number, maximo: number): Pant {
  if (maximo <= 0) return Pant.NINGUNO;
  if (aliento <= 0) return Pant.AGOTADO;
  if (aliento / maximo < BREATH_LOW_RATIO) return Pant.JADEO;
  return Pant.NINGUNO;
}

export function pantTintWeight(aliento: number, maximo: number): number {
  if (maximo <= 0 || BREATH_LOW_RATIO <= 0) return 0;
  const ratio = clamp(aliento / maximo, 0, 1);
  if (ratio >= BREATH_LOW_RATIO) return 0;
  const hundido = 1 - ratio / BREATH_LOW_RATIO;
  return hundido * PANT_TINT_MAX;
}

export function difficultyName(modo: Difficulty): string {
  if (modo === Difficulty.FACIL) return 'Fácil';
  if (modo === Difficulty.DIFICIL) return 'Difícil';
  return 'Normal';
}

export function pipeSpawnInterval(): number {
  return PIPE_SPACING / SCROLL_SPEED;
}

export function confidenceLevel(partidas: number): number {
  return clamp(Math.floor(partidas / CONFIDENCE_STEP), 0, CONFIDENCE_MAX_LEVEL);
}

export function maxBreathFor(nivel: number): number {
  const n = clamp(nivel, 0, CONFIDENCE_MAX_LEVEL);
  return MAX_BREATH + n * CONFIDENCE_BREATH_BONUS;
}

export function fatigueImpulseMult(aleteosEnVentana: number): number {
  return aleteosEnVentana > FATIGUE_FLAP_COUNT ? 1 - FATIGUE_PENALTY : 1;
}

export function isFatigued(aleteosEnVentana: number): boolean {
  return aleteosEnVentana > FATIGUE_FLAP_COUNT;
}

export function medalFor(score: number): Medal {
  if (score >= MEDAL_GOLD) return Medal.JAMON;
  if (score >= MEDAL_SILVER) return Medal.TORTILLA;
  if (score >= MEDAL_BRONZE) return Medal.CROQUETA;
  return Medal.NINGUNA;
}

export function medalName(medal: Medal): string {
  if (medal === Medal.JAMON) return 'Jamón';
  if (medal === Medal.TORTILLA) return 'Tortilla';
  if (medal === Medal.CROQUETA) return 'Croqueta';
  return '';
}

export function medalTextureName(medal: Medal): string {
  if (medal === Medal.JAMON) return 'medal_jamon';
  if (medal === Medal.TORTILLA) return 'medal_tortilla';
  if (medal === Medal.CROQUETA) return 'medal_croqueta';
  return '';
}
