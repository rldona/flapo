extends Node
## Constantes de juego compartidas entre varias escenas.
##
## Autoload (`GameConfig`). Aquí vive lo que más de un sistema necesita saber:
## si la velocidad de scroll estuviera duplicada en Pipe, Ground y Parallax,
## tunearla significaría tocar tres sitios y olvidarse de uno.
##
## Regla del proyecto: lo compartido vive aquí; lo que se tunea a ojo en un
## nodo concreto se expone con `@export` en ese nodo. Los valores de esta
## tabla salen de docs/GDD.md y se cierran en T-040.

# --- Pantalla -----------------------------------------------------------
## Tamaño lógico del viewport, en píxeles. Coincide con
## display/window/size/viewport_{width,height} de project.godot.
const VIEWPORT_SIZE := Vector2i(288, 512)

# La física de Flapo (gravedad, impulso, techo) no está aquí: vive como
# `@export` en `scripts/bird.gd` porque es lo que se tunea a ojo en T-040.
# Ver ADR-0003.

# --- Mundo --------------------------------------------------------------
## Velocidad a la que el mundo se desplaza hacia la izquierda, px/s.
## La usan tuberías, suelo y parallax.
const SCROLL_SPEED: float = 100.0
## Distancia horizontal entre dos pares de tuberías consecutivos, px.
const PIPE_SPACING: float = 160.0
## Alto del hueco por el que pasa Flapo, px.
const PIPE_GAP: float = 100.0
## Rango vertical (fracción de la altura jugable) donde puede caer el centro
## del hueco. Evita huecos pegados al techo o al suelo.
const GAP_RANGE_MIN: float = 0.20
const GAP_RANGE_MAX: float = 0.80

# --- Puntuación ---------------------------------------------------------
const MEDAL_BRONZE: int = 10
const MEDAL_SILVER: int = 20
const MEDAL_GOLD: int = 40


## Segundos entre spawns de tuberías (T-025).
##
## Derivado, no constante suelta: la separación en píxeles es lo que se
## percibe al jugar, y el intervalo es su consecuencia. Si se tunea la
## velocidad de scroll sin tocar esto, la separación real cambiaría.
func pipe_spawn_interval() -> float:
	return PIPE_SPACING / SCROLL_SPEED
