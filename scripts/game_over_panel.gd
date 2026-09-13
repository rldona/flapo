class_name GameOverPanel
extends CanvasLayer
## Panel que aparece al morir: medalla, puntuación, récord y botones.
##
## Es un `CanvasLayer` para que no lo arrastre el scroll del mundo ni le
## afecte la cámara: la UI vive en coordenadas de pantalla. Y por eso no le
## afecta la sacudida de T-042, que mueve la cámara y no el mundo.
##
## No sabe nada de la máquina de estados ni de dónde salen los números:
## recibe avisos y datos, y emite señales.

## El jugador quiere otra partida.
signal restart_pressed
## El jugador quiere compartir su marca. Solo se puede pulsar en Android.
signal share_pressed(texto: String)

## El jugador ha tocado el botón de silencio.
signal mute_pressed

## Retardo antes de que aparezca el panel, s (GDD: 0,5 s). Da tiempo a ver el
## batacazo entero antes de tapar la pantalla con una caja.
@export var delay: float = 0.5
## Cuánto tarda en aparecer una vez sale, s.
@export var fade_time: float = 0.2
## Escala de partida de la animación de entrada. 1.0 la desactiva.
@export_range(0.5, 1.0) var pop_scale: float = 0.86

## Imágenes de las medallas, en el orden del enum: croqueta, tortilla, jamón.
@export var medal_textures: Array[Texture2D] = []

## Segundos que faltan para que salga. Negativo = no hay nada pendiente.
var _delay_left: float = -1.0
var _fade_left: float = 0.0
var _score: int = 0

@onready var _root: Control = $Root
@onready var _box: VBoxContainer = $Root/Box
@onready var _medal_rect: TextureRect = $Root/Box/Medal
@onready var _medal_label: Label = $Root/Box/MedalName
@onready var _score_label: Label = $Root/Box/Score
@onready var _high_label: Label = $Root/Box/HighScore
@onready var _record_label: Label = $Root/Box/NewRecord
@onready var _button: Button = $Root/Box/Button
@onready var _mute_button: Button = $Root/Box/MuteButton
@onready var _share_button: Button = $Root/Box/ShareButton


func _ready() -> void:
	_mute_button.pressed.connect(func() -> void: mute_pressed.emit())
	_button.pressed.connect(_on_button_pressed)
	_share_button.pressed.connect(_on_share_pressed)
	# Compartir solo tiene sentido donde hay algo con lo que compartir.
	_share_button.visible = OS.has_feature("android")
	_ocultar()


func _process(delta: float) -> void:
	if _delay_left >= 0.0:
		_delay_left -= delta
		if _delay_left < 0.0:
			visible = true
			_fade_left = fade_time
	if _fade_left > 0.0:
		_fade_left = maxf(_fade_left - delta, 0.0)
		var t: float = 1.0 - _fade_left / fade_time
		_root.modulate.a = t
		# Entra creciendo un poco: da sensación de que el panel "llega", en
		# vez de aparecer de la nada encima del cadáver de Flapo.
		_escalar(lerpf(pop_scale, 1.0, t))


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	if to == GameState.State.GAME_OVER:
		# No se muestra ya: se programa. Mientras tanto el jugador ve el
		# flash, la sacudida y el rebote de T-042 sin nada encima.
		_delay_left = delay
	else:
		_ocultar()


## Rellena el panel con el resultado de la partida.
func show_results(score: int, high_score: int, is_record: bool) -> void:
	_score = score
	_score_label.text = str(score)
	_high_label.text = "Récord %d" % high_score
	_record_label.visible = is_record
	var medal: GameConfig.Medal = GameConfig.medal_for(score)
	_medal_label.text = GameConfig.medal_name(medal)
	_medal_label.visible = medal != GameConfig.Medal.NINGUNA
	# El enum empieza en NINGUNA, así que la textura es el índice menos uno.
	var i: int = int(medal) - 1
	_medal_rect.visible = i >= 0 and i < medal_textures.size()
	if _medal_rect.visible:
		_medal_rect.texture = medal_textures[i]


## Se conecta a `Main.score_changed` para que el marcador esté al día
## aunque nadie haya llamado todavía a `show_results()`.
func set_score(score: int) -> void:
	_score = score
	_score_label.text = str(score)


## Está el panel realmente disponible para el jugador (visible y opaco).
func is_ready_for_input() -> bool:
	return visible and _fade_left <= 0.0


func _escalar(factor: float) -> void:
	_box.scale = Vector2(factor, factor)
	# `pivot_offset` al centro: si no, el panel crece hacia abajo y a la
	# derecha en vez de desde su propio centro.
	_box.pivot_offset = _box.size * 0.5


func _ocultar() -> void:
	visible = false
	_delay_left = -1.0
	_fade_left = 0.0
	if _root != null:
		_root.modulate.a = 1.0
	if _box != null:
		_escalar(1.0)


func _on_button_pressed() -> void:
	restart_pressed.emit()


func _on_share_pressed() -> void:
	var pieza: String = "1 tubería" if _score == 1 else "%d tuberías" % _score
	share_pressed.emit("He cruzado %s con Flapo." % pieza)


## Refleja el estado del silencio en el botón.
func set_muted(muted: bool) -> void:
	_mute_button.text = "Sonido: no" if muted else "Sonido: sí"
