class_name Effects
extends Node
## Los efectos temporales que dan las frutas (T-047).
##
## Reglas de composición, elegidas para que el jugador pueda saber siempre en
## qué estado está sin leer un manual:
##
## - **Un solo efecto temporal a la vez.** Coger una fruta sustituye el efecto
##   anterior y reinicia el reloj. Sin acumulaciones ni cancelaciones raras:
##   verde y luego roja deja "pesado", no "normal".
## - **El escudo va aparte** y no caduca: es una carga que se gasta al chocar.
##   Puede convivir con cualquier efecto.
##
## Este nodo no toca a nadie: solo lleva la cuenta y publica multiplicadores.
## Main los reparte ("call down", ADR-0005).

## Han cambiado los efectos activos. Lleva la lista entera y no uno solo:
## desde que se acumulan, "el efecto activo" ya no es una cosa.
signal changed(activos: Array)
## El escudo se ha ganado o se ha gastado. Lleva **cuántos quedan**, no un
## sí/no: los escudos se acumulan y el HUD tiene que poder decir cuántos.
signal shield_changed(cantidad: int)

enum Kind { NINGUNO, INMUNIDAD, PESADO, LIGERO, GRANDE, LENTO }

## Qué efectos compiten entre sí. Los del mismo eje se sustituyen; los de
## ejes distintos conviven.
##
## Pesado y ligero comparten eje **porque son opuestos**: dejarlos convivir
## los haría cancelarse, y el jugador vería "no pasa nada" con dos frutas
## encima. Eso es justo lo que ADR-0019 no quería.
const EJES: Dictionary = {
	"gravedad": [Kind.PESADO, Kind.LIGERO],
	"tamano": [Kind.GRANDE],
	"mundo": [Kind.LENTO],
}

## Cuánto dura un efecto temporal, s.
@export var duration: float = 6.0
## Multiplicador de gravedad de la fruta roja.
@export var heavy_gravity_mult: float = 2.0
## Multiplicador de gravedad de la fruta verde.
@export var light_gravity_mult: float = 0.5
## Cuánto crece el DIBUJO de Flapo con la fruta naranja.
@export var big_size_mult: float = 2.0
## Cuánto crece su HITBOX. Menos que el dibujo a propósito: ver ADR-0019.
@export var big_hitbox_mult: float = 1.6
## Multiplicador de velocidad del mundo de la fruta violeta.
@export var slow_speed_mult: float = 0.6

## Cuánto le queda a cada efecto activo, en segundos. Diccionario y no una
## variable suelta: los efectos se acumulan (ADR-0019, ampliación).
var _restantes: Dictionary = {}
## Cuántos escudos lleva encima. Un contador y no un `bool`: coger una azul
## teniendo otra ya no desperdicia la segunda.
var _shield: int = 0


func _process(delta: float) -> void:
	if _restantes.is_empty():
		return
	for k in _restantes.keys():
		_restantes[k] = float(_restantes[k]) - delta
		if _restantes[k] <= 0.0:
			_restantes.erase(k)
	changed.emit(activos())


## Activa lo que da una fruta.
func apply(kind: Kind) -> void:
	if kind == Kind.INMUNIDAD:
		# Se apilan hasta el tope. Pasado el tope la fruta no se pierde en
		# silencio para el jugador —ya lleva los que caben— pero tampoco
		# suma: es preferible a un contador que crece sin sentido.
		_shield = mini(_shield + 1, GameConfig.SHIELD_MAX)
		shield_changed.emit(_shield)
		return
	# Un efecto por EJE, varios ejes a la vez. Coger la violeta llevando la
	# naranja deja "grande y lento", que es lo que uno espera; coger la roja
	# llevando la verde deja "pesado" y no "normal", que es lo que ADR-0019
	# quería evitar: cancelaciones que el jugador tenga que deducir.
	for otro in EJES.get(_eje_de(kind), []):
		if otro != kind:
			_restantes.erase(otro)
	_restantes[kind] = duration
	changed.emit(activos())


## Gasta el escudo. Devuelve `true` si había uno y ha absorbido el golpe.
func consume_shield() -> bool:
	if _shield <= 0:
		return false
	_shield -= 1
	shield_changed.emit(_shield)
	return true


func has_shield() -> bool:
	return _shield > 0


## Cuántos escudos quedan. Lo usan el HUD y los tests.
func shield_count() -> int:
	return _shield


## Los efectos activos, como `[[kind, segundos], ...]`, del más reciente al
## más antiguo. Lo usan el HUD y los tests.
func activos() -> Array:
	var salida: Array = []
	for k in _restantes:
		salida.append([k, float(_restantes[k])])
	salida.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return salida


## Si ese efecto está activo ahora mismo.
func activo(kind: Kind) -> bool:
	return _restantes.has(kind)


## Cuánto le queda a ese efecto, o 0.
func time_left_of(kind: Kind) -> float:
	return float(_restantes.get(kind, 0.0))


## El efecto activo al que más le queda, o NINGUNO. Se conserva porque hay
## sitios a los que solo les interesa "¿hay algo?".
func kind() -> Kind:
	var lista: Array = activos()
	return lista[0][0] if not lista.is_empty() else Kind.NINGUNO


func time_left() -> float:
	var lista: Array = activos()
	return lista[0][1] if not lista.is_empty() else 0.0


func gravity_mult() -> float:
	if activo(Kind.PESADO):
		return heavy_gravity_mult
	if activo(Kind.LIGERO):
		return light_gravity_mult
	return 1.0


func speed_mult() -> float:
	return slow_speed_mult if activo(Kind.LENTO) else 1.0


func size_mult() -> float:
	return big_size_mult if activo(Kind.GRANDE) else 1.0


func hitbox_mult() -> float:
	return big_hitbox_mult if activo(Kind.GRANDE) else 1.0


## A qué eje pertenece un efecto.
static func _eje_de(kind: Kind) -> String:
	for eje in EJES:
		if (EJES[eje] as Array).has(kind):
			return eje
	return ""


## Nombre corto para el HUD.
func kind_name(kind: Kind) -> String:
	match kind:
		Kind.PESADO:
			return "Pesado"
		Kind.LIGERO:
			return "Ligero"
		Kind.GRANDE:
			return "Grande"
		Kind.LENTO:
			return "Lento"
		_:
			return ""


## Main llama a esto al volver a READY: los efectos no cruzan partidas.
func clear() -> void:
	_restantes.clear()
	_shield = 0
	changed.emit(activos())
	shield_changed.emit(0)
