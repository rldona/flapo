class_name PipeSpawner
extends Node2D
## Crea tuberías mientras se juega y limpia lo que queda al reiniciar.
##
## Las tuberías nacen como hijas suyas: así el spawner no necesita llevar
## ninguna lista propia: el árbol de escena YA es la lista. Cada tubería se
## libera sola al salir de pantalla (ADR-0008), y el spawner solo tiene que
## saber cuándo crear y cuándo parar.

## Escena de tubería a instanciar. Se asigna en el editor.
@export var pipe_scene: PackedScene

## X donde nace cada tubería, px. Fuera de pantalla por la derecha, para que
## nunca aparezca de la nada delante del jugador.
@export var spawn_x: float = 320.0

## Semilla del sorteo del hueco. 0 = distinta en cada partida.
## Fijarla hace la partida reproducible, que es lo que usan los tests.
@export var random_seed: int = 0

@onready var _timer: Timer = $Timer

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_timer.timeout.connect(_on_timer_timeout)
	# El intervalo NO es un número propio: es la separación en píxeles del
	# GDD dividida por la velocidad de scroll. Ver GameConfig y ADR-0003.
	_timer.wait_time = GameConfig.pipe_spawn_interval()
	_timer.autostart = false
	# El timer cuenta en frames de física, no de dibujo. Las tuberías se
	# mueven en `_physics_process`, así que si el spawn contase en el reloj
	# de dibujo, la separación real variaría con los fps: justo lo que la
	# ADR-0002 evita en la física de Flapo.
	_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_reiniciar_rng()


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	match to:
		GameState.State.READY:
			_timer.stop()
			_liberar_todas()
			_reiniciar_rng()
		GameState.State.PLAYING:
			# La primera tubería sale ya: si esperásemos al primer timeout,
			# la partida arrancaría con 1,6 s de nada.
			_crear_tuberia()
			_timer.start()
		GameState.State.GAME_OVER:
			_timer.stop()
			_congelar_todas()


## Número de tuberías vivas. Lo usan los tests y el criterio de T-028.
func pipe_count() -> int:
	var n: int = 0
	for hijo in get_children():
		if hijo is Pipe:
			n += 1
	return n


func _on_timer_timeout() -> void:
	_crear_tuberia()


func _crear_tuberia() -> void:
	if pipe_scene == null:
		push_error("PipeSpawner no tiene asignada la escena de tubería.")
		return
	var pipe: Pipe = pipe_scene.instantiate()
	pipe.position = Vector2(spawn_x, 0.0)
	add_child(pipe)
	# Después de add_child: `randomize_gap` toca los nodos internos, que solo
	# existen una vez ha corrido `_ready()` de la tubería.
	pipe.randomize_gap(_rng)


func _liberar_todas() -> void:
	for hijo in get_children():
		if hijo is Pipe:
			hijo.queue_free()


func _congelar_todas() -> void:
	for hijo in get_children():
		if hijo is Pipe:
			hijo.moving = false


func _reiniciar_rng() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
