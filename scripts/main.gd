extends Node2D
## Raíz de la partida y dueña de la máquina de estados.
##
## Patrón "call down, signal up" (la recomendación oficial de Godot):
## Main conoce a sus hijos y les conecta señales o les llama métodos; los
## hijos nunca buscan a Main con `get_parent()` ni suben por el árbol. Así
## `Bird.tscn` o `Pipe.tscn` se pueden abrir y probar sueltos con F6.
##
## Main no decide *por qué* se cambia de estado, solo que el cambio es legal
## y lo anuncia. Quien detecta la muerte (T-028) llama a `change_state()`.

## Se emite después de que el estado ya ha cambiado, nunca antes: cuando un
## nodo reacciona, `state` ya devuelve el valor nuevo.
signal state_changed(to: GameState.State)

## Puntuación nueva. La emite Main porque es quien lleva la cuenta; el HUD
## (T-029) se cuelga de aquí en vez de preguntar cada frame.
signal score_changed(score: int)

## Flapo. Se asigna arrastrando el nodo en el inspector, no con una ruta de
## texto: si algún día se mueve o se renombra, Godot actualiza la referencia.
@export var bird: Bird

## El generador de tuberías.
@export var pipe_spawner: PipeSpawner

## El suelo.
@export var ground: Ground

## El panel de Game Over.
@export var game_over_panel: GameOverPanel

## El marcador de la partida en curso.
@export var hud: Hud

## El nodo que reparte el jugo al morir (flash, sacudida, hit-stop).
@export var juice: Juice

## Escribe cada transición en la consola. Útil hasta que exista HUD (T-029).
@export var log_transitions: bool = true

## Transiciones legales. Tenerlas en una tabla en vez de repartidas en `if`
## convierte un bug de lógica (reiniciar desde PLAYING, morir dos veces) en
## un aviso en consola en lugar de en un estado imposible.
const _TRANSITIONS: Dictionary = {
	GameState.State.READY: [GameState.State.PLAYING],
	GameState.State.PLAYING: [GameState.State.GAME_OVER],
	GameState.State.GAME_OVER: [GameState.State.READY],
}

var _state: GameState.State = GameState.State.READY
var _score: int = 0


func _ready() -> void:
	if log_transitions:
		state_changed.connect(_on_state_changed_log)
	_connect_children()
	# Se anuncia el estado inicial para que nadie tenga que suponerlo. Los
	# hijos ya están listos: en Godot `_ready()` corre de abajo arriba.
	state_changed.emit(_state)


## `_unhandled_input` y no `_input`: así la UI (botones de T-071) se queda
## primero con el evento y el juego solo ve lo que nadie ha consumido.
func _unhandled_input(event: InputEvent) -> void:
	if _state == GameState.State.READY and event.is_action_pressed("flap"):
		change_state(GameState.State.PLAYING)
	elif _state == GameState.State.GAME_OVER and event.is_action_pressed("restart"):
		restart()


## Estado actual. Solo lectura: cambiarlo pasa por `change_state()`, que es
## lo único que garantiza que se emita la señal.
func get_state() -> GameState.State:
	return _state


## Vuelve a dejarlo todo listo para jugar.
##
## No recarga la escena: cada sistema se reinicia al recibir READY. Ver
## ADR-0011 sobre por qué, y el test de 50 reinicios que lo respalda.
func restart() -> void:
	change_state(GameState.State.READY)


## Puntuación de la partida en curso.
func get_score() -> int:
	return _score


## Intenta pasar a `to`. Ignora el cambio si no es una transición legal.
func change_state(to: GameState.State) -> void:
	if to == _state:
		return
	if not _TRANSITIONS[_state].has(to):
		push_warning(
			"Transición ilegal: %s -> %s" % [_state_name(_state), _state_name(to)]
		)
		return
	_state = to
	# La puntuación se reinicia al volver a READY, no al morir: el panel de
	# Game Over (T-071) tiene que poder seguir enseñándola.
	if to == GameState.State.READY:
		_score = 0
		score_changed.emit(_score)
	state_changed.emit(to)


## "Call down, signal up": el padre cablea, los hijos no se buscan entre sí.
func _connect_children() -> void:
	if bird == null:
		push_error("Main no tiene asignado el nodo Bird en el inspector.")
		return
	state_changed.connect(bird.on_game_state_changed)
	bird.died.connect(_on_bird_died)
	if pipe_spawner == null:
		push_error("Main no tiene asignado el nodo PipeSpawner en el inspector.")
		return
	state_changed.connect(pipe_spawner.on_game_state_changed)
	pipe_spawner.scored.connect(_on_scored)
	if ground == null:
		push_error("Main no tiene asignado el nodo Ground en el inspector.")
		return
	state_changed.connect(ground.on_game_state_changed)
	if game_over_panel == null:
		push_error("Main no tiene asignado el nodo GameOverPanel en el inspector.")
		return
	state_changed.connect(game_over_panel.on_game_state_changed)
	score_changed.connect(game_over_panel.set_score)
	game_over_panel.restart_pressed.connect(restart)
	if hud == null:
		push_error("Main no tiene asignado el nodo Hud en el inspector.")
		return
	state_changed.connect(hud.on_game_state_changed)
	score_changed.connect(hud.set_score)
	if juice == null:
		push_error("Main no tiene asignado el nodo Juice en el inspector.")
		return
	state_changed.connect(juice.on_game_state_changed)


func _on_scored() -> void:
	_score += 1
	score_changed.emit(_score)


func _on_bird_died() -> void:
	if juice != null:
		juice.punch()
	change_state(GameState.State.GAME_OVER)


func _on_state_changed_log(to: GameState.State) -> void:
	print("[Main] estado -> ", _state_name(to))


func _state_name(state: GameState.State) -> String:
	return GameState.State.keys()[state]
