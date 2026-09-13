class_name GhostRecord
extends RefCounted
## El vuelo con el que se batió el récord, guardado en disco (T-243).
##
## Guarda **posiciones, no pulsaciones**, y esa es la decisión de fondo del
## ticket (ADR-0032). Reproducir un vuelo desde la lista de aleteos obliga a
## que la física de Flapo sea idéntica para siempre: el día que se toque
## `GRAVITY`, `flap_impulse` o el planeo en `GameConfig`, todos los fantasmas
## ya guardados se desincronizan y empiezan a atravesar tuberías sin que
## salte ningún error. Con posiciones, el fantasma **es** el vuelo que se
## hizo, pase lo que pase con las constantes.
##
## Solo se guarda la `y`: la `x` de Flapo no se mueve nunca (`_mantener_carril`
## en `Bird`), así que grabarla sería grabar 3600 veces el mismo número.
##
## Misma regla de oro que `SaveManager`: **nunca reventar**. Un fichero
## ausente, truncado, de otra versión o con basura devuelve `null` y el juego
## sigue exactamente igual, solo que sin fantasma.

const RUTA: String = "user://ghost.dat"

## Marca de fichero. Sin esto, cualquier fichero del tamaño justo se leería
## como si fuera un fantasma.
const MAGIC: int = 0x464C4147  # "FLAG", de FLApo Ghost

## Sube cuando cambie el formato. Un fichero de otra versión se descarta
## entero en vez de intentar interpretarlo a medias.
const VERSION: int = 1

## Bytes de cabecera: magia(4) + versión(4) + semilla(8) + marca(4) + nº(4).
const _CABECERA: int = 24

## La semilla de aquella partida. El fantasma solo sale si la de ahora es la
## misma: con otras tuberías, el vuelo grabado no significa nada.
var semilla: int = 0

## Los puntos que se hicieron. Se guarda para poder enseñarlos algún día y
## para saber, al grabar encima, si el vuelo nuevo es mejor.
var score: int = 0

## La `y` de Flapo en cada frame de física desde el primero de `PLAYING`.
var posiciones := PackedFloat32Array()


## Cuántos frames dura el vuelo.
func frames() -> int:
	return posiciones.size()


## La `y` grabada en ese frame. Pasado el final, se queda en la última: el
## fantasma se detiene donde se estrelló en vez de saltar al origen.
func y_en(frame: int) -> float:
	if posiciones.is_empty():
		return 0.0
	return posiciones[clampi(frame, 0, posiciones.size() - 1)]


## Escribe el fichero. `false` si no se ha podido, sin tumbar la partida.
func guardar(ruta: String = RUTA) -> bool:
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		push_warning(
			"No se ha podido guardar el fantasma (error %d)." % FileAccess.get_open_error()
		)
		return false
	f.store_32(MAGIC)
	f.store_32(VERSION)
	f.store_64(semilla)
	f.store_32(score)
	f.store_32(posiciones.size())
	for y in posiciones:
		f.store_float(y)
	f.close()
	return true


## Lee el fichero. `null` si no hay, no vale o no se entiende.
##
## Estático y devolviendo `null` a propósito: quien llama no tiene que
## preguntar "¿es válido?" después de construirlo, porque un `GhostRecord`
## que existe es siempre un fantasma reproducible.
static func cargar(ruta: String = RUTA) -> GhostRecord:
	if not FileAccess.file_exists(ruta):
		return null
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return null
	if f.get_length() < _CABECERA:
		return null
	if f.get_32() != MAGIC or f.get_32() != VERSION:
		return null
	var rec := GhostRecord.new()
	rec.semilla = f.get_64()
	rec.score = f.get_32()
	var n: int = f.get_32()
	if n <= 0 or n > GameConfig.GHOST_MAX_FRAMES:
		return null
	# El tamaño tiene que cuadrar al byte. Es lo que separa un fichero
	# truncado a medias de uno bueno: sin esta comprobación, un fichero
	# cortado se leería como un vuelo lleno de ceros y el fantasma caería
	# recto al suelo como si eso fuera lo que pasó.
	if f.get_length() != _CABECERA + n * 4:
		return null
	rec.posiciones.resize(n)
	for i in n:
		rec.posiciones[i] = f.get_float()
	f.close()
	return rec


## Borra el fichero. La usan los tests.
static func borrar(ruta: String = RUTA) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
