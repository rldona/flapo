class_name MenuPanel
extends CanvasLayer
## Pantalla de inicio (T-078): título, récord y por dónde se empieza.
##
## Lo que hay aquí son **acciones**: jugar, el reto de hoy, un código, ver
## estadísticas. Los ajustes —nombre, modo, sonido, fantasma— se fueron a
## `OptionsPanel` en T-087, cuando esto llegó a nueve elementos apilados en
## una columna de 288 px y dejó de leerse de un vistazo.
##
## Es un `CanvasLayer` como los otros paneles (GameOver, Pausa) para que viva
## fuera del mundo que hace scroll y no herede su transformación.
##
## No sabe nada de `SaveManager` ni de la partida: recibe qué enseñar y avisa
## de lo que el jugador toca. Quien decide qué significa es `Main`
## ("signal up", ADR-0005). Así el menú se puede montar suelto en un test.

## El jugador quiere empezar.
signal play_pressed

## El jugador quiere jugar un código concreto (T-242).
signal code_pressed(codigo: String)

## El jugador quiere jugar el reto del día (T-241).
signal daily_pressed

## El jugador quiere ver sus estadísticas (T-084).
signal stats_pressed

## El jugador quiere abrir las opciones (T-087).
signal options_pressed

@onready var _play: Button = $Root/Box/Play
@onready var _options: Button = $Root/Box/Options
@onready var _record: Label = $Root/Box/Record
@onready var _stats: Button = $Root/Box/Stats
@onready var _daily: Button = $Root/Box/Daily
@onready var _code: LineEdit = $Root/Box/Code
@onready var _code_play: Button = $Root/Box/CodePlay
@onready var _aviso: Label = $Root/Box/Aviso


func _ready() -> void:
	_play.pressed.connect(func() -> void: play_pressed.emit())
	_options.pressed.connect(func() -> void: options_pressed.emit())
	_stats.pressed.connect(func() -> void: stats_pressed.emit())
	_daily.pressed.connect(func() -> void: daily_pressed.emit())
	_code.max_length = GameConfig.CODIGO_LARGO
	_code_play.pressed.connect(func() -> void: code_pressed.emit(_code.text))
	# Escribir borra el aviso anterior: dejarlo puesto mientras el jugador
	# corrige haría pensar que el código nuevo también está mal.
	_code.text_changed.connect(func(_t: String) -> void: set_aviso(""))
	_aviso.text = ""
	visible = false


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	visible = to == GameState.State.MENU


## Enseña un aviso corto bajo el código, o lo quita (T-242).
func set_aviso(texto: String) -> void:
	_aviso.text = texto


## Lo que dice el aviso ahora mismo. Lo usan los tests.
func aviso() -> String:
	return _aviso.text if _aviso != null else ""


## El récord, para que el menú no sea una pantalla vacía.
##
## Con el nido delante si el jugador ha completado el viaje (T-209). Un
## símbolo y no una línea aparte: quien ha llegado ya lo sabe, y a quien no ha
## llegado no se le anuncia lo que le falta.
func set_high_score(record: int, viaje_completado: bool = false) -> void:
	var nido: String = "🪹 " if viaje_completado else ""
	_record.text = "%sRécord: %d" % [nido, record]
