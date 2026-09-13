class_name FruitSpawner
extends Node2D
## Crea frutas entre tuberías (T-047).
##
## Nacen **a mitad de camino entre dos tuberías** y a una altura del centro:
## así siempre son alcanzables y siempre son esquivables, que es lo que las
## convierte en una decisión. Una fruta pegada a un tubo no se decide, se
## sufre.
##
## Para que ese "a mitad de camino" sea verdad, el reloj **no es propio**: se
## engancha a `PipeSpawner.pipe_spawned` y arranca un temporizador de un solo
## disparo a medio intervalo. Con un temporizador propio en paralelo bastaba
## un cambio de dificultad para desfasarlos —Godot no reinicia la cuenta al
## cambiar `wait_time`— y medido daba frutas naciendo a 52 px de una tubería
## en vez de a 85. Ver ADR-0019.

## Flapo ha cogido una fruta. El spawner solo hace de puente.
signal taken(kind: Effects.Kind, puntos: int)

## Las de castigo. Se listan aparte porque son las que dan puntos.
const CASTIGOS: Array = [Effects.Kind.PESADO, Effects.Kind.GRANDE]

## Escena de fruta a instanciar.
@export var fruit_scene: PackedScene
## Texturas por efecto, en el orden del enum a partir de INMUNIDAD.
@export var textures: Array[Texture2D] = []
## Probabilidad de que salga fruta en cada hueco entre tuberías.
@export_range(0.0, 1.0) var chance: float = 0.6
## X donde nacen, px. Fuera de pantalla por la derecha.
@export var spawn_x: float = 320.0
## Franja de altura donde pueden aparecer, como fracción de la altura jugable.
@export_range(0.0, 1.0) var min_ratio: float = 0.25
@export_range(0.0, 1.0) var max_ratio: float = 0.75
## Puntos que dan las frutas de castigo. Es lo que las hace jugables.
@export var penalty_points: int = 3
## Hueco mínimo, px, para que pueda salir la fruta que agranda a Flapo. Por
## debajo de esto sería injusta: ver ADR-0019.
@export var big_min_gap: float = 90.0
## Semilla. 0 = distinta en cada partida.
@export var random_seed: int = 0

var scroll_speed: float = GameConfig.SCROLL_SPEED
var _gap_actual: float = GameConfig.PIPE_GAP
var _separacion: float = GameConfig.PIPE_SPACING
var _rng := RandomNumberGenerator.new()

@onready var _timer: Timer = $Timer


func _ready() -> void:
	_timer.timeout.connect(_on_timeout)
	_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_timer.one_shot = true
	_reiniciar_rng()


## Main conecta aquí la señal de PipeSpawner.
##
## NO se comprueba si se está jugando, y es deliberado: `pipe_spawned` solo
## puede ocurrir jugando, porque las tuberías solo nacen en PLAYING. Una
## guarda aquí parecía inocente y era un bug: `Main` conecta `state_changed`
## en el orden de su tabla de piezas, PipeSpawner va antes que FruitSpawner,
## y la primera tubería se creaba —emitiendo esta señal— antes de que este
## nodo se hubiera enterado de que la partida había empezado. Se perdía la
## primera oportunidad de fruta y, sobre todo, el código dependía de un orden
## que nadie había decidido.
func on_pipe_spawned() -> void:
	_timer.start(_medio_intervalo())


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	match to:
		# MENU se trata igual que READY: la pantalla de inicio es el mundo
		# quieto con un panel encima, no un sitio aparte (T-078).
		GameState.State.MENU, GameState.State.READY:
			_timer.stop()
			_liberar_todas()
			_reiniciar_rng()
		GameState.State.PLAYING:
			pass
		GameState.State.GAME_OVER:
			_timer.stop()
			_congelar_todas()


## Recibe la dificultad para ir a la misma velocidad que el resto del mundo.
func set_difficulty(velocidad: float, hueco: float, separacion: float) -> void:
	scroll_speed = velocidad
	_gap_actual = hueco
	_separacion = separacion
	for hijo in get_children():
		if hijo is Fruit:
			hijo.scroll_speed = velocidad


## Número de frutas vivas. Lo usan los tests.
func fruit_count() -> int:
	var n: int = 0
	for hijo in get_children():
		if hijo is Fruit:
			n += 1
	return n


## Qué frutas pueden salir ahora mismo.
func kinds_disponibles() -> Array:
	var kinds: Array = [
		Effects.Kind.INMUNIDAD,
		Effects.Kind.PESADO,
		Effects.Kind.LIGERO,
		Effects.Kind.LENTO,
	]
	# La naranja solo mientras el hueco dé margen: con Flapo al doble y el
	# hueco ya estrecho, no habría forma humana de pasar.
	if _gap_actual >= big_min_gap:
		kinds.append(Effects.Kind.GRANDE)
	return kinds


## Medio intervalo entre tuberías, en segundos.
func _medio_intervalo() -> float:
	return (_separacion / scroll_speed) * 0.5


func _on_timeout() -> void:
	if _rng.randf() > chance:
		return
	_crear()


func _crear() -> void:
	if fruit_scene == null:
		push_error("FruitSpawner no tiene asignada la escena de fruta.")
		return
	var kinds: Array = kinds_disponibles()
	var kind: Effects.Kind = kinds[_rng.randi_range(0, kinds.size() - 1)]
	var fruit: Fruit = fruit_scene.instantiate()
	fruit.kind = kind
	fruit.points = penalty_points if CASTIGOS.has(kind) else 0
	fruit.scroll_speed = scroll_speed
	fruit.float_phase = _rng.randf() * TAU
	var i: int = int(kind) - 1
	if i >= 0 and i < textures.size():
		fruit.set_texture(textures[i])
	fruit.taken.connect(_on_taken)
	add_child(fruit)
	var ratio: float = _rng.randf_range(min_ratio, max_ratio)
	fruit.place(Vector2(spawn_x, ratio * GameConfig.playable_height()))


func _on_taken(kind: Effects.Kind, puntos: int) -> void:
	taken.emit(kind, puntos)


func _liberar_todas() -> void:
	for hijo in get_children():
		if hijo is Fruit:
			hijo.queue_free()


func _congelar_todas() -> void:
	for hijo in get_children():
		if hijo is Fruit:
			hijo.scroll_speed = 0.0


## Recibe el generador de la partida (T-240).
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func _reiniciar_rng() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
