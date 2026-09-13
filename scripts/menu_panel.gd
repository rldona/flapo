class_name MenuPanel
extends CanvasLayer
## Pantalla de inicio (T-078): título, jugar y elección de dificultad.
##
## Es un `CanvasLayer` como los otros paneles (GameOver, Pausa) para que viva
## fuera del mundo que hace scroll y no herede su transformación.
##
## No sabe nada de `SaveManager` ni de la partida: recibe qué enseñar y avisa
## de lo que el jugador toca. Quien decide qué significa es `Main`
## ("signal up", ADR-0005). Así el menú se puede montar suelto en un test.

## El jugador quiere empezar.
signal play_pressed

## El jugador ha escrito su nombre (T-079). Ya viene saneado.
signal name_changed(nombre: String)

## El jugador quiere jugar el reto del día (T-241).
signal daily_pressed

## El jugador quiere ver sus estadísticas (T-084).
signal stats_pressed

## El jugador ha cambiado de modo.
signal difficulty_selected(modo: GameConfig.Difficulty)

var _modo: GameConfig.Difficulty = GameConfig.Difficulty.NORMAL

@onready var _play: Button = $Root/Box/Play
@onready var _difficulty: Button = $Root/Box/Difficulty
@onready var _record: Label = $Root/Box/Record
@onready var _stats: Button = $Root/Box/Stats
@onready var _daily: Button = $Root/Box/Daily
@onready var _name: LineEdit = $Root/Box/Name


func _ready() -> void:
	_play.pressed.connect(func() -> void: play_pressed.emit())
	# Un solo botón que cicla en vez de tres: a 288 px de ancho tres botones
	# quedan por debajo de los 48 dp táctiles que exige T-030.
	_difficulty.pressed.connect(_on_difficulty_pressed)
	_stats.pressed.connect(func() -> void: stats_pressed.emit())
	_daily.pressed.connect(func() -> void: daily_pressed.emit())
	_name.max_length = GameConfig.PLAYER_NAME_MAX_LEN
	_name.placeholder_text = GameConfig.PLAYER_NAME_DEFAULT
	# `text_changed` y no `text_submitted`: en móvil mucha gente cierra el
	# teclado sin darle a Intro, y el nombre se perdería.
	_name.text_changed.connect(_on_name_changed)
	visible = false


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	visible = to == GameState.State.MENU


## Enseña el modo que viene del guardado, sin emitir nada: es un reflejo del
## estado, no una elección del jugador.
func set_difficulty(modo: GameConfig.Difficulty) -> void:
	_modo = modo
	_refrescar()


## Enseña el nombre guardado, sin emitir nada.
func set_player_name(nombre: String) -> void:
	if _name != null and _name.text != nombre:
		_name.text = nombre


## Lo que hay escrito ahora mismo. Lo usan los tests.
func player_name() -> String:
	return _name.text if _name != null else ""


## El récord, para que el menú no sea una pantalla vacía.
func set_high_score(record: int) -> void:
	_record.text = "Récord: %d" % record


## Qué modo enseña ahora mismo. Lo usan los tests.
func difficulty() -> GameConfig.Difficulty:
	return _modo


func _on_name_changed(texto: String) -> void:
	var limpio: String = GameConfig.sanitize_player_name(texto)
	if limpio != texto:
		# Se corrige lo escrito en el sitio, para que el jugador vea qué se
		# va a guardar de verdad. `caret_column` al final: sin esto el cursor
		# salta al principio en cuanto se sanea un carácter.
		_name.text = limpio
		_name.caret_column = limpio.length()
	name_changed.emit(limpio)


func _on_difficulty_pressed() -> void:
	var siguiente: int = (int(_modo) + 1) % (int(GameConfig.Difficulty.DIFICIL) + 1)
	_modo = siguiente as GameConfig.Difficulty
	_refrescar()
	difficulty_selected.emit(_modo)


func _refrescar() -> void:
	if _difficulty != null:
		_difficulty.text = "Modo: %s" % GameConfig.difficulty_name(_modo)
