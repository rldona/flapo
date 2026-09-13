class_name ReplayRecorder
extends Node
## Graba la partida en curso para poder reproducirla (T-261).
##
## Graba **flancos del botón**, no eventos con marca de tiempo: en qué frame
## de física se pulsó y en cuál se soltó. Con la física a 60 Hz fijos
## (ADR-0002) y toda la aleatoriedad sembrada (T-240), eso basta para repetir
## la partida entera.
##
## Límite conocido: un toque que empiece y acabe **dentro del mismo frame**
## (menos de 16 ms) no deja flanco y se pierde. Ver ADR-0036.
##
## Solo graba. Reproducir es cosa de `tools/replay_player.gd`, que no viaja en
## el export: el juego no necesita saber reproducirse a sí mismo.

## Frame de física desde el primero de `PLAYING`.
var _frame: int = 0
var _activo: bool = false
var _ultimo: bool = false
var _replay := Replay.new()


## Main dice con qué va a jugarse, ya sembrado (T-240).
func preparar(semilla: int, modo: GameConfig.Difficulty, confianza: int) -> void:
	_replay = Replay.new()
	_replay.semilla = semilla
	_replay.modo = modo
	_replay.confianza = confianza
	_frame = 0
	_ultimo = false


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	match to:
		GameState.State.MENU, GameState.State.READY:
			_activo = false
			_frame = 0
			_ultimo = false
		GameState.State.PLAYING:
			_activo = true
		GameState.State.GAME_OVER:
			_activo = false


func _physics_process(_delta: float) -> void:
	if not _activo:
		return
	var ahora: bool = Input.is_action_pressed("flap")
	if ahora != _ultimo:
		_replay.anotar(_frame, ahora)
		_ultimo = ahora
	_frame += 1


## Main llama a esto al morir: deja la última partida siempre a mano.
##
## Se guarda SIEMPRE, no solo cuando pasa algo raro. Un replay solo sirve si
## ya está grabado cuando aparece el bug; pedirle al jugador que active una
## grabación y lo reproduzca es pedirle justo lo que no va a hacer.
func terminar(score: int) -> void:
	_replay.score = score
	_replay.guardar()


## Guarda una copia aparte, desde el botón de la pausa. Devuelve la ruta, o
## vacío si no se ha podido.
##
## Con fecha en el nombre para que guardar dos veces no pise la primera: quien
## le da a este botón está intentando conservar algo concreto.
func guardar_copia(score: int) -> String:
	_replay.score = score
	var ruta: String = (
		"user://replay_%s.replay" % Time.get_datetime_string_from_system().replace(":", "-")
	)
	return ruta if _replay.guardar(ruta) else ""


## El replay que se lleva grabado. Lo usan los tests.
func replay() -> Replay:
	return _replay
