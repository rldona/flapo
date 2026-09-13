class_name SaveManager
extends RefCounted
## Progreso persistente: récord y partidas jugadas.
##
## No es un autoload, aunque el ticket lo pidiera. Ver ADR-0013: el estado de
## verdad está en el fichero, no en memoria, y un `class_name` se resuelve en
## compilación (ADR-0009) mientras que un autoload no existe ni en
## `--check-only` ni en los scripts `-s` de los tests.
##
## Regla de oro de este fichero: **nunca reventar**. Un guardado ausente,
## corrupto, de otra versión o con tipos raros devuelve valores por defecto.
## Perder el récord es molesto; no poder abrir el juego es un desastre.

const RUTA: String = "user://save.cfg"
const SECCION: String = "progreso"

## Copia en memoria. Se rellena en la primera lectura.
static var _cfg: ConfigFile = null


## Mejor puntuación conseguida.
static func get_high_score() -> int:
	return _leer_int("high_score")


## Cuántas partidas se han jugado en total.
static func get_games_played() -> int:
	return _leer_int("games_played")


## Escalón de confianza alcanzado (T-074).
##
## Se guarda además de derivarse de las partidas jugadas, y no es
## redundancia gratuita: si algún día se sube `CONFIDENCE_STEP`, quien ya
## había llegado a un escalón no lo pierde. La progresión nunca va hacia
## atrás, que es lo único que un jugador no perdona.
static func get_confidence() -> int:
	return _leer_int("confidence")


## Modo de dificultad elegido la última vez (T-078).
##
## Por defecto NORMAL, que es el juego tal y como se diseñó: un guardado
## ausente o con un número imposible nunca deja al jugador en un modo raro.
static func get_difficulty() -> GameConfig.Difficulty:
	# NO se usa `_leer_int`: ese devuelve 0 para lo que falta, y 0 es FACIL.
	# El juego habría arrancado en fácil sin que nadie lo eligiera.
	# El defecto es NORMAL y no 0: 0 es FACIL, y el juego habría arrancado en
	# fácil sin que nadie lo eligiera. Por eso tampoco se usa `_leer_int`.
	var valor: Variant = _datos().get_value(
		SECCION, "difficulty", int(GameConfig.Difficulty.NORMAL)
	)
	if typeof(valor) != TYPE_INT and typeof(valor) != TYPE_FLOAT:
		return GameConfig.Difficulty.NORMAL
	var modo: int = int(valor)
	if modo < 0 or modo > int(GameConfig.Difficulty.DIFICIL):
		return GameConfig.Difficulty.NORMAL
	return modo as GameConfig.Difficulty


## Recuerda el modo elegido. Se guarda al elegirlo, no al morir: si el
## jugador cierra el juego desde el propio menú, la elección no se pierde.
static func set_difficulty(modo: GameConfig.Difficulty) -> void:
	var cfg: ConfigFile = _datos()
	cfg.set_value(SECCION, "difficulty", int(modo))
	var err: Error = cfg.save(RUTA)
	if err != OK:
		push_warning("No se ha podido guardar la dificultad (error %d)." % err)


## Registra una partida terminada. Devuelve `true` si ha sido récord.
static func record_game(score: int) -> bool:
	var cfg: ConfigFile = _datos()
	var record: bool = score > get_high_score()
	if record:
		cfg.set_value(SECCION, "high_score", score)
	var partidas: int = get_games_played() + 1
	cfg.set_value(SECCION, "games_played", partidas)
	# Nunca baja: se queda con lo mejor entre lo guardado y lo que toca.
	var nivel: int = maxi(get_confidence(), GameConfig.confidence_level(partidas))
	cfg.set_value(SECCION, "confidence", nivel)
	# Un fallo al escribir (disco lleno, permisos) no puede tumbar la
	# partida: se avisa y se sigue jugando con los datos en memoria.
	var err: Error = cfg.save(RUTA)
	if err != OK:
		push_warning("No se ha podido guardar el progreso (error %d)." % err)
	return record


## Borra el progreso. La usan los tests y serviría para un botón de reinicio
## de datos si algún día hace falta.
static func clear() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(RUTA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
	_cfg.save(RUTA)


## Olvida la copia en memoria y vuelve a leer del disco. Solo para tests:
## permite simular "abrir el juego otra vez" sin reiniciar el proceso.
static func forget_cache() -> void:
	_cfg = null


static func _datos() -> ConfigFile:
	if _cfg != null:
		return _cfg
	_cfg = ConfigFile.new()
	var err: Error = _cfg.load(RUTA)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		# Corrupto o ilegible: se descarta entero y se empieza de cero. Es
		# preferible a intentar rescatar valores sueltos de un fichero roto.
		push_warning("Guardado ilegible (error %d): se empieza de cero." % err)
		_cfg = ConfigFile.new()
	return _cfg


static func _leer_int(clave: String) -> int:
	var valor: Variant = _datos().get_value(SECCION, clave, 0)
	# El fichero es texto y editable a mano: puede traer cualquier cosa.
	if typeof(valor) != TYPE_INT and typeof(valor) != TYPE_FLOAT:
		return 0
	return maxi(int(valor), 0)
