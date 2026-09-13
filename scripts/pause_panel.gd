class_name PausePanel
extends CanvasLayer
## Velo de pausa.
##
## Tiene `process_mode = ALWAYS` en la escena: si se pausara con el resto del
## árbol, no podría dibujarse ni responder justo cuando hace falta.

## El jugador quiere seguir jugando.
signal resume_pressed

## El jugador ha tocado el botón de silencio.
signal mute_pressed

## El jugador quiere guardar esta partida para reportarla (T-261).
signal save_replay_pressed

@onready var _button: Button = $Root/Box/Button
@onready var _mute_button: Button = $Root/Box/MuteButton
@onready var _save_button: Button = $Root/Box/SaveButton
@onready var _aviso: Label = $Root/Box/Aviso


func _ready() -> void:
	_mute_button.pressed.connect(func() -> void: mute_pressed.emit())
	_button.pressed.connect(_on_button_pressed)
	_save_button.pressed.connect(func() -> void: save_replay_pressed.emit())
	_aviso.text = ""
	visible = false


## Main llama a esto al pausar o reanudar.
func set_paused(paused: bool) -> void:
	visible = paused
	# El aviso se borra al abrir la pausa: si se quedara puesto, la próxima
	# vez parecería que se acaba de guardar algo que no se ha guardado.
	if paused:
		set_aviso("")


## Enseña un aviso corto, o lo quita.
func set_aviso(texto: String) -> void:
	if _aviso != null:
		_aviso.text = texto


## Lo que dice el aviso ahora mismo. Lo usan los tests.
func aviso() -> String:
	return _aviso.text if _aviso != null else ""


func _on_button_pressed() -> void:
	resume_pressed.emit()


## Refleja el estado del silencio en el botón.
func set_muted(muted: bool) -> void:
	_mute_button.text = "Sonido: no" if muted else "Sonido: sí"
