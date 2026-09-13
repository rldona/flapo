class_name Background
extends Node2D
## Fondo en dos capas con parallax.
##
## Usa `Parallax2D`, el nodo de Godot 4.3+ que sustituye a la pareja
## `ParallaxBackground` + `ParallaxLayer`. Ver ADR-0012.
##
## El desplazamiento se lleva a mano con `scroll_offset` en vez de con
## `autoscroll`: así el fondo comparte reloj con el suelo y las tuberías, y
## pararlo en GAME_OVER es dejar de sumar, no tocar una propiedad del nodo.

## Fracción de la velocidad de scroll a la que va cada capa, de más lejana a
## más cercana. Lo lejano se mueve menos: es lo que crea la profundidad.
@export var layer_speeds: PackedFloat32Array = PackedFloat32Array([0.15, 0.40])

## Velocidad de scroll de referencia, px/s. Cada capa va a su fracción.
@export var scroll_speed: float = GameConfig.SCROLL_SPEED

## Si está en marcha. Main lo para en GAME_OVER.
@export var moving: bool = true

var _offset: float = 0.0

@onready var _layers: Array[Parallax2D] = [$Far, $Near]


func _process(delta: float) -> void:
	if not moving:
		return
	_offset += scroll_speed * delta
	_apply_offset()


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	# Criterio de T-043: se detiene en GAME_OVER. En READY sigue, igual que
	# el suelo: el mundo está vivo mientras Flapo espera.
	moving = to != GameState.State.GAME_OVER
	if to == GameState.State.READY:
		_offset = 0.0
		_apply_offset()


## Desplazamiento acumulado de la capa `i`, px. Lo usan los tests.
func layer_offset(i: int) -> float:
	return _layers[i].scroll_offset.x


func _apply_offset() -> void:
	for i in _layers.size():
		var factor: float = layer_speeds[i] if i < layer_speeds.size() else 1.0
		_layers[i].scroll_offset.x = -_offset * factor
