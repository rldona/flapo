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
const PIPE_GAP: float = 100.0

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


## Velocidad de scroll para una puntuación, px/s.
static func scroll_speed_for(score: int) -> float:
	return lerpf(SCROLL_SPEED, SCROLL_SPEED_MAX, difficulty(score))


## Alto del hueco para una puntuación, px.
static func pipe_gap_for(score: int) -> float:
	return lerpf(PIPE_GAP, PIPE_GAP_MIN, difficulty(score))


## Separación entre tuberías para una puntuación, px.
static func pipe_spacing_for(score: int) -> float:
	return lerpf(PIPE_SPACING, PIPE_SPACING_MAX, difficulty(score))


## Segundos entre spawns para una puntuación.
static func pipe_spawn_interval_for(score: int) -> float:
	return pipe_spacing_for(score) / scroll_speed_for(score)


## Cuántos aleteos caben entre dos tuberías a esa puntuación.
##
## Es el número que decide si la curva es difícil o injusta: por debajo de 3
## no da tiempo a corregir. Ver docs/GDD.md.
static func flaps_between_pipes(score: int) -> float:
	return pipe_spawn_interval_for(score) / FLAP_CYCLE


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
