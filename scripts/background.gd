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
var _variante: GameConfig.Scenery = GameConfig.Scenery.DIA
## El tramo del viaje que se está enseñando y el que se quiere enseñar
## (T-222). Cuando no coinciden, hay fundido en marcha.
var _tramo: GameConfig.Stage = GameConfig.Stage.PARQUE
## Cuánto llevamos del fundido, de 0 a 1.
var _mezcla: float = 1.0

@onready var _layers: Array[Parallax2D] = [$Far, $Near]
## Las cuatro capas de tramo, en el orden del enum. Viven **todas** dentro del
## mismo `Parallax2D` y existen desde el primer frame: cambiar de tramo es
## mover alfas, no crear ni destruir nodos. Por eso no puede haber capas
## huérfanas — no hay nada que quedarse huérfano (ADR-0040).
@onready var _tramos: Array[Sprite2D] = [$Near/Parque, $Near/City, $Near/Nubes, $Near/Cielo]
@onready var _rain: CPUParticles2D = $Rain


func _process(delta: float) -> void:
	_avanzar_fundido(delta)
	if not moving:
		return
	_offset += scroll_speed * delta
	_apply_offset()


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	# Criterio de T-043: se detiene en GAME_OVER. En READY sigue, igual que
	# el suelo: el mundo está vivo mientras Flapo espera.
	moving = to != GameState.State.GAME_OVER
	if to == GameState.State.READY or to == GameState.State.MENU:
		_offset = 0.0
		_apply_offset()
		# Al empezar se vuelve al parque de golpe, sin fundido: el fundido
		# cuenta un viaje, y aquí no se ha viajado todavía.
		_tramo = GameConfig.Stage.PARQUE
		_mezcla = 1.0
		_aplicar_tramos()


## Aplica la variante de escenario (T-057).
##
## Solo tiñe y enciende la lluvia. **No toca `layer_speeds` ni el offset**: si
## una variante cambiara la velocidad del parallax, dejaría de ser cosmética y
## el mundo iría distinto según el cielo que tocara.
func set_variant(variante: GameConfig.Scenery) -> void:
	_variante = variante
	var tinte: Color = GameConfig.scenery_tint(variante)
	for capa in _layers:
		capa.modulate = tinte
	if _rain != null:
		_rain.emitting = GameConfig.scenery_rains(variante)


## Main empuja el tramo que toca (T-222). "Call down" (ADR-0005): el fondo no
## consulta el marcador, lo recibe.
##
## Si es el mismo, no pasa nada: llamarlo en cada punto es lo normal.
func set_stage(tramo: GameConfig.Stage) -> void:
	if tramo == _tramo:
		return
	_tramo = tramo
	_mezcla = 0.0


## Qué tramo se está enseñando. Lo usan los tests.
func stage() -> GameConfig.Stage:
	return _tramo


## Cuánto lleva el fundido, de 0 a 1. Lo usan los tests.
func mezcla() -> float:
	return _mezcla


## Avanza el fundido entre tramos.
##
## Corre aunque el mundo esté parado: si el jugador muere a mitad de un
## cambio, el paisaje termina de cambiar en vez de quedarse a medias.
func _avanzar_fundido(delta: float) -> void:
	if _mezcla >= 1.0:
		return
	if GameConfig.JOURNEY_FADE_TIME <= 0.0:
		_mezcla = 1.0
	else:
		_mezcla = minf(_mezcla + delta / GameConfig.JOURNEY_FADE_TIME, 1.0)
	_aplicar_tramos()


## Reparte la opacidad entre las cuatro capas.
##
## Solo dos tienen alfa a la vez: la del tramo nuevo entrando y **la anterior**
## saliendo. Se guarda cuál era la anterior en el propio índice: el tramo
## siempre avanza de uno en uno porque la puntuación sube de uno en uno.
func _aplicar_tramos() -> void:
	if _tramos.is_empty():
		return
	var anterior: int = maxi(int(_tramo) - 1, 0)
	for i in _tramos.size():
		var alfa: float = 0.0
		if i == int(_tramo):
			alfa = _mezcla
		elif i == anterior and int(_tramo) > 0:
			alfa = 1.0 - _mezcla
		_tramos[i].modulate.a = alfa


## La opacidad de una capa de tramo. Lo usan los tests.
func stage_alpha(i: int) -> float:
	return _tramos[i].modulate.a if i >= 0 and i < _tramos.size() else 0.0


## Qué variante está puesta. Lo usan los tests.
func variant() -> GameConfig.Scenery:
	return _variante


## Desplazamiento acumulado de la capa `i`, px. Lo usan los tests.
func layer_offset(i: int) -> float:
	return _layers[i].scroll_offset.x


func _apply_offset() -> void:
	for i in _layers.size():
		var factor: float = layer_speeds[i] if i < layer_speeds.size() else 1.0
		_layers[i].scroll_offset.x = -_offset * factor
