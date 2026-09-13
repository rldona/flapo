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


## Tuberías cruzadas en toda la vida del jugador (T-084).
##
## Es el ÚNICO contador nuevo que añade la pantalla de estadísticas, y a
## propósito: de él sale también la media por partida, que es el número que
## de verdad dice si uno está mejorando. Aleteos totales o tiempo jugado
## serían dos claves más que nadie mira.
static func get_total_score() -> int:
	return _leer_int("total_score")


## Puntuación media por partida (T-084). Derivada, no guardada.
static func get_average_score() -> float:
	var partidas: int = get_games_played()
	if partidas <= 0:
		return 0.0
	return float(get_total_score()) / float(partidas)


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


## Si el jugador está jugando en modo espejo (T-076).
##
## Va con la dificultad y no en `settings.cfg`: es un modo de juego, como
## fácil/normal/difícil, no una preferencia de presentación. Por defecto
## `false`, siempre: el modo normal es el juego.
static func get_mirror() -> bool:
	return _leer_int("mirror") > 0


## Recuerda el modo espejo. Se guarda al elegirlo, no al morir.
static func set_mirror(activo: bool) -> void:
	var cfg: ConfigFile = _datos()
	cfg.set_value(SECCION, "mirror", 1 if activo else 0)
	var err: Error = cfg.save(RUTA)
	if err != OK:
		push_warning("No se ha podido guardar el modo espejo (error %d)." % err)


## Nombre del jugador (T-079). Vacío si no ha puesto ninguno: quien decide
## qué enseñar entonces es `GameConfig.display_player_name`.
static func get_player_name() -> String:
	var valor: Variant = _datos().get_value(SECCION, "player_name", "")
	if typeof(valor) != TYPE_STRING:
		return ""
	# Se sanea también al LEER, no solo al escribir: el fichero es texto
	# editable a mano y puede traer un nombre de 300 caracteres.
	return GameConfig.sanitize_player_name(valor)


## Guarda el nombre, ya saneado.
static func set_player_name(nombre: String) -> void:
	var cfg: ConfigFile = _datos()
	cfg.set_value(SECCION, "player_name", GameConfig.sanitize_player_name(nombre))
	var err: Error = cfg.save(RUTA)
	if err != OK:
		push_warning("No se ha podido guardar el nombre (error %d)." % err)


## Si el jugador ha planeado alguna vez (T-200).
##
## Es lo que apaga el aviso para siempre. Ausente o corrupto devuelve
## `false`, o sea "todavía no": ante la duda se enseña, que es el error
## barato — el caro sería que alguien no descubra nunca el planeo.
static func get_has_glided() -> bool:
	return _leer_int("has_glided") > 0


## Lo marca. Se guarda en cuanto ocurre, no al morir: si el jugador cierra el
## juego justo después de descubrirlo, no tiene que volver a descubrirlo.
static func set_has_glided() -> void:
	if get_has_glided():
		return
	var cfg: ConfigFile = _datos()
	cfg.set_value(SECCION, "has_glided", 1)
	var err: Error = cfg.save(RUTA)
	if err != OK:
		push_warning("No se ha podido guardar el descubrimiento (error %d)." % err)


## Mejor marca conseguida en el reto de ese día (T-241).
##
## Clave propia por día, separada del récord general: mezclarlos haría que un
## buen día de reto contaminara el récord de siempre, y son dos cosas que se
## comparan con gente distinta.
static func get_daily_best(clave: String) -> int:
	return _leer_int(clave)


## Guarda la marca del día si mejora. Devuelve `true` si era mejor.
static func record_daily(clave: String, score: int) -> bool:
	if score <= get_daily_best(clave):
		return false
	var cfg: ConfigFile = _datos()
	cfg.set_value(SECCION, clave, score)
	var err: Error = cfg.save(RUTA)
	if err != OK:
		push_warning("No se ha podido guardar el reto (error %d)." % err)
	return true


## Los retos jugados, de más reciente a más antiguo (T-241).
##
## Se derivan de las claves que ya hay en el fichero: no hace falta una lista
## aparte que mantener sincronizada, y por tanto no puede desincronizarse.
static func get_daily_history() -> Array:
	var cfg: ConfigFile = _datos()
	if not cfg.has_section(SECCION):
		return []
	var retos: Array = []
	for clave in cfg.get_section_keys(SECCION):
		if (clave as String).begins_with("daily_"):
			retos.append([clave, _leer_int(clave)])
	retos.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return retos


## Registra una partida terminada. Devuelve `true` si ha sido récord.
##
## `cuenta_para_el_record` lo pone a `false` el reto del día (T-241): esa
## partida cuenta como jugada —y suma confianza y tuberías— pero su marca
## va a la clave del reto, no al récord general.
static func record_game(score: int, cuenta_para_el_record: bool = true) -> bool:
	var cfg: ConfigFile = _datos()
	var record: bool = cuenta_para_el_record and score > get_high_score()
	if record:
		cfg.set_value(SECCION, "high_score", score)
	var partidas: int = get_games_played() + 1
	cfg.set_value(SECCION, "games_played", partidas)
	cfg.set_value(SECCION, "total_score", get_total_score() + maxi(score, 0))
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
