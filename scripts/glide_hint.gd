class_name GlideHint
extends CanvasLayer
## Enseña a planear, una vez en la vida (T-200).
##
## Vive en su propio `CanvasLayer` y no dentro del HUD porque el HUD solo se
## ve en `PLAYING` (T-029) y el pictograma tiene que salir en `READY`, antes
## de empezar. Meterlo ahí habría obligado a romper esa regla del HUD para un
## cartel que la mayoría de partidas ni sale.
##
## **Nunca bloquea la entrada.** Es un `Control` con `mouse_filter = IGNORE`
## y no pausa el árbol: aletear con el cartel puesto funciona exactamente
## igual que sin él. Un tutorial que hay que cerrar es un tutorial que
## estorba.
##
## No decide nada: Main le dice qué enseñar, y el "¿toca?" son funciones
## puras de `GameConfig` ("call down", ADR-0005).

## Lo que se enseña en READY, antes de la primera partida.
@export_multiline var texto_pictograma: String = "Mantén pulsado\npara planear"

## Lo que se enseña en mitad de la partida si nadie ha planeado.
@export_multiline var texto_aviso: String = "Mantén pulsado para planear"

@onready var _label: Label = $Root/Label


func _ready() -> void:
	visible = false


## Enseña el pictograma de READY, el aviso de partida, o nada.
func mostrar(modo: String) -> void:
	match modo:
		"pictograma":
			_label.text = texto_pictograma
			visible = true
		"aviso":
			_label.text = texto_aviso
			visible = true
		_:
			visible = false


## Lo que se está enseñando ahora mismo. Lo usan los tests.
func texto() -> String:
	return _label.text if visible else ""
