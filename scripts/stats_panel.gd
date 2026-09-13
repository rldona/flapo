class_name StatsPanel
extends CanvasLayer
## Pantalla de estadísticas (T-084).
##
## **No es un estado nuevo de la máquina**: es un panel que se abre encima
## del menú, como la pausa se abre encima de la partida. Añadir un quinto
## estado obligaría a cada pieza del juego a saber que existe una pantalla
## que no cambia nada del mundo, y no hay nada que cambiar: detrás sigue
## estando el menú.
##
## Solo enseña lo que le dan. Quien lee el guardado es `Main` ("call down",
## ADR-0005), así que este panel se puede montar suelto en un test.

## El jugador quiere volver al menú.
signal back_pressed

@onready var _lines: VBoxContainer = $Root/Box/Lines
@onready var _back: Button = $Root/Box/Back


func _ready() -> void:
	_back.pressed.connect(func() -> void: back_pressed.emit())
	visible = false


## Abre o cierra el panel.
func set_open(abierto: bool) -> void:
	visible = abierto


## Rellena las filas. Se le pasan hechas para que el panel no sepa nada de
## `SaveManager` ni de cómo se calcula una media.
func set_stats(filas: Array) -> void:
	for hijo in _lines.get_children():
		hijo.queue_free()
	for fila in filas:
		var label := Label.new()
		label.text = "%s: %s" % [fila[0], fila[1]]
		_lines.add_child(label)


## Lo que enseña ahora mismo, en texto plano. Lo usan los tests.
func lines_text() -> PackedStringArray:
	var textos: PackedStringArray = PackedStringArray()
	for hijo in _lines.get_children():
		if hijo is Label:
			textos.append((hijo as Label).text)
	return textos
