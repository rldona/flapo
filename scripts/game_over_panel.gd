class_name GameOverPanel
extends CanvasLayer
## Panel que aparece al morir: puntuación y botón para volver a jugar.
##
## Es un `CanvasLayer` para que no lo arrastre el scroll del mundo ni le
## afecte ninguna cámara: la UI vive en su propia capa, en coordenadas de
## pantalla. Versión mínima de T-028; el panel completo con récord, medalla y
## animación de entrada es T-071.
##
## No sabe nada de la máquina de estados: recibe avisos y emite una señal.

## El jugador quiere otra partida.
signal restart_pressed

## Retardo antes de que aparezca el panel, s (GDD: 0,5 s). Da tiempo a ver el
## batacazo entero antes de tapar la pantalla con una caja.
@export var delay: float = 0.5
## Cuánto tarda en aparecer una vez sale, s.
@export var fade_time: float = 0.2

## Segundos que faltan para que salga. Negativo = no hay nada pendiente.
var _delay_left: float = -1.0
var _fade_left: float = 0.0

@onready var _root: Control = $Root
@onready var _score_label: Label = $Root/Box/Score
@onready var _button: Button = $Root/Box/Button


func _ready() -> void:
	_button.pressed.connect(_on_button_pressed)
	_ocultar()


func _process(delta: float) -> void:
	if _delay_left >= 0.0:
		_delay_left -= delta
		if _delay_left < 0.0:
			visible = true
			_fade_left = fade_time
	if _fade_left > 0.0:
		_fade_left = maxf(_fade_left - delta, 0.0)
		_root.modulate.a = 1.0 - _fade_left / fade_time


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	if to == GameState.State.GAME_OVER:
		# No se muestra ya: se programa. Mientras tanto el jugador ve el
		# flash, la sacudida y el rebote de T-042 sin nada encima.
		_delay_left = delay
	else:
		_ocultar()


## Se conecta a `Main.score_changed`, así que el panel siempre trae la
## puntuación al día sin tener que preguntarla al mostrarse.
func set_score(score: int) -> void:
	_score_label.text = str(score)


## Está el panel realmente disponible para el jugador (visible y opaco).
func is_ready_for_input() -> bool:
	return visible and _fade_left <= 0.0


func _ocultar() -> void:
	visible = false
	_delay_left = -1.0
	_fade_left = 0.0
	if _root != null:
		_root.modulate.a = 1.0


func _on_button_pressed() -> void:
	restart_pressed.emit()
