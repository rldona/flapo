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

## El jugador ha cambiado de modo.
signal difficulty_selected(modo: GameConfig.Difficulty)

var _modo: GameConfig.Difficulty = GameConfig.Difficulty.NORMAL

@onready var _play: Button = $Root/Box/Play
@onready var _difficulty: Button = $Root/Box/Difficulty
@onready var _record: Label = $Root/Box/Record


func _ready() -> void:
	_play.pressed.connect(func() -> void: play_pressed.emit())
	# Un solo botón que cicla en vez de tres: a 288 px de ancho tres botones
	# quedan por debajo de los 48 dp táctiles que exige T-030.
	_difficulty.pressed.connect(_on_difficulty_pressed)
	visible = false


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	visible = to == GameState.State.MENU


## Enseña el modo que viene del guardado, sin emitir nada: es un reflejo del
## estado, no una elección del jugador.
func set_difficulty(modo: GameConfig.Difficulty) -> void:
	_modo = modo
	_refrescar()


## El récord, para que el menú no sea una pantalla vacía.
func set_high_score(record: int) -> void:
	_record.text = "Récord: %d" % record


## Qué modo enseña ahora mismo. Lo usan los tests.
func difficulty() -> GameConfig.Difficulty:
	return _modo


func _on_difficulty_pressed() -> void:
	var siguiente: int = (int(_modo) + 1) % (int(GameConfig.Difficulty.DIFICIL) + 1)
	_modo = siguiente as GameConfig.Difficulty
	_refrescar()
	difficulty_selected.emit(_modo)


func _refrescar() -> void:
	if _difficulty != null:
		_difficulty.text = "Modo: %s" % GameConfig.difficulty_name(_modo)
