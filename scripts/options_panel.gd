class_name OptionsPanel
extends CanvasLayer
## Submenú de opciones (T-087).
##
## **No es un estado nuevo de la máquina**, igual que las estadísticas
## (T-084): es un panel que se abre encima del menú. Detrás sigue estando el
## menú, no hay nada del mundo que cambiar, y un quinto estado obligaría a
## cada pieza del juego a saber que existe una pantalla que no le afecta.
##
## Lo que vive aquí son **ajustes**: cosas que se eligen una vez y persisten.
## Jugar un código o ver las estadísticas son acciones, y se quedan fuera.
## Ese es el criterio que decide qué entra, y el que evita que este panel
## acabe creciendo como creció el menú.
##
## No sabe nada de `Settings` ni de `SaveManager`: recibe qué enseñar y avisa
## de lo que el jugador toca ("signal up", ADR-0005).

## El jugador quiere volver al menú.
signal back_pressed

## El jugador ha escrito su nombre (T-079). Ya viene saneado.
signal name_changed(nombre: String)

## El jugador ha cambiado de modo (T-078).
signal difficulty_selected(modo: GameConfig.Difficulty)

## El jugador ha tocado el silencio (T-061).
signal sound_toggled

## El jugador ha escondido o enseñado el fantasma del récord (T-243).
signal ghost_toggled

## El jugador ha tocado el modo espejo (T-076).
signal mirror_toggled

var _modo: GameConfig.Difficulty = GameConfig.Difficulty.NORMAL
var _muted: bool = false
var _ghost_hidden: bool = false
var _mirror: bool = false

@onready var _name: LineEdit = $Root/Box/Name
@onready var _difficulty: Button = $Root/Box/Difficulty
@onready var _sound: Button = $Root/Box/Sound
@onready var _ghost: Button = $Root/Box/Ghost
@onready var _mirror_button: Button = $Root/Box/Mirror
@onready var _back: Button = $Root/Box/Back


func _ready() -> void:
	_name.max_length = GameConfig.PLAYER_NAME_MAX_LEN
	_name.placeholder_text = GameConfig.PLAYER_NAME_DEFAULT
	# `text_changed` y no `text_submitted`: en móvil mucha gente cierra el
	# teclado sin darle a Intro, y el nombre se perdería.
	_name.text_changed.connect(_on_name_changed)
	# Un solo botón que cicla en vez de tres: a 288 px de ancho tres botones
	# quedan por debajo de los 48 dp táctiles que exige T-030.
	_difficulty.pressed.connect(_on_difficulty_pressed)
	_sound.pressed.connect(func() -> void: sound_toggled.emit())
	_ghost.pressed.connect(func() -> void: ghost_toggled.emit())
	_mirror_button.pressed.connect(func() -> void: mirror_toggled.emit())
	# Escondido hasta que se desbloquea (T-076): un botón desactivado que no
	# dice por qué es peor que no tener botón. Cuando aparece, es un premio.
	_mirror_button.visible = false
	_back.pressed.connect(func() -> void: back_pressed.emit())
	visible = false
	_refrescar()


## Abre o cierra el panel.
func set_open(abierto: bool) -> void:
	visible = abierto


## Si está abierto. Lo usan los tests.
func is_open() -> bool:
	return visible


## Enseña el modo guardado, sin emitir nada: es un reflejo del estado, no una
## elección del jugador.
func set_difficulty(modo: GameConfig.Difficulty) -> void:
	_modo = modo
	_refrescar()


## Qué modo enseña ahora mismo. Lo usan los tests.
func difficulty() -> GameConfig.Difficulty:
	return _modo


## Enseña el nombre guardado, sin emitir nada.
func set_player_name(nombre: String) -> void:
	if _name != null and _name.text != nombre:
		_name.text = nombre


## Lo que hay escrito ahora mismo. Lo usan los tests.
func player_name() -> String:
	return _name.text if _name != null else ""


## Enseña el estado del silencio, sin emitir nada.
func set_muted(muted: bool) -> void:
	_muted = muted
	_refrescar()


## Enseña si el fantasma está escondido, sin emitir nada.
func set_ghost_hidden(oculto: bool) -> void:
	_ghost_hidden = oculto
	_refrescar()


## Enseña el modo espejo, o lo esconde si aún no está desbloqueado (T-076).
func set_mirror(activo: bool, desbloqueado: bool) -> void:
	_mirror = activo
	if _mirror_button != null:
		_mirror_button.visible = desbloqueado
	_refrescar()


## Si el botón del espejo se está viendo. Lo usan los tests.
func mirror_visible() -> bool:
	return _mirror_button != null and _mirror_button.visible


## El texto de cada botón. Lo usan los tests.
func lines_text() -> PackedStringArray:
	if _difficulty == null:
		return PackedStringArray()
	return PackedStringArray([_difficulty.text, _sound.text, _ghost.text, _mirror_button.text])


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


## Los botones dicen **cómo está la cosa**, no qué pasa al pulsarlos.
##
## "Sonido: activado" y no "Silenciar": un botón que enuncia la acción deja
## al jugador adivinando en qué estado está ahora mismo, que es justo lo que
## viene a mirar cuando abre opciones.
func _refrescar() -> void:
	if _difficulty == null:
		return
	_difficulty.text = "Modo: %s" % GameConfig.difficulty_name(_modo)
	_sound.text = "Sonido: %s" % ("apagado" if _muted else "activado")
	_ghost.text = "Fantasma: %s" % ("oculto" if _ghost_hidden else "visible")
	_mirror_button.text = "Espejo: %s" % ("sí" if _mirror else "no")
