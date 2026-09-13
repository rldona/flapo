class_name GameSession
extends RefCounted
## Todo lo que una partida sabe de sí misma antes de empezar a jugarse.
##
## Semilla, código, reto del día, nombre del jugador, modo de dificultad y
## confianza acumulada. Son cosas distintas, pero comparten dos rasgos que
## las juntan aquí: **salen del guardado** y **no tienen nada que ver con el
## bucle de juego**.
##
## Se extrae de `Main` porque `Main` había pasado de veinte métodos públicos
## y la mitad eran esto. No era un problema del linter: era que `Main` hacía
## de máquina de estados, de cableado, de marcador Y de perfil del jugador, y
## cada ticket de la ola le añadía otro par de métodos.
##
## Es un `RefCounted` y no un nodo: no dibuja, no procesa, no escucha señales.
## Y **no cambia de estado**: quien decide cuándo se empieza a jugar sigue
## siendo `Main`. Aquí solo se prepara lo que esa partida va a ser.

## El generador de TODA la aleatoriedad de la partida (T-240, ADR-0030).
var rng := RandomNumberGenerator.new()

## El reto del día en curso, si lo hay (T-241).
var daily := DailyChallenge.new()

var _seed: int = 0
var _player_name: String = ""
var _difficulty: GameConfig.Difficulty = GameConfig.Difficulty.NORMAL
var _confidence: int = 0
var _has_glided: bool = false
var _mirror: bool = false


## Lee del guardado todo lo que persiste. Se llama una vez, al arrancar.
func cargar() -> void:
	_difficulty = SaveManager.get_difficulty()
	_player_name = SaveManager.get_player_name()
	_confidence = SaveManager.get_confidence()
	_has_glided = SaveManager.get_has_glided()
	_mirror = SaveManager.get_mirror()


## La semilla de la partida en curso (T-240).
func seed() -> int:
	return _seed


## Fija la semilla de la SIGUIENTE partida.
##
## No siembra ya: se siembra al empezar la partida. Si se sembrara aquí,
## jugar y reiniciar daría partidas distintas.
func set_seed(semilla: int) -> void:
	_seed = semilla


## El código corto de la partida en curso (T-242).
func codigo() -> String:
	return GameConfig.seed_a_codigo(_seed)


## Prepara una partida libre: sin reto y con semilla sorteada.
func preparar_libre() -> void:
	daily.parar()
	_seed = GameConfig.SEED_ALEATORIA


## Prepara el reto de una fecha, o el de hoy (T-241).
func preparar_reto(fecha: Array = []) -> void:
	daily.empezar(fecha)
	_seed = daily.semilla()


## Prepara la partida de un código. `false` si el código no vale (T-242).
func preparar_codigo(texto: String) -> bool:
	var semilla: int = GameConfig.codigo_a_seed(texto)
	if semilla < 0:
		return false
	daily.parar()
	_seed = semilla
	return true


## Siembra el generador y lo reparte entre las piezas que lo necesitan.
##
## Con semilla 0 se sortea una **dentro del espacio del código** (T-242) y se
## guarda: la partida libre sigue siendo distinta cada vez, pero se puede
## saber cuál tocó y volver a jugarla.
func sembrar(piezas: Array) -> void:
	if _seed == GameConfig.SEED_ALEATORIA:
		rng.randomize()
		_seed = posmod(int(rng.seed), GameConfig.codigo_modulo())
	# Solo `seed`: asignarlo ya reinicia el estado. Poner `state = 0` a mano
	# dejaba el generador degenerado, devolviendo la misma secuencia con
	# cualquier semilla (ADR-0030).
	rng.seed = _seed
	for pieza in piezas:
		if pieza != null:
			pieza.set_rng(rng)


## El nombre tal y como se guarda: vacío si no puso ninguno (T-079).
func player_name() -> String:
	return _player_name


## Guarda el nombre, ya saneado. Sale pronto si no ha cambiado: se llama en
## cada tecla y escribir no debería tocar el disco doce veces.
func set_player_name(nombre: String) -> void:
	var limpio: String = GameConfig.sanitize_player_name(nombre)
	if limpio == _player_name:
		return
	_player_name = limpio
	SaveManager.set_player_name(limpio)


## Modo de dificultad activo (T-078).
func difficulty() -> GameConfig.Difficulty:
	return _difficulty


## Cambia el modo y lo recuerda. Se guarda al elegir, no al morir.
func set_difficulty(modo: GameConfig.Difficulty) -> void:
	_difficulty = modo
	SaveManager.set_difficulty(modo)


## Si se juega en modo espejo (T-076).
func mirror() -> bool:
	return _mirror


## Cambia el modo espejo y lo recuerda.
##
## No comprueba aquí si está desbloqueado: quien conoce el récord es `Main`.
## La sesión guarda lo que le dicen; decidir si se puede es de quien tiene el
## dato ("call down", ADR-0005).
func set_mirror(activo: bool) -> void:
	_mirror = activo
	SaveManager.set_mirror(activo)


## Escalón de confianza acumulado (T-074).
func confidence() -> int:
	return _confidence


## Aliento máximo que le toca a Flapo con esa confianza (T-074).
func max_breath() -> float:
	return GameConfig.max_breath_for(_confidence)


## Si el jugador ya sabe planear (T-200).
func has_glided() -> bool:
	return _has_glided


## Marca que ya sabe. Se guarda en cuanto ocurre, no al morir.
func marcar_planeo() -> void:
	if _has_glided:
		return
	_has_glided = true
	SaveManager.set_has_glided()


## Registra la partida terminada. Devuelve `true` si ha sido récord.
##
## En el reto la marca va a SU clave y el récord general no se toca, pero la
## partida cuenta igual: si no, jugar retos no haría avanzar la confianza y
## sería una trampa al revés (T-241).
func registrar_partida(score: int) -> bool:
	var record: bool
	if daily.activo():
		record = SaveManager.record_daily(daily.clave(), score)
		SaveManager.record_game(score, false)
	else:
		record = SaveManager.record_game(score)
	_confidence = SaveManager.get_confidence()
	return record
