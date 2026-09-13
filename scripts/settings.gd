class_name Settings
extends RefCounted
## Ajustes del jugador: de momento, solo el silencio.
##
## Vive aparte de `SaveManager` (progreso) porque son cosas distintas: borrar
## la partida no debería desactivar el mute, y al revés. Misma regla de oro:
## **nunca reventar**. Ver ADR-0013.

const RUTA: String = "user://settings.cfg"
const SECCION: String = "audio"

static var _cfg: ConfigFile = null


## Si el jugador ha silenciado el juego.
static func is_muted() -> bool:
	var valor: Variant = _datos().get_value(SECCION, "muted", false)
	return valor if typeof(valor) == TYPE_BOOL else false


## Guarda el silencio. Devuelve el valor que ha quedado.
static func set_muted(muted: bool) -> bool:
	var cfg: ConfigFile = _datos()
	cfg.set_value(SECCION, "muted", muted)
	var err: Error = cfg.save(RUTA)
	if err != OK:
		push_warning("No se han podido guardar los ajustes (error %d)." % err)
	return muted


## Olvida la copia en memoria. Solo para tests: simula reabrir el juego.
static func forget_cache() -> void:
	_cfg = null


## Borra los ajustes.
static func clear() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(RUTA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
	_cfg.save(RUTA)


static func _datos() -> ConfigFile:
	if _cfg != null:
		return _cfg
	_cfg = ConfigFile.new()
	var err: Error = _cfg.load(RUTA)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Ajustes ilegibles (error %d): se empieza de cero." % err)
		_cfg = ConfigFile.new()
	return _cfg
