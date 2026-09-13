class_name AirSpawner
extends Node2D
## El aire: lo que no se ve pero se nota (T-203).
##
## De momento, las térmicas. En T-204 vivirá aquí también el rebufo del
## hermano, porque son la misma idea con dos formas: **zonas de aire que
## cambian lo que hace el planeo**, no obstáculos.
##
## Como `FruitSpawner`, no tiene reloj propio: se engancha a
## `PipeSpawner.pipe_spawned` y cuenta tuberías. Un temporizador en paralelo
## se desfasa en cuanto cambia la dificultad —Godot no reinicia la cuenta al
## tocar `wait_time`— y eso ya costó un bug en T-047 (ADR-0019).

## Flapo ha entrado o salido de una térmica. El spawner solo hace de puente.
signal thermal_changed(dentro: bool)

## Escena de térmica a instanciar. Se asigna en el editor.
@export var thermal_scene: PackedScene

## X donde nacen las tuberías, px. Se usa como referencia para colocar la
## térmica **a mitad de camino de la siguiente**, que es el mismo criterio que
## siguen las frutas (ADR-0019) y por el mismo motivo: ahí no estorba a ningún
## hueco. Al nacer fuera de pantalla, la columna se ve llegar con tiempo.
@export var spawn_x: float = 320.0

## Velocidad y separación en curso. Las fija Main con la curva de dificultad.
var scroll_speed: float = GameConfig.SCROLL_SPEED
var spacing: float = GameConfig.PIPE_SPACING

## Tuberías creadas en esta partida. Es lo que hace predecible a la térmica:
## se puede contar, igual que la tubería blandita (T-066).
var _contador: int = 0
## La puntuación actual. La empuja Main ("call down", ADR-0005): el spawner no
## consulta el marcador.
var _score: int = 0

@onready var _pipe_spawner: PipeSpawner = null


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	match to:
		GameState.State.MENU, GameState.State.READY:
			_contador = 0
			_score = 0
			_liberar_todas()
		GameState.State.GAME_OVER:
			_congelar_todas()


## Main le pasa el generador de tuberías para poder reservarle una normal.
func set_pipe_spawner(spawner: PipeSpawner) -> void:
	_pipe_spawner = spawner


## Main empuja la dificultad, como al resto.
func set_difficulty(velocidad: float, separacion: float, score: int) -> void:
	scroll_speed = velocidad
	spacing = separacion
	_score = score
	for hijo in get_children():
		if hijo is Thermal:
			hijo.scroll_speed = velocidad


## Ha nacido una tubería: toca contar y quizá soltar una térmica.
func on_pipe_spawned() -> void:
	_contador += 1
	if not _toca_termica():
		return
	if _pipe_spawner == null:
		return
	# La garantía del ticket, y son DOS comprobaciones porque la térmica cae
	# entre dos tuberías y las dos cuentan.
	#
	# La de detrás ya existe: se mira. La de delante todavía no, así que se le
	# PIDE al generador que salga normal — "lo garantiza el spawner, no el
	# azar", dice el ticket. Si no puede prometerlo (tramo especial en marcha,
	# T-067), no hay térmica.
	var anterior: Pipe = _pipe_spawner.ultima_tuberia()
	if anterior != null and (anterior.oscillation_amplitude > 0.0 or anterior.special):
		return
	if not _pipe_spawner.reservar_normal():
		return
	_crear_termica()


## Si a esta tubería le toca térmica.
##
## Función del contador y de la puntuación, sin azar: la térmica es un
## elemento que se aprende, y algo que se aprende tiene que ser predecible.
func _toca_termica() -> bool:
	if _score < GameConfig.THERMAL_MIN_SCORE:
		return false
	if GameConfig.THERMAL_INTERVAL <= 0:
		return false
	return _contador % GameConfig.THERMAL_INTERVAL == 0


func _crear_termica() -> void:
	if thermal_scene == null:
		push_error("AirSpawner no tiene asignada la escena de térmica.")
		return
	var t: Thermal = thermal_scene.instantiate()
	t.scroll_speed = scroll_speed
	# A mitad de camino de la siguiente tubería: ahí no estorba a ningún
	# hueco, y es el mismo sitio donde van las frutas por el mismo motivo.
	var referencia: float = _pipe_spawner.spawn_x if _pipe_spawner != null else spawn_x
	t.position = Vector2(referencia + spacing * 0.5, GameConfig.playable_height() * 0.5)
	t.cambiado.connect(_on_thermal_cambiado)
	add_child(t)


## Cuántas térmicas hay vivas. Lo usan los tests.
func thermal_count() -> int:
	var n: int = 0
	for hijo in get_children():
		if hijo is Thermal:
			n += 1
	return n


func _on_thermal_cambiado(dentro: bool) -> void:
	thermal_changed.emit(dentro)


func _liberar_todas() -> void:
	for hijo in get_children():
		if hijo is Thermal:
			hijo.queue_free()


func _congelar_todas() -> void:
	for hijo in get_children():
		if hijo is Thermal:
			hijo.moving = false
