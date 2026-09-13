class_name DailyChallenge
extends RefCounted
## El reto del día (T-241).
##
## Vive fuera de `Main` porque `Main` ya cablea medio juego: la fecha, la
## semilla, la clave de guardado y el nombre para compartir son un tema
## propio, y juntos caben en un objeto que se puede probar suelto.
##
## Es un `RefCounted` y no un nodo: no dibuja, no procesa y no escucha
## señales. Solo convierte una fecha en las cuatro cosas que el juego
## necesita saber de ella.

## La fecha del reto, [año, mes, día]. Vacía si no hay reto en curso.
var fecha: Array = []


## Si hay un reto en curso.
func activo() -> bool:
	return fecha.size() == 3


## La fecha de hoy, en LOCAL.
##
## `get_date_dict_from_system()` y no la variante UTC: el reto tiene que
## cambiar a medianoche del jugador, no a las dos de la madrugada. Está
## aparte para poder inyectar una fecha en los tests, que es lo único que
## permite probar "y al día siguiente cambia" sin esperar 24 horas.
static func hoy() -> Array:
	var d: Dictionary = Time.get_date_dict_from_system()
	return [int(d["year"]), int(d["month"]), int(d["day"])]


## Empieza el reto de esa fecha, o el de hoy si no se dice ninguna.
func empezar(nueva: Array = []) -> void:
	fecha = nueva.duplicate() if nueva.size() == 3 else hoy()


## Deja de haber reto.
func parar() -> void:
	fecha = []


## La semilla del reto en curso, o 0 si no hay.
func semilla() -> int:
	if not activo():
		return GameConfig.SEED_ALEATORIA
	return GameConfig.daily_seed(fecha[0], fecha[1], fecha[2])


## La clave de guardado del reto en curso, o "" si no hay.
func clave() -> String:
	if not activo():
		return ""
	return GameConfig.daily_key(fecha[0], fecha[1], fecha[2])


## "Reto del 8 de septiembre", para compartir. "" si no hay reto.
func nombre() -> String:
	if not activo():
		return ""
	return "Reto del %s" % GameConfig.daily_name(fecha[1], fecha[2])


## Mejor marca guardada de este reto.
func mejor() -> int:
	var k: String = clave()
	return SaveManager.get_daily_best(k) if k != "" else 0
