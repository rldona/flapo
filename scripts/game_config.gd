class_name GameConfig
extends RefCounted
## Constantes de juego compartidas entre varias escenas.
##
## No es un autoload: es un contenedor de constantes que no se instancia
## nunca. Un autoload solo se registra al arrancar el juego, así que
## `--check-only` y los scripts lanzados con `-s` no lo ven (ADR-0009).
## Como aquí no hay estado, no hace falta que sea un nodo.
##
## Aquí vive lo que más de un sistema necesita saber:
## si la velocidad de scroll estuviera duplicada en Pipe, Ground y Parallax,
## tunearla significaría tocar tres sitios y olvidarse de uno.
##
## Regla del proyecto: lo compartido vive aquí; lo que se tunea a ojo en un
## nodo concreto se expone con `@export` en ese nodo. Los valores de esta
## tabla salen de docs/GDD.md y se cierran en T-040.

## Medallas. Con nombre de comida, como pide el GDD ("Concepto y tono"):
## croqueta de bronce, tortilla de plata, jamón de oro.
## Los tres modos que se eligen en el menú. NORMAL es el juego tal y como se
## diseñó: los otros dos son ese mismo juego escalado, no tablas aparte.
enum Difficulty {
	FACIL,
	NORMAL,
	DIFICIL,
}

enum Medal { NINGUNA, CROQUETA, TORTILLA, JAMON }

# --- Pantalla -----------------------------------------------------------
## Tamaño lógico del viewport, en píxeles. Coincide con
## display/window/size/viewport_{width,height} de project.godot.
const VIEWPORT_SIZE := Vector2i(288, 512)

# La física de Flapo (gravedad, impulso, techo) no está aquí: vive como
# `@export` en `scripts/bird.gd` porque es lo que se tunea a ojo en T-040.
# Ver ADR-0003.

## Alto del suelo, px. Se lo restan las tuberías para saber por dónde pueden
## sortear su hueco, y lo usa Ground para su propia colisión.
const GROUND_HEIGHT: float = 64.0

# --- Mundo --------------------------------------------------------------
## Velocidad a la que el mundo se desplaza hacia la izquierda, px/s.
## La usan tuberías, suelo y parallax.
const SCROLL_SPEED: float = 100.0
## Distancia horizontal entre dos pares de tuberías consecutivos, px.
const PIPE_SPACING: float = 160.0

# --- Curva de dificultad (T-045) ----------------------------------------
## Puntuación a la que la dificultad llega a su tope. A partir de ahí el juego
## no sube más: lo que queda es aguantar.
const DIFFICULTY_CAP: int = 30
## Velocidad de scroll en el tope, px/s.
const SCROLL_SPEED_MAX: float = 145.0
## Hueco en el tope, px. Sigue siendo cinco veces la hitbox de Flapo.
const PIPE_GAP_MIN: float = 82.0
## Separación en el tope, px. Sube un poco a propósito: ver ADR-0018.
const PIPE_SPACING_MAX: float = 172.0
## Segundos que dura un aleteo completo, medido con tools/medir_feel.gd.
const FLAP_CYCLE: float = 0.35
## Alto del hueco al empezar la partida, px. Es la base de la curva de
## dificultad; el rango vertical del hueco sigue siendo `@export` de Pipe.
##
## Arranca por encima de los 100 px "de género" a propósito: los primeros
## diez segundos de alguien que no ha jugado nunca son los que deciden si
## sigue. Se estrecha hasta PIPE_GAP_MIN con la puntuación (ADR-0018).
const PIPE_GAP: float = 118.0

# --- Aliento (T-048) ----------------------------------------------------
## Aliento máximo. La escala es arbitraria —lo que importa son las
## proporciones entre gasto y recuperación—, pero 100 se lee como porcentaje
## y hace las cuentas evidentes al tunear.
const MAX_BREATH: float = 100.0

## Lo que cuesta un aleteo. A un ritmo normal de ~2,5 aleteos por segundo son
## 25 de gasto por segundo, algo por encima de lo que se recupera cruzando
## huecos: machacar el botón se paga.
const BREATH_DRAIN_FLAP: float = 10.0

## Lo que cuesta planear, por segundo. Menos que aletear sostenido, que es lo
## que hace del planeo la opción "barata" y le da sentido al recurso.
const BREATH_DRAIN_GLIDE: float = 15.0

## Lo que se recupera al cruzar el hueco **por el centro**. Con un hueco cada
## 1,6 s son ~15,6 por segundo: sostiene el planeo continuo, pero no el
## aleteo continuo. Volar bien se premia; martillear, no.
const BREATH_RECOVER_ON_GAP: float = 25.0

## Qué fracción central del hueco cuenta como "por el centro". Solo la mitad
## central: si valiera todo el hueco, recuperar sería automático y el recurso
## dejaría de existir.
const BREATH_BAND_RATIO: float = 0.5

# --- Modos de dificultad (T-078) ----------------------------------------
## Multiplicador del hueco. Es la palanca que más se nota: el margen de paso
## va de 51 px por lado en fácil a 28 en difícil (hitbox de radio 8).
const DIFFICULTY_GAP_MULT: Array[float] = [1.18, 1.0, 0.88]

## Multiplicador de la velocidad del mundo. Cambia el tiempo de reacción
## desde que la tubería entra en pantalla: 2,5 s en fácil, 1,9 s en difícil.
const DIFFICULTY_SPEED_MULT: Array[float] = [0.85, 1.0, 1.15]

# --- Confianza (T-074) --------------------------------------------------
## Partidas jugadas por cada escalón de confianza. Se cuentan PARTIDAS, no
## puntos: mejora quien insiste, no quien ya juega bien. Es lo que hace la
## progresión narrativa en vez de competitiva ("va cogiendo el truco").
const CONFIDENCE_STEP: int = 10

## Tope de escalones. La progresión termina: un juego que mejora sin límite
## acaba jugándose solo, y a las 50 partidas Flapo ya ha cogido el truco.
const CONFIDENCE_MAX_LEVEL: int = 5

## Aliento extra por escalón. Pequeño a propósito: 8 sobre 100 no se nota en
## una partida, pero la barra es visiblemente más larga a las 50.
const CONFIDENCE_BREATH_BONUS: float = 8.0

# --- Fatiga (T-049) -----------------------------------------------------
## Cuántos aleteos caben en la ventana antes de que empiece a notarse. A los
## 3,4 aleteos por hueco que da la curva de dificultad en su tope (ADR-0018),
## jugar bien nunca llega aquí: solo llega quien machaca el botón.
const FATIGUE_FLAP_COUNT: int = 4

## Ventana que se mira hacia atrás, s.
const FATIGUE_WINDOW: float = 1.2

## Cuánto se reduce el impulso del aleteo estando fatigado, en tanto por uno.
## 0,3 se nota sin quitar el control: Flapo sube menos, no deja de subir.
const FATIGUE_PENALTY: float = 0.3

# --- Puntuación ---------------------------------------------------------
const MEDAL_BRONZE: int = 10
const MEDAL_SILVER: int = 20
const MEDAL_GOLD: int = 40


## Cuánto de dificultad se ha desbloqueado, de 0 a 1.
##
## Todas las magnitudes de la curva son funciones puras de la puntuación: no
## hay estado de dificultad que reiniciar, y con puntuación 0 salen exactamente
## los valores del GDD. Ver ADR-0018.
static func difficulty(score: int) -> float:
	return clampf(float(score) / float(DIFFICULTY_CAP), 0.0, 1.0)


## Cuánto escala el hueco en cada modo (T-078).
static func gap_mult(modo: Difficulty) -> float:
	return DIFFICULTY_GAP_MULT[clampi(int(modo), 0, DIFFICULTY_GAP_MULT.size() - 1)]


## Cuánto escala la velocidad del mundo en cada modo (T-078).
static func speed_mult(modo: Difficulty) -> float:
	return DIFFICULTY_SPEED_MULT[clampi(int(modo), 0, DIFFICULTY_SPEED_MULT.size() - 1)]


## Velocidad de scroll para una puntuación, px/s.
static func scroll_speed_for(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return lerpf(SCROLL_SPEED, SCROLL_SPEED_MAX, difficulty(score)) * speed_mult(modo)


## Alto del hueco para una puntuación, px.
static func pipe_gap_for(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return lerpf(PIPE_GAP, PIPE_GAP_MIN, difficulty(score)) * gap_mult(modo)


## Separación entre tuberías para una puntuación, px.
##
## Escala con la MISMA proporción que la velocidad, y eso no es casualidad:
## así el tiempo entre dos tuberías —y por tanto los aleteos que caben— es
## idéntico en los tres modos. La dificultad cambia el margen y el tiempo de
## reacción, nunca el invariante de ADR-0018 de no bajar de 3 aleteos.
static func pipe_spacing_for(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return lerpf(PIPE_SPACING, PIPE_SPACING_MAX, difficulty(score)) * speed_mult(modo)


## Segundos entre spawns para una puntuación.
static func pipe_spawn_interval_for(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return pipe_spacing_for(score, modo) / scroll_speed_for(score, modo)


## Cuántos aleteos caben entre dos tuberías a esa puntuación.
##
## Es el número que decide si la curva es difícil o injusta: por debajo de 3
## no da tiempo a corregir. Ver docs/GDD.md.
static func flaps_between_pipes(score: int, modo: Difficulty = Difficulty.NORMAL) -> float:
	return pipe_spawn_interval_for(score, modo) / FLAP_CYCLE


## Nombre del modo para la interfaz. Vive aquí y no en el menú porque es
## contenido de las reglas, no de la pantalla que lo enseña.
static func difficulty_name(modo: Difficulty) -> String:
	match modo:
		Difficulty.FACIL:
			return "Fácil"
		Difficulty.DIFICIL:
			return "Difícil"
	return "Normal"


## Segundos entre spawns de tuberías (T-025).
##
## Derivado, no constante suelta: la separación en píxeles es lo que se
## percibe al jugar, y el intervalo es su consecuencia. Si se tunea la
## velocidad de scroll sin tocar esto, la separación real cambiaría.
static func pipe_spawn_interval() -> float:
	return PIPE_SPACING / SCROLL_SPEED


## Alto de la zona por la que Flapo puede volar, px: la pantalla menos el
## suelo. Derivado por el mismo motivo que el intervalo de spawn.
static func playable_height() -> float:
	return float(VIEWPORT_SIZE.y) - GROUND_HEIGHT


## En qué escalón de confianza está alguien que ha jugado `partidas` partidas.
##
## Función pura, como el resto de la progresión: no hay estado de confianza
## que sincronizar, solo un número guardado del que se deriva todo.
static func confidence_level(partidas: int) -> int:
	return clampi(partidas / CONFIDENCE_STEP, 0, CONFIDENCE_MAX_LEVEL)


## Aliento máximo en ese escalón. En el tope, 140 sobre los 100 de salida.
static func max_breath_for(nivel: int) -> float:
	var n: int = clampi(nivel, 0, CONFIDENCE_MAX_LEVEL)
	return MAX_BREATH + float(n) * CONFIDENCE_BREATH_BONUS


## Multiplicador del impulso de aleteo según cuántos aleteos ha habido en la
## ventana reciente (T-049).
##
## Es una **función pura del historial**: no hay estado de fatiga escondido en
## `bird.gd` que haya que reiniciar, sincronizar o depurar. Flapo guarda las
## marcas de tiempo de sus aleteos y pregunta.
static func fatigue_impulse_mult(aleteos_en_ventana: int) -> float:
	return 1.0 - FATIGUE_PENALTY if aleteos_en_ventana > FATIGUE_FLAP_COUNT else 1.0


## Si ese número de aleteos cuenta como fatiga. Lo usa el HUD y los tests.
static func is_fatigued(aleteos_en_ventana: int) -> bool:
	return aleteos_en_ventana > FATIGUE_FLAP_COUNT


## Qué medalla corresponde a una puntuación. Los umbrales viven aquí y no en
## el panel: son regla de juego, no decoración (criterio de T-071).
static func medal_for(score: int) -> Medal:
	if score >= MEDAL_GOLD:
		return Medal.JAMON
	if score >= MEDAL_SILVER:
		return Medal.TORTILLA
	if score >= MEDAL_BRONZE:
		return Medal.CROQUETA
	return Medal.NINGUNA


## Nombre visible de una medalla.
static func medal_name(medal: Medal) -> String:
	match medal:
		Medal.JAMON:
			return "Jamón"
		Medal.TORTILLA:
			return "Tortilla"
		Medal.CROQUETA:
			return "Croqueta"
		_:
			return ""
