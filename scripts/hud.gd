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

## Separación mínima del borde superior, px de juego. Se suma al margen que
## reporte el sistema, para que el marcador no quede pegado al borde ni
## siquiera en una pantalla sin notch.
@export var margen_superior: float = 24.0

@onready var _score_label: Label = $Score


func _ready() -> void:
	visible = false
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
