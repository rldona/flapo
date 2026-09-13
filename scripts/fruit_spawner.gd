class_name FruitSpawner
extends Node2D
## Crea frutas entre tuberías (T-047).
##
## Nacen **a mitad de camino entre dos tuberías** y a una altura del centro:
## así siempre son alcanzables y siempre son esquivables, que es lo que las
## convierte en una decisión. Una fruta pegada a un tubo no se decide, se
## sufre.

## Flapo ha cogido una fruta. El spawner solo hace de puente.
signal taken(kind: Effects.Kind, puntos: int)

## Las de castigo. Se listan aparte porque son las que dan puntos.
const CASTIGOS: Array = [Effects.Kind.PESADO, Effects.Kind.GRANDE]

## Escena de fruta a instanciar.
@export var fruit_scene: PackedScene
## Texturas por efecto, en el orden del enum a partir de INMUNIDAD.
@export var textures: Array[Texture2D] = []
## Probabilidad de que salga fruta en cada hueco entre tuberías.
@export_range(0.0, 1.0) var chance: float = 0.45
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
var _rng := RandomNumberGenerator.new()

@onready var _timer: Timer = $Timer


func _ready() -> void:
	_timer.timeout.connect(_on_timeout)
	_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_timer.wait_time = GameConfig.pipe_spawn_interval()
	_reiniciar_rng()


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	match to:
		GameState.State.READY:
			_timer.stop()
			_liberar_todas()
			_reiniciar_rng()
		GameState.State.PLAYING:
			# Arranca a medio intervalo para que la primera fruta caiga entre
			# la primera y la segunda tubería, no encima de una.
			_timer.start(_timer.wait_time * 0.5)
		GameState.State.GAME_OVER:
			_timer.stop()
			_congelar_todas()


## Recibe la dificultad para ir a la misma velocidad que el resto del mundo.
func set_difficulty(velocidad: float, hueco: float, separacion: float) -> void:
	scroll_speed = velocidad
	_gap_actual = hueco
	if _timer != null:
		_timer.wait_time = separacion / velocidad
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


func _reiniciar_rng() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
