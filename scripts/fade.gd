class_name Fade
extends CanvasLayer
## Fundido corto al arrancar la partida.
##
## Cubre la pantalla con un velo del color del cielo y lo va quitando al pasar
## a PLAYING. Es un respiro de un cuarto de segundo entre "estoy mirando" y
## "estoy jugando"; sin él, el primer aleteo y el arranque del mundo ocurren
## en el mismo frame y se siente brusco.
##
## Criterio de T-044: ninguna transición bloquea la entrada más de 1 s. Este
## velo NO bloquea nada: es puramente visual, con `mouse_filter` en ignorar.

## Cuánto dura el fundido, s. Muy por debajo del segundo del criterio.
@export var fade_time: float = 0.25
## Opacidad de partida del velo.
@export_range(0.0, 1.0) var start_alpha: float = 0.6

var _left: float = 0.0

@onready var _rect: ColorRect = $Veil


func _ready() -> void:
	_rect.color.a = 0.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	_rect.color.a = start_alpha * (_left / fade_time)


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	if to == GameState.State.PLAYING:
		_left = fade_time
		_rect.color.a = start_alpha
	else:
		_left = 0.0
		_rect.color.a = 0.0


## Opacidad actual del velo. Lo usan los tests.
func alpha() -> float:
	return _rect.color.a
