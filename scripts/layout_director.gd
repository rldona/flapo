class_name LayoutDirector
extends Node
## Vigila el tamaño de la ventana y publica el layout (T-085).
##
## Sustituye la idea de "layout de móvil / layout de escritorio" por un
## cálculo continuo: no hay dos casos, hay una función del tamaño de la
## ventana. Cualquier proporción —16:9, 21:9, 4:3, vertical extremo— sale del
## mismo cálculo, así que no hay un caso "raro" sin probar.
##
## Escucha `size_changed` de la raíz, que se emite **en vivo** al arrastrar el
## borde de la ventana, no solo al arrancar. Es la diferencia entre un layout
## que se adapta y uno que se configura una vez.
##
## No dibuja nada. Publica escala, caja del playfield y espacio sobrante, y
## quien decida qué hacer con ese hueco es otro (T-086): "signal up".
##
## Ver ADR-0025, y el aviso que lleva sobre `stretch/mode=viewport`.

## El layout ha cambiado. Solo se emite cuando cambia de verdad: arrastrar el
## borde de una ventana dispara `size_changed` en cada píxel, y la escala
## entera cambia una vez cada 288.
signal layout_changed(escala: int, playfield: Rect2i, margen: Vector2i)

var _escala: int = GameConfig.MIN_WINDOW_SCALE
var _playfield: Rect2i = Rect2i()
var _margen: Vector2i = Vector2i.ZERO
var _ventana: Vector2i = Vector2i.ZERO


func _ready() -> void:
	get_tree().root.size_changed.connect(_al_cambiar_la_ventana)
	_al_cambiar_la_ventana()


## Escala entera actual del playfield.
func scale_factor() -> int:
	return _escala


## Caja del playfield en píxeles reales de ventana.
func playfield() -> Rect2i:
	return _playfield


## Espacio sobrante a cada lado, en píxeles reales.
func margin() -> Vector2i:
	return _margen


## Recalcula para un tamaño de ventana dado.
##
## Se puede llamar con un tamaño inventado, y por eso es pública: en headless
## no hay ventana que redimensionar, así que probar el comportamiento en vivo
## exige poder simular el tamaño. Devuelve si el layout ha cambiado.
func update_for(ventana: Vector2i) -> bool:
	var escala: int = GameConfig.window_scale_for(ventana)
	var caja: Rect2i = GameConfig.playfield_rect_for(ventana)
	var margen: Vector2i = GameConfig.layout_margin_for(ventana)
	_ventana = ventana
	if escala == _escala and caja == _playfield and margen == _margen:
		return false
	_escala = escala
	_playfield = caja
	_margen = margen
	layout_changed.emit(_escala, _playfield, _margen)
	return true


func _al_cambiar_la_ventana() -> void:
	update_for(DisplayServer.window_get_size())
