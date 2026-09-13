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

## Flapo ha entrado o salido de la estela del hermano (T-204).
signal slipstream_changed(dentro: bool)

## Escena de térmica a instanciar. Se asigna en el editor.
@export var thermal_scene: PackedScene

## Escena del hermano y de su estela (T-204).
@export var brother_scene: PackedScene
@export var slipstream_scene: PackedScene

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
		if hijo is Thermal or hijo is Brother or hijo is Slipstream:
			hijo.scroll_speed = velocidad


## Ha nacido una tubería: toca contar y quizá soltar una térmica.
func on_pipe_spawned() -> void:
	_contador += 1
	_quiza_hermano()
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


## Si a esta tubería le toca que pase el hermano (T-204).
##
## Va aparte de la térmica y con otro intervalo: son dos cosas distintas y
## coincidir de vez en cuando está bien, pero atarlas las haría previsibles
## juntas y el chiste dejaría de sorprender.
func _quiza_hermano() -> void:
	if _score < AirConfig.BROTHER_MIN_SCORE:
		return
	if AirConfig.BROTHER_INTERVAL <= 0 or _contador % AirConfig.BROTHER_INTERVAL != 0:
		return
	if brother_scene == null or slipstream_scene == null:
		return
	var y: float = _altura_libre()

	var hermano: Brother = brother_scene.instantiate()
	hermano.scroll_speed = scroll_speed
	hermano.position = Vector2(GameConfig.VIEWPORT_SIZE.x + 24.0, y)
	add_child(hermano)

	var estela: Slipstream = slipstream_scene.instantiate()
	estela.scroll_speed = scroll_speed
	estela.ancho = float(GameConfig.VIEWPORT_SIZE.x)
	estela.position = Vector2(float(GameConfig.VIEWPORT_SIZE.x) * 0.5, y)
	estela.cambiado.connect(_on_slipstream_cambiado)
	add_child(estela)


## Por dónde cruza el hermano sin tapar ningún hueco (T-204).
##
## Por el borde de arriba o el de abajo, eligiendo el contrario al hueco que
## toca cruzar ahora. Los huecos se sortean entre el 20 % y el 80 % de la
## altura, así que un borde nunca cae dentro de ninguno — y eso vale para
## todas las tuberías que el hermano se cruce, no solo la siguiente.
func _altura_libre() -> float:
	var alto: float = GameConfig.playable_height()
	var centro: float = alto * 0.5
	if _pipe_spawner != null:
		var ultima: Pipe = _pipe_spawner.ultima_tuberia()
		if ultima != null:
			centro = ultima.get_gap_center()
	# El hueco está arriba: cruza por abajo, y al revés. Así, además de no
	# tapar nada, pasa por donde el jugador no está mirando.
	if centro < alto * 0.5:
		return alto - AirConfig.BROTHER_EDGE_MARGIN
	return AirConfig.BROTHER_EDGE_MARGIN


## Cuántos hermanos hay cruzando. Lo usan los tests.
func brother_count() -> int:
	var n: int = 0
	for hijo in get_children():
		if hijo is Brother:
			n += 1
	return n


## Cuántas estelas hay vivas. Lo usan los tests.
func slipstream_count() -> int:
	var n: int = 0
	for hijo in get_children():
		if hijo is Slipstream:
			n += 1
	return n


func _on_slipstream_cambiado(dentro: bool) -> void:
	slipstream_changed.emit(dentro)


## Si a esta tubería le toca térmica.
##
## Función del contador y de la puntuación, sin azar: la térmica es un
## elemento que se aprende, y algo que se aprende tiene que ser predecible.
func _toca_termica() -> bool:
	if _score < AirConfig.THERMAL_MIN_SCORE:
		return false
	if AirConfig.THERMAL_INTERVAL <= 0:
		return false
	return _contador % AirConfig.THERMAL_INTERVAL == 0


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
		hijo.queue_free()


func _congelar_todas() -> void:
	for hijo in get_children():
		if hijo is Thermal or hijo is Brother or hijo is Slipstream:
			hijo.moving = false
