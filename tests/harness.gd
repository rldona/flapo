class_name Harness
extends RefCounted
## Utilidades mínimas para las comprobaciones headless.
##
## No es un framework de tests: es lo justo para que un `.gd` que extiende
## `SceneTree` pueda montar escenas, inyectar entrada y contar fallos. El
## framework de verdad (GUT o gdUnit4) llega en T-080; ver ADR-0007.

var fallos: int = 0
var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


## Registra una comprobación. `detalle` debe llevar los números reales: un
## test que solo dice "FALLO" obliga a volver a instrumentar a mano.
func check(nombre: String, ok: bool, detalle: String = "") -> void:
	var marca: String = "  OK   " if ok else "  FALLO"
	print(marca + " | " + nombre + (" | " + detalle if detalle != "" else ""))
	if not ok:
		fallos += 1


## Instancia una escena, le aplica `props` y la mete en el árbol.
##
## Las propiedades se asignan ANTES de entrar al árbol: si se hace después,
## `_ready()` ya ha corrido con los valores por defecto. Añadir un nodo desde
## `_init()` de un SceneTree no dispara `_ready()` hasta el primer frame de
## proceso, de ahí el `await`.
func montar(ruta: String, props: Dictionary = {}) -> Node:
	var nodo: Node = load(ruta).instantiate()
	for clave in props:
		nodo.set(clave, props[clave])
	_tree.root.add_child(nodo)
	await _tree.process_frame
	return nodo


## Inyecta una pulsación de tecla real.
##
## `Input.action_press()` NO sirve: no cuadra los contadores de frame que usa
## `is_action_just_pressed()` y la pulsación se pierde en `_physics_process`.
## Hay que soltar siempre lo que se pulsa, o la siguiente pulsación no genera
## flanco y el test falla por un motivo que no es el que se está probando.
func pulsa(keycode: Key, pulsada: bool = true) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pulsada
	Input.parse_input_event(ev)


## Espera `n` ticks de física (60 Hz fijos, ver ADR-0002).
func ticks(n: int) -> void:
	for i in n:
		await _tree.physics_frame


## Imprime el resumen y devuelve el código de salida para `quit()`.
func resumen(titulo: String) -> int:
	print("--- %s: %d fallo(s) ---" % [titulo, fallos])
	return 1 if fallos > 0 else 0
