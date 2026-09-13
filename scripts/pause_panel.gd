class_name PausePanel
extends CanvasLayer
## Velo de pausa.
##
## Tiene `process_mode = ALWAYS` en la escena: si se pausara con el resto del
## árbol, no podría dibujarse ni responder justo cuando hace falta.

## El jugador quiere seguir jugando.
signal resume_pressed

@onready var _button: Button = $Root/Box/Button


func _ready() -> void:
	_button.pressed.connect(_on_button_pressed)
	visible = false


## Main llama a esto al pausar o reanudar.
func set_paused(paused: bool) -> void:
	visible = paused


func _on_button_pressed() -> void:
	resume_pressed.emit()
