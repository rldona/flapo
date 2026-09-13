class_name PipeSpawner
extends Node2D
## Crea tuberías mientras se juega y limpia lo que queda al reiniciar.
##
## Las tuberías nacen como hijas suyas: así el spawner no necesita llevar
## ninguna lista propia: el árbol de escena YA es la lista. Cada tubería se
## libera sola al salir de pantalla (ADR-0008), y el spawner solo tiene que
## saber cuándo crear y cuándo parar.

## Acaba de nacer una tubería. La usa FruitSpawner para colocarse justo a
## mitad de camino de la siguiente.
signal pipe_spawned

## Flapo ha cruzado una tubería. El spawner solo hace de puente: quien
## detecta el paso es la tubería y quien lleva la cuenta es Main.
signal scored

## Flapo ha cruzado por el centro del hueco (T-048).
signal centered

## Escena de tubería a instanciar. Se asigna en el editor.
@export var pipe_scene: PackedScene

## X donde nace cada tubería, px. Fuera de pantalla por la derecha, para que
## nunca aparezca de la nada delante del jugador.
@export var spawn_x: float = 320.0

## Semilla del sorteo del hueco. 0 = distinta en cada partida.
## Fijarla hace la partida reproducible, que es lo que usan los tests.
@export var random_seed: int = 0

## Velocidad, hueco y separación en curso. Los fija Main con la curva de
## dificultad; los valores por defecto son los de puntuación 0.
var scroll_speed: float = GameConfig.SCROLL_SPEED
var gap: float = GameConfig.PIPE_GAP
var spacing: float = GameConfig.PIPE_SPACING
## Probabilidad de que el próximo par oscile (T-063). La fija Main, que es
## quien conoce la puntuación: el spawner no consulta el marcador ("call
## down", ADR-0005).
var moving_chance: float = 0.0
## Probabilidad de que el próximo par gire (T-065). También la fija Main.
var spin_chance: float = 0.0
## Cuántas tuberías van en esta partida. Es lo que hace predecible a la
## blandita (T-066): se puede contar. Se reinicia en READY.
var _contador: int = 0

## El generador de la partida. Lo inyecta Main (T-240): el spawner NO crea el
## suyo, porque dos generadores son dos partidas distintas.
var _rng := RandomNumberGenerator.new()

@onready var _timer: Timer = $Timer


func _ready() -> void:
	_timer.timeout.connect(_on_timer_timeout)
	# El intervalo NO es un número propio: es la separación en píxeles del
	# GDD dividida por la velocidad de scroll. Ver GameConfig y ADR-0003.
	_timer.wait_time = spacing / scroll_speed
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
		# MENU se trata igual que READY: la pantalla de inicio es el mundo
		# quieto con un panel encima, no un sitio aparte (T-078).
		GameState.State.MENU, GameState.State.READY:
			_contador = 0
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


## Aplica la dificultad de la puntuación actual (ADR-0018).
##
## La velocidad se propaga también a las tuberías YA vivas: si unas fueran
## más rápidas que otras, la separación entre ellas se deformaría en pantalla
## y el mundo dejaría de moverse como un bloque.
func set_difficulty(velocidad: float, hueco: float, separacion: float) -> void:
	scroll_speed = velocidad
	gap = hueco
	spacing = separacion
	if _timer != null:
		_timer.wait_time = spacing / scroll_speed
	for hijo in get_children():
		if hijo is Pipe:
			hijo.scroll_speed = scroll_speed


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
	pipe.scroll_speed = scroll_speed
	pipe.gap = gap
	# Antes de add_child: así ya nace teñida y se distingue desde el primer
	# frame en pantalla, que es el criterio de T-066.
	pipe.soft = GameConfig.is_soft_pipe(_contador)
	_contador += 1
	pipe.position = Vector2(spawn_x, 0.0)
	pipe.scored.connect(_on_pipe_scored)
	pipe.centered.connect(_on_pipe_centered)
	add_child(pipe)
	# Después de add_child: `randomize_gap` toca los nodos internos, que solo
	# existen una vez ha corrido `_ready()` de la tubería.
	pipe.randomize_gap(_rng)
	_quiza_oscilante(pipe)
	# El giro es puramente visual, así que no depende de la altura ni del
	# hueco: se decide y ya está.
	pipe.spin = spin_chance > 0.0 and _rng.randf() < spin_chance
	pipe_spawned.emit()


## Decide si este par oscila, y con cuánta amplitud (T-063).
##
## La amplitud se calcula DESPUÉS de sortear la altura, porque depende de
## ella: un hueco pegado al techo apenas puede subir. Si no cabe margen sale
## 0 y la tubería es normal, que es preferible a mover un hueco medio fuera
## de pantalla.
func _quiza_oscilante(pipe: Pipe) -> void:
	if moving_chance <= 0.0 or _rng.randf() >= moving_chance:
		return
	pipe.oscillation_amplitude = GameConfig.moving_pipe_amplitude(pipe.gap, pipe.get_gap_center())
	# Desfase al azar: si todas arrancaran en el mismo punto del seno, la
	# pantalla entera temblaría a la vez en vez de parecer tuberías sueltas.
	pipe.oscillation_phase = _rng.randf_range(0.0, TAU)


func _on_pipe_scored() -> void:
	scored.emit()


func _on_pipe_centered() -> void:
	centered.emit()


func _liberar_todas() -> void:
	for hijo in get_children():
		if hijo is Pipe:
			hijo.queue_free()


func _congelar_todas() -> void:
	for hijo in get_children():
		if hijo is Pipe:
			hijo.moving = false


## Recibe el generador de la partida (T-240).
##
## Se comparte, no se copia: si cada sistema tuviera el suyo, la misma
## semilla daría partidas distintas según el orden en que se consultaran.
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func _reiniciar_rng() -> void:
	# `random_seed` sigue existiendo para poder aislar el spawner en un test
	# suelto. En la partida real vale 0 y manda el generador de Main.
	if random_seed != 0:
		_rng.seed = random_seed
