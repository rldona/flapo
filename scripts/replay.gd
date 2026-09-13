class_name Replay
extends RefCounted
## Una partida grabada entera, para volver a jugarla igual (T-261).
##
## Un bug reportado con su replay se reproduce en CI sin que nadie tenga que
## jugar. Esa es toda la razón de existir de este fichero.
##
## **No es lo mismo que el fantasma (T-243).** El fantasma graba posiciones
## porque tiene que sobrevivir a que cambien las constantes (ADR-0032); un
## replay graba **entradas** porque tiene que reproducir la partida entera
## —muertes, frutas, viento— y no solo un vuelo. Son dos ficheros distintos a
## propósito, y ADR-0036 explica por qué no se pueden fusionar.
##
## Regla de oro de siempre: **nunca reventar**. Ausente, truncado, de otra
## versión o con basura devuelve `null` y el juego ni se entera.

const RUTA_ULTIMA: String = "user://last.replay"

## Marca de fichero: "FLRP", de FLapo RePlay.
const MAGIC: int = 0x464C5250

## Sube a 2 con T-067: el récord entra en el fichero. Un replay de la versión
## 1 no se puede reproducir con garantías porque no dice con qué récord se
## jugó, así que se descarta entero en vez de adivinarlo.
const VERSION: int = 2

## magia(4) + versión(4) + semilla(8) + modo(4) + confianza(4) + récord(4)
## + marca(4) + nº(4)
const _CABECERA: int = 36

## Tope de flancos, por si un fichero manipulado dice que trae millones.
const MAX_EVENTOS: int = 100000

## La semilla de la partida (T-240).
var semilla: int = 0

## El modo de dificultad con el que se jugó (T-078).
##
## Va en el fichero porque cambia el mundo: el hueco, la velocidad y la
## separación salen de él. Sin guardarlo, el replay de un bug en difícil se
## reproduciría en normal y el bug no aparecería.
var modo: GameConfig.Difficulty = GameConfig.Difficulty.NORMAL

## La confianza acumulada del jugador (T-074).
##
## Y esta es la que se olvida: la confianza **alarga la barra de aliento**, o
## sea que cambia cuánto se puede planear. El mismo fichero jugado por un
## perfil nuevo y por uno veterano da dos partidas distintas.
var confianza: int = 0

## El récord que tenía el jugador al empezar (T-067).
##
## Es el más raro de los cuatro y el que más tarde apareció. Desde T-067 el
## récord **cambia el mundo**: al superarlo salen cuatro tuberías especiales
## con la dificultad congelada. O sea que la misma semilla y las mismas
## pulsaciones dan partidas distintas según lo bueno que fueras antes.
##
## Lo destapó el bot de T-260 al dejar de dar dos tandas iguales, no una
## lectura del código.
var record: int = 0

## Los puntos que se hicieron. Es contra lo que se compara al reproducir: sin
## un resultado esperado, un replay no verifica nada, solo vuelve a jugar.
var score: int = 0

## En qué frames cambió el botón, y a qué. Se guardan los **flancos**, no el
## estado de cada frame: una partida de un minuto son 3600 frames y unos 80
## flancos.
var frames := PackedInt32Array()
var pulsado := PackedByteArray()


## Cuántos flancos tiene.
func eventos() -> int:
	return frames.size()


## Anota un flanco. Devuelve `false` si se pasó del tope.
func anotar(frame: int, esta_pulsado: bool) -> bool:
	if frames.size() >= MAX_EVENTOS:
		return false
	frames.append(frame)
	pulsado.append(1 if esta_pulsado else 0)
	return true


## Escribe el fichero. `false` si no se ha podido, sin tumbar la partida.
func guardar(ruta: String = RUTA_ULTIMA) -> bool:
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		push_warning("No se ha podido guardar el replay (error %d)." % FileAccess.get_open_error())
		return false
	f.store_32(MAGIC)
	f.store_32(VERSION)
	f.store_64(semilla)
	f.store_32(int(modo))
	f.store_32(confianza)
	f.store_32(record)
	f.store_32(score)
	f.store_32(frames.size())
	for i in frames.size():
		f.store_32(frames[i])
		f.store_32(pulsado[i])
	f.close()
	return true


## Lee el fichero. `null` si no hay, no vale o no se entiende.
static func cargar(ruta: String = RUTA_ULTIMA) -> Replay:
	if not FileAccess.file_exists(ruta):
		return null
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if f == null or f.get_length() < _CABECERA:
		return null
	if f.get_32() != MAGIC or f.get_32() != VERSION:
		return null
	var rep := Replay.new()
	rep.semilla = f.get_64()
	var m: int = f.get_32()
	if m < 0 or m > int(GameConfig.Difficulty.DIFICIL):
		return null
	rep.modo = m as GameConfig.Difficulty
	rep.confianza = f.get_32()
	rep.record = f.get_32()
	rep.score = f.get_32()
	var n: int = f.get_32()
	if n < 0 or n > MAX_EVENTOS:
		return null
	# El tamaño tiene que cuadrar al byte: un fichero cortado se leería como
	# una partida con menos pulsaciones, o sea otra partida distinta que
	# encima parecería válida.
	if f.get_length() != _CABECERA + n * 8:
		return null
	for i in n:
		rep.frames.append(f.get_32())
		rep.pulsado.append(f.get_32())
	f.close()
	# Los frames tienen que ir a más: si no, el fichero está manipulado y
	# reproducirlo daría cualquier cosa.
	for i in range(1, rep.frames.size()):
		if rep.frames[i] <= rep.frames[i - 1]:
			return null
	return rep


## Borra el fichero. La usan los tests.
static func borrar(ruta: String = RUTA_ULTIMA) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
