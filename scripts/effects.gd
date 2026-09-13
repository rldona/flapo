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

## El efecto activo ha cambiado. `restante` es 0 si no hay ninguno.
signal changed(kind: Kind, restante: float)
## El escudo se ha ganado o se ha gastado.
signal shield_changed(activo: bool)

enum Kind { NINGUNO, INMUNIDAD, PESADO, LIGERO, GRANDE, LENTO }

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

var _kind: Kind = Kind.NINGUNO
var _left: float = 0.0
var _shield: bool = false


func _process(delta: float) -> void:
	if _kind == Kind.NINGUNO:
		return
	_left = maxf(_left - delta, 0.0)
	if _left <= 0.0:
		_kind = Kind.NINGUNO
		changed.emit(_kind, 0.0)
	else:
		changed.emit(_kind, _left)


## Activa lo que da una fruta.
func apply(kind: Kind) -> void:
	if kind == Kind.INMUNIDAD:
		_shield = true
		shield_changed.emit(true)
		return
	_kind = kind
	_left = duration
	changed.emit(_kind, _left)


## Gasta el escudo. Devuelve `true` si había uno y ha absorbido el golpe.
func consume_shield() -> bool:
	if not _shield:
		return false
	_shield = false
	shield_changed.emit(false)
	return true


func has_shield() -> bool:
	return _shield


func kind() -> Kind:
	return _kind


func time_left() -> float:
	return _left


func gravity_mult() -> float:
	match _kind:
		Kind.PESADO:
			return heavy_gravity_mult
		Kind.LIGERO:
			return light_gravity_mult
		_:
			return 1.0


func speed_mult() -> float:
	return slow_speed_mult if _kind == Kind.LENTO else 1.0


func size_mult() -> float:
	return big_size_mult if _kind == Kind.GRANDE else 1.0


func hitbox_mult() -> float:
	return big_hitbox_mult if _kind == Kind.GRANDE else 1.0


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
	_kind = Kind.NINGUNO
	_left = 0.0
	_shield = false
	changed.emit(_kind, 0.0)
	shield_changed.emit(false)
