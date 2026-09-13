class_name Hud
extends CanvasLayer
## Marcador de la partida en curso.
##
## `CanvasLayer` por lo mismo que el panel de Game Over: la UI vive en
## coordenadas de pantalla y no la arrastra el scroll del mundo.
##
## No cuenta nada ni pregunta nada: se limita a enseñar lo que Main le manda
## por `score_changed`. Si algún día el marcador se desincroniza, el fallo
## está en quien cuenta, no aquí.
##
## Sí se ocupa de no meterse debajo del notch: ver `_aplicar_margen_seguro()`.

## Color de la barra de aliento en reposo y fatigado.
const COLOR_ALIENTO := Color(0.949, 0.851, 0.655)
## Color del aviso de viento. Ámbar: advertencia, no información.
const COLOR_AVISO: Color = Color("#E6B84A")
const COLOR_FATIGA := Color(0.851, 0.537, 0.447)

## Separación mínima del borde superior, px de juego. Se suma al margen que
## reporte el sistema, para que el marcador no quede pegado al borde ni
## siquiera en una pantalla sin notch.
## Cómo se llama el escudo en pantalla. En `@export` y no escrito dentro del
## código porque es texto que se ve: cambiarlo no debería obligar a tocar la
## lógica que decide cuándo sale.
@export var texto_escudo: String = "Escudo"

@export var margen_superior: float = 24.0

@onready var _score_label: Label = $Score
@onready var _effect_label: Label = $Effect
@onready var _shield_label: Label = $Shield
@onready var _wind_label: Label = $Wind
@onready var _journey_label: Label = $Journey
@onready var _breath_back: ColorRect = $Breath/Back
@onready var _breath_fill: ColorRect = $Breath/Fill


func _ready() -> void:
	visible = false
	_effect_label.visible = false
	_wind_label.visible = false
	_shield_label.visible = false
	_aplicar_margen_seguro()
	# En móvil el área segura puede cambiar al rotar o al aparecer barras.
	get_tree().root.size_changed.connect(_aplicar_margen_seguro)


## Baja el marcador por debajo del notch, si lo hay.
##
## `get_display_safe_area()` viene en píxeles REALES de pantalla, y el juego
## dibuja en 288×512 lógicos. Hay que convertir con la escala del viewport, o
## en un móvil de 1080 de ancho el margen saldría cuarenta veces mayor de lo
## que toca.
func _aplicar_margen_seguro() -> void:
	var pantalla: Vector2i = DisplayServer.window_get_size()
	var segura: Rect2i = DisplayServer.get_display_safe_area()
	var margen: float = margen_seguro(pantalla.y, segura.position.y, margen_superior)
	_score_label.offset_top = margen
	_score_label.offset_bottom = margen + 32.0


## Margen superior en píxeles DE JUEGO, dado el alto real de la pantalla y el
## recorte que reporta el sistema.
##
## Está aparte y es `static` para poder probarla con un notch inventado: en
## headless no hay pantalla que consultar. La conversión es lo que importa:
## `get_display_safe_area()` devuelve píxeles reales y el juego dibuja en
## 288×512 lógicos, así que en un móvil de 2400 de alto un notch de 100 px
## son 21 px de juego, no 100.
static func margen_seguro(alto_pantalla: int, recorte: int, base: float) -> float:
	if recorte <= 0 or alto_pantalla <= 0:
		return base
	var escala: float = float(GameConfig.VIEWPORT_SIZE.y) / float(alto_pantalla)
	return base + float(recorte) * escala


## Main llama a esto al cambiar de estado ("call down", ADR-0005).
func on_game_state_changed(to: GameState.State) -> void:
	# Solo durante la partida: en READY estorbaría a la pantalla de inicio y
	# en GAME_OVER lo sustituye el panel, que ya enseña la puntuación.
	visible = to == GameState.State.PLAYING


func set_score(score: int) -> void:
	_score_label.text = str(score)


## Qué efecto de fruta está activo y cuánto le queda (T-047).
##
## Se enseña el nombre y los segundos porque un efecto invisible es un efecto
## que el jugador cree que es un bug: "¿por qué caigo más rápido de golpe?".
func set_effect(nombre: String, restante: float) -> void:
	_effect_label.visible = nombre != ""
	if _effect_label.visible:
		_effect_label.text = "%s %.0f" % [nombre, ceilf(restante)]


## Anuncia o niega el viento (T-064).
##
## El aviso y la ráfaga se distinguen en el texto **y** en el color: durante
## el aviso es una advertencia (ámbar, "se acerca"), soplando es un hecho
## (blanco). Si fueran el mismo cartel, el jugador no sabría si tiene dos
## segundos para colocarse o si ya está pasando.
func set_wind(fase: String, a_favor: bool) -> void:
	_wind_label.visible = fase != ""
	if not _wind_label.visible:
		return
	var flecha: String = "»»" if a_favor else "««"
	if fase == "aviso":
		_wind_label.text = "%s viento %s" % [flecha, flecha]
		_wind_label.modulate = COLOR_AVISO
	else:
		_wind_label.text = "%s %s %s" % [flecha, flecha, flecha]
		_wind_label.modulate = Color.WHITE


## La línea del final del viaje (T-209), o "" para quitarla.
##
## Va en el HUD y no en un panel propio porque **no para el juego**: la
## partida sigue debajo. Un panel encima diría "esto ha terminado", y es justo
## lo contrario de lo que pasa.
func set_journey_line(texto: String) -> void:
	if _journey_label == null:
		return
	_journey_label.text = texto
	_journey_label.visible = texto != ""


## Lo que dice la línea del nido ahora mismo. Lo usan los tests.
func journey_line() -> String:
	return _journey_label.text if _journey_label != null and _journey_label.visible else ""


## Cuántos escudos lleva Flapo.
##
## Con uno se escribe "Escudo" a secas y con varios "Escudo x3". El "x1" se
## calla a propósito: es ruido, y a 288 px de ancho cada carácter que no dice
## nada le quita sitio a uno que sí.
func set_shield(cantidad: int) -> void:
	_shield_label.visible = cantidad > 0
	if cantidad > 1:
		_shield_label.text = "%s x%d" % [texto_escudo, cantidad]
	else:
		_shield_label.text = texto_escudo


## Nivel de aliento (T-048).
##
## La barra va abajo, sobre la franja del suelo, y no arriba: el criterio del
## ticket es que no tape la puntuación, y arriba ya están el marcador, el
## efecto activo y el escudo.
func set_breath(actual: float, maximo: float) -> void:
	if maximo <= 0.0:
		return
	var ratio: float = clampf(actual / maximo, 0.0, 1.0)
	# Se mueve `offset_right`, no `size`: el relleno tiene anclas verticales
	# opuestas (0 arriba, 1 abajo) para ocupar todo el alto, y en ese caso
	# Godot recalcula `size` después de `_ready()` y avisa de que lo va a
	# pisar. El ancho lo define el offset.
	_breath_fill.offset_right = _breath_back.size.x * ratio


## Fatiga (T-049): tiñe la barra de aliento en vez de ocupar sitio propio.
## Arriba ya no cabe nada más y son dos caras del mismo cansancio.
func set_fatigued(fatigado: bool, _aleteos: int) -> void:
	_breath_fill.color = COLOR_FATIGA if fatigado else COLOR_ALIENTO
