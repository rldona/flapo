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

@onready var _score_label: Label = $Root/Box/Score
@onready var _button: Button = $Root/Box/Button


func _ready() -> void:
	_button.pressed.connect(_on_button_pressed)
	visible = false


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	visible = to == GameState.State.GAME_OVER


## Se conecta a `Main.score_changed`, así que el panel siempre trae la
## puntuación al día sin tener que preguntarla al mostrarse.
func set_score(score: int) -> void:
	_score_label.text = str(score)


func _on_button_pressed() -> void:
	restart_pressed.emit()
